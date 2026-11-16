import '../utils/cached.dart';
import '../utils/clock.dart';
import '../utils/result.dart';
import 'error_mapper.dart';

/// The one caching policy every read repository uses.
///
///   refresh = true : ask the server. On success save to the cache and return
///                    fresh data. On failure fall back to the cache (marked
///                    stale, carrying the error); fail only if the cache is
///                    empty too.
///   refresh = false: return the cache straight away if there is one (for an
///                    instant first paint), otherwise behave like refresh.
Future<Result<Cached<T>>> cachedFetch<T>({
  required bool refresh,
  required Clock clock,
  required Future<T> Function() fetchRemote,
  required Future<void> Function(T value, DateTime fetchedAt) saveCache,
  required Future<Cached<T>?> Function() readCache,
}) async {
  Future<Cached<T>?> safeRead() async {
    try {
      return await readCache();
    } catch (_) {
      return null; // a broken cache is treated as an empty one
    }
  }

  if (!refresh) {
    final cached = await safeRead();
    if (cached != null) return Success(cached);
  }

  try {
    final value = await fetchRemote();
    final fetchedAt = clock.nowUtc();
    try {
      await saveCache(value, fetchedAt);
    } catch (_) {
      // Failing to cache must not hide data we did manage to fetch.
    }
    return Success(Cached(value, fetchedAt: fetchedAt));
  } catch (error) {
    final failure = toFailure(error);
    final cached = await safeRead();
    if (cached == null) return Fail(failure);
    return Success(Cached(
      cached.value,
      fetchedAt: cached.fetchedAt,
      isStale: true,
      refreshError: failure,
    ));
  }
}
