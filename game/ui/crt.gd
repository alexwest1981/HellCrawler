## CRT-lagret (M39): en ruta överst i HUD-lagret som läser skärmen och lägger tillbaka den med
## skanlinjer, vinjett och välvd kant (se `crt.gdshader`). Alex' referensbilder har den känslan — bilden
## ligger i en gammal tjock-TV.
##
## Rutan tar INGEN pekare (`MOUSE_FILTER_IGNORE`): den ligger över allt, och ett lager som äter klick
## hade gjort menyn och korten oklickbara utan att något syntes på skärmen (precis det felet hade
## spelvyn i går, se M39-fixen av `gui_disable_input`).
class_name Crt
extends ColorRect

const SHADER := "res://ui/crt.gdshader"
## Shaderns standardvärden, satta UTTRYCKLIGEN av samma skäl som `styrka` (se `bygg`). De står här
## för att `sätt_rak` ska kunna ge tillbaka dem utan att läsa shadern.
const VÄLVNING := 0.018
const KROMA := 0.5

static func bygg() -> Crt:
	var c := Crt.new()
	c.name = "crt"
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.color = Color(1, 1, 1, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(SHADER):
		var m := ShaderMaterial.new()
		m.shader = load(SHADER)
		# Styrkan sätts uttryckligen: en uniform som aldrig ställts in ligger kvar på shaderns
		# standardvärde i ritningen, men `get_shader_parameter` svarar null — och då mätte provet 0,00
		# samtidigt som effekten var fullt påslagen. Samma sak för välvningen och färgdelningen, som
		# `sätt_rak` ska kunna stänga av och slå på igen.
		m.set_shader_parameter("styrka", 1.0)
		m.set_shader_parameter("valvning", VÄLVNING)
		m.set_shader_parameter("kroma", KROMA)
		c.material = m
	return c

## Slår effekten av och på. Av betyder att rutan inte syns alls, inte att styrkan är noll: en ruta som
## ligger kvar och kopierar skärmen varje bildruta kostar tid även när den inte gör något.
func sätt_på(på: bool) -> void:
	visible = på

func är_på() -> bool:
	return visible and material is ShaderMaterial

## Styrkan (0-1) för mätning och för ett mjukare läge. Utan material finns inget att ställa.
func sätt_styrka(v: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("styrka", clampf(v, 0.0, 1.0))

## RAKT LÄGE (M123): välvningen och färgdelningen av, allt annat kvar. Alex, om byn: *"Bort med ...
## CRT-kurvaturen/svart i hörnen/sträckningen i sidled"*. Skanlinjerna och vinjetten var inte
## klagomålet, men kanten buktade (svarta hörn där uv hamnade utanför bilden) och färgerna delades i
## sidled. Uniformerna finns redan i shadern — ingen ny shader, ingen ny ruta.
func sätt_rak(på: bool) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("valvning", 0.0 if på else VÄLVNING)
		(material as ShaderMaterial).set_shader_parameter("kroma", 0.0 if på else KROMA)

func rak() -> bool:
	if material is ShaderMaterial:
		var v = (material as ShaderMaterial).get_shader_parameter("valvning")
		return float(v) <= 0.0 if v != null else false
	return false

func styrka() -> float:
	if material is ShaderMaterial:
		# get_shader_parameter ger null om shadern inte kunde kompileras, och float(null) kastar ett fel
		# i stället för att säga vad som är fel — då är styrkan noll och felet står i loggen.
		var v = (material as ShaderMaterial).get_shader_parameter("styrka")
		return float(v) if v != null else 0.0
	return 0.0
