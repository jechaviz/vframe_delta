module vframe_delta

import vdirty_regions

pub fn patterned_frame(width int, height int, seed int) PixelBuffer {
	mut frame := new_pixel_buffer(width, height)
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			i := y * frame.stride + x * bytes_per_pixel
			frame.pixels[i] = u8((x + seed) & 0xff)
			frame.pixels[i + 1] = u8((y + seed * 3) & 0xff)
			frame.pixels[i + 2] = u8((x + y + seed * 7) & 0xff)
			frame.pixels[i + 3] = 255
		}
	}
	return frame
}

pub fn paint_rect(mut frame PixelBuffer, x int, y int, w int, h int, b u8, g u8, r u8) {
	rect := clip_rect(vdirty_regions.Rect{x: x, y: y, w: w, h: h}, frame.width, frame.height)
	for py := rect.y; py < rect.y + rect.h; py++ {
		for px := rect.x; px < rect.x + rect.w; px++ {
			i := py * frame.stride + px * bytes_per_pixel
			frame.pixels[i] = b
			frame.pixels[i + 1] = g
			frame.pixels[i + 2] = r
			frame.pixels[i + 3] = 255
		}
	}
}
