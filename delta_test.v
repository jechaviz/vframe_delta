module vframe_delta

fn test_full_delta_roundtrip() {
	mut next := new_pixel_buffer(16, 16)
	for i := 0; i < next.pixels.len; i++ {
		next.pixels[i] = u8(i % 251)
	}
	delta := diff_frames(PixelBuffer{}, next, 1, DiffOptions{tile_size: 8})
	assert delta.full
	assert delta.complete()
	applied := apply_delta(PixelBuffer{}, delta) or { panic(err.msg()) }
	assert applied.pixels == next.pixels
}

fn test_single_tile_change_and_codec_roundtrip() {
	mut prev := new_pixel_buffer(32, 32)
	mut next := prev.dup()
	for y := 2; y < 6; y++ {
		for x := 2; x < 6; x++ {
			index := y * next.stride + x * bytes_per_pixel
			next.pixels[index] = 10
			next.pixels[index + 1] = 20
			next.pixels[index + 2] = 30
			next.pixels[index + 3] = 255
		}
	}
	delta := diff_frames(prev, next, 2, DiffOptions{tile_size: 8})
	assert !delta.full
	assert delta.tiles.len == 1
	encoded := encode_delta(delta)
	decoded := decode_delta(encoded) or { panic(err.msg()) }
	applied := apply_delta(prev, decoded) or { panic(err.msg()) }
	assert decoded.sequence == 2
	assert applied.pixels == next.pixels
}

fn test_backpressure_caps_partial_delta() {
	mut prev := new_pixel_buffer(32, 32)
	mut next := prev.dup()
	for i := 0; i < next.pixels.len; i += 4 {
		next.pixels[i] = 255
	}
	delta := diff_frames(prev, next, 3, DiffOptions{
		tile_size: 8
		max_tiles_per_delta: 2
	})
	assert delta.tiles.len == 2
	assert delta.backpressure
	assert !delta.complete()
}
