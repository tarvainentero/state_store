import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:state_store/state_store.dart';

import 'example_complex.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Step 1
  /// Set up all state variables that require initial value
  /// or if you want to mark the variable as persisted.
  /// (id, defaultValue, persistence)
  ///
  /// For more complex values also define Importer and Exporter.
  ///
  StateStore.setUp<int>('counter', 0, true);
  StateStore.setUp<String>('text', 'Tiger blood', true);
  StateStore.setUp<Complex>('complex', Complex.demo(), true);

  /// Step 2
  /// Use import to fetch all persisted values
  await StateStore.import();

  /// In cases where you want to use external state debugger for the state_store
  /// NOTE: This requires socket connection entitlement
  /// macos:
  /// <key>com.apple.security.network.client</key>
  /// <true/>
  if (kDebugMode) {
    await StateStore.connectRemoteDebugging();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  void _incrementCounter() {
    /// Step 5: Use dispatch to update value. All listeners and builders
    /// will be notified/updated
    StateStore.dispatch('counter', StateStore.get('counter') + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),

            /// Step 3: Use state_store builder to handle value changes in the UI
            StateStoreBuilder(
              /// Step 4: Use the value in the builder function
              builder: (context, value) => Text(
                '$value',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              id: 'counter',
            ),
            const SizedBox(height: 20),
            const Text(
              'Random text',
            ),
            const SizedBox(height: 10),
            StateStoreBuilder<String?>(
              id: 'text',
              builder: (context, value) => Text(
                value ?? '',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .apply(color: Colors.amber),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Complex',
            ),
            const SizedBox(height: 10),
            StateStoreBuilder<Complex?>(
              id: 'complex',
              builder: (context, value) => Column(
                children: [
                  Text(
                    value?.id ?? '-',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .apply(color: Colors.amber),
                  ),
                  Text(
                    value?.name ?? '-',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .apply(color: Colors.amber),
                  ),
                  Text(
                    value?.description ?? '-',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .apply(color: Colors.amber),
                  ),
                  Text(
                    value?.numbers.toString() ?? '-',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .apply(color: Colors.amber),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
