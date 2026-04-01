// Web stub — face verification is not available on web platform.
// This file is conditionally imported on web builds.

import 'dart:math';

class FaceVerificationService {
  FaceVerificationService._();
  static final instance = FaceVerificationService._();

  bool get isReady => false;

  Future<void> init() async {
    // No-op on web
  }

  void dispose() {}

  Future<FaceResult?> generateEmbedding(dynamic file) async {
    return FaceResult.error('Face verification is not available on web. Use Android/iOS.');
  }

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

  static bool isMatch(List<double> a, List<double> b, {double threshold = 0.65}) {
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
