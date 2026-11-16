import '../../../../core/utils/clock.dart';
import '../entities/leave.dart';
import '../repositories/leave_repository.dart';
import '../validators/leave_validator.dart';

/// Runs the local leave rules without sending anything. The form calls it
/// when the user taps "Review Request", so mistakes are shown on the form
/// rather than after the review step.
class ValidateLeaveRequest {
  const ValidateLeaveRequest({
    required LeaveRepository repository,
    required Clock clock,
    LeaveValidator validator = const LeaveValidator(),
  })  : _repository = repository,
        _clock = clock,
        _validator = validator;

  final LeaveRepository _repository;
  final Clock _clock;
  final LeaveValidator _validator;

  /// Every broken rule; an empty list means the draft is valid.
  Future<List<LeaveIssue>> call(LeaveDraft draft) async {
    // refresh: false = use what is saved, no waiting on the network.
    final balances = await _repository.getBalances(refresh: false);
    final requests = await _repository.getRequests(refresh: false);
    return _validator.validate(
      draft: draft,
      today: _clock.today(),
      balances: balances.fold((c) => c.value, (_) => const []),
      existing: requests.fold((c) => c.value, (_) => const []),
    );
  }
}
