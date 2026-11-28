package main

import sdl "vendor:sdl3"

Input_State :: struct {
	mouse_x: f32,
	mouse_y: f32,
	mouse_down: bool,
	mouse_pressed: bool,
	mouse_released: bool,
}

update_input :: proc(input: ^Input_State) {
	was_down := input.mouse_down
	
	buttons := sdl.GetMouseState(&input.mouse_x, &input.mouse_y)
	input.mouse_down = .LEFT in buttons
	input.mouse_pressed = input.mouse_down && !was_down
	input.mouse_released = !input.mouse_down && was_down
}