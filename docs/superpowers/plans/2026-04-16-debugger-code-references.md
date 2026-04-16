# Debugger Code References & Jump-to-IDE Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance the state_store_debugger app to show where each state key is used in client code and allow jumping to those locations in VS Code.

**Architecture:** A `CodeScanner` service scans `.dart` files in the user-configured project path, builds a key-to-references index, and watches for file changes. The debugger UI shows a bottom sheet with code references when a key is tapped, with tap-to-open-in-VS-Code on each reference.

**Tech Stack:** Flutter, dart:io (file system + process), StateStore (persistence)

---

## File Structure

All files under `state_store_debugger/lib/`:

| File | Responsibility |
|---|---|
| `code_reference.dart` (new) | `CodeReference` data class |
| `code_scanner.dart` (new) | File scanning, index building, file watching |
| `setup_screen.dart` (new) | Project path input screen |
| `main.dart` (modify) | Routing, pass scanner to debugger, reference bottom sheet |
| `json_viewer.dart` (existing, no changes) | Unchanged |
| `socket_server.dart` (existing, no changes) | Unchanged |

---

### Task 1: CodeReference data class

**Files:**
- Create: `state_store_debugger/lib/code_reference.dart`

- [ ] **Step 1: Create the CodeReference class**

```dart
// state_store_debugger/lib/code_reference.dart

class CodeReference {
  final String filePath;
  final int lineNumber;
  final String lineContent;
  final String usageType;

  const CodeReference({
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
    required this.usageType,
  });

  @override
  String toString() => '$usageType $filePath:$lineNumber';
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd state_store_debugger && flutter analyze lib/code_reference.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add state_store_debugger/lib/code_reference.dart
git commit -m "feat(debugger): add CodeReference data class"
```

---

### Task 2: CodeScanner service

**Files:**
- Create: `state_store_debugger/lib/code_scanner.dart`

- [ ] **Step 1: Create the CodeScanner class with scanning logic**

```dart
// state_store_debugger/lib/code_scanner.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'code_reference.dart';

class CodeScanner {
  final String projectPath;
  Map<String, List<CodeReference>> _index = {};
  StreamSubscription<FileSystemEvent>? _watchSubscription;

  CodeScanner({required this.projectPath});

  /// Returns all references for a given state key.
  List<CodeReference> referencesForKey(String key) {
    return _index[key] ?? [];
  }

  /// Returns all discovered keys.
  Set<String> get discoveredKeys => _index.keys.toSet();

  /// Performs the initial full scan of all .dart files under projectPath.
  Future<void> scan() async {
    _index = {};
    final dir = Directory(projectPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        _scanFile(entity);
      }
    }
    debugPrint('CodeScanner: indexed ${_index.length} keys from $projectPath');
  }

  /// Starts watching for file changes and re-scans modified files.
  void watch() {
    final dir = Directory(projectPath);
    _watchSubscription = dir.watch(recursive: true).listen((event) {
      if (!event.path.endsWith('.dart')) return;

      if (event is FileSystemDeleteEvent) {
        _removeFileFromIndex(event.path);
      } else {
        // FileSystemCreateEvent or FileSystemModifyEvent
        final file = File(event.path);
        if (file.existsSync()) {
          _removeFileFromIndex(event.path);
          _scanFile(file);
        }
      }
    });
  }

  void dispose() {
    _watchSubscription?.cancel();
  }

  void _scanFile(File file) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final refs = _parseLine(file.path, i + 1, line);
      for (final ref in refs) {
        _index.putIfAbsent(ref.key, () => []).add(ref.value);
      }
    }
  }

  void _removeFileFromIndex(String filePath) {
    for (final key in _index.keys.toList()) {
      _index[key]!.removeWhere((ref) => ref.filePath == filePath);
      if (_index[key]!.isEmpty) {
        _index.remove(key);
      }
    }
  }

  /// Parses a single line and returns any (stateKey, CodeReference) pairs found.
  List<MapEntry<String, CodeReference>> _parseLine(
      String filePath, int lineNumber, String line) {
    final results = <MapEntry<String, CodeReference>>[];

    // Match string literals (single or double quoted)
    final stringLiterals = RegExp(r"""['"]([^'"]+)['"]""");
    final matches = stringLiterals.allMatches(line);
    if (matches.isEmpty) return results;

    // Determine usage type from the line content
    final usageType = _detectUsageType(line);
    if (usageType == null) return results;

    for (final match in matches) {
      final key = match.group(1)!;
      // Skip obvious non-keys (imports, package refs, etc.)
      if (key.contains('/') || key.contains('.dart') || key.contains('package:')) {
        continue;
      }
      results.add(MapEntry(
        key,
        CodeReference(
          filePath: filePath,
          lineNumber: lineNumber,
          lineContent: line.trim(),
          usageType: usageType,
        ),
      ));
    }

    return results;
  }

  /// Detects the StateStore usage type from a line of code.
  /// Returns null if the line doesn't contain a StateStore reference.
  String? _detectUsageType(String line) {
    if (line.contains('StateStore.setUp')) return 'setUp';
    if (line.contains('StateStore.dispatch') &&
        !line.contains('dispatchToggle') &&
        !line.contains('dispatchAddition')) {
      return 'dispatch';
    }
    if (line.contains('StateStore.dispatchToggle')) return 'dispatchToggle';
    if (line.contains('StateStore.dispatchAddition')) return 'dispatchAddition';
    if (line.contains('StateStore.get')) return 'get';
    if (line.contains('StateStore.trigger')) return 'trigger';
    if (line.contains('StateStore.addListener')) return 'addListener';
    if (line.contains('StateStore.removeListener')) return 'removeListener';
    if (line.contains('StateStoreMultiBuilder')) return 'multiBuilder';
    if (line.contains('StateStoreBuilder')) return 'builder';
    return null;
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd state_store_debugger && flutter analyze lib/code_scanner.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add state_store_debugger/lib/code_scanner.dart
git commit -m "feat(debugger): add CodeScanner service with file watching"
```

---

### Task 3: Setup screen

**Files:**
- Create: `state_store_debugger/lib/setup_screen.dart`

- [ ] **Step 1: Create the SetupScreen widget**

```dart
// state_store_debugger/lib/setup_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  final String? initialPath;
  final void Function(String path) onPathConfirmed;

  const SetupScreen({
    super.key,
    this.initialPath,
    required this.onPathConfirmed,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPath ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final path = _controller.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Please enter a path');
      return;
    }
    final dir = Directory(path);
    if (!dir.existsSync()) {
      setState(() => _error = 'Directory does not exist');
      return;
    }
    setState(() => _error = null);
    widget.onPathConfirmed(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('State Store Debugger'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client Project Path',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the root path of the Flutter project you want to debug. '
              'The scanner will search for StateStore key usages in the Dart files.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Project root path',
                hintText: '/path/to/your/flutter/project',
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle),
                  onPressed: _confirm,
                ),
              ),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.folder_open),
              label: const Text('Start Debugging'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd state_store_debugger && flutter analyze lib/setup_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add state_store_debugger/lib/setup_screen.dart
git commit -m "feat(debugger): add setup screen for project path"
```

---

### Task 4: Wire up main.dart — routing, scanner, and reference bottom sheet

**Files:**
- Modify: `state_store_debugger/lib/main.dart`

- [ ] **Step 1: Rewrite main.dart with routing and scanner integration**

Replace the entire contents of `state_store_debugger/lib/main.dart` with:

```dart
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
```

- [ ] **Step 2: Verify it compiles**

Run: `cd state_store_debugger && flutter analyze lib/`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add state_store_debugger/lib/main.dart
git commit -m "feat(debugger): wire up routing, scanner, and reference panel"
```

---

### Task 5: Manual integration test

- [ ] **Step 1: Run the debugger app pointing at the example project**

Run: `cd state_store_debugger && flutter run -d macos`

- [ ] **Step 2: On the setup screen, enter the example app path**

Enter: `/Users/terotarvainen/projects/playground/flutter/state_store/example`

Verify: The app transitions to the debugger view.

- [ ] **Step 3: Run the example app in a separate terminal**

Run: `cd example && flutter run -d macos`

Verify: The debugger shows the live state keys from the example app.

- [ ] **Step 4: Tap a state key (e.g., `main.counter`)**

Verify: A bottom sheet appears showing references like:
```
main.counter — 3 references

setUp    lib/main.dart:21
dispatch lib/main.dart:67
builder  lib/main.dart:86
```

- [ ] **Step 5: Tap a reference row**

Verify: VS Code opens at the correct file and line number.

- [ ] **Step 6: Test the "Change project" button**

Tap the folder icon in the app bar. Verify: Returns to the setup screen with the previous path pre-filled.

- [ ] **Step 7: Commit all remaining changes**

```bash
git add -A
git commit -m "feat(debugger): code references and jump-to-VS-Code complete"
```
