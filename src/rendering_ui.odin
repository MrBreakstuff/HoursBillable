package main

import sdl "vendor:sdl3"
import clay "libs:clay"

render_rectangle :: proc(
	renderer: ^sdl.Renderer,
	box: clay.BoundingBox,
	renderData: clay.RectangleRenderData,
) {
	if box.width <= 0 || box.height <= 0 { return }
	
	color := renderData.backgroundColor
	
	sdl.SetRenderDrawColor(
		renderer,
		u8(color.r),
		u8(color.g),
		u8(color.b),
		u8(color.a),
	)
	
	rect := sdl.FRect{
		box.x,
		box.y,
		box.width,
		box.height,
	}
	
	sdl.RenderFillRect(renderer, &rect)
}

render_border :: proc(
	renderer: ^sdl.Renderer,
	box: clay.BoundingBox,
	renderData: clay.BorderRenderData,
) {
	w := box.width
	h := box.height
	
	if w <= 0 || h <= 0 {
		return
	}
	
	top := min(f32(renderData.width.top), h)
	bottom := min(f32(renderData.width.bottom), h - top)
	left := min(f32(renderData.width.left), w)
	right := min(f32(renderData.width.right), w - left)
	
	inner_height := h - top - bottom
	
	color := renderData.color
	sdl.SetRenderDrawColor(
		renderer,
		u8(color.r),
		u8(color.g),
		u8(color.b),
		u8(color.a),
	)
	
	if top > 0 {
		rect := sdl.FRect{
			box.x,
			box.y,
			w,
			top,
		}
		sdl.RenderFillRect(renderer, &rect)
	}
	
	if bottom > 0 {
		rect := sdl.FRect{
			box.x,
			box.y + h - bottom,
			w,
			bottom,
		}
		sdl.RenderFillRect(renderer, &rect)
	}
	
	if left > 0 && inner_height > 0 {
		rect := sdl.FRect{
			box.x,
			box.y + top,
			left,
			inner_height,
		}
		sdl.RenderFillRect(renderer, &rect)
	}
	
	if right > 0 && inner_height > 0 {
		rect := sdl.FRect{
			box.x + w - right,
			box.y + top,
			right,
			inner_height,
		}
		sdl.RenderFillRect(renderer, &rect)
	}
}

render_clay_commands :: proc(
	renderer: ^sdl.Renderer,
	commands: ^clay.ClayArray(clay.RenderCommand),
	text_system: ^Text_System,
) {
	for i in 0..<commands.length {
		cmd := clay.RenderCommandArray_Get(commands, i)
		box := cmd.boundingBox
		
		#partial switch cmd.commandType {
		case .None:
			continue
		
		case .Rectangle:
			rectData := cmd.renderData.rectangle
			
			if has_rounded_corners(rectData.cornerRadius){
				render_rounded_background(renderer, box, rectData)
			} else {
				render_rectangle(renderer, box, rectData)
			}
		
		case .Border:
			borderData := cmd.renderData.border
			if has_rounded_corners(borderData.cornerRadius) {
				render_rounded_border(renderer, box, borderData)
			} else {
				render_border(renderer, box, borderData)
			}
		
		case .ScissorStart:
			clip := sdl.Rect{i32(box.x), i32(box.y), i32(box.width), i32(box.height)}
			sdl.SetRenderClipRect(renderer, &clip)
			
		case .ScissorEnd:
			sdl.SetRenderClipRect(renderer, nil)
			
		case .Text:
			render_text(text_system, box, cmd.renderData.text)
		}
	}
}