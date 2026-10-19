// SKYMNINGSHIMLEN (A-testet 19/10). ProceduralSkyMaterial ger en jämn gradient och ingenting mer —
// och i en porträtvy är himlen en tredjedel av bilden, så en plan yta där läser som en tom vägg.
//
// Här ligger två saker: gradienten (samma färger som förut, ur by.tscn) och STJÄRNOR. Stjärnorna är
// ett gitter i synriktningen: varje cell får ett slumptal ur sin egen position, och de ytterst få
// celler som ligger över tröskeln tänds. Ingen textur, inget minne, och samma stjärnhimmel varje
// bildruta (ingen flimmer — himlen ska inte röra sig).
//
// De tänds bara en bit över horisonten: vid horisonten ligger dimman och solljuset, och en stjärna
// där hade sett ut som en pixel i dimman.
shader_type sky;

uniform vec3 topp : source_color = vec3(0.071, 0.118, 0.271);
uniform vec3 horisont : source_color = vec3(0.878, 0.639, 0.541);
uniform vec3 stjarnfarg : source_color = vec3(0.85, 0.90, 1.0);
uniform float kurva : hint_range(0.1, 2.0) = 0.55;
uniform float stjarnstyrka : hint_range(0.0, 2.0) = 0.85;
uniform float stjarnhojd : hint_range(0.0, 0.9) = 0.28;
uniform float tathet : hint_range(0.0, 1.0) = 0.992;

float slump(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 c = mix(horisont, topp, pow(h, kurva));
	// EN PUNKT PER CELL, inte en färgad cell: först tändes hela celler, och en cell i ett kubgitter
	// projiceras som en långsträckt fyrkant — stjärnorna blev diagonala streck som såg ut som regn
	// (MÄTT på provbilden: "thin diagonal streaks, not round stars"). Nu ligger en slumpad punkt i
	// cellen och bara pixlarna närmast den tänds, alltså runda stjärnor.
	vec3 q = normalize(EYEDIR) * 240.0;
	vec3 cell = floor(q);
	vec3 f = fract(q) - 0.5;
	float lott = slump(cell);
	vec3 avik = (vec3(slump(cell + 1.7), slump(cell + 3.1), slump(cell + 5.3)) - 0.5) * 0.6;
	float nara = smoothstep(0.09, 0.0, length(f - avik));
	float hojd = smoothstep(stjarnhojd, stjarnhojd + 0.35, EYEDIR.y);
	COLOR = c + stjarnfarg * nara * step(tathet, lott) * hojd * stjarnstyrka;
}
