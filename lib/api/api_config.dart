class ApiConfig {
  /// Server chính (Dev Tunnel) và server dự phòng (Vercel).
  static const primary = 'https://d81h6zk7-8000.asse.devtunnels.ms';
  static const fallback = 'https://he-thong-cua-thong-minh-hp-iots.vercel.app';

  static const timeout = Duration(seconds: 15);
  static const appVersion = '1.0.0';

  /// Khi server chính lỗi, dùng server dự phòng trong khoảng này rồi thử lại server chính.
  static const primaryRetryAfter = Duration(seconds: 30);
}
