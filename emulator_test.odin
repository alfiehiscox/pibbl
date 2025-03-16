package pibbl

import "core:testing"

// ===========================================================
// ======================= Interrupts =====================-==
// ===========================================================

test_should_interrupt :: proc(t: ^testing.T) {
	e: Emulator

	request_vblank(&e)
	request_timer(&e)

	testing.expect(t, should_interrupt(&e) == false)

	e._ime = true
	testing.expect(t, should_interrupt(&e) == false)

	e._ie = 0b00010010
	testing.expect(t, should_interrupt(&e) == false)

	e._ie = 0b00010011
	testing.expect(t, should_interrupt(&e) == true)

	e._ie = 0b00010111
	testing.expect(t, should_interrupt(&e) == true)

	e._ie = 0b00010110
	testing.expect(t, should_interrupt(&e) == true)

	e._ime = false
	testing.expect(t, should_interrupt(&e) == false)
}

test_request_and_handle_vblank :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 0xC010 // random mem position

	request_vblank(&e)
	testing.expect(t, e._if == 1)

	cycles, err := interrupt(&e)

	testing.expect(t, e._ime == false)
	testing.expect(t, e._if == 0)
	testing.expect(t, cycles == 5)
	prev, _ := stack_pop_u16(&e)
	testing.expect(t, prev == 0xC010)
	testing.expect(t, e.pc == VBLANK_VEC)
}


test_request_and_handle_lcd :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 0xC010 // random mem position

	request_lcd(&e)
	testing.expect(t, e._if == 2)

	cycles, err := interrupt(&e)

	testing.expect(t, e._ime == false)
	testing.expect(t, e._if == 0)
	testing.expect(t, cycles == 5)
	prev, _ := stack_pop_u16(&e)
	testing.expect(t, prev == 0xC010)
	testing.expect(t, e.pc == STAT_VEC)
}

test_request_and_handle_timer :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 0xC010 // random mem position

	request_timer(&e)
	testing.expect(t, e._if == 4)

	cycles, err := interrupt(&e)

	testing.expect(t, e._ime == false)
	testing.expect(t, e._if == 0)
	testing.expect(t, cycles == 5)
	prev, _ := stack_pop_u16(&e)
	testing.expect(t, prev == 0xC010)
	testing.expect(t, e.pc == TIMER_VEC)
}

test_request_and_handle_serial :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 0xC010 // random mem position

	request_serial(&e)
	testing.expect(t, e._if == 8)

	cycles, err := interrupt(&e)

	testing.expect(t, e._ime == false)
	testing.expect(t, e._if == 0)
	testing.expect(t, cycles == 5)
	prev, _ := stack_pop_u16(&e)
	testing.expect(t, prev == 0xC010)
	testing.expect(t, e.pc == SERIAL_VEC)
}

test_request_and_handle_joypad :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 0xC010 // random mem position

	request_joypad(&e)
	testing.expect(t, e._if == 16)

	cycles, err := interrupt(&e)

	testing.expect(t, e._ime == false)
	testing.expect(t, e._if == 0)
	testing.expect(t, cycles == 5)
	prev, _ := stack_pop_u16(&e)
	testing.expect(t, prev == 0xC010)
	testing.expect(t, e.pc == JOYPAD_VEC)
}

test_interrupt_priority :: proc(t: ^testing.T) {
	e: Emulator
	e.pc = 0xC010 // random mem position

	cycles: int
	err: Emulator_Error

	request_timer(&e)
	request_vblank(&e)
	request_joypad(&e)

	cycles, err = interrupt(&e)

	testing.expect(t, e._ime == false)
	testing.expect(t, e._if == 0)
	testing.expect(t, cycles == 5)
	prev, _ := stack_pop_u16(&e)
	testing.expect(t, prev == 0xC010)
	testing.expect(t, e.pc == VBLANK_VEC)

	cycles, err = interrupt(&e)

	testing.expect(t, e._ime == false)
	testing.expect(t, e._if == 0)
	testing.expect(t, cycles == 5)
	prev, _ = stack_pop_u16(&e)
	testing.expect(t, prev == 0xC010)
	testing.expect(t, e.pc == TIMER_VEC)

	cycles, err = interrupt(&e)

	testing.expect(t, e._ime == false)
	testing.expect(t, e._if == 0)
	testing.expect(t, cycles == 5)
	prev, _ = stack_pop_u16(&e)
	testing.expect(t, prev == 0xC010)
	testing.expect(t, e.pc == JOYPAD_VEC)

	cycles, err = interrupt(&e)
	testing.expect(t, cycles == 0)
}
