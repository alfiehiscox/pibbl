package pibbl

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
	- rram: 8KB External Rom Ram    - A000:BFFF <In PPU>
	- wram: 8KB Working Memory      - C000:DFFF
	- oam : 160B Sprite Attr Table  - FE00:FE9F <In PPU>
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
	hram:    [127]byte,
	io:      [127]byte,

	// 
	intr:    byte,

	// Peripherals (sound, screen, etc) 
	ppu:     Pixel_Processing_Unit,

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

	//e.ppu = ppu.new(e.vram[:])

	unimplemented()
}

Emulator_Error :: enum {
	None = 0,
	Invalid_Access,
	Invalid_Write,
	Instruction_Not_Emulated,
	Invalid_Instruction,
	Stack_Overflow,
	Stack_Underflow,
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

tick_peripherals :: proc(e: ^Emulator, mcycles: int) -> Emulator_Error {
	unimplemented()
}

// ===========================================================
// ===================== Emulator Utils  =====================
// ===========================================================

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
		operand = byte((e.bc & 0xFF00) >> 8) // reg b
	case 1:
		operand = byte(e.bc) // reg c 
	case 2:
		operand = byte((e.de & 0xFF00) >> 8) // reg d
	case 3:
		operand = byte(e.de) // reg e 
	case 4:
		operand = byte((e.hl & 0xFF00) >> 8) // reg h
	case 5:
		operand = byte(e.hl) // reg l
	case 6:
		operand = access(e, e.hl) or_return // reg [hl]
	case 7:
		operand = byte((e.af & 0xFF00) >> 8) // reg a 
	case:
		return 0, .Invalid_Instruction
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
		return ppu_access(&e.ppu, addr)
	case addr >= 0xA000 && addr <= 0xBFFF:
		return e.rram[addr - 0xA000], nil
	case addr >= 0xC000 && addr <= 0xDFFF:
		return e.wram[addr - 0xC000], nil
	case addr >= 0xFE00 && addr <= 0xFE9F:
		return ppu_access(&e.ppu, addr)
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
		return ppu_write(&e.ppu, addr, val)
	case addr >= 0xA000 && addr <= 0xBFFF:
		e.rram[addr - 0xA000] = val
	case addr >= 0xC000 && addr <= 0xDFFF:
		e.wram[addr - 0xC000] = val
	case addr >= 0xFE00 && addr <= 0xFE9F:
		return ppu_write(&e.ppu, addr, val)
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

stack_push_byte :: proc(e: ^Emulator, val: byte) -> Emulator_Error {
	if e.sp - 1 < 0xC000 do return .Stack_Overflow
	e.sp -= 1
	return write(e, e.sp, val)
}

stack_pop_byte :: proc(e: ^Emulator) -> (b: byte, err: Emulator_Error) {
	if e.sp + 1 > 0xFFFE do return 0, .Stack_Underflow
	b = access(e, e.sp) or_return
	e.sp += 1
	return b, nil
}

stack_push_u16 :: proc(e: ^Emulator, val: u16) -> Emulator_Error {
	if e.sp - 2 < 0xC000 do return .Stack_Overflow
	e.sp -= 2
	write(e, e.sp, byte(val & 0xFF)) or_return
	write(e, e.sp + 1, byte((val >> 8) & 0xFF)) or_return
	return nil
}

stack_pop_u16 :: proc(e: ^Emulator) -> (b: u16, err: Emulator_Error) {
	if e.sp + 2 > 0xFFFE do return 0, .Stack_Underflow
	low := access(e, e.sp) or_return
	high := access(e, e.sp + 1) or_return
	e.sp += 2
	return u16(high) << 8 | u16(low), nil
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

set_r16_register :: proc(e: ^Emulator, reg: byte, value: u16) -> Emulator_Error {
	switch reg {
	case 0:
		e.bc = value
	case 1:
		e.de = value
	case 2:
		e.hl = value
	case 3:
		e.sp = value
	case:
		return .Instruction_Not_Emulated
	}

	return nil
}

set_r8_register :: proc(e: ^Emulator, reg: byte, value: u8) -> Emulator_Error {
	switch reg {
	case 0:
		e.bc = u16(value) << 8 | (e.bc & 0x00FF) // b
	case 1:
		e.bc = (e.bc & 0xFF00) | u16(value) // c 
	case 2:
		e.de = u16(value) << 8 | (e.de & 0x00FF) // d 
	case 3:
		e.de = (e.de & 0xFF00) | u16(value) // e 
	case 4:
		e.hl = u16(value) << 8 | (e.hl & 0x00FF) // h
	case 5:
		e.hl = (e.hl & 0xFF00) | u16(value) // l 
	case 6:
		write(e, e.hl, value) or_return // [hl]
	case 7:
		e.af = u16(value) << 8 | (e.af & 0x00FF) // a
	case:
		return .Unknown_Register
	}

	return nil
}
