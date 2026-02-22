package main

import "core:fmt"
import "core:math/rand"
import "core:strings"

Coin :: enum {
	Heads,
	Tails,
}
Prefix :: [dynamic]string

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

rain :: proc(points: Points) -> Targets {
	t := make(Targets)

	for pos in points {
		t[pos] = Pos {
			x = pos.x,
			y = pos.y + rnd_y_offset(100),
		}
	}
	return t
}

rnd_y_offset :: proc(range: i32) -> i32 {
	n := rand.int31_max(range)
	if coin_flip() == Coin.Heads {return n}
	return n * -1
}

rnd_x_offset :: proc(range: i32) -> i32 {
	return rand.int31_max(range)
}

coin_flip :: proc() -> Coin {
	n := rand.int31_max(2)
	if n == 1 {return Coin.Heads}
	return Coin.Tails
}

render_prefix :: proc(prefix: Prefix) {
	builder: strings.Builder
	defer delete(builder.buf)

	for s in prefix {
		fmt.println(s)
	}
}

mv_up :: proc(n: i32) -> string {
	return fmt.aprintf("\033[%dA", n)
}
mv_right :: proc(n: i32) -> string {
	return fmt.aprintf("\033[%dC", n)
}

render :: proc(frame: []rune, dm: Dimensions, x_offset: i32) {
	builder: strings.Builder
	defer delete(builder.buf)

	strings.write_string(&builder, mv_up(dm.height))
	for y: i32 = 0; y < dm.height; y += 1 {
		if x_offset > 0 {strings.write_string(&builder, mv_right(x_offset))}

		for x: i32 = 0; x < dm.width; x += 1 {
			size := i32(len(frame))
			i := frame_idx(Pos{x = x, y = y}, dm.width, size)
			strings.write_rune(&builder, frame[i])
		}
		strings.write_rune(&builder, '\n')
	}
	fmt.print(strings.to_string(builder))
}
