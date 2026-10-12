## FLISAN SKA UT UR KROPPEN — inte bara lossna (M118).
##
## Alex: *"Fienden tappar inte voxlar när man skadar dem"* och sedan *"Ok, voxlarna verkar mest gälla
## spökena."* Rotorsaken satt inte i antalet: `-- flisprov` mätte 94-346 bitar per träff för ALLA 17
## typer. Den satt i VAR bitarna hamnade — och det är samma sak som att de inte syns.
##
## Bitarna byggs ur de celler `Voxel.lossna` lämnade tillbaka, och de börjar alltså på sina EGNA
## cellers plats, inne i modellen. En träff som dödar tar bort kroppen och då syns de; en träff som
## bara skadar lämnar kroppen kvar, och en bit innanför kroppens ruta är dold för spelaren. Farten var
## mest UPPÅT (`m * 1,4` plus modellhöjden) och bara en aning utåt, så bitarna flög upp längs kroppen
## i stället för ut ur den.
##
## Mätt med `-- flisprov` (andel bitar utanför kroppens ruta 0,5 s efter träffen):
##
##   typ            före fixen   efter fixen
##   salt_wretch        19 %        99 %
##   bone_wretch        22 %        69 %     ← lägst av alla; en bred, låg kropp
##   mire_hound         32 %       100 %
##   candlewisp         52 %        99 %
##   ossuary_king       47 %       100 %
##   snitt, 17 typer    49 %        98 %
##
## Provet mäter exakt detta, huvudlöst och utan bild: bygg modellen, slå en träff som inte dödar, och
## räkna hur många bitar som hunnit UT ur kroppens ruta medan de lever. Utan sidledesknuffen
## (`VoxelRas.FLISA_SIDLED`) faller det på de täta typerna — det är provets hela uppgift.
##
##   godot --headless --path game --script res://tests/test_flisa.gd
extends SceneTree

var fails := 0
var checks := 0

## Typ -> lägsta andel bitar utanför kroppen som godkänns. Siffrorna är MÄTTA, inte satta: med
## knuffen ligger de på 99-100 % (bone_wretch 69 %, den bredaste och lägsta kroppen), utan den på
## 19-52 %. Gränsen 65 % ligger mellan dem, med marginal åt båda hållen.
const TYPER := {
	"mire_hound": 0.90,
	"salt_wretch": 0.90,
	"bone_wretch": 0.65,
	"candlewisp": 0.90,
	"ossuary_king": 0.90,
}
const SIDOR := 64
const DJUP := 2
const PIXEL := 0.012

func check(ok: bool, vad: String, detalj := "") -> void:
	checks += 1
	print("  %s  %s%s" % ["ok  " if ok else "FEL ", vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	if not ok:
		fails += 1

## Samma ruta som spelet ritar en fiende ur (`_enemy_tex` + `_klä_voxel`), utan retuschen: figurens
## FORM är det provet mäter, och retuschen ändrar färg.
func _textur(id: String) -> Texture2D:
	var path := "res://assets/enemies/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null

func _initialize() -> void:
	print("— flisan: bitarna ska UT ur kroppen —")
	check(VoxelRas.FLISA_SIDLED > 1.0,
		"flisan har en sidledesknuff (annars flyger bitarna upp längs kroppen och syns inte)",
		"FLISA_SIDLED %.1f" % VoxelRas.FLISA_SIDLED)
	var summa := 0.0
	var antal := 0
	for id in TYPER.keys():
		var tex: Texture2D = _textur(id)
		if tex == null:
			check(false, "%s: bilden finns" % id)
			continue
		var r := Voxel.figur_ruta(tex, 0, 6)
		if r.size.y <= 0.0:
			check(false, "%s: figurens ruta är inte tom" % id)
			continue
		var sidor := mini(SIDOR, maxi(8, int(r.size.y)))
		var vx := Voxel.ur_ark(tex, 0, 6, r.size.y * PIXEL, sidor, DJUP)
		var hela := vx.antal_celler()
		# TRÄFFEN SOM INTE DÖDAR: samma andel celler som `_slag_kvitto` tar (5 %, minst fyra).
		var borta := vx.lossna(maxi(4, int(float(hela) * 0.05)))
		check(not borta.is_empty(), "%s: träffen tar celler ur modellen" % id,
			"%d av %d celler" % [borta.size(), hela])
		if borta.is_empty():
			continue
		var kropp := Rect2()
		var kvar_mesh := vx.mesh()
		if kvar_mesh != null:
			# Bara x/y: modellen är två celler djup, och en bit som far i sidled är ute.
			var låda := kvar_mesh.get_aabb()
			kropp = Rect2(låda.position.x, låda.position.y, låda.size.x, låda.size.y)
		var flisa := Voxel.new()
		flisa.sidor = vx.sidor
		flisa.djup = vx.djup
		flisa.höjd = vx.höjd
		flisa.kolumner = vx.kolumner
		flisa.celler = borta
		flisa._förskjutning = vx._förskjutning
		var ras := VoxelRas.från(flisa, Transform3D(), 0.0, null, 4, VoxelRas.FLISA_SIDLED)
		root.add_child(ras)
		check(ras.antal_bitar() > 20, "%s: bitarna blir flera än en handfull" % id,
			"%d bitar" % ras.antal_bitar())
		# BITARNA FÖLJS MEDAN DE LEVER, och det BÄSTA värdet sparas: en enda lång bildruta kan hinna
		# döda hela raset (se `-- flisprov`), och det är rörelsen som mäts, inte takten.
		var bästa := 0.0
		var bästa_antal := 0
		for runda in 12:
			await create_timer(0.05).timeout
			var inne := 0
			var totalt := 0
			for bit in ras._bitar:
				var bn: MeshInstance3D = bit["nod"]
				if bn == null or not is_instance_valid(bn) or bn.mesh == null or not bn.visible:
					continue
				totalt += 1
				var p: Vector3 = bn.position + bn.mesh.get_aabb().get_center()
				if kropp.has_point(Vector2(p.x, p.y)):
					inne += 1
			if totalt > 0 and float(totalt - inne) / float(totalt) > bästa:
				bästa = float(totalt - inne) / float(totalt)
				bästa_antal = totalt
		check(bästa >= float(TYPER[id]), "%s: bitarna hinner ut ur kroppen" % id,
			"%.0f %% utanför (%d bitar mätta), krav %.0f %%" % [100.0 * bästa, bästa_antal,
				100.0 * float(TYPER[id])])
		summa += bästa
		antal += 1
		ras.queue_free()
		await create_timer(0.05).timeout
	print("")
	print("%d kontroller, %d fel — snitt %.0f %% av bitarna utanför kroppen (%d typer)"
		% [checks, fails, 100.0 * summa / float(maxi(1, antal)), antal])
	quit(1 if fails > 0 else 0)
