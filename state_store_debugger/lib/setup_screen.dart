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
