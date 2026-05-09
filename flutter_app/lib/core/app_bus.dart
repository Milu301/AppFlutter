import 'dart:async';

abstract class AppEvent {}

class UnauthorizedEvent extends AppEvent {}

class BlockingAuthEvent extends AppEvent {
  final String code; // SUBSCRIPTION_EXPIRED | DEVICE_MISMATCH
  final String message;
  BlockingAuthEvent({required this.code, required this.message});
}

class AppBus {
  static final StreamController<AppEvent> _controller = StreamController<AppEvent>.broadcast();

  static Stream<AppEvent> get stream => _controller.stream;

  static void emit(AppEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  static void dispose() {
    _controller.close();
  }
}
