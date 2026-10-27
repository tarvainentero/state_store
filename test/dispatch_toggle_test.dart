import 'package:flutter_test/flutter_test.dart';
import 'package:state_store/state_store.dart';

void main() {
  tearDown(StateStore.dispose);

  test('toggles a bool value and notifies listeners', () {
    StateStore.setUp<bool>('flag', false);
    bool? received;
    StateStore.addListener('flag', (id, value, ctx) => received = value);

    StateStore.dispatchToggle('flag');

    expect(StateStore.get<bool>('flag'), isTrue);
    expect(received, isTrue);
  });

  test('throws an assertion for an unknown id', () {
    expect(() => StateStore.dispatchToggle('missing'),
        throwsA(isA<AssertionError>()));
  });

  test('throws an assertion for a non-bool value', () {
    StateStore.setUp<int>('count', 0);
    expect(() => StateStore.dispatchToggle('count'),
        throwsA(isA<AssertionError>()));
    expect(StateStore.get<int>('count'), 0);
  });
}
