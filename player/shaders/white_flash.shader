shader_type canvas_item;

uniform float flash : hint_range(0.0, 2.0) = 0.0;
uniform vec3 flash_color : hint_color = vec3(1.0, 1.0, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV) * COLOR;
    // Additive flash: add `flash` * flash_color to rgb channels.
    // Don't change alpha; clamps keep values in range.
    tex_color.rgb = min(tex_color.rgb + flash_color * flash, vec3(1.0));
    COLOR = tex_color;
}
