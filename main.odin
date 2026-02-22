package main

import "core:fmt"
import "core:os"
import "core:time"

Pos :: struct {
	x: i32,
	y: i32,
}
Dimensions :: struct {
	width:  i32,
	height: i32,
}
Status :: enum {
	Seeking,
	Resting,
}

Cells :: map[Pos]rune
Targets :: map[Pos]Pos
Points :: map[Pos]Status

Base: rune = '\U00002800'
Full: rune = '\U000028FF'

FPS: i64 = 120

main :: proc() {
	term_dm, ok := dimensions()
	if !ok {
		fmt.eprintln("Failed to get terminal size")
		os.exit(1)
	}
	l := log_init(true)
	defer log_close(&l)

	x_offset: i32 = 20
	cells, screen_dm, prefix := read_file_by_lines("logo.txt", &l, x_offset)

	screen_dm.width = term_dm.width - x_offset
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
	targets := make(Targets)
	arrived := make(map[Pos]bool)

	cells_to_points(cells, bitmap, &points)
	// shoot_in(points, &targets)
	rain(points, &targets)

	interval := time.Second / time.Duration(FPS)
	render_prefix(prefix)

	for len(targets) > len(arrived) {
		clear_cells(&cells)
		clear_points(&points)
		fill(&frame)

		move(&targets, &points, &arrived)
		points_to_cells(points, &cells, braille)
		cells_to_frame(cells, &frame, screen_dm)

		render(frame, screen_dm, x_offset)
		time.sleep(interval)
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

out_of_bounds :: proc(pos: Pos, width, height: i32) -> bool {
	if pos.x < 0 || pos.y < 0 {return true}
	if pos.x >= width || pos.y >= height {return true}
	return false
}

cells_to_frame :: proc(cells: Cells, frame: ^[]rune, screen_dm: Dimensions) {
	for pos, ascii in cells {
		if out_of_bounds(pos, screen_dm.width, screen_dm.height) {continue}
		size := i32(len(frame))
		idx := frame_idx(pos, screen_dm.width, size)
		frame^[idx] = ascii
	}
}

points_to_cells :: proc(points: Points, cells: ^Cells, offset: OffsetMap) {
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
	for p, status in points {
		delete_key(points, p)
	}
}

frame_idx :: proc(cell: Pos, width: i32, size: i32) -> i32 {
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
cells_to_points :: proc(cells: Cells, bitmap: Bitmap, points: ^Points) {
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
			points^[p] = Status.Seeking
		}
	}
}

set_cursor :: proc(show: bool) {
	if show {
		fmt.print("\x1b[?25h")
		return
	}
	fmt.print("\x1b[?25l")
}
