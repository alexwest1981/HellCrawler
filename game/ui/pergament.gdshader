// Parchment for the MINIMAP (Alex: *"Parchment-shadern var tänkt till kartan ... den som är uppe till
// höger över dungeon"*). The minimap is drawn in code (draw_rect per tile plus the marks), so the
// shader works without a texture: the colour comes from COLOR (the draw call's own colour, times
// TEXTURE, which is white for an untextured draw) and the position from the vertex position, passed
// down as a varying. That also makes it work on a textured layer.
//
// ASCII only: the Godot tokenizer stops at a-ring/a-umlaut/o-umlaut, and a shader with one of them in
// a name never compiles — and headless never compiles shaders, so it only shows in a render run.

shader_type canvas_item;

uniform vec3 ton : source_color = vec3(0.82, 0.68, 0.44);       // parchment
uniform vec3 kant_ton : source_color = vec3(0.12, 0.07, 0.03);  // burnt/browned edge
uniform float styrka : hint_range(0.0, 1.0) = 0.85;             // how much of the paper treatment
uniform float kroma : hint_range(0.0, 1.0) = 0.90;              // how much of the map's own colour survives
uniform float gryn : hint_range(0.0, 0.5) = 0.16;               // paper grain
uniform float flackar : hint_range(0.0, 1.0) = 0.50;            // dirt spots
uniform float kant : hint_range(0.0, 1.0) = 0.40;               // darker toward the border
uniform vec2 storlek = vec2(76.0, 60.0);                        // the item's own size, in local px

varying vec2 lokal;

float slump(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Value noise: cheap, two octaves are plenty for paper the size of a postage stamp.
float brus(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = slump(i);
	float b = slump(i + vec2(1.0, 0.0));
	float c = slump(i + vec2(0.0, 1.0));
	float d = slump(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	lokal = VERTEX;
}

void fragment() {
	vec2 uv = lokal / max(storlek, vec2(1.0));
	vec3 c = COLOR.rgb * texture(TEXTURE, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	// Papper: LJUSET tonas till papper, men FÄRGEN behålls (kroma = avvikelsen från grått). En grå sten
	// blir alltså varmt papper medan en röd fiende förblir röd — det är skillnaden mellan att tona
	// kartan och att färga den, och utan kroma försvinner märkena man läser kartan med.
	vec3 kroma_kvar = (c - vec3(lum)) * kroma;
	vec3 papper = ton * (0.30 + 1.05 * lum);
	vec3 f = mix(c, papper + kroma_kvar, styrka);
	// Korn och fläckar: utan dem läses tonen som ett filter, inte som ett material.
	float n = brus(uv * 34.0) * 0.6 + brus(uv * 96.0) * 0.4;
	f *= 1.0 - gryn * (1.0 - n);
	float flack = smoothstep(0.66, 0.95, brus(uv * 5.0 + vec2(3.1, 7.7)));
	f = mix(f, kant_ton, flack * flackar * 0.45);
	// Den nötta kanten: ett papper som vikts och hanterats i år.
	float d = distance(uv, vec2(0.5));
	f = mix(f, kant_ton, kant * smoothstep(0.22, 0.70, d));
	COLOR = vec4(f, 1.0);
}
