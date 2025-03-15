package pibbl

Pixel_Processing_Unit :: struct {
	vram: [8192]byte,
	oam:  [160]byte,
}

tick :: proc(ppu: ^Pixel_Processing_Unit, cycles: int) {}

ppu_access :: proc(ppu: ^Pixel_Processing_Unit, addr: u16) -> (byte, Emulator_Error) {
	// need to check the PPU mode before this
	switch {
	case addr >= 0x8000 && addr <= 0x9FFF:
		return ppu.vram[addr - 0x8000], nil
	case addr >= 0xFE00 && addr <= 0xFE9F:
		return ppu.oam[addr - 0xFE00], nil
	case:
		return 0x00, .Invalid_Access
	}
}

ppu_write :: proc(ppu: ^Pixel_Processing_Unit, addr: u16, val: byte) -> Emulator_Error {
	switch {
	case addr >= 0x8000 && addr <= 0x9FFF:
		ppu.vram[addr - 0x8000] = val
	case addr >= 0xFE00 && addr <= 0xFE9F:
		ppu.oam[addr - 0xFE00] = val
	case:
		return .Invalid_Write
	}

	return nil
}
