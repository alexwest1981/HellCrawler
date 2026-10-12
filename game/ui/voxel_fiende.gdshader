// THE FLOOR UNDER THE LIGHT (M112).
//
// Alex: *"strider med fiender resulterar ofta med att man har ljus bakom fienden, och då är de
// grådassiga, så man skulle behöva avge lite ljus själv, så det lyser upp fienden med."*
// (fights often leave the enemy backlit, and then they are grey and dull -- they should give off a
// little light of their own, so that lights the enemy up too.)
//
// WHY EMISSION AND NOT A LIGHTER MATERIAL: a CONSTANT emission was tried and measured away (M74) --
// "en fast emission lägger samma ljus över allt och späder ut figurens egna färger", the figures came
// out pale white. The difference here is that the emission is MULTIPLIED BY THE FIGURE'S OWN COLOUR
// (the voxel model's vertex colour), so a dark enemy stays dark and a coloured one stays coloured. It
// is a FLOOR under the light, not a layer over the art -- the same thing the linked 2D cel/toon
// shaders do with their `min_light` (godotshaders.com/shader/2d-cel-toon-shader-v2-basic, CC0).
//
// The model KEEPS Godot's own lighting loop: no `light()` function is written here, so the room's
// torches, the player's lantern and the shadows land on the model exactly as before. Only EMISSION is
// added, and it is added to the material the voxel model already had (`Voxel.nod`) -- the material is
// ours, so nothing of Godot's sprite/grid machinery is at stake.
//
// NOTE: the declaration names are ASCII on purpose. Godot's shader tokenizer stops at a/a/o (measured:
// "SHADER ERROR: Tokenizer: Unknown character") and `--headless` never compiles shaders, so the test
// suite would not catch it. Same trap as `ui/dekor.gdshader` and `ui/fiende_material.gdshader`.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

// 0.0 = the old behaviour (the enemy goes black when the light is behind it).
uniform float min_ljus : hint_range(0.0, 1.0) = 0.20;
uniform float grovhet : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	// The colour comes from the art, never from a constant (the M74 rule).
	ALBEDO = COLOR.rgb;
	ROUGHNESS = grovhet;
	METALLIC = 0.0;
	EMISSION = COLOR.rgb * min_ljus;
}
