package main

import "base:intrinsics"
import "core:encoding/endian"
import "core:log"

MAX_ROM :: 16384

Emulator :: struct {
	// Registers
	af:      u16,
	bc:      u16,
	de:      u16,
	hl:      u16,
	sp:      u16,
	pc:      u16,

	// Full ROM for banking. field `rom` must have 
	// lifetime same as Emulator struct. 
	rom:     []byte,

	/**
	Memory Regions:
	- rom : 16KB Bank 00            - 0000:3FFF
	- romN: 16KB Bank 01~NN         - 4000:7FFF
	- vram: 8KB Video Memory        - 8000:9FFF
	- rram: 8KB External Rom Ram    - A000:BFFF
	- wram: 8KB Working Memory      - C000:DFFF
	- oam : 160B Sprite Attr Table  - FE00:FE9F
	- io  : 127B i/o registres      - FF00:FF7F
	- hram: 127B fast CPU mem       - FF80:FFFE
	- intr: interupt enable flag 1B - FFFF

	Stack grows across hram and wram. 
	- Stacks at 0xFFFE and grows downward 
	- If grows out of hram goes into wram

	Points: 
	- TODO(alfie) implement rom banking
	- TODO(alfie) do we need the mirror ram at E000:FDFF
	**/
	rom0:    [MAX_ROM]byte,
	romN:    [MAX_ROM]byte,
	bank:    int,
	rram:    [8192]byte,
	wram:    [8192]byte,
	vram:    [8192]byte,
	hram:    [127]byte,
	oam:     [160]byte,
	io:      [127]byte,
	intr:    byte,

	// Peripherals (sound, screen, etc) 

	// emulation helpers 
	running: bool,
}

emulator_init :: proc(e: ^Emulator, rom: []byte) {
	// init 
	e.rom = rom
	e.pc = 0
	e.sp = 0xFFFE

	// First 16KB of rom always goes into `rom0` 
	bank0 := len(rom) < MAX_ROM ? rom : rom[:MAX_ROM]
	copy_slice(e.rom0[:len(bank0)], bank0)
	e.bank = 0

	// We can fit entire rom in mem
	if len(rom) > MAX_ROM && len(rom) < (2 * MAX_ROM) {
		bank1 := rom[MAX_ROM:]
		copy_slice(e.romN[:len(bank1)], bank1)
		e.bank = 1
	}

	unimplemented()
}

Emulator_Error :: enum {
	None = 0,
	Invalid_Access,
	Invalid_Write,
	Stack_Overflow,
	Instruction_Not_Emulated,
	Instruction_Not_Parsed,
}

/**
Timing: 

We want cycle accurate timing in this emulator. The best way I 
can think of doing this is tracking machine cycles per instruction 
and updating peripherals by said cycle count. 

The DMG CPU runs at ~4.19MHz. However other peripherals operate at 
different speeds. To get around this we normally use Machine cycles (M-Cycles) 
to describe how long a instruction takes. 
- 1 M Cycle == 4 CPU Cycles

So we want know how many m-cycles a CPU instruction takes, then tick 
the peripherals by that many cycles. 

A 'frame' is 'drawn' at a rate of 59.73 times/second. This is 70,224 CPU cycles 
assuming a 4.19MHz CPU clock rate. During those ~70K cycles the PPU will write 
pixels to a frame buffer and at which point we draw those to screen. 

After this we can optionally pause execution to ensure a 4.19MHz CPU rate, and 
then start again.
**/

/** 
Carries: 

The ALU has a half and full carry bit flag stored regirster f. Bit are refereneced 
from 0. Say a u8 has bits 0-7 and a u16 has bits 0-15

- On 8 bit calculation the half flag is set if there is a rollover from bit 3 to 4 
- On 8 bit calcuations the full flag is set if there is a rollover from bit 7 and in odin we wrap arround for unsigned ints.
- On 16 bit calculations the half flag is set if there is a rollover from bit 3 to 4 in the highest register. This basically means when a rollover from bit 11 to 12. 
- On 16 bit calculations the full flag is set if there is a rollover from bit 15 and in odin we wrap arround for unsighed ints.

**/

execute :: proc(e: ^Emulator) -> Emulator_Error {
	e.running = true

	for e.running {
	}

	unimplemented()
}

fetch_opcode :: proc(e: ^Emulator) -> (opcode: byte, err: Emulator_Error) {
	opcode = access(e, e.sp) or_return
	e.pc += 1
	return opcode, nil
}

// This is basically an implementation of these listings: https://gbdev.io/gb-opcodes/optables/
execute_instruction :: proc(e: ^Emulator, opcode: byte) -> (cycles: int, err: Emulator_Error) {
	switch (opcode & 0xC0) >> 6 {
	case 0:
		return execute_block_0_instruction(e, opcode)
	case 1:
		return execute_block_1_instruction(e, opcode)
	case 2:
		return execute_block_2_instruction(e, opcode)
	case 3:
		return execute_block_3_instruction(e, opcode)
	case:
		return -1, .Instruction_Not_Emulated
	}
}

execute_block_0_instruction :: proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	switch {
	case opcode == 0x00:
		return 1, nil // noop 
	case opcode & 0x0F == 0x01:
		return execute_ld_r16_imm16(e, opcode) // ld r16, imm16 
	case opcode & 0x0F == 0x02:
		return execute_ld_r16mem_a(e, opcode) // ld [r16mem], a 
	case opcode & 0x0F == 0x0A:
		return execute_ld_a_r16mem(e, opcode) // ld a, r16mem 
	case opcode == 0x08:
		return execute_ld_imm16_sp(e) // ld imm16, sp 
	case opcode & 0x0F == 0x03:
		return execute_inc_r16(e, opcode) // inc r16
	case opcode & 0x0F == 0x0B:
		return execute_dec_r16(e, opcode) // dec r16
	case opcode & 0x0F == 0x09:
		return execute_add_hl_r16(e, opcode) // add hl, [r16]
	case opcode & 0x07 == 0x04:
		return execute_inc_r8(e, opcode) // inc r8
	case opcode & 0x07 == 0x05:
		return execute_dec_r8(e, opcode) // dec r8
	}

	unimplemented()
}

execute_ld_r16_imm16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	val_bytes := access_range(e, e.pc, e.pc + 2) or_return
	defer delete(val_bytes)

	e.pc += 2

	val, ok := endian.get_u16(val_bytes, .Little)
	if !ok do return -1, .Instruction_Not_Parsed

	switch (opcode & 0x30) >> 4 {
	case 0:
		e.bc = val // ld bc imm16 
	case 1:
		e.de = val // ld de imm16 
	case 2:
		e.hl = val // ld hl imm16 
	case 3:
		e.sp = val // ld sp imm16 
	case:
		return -1, .Instruction_Not_Parsed
	}

	return 3, nil
}

execute_ld_r16mem_a :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	switch (opcode & 0x30) >> 4 {
	case 0:
		// ld [bc], a
		a := byte((e.af & 0xFF00) >> 8)
		err = write(e, e.bc, a)
	case 1:
		// ld [de], a
		a := byte((e.af & 0xFF00) >> 8)
		err = write(e, e.de, a)
	case 2:
		// ld [hl+], a
		a := byte((e.af & 0xFF00) >> 8)
		err = write(e, e.hl, a)
		e.hl += 1
	case 3:
		// ld [hl-], a
		a := byte((e.af & 0xFF00) >> 8)
		err = write(e, e.hl, a)
		e.hl -= 1
	case:
		return -1, .Instruction_Not_Parsed
	}

	return 2, nil
}

execute_ld_a_r16mem :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	switch (opcode & 0x30) >> 4 {
	case 0:
		// ld a, [bc]
		data := access(e, e.bc) or_return
		e.af = (u16(data) << 8) | (e.af & 0x00FF)
	case 1:
		// ld a, [de]
		data := access(e, e.de) or_return
		e.af = (u16(data) << 8) | (e.af & 0x00FF)
	case 2:
		// ld a, [hl+]
		data := access(e, e.hl) or_return
		e.af = (u16(data) << 8) | (e.af & 0x00FF)
		e.hl += 1
	case 3:
		// ld a, [hl-]
		data := access(e, e.hl) or_return
		e.af = (u16(data) << 8) | (e.af & 0x00FF)
		e.hl -= 1
	case:
		return -1, .Instruction_Not_Parsed
	}

	return 2, nil
}

execute_ld_imm16_sp :: #force_inline proc(e: ^Emulator) -> (cycles: int, err: Emulator_Error) {
	// ld [imm16], sp 

	val_bytes := access_range(e, e.pc, e.pc + 2) or_return
	defer delete(val_bytes)

	e.pc += 2

	addr, ok := endian.get_u16(val_bytes, .Little)
	if !ok do return -1, .Instruction_Not_Parsed

	write(e, addr, byte(e.sp & 0x00FF)) or_return
	write(e, addr + 1, byte(e.sp >> 8)) or_return

	return 5, nil
}

execute_inc_r16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	switch (opcode & 0x30) >> 4 {
	case 0:
		e.bc += 1 // inc bc
	case 1:
		e.de += 1 // inc de
	case 2:
		e.hl += 1 // inc hl
	case 3:
		e.sp += 1 // inc sp
	case:
		return -1, .Instruction_Not_Parsed
	}

	return 2, nil
}

execute_dec_r16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	switch (opcode & 0x30) >> 4 {
	case 0:
		e.bc -= 1 // inc bc
	case 1:
		e.de -= 1 // inc de
	case 2:
		e.hl -= 1 // inc hl
	case 3:
		e.sp -= 1 // inc sp
	case:
		return -1, .Instruction_Not_Parsed
	}

	return 2, nil
}

execute_add_hl_r16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {

	f := 0

	switch (opcode & 0x30) >> 4 {
	case 0:
		// add hl, bc
		if will_add_overflow(e.hl, e.bc) do f |= 0x10
		if will_add_h_overflow(e.hl, e.bc) do f |= 0x20
		e.hl += e.bc
	case 1:
		// add hl, de
		if will_add_overflow(e.hl, e.de) do f |= 0x10
		if will_add_h_overflow(e.hl, e.de) do f |= 0x20
		e.hl += e.de
	case 2:
		// add hl, hl
		if will_add_overflow(e.hl, e.hl) do f |= 0x10
		if will_add_h_overflow(e.hl, e.hl) do f |= 0x20
		e.hl += e.hl
	case 3:
		// add hl, sp
		if will_add_overflow(e.hl, e.sp) do f |= 0x10
		if will_add_h_overflow(e.hl, e.sp) do f |= 0x20
		e.hl += e.sp
	case:
		return -1, .Instruction_Not_Parsed
	}

	e.af = (e.af & 0xFF00) | u16(f)

	return 2, nil
}

execute_inc_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_dec_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_block_1_instruction :: proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_block_2_instruction :: proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_block_3_instruction :: proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	unimplemented()
}


tick_peripherals :: proc(e: ^Emulator, mcycles: int) -> Emulator_Error {
	unimplemented()
}

// min_addr == inclusive, max_addr == exclusive
// allocates the returned []byte
access_range :: proc(
	e: ^Emulator,
	min_addr: u16,
	max_addr: u16,
	allocator := context.allocator,
) -> (
	results: []byte,
	err: Emulator_Error,
) {
	if max_addr <= min_addr {
		return nil, .Invalid_Access
	}

	results = make([]byte, max_addr - min_addr, allocator)
	for n, i in min_addr ..< max_addr {
		data, err := access(e, u16(n))
		if err != nil {
			delete(results)
			return nil, err
		}

		results[i] = data
	}

	return results, nil
}

access :: proc(e: ^Emulator, addr: u16) -> (byte, Emulator_Error) {
	switch {
	case addr >= 0x0000 && addr <= 0x3FFF:
		return e.rom0[addr], nil
	case addr >= 0x4000 && addr <= 0x7FFF:
		return e.romN[addr - 0x4000], nil // TODO(alfie) - memory banking 
	case addr >= 0x8000 && addr <= 0x9FFF:
		return e.vram[addr - 0x8000], nil
	case addr >= 0xA000 && addr <= 0xBFFF:
		return e.rram[addr - 0xA000], nil
	case addr >= 0xC000 && addr <= 0xDFFF:
		return e.wram[addr - 0xC000], nil
	case addr >= 0xFE00 && addr <= 0xFE9F:
		return e.oam[addr - 0xFE00], nil
	case addr >= 0xFF00 && addr <= 0xFF7F:
		return e.io[addr - 0xFF00], nil
	case addr >= 0xFF80 && addr <= 0xFFFE:
		return e.hram[addr - 0xFF80], nil
	case addr == 0xFFFF:
		return e.intr, nil
	case:
		return 0x00, .Invalid_Access
	}
}

write :: proc(e: ^Emulator, addr: u16, val: byte) -> Emulator_Error {
	switch {
	case addr >= 0x0000 && addr <= 0x3FFF:
		return .Invalid_Write
	case addr >= 0x4000 && addr <= 0x7FFF:
		return .Invalid_Write
	case addr >= 0x8000 && addr <= 0x9FFF:
		e.vram[addr - 0x8000] = val
	case addr >= 0xA000 && addr <= 0xBFFF:
		e.rram[addr - 0xA000] = val
	case addr >= 0xC000 && addr <= 0xDFFF:
		e.wram[addr - 0xC000] = val
	case addr >= 0xFE00 && addr <= 0xFE9F:
		e.oam[addr - 0xFE00] = val
	case addr >= 0xFF00 && addr <= 0xFF7F:
		e.io[addr - 0xFF00] = val
	case addr >= 0xFF80 && addr <= 0xFFFE:
		e.hram[addr - 0xFF80] = val
	case addr == 0xFFFF:
		e.intr = val
	case:
		return .Invalid_Write
	}

	return nil
}

stack_push :: proc(e: ^Emulator, val: byte) -> Emulator_Error {
	unimplemented()
}

stack_pop :: proc(e: ^Emulator) -> (byte, Emulator_Error) {
	unimplemented()
}

will_add_overflow :: proc(a, b: $T) -> bool where intrinsics.type_is_integer(T) {
	return a + b < a
}

will_add_h_overflow :: proc {
	will_add_h_overflow_u8,
	will_add_h_overflow_u16,
}

will_add_h_overflow_u8 :: proc(a, b: u8) -> bool {
	return (a & 0xF) + (b & 0xF) > 0xF
}

will_add_h_overflow_u16 :: proc(a, b: u16) -> bool {
	return (a & 0x0FFF) + (b & 0x0FFF) > 0x0FFF
}

// a = 0b 0010 1111 
// b = 0b 0010 0001
// + = 0b 0011 0000
