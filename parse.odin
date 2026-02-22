package main

import "core:fmt"
import "core:os"
import "core:strings"

read_file_by_lines :: proc(
	filepath: string,
	l: ^Logger,
	offset: i32,
) -> (
	Cells,
	Dimensions,
	Prefix,
) {
	data, ok := os.read_entire_file(filepath, context.allocator)
	if !ok {
		fmt.panicf("Failed to read file: %s", filepath)
	}
	cells := make(Cells)
	prefix := make(Prefix)

	dm := Dimensions{}
	row: i32 = 0

	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		defer row += 1
		dm.height += 1

		w: i32 = 0
		col: i32 = 0
		p := ""

		for r, i in line {
			if !is_braille(r) && r != ' ' && r != Base {
				msg(l, fmt.tprintf("Non-braille/space rune: %#v (U+%04X)\n", r, r))
				continue
			}
			if col == offset {
				p = line[0:i]
			}
			w += 1
			if is_braille(r) && col >= offset {
				pos := Pos {
					x = col - offset,
					y = row,
				}
				cells[pos] = r
			}
			if w > dm.width {dm.width = w}
			col += 1
		}
		append(&prefix, p)
	}
	return cells, dm, prefix
}
