import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// On-device OCR via Google ML Kit Text Recognition v2 (Latin).
/// Fully offline — model di-bundle di apk (1-2 MB).
class OcrService {
  OcrService._();
  static final instance = OcrService._();

  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String?> pickAndRecognize({required ImageSource source}) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (file == null) return null;
    return recognizeFromPath(file.path);
  }

  Future<String> recognizeFromPath(String path) async {
    final input = InputImage.fromFile(File(path));
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
