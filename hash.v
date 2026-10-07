module vframe_delta

import vdirty_regions

pub const fnv64_offset = u64(14695981039346656037)
pub const fnv64_prime = u64(1099511628211)

pub fn fnv1a64_bytes(bytes []u8) u64 {
	mut hash := fnv64_offset
	for b in bytes {
		hash ^= u64(b)
		hash *= fnv64_prime
	}
	return hash
}

pub fn checksum_rect(frame PixelBuffer, rect vdirty_regions.Rect) u64 {
	r := clip_rect(rect, frame.width, frame.height)
	if !frame.valid() || !r.valid() {
		return fnv64_offset
	}
	mut hash := fnv64_offset
	row_bytes := r.w * bytes_per_pixel
	for y := r.y; y < r.y + r.h; y++ {
		start := y * frame.stride + r.x * bytes_per_pixel
		for i := 0; i < row_bytes; i++ {
			hash ^= u64(frame.pixels[start + i])
			hash *= fnv64_prime
		}
	}
	return hash
}

pub fn frame_checksum(frame PixelBuffer) u64 {
	return checksum_rect(frame, full_rect(frame))
}
