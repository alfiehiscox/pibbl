package pibbl

import "core:encoding/endian"
import "core:log"
import "core:testing"

@(test)
test_execute_ld_r16_imm16 :: proc(t: ^testing.T) {
	e: Emulator

	e._rom0[1], e._rom0[2] = 0x00, 0x04
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
	e._wram[0x44] = 0x55 // addr: 0xC044
	e.bc = 0xC044
	cycles, err = execute_ld_a_r16mem(&e, 0b00001010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, byte(e.af >> 8) == 0x55)
	testing.expect(t, byte(e.af & 0x00FF) == 0xBC)

	e.af = 0x00BC
	e._wram[0x55] = 0x55 // addr: 0xC055
	e.de = 0xC055
	cycles, err = execute_ld_a_r16mem(&e, 0b00011010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, byte(e.af >> 8) == 0x55)
	testing.expect(t, byte(e.af & 0x00FF) == 0xBC)

	e.af = 0x00BC
	e._wram[0x66] = 0x55 // addr: 0xC066
	e.hl = 0xC066
	cycles, err = execute_ld_a_r16mem(&e, 0b00101010)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)
	testing.expect(t, byte(e.af >> 8) == 0x55)
	testing.expect(t, e.hl == 0xC066 + 1)
	testing.expect(t, byte(e.af & 0x00FF) == 0xBC)

	e.af = 0x00BC
	e._wram[0x77] = 0x55 // addr: 0xC077
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

	e._rom0[e.pc], e._rom0[e.pc + 1] = 0x11, 0xC0

	cycles: int
	err: Emulator_Error

	e.sp = 0xABCD
	cycles, err = execute_ld_imm16_sp(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 5)
	testing.expect(t, e.pc == 3)
	testing.expect(t, e._wram[0x11] == 0xCD)
	testing.expect(t, e._wram[0x12] == 0xAB)
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
	e._wram[0x000F] = 0x80
	e.hl = 0xC00F
	cycles, err = execute_inc_r8(&e, 0b00110100)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e._wram[0x000F] == 0x81)
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
	e._wram[0x000F] = 0x10
	e.hl = 0xC00F
	e.af = 0
	cycles, err = execute_dec_r8(&e, 0b00110101)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 1)
	testing.expect(t, e._wram[0x000F] == 0x0F)
	testing.expect(t, byte(e.af) == FLAG_SUB | FLAG_HALF_CARRY)
}

@(test)
test_execute_ld_r8_imm8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// h 
	e.hl = 0
	e._rom0[e.pc] = 0xFF
	cycles, err = execute_ld_r8_imm8(&e, 0b00100110)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 2)
	testing.expect(t, e.hl == 0xFF00)

	// l 
	e.pc = 1
	e.hl = 0
	e._rom0[e.pc] = 0xAB
	cycles, err = execute_ld_r8_imm8(&e, 0b00101110)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 2)
	testing.expect(t, e.hl == 0x00AB)

	// ld [hl],imm8
	e.pc = 1
	e._rom0[e.pc] = 0xAB
	e._wram[0x000F] = 0x00
	e.hl = 0xC00F
	cycles, err = execute_ld_r8_imm8(&e, 0b00110110)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 2)
	testing.expect(t, e._wram[0x000F] == 0xAB)
}

@(test)
test_execute_rlca :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.af = 0x7F00 | FLAG_FULL_CARRY

	// 0x01111111_00010000 
	// goes to 
	// 0x11111110_00000000

	cycles, err = execute_rlca(&e, 0x07)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0xFE00, "exp=0xFE00 got=0x%X", e.af)

	// 0x10101010_00000000
	// goes to 
	// 0x01010101_00010000

	e.af = 0xAA00
	cycles, err = execute_rlca(&e, 0x07)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x5510, "exp=0x5510 got=0x%X", e.af)

}

@(test)
test_execute_rrca :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// 0x01111111_00010000 
	// goes to 
	// 0x10111111_00010000

	e.af = 0x7F00 | FLAG_FULL_CARRY
	cycles, err = execute_rrca(&e, 0x0F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0xBF10, "exp=0xBF10 got=0x%X", e.af)

	// 0x10101011_00000000
	// goes to 
	// 0x11010101_00010000

	e.af = 0xAB00
	cycles, err = execute_rrca(&e, 0x0F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0xD510, "exp=0xD510 got=0x%X", e.af)

}

@(test)
test_execute_rla :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// 0x01111111_00010000 
	// goes to 
	// 0x11111111_00000000

	e.af = 0x7F00 | FLAG_FULL_CARRY
	cycles, err = execute_rla(&e, 0x17)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0xFF00, "exp=0xFF00 got=0x%X", e.af)

	// 0x11101011_00000000
	// goes to 
	// 0x11010110_00010000

	e.af = 0xEB00
	cycles, err = execute_rla(&e, 0x17)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0xD610, "exp=0xD610 got=0x%X", e.af)
}

@(test)
test_execute_rra :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// 0x01111111_00010000 
	// goes to 
	// 0x10111111_00010000

	e.af = 0x7F00 | FLAG_FULL_CARRY
	cycles, err = execute_rra(&e, 0x1F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0xBF10, "exp=0xBF10 got=0x%X", e.af)

	// 0x11101011_00000000
	// goes to 
	// 0x01110101_00010000

	e.af = 0xEB00
	cycles, err = execute_rra(&e, 0x1F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x7510, "exp=0x7510 got=0x%X", e.af)
}

@(test)
test_execute_dda :: proc(t: ^testing.T) {

	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// If the subtract flag is set with Half/Full Carry 
	// Adjustment will be 0x66 therefore a will be zero with no underflow
	e.af = 0x6600 | FLAG_SUB | FLAG_HALF_CARRY | FLAG_FULL_CARRY
	cycles, err = execute_dda(&e, 0x27)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		byte((e.af & 0xFF00) >> 8) == 0x00,
		"exp=0x00 got=%X",
		byte((e.af & 0xFF00) >> 8),
	)
	testing.expect(t, byte(e.af) == FLAG_ZERO | FLAG_SUB, "expected zero flag to be set")

	// If the subtract flag is set with half carry and underflow
	// Adjustment will be 0x06 therefore a will be 0xFF with carry set
	e.af = 0x0500 | FLAG_SUB | FLAG_HALF_CARRY
	cycles, err = execute_dda(&e, 0x27)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		byte((e.af & 0xFF00) >> 8) == 0xFF,
		"exp=0xFF got=%X",
		byte((e.af & 0xFF00) >> 8),
	)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY | FLAG_SUB, "expected carry flag to be set")

	// If the subtract flag is NOT set with Half/Full Carry 
	// Adjustment will be 0x66 therefore a will 0xCC with no overflow
	e.af = 0x6600 | FLAG_HALF_CARRY | FLAG_FULL_CARRY
	cycles, err = execute_dda(&e, 0x27)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		byte((e.af & 0xFF00) >> 8) == 0xCC,
		"exp=0xCC got=%X",
		byte((e.af & 0xFF00) >> 8),
	)
	testing.expectf(
		t,
		byte(e.af) == FLAG_SUB | FLAG_FULL_CARRY,
		"expected carry flag to be set: flag=%b",
		byte(e.af),
	)

	// If the subtract flag is NOT set with half carry and overflow
	// Adjustment will be 0x66 therefore a will be 0x04 with carry set
	e.af = 0xFE00 | FLAG_HALF_CARRY
	cycles, err = execute_dda(&e, 0x27)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		byte((e.af & 0xFF00) >> 8) == 0x64,
		"exp=0x64 got=%X",
		byte((e.af & 0xFF00) >> 8),
	)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY | FLAG_SUB, "expected carry flag to be set")
}

@(test)
test_execute_cpl :: proc(t: ^testing.T) {

	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// 0b10101011_00000000
	// goes to 
	// 0x01010100_00000000

	e.af = 0xAB00
	cycles, err = execute_cpl(&e, 0x2F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == 0x5400)

	// 0b11111111_00000000
	// goes to 
	// 0x00000000_00000000

	e.af = 0xFF00
	cycles, err = execute_cpl(&e, 0x2F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == 0x0000)
}

@(test)
test_execute_scf :: proc(t: ^testing.T) {

	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.af = 0x0000
	cycles, err = execute_scf(&e, 0x37)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == FLAG_FULL_CARRY)

	e.af = 0x0010
	cycles, err = execute_scf(&e, 0x37)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == FLAG_FULL_CARRY)
}

@(test)
test_execute_ccf :: proc(t: ^testing.T) {

	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.af = 0x0000
	cycles, err = execute_ccf(&e, 0x3F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == FLAG_FULL_CARRY, "exp=%x got=%x", FLAG_FULL_CARRY, e.af)

	e.af = 0x0010
	cycles, err = execute_ccf(&e, 0x3F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == 0)
}

@(test)
test_execute_jr_imm8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	// Jump positive offset 
	e.pc = 54
	e._rom0[e.pc] = 8

	cycles, err = execute_jr_imm8(&e, 0x18)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 63)

	// Jump negative offset
	e.pc = 68
	e._rom0[e.pc] = ~u8(24)

	cycles, err = execute_jr_imm8(&e, 0x18)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 44)
}

@(test)
test_execute_jr_cond_imm8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	// test nz - positive 
	e.af = 0
	e.pc = 12
	e._rom0[e.pc] = 24
	cycles, err = execute_jr_cond_imm8(&e, 0x20)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expectf(t, e.pc == 37, "exp=37 got=%d", e.pc)

	// test nz - negative
	e.af = FLAG_ZERO
	e.pc = 12
	e._rom0[e.pc] = 24
	cycles, err = execute_jr_cond_imm8(&e, 0x20)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.pc == 13, "exp=13 got=%d", e.pc)

	// test z - positive
	e.af = FLAG_ZERO
	e.pc = 12
	e._rom0[e.pc] = ~u8(6)
	cycles, err = execute_jr_cond_imm8(&e, 0x28)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expectf(t, e.pc == 6, "exp=6 got=%d", e.pc)

	// test z - negative
	e.af = 0
	e.pc = 12
	e._rom0[e.pc] = 24
	cycles, err = execute_jr_cond_imm8(&e, 0x28)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.pc == 13, "exp=13 got=%d", e.pc)

	// test nc - positive 
	e.af = 0
	e.pc = 12
	e._rom0[e.pc] = 10
	cycles, err = execute_jr_cond_imm8(&e, 0x30)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expectf(t, e.pc == 23, "exp=23 got=%d", e.pc)

	// test nc - negative
	e.af = FLAG_FULL_CARRY
	e.pc = 12
	e._rom0[e.pc] = 24
	cycles, err = execute_jr_cond_imm8(&e, 0x30)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.pc == 13, "exp=13 got=%d", e.pc)

	// test c - positive 
	e.af = FLAG_FULL_CARRY
	e.pc = 12
	e._rom0[e.pc] = 10
	cycles, err = execute_jr_cond_imm8(&e, 0x38)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expectf(t, e.pc == 23, "exp=23 got=%d", e.pc)

	// test c - negative
	e.af = 0
	e.pc = 12
	e._rom0[e.pc] = 24
	cycles, err = execute_jr_cond_imm8(&e, 0x38)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.pc == 13, "exp=13 got=%d", e.pc)

}

@(test)
test_execute_stop :: proc(t: ^testing.T) {
	testing.fail(t)
}

@(test)
test_execute_halt :: proc(t: ^testing.T) {
	testing.fail(t)
}

// TODO: should probably test Block 1 instructions 

@(test)
test_execute_add_a_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// Add with zero + full carry (c)
	e.af = 0x8000
	e.bc = 0x0080
	cycles, err = execute_block_2_instruction(&e, 0x81)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)

	testing.expectf(
		t,
		e.af == (0x0000 | FLAG_ZERO | FLAG_FULL_CARRY),
		"got=%X exp=%X",
		e.af,
		0x0000 | FLAG_ZERO | FLAG_FULL_CARRY,
	)

	// Add with half carry (b)
	e.af = 0x0F00
	e.bc = 0x0100
	cycles, err = execute_block_2_instruction(&e, 0x80)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == (0x1000 | FLAG_HALF_CARRY))

	// Add with [hl]
	e._wram[5] = 0x05
	e.hl = 0xC005
	e.af = 0x0000
	cycles, err = execute_block_2_instruction(&e, 0x86)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == 0x0500, "got=%X exp=0500", e.af)

	// Add a to a
	e.af = 0x4400
	cycles, err = execute_block_2_instruction(&e, 0x87)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == 0x8800)
}

@(test)
test_execute_adc_a_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// Add with zero + full carry (c)
	e.af = 0x8000 | FLAG_FULL_CARRY
	e.bc = 0x007F
	cycles, err = execute_block_2_instruction(&e, 0x89)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		e.af == (0x0000 | FLAG_ZERO | FLAG_FULL_CARRY),
		"got=%b exp=%b",
		e.af,
		0x0000 | FLAG_ZERO | FLAG_FULL_CARRY,
	)

	// Add with half carry (b)
	e.af = 0x0F00 | FLAG_FULL_CARRY
	e.bc = 0x0100
	cycles, err = execute_block_2_instruction(&e, 0x88)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == (0x1100 | FLAG_HALF_CARRY))

	// Add with [hl]
	e._wram[5] = 0x05
	e.hl = 0xC005
	e.af = 0x0000 | FLAG_FULL_CARRY
	cycles, err = execute_block_2_instruction(&e, 0x8E)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == 0x0600, "got=%X exp=0500", e.af)

	// Add a to a
	e.af = 0x4400 | FLAG_FULL_CARRY
	cycles, err = execute_block_2_instruction(&e, 0x8F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == 0x8900)
}

@(test)
test_execute_sub_a_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// Add with zero + full carry (c)
	e.af = 0x7E00
	e.bc = 0x0081
	cycles, err = execute_block_2_instruction(&e, 0x91)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		e.af == (0xFD00 | FLAG_FULL_CARRY),
		"got=%X exp=%X",
		e.af,
		0xFD00 | FLAG_FULL_CARRY,
	)

	// Add with half carry (b)
	e.af = 0x0F00
	e.bc = 0x0100
	cycles, err = execute_block_2_instruction(&e, 0x90)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x0E00, "got=%X exp=%X", e.af, 0x0E00)

	// Add with [hl]
	e._wram[5] = 0x05
	e.hl = 0xC005
	e.af = 0xFF00
	cycles, err = execute_block_2_instruction(&e, 0x96)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == 0xFA00, "got=%X exp=FB00", e.af)

	// Add a to a
	e.af = 0x4400
	cycles, err = execute_block_2_instruction(&e, 0x97)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == 0x0000 | FLAG_ZERO)
}

@(test)
test_execute_sbc_a_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// Add with zero + full carry (c)
	e.af = 0x7E00 | FLAG_FULL_CARRY
	e.bc = 0x0081
	cycles, err = execute_block_2_instruction(&e, 0x99)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		e.af == (0xFC00 | FLAG_FULL_CARRY),
		"got=%X exp=%X",
		e.af,
		0xFC00 | FLAG_FULL_CARRY,
	)

	// Add with half carry (b)
	e.af = 0x0F00 | FLAG_FULL_CARRY
	e.bc = 0x0100
	cycles, err = execute_block_2_instruction(&e, 0x98)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x0D00, "got=%X exp=%X", e.af, 0x0D00)

	// Add with [hl]
	e._wram[5] = 0x05
	e.hl = 0xC005
	e.af = 0xFF00 | FLAG_FULL_CARRY
	cycles, err = execute_block_2_instruction(&e, 0x9E)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == 0xF900, "got=%X exp=F900", e.af)

	// Add a to a
	e.af = 0x4400 | FLAG_FULL_CARRY
	cycles, err = execute_block_2_instruction(&e, 0x9F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		e.af == 0xFF00 | FLAG_FULL_CARRY | FLAG_HALF_CARRY,
		"got=%X exp=%X",
		e.af,
		0xFF00 | FLAG_FULL_CARRY | FLAG_HALF_CARRY,
	)
}

@(test)
test_execute_and_a_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.af = 0x7E00
	e.bc = 0x0081
	cycles, err = execute_block_2_instruction(&e, 0xA1)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		e.af == (0x0000 | FLAG_HALF_CARRY | FLAG_ZERO),
		"got=%X exp=%X",
		e.af,
		0x0000 | FLAG_HALF_CARRY | FLAG_ZERO,
	)

	e.af = 0x0F00
	e.bc = 0x0100
	cycles, err = execute_block_2_instruction(&e, 0xA0)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		e.af == 0x0100 | FLAG_HALF_CARRY,
		"got=%X exp=%X",
		e.af,
		0x0100 | FLAG_HALF_CARRY,
	)

	// Add with [hl]
	e._wram[5] = 0x05
	e.hl = 0xC005
	e.af = 0xFF00
	cycles, err = execute_block_2_instruction(&e, 0xA6)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == 0x0500 | FLAG_HALF_CARRY, "got=%X exp=0520", e.af)

	// Add a to a
	e.af = 0x4400
	cycles, err = execute_block_2_instruction(&e, 0xA7)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		e.af == 0x4400 | FLAG_HALF_CARRY,
		"got=%X exp=%X",
		e.af,
		0x4400 | FLAG_HALF_CARRY,
	)
}

@(test)
test_execute_xor_a_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1
	cycles: int
	err: Emulator_Error

	e.af = 0x7E00
	e.bc = 0x0081
	cycles, err = execute_block_2_instruction(&e, 0xA9)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == (0xFF00), "got=%X exp=%X", e.af, 0xFF00)

	e.af = 0x0F00
	e.bc = 0x0100
	cycles, err = execute_block_2_instruction(&e, 0xA8)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x0E00, "got=%X exp=%X", e.af, 0x0E00)

	// Add with [hl]
	e._wram[5] = 0x05
	e.hl = 0xC005
	e.af = 0xFF00
	cycles, err = execute_block_2_instruction(&e, 0xAE)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == 0xFA00, "got=%X exp=FA00", e.af)

	// Add a to a
	e.af = 0x4400
	cycles, err = execute_block_2_instruction(&e, 0xAF)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x0000 | FLAG_ZERO, "got=%X exp=%X", e.af, 0x0000 | FLAG_ZERO)
}

@(test)
test_execute_or_a_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.af = 0x7E00
	e.bc = 0x0081
	cycles, err = execute_block_2_instruction(&e, 0xB1)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0xFF00, "got=%X exp=%X", e.af, 0xFF00)

	e.af = 0x0F00
	e.bc = 0x0100
	cycles, err = execute_block_2_instruction(&e, 0xB0)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x0F00, "got=%X exp=%X", e.af, 0x0F00)

	// Add with [hl]
	e._wram[5] = 0x05
	e.hl = 0xC005
	e.af = 0xFF00
	cycles, err = execute_block_2_instruction(&e, 0xB6)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == 0xFF00, "got=%X exp=FF00", e.af)

	// Add a to a
	e.af = 0x4400
	cycles, err = execute_block_2_instruction(&e, 0xB7)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x4400, "got=%X exp=%X", e.af, 0x4400)
}

@(test)
test_execute_cp_a_r8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// Add with zero + full carry (c)
	e.af = 0x7E00
	e.bc = 0x0081
	cycles, err = execute_block_2_instruction(&e, 0xB9)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(
		t,
		e.af == (0x7E00 | FLAG_FULL_CARRY),
		"got=%X exp=%X",
		e.af,
		0x7E00 | FLAG_FULL_CARRY,
	)

	// Add with half carry (b)
	e.af = 0x0F00
	e.bc = 0x0100
	cycles, err = execute_block_2_instruction(&e, 0xB8)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expectf(t, e.af == 0x0F00, "got=%X exp=%X", e.af, 0x0E00)

	// Add with [hl]
	e._wram[5] = 0x05
	e.hl = 0xC005
	e.af = 0xFF00
	cycles, err = execute_block_2_instruction(&e, 0xBE)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == 0xFF00, "got=%X exp=FF00", e.af)

	// Add a to a
	e.af = 0x4400
	cycles, err = execute_block_2_instruction(&e, 0xBF)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.af == 0x4400 | FLAG_ZERO)
}

@(test)
test_execute_add_a_imm8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// Add with zero + full carry (c)
	e.af = 0x8000
	e._rom0[e.pc] = 0x80
	cycles, err = execute_block_3_instruction(&e, 0xC6)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 2)
	testing.expectf(
		t,
		e.af == (0x0000 | FLAG_ZERO | FLAG_FULL_CARRY),
		"got=%X exp=%X",
		e.af,
		0x0000 | FLAG_ZERO | FLAG_FULL_CARRY,
	)

	e.pc += 1

	// Add with half carry (b)
	e.af = 0x0F00
	e._rom0[e.pc] = 0x01
	cycles, err = execute_block_3_instruction(&e, 0xC6)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 4)
	testing.expect(t, e.af == (0x1000 | FLAG_HALF_CARRY))
}

@(test)
test_execute_adc_a_imm8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	// Add with zero + full carry (c)
	e.af = 0x8000 | FLAG_FULL_CARRY
	e._rom0[e.pc] = 0x7F
	cycles, err = execute_block_3_instruction(&e, 0xCE)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 2)
	testing.expectf(
		t,
		e.af == (0x0000 | FLAG_ZERO | FLAG_FULL_CARRY),
		"got=%b exp=%b",
		e.af,
		0x0000 | FLAG_ZERO | FLAG_FULL_CARRY,
	)

	e.pc += 1

	// Add with half carry (b)
	e.af = 0x0F00 | FLAG_FULL_CARRY
	e._rom0[e.pc] = 0x01
	cycles, err = execute_block_3_instruction(&e, 0xCE)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 4)
	testing.expect(t, e.af == (0x1100 | FLAG_HALF_CARRY))
}

// TODO: Probably do the rest of a imm8 arithmetic tests

@(test)
test_execute_ret_cond :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	sp_0 := e.sp
	_ = stack_push_u16(&e, 0xCCCC)
	sp_1 := e.sp
	_ = stack_push_u16(&e, 0x0024)

	// ret if nz - fail 
	e.pc = 1
	e.af = 0 | FLAG_ZERO
	cycles, err = execute_block_3_instruction(&e, 0xC0)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 1)

	// Jump if nz - success 
	e.pc = 1
	e.af = 0
	cycles, err = execute_block_3_instruction(&e, 0xC0)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 5)
	testing.expect(t, e.pc == 0x24)
	testing.expect(t, e.sp == sp_1)

	// Jump if c - success 
	e.pc = 1
	e.af = 0 | FLAG_FULL_CARRY
	cycles, err = execute_block_3_instruction(&e, 0xD8)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 5)
	testing.expect(t, e.pc == 0xCCCC)
	testing.expect(t, e.sp == sp_0)
}

@(test)
test_execute_ret :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	_ = stack_push_u16(&e, 0xCCCC)
	sp := e.sp
	_ = stack_push_u16(&e, 0x0024)

	cycles, err = execute_block_3_instruction(&e, 0xC9)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x0024)
	testing.expect(t, e.sp == sp)
}

@(test)
test_execute_reti :: proc(t: ^testing.T) {
	testing.fail(t)
}

@(test)
test_execute_jp_cond_imm8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	copy_slice(e._rom0[e.pc:e.pc + 2], []byte{0x22, 0x00})

	// Jump if nz - fail 
	e.pc = 1
	e.af = 0 | FLAG_ZERO
	cycles, err = execute_block_3_instruction(&e, 0xC2)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 3)

	// Jump if nz - success 
	e.pc = 1
	e.af = 0
	cycles, err = execute_block_3_instruction(&e, 0xC2)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x22)

	// Jump if c - success 
	e.pc = 1
	e.af = 0 | FLAG_FULL_CARRY
	cycles, err = execute_block_3_instruction(&e, 0xDA)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x22)

	// Jump if nc - fail 
	e.pc = 1
	e.af = 0 | FLAG_FULL_CARRY
	cycles, err = execute_block_3_instruction(&e, 0xD2)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 3)

}

@(test)
test_execute_jp_imm8 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	copy_slice(e._rom0[e.pc:e.pc + 2], []byte{0x22, 0x00})

	cycles, err = execute_block_3_instruction(&e, 0xC3)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x22)
}

@(test)
test_execute_jp_hl :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error

	e.hl = 0x2200
	cycles, err = execute_block_3_instruction(&e, 0xE9)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 1)
	testing.expect(t, e.pc == 0x2200)
}

@(test)
test_execute_call_imm16 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1
	sp := e.sp

	cycles: int
	err: Emulator_Error

	copy_slice(e._rom0[e.pc:e.pc + 2], []byte{0x22, 0x00})

	cycles, err = execute_block_3_instruction(&e, 0xCD)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 6)
	testing.expect(t, e.pc == 0x22)
	testing.expect(t, e.sp == sp - 2)

	addr, _ := stack_pop_u16(&e)
	testing.expectf(t, addr == 4, "got=%d exp=%d", addr, 4)
}

@(test)
test_execute_call_cond_imm16 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1
	sp := e.sp

	cycles: int
	err: Emulator_Error
	addr: u16

	copy_slice(e._rom0[e.pc:e.pc + 2], []byte{0x22, 0x00})

	// Jump if nz - fail 
	e.pc = 1
	e.af = 0 | FLAG_ZERO
	cycles, err = execute_block_3_instruction(&e, 0xC4)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 3)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 4, "got=%d exp=%d", addr, 4)

	// Jump if nz - success 
	e.pc = 1
	e.af = 0
	cycles, err = execute_block_3_instruction(&e, 0xC4)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 6)
	testing.expect(t, e.pc == 0x22)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 4, "got=%d exp=%d", addr, 4)

	// Jump if c - success 
	e.pc = 1
	e.af = 0 | FLAG_FULL_CARRY
	cycles, err = execute_block_3_instruction(&e, 0xDC)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 6)
	testing.expect(t, e.pc == 0x22)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 4, "got=%d exp=%d", addr, 4)

	// Jump if nc - fail 
	e.pc = 1
	e.af = 0 | FLAG_FULL_CARRY
	cycles, err = execute_block_3_instruction(&e, 0xD4)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 3)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 4, "got=%d exp=%d", addr, 4)

	testing.expect(t, e.sp == sp)

}

@(test)
test_execute_rst_tgt3 :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1

	cycles: int
	err: Emulator_Error
	addr: u16

	cycles, err = execute_block_3_instruction(&e, 0xC7)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 2, "got=%d exp=%d", addr, 2)

	e.pc = 1
	cycles, err = execute_block_3_instruction(&e, 0xCF)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x08)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 2, "got=%d exp=%d", addr, 2)

	e.pc = 1
	cycles, err = execute_block_3_instruction(&e, 0xD7)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x10)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 2, "got=%d exp=%d", addr, 2)

	e.pc = 1
	cycles, err = execute_block_3_instruction(&e, 0xDF)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x18)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 2, "got=%d exp=%d", addr, 2)

	e.pc = 1
	cycles, err = execute_block_3_instruction(&e, 0xE7)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x20)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 2, "got=%d exp=%d", addr, 2)

	e.pc = 1
	cycles, err = execute_block_3_instruction(&e, 0xEF)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 2, "got=%d exp=%d", addr, 2)

	e.pc = 1
	cycles, err = execute_block_3_instruction(&e, 0xF7)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x30)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 2, "got=%d exp=%d", addr, 2)

	e.pc = 1
	cycles, err = execute_block_3_instruction(&e, 0xFF)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0x38)

	addr, _ = stack_pop_u16(&e)
	testing.expectf(t, addr == 2, "got=%d exp=%d", addr, 2)
}

@(test)
test_execute_push_r16stk :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1
	sp := e.sp

	value: u16
	cycles: int
	err: Emulator_Error

	// push bc
	e.bc = 0xAAAA
	cycles, err = execute_block_3_instruction(&e, 0xC5)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.sp == sp - 2)

	value, _ = stack_pop_u16(&e)
	testing.expectf(t, value == e.bc, "got=%d exp=%d", value, 2)

	// push de 
	e.de = 0xBBBB
	cycles, err = execute_block_3_instruction(&e, 0xD5)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.sp == sp - 2)

	value, _ = stack_pop_u16(&e)
	testing.expectf(t, value == e.de, "got=%d exp=%d", value, e.de)

	// push hl 
	e.hl = 0xCCCC
	cycles, err = execute_block_3_instruction(&e, 0xE5)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.sp == sp - 2)

	value, _ = stack_pop_u16(&e)
	testing.expectf(t, value == e.hl, "got=%d exp=%d", value, e.hl)

	// push af 
	e.af = 0xDDDD
	cycles, err = execute_block_3_instruction(&e, 0xF5)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.sp == sp - 2)

	value, _ = stack_pop_u16(&e)
	testing.expectf(t, value == e.af, "got=%d exp=%d", value, e.af)
}

@(test)
test_execute_pop_r16stk :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 1
	sp := e.sp

	addr: u16
	cycles: int
	err: Emulator_Error

	// pop bc
	stack_push_u16(&e, 0xAAAA)
	cycles, err = execute_block_3_instruction(&e, 0xC1)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, sp == e.sp)
	testing.expect(t, e.bc == 0xAAAA)

	// pop de 
	stack_push_u16(&e, 0xBBBB)
	cycles, err = execute_block_3_instruction(&e, 0xD1)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, sp == e.sp)
	testing.expect(t, e.de == 0xBBBB)

	// pop hl 
	stack_push_u16(&e, 0xCCCC)
	cycles, err = execute_block_3_instruction(&e, 0xE1)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, sp == e.sp)
	testing.expect(t, e.hl == 0xCCCC)

	// pop af 
	stack_push_u16(&e, 0xDDDD)
	cycles, err = execute_block_3_instruction(&e, 0xF1)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, sp == e.sp)
	testing.expect(t, e.af == 0xDDDD)
}

@(test)
test_stack_byte :: proc(t: ^testing.T) {
	e: Emulator
	e.sp = 0xFFFE
	err: Emulator_Error

	err = stack_push_byte(&e, 0x01)
	testing.expectf(t, err == nil, "err=%s", err)
	err = stack_push_byte(&e, 0x02)
	testing.expectf(t, err == nil, "err=%s", err)
	err = stack_push_byte(&e, 0x03)
	testing.expectf(t, err == nil, "err=%s", err)
	err = stack_push_byte(&e, 0x04)
	testing.expectf(t, err == nil, "err=%s", err)

	testing.expect(t, e.sp == 0xFFFE - 4)

	b: byte

	b, err = stack_pop_byte(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, b == 0x04)

	b, err = stack_pop_byte(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, b == 0x03)

	b, err = stack_pop_byte(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, b == 0x02)

	b, err = stack_pop_byte(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, b == 0x01)

	testing.expect(t, e.sp == 0xFFFE)
}

@(test)
test_stack_u16 :: proc(t: ^testing.T) {
	e: Emulator
	e.sp = 0xFFFE
	err: Emulator_Error

	err = stack_push_u16(&e, 0x01)
	testing.expectf(t, err == nil, "err=%s", err)
	err = stack_push_u16(&e, 0x02)
	testing.expectf(t, err == nil, "err=%s", err)
	err = stack_push_u16(&e, 0x03)
	testing.expectf(t, err == nil, "err=%s", err)
	err = stack_push_u16(&e, 0x04)
	testing.expectf(t, err == nil, "err=%s", err)

	testing.expect(t, e.sp == 0xFFFE - 8)

	b: u16

	b, err = stack_pop_u16(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, b == 0x04)

	b, err = stack_pop_u16(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, b == 0x03)

	b, err = stack_pop_u16(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, b == 0x02)

	b, err = stack_pop_u16(&e)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, b == 0x01)

	testing.expect(t, e.sp == 0xFFFE)
}

@(test)
test_prefix_rlc_r8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	// rlc b
	e.af = 0
	e.bc = 0xFF00
	cycles, err = execute_prefix_instruction(&e, 0)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.bc == 0xFF00);testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)

	// rlc l 
	e.af = 0
	e.hl = 0x0080
	cycles, err = execute_prefix_instruction(&e, 5)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.hl == 0x0001, "exp=%X act=%X", 0x0001, e.hl)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)

	// rlc e 
	e.af = 0
	e.de = 0x0000
	cycles, err = execute_prefix_instruction(&e, 3)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.de == 0x0000)
	testing.expect(t, byte(e.af) == FLAG_ZERO)

	// rlc [hl]
	e.af = 0
	e.hl = 0xC001
	e._wram[1] = 0xAB
	cycles, err = execute_prefix_instruction(&e, 6)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e._wram[1] == 0x57)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)
}

@(test)
test_prefix_rrc_r8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	e.af = 0
	e.bc = 0xFF00
	cycles, err = execute_prefix_instruction(&e, 0x8)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.bc == 0xFF00)
	testing.expectf(t, byte(e.af) == FLAG_FULL_CARRY, "exp=%b got=%b", FLAG_FULL_CARRY, byte(e.af))

	e.af = 0
	e.hl = 0x0080
	cycles, err = execute_prefix_instruction(&e, 0xD)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.hl == 0x0040, "exp=%X act=%X", 0x0040, e.hl)
	testing.expect(t, byte(e.af) == 0)

	e.af = 0
	e.bc = 0x0001
	cycles, err = execute_prefix_instruction(&e, 0x9)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.bc == 0x0080, "exp=%X act=%X", 0x0080, e.bc)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)

	e.af = 0
	e.de = 0x0000
	cycles, err = execute_prefix_instruction(&e, 0xB)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.de == 0x0000)
	testing.expect(t, byte(e.af) == FLAG_ZERO)

	e.af = 0
	e.hl = 0xC001
	e._wram[1] = 0xAB
	cycles, err = execute_prefix_instruction(&e, 0xE)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e._wram[1] == 0xD5)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)
}

@(test)
test_prefix_rl_r8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	// rl b
	e.af = 0
	e.bc = 0xFF00
	cycles, err = execute_prefix_instruction(
		&e,
		0x10,
	);testing.expectf(t, err == nil, "err=%s", err);testing.expect(t, cycles == 2);testing.expect(t, e.bc == 0xFE00)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)

	// rl l 
	e.af = 0
	e.hl = 0x0080
	cycles, err = execute_prefix_instruction(&e, 0x15)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.hl == 0x0000, "exp=%X act=%X", 0x0000, e.hl)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY | FLAG_ZERO)

	// rl e 
	e.af = 0 | FLAG_FULL_CARRY
	e.de = 0x0000
	cycles, err = execute_prefix_instruction(&e, 0x13)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.de == 0x0001)
	testing.expect(t, byte(e.af) == 0x00)

	// rl [hl]
	e.af = 0
	e.hl = 0xC001
	e._wram[1] = 0xAB // 0b10101011
	cycles, err = execute_prefix_instruction(&e, 0x16)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e._wram[1] == 0x56)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)
}

@(test)
test_prefix_rr_r8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	// rr b 
	e.af = 0
	e.bc = 0xFF00
	cycles, err = execute_prefix_instruction(&e, 0x18)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.bc == 0x7F00)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)

	// rr l 
	e.af = 0
	e.hl = 0x0080
	cycles, err = execute_prefix_instruction(&e, 0x1D)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.hl == 0x0040, "exp=%X act=%X", 0x0040, e.hl)
	testing.expect(t, byte(e.af) == 0)

	// rr c
	e.af = 0
	e.bc = 0x0001
	cycles, err = execute_prefix_instruction(&e, 0x19)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.bc == 0x0000, "exp=%X act=%X", 0x0000, e.bc)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY | FLAG_ZERO)

	// rr e 
	e.af = 0 | FLAG_FULL_CARRY
	e.de = 0x0000
	cycles, err = execute_prefix_instruction(&e, 0x1B)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.de == 0x0080)
	testing.expect(t, byte(e.af) == 0)

	// rr [hl]
	e.af = 0
	e.hl = 0xC001
	e._wram[1] = 0xAB
	cycles, err = execute_prefix_instruction(&e, 0x1E)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e._wram[1] == 0x55)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)
}

@(test)
test_prefix_sla_r8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	// sla b 
	e.af = 0
	e.bc = 0xFF00
	cycles, err = execute_prefix_instruction(&e, 0x20)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.bc == 0xFE00)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)

	// sla l 
	e.af = 0
	e.hl = 0x0080
	cycles, err = execute_prefix_instruction(&e, 0x25)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.hl == 0x0000, "exp=%X act=%X", 0x0000, e.hl)
	testing.expect(t, byte(e.af) == FLAG_ZERO | FLAG_FULL_CARRY)

	// sla [hl]
	e.af = 0
	e.hl = 0xC001
	e._wram[1] = 0xAB
	cycles, err = execute_prefix_instruction(&e, 0x26)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e._wram[1] == 0x56)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)
}

@(test)
test_prefix_sra_r8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	// sra b 
	e.af = 0
	e.bc = 0xFF00
	cycles, err = execute_prefix_instruction(&e, 0x28)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.bc == 0xFF00)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)

	// sra l 
	e.af = 0
	e.hl = 0x0080
	cycles, err = execute_prefix_instruction(&e, 0x2D)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.hl == 0x00C0, "exp=%X act=%X", 0x00C0, e.hl)
	testing.expect(t, byte(e.af) == 0)

	// sra [hl]
	e.af = 0
	e.hl = 0xC001
	e._wram[1] = 0xAB
	cycles, err = execute_prefix_instruction(&e, 0x2E)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e._wram[1] == 0xD5)
	testing.expect(t, byte(e.af) == FLAG_FULL_CARRY)
}

@(test)
test_prefix_swap_r8 :: proc(t: ^testing.T) {
	e: Emulator

	cycles: int
	err: Emulator_Error

	// swap b
	e.bc = 0xABCD
	cycles, err = execute_prefix_instruction(&e, 0x30)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.bc == 0xBACD)

	// swap l
	e.af = 0xBB00
	e.hl = 0xAA00
	cycles, err = execute_prefix_instruction(&e, 0x35)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.hl == 0xAA00)
	testing.expect(t, e.af == 0xBB00 | FLAG_ZERO)

	// swap [hl]
	e.hl = 0xC002
	e._wram[2] = 0xCF
	cycles, err = execute_prefix_instruction(&e, 0x36)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e._wram[2] == 0xFC)
}

@(test)
test_prefix_srl_r8 :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error

	// srl c 
	e.bc = 0x00FF
	e.af = 0
	cycles, err = execute_prefix_instruction(&e, 0x39)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.bc == 0x007F)
	testing.expect(t, e.af == FLAG_FULL_CARRY)

	// srl l 
	e.hl = 0xAA
	e.af = FLAG_FULL_CARRY
	cycles, err = execute_prefix_instruction(&e, 0x3D)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.hl == 0x0055)
	testing.expect(t, e.af == 0)

	// srl [hl]
	e.af = 0
	e.hl = 0xC003
	e._wram[3] = 0xDE
	cycles, err = execute_prefix_instruction(&e, 0x3E)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e._wram[3] == 0x6F)
	testing.expect(t, e.af == 0)

	// srl a
	e.af = 0x0100
	cycles, err = execute_prefix_instruction(&e, 0x3F)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(
		t,
		e.af == 0x00 | FLAG_ZERO | FLAG_FULL_CARRY,
		"got=%b exp=%b",
		e.af,
		0x00 | FLAG_ZERO | FLAG_FULL_CARRY,
	)
}

@(test)
test_prefix_bit_b3_r8 :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error

	// bit 3 c
	e.af = 0
	e.bc = 0b0000_0000_0001_1000
	cycles, err = execute_prefix_instruction(&e, 0x59)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.af == FLAG_HALF_CARRY, "exp=%b act=%b", FLAG_HALF_CARRY, e.af)

	// bit 7 l
	e.af = 0
	e.hl = 0b0000_0000_0010_1000
	cycles, err = execute_prefix_instruction(&e, 0b01111101)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.af == FLAG_ZERO | FLAG_HALF_CARRY)

	// bit 0 [hl]
	e.af = 0
	e.hl = 0xC003
	e._wram[3] = 0x10
	cycles, err = execute_prefix_instruction(&e, 0b01000110)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.af == FLAG_ZERO | FLAG_HALF_CARRY)
}

@(test)
test_prefix_res_b3_r8 :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error

	// res 3 c
	e.af = 0
	e.bc = 0b0000_0000_0001_1000
	cycles, err = execute_prefix_instruction(&e, 0x99)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.bc == 0x0010, "exp=%b act=%b", 0x0010, e.bc)

	// res 7 l
	e.af = 0
	e.hl = 0b0000_0000_0010_1000
	cycles, err = execute_prefix_instruction(&e, 0xBD)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.hl == 0b0000_0000_0010_1000)

	// res 4 [hl]
	e.af = 0
	e.hl = 0xC003
	e._wram[3] = 0x10 // 00010000
	cycles, err = execute_prefix_instruction(&e, 0xA6)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e._wram[3] == 0)
}

@(test)
test_prefix_set_b3_r8 :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error

	// res 3 c
	e.af = 0
	e.bc = 0b0000_0000_0001_0000
	cycles, err = execute_prefix_instruction(&e, 0xD9)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expectf(t, e.bc == 0x0018, "exp=%b act=%b", 0x0018, e.bc)

	// res 7 l
	e.af = 0
	e.hl = 0b0000_0000_0010_1000
	cycles, err = execute_prefix_instruction(&e, 0xFD)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.hl == 0b0000_0000_1010_1000)

	// res 2 [hl]
	e.af = 0
	e.hl = 0xC003
	e._wram[3] = 0x10 // 00010000
	cycles, err = execute_prefix_instruction(&e, 0xD6)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e._wram[3] == 0x14)
}

@(test)
test_ldh_c_a :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error
	value: byte

	e.pc = 2
	e.af = 0xBB00
	e.bc = 0x0012

	cycles, err = execute_block_3_instruction(&e, 0xE2)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	value, err = access(&e, 0xFF00 + 0x12)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, value == 0xBB)
}

@(test)
test_ldh_imm8_a :: proc(t: ^testing.T) {

	e: Emulator
	cycles: int
	err: Emulator_Error
	value: byte

	e.pc = 0xC002

	write(&e, e.pc, 0x12)
	e.af = 0xBB00

	cycles, err = execute_block_3_instruction(&e, 0xE0)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 0xC003)
	value, err = access(&e, 0xFF12)
	testing.expectf(t, value == 0xBB, "exp=0xBB got=%X", value)
}

@(test)
test_ld_imm16_a :: proc(t: ^testing.T) {

	e: Emulator
	cycles: int
	err: Emulator_Error
	value: u16
	ok: bool

	e.pc = 0xC000

	ok = endian.put_u16(e._wram[0:2], .Little, 0xC0AB)
	testing.expect(t, ok)
	e.af = 0xBB00

	cycles, err = execute_block_3_instruction(&e, 0xEA)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0xC002)

	values: []byte
	values, err = access_range(&e, 0xC0AB, 0xC0AD)
	testing.expectf(t, err == nil, "err=%s", err)
	defer delete(values)

	value, ok = endian.get_u16(values, .Little)
	testing.expectf(t, ok, "not okay")
	testing.expectf(t, value == 0xBB, "exp=0xBB got=%X", value)
}

@(test)
test_ld_a_c :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error

	e.pc = 2 
	e.af = 0 
	e.bc = 0x00AA
	write(&e, 0xFFAA, 0x12)

	cycles, err = execute_block_3_instruction(&e, 0xF2)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	a := (e.af & 0xFF00) >> 8
	testing.expectf(t, a == 0x12, "exp=12 got=%X", a)
}

@(test)
test_ldh_a_imm8 :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error

	e.pc = 0xC002 
	write(&e, e.pc, 0x12)
	write(&e, 0xC012, 0xAC)

	cycles, err = execute_block_3_instruction(&e, 0xF0)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 0xC003)
	a := (e.af & 0xFF00) >> 8
	testing.expectf(t, a == 0xAC, "exp=AC got=%X", a)
}

@(test)
test_ld_a_imm16 :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error

	e.af = 0
	e.pc = 0xC000
	ok := endian.put_u16(e._wram[0:2], .Little, 0xC0AB)
	testing.expect(t, ok)
	write(&e, 0xC0AB, 0xAA)

	cycles, err = execute_block_3_instruction(&e, 0xFA)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0xC002)
	a := (e.af & 0xFF00) >> 8
	testing.expectf(t, a == 0xAA, "exp=AA got=%X", a)
}

@(test)
test_add_sp_imm8 :: proc(t: ^testing.T) {
	e: Emulator
	cycles: int
	err: Emulator_Error

	// Test positive offset
	e.af = 0 
	e.sp = 0xFFF2
	e.pc = 0xC000
	write(&e, e.pc, 0x0F)
	cycles, err = execute_block_3_instruction(&e, 0xE8)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0xC001)
	value := 0xFFF2 + 0x0F
	testing.expect(t, e.sp == u16(value))
	testing.expectf(t, e.af == FLAG_FULL_CARRY | FLAG_HALF_CARRY , "got=%b", e.af)

	// Test negative offset
	e.af = 0 
	e.sp = 0xFFFE
	e.pc = 0xC000
	operand := ~u8(12) // -13
	write(&e, e.pc, operand)
	cycles, err = execute_block_3_instruction(&e, 0xE8)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 4)
	testing.expect(t, e.pc == 0xC001)
	testing.expectf(t, e.sp == (0xFFFE - 13), "exp=%x got=%x", (0xFFFE - 13), e.sp)
	testing.expectf(t, e.af == FLAG_HALF_CARRY | FLAG_FULL_CARRY, "got=%b", e.af)
}

@(test)
test_ld_hl_sp_imm8 :: proc(t: ^testing.T) {
	e: Emulator 
	cycles: int 
	err: Emulator_Error

	e.af = 0 
	e.hl = 0 
	e.sp = 0xFFF2
	e.pc = 0xC000
	write(&e, e.pc, 0x0F)
	cycles, err = execute_block_3_instruction(&e, 0xF8)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 0xC001)
	value := 0xFFF2 + 0x0F
	testing.expect(t, e.hl == u16(value))
	testing.expectf(t, e.af == FLAG_FULL_CARRY | FLAG_HALF_CARRY , "got=%b", e.af)

	e.af = 0 
	e.hl = 0 
	e.sp = 0xFFFE
	e.pc = 0xC000
	operand := ~u8(12) // -13
	write(&e, e.pc, operand)
	cycles, err = execute_block_3_instruction(&e, 0xF8)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.pc == 0xC001)
	testing.expectf(t, e.hl == (0xFFFE - 13), "exp=%x got=%x", (0xFFFE - 13), e.hl)
	testing.expectf(t, e.af == FLAG_HALF_CARRY | FLAG_FULL_CARRY, "got=%b", e.af)
}

@(test)
test_ld_sp_hl :: proc(t: ^testing.T) {
	e: Emulator 
	cycles: int 
	err: Emulator_Error

	e.hl = 0xFFF2
	e.sp = 0xFFFE
	e.pc = 0xC000
	cycles, err = execute_block_3_instruction(&e, 0xF9)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e.pc == 0xC000)
	testing.expect(t, e.sp == 0xFFF2)
}

@(test) 
test_ei_then_di :: proc(t: ^testing.T) {
	e: Emulator 
	cycles: int 
	err: Emulator_Error

	e._ime = true 
	e.pc = 0xC000 
	write(&e, e.pc, 0xF3) // di instruction 

	cycles, err = execute_block_3_instruction(&e, 0xFB) // ei instruction
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 2)
	testing.expect(t, e._ime == true)
	testing.expect(t, e.pc == 0xC001)
}

@(test)
test_ei_then_ld_sp_hl :: proc(t: ^testing.T) {
	e: Emulator 
	cycles: int 
	err: Emulator_Error

	e._ime = false
	e.pc = 0xC000 
	e.sp = 0xFFFE
	e.hl = 0xFFF0
	write(&e, e.pc, 0xF9) // ld sp, hl

	cycles, err = execute_block_3_instruction(&e, 0xFB)
	testing.expectf(t, err == nil, "err=%s", err)
	testing.expect(t, cycles == 3)
	testing.expect(t, e.sp == 0xFFF0)
	testing.expect(t, e.pc == 0xC001)
	testing.expect(t, e._ime == true )
}

















