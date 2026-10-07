module vframe_delta

import vdirty_regions

pub const bytes_per_pixel = 4
pub const default_tile_size = 128

pub enum PixelFormat {
	bgra8888
}

pub struct Geometry {
pub:
	width int
	height int
	stride int
	tile_size int = default_tile_size
	format PixelFormat = .bgra8888
}

pub struct PixelBuffer {
pub:
	width int
	height int
	stride int
	format PixelFormat = .bgra8888
pub mut:
	pixels []u8
}

pub fn new_geometry(width int, height int, tile_size int) Geometry {
	w := max_int(0, width)
	h := max_int(0, height)
	tile := if tile_size > 0 { tile_size } else { default_tile_size }
	return Geometry{width: w, height: h, stride: w * bytes_per_pixel, tile_size: tile}
}

pub fn new_pixel_buffer(width int, height int) PixelBuffer {
	w := max_int(0, width)
	h := max_int(0, height)
	stride := w * bytes_per_pixel
	return PixelBuffer{width: w, height: h, stride: stride, pixels: []u8{len: stride * h}}
}

pub fn pixel_buffer_from_bgra(width int, height int, pixels []u8) !PixelBuffer {
	expected := max_int(0, width) * max_int(0, height) * bytes_per_pixel
	if pixels.len != expected {
		return error('bgra buffer size mismatch: expected ${expected}, got ${pixels.len}')
	}
	return PixelBuffer{
		width: width
		height: height
		stride: width * bytes_per_pixel
		pixels: pixels.clone()
	}
}

pub fn (frame PixelBuffer) valid() bool {
	return frame.width > 0 && frame.height > 0 && frame.stride >= frame.width * bytes_per_pixel
		&& frame.pixels.len >= frame.stride * frame.height
}

pub fn (frame PixelBuffer) byte_len() int {
	return frame.stride * frame.height
}

pub fn (frame PixelBuffer) geometry(tile_size int) Geometry {
	return Geometry{
		width: frame.width
		height: frame.height
		stride: frame.stride
		tile_size: if tile_size > 0 { tile_size } else { default_tile_size }
		format: frame.format
	}
}

pub fn (frame PixelBuffer) dup() PixelBuffer {
	return PixelBuffer{
		width: frame.width
		height: frame.height
		stride: frame.stride
		format: frame.format
		pixels: frame.pixels.clone()
	}
}

pub fn full_rect(frame PixelBuffer) vdirty_regions.Rect {
	return vdirty_regions.Rect{x: 0, y: 0, w: frame.width, h: frame.height}
}

pub fn same_geometry(a Geometry, b Geometry) bool {
	return a.width == b.width && a.height == b.height && a.stride == b.stride
		&& a.tile_size == b.tile_size && a.format == b.format
}

pub fn same_frame_shape(a PixelBuffer, b PixelBuffer) bool {
	return a.width == b.width && a.height == b.height && a.stride == b.stride
		&& a.format == b.format
}

pub fn clip_rect(rect vdirty_regions.Rect, width int, height int) vdirty_regions.Rect {
	return vdirty_regions.clip(rect, vdirty_regions.Rect{x: 0, y: 0, w: width, h: height})
}

fn min_int(a int, b int) int {
	return if a < b { a } else { b }
}

fn max_int(a int, b int) int {
	return if a > b { a } else { b }
}
