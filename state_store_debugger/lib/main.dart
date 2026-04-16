import 'package:flutter/material.dart';
import 'package:state_store/state_store.dart';
import 'package:state_store_rc/json_viewer.dart';

import 'socket_server.dart';

Future<void> main() async {
  StateStore.setUp<bool>('view_mode_folded', false, true);

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
          leading: StateStoreBuilder<bool>(
            id: 'view_mode_folded',
            builder: (ctx, state) => IconButton(
              icon: Icon(state ? Icons.code : Icons.format_list_bulleted),
              onPressed: () {
                StateStore.dispatchToggle<bool>('view_mode_folded');
              },
            ),
          ),
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

  /// The current actual state as is
  Map<String, dynamic> state = <String, dynamic>{};

  /// The same as state but all keys in state are parsed for '.' and
  /// then grouped by these new subkeys. E.x. 'a.b.c' becomes
  /// a
  ///  b
  ///   c
  Map<String, dynamic> foldedState = <String, dynamic>{};

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
        child: StateStoreBuilder<bool>(
          id: 'view_mode_folded',
          builder: (context, folded) => folded
              ? JsonViewer(
                  foldedState,
                  onSelected: _onSelected,
                )
              : JsonViewer(
                  state,
                  onSelected: _onSelected,
                ),
        ),
      ),
    );
  }

  void _onDispatch(Map<String, dynamic> state) {
    setState(() {
      this.state = state;
      foldedState = _fold(state);
    });
  }

  void _onSelected(String? key, value) {
    print("Selected $key: $value");
  }

  Map<String, dynamic> _fold(Map<String, dynamic> state) {
    Map<String, dynamic> result = <String, dynamic>{};
    for (var key in state.keys) {
      var value = state[key];
      _ensureAndInsertTarget(result, key, value);
    }
    return result;
  }

  void _ensureAndInsertTarget(
      Map<String, dynamic> target, String key, dynamic value) {
    var parts = key.split('.');
    var current = target;
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i];
      if (i == parts.length - 1) {
        current[part] = value;
      } else {
        if (current[part] == null) {
          current[part] = <String, dynamic>{};
        }
        current = current[part];
      }
    }
  }
}
