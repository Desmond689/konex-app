import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../providers/story_provider.dart';
import '../../../../core/errors/error_handler.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  String? _mediaType; // photo | video | text
  File? _file;
  final _textCtrl = TextEditingController();
  String _privacy = 'everyone';
  String _bgColor = '#7C3AED';
  bool _loading = false;
  String? _error;

  final _colors = [
    '#7C3AED',
    '#EC4899',
    '#3B82F6',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#000000',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source, {bool video = false}) async {
    final picker = ImagePicker();
    final XFile? file;
    if (video) {
      file = await picker.pickVideo(source: source, maxDuration: const Duration(seconds: 30));
    } else {
      file = await picker.pickImage(source: source, maxWidth: 1080, imageQuality: 85);
    }
    if (file == null) return;
    setState(() {
      _file = File(file!.path);
      _mediaType = video ? 'video' : 'photo';
    });
  }

  Future<void> _submit() async {
    if (_mediaType == null) return;
    if (_mediaType == 'text' && _textCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Write something for your text story');
      return;
    }
    if ((_mediaType == 'photo' || _mediaType == 'video') && _file == null) {
      setState(() => _error = 'Select a photo or video');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? mediaUrl;
      if (_file != null) {
        final up = await ref.read(storyRepositoryProvider).uploadMedia(_file!, _mediaType!);
        mediaUrl = up.valueOrNull;
        if (mediaUrl == null) {
          setState(() {
            _loading = false;
            _error = 'Upload failed';
          });
          return;
        }
      }

      final r = await ref.read(storyRepositoryProvider).create(
            mediaType: _mediaType!,
            mediaUrl: mediaUrl,
            textContent: _mediaType == 'text' ? _textCtrl.text.trim() : null,
            backgroundColor: _mediaType == 'text' ? _bgColor : null,
            privacy: _privacy,
          );

      if (!mounted) return;
      setState(() => _loading = false);
      r.when(
        success: (_) {
          ref.invalidate(homeStoryRingsProvider);
          Navigator.of(context).pop(true);
        },
        failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = ErrorHandler.userMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Story'),
        actions: [
          if (_mediaType != null)
            TextButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Share', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _mediaType == null ? _typePicker() : _compose(),
    );
  }

  Widget _typePicker() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share a moment', style: AppTextStyles.headline),
          const SizedBox(height: 8),
          Text(
            'Stories disappear after 24 hours',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 32),
          _typeCard(
            icon: Icons.photo_camera_outlined,
            label: 'Photo',
            subtitle: 'From camera or gallery',
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Camera'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pick(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Gallery'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pick(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _typeCard(
            icon: Icons.videocam_outlined,
            label: 'Video',
            subtitle: 'Up to 30 seconds',
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.videocam),
                      title: const Text('Record'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pick(ImageSource.camera, video: true);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.video_library),
                      title: const Text('Gallery'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pick(ImageSource.gallery, video: true);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _typeCard(
            icon: Icons.text_fields,
            label: 'Text',
            subtitle: 'Type something cool',
            onTap: () => setState(() => _mediaType = 'text'),
          ),
        ],
      ),
    );
  }

  Widget _typeCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.title.copyWith(fontSize: 16)),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compose() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_mediaType == 'photo' && _file != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(_file!, height: 320, width: double.infinity, fit: BoxFit.cover),
          ),
        if (_mediaType == 'video' && _file != null)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, size: 48, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text('Video selected'),
                ],
              ),
            ),
          ),
        if (_mediaType == 'text') ...[
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: Color(int.parse(_bgColor.replaceFirst('#', '0xFF'))),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: TextField(
              controller: _textCtrl,
              maxLines: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Type your story...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _colors[i];
                final selected = c == _bgColor;
                return GestureDetector(
                  onTap: () => setState(() => _bgColor = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Who can see this?', style: AppTextStyles.title.copyWith(fontSize: 15)),
        const SizedBox(height: 8),
        ...[
          ('everyone', '🌎 Everyone'),
          ('followers', '👥 Followers'),
          ('friends', '🎮 Gaming friends'),
          ('only_me', '🔒 Only me'),
        ].map((o) {
          return RadioListTile<String>(
            value: o.$1,
            groupValue: _privacy,
            onChanged: (v) => setState(() => _privacy = v!),
            title: Text(o.$2),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          );
        }),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 24),
        KxButton(
          label: _loading ? 'Sharing...' : 'Share Story',
          onPressed: _loading ? null : _submit,
        ),
        TextButton(
          onPressed: () => setState(() {
            _mediaType = null;
            _file = null;
            _textCtrl.clear();
          }),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
