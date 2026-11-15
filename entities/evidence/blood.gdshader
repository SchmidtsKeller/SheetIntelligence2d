// A blood mark on the ground (#91), drawn from the numbers of a BloodShape
// instead of an image.
//
// Every element of the shape is a stroke with a soft field; the fields add
// up, so overlapping blobs flow into one pool, and the sum is how thick the
// blood is. Noise shifts the outline so it is irregular, makes thicker and
// thinner parts, and darkens where the blood clots. The blood is dark,
// oxidized crimson, nearly opaque where it is thick and slightly transparent
// at its thin edges, so the ground shows through.
//
// Wet: the thickness is also a height. Its rim rises like a drop of liquid
// and its top is flat and glossy, so the flashlight and the torches glint on
// it the way they glint on the wet mud of the painted ground (#76). Unlit, it
// stays dark: the glint is light, never colour of its own.
shader_type canvas_item;

// Keep in step with BloodShape.MAX_ELEMENTS and BloodShape.FIELD_REACH.
const int MAX_ELEMENTS = 16;
const float FIELD_REACH = 1.7;
// The field of one element at its edge: (1 - 1 / FIELD_REACH^2)^3.
const float EDGE_FIELD = 0.2797;

// Per element: its ends (a.x, a.y, b.x, b.y) and (radius at a, radius at b,
// thickness, unused), in pixels around the center.
uniform vec4 segments[MAX_ELEMENTS];
uniform vec4 params[MAX_ELEMENTS];
uniform int element_count = 0;
// Where the noise is read for this mark.
uniform vec2 noise_offset = vec2(0.0);

uniform vec3 thick_color : source_color = vec3(0.14, 0.045, 0.038);
uniform vec3 thin_color : source_color = vec3(0.3, 0.11, 0.085);
// Clotted, drying blood: darker and browner.
uniform vec3 clot_color : source_color = vec3(0.09, 0.04, 0.032);
uniform float thick_alpha = 0.93;
uniform float thin_alpha = 0.42;
// How far the outline is shifted, in pixels, at two scales.
uniform float warp_amount = 2.4;
uniform float edge_roughness = 0.5;
// How high the blood stands at its rim, for the light.
uniform float rim_height = 7.0;
// How much the angle of the light shapes the blood (0: flat lighting).
uniform float relief_lighting = 0.35;
// A sharp glint where the light is mirrored and a broad wet sheen.
uniform float glint_strength = 1.0;
uniform float glint_sharpness = 80.0;
uniform float sheen_strength = 0.1;
uniform float sheen_sharpness = 20.0;

// Position around the center, in pixels, from vertex() to fragment().
varying vec2 local;
// How glossy the pixel is, from fragment() to light().
varying float wetness;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// The summed field at p and its gradient.
vec3 field(vec2 p) {
	float sum = 0.0;
	vec2 gradient = vec2(0.0);
	for (int index = 0; index < MAX_ELEMENTS; index++) {
		if (index >= element_count) {
			break;
		}
		vec4 segment = segments[index];
		vec4 param = params[index];
		vec2 a = segment.xy;
		vec2 ab = segment.zw - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
		vec2 offset = p - (a + ab * t);
		float reach = FIELD_REACH * mix(param.x, param.y, t);
		float q = dot(offset, offset) / (reach * reach);
		if (q < 1.0) {
			float falloff = 1.0 - q;
			sum += param.z * falloff * falloff * falloff;
			gradient -= param.z * 6.0 * falloff * falloff * offset / (reach * reach);
		}
	}
	return vec3(sum, gradient);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 seed = noise_offset;
	// An irregular outline: the field is read at a shifted point.
	vec2 warp = vec2(
		value_noise(local * 0.16 + seed),
		value_noise(local * 0.16 + seed + vec2(31.7, 11.3))
	) - 0.5;
	vec2 rough = vec2(
		value_noise(local * 0.4 + seed + vec2(5.1, 47.9)),
		value_noise(local * 0.4 + seed + vec2(63.2, 2.7))
	) - 0.5;
	vec3 f = field(local + warp * 2.0 * warp_amount + rough * 2.0 * edge_roughness);

	// Inside where the field passes its edge value; the edge is smoothed over
	// about a pixel on screen, whatever the zoom.
	float above = f.x - EDGE_FIELD;
	float edge_width = max(fwidth(f.x), 0.0001);
	float cover = smoothstep(-edge_width, edge_width, above);
	// Thickness: rises fast at the rim, then flat, like a pool of liquid.
	float thickness = 1.0 - exp(-2.2 * max(above, 0.0));
	float variation = value_noise(local * 0.11 + seed + vec2(17.0, 83.0));
	thickness *= mix(0.4, 1.0, variation);
	float clot = smoothstep(0.55, 0.85, value_noise(local * 0.3 + seed + vec2(71.0, 29.0)));

	vec3 color = mix(thin_color, thick_color, smoothstep(0.0, 0.7, thickness));
	color = mix(color, clot_color, clot * 0.7 * thickness);
	float alpha = mix(thin_alpha, thick_alpha, smoothstep(0.05, 0.6, thickness)) * cover;
	COLOR = vec4(color, alpha) * COLOR;

	// The height's slope: steep at the rim, flat on top.
	vec2 slope = rim_height * 2.2 * exp(-2.2 * max(above, 0.0)) * f.yz;
	NORMAL = normalize(vec3(-slope, 1.0));
	// Clots are duller; thin films are wet too.
	wetness = mix(1.0, 0.45, clot) * smoothstep(0.0, 0.15, thickness + 0.1);
}

void light() {
	vec3 to_light = LIGHT_POSITION - LIGHT_VERTEX;
	float diffuse = 1.0;
	float spec = 0.0;
	// Lights without height (e.g. directional ones) light the blood flat.
	if (!LIGHT_IS_DIRECTIONAL && to_light.z > 0.5) {
		vec3 l = normalize(to_light);
		// Relative to flat ground, so the blood is as bright as the ground.
		float lambert = clamp(dot(NORMAL, l) / l.z, 0.0, 2.0);
		diffuse = mix(1.0, lambert, relief_lighting);
		vec3 half_vector = normalize(l + vec3(0.0, 0.0, 1.0));
		float facing = max(dot(NORMAL, half_vector), 0.0);
		spec = glint_strength * pow(facing, glint_sharpness);
		spec += sheen_strength * pow(facing, sheen_sharpness);
		spec *= wetness;
	}
	vec3 light_color = LIGHT_COLOR.rgb * LIGHT_ENERGY;
	LIGHT = vec4(light_color * (COLOR.rgb * diffuse + vec3(spec)), LIGHT_COLOR.a);
}
