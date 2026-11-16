import 'package:hive_flutter/hive_flutter.dart';

/// One cached value together with the moment it was fetched.
typedef CacheEntry = ({Object? data, DateTime fetchedAt});

/// Local storage for the whole app, built on Hive (a fast key-value store
/// that keeps its data in files on the device).
///
/// Two "boxes" (Hive's word for a table):
///
///   cache          copies of server data for offline viewing, one entry
///                  per kind of data: employee, attendance, leave_balances,
///                  leave_requests. Each entry is {fetched_at, data}.
///
///   outbox_events  attendance events waiting to reach the server. The key
///                  is an auto-incrementing number (the event's `seq`),
///                  which fixes the order events are sent in.
///
/// Values are plain maps and lists (the same shape as the API's JSON), so
/// no generated TypeAdapters or build step are needed.
class AppDatabase {
  AppDatabase._(this._cache, this.outbox);

  final Box<dynamic> _cache;

  /// The outbox box. Only OutboxLocalDataSource touches it.
  final Box<dynamic> outbox;

  static const _cacheBox = 'cache';
  static const _outboxBox = 'outbox_events';

  // Keys inside the cache box.
  static const employeeKey = 'employee';
  static const attendanceKey = 'attendance';
  static const leaveBalancesKey = 'leave_balances';
  static const leaveRequestsKey = 'leave_requests';

  /// Bumped when the stored shape changes. See [_migrate].
  static const _schemaVersion = 1;
  static const _schemaVersionKey = '__schema_version';

  /// Opens (or creates) the boxes.
  ///
  /// [directory] exists for tests, which pass a temporary folder. The app
  /// passes nothing and Hive uses the app's private documents folder.
  static Future<AppDatabase> open({String? directory}) async {
    if (directory == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(directory);
    }
    final cache = await Hive.openBox<dynamic>(_cacheBox);
    final outbox = await Hive.openBox<dynamic>(_outboxBox);
    final database = AppDatabase._(cache, outbox);
    await database._migrate();
    return database;
  }

  /// Hive has no built-in migrations, so the version is stored as a normal
  /// entry and upgrades are applied here, one version at a time.
  Future<void> _migrate() async {
    final stored = _cache.get(_schemaVersionKey) as int? ?? _schemaVersion;
    for (var version = stored + 1; version <= _schemaVersion; version++) {
      // case 2: rewrite entries into the new shape.
    }
    await _cache.put(_schemaVersionKey, _schemaVersion);
  }

  Future<void> close() async {
    await _cache.close();
    await outbox.close();
  }

  // ---- cache --------------------------------------------------------------

  /// Saves one kind of cached data with its timestamp.
  ///
  /// The data and the timestamp are ONE Hive entry, written in one step, so
  /// a crash can never leave new data with an old timestamp (or the other
  /// way round). This replaces what a transaction did in SQL.
  Future<void> writeCache(String key, Object? data, DateTime fetchedAt) {
    return _cache.put(key, {
      'fetched_at': fetchedAt.toUtc().toIso8601String(),
      'data': data,
    });
  }

  /// Null means "never fetched" — which is different from "fetched, and the
  /// list was empty" (that returns an entry whose data is an empty list).
  CacheEntry? readCache(String key) {
    final entry = _cache.get(key);
    if (entry is! Map) return null;
    return (
      data: entry['data'],
      fetchedAt: DateTime.parse(entry['fetched_at'] as String),
    );
  }

  /// Deletes every cached value and every outbox event (Developer Settings).
  Future<void> clearAll() async {
    await _cache.clear();
    await outbox.clear();
    await _cache.put(_schemaVersionKey, _schemaVersion);
  }

  /// Hive returns maps as `Map<dynamic, dynamic>`; the models want
  /// `Map<String, Object?>`. Converts one stored map.
  static Map<String, Object?> row(Object? value) =>
      Map<String, Object?>.from(value as Map);

  /// Converts a stored list of maps.
  static List<Map<String, Object?>> rows(Object? value) =>
      [for (final item in (value as List? ?? const [])) row(item)];
}
