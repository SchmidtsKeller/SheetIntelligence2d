// The Monster's night vision (#90): a red vignette and a subtle filter over
// the world. Drawn by NightVision (night_vision.gd), which owns the look: every
// value here is set from its exports, where the defaults are documented.
//
// One full-screen pass that reads the screen once. It works with the
// Compatibility renderer the Web build uses and stays cheap on phones: no
// mipmaps, no blur, a handful of arithmetic per pixel.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// 0 shows the world untouched, 1 the look, above 1 a stronger look (spider).
uniform float intensity = 1.0;
uniform float desaturation = 0.3;
uniform vec4 tint : source_color = vec4(1.0, 0.66, 0.45, 1.0);
uniform float tint_strength = 0.22;
uniform float shadow_lift = 0.05;
uniform float grain = 0.025;
uniform float grain_fps = 24.0;
uniform vec4 vignette_color : source_color = vec4(0.36, 0.07, 0.05, 1.0);
uniform float vignette_strength = 0.7;
uniform float vignette_start = 0.55;
uniform float vignette_end = 1.25;
uniform float pulse = 0.06;
uniform float pulse_period = 4.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);


float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
	vec3 world = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(world, LUMA);
	// The tint at the brightness of the pixel: amber where it is light.
	vec3 tint_dir = tint.rgb / max(dot(tint.rgb, LUMA), 0.001);
	vec3 color = mix(world, vec3(luma), clamp(desaturation * intensity, 0.0, 1.0));
	color = mix(color, luma * tint_dir, clamp(tint_strength * intensity, 0.0, 1.0));
	// Night vision: the dark stays dark, but readable.
	color += shadow_lift * intensity * (1.0 - luma) * (1.0 - luma) * tint_dir;

	// Strongest at the edges and corners, following the screen's shape.
	vec2 edge = abs(SCREEN_UV - 0.5) * 2.0;
	float reach = pow(pow(edge.x, 3.0) + pow(edge.y, 3.0), 1.0 / 3.0);
	float breath = 1.0 + pulse * sin(TIME * 6.2831853 / max(pulse_period, 0.01));
	float vignette = smoothstep(vignette_start, vignette_end, reach * breath);
	// The vignette keeps the shapes under it, as shades of crimson.
	vec3 crimson = vignette_color.rgb * (0.5 + luma);
	color = mix(color, crimson, clamp(vignette * vignette_strength * intensity, 0.0, 1.0));

	vec2 cell = floor(FRAGCOORD.xy) + floor(TIME * grain_fps) * vec2(37.0, 17.0);
	color += (hash(cell) - 0.5) * grain * intensity;

	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
