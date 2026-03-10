import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static const String _folderName = "docsafe_images";

  /// Saves and compresses an image to the app's documents directory.
  ///
  /// - Compresses the image to JPEG at 70% quality.
  /// - Resizes the image so the longest edge is max 1500 pixels (maintaining aspect ratio).
  /// - Saves the compressed image with a UUID filename and .jpg extension.
  /// - Returns the path to the saved compressed image.
  Future<String> saveAndCompressImage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw Exception("Source file does not exist: $sourcePath");
    }

    // Read the image file
    final imageBytes = await sourceFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception("Failed to decode image: $sourcePath");
    }

    // Resize the image
    final resizedImage = img.copyResize(
      image,
      width: image.width > image.height ? 1500 : null,
      height: image.height > image.width ? 1500 : null,
    );

    // Compress the image to JPEG at 70% quality
    final compressedImageBytes = img.encodeJpg(resizedImage, quality: 70);

    // Get the app's documents directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDocDir.path}/$_folderName');

    // Create the "docsafe_images" subfolder if it doesn't exist
    if (!imageDir.existsSync()) {
      await imageDir.create(recursive: true);
    }

    // Generate a UUID filename
    final uuid = Uuid().v4();
    final savedImagePath = '${imageDir.path}/$uuid.jpg';

    // Save the compressed image
    final savedImageFile = File(savedImagePath);
    await savedImageFile.writeAsBytes(compressedImageBytes);

    return savedImagePath;
  }

  /// Deletes the image file at the given path if it exists.
  Future<void> deleteImage(String imagePath) async {
    final file = File(imagePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Returns a File object for the given path.
  File getImageFile(String imagePath) {
    return File(imagePath);
  }
}
