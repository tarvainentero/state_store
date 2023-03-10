import 'package:flutter_test/flutter_test.dart';

import 'package:state_store/state_store.dart';

void main() {
  test('adds one to input values', () {
    StateStore.dispatch('counter', 0);
    expect(StateStore.get('calculator'), 0);
  });
}
