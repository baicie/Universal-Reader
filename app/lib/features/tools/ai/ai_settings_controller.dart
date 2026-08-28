import 'package:flutter/foundation.dart';

import 'ai_settings.dart';

class AiSettingsController extends ChangeNotifier {
  AiSettingsController({required this.repository});

  final AiSettingsRepository repository;
  AiSettings settings = const AiSettings();
  bool loading = true;

  Future<void> load() async {
    settings = await repository.load();
    loading = false;
    notifyListeners();
  }

  Future<void> update(AiSettings next) async {
    settings = next;
    notifyListeners();
    await repository.save(next);
  }
}
