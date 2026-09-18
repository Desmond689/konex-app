import 'dart:io';

import '../../../media/presentation/create_video_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../providers/post_provider.dart';
import '../../../../core/errors/error_handler.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _body = TextEditingController();
  final List<String> _imagePaths = [];
  bool _loading = false;
  String? _error;

  static const _maxImages = 10;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final remaining = _maxImages - _imagePaths.length;
    if (remaining <= 0) {
      setState(() => _error = 'Max $_maxImages photos per post');
      return;
    }
    final files = await picker.pickMultiImage(
      maxWidth: 1920,
      imageQuality: 85,
      limit: remaining,
    );
    if (files.isEmpty || !mounted) return;
    setState(() {
      _imagePaths.addAll(files.map((f) => f.path).take(remaining));
      _error = null;
    });
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty && _imagePaths.isEmpty) {
      setState(() => _error = 'Write something or add photos');
      return;
    }
    if (text.length > AppConstants.maxPostTextLength) {
      setState(() => _error = 'Post is too long');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = ref.read(postRepositoryProvider);
    final result = _imagePaths.isNotEmpty
        ? await repo.createMultiImagePost(
            body: text,
            localImagePaths: List.from(_imagePaths),
          )
        : await repo.createTextPost(body: text);

    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _body,
              maxLines: 5,
              maxLength: AppConstants.maxPostTextLength,
              decoration: const InputDecoration(
                hintText: "What's on your mind, gamer?",
                border: InputBorder.none,
              ),
              style: AppTextStyles.body,
            ),
            if (_imagePaths.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagePaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_imagePaths[i]),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagePaths.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_imagePaths.length}/$_maxImages photos',
                style: AppTextStyles.caption,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(color: Colors.redAccent),
                ),
              ),
            const Spacer(),
            Row(
              children: [
                IconButton(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  tooltip: 'Add photos',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateVideoPostScreen()),
                  ),
                  icon: const Icon(Icons.videocam_outlined),
                  tooltip: 'Video',
                ),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: KxButton(
                    label: 'Post',
                    onPressed: _submit,
                    loading: _loading,
                    expanded: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
