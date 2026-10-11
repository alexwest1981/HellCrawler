shader_type spatial;
// DEKORATIONEN (M84): graset, roten, mossan och smasten i miljon. Alex: *"saker i miljon som inte
// skall ha nagon collision, men bidrar till mer... kansla"*.
//
// GRASET LYSER INTE SIALVT: render_mode ar inte `unshaded`. Vaningen ar mork och lyktan i handen ar
// det som lyser (BESLUT 007), sa en tuva ska falla i skugga nar ljuset vander sig bort - annars
// lyser den som en dekal i morkret. Albedon ar textur, ingen emission.
//
// GLODEN (glöd > 0) ar undantaget fran den regeln och galler bara elden: en kandelaer och en spricka i
// golvet med eld ar LJUSKALLOR, och i referensen (One More Dungeon) ar det precis de som syns langt
// bort i morkret - svampar, symboler och kittlar som gloder. Matt: 71 rekvisiter pa en 50x50-vaning
// med 24 riktiga ljus syntes anda inte i vyn, for ett ljus racker 4,5 m; en glodande duk syns pa hur
// langt som helst och kostar ingenting. Gloden lyser inte UPP rummet (det gor ljuset), den visar VAR
// ljuset ar.
//
// BILLBOARDEN ar samma recept som fiendelagret: basen kommer fran den inverterade vyn och modellens
// egen translation behalls. Den tappar modellens skala, vilket inte spelar nagon roll har - varje
// instans ar en QuadMesh i sin egen storlek.
//
// VINDEN: toppen svar, roten star still. Svingen dras ur varldslaget (MODEL_MATRIX[3]) i stallet for
// ur INSTANCE_CUSTOM, sa ingen instansdata behover skickas in.
render_mode cull_disabled, depth_draw_opaque, shadows_disabled, specular_disabled;

uniform sampler2D textur : source_color, filter_nearest, repeat_disable;
uniform float svep : hint_range(0.0, 0.08) = 0.012;
uniform float vind : hint_range(0.0, 4.0) = 1.4;
// Gloden: markdekoren har 0 (albedon ar textur, ingen emission), elden har ett varde over 1 sa den
// syns pa hall i morkret.
uniform float glod : hint_range(0.0, 8.0) = 0.0;

void vertex() {
	// Skalan per instans behalls: langden pa basens axlar ar instansens skala (M79: tappade man den
	// ritades lagret i en annan storlek an figuren). Positionen kommer fran MODEL_MATRIX[3].
	vec3 skala = vec3(length(MODEL_MATRIX[0]), length(MODEL_MATRIX[1]), length(MODEL_MATRIX[2]));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * skala.x, INV_VIEW_MATRIX[1] * skala.y,
		INV_VIEW_MATRIX[2] * skala.z, MODEL_MATRIX[3]);
	float fas = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
	VERTEX.x += sin(TIME * vind + fas) * svep * UV.y * UV.y;
}

void fragment() {
	vec4 c = texture(textur, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	EMISSION = c.rgb * glod;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
