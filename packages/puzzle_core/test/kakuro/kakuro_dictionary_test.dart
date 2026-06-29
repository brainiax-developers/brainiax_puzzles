import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('KakuroDictionary', () {
    test('Combinations for L=2, S=3', () {
      final dict = KakuroDictionary.instance;
      final combs = dict.getCombinations(2, 3);
      expect(combs, isNotNull);
      expect(combs!.length, equals(1)); // Only {1, 2}
      
      // 1 (bit 0) and 2 (bit 1) -> mask is 1 | 2 = 3
      expect(combs.first, equals(3));
      
      expect(dict.getAmbiguity(2, 3), equals(1));
    });

    test('Combinations for L=2, S=4', () {
      final dict = KakuroDictionary.instance;
      final combs = dict.getCombinations(2, 4);
      expect(combs, isNotNull);
      expect(combs!.length, equals(1)); // Only {1, 3}
      
      // 1 (bit 0) and 3 (bit 2) -> mask is 1 | 4 = 5
      expect(combs.first, equals(5));
    });
    
    test('Impossible combinations return null', () {
      final dict = KakuroDictionary.instance;
      // L=2, min sum is 3. Sum=2 is impossible
      expect(dict.getCombinations(2, 2), isNull);
      
      // L=9, sum must be 45
      expect(dict.getCombinations(9, 44), isNull);
      expect(dict.getCombinations(9, 46), isNull);
      expect(dict.getCombinations(9, 45), isNotNull);
    });

    test('Combinations for L=3, S=6', () {
      final dict = KakuroDictionary.instance;
      final combs = dict.getCombinations(3, 6);
      expect(combs, isNotNull);
      expect(combs!.length, equals(1)); // {1, 2, 3}
    });

    test('Ambiguity count is correct', () {
      final dict = KakuroDictionary.instance;
      // L=2, S=10 has combinations: {1,9}, {2,8}, {3,7}, {4,6} -> 4 combinations
      final combs = dict.getCombinations(2, 10);
      expect(combs!.length, equals(4));
      expect(dict.getAmbiguity(2, 10), equals(4));
    });
  });
}
