import '../../analysis/domain/statistics.dart';
import '../../core/time_format.dart';

/// Theme selection.
enum ThemeChoice { system, light, dark }

/// Language selection; `system` follows the device.
enum LanguageChoice { system, en, de }

/// All global user settings with their defaults.
class AppSettings {
  const AppSettings({
    this.theme = ThemeChoice.system,
    this.language = LanguageChoice.system,
    this.defaultUnit = TimeUnit.hm,
    this.defaultMethod = CycleTimeMethod.median,
    this.vibration = true,
    this.hardwareKeys = true,
    this.holdThresholdMs = 400,
    this.keepScreenOn = true,
    this.notifications = true,
    this.staleDays = 10,
  });

  final ThemeChoice theme;
  final LanguageChoice language;
  final TimeUnit defaultUnit;
  final CycleTimeMethod defaultMethod;
  final bool vibration;
  final bool hardwareKeys;

  /// How long volume up must be held to start a special time.
  final int holdThresholdMs;
  final bool keepScreenOn;
  final bool notifications;

  /// Opening a study whose last measurement is older than this many days
  /// offers a new measurement (revision); 0 = never ask.
  final int staleDays;

  /// Choices for [staleDays] in the settings.
  static const staleDayChoices = [0, 3, 7, 10, 14, 30, 60, 90, 180, 365];

  static const minHoldMs = 250;
  static const maxHoldMs = 1000;

  AppSettings copyWith({
    ThemeChoice? theme,
    LanguageChoice? language,
    TimeUnit? defaultUnit,
    CycleTimeMethod? defaultMethod,
    bool? vibration,
    bool? hardwareKeys,
    int? holdThresholdMs,
    bool? keepScreenOn,
    bool? notifications,
    int? staleDays,
  }) => AppSettings(
    theme: theme ?? this.theme,
    language: language ?? this.language,
    defaultUnit: defaultUnit ?? this.defaultUnit,
    defaultMethod: defaultMethod ?? this.defaultMethod,
    vibration: vibration ?? this.vibration,
    hardwareKeys: hardwareKeys ?? this.hardwareKeys,
    holdThresholdMs: holdThresholdMs ?? this.holdThresholdMs,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    notifications: notifications ?? this.notifications,
    staleDays: staleDays ?? this.staleDays,
  );

  Map<String, String> toMap() => {
    'theme': theme.name,
    'language': language.name,
    'defaultUnit': defaultUnit.name,
    'defaultMethod': defaultMethod.name,
    'vibration': '$vibration',
    'hardwareKeys': '$hardwareKeys',
    'holdThresholdMs': '$holdThresholdMs',
    'keepScreenOn': '$keepScreenOn',
    'notifications': '$notifications',
    'staleDays': '$staleDays',
  };

  /// Reads stored values; unknown or missing keys fall back to defaults.
  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    T pick<T extends Enum>(List<T> values, String? v, T fallback) =>
        values.where((e) => e.name == v).firstOrNull ?? fallback;
    bool flag(String key, bool fallback) =>
        m[key] == null ? fallback : m[key] == 'true';
    final hold = int.tryParse(m['holdThresholdMs'] ?? '') ?? d.holdThresholdMs;
    return AppSettings(
      theme: pick(ThemeChoice.values, m['theme'], d.theme),
      language: pick(LanguageChoice.values, m['language'], d.language),
      defaultUnit: pick(TimeUnit.values, m['defaultUnit'], d.defaultUnit),
      defaultMethod: pick(
        CycleTimeMethod.values,
        m['defaultMethod'],
        d.defaultMethod,
      ),
      vibration: flag('vibration', d.vibration),
      hardwareKeys: flag('hardwareKeys', d.hardwareKeys),
      holdThresholdMs: hold.clamp(minHoldMs, maxHoldMs),
      keepScreenOn: flag('keepScreenOn', d.keepScreenOn),
      notifications: flag('notifications', d.notifications),
      staleDays: (int.tryParse(m['staleDays'] ?? '') ?? d.staleDays).clamp(
        0,
        3650,
      ),
    );
  }
}
