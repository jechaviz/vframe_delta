module vframe_delta

import vdirty_regions

pub struct TileKey {
pub:
	x int
	y int
}

pub struct TileDelta {
pub:
	key TileKey
	rect vdirty_regions.Rect
	checksum u64
	bytes []u8
}

pub fn tile_rect(geometry Geometry, key TileKey) vdirty_regions.Rect {
	tile := if geometry.tile_size > 0 { geometry.tile_size } else { default_tile_size }
	x := key.x * tile
	y := key.y * tile
	return vdirty_regions.Rect{
		x: x
		y: y
		w: min_int(tile, max_int(0, geometry.width - x))
		h: min_int(tile, max_int(0, geometry.height - y))
	}
}

pub fn tile_count_x(geometry Geometry) int {
	tile := if geometry.tile_size > 0 { geometry.tile_size } else { default_tile_size }
	return ceil_div(max_int(0, geometry.width), tile)
}

pub fn tile_count_y(geometry Geometry) int {
	tile := if geometry.tile_size > 0 { geometry.tile_size } else { default_tile_size }
	return ceil_div(max_int(0, geometry.height), tile)
}

pub fn all_tile_keys(geometry Geometry) []TileKey {
	mut keys := []TileKey{cap: tile_count_x(geometry) * tile_count_y(geometry)}
	for y := 0; y < tile_count_y(geometry); y++ {
		for x := 0; x < tile_count_x(geometry); x++ {
			keys << TileKey{x: x, y: y}
		}
	}
	return keys
}

pub fn tile_keys_for_rect(geometry Geometry, rect vdirty_regions.Rect) []TileKey {
	r := clip_rect(rect, geometry.width, geometry.height)
	if !r.valid() {
		return []TileKey{}
	}
	tile := if geometry.tile_size > 0 { geometry.tile_size } else { default_tile_size }
	start_x := r.x / tile
	start_y := r.y / tile
	end_x := (r.x + r.w - 1) / tile
	end_y := (r.y + r.h - 1) / tile
	mut keys := []TileKey{cap: (end_x - start_x + 1) * (end_y - start_y + 1)}
	for y := start_y; y <= end_y; y++ {
		for x := start_x; x <= end_x; x++ {
			keys << TileKey{x: x, y: y}
		}
	}
	return keys
}

pub fn extract_rect_bytes(frame PixelBuffer, rect vdirty_regions.Rect) []u8 {
	r := clip_rect(rect, frame.width, frame.height)
	if !frame.valid() || !r.valid() {
		return []u8{}
	}
	row_bytes := r.w * bytes_per_pixel
	mut out := []u8{cap: row_bytes * r.h}
	for y := r.y; y < r.y + r.h; y++ {
		start := y * frame.stride + r.x * bytes_per_pixel
		out << frame.pixels[start..start + row_bytes]
	}
	return out
}

pub fn make_tile_delta(frame PixelBuffer, geometry Geometry, key TileKey) TileDelta {
	rect := tile_rect(geometry, key)
	return TileDelta{key: key, rect: rect, checksum: checksum_rect(frame, rect), bytes: extract_rect_bytes(frame, rect)}
}

fn ceil_div(value int, divisor int) int {
	if value <= 0 {
		return 0
	}
	d := if divisor > 0 { divisor } else { 1 }
	return (value + d - 1) / d
}
