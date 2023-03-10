import 'dart:io';

import 'state_store.dart';

class SocketClient {
  final StateStore stateStore;
  SocketClient(this.stateStore);

  Socket? _socket;

  Future<void> connect() async {
    _socket ??= await Socket.connect('localhost', 4567);
    _socket?.listen((event) {
      print("GOT DATA IN DA ASS: $event");
    });
  }

  void updateFullState(String fullState) {
    _send(fullState);
  }

  void _send(String message) {
    _socket?.write(message);
  }

  void close() {
    _socket?.close();
  }
}
