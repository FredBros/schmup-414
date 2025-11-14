shader_type canvas_item;

uniform float speed_y = 0.20;   // vitesse de défilement vertical
uniform float tiling_y = 2.0;    // combien de tuiles verticales apparaissent sur l'écran

void fragment() {
vec2 uv = UV;
uv.y = fract(uv.y * tiling_y - TIME * speed_y);
COLOR = texture(TEXTURE, uv);
}