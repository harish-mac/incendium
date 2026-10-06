shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 5.0) = 2.0;
uniform vec4 tint : source_color = vec4(0.1, 0.05, 0.15, 0.4);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}