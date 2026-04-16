import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'code_reference.dart';

/// A file entry for the minimap with its line count and any references.
class _FileEntry {
  final String relativePath;
  final String absolutePath;
  final int lineCount;
  final List<CodeReference> refs;

  _FileEntry({
    required this.relativePath,
    required this.absolutePath,
    required this.lineCount,
    required this.refs,
  });
}

/// A bird's-eye minimap view of the project file structure.
/// Files are drawn as thin rectangles, grouped by folder.
/// Reference locations are highlighted as clickable hotspots.
class CodeMapView extends StatefulWidget {
  final String projectPath;
  final List<CodeReference> refs;
  final void Function(CodeReference ref) onRefTap;

  const CodeMapView({
    super.key,
    required this.projectPath,
    required this.refs,
    required this.onRefTap,
  });

  @override
  State<CodeMapView> createState() => _CodeMapViewState();
}

class _CodeMapViewState extends State<CodeMapView> {
  List<_FileEntry> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scanFiles();
  }

  @override
  void didUpdateWidget(CodeMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectPath != widget.projectPath) {
      _scanFiles();
    }
  }

  Future<void> _scanFiles() async {
    setState(() => _loading = true);

    final dir = Directory(widget.projectPath);
    if (!await dir.exists()) {
      setState(() {
        _files = [];
        _loading = false;
      });
      return;
    }

    // Build a ref lookup: absolutePath -> list of refs
    final refsByFile = <String, List<CodeReference>>{};
    for (final ref in widget.refs) {
      refsByFile.putIfAbsent(ref.filePath, () => []).add(ref);
    }

    final files = <_FileEntry>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final lineCount = _countLines(entity);
        final relativePath = entity.path.substring(widget.projectPath.length + 1);
        files.add(_FileEntry(
          relativePath: relativePath,
          absolutePath: entity.path,
          lineCount: lineCount,
          refs: refsByFile[entity.path] ?? [],
        ));
      }
    }

    // Sort by path for consistent folder grouping
    files.sort((a, b) => a.relativePath.compareTo(b.relativePath));

    setState(() {
      _files = files;
      _loading = false;
    });
  }

  int _countLines(File file) {
    try {
      return file.readAsLinesSync().length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_files.isEmpty) {
      return const Center(child: Text('No Dart files found'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: _CodeMap(
            files: _files,
            availableWidth: constraints.maxWidth - 16,
            onRefTap: widget.onRefTap,
          ),
        );
      },
    );
  }
}

/// Renders the minimap using custom painting with hit-testable reference markers.
class _CodeMap extends StatelessWidget {
  final List<_FileEntry> files;
  final double availableWidth;
  final void Function(CodeReference ref) onRefTap;

  static const double folderGap = 8.0;

  const _CodeMap({
    required this.files,
    required this.availableWidth,
    required this.onRefTap,
  });

  @override
  Widget build(BuildContext context) {
    // Group files by their top-level folder
    final groups = <String, List<_FileEntry>>{};
    for (final file in files) {
      final parts = file.relativePath.split(Platform.pathSeparator);
      final folder = parts.length > 1 ? parts.first : '.';
      groups.putIfAbsent(folder, () => []).add(file);
    }

    final maxLines = files.map((f) => f.lineCount).reduce(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              entry.key,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final file in entry.value)
            _FileBar(
              file: file,
              maxLines: maxLines,
              availableWidth: availableWidth,
              onRefTap: onRefTap,
            ),
          SizedBox(height: folderGap),
        ],
      ],
    );
  }
}

/// A single file bar in the minimap.
class _FileBar extends StatelessWidget {
  final _FileEntry file;
  final int maxLines;
  final double availableWidth;
  final void Function(CodeReference ref) onRefTap;

  const _FileBar({
    required this.file,
    required this.maxLines,
    required this.availableWidth,
    required this.onRefTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRefs = file.refs.isNotEmpty;
    final barWidth = maxLines > 0
        ? (file.lineCount / maxLines * availableWidth).clamp(8.0, availableWidth)
        : 8.0;

    return Tooltip(
      message: '${file.relativePath} (${file.lineCount} lines)'
          '${hasRefs ? ' — ${file.refs.length} reference${file.refs.length == 1 ? '' : 's'}' : ''}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: SizedBox(
          height: hasRefs ? 14 : 4,
          width: availableWidth,
          child: CustomPaint(
            painter: _FileBarPainter(
              file: file,
              barWidth: barWidth,
              hasRefs: hasRefs,
            ),
            child: hasRefs
                ? _RefHitTargets(
                    file: file,
                    barWidth: barWidth,
                    onRefTap: onRefTap,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Paints the file bar and reference markers.
class _FileBarPainter extends CustomPainter {
  final _FileEntry file;
  final double barWidth;
  final bool hasRefs;

  _FileBarPainter({
    required this.file,
    required this.barWidth,
    required this.hasRefs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = hasRefs ? 6.0 : 4.0;
    final barTop = hasRefs ? (size.height - barHeight) / 2 : 0.0;

    // Draw file bar
    final barPaint = Paint()
      ..color = hasRefs ? Colors.amber.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, barTop, barWidth, barHeight),
        const Radius.circular(1),
      ),
      barPaint,
    );

    if (!hasRefs || file.lineCount == 0) return;

    // Draw reference markers
    final markerPaint = Paint()..color = Colors.redAccent;
    for (final ref in file.refs) {
      final x = (ref.lineNumber / file.lineCount * barWidth).clamp(2.0, barWidth - 2);
      canvas.drawCircle(Offset(x, size.height / 2), 4, markerPaint);
    }
  }

  @override
  bool shouldRepaint(_FileBarPainter oldDelegate) =>
      file != oldDelegate.file || barWidth != oldDelegate.barWidth;
}

/// Invisible hit-test targets over each reference marker.
class _RefHitTargets extends StatelessWidget {
  final _FileEntry file;
  final double barWidth;
  final void Function(CodeReference ref) onRefTap;

  const _RefHitTargets({
    required this.file,
    required this.barWidth,
    required this.onRefTap,
  });

  @override
  Widget build(BuildContext context) {
    if (file.lineCount == 0) return const SizedBox.shrink();

    return Stack(
      children: file.refs.map((ref) {
        final x = (ref.lineNumber / file.lineCount * barWidth).clamp(2.0, barWidth - 2);
        return Positioned(
          left: x - 8,
          top: 0,
          child: Tooltip(
            message: '${ref.usageType} — ${file.relativePath}:${ref.lineNumber}',
            child: GestureDetector(
              onTap: () => onRefTap(ref),
              child: const SizedBox(width: 16, height: 14),
            ),
          ),
        );
      }).toList(),
    );
  }
}
