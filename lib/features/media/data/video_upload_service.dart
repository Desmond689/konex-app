import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/constants.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/base_repository.dart';

/// Client-side video upload.
/// Max 50 MB. Authorization + api.video secret stay on Edge Function.
class VideoUploadService with BaseRepository {
  VideoUploadService(this._client);
  final SupabaseClient _client;

  static const int maxBytes = AppConstants.maxVideoUploadBytes; // 50 MB

  /// Validate local file before any network call.
  Result<void> validateFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return Failure('File not found');
    }
    final size = file.lengthSync();
    if (size <= 0) return Failure('Empty file');
    if (size > maxBytes) {
      return Failure(
        'Video must be under ${maxBytes ~/ (1024 * 1024)} MB (yours is ${size ~/ (1024 * 1024)} MB)',
      );
    }
    final ext = p.extension(path).toLowerCase();
    const allowed = {'.mp4', '.mov', '.webm', '.m4v'};
    if (!allowed.contains(ext)) {
      return Failure('Unsupported format. Use MP4, MOV, or WebM.');
    }
    return const Success(null);
  }

  /// 1) Ask Edge Function for upload session
  /// 2) Upload bytes to api.video (or mock path)
  /// 3) Create post + media metadata in Supabase
  Future<Result<String>> uploadAndCreatePost({
    required String localPath,
    String? caption,
    void Function(double progress)? onProgress,
  }) {
    return guard(() async {
      final validation = validateFile(localPath);
      if (validation.isFailure) {
        throw validation.when(
          success: (_) => StateError('unreachable'),
          failure: (e, _) => e is Exception ? e : Exception(e.toString()),
        );
      }

      // Request upload authorization from Edge Function (JWT attached by supabase client)
      final sessionRes = await _client.functions.invoke(
        'create-video-upload',
        body: {
          'title': caption ?? 'KONEX clip',
          'description': caption ?? '',
        },
      );

      if (sessionRes.status != 200) {
        throw Exception(
          'Upload auth failed (${sessionRes.status}): ${sessionRes.data}',
        );
      }

      final data = Map<String, dynamic>.from(sessionRes.data as Map);
      final videoId = data['videoId'] as String?;
      final uploadToken = data['uploadToken'] as String?;
      final isMock = data['mock'] == true;

      if (videoId == null) {
        throw Exception('No videoId from server');
      }

      if (isMock) {
        throw Exception(
          'Video upload is not configured on the server (api.video mock mode). '
          'Your clip was not posted. Ask an admin to configure the create-video-upload function.',
        );
      }

      if (uploadToken != null) {
        await _uploadToApiVideo(
          localPath: localPath,
          uploadToken: uploadToken,
          onProgress: onProgress,
        );
      } else {
        // Fallback: progressive upload endpoint with video id (token-less flows vary by api.video plan)
        await _uploadToApiVideoWithVideoId(
          localPath: localPath,
          videoId: videoId,
          onProgress: onProgress,
        );
      }

      final uid = _client.auth.currentUser!.id;
      final mediaUrl = 'https://vod.api.video/vod/$videoId/mp4/source.mp4';
      final thumb = 'https://vod.api.video/vod/$videoId/thumbnail.jpg';

      final mediaRow = await _client.from('media').insert({
        'owner_id': uid,
        'type': 'video',
        'provider': 'api_video',
        'storage_key': videoId,
        'media_url': mediaUrl,
        'thumbnail_url': thumb,
        'status': 'processing',
      }).select().single();

      final post = await _client.from('posts').insert({
        'author_id': uid,
        'body': caption?.trim().isEmpty == true ? null : caption?.trim(),
        'post_type': 'video',
        'visibility': 'public',
      }).select().single();

      await _client.from('post_media').insert({
        'post_id': post['id'],
        'media_id': mediaRow['id'],
        'position': 0,
      });

      onProgress?.call(1.0);
      return post['id'] as String;
    });
  }

  Future<void> _uploadToApiVideo({
    required String localPath,
    required String uploadToken,
    void Function(double progress)? onProgress,
  }) async {
    final file = File(localPath);
    final length = await file.length();
    final uri = Uri.parse('https://ws.api.video/upload?token=$uploadToken');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        localPath,
        filename: p.basename(localPath),
      ),
    );

    onProgress?.call(0.1);
    final streamed = await request.send();
    onProgress?.call(0.9);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('api.video upload failed: ${res.statusCode} ${res.body}');
    }
    // length used for future chunked progress
    assert(length > 0);
  }

  Future<void> _uploadToApiVideoWithVideoId({
    required String localPath,
    required String videoId,
    void Function(double progress)? onProgress,
  }) async {
    // Production: prefer token upload. This path requires server-side proxy if no client token.
    onProgress?.call(0.5);
    throw Exception(
      'Configure API_VIDEO_API_KEY and upload token flow. '
      'Video id=$videoId created; complete upload via Edge proxy if needed.',
    );
  }
}
