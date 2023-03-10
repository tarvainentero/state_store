import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const port = 4567;

enum ConnectionState {
  settingUp,
  listening,
  connected,
  disconnected,
}

typedef OnDispatch = void Function(Map<String, dynamic> state);

class SocketServer {
  OnDispatch? _onDispatch;
  ServerSocket? server;
  SocketServer();

  Future<void> start(OnDispatch listener) async {
    _onDispatch = listener;
    try {
      print("Starting server on port $port");
      server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      print("Server started on port $port. Listening for connections...");
      server?.listen((socket) {
        _handleConnection(socket);
      });
    } catch (e) {
      print(e);
    }
  }

  void dispose() {
    print("Closing server on port $port");
    server?.close();
  }

  void _handleConnection(Socket socket) {
    print('Connection from'
        ' ${socket.remoteAddress.address}:${socket.remotePort}');

    // listen for events from the client
    socket.listen(
      // handle data from the client
      (Uint8List data) async {
        _handleData(socket, data);
      },

      // handle errors
      onError: (error) {
        print(error);
        socket.close();
      },

      // handle the client closing the connection
      onDone: () {
        print('Client left');
        _onDispatch?.call(<String, dynamic>{});
        socket.close();
      },
    );
  }

  void _handleData(Socket socket, Uint8List data) {
    String message = String.fromCharCodes(data);
    print("Got data: $message");
    try {
      Map<String, dynamic> json = jsonDecode(message);
      _onDispatch?.call(json);
    } catch (e) {
      print("Invalid message format: bypassing");
      return;
    }
  }
}
