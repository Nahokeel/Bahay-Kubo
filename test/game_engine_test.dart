import 'package:flutter_test/flutter_test.dart';
import 'package:bahay_kubo/game_engine.dart';

void main() {
  test('correct swipe increases score and coins', () {
    final engine = GameEngine();
    engine.currentItem = SpawnItem(type: ItemType.fruit, name: 'Mango');
    final startScore = engine.score;
    final startCoins = engine.coins;
    final startTime = engine.timeLeft;
    engine.running = true;
    engine.swipeRight();
    expect(engine.score, greaterThanOrEqualTo(startScore + 1));
    expect(engine.coins, greaterThanOrEqualTo(startCoins + 1));
    expect(engine.timeLeft, greaterThan(startTime));
  });

  test('incorrect swipe penalizes time', () {
    final engine = GameEngine();
    engine.currentItem = SpawnItem(type: ItemType.vegetable, name: 'Okra');
    final startScore = engine.score;
    final startTime = engine.timeLeft;
    engine.running = true;
    engine.swipeRight(); // wrong
    expect(engine.score, lessThanOrEqualTo(startScore));
    expect(engine.timeLeft, lessThan(startTime));
  });
}
