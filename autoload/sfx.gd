extends Node
## Effets sonores (autoload "Sfx").
##
## Volontairement minimal pour le M0 : un lecteur 3D jetable par son.
## Les vrais bus audio (Musique / SFX / Ambiance) arriveront au jalon M7.

const POOL_SIZE := 8

var _players: Array[AudioStreamPlayer3D] = []


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.max_distance = 40.0
		add_child(player)
		_players.append(player)


## Joue un son à une position du monde (réutilise un lecteur libre).
func play_at(stream: AudioStream, position: Vector3) -> void:
	if stream == null:
		return
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.global_position = position
			player.play()
			return


## Joue un son non spatialisé (interface).
func play_ui(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
