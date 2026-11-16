import '../entities/outbox_event.dart';
import '../repositories/outbox_repository.dart';

/// Every outbox event, oldest first, plus a stream that fires when the
/// outbox changes. The Sync Center screen is built from this.
class GetOutboxEvents {
  const GetOutboxEvents(this._outbox);

  final OutboxRepository _outbox;

  Future<List<OutboxEvent>> call() => _outbox.all();

  Stream<void> get changes => _outbox.changes;
}
