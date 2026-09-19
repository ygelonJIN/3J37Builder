import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';

Future<bool> saveImageToGallery(Uint8List bytes, String name) async {
  final result = await ImageGallerySaver.saveImage(bytes, quality: 100, name: name);
  return result != null && (result['isSuccess'] == true || result['success'] == true);
}
