class IntGrid {
  final int width;
  final int height;
  final List<int> _cells;

  IntGrid(this.width, this.height, [int fill = 0])
      : assert(width > 0 && height > 0),
        _cells = List<int>.filled(width * height, fill, growable: false);

  IntGrid.fromList(this.width, this.height, List<int> values)
      : assert(values.length == width * height),
        _cells = List<int>.from(values, growable: false);

  int operator [](List<int> pos) => get(pos[0], pos[1]);

  void operator []=(List<int> pos, int value) => set(pos[0], pos[1], value);

  int index(int x, int y) => y * width + x;

  int get(int x, int y) => _cells[index(x, y)];

  void set(int x, int y, int value) => _cells[index(x, y)] = value;

  void fill(int value) {
    for (int i = 0; i < _cells.length; i++) {
      _cells[i] = value;
    }
  }

  IntGrid clone() => IntGrid.fromList(width, height, _cells);

  Iterable<int> get values => _cells;
}

class BoolGrid {
  final int width;
  final int height;
  final List<bool> _cells;

  BoolGrid(this.width, this.height, [bool fill = false])
      : assert(width > 0 && height > 0),
        _cells = List<bool>.filled(width * height, fill, growable: false);

  BoolGrid.fromList(this.width, this.height, List<bool> values)
      : assert(values.length == width * height),
        _cells = List<bool>.from(values, growable: false);

  int index(int x, int y) => y * width + x;

  bool get(int x, int y) => _cells[index(x, y)];

  void set(int x, int y, bool value) => _cells[index(x, y)] = value;

  void fill(bool value) {
    for (int i = 0; i < _cells.length; i++) {
      _cells[i] = value;
    }
  }

  BoolGrid clone() => BoolGrid.fromList(width, height, _cells);

  Iterable<bool> get values => _cells;
}

/// Fixed-size bitset for candidate tracking.
class FixedBitSet {
  final int length;
  int _bits;

  FixedBitSet(this.length, {int initialBits = 0})
      : assert(length > 0 && length <= 64),
        _bits = initialBits & ((1 << length) - 1);

  bool contains(int index) {
    _checkIndex(index);
    return (_bits & (1 << index)) != 0;
  }

  void add(int index) {
    _checkIndex(index);
    _bits |= 1 << index;
  }

  void remove(int index) {
    _checkIndex(index);
    _bits &= ~(1 << index);
  }

  void toggle(int index) {
    _checkIndex(index);
    _bits ^= 1 << index;
  }

  int toInt() => _bits;

  int count() => _countBits(_bits);

  bool get isEmpty => _bits == 0;

  bool get isSingle => _bits != 0 && (_bits & (_bits - 1)) == 0;

  int? singleIndex() {
    if (!isSingle) return null;
    return _bits.bitLength - 1;
  }

  Iterable<int> indices() sync* {
    int remaining = _bits;
    int idx = 0;
    while (remaining != 0) {
      if ((remaining & 1) != 0) {
        yield idx;
      }
      remaining >>= 1;
      idx++;
    }
  }

  void _checkIndex(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index');
    }
  }

  static int _countBits(int value) {
    int v = value;
    int count = 0;
    while (v != 0) {
      v &= v - 1;
      count++;
    }
    return count;
  }
}
