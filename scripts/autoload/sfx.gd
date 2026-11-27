extends Node
## Spielt die erzeugten Soundeffekte aus res://sounds ab.
## Ein kleiner Pool aus Playern sorgt dafür, dass sich Sounds überlagern dürfen.

const NAMEN := ["knack_perfekt", "knack_riss", "knirschen", "matsch", "knarzen", "greifen", "ablegen",
	"werfen", "einwurf", "muenzen", "kasse", "verkauf", "freischalten", "meilenstein", "eichhorn",
	"miau", "fehler", "maschine", "wischen", "hebel", "stinken", "warnung"]

var _sounds := {}
var _player: Array[AudioStreamPlayer] = []
var _naechster := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMEN:
		var pfad := "res://sounds/%s.wav" % n
		if ResourceLoader.exists(pfad):
			_sounds[n] = load(pfad)
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_player.append(p)


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
