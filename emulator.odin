package pibbl

import "base:intrinsics"
import "core:log"

MAX_ROM :: 16384

FLAG_ZERO :: 0x80       // 0x10000000
FLAG_SUB :: 0x40        // 0x01000000
FLAG_HALF_CARRY :: 0x20 // 0x00100000
FLAG_FULL_CARRY :: 0x10 // 0x00010000

Emulator_Error :: enum {
	None = 0,
	Invalid_Access,
	Invalid_Write,
	Instruction_Not_Emulated,
	Invalid_Instruction,
	Stack_Overflow,
	Stack_Underflow,
	Unknown_Register,
	Unknown_Interrupt_Vector,
}

Emulator :: struct {
	// Registers
	af:      u16,
	bc:      u16,
	de:      u16,
	hl:      u16,
	sp:      u16,
	pc:      u16,

	// Full ROM for banking. field `_rom` must have 
	// lifetime same as Emulator struct. 
	_rom:    []byte,

	/**
	Memory Regions:
	- _rom : 16KB Bank 00            - 0000:3FFF
	- _romN: 16KB Bank 01~NN         - 4000:7FFF
	- _vram: 8KB Video Memory        - 8000:9FFF
	- _rram: 8KB External Rom Ram    - A000:BFFF <In PPU>
	- _wram: 8KB Working Memory      - C000:DFFF
	- _oam : 160B Sprite Attr Table  - FE00:FE9F <In PPU>
	- _io  : 127B i/o registres      - FF00:FF7F
	- _hram: 127B fast CPU mem       - FF80:FFFE

	Stack grows across hram and wram. 
	- Stacks at 0xFFFE and grows downward 
	- If grows out of hram goes into wram

	Points: 
	- TODO(alfie) implement rom banking
	- TODO(alfie) do we need the mirror ram at E000:FDFF
	**/
	_rom0:   [MAX_ROM]byte,
	_romN:   [MAX_ROM]byte,
	_bank:   int,
	_rram:   [8192]byte,
	_wram:   [8192]byte,
	_hram:   [127]byte,

	// TODO: not sure I need to map this explicitly 
	// to peripherals that store their own data yet. 
	_io:     [127]byte,

	// Interrupts
	_ime:    bool,
	_ie:     byte,
	_if:     byte,

	// Peripherals (sound, screen, etc) 
	ppu:     Pixel_Processing_Unit,

	// emulation helpers 
	running: bool,
}

emulator_init :: proc(e: ^Emulator, rom: []byte) {
	// init 
	e._rom = rom
	e.pc = 0
	e.sp = 0xFFFE
	e._ime = false
	e._ie = 0
	e._if = 0

	// First 16KB of rom always goes into `rom0` 
	bank0 := len(rom) < MAX_ROM ? rom : rom[:MAX_ROM]
	copy_slice(e._rom0[:len(bank0)], bank0)
	e._bank = 0

	// We can fit entire rom in mem
	if len(rom) > MAX_ROM && len(rom) < (2 * MAX_ROM) {
		bank1 := rom[MAX_ROM:]
		copy_slice(e._romN[:len(bank1)], bank1)
		e._bank = 1
	}

	unimplemented()
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
		cycles := 0
		if should_interrupt(e) {
			cycles, err := interrupt(e)
			log.errorf("Error in Interrupt: %v\n", err)
			if fatal_error(err) do return err
		}

		opcode, opcode_err := fetch_opcode(e)
		log.errorf("Error in Fetch: %v\n", opcode_err)
		if fatal_error(opcode_err) do return opcode_err

		instr_cycles, execute_err := execute_instruction(e, opcode)
		log.errorf("Error in Execute Instruction: %v\n", execute_err)
		if fatal_error(execute_err) do return execute_err
		cycles += instr_cycles

		tick_err := tick_peripherals(e, cycles)
		log.errorf("Error in Tick Peripherals: %v\n", tick_err)
		if fatal_error(tick_err) do return tick_err
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
// ================== Hardware Registers =====================
// ===========================================================

JOYP :: 0xFF00 // Joypad
SB :: 0xFF01 // Serial Transfer Data
SC :: 0xFF02 // Serial Transfer Control 
DIV :: 0xFF04 // Divider Register
TIMA :: 0xFF05 // Timer Counter 
TMA :: 0xFF06 // Timer Modulo
TAC :: 0xFF07 // Timer Control 
IF :: 0xFF0F // Interrupt Flag 
LCDC :: 0xFF40 // LCD Control 
STAT :: 0xFF41 // LCD Status 
SCY :: 0xFF42 // Viewport Y Position 
SCX :: 0xFF43 // Viewport X Position 
LY :: 0xFF44 // LCD Y Coordinate 
LYC :: 0xFF45 // LY Compare
DMA :: 0xFF46 // OAM DMA Source Address & Start 
BGP :: 0xFF47 // BG Pallette Data 
OBP0 :: 0xFF48 // OBJ Pallette 0 Data 
OBP1 :: 0xFF49 // OBJ Pallette 1 Data 
WY :: 0xFF4A // Window Y Position 
WX :: 0xFF4B // Window X Position Plus 7 
IE :: 0xFFFF // Interrupt Enable 
NR10 :: 0xFF10 // Sound Channel 1 Sweep 
NR11 :: 0xFF11 // Sound Channel 1 Length Timer & Duty Cycle 
NR12 :: 0xFF12 // Sound Channel 1 Volumn & Envelope 
NR13 :: 0xFF13 // Sound Channel 1 Period Low 
NR14 :: 0xFF14 // Sound Channel 1 Period High & Control 
NR21 :: 0xFF16 // Sound Channel 2 Length Timer & Duty Cycle 
NR22 :: 0xFF17 // Sound Channel 2 Volume & Envelope
NR23 :: 0xFF18 // Sound Channel 2 Period Low 
NR24 :: 0xFF19 // Sound Channel 2 Period High & Control 
NR30 :: 0xFF1A // Sound Channel 3 DAC Enable 
NR31 :: 0xFF1B // Sound Channel 3 Length Timer 
NR32 :: 0xFF1C // Sound Channle 3 Output Level
NR33 :: 0xFF1D // Sound Channel 3 Period Low 
NR34 :: 0xFF1E // Sound Channel 3 Period High & Control 
NR41 :: 0xFF20 // Sound Channel 4 Length Timer 
NR42 :: 0xFF21 // Sound Channel 4 Volume & Envelope 
NR43 :: 0xFF22 // Sound Channel 4 Frequency & Randomness 
NR44 :: 0xFF23 // Sound Channel 4 Control 
NR50 :: 0xFF24 // Master Volume & VIN Panning 
NR51 :: 0xFF25 // Sound Panning 
NR52 :: 0xFF26 // Sound On/Off 
WAVE_RAM_START :: 0xFF30
WAVE_RAM_STOP :: 0xFF3F

// ===========================================================
// ======================= Interrupts ========================
// ===========================================================

// Interrupt Vectors 
VBLANK_VEC :: 0x0040
STAT_VEC :: 0x0048
TIMER_VEC :: 0x0050
SERIAL_VEC :: 0x0058
JOYPAD_VEC :: 0x0060

request_vblank :: #force_inline proc(e: ^Emulator) {e._if |= 0x01}
request_lcd :: #force_inline proc(e: ^Emulator) {e._if |= 0x02}
request_timer :: #force_inline proc(e: ^Emulator) {e._if |= 0x04}
request_serial :: #force_inline proc(e: ^Emulator) {e._if |= 0x08}
request_joypad :: #force_inline proc(e: ^Emulator) {e._if |= 0x10}

should_interrupt :: proc(e: ^Emulator) -> bool {
	if !e._ime do return false
	if e._ie == 0 do return false
	if e._if == 0 do return false
	return e._ie & e._if > 0
}

interrupt :: proc(e: ^Emulator) -> (cycles: int, err: Emulator_Error) {
	e._ime = false

	for i: uint = 0; i < 5; i += 1 {
		flag := e._if & (1 << i)
		if flag >> i == 1 {
			cycles += 2
			e._if &= ~flag // unset flag 
			stack_push_u16(e, e.pc) or_return // push pc 
			cycles += 2
			e.pc = get_interrupt_vector(flag) or_return // handle interrupt 
			cycles += 1
			return cycles, nil
		}
	}

	return cycles, nil
}

get_interrupt_vector :: proc(flag: byte) -> (u16, Emulator_Error) {
	switch flag {
	case 1:
		return VBLANK_VEC, nil // 0b00000001
	case 2:
		return STAT_VEC, nil // 0b00000010
	case 4:
		return TIMER_VEC, nil // 0b00000100
	case 8:
		return SERIAL_VEC, nil // ob0001000
	case 16:
		return JOYPAD_VEC, nil // 0b00010000
	case:
		return 0, .Unknown_Interrupt_Vector
	}
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
		return e._rom0[addr], nil
	case addr >= 0x4000 && addr <= 0x7FFF:
		return e._romN[addr - 0x4000], nil // TODO(alfie) - memory banking 
	case addr >= 0x8000 && addr <= 0x9FFF:
		return ppu_access(&e.ppu, addr)
	case addr >= 0xA000 && addr <= 0xBFFF:
		return e._rram[addr - 0xA000], nil
	case addr >= 0xC000 && addr <= 0xDFFF:
		return e._wram[addr - 0xC000], nil
	case addr >= 0xFE00 && addr <= 0xFE9F:
		return ppu_access(&e.ppu, addr)
	case addr >= 0xFF00 && addr <= 0xFF7F:
		return access_io(e, addr)
	//return e._io[addr - 0xFF00], nil
	case addr >= 0xFF80 && addr <= 0xFFFE:
		return e._hram[addr - 0xFF80], nil
	case addr == 0xFFFF:
		return e._ie, nil
	case:
		return 0x00, .Invalid_Access
	}
}

// It might be that we explicitly map the IO registers to their own 
// modules but for now it's just a flat map apart from interrupts. 
access_io :: proc(e: ^Emulator, addr: u16) -> (byte, Emulator_Error) {
	switch {
	case addr == IE:
		return e._ie, nil
	case addr == IF:
		return e._if, nil
	case addr >= 0xFF00 && addr <= 0xFF7F:
		return e._io[addr - 0xFF00], nil
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
		e._rram[addr - 0xA000] = val
	case addr >= 0xC000 && addr <= 0xDFFF:
		e._wram[addr - 0xC000] = val
	case addr >= 0xFE00 && addr <= 0xFE9F:
		return ppu_write(&e.ppu, addr, val)
	case addr >= 0xFF00 && addr <= 0xFF7F:
		return write_io(e, addr, val)
	case addr >= 0xFF80 && addr <= 0xFFFE:
		e._hram[addr - 0xFF80] = val
	case addr == 0xFFFF:
		e._ie = val
	case:
		return .Invalid_Write
	}

	return nil
}

// It might be that we explicitly map the IO registers to their own 
// modules but for now it's just a flat map apart from interrupts. 
write_io :: proc(e: ^Emulator, addr: u16, val: byte) -> Emulator_Error {
	switch {
	case addr == IE:
		e._ie = val
	case addr == IF:
		e._if = val
	case addr >= 0xFF00 && addr <= 0xFF7F:
		e._io[addr - 0xFF00] = val
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
	will_add_h_overflow_i16, 
}

will_add_h_overflow_u8 :: proc(a, b: u8) -> bool {
	return (a & 0x0F) + (b & 0x0F) > 0x0F
}

will_add_h_overflow_u16 :: proc(a, b: u16) -> bool {
	return (a & 0x0FFF) + (b & 0x0FFF) > 0x0FFF
}

will_add_h_overflow_i16 :: proc(a, b: i16) -> bool {
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

fatal_error :: proc(err: Emulator_Error) -> bool {
	return err == .Stack_Underflow || err == .Stack_Overflow
}
