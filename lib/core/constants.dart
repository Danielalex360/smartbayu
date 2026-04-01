class SmartBayu {
  // ====== SUPABASE (from --dart-define or fallback) ======
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ddpvuxiqxqjrzwharnha.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRkcHZ1eGlxeHFqcnp3aGFybmhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzMjQwMzYsImV4cCI6MjA4NDkwMDAzNn0.ymXkqKgXlB1RQSZKri7uVlx1a--3-mu_Wv4KYkgXTc4',
  );

  // ====== FACE VERIFICATION (on-device) ======
  static const faceModelPath = 'assets/models/mobilefacenet.tflite';
  static const faceEmbeddingSize = 192;
  static const faceMatchThreshold = 0.65; // cosine similarity

  // ====== GEOFENCE ======
  static const resortLat = 2.428795;
  static const resortLng = 103.983596;
  static const geofenceMeters = 3000;

  // ====== STORAGE BUCKET ======
  static const storageBucket = 'smartbayu';

  // ====== TEMP SELFIE PATH ======
  static const tempSelfiePath = 'tempSelfies';
}
