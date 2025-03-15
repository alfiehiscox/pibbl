package pibbl

import "core:encoding/endian"

// The implementations basically follow the naming conventions and block  of 
// these listings founc here : https://gbdev.io/gb-opcodes/optables
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
		return 0, .Instruction_Not_Emulated
	}

	if source_reg == 0x06 || dest_reg == 0x06 {
		return 2, nil
	} else {
		return 1, nil
	}
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
		e.pc = stack_pop_u16(e) or_return
		return 4, nil
	case 0xD9:
		return execute_reti(e, opcode) // reti
	case 0xC2, 0xCA, 0xD2, 0xDA:
		return execute_jp_cond_imm8(e, opcode) // jp cond, imm16
	case 0xC3:
		return execute_jp_imm16(e, opcode) // jp imm16
	case 0xE9:
		e.pc = e.hl
		return 1, nil
	case 0xC4, 0xCC, 0xD4, 0xDC:
		return execute_call_cond_imm16(e, opcode) //call cond, imm16
	case 0xCD:
		return execute_call_imm16(e, opcode) // call imm16 
	case 0xC7, 0xCF, 0xD7, 0xDF, 0xE7, 0xEF, 0xF7, 0xFF:
		return execute_rst_tgt3(e, opcode) // rst tgt3
	case 0xC1, 0xD1, 0xE1, 0xF1:
		return execute_pop_r16stk(e, opcode) // pop r16stk
	case 0xC5, 0xD5, 0xE5, 0xF5:
		return execute_push_r16stk(e, opcode) // push r16stk
	case 0xCB:
		prefix_opcode := access(e, e.pc) or_return
		e.pc += 1
		return execute_prefix_instruction(e, prefix_opcode) // prefix
	case 0xE2:
		return execute_ldh_c_a(e, opcode) // ldh [c], a
	case 0xE0:
		return execute_ldh_imm8_a(e, opcode) // ldh [imm8], a
	case 0xEA:
		return execute_ld_imm16_a(e, opcode) // ld [imm16], a
	case 0xF2:
		return execute_ldh_a_c(e, opcode) // ldh a, [c]
	case 0xF0:
		return execute_ldh_a_imm8(e, opcode) // ldh a, [imm8]
	case 0xFA:
		return execute_a_imm16(e, opcode) // ld a, [imm16]
	case:
		return 0, .Instruction_Not_Emulated
	}
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

execute_prefix_instruction :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	switch opcode {
	case 0x00 ..= 0x07:
		return execute_rlc_r8(e, opcode)
	case 0x08 ..= 0x0F:
		return execute_rrc_r8(e, opcode)
	case 0x10 ..= 0x17:
		return execute_rl_r8(e, opcode)
	case 0x18 ..= 0x1F:
		return execute_rr_r8(e, opcode)
	case 0x20 ..= 0x27:
		return execute_sla_r8(e, opcode)
	case 0x28 ..= 0x2F:
		return execute_sra_r8(e, opcode)
	case 0x30 ..= 0x37:
		return execute_swap_r8(e, opcode)
	case 0x38 ..= 0x3F:
		return execute_srl_r8(e, opcode)
	case 0x40 ..= 0x7F:
		return execute_bit_b3_r8(e, opcode)
	case 0x80 ..= 0xBF:
		return execute_res_b3_r8(e, opcode)
	case 0xC0 ..= 0xFF:
		return execute_set_b3_r8(e, opcode)
	case:
		return 0, .Instruction_Not_Emulated
	}
}

// ===============================================================
// ===================== Block 0 Instructions ====================
// ===============================================================

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
	if !ok do return 0, .Invalid_Instruction

	reg := (opcode & 0x30) >> 4
	if err := set_r16_register(e, reg, val); err != nil {
		return 0, err
	} else {
		return 3, nil
	}
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
		return 0, .Instruction_Not_Emulated
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
		return 0, .Instruction_Not_Emulated
	}

	return 2, nil
}

execute_ld_imm16_sp :: #force_inline proc(e: ^Emulator) -> (cycles: int, err: Emulator_Error) {
	// ld [imm16], sp 

	val_bytes := access_range(e, e.pc, e.pc + 2) or_return
	defer delete(val_bytes)

	e.pc += 2

	addr, ok := endian.get_u16(val_bytes, .Little)
	if !ok do return 0, .Invalid_Instruction

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
		return 0, .Instruction_Not_Emulated
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
		e.bc -= 1 // dec bc
	case 1:
		e.de -= 1 // dec de
	case 2:
		e.hl -= 1 // dec hl
	case 3:
		e.sp -= 1 // dec sp
	case:
		return 0, .Instruction_Not_Emulated
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
		return 0, .Instruction_Not_Emulated
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
	reg := (opcode & 0x38) >> 3

	operand: u8
	switch reg {
	case 0:
		operand = u8((e.bc & 0xFF00) >> 8)
	case 1:
		operand = u8(e.bc)
	case 2:
		operand = u8((e.de & 0xFF00) >> 8)
	case 3:
		operand = u8(e.de)
	case 4:
		operand = u8((e.hl & 0xFF00) >> 8)
	case 5:
		operand = u8(e.hl)
	case 6:
		operand = access(e, e.hl) or_return
	case 7:
		operand = u8((e.af & 0xFF00) >> 8)
	case:
		return -1, .Instruction_Not_Emulated
	}

	if will_add_h_overflow(operand, 1) do f |= FLAG_HALF_CARRY
	if operand + 1 == 0 do f |= FLAG_ZERO

	set_r8_register(e, reg, operand + 1) or_return
	e.af = (e.af & 0xFF00) | u16(f)

	if reg == 6 {
		return 3, nil
	} else {
		return 1, nil
	}
}

execute_dec_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	f := 0
	reg := (opcode & 0x38) >> 3

	operand: u8
	switch reg {
	case 0:
		operand = u8((e.bc & 0xFF00) >> 8)
	case 1:
		operand = u8(e.bc)
	case 2:
		operand = u8((e.de & 0xFF00) >> 8)
	case 3:
		operand = u8(e.de)
	case 4:
		operand = u8((e.hl & 0xFF00) >> 8)
	case 5:
		operand = u8(e.hl)
	case 6:
		operand = access(e, e.hl) or_return
	case 7:
		operand = u8((e.af & 0xFF00) >> 8)
	case:
		return -1, .Instruction_Not_Emulated
	}

	if will_sub_h_underflow_u8(operand, 1) do f |= FLAG_HALF_CARRY
	if operand - 1 == 0 do f |= FLAG_ZERO

	f |= FLAG_SUB

	set_r8_register(e, reg, operand - 1) or_return
	e.af = (e.af & 0xFF00) | u16(f)

	if reg == 6 {
		return 3, nil
	} else {
		return 1, nil
	}
}

execute_ld_r8_imm8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := (opcode & 0x38) >> 3
	next := access(e, e.pc) or_return
	e.pc += 1
	set_r8_register(e, reg, next) or_return

	if reg == 6 {
		return 3, nil
	} else {
		return 2, nil
	}
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
		return 0, .Instruction_Not_Emulated
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

// ===============================================================
// ===================== Block 1 Instructions ====================
// ===============================================================


execute_halt :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	unimplemented()
}


// ===============================================================
// ===================== Block 3 Instructions ====================
// ===============================================================

execute_ret_cond :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	cond := (opcode & 0x18) >> 3
	f := byte(e.af)

	switch cond {
	case 0:
		if f & FLAG_ZERO != FLAG_ZERO {
			e.pc = stack_pop_u16(e) or_return
			return 5, nil
		}
	case 1:
		if f & FLAG_ZERO == FLAG_ZERO {
			e.pc = stack_pop_u16(e) or_return
			return 5, nil
		}
	case 2:
		if f & FLAG_FULL_CARRY != FLAG_FULL_CARRY {
			e.pc = stack_pop_u16(e) or_return
			return 5, nil
		}
	case 3:
		if f & FLAG_FULL_CARRY == FLAG_FULL_CARRY {
			e.pc = stack_pop_u16(e) or_return
			return 5, nil
		}
	}

	return 2, nil
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
	if !ok do return 0, .Invalid_Instruction

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
	if !ok do return 0, .Invalid_Instruction

	e.pc = val

	return 4, nil
}

execute_call_cond_imm16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	val_bytes := access_range(e, e.pc, e.pc + 2) or_return
	defer delete(val_bytes)

	e.pc += 2

	stack_push_u16(e, e.pc + 1) or_return

	val, ok := endian.get_u16(val_bytes, .Little)
	if !ok do return 0, .Invalid_Instruction

	cond := (opcode & 0x18) >> 3
	f := byte(e.af)

	switch cond {
	case 0:
		if f & FLAG_ZERO != FLAG_ZERO {
			e.pc = val
			return 6, nil
		}
	case 1:
		if f & FLAG_ZERO == FLAG_ZERO {
			e.pc = val
			return 6, nil
		}
	case 2:
		if f & FLAG_FULL_CARRY != FLAG_FULL_CARRY {
			e.pc = val
			return 6, nil
		}
	case 3:
		if f & FLAG_FULL_CARRY == FLAG_FULL_CARRY {
			e.pc = val
			return 6, nil
		}
	}

	return 3, nil
}

execute_call_imm16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	val_bytes := access_range(e, e.pc, e.pc + 2) or_return
	defer delete(val_bytes)

	e.pc += 2

	stack_push_u16(e, e.pc + 1) or_return

	val, ok := endian.get_u16(val_bytes, .Little)
	if !ok do return 0, .Invalid_Instruction

	e.pc = val

	return 6, nil
}

execute_pop_r16stk :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	switch (opcode & 0x30) >> 4 {
	case 0:
		e.bc = stack_pop_u16(e) or_return
	case 1:
		e.de = stack_pop_u16(e) or_return
	case 2:
		e.hl = stack_pop_u16(e) or_return
	case 3:
		e.af = stack_pop_u16(e) or_return
	}

	return 3, nil
}

execute_push_r16stk :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {

	switch (opcode & 0x30) >> 4 {
	case 0:
		stack_push_u16(e, e.bc) or_return
	case 1:
		stack_push_u16(e, e.de) or_return
	case 2:
		stack_push_u16(e, e.hl) or_return
	case 3:
		stack_push_u16(e, e.af) or_return
	case:
		return 0, .Instruction_Not_Emulated
	}

	return 4, nil
}


execute_rst_tgt3 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {

	tgt3 := (opcode & 0x38) >> 3
	vec := u16(tgt3) * 8

	stack_push_u16(e, e.pc + 1) or_return

	e.pc = vec

	return 4, nil
}


execute_ldh_a_imm8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_ldh_a_c :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_ld_imm16_a :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_ldh_imm8_a :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_ldh_c_a :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

execute_a_imm16 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycle: int,
	err: Emulator_Error,
) {
	unimplemented()
}

// ===============================================================
// ===================== Prefix Instructions =====================
// ===============================================================

execute_rlc_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	switch reg {
	case 0:
		b := byte((e.bc & 0xFF00) >> 8)
		most := (b & 0x80) >> 7
		new_b := b << 1 | most
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_b == 0 do new_f |= FLAG_ZERO
		e.bc = (u16(new_b) << 8) | (e.bc & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 1:
		c := byte(e.bc)
		most := (c & 0x80) >> 7
		new_c := c << 1 | most
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_c == 0 do new_f |= FLAG_ZERO
		e.bc = (e.bc & 0xFF00) | u16(new_c)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 2:
		d := byte((e.de & 0xFF00) >> 8)
		most := (d & 0x80) >> 7
		new_d := d << 1 | most
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_d == 0 do new_f |= FLAG_ZERO
		e.de = (u16(new_d) << 8) | (e.de & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 3:
		e2 := byte(e.de)
		most := (e2 & 0x80) >> 7
		new_e := e2 << 1 | most
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_e == 0 do new_f |= FLAG_ZERO
		e.de = (e.de & 0xFF00) | u16(new_e)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 4:
		h := byte((e.hl & 0xFF00) >> 8)
		most := (h & 0x80) >> 7
		new_h := h << 1 | most
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_h == 0 do new_f |= FLAG_ZERO
		e.hl = (u16(new_h) << 8) | (e.hl & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 5:
		l := byte(e.hl)
		most := (l & 0x80) >> 7
		new_l := l << 1 | most
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_l == 0 do new_f |= FLAG_ZERO
		e.hl = (e.hl & 0xFF00) | u16(new_l)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 6:
		byte := access(e, e.hl) or_return
		most := (byte & 0x80) >> 7
		new_byte := byte << 1 | most
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_byte == 0 do new_f |= FLAG_ZERO
		write(e, e.hl, new_byte) or_return
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 4, nil
	case 7:
		a := byte((e.af & 0xFF00) >> 8)
		most := (a & 0x80) >> 7
		new_a := a << 1 | most
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_a == 0 do new_f |= FLAG_ZERO
		e.af = (u16(new_a) << 8) | u16(new_f)
		return 2, nil
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_rrc_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	switch reg {
	case 0:
		b := byte((e.bc & 0xFF00) >> 8)
		least := b & 0x01 << 7
		new_b := b >> 1 | least
		new_f := least != 0x80 ? 0 : FLAG_FULL_CARRY
		if new_b == 0 do new_f |= FLAG_ZERO
		e.bc = (u16(new_b) << 8) | (e.bc & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 1:
		c := byte(e.bc)
		least := c & 0x01 << 7
		new_c := c >> 1 | least
		new_f := least != 0x80 ? 0 : FLAG_FULL_CARRY
		if new_c == 0 do new_f |= FLAG_ZERO
		e.bc = (e.bc & 0xFF00) | u16(new_c)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 2:
		d := byte((e.de & 0xFF00) >> 8)
		least := d & 0x01 << 7
		new_d := d >> 1 | least
		new_f := least != 0x80 ? 0 : FLAG_FULL_CARRY
		if new_d == 0 do new_f |= FLAG_ZERO
		e.de = (u16(new_d) << 8) | (e.de & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 3:
		e2 := byte(e.de)
		least := e2 & 0x01 << 7
		new_e := e2 >> 1 | least
		new_f := least != 0x80 ? 0 : FLAG_FULL_CARRY
		if new_e == 0 do new_f |= FLAG_ZERO
		e.de = (e.de & 0xFF00) | u16(new_e)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 4:
		h := byte((e.hl & 0xFF00) >> 8)
		least := h & 0x01 << 7
		new_h := h >> 1 | least
		new_f := least != 0x80 ? 0 : FLAG_FULL_CARRY
		if new_h == 0 do new_f |= FLAG_ZERO
		e.hl = (u16(new_h) << 8) | (e.hl & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 5:
		l := byte(e.hl)
		least := l & 0x01 << 7
		new_l := l >> 1 | least
		new_f := least != 0x80 ? 0 : FLAG_FULL_CARRY
		if new_l == 0 do new_f |= FLAG_ZERO
		e.hl = (e.hl & 0xFF00) | u16(new_l)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 6:
		byte := access(e, e.hl) or_return
		least := byte & 0x01 << 7
		new_byte := byte >> 1 | least
		new_f := least != 0x80 ? 0 : FLAG_FULL_CARRY
		if new_byte == 0 do new_f |= FLAG_ZERO
		write(e, e.hl, new_byte) or_return
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 4, nil
	case 7:
		a := byte((e.af & 0xFF00) >> 8)
		least := a & 0x01 << 7
		new_a := a >> 1 | least
		new_f := least != 0x80 ? 0 : FLAG_FULL_CARRY
		if new_a == 0 do new_f |= FLAG_ZERO
		e.af = (u16(new_a) << 8) | u16(new_f)
		return 2, nil
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_rl_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	switch reg {
	case 0:
		b := byte((e.bc & 0xFF00) >> 8)
		most := (b & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_b := b << 1 | carry
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_b == 0 do new_f |= FLAG_ZERO
		e.bc = (u16(new_b) << 8) | (e.bc & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 1:
		c := byte(e.bc)
		most := (c & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_c := c << 1 | carry
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_c == 0 do new_f |= FLAG_ZERO
		e.bc = (e.bc & 0xFF00) | u16(new_c)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 2:
		d := byte((e.de & 0xFF00) >> 8)
		most := (d & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_d := d << 1 | carry
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_d == 0 do new_f |= FLAG_ZERO
		e.de = (u16(new_d) << 8) | (e.de & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 3:
		e2 := byte(e.de)
		most := (e2 & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_e := e2 << 1 | carry
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_e == 0 do new_f |= FLAG_ZERO
		e.de = (e.de & 0xFF00) | u16(new_e)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 4:
		h := byte((e.hl & 0xFF00) >> 8)
		most := (h & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_h := h << 1 | carry
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_h == 0 do new_f |= FLAG_ZERO
		e.hl = (u16(new_h) << 8) | (e.hl & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 5:
		l := byte(e.hl)
		most := (l & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_l := l << 1 | carry
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_l == 0 do new_f |= FLAG_ZERO
		e.hl = (e.hl & 0xFF00) | u16(new_l)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 6:
		byte1 := access(e, e.hl) or_return
		most := (byte1 & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_byte := byte1 << 1 | carry
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_byte == 0 do new_f |= FLAG_ZERO
		write(e, e.hl, new_byte) or_return
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 4, nil
	case 7:
		a := byte((e.af & 0xFF00) >> 8)
		most := (a & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_a := a << 1 | carry
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_a == 0 do new_f |= FLAG_ZERO
		e.af = (u16(new_a) << 8) | u16(new_f)
		return 2, nil
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_rr_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	switch reg {
	case 0:
		b := byte((e.bc & 0xFF00) >> 8)
		least := b & 0x01
		carry := byte((e.af & FLAG_FULL_CARRY) << 3)
		new_b := b >> 1 | carry
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_b == 0 do new_f |= FLAG_ZERO
		e.bc = (u16(new_b) << 8) | (e.bc & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 1:
		c := byte(e.bc)
		least := c & 0x01
		carry := byte((e.af & FLAG_FULL_CARRY) << 3)
		new_c := c >> 1 | carry
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_c == 0 do new_f |= FLAG_ZERO
		e.bc = (e.bc & 0xFF00) | u16(new_c)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 2:
		d := byte((e.de & 0xFF00) >> 8)
		least := d & 0x01
		carry := byte((e.af & FLAG_FULL_CARRY) << 3)
		new_d := d >> 1 | carry
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_d == 0 do new_f |= FLAG_ZERO
		e.de = (u16(new_d) << 8) | (e.de & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 3:
		e2 := byte(e.de)
		least := e2 & 0x01
		carry := byte((e.af & FLAG_FULL_CARRY) << 3)
		new_e := e2 >> 1 | carry
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_e == 0 do new_f |= FLAG_ZERO
		e.de = (e.de & 0xFF00) | u16(new_e)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 4:
		h := byte((e.hl & 0xFF00) >> 8)
		least := h & 0x01
		carry := byte((e.af & FLAG_FULL_CARRY) << 3)
		new_h := h >> 1 | carry
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_h == 0 do new_f |= FLAG_ZERO
		e.hl = (u16(new_h) << 8) | (e.hl & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 5:
		l := byte(e.hl)
		least := l & 0x01
		carry := byte((e.af & FLAG_FULL_CARRY) << 3)
		new_l := l >> 1 | carry
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_l == 0 do new_f |= FLAG_ZERO
		e.hl = (e.hl & 0xFF00) | u16(new_l)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 6:
		byte1 := access(e, e.hl) or_return
		least := byte1 & 0x01
		carry := byte((e.af & FLAG_FULL_CARRY) << 3)
		new_byte := byte1 >> 1 | carry
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_byte == 0 do new_f |= FLAG_ZERO
		write(e, e.hl, new_byte) or_return
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 4, nil
	case 7:
		a := byte((e.af & 0xFF00) >> 8)
		least := a & 0x01
		carry := byte((e.af & FLAG_FULL_CARRY) << 3)
		new_a := a >> 1 | carry
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_a == 0 do new_f |= FLAG_ZERO
		e.af = (u16(new_a) << 8) | u16(new_f)
		return 2, nil
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_sla_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	switch opcode & 0x07 {
	case 0:
		b := byte((e.bc & 0xFF00) >> 8)
		most := (b & 0x80) >> 7
		new_b := b << 1
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_b == 0 do new_f |= FLAG_ZERO
		e.bc = (u16(new_b) << 8) | (e.bc & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 1:
		c := byte(e.bc)
		most := (c & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_c := c << 1
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_c == 0 do new_f |= FLAG_ZERO
		e.bc = (e.bc & 0xFF00) | u16(new_c)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 2:
		d := byte((e.de & 0xFF00) >> 8)
		most := (d & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_d := d << 1
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_d == 0 do new_f |= FLAG_ZERO
		e.de = (u16(new_d) << 8) | (e.de & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 3:
		e2 := byte(e.de)
		most := (e2 & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_e := e2 << 1
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_e == 0 do new_f |= FLAG_ZERO
		e.de = (e.de & 0xFF00) | u16(new_e)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 4:
		h := byte((e.hl & 0xFF00) >> 8)
		most := (h & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_h := h << 1
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_h == 0 do new_f |= FLAG_ZERO
		e.hl = (u16(new_h) << 8) | (e.hl & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 5:
		l := byte(e.hl)
		most := (l & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_l := l << 1
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_l == 0 do new_f |= FLAG_ZERO
		e.hl = (e.hl & 0xFF00) | u16(new_l)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 6:
		byte1 := access(e, e.hl) or_return
		most := (byte1 & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_byte := byte1 << 1
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_byte == 0 do new_f |= FLAG_ZERO
		write(e, e.hl, new_byte) or_return
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 4, nil
	case 7:
		a := byte((e.af & 0xFF00) >> 8)
		most := (a & 0x80) >> 7
		carry := byte((e.af & FLAG_FULL_CARRY) >> 4)
		new_a := a << 1
		new_f := most == 0 ? 0 : FLAG_FULL_CARRY
		if new_a == 0 do new_f |= FLAG_ZERO
		e.af = (u16(new_a) << 8) | u16(new_f)
		return 2, nil
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_sra_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	switch reg {
	case 0:
		b := byte((e.bc & 0xFF00) >> 8)
		most, least := b & 0x80, b & 0x01
		new_b := (b >> 1) | most
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_b == 0 do new_f |= FLAG_ZERO
		e.bc = (u16(new_b) << 8) | (e.bc & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 1:
		c := byte(e.bc)
		most, least := c & 0x80, c & 0x01
		new_c := (c >> 1) | most
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_c == 0 do new_f |= FLAG_ZERO
		e.bc = (e.bc & 0xFF00) | u16(new_c)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 2:
		d := byte((e.de & 0xFF00) >> 8)
		most, least := d & 0x80, d & 0x01
		new_d := (d >> 1) | most
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_d == 0 do new_f |= FLAG_ZERO
		e.de = (u16(new_d) << 8) | (e.de & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 3:
		e2 := byte(e.de)
		most, least := e2 & 0x80, e2 & 0x01
		new_e := (e2 >> 1) | most
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_e == 0 do new_f |= FLAG_ZERO
		e.de = (e.de & 0xFF00) | u16(new_e)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 4:
		h := byte((e.hl & 0xFF00) >> 8)
		most, least := h & 0x80, h & 0x01
		new_h := (h >> 1) | most
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_h == 0 do new_f |= FLAG_ZERO
		e.hl = (u16(new_h) << 8) | (e.hl & 0xFF)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 5:
		l := byte(e.hl)
		most, least := l & 0x80, l & 0x01
		new_l := (l >> 1) | most
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_l == 0 do new_f |= FLAG_ZERO
		e.hl = (e.hl & 0xFF00) | u16(new_l)
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 6:
		byte1 := access(e, e.hl) or_return
		most, least := byte1 & 0x80, byte1 & 0x01
		new_byte := (byte1 >> 1) | most
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_byte == 0 do new_f |= FLAG_ZERO
		write(e, e.hl, new_byte) or_return
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 4, nil
	case 7:
		a := byte((e.af & 0xFF00) >> 8)
		most, least := a & 0x80, a & 0x01
		new_a := (a >> 1) | most
		new_f := least == 0 ? 0 : FLAG_FULL_CARRY
		if new_a == 0 do new_f |= FLAG_ZERO
		e.bc = (u16(new_a) << 8) | u16(new_f)
		return 2, nil
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_swap_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	switch reg {
	case 0:
		b := byte((e.bc & 0xFF00) >> 8)
		b_high, b_low := (b & 0xF0) >> 4, b & 0x0F
		new_b := (b_low << 4) | b_high
		e.bc = (u16(new_b) << 8) | (e.bc & 0x00FF)
		if new_b == 0 do e.af = (e.af & 0xFF00) | FLAG_ZERO
		return 2, nil
	case 1:
		c := byte(e.bc)
		c_high, c_low := (c & 0xF0) >> 4, c & 0x0F
		new_c := (c_low << 4) | c_high
		e.bc = (e.bc & 0xFF00) | u16(new_c)
		if new_c == 0 do e.af = (e.af & 0xFF00) | FLAG_ZERO
		return 2, nil
	case 2:
		d := byte((e.de & 0xFF00) >> 8)
		d_high, d_low := (d & 0xF0) >> 4, d & 0x0F
		new_d := (d_low << 4) | d_high
		e.de = (u16(new_d) << 8) | (e.de & 0x00FF)
		if new_d == 0 do e.af = (e.af & 0xFF00) | FLAG_ZERO
		return 2, nil
	case 3:
		e1 := byte(e.de)
		e1_high, e1_low := (e1 & 0xF0) >> 4, e1 & 0x0F
		new_e1 := (e1_low << 4) | e1_high
		e.de = (e.de & 0xFF00) | u16(new_e1)
		if new_e1 == 0 do e.af = (e.af & 0xFF00) | FLAG_ZERO
		return 2, nil
	case 4:
		h := byte((e.hl & 0xFF00) >> 8)
		h_high, h_low := (h & 0xF0) >> 4, h & 0x0F
		new_h := (h_low << 4) | h_high
		e.hl = (u16(new_h) << 8) | (e.hl & 0x00FF)
		if new_h == 0 do e.af = (e.af & 0xFF00) | FLAG_ZERO
		return 2, nil
	case 5:
		l := byte(e.hl)
		l_high, l_low := (l & 0xF0) >> 4, l & 0x0F
		new_l := (l_low << 4) | l_high
		e.hl = (e.hl & 0xFF00) | u16(new_l)
		if new_l == 0 do e.af = (e.af & 0xFF00) | FLAG_ZERO
		return 2, nil
	case 6:
		byte := access(e, e.hl) or_return
		byte_high, byte_low := (byte & 0xF0) >> 4, byte & 0x0F
		new_byte := (byte_low << 4) | byte_high
		write(e, e.hl, new_byte) or_return
		if new_byte == 0 do e.af = (e.af & 0xFF00) | FLAG_ZERO
		return 4, nil
	case 7:
		a := byte((e.bc & 0xFF00) >> 8)
		a_high, a_low := (a & 0xF0) >> 4, a & 0x0F
		new_a := (a_low << 4) | a_high
		e.af = (u16(new_a) << 8) | (e.af & 0x00FF)
		if new_a == 0 do e.af = FLAG_ZERO
		return 2, nil
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_srl_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	switch reg {
	case 0:
		b := byte((e.bc & 0xFF00) >> 8)
		least := b & 0x1
		e.bc = u16(b >> 1) << 8 | (e.bc & 0x00FF)
		new_f := least == 1 ? FLAG_FULL_CARRY : 0
		if b == 1 do new_f |= FLAG_ZERO
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 1:
		c := byte(e.bc)
		least := c & 0x1
		e.bc = (e.bc & 0xFF00) | u16(c >> 1)
		new_f := least == 1 ? FLAG_FULL_CARRY : 0
		if c == 1 do new_f |= FLAG_ZERO
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 2:
		d := byte((e.de & 0xFF00) >> 8)
		least := d & 0x1
		e.de = u16(d >> 1) << 8 | (e.de & 0x00FF)
		new_f := least == 1 ? FLAG_FULL_CARRY : 0
		if d == 1 do new_f |= FLAG_ZERO
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 3:
		e1 := byte(e.de)
		least := e1 & 0x1
		e.de = (e.de & 0xFF00) | u16(e1 >> 1)
		new_f := least == 1 ? FLAG_FULL_CARRY : 0
		if e1 == 1 do new_f |= FLAG_ZERO
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 4:
		h := byte((e.hl & 0xFF00) >> 8)
		least := h & 0x1
		e.hl = u16(h >> 1) << 8 | (e.hl & 0x00FF)
		new_f := least == 1 ? FLAG_FULL_CARRY : 0
		if h == 1 do new_f |= FLAG_ZERO
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 5:
		l := byte(e.hl)
		least := l & 0x1
		e.hl = (e.hl & 0xFF00) | u16(l >> 1)
		new_f := least == 1 ? FLAG_FULL_CARRY : 0
		if l == 1 do new_f |= FLAG_ZERO
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 2, nil
	case 6:
		byte := access(e, e.hl) or_return
		least := byte & 0x01
		write(e, e.hl, byte >> 1) or_return
		new_f := least == 1 ? FLAG_FULL_CARRY : 0
		if byte == 1 do new_f |= FLAG_ZERO
		e.af = (e.af & 0xFF00) | u16(new_f)
		return 4, nil
	case 7:
		a := byte((e.af & 0xFF00) >> 8)
		least := a & 0x1
		new_f := least == 1 ? FLAG_FULL_CARRY : 0
		if a == 1 do new_f |= FLAG_ZERO
		e.af = (u16(a >> 1) << 8) | u16(new_f)
		return 2, nil
	case:
		return 0, .Instruction_Not_Emulated
	}
}

execute_bit_b3_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	operand: byte
	switch reg {
	case 0:
		operand = byte((e.bc & 0xFF00) >> 8)
	case 1:
		operand = byte(e.bc)
	case 2:
		operand = byte((e.de & 0xFF00) >> 8)
	case 3:
		operand = byte(e.de)
	case 4:
		operand = byte((e.hl & 0xFF00) >> 8)
	case 5:
		operand = byte(e.hl)
	case 6:
		operand = access(e, e.hl) or_return
	case 7:
		operand = byte((e.af & 0xFF00) >> 8)
	case:
		return 0, .Instruction_Not_Emulated
	}

	new_f := FLAG_HALF_CARRY

	index := (opcode & 0x38) >> 3
	bit := (operand >> index) & 0x01

	if bit == 0 do new_f |= FLAG_ZERO

	e.af = (e.af & 0xFF00) | u16(new_f)

	if reg == 6 {
		return 3, nil
	} else {
		return 2, nil
	}
}

execute_res_b3_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	index := (opcode & 0x38) >> 3

	operand: byte
	switch reg {
	case 0:
		operand = byte((e.bc & 0xFF00) >> 8)
		operand &= ~(1 << index)
		e.bc = (u16(operand) << 8) | (e.bc & 0xFF00)
	case 1:
		operand = byte(e.bc)
		operand &= ~(1 << index)
		e.bc = (e.bc & 0xFF00) | u16(operand)
	case 2:
		operand = byte((e.de & 0xFF00) >> 8)
		operand &= ~(1 << index)
		e.de = (u16(operand) << 8) | (e.de & 0xFF00)
	case 3:
		operand = byte(e.de)
		operand &= ~(1 << index)
		e.de = (e.de & 0xFF00) | u16(operand)
	case 4:
		operand = byte((e.hl & 0xFF00) >> 8)
		operand &= ~(1 << index)
		e.hl = (u16(operand) << 8) | (e.hl & 0xFF00)
	case 5:
		operand = byte(e.hl)
		operand &= ~(1 << index)
		e.hl = (e.hl & 0xFF00) | u16(operand)
	case 6:
		operand = access(e, e.hl) or_return
		operand &= ~(1 << index)
		write(e, e.hl, operand) or_return
	case 7:
		operand = byte((e.af & 0xFF00) >> 8)
		operand &= ~(1 << index)
		e.af = (u16(operand) << 8) | (e.af & 0xFF00)
	case:
		return 0, .Instruction_Not_Emulated
	}

	if reg == 6 {
		return 3, nil
	} else {
		return 2, nil
	}
}

execute_set_b3_r8 :: #force_inline proc(
	e: ^Emulator,
	opcode: byte,
) -> (
	cycles: int,
	err: Emulator_Error,
) {
	reg := opcode & 0x07
	index := (opcode & 0x38) >> 3

	operand: byte
	switch reg {
	case 0:
		operand = byte((e.bc & 0xFF00) >> 8)
		operand |= (1 << index)
		e.bc = (u16(operand) << 8) | (e.bc & 0xFF00)
	case 1:
		operand = byte(e.bc)
		operand |= (1 << index)
		e.bc = (e.bc & 0xFF00) | u16(operand)
	case 2:
		operand = byte((e.de & 0xFF00) >> 8)
		operand |= (1 << index)
		e.de = (u16(operand) << 8) | (e.de & 0xFF00)
	case 3:
		operand = byte(e.de)
		operand |= (1 << index)
		e.de = (e.de & 0xFF00) | u16(operand)
	case 4:
		operand = byte((e.hl & 0xFF00) >> 8)
		operand |= (1 << index)
		e.hl = (u16(operand) << 8) | (e.hl & 0xFF00)
	case 5:
		operand = byte(e.hl)
		operand |= (1 << index)
		e.hl = (e.hl & 0xFF00) | u16(operand)
	case 6:
		operand = access(e, e.hl) or_return
		operand |= (1 << index)
		write(e, e.hl, operand) or_return
	case 7:
		operand = byte((e.af & 0xFF00) >> 8)
		operand |= (1 << index)
		e.af = (u16(operand) << 8) | (e.af & 0xFF00)
	case:
		return 0, .Instruction_Not_Emulated
	}

	if reg == 6 {
		return 3, nil
	} else {
		return 2, nil
	}
}
