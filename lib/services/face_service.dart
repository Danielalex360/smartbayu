// Conditional import: native on mobile, stub on web
export 'face_verification_service_stub.dart'
    if (dart.library.io) 'face_verification_service.dart';
