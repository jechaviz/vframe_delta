module vframe_delta

import vdirty_regions

pub fn encode_delta(delta FrameDelta) []u8 {
	mut out := []u8{cap: encoded_delta_capacity(delta)}
	write_magic(mut out)
	write_u64_le(mut out, delta.sequence)
	write_u32_le(mut out, u32(delta.geometry.width))
	write_u32_le(mut out, u32(delta.geometry.height))
	write_u32_le(mut out, u32(delta.geometry.stride))
	write_u32_le(mut out, u32(delta.geometry.tile_size))
	out << if delta.full { u8(1) } else { u8(0) }
	write_u32_le(mut out, u32(delta.tiles.len))
	for tile in delta.tiles {
		write_u32_le(mut out, u32(tile.key.x))
		write_u32_le(mut out, u32(tile.key.y))
		write_u32_le(mut out, u32(tile.rect.x))
		write_u32_le(mut out, u32(tile.rect.y))
		write_u32_le(mut out, u32(tile.rect.w))
		write_u32_le(mut out, u32(tile.rect.h))
		write_u64_le(mut out, tile.checksum)
		write_u32_le(mut out, u32(tile.bytes.len))
		out << tile.bytes
	}
	return out
}

pub fn decode_delta(data []u8) !FrameDelta {
	mut cursor := ByteCursor{data: data}
	cursor.expect_magic()!
	sequence := cursor.read_u64()!
	width := int(cursor.read_u32()!)
	height := int(cursor.read_u32()!)
	stride := int(cursor.read_u32()!)
	tile_size := int(cursor.read_u32()!)
	full := cursor.read_u8()! == 1
	count := int(cursor.read_u32()!)
	mut tiles := []TileDelta{cap: count}
	for _ in 0 .. count {
		key := TileKey{x: int(cursor.read_u32()!), y: int(cursor.read_u32()!)}
		rect := vdirty_regions.Rect{
			x: int(cursor.read_u32()!)
			y: int(cursor.read_u32()!)
			w: int(cursor.read_u32()!)
			h: int(cursor.read_u32()!)
		}
		checksum := cursor.read_u64()!
		byte_len := int(cursor.read_u32()!)
		bytes := cursor.read_bytes(byte_len)!
		tiles << TileDelta{key: key, rect: rect, checksum: checksum, bytes: bytes}
	}
	geometry := Geometry{width: width, height: height, stride: stride, tile_size: tile_size}
	mut regions := []vdirty_regions.Rect{cap: tiles.len}
	for tile in tiles {
		regions << tile.rect
	}
	return FrameDelta{
		sequence: sequence
		geometry: geometry
		full: full
		tiles: tiles
		dirty_regions: regions
		total_dirty_tiles: tiles.len
		sent_dirty_tiles: tiles.len
	}
}

struct ByteCursor {
	data []u8
mut:
	offset int
}

fn (mut c ByteCursor) expect_magic() ! {
	if c.data.len < 4 {
		return error('delta payload too short')
	}
	if c.data[0] != u8(`V`) || c.data[1] != u8(`F`) || c.data[2] != u8(`R`) || c.data[3] != u8(`1`) {
		return error('invalid frame-delta magic')
	}
	c.offset = 4
}

fn (mut c ByteCursor) read_u8() !u8 {
	if c.offset + 1 > c.data.len {
		return error('unexpected eof while reading u8')
	}
	value := c.data[c.offset]
	c.offset++
	return value
}

fn (mut c ByteCursor) read_u32() !u32 {
	if c.offset + 4 > c.data.len {
		return error('unexpected eof while reading u32')
	}
	value := u32(c.data[c.offset]) | (u32(c.data[c.offset + 1]) << 8) |
		(u32(c.data[c.offset + 2]) << 16) | (u32(c.data[c.offset + 3]) << 24)
	c.offset += 4
	return value
}

fn (mut c ByteCursor) read_u64() !u64 {
	lo := u64(c.read_u32()!)
	hi := u64(c.read_u32()!)
	return lo | (hi << 32)
}

fn (mut c ByteCursor) read_bytes(len int) ![]u8 {
	if len < 0 || c.offset + len > c.data.len {
		return error('unexpected eof while reading bytes')
	}
	bytes := c.data[c.offset..c.offset + len].clone()
	c.offset += len
	return bytes
}

fn write_u32_le(mut out []u8, value u32) {
	out << u8(value & 0xff)
	out << u8((value >> 8) & 0xff)
	out << u8((value >> 16) & 0xff)
	out << u8((value >> 24) & 0xff)
}

fn write_magic(mut out []u8) {
	out << u8(`V`)
	out << u8(`F`)
	out << u8(`R`)
	out << u8(`1`)
}

fn write_u64_le(mut out []u8, value u64) {
	write_u32_le(mut out, u32(value & 0xffff_ffff))
	write_u32_le(mut out, u32(value >> 32))
}

fn encoded_delta_capacity(delta FrameDelta) int {
	mut total := 4 + 8 + 4 * 4 + 1 + 4
	for tile in delta.tiles {
		total += 4 * 6 + 8 + 4 + tile.bytes.len
	}
	return total
}
