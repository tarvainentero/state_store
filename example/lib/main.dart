import 'package:flutter/material.dart';
import 'package:state_store/state_store.dart';

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

  /// Step 2
  /// Use import to fetch all persisted values
  await StateStore.import();

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
                style: Theme.of(context).textTheme.headline4,
              ),
              id: 'counter',
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
