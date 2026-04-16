import 'dart:io';

import 'package:flutter/material.dart';
import 'package:state_store/state_store.dart';
import 'package:state_store_debugger/json_viewer.dart';

import 'code_map_view.dart';
import 'code_reference.dart';
import 'code_scanner.dart';
import 'setup_screen.dart';
import 'socket_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  StateStore.setUp<bool>('view_mode_folded', false, persist: true);
  StateStore.setUp<String>('project_path', '', persist: true);
  StateStore.setUp<double>('panel_width', 360.0, persist: true);
  StateStore.setUp<int>('refs_view_tab', 0, persist: true);

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
  final SocketServer _socketServer = SocketServer();
  Map<String, dynamic> _state = <String, dynamic>{};
  Map<String, dynamic> _foldedState = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _socketServer.start(_onDispatch);
    final savedPath = StateStore.get<String>('project_path') ?? '';
    if (savedPath.isNotEmpty && Directory(savedPath).existsSync()) {
      _initScanner(savedPath);
    }
  }

  @override
  void dispose() {
    _scanner?.dispose();
    _socketServer.dispose();
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

  void _onDispatch(Map<String, dynamic> newState) {
    setState(() {
      _state = newState;
      _foldedState = _fold(newState);
    });
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
      state: _state,
      foldedState: _foldedState,
      onChangeProject: _changeProject,
    );
  }

  static Map<String, dynamic> _fold(Map<String, dynamic> state) {
    Map<String, dynamic> result = <String, dynamic>{};
    for (var key in state.keys) {
      var value = state[key];
      _ensureAndInsertTarget(result, key, value);
    }
    return result;
  }

  static void _ensureAndInsertTarget(
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

class DebuggerPage extends StatefulWidget {
  final CodeScanner scanner;
  final Map<String, dynamic> state;
  final Map<String, dynamic> foldedState;
  final VoidCallback onChangeProject;

  const DebuggerPage({
    super.key,
    required this.scanner,
    required this.state,
    required this.foldedState,
    required this.onChangeProject,
  });

  @override
  State<DebuggerPage> createState() => _DebuggerPageState();
}

class _DebuggerPageState extends State<DebuggerPage> {
  String? _selectedKey;
  List<CodeReference> _selectedRefs = [];

  void _onSelected(String? key, dynamic value) {
    if (key == null) return;

    // Strip the " [*]" persistence suffix that the socket client adds
    final cleanKey = key.replaceAll(RegExp(r'\s*\[\*\]$'), '');

    setState(() {
      if (_selectedKey == cleanKey) {
        // Toggle off on re-select
        _selectedKey = null;
        _selectedRefs = [];
      } else {
        _selectedKey = cleanKey;
        _selectedRefs = widget.scanner.referencesForKey(cleanKey);
      }
    });
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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: StateStoreBuilder<bool>(
                  id: 'view_mode_folded',
                  builder: (context, folded) => folded
                      ? JsonViewer(widget.foldedState, onSelected: (k, v) => _onSelected(k, v))
                      : JsonViewer(widget.state, onSelected: (k, v) => _onSelected(k, v)),
                ),
              ),
            ),
          ),
          if (_selectedKey != null)
            StateStoreBuilder<double>(
              id: 'panel_width',
              builder: (context, _) => _ResizableReferencesPanel(
                selectedKey: _selectedKey!,
                refs: _selectedRefs,
                projectPath: widget.scanner.projectPath,
                onClose: () => setState(() {
                  _selectedKey = null;
                  _selectedRefs = [];
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResizableReferencesPanel extends StatelessWidget {
  final String selectedKey;
  final List<CodeReference> refs;
  final String projectPath;
  final VoidCallback onClose;

  static const double _minWidth = 200.0;
  static const double _maxWidth = 800.0;

  const _ResizableReferencesPanel({
    required this.selectedKey,
    required this.refs,
    required this.projectPath,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final width = (StateStore.get<double>('panel_width') ?? 360.0)
        .clamp(_minWidth, _maxWidth);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final newWidth = (width - details.delta.dx)
                  .clamp(_minWidth, _maxWidth);
              StateStore.dispatch<double>('panel_width', newWidth);
            },
            child: Container(
              width: 6,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  width: 2,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: width,
          child: _ReferencesPanelContent(
            selectedKey: selectedKey,
            refs: refs,
            projectPath: projectPath,
            onClose: onClose,
          ),
        ),
      ],
    );
  }
}

class _ReferencesPanelContent extends StatelessWidget {
  final String selectedKey;
  final List<CodeReference> refs;
  final String projectPath;
  final VoidCallback onClose;

  const _ReferencesPanelContent({
    required this.selectedKey,
    required this.refs,
    required this.projectPath,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$selectedKey \u2014 ${refs.length} reference${refs.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          StateStoreBuilder<int>(
            id: 'refs_view_tab',
            builder: (context, tab) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _TabButton(
                    label: 'List',
                    icon: Icons.list,
                    selected: tab == 0,
                    onTap: () => StateStore.dispatch('refs_view_tab', 0),
                  ),
                  const SizedBox(width: 4),
                  _TabButton(
                    label: 'Map',
                    icon: Icons.map_outlined,
                    selected: tab == 1,
                    onTap: () => StateStore.dispatch('refs_view_tab', 1),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          if (refs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No references found in source'),
            )
          else
            Expanded(
              child: StateStoreBuilder<int>(
                id: 'refs_view_tab',
                builder: (context, tab) => tab == 1
                    ? CodeMapView(
                        projectPath: projectPath,
                        refs: refs,
                        onRefTap: (ref) => _openInVsCode(ref, context),
                      )
                    : _RefListView(
                        refs: refs,
                        projectPath: projectPath,
                      ),
              ),
            ),
        ],
      ),
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
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Colors.grey),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Colors.grey,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefListView extends StatelessWidget {
  final List<CodeReference> refs;
  final String projectPath;

  const _RefListView({
    required this.refs,
    required this.projectPath,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: refs.length,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemBuilder: (context, index) {
        final ref = refs[index];
        final relativePath = ref.filePath.startsWith(projectPath)
            ? ref.filePath.substring(projectPath.length + 1)
            : ref.filePath;
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Chip(
            label: Text(ref.usageType,
                style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
          ),
          title: Text('$relativePath:${ref.lineNumber}'
              '${ref.occurrences > 1 ? ' (${ref.occurrences}x on this line)' : ''}'),
          subtitle: Text(ref.lineContent,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => _openInVsCode(ref, context),
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
}
