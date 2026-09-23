// CRT-läget (M39): skärmen läses och läggs tillbaka med skanlinjer, vinjett och en svag
// färgförskjutning — känslan i referensbilderna Alex gav, där bilden ligger i en gammal tjock-TV.
//
// VÄLVNINGEN: HÖRNEN BUKTAR, MELLANPARTIET ÄR PLATT (M69). Formen drog förut ut uv över HELA bilden
// (`valvning` · r²), och Alex: *"jag ville ha kvar buktningen, så det blev CRT-upplevelsen, det var en
// häftig effekt, men det får inte bukta hej vilt när man vänder sig"*. Det som far när man vänder sig
// är just mellanpartiet — det man tittar rakt på — inte hörnet. Greppet sitter nu i hörnen (r² · r²):
//
//   punkt                 gammal (0,035 · r²)   ny (0,018 · r⁴)
//   hörnet (c = ±1, ±1)   7,0 %                 7,2 %   ← oförändrat
//   kanten (c = 1, 0)     3,5 %                 1,8 %
//   halvvägs (c = 0,5)    1,8 %                 0,11 %  ← sexton gånger plattare
//
// En bild som rör sig olika mycket i olika delar av skärmen ger åksjuka; nu rör den sig bara ute i
// hörnen, där inget man följer med blicken passerar.
//
// Skalan är TV:ns, inte spelets: effekten räknas i FRAGCOORD (skärmens pixlar) så skanlinjerna hamnar på
// varannan RAD i fönstret och inte på varannan pixel i spelvyn (480x270) — då hade de blivit 2,7 px
// breda ränder som vandrar när fönstret ändrar storlek.
shader_type canvas_item;
render_mode unshaded;

// Hinten läser skärmen BAKOM den här rutan: rutan ligger överst i HUD-lagret och kopierar allt som
// redan ritats (3D-vyn, HUD:en, menyn).
//
// FILTRET SPELAR INGEN ROLL (M78, mätt). Frågan var om `filter_linear` mjukade upp pixelkonsten en
// gång extra, eftersom lagret täcker hela skärmen. Mätt: two bilder tagna före och efter ett byte till
// `filter_nearest`, samma prov och samma fönster, var pixel-identiska (0 av 1 952 880 pixlar skilde).
// Effekten räknas i FRAGCOORD, alltså en sampling per skärmpixel — provet ligger 1:1 med rutan, och då
// ger båda filtren samma texel. Kvar står `filter_linear`, som var där först: ingen anledning att byta
// något som inte gör någon skillnad.
uniform sampler2D skarm : hint_screen_texture, filter_linear;

uniform float styrka : hint_range(0.0, 1.0) = 1.0;      // 0 = ingen effekt alls
uniform float skanlinje : hint_range(0.0, 1.0) = 0.22;  // hur mycket varannan rad mörknar
// 0,6 och inte 0,85: granskningen av en SPELskärmbild ("läsbar men på gränsen till för mörk") visade
// att statusraden uppe till vänster och hörnen — där korthögarna står — tappade kontrast i vinjetten.
uniform float vinjett : hint_range(0.0, 2.0) = 0.60;    // hur mörkt hörnen blir
uniform float valvning : hint_range(0.0, 0.2) = 0.018;  // hur mycket HÖRNEN buktar ut (se r² · r²)
uniform float kroma : hint_range(0.0, 3.0) = 0.5;       // färgförskjutning i px mellan röd och blå

void fragment() {
	// Välvningen: uv dras ut från mitten, men kraften växer med FJÄRDE potensen av avståndet, så
	// hörnet buktar som förut medan mittpartiet står nästan still.
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	float r2 = dot(c, c);
	c *= 1.0 + valvning * r2 * r2;
	vec2 uv = c * 0.5 + 0.5;

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		// Utanför bilden: svart, som en bildrörsskärm utan signal i kanten.
		COLOR = vec4(0.0, 0.0, 0.0, styrka);
	} else {
		float px = SCREEN_PIXEL_SIZE.x * kroma;
		vec3 f;
		f.r = texture(skarm, vec2(uv.x + px, uv.y)).r;
		f.g = texture(skarm, uv).g;
		f.b = texture(skarm, vec2(uv.x - px, uv.y)).b;

		// Skanlinjerna: varannan rad i FÖNSTRET, halvstarka.
		float rad = mod(FRAGCOORD.y, 2.0);
		f *= 1.0 - skanlinje * step(1.0, rad);

		// Vinjetten: mörknar mot hörnen, mätt i avstånd från mitten.
		float d = distance(SCREEN_UV, vec2(0.5, 0.5));
		f *= 1.0 - vinjett * pow(clamp(d * 1.35, 0.0, 1.0), 2.0);

		COLOR = vec4(mix(texture(skarm, uv).rgb, f, styrka), 1.0);
	}
}
