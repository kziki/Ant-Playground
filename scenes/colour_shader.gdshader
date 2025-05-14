shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D user_pallete: filter_nearest;

void fragment() {
	vec4 screen_colour = texture(screen, SCREEN_UV);
	float l8_index_normalized = screen_colour.r;
	vec2 pallate_uv = vec2(0.5, l8_index_normalized);
	vec4 colour = texture(user_pallete, pallate_uv);
	COLOR = colour;
}