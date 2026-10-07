module vframe_delta

import vdirty_regions

pub struct DiffOptions {
pub:
	tile_size int = default_tile_size
	max_tiles_per_delta int
}

pub struct FrameDelta {
pub:
	sequence u64
	geometry Geometry
	full bool
	tiles []TileDelta
	dirty_regions []vdirty_regions.Rect
	total_dirty_tiles int
	sent_dirty_tiles int
	backpressure bool
}

pub fn diff_frames(prev PixelBuffer, next PixelBuffer, sequence u64, options DiffOptions) FrameDelta {
	geometry := next.geometry(options.tile_size)
	full := !prev.valid() || !same_frame_shape(prev, next)
	keys := if full { all_tile_keys(geometry) } else { changed_tile_keys(prev, next, geometry) }
	selected := cap_tile_keys(keys, options.max_tiles_per_delta, full)
	mut tiles := []TileDelta{cap: selected.len}
	mut regions := []vdirty_regions.Rect{cap: selected.len}
	for key in selected {
		tile := make_tile_delta(next, geometry, key)
		tiles << tile
		regions << tile.rect
	}
	return FrameDelta{
		sequence: sequence
		geometry: geometry
		full: full
		tiles: tiles
		dirty_regions: regions
		total_dirty_tiles: keys.len
		sent_dirty_tiles: selected.len
		backpressure: !full && selected.len < keys.len
	}
}

pub fn apply_delta(base PixelBuffer, delta FrameDelta) !PixelBuffer {
	mut out := if delta.full || !base.valid() || !same_geometry(base.geometry(delta.geometry.tile_size), delta.geometry) {
		new_pixel_buffer(delta.geometry.width, delta.geometry.height)
	} else {
		base.dup()
	}
	for tile in delta.tiles {
		paste_tile(mut out, tile)!
	}
	return out
}

pub fn (delta FrameDelta) complete() bool {
	return delta.sent_dirty_tiles == delta.total_dirty_tiles && !delta.backpressure
}

fn changed_tile_keys(prev PixelBuffer, next PixelBuffer, geometry Geometry) []TileKey {
	mut keys := []TileKey{}
	for key in all_tile_keys(geometry) {
		rect := tile_rect(geometry, key)
		if checksum_rect(prev, rect) != checksum_rect(next, rect) {
			keys << key
		}
	}
	return keys
}

fn cap_tile_keys(keys []TileKey, max_tiles int, full bool) []TileKey {
	if full || max_tiles <= 0 || keys.len <= max_tiles {
		return keys.clone()
	}
	return keys[..max_tiles].clone()
}

fn paste_tile(mut frame PixelBuffer, tile TileDelta) ! {
	rect := clip_rect(tile.rect, frame.width, frame.height)
	expected := rect.w * rect.h * bytes_per_pixel
	if !rect.valid() {
		return
	}
	if tile.bytes.len != expected {
		return error('tile byte size mismatch: expected ${expected}, got ${tile.bytes.len}')
	}
	row_bytes := rect.w * bytes_per_pixel
	for row := 0; row < rect.h; row++ {
		dst := (rect.y + row) * frame.stride + rect.x * bytes_per_pixel
		src := row * row_bytes
		for i := 0; i < row_bytes; i++ {
			frame.pixels[dst + i] = tile.bytes[src + i]
		}
	}
}
