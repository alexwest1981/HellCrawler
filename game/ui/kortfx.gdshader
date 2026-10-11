// The card's own effects, in ONE overlay on top of the card.
//
// Idea and recipe from godotshaders.com: "2d Burn/dissolve from point" by DimensionAlmios (enekoassets)
// and "Highlight Shader (Good version)" by oLe Studios. This file is our own writing of both — the
// pages' own licence could not be read from the HTML, so the credit stands in full: keep their names
// here if the file is ever reused elsewhere.
//
// Alex wanted two things from the shaders he sent: a shine when the pointer is over a card
// ("highlight-shader-good-version" — a mild version), and the card burning away when it is used
// ("2d-burn-dissolve-from-point"). Both live here, and they are drawn by a single node sitting ON TOP
// of the card.
//
// WHY AN OVERLAY AND NOT A MATERIAL ON THE CARD'S PARTS: a card is a tree (banner, icon, name, effect
// text). A canvas shader runs per draw call, and UV is that part's own rect — a burning spot would land
// in a different place on every part. This node reads SCREEN_TEXTURE (everything already drawn under
// it, which IS the whole card) and dissolves that, so the frame, the art and the text burn together.
// The overlay is only visible while something is happening, so the screen copy costs nothing in idle.
//
// ASCII only: the Godot tokenizer stops at a-ring/a-umlaut/o-umlaut in a NAME, and headless never
// compiles shaders — a broken shader would only show in a render run.

shader_type canvas_item;

uniform sampler2D skarm : hint_screen_texture, filter_nearest;
uniform vec2 storlek = vec2(104.0, 144.0);        // the overlay's own size in px (the card's size)

// THE SHINE (hover): a light band that follows the pointer.
uniform float glans : hint_range(0.0, 1.0) = 0.0;
uniform vec2 glans_pos = vec2(52.0, 72.0);        // pointer, in the overlay's own px
uniform float glans_vidd : hint_range(1.0, 60.0) = 12.0;
// MILD (Alex ville ha "en mild version"): 0,30 mot nästan vitt tvättade kortet och lästes som
// genomskinlighet — precis det han inte vill ha. 0,14 är en glimt, inte en slöja, och tonen är
// papperets egen varma ton i stället för vitt.
uniform float glans_styrka : hint_range(0.0, 1.0) = 0.14;

// THE BURN (played): a noise-driven dissolve from the point where the card was clicked.
uniform float brand : hint_range(0.0, 1.2) = 0.0; // 0 = whole card, >= 1 = gone
uniform vec2 brand_punkt = vec2(52.0, 72.0);      // the click, in the overlay's own px
uniform float brand_kant : hint_range(0.0, 30.0) = 7.0;
uniform vec3 brand_glod : source_color = vec3(1.0, 0.62, 0.18);

float slump(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Value noise: cheap, and the card is 104x144 px, so two octaves read as a torn edge.
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

void fragment() {
	vec4 c = texture(skarm, SCREEN_UV);
	vec2 p = UV * storlek;

	// The shine first: it is added to the card, not painted over it.
	if (glans > 0.001) {
		// A diagonal band: the band's own axis is turned 45 degrees, so the light sweeps like a
		// reflection over a glossy surface instead of a vertical stripe.
		float axel = (p.x * 0.7 + p.y * 0.7);
		float mal = (glans_pos.x * 0.7 + glans_pos.y * 0.7);
		float avstand = abs(axel - mal);
		float band = 1.0 - smoothstep(0.0, glans_vidd, avstand);
		if (band > 0.0) {
			// Blue-white, not pure white: the palette's own highlight, so the card does not lose
			// its colours where the light passes.
			c.rgb = mix(c.rgb, vec3(0.92, 0.90, 0.82), band * glans_styrka * glans);
		}
	}

	// Then the burn.
	if (brand > 0.001) {
		float n = brus(p * 0.07) * 0.6 + brus(p * 0.16) * 0.4;
		float d = distance(p, brand_punkt) + (n - 0.5) * 22.0;
		float radie = brand * max(storlek.x, storlek.y) * 1.15;
		if (d < radie) {
			c = vec4(0.0);                                  // burnt away
		} else if (d < radie + brand_kant + n * 7.0) {
			c.rgb = mix(c.rgb, brand_glod, 0.80);           // the glowing edge
			c.a = max(c.a, 0.92);
		}
	}

	COLOR = c;
}
