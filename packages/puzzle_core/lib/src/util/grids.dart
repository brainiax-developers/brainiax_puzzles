/// A 2D grid of integers with efficient 1D storage and 2D indexing.
/// 
/// This class provides a memory-efficient way to store and access 2D integer data.
/// It uses a single 1D list internally and converts 2D coordinates to 1D indices.
/// 
/// Example usage:
/// ```dart
/// final grid = IntGrid(3, 3, fill: 0);
/// grid.set(1, 1, 42);
/// print(grid.get(1, 1)); // 42
/// 
/// // Using operator syntax
/// grid[[2, 0]] = 99;
/// print(grid[[2, 0]]); // 99
/// ```
class IntGrid {
  /// The width of the grid.
  final int width;
  
  /// The height of the grid.
  final int height;
  
  /// Internal 1D storage for the grid cells.
  final List<int> _cells;

  /// Creates a new IntGrid with the specified dimensions.
  /// 
  /// [width] and [height] must be positive integers.
  /// [fill] is the initial value for all cells (defaults to 0).
  IntGrid(this.width, this.height, [int fill = 0])
      : assert(width > 0 && height > 0),
        _cells = List<int>.filled(width * height, fill, growable: false);

  /// Creates a new IntGrid from an existing list of values.
  /// 
  /// [values] must have exactly [width] * [height] elements.
  IntGrid.fromList(this.width, this.height, List<int> values)
      : assert(values.length == width * height),
        _cells = List<int>.from(values, growable: false);

  /// Gets the value at the specified position using operator syntax.
  /// 
  /// [pos] must be a list of exactly 2 elements [x, y].
  int operator [](List<int> pos) {
    if (pos.length != 2) {
      throw ArgumentError('Position must be a list of exactly 2 elements [x, y]');
    }
    return get(pos[0], pos[1]);
  }

  /// Sets the value at the specified position using operator syntax.
  /// 
  /// [pos] must be a list of exactly 2 elements [x, y].
  void operator []=(List<int> pos, int value) {
    if (pos.length != 2) {
      throw ArgumentError('Position must be a list of exactly 2 elements [x, y]');
    }
    set(pos[0], pos[1], value);
  }

  /// Converts 2D coordinates to 1D index.
  int index(int x, int y) => y * width + x;

  /// Gets the value at the specified coordinates.
  /// 
  /// Throws [RangeError] if coordinates are out of bounds.
  int get(int x, int y) {
    _checkBounds(x, y);
    return _cells[index(x, y)];
  }

  /// Sets the value at the specified coordinates.
  /// 
  /// Throws [RangeError] if coordinates are out of bounds.
  void set(int x, int y, int value) {
    _checkBounds(x, y);
    _cells[index(x, y)] = value;
  }

  void _checkBounds(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      throw RangeError('Position ($x, $y) out of bounds for ${width}x$height grid');
    }
  }

  /// Fills all cells with the specified value.
  void fill(int value) {
    for (int i = 0; i < _cells.length; i++) {
      _cells[i] = value;
    }
  }

  /// Creates a deep copy of this grid.
  IntGrid clone() => IntGrid.fromList(width, height, _cells);

  /// Returns an iterable over all cell values.
  Iterable<int> get values => _cells;
}

/// A 2D grid of boolean values with efficient 1D storage and 2D indexing.
/// 
/// This class provides a memory-efficient way to store and access 2D boolean data.
/// It uses a single 1D list internally and converts 2D coordinates to 1D indices.
/// 
/// Example usage:
/// ```dart
/// final grid = BoolGrid(3, 3, fill: false);
/// grid.set(1, 1, true);
/// print(grid.get(1, 1)); // true
/// ```
class BoolGrid {
  /// The width of the grid.
  final int width;
  
  /// The height of the grid.
  final int height;
  
  /// Internal 1D storage for the grid cells.
  final List<bool> _cells;

  BoolGrid(this.width, this.height, [bool fill = false])
      : assert(width > 0 && height > 0),
        _cells = List<bool>.filled(width * height, fill, growable: false);

  BoolGrid.fromList(this.width, this.height, List<bool> values)
      : assert(values.length == width * height),
        _cells = List<bool>.from(values, growable: false);

  int index(int x, int y) => y * width + x;

  bool get(int x, int y) {
    _checkBounds(x, y);
    return _cells[index(x, y)];
  }

  void set(int x, int y, bool value) {
    _checkBounds(x, y);
    _cells[index(x, y)] = value;
  }

  void _checkBounds(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      throw RangeError('Position ($x, $y) out of bounds for ${width}x$height grid');
    }
  }

  void fill(bool value) {
    for (int i = 0; i < _cells.length; i++) {
      _cells[i] = value;
    }
  }

  BoolGrid clone() => BoolGrid.fromList(width, height, _cells);

  Iterable<bool> get values => _cells;
}

/// A fixed-size bitset for efficient candidate tracking in constraint solving.
/// 
/// This class provides a memory-efficient way to track which values are possible
/// for a given variable in constraint satisfaction problems. It uses bit manipulation
/// for fast operations and can handle up to 64 candidates.
/// 
/// Example usage:
/// ```dart
/// final candidates = FixedBitSet(9); // For digits 0-8
/// candidates.add(3);
/// candidates.add(7);
/// print(candidates.contains(3)); // true
/// print(candidates.count()); // 2
/// print(candidates.isSingle); // false
/// 
/// candidates.remove(3);
/// print(candidates.isSingle); // true
/// print(candidates.singleIndex()); // 7
/// ```
class FixedBitSet {
  /// The maximum number of candidates (must be <= 64).
  final int length;
  
  /// Internal bit storage.
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
