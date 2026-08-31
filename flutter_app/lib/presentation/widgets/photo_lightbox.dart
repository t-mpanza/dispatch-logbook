import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../data/models/attachment.dart';

class PhotoLightbox extends StatelessWidget {
  final Attachment attachment;

  const PhotoLightbox({super.key, required this.attachment});

  static void show(BuildContext context, Attachment attachment) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        pageBuilder: (context, _, _) => PhotoLightbox(attachment: attachment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (attachment.bytes != null) {
      imageProvider = MemoryImage(attachment.bytes!);
    } else if (attachment.downloadUrl != null) {
      imageProvider = NetworkImage(attachment.downloadUrl!);
    } else {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Image not available', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          attachment.name ?? 'Photo Preview',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      body: PhotoView(
        imageProvider: imageProvider,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3.0,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
