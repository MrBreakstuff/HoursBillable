package main

import "core:math"
import sdl "vendor:sdl3"
import clay "libs:clay"

CORNER_ARC_SEGMENTS :: 16
PERIMETER_VERTICES :: 4 * (CORNER_ARC_SEGMENTS + 1)
BACKGROUND_VERTEX_COUNT :: PERIMETER_VERTICES + 1
BACKGROUND_INDEX_COUNT :: PERIMETER_VERTICES * 3
BORDER_VERTEX_COUNT :: PERIMETER_VERTICES * 2
BORDER_INDEX_COUNT :: PERIMETER_VERTICES * 6

Vec2 :: [2]f32

Corner :: enum {
	Top_Left,
	Top_Right,
	Bottom_Right,
	Bottom_Left,
}

Rounded_Rect :: struct {
	box: clay.BoundingBox,
	radii: [Corner]Vec2,
}

Perimeter :: [PERIMETER_VERTICES]Vec2

has_rounded_corners :: proc(
	radius: clay.CornerRadius,
) -> bool {
	return  radius.topLeft     > 0 ||
			radius.topRight    > 0 ||
			radius.bottomLeft  > 0 ||
			radius.bottomRight > 0
}

to_sdl_color :: proc(color: clay.Color) -> sdl.FColor {
	return {
		clamp(color.r / 255.0, 0.0, 1.0),
		clamp(color.g / 255.0, 0.0, 1.0),
		clamp(color.b / 255.0, 0.0, 1.0),
		clamp(color.a / 255.0, 0.0, 1.0),
	}
}

make_vertex :: proc(
	position: Vec2,
	color: sdl.FColor,
) -> sdl.Vertex {
	return {
		position = {position.x, position.y},
		color = color,
		tex_coord = {0, 0},
	}
}

normalize_radii :: proc(rect: ^Rounded_Rect) {
	radii := &rect.radii
	
	top := radii[.Top_Left].x + radii[.Top_Right].x
	bottom := radii[.Bottom_Left].x + radii[.Bottom_Right].x
	left := radii[.Top_Left].y + radii[.Bottom_Left].y
	right := radii[.Top_Right].y + radii[.Bottom_Right].y
	
	width := max(0, rect.box.width)
	height := max(0, rect.box.height)
	
	scale: f32 = 1
	
	if top > 0 {scale = min(scale, width / top)}
	if bottom > 0 { scale = min(scale, width / bottom) }
	if left > 0 {scale = min(scale, height / left)}
	if right > 0 {scale = min(scale, height / right)}
	
	for &radius in rect.radii { radius *= scale }
}

generate_perimeter :: proc(
	rect: Rounded_Rect,
) -> Perimeter {
	points: Perimeter
	
	x := rect.box.x
	y := rect.box.y
	w := rect.box.width
	h := rect.box.height
	
	radii := rect.radii
	
	corner_centers: [Corner]Vec2 = {
		.Top_Left = {
			x + radii[.Top_Left].x,
			y + radii[.Top_Left].y,
		},
		.Top_Right = {
			x + w - radii[.Top_Right].x,
			y + radii[.Top_Right].y,
		},
		.Bottom_Right = {
			x + w - radii[.Bottom_Right].x,
			y + h - radii[.Bottom_Right].y,
		},
		.Bottom_Left = {
			x + radii[.Bottom_Left].x,
			y + h - radii[.Bottom_Left].y,
		},
	}
	
	start_angles: [Corner]f32 = {
		.Top_Left = math.PI,
		.Top_Right = 1.5 * math.PI,
		.Bottom_Right = 0,
		.Bottom_Left = 0.5 * math.PI,
	}
	
	index := 0
	
	for corner in Corner {
		center := corner_centers[corner]
		radius := radii[corner]
		start  := start_angles[corner]
		
		for segment in 0..=CORNER_ARC_SEGMENTS {
			t : f32 = f32(segment) / f32(CORNER_ARC_SEGMENTS)
			
			angle : f32 = start + t * f32(math.PI / 2)
			
			points[index] = {
				center.x + radius.x * math.cos(angle),
				center.y + radius.y * math.sin(angle),
			}
			
			index += 1
			
		}
	}
	return points
}

rounded_rect :: proc(
	box: clay.BoundingBox,
	radius: clay.CornerRadius,
) -> Rounded_Rect {
	top_left := max(0, radius.topLeft)
	top_right := max(0, radius.topRight)
	bottom_right := max(0, radius.bottomRight)
	bottom_left := max(0, radius.bottomLeft)
	
	rect := Rounded_Rect{
		box = box,
		radii = {
			.Top_Left = {top_left, top_left},
			.Top_Right = {top_right, top_right},
			.Bottom_Right = {bottom_right, bottom_right},
			.Bottom_Left = {bottom_left, bottom_left},
		},
	}
	normalize_radii(&rect)
	return rect
}

Background_Mesh :: struct {
	vertices: [BACKGROUND_VERTEX_COUNT]sdl.Vertex,
	indices:  [BACKGROUND_INDEX_COUNT]i32,
}

generate_background_mesh :: proc(
	rect: Rounded_Rect,
	color: sdl.FColor,
	mesh: ^Background_Mesh,
) {
	perimeter := generate_perimeter(rect)
	
	center := Vec2{
		rect.box.x + rect.box.width  * 0.5,
		rect.box.y + rect.box.height * 0.5,
	}
	
	mesh.vertices[0] = make_vertex(center, color)
	
	for point, i in perimeter {
		mesh.vertices[i + 1] = make_vertex(point, color)
	}
	
	for i in 0..<PERIMETER_VERTICES {
		current := i + 1
		next := ((i + 1) % PERIMETER_VERTICES) + 1
		
		mesh.indices[i * 3 + 0] = 0
		mesh.indices[i * 3 + 1] = i32(current)
		mesh.indices[i * 3 + 2] = i32(next)
	}
}

render_rounded_background :: proc(
	renderer: ^sdl.Renderer,
	box: clay.BoundingBox,
	renderData: clay.RectangleRenderData,
) {
	if box.width <= 0 || box.height <= 0 {
		return
	}
	
	rect := rounded_rect(box, renderData.cornerRadius)
	color := to_sdl_color(renderData.backgroundColor)
	
	mesh: Background_Mesh
	
	generate_background_mesh(rect, color, &mesh)
	
	sdl.RenderGeometry(
		renderer,
		nil,
		raw_data(mesh.vertices[:]),
		i32(len(mesh.vertices)),
		raw_data(mesh.indices[:]),
		i32(len(mesh.indices)),
	)
}

inner_rect :: proc(
	outer: Rounded_Rect,
	width: clay.BorderWidth,
) -> Rounded_Rect {
	inner := outer
	
	w  := outer.box.width
	h := outer.box.height
	
	left   := min(f32(width.left), w)
	right  := min(f32(width.right), w - left)
	top    := min(f32(width.top), h)
	bottom := min(f32(width.bottom), h - top)
	
	inner.box.x += left
	inner.box.y += top
	
	inner.box.width  -= left + right
	inner.box.height -= top + bottom
	
	inner.radii[.Top_Left]     -= Vec2{left,  top}
	inner.radii[.Top_Right]    -= Vec2{right, top}
	inner.radii[.Bottom_Right] -= Vec2{right, bottom}
	inner.radii[.Bottom_Left]  -= Vec2{left, bottom}
	
	for &radius in inner.radii {
		radius.x = max(0, radius.x)
		radius.y = max(0, radius.y)
	}
	
	normalize_radii(&inner)
	return inner
}

Border_Mesh :: struct {
	vertices: [BORDER_VERTEX_COUNT]sdl.Vertex,
	indices: [BORDER_INDEX_COUNT]i32,
}

get_outer_index :: proc(index: int) -> i32 {
	return i32(index * 2)
}

get_inner_index :: proc(index: int) -> i32 {
	return i32(index * 2 + 1)
}

generate_border_mesh :: proc(
	outer: Rounded_Rect,
	inner: Rounded_Rect,
	color: sdl.FColor,
	mesh: ^Border_Mesh,
) {
	outer_vertices := generate_perimeter(outer)
	inner_vertices := generate_perimeter(inner)
	
	for i in 0..<PERIMETER_VERTICES {
		next := (i + 1) % PERIMETER_VERTICES
		
		outer_current := get_outer_index(i)
		inner_current := get_inner_index(i)
		outer_next := get_outer_index(next)
		inner_next := get_inner_index(next)
		
		offset := i * 6
		
		mesh.vertices[outer_current] = make_vertex(outer_vertices[i], color)
		mesh.vertices[inner_current] = make_vertex(inner_vertices[i], color)
		
		mesh.indices[offset + 0] = outer_current
		mesh.indices[offset + 1] = outer_next
		mesh.indices[offset + 2] = inner_next
		
		mesh.indices[offset + 3] = outer_current
		mesh.indices[offset + 4] = inner_next
		mesh.indices[offset + 5] = inner_current
	}
}

render_rounded_border :: proc(
	renderer: ^sdl.Renderer,
	box: clay.BoundingBox,
	renderData: clay.BorderRenderData,
) {
	if box.width <= 0 || box.height <= 0 { return }
	
	if (renderData.width.top    |
		renderData.width.bottom |
		renderData.width.left   |
		renderData.width.right) == 0 {
			return
		}
		
	outer := rounded_rect(box, renderData.cornerRadius)
	inner := inner_rect(outer, renderData.width)
	color := to_sdl_color(renderData.color)
	
	// Case where borders inner box is entirely taken up by borders
	// Just render a solid rounded rect
	if inner.box.width <= 0 || inner.box.height <= 0 {
		mesh: Background_Mesh
		
		generate_background_mesh(outer, color, &mesh)
		
		sdl.RenderGeometry(
			renderer,
			nil,
			raw_data(mesh.vertices[:]),
			i32(len(mesh.vertices)),
			raw_data(mesh.indices[:]),
			i32(len(mesh.indices)),
		)
		return
	}
	
	mesh: Border_Mesh
	generate_border_mesh(outer, inner, color, &mesh)
	sdl.RenderGeometry(
		renderer,
		nil,
		raw_data(mesh.vertices[:]),
		i32(len(mesh.vertices)),
		raw_data(mesh.indices[:]),
		i32(len(mesh.indices)),
	)
}