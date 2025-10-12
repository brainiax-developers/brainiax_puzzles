class DisjointSetUnion {
  final List<int> _parent;
  final List<int> _size;

  DisjointSetUnion(int n)
      : assert(n > 0),
        _parent = List<int>.generate(n, (int i) => i, growable: false),
        _size = List<int>.filled(n, 1, growable: false);

  int find(int x) {
    if (_parent[x] != x) {
      _parent[x] = find(_parent[x]);
    }
    return _parent[x];
  }

  bool union(int a, int b) {
    int rootA = find(a);
    int rootB = find(b);
    if (rootA == rootB) {
      return false;
    }
    if (_size[rootA] < _size[rootB]) {
      final int temp = rootA;
      rootA = rootB;
      rootB = temp;
    }
    _parent[rootB] = rootA;
    _size[rootA] += _size[rootB];
    return true;
  }

  bool connected(int a, int b) => find(a) == find(b);

  int componentSize(int x) => _size[find(x)];
}
