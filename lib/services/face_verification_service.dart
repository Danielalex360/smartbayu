import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/constants.dart';

class FaceVerificationService {
  FaceVerificationService._();
  static final instance = FaceVerificationService._();

  Interpreter? _interpreter;
  bool _ready = false;

  bool get isReady => _ready;

  /// Call once at app start or before first use.
  Future<void> init() async {
    if (_ready) return;
    try {
      _interpreter = await Interpreter.fromAsset(SmartBayu.faceModelPath);
      _ready = true;
    } catch (e) {
      _ready = false;
      rethrow;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _ready = false;
  }

  /// Detect exactly one face in [file], crop it, and return a 192-dim embedding.
  /// Returns null if no face / multiple faces detected.
  /// Throws if model not loaded.
  Future<FaceResult?> generateEmbedding(File file) async {
    if (!_ready || _interpreter == null) {
      throw StateError('FaceVerificationService not initialised. Call init() first.');
    }

    // 1) Detect face with ML Kit
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
      ),
    );

    try {
      final inputImage = InputImage.fromFile(file);
      final faces = await detector.processImage(inputImage);

      if (faces.isEmpty) return FaceResult.error('No face detected.');
      if (faces.length > 1) return FaceResult.error('Multiple faces detected. Only 1 allowed.');

      final face = faces.first;

      // 2) Read and decode image
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return FaceResult.error('Cannot decode image.');

      // 3) Crop face region with padding
      final rect = face.boundingBox;
      final padX = (rect.width * 0.25).toInt();
      final padY = (rect.height * 0.25).toInt();
      final x = (rect.left.toInt() - padX).clamp(0, decoded.width - 1);
      final y = (rect.top.toInt() - padY).clamp(0, decoded.height - 1);
      final w = (rect.width.toInt() + padX * 2).clamp(1, decoded.width - x);
      final h = (rect.height.toInt() + padY * 2).clamp(1, decoded.height - y);

      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

      // 4) Resize to 112x112 (MobileFaceNet input)
      final resized = img.copyResize(cropped, width: 112, height: 112);

      // 5) Normalise to [-1, 1] and create input tensor
      final input = Float32List(1 * 112 * 112 * 3);
      int idx = 0;
      for (int row = 0; row < 112; row++) {
        for (int col = 0; col < 112; col++) {
          final pixel = resized.getPixel(col, row);
          input[idx++] = (pixel.r.toDouble() - 127.5) / 127.5;
          input[idx++] = (pixel.g.toDouble() - 127.5) / 127.5;
          input[idx++] = (pixel.b.toDouble() - 127.5) / 127.5;
        }
      }

      final inputTensor = input.reshape([1, 112, 112, 3]);

      // 6) Run inference
      final output = List.filled(1 * SmartBayu.faceEmbeddingSize, 0.0)
          .reshape([1, SmartBayu.faceEmbeddingSize]);
      _interpreter!.run(inputTensor, output);

      final embedding = List<double>.from(output[0] as List);
      return FaceResult.success(embedding);
    } finally {
      await detector.close();
    }
  }

  /// Cosine similarity between two embeddings. Returns 0..1.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    if (denom == 0) return 0;
    return dot / denom;
  }

  /// Returns true if similarity >= threshold.
  static bool isMatch(List<double> a, List<double> b,
      {double threshold = SmartBayu.faceMatchThreshold}) {
    return cosineSimilarity(a, b) >= threshold;
  }
}

class FaceResult {
  final List<double>? embedding;
  final String? errorMessage;
  bool get ok => embedding != null;

  FaceResult.success(this.embedding) : errorMessage = null;
  FaceResult.error(this.errorMessage) : embedding = null;
}
