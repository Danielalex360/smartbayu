class SmartBayu {
  // ====== FACE VERIFICATION (on-device) ======
  static const faceModelPath = 'assets/models/mobilefacenet.tflite';
  static const faceEmbeddingSize = 192;
  static const faceMatchThreshold = 0.65; // cosine similarity

  // ====== GEOFENCE ======
  static const resortLat = 2.428795;
  static const resortLng = 103.983596;
  static const geofenceMeters = 3000;

  // ====== TEMP SELFIE PATH ======
  static const tempSelfiePath = 'tempSelfies';
}
