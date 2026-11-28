extends Node
## Spielt die erzeugten Soundeffekte aus res://sounds ab, dazu Musik und Atmo in Schleife.
## Ein kleiner Pool aus Playern sorgt dafür, dass sich Sounds überlagern dürfen.

const NAMEN := ["knack_perfekt", "knack_riss", "knistern", "knirschen", "matsch", "knarzen", "ausholen", "hammer",
	"greifen", "ablegen", "werfen", "einwurf", "plopp", "schritt", "hinsetzen", "muenzen", "kasse", "verkauf",
	"glocke", "freischalten", "meilenstein", "gold", "ziel", "voll", "rohrpost", "eichhorn", "miau", "fehler",
	"maschine", "wischen", "hebel", "rollen", "rutsch", "stinken", "warnung", "schaufeln", "sog", "kauz", "gack"]

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
var _grillen: AudioStreamPlayer
var _regen: AudioStreamPlayer
var _draussen_player: AudioStreamPlayer
var _tiefpass: AudioEffectLowPassFilter
var _draussen_bus := -1
var _gestartet := false
var _klang := {"vogel": 1.0, "grillen": 0.0, "regen": 0.0}

const BUS_DRAUSSEN := "Draussen"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Eigener Bus für alles, was von draußen kommt: in der Hütte klingt es leiser und dumpfer
	AudioServer.add_bus()
	_draussen_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_draussen_bus, BUS_DRAUSSEN)
	AudioServer.set_bus_send(_draussen_bus, "Master")
	_tiefpass = AudioEffectLowPassFilter.new()
	_tiefpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_draussen_bus, _tiefpass)
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
	_atmo.bus = BUS_DRAUSSEN
	_grillen = _schleife("res://sounds/grillen.wav")
	_grillen.bus = BUS_DRAUSSEN
	_regen = _schleife("res://sounds/regen.wav")
	_regen.bus = BUS_DRAUSSEN
	_draussen_player = AudioStreamPlayer.new()
	_draussen_player.bus = BUS_DRAUSSEN
	add_child(_draussen_player)


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
	_gestartet = true
	tagesklang(_klang.vogel, _klang.grillen, _klang.regen)


func musik_lautstaerke(wert: float) -> void:
	_musik.volume_db = linear_to_db(max(0.001, wert)) - 9.0


## Lautstärken der Außen-Schleifen (0..1): Vogelgezwitscher, Grillen, Regen. Der Himmel stellt das je Tageszeit.
func tagesklang(vogel: float, grillen: float, regen: float) -> void:
	_klang = {"vogel": vogel, "grillen": grillen, "regen": regen}
	_schleife_laut(_atmo, vogel, -14.0)
	_schleife_laut(_grillen, grillen, -19.0)
	_schleife_laut(_regen, regen, -11.0)


func _schleife_laut(p: AudioStreamPlayer, anteil: float, voll_db: float) -> void:
	if p == null or p.stream == null:
		return
	if anteil <= 0.01:
		if p.playing:
			p.stop()
		return
	p.volume_db = voll_db + linear_to_db(clampf(anteil, 0.01, 1.0))
	if not p.playing and _gestartet:
		p.play()


## anteil 0 = draußen (klar), 1 = in der Hütte (leiser und dumpf)
func draussen_daempfen(anteil: float) -> void:
	if _draussen_bus < 0:
		return
	_tiefpass.cutoff_hz = lerpf(20000.0, 1100.0, clampf(anteil, 0.0, 1.0))
	AudioServer.set_bus_volume_db(_draussen_bus, lerpf(0.0, -7.0, clampf(anteil, 0.0, 1.0)))


## Einzelnes Geräusch von draußen (Kauz, knackender Ast), läuft über den gedämpften Bus.
func spiele_draussen(name: String, lautstaerke_db := 0.0, tonhoehe := 1.0) -> void:
	var strom: AudioStream = _sounds.get(name)
	if strom == null and _varianten.has(name):
		var liste: Array = _varianten[name]
		strom = liste[randi() % liste.size()]
	if strom == null:
		return
	_draussen_player.stream = strom
	_draussen_player.volume_db = lautstaerke_db
	_draussen_player.pitch_scale = tonhoehe
	_draussen_player.play()
