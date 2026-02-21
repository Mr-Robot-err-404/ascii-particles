package main

import "core:testing"

@(test)
test_braille_points :: proc(t: ^testing.T) {
	bitmap, _ := get_bitmap()
	b := braille_to_byte('\U000028FF')
	count := 0

	for i: u8 = 0; i < 8; i += 1 {
		bit: u8 = 1 << i
		v := b & bit

		if v == 0 {
			continue
		}
		_, ok := bitmap[bit]
		if ok {count += 1}
	}
	testing.expectf(t, count == 8, "Full braille should find 8 points, got %d", count)
}
