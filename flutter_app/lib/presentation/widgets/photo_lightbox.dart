import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/attachment.dart';
import '../../data/services/supabase_service.dart';

class PhotoLightbox extends StatefulWidget {
  final List<Attachment> attachments;
  final int initialIndex;

  const PhotoLightbox({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
  });

  static void show(
    BuildContext context,
    Attachment attachment, {
    List<Attachment>? allAttachments,
  }) {
    AppHaptics.light();
    final photoList = allAttachments != null && allAttachments.isNotEmpty
        ? allAttachments.where((a) => a.kind == AttachmentKind.photo || a.kind == AttachmentKind.image).toList()
        : [attachment];

    final idx = photoList.indexWhere((a) => a.id == attachment.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoLightbox(
          attachments: photoList.isNotEmpty ? photoList : [attachment],
          initialIndex: idx >= 0 ? idx : 0,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<PhotoLightbox> createState() => _PhotoLightboxState();
}

class _PhotoLightboxState extends State<PhotoLightbox> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<String, Uint8List> _bytesCache = {};
  final Map<String, ImageProvider> _providerCache = {};
  final Set<String> _loadingIds = {};

  int _rotationQuarterTurns = 0;
  bool _isBrightnessBoosted = false;
  bool _showMetadata = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.attachments.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _loadImageForIndex(_currentIndex);
  }

  Attachment get _currentAttachment => widget.attachments[_currentIndex];

  Future<void> _loadImageForIndex(int idx) async {
    if (idx < 0 || idx >= widget.attachments.length) return;
    final att = widget.attachments[idx];

    if (_providerCache.containsKey(att.id) || _loadingIds.contains(att.id)) return;

    setState(() => _loadingIds.add(att.id));

    // 1. In-Memory Raw Bytes
    if (att.bytes != null && att.bytes!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _bytesCache[att.id] = att.bytes!;
          _providerCache[att.id] = MemoryImage(att.bytes!);
          _loadingIds.remove(att.id);
        });
      }
      return;
    }

    // 2. Direct Local File Path
    if (att.localFilePath != null) {
      final file = File(att.localFilePath!);
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          if (mounted) {
            setState(() {
              _bytesCache[att.id] = bytes;
              _providerCache[att.id] = FileImage(file);
              _loadingIds.remove(att.id);
            });
          }
          return;
        } catch (_) {}
      }
    }

    // 3. Scan Permanent Local Documents Directory
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final localCandidate1 = File('${docDir.path}/attachments/${att.id}.jpg');
      if (await localCandidate1.exists()) {
        final bytes = await localCandidate1.readAsBytes();
        if (mounted) {
          setState(() {
            _bytesCache[att.id] = bytes;
            _providerCache[att.id] = FileImage(localCandidate1);
            _loadingIds.remove(att.id);
          });
        }
        return;
      }

      if (att.name != null) {
        final localCandidate2 = File('${docDir.path}/attachments/${att.name}');
        if (await localCandidate2.exists()) {
          final bytes = await localCandidate2.readAsBytes();
          if (mounted) {
            setState(() {
              _bytesCache[att.id] = bytes;
              _providerCache[att.id] = FileImage(localCandidate2);
              _loadingIds.remove(att.id);
            });
          }
          return;
        }
      }
    } catch (_) {}

    // 4. Remote Cloud URL Resolution & Proactive Fetch
    final url = _resolveImageUrl(att);
    if (url != null) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final bytes = response.bodyBytes;
          _bytesCache[att.id] = bytes;

          // Cache permanently
          try {
            final docDir = await getApplicationDocumentsDirectory();
            final attachmentsDir = Directory('${docDir.path}/attachments');
            if (!attachmentsDir.existsSync()) {
              await attachmentsDir.create(recursive: true);
            }
            final saveFile = File('${attachmentsDir.path}/${att.id}.jpg');
            await saveFile.writeAsBytes(bytes);
          } catch (_) {}

          if (mounted) {
            setState(() {
              _providerCache[att.id] = MemoryImage(bytes);
              _loadingIds.remove(att.id);
            });
          }
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _loadingIds.remove(att.id));
    }
  }

  String? _resolveImageUrl(Attachment att) {
    if (att.downloadUrl != null && att.downloadUrl!.isNotEmpty) {
      return att.downloadUrl;
    }
    if (att.storagePath != null && att.storagePath!.isNotEmpty) {
      try {
        return SupabaseService.client.storage
            .from('attachments')
            .getPublicUrl(att.storagePath!);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _handleSharePhoto() async {
    AppHaptics.light();
    final att = _currentAttachment;
    final bytes = _bytesCache[att.id] ?? att.bytes;

    try {
      if (att.localFilePath != null && File(att.localFilePath!).existsSync()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(att.localFilePath!)],
            text: 'Photo logged: ${att.name ?? "Inspection photo"}',
          ),
        );
        return;
      }

      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final shareFile = File('${tempDir.path}/share_${att.id}.jpg');
        await shareFile.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(shareFile.path)],
            text: 'Photo logged: ${att.name ?? "Inspection photo"}',
          ),
        );
        return;
      }

      final url = _resolveImageUrl(att);
      if (url != null) {
        await SharePlus.instance.share(
          ShareParams(text: url, subject: att.name ?? 'Inspection photo'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share photo: $e')),
        );
      }
    }
  }

  void _rotatePhoto() {
    AppHaptics.light();
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _toggleBrightness() {
    AppHaptics.medium();
    setState(() {
      _isBrightnessBoosted = !_isBrightnessBoosted;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final att = _currentAttachment;
    final totalPhotos = widget.attachments.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Photo Viewer PageView
          PageView.builder(
            controller: _pageController,
            itemCount: totalPhotos,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
                _rotationQuarterTurns = 0;
              });
              _loadImageForIndex(idx);
            },
            itemBuilder: (context, index) {
              final itemAtt = widget.attachments[index];
              final provider = _providerCache[itemAtt.id];
              final isLoading = _loadingIds.contains(itemAtt.id);

              if (isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGlow),
                );
              }

              if (provider == null) {
                return _buildMissingBucketGuidance(itemAtt);
              }

              Widget imageWidget = PhotoView(
                imageProvider: provider,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 3.5,
                initialScale: PhotoViewComputedScale.contained,
                heroAttributes: PhotoViewHeroAttributes(tag: itemAtt.id),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGlow),
                ),
                errorBuilder: (context, error, stackTrace) =>
                    _buildMissingBucketGuidance(itemAtt),
              );

              // Apply Brightness & Exposure Boost
              if (_isBrightnessBoosted) {
                imageWidget = ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    1.4, 0, 0, 0, 30, // Red
                    0, 1.4, 0, 0, 30, // Green
                    0, 0, 1.4, 0, 30, // Blue
                    0, 0, 0, 1, 0,    // Alpha
                  ]),
                  child: imageWidget,
                );
              }

              // Apply 90-degree Rotation
              if (_rotationQuarterTurns != 0) {
                imageWidget = RotatedBox(
                  quarterTurns: _rotationQuarterTurns,
                  child: imageWidget,
                );
              }

              return imageWidget;
            },
          ),

          // Top Premium Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            att.name ?? 'Inspection Photo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_currentIndex + 1} of $totalPhotos • ${AppFormatters.formatTimeHHmm(att.createdAt)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showMetadata ? Icons.info_rounded : Icons.info_outline_rounded,
                        color: _showMetadata ? AppColors.primaryGlow : Colors.white,
                        size: 22,
                      ),
                      onPressed: () {
                        AppHaptics.light();
                        setState(() => _showMetadata = !_showMetadata);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                      onPressed: _handleSharePhoto,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Premium Media Controls Toolbar
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xCC13151F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Rotate 90°
                    _buildMediaActionButton(
                      icon: Icons.rotate_90_degrees_cw_rounded,
                      label: 'Rotate',
                      isActive: _rotationQuarterTurns != 0,
                      onTap: _rotatePhoto,
                    ),

                    // Brightness / Warehouse Night Booster
                    _buildMediaActionButton(
                      icon: _isBrightnessBoosted ? Icons.wb_sunny_rounded : Icons.wb_sunny_outlined,
                      label: _isBrightnessBoosted ? 'Boost: ON' : 'Exposure',
                      isActive: _isBrightnessBoosted,
                      activeColor: Colors.amber,
                      onTap: _toggleBrightness,
                    ),

                    // Reset Transformations
                    if (_rotationQuarterTurns != 0 || _isBrightnessBoosted)
                      _buildMediaActionButton(
                        icon: Icons.restore_rounded,
                        label: 'Reset',
                        onTap: () {
                          AppHaptics.light();
                          setState(() {
                            _rotationQuarterTurns = 0;
                            _isBrightnessBoosted = false;
                          });
                        },
                      ),

                    // Share
                    _buildMediaActionButton(
                      icon: Icons.ios_share_rounded,
                      label: 'Share',
                      onTap: _handleSharePhoto,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Photo Metadata Inspector Card (Toggleable)
          if (_showMetadata)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xEE1E2330),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.perm_media_rounded, size: 14, color: AppColors.primaryGlow),
                        SizedBox(width: 6),
                        Text(
                          'ATTACHMENT METADATA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGlow,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow('File Name', att.name ?? 'Unnamed'),
                    _buildMetaRow('Logged At', DateTime.fromMillisecondsSinceEpoch(att.createdAt).toLocal().toString()),
                    _buildMetaRow('Local Cache', att.localFilePath != null ? 'Permanent on device' : 'In-memory / Cloud'),
                    _buildMetaRow('MIME Type', att.mime),
                    if (_bytesCache[att.id] != null)
                      _buildMetaRow('File Size', '${(_bytesCache[att.id]!.lengthInBytes / 1024).toStringAsFixed(1)} KB'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final color = isActive ? (activeColor ?? AppColors.primaryGlow) : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingBucketGuidance(Attachment att) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.warning),
              const SizedBox(height: 12),
              const Text(
                'Media Not in Local Cache',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This photo was saved prior to v2.0.49 and the remote Supabase project does not have the public "attachments" storage bucket enabled.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('https://supabase.com/dashboard/project/glxxawxuwusxwjvezugo/storage/buckets');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
                label: const Text('Open Supabase Storage Page', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
