// CRT MODE (M39): the screen is read and put back with scanlines, a vignette and a slight colour
// shift -- the feel of the reference screenshots Alex gave, where the picture sits inside an old
// thick TV.
//
// THE BULGE: THE CORNERS BULGE, THE MIDDLE STAYS FLAT (M69). The shape used to stretch uv across the
// WHOLE picture (`valvning` * r2), and Alex: *"jag ville ha kvar buktningen, sa det blev
// CRT-upplevelsen, det var en haftig effekt, men det far inte bukta hej vilt nar man vander sig"*
// ("I wanted to keep the bulge, the CRT feel, the effect was great, but it must not bulge all over
// the place when you turn"). What moves when you turn is the middle -- the part you look straight at
// -- not the corner. The grip now lives in the corners (r2 * r2):
//
//   point                old (0.035 * r2)   new (0.018 * r4)
//   corner (c = +-1,+-1) 7.0 %              7.2 %   <- unchanged
//   edge   (c = 1, 0)    3.5 %              1.8 %
//   halfway (c = 0.5)    1.8 %              0.11 %  <- sixteen times flatter
//
// A picture that moves by different amounts in different parts of the screen causes motion sickness;
// now it moves only out in the corners, where nothing you follow with your eyes passes.
//
// The scale is the TV's, not the game's: the effect is computed in FRAGCOORD (screen pixels) so the
// scanlines land on every OTHER ROW of the window and not on every other pixel of the game view
// (480x270) -- those would have been 2.7 px wide bands that crawl when the window is resized.
shader_type canvas_item;
render_mode unshaded;

// The hint reads the screen BEHIND this rect: the rect sits on top of the HUD layer and copies
// everything already drawn (the 3D view, the HUD, the menu).
//
// THE FILTER DOES NOT MATTER (M78, measured). The question was whether `filter_linear` softens the
// pixel art one extra time, since the layer covers the whole screen. Measured: two screenshots taken
// before and after switching to `filter_nearest`, same run and same window, were pixel-identical
// (0 of 1 952 880 pixels differed). The effect is computed in FRAGCOORD, i.e. one sample per screen
// pixel -- the sample sits 1:1 with the rect, and then both filters give the same texel. Left as
// `filter_linear`, which was there first: no reason to change something that makes no difference.
uniform sampler2D skarm : hint_screen_texture, filter_linear;

uniform float styrka : hint_range(0.0, 1.0) = 1.0;      // 0 = no effect at all
uniform float skanlinje : hint_range(0.0, 1.0) = 0.22;  // how much every other row darkens
// 0.6 and not 0.85: the review of a GAME screenshot ("readable but on the edge of too dark") showed
// that the status row in the top left and the corners -- where the card stacks sit -- lost contrast
// in the vignette.
uniform float vinjett : hint_range(0.0, 2.0) = 0.60;    // how dark the corners get
uniform float valvning : hint_range(0.0, 0.2) = 0.018;  // how much the CORNERS bulge (see r2 * r2)
uniform float kroma : hint_range(0.0, 3.0) = 0.5;       // colour shift in px between red and blue
// THE SCANLINE PERIOD FOLLOWS THE GAME PIXEL (M151). It used to be two WINDOW rows, which was right
// while the view was 480x270 blown up; at 1920x1080 it is 540 hair-thin lines per screen -- measured
// in `chest.png` as film grain over the whole picture. `radhojd` is set to twice the screen pixels
// per game pixel, so a line stays as thick as it looked before the density went up.
uniform float radhojd : hint_range(2.0, 16.0) = 2.0;

void fragment() {
	// The bulge: uv is pulled out from the centre, but the strength grows with the FOURTH power of
	// the distance, so the corner bulges as before while the middle hardly moves.
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	float r2 = dot(c, c);
	c *= 1.0 + valvning * r2 * r2;
	vec2 uv = c * 0.5 + 0.5;

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		// Outside the picture: black, like a picture tube with no signal at the edge.
		COLOR = vec4(0.0, 0.0, 0.0, styrka);
	} else {
		float px = SCREEN_PIXEL_SIZE.x * kroma;
		vec3 f;
		f.r = texture(skarm, vec2(uv.x + px, uv.y)).r;
		f.g = texture(skarm, uv).g;
		f.b = texture(skarm, vec2(uv.x - px, uv.y)).b;

		// The scanlines: every other row of a GAME pixel, half strength.
		float rad = mod(FRAGCOORD.y, radhojd);
		f *= 1.0 - skanlinje * step(1.0, rad);

		// The vignette: darkens towards the corners, measured as distance from the centre.
		float d = distance(SCREEN_UV, vec2(0.5, 0.5));
		f *= 1.0 - vinjett * pow(clamp(d * 1.35, 0.0, 1.0), 2.0);

		COLOR = vec4(mix(texture(skarm, uv).rgb, f, styrka), 1.0);
	}
}
