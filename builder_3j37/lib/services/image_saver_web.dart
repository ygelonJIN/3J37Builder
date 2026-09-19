import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> saveImageToGallery(Uint8List bytes, String name) async {
  try {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '$name.png')
      ..click();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (e) {
    return false;
  }
}
