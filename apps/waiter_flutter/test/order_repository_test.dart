import 'package:flutter_test/flutter_test.dart';
import 'package:waiter_flutter/features/orders/order_repository.dart';

void main() {
  test('order line uses backend item keys and preserves modifiers', () {
    final line = OrderLine(
      productId: 'PLATO-12',
      name: 'Arroz chaufa',
      quantity: 2,
      note: 'Sin cebolla',
      modifiers: {3, 7},
    );

    expect(line.toRequestJson(), {
      'id_producto': 'PLATO-12',
      'cantidad': 2,
      'prioridad': 'NORMAL',
      'nota': 'Sin cebolla',
      'modificadores': [3, 7],
    });
  });
}
