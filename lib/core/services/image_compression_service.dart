import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Compress images before upload (Batch 10).
class ImageCompressionService {
  /// Max edge length and JPEG quality.
  Future<File> compressForUpload(
    String path, {
    int maxSide = 1600,
    int quality = 82,
  }) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return File(path);

    img.Image out = decoded;
    final maxDim = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (maxDim > maxSide) {
      if (decoded.width >= decoded.height) {
        out = img.copyResize(decoded, width: maxSide);
      } else {
        out = img.copyResize(decoded, height: maxSide);
      }
    }

    final jpg = img.encodeJpg(out, quality: quality);
    final dir = await getTemporaryDirectory();
    // Use a UUID, not a millisecond timestamp: compressing several images in
    // a fast loop (multi-image post) or two posts submitted close together
    // could hit the same millisecond, so two compressions would collide on
    // the same temp path and one image's bytes would silently overwrite the
    // other's before upload — attaching the wrong photo to a post.
    final outPath = p.join(
      dir.path,
      'kx_${const Uuid().v4()}.jpg',
    );
    final file = File(outPath);
    await file.writeAsBytes(Uint8List.fromList(jpg));
    return file;
  }
}
