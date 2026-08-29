import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'library_repository.dart';
import 'sqlite_library_repository.dart';

Future<LibraryRepository> openLocalLibrary(
  SharedPreferences preferences,
) async {
  final dir = await getApplicationSupportDirectory();
  final repository = await SqliteLibraryRepository.open(
    '${dir.path}/library.sqlite',
  );
  await repository.migrateFromPreferences(preferences);
  return repository;
}
