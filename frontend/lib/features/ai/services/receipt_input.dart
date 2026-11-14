import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:project_one/core/network/backend_client.dart';

class ReceiptImage {
  const ReceiptImage({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;
}

abstract interface class ReceiptInput {
  Future<ReceiptImage?> pick();
}

class FileReceiptInput implements ReceiptInput {
  @override
  Future<ReceiptImage?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Ảnh hóa đơn',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          uniformTypeIdentifiers: [
            'public.jpeg',
            'public.png',
            'org.webmproject.webp',
          ],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 8 * 1024 * 1024) {
      throw const FinanceApiException('Ảnh tối đa 8 MB. Hãy chọn ảnh nhỏ hơn.');
    }
    final bytes = await file.readAsBytes();
    String? mime;
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      mime = 'image/jpeg';
    } else if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG') {
      mime = 'image/png';
    } else if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      mime = 'image/webp';
    }
    if (mime == null || bytes.length > 8 * 1024 * 1024) {
      throw const FinanceApiException(
        'Hãy chọn ảnh JPEG, PNG hoặc WebP tối đa 8 MB.',
      );
    }
    return ReceiptImage(bytes: bytes, mimeType: mime);
  }
}
