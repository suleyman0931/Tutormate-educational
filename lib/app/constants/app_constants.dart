/// App-wide constants for TutorMate.
class AppConstants {
  AppConstants._();

  /// App display name.
  static const String appName = 'TutorMate';

  /// Database file name.
  static const String databaseName = 'tutormate.db';

  /// Subdirectory inside app documents for PDF files.
  static const String pdfsDir = 'pdfs';

  /// Subdirectory inside app documents for cover images.
  static const String coversDir = 'covers';

  /// Subdirectory inside app documents for backup archives.
  static const String backupsDir = 'backups';

  /// Backup archive file extension.
  static const String backupExtension = '.tutormate';

  /// Minimum supported grade.
  static const int minGrade = 1;

  /// Maximum supported grade.
  static const int maxGrade = 5;

  /// Default subjects seeded into the database on first creation.
  static const List<String> defaultSubjects = [
    'Mathematics',
    'English',
    'Amharic',
    'Afaan Oromo',
    'Science',
    'Social Studies',
    'Civics',
    'Other',
  ];

  /// Reading progress save interval (milliseconds).
  static const int progressSaveIntervalMs = 30000; // 30 seconds

  /// Max PDF file size in bytes we attempt to hash fully (50 MB).
  /// Larger files are hashed using head + tail chunks only.
  static const int maxFullHashSize = 50 * 1024 * 1024;

  /// Supported grades as a list.
  static List<int> get grades =>
      List.generate(maxGrade - minGrade + 1, (i) => minGrade + i);
}

/// Shared keys for SharedPreferences and settings storage.
class PrefKeys {
  PrefKeys._();

  static const String themeMode = 'theme_mode'; // 0=light, 1=dark, 2=system
  static const String defaultZoom = 'default_zoom';
  static const String readingMode = 'reading_mode'; // 0=continuous, 1=single
  static const String showPageNumbers = 'show_page_numbers';
  static const String distractionFree = 'distraction_free';
  static const String geminiApiKey = 'gemini_api_key';
  static const String geminiModel = 'gemini_model';
  static const String geminiKeyInitialized = 'gemini_key_initialized';
  static const String pinEnabled = 'pin_enabled';
  static const String pinHash = 'pin_hash';
  static const String pinSalt = 'pin_salt';
  static const String biometricEnabled = 'biometric_enabled';
  static const String autoLockMinutes = 'auto_lock_minutes';
  static const String lastActiveTimestamp = 'last_active_timestamp';
}
