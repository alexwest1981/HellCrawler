## Plåten som HUD:ens små rutor vilar på (M40): en mörk metallskiva med fasade kanter och nitar i
## hörnen — samma material som HUD-ramen (M36), men för statusblocket och loggen.
##
## En enda funktion för alla tre: tre kopior av samma plåt hade glidit isär i smutsen och nitarnas
## läge, och det är just likheten som gör att rutorna läses som samma HUD.
class_name HudPlat
extends RefCounted

const NIT = 2.0          ## nitarnas storlek i px
const LUFT := 4.0        ## hur långt in från kanten nitarna sitter

## `c` ritar, `r` är plåten i c:s egna koordinater. `alpha` är över hur mycket rutan ligger: en ruta som
## ligger över spelvärlden ska släppa igenom en aning (referensens plattor är halvgenomskinliga), medan
## en som ligger i marginalen kan vara tät.
static func rita(c: CanvasItem, r: Rect2, alpha: float = 0.94) -> void:
	var mörk := Palett.c(2)
	var ljus := Palett.c(4)
	var högdager := Palett.c(5)
	var nit := Palett.c(6)
	var botten := Palett.c(1)
	var f := mörk
	f.a = alpha
	c.draw_rect(r, f)
	# Fasade kanter: ljus överkant och vänsterkant, mörk underkant och högerkant. Det är samma grepp
	# som HUD-ramen använder, och det är det som gör en platt ruta till en plåt.
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), högdager)
	c.draw_rect(Rect2(r.position, Vector2(1.0, r.size.y)), ljus)
	c.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1.0), Vector2(r.size.x, 1.0)), botten)
	c.draw_rect(Rect2(Vector2(r.end.x - 1.0, r.position.y), Vector2(1.0, r.size.y)), botten)
	# Nitar i de fyra hörnen, indragna från kanten.
	for p in [Vector2(r.position.x + LUFT, r.position.y + LUFT),
			Vector2(r.end.x - LUFT - NIT, r.position.y + LUFT),
			Vector2(r.position.x + LUFT, r.end.y - LUFT - NIT),
			Vector2(r.end.x - LUFT - NIT, r.end.y - LUFT - NIT)]:
		c.draw_rect(Rect2(p, Vector2(NIT, NIT)), nit)
		c.draw_rect(Rect2(p + Vector2(NIT, 0.0), Vector2(1.0, NIT)), botten)
