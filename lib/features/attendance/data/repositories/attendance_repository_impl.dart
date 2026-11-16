import '../../../../core/network/cached_fetch.dart';
import '../../../../core/utils/cached.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_local_data_source.dart';
import '../datasources/attendance_remote_data_source.dart';
import '../models/attendance_record_model.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  const AttendanceRepositoryImpl({
    required AttendanceRemoteDataSource remote,
    required AttendanceLocalDataSource local,
    required Clock clock,
  })  : _remote = remote,
        _local = local,
        _clock = clock;

  final AttendanceRemoteDataSource _remote;
  final AttendanceLocalDataSource _local;
  final Clock _clock;

  @override
  Future<Result<Cached<List<AttendanceRecord>>>> getRecords({
    bool refresh = true,
  }) {
    return cachedFetch<List<AttendanceRecord>>(
      refresh: refresh,
      clock: _clock,
      fetchRemote: _remote.fetchRecords,
      saveCache: (records, at) =>
          _local.replaceAll(records.cast<AttendanceRecordModel>(), at),
      readCache: _readCache,
    );
  }

  Future<Cached<List<AttendanceRecord>>?> _readCache() async {
    final fetchedAt = await _local.fetchedAt();
    if (fetchedAt == null) return null; // never fetched
    return Cached(await _local.readAll(), fetchedAt: fetchedAt, isStale: true);
  }

  @override
  Future<Cached<List<AttendanceRecord>>?> cachedRecords() async {
    try {
      return await _readCache();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AttendanceRecord?> cachedRecordFor(String workDate) async {
    try {
      return await _local.readForWorkDate(workDate);
    } catch (_) {
      return null;
    }
  }
}
