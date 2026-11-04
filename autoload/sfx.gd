extends Node
## Effets sonores (autoload "Sfx").
##
## Aucun fichier audio : tous les sons sont **synthétisés au démarrage**
## (bruit filtré + sinus), ce qui garde le projet 100 % original et
## redistribuable. Remplacer un son par un vrai fichier .wav plus tard ne
## demandera que de changer `_streams["nom"]`.
##
## `play("nom", position)` pour un son dans le monde,
## `play_ui("nom")` pour un son non spatialisé (interface).

const SAMPLE_RATE := 22050
const POOL_SIZE := 10
const UI_POOL_SIZE := 4

var _players: Array[AudioStreamPlayer3D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _music_player: AudioStreamPlayer = null
var _music_track := "day"


func _ready() -> void:
	# En mode sans fenêtre (tests, export serveur) on synthétise quand même
	# les sons — pour que les tests les vérifient — mais sans lecteurs audio.
	if DisplayServer.get_name() != "headless":
		for i in POOL_SIZE:
			var player := AudioStreamPlayer3D.new()
			player.max_distance = 45.0
			player.unit_size = 6.0
			add_child(player)
			_players.append(player)

		for i in UI_POOL_SIZE:
			var ui_player := AudioStreamPlayer.new()
			add_child(ui_player)
			_ui_players.append(ui_player)

	_streams["harvest"] = _make_harvest()
	_streams["eat"] = _make_eat()
	_streams["craft"] = _make_craft()
	_streams["build"] = _make_build()
	_streams["step"] = _make_step()
	_streams["splash"] = _make_splash()
	_streams["death"] = _make_death()
	_streams["ui"] = _make_ui()
	_streams["music"] = _make_music(_music_track)
	if DisplayServer.get_name() != "headless":
		var music_player := AudioStreamPlayer.new()
		music_player.volume_db = -12.0
		add_child(music_player)
		_music_player = music_player

	# Applique le volume général (réglages persistants) dès le démarrage.
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Settings.master_volume, 0.0001)))


func get_stream(sound: String) -> AudioStream:
	return _streams.get(sound)


## Joue un son à une position du monde (réutilise un lecteur libre).
func play(sound: String, position: Vector3, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.global_position = position
			player.play()
			return


## Coupe tous les sons en cours (changement de scène, fin de partie, tests).
func stop_all() -> void:
	for player in _players:
		player.stop()
	for player in _ui_players:
		player.stop()
	if _music_player != null:
		_music_player.stop()


## Joue un son non spatialisé (interface, retour d'action).
func play_ui(sound: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	for player in _ui_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return
	if _ui_players.is_empty():
		return
	# Tous occupés : on réutilise le premier (les sons d'interface sont courts).
	_ui_players[0].stream = stream
	_ui_players[0].volume_db = volume_db
	_ui_players[0].play()


# --- Musique d'ambiance dynamique -------------------------------------------

func play_music(track: String) -> void:
	_music_track = track
	_streams["music"] = _make_music(track)
	_start_music()


func stop_music() -> void:
	play_music("day")


func _start_music() -> void:
	if _music_player == null:
		return
	var stream: AudioStream = _streams.get("music")
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.play()


func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ratio := GameState.world_time / GameState.SECONDS_PER_DAY
	var track := "night"
	if ratio >= 0.25 and ratio < 0.75:
		track = "day" if ratio < 0.5 else "dusk"
	if track != _music_track:
		play_music(track)


# --- Synthèse ----------------------------------------------------------------
# Chaque générateur renvoie un tableau d'échantillons entre -1 et 1.

## Bruit filtré passe-bas : idéal pour les impacts (bois, pierre, pas).
func _noise(duration: float, decay: float, smoothing: float, volume: float) -> PackedFloat32Array:
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var previous := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var envelope := exp(-t * decay)
		var raw := randf() * 2.0 - 1.0
		previous = lerpf(previous, raw, smoothing)
		samples[i] = previous * envelope * volume
	return samples


## Sinus avec glissando de fréquence et décroissance.
func _sweep(freq_start: float, freq_end: float, duration: float, decay: float, volume: float) -> PackedFloat32Array:
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var ratio := t / duration
		var freq := lerpf(freq_start, freq_end, ratio)
		phase += TAU * freq / SAMPLE_RATE
		samples[i] = sin(phase) * exp(-t * decay) * volume
	return samples


## Ajoute `b` à `a` (mélange de deux sons).
func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var count := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var va := a[i] if i < a.size() else 0.0
		var vb := b[i] if i < b.size() else 0.0
		out[i] = va + vb
	return out


## Décalage temporel (silence puis `b`), pour les sons en plusieurs temps.
func _delay(b: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var offset := int(seconds * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(offset + b.size())
	for i in b.size():
		out[offset + i] = b[i]
	return out


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


# --- Musique ----------------------------------------------------------------

func _make_music(track: String) -> AudioStreamWAV:
	var duration := 2.0
	var samples := PackedFloat32Array()
	samples.resize(int(duration * SAMPLE_RATE))
	if track == "night":
		for i in samples.size():
			var t := float(i) / SAMPLE_RATE
			samples[i] = (sin(TAU * 55.0 * t) * 0.12 + randf() * 0.02 - 0.01) * exp(-t * 3.0)
	else:
		var amb := _noise(duration, 6.0, 0.5, 0.05)
		samples = amb
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	stream.data = data
	return stream


# --- Sons --------------------------------------------------------------------

func _make_harvest() -> AudioStreamWAV:
	# Craquement de bois : bruit sec + petit "toc" grave.
	var crack := _noise(0.22, 26.0, 0.35, 0.9)
	var thump := _sweep(160.0, 70.0, 0.16, 22.0, 0.5)
	return _to_wav(_mix(crack, thump))


func _make_eat() -> AudioStreamWAV:
	# Trois petits croquements rapprochés.
	var bite := _noise(0.06, 40.0, 0.5, 0.7)
	var out := _mix(bite, _delay(bite, 0.11))
	out = _mix(out, _delay(bite, 0.2))
	return _to_wav(out)


func _make_craft() -> AudioStreamWAV:
	# Deux notes montantes : "ça marche".
	var first := _sweep(520.0, 520.0, 0.12, 12.0, 0.35)
	var second := _sweep(780.0, 780.0, 0.22, 10.0, 0.35)
	return _to_wav(_mix(first, _delay(second, 0.1)))


func _make_build() -> AudioStreamWAV:
	# Coup de marteau : impact mat puis résonance courte.
	var hit := _noise(0.3, 18.0, 0.25, 1.0)
	var wood := _sweep(220.0, 90.0, 0.25, 16.0, 0.55)
	return _to_wav(_mix(hit, wood))


func _make_step() -> AudioStreamWAV:
	# Pas étouffé sur le sable.
	return _to_wav(_noise(0.09, 55.0, 0.18, 0.45))


func _make_splash() -> AudioStreamWAV:
	# Entrée dans l'eau : bruit large qui s'éteint.
	var splash := _noise(0.55, 7.0, 0.7, 0.8)
	var body := _sweep(400.0, 120.0, 0.4, 9.0, 0.2)
	return _to_wav(_mix(splash, body))


func _make_death() -> AudioStreamWAV:
	# Descente grave, un peu inquiétante.
	return _to_wav(_sweep(320.0, 60.0, 1.1, 2.2, 0.5))


func _make_ui() -> AudioStreamWAV:
	# Clic d'interface discret.
	return _to_wav(_sweep(900.0, 700.0, 0.07, 45.0, 0.3))
