import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/attachment.dart';
import '../../data/services/supabase_service.dart';

class PhotoLightbox extends StatefulWidget {
  final Attachment attachment;

  const PhotoLightbox({super.key, required this.attachment});

  static void show(BuildContext context, Attachment attachment) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        pageBuilder: (context, _, _) => PhotoLightbox(attachment: attachment),
      ),
    );
  }

  @override
  State<PhotoLightbox> createState() => _PhotoLightboxState();
}

class _PhotoLightboxState extends State<PhotoLightbox> {
  bool _isDownloading = false;

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

  ImageProvider? _resolveImageProvider() {
    if (widget.attachment.bytes != null) {
      return MemoryImage(widget.attachment.bytes!);
    }

    if (widget.attachment.localFilePath != null) {
      final file = File(widget.attachment.localFilePath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    final url = _resolveImageUrl();
    if (url != null) {
      return NetworkImage(url);
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
      } else {
        final url = _resolveImageUrl();
        if (url != null) {
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            await file.writeAsBytes(res.bodyBytes);
          } else {
            throw Exception('HTTP ${res.statusCode}');
          }
        } else {
          throw Exception('No image source available');
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
              'Failed to download image: $e',
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
    final imageProvider = _resolveImageProvider();
    final url = _resolveImageUrl();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
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
            tooltip: 'Download Image',
            onPressed: _isDownloading ? null : _handleDownload,
          ),
        ],
      ),
      body: imageProvider == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_rounded,
                      size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Image not available locally or in cloud',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          : PhotoView(
              imageProvider: imageProvider,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load image ($error)',
                      style:
                          const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
