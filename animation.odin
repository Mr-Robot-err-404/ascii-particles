package main

import "core:math/rand"

Coin :: enum {
	Heads,
	Tails,
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
