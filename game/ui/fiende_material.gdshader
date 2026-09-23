// Fiendens materiallager (M73): ett TUNT lager ovanpa konsten, styrt av en MASK.
//
// OBS: INGA svenska tecken i den har filen. Godots shader-tokenizer stoppar pa a/a/o (matt: "SHADER
// ERROR: Tokenizer: Unknown character") och da kompileras inte shadern alls. Kommentarerna skrivs
// darfor utan prickar har, till skillnad fran all annan kod i projektet.
//
// VARFOR ETT LAGER OCH INTE ETT MATERIAL PA FIGUREN: ett `material_override` pa en Sprite3D tar bort
// Godots egen rakning av rutnatet (hframes) OCH hela dess ljusslinga. Matt under vagens gang:
//   - override pa figuren: arket trycktes in i quaden, figuren blev en 16 px remsa (73 px mot 22 641, M59)
//   - egen ljusslinga i shadern: figuren blev 55 steg morkare an med Godots eget material (svart
//     silhuett med en enda glansflack), och aven en helt tom genomgangsshadern skilde 19 445 px fran
//     Godots egen - ljusmodellen ar inte vard att kopiera for att fa en glans.
// Lagret ror darfor INTE figuren: den behaller Godots material, rutnat, billboard och ljus exakt som
// forut, och glansen laggs ovanpa. Gar lagret sonder star figuren kvar orodd.
//
// Rutorna klipps ur en AtlasTexture (samma ruta som figuren visar), sa shadern behover ingen egen
// rutmatematik: UV ar 0..1 over rutan.
//
// Maskens kanaler, samma filformat for generatorn och for materialeditorn:
//   R = vat (glansig)   G = metall (spegelblank)   B = glas (kantljus)   A = aura (emission)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D ark : source_color, filter_nearest;
uniform sampler2D mask : source_color, filter_nearest;
uniform vec3 vat_farg : source_color = vec3(0.85, 0.93, 1.0);
uniform vec3 metall_farg : source_color = vec3(0.80, 0.88, 1.0);
uniform vec3 glas_farg : source_color = vec3(0.75, 0.90, 1.0);
// AURAN (M74): en KALL KANT. Den var varm (1.0, 0.72, 0.40) och lag som ett fyllt lager over HELA
// kroppen (maskens band 0.0-1.0): en vitblek valnad med varm dimma over sig laser som ANGAR. Alex:
// "Spokena ser ut som de angar, det skall bara vara minimal aura runtom som ger en kansla av
// etheritet". En blek kall kant laser som eter.
uniform vec3 aura_farg : source_color = vec3(0.68, 0.80, 1.00);
uniform float aura_vidd = 0.016;     // ringens radie i andelar av rutan (~1,3 texel i en 80 px-ruta)
uniform float aura_styrka = 0.55;    // matt fram, se tools/mat_aura.py: ett hogre varde branner ut kanten
uniform float styrka = 1.0;

void vertex() {
	// BILLBOARDEN AR FIGURENS, INTE SHADERNS (M79, Alex: *"det blir som en dubbel, vit fiende"*).
	//
	// Raden som stod har var Godots eget recept ur dokumentationen:
	//
	//     MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
	//                                           INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	//
	// Den satter lagrets bas mot kameran men TAPPAR modellens skala, och lagret hamnade darfor
	// forskjutet och en aning fel skalat mot figuren - matt som en blek dubblett over fienden. Lagret
	// ar ett BARN till figuren och har nu `BILLBOARD_ENABLED` precis som den (satts i `_fiende_lager`),
	// sa de tva quadarna hamnar pa varandra utan egen matematik.
}

void fragment() {
	vec4 konst = texture(ark, UV);
	vec4 m = texture(mask, UV);
	// Lagret foljer konstens silhuett: ingen glans pa genomskinliga rutor.
	float yta = konst.a;
	// Glas ar ett kantljus langs silhuetten, vatten en mjuk glans, metall en stram och kall.
	// Siffrorna ar nedtonade efter matning: banden tacker HELA kroppen (generatorns mask ar ett band,
	// inte en malad yta), och 0,75 overall gjorde figuren DUBBELT sa ljus (medel 159 mot 75) - en
	// helkroppsgloria, inte en glans. En malad mask i editorn ger glansen pa axeln i stallet.
	float kant = pow(1.0 - abs(UV.x - 0.5) * 2.0, 1.5);
	vec3 farg = vat_farg * m.r * 0.30
		+ metall_farg * m.g * 0.32
		+ glas_farg * m.b * kant * 0.70;
	// AURAN (M74): en KANT langs silhuetten, inte en fyllning over kroppen.
	// Maskens A sager VAR auran far sitta (bandet), och kanten kommer ur hur BLANDAD en ring av prov
	// kring pixeln ar: helt innanfor silhuetten = 1 (ingen aura), halften innanfor (pa sjalva kanten)
	// = 0, helt utanfor = 0. Att mata BARA sin egen pixel racker inte - da blir hela bandet en
	// fyllning, och det var precis vad Alex sag ("spokena ser ut som de angar").
	// Grenen kostar ingenting for en fiende utan aura: m.a ar 0 overallt och ringen hoppas over.
	float aura = 0.0;
	if (m.a > 0.004) {
		float nara = 0.0;
		for (int i = 0; i < 8; i++) {
			float v = float(i) * 0.7853981634;
			nara += textureLod(ark, UV + vec2(cos(v), sin(v)) * aura_vidd, 0.0).a;
		}
		float kantighet = clamp(1.0 - abs(2.0 * (nara * 0.125) - 1.0), 0.0, 1.0);
		aura = kantighet * clamp(m.a * 2.0, 0.0, 1.0);
	}
	ALBEDO = (farg + aura_farg * aura * aura_styrka) * styrka * yta;
	ALPHA = 1.0;
}
