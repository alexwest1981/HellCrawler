shader_type spatial;
// DEKORATIONEN (M84): graset, roten, mossan och smasten i miljon. Alex: *"saker i miljon som inte
// skall ha nagon collision, men bidrar till mer... kansla"*.
//
// GRASET LYSER INTE SIALVT: render_mode ar inte `unshaded`. Vaningen ar mork och lyktan i handen ar
// det som lyser (BESLUT 007), sa en tuva ska falla i skugga nar ljuset vander sig bort - annars
// lyser den som en dekal i morkret. Albedon ar textur, ingen emission.
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
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
