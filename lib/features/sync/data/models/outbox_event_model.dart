import '../../domain/entities/outbox_event.dart';

class OutboxEventModel extends OutboxEvent {
  const OutboxEventModel({
    required super.seq,
    required super.eventId,
    required super.type,
    required super.occurredAt,
    required super.workDate,
    required super.lat,
    required super.lng,
    required super.accuracy,
    required super.status,
    required super.attempts,
    required super.lastError,
    required super.serverRecordId,
    required super.createdAt,
  });

  factory OutboxEventModel.fromEntity(OutboxEvent e) => e is OutboxEventModel
      ? e
      : OutboxEventModel(
          seq: e.seq,
          eventId: e.eventId,
          type: e.type,
          occurredAt: e.occurredAt,
          workDate: e.workDate,
          lat: e.lat,
          lng: e.lng,
          accuracy: e.accuracy,
          status: e.status,
          attempts: e.attempts,
          lastError: e.lastError,
          serverRecordId: e.serverRecordId,
          createdAt: e.createdAt,
        );

  factory OutboxEventModel.fromDb(Map<String, Object?> row) => OutboxEventModel(
        seq: row['seq'] as int,
        eventId: row['event_id'] as String,
        type: AttendanceEventType.fromWire(row['type'] as String),
        occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
        workDate: row['work_date'] as String,
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
        accuracy: (row['accuracy'] as num?)?.toDouble(),
        status: SyncStatus.fromWire(row['status'] as String),
        attempts: row['attempts'] as int,
        lastError: row['last_error'] as String?,
        serverRecordId: row['server_record_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      );

  /// Row for INSERT. `seq` is left out so Hive assigns the next number (the box key).
  Map<String, Object?> toDb() => {
        'event_id': eventId,
        'type': type.wire,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'work_date': workDate,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'status': status.wire,
        'attempts': attempts,
        'last_error': lastError,
        'server_record_id': serverRecordId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  /// Body of POST /attendance/events. Only what the server needs — local
  /// bookkeeping (seq, status, attempts) stays on the device.
  Map<String, Object?> toJson() => {
        'event_id': eventId,
        'type': type.wire,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'work_date': workDate,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
      };
}
