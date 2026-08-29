import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'library_controller.dart';
import 'library_repository.dart';
import 'locale_controller.dart';
import 'reader_prefs.dart';
import 'seed_documents.dart';
import '../features/tools/ai/ai_runtime.dart';
import '../features/tools/ai/ai_settings.dart';
import '../features/tools/ai/ai_settings_controller.dart';
import '../features/tools/ai/conversation_store.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  throw StateError('Library repository must be overridden at startup');
});

final libraryProvider = ChangeNotifierProvider<PersistedLibraryController>((
  ref,
) {
  final controller = PersistedLibraryController(
    repository: ref.watch(libraryRepositoryProvider),
    initialDocuments: seedDocuments,
  );
  controller.load();
  return controller;
});

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  throw StateError('AI settings repository must be overridden at startup');
});

final aiSettingsProvider = ChangeNotifierProvider<AiSettingsController>((ref) {
  final controller = AiSettingsController(
    repository: ref.watch(aiSettingsRepositoryProvider),
  );
  controller.load();
  return controller;
});

final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final localeProvider = ChangeNotifierProvider<LocaleController>((ref) {
  return LocaleController();
});

final readerPrefsProvider = ChangeNotifierProvider<ReaderPrefsController>((
  ref,
) {
  return ReaderPrefsController();
});

final aiRuntimeProvider = Provider<AiRuntime>((ref) {
  return AiRuntime.local(InMemoryConversationRepository());
});
