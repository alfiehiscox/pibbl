package main

import "core:log"
import "core:testing"

@(test)
test_execute_ld_r16_imm16 :: proc(t: ^testing.T) {
	e: Emulator

	e.rom0[1], e.rom0[2] = 0x00, 0x04
	e.pc = 1

	cycles: int
	err: Emulator_Error

	cycles, err = execute_ld_r16_imm16(&e, 0b00000001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 3)
	testing.expect(t, e.bc == 0x0400)

	e.pc = 1

	cycles, err = execute_ld_r16_imm16(&e, 0b00010001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 3)
	testing.expect(t, e.de == 0x0400)

	e.pc = 1

	cycles, err = execute_ld_r16_imm16(&e, 0b00100001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 3)
	testing.expect(t, e.hl == 0x0400)

	e.pc = 1

	cycles, err = execute_ld_r16_imm16(&e, 0b00110001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 3)
	testing.expect(t, e.sp == 0x0400)
}


@(test)
test_execute_ld_r16mem_a :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1
	e.af = 0xBC00

	cycles: int
	err: Emulator_Error

	e.bc = 0xC0FF
	cycles, err = execute_ld_r16mem_a(&e, 0b00000010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	val, _ := access(&e, e.bc)
	testing.expectf(t, val == 0xBC, "exp=0xBC got=%X", val)

	e.de = 0xC0AA
	cycles, err = execute_ld_r16mem_a(&e, 0b00010010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	val, _ = access(&e, e.de)
	testing.expectf(t, val == 0xBC, "exp=0xBC got=%X", val)

	e.hl = 0xC011
	cycles, err = execute_ld_r16mem_a(&e, 0b00100010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	val, _ = access(&e, 0xC011)
	testing.expectf(t, val == 0xBC, "exp=0xBC got=%X", val)
	testing.expect(t, e.hl == 0xC011 + 1)

	e.hl = 0xC022
	cycles, err = execute_ld_r16mem_a(&e, 0b00110010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	val, _ = access(&e, 0xC022)
	testing.expectf(t, val == 0xBC, "exp=0xBC got=%X", val)
	testing.expect(t, e.hl == 0xC022 - 1)
}

@(test)
test_execute_ld_a_r16mem :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.af = 0x00BC
	e.wram[0x44] = 0x55 // addr: 0xC044
	e.bc = 0xC044
	cycles, err = execute_ld_a_r16mem(&e, 0b00001010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, byte(e.af >> 8) == 0x55)
	testing.expect(t, byte(e.af & 0x00FF) == 0xBC)

	e.af = 0x00BC
	e.wram[0x55] = 0x55 // addr: 0xC055
	e.de = 0xC055
	cycles, err = execute_ld_a_r16mem(&e, 0b00011010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, byte(e.af >> 8) == 0x55)
	testing.expect(t, byte(e.af & 0x00FF) == 0xBC)

	e.af = 0x00BC
	e.wram[0x66] = 0x55 // addr: 0xC066
	e.hl = 0xC066
	cycles, err = execute_ld_a_r16mem(&e, 0b00101010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, byte(e.af >> 8) == 0x55)
	testing.expect(t, e.hl == 0xC066 + 1)
	testing.expect(t, byte(e.af & 0x00FF) == 0xBC)

	e.af = 0x00BC
	e.wram[0x77] = 0x55 // addr: 0xC077
	e.hl = 0xC077
	cycles, err = execute_ld_a_r16mem(&e, 0b00111010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, byte(e.af >> 8) == 0x55)
	testing.expect(t, e.hl == 0xC077 - 1)
	testing.expect(t, byte(e.af & 0x00FF) == 0xBC)
}

@(test)
test_execute_ld_imm16_sp :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	e.rom0[e.pc], e.rom0[e.pc + 1] = 0x11, 0xC0

	cycles: int
	err: Emulator_Error

	e.sp = 0xABCD
	cycles, err = execute_ld_imm16_sp(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 5)
	testing.expect(t, e.pc == 3)
	testing.expect(t, e.wram[0x11] == 0xCD)
	testing.expect(t, e.wram[0x12] == 0xAB)
}

@(test)
test_execute_inc_r16 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.bc = 0x00FE
	cycles, err = execute_inc_r16(&e, 0b00000011)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.bc == 0x00FF)

	e.de = 0x00FE
	cycles, err = execute_inc_r16(&e, 0b00010011)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.de == 0x00FF)

	e.hl = 0x00FE
	cycles, err = execute_inc_r16(&e, 0b00100011)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.hl == 0x00FF)

	e.sp = 0x00FE
	cycles, err = execute_inc_r16(&e, 0b00110011)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.sp == 0x00FF)
}

@(test)
test_execute_dec_r16 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.bc = 0x00FE
	cycles, err = execute_dec_r16(&e, 0b00001011)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.bc == 0x00FD)

	e.de = 0x00FE
	cycles, err = execute_dec_r16(&e, 0b00011011)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.de == 0x00FD)

	e.hl = 0x00FE
	cycles, err = execute_dec_r16(&e, 0b00101011)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.hl == 0x00FD)

	e.sp = 0x00FE
	cycles, err = execute_dec_r16(&e, 0b00111011)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.sp == 0x00FD)
}

@(test)
test_execute_add_hl_r16 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// ===== bc ======
	// With no overflow
	e.hl = 0x0010
	e.bc = 0x000F
	e.af = 0xAB00
	f := u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00001001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expectf(t, u8(e.af & 0x00FF) == f, "f-before=%b, f-after=%b", f, u8(e.af & 0x00FF)) // no change
	testing.expect(t, e.hl == 0x001F)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)

	// With half overflow
	e.hl = 0x0FF1
	e.bc = 0x000F
	e.af = 0xAB00
	f = u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00001001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expect(t, u8(e.af & 0x00FF) == FLAG_HALF_CARRY)
	testing.expect(t, e.hl == 0x1000)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)

	// With full overflow + half overflow
	e.hl = 0x8FFF
	e.bc = 0x8001
	e.af = 0xAB00
	f = u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00001001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expect(t, u8(e.af) == FLAG_FULL_CARRY | FLAG_HALF_CARRY)
	testing.expect(t, e.hl == 0x1000)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)

	// ===== de ======
	//With no overflow
	e.hl = 0x0010
	e.de = 0x000F
	e.af = 0xAB00
	f = u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00011001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expect(t, u8(e.af & 0x00FF) == f) // no change
	testing.expect(t, e.hl == 0x001F)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)

	// With half overflow
	e.hl = 0x0FF1
	e.de = 0x000F
	e.af = 0xAB00
	f = u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00011001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expect(t, u8(e.af & 0x00FF) == FLAG_HALF_CARRY)
	testing.expect(t, e.hl == 0x1000)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)

	// With full overflow + half overflow
	e.hl = 0x8FFF
	e.de = 0x8001
	e.af = 0xAB00
	f = u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00011001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expect(t, u8(e.af & 0x00FF) == FLAG_FULL_CARRY | FLAG_HALF_CARRY)
	testing.expect(t, e.hl == 0x1000)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)

	//// ===== hl ======
	//// TODO: (alfie)

	// ===== sp ======
	// With no overflow
	e.hl = 0x0010
	e.sp = 0x000F
	e.af = 0xAB00
	f = u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00111001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expect(t, u8(e.af & 0x00FF) == f) // no change
	testing.expect(t, e.hl == 0x001F)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)

	// With half overflow
	e.hl = 0x0FF1
	e.sp = 0x000F
	e.af = 0xAB00
	f = u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00111001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expect(t, u8(e.af & 0x00FF) == FLAG_HALF_CARRY)
	testing.expect(t, e.hl == 0x1000)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)

	// With full overflow + half overflow
	e.hl = 0x8FFF
	e.sp = 0x8001
	e.af = 0xAB00
	f = u8(e.af & 0x00FF)
	cycles, err = execute_add_hl_r16(&e, 0b00111001)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, e.pc == 1)
	testing.expect(t, cycles == 2)
	testing.expect(t, u8(e.af & 0x00FF) == FLAG_FULL_CARRY | FLAG_HALF_CARRY)
	testing.expect(t, e.hl == 0x1000)
	testing.expect(t, (e.af & 0xFF00) >> 8 == 0xAB)
}

@(test)
test_execute_inc_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// b
	e.bc = 0xFF00
	e.af = 0
	cycles, err = execute_inc_r8(&e, 0b00000100)
	log.infof("e.af = %b", e.af)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.bc == 0x00)
	testing.expect(t, byte(e.af) == FLAG_ZERO | FLAG_HALF_CARRY) // set zero bit

	// c 
	e.bc = 0x000F
	e.af = 0
	cycles, err = execute_inc_r8(&e, 0b00001100)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.bc == 0x0010)
	testing.expect(t, byte(e.af) == FLAG_HALF_CARRY) // half carry

	// inc [hl] is different 
	e.wram[0x000F] = 0x80
	e.hl = 0xC00F
	cycles, err = execute_inc_r8(&e, 0b00110100)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.wram[0x000F] == 0x81)
	testing.expect(t, byte(e.af) == 0)
}

@(test)
test_execute_dec_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// d 
	e.de = 0xFF00
	e.af = 0
	cycles, err = execute_dec_r8(&e, 0b00010101)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.de == 0xFE00)
	testing.expect(t, byte(e.af) == FLAG_SUB)

	// e
	e.de = 0x0001
	e.af = 0
	cycles, err = execute_dec_r8(&e, 0b00011101)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.de == 0)
	testing.expect(t, byte(e.af) == FLAG_SUB | FLAG_ZERO)

	// dec [hl]
	e.wram[0x000F] = 0x10
	e.hl = 0xC00F
	e.af = 0
	cycles, err = execute_dec_r8(&e, 0b00110101)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e.wram[0x000F] == 0x0F)
	testing.expect(t, byte(e.af) == FLAG_SUB | FLAG_HALF_CARRY)
}
