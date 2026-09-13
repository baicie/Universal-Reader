# Persistence compatibility

## Local envelope v1

Local SharedPreferences stores read a versioned envelope first and fall back to the previous unversioned value:

```json
{
  "schema_version": 1,
  "payload": []
}
```

The stores use a new `.v2` key while continuing to write the legacy `.v1` payload. This provides two guarantees:

- New builds can read and migrate legacy data.
- Older builds can still read the `.v1` payload after rollback.

The envelope applies to the library catalog, shelves, annotations, and conversations. Server JSON contracts are unchanged.

## SQLite

`SqliteLibraryRepository` uses SQLite `PRAGMA user_version` with schema value `1`. Existing databases start at version `0`, retain all rows, and are upgraded in place. A database from a newer unsupported schema is rejected and its connection is closed instead of being treated as empty or overwritten.

## Change policy

- Adding a field does not require a schema bump; readers already ignore unknown fields.
- A semantic change adds a migration from the previous version and a regression fixture.
- A future version is never downgraded or silently deleted.
- Rollback compatibility requires continuing to write the legacy payload while the schema is additive.

## Commands

```powershell
cd app
flutter test test/persistence_compatibility_test.dart test/sqlite_library_repository_test.dart
```
