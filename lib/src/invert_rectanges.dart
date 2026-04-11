import 'dart:ui';

/// Given bounds and a set of rectangles, returns a set of non-overlapping
/// rectangles that covers the area not covered by original rectangles.
List<Rect> invert(Rect bounds, Iterable<Rect> rectangles) {
  final clipped = rectangles
      .map((r) => r.intersect(bounds))
      .where((r) => r.width > 0 && r.height > 0)
      .toList();

  if (clipped.isEmpty) return [bounds];

  clipped.sort(
    (a, b) =>
        a.top != b.top ? a.top.compareTo(b.top) : a.left.compareTo(b.left),
  );

  final ys = <double>{bounds.top, bounds.bottom};
  for (final r in clipped) {
    ys.add(r.top);
    ys.add(r.bottom);
  }
  final yList = ys.toList()..sort();

  final result = <Rect>[];
  // Active rects that overlap the current band.
  final active = <Rect>[];
  int nextRect = 0;

  for (int i = 0; i < yList.length - 1; i++) {
    final bandTop = yList[i];
    final bandBottom = yList[i + 1];

    // Mark rects that ended at or before bandTop.
    // They will be pushed to the end during sorting and removed after.
    for (int i = 0; i < active.length; ++i) {
      if (active[i].bottom <= bandTop) {
        active[i] = const Rect.fromLTWH(double.maxFinite, 0, 0, 0);
      }
    }

    while (nextRect < clipped.length && clipped[nextRect].top <= bandTop) {
      active.add(clipped[nextRect++]);
    }
    active.sort((a, b) => a.left.compareTo(b.left));

    double x = bounds.left;
    for (final (int index, Rect r) in active.indexed) {
      if (r.left == double.maxFinite) {
        active.removeRange(index, active.length);
        break;
      }
      if (r.left > x) {
        result.add(Rect.fromLTRB(x, bandTop, r.left, bandBottom));
      }
      if (r.right > x) x = r.right;
    }
    if (x < bounds.right) {
      result.add(Rect.fromLTRB(x, bandTop, bounds.right, bandBottom));
    }
  }

  return result;
}
