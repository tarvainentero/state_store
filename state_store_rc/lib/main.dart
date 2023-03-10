import 'package:flutter/material.dart';
import 'package:state_store_rc/json_viewer.dart';

import 'socket_server.dart';

Future<void> main() async {
  runApp(const TheApp());
}

class TheApp extends StatelessWidget {
  const TheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'State Store Debugger',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: const ThePage(),
    );
  }
}

class ThePage extends StatelessWidget {
  const ThePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('State Store Debugger'),
        ),
        body: const StateStoreDebugger());
  }
}

class StateStoreDebugger extends StatefulWidget {
  const StateStoreDebugger({Key? key}) : super(key: key);

  @override
  State<StateStoreDebugger> createState() => _StateStoreDebuggerState();
}

class _StateStoreDebuggerState extends State<StateStoreDebugger> {
  final SocketServer socketServer = SocketServer();
  Map<String, dynamic> state = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    socketServer.start(_onDispatch);
  }

  @override
  void dispose() {
    socketServer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: JsonViewer(
          state,
          onSelected: _onSelected,
        ),
      ),
    );
  }

  void _onDispatch(Map<String, dynamic> state) {
    setState(() {
      this.state = state;
    });
  }

  void _onSelected(String? key, value) {
    print("Selected $key: $value");
  }
}
