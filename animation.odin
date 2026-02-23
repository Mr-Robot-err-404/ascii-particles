package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"

Coin :: enum {
	Heads,
	Tails,
}
Prefix :: [dynamic]string
Phases :: map[Pos]f16

move :: proc(t: ^Targets, points: ^Points, arrived: ^map[Pos]bool) {
	for target, pos in t {
		if arrived[target] {
			points^[target] = Status.Resting
			continue
		}
		next := walk(target, pos)

		if target == next {
			points^[next] = Status.Resting
			arrived^[next] = true
			continue
		}
		points^[next] = Status.Seeking
		t^[target] = next
	}
}

walk :: proc(target: Pos, pos: Pos) -> Pos {
	dx := dir(target.x, pos.x)
	dy := dir(target.y, pos.y)

	next := Pos {
		x = pos.x + dx,
		y = pos.y + dy,
	}
	return next
}

wave_motion :: proc(
	t: ^Targets,
	points: ^Points,
	arrived: ^map[Pos]bool,
	amplitudes: Amplitudes,
	threshold: i32,
	frequency: f16,
	n: u64,
	phases: Phases,
) {
	for target, pos in t {
		if arrived[target] {
			points^[target] = Status.Resting
			continue
		}
		amp, ok := amplitudes[target]
		if !ok {continue}

		next := wave_step(target, pos, amp, frequency, n, threshold, phases)
		if target == next {
			points^[next] = Status.Resting
			arrived^[next] = true
			continue
		}
		points^[next] = Status.Seeking
		t^[target] = next
	}
}

wave_step :: proc(
	target: Pos,
	pos: Pos,
	amp: f16,
	frequency: f16,
	frame: u64,
	threshold: i32,
	phases: Phases,
) -> Pos {
	if within_threshold(target, pos, threshold) {
		return walk(target, pos)
	}
	return oscillate(pos, target, amp, frequency, frame, phases)
}

within_threshold :: proc(target: Pos, pos: Pos, threshold: i32) -> bool {
	x := math.abs(target.x - pos.x)
	return x < threshold
}

calc_distance :: proc(target: Pos, pos: Pos) -> (f16, f16, f16) {
	dx := f16(target.x - pos.x)
	dy := f16(target.y - pos.y)
	return math.sqrt(dx * dx + dy * dy), dx, dy
}

oscillate :: proc(
	pos: Pos,
	target: Pos,
	amplitude: f16,
	frequency: f16,
	frame: u64,
	phases: Phases,
) -> Pos {
	distance, dx, dy := calc_distance(target, pos)
	norm_x := dx / distance
	norm_y := dy / distance

	next_x := f16(pos.x) + norm_x
	next_y := f16(pos.y) + norm_y

	perp_x := norm_y * -1
	perp_y := norm_x

	disp_x := math.sin(frequency * f16(frame) + phases[target]) * amplitude * perp_x
	disp_y := math.sin(frequency * f16(frame) + phases[target]) * amplitude * perp_y

	return Pos{x = i32(next_x + disp_x), y = i32(next_y + disp_y)}
}

rain :: proc(points: Points, targets: ^Targets) {
	for pos in points {
		targets^[pos] = Pos {
			x = pos.x,
			y = pos.y + rnd_y_offset(100),
		}
	}
}

swoop :: proc(
	points: Points,
	targets: ^Targets,
	y_midpoint: i32,
	phases: ^Phases,
	amplitude: f16,
) {

	for t in points {
		offset := rnd_y_offset(5)
		y := y_midpoint - i32(amplitude) + offset
		phase: f16 = 0

		if coin_flip() == Coin.Heads {
			y = y_midpoint + i32(amplitude) + offset
			phase = math.PI
		}
		start := Pos {
			x = t.x + 100 + rnd_x_offset(5),
			y = y,
		}
		phases^[t] = phase
		targets^[t] = start
	}
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
