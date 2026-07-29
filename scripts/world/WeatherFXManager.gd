class_name WeatherFXManager
extends CanvasLayer

## Manages visual weather effects: rain particle overlay, lightning flashes,
## and fog tint. Spawned as a CanvasLayer overlay above the world.
## Listens to WeatherSystem signals and orchestrates all atmospheric visuals.

@export var rain_particle_count: int = 200

var _weather_system: WeatherSystem = null
var _rain_particles: GPUParticles2D = null
var _lightning_timer: Timer = null
var _lightning_flash: ColorRect = null
var _fog_overlay: ColorRect = null
var _fog_particles: GPUParticles2D = null
var _fog_drift_tween: Tween = null


func _ready() -> void:
	# Use layer 1 so it renders ABOVE the HUD's day-night overlay
	layer = 2
	_setup_rain_particles()
	_setup_lightning()
	_setup_fog_overlay()
	_setup_fog_particles()
	
	# Find WeatherSystem (it's a child of GameManager)
	_weather_system = get_tree().root.find_child("WeatherSystem", true, false)
	if not _weather_system:
		# Try from GameManager
		var gm := get_tree().root.find_child("GameManager", true, false)
		if gm and "weather_system" in gm:
			_weather_system = gm.weather_system as WeatherSystem
	
	if _weather_system:
		_weather_system.weather_changed.connect(_on_weather_changed)
		_on_weather_changed(_weather_system.current_weather)


func _setup_rain_particles() -> void:
	# Load or create rain drop texture
	var rain_tex: Texture2D = load("res://assets/generated/rain_drop.png")
	if not rain_tex:
		var img := Image.create(8, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		for y in 6:
			img.set_pixel(3, y + 3, Color(0.85, 0.9, 1.0, 1.0))
			img.set_pixel(4, y + 3, Color(0.85, 0.9, 1.0, 0.7))
		rain_tex = ImageTexture.create_from_image(img)
	
	# GPUParticles2D for falling rain
	_rain_particles = GPUParticles2D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.emitting = false
	_rain_particles.visible = false
	_rain_particles.amount = rain_particle_count
	_rain_particles.lifetime = 1.5
	_rain_particles.one_shot = false
	_rain_particles.explosiveness = 0.0
	_rain_particles.preprocess = 0.0
	_rain_particles.texture = rain_tex
	_rain_particles.fixed_fps = 0
	_rain_particles.local_coords = true
	
	# Visibility rect covering a wide area above the viewport
	_rain_particles.visibility_rect = Rect2(-1200, -200, 2400, 1600)
	
	# Process material for rain behavior
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0.0, 1.0, 0.0)  # Straight down
	pmat.spread = 20.0  # Slight spread for wind effect
	pmat.gravity = Vector3(80.0, 500.0, 0.0)  # Fast falling + slight sideways drift
	pmat.initial_velocity_min = 300.0
	pmat.initial_velocity_max = 450.0
	pmat.scale_min = 0.8
	pmat.scale_max = 1.6
	pmat.color = Color(0.85, 0.9, 1.0, 0.5)
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(1200, 10, 0)
	
	_rain_particles.process_material = pmat
	add_child(_rain_particles)


func _setup_lightning() -> void:
	# Full-screen white flash overlay
	_lightning_flash = ColorRect.new()
	_lightning_flash.name = "LightningFlash"
	_lightning_flash.color = Color(1.0, 1.0, 0.95, 0.0)
	_lightning_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning_flash.visible = false
	_lightning_flash.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_lightning_flash)
	
	# Timer for periodic lightning strikes
	_lightning_timer = Timer.new()
	_lightning_timer.name = "LightningTimer"
	_lightning_timer.one_shot = true
	_lightning_timer.timeout.connect(_trigger_lightning)
	add_child(_lightning_timer)


func _setup_fog_overlay() -> void:
	_fog_overlay = ColorRect.new()
	_fog_overlay.name = "FogOverlay"
	_fog_overlay.color = Color(0.65, 0.65, 0.72, 0.0)
	_fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_overlay.visible = false
	_fog_overlay.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_fog_overlay)


## Creates drifting fog particles that scroll horizontally, giving the
## illusion of rolling mist banks moving across the landscape.
func _setup_fog_particles() -> void:
	# Create a soft, blurry cloud texture procedurally
	var fog_tex: Texture2D = _make_fog_particle_texture()
	
	_fog_particles = GPUParticles2D.new()
	_fog_particles.name = "FogParticles"
	_fog_particles.emitting = false
	_fog_particles.visible = false
	_fog_particles.amount = 30
	_fog_particles.lifetime = 20.0
	_fog_particles.one_shot = false
	_fog_particles.explosiveness = 0.0
	_fog_particles.preprocess = 5.0  # Pre-fill so fog is already drifting
	_fog_particles.texture = fog_tex
	_fog_particles.fixed_fps = 0
	_fog_particles.local_coords = true
	
	# Large visibility rect so fog covers the whole viewport
	_fog_particles.visibility_rect = Rect2(-1600, -600, 3200, 1800)
	
	# Process material for slow horizontal drift
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(1.0, 0.0, 0.0)  # Drift right
	pmat.spread = 5.0
	pmat.gravity = Vector3(0.0, 0.0, 0.0)  # No gravity — floats in air
	pmat.initial_velocity_min = 8.0
	pmat.initial_velocity_max = 20.0
	pmat.scale_min = 4.0
	pmat.scale_max = 10.0
	pmat.color = Color(0.85, 0.85, 0.88, 0.15)
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(1600, 600, 0)
	
	# Add slight randomness to lifetime so fog doesn't all fade together
	pmat.lifetime_randomness = 0.4
	
	_fog_particles.process_material = pmat
	add_child(_fog_particles)


## Creates a soft radial gradient texture for fog cloud particles.
func _make_fog_particle_texture() -> Texture2D:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var cx := size / 2.0
	var cy := size / 2.0
	var radius := size / 2.0
	for y in range(size):
		for x in range(size):
			var dx := (x - cx) / radius
			var dy := (y - cy) / radius
			var dist := sqrt(dx * dx + dy * dy)
			if dist < 1.0:
				# Smooth falloff: bright center fading to transparent edges
				var alpha := (1.0 - dist * dist) * 0.8
				# Slight noise variation for organic feel
				var noise := sin(x * 0.3 + y * 0.3) * 0.1 + 0.9
				alpha *= noise
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	
	return ImageTexture.create_from_image(img)


func _on_weather_changed(weather: WeatherSystem.WeatherType) -> void:
	match weather:
		WeatherSystem.WeatherType.RAIN:
			_start_rain()
			_clear_fog_instant()
			_stop_lightning()
		
		WeatherSystem.WeatherType.STORM:
			_start_rain()
			_clear_fog_instant()
			_start_lightning()
		
		WeatherSystem.WeatherType.FOG:
			_stop_rain()
			_stop_lightning()
			_show_fog_warning_and_start()
		
		WeatherSystem.WeatherType.CLEAR:
			_stop_rain()
			_clear_fog_instant()
			_stop_lightning()


func _start_rain() -> void:
	if not _rain_particles:
		return
	_rain_particles.visible = true
	_rain_particles.emitting = true


func _stop_rain() -> void:
	if not _rain_particles:
		return
	_rain_particles.emitting = false
	_rain_particles.visible = false


func _start_lightning() -> void:
	if _lightning_flash:
		_lightning_flash.visible = true
	_schedule_next_lightning()


func _stop_lightning() -> void:
	if _lightning_timer:
		_lightning_timer.stop()
	if _lightning_flash:
		_lightning_flash.visible = false
		_lightning_flash.color = Color(1.0, 1.0, 0.95, 0.0)


func _schedule_next_lightning() -> void:
	if not _lightning_timer:
		return
	var delay: float = 2.0 + randf() * 8.0
	_lightning_timer.start(delay)


func _trigger_lightning() -> void:
	if not _lightning_flash or not is_instance_valid(_lightning_flash):
		return
	# Quick bright flash with flicker
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_lightning_alpha, 0.0, 0.55, 0.04)
	tween.tween_method(_set_lightning_alpha, 0.55, 0.2, 0.02)
	tween.tween_method(_set_lightning_alpha, 0.2, 0.45, 0.02)
	tween.tween_method(_set_lightning_alpha, 0.45, 0.0, 0.15)
	
	# Play thunder rumble
	AudioManager.play(AudioManager.Sound.STORM_RUMBLE, -8.0)
	
	_schedule_next_lightning()


func _set_lightning_alpha(alpha: float) -> void:
	if _lightning_flash:
		_lightning_flash.color = Color(1.0, 1.0, 0.95, alpha)


## Shows a warning toast, then starts the fog after a brief delay
## so the player sees "The fog is coming..." before visibility drops.
func _show_fog_warning_and_start() -> void:
	# Skip if fog is already active or a start timer is already pending
	if _fog_overlay and _fog_overlay.visible:
		return
	if find_child("FogStartDelay", true, false):
		return
	
	ToastNotification.show_toast("The fog is coming...", ToastNotification.ToastType.WARNING, 3.0)
	
	# Delay the fog starting so the toast has time to be read
	var fog_timer := Timer.new()
	fog_timer.name = "FogStartDelay"
	fog_timer.one_shot = true
	fog_timer.timeout.connect(_start_fog)
	add_child(fog_timer)
	fog_timer.start(2.0)


func _start_fog() -> void:
	if not _fog_overlay:
		return
	_fog_overlay.visible = true
	_fog_overlay.color = Color(0.65, 0.65, 0.72, 0.0)
	
	# Start drifting fog particles
	if _fog_particles:
		_fog_particles.visible = true
		_fog_particles.emitting = true
	
	# Thicker fog overlay that rolls in
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_fog_alpha, 0.0, 0.35, 3.0)
	
	# Start subtle fog-pulse tween for atmospheric variation
	_fog_drift_tween = create_tween().set_loops()
	_fog_drift_tween.tween_method(_set_fog_alpha, 0.35, 0.4, 5.0)
	_fog_drift_tween.tween_method(_set_fog_alpha, 0.4, 0.35, 5.0)


func _clear_fog_instant() -> void:
	if not _fog_overlay:
		return
	_fog_overlay.color = Color(0.65, 0.65, 0.72, 0.0)
	_fog_overlay.visible = false
	# Kill any active fog tween
	var tw := create_tween()
	tw.kill()
	# Stop fog particles
	if _fog_particles:
		_fog_particles.emitting = false
		_fog_particles.visible = false
	# Kill drift tween
	if _fog_drift_tween and _fog_drift_tween.is_valid():
		_fog_drift_tween.kill()
		_fog_drift_tween = null
	# Cancel any pending fog-start delay timer
	var delay_timer := find_child("FogStartDelay", true, false)
	if delay_timer:
		delay_timer.queue_free()


func _set_fog_alpha(alpha: float) -> void:
	if _fog_overlay:
		_fog_overlay.color = Color(0.65, 0.65, 0.72, alpha)


func _exit_tree() -> void:
	if _weather_system and is_instance_valid(_weather_system):
		if _weather_system.weather_changed.is_connected(_on_weather_changed):
			_weather_system.weather_changed.disconnect(_on_weather_changed)