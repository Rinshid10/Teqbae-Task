/// Every user-facing string lives here, so wording can be reviewed (or later
/// localised) in one place. Strings with values in them are functions.
/// Pure Dart (no Flutter import), so the domain layer may use it too.
abstract final class AppStrings {
  static const appName = 'REBS HRMS';
  static const brandShort = 'REBS';
  static const appVersion = 'v1.0.0';

  // ---- Navigation ---------------------------------------------------------
  static const tabHome = 'Home';
  static const tabAttendance = 'Attendance';
  static const tabLeave = 'Leave';

  // ---- Generic ------------------------------------------------------------
  static const retry = 'Try again';
  static const cancel = 'Cancel';
  static const close = 'Close';
  static const gotIt = 'Got it';
  static const seeAll = 'See all';
  static const emptyTitle = 'Nothing here yet';
  static const errorTitle = 'Something went wrong';
  static const noValue = '—';
  static const online = 'Online';
  static const offline = 'Offline';
  static const daysWord = 'days';
  static const office = 'Office';

  static const offlineTitle = 'Working offline';
  static String offlineBanner(String time) =>
      'Showing saved data · last updated $time';
  static const offlineBannerNoTime =
      'Could not reach the server. Check-ins are saved on this device.';
  static const serverUnreachable = 'Server unreachable';
  static const nothingWaiting = 'Nothing waiting';

  // ---- Network errors -----------------------------------------------------
  static const noConnection = 'No internet connection.';
  static const timeout = 'The server took too long to respond.';
  static const cacheError = 'Could not read saved data.';
  static const unexpectedResponse = 'The server sent an unexpected response.';
  static String requestFailed(int status) => 'Request failed ($status).';

  // ---- Form fields --------------------------------------------------------
  static const selectDate = 'Select';

  // ---- Splash -------------------------------------------------------------
  static const splashBadge = 'Offline ready';
  static const splashProduct = 'Workspace';
  static const splashLoading = 'Loading your workspace…';
  static const splashHint =
      'Attendance is saved on this device and synced when you are online.';

  // ---- Home ---------------------------------------------------------------
  static const goodMorning = 'Good morning';
  static const goodAfternoon = 'Good afternoon';
  static const goodEvening = 'Good evening';
  static const profileNotLoaded = 'Profile will load when you are online';
  static const hoursWorkedToday = 'Hours worked today';
  static const totalWorkedToday = 'Total worked today';
  static const checkInLabel = 'Check-in';
  static const checkOutLabel = 'Check-out';
  static const leaveOverline = 'Leave';
  static const recentAttendance = 'Recent attendance';
  static const noAttendanceYet = 'No attendance yet';
  static const noAttendanceMonth = 'No attendance this month';
  static const noAttendanceMessage = 'Your check-ins will appear here.';
  static const allSynced = 'All synced';
  static String pendingShort(int count) => '$count pending';
  static const justNow = 'Just now';
  static const notSyncedYet = 'Not synced yet';
  static String lastSyncedAt(String time) => 'Last synced $time';
  static String atTheOffice(int metres) =>
      "You're at the office · $metres m away";

  // ---- Attendance ---------------------------------------------------------
  static const statusNotCheckedIn = 'Not Checked In';
  static const statusCheckedIn = 'Checked In';
  static const statusCheckedOut = 'Checked Out';
  static const checkIn = 'Check In';
  static const checkOut = 'Check Out';
  static const doneForToday = 'You are done for today.';
  static const inProgressDuration = 'In progress';
  static const noCheckOut = 'No check-out';
  static const storedLocally = 'Stored locally';
  static const notAccepted = 'Not accepted';
  static String netDuration(String duration) => '$duration net';
  static const previousMonth = 'Previous month';
  static const nextMonth = 'Next month';
  static const summaryPresent = 'Present';
  static const summaryAverage = 'Avg Daily';
  static const summaryPending = 'Pending';
  static String logWord(int count) => count == 1 ? 'log' : 'logs';
  static String weekLabel(int week) => 'Week $week';
  static String weekSummary(int days, String worked) =>
      '$days ${days == 1 ? 'day' : 'days'} • $worked';

  static const attendanceInProgress = 'Still working on your last tap.';
  static const alreadyCheckedIn = 'You have already checked in today.';
  static const dayAlreadyComplete =
      'You have already checked in and out today.';
  static const checkInRequired = 'Check in first, then you can check out.';
  static const alreadyCheckedOut = 'You have already checked out today.';
  static const checkOutBeforeCheckIn =
      'Check-out cannot be earlier than check-in. Check your device clock.';
  static const duplicateEvent = 'This was already recorded for today.';
  static String outsideGeofence({
    required int distanceMeters,
    required int radiusMeters,
    required bool isCheckIn,
  }) =>
      "You're $distanceMeters m from the office. "
      '${isCheckIn ? 'Check-in' : 'Check-out'} is allowed within '
      '$radiusMeters m.';

  // ---- Location check sheet -----------------------------------------------
  static const geofenceCheck = 'Geo-fence check';
  static const verifyingLocation = 'Verifying your location';
  static const locationVerified = 'Location verified';
  static const verifyingShort = 'Verifying…';
  static const gettingPosition = 'Getting your position…';
  static const gettingPositionHint = 'This usually takes a few seconds';
  static const deviceLocation = 'Device location';
  static const locating = 'Locating';
  static const zoneOk = 'Zone OK';
  static const gpsLocked = 'GPS locked';
  static const confirmCheckIn = 'Confirm Check In';
  static const confirmCheckOut = 'Confirm Check Out';
  static String youAreFromOffice(int metres) =>
      "You're $metres m from the office";
  static String insideRadius(int radius) =>
      'Inside the allowed $radius m radius';
  static String youMarker(int metres) => 'You · $metres m';
  static String perimeter(int radius) => '$radius m perimeter';
  static String accuracy(int metres) => '±$metres m accuracy';
  static String metres(int value) => '$value m';
  static String zone(int radius) => '$radius m zone';

  static const outOfRange = 'Out of Range';
  static const outsideTitle = "You're outside the office area";
  static const pillLocationOff = 'Location Off';
  static const pillPermission = 'Permission Needed';
  static const pillBlocked = 'Permission Blocked';
  static const pillNoGps = 'No GPS Fix';
  static const pillNotAllowed = 'Not Allowed';
  static const locationOffTitle = 'Location is turned off';
  static const locationDeniedTitle = 'Location permission needed';
  static const locationBlockedTitle = 'Location permission is blocked';
  static const locationUnavailableTitle = "Couldn't find your location";
  static const notAllowedTitle = "This can't be recorded";

  static const locationServiceOff =
      'Turn on location so we can confirm you are at the office.';
  static const locationDenied =
      'Location permission is needed to confirm you are at the office.';
  static const locationDeniedForever =
      'Location permission is blocked. Allow it in the app settings.';
  static const locationTimeout =
      'Could not get your location in time. Try again near a window.';
  static const locationUnavailable =
      'Your location is unavailable right now.';
  static const actionTurnOnLocation = 'Turn on location';
  static const actionAllowLocation = 'Allow location';
  static const actionOpenAppSettings = 'Open app settings';

  // ---- Check-in confirmation ----------------------------------------------
  static String checkedInAt(String time) => 'Checked in at $time';
  static String checkedOutAt(String time) => 'Checked out at $time';
  static const successCheckInSubtitle = 'Have a productive day.';
  static const successCheckOutSubtitle = 'Thanks for today. See you soon.';
  static String distanceFromOffice(int metres, int? accuracy) =>
      accuracy == null
          ? '$metres m from the office'
          : '$metres m from the office · ±$accuracy m';
  static const successSyncedTitle = 'Saved to the server';
  static const successSyncedBody = 'Your attendance record is up to date.';
  static const successPendingTitle = 'Saved on this device';
  static const successPendingBody =
      'It will be sent to the server automatically when a connection is '
      'available.';
  static const backToHome = 'Back to Home';

  // ---- Sync ---------------------------------------------------------------
  static const pendingSync = 'Pending Sync';
  static const synced = 'Synced';
  static const rejected = 'Rejected';
  static const syncNow = 'Sync Now';
  static const syncing = 'Syncing…';
  static String syncNowCount(int count) =>
      'Sync Now ($count ${count == 1 ? 'Change' : 'Changes'})';
  static String pendingEvents(int count) => count == 1
      ? '1 event waiting to sync'
      : '$count events waiting to sync';
  static const syncAllDone = 'Everything is synced';
  static const syncFailedTitle = "Couldn't sync yet";
  static String syncFailedBody(String reason) =>
      '$reason Your check-ins are safe on this device and will be sent '
      'automatically.';
  static const syncSomeRejected = 'Some events were rejected';
  static const checkInWasRejected = 'Check-in was rejected';
  static const noReasonGiven = 'The server gave no reason.';

  static const syncCenter = 'Sync Center';
  static const savedOnDevice = 'Saved on this device';
  static const autoSyncHint = 'Syncs automatically when the network reconnects';
  static const queueTitle = 'Queue (in order)';
  static const queueOrder = 'Oldest first';
  static const queueEmpty = 'Nothing waiting';
  static const queueEmptyMessage = 'New check-ins appear here until they sync.';
  static const queueWaiting = 'Waiting for its turn';
  static String queueRetrying(int attempts, String? error) {
    final tries = 'Tried $attempts ${attempts == 1 ? 'time' : 'times'}';
    return (error == null || error.isEmpty) ? tries : '$tries · $error';
  }

  static String eventId(String shortId) => 'ID #$shortId';
  static const historyTitleSection = 'Recent sync history';
  static const historyEmpty = 'No synced events yet';
  static String historyTitle(String day, String type) => '$day $type';
  static String historySynced(String time) => 'Recorded at $time';
  static const historyRejected = 'Not accepted by the server';

  // ---- Rejected event sheet -----------------------------------------------
  static const eventDetails = 'Event details';
  static const checkInNotAccepted = 'Check-in not accepted';
  static const checkOutNotAccepted = 'Check-out not accepted';
  static const rejectedIntro =
      'The server could not add this to your attendance record.';
  static const declined = 'Declined';
  static const rejectedTitle = 'Why it was rejected';
  static const recordsSafeTitle = 'Your other records are safe';
  static const recordsSafeBody =
      'Nothing else was changed. Records already on the server are kept '
      'as they are.';

  // ---- Leave --------------------------------------------------------------
  static const applyForLeave = 'Apply for Leave';
  static const applyLeave = 'Apply Leave';
  static const myRequests = 'My requests';
  static const filterAll = 'All';
  static const daysLeft = 'days left';
  static const totalAllocated = 'Total allocated';
  static const noLeaveRequests = 'No requests here';
  static const noLeaveRequestsMessage = 'Requests you send will appear here.';
  static const leaveBalanceStrip = 'Leave balance';
  static String leaveTotalDays(int days) =>
      '$days ${days == 1 ? 'day' : 'days'} in total';
  static const leaveTypeLabel = 'Select leave type';
  static const leaveCasual = 'Casual';
  static const leaveSick = 'Sick';
  static String leaveTypeFull(String type) => '$type Leave';
  static const durationLabel = 'Duration';
  static const leaveStartLabel = 'Start Date';
  static const leaveEndLabel = 'End Date';
  static const leaveReasonLabel = 'Reason for absence';
  static const leaveReasonPlaceholder = 'Why do you need this leave?';
  static const leaveReasonHint = 'Minimum 10 characters';
  static const reviewRequest = 'Review Request';
  static const overlapTitle = 'Dates overlap a request';
  static String daysAvailable(int days) =>
      '$days ${days == 1 ? 'day' : 'days'} available';
  static String daysRequested(int days) =>
      '$days ${days == 1 ? 'day' : 'days'} requested';
  static String deductedFrom(String type) => 'Taken from your $type balance';
  static String deductedFromWithRemaining(String type, int remaining) =>
      remaining < 0
          ? 'More than your $type balance allows'
          : 'Taken from your $type balance ($remaining remaining)';

  static const stepTwoOfTwo = 'Step 2 of 2';
  static const reviewTitle = 'Review your request';
  static const reviewIntro =
      'Please make sure the details are right before sending.';
  static const leaveCategory = 'Leave category';
  static const requestedDates = 'Requested dates';
  static const balanceAfter = 'Balance after this request';
  static const reasonForAbsence = 'Reason for absence';
  static String daysRemaining(int days) =>
      '$days ${days == 1 ? 'day' : 'days'} remaining';
  static String availableNow(int days) => '($days available now)';
  static const submitRequest = 'Submit Request';
  static const editDetails = 'Edit Details';
  static const leaveSent = 'Leave request sent';
  static const leaveStatusPending = 'Pending';
  static const leaveStatusApproved = 'Approved';
  static const leaveStatusRejected = 'Rejected';
  static String leaveDays(int days) => days == 1 ? '1 day' : '$days days';

  static const offlineSheetTitle = "You're offline";
  static const leaveNotSentTitle = "Couldn't send your request";
  static const leaveOfflineBody =
      'Leave requests need a connection. Connect to the network and try '
      'again.';
  static const leaveOffline =
      "You're offline. Leave requests need a connection.";
  static const leaveStartRequired = 'Choose a start date.';
  static const leaveStartInPast = 'Start date cannot be in the past.';
  static const leaveEndRequired = 'Choose an end date.';
  static const leaveEndBeforeStart =
      'End date cannot be before the start date.';
  static const leaveReasonTooShort =
      'Reason must have at least 10 characters.';
  static const leaveOverlap =
      'These dates overlap one of your existing requests.';
  static String leaveInsufficientBalance(int requested, int available) =>
      'You requested $requested days but only $available are available.';

  // ---- Developer settings (reviewers) -------------------------------------
  static const devTitle = 'Developer Settings';
  static const devSandbox = 'Developer Sandbox';
  static const devDebugOnly = 'Debug only';
  static const devNoticeTitle = 'For reviewers';
  static const devNoticeBody =
      'These switches change where the app thinks you are and how the mock '
      'server answers.';
  static const devSimulateLocation = 'Simulate location';
  static String devActive(String mode) => 'Active: $mode';
  static const devRealGps = 'Real GPS';
  static const devInside = 'Inside office';
  static const devInsideHint = 'About 30 m from the office';
  static const devOutside = 'Outside office';
  static const devOutsideHint = 'About 840 m away';
  static const devDenied = 'Permission denied';
  static const devDeniedForever = 'Permanently denied';
  static const devUnavailable = 'GPS unavailable';
  static const devMockScenario = 'Mock API scenario';
  static const devServerConnected = 'Connected';
  static const devServerUnreachable = 'Server unreachable';
  static const devScenarioSuccess = 'Normal success';
  static const devScenarioSlow = 'Slow network (4 s)';
  static const devScenarioTimeout = 'Network timeout';
  static const devScenarioTimeoutAfterCommit = 'Timeout after save';
  static const devScenarioServerError = 'Server 500 error';
  static const devScenarioDuplicate = 'Duplicate attendance';
  static const devScenarioLeaveValidation = 'Leave validation error';
  static const devOfficeParameters = 'Office parameters';
  static const devLocked = 'Read-only';
  static const devCoordinates = 'Coordinates';
  static const devRadius = 'Radius limit';
  static const devTimezone = 'Timezone';
  static const devServer = 'Server';
  static String geofenceRadius(int metres) => '$metres m geofence';
  static const devReset = 'Reset mock data & local database';
  static const devResetHint =
      'Clears saved data and unsent check-ins on this device, and clears '
      "the mock server's data.";
  static const devResetDone = 'Everything was reset';
  static const devResetLocalOnly =
      'Local data cleared. The server could not be reached.';
}
