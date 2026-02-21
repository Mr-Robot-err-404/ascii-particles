package main

import "core:fmt"
import "core:os"

Logger :: struct {
	handle:  os.Handle,
	enabled: bool,
}
Path := "render.log"

log_init :: proc(enabled: bool) -> Logger {
	if !enabled {return Logger{}}

	handle, err := os.open(Path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
	if err != 0 {
		return Logger{}
	}
	return Logger{handle = handle, enabled = true}
}

log_map :: proc(logger: ^Logger, m: map[Pos]rune) {
	for pos, value in m {
		msg(logger, fmt.aprintf("%d:%d %c", pos.x, pos.y, value))
	}
}

digit :: proc(logger: ^Logger, n: i32) {
	if !logger.enabled {
		return
	}
	data := fmt.tprintf("%d\n", n)
	os.write_string(logger.handle, data)
}

msg :: proc(logger: ^Logger, msg: string) {
	if !logger.enabled {
		return
	}
	data := fmt.tprintf("%s\n", msg)
	os.write_string(logger.handle, data)
}

log_close :: proc(logger: ^Logger) {
	if logger.enabled {
		os.close(logger.handle)
	}
}
