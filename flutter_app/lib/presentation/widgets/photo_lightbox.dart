import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/attachment.dart';
import '../../data/services/supabase_service.dart';

class PhotoLightbox extends StatefulWidget {
  final Attachment attachment;

  const PhotoLightbox({super.key, required this.attachment});

  static void show(BuildContext context, Attachment attachment) {
    AppHaptics.light();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoLightbox(attachment: attachment),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<PhotoLightbox> createState() => _PhotoLightboxState();
}

class _PhotoLightboxState extends State<PhotoLightbox> {
  bool _isDownloading = false;
  ImageProvider? _imageProvider;
  bool _isLoadingProvider = true;
  Uint8List? _loadedBytes;

  @override
  void initState() {
    super.initState();
    _initImageProvider();
  }

  Future<void> _initImageProvider() async {
    setState(() {
      _isLoadingProvider = true;
    });

    // 1. In-Memory Raw Bytes
    if (widget.attachment.bytes != null && widget.attachment.bytes!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _loadedBytes = widget.attachment.bytes;
          _imageProvider = MemoryImage(_loadedBytes!);
          _isLoadingProvider = false;
        });
      }
      return;
    }

    // 2. Direct Local File Path
    if (widget.attachment.localFilePath != null) {
      final file = File(widget.attachment.localFilePath!);
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          if (mounted) {
            setState(() {
              _loadedBytes = bytes;
              _imageProvider = FileImage(file);
              _isLoadingProvider = false;
            });
          }
          return;
        } catch (_) {}
      }
    }

    // 3. Fallback: Scan Permanent Local Documents Directory
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final localCandidate1 =
          File('${docDir.path}/attachments/${widget.attachment.id}.jpg');
      if (await localCandidate1.exists()) {
        final bytes = await localCandidate1.readAsBytes();
        if (mounted) {
          setState(() {
            _loadedBytes = bytes;
            _imageProvider = FileImage(localCandidate1);
            _isLoadingProvider = false;
          });
        }
        return;
      }

      if (widget.attachment.name != null) {
        final localCandidate2 =
            File('${docDir.path}/attachments/${widget.attachment.name}');
        if (await localCandidate2.exists()) {
          final bytes = await localCandidate2.readAsBytes();
          if (mounted) {
            setState(() {
              _loadedBytes = bytes;
              _imageProvider = FileImage(localCandidate2);
              _isLoadingProvider = false;
            });
          }
          return;
        }

        final localCandidate3 =
            File('${docDir.path}/${widget.attachment.name}');
        if (await localCandidate3.exists()) {
          final bytes = await localCandidate3.readAsBytes();
          if (mounted) {
            setState(() {
              _loadedBytes = bytes;
              _imageProvider = FileImage(localCandidate3);
              _isLoadingProvider = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    // 4. Remote Cloud URL Resolution & Proactive Fetch
    final url = _resolveImageUrl();
    if (url != null) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          _loadedBytes = response.bodyBytes;

          // Cache permanently to documents directory
          try {
            final docDir = await getApplicationDocumentsDirectory();
            final attachmentsDir = Directory('${docDir.path}/attachments');
            if (!attachmentsDir.existsSync()) {
              await attachmentsDir.create(recursive: true);
            }
            final saveFile =
                File('${attachmentsDir.path}/${widget.attachment.id}.jpg');
            await saveFile.writeAsBytes(_loadedBytes!);
          } catch (_) {}

          if (mounted) {
            setState(() {
              _imageProvider = MemoryImage(_loadedBytes!);
              _isLoadingProvider = false;
            });
          }
          return;
        } else {
          // HTTP 404 or NoSuchBucket
          if (mounted) {
            setState(() {
              _imageProvider = null;
              _isLoadingProvider = false;
            });
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _imageProvider = null;
            _isLoadingProvider = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _imageProvider = null;
        _isLoadingProvider = false;
      });
    }
  }

  String? _resolveImageUrl() {
    if (widget.attachment.downloadUrl != null &&
        widget.attachment.downloadUrl!.isNotEmpty) {
      return widget.attachment.downloadUrl;
    }
    if (widget.attachment.storagePath != null &&
        widget.attachment.storagePath!.isNotEmpty) {
      return SupabaseService.client.storage
          .from('attachments')
          .getPublicUrl(widget.attachment.storagePath!);
    }
    return null;
  }

  Future<void> _handleDownload() async {
    AppHaptics.medium();
    setState(() => _isDownloading = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filename = widget.attachment.name ??
          'dispatch_photo_${widget.attachment.id.substring(0, 8)}.jpg';
      final file = File('${dir.path}/$filename');

      if (_loadedBytes != null) {
        await file.writeAsBytes(_loadedBytes!);
      } else if (widget.attachment.bytes != null) {
        await file.writeAsBytes(widget.attachment.bytes!);
      } else if (widget.attachment.localFilePath != null &&
          File(widget.attachment.localFilePath!).existsSync()) {
        final src = File(widget.attachment.localFilePath!);
        await file.writeAsBytes(await src.readAsBytes());
      } else {
        final url = _resolveImageUrl();
        if (url != null) {
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            await file.writeAsBytes(res.bodyBytes);
          } else {
            throw Exception('Cloud storage returned HTTP ${res.statusCode}');
          }
        } else {
          throw Exception('No local or cloud image source found');
        }
      }

      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.backgroundSecondary,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved to device: $filename',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.errorBg,
            content: Text(
              'Failed to save image: $e',
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _handleOpenSupabaseStorage() async {
    AppHaptics.light();
    const dashboardUrl =
        'https://supabase.com/dashboard/project/glxxawxuwusxwjvezugo/storage/buckets';
    final uri = Uri.parse(dashboardUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.attachment.name ?? 'Photo Preview',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            if (widget.attachment.caption != null)
              Text(
                widget.attachment.caption!,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (_imageProvider != null)
            IconButton(
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGlow,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_rounded,
                      color: AppColors.primaryGlow, size: 22),
              tooltip: 'Save to Device',
              onPressed: _isDownloading ? null : _handleDownload,
            ),
        ],
      ),
      body: _isLoadingProvider
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primaryGlow,
                    strokeWidth: 2.5,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Loading photo...',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : _imageProvider == null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: GlassDecorations.glassCard(borderRadius: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cloud_off_rounded,
                                size: 30, color: AppColors.warning),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Supabase Storage Bucket "attachments" Required',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'The cloud database contains a reference to this photo, but the storage bucket "attachments" does not exist in your Supabase project dashboard.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HOW TO CREATE THE BUCKET (10 SECONDS):',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGlow,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '1. Open Supabase Dashboard → Storage\n'
                                  '2. Click "New bucket"\n'
                                  '3. Name: attachments\n'
                                  '4. Toggle "Public bucket" → ON\n'
                                  '5. Click "Save bucket"',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textPrimary,
                                    height: 1.5,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _handleOpenSupabaseStorage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.open_in_browser_rounded,
                                  size: 18, color: Colors.white),
                              label: const Text(
                                'Open Supabase Storage Page',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: _initImageProvider,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.glassBorder),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.refresh_rounded,
                                  size: 16, color: AppColors.textSecondary),
                              label: const Text(
                                'Retry Loading',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : PhotoView(
                  imageProvider: _imageProvider!,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3.0,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.black),
                  loadingBuilder: (context, event) => Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: event == null
                            ? 0
                            : event.cumulativeBytesLoaded /
                                (event.expectedTotalBytes ?? 1),
                        color: AppColors.primaryGlow,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
    );
  }
}
