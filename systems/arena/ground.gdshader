// The painted ground of the arena (#76), drawn on one sprite that covers it.
//
// Five painted terrains (grass, clover, path, gravel, mud) are blended by the
// layout map; where two meet, the brighter texels of either win, so edges
// look grown, not faded. Every terrain is tiled twice, the second time turned
// and scaled, and the relief map's variant decides which shows, so the tiling
// does not repeat visibly.
//
// The height map gives the light something to shape: each terrain's normal
// map (its brightness as height), the hills and the cart ruts. The reflection
// map (each terrain's gloss, plus where it is wet) makes the light glint.
// Flat, dry ground is lit exactly as without them, so the brightness the
// lights were tuned for (#63) stays.
shader_type canvas_item;

// Path (R), gravel (G), mud (B), clover (A); the rest is grass.
uniform sampler2D layout_map : filter_linear, repeat_disable;
// Hills (R), wetness (G), cart ruts (B), which tiling shows (A).
uniform sampler2D relief_map : filter_linear, repeat_disable;
// Each terrain: color with gloss in alpha, and its normal map.
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D clover_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D clover_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap, repeat_enable;

// Size of the arena in pixels; the sprite covers it.
uniform vec2 world_size = vec2(3200.0, 2400.0);
// Pixels of arena per terrain tile.
uniform float tile_size = 320.0;
uniform float brightness = 1.0;
// How strongly brighter texels win where terrains meet.
uniform float blend_sharpness = 8.0;
// Strength of the terrains' own relief, the hills and the ruts.
uniform float detail_relief = 1.0;
uniform float hill_relief = 90.0;
uniform float rut_depth = 4.0;
// How much the angle of the light shapes the ground (0: flat lighting).
uniform float relief_lighting = 0.85;
uniform float specular_strength = 0.6;
// Wet ground is darker and shinier.
uniform float wet_darkening = 0.3;
// Cart ruts are darker, packed earth.
uniform float rut_darkening = 0.3;

// Gloss (x) and shininess (y) of the pixel, from fragment() to light().
varying vec2 reflection;

struct Terrain {
	vec3 color;
	float gloss;
	vec2 normal;
	float weight;
};

void add_terrain(
	inout Terrain sum,
	sampler2D albedo,
	sampler2D normal_map,
	float weight,
	vec2 uv_a,
	vec2 uv_b,
	vec4 grad_a,
	vec4 grad_b,
	float variant
) {
	if (weight < 0.004) {
		return;
	}
	vec4 a = textureGrad(albedo, uv_a, grad_a.xy, grad_a.zw);
	vec4 b = textureGrad(albedo, uv_b, grad_b.xy, grad_b.zw);
	vec2 na = textureGrad(normal_map, uv_a, grad_a.xy, grad_a.zw).xy * 2.0 - 1.0;
	vec2 nb = textureGrad(normal_map, uv_b, grad_b.xy, grad_b.zw).xy * 2.0 - 1.0;
	// The second tiling is turned by 90 degrees, and its normals with it.
	nb = vec2(nb.y, -nb.x);
	vec4 texel = mix(a, b, variant);
	float height = dot(texel.rgb, vec3(0.3, 0.59, 0.11));
	float blend = weight * exp(blend_sharpness * height);
	sum.color += texel.rgb * blend;
	sum.gloss += texel.a * blend;
	sum.normal += mix(na, nb, variant) * blend;
	sum.weight += blend;
}

float macro_height(vec2 uv) {
	vec4 relief = texture(relief_map, uv);
	return relief.r * hill_relief - relief.b * rut_depth;
}

void fragment() {
	vec2 world = UV * world_size;
	vec4 mix_map = texture(layout_map, UV);
	vec4 relief = texture(relief_map, UV);
	vec2 uv_a = world / tile_size;
	vec2 uv_b = vec2(-world.y, world.x) / (tile_size * 1.27) + vec2(0.37, 0.71);
	vec4 grad_a = vec4(dFdx(uv_a), dFdy(uv_a));
	vec4 grad_b = vec4(dFdx(uv_b), dFdy(uv_b));
	float variant = relief.a;

	float grass = max(1.0 - mix_map.r - mix_map.g - mix_map.b - mix_map.a, 0.0);
	Terrain sum = Terrain(vec3(0.0), 0.0, vec2(0.0), 0.0);
	add_terrain(sum, grass_albedo, grass_normal, grass, uv_a, uv_b, grad_a, grad_b, variant);
	add_terrain(sum, clover_albedo, clover_normal, mix_map.a, uv_a, uv_b, grad_a, grad_b, variant);
	add_terrain(sum, path_albedo, path_normal, mix_map.r, uv_a, uv_b, grad_a, grad_b, variant);
	add_terrain(sum, gravel_albedo, gravel_normal, mix_map.g, uv_a, uv_b, grad_a, grad_b, variant);
	add_terrain(sum, mud_albedo, mud_normal, mix_map.b, uv_a, uv_b, grad_a, grad_b, variant);
	float total = max(sum.weight, 0.0001);
	vec3 color = sum.color / total;
	float gloss = sum.gloss / total;
	vec2 detail = sum.normal / total;

	// Hills and ruts: the slope of the macro height, per pixel of arena.
	vec2 texel = 1.0 / vec2(textureSize(relief_map, 0));
	vec2 step_px = texel * world_size;
	vec2 slope = vec2(
		macro_height(UV + vec2(texel.x, 0.0)) - macro_height(UV - vec2(texel.x, 0.0)),
		macro_height(UV + vec2(0.0, texel.y)) - macro_height(UV - vec2(0.0, texel.y))
	) / (2.0 * step_px);

	float wet = relief.g;
	color *= brightness * (1.0 - wet_darkening * wet) * (1.0 - rut_darkening * relief.b);
	COLOR = vec4(color, 1.0);
	NORMAL = normalize(vec3(detail * detail_relief - slope, 1.0));
	reflection = vec2(clamp(gloss + wet * 0.6, 0.0, 1.0), mix(0.25, 0.9, wet));
}

void light() {
	vec3 to_light = LIGHT_POSITION - LIGHT_VERTEX;
	float diffuse = 1.0;
	float spec = 0.0;
	// Lights without height (e.g. directional ones) light the ground flat.
	if (!LIGHT_IS_DIRECTIONAL && to_light.z > 0.5) {
		vec3 l = normalize(to_light);
		// Relative to flat ground, so flat ground is lit as before.
		float lambert = clamp(dot(NORMAL, l) / l.z, 0.0, 2.5);
		diffuse = mix(1.0, lambert, relief_lighting);
		vec3 half_vector = normalize(l + vec3(0.0, 0.0, 1.0));
		float exponent = mix(10.0, 80.0, reflection.y);
		spec = pow(max(dot(NORMAL, half_vector), 0.0), exponent);
		spec *= reflection.x * specular_strength;
	}
	vec3 light_color = LIGHT_COLOR.rgb * LIGHT_ENERGY;
	LIGHT = vec4(light_color * (COLOR.rgb * diffuse + vec3(spec)), LIGHT_COLOR.a);
}
