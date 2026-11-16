import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/view_state.dart';
import '../../../../core/widgets/app_messenger.dart';
import '../../../sync/presentation/sync_service.dart';
import '../../domain/entities/leave.dart';
import '../../domain/usecases/get_leave_overview.dart';
import '../../domain/usecases/submit_leave_request.dart';
import '../../domain/usecases/validate_leave_request.dart';
import '../../domain/validators/leave_validator.dart';
import '../models/leave_ui.dart';

class LeaveScreenData {
  const LeaveScreenData({
    required this.balances,
    required this.filter,
    required this.counts,
    required this.requests,
    required this.offlineMessage,
  });

  final List<LeaveBalanceUi> balances;
  final LeaveFilter filter;

  /// How many requests each filter chip would show.
  final Map<LeaveFilter, int> counts;

  /// Already filtered by [filter].
  final List<LeaveRequestUi> requests;
  final String? offlineMessage;
}

/// What happened when the review step's Submit was tapped.
enum LeaveSubmitOutcome {
  /// Sent. Close the flow.
  sent,

  /// The server (or a last local check) rejected specific fields. Go back
  /// to the form, where the errors are now shown.
  fixForm,

  /// Could not send (offline, timeout, 5xx). Stay on the review step; the
  /// view shows `submitError` in a sheet.
  failed,
}

/// Drives the Leave tab, the request form and the review step.
class LeaveController extends GetxController {
  LeaveController({
    required GetLeaveOverview getOverview,
    required ValidateLeaveRequest validateRequest,
    required SubmitLeaveRequest submitRequest,
    required SyncService sync,
    required Clock clock,
    required AppFormat format,
    required LeaveUiMapper mapper,
  })  : _getOverview = getOverview,
        _validateRequest = validateRequest,
        _submitRequest = submitRequest,
        _sync = sync,
        _clock = clock,
        _format = format,
        _mapper = mapper;

  final GetLeaveOverview _getOverview;
  final ValidateLeaveRequest _validateRequest;
  final SubmitLeaveRequest _submitRequest;
  final SyncService _sync;
  final Clock _clock;
  final AppFormat _format;
  final LeaveUiMapper _mapper;

  static const maxReasonLength = 200;

  // ---- list ---------------------------------------------------------------

  final state = Rx<ViewState<LeaveScreenData>>(const ViewLoading());
  RxBool get isOnline => _sync.isOnline;

  /// True when a leave request cannot be sent right now: the device has no
  /// connection, or the last attempt to reach the server failed (Wi-Fi can
  /// be on while the server is unreachable).
  bool get isOffline => !_sync.isOnline.value || _offlineMessage != null;

  /// Asks the server again. Returns true when it answered, i.e. leave can
  /// be requested now.
  Future<bool> recheckConnection() async {
    await load(refresh: true);
    return !isOffline;
  }

  /// Why the last submit could not be sent, for the view to show in a
  /// sheet. [submitFailedOffline] picks the "You're offline" wording.
  String? submitError;
  bool submitFailedOffline = false;

  List<LeaveBalance> _balances = const [];
  List<LeaveRequest> _requests = const [];
  LeaveFilter _filter = LeaveFilter.all;
  String? _offlineMessage;
  bool _isStale = false;
  int _loadId = 0;

  // ---- form ---------------------------------------------------------------

  final type = LeaveType.casual.obs;
  final startDate = Rxn<DateTime>();
  final endDate = Rxn<DateTime>();
  final reasonController = TextEditingController();

  /// Inline errors, keyed by LeaveFields. Filled by local validation and by
  /// server 422 responses alike.
  final errors = <String, String>{}.obs;
  final isSubmitting = false.obs;

  /// "14 days in total" in the strip at the top of the form.
  final totalBalanceLabel = ''.obs;

  /// "6 days available" next to the type selector.
  final availableLabel = ''.obs;

  /// "3 days requested" once both dates are chosen; empty otherwise.
  final requestedLabel = ''.obs;

  /// "Taken from your Casual balance (3 remaining)".
  final deductionLabel = ''.obs;

  /// Set while the chosen dates clash with an existing request, so the
  /// user is warned before reaching the review step.
  final overlapWarning = RxnString();

  /// The review step's summary; set by [review].
  final reviewData = Rxn<LeaveReviewUi>();

  /// Date pickers start at the COMPANY's today, not the device's.
  DateTime get firstSelectableDate => _clock.today();
  DateTime get lastSelectableDate =>
      _clock.today().add(const Duration(days: 365));

  @override
  void onInit() {
    super.onInit();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    final wasStale = await load(refresh: false);
    if (wasStale) await load(refresh: true);
  }

  /// Returns whether the data shown is still stale.
  Future<bool> load({bool refresh = true}) async {
    final id = ++_loadId;
    final result = await _getOverview(refresh: refresh);
    if (id != _loadId) return false;

    switch (result) {
      case Success(:final value):
        _balances = value.value.balances;
        _requests = value.value.requests;
        _isStale = value.isStale;
        _offlineMessage = value.refreshError == null
            ? null
            : value.fetchedAt == null
                ? AppStrings.offlineBannerNoTime
                : AppStrings.offlineBanner(_format.time(value.fetchedAt));
        _show();
        _updateDerived();
        return value.isStale;

      case Fail(:final failure):
        // Keep showing what we have if there is anything on screen.
        if (state.value is ViewData<LeaveScreenData>) return false;

        if (failure is NetworkFailure || failure is TimeoutFailure) {
          // The server cannot be reached and nothing is saved yet. Open the
          // screen empty with the offline banner rather than an error: the
          // user can still fill in the form, and is told on submit that
          // sending needs a connection.
          _offlineMessage = AppStrings.offlineBannerNoTime;
          _isStale = true;
          _show();
          return false; // do not loop: the caller already tried the network
        }
        // The server answered with an error (e.g. 500): a real error state.
        state.value = ViewError(failure.message);
        return false;
    }
  }

  void setFilter(LeaveFilter filter) {
    _filter = filter;
    _show();
  }

  static bool _matches(LeaveRequest r, LeaveFilter filter) => switch (filter) {
        LeaveFilter.all => true,
        LeaveFilter.pending => r.status == LeaveStatus.pending,
        LeaveFilter.approved => r.status == LeaveStatus.approved,
        LeaveFilter.rejected => r.status == LeaveStatus.rejected,
      };

  void _show() {
    state.value = ViewData(
      LeaveScreenData(
        balances: _balances.map(_mapper.balance).toList(),
        filter: _filter,
        counts: {
          for (final f in LeaveFilter.values)
            f: _requests.where((r) => _matches(r, f)).length,
        },
        requests: [
          for (final r in _requests)
            if (_matches(r, _filter)) _mapper.request(r),
        ],
        offlineMessage: _offlineMessage,
      ),
      isStale: _isStale,
      isOffline: _offlineMessage != null,
    );
  }

  // ---- form input ---------------------------------------------------------

  void setType(LeaveType value) {
    type.value = value;
    errors.remove(LeaveFields.type);
    // A balance error depends on the type, so it no longer applies.
    errors.remove(LeaveFields.endDate);
    _updateDerived();
  }

  void setStartDate(DateTime value) {
    startDate.value = value;
    errors.remove(LeaveFields.startDate);
    _updateDerived();
  }

  void setEndDate(DateTime value) {
    endDate.value = value;
    errors.remove(LeaveFields.endDate);
    _updateDerived();
  }

  void onReasonChanged(String _) => errors.remove(LeaveFields.reason);

  LeaveDraft get _draft => LeaveDraft(
        type: type.value,
        startDate: startDate.value,
        endDate: endDate.value,
        reason: reasonController.text,
      );

  LeaveBalance? get _selectedBalance =>
      _balances.where((b) => b.type == type.value).firstOrNull;

  int? get _requestedDays {
    final start = startDate.value;
    final end = endDate.value;
    if (start == null || end == null || end.isBefore(start)) return null;
    return LeaveValidator.countDays(start, end);
  }

  /// Recomputes the helper texts that depend on the chosen type and dates.
  void _updateDerived() {
    final balance = _selectedBalance;
    final typeName = LeaveUiMapper.typeLabel(type.value);
    final days = _requestedDays;

    totalBalanceLabel.value = _balances.isEmpty
        ? ''
        : AppStrings.leaveTotalDays(
            _balances.fold<int>(0, (sum, b) => sum + b.available));
    availableLabel.value =
        balance == null ? '' : AppStrings.daysAvailable(balance.available);
    requestedLabel.value = days == null ? '' : AppStrings.daysRequested(days);
    deductionLabel.value = days == null
        ? ''
        : balance == null
            ? AppStrings.deductedFrom(typeName)
            : AppStrings.deductedFromWithRemaining(
                typeName, balance.available - days);

    // Overlap is the one rule worth flagging before "Review": the user
    // cannot know about it from the form alone.
    final start = startDate.value;
    final end = endDate.value;
    final clashes = start != null &&
        end != null &&
        !end.isBefore(start) &&
        _requests.any((r) =>
            r.blocksDates &&
            !start.isAfter(r.endDate) &&
            !end.isBefore(r.startDate));
    overlapWarning.value = clashes ? AppStrings.leaveOverlap : null;
  }

  /// "Review Request": validates locally. On success fills [reviewData] and
  /// returns true so the view can open the review step; otherwise the
  /// errors are shown under their fields.
  Future<bool> review() async {
    errors.clear();
    final draft = _draft;
    final issues = await _validateRequest(draft);
    if (issues.isNotEmpty) {
      final byField = <String, String>{};
      for (final issue in issues) {
        byField.putIfAbsent(issue.field, () => issue.message);
      }
      errors.assignAll(byField);
      return false;
    }

    final balance = _selectedBalance;
    final days = _requestedDays!;
    final remaining = balance == null ? null : balance.available - days;
    reviewData.value = LeaveReviewUi(
      type: draft.type,
      typeLabel: AppStrings.leaveTypeFull(LeaveUiMapper.typeLabel(draft.type)),
      dateRange: _mapper.dateRange(draft.startDate!, draft.endDate!),
      daysLabel: AppStrings.leaveDays(days),
      balanceAfterLabel:
          remaining == null ? null : AppStrings.daysRemaining(remaining),
      balanceNowLabel: balance == null
          ? null
          : AppStrings.availableNow(balance.available),
      remainingFraction: balance == null || balance.available <= 0
          ? 0
          : (remaining! / balance.available).clamp(0.0, 1.0),
      reason: draft.reason.trim(),
    );
    return true;
  }

  /// "Submit Request" on the review step.
  Future<LeaveSubmitOutcome> submit() async {
    if (isSubmitting.value) return LeaveSubmitOutcome.failed; // tap guard
    isSubmitting.value = true;
    errors.clear();

    try {
      final result = await _submitRequest(_draft);

      switch (result) {
        case Success():
          _resetForm();
          AppMessenger.show(AppStrings.leaveSent);
          // The repository already refreshed its caches after the POST.
          await load(refresh: false);
          return LeaveSubmitOutcome.sent;

        case Fail(failure: ValidationFailure(:final fieldErrors)):
          errors.assignAll(fieldErrors);
          return LeaveSubmitOutcome.fixForm;

        case Fail(failure: RejectedFailure(:final fieldErrors, :final message)):
          // Server 422: put each error under its field. Anything that does
          // not belong to a field on this form goes to a snackbar instead.
          final known = {
            for (final entry in fieldErrors.entries)
              if (_formFields.contains(entry.key)) entry.key: entry.value,
          };
          if (known.isEmpty) {
            submitError = message;
            submitFailedOffline = false;
            return LeaveSubmitOutcome.failed;
          }
          errors.assignAll(known);
          return LeaveSubmitOutcome.fixForm;

        case Fail(:final failure):
          // Offline, timeout, 5xx.
          submitError = failure.message;
          submitFailedOffline =
              failure is NetworkFailure || failure is TimeoutFailure;
          return LeaveSubmitOutcome.failed;
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  static const _formFields = {
    LeaveFields.type,
    LeaveFields.startDate,
    LeaveFields.endDate,
    LeaveFields.reason,
  };

  void _resetForm() {
    type.value = LeaveType.casual;
    startDate.value = null;
    endDate.value = null;
    reasonController.clear();
    errors.clear();
    reviewData.value = null;
    _updateDerived();
  }

  @override
  void onClose() {
    reasonController.dispose();
    super.onClose();
  }
}
