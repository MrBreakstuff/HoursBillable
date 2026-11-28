package main

import "core:fmt"
import "base:runtime"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
import clay "libs:clay"

DEFAULT_FPS :: 30
NS_PER_SECOND :: 1_000_000_000 

limit_framerate :: proc(frame_start: u64, target_fps: u32 = DEFAULT_FPS) {
	if target_fps == 0 {
		return
	}
	
	target_frame_time := NS_PER_SECOND / u64(target_fps)
	elapsed_frame_time := sdl.GetTicksNS() - frame_start
	
	if elapsed_frame_time < target_frame_time {
		remaining_time := target_frame_time - elapsed_frame_time
		sdl.DelayNS(remaining_time)
	}
}

App :: struct {
	running: bool,
	window: ^sdl.Window,
	renderer: ^sdl.Renderer,
	clay_memory: []u8,
	window_width: i32,
	window_height: i32,
	// Input state
	// Font resources
	// Application-specific state
}

error_handler :: proc "c" (errorData: clay.ErrorData) {
	context = runtime.default_context()
	fmt.eprintln(errorData)
}

measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions {
	system := cast(^Text_System)user_data
	
	font := get_font(system, config.fontId, config.fontSize)
	if font == nil { return {} }
	
	if text.length <= 0 {
		return {
			width = 0,
			height = f32(ttf.GetFontHeight(font)),
		}
	}
	
	//Why this here and then f32 at the return? When is this initialized?
	width, height: i32
	
	if !ttf.GetStringSize(
		font, cast(cstring)text.chars,
		uint(text.length),
		&width, &height,
	) { return {} }
	
	return {
		width = f32(width),
		height = f32(height),
	}
}
	
main :: proc() {
	if !sdl.Init({.VIDEO}) {
		fmt.eprintln("SDL Init failed:", sdl.GetError())
		return
	}
	defer sdl.Quit()
	
	window_width : i32 = 1080
	window_height : i32= 720
	
	window := sdl.CreateWindow("HoursBillable", window_width, window_height, {.RESIZABLE})
	if window == nil {
		fmt.eprintln("window creation failed:", sdl.GetError())
		return
	}
	defer sdl.DestroyWindow(window)
	
	renderer := sdl.CreateRenderer(window, nil)
	if renderer == nil {
		fmt.eprintln("Renderer creation failed:", sdl.GetError())
		return
	}
	sdl.SetRenderVSync(renderer, 0)
	//sdl.SetRenderDrawBlendMode(renderer, .Blend)
	defer sdl.DestroyRenderer(renderer)
	
	min_memory_size := clay.MinMemorySize()
	memory := make([]u8, int(min_memory_size))
	defer delete(memory)
	
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(len(memory)), raw_data(memory),)
	
	clay_context := clay.Initialize(arena, {f32(window_width), f32(window_height)}, { handler = error_handler })
	if clay_context == nil {
		fmt.eprintln("Clay initialization failed")
		return
	}
	
	text_system: Text_System
	if !init_text_system(&text_system, renderer) {
		fmt.eprintln("Text system initialization failed")
		return
	}
	defer destroy_text_system(&text_system)
	
	clay.SetMeasureTextFunction(measure_text, &text_system)
	previous_time := sdl.GetTicksNS()
	
	running := true
	input: Input_State
	show_second_text := false
	for running {
		frame_start := sdl.GetTicksNS()
		delta_time := f32(f64(frame_start - previous_time) / NS_PER_SECOND,)
		previous_time = frame_start
		
		event: sdl.Event
		mouse_wheel: clay.Vector2
		
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				running = false
			case .WINDOW_RESIZED:
				w, h: i32
				sdl.GetWindowSize(window, &w, &h)
				clay.SetLayoutDimensions({f32(w), f32(h)})
			case .MOUSE_WHEEL:
				mouse_wheel = {event.wheel.x, event.wheel.y}
			}
		}
		
		update_input(&input)
		clay.SetPointerState(
			{input.mouse_x, input.mouse_y},
			input.mouse_down,
		)
		
		clay.BeginLayout()
		if clay.UI(clay.ID("Root"))({
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				layoutDirection = .TopToBottom,
				padding = clay.PaddingAll(16),
				childGap = 16,
			},
			backgroundColor = {30, 30, 46, 255},
		}) {
			label := "Hide text box" if show_second_text else "Show text box"
				
			if button(clay.ID("ToggleText"), label, &input) {
				show_second_text = ! show_second_text
			}
			
			if clay.UI(clay.ID("TextRow"))({
				layout = {
					layoutDirection = .LeftToRight,
					childGap = 16,
				},
			}) {
				if clay.UI(clay.ID("Box"))({
					layout = {
						sizing = {
							width	= clay.SizingFixed(200),
							height   = clay.SizingFixed(100),
						},
						layoutDirection = .TopToBottom,
						childAlignment = { x = .Center, y = .Center },
					},
					backgroundColor = {137, 180, 250, 255},
					cornerRadius = clay.CornerRadiusAll(8),
				}) {
					ui_text("Hours Billable", .Heading)
					ui_text("Track your time and manage projects", .Body, {180, 190, 205, 255})
				}
				
				if show_second_text {
					if clay.UI(clay.ID("SecondBox"))({
						layout = {
							sizing = {
								width = clay.SizingFixed(200),
								height = clay.SizingFixed(100),
							},
							childAlignment = { x = .Center, y = .Center },
						},
						backgroundColor = {166, 227, 161, 255},
						cornerRadius = clay.CornerRadiusAll(8),
					}) {
						ui_text("Second text box", .Heading)
					}
				}
			}
		}
		render_commands := clay.EndLayout(delta_time)
		
		sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)
		sdl.RenderClear(renderer)
		render_clay_commands(renderer, &render_commands, &text_system)
		sdl.RenderPresent(renderer)
		
		limit_framerate(frame_start)
	}
}
