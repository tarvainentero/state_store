## 0.8.0

- All internal logging is now off by default and goes through `debugPrint`.
  Enable it in debug builds with `StateStore.verbose = kDebugMode`.
- `dispatchToggle` no longer declares a bogus `<bool>` type parameter.
  Call it as `StateStore.dispatchToggle('id')`. Passing `<bool>` is a
  breaking change for callers that did so.
- `dispatchToggle` asserts on unknown ids and non-bool values in debug builds
  and is a no-op for them in release builds instead of crashing.

## 0.7.0

- `persist` is now a named parameter in `setUp`
- Debugger: code references panel showing where each state id is used, with
  jump-to-VS-Code
- Debugger: resizable split pane and code map minimap view

## 0.6.0

- Add StateStoreMultiBuilder for listening to multiple state IDs
- Recreate example app with latest Flutter

## 0.5.0

- Support for migration of old persisted values to new format

## 0.4.2

- 'Folding' state view support to state_store_debugger
- Support for custom ToEncodable functions to handle custom non json serializable content

## 0.3.0

- Support for remote state observator
- Application to view state remotely added: see state_store_debugger

## 0.1.0

- Initial Open Source release. Very much in development mode still.

## 0.0.1

- Intial private release.
