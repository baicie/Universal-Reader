import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AiSettings {
  const AiSettings({
    this.enabled = false,
    this.endpoint = '',
    this.apiKey = '',
    this.model = '',
  });

  final bool enabled;
  final String endpoint;
  final String apiKey;
  final String model;

  bool get ready =>
      enabled && endpoint.trim().isNotEmpty && model.trim().isNotEmpty;

  AiSettings copyWith({
    bool? enabled,
    String? endpoint,
    String? apiKey,
    String? model,
  }) {
    return AiSettings(
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'endpoint': endpoint,
    'apiKey': apiKey,
    'model': model,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      enabled: json['enabled'] == true,
      endpoint: json['endpoint'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
    );
  }
}

abstract interface class AiSettingsRepository {
  Future<AiSettings> load();
  Future<void> save(AiSettings settings);
}

class SharedPreferencesAiSettingsRepository implements AiSettingsRepository {
  SharedPreferencesAiSettingsRepository(this.preferences);

  static const storageKey = 'universal_reader.ai.v1';
  final SharedPreferences preferences;

  @override
  Future<AiSettings> load() async {
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const AiSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const AiSettings();
      return AiSettings.fromJson(decoded);
    } on FormatException {
      return const AiSettings();
    } on TypeError {
      return const AiSettings();
    }
  }

  @override
  Future<void> save(AiSettings settings) async {
    await preferences.setString(storageKey, jsonEncode(settings.toJson()));
  }
}

class InMemoryAiSettingsRepository implements AiSettingsRepository {
  InMemoryAiSettingsRepository([this._settings = const AiSettings()]);

  AiSettings _settings;

  @override
  Future<AiSettings> load() async => _settings;

  @override
  Future<void> save(AiSettings settings) async {
    _settings = settings;
  }
}
