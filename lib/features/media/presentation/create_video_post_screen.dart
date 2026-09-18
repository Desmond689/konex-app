import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/dependency_injection.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/kx_button.dart';
import '../data/video_upload_service.dart';
import '../../../core/errors/error_handler.dart';

final videoUploadServiceProvider = Provider((ref) {
  return VideoUploadService(ref.watch(supabaseClientProvider));
});

class CreateVideoPostScreen extends ConsumerStatefulWidget {
  const CreateVideoPostScreen({super.key});

  @override
  ConsumerState<CreateVideoPostScreen> createState() =>
      _CreateVideoPostScreenState();
}

class _CreateVideoPostScreenState extends ConsumerState<CreateVideoPostScreen> {
  final _caption = TextEditingController();
  String? _path;
  bool _loading = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (file == null) return;
    final service = ref.read(videoUploadServiceProvider);
    final v = service.validateFile(file.path);
    if (v.isFailure) {
      setState(() => _error = v.when(
            success: (_) => null,
            failure: (e, _) => e.toString(),
          ));
      return;
    }
    setState(() {
      _path = file.path;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_path == null) {
      setState(() => _error = 'Select a video first');
      return;
    }
    setState(() {
      _loading = true;
      _progress = 0;
      _error = null;
    });
    final r = await ref.read(videoUploadServiceProvider).uploadAndCreatePost(
          localPath: _path!,
          caption: _caption.text.trim(),
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
    if (!mounted) return;
    setState(() => _loading = false);
    r.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload clip')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Max 50 MB. API keys stay on the server (Edge Function).',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _pick,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(_path == null ? 'Choose video' : _path!.split('/').last),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Caption (optional)'),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              Text('${(_progress * 100).toStringAsFixed(0)}%', style: AppTextStyles.caption),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
            ],
            const Spacer(),
            KxButton(
              label: 'Post clip',
              onPressed: _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
