package main

import "core:fmt"
import "core:os"

main :: proc() {
	if len(os.args) != 2 {
		fmt.printf("usage: pibbl <path-to-rom>")
		os.exit(1)
	}

	rom, err := os.read_entire_file_or_err(os.args[1])
	if err != nil {
		fmt.printf("i/o error: %s\n", err)
		os.exit(1)
	}
	defer delete(rom)

	emulator: Emulator
	emulator_init(&emulator, rom)

	if err := execute(&emulator); err != nil {
		fmt.printf("emulator error: %s\n", err)
		os.exit(1)
	}
}
