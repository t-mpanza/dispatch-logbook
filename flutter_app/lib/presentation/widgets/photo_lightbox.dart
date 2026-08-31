import 'dart:io';
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
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _initImageProvider();
  }

  Future<void> _initImageProvider() async {
    setState(() => _isLoadingProvider = true);

    // 1. Direct Memory Bytes
    if (widget.attachment.bytes != null && widget.attachment.bytes!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _imageProvider = MemoryImage(widget.attachment.bytes!);
          _isLoadingProvider = false;
        });
      }
      return;
    }

    // 2. Direct Local File Path
    if (widget.attachment.localFilePath != null) {
      final file = File(widget.attachment.localFilePath!);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _imageProvider = FileImage(file);
            _isLoadingProvider = false;
          });
        }
        return;
      }
    }

    // 3. Fallback to App Documents Directory
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final localCandidate1 = File('${docDir.path}/attachments/${widget.attachment.id}.jpg');
      if (await localCandidate1.exists()) {
        if (mounted) {
          setState(() {
            _imageProvider = FileImage(localCandidate1);
            _isLoadingProvider = false;
          });
        }
        return;
      }

      if (widget.attachment.name != null) {
        final localCandidate2 = File('${docDir.path}/${widget.attachment.name}');
        if (await localCandidate2.exists()) {
          if (mounted) {
            setState(() {
              _imageProvider = FileImage(localCandidate2);
              _isLoadingProvider = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    // 4. Remote Cloud URL
    final url = _resolveImageUrl();
    if (url != null) {
      _resolvedUrl = url;
      if (mounted) {
        setState(() {
          _imageProvider = NetworkImage(url);
          _isLoadingProvider = false;
        });
      }
      return;
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

      if (widget.attachment.bytes != null) {
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

  Future<void> _handleOpenInBrowser() async {
    final url = _resolveImageUrl();
    if (url != null) {
      AppHaptics.light();
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl ?? _resolveImageUrl();

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
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (widget.attachment.caption != null)
              Text(
                widget.attachment.caption!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (url != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded,
                  color: AppColors.textSecondary, size: 20),
              tooltip: 'Open in Browser',
              onPressed: _handleOpenInBrowser,
            ),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGlow))
          : _imageProvider == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: GlassDecorations.glassCard(borderRadius: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image_not_supported_rounded,
                              size: 48, color: AppColors.warning),
                          const SizedBox(height: 14),
                          const Text(
                            'Image Stored Locally',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This image is saved on the originating device. If synced to a second device, the Supabase storage bucket "attachments" is required.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _initImageProvider,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                            label: const Text('Retry Loading',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
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
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
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
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: GlassDecorations.glassCard(borderRadius: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded,
                                size: 48, color: AppColors.warning),
                            const SizedBox(height: 14),
                            const Text(
                              'Cloud Bucket "attachments" Not Found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'The storage bucket is missing in your Supabase project dashboard. Captured photos will continue to save safely in local device storage.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _initImageProvider,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                              label: const Text('Retry Local Load',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
