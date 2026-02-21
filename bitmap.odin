package main

// bit layout for a braille cell
// ┌───┬───┐
// │ 1 │ 4 │
// ├───┼───┤
// │ 2 │ 5 │
// ├───┼───┤
// │ 3 │ 6 │
// ├───┼───┤
// │ 7 │ 8 │
// └───┴───┘

Bitmap :: map[byte]Pos
OffsetMap :: map[Pos]byte

get_bitmap :: proc() -> (Bitmap, OffsetMap) {
	bitmap := make(Bitmap)
	offset := make(OffsetMap)

	points := [8]Pos {
		{x = 0, y = 0},
		{x = 0, y = 1},
		{x = 0, y = 2},
		{x = 1, y = 0},
		{x = 1, y = 1},
		{x = 1, y = 2},
		{x = 0, y = 3},
		{x = 1, y = 3},
	}
	for i: u8 = 0; i < len(points); i += 1 {
		pos := points[i]
		b: u8 = 1 << i
		bitmap[b] = pos
		offset[pos] = b
	}
	return bitmap, offset
}
