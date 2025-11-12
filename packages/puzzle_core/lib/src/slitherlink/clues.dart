import 'dart:typed_data';

List<int> deriveClues({
  required Uint8List colors,
  required int width,
  required int height,
  required int stride,
}) {
  final List<int> clues = List<int>.filled(width * height, 0);
  for (int row = 0; row < height; row++) {
    for (int col = 0; col < width; col++) {
      final int center = colors[(row + 1) * stride + (col + 1)];
      int count = 0;
      if (colors[row * stride + (col + 1)] != center) {
        count++;
      }
      if (colors[(row + 2) * stride + (col + 1)] != center) {
        count++;
      }
      if (colors[(row + 1) * stride + col] != center) {
        count++;
      }
      if (colors[(row + 1) * stride + (col + 2)] != center) {
        count++;
      }
      clues[row * width + col] = count;
    }
  }
  return clues;
}
