import 'package:shared_preferences/shared_preferences.dart';

import 'library_repository.dart';
import 'web_library_repository.dart';

Future<LibraryRepository> openLocalLibrary(
  SharedPreferences preferences,
) async {
  final repository = WebPersistentLibraryRepository(preferences);
  await repository.migrateFromPreferences(preferences);
  return repository;
}
