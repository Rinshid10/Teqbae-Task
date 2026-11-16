import 'package:hive/hive.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/exceptions.dart';
import '../models/outbox_event_model.dart';

/// Reads and writes the outbox box in Hive.
///
/// Each event is one entry. Its key is the number Hive assigns with
/// `box.add` (0, 1, 2, ...), which never repeats and always grows — that
/// key is the event's `seq`, the order events are sent in.
///
/// Hive has no unique indexes, so the two rules a SQL index would enforce
/// are checked here, in [insert], before anything is written.
class OutboxLocalDataSource {
  const OutboxLocalDataSource(this._database);

  final AppDatabase _database;

  Box<dynamic> get _box => _database.outbox;

  static const _pending = 'PENDING';
  static const _syncing = 'SYNCING';
  static const _rejected = 'REJECTED';

  /// PENDING plus SYNCING. An event left in SYNCING by a crash mid-request
  /// is therefore retried automatically on the next run.
  static bool _isUnsent(Map<String, Object?> row) =>
      row['status'] == _pending || row['status'] == _syncing;

  /// Every stored event with its key added as `seq`, oldest first.
  /// (Hive keeps integer keys in ascending order.)
  List<Map<String, Object?>> _rows() => [
        for (final key in _box.keys)
          {...AppDatabase.row(_box.get(key)), 'seq': key as int},
      ];

  /// Stores a new event and returns it (now carrying its seq).
  ///
  /// Throws [DuplicateOutboxEventException] when there is already
  ///   - an event with the same event_id, or
  ///   - a live (not REJECTED) event of the same type for the same day.
  ///
  /// The second rule is the last line of defence against duplicate
  /// attendance: even if two taps slipped past the UI lock and the domain
  /// check, only one event is stored. Rejected events are excluded so the
  /// user can try again after one.
  ///
  /// Why this check cannot race with itself: Dart runs this code on one
  /// thread, and there is no `await` between the check and `_box.add`.
  /// Hive updates its in-memory copy at once inside `add` (only the disk
  /// write is awaited), so a second insert always sees the first.
  Future<OutboxEventModel> insert(OutboxEventModel event) async {
    final row = event.toDb();
    final clash = _rows().any((existing) =>
        existing['event_id'] == row['event_id'] ||
        (existing['work_date'] == row['work_date'] &&
            existing['type'] == row['type'] &&
            existing['status'] != _rejected));
    if (clash) throw const DuplicateOutboxEventException();

    try {
      final seq = await _box.add(row);
      return OutboxEventModel.fromDb({...row, 'seq': seq});
    } catch (error) {
      throw CacheException(error.toString());
    }
  }

  Future<List<OutboxEventModel>> readAll() async =>
      _rows().map(OutboxEventModel.fromDb).toList();

  Future<List<OutboxEventModel>> readForWorkDate(String workDate) async => [
        for (final row in _rows())
          if (row['work_date'] == workDate) OutboxEventModel.fromDb(row),
      ];

  /// The unsent event with the lowest seq, or null when none is waiting.
  Future<OutboxEventModel?> readNextUnsent() async {
    final row = _rows().where(_isUnsent).firstOrNull;
    return row == null ? null : OutboxEventModel.fromDb(row);
  }

  Future<int> countUnsent() async => _rows().where(_isUnsent).length;

  /// Changes some fields of one event. Read-merge-write is safe for the
  /// same reason as [insert]: nothing else runs between the read and the
  /// in-memory update.
  Future<void> update(int seq, Map<String, Object?> values) async {
    final current = _box.get(seq);
    if (current == null) return;
    await _box.put(seq, {...AppDatabase.row(current), ...values});
  }

  /// A temporary failure: back to PENDING, attempts + 1, error remembered.
  Future<void> recordFailedAttempt(int seq, String error) async {
    final current = _box.get(seq);
    if (current == null) return;
    final row = AppDatabase.row(current);
    await _box.put(seq, {
      ...row,
      'status': _pending,
      'attempts': (row['attempts'] as int? ?? 0) + 1,
      'last_error': error,
    });
  }

  /// Rejects the unsent CHECK_OUT(s) of one working day.
  Future<void> rejectUnsentCheckOut(String workDate, String reason) async {
    final changes = <int, Map<String, Object?>>{};
    for (final row in _rows()) {
      if (row['work_date'] == workDate &&
          row['type'] == 'CHECK_OUT' &&
          _isUnsent(row)) {
        final seq = row['seq'] as int;
        changes[seq] = {
          ...row,
          'status': _rejected,
          'last_error': reason,
        }..remove('seq'); // seq is the key, not part of the stored value
      }
    }
    // One write for all of them.
    if (changes.isNotEmpty) await _box.putAll(changes);
  }
}

/// A live event of this type already exists for the working day.
class DuplicateOutboxEventException implements Exception {
  const DuplicateOutboxEventException();
}
