package main

import "core:fmt"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
import clay "libs:clay"

Font_ID :: enum u16 {
	Display,
	Heading,
	Subheading,
	Body,
	Body_Emphasis,
	Button,
	Caption,
}

Font_Face :: enum {
	Regular,
	Medium,
	Semi_Bold,
}

Font_Spec :: struct {
	face: Font_Face,
	size: u16,
}

FONT_PATHS :: [Font_Face]cstring{
	.Regular	= "assets/fonts/Inter_18pt-Regular.ttf",
	.Medium	 = "assets/fonts/Inter_18pt-Medium.ttf",
	.Semi_Bold  = "assets/fonts/Inter_24pt-SemiBold.ttf",
}

@(rodata)
FONT_SPECS := [Font_ID]Font_Spec{
	.Display		= {.Semi_Bold, 32},
	.Heading		= {.Semi_Bold, 24},
	.Subheading	 = {.Medium, 20},
	.Body		   = {.Regular, 16},
	.Body_Emphasis  = {.Semi_Bold, 16},
	.Button		 = {.Medium, 14},
	.Caption		= {.Regular, 12},
}

Text_System :: struct {
	engine: ^ttf.TextEngine,
	fonts: [Font_ID]^ttf.Font,
}

load_fonts :: proc(system:  ^Text_System,) -> bool {
	faces: [Font_Face]^ttf.Font
	defer {
		for face in faces {
			if face != nil {
				ttf.CloseFont(face)
			}
		}
	}
	
	for path, face in FONT_PATHS {
		faces[face] = ttf.OpenFont(path, 16)
		
		if faces[face] == nil {
			fmt.eprintln(
				"Failed to open font:",
				path,
				sdl.GetError(),
			)
			return false
		}
	}
	
	for spec, id in FONT_SPECS {
		font := ttf.CopyFont(faces[spec.face])
		
		if font == nil {
			fmt.eprintln("Failed to copy font:", id)
			return false
		}
		
		if !ttf.SetFontSize(font, f32(spec.size)) {
			fmt.eprintln("Failed to set font size:", id)
			ttf.CloseFont(font)
			return false
		}
		system.fonts[id] = font
	}
	
	return true
}

get_font :: proc "contextless" (
	system: ^Text_System,
	id: u16,
	size: u16,
) -> ^ttf.Font {
	if system == nil || int(id) >= len(system.fonts) do return nil
	
	font_id := Font_ID(id)
	if FONT_SPECS[font_id].size != size do return nil
	
	return system.fonts[font_id]
}

init_text_system :: proc(
	system: ^Text_System,
	renderer: ^sdl.Renderer,
) -> bool {
	if !ttf.Init() {
		fmt.eprintln("SDL_ttf init failed:", sdl.GetError())
		return false
	}
	
	system.engine = ttf.CreateRendererTextEngine(renderer)
	
	if system.engine == nil {
		fmt.eprintln("Text engine failed:", sdl.GetError())
		ttf.Quit()
		return false
	}
	
	if !load_fonts(system) {
		destroy_text_system(system)
		return false
	}
	
	return true
}

destroy_text_system :: proc(system: ^Text_System) {
	if system.engine != nil {
		ttf.DestroyRendererTextEngine(system.engine)
	}
	
	for font in system.fonts {
		if font != nil {
			ttf.CloseFont(font)
		}
	}
	
	system^ = {}
	
	ttf.Quit()
}

render_text :: proc(
	system: ^Text_System,
	box: clay.BoundingBox,
	textData: clay.TextRenderData,
) {
	if textData.stringContents.length <= 0 { return }
	
	font := get_font(system, textData.fontId, textData.fontSize)
	if font == nil { return }
	
	text := ttf.CreateText(system.engine, font,
							cast(cstring)textData.stringContents.chars,
							uint(textData.stringContents.length))
							
	if text == nil { return }
	defer ttf.DestroyText(text)
	
	color := textData.textColor
	
	if !ttf.SetTextColor(
		text,
		u8(clamp(color.r, 0, 255)),
		u8(clamp(color.g, 0, 255)),
		u8(clamp(color.b, 0, 255)),
		u8(clamp(color.a, 0, 255)),
	) { return }
	
	ttf.DrawRendererText(text, box.x, box.y)
}

ui_text_static :: proc(
	$text: string,
	font: Font_ID = .Body,
	color: clay.Color = { 255, 255, 255, 255 }
) {
	clay.TextStatic(
		text,
		clay.TextElementConfig({
			fontId = u16(font),
			fontSize = FONT_SPECS[font].size,
			textColor = color,
		}),
	)
}

ui_text_dynamic :: proc(
	text: string,
	font: Font_ID = .Body,
	color: clay.Color = { 255, 255, 255, 255 }
) {
	clay.TextDynamic(
		text,
		clay.TextElementConfig({
			fontId = u16(font),
			fontSize = FONT_SPECS[font].size,
			textColor = color,
		}),
	)
}

ui_text :: proc {
	ui_text_static,
	ui_text_dynamic,
}
