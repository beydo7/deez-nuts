extends Node
## Spielt die erzeugten Soundeffekte aus res://sounds ab, dazu Musik und Atmo in Schleife.
## Ein kleiner Pool aus Playern sorgt dafür, dass sich Sounds überlagern dürfen.

const NAMEN := ["knack_perfekt", "knack_riss", "knistern", "knirschen", "matsch", "knarzen", "ausholen", "hammer",
	"greifen", "ablegen", "werfen", "einwurf", "plopp", "schritt", "hinsetzen", "muenzen", "kasse", "verkauf",
	"glocke", "freischalten", "meilenstein", "gold", "ziel", "voll", "rohrpost", "eichhorn", "miau", "fehler",
	"maschine", "wischen", "hebel", "rollen", "rutsch", "stinken", "warnung", "schaufeln", "sog"]

## Aufgenommene Geräusche von Kenney (CC0) in res://sounds/kenney, je Gruppe mehrere Varianten.
const VARIANTEN := ["footstep_grass", "footstep_wood", "impactWood_light", "impactWood_medium", "impactPlate_light",
	"impactSoft_medium", "impactSoft_heavy", "impactGlass_light", "impactMining", "impactPlank_medium",
	"impactBell_heavy", "click", "select", "confirmation", "drop", "error", "pluck"]

var _sounds := {}
var _varianten := {}
var _player: Array[AudioStreamPlayer] = []
var _naechster := 0
var _musik: AudioStreamPlayer
var _atmo: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMEN:
		var pfad := "res://sounds/%s.wav" % n
		if ResourceLoader.exists(pfad):
			_sounds[n] = load(pfad)
	for g in VARIANTEN:
		var liste: Array = []
		for i in range(1, 10):
			var pfad := "res://sounds/kenney/%s_%03d.ogg" % [g, i]
			if ResourceLoader.exists(pfad):
				liste.append(load(pfad))
		if not liste.is_empty():
			_varianten[g] = liste
	for i in 24:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_player.append(p)
	_musik = _schleife("res://sounds/musik.wav")
	_atmo = _schleife("res://sounds/atmo.wav")


func _schleife(pfad: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	if ResourceLoader.exists(pfad):
		p.stream = load(pfad)
		p.finished.connect(p.play)
	return p


## Spielt einen Sound. tonhoehe 1.0 = normal, streuung = Zufall auf die Tonhöhe.
func spiele(name: String, lautstaerke_db := 0.0, tonhoehe := 1.0, streuung := 0.06) -> void:
	if not _sounds.has(name):
		return
	var p := _player[_naechster]
	_naechster = (_naechster + 1) % _player.size()
	p.stream = _sounds[name]
	p.volume_db = lautstaerke_db
	p.pitch_scale = max(0.05, tonhoehe * (1.0 + randf_range(-streuung, streuung)))
	p.play()


## Spielt eine zufällige Variante aus einer Kenney-Gruppe (z. B. "footstep_grass").
func variante(gruppe: String, lautstaerke_db := 0.0, tonhoehe := 1.0, streuung := 0.05) -> void:
	if not _varianten.has(gruppe):
		return
	var liste: Array = _varianten[gruppe]
	var p := _player[_naechster]
	_naechster = (_naechster + 1) % _player.size()
	p.stream = liste[randi() % liste.size()]
	p.volume_db = lautstaerke_db
	p.pitch_scale = max(0.05, tonhoehe * (1.0 + randf_range(-streuung, streuung)))
	p.play()


func hat_variante(gruppe: String) -> bool:
	return _varianten.has(gruppe)


func musik_starten() -> void:
	musik_lautstaerke(float(Game.einstellungen.get("musik", 0.6)))
	if _musik.stream and not _musik.playing:
		_musik.play()
	if _atmo.stream and not _atmo.playing:
		_atmo.volume_db = -14.0
		_atmo.play()


func musik_lautstaerke(wert: float) -> void:
	_musik.volume_db = linear_to_db(max(0.001, wert)) - 9.0
