// The screen melts when the run ends in defeat — the way back to the village.
//
// Idea and recipe from godotshaders.com: "DOOM-like Melting Screen" by shader_kitten. This file is our
// own writing of it (the original melts a texture; ours reads the screen); the credit stands in full
// since the page's licence could not be read from the HTML.
//
// Alex sent the DOOM melting screen for exactly this: "När man dött och skall tillbaka till byn så kan
// denna transition vara". The original melts a texture; here the node reads SCREEN_TEXTURE instead, so
// the whole game view (dungeon, HUD, panel and all) dissolves without any render target of its own.
//
// Movement 0 = the picture as it is, 1 = gone. Each column of the screen falls a different distance,
// driven by value noise, which is what makes it read as melting rather than as a wipe.
//
// ASCII only: the Godot tokenizer stops at a-ring/a-umlaut/o-umlaut in a NAME.

shader_type canvas_item;

uniform sampler2D skarm : hint_screen_texture, filter_nearest;
uniform float smalt : hint_range(0.0, 1.5) = 0.0;      // 0 = whole, >= 1 = gone
uniform float kolumner : hint_range(1.0, 64.0) = 24.0; // how coarse the falling strips are
uniform vec3 aska : source_color = vec3(0.10, 0.07, 0.06);

float slump(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (smalt <= 0.001) {
		COLOR = texture(skarm, SCREEN_UV);
	} else {
		// One noise value per column: neighbouring pixels fall together, so it reads as strips
		// rather than as a wipe.
		float x = floor(UV.x * kolumner) / kolumner;
		float n = slump(vec2(x, 1.0)) * 0.7 + slump(vec2(x * 3.0, 7.0)) * 0.3;
		// THE COLUMN IS SAMPLED HIGHER UP than the pixel being drawn, so the picture slides DOWN,
		// which is the melting (the DOOM shader's one line: col = UV.y - movement * k). The space
		// the column has left behind is bare ash.
		float fall = smalt * (0.35 + n * 1.4);
		float kalla = UV.y - fall;
		if (kalla < 0.0) {
			COLOR = vec4(aska, 1.0);
		} else {
			vec4 c = texture(skarm, vec2(SCREEN_UV.x, kalla));
			// The top of every column is burnt, so the edge reads while it falls.
			float kant = smoothstep(0.0, 0.22, kalla);
			c.rgb = mix(aska, c.rgb, kant);
			COLOR = c;
		}
	}
}
