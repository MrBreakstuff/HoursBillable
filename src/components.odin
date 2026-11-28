package main

import clay "libs:clay"

button :: proc(
	id: clay.ElementId,
	label: string,
	input: ^Input_State,
	font_id: u16 = 0,
) -> bool {
	hovered := clay.PointerOver(id)
	
	background: clay.Color = {69, 71, 90, 255}
	
	if hovered {
		background = {88, 91, 112, 255}
		if input.mouse_down { background = {49, 50, 68, 255} }
	}
	
	if clay.UI(id)({
		layout = {
			sizing = {
				width = clay.SizingFixed(180),
				height = clay.SizingFixed(40),
			},
			childAlignment = { x = .Center, y = .Center },
			padding = clay.PaddingAll(8),
		},
		backgroundColor = background,
		cornerRadius = clay.CornerRadiusAll(6),
	}) {
		clay.Text(label, {
			fontId = font_id,
			fontSize = 16,
			textColor = {205, 214, 244, 255},
		})
	}
	
	return hovered && input.mouse_pressed
}