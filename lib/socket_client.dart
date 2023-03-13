import 'dart:convert';
import 'dart:io';

import 'state_store.dart';

typedef ToEncodable = Object? Function(Object? object);

class SocketClient {
  final StateStore stateStore;
  final ToEncodable? toEncodable;
  SocketClient(this.stateStore, {this.toEncodable});

  Socket? _socket;

  Future<void> connect() async {
    _socket ??= await Socket.connect('localhost', 4567);
  }

  void updateFullState(Map<String, dynamic> state) {
    var map = <String, dynamic>{};
    for (var i in state.keys) {
      var val = state[i]!.value;
      bool persisted = state[i]!.persist;
      if (persisted) {
        map["$i [*]"] = val;
      } else {
        map[i] = val;
      }
    }
    var fullState = jsonEncode(map, toEncodable: toEncodable);

    _send(fullState);
  }

  void _send(String message) {
    _socket?.write(message);
  }

  void close() {
    _socket?.close();
  }
}
