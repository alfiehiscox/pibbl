package main

import "core:fmt"
import "core:mem"
import "core:os"

/**
Running: 

odin run . -- ../roms/SuperMarioLand.gb

**/

main :: proc() {
	default := context.allocator
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, default)
	defer mem.tracking_allocator_destroy(&tracking_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer print_memory_usage(&tracking_allocator)

	if len(os.args) < 2 {
		fmt.printf("Usage: decomp <file>\n")
		os.exit(1)
	}

	fd, err := os.open(os.args[1])
	if err != nil {
		fmt.printf("Err: %v\n", err)
		os.exit(1)
	}
	defer os.close(fd)

	first_100: [100]byte
	if _, err := os.read(fd, first_100[:]); err != nil {
		fmt.printf("Err: %v\n", err)
		os.exit(1)
	}

	fmt.printfln(">>> First 100 Bytes: %s", os.args[1])
	for i in 0 ..< len(first_100) {
		fmt.printf("%X ", first_100[i])
	}
	fmt.println("\n<<< First 100 Bytes")
}
