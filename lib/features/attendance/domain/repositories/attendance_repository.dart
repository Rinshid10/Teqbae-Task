import '../../../../core/utils/cached.dart';
import '../../../../core/utils/result.dart';
import '../entities/attendance_record.dart';

abstract class AttendanceRepository {
  /// Server attendance records. See `cachedFetch` for what [refresh] means.
  Future<Result<Cached<List<AttendanceRecord>>>> getRecords({bool refresh = true});

  /// Local-only read of the cached records; null if never fetched. Used to
  /// re-render after an outbox change without touching the network.
  Future<Cached<List<AttendanceRecord>>?> cachedRecords();

  /// Local-only lookup of one day's server record. Never hits the network.
  Future<AttendanceRecord?> cachedRecordFor(String workDate);
}
