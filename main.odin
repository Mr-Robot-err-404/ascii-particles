package main

import "core:fmt"
import "core:os"
import "core:strings"


Pos :: struct {
	x: i32,
	y: i32,
}
Dimensions :: struct {
	width:  i32,
	height: i32,
}
Cells :: map[Pos]rune

Base: rune = '\U00002800'
Full: rune = '\U000028FF'

main :: proc() {
	term_dm, ok := dimensions()
	if !ok {
		fmt.eprintln("Failed to get terminal size")
		os.exit(1)
	}
	l := log_init(false)
	defer log_close(&l)

	cells, screen_dm := read_file_by_lines("simple.txt")
	screen_dm.width = term_dm.width
	size := screen_dm.width * screen_dm.height

	frame := make([]rune, size)
	fill(&frame)

	dm := Dimensions {
		width  = screen_dm.width * 2,
		height = screen_dm.height * 4,
	}
	bitmap, braille := get_bitmap()
	points := make(map[Pos]bool)

	cells_to_points(cells, bitmap, &points)
	points_to_cells(points, &cells, braille)

	cells_to_frame(cells, &frame, screen_dm.width)
	render(frame, screen_dm)
}

cells_to_frame :: proc(cells: Cells, frame: ^[]rune, width: i32) {
	for pos, ascii in cells {
		idx := frame_idx(pos, width)
		frame^[idx] = ascii
	}
}

points_to_cells :: proc(points: map[Pos]bool, cells: ^Cells, offset: OffsetMap) {
	for p in cells {
		delete_key(cells, p)
	}
	for pos in points {
		sub_pos := Pos {
			x = pos.x % 2,
			y = pos.y % 4,
		}
		b, ok := offset[sub_pos]
		if !ok {continue}

		screen_pos := Pos {
			x = pos.x / 2,
			y = pos.y / 4,
		}
		r, okay := cells^[screen_pos]
		if !okay {
			r = Base
		}
		bits := braille_to_byte(r)
		bits |= b
		cells^[screen_pos] = Base + rune(bits)
	}
}

frame_idx :: proc(cell: Pos, width: i32) -> i32 {
	return cell.y * width + cell.x
}

fill :: proc(frame: ^[]rune) {
	for i in 0 ..< len(frame) {
		frame^[i] = ' '
	}
}

braille_to_byte :: proc(r: rune) -> byte {
	return byte(r - Base)
}
is_braille :: proc(r: rune) -> bool {
	return r > Base && r <= Full
}
cells_to_points :: proc(cells: Cells, bitmap: Bitmap, points: ^map[Pos]bool) {
	for pos, value in cells {
		b := braille_to_byte(value)

		for i: u8 = 0; i < 8; i += 1 {
			bit: u8 = 1 << i

			v := b & bit
			if v == 0 {continue}

			point, ok := bitmap[bit]
			if !ok {continue}

			p := Pos {
				x = (pos.x * 2) + point.x,
				y = (pos.y * 4) + point.y,
			}
			points^[p] = true
		}
	}
}

render :: proc(frame: []rune, dm: Dimensions) {
	builder: strings.Builder
	defer delete(builder.buf)

	for y: i32 = 0; y < dm.height; y += 1 {
		for x: i32 = 0; x < dm.width; x += 1 {
			i := frame_idx(Pos{x = x, y = y}, dm.width)
			strings.write_rune(&builder, frame[i])
		}
		strings.write_rune(&builder, '\n')
	}
	fmt.print(strings.to_string(builder))
}

read_file_by_lines :: proc(filepath: string) -> (Cells, Dimensions) {
	data, ok := os.read_entire_file(filepath, context.allocator)
	if !ok {
		fmt.panicf("Failed to read file: %s", filepath)
	}
	cells := make(Cells)

	dm := Dimensions{}
	row: i32 = 0

	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		defer row += 1
		dm.height += 1

		w: i32 = 0
		col: i32 = 0

		for r in line {
			if !is_braille(r) && r != ' ' {
				col += 1
				continue
			}
			w += 1
			if is_braille(r) {
				pos := Pos {
					x = col,
					y = row,
				}
				cells[pos] = r
			}
			if w > dm.width {dm.width = w}
			col += 1
		}
	}
	return cells, dm
}
