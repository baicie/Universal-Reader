const persistenceSchemaVersion = 1;

class UnsupportedPersistenceVersionException implements Exception {
  const UnsupportedPersistenceVersionException({
    required this.store,
    required this.version,
    required this.supportedVersion,
  });

  final String store;
  final int version;
  final int supportedVersion;

  @override
  String toString() =>
      'Unsupported $store persistence version $version; '
      'this build supports up to $supportedVersion.';
}

class DecodedPersistedPayload {
  const DecodedPersistedPayload({
    required this.schemaVersion,
    required this.payload,
    required this.migrated,
  });

  final int schemaVersion;
  final Object? payload;
  final bool migrated;
}

Map<String, Object?> encodePersistedPayload({
  required int schemaVersion,
  required Object? payload,
}) {
  return {'schema_version': schemaVersion, 'payload': payload};
}

DecodedPersistedPayload decodePersistedPayload(
  Object? decoded, {
  required String store,
  int currentVersion = persistenceSchemaVersion,
  Map<int, Object? Function(Object?)> migrations = const {},
}) {
  if (decoded is Map && decoded.containsKey('schema_version')) {
    final rawVersion = decoded['schema_version'];
    if (rawVersion is! int || rawVersion < 1) {
      throw FormatException('Invalid $store schema version.');
    }
    if (rawVersion > currentVersion) {
      throw UnsupportedPersistenceVersionException(
        store: store,
        version: rawVersion,
        supportedVersion: currentVersion,
      );
    }
    final payload = decoded['payload'];
    return _migrate(
      store: store,
      version: rawVersion,
      payload: payload,
      currentVersion: currentVersion,
      migrations: migrations,
    );
  }

  return _migrate(
    store: store,
    version: 1,
    payload: decoded,
    currentVersion: currentVersion,
    migrations: migrations,
  );
}

DecodedPersistedPayload _migrate({
  required String store,
  required int version,
  required Object? payload,
  required int currentVersion,
  required Map<int, Object? Function(Object?)> migrations,
}) {
  var current = version;
  var value = payload;
  while (current < currentVersion) {
    final migration = migrations[current];
    if (migration == null) {
      throw UnsupportedPersistenceVersionException(
        store: store,
        version: version,
        supportedVersion: currentVersion,
      );
    }
    value = migration(value);
    current++;
  }
  return DecodedPersistedPayload(
    schemaVersion: current,
    payload: value,
    migrated: current != version,
  );
}
