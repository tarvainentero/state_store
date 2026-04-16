# Debugger Code References & Jump-to-IDE

## Overview

Enhance the `state_store_debugger` app so that users can see where each state key is used in their client code, and jump directly to those locations in VS Code.

## Scope

All changes are confined to `state_store_debugger/`. No changes to the `state_store` library or any client app.

## Features

### 1. Project Path Configuration

- On first launch, a setup screen asks the user for the client project's root path (the directory containing `lib/`)
- The user can paste a path or browse using a directory picker
- The path is persisted via `StateStore` so it's remembered across restarts
- An option in the app bar allows the user to change the project path later

### 2. Code Scanner Service

A `CodeScanner` class that:

- **Initial scan:** Recursively finds all `.dart` files under the provided path. Reads each file line-by-line and looks for string literals matching known state keys in lines that reference `StateStore`, `StateStoreBuilder`, or `StateStoreMultiBuilder`.
- **Index structure:** Builds a `Map<String, List<CodeReference>>` where the key is the state ID (e.g., `'main.counter'`) and value is a list of references. Each `CodeReference` contains: `filePath`, `lineNumber`, `lineContent`, and `usageType` (setUp, dispatch, get, builder, etc.).
- **File watcher:** Uses `Directory.watch(recursive: true)` to detect `.dart` file changes. When a file is created/modified/deleted, re-scans that single file and updates the index.

#### Key discovery

The scanner discovers keys in two ways:
- From the live state received over the socket connection (keys currently in the store)
- From scanning the source files directly (any string literal used with StateStore APIs)

This means the reference panel works even for keys that haven't been dispatched yet.

#### Matching strategy

The scanner looks for lines containing both:
1. A `StateStore` / `StateStoreBuilder` / `StateStoreMultiBuilder` reference (or common method names like `setUp`, `dispatch`, `get`, `dispatchToggle`, `dispatchAddition`, `addListener`, `trigger`)
2. A string literal matching a known state key (e.g., `'main.counter'`)

This is regex-based, not AST-based. Sufficient for string-literal key lookups.

### 3. UI — Reference Panel

When the user taps a state key in the JSON state viewer:

- A bottom sheet appears showing all code references for that key
- Each row shows: usage type, relative file path, and line number
- Example:
  ```
  main.counter — 3 references

  setUp    lib/main.dart:21
  dispatch lib/main.dart:67
  builder  lib/main.dart:86
  ```
- Keys with no references show "No references found in source"
- Each row is tappable to trigger jump-to-IDE

### 4. Jump to VS Code

Tapping a reference row runs:

```dart
Process.run('code', ['--goto', '$filePath:$lineNumber'])
```

This uses VS Code's `--goto` CLI flag to open the file at the exact line.

If the `code` command fails (VS Code not installed or not in PATH), a snackbar is shown with the file path and line number for manual navigation.

Only VS Code is supported initially. Other IDEs can be added later.

## New Files

- `lib/code_scanner.dart` — scanner service with file watching
- `lib/code_reference.dart` — `CodeReference` data class
- `lib/setup_screen.dart` — project path configuration screen

## Modified Files

- `lib/main.dart` — routing (setup screen -> debugger view), persist project path, pass scanner to debugger, add reference bottom sheet on key tap
