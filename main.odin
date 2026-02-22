package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"


Pos :: struct {
	x: i32,
	y: i32,
}
Dimensions :: struct {
	width:  i32,
	height: i32,
}
Cells :: map[Pos]rune
Targets :: map[Pos]Pos
Points :: map[Pos]bool

Base: rune = '\U00002800'
Full: rune = '\U000028FF'

FPS: i64 = 60

main :: proc() {
	term_dm, ok := dimensions()
	if !ok {
		fmt.eprintln("Failed to get terminal size")
		os.exit(1)
	}
	l := log_init(true)
	defer log_close(&l)

	cells, screen_dm := read_file_by_lines("logo.txt", &l)
	screen_dm.width = term_dm.width
	size := screen_dm.width * screen_dm.height

	frame := make([]rune, size)

	set_cursor(false)
	defer set_cursor(true)

	dm := Dimensions {
		width  = screen_dm.width * 2,
		height = screen_dm.height * 4,
	}
	bitmap, braille := get_bitmap()
	points := make(Points)

	cells_to_points(cells, bitmap, &points)
	targets := make_targets(points)

	points_to_cells(points, &cells, braille)
	cells_to_frame(cells, &frame, screen_dm.width)
	render(frame, screen_dm, true)

	c := 0
	interval := time.Second / time.Duration(FPS)

	for c < 40 {
		defer c += 1
		clear_cells(&cells)
		clear_points(&points)
		fill(&frame)

		move(&targets, &points)
		points_to_cells(points, &cells, braille)
		cells_to_frame(cells, &frame, screen_dm.width)

		render(frame, screen_dm, false)
		time.sleep(interval)
	}
}

move :: proc(t: ^Targets, points: ^Points) {
	for target, pos in t {
		x := dir(target.x, pos.x)
		y := dir(target.y, pos.y)
		next := Pos {
			x = pos.x + x,
			y = pos.y + y,
		}
		t^[target] = next
		points^[next] = true
	}
}

dir :: proc(target: i32, source: i32) -> i32 {
	diff := target - source

	if diff == 0 {
		return 0
	}
	if diff > 0 {
		return 1
	}
	return -1
}

make_targets :: proc(points: Points) -> Targets {
	t := make(Targets)

	for pos in points {
		t[pos] = Pos {
			x = pos.x + 50,
			y = pos.y,
		}
	}
	return t
}

cells_to_frame :: proc(cells: Cells, frame: ^[]rune, width: i32) {
	for pos, ascii in cells {
		idx := frame_idx(pos, width)
		frame^[idx] = ascii
	}
}

points_to_cells :: proc(points: map[Pos]bool, cells: ^Cells, offset: OffsetMap) {
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
clear_cells :: proc(cells: ^Cells) {
	for p in cells {
		delete_key(cells, p)
	}
}
clear_points :: proc(points: ^Points) {
	for p in points {
		delete_key(points, p)
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

render :: proc(frame: []rune, dm: Dimensions, first_frame: bool) {
	if !first_frame {
		fmt.printf("\033[%dA", dm.height)
	}
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

read_file_by_lines :: proc(filepath: string, l: ^Logger) -> (Cells, Dimensions) {
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
			if !is_braille(r) && r != ' ' && r != Base {
				msg(l, fmt.tprintf("Non-braille/space rune: %#v (U+%04X)\n", r, r))
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

set_cursor :: proc(show: bool) {
	if show {
		fmt.print("\x1b[?25h")
		return
	}
	fmt.print("\x1b[?25l")
}
