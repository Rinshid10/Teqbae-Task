/// What the employee did.
enum AttendanceEventType {
  checkIn('CHECK_IN'),
  checkOut('CHECK_OUT');

  const AttendanceEventType(this.wire);

  /// The value stored locally and sent to the server.
  final String wire;

  static AttendanceEventType fromWire(String value) =>
      values.firstWhere((t) => t.wire == value);
}

/// Where an outbox event is on its way to the server.
enum SyncStatus {
  /// Saved locally, not yet accepted by the server.
  pending('PENDING'),

  /// Being sent right now. If the app dies here the event is simply picked
  /// up again on the next run — safe because the server deduplicates.
  syncing('SYNCING'),

  /// The server has it.
  synced('SYNCED'),

  /// The server refused it for a business reason. Never retried.
  rejected('REJECTED');

  const SyncStatus(this.wire);
  final String wire;

  static SyncStatus fromWire(String value) =>
      values.firstWhere((s) => s.wire == value);

  /// Still waiting to be delivered.
  bool get isUnsent => this == pending || this == syncing;
}

/// One check-in or check-out, queued in the `outbox_events` table.
class OutboxEvent {
  const OutboxEvent({
    required this.seq,
    required this.eventId,
    required this.type,
    required this.occurredAt,
    required this.workDate,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.status,
    required this.attempts,
    required this.lastError,
    required this.serverRecordId,
    required this.createdAt,
  });

  /// Local, ever-increasing number. Events are sent strictly in this order.
  final int seq;

  /// UUID v4 created on the device. It is the idempotency key: however many
  /// times this event is sent, the server stores it once.
  final String eventId;
  final AttendanceEventType type;

  /// When the user tapped, in UTC.
  final DateTime occurredAt;

  /// Company working day (yyyy-MM-dd) the event belongs to.
  final String workDate;
  final double lat;
  final double lng;
  final double? accuracy;
  final SyncStatus status;

  /// How many sends have failed for a temporary reason.
  final int attempts;

  /// Last temporary error, or the rejection reason when REJECTED.
  final String? lastError;
  final String? serverRecordId;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is OutboxEvent &&
      other.seq == seq &&
      other.eventId == eventId &&
      other.type == type &&
      other.occurredAt == occurredAt &&
      other.workDate == workDate &&
      other.lat == lat &&
      other.lng == lng &&
      other.accuracy == accuracy &&
      other.status == status &&
      other.attempts == attempts &&
      other.lastError == lastError &&
      other.serverRecordId == serverRecordId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(seq, eventId, type, occurredAt, workDate,
      lat, lng, accuracy, status, attempts, lastError, serverRecordId, createdAt);

  @override
  String toString() => 'OutboxEvent(#$seq ${type.wire} $workDate ${status.wire})';
}
