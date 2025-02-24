package main

import "base:intrinsics"
import "core:encoding/endian"
import "core:log"

MAX_ROM :: 16384

FLAG_ZERO :: 0x80
FLAG_SUB :: 0x40
FLAG_HALF_CARRY :: 0x20
FLAG_FULL_CARRY :: 0x10

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
	Unknown_Register,
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
- On 8 bit calcuations the full flag is set if there is a rollover from bit 7 and in 
  odin we wrap arround for unsigned ints.
- On 16 bit calculations the half flag is set if there is a rollover from bit 3 to 4 in the highest register.
  This basically means when a rollover from bit 11 to 12. 
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
	case opcode & 0x07 == 0x06:
		return execute_ld_r8_imm8(e, opcode) // ld r8, imm8 	
	case opcode == 0x07:
		return execute_rlca(e, opcode) // rlca 
	case opcode == 0x0F:
		return execute_rrca(e, opcode) // rrca
	case opcode == 0x17:
		return execute_rla(e, opcode) // rla
	case opcode == 0x1F:
		return execute_rra(e, opcode) // rra 
	case opcode == 0x27:
		return execute_dda(e, opcode) // dda 
	case opcode == 0x2F:
		return execute_cpl(e, opcode) // cpl 
	case opcode == 0x37:
		return execute_scf(e, opcode) // scf
	case opcode == 0x3F:
		return execute_ccf(e, opcode) // ccf
	case opcode == 0x18:
		return execute_jr_imm8(e, opcode) // jr imm8 
	case opcode == 0x20 || opcode == 0x28 || opcode == 0x30 || opcode == 0x38:
		return execute_jr_cond_imm8(e, opcode) // jr cond imm8 
	case opcode == 0x10:
		return execute_stop(e, opcode) // stop
	case:
		return 0, .Instruction_Not_Emulated
	}
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
	if !ok do return 0, .Instruction_Not_Parsed

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
		return 0, .Instruction_Not_Parsed
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
		return 0, .Instruction_Not_Parsed
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
		return 0, .Instruction_Not_Parsed
	}

	return 2, nil
}

execute_ld_imm16_sp :: #force_inline proc(e: ^Emulator) -> (cycles: int, err: Emulator_Error) {
	// ld [imm16], sp 

	val_bytes := access_range(e, e.pc, e.pc + 2) or_return
	defer delete(val_bytes)

	e.pc += 2

	addr, ok := endian.get_u16(val_bytes, .Little)
	if !ok do return 0, .Instruction_Not_Parsed

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
		return 0, .Instruction_Not_Parsed
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
		return 0, .Instruction_Not_Parsed
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
		if will_add_overflow(e.hl, e.bc) do f |= FLAG_FULL_CARRY
		if will_add_h_overflow(e.hl, e.bc) do f |= FLAG_HALF_CARRY
		e.hl += e.bc
	case 1:
		// add hl, de
		if will_add_overflow(e.hl, e.de) do f |= FLAG_FULL_CARRY
		if will_add_h_overflow(e.hl, e.de) do f |= FLAG_HALF_CARRY
		e.hl += e.de
	case 2:
		// add hl, hl
		if will_add_overflow(e.hl, e.hl) do f |= FLAG_FULL_CARRY
		if will_add_h_overflow(e.hl, e.hl) do f |= FLAG_HALF_CARRY
		e.hl += e.hl
	case 3:
		// add hl, sp
		if will_add_overflow(e.hl, e.sp) do f |= FLAG_FULL_CARRY
		if will_add_h_overflow(e.hl, e.sp) do f |= FLAG_HALF_CARRY
		e.hl += e.sp
	case:
		return 0, .Instruction_Not_Parsed
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

	f := 0

	switch (opcode & 0x38) >> 3 {
	case 0:
		// inc b 
		b := u8((e.bc & 0xFF00) >> 8)
		if will_add_h_overflow(b, 1) do f |= FLAG_HALF_CARRY
		if b + 1 == 0 do f |= FLAG_ZERO
		e.bc = u16(b + 1) << 8 | (e.bc & 0x00FF)
	case 1:
		// inc c
		c := u8(e.bc)
		if will_add_h_overflow(c, 1) do f |= FLAG_HALF_CARRY
		if c + 1 == 0 do f |= FLAG_ZERO
		e.bc = (e.bc & 0xFF00) | u16(c + 1)
	case 2:
		// inc d
		d := u8((e.de & 0xFF00) >> 8)
		if will_add_h_overflow(d, 1) do f |= FLAG_HALF_CARRY
		if d + 1 == 0 do f |= FLAG_ZERO
		e.de = u16(d + 1) << 8 | (e.de & 0x00FF)
	case 3:
		// inc e
		er := u8(e.de)
		if will_add_h_overflow(er, 1) do f |= FLAG_HALF_CARRY
		if er + 1 == 0 do f |= FLAG_ZERO
		e.de = (e.de & 0xFF00) | u16(er + 1)
	case 4:
		// inc h 
		h := u8((e.hl & 0xFF00) >> 8)
		if will_add_h_overflow(h, 1) do f |= FLAG_HALF_CARRY
		if h + 1 == 0 do f |= FLAG_ZERO
		e.hl = u16(h + 1) << 8 | (e.hl & 0x00FF)
	case 5:
		// inc l
		l := u8(e.hl)
		if will_add_h_overflow(l, 1) do f |= FLAG_HALF_CARRY
		if l + 1 == 0 do f |= FLAG_ZERO
		e.hl = (e.hl & 0xFF00) | u16(l + 1)
	case 6:
		// inc [hl]
		v := access(e, e.hl) or_return
		if will_add_h_overflow(v, 1) do f |= FLAG_HALF_CARRY
		if v + 1 == 0 do f |= FLAG_ZERO
		write(e, e.hl, v + 1) or_return
		e.af = (e.af & 0xFF00) | u16(f)
		return 3, nil
	case 7:
		// inc a
		a := u8((e.af & 0xFF00) >> 8)
		if will_add_h_overflow(a, 1) do f |= FLAG_HALF_CARRY
		if a + 1 == 0 do f |= FLAG_ZERO
		e.hl = u16(a + 1) << 8 | (e.af & 0x00FF)
	case:
		return 0, .Instruction_Not_Parsed
	}

	e.af = (e.af & 0xFF00) | u16(f)

	return 1, nil
}

execute_dec_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	f := 0

	switch (opcode & 0x38) >> 3 {
	case 0:
		// dec b 
		b := u8((e.bc & 0xFF00) >> 8)
		if will_sub_h_underflow_u8(b, 1) do f |= FLAG_HALF_CARRY
		if b - 1 == 0 do f |= FLAG_ZERO
		e.bc = u16(b - 1) << 8 | (e.bc & 0x00FF)
	case 1:
		// dec c
		c := u8(e.bc)
		if will_sub_h_underflow_u8(c, 1) do f |= FLAG_HALF_CARRY
		if c - 1 == 0 do f |= FLAG_ZERO
		e.bc = (e.bc & 0xFF00) | u16(c - 1)
	case 2:
		// dec d
		d := u8((e.de & 0xFF00) >> 8)
		if will_sub_h_underflow_u8(d, 1) do f |= FLAG_HALF_CARRY
		if d - 1 == 0 do f |= FLAG_ZERO
		e.de = u16(d - 1) << 8 | (e.de & 0x00FF)
	case 3:
		// dec e
		er := u8(e.de)
		if will_sub_h_underflow_u8(er, 1) do f |= FLAG_HALF_CARRY
		if er - 1 == 0 do f |= FLAG_ZERO
		e.de = (e.de & 0xFF00) | u16(er - 1)
	case 4:
		// dec h 
		h := u8((e.hl & 0xFF00) >> 8)
		if will_sub_h_underflow_u8(h, 1) do f |= FLAG_HALF_CARRY
		if h - 1 == 0 do f |= FLAG_ZERO
		e.hl = u16(h - 1) << 8 | (e.hl & 0x00FF)
	case 5:
		// dec l
		l := u8(e.hl)
		if will_sub_h_underflow_u8(l, 1) do f |= FLAG_HALF_CARRY
		if l - 1 == 0 do f |= FLAG_ZERO
		e.hl = (e.hl & 0xFF00) | u16(l - 1)
	case 6:
		// dec [hl]
		v := access(e, e.hl) or_return
		if will_sub_h_underflow_u8(v, 1) do f |= FLAG_HALF_CARRY
		if v - 1 == 0 do f |= FLAG_ZERO
		f |= FLAG_SUB
		write(e, e.hl, v - 1) or_return
		e.af = (e.af & 0xFF00) | u16(f)
		return 3, nil
	case 7:
		// dec a
		a := u8((e.af & 0xFF00) >> 8)
		if will_sub_h_underflow_u8(a, 1) do f |= FLAG_HALF_CARRY
		if a - 1 == 0 do f |= FLAG_ZERO
		e.af = u16(a - 1) << 8 | (e.af & 0x00FF)
	case:
		return 0, .Instruction_Not_Parsed
	}

	f |= FLAG_SUB
	e.af = (e.af & 0xFF00) | u16(f)

	return 1, nil
}

execute_ld_r8_imm8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	switch (opcode & 0x38) >> 3 {
	case 0:
		// ld b,imm8
		next := access(e, e.pc) or_return
		e.pc += 1
		e.bc = (u16(next) << 8) | (e.bc & 0x00FF)
	case 1:
		// ld c,imm8
		next := access(e, e.pc) or_return
		e.pc += 1
		e.bc = (e.bc & 0xFF00) | u16(next)
	case 2:
		// ld d,imm8
		next := access(e, e.pc) or_return
		e.pc += 1
		e.de = (u16(next) << 8) | (e.de & 0x00FF)
	case 3:
		// ld e,imm8
		next := access(e, e.pc) or_return
		e.pc += 1
		e.de = (e.de & 0xFF00) | u16(next)
	case 4:
		// ld h,imm8
		next := access(e, e.pc) or_return
		e.pc += 1
		e.hl = (u16(next) << 8) | (e.hl & 0x00FF)
	case 5:
		// ld l,imm8
		next := access(e, e.pc) or_return
		e.pc += 1
		e.hl = (e.hl & 0xFF00) | u16(next)
	case 6:
		// ld [hl],imm8
		next := access(e, e.pc) or_return
		e.pc += 1
		write(e, e.hl, next) or_return
		return 3, nil
	case 7:
		// ld a,imm8
		next := access(e, e.pc) or_return
		e.pc += 1
		e.af = (u16(next) << 8) | (e.af & 0x00FF)
	case:
		return 0, .Instruction_Not_Parsed
	}

	return 2, nil
}

execute_rlca :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {

	a := byte((e.af & 0xFF00) >> 8)
	most := (a & 0x80) >> 7

	new_a := a << 1 | most
	new_f := most == 0 ? 0 : FLAG_FULL_CARRY

	e.af = (u16(new_a) << 8) | u16(new_f)

	return 1, nil
}

execute_rrca :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	a := byte((e.af & 0xFF00) >> 8)
	least := a & 0x01 << 7

	new_a := a >> 1 | least
	new_f := least == 0 ? 0 : FLAG_FULL_CARRY

	e.af = (u16(new_a) << 8) | u16(new_f)

	return 1, nil
}

execute_rla :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	a := byte((e.af & 0xFF00) >> 8)
	most := (a & 0x80) >> 7
	carry := (byte(e.af) & FLAG_FULL_CARRY) >> 4

	new_a := a << 1 | carry
	new_f := most == 0 ? 0 : FLAG_FULL_CARRY

	e.af = (u16(new_a) << 8) | u16(new_f)

	return 1, nil
}

execute_rra :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	a := byte((e.af & 0xFF00) >> 8)
	least := a & 0x01 << 7
	carry := (byte(e.af) & FLAG_FULL_CARRY) << 3

	new_a := a >> 1 | carry
	new_f := least == 0 ? 0 : FLAG_FULL_CARRY

	e.af = (u16(new_a) << 8) | u16(new_f)

	return 1, nil
}

execute_dda :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	a := byte((e.af & 0xFF00) >> 8)
	n := byte(e.af) & FLAG_SUB >> 6
	h := byte(e.af) & FLAG_HALF_CARRY >> 5
	c := byte(e.af) & FLAG_FULL_CARRY >> 4

	new_a := a
	new_f := FLAG_SUB

	if n == 1 {
		adj: byte = 0
		if h == 1 do adj += 0x06
		if c == 1 do adj += 0x60

		if will_sub_underflow_u8(a, adj) {
			new_f |= FLAG_FULL_CARRY
		}

		new_a -= adj
	} else {
		adj: byte = 0
		if h == 1 || (a & 0x0F) > 0x09 do adj += 0x06
		if c == 1 || a > 0x99 {
			adj += 0x60
			new_f |= FLAG_FULL_CARRY
		}

		new_a += adj
	}

	if new_a == 0 {
		new_f |= FLAG_ZERO
	}

	e.af = (u16(new_a) << 8) | u16(new_f)
	return 1, nil
}

execute_cpl :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	a := byte((e.af & 0xFF00) >> 8)
	e.af = u16(~a) << 8 | e.af & 0x00FF
	return 1, nil
}

execute_scf :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	e.af = e.af | FLAG_FULL_CARRY
	return 1, nil
}

execute_ccf :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	c := (byte(e.af) & FLAG_FULL_CARRY) >> 4
	if c == 1 {
		e.af &= ~u16(FLAG_FULL_CARRY)
	} else {
		e.af |= FLAG_FULL_CARRY
	}
	return 1, nil
}

execute_jr_imm8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	addr: i8 = auto_cast access(e, e.pc) or_return
	e.pc += 1
	e.pc = u16(i16(e.pc) + i16(addr))
	return 3, nil
}

execute_jr_cond_imm8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	z := (byte(e.af) & FLAG_ZERO) >> 7
	c := (byte(e.af) & FLAG_FULL_CARRY) >> 4

	switch (opcode & 0x18) >> 3 {
	case 0:
		if z == 0 do return execute_jr_imm8(e, opcode)
		e.pc += 1
		return 2, nil
	case 1:
		if z == 1 do return execute_jr_imm8(e, opcode)
		e.pc += 1
		return 2, nil
	case 2:
		if c == 0 do return execute_jr_imm8(e, opcode)
		e.pc += 1
		return 2, nil
	case 3:
		if c == 1 do return execute_jr_imm8(e, opcode)
		e.pc += 1
		return 2, nil
	case:
		return 0, .Instruction_Not_Parsed
	}
}

// TODO: Look at this because it has some weird quirks
execute_stop :: #force_inline proc(
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

	if opcode == 0x77 {
		return execute_halt(e, opcode)
	}

	source_reg := opcode & 0x03
	source: byte
	switch source_reg {
	case 0:
		source = byte((e.bc & 0xFF00) >> 8)
	case 1:
		source = byte(e.bc)
	case 2:
		source = byte((e.de & 0xFF00) >> 8)
	case 3:
		source = byte(e.de)
	case 4:
		source = byte((e.hl & 0xFF00) >> 8)
	case 5:
		source = byte(e.hl)
	case 6:
		source = access(e, e.hl) or_return
	case 7:
		source = byte((e.af & 0xFF00) >> 8)
	case:
		return 0, .Unknown_Register
	}

	dest_reg := (opcode & 0x38) >> 3
	switch dest_reg {
	case 0:
		e.bc = (u16(source) << 8) | (e.bc & 0x00FF)
	case 1:
		e.bc = (e.bc & 0xFF00) | u16(source)
	case 2:
		e.de = (u16(source) << 8) | (e.de & 0x00FF)
	case 3:
		e.de = (e.de & 0xFF00) | u16(source)
	case 4:
		e.hl = (u16(source) << 8) | (e.hl & 0x00FF)
	case 5:
		e.hl = (e.hl & 0xFF00) | u16(source)
	case 6:
		write(e, e.hl, source) or_return
	case 7:
		e.af = (u16(source) << 8) | (e.af & 0x00FF)
	case:
		return 0, .Instruction_Not_Parsed
	}

	if source_reg == 0x06 || dest_reg == 0x06 {
		return 2, nil
	} else {
		return 1, nil
	}
}

execute_halt :: #force_inline proc(
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
	operand := get_arithmetic_register_value(e, opcode) or_return

	carry: byte = 0
	switch (opcode & 0x38) >> 3 {
	case 1, 3:
		carry = (byte(e.af) & FLAG_FULL_CARRY) >> 4
	}

	a := byte((e.af & 0xFF00) >> 8)
	f := 0

	switch (opcode & 0x38) >> 3 {
	case 0, 1:
		if will_add_overflow(a, operand + carry) do f |= FLAG_FULL_CARRY
		if will_add_h_overflow(a, operand + carry) do f |= FLAG_HALF_CARRY
	case 2, 3, 7:
		if will_sub_underflow_u8(a, operand + carry) do f |= FLAG_FULL_CARRY
		if will_sub_h_underflow_u8(a, operand + carry) do f |= FLAG_HALF_CARRY
	case 4:
		f |= FLAG_HALF_CARRY
	}

	switch (opcode & 0x38) >> 3 {
	case 0, 1:
		a += operand + carry
	case 2, 3, 7:
		a -= operand + carry
	case 4:
		a &= operand
	case 5:
		a ~= operand
	case 6:
		a |= operand
	case:
		return 0, .Instruction_Not_Emulated
	}

	if a == 0 do f |= FLAG_ZERO

	if (opcode & 0x38) >> 3 == 7 {
		e.af = u16(e.af) | u16(f)
	} else {
		e.af = u16(a) << 8 | u16(f)
	}

	if opcode & 0x07 == 6 {
		return 2, nil
	} else {
		return 1, nil
	}
}

execute_block_3_instruction :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	switch opcode {
	case 0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE:
		return execute_block_3_arithmetic_instruction(e, opcode)
	case 0xC0, 0xC8, 0xD0, 0xD8:
		return execute_ret_cond(e, opcode) // ret cond
	case 0xC9:
		return execute_ret(e, opcode) // ret
	case 0xD9:
		return execute_reti(e, opcode) // reti
	case 0xC2, 0xCA, 0xD2, 0xDA:
		return execute_jp_cond_imm8(e, opcode) // jp cond, imm16
	case 0xC3:
		return execute_jp_imm16(e, opcode) // jp imm16
	case 0xE9:
		return execute_jp_hl(e, opcode) // jp hl
	case 0xC4, 0xCC, 0xD4, 0xDC:
		return execute_call_cond_imm16(e, opcode) //call cond, imm16
	case 0xCD:
		return execute_call_imm16(e, opcode) // call imm16 
	case 0xC7, 0xCF, 0xD7, 0xDF, 0xE7, 0xEF, 0xF7, 0xFF:
		return execute_rst_tgt3(e, opcode) // rst tgt3
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_rst_tgt3 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_call_imm16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_call_cond_imm16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_jp_hl :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	e.pc = e.hl
	return 1, nil
}

execute_jp_imm16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	val_bytes := access_range(e, e.pc, e.pc + 2) or_return
	defer delete(val_bytes)

	e.pc += 2

	val, ok := endian.get_u16(val_bytes, .Little)
	if !ok do return 0, .Instruction_Not_Parsed

	e.pc = val

	return 4, nil
}

execute_jp_cond_imm8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	val_bytes := access_range(e, e.pc, e.pc + 2) or_return
	defer delete(val_bytes)

	e.pc += 2

	val, ok := endian.get_u16(val_bytes, .Little)
	if !ok do return 0, .Instruction_Not_Parsed

	cond := (opcode & 0x18) >> 3
	f := byte(e.af)

	switch cond {
	case 0:
		if f & FLAG_ZERO != FLAG_ZERO {
			e.pc = val
			return 4, nil
		}
	case 1:
		if f & FLAG_ZERO == FLAG_ZERO {
			e.pc = val
			return 4, nil
		}
	case 2:
		if f & FLAG_FULL_CARRY != FLAG_FULL_CARRY {
			e.pc = val
			return 4, nil
		}
	case 3:
		if f & FLAG_FULL_CARRY == FLAG_FULL_CARRY {
			e.pc = val
			return 4, nil
		}
	}

	return 3, nil
}

execute_ret :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_reti :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}


execute_ret_cond :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_block_3_arithmetic_instruction :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	operand := access(e, e.pc) or_return
	e.pc += 1

	carry: byte = 0
	switch opcode {
	case 0xCE, 0xDE:
		carry = (byte(e.af) & FLAG_FULL_CARRY) >> 4
	}

	a := byte((e.af & 0xFF00) >> 8)
	f := 0

	switch opcode {
	case 0xC6, 0xCE:
		if will_add_overflow(a, operand + carry) do f |= FLAG_FULL_CARRY
		if will_add_h_overflow(a, operand + carry) do f |= FLAG_HALF_CARRY
	case 0xD6, 0xDE, 0xFE:
		if will_sub_underflow_u8(a, operand + carry) do f |= FLAG_FULL_CARRY
		if will_sub_h_underflow_u8(a, operand + carry) do f |= FLAG_HALF_CARRY
	case 0xE6:
		f |= FLAG_HALF_CARRY
	}

	switch opcode {
	case 0xC6, 0xCE:
		a += operand + carry
	case 0xD6, 0xDE, 0xFE:
		a -= operand + carry
	case 0xE6:
		a &= operand
	case 0xEE:
		a ~= operand
	case 0xF6:
		a |= operand
	case:
		return 0, .Instruction_Not_Emulated
	}

	if a == 0 do f |= FLAG_ZERO

	if opcode == 0xFE {
		e.af = u16(e.af) | u16(f)
	} else {
		e.af = u16(a) << 8 | u16(f)
	}

	return 2, nil
}

tick_peripherals :: proc(e: ^Emulator, mcycles: int) -> Emulator_Error {
	unimplemented()
}

// Will get value from the value coded as the 0 & 0x07 segment of opcode 
get_arithmetic_register_value :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	operand: byte,
	err: Emulator_Error,
) {

	switch opcode & 0x07 {
	case 0:
		// reg b
		operand = byte((e.bc & 0xFF00) >> 8)
	case 1:
		// reg c 
		operand = byte(e.bc)
	case 2:
		// reg d
		operand = byte((e.de & 0xFF00) >> 8)
	case 3:
		// reg e 
		operand = byte(e.de)
	case 4:
		// reg h
		operand = byte((e.hl & 0xFF00) >> 8)
	case 5:
		// reg l
		operand = byte(e.hl)
	case 6:
		// reg [hl]
		operand = access(e, e.hl) or_return
	case 7:
		// reg a 
		operand = byte((e.af & 0xFF00) >> 8)
	case:
		return 0, .Instruction_Not_Parsed
	}

	return operand, nil
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
	return (a & 0x0F) + (b & 0x0F) > 0x0F
}

will_add_h_overflow_u16 :: proc(a, b: u16) -> bool {
	return (a & 0x0FFF) + (b & 0x0FFF) > 0x0FFF
}

will_sub_underflow_u8 :: proc(a, b: u8) -> bool {
	return a < b
}

will_sub_h_underflow_u8 :: proc(a, b: u8) -> bool {
	return (a & 0x0F) < (b & 0x0F)
}
