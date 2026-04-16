import 'dart:io';

import 'package:flutter/material.dart';
import 'package:state_store/state_store.dart';
import 'package:state_store_debugger/json_viewer.dart';

import 'code_reference.dart';
import 'code_scanner.dart';
import 'setup_screen.dart';
import 'socket_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  StateStore.setUp<bool>('view_mode_folded', false, persist: true);
  StateStore.setUp<String>('project_path', '', persist: true);

  await StateStore.import();

  runApp(const TheApp());
}

class TheApp extends StatelessWidget {
  const TheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'State Store Debugger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  CodeScanner? _scanner;

  @override
  void initState() {
    super.initState();
    final savedPath = StateStore.get<String>('project_path') ?? '';
    if (savedPath.isNotEmpty && Directory(savedPath).existsSync()) {
      _initScanner(savedPath);
    }
  }

  @override
  void dispose() {
    _scanner?.dispose();
    super.dispose();
  }

  void _initScanner(String path) {
    _scanner?.dispose();
    final scanner = CodeScanner(projectPath: path);
    scanner.scan().then((_) {
      scanner.watch();
      setState(() => _scanner = scanner);
    });
    StateStore.dispatch('project_path', path);
  }

  void _changeProject() {
    _scanner?.dispose();
    setState(() => _scanner = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_scanner == null) {
      final savedPath = StateStore.get<String>('project_path') ?? '';
      return SetupScreen(
        initialPath: savedPath.isNotEmpty ? savedPath : null,
        onPathConfirmed: _initScanner,
      );
    }
    return DebuggerPage(
      scanner: _scanner!,
      onChangeProject: _changeProject,
    );
  }
}

class DebuggerPage extends StatefulWidget {
  final CodeScanner scanner;
  final VoidCallback onChangeProject;

  const DebuggerPage({
    super.key,
    required this.scanner,
    required this.onChangeProject,
  });

  @override
  State<DebuggerPage> createState() => _DebuggerPageState();
}

class _DebuggerPageState extends State<DebuggerPage> {
  final SocketServer socketServer = SocketServer();

  Map<String, dynamic> state = <String, dynamic>{};
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
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Change project',
            onPressed: widget.onChangeProject,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: StateStoreBuilder<bool>(
            id: 'view_mode_folded',
            builder: (context, folded) => folded
                ? JsonViewer(foldedState, onSelected: _onSelected)
                : JsonViewer(state, onSelected: _onSelected),
          ),
        ),
      ),
    );
  }

  void _onDispatch(Map<String, dynamic> newState) {
    setState(() {
      state = newState;
      foldedState = _fold(newState);
    });
  }

  void _onSelected(String? key, dynamic value) {
    if (key == null) return;

    // Strip the " [*]" persistence suffix that the socket client adds
    final cleanKey = key.replaceAll(RegExp(r'\s*\[\*\]$'), '');

    final refs = widget.scanner.referencesForKey(cleanKey);
    _showReferencesSheet(context, cleanKey, refs);
  }

  void _showReferencesSheet(
      BuildContext context, String key, List<CodeReference> refs) {
    final projectPath = widget.scanner.projectPath;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (refs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const Text('No references found in source'),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$key \u2014 ${refs.length} reference${refs.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...refs.map((ref) {
                // Show path relative to project root
                final relativePath = ref.filePath.startsWith(projectPath)
                    ? ref.filePath.substring(projectPath.length + 1)
                    : ref.filePath;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Chip(
                    label: Text(ref.usageType,
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                  title: Text('$relativePath:${ref.lineNumber}'),
                  subtitle: Text(ref.lineContent,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openInVsCode(ref, context),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openInVsCode(CodeReference ref, BuildContext context) async {
    try {
      final result = await Process.run(
          'code', ['--goto', '${ref.filePath}:${ref.lineNumber}']);
      if (result.exitCode != 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open VS Code. '
                'Navigate to ${ref.filePath}:${ref.lineNumber}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('VS Code not found. '
              'Navigate to ${ref.filePath}:${ref.lineNumber}')),
        );
      }
    }
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
