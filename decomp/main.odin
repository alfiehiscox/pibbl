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

	if rerr := run(first_100[:]); err != nil {
		fmt.printf("Err: %v\n", err)
		os.exit(1)
	}
}

Decomp_Error :: enum {
	None = 0,
	EOF,
}

run :: proc(input: []byte) -> Decomp_Error {
	decomp := Decomp {
		data = input,
		idx  = 0,
	}

	for b in next(&decomp) {
		switch b {
		case 0x00:
			fmt.println("nop")
		case 0x10:
			reg := next_u8(&decomp) or_return
			fmt.println("STOP n8 (%d)\n", reg)
		case 0x20:
			reg := next_u8(&decomp) or_return
			fmt.println("JR NZ, e8 (%d)\n", reg)
		case 0x30:
			reg := next_u8(&decomp) or_return
			fmt.println("JR NC, e8 (%d)\n", reg)
		case 0x40:
			fmt.println("LD B, B")
		case 0x50:
			fmt.println("LD D, B")
		case 0x60:
			fmt.println("LD H, B")
		case 0x70:
			fmt.println("LD [HL], B")

		case 0x01:
			memaddrs := next_u16(&decomp) or_return
			fmt.printf("LD BC, n16 (%d)\n", memaddrs)
		case 0x11:
			memaddrs := next_u16(&decomp) or_return
			fmt.printf("LD DE, n16 (%d)\n", memaddrs)
		case 0x21:
			memaddrs := next_u16(&decomp) or_return
			fmt.printf("LD HL, n16 (%d)\n", memaddrs)
		case 0x31:
			memaddrs := next_u16(&decomp) or_return
			fmt.printf("LD SP, n16 (%d)\n", memaddrs)
		case 0x41:
			fmt.println("LD B, C")
		case 0x51:
			fmt.println("LD D, C")
		case 0x61:
			fmt.println("LD H, C")
		case 0x71:
			fmt.println("LD [HL], C")

		case 0x02:
			fmt.printf("LD [BC], A\n")
		case 0x12:
			fmt.printf("LD [DE], A\n")
		case 0x22:
			fmt.printf("LD [HL+], A\n")
		case 0x32:
			fmt.printf("LD [HL-], A\n")
		case 0x42:
			fmt.println("LD B, D")
		case 0x52:
			fmt.println("LD D, D")
		case 0x62:
			fmt.println("LD H, D")
		case 0x72:
			fmt.println("LD [HL], D")

		case 0x03:
			fmt.printf("INC BC\n")
		case 0x13:
			fmt.printf("INC DE\n")
		case 0x23:
			fmt.printf("INC HL\n")
		case 0x33:
			fmt.printf("INC SP\n")
		case 0x43:
			fmt.println("LD B, E")
		case 0x53:
			fmt.println("LD D, E")
		case 0x63:
			fmt.println("LD H, E")
		case 0x73:
			fmt.println("LD [HL], E")

		case 0x04:
			fmt.printf("INC B\n")
		case 0x14:
			fmt.printf("INC D\n")
		case 0x24:
			fmt.printf("INC H\n")
		case 0x34:
			fmt.printf("INC HL\n")
		case 0x44:
			fmt.println("LD B, H")
		case 0x54:
			fmt.println("LD D, H")
		case 0x64:
			fmt.println("LD H, H")
		case 0x74:
			fmt.println("LD [HL], H")

		case 0x05:
			fmt.printf("DEC B\n")
		case 0x15:
			fmt.printf("DEC D\n")
		case 0x25:
			fmt.printf("DEC H\n")
		case 0x35:
			fmt.printf("DEC HL\n")
		case 0x45:
			fmt.println("LD B, L")
		case 0x55:
			fmt.println("LD D, L")
		case 0x65:
			fmt.println("LD H, L")
		case 0x75:
			fmt.println("LD [HL], L")

		case:
			fmt.println("Unknown Instruction")
		}
	}

	return nil
}

Decomp :: struct {
	data: []byte,
	idx:  int,
}

next :: #force_inline proc(decomp: ^Decomp) -> (result: byte, ok: bool) {
	if decomp.idx >= len(decomp.data) {
		ok = false
		return
	}

	result = decomp.data[decomp.idx]
	decomp.idx += 1
	ok = true
	return
}

next_u8 :: #force_inline proc(decomp: ^Decomp) -> (result: u8, err: Decomp_Error) {
	if decomp.idx + 1 >= len(decomp.data) do return 0, .EOF
	decomp.idx += 1
	byte := decomp.data[decomp.idx]
	result = u8(byte)
	return result, nil
}

next_u16 :: #force_inline proc(decomp: ^Decomp) -> (result: u16, err: Decomp_Error) {
	if decomp.idx + 2 >= len(decomp.data) do return 0, .EOF
	bytes := decomp.data[decomp.idx:decomp.idx + 2]
	result = u16(bytes[1]) << 8 | u16(bytes[0])
	decomp.idx += 2
	return result, nil
}
