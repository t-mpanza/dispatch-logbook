import 'package:image_picker/image_picker.dart';
import '../../core/utils/id_generator.dart';
import '../models/attachment.dart';

class CameraService {
  static final ImagePicker _picker = ImagePicker();

  static Future<Attachment?> capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo == null) return null;

      final bytes = await photo.readAsBytes();
      final id = IdGenerator.generate();
      final name = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      return Attachment(
        id: id,
        kind: AttachmentKind.photo,
        bytes: bytes,
        mime: 'image/jpeg',
        name: name,
        localFilePath: photo.path,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<Attachment?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return null;

      final bytes = await image.readAsBytes();
      final id = IdGenerator.generate();
      final name = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      return Attachment(
        id: id,
        kind: AttachmentKind.image,
        bytes: bytes,
        mime: 'image/jpeg',
        name: name,
        localFilePath: image.path,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      return null;
    }
  }
}
