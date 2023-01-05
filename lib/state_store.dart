// ignore_for_file: slash_for_doc_comments

// MIT License

// Copyright (c) 2022 Tero Tarvainen "Do or do not. There is no question."

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

library state_store;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Importer = dynamic Function(String val);
typedef Exporter = String Function(dynamic val);

/// Signature of callbacks for state changes
typedef StateChangeCallback<V> = void Function(
    String id, V newState, BuildContext? ctx);

/// Signature of callbacks for triggered events
typedef TriggerCallback<V> = void Function(String id,
    {V? value, BuildContext? ctx});

class StateStore {
  static final GlobalKey<NavigatorState> key = GlobalKey();
  static final StateStore _instance = StateStore._internal();
  // All elements that contain data are stored here.
  final Map<String, StateElement> _store = {};
  // All elements that simply trigger events are stored here (namely the 'id' and listeners)
  final Map<String, TriggerElement> _triggers = {};

  factory StateStore() {
    throw ArgumentError('StateStore can not be instantiated. Static only!');
  }
  StateStore._internal();

  /********************************************************************************************
   *                              A P I
   ********************************************************************************************/

  /// Retrieve stored value with given id
  static V? get<V>(String id, [V? defaultValue]) {
    return _instance._value(id, defaultValue);
  }

  static void setUp<V>(
    String id,
    V value,
    bool persist, {
    Importer importer = jsonDecode,
    Exporter exporter = jsonEncode,
  }) {
    _instance._create(id, value, persist,
        importer: importer, exporter: exporter);
  }

  /// Push state change. This will replace the old value with 'event'
  /// and notify all listeners of the change.
  static void dispatch<V>(String id, V event, {BuildContext? ctx}) {
    // print("[StateStore]:[dispatch]: $id, $event");
    _instance._dispatch(id, event, ctx: ctx);
  }

  static void dispatchAddition<V>(String id, V value, {BuildContext? ctx}) {
    // print("[StateStore]:[dispatchAddition]: $id, $value");
    _instance._dispatchAddition(id, value, ctx: ctx);
  }

  /// Trigger change. This will notify all listeners of the event.
  static void trigger<V>(String id, {V? value, BuildContext? ctx}) {
    //print("[StateStore] TRIGGERED: $id");
    _instance._trigger(id, value: value, ctx: ctx);
  }

  /// Convenience method to add single listener to bunch of ids.
  static void addListeners(
      List<String> stateIds, StateChangeCallback listener) {
    for (String id in stateIds) {
      addListener(id, listener);
    }
  }

  /// Start listening on given state changes (id)
  static void addListener(String id, StateChangeCallback listener) {
    _instance._addListener(id, listener);
  }

  /// Cleanup listener so memory can be freed
  static void removeListener(String id, StateChangeCallback listener) {
    _instance._removeListener(id, listener);
  }

  /// Convenience method to remove single listener from bunch of ids.
  static void removeListeners(List<String> ids, StateChangeCallback listener) {
    for (String id in ids) {
      removeListener(id, listener);
    }
  }

  /// Convenience method to add single trigger listener to bunch of ids.
  static void addTriggerListeners(
      List<String> triggerIds, TriggerCallback listener) {
    for (String id in triggerIds) {
      addTriggerListener(id, listener);
    }
  }

  /// Start listening on given trigger (id)
  static void addTriggerListener(String id, TriggerCallback listener) {
    _instance._addTriggerListener(id, listener);
  }

  /// Convenience method to remove single trigger listener from bunch of ids.
  static void removeTriggerListeners(
      List<String> triggerIds, TriggerCallback listener) {
    for (String id in triggerIds) {
      removeTriggerListener(id, listener);
    }
  }

  /// Cleanup listener so memory can be freed
  static void removeTriggerListener(String id, TriggerCallback listener) {
    _instance._removeTriggerListener(id, listener);
  }

  static void disposeValue(String id) {
    _instance._disposeValue(id);
  }

  static void disposeValues(List<String> ids) {
    for (var id in ids) {
      disposeValue(id);
    }
  }

  static void dispose() {
    _instance._dispose();
  }

  static void prettyPrint() {
    _instance._prettyPrint();
  }

  static Future<bool> cleanPersistentStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.clear();
  }

  static Future<void> import() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print("# import");
    for (var i in prefs.getKeys()) {
      String item = prefs.get(i)! as String;
      assert(_instance._store[i] != null,
          'Trying to import $i, but store does not contain setUp for it.');
      _instance._store[i]!.import(item);
      print(
          "#    bringing: $i, ${_instance._store[i]!._value}, <${_instance._store[i]!._value.runtimeType}>");
    }
    print("# import ready");
  }

  /// Hackish way to ensure that we always have a reference to the Navigator
  /// in case some dispatch action leads to navigation and the dispatch does not
  /// include BuildContext.
  ///
  /// Usage: MaterialApp( navigationKey: StateStore.getNavigationKey(), )
  static GlobalKey<NavigatorState> getNavigationKey() {
    return key;
  }

  /********************************************************************************************
   *                            IMPLEMENTATION
   ********************************************************************************************/

  /// Listener is added even though such value might not exist yet with
  /// given id.
  void _addListener(String id, StateChangeCallback listener) {
    var stateElement = _store[id];
    if (stateElement == null) {
      // Note that listener is added even though such value does
      // not yet exist. When first value is set, listener is
      // called with that value and null as the old state.
      stateElement = StateElement();
      _store[id] = stateElement;
    }
    stateElement.addListener(listener);
  }

  void _removeListener(String id, StateChangeCallback listener) {
    var stateElement = _store[id];
    if (stateElement == null) {
      // nothing to do, since no such value
      // Basically an error case
      assert(false, "StateStore remove listener called for unrecognized id");
      return;
    }
    stateElement.removeListener(listener);
  }

  /// Listener is added even though such value might not exist yet with
  /// given id.
  void _addTriggerListener(String id, TriggerCallback listener) {
    var trigger = _triggers[id];
    if (trigger == null) {
      // Note that listener is added even though such value does
      // not yet exist.
      trigger = TriggerElement();
      _triggers[id] = trigger;
    }
    trigger.addListener(listener);
  }

  void _removeTriggerListener(String id, TriggerCallback listener) {
    var trigger = _triggers[id];
    if (trigger == null) {
      // nothing to do, since no such value
      // Basically an error case
      assert(false, "StateStore remove listener called for unrecognized id");
      return;
    }
    trigger.removeListener(listener);
  }

  /// Creates a state element with given values.
  /// Does NOT persist to disk
  /// Does NOT notify listeners
  /// Only creation.
  /// To be used in setUp
  void _create(
    String id,
    dynamic value,
    bool persist, {
    Importer importer = jsonDecode,
    Exporter exporter = jsonEncode,
  }) {
    var stateElement = _store[id];
    if (stateElement == null) {
      stateElement = StateElement(
        persist: persist,
        importer: importer,
        exporter: exporter,
      );
      stateElement._value = value;
      _store[id] = stateElement;
    }
  }

  void _dispatch(String id, dynamic value, {BuildContext? ctx}) {
    var stateElement = _store[id];
    if (stateElement == null) {
      stateElement = StateElement();
      _store[id] = stateElement;
    }
    try {
      stateElement.update(id, value, ctx);
    } catch (e) {
      print("### $e");
    }

    // Note: Persisted elements need to be set up
    // separately
    if (stateElement.persist) {
      _persist(id, stateElement.export());
    }
  }

  // dispatch but for array values. If such element (array) does not yet exist
  // then it's created
  void _dispatchAddition(String id, dynamic value, {BuildContext? ctx}) {
    var stateElement = _store[id];
    if (stateElement == null) {
      stateElement = StateElement();
      stateElement._value = [];
      _store[id] = stateElement;
    }
    // Add the new value to the list
    stateElement._value.add(value);
    try {
      stateElement.update(id, stateElement._value, ctx);
    } catch (e) {
      print("### $e");
    }

    // Note: Persisted elements need to be set up
    // separately
    if (stateElement.persist) {
      _persist(id, stateElement.export());
    }
  }

  void _persist(String id, String value) {
    Future(() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(id, value);
      print("[StateStore]: Persist $id: $value");
    });
  }

  void _trigger(String id, {dynamic value, BuildContext? ctx}) {
    var triggerElement = _triggers[id];
    if (triggerElement != null) {
      triggerElement.trigger(id, value: value, ctx: ctx);
    }
  }

  V? _value<V>(String id, [V? defaultValue]) {
    var stateElement = _store[id];
    if (stateElement == null) {
      return defaultValue;
    }
    if (stateElement._value == null) {
      return defaultValue;
    }
    return stateElement._value;
  }

  void _disposeValue(String id) {
    _store.remove(id);
  }

  void _dispose() {
    _store.clear();
    _triggers.clear();
  }

  void _prettyPrint() {
    _prettyPrintStore();
    _prettyPrintTriggers();
  }

  void _prettyPrintStore() {
    _store.forEach((k, v) {
      print("ID: $k: ");
      print("    Value:   ${v._value}");
      print("    Type:    ${v._value.runtimeType}");
      if (v._ctx != null) {
        print("    Context: ${v._ctx}");
      }
      print("    Listener count: ${v._listeners!.length}");
    });
  }

  void _prettyPrintTriggers() {
    _triggers.forEach((k, v) {
      print("ID: $k, listeners count: ${v._listeners!.length}");
    });
  }
}

class StateChangeNotifier<V> {
  ObserverList<StateChangeCallback>? _listeners =
      ObserverList<StateChangeCallback>();

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_listeners == null) {
        throw FlutterError('A $runtimeType was used after being disposed.\n'
            'Once you have called dispose() on a $runtimeType, it can no longer be used.');
      }
      return true;
    }());
    return true;
  }

  @protected
  bool get hasListeners {
    assert(_debugAssertNotDisposed());
    return _listeners!.isNotEmpty;
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    _listeners = null;
  }

  @protected
  @visibleForTesting
  void notifyListeners(String id, V newValue, BuildContext? ctx) {
    assert(_debugAssertNotDisposed());
    if (_listeners != null) {
      final List<StateChangeCallback> localListeners =
          List<StateChangeCallback>.from(_listeners!);
      for (StateChangeCallback listener in localListeners) {
        try {
          if (_listeners!.contains(listener)) listener(id, newValue, ctx);
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'StateStore',
            context: ErrorDescription(
                'while dispatching StateStore for $runtimeType'),
            informationCollector: () sync* {
              yield DiagnosticsProperty<StateChangeNotifier>(
                'The $runtimeType sending notification was',
                this,
                style: DiagnosticsTreeStyle.errorProperty,
              );
            },
          ));
        }
      }
    }
  }

  addListener(StateChangeCallback listener) {
    assert(_debugAssertNotDisposed());
    _listeners!.add(listener);
  }

  removeListener(StateChangeCallback listener) {
    assert(_debugAssertNotDisposed());
    _listeners!.remove(listener);
  }
}

class TriggerNotifier {
  ObserverList<TriggerCallback>? _listeners = ObserverList<TriggerCallback>();

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_listeners == null) {
        throw FlutterError('A $runtimeType was used after being disposed.\n'
            'Once you have called dispose() on a $runtimeType, it can no longer be used.');
      }
      return true;
    }());
    return true;
  }

  @protected
  bool get hasListeners {
    assert(_debugAssertNotDisposed());
    return _listeners!.isNotEmpty;
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    _listeners = null;
  }

  @protected
  @visibleForTesting
  void notifyListeners(String id, dynamic value, BuildContext? ctx) {
    assert(_debugAssertNotDisposed());
    if (_listeners != null) {
      final List<TriggerCallback> localListeners =
          List<TriggerCallback>.from(_listeners!);
      for (TriggerCallback listener in localListeners) {
        try {
          if (_listeners!.contains(listener)) {
            listener(id, value: value, ctx: ctx);
          }
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'StateStore',
            context: ErrorDescription(
                'while dispatching StateStore for $runtimeType'),
            informationCollector: () sync* {
              yield DiagnosticsProperty<TriggerNotifier>(
                'The $runtimeType sending notification was',
                this,
                style: DiagnosticsTreeStyle.errorProperty,
              );
            },
          ));
        }
      }
    }
  }

  addListener(TriggerCallback listener) {
    assert(_debugAssertNotDisposed());
    _listeners!.add(listener);
  }

  removeListener(TriggerCallback listener) {
    assert(_debugAssertNotDisposed());
    _listeners!.remove(listener);
  }
}

class TriggerElement with TriggerNotifier {
  void trigger(String id, {dynamic value, BuildContext? ctx}) {
    //print("Trigger $id, listeners ${_listeners.length}");
    notifyListeners(id, value, ctx);
  }
}

class StateElement<V> with StateChangeNotifier {
  V? _value;
  BuildContext? _ctx;
  final bool persist;
  final Importer importer;
  final Exporter exporter;

  StateElement({
    this.persist = false,
    this.importer = jsonDecode,
    this.exporter = jsonEncode,
  });

  void update(String id, V newValue, [BuildContext? ctx]) {
    _value = newValue;
    _ctx = ctx;
    //print("Dispatch $id");
    //print("Dispatch $id $newValue $_listeners.length");
    notifyListeners(id, _value, _ctx);
  }

  void import(String val) {
    _value = importer(val);
  }

  String export() {
    // print("[StateStore] ### Export: $_value, $exporter");
    return exporter(_value);
  }
}

typedef StateStoreWidgetBuilder<S> = Widget Function(
    BuildContext context, S state);

typedef StateStoreBuilderCondition<S> = bool Function(S current);

class StateStoreBuilder<S> extends StateStoreBuilderBase<S> {
  final StateStoreWidgetBuilder<S> builder;

  const StateStoreBuilder({
    Key? key,
    required this.builder,
    required String id,
    StateStoreBuilderCondition<S>? condition,
  }) : super(key: key, id: id, condition: condition);

  @override
  Widget build(BuildContext context, S state) => builder(context, state);
}

abstract class StateStoreBuilderBase<S> extends StatefulWidget {
  const StateStoreBuilderBase({Key? key, this.id, this.condition})
      : super(key: key);

  final String? id;

  final StateStoreBuilderCondition<S>? condition;

  /// Returns a [Widget] based on the [BuildContext] and current [state].
  Widget build(BuildContext context, S state);

  @override
  State<StateStoreBuilderBase<S?>> createState() =>
      _StateStoreBuilderBaseState<S>();
}

class _StateStoreBuilderBaseState<S> extends State<StateStoreBuilderBase<S?>> {
  S? _state;
  String? _id = "";

  StateChangeCallback? listener;

  @override
  void initState() {
    super.initState();
    _id = widget.id;
    _state = StateStore.get(_id!);
    _subscribe();
  }

  @override
  void didUpdateWidget(StateStoreBuilderBase<S?> oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) => widget.build(context, _state);

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    listener = (_id, newValue, ctx) {
      if (widget.condition?.call(newValue) ?? true) {
        setState(() {
          _state = newValue;
        });
      }
    };
    StateStore.addListener(_id!, listener!);
  }

  void _unsubscribe() {
    StateStore.removeListener(_id!, listener!);
    listener = null;
  }
}
