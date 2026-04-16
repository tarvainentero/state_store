# state_store

A lightweight state management package for Flutter. No boilerplate, no code generation — just a simple static API with optional persistence via SharedPreferences.

## Features

- **Simple static API** — no providers, no context, no InheritedWidgets
- **Persistence** — opt-in per-value persistence to SharedPreferences with custom serialization support
- **Reactive builders** — `StateStoreBuilder` and `StateStoreMultiBuilder` widgets that rebuild on state changes
- **Listeners** — subscribe to state changes and fire-and-forget trigger events
- **Data migration** — migrate old persisted keys when your state schema changes
- **Remote debugging** — inspect live app state with the companion `state_store_debugger` desktop app

## Getting started

Add `state_store` to your `pubspec.yaml`:

```yaml
dependencies:
  state_store: ^0.7.0
```

## Usage

### 1. Set up state variables

```dart
StateStore.setUp<int>('counter', 0, persist: true);  // persisted
StateStore.setUp<String>('username', '');              // in-memory only
```

### 2. Load persisted values

```dart
await StateStore.import();
```

### 3. Read and update state

```dart
// Read
int count = StateStore.get('counter');

// Update — notifies all listeners and builders
StateStore.dispatch('counter', count + 1);

// Toggle a boolean
StateStore.dispatchToggle('darkMode');

// Append to a list
StateStore.dispatchAddition('items', newItem);
```

### 4. React to state in the UI

Single value:

```dart
StateStoreBuilder<int>(
  id: 'counter',
  builder: (context, value) => Text('$value'),
)
```

Multiple values:

```dart
StateStoreMultiBuilder(
  ids: const ['counter', 'username'],
  builder: (context, states) {
    final counter = states['counter'] as int;
    final name = states['username'] as String;
    return Text('$name pressed $counter times');
  },
)
```

### 5. Listen to changes

```dart
StateStore.addListener('counter', (id, newValue, ctx) {
  print('Counter changed to $newValue');
});
```

### 6. Custom types with persistence

```dart
StateStore.setUp<MyClass>(
  'myObject',
  MyClass.defaultValue(),
  persist: true,
  importer: (json) => MyClass.fromJson(jsonDecode(json)),
  exporter: (value) => jsonEncode(value.toJson()),
);
```

### 7. Remote debugging

Connect to the companion `state_store_debugger` app to inspect state in real time:

```dart
if (kDebugMode) {
  await StateStore.connectRemoteDebugging();
}
```

See the `state_store_debugger` directory for the remote debugger app.

## Example

See the `example` directory for a complete working app.

## Additional information

This package is provided as-is without dedicated support.
