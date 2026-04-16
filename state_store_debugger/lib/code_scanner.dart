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
