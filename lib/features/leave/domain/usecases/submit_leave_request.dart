import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/result.dart';
import '../entities/leave.dart';
import '../repositories/leave_repository.dart';
import '../validators/leave_validator.dart';

/// Validate locally, make sure we are online, then send.
class SubmitLeaveRequest {
  const SubmitLeaveRequest({
    required LeaveRepository repository,
    required NetworkInfo networkInfo,
    required Clock clock,
    LeaveValidator validator = const LeaveValidator(),
  })  : _repository = repository,
        _networkInfo = networkInfo,
        _clock = clock,
        _validator = validator;

  final LeaveRepository _repository;
  final NetworkInfo _networkInfo;
  final Clock _clock;
  final LeaveValidator _validator;

  Future<Result<LeaveRequest>> call(LeaveDraft draft) async {
    // Validate against what we have saved (refresh: false = no waiting on
    // the network). If nothing is saved the lists are empty and the server
    // remains the judge of balance and overlap.
    final balances = await _repository.getBalances(refresh: false);
    final requests = await _repository.getRequests(refresh: false);

    final issues = _validator.validate(
      draft: draft,
      today: _clock.today(),
      balances: balances.fold((c) => c.value, (_) => const []),
      existing: requests.fold((c) => c.value, (_) => const []),
    );
    if (issues.isNotEmpty) {
      // First message per field wins.
      final fieldErrors = <String, String>{};
      for (final issue in issues) {
        fieldErrors.putIfAbsent(issue.field, () => issue.message);
      }
      return Fail(ValidationFailure(
        issues.first.message,
        code: issues.first.code.name,
        fieldErrors: fieldErrors,
      ));
    }

    // Validation comes first so the user can fix the form offline, but the
    // request itself is never queued: an approval flow should not start
    // from a request the user may have forgotten they made.
    if (!await _networkInfo.isConnected) {
      return const Fail(NetworkFailure(AppStrings.leaveOffline));
    }

    final result = await _repository.submit(draft);
    return switch (result) {
      // The connection dropped between the check and the request.
      Fail(failure: NetworkFailure()) =>
        const Fail(NetworkFailure(AppStrings.leaveOffline)),
      _ => result,
    };
  }
}
