import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('Seed hashing', () {
    test('Seed.fromString is deterministic', () {
      const String seed = 'nonogram_2024_01_15';
      final int first = Seed.fromString(seed);
      final int second = Seed.fromString(seed);
      expect(first, equals(second));
    });

    test('Different strings map to different seeds when possible', () {
      final int a = Seed.fromString('alpha');
      final int b = Seed.fromString('beta');
      expect(a, isNot(equals(b)));
    });
  });

  group('xoroshiro128** RNG', () {
    test('same seed yields identical sequence', () {
      final SeededRng rngA = SeededRng(123456789);
      final SeededRng rngB = SeededRng(123456789);
      final List<int> seqA = List<int>.generate(10, (_) => rngA.nextInt64());
      final List<int> seqB = List<int>.generate(10, (_) => rngB.nextInt64());
      expect(seqA, equals(seqB));
      expect(
        seqA,
        equals(<int>[
          5784055621119223165,
          13481066351989560381,
          6257555476624109895,
          3781425647217463804,
          2452682545138275971,
          13688970479100395312,
          2145774650571516026,
          17062167744504095323,
          9354540691832391570,
          6699895782966430949,
        ]),
      );
    });

    test('bounded random numbers are deterministic', () {
      final SeededRng rng = SeededRng(42);
      final List<int> values = List<int>.generate(8, (_) => rng.nextIntInRange(17));
      expect(values, equals(<int>[10, 16, 5, 12, 9, 0, 0, 3]));
    });

    test('shuffleDeterministic preserves determinism', () {
      final SeededRng rng = SeededRng(1001);
      final List<int> list = <int>[1, 2, 3, 4, 5];
      shuffleDeterministic(rng, list);
      expect(list, equals(<int>[3, 5, 2, 4, 1]));
    });

    test('pickWeighted respects weights deterministically', () {
      final SeededRng rng = SeededRng(987654321);
      final List<String> choices = <String>['a', 'b', 'c'];
      final List<int> weights = <int>[1, 3, 6];
      final List<String> picked = <String>[];
      for (int i = 0; i < 5; i++) {
        picked.add(pickWeighted(rng, choices, weights));
      }
      expect(picked, equals(<String>['c', 'c', 'b', 'c', 'c']));
    });
  });
}
