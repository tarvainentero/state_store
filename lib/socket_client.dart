import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef ToEncodable = Object? Function(Object? object);
const separator = "|||";

class SocketClient {
  final ToEncodable? toEncodable;
  SocketClient({this.toEncodable});
  Map<String, dynamic>? _stateToSend;
  Socket? _socket;
  Timer? _timer;

  Future<void> connect() async {
    _socket ??= await Socket.connect('localhost', 4567);

    // Note: State is updated only by timed interval.
    // This is to prevent sending too many updates.
    _timer ??= Timer.periodic(const Duration(seconds: 5), (timer) {
      _sendState();
    });
  }

  void updateFullState(Map<String, dynamic> state) {
    _stateToSend = state;
  }

  /// This is the actual state that we are going to send
  /// This has waited the throttling time and is ready to be sent
  void _sendState() {
    if (_stateToSend == null) return;

    Map<String, dynamic> data = _stateToSend!;
    _stateToSend = null;
    var map = <String, dynamic>{};
    for (var i in data.keys) {
      var val = data[i]!.value;
      bool persisted = data[i]!.persist;
      if (persisted) {
        map["$i [*]"] = val;
      } else {
        map[i] = val;
      }
    }
    _send(jsonEncode(map, toEncodable: toEncodable) + separator);
  }

  void _send(String message) {
    _socket?.write(message);
  }

  void close() {
    _socket?.close();
    _timer?.cancel();
  }
}
