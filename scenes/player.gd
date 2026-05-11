extends CharacterBody3D

# ============================================================
#  GENSAKU — Locomotion + Cámara Sobre el Hombro v0.4
#  Estilo Dark Souls: personaje mira hacia donde se mueve,
#  cámara orbita libremente con SpringArm (evita paredes)
# ============================================================

# ---------- MOVIMIENTO ----------
@export_group("Movimiento")
@export var walk_speed    : float = 4.0
@export var run_speed     : float = 10.0
@export var acceleration  : float = 20.0
@export var deceleration  : float = 15.0
@export var jump_force    : float = 7.0
@export var gravity_scale : float = 2.2
@export var air_control   : float = 0.4

# ---------- CÁMARA ----------
@export_group("Cámara")
@export var mouse_sensitivity  : float = 0.002
@export var fov_base           : float = 75.0
@export var fov_max            : float = 95.0
@export var cam_pitch_min      : float = -30.0  # límite mirando hacia arriba
@export var cam_pitch_max      : float = 50.0   # límite mirando hacia abajo
@export var cam_distance       : float = 3.0    # distancia base SpringArm
@export var shoulder_offset    : float = 0.6    # offset hombro derecho
@export var cam_height         : float = 1.5    # altura pivot sobre el personaje
@export var rotation_smoothing : float = 8.0    # suavizado rotación mesh

# ---------- ANIMACIONES ----------
@export_group("Animaciones")
@export var anim_walk_speed : float = 1.0
@export var anim_run_speed  : float = 1.5

# ---------- NODOS ----------
@onready var cam_pivot   : Node3D          = $CameraPivot
@onready var spring_arm  : SpringArm3D     = $CameraPivot/SpringArm3D
@onready var camera      : Camera3D        = $CameraPivot/SpringArm3D/Camera3D
@onready var anim_player : AnimationPlayer = $Ziel_TheCrystalChimera/AnimationPlayer
@onready var mesh_root   : Node3D          = $Ziel_TheCrystalChimera

# ---------- NOMBRES DE ANIMACIONES ----------
const ANIM_IDLE := "Z_Idle_24/Anim_Z_Idle_24"
const ANIM_WALK := "Z_WalkCycle_24/Anim_Z_WalkCycle_24"
const ANIM_RUN  := "Z_FastRunCycle_24/Anim_Z_FastRunCycle_24"
const ANIM_JUMP := "Z_RunJumping_24/Anim_Z_RunJumping_24"
const ANIM_FALL := "Z_FallingCycle_24/Anim_Z_FallingCycle_24"
const ANIM_LAND := "Z_FallingLanding_24/Anim_Z_FallingLanding_24"

# ---------- FÍSICA ----------
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ---------- ESTADO CÁMARA ----------
var _cam_yaw   : float = 0.0
var _cam_pitch : float = 0.0

# ============================================================
#  STATE MACHINE
# ============================================================
enum State { IDLE, WALK, RUN, JUMP, FALL, LAND }

var current_state  : State = State.IDLE
var previous_state : State = State.IDLE
var land_timer     : float = 0.0
const LAND_DURATION : float = 0.4

# ============================================================
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Configurar SpringArm
	spring_arm.spring_length  = cam_distance
	spring_arm.position       = Vector3(shoulder_offset, 0.0, 0.0)
	spring_arm.collision_mask = 1
	spring_arm.margin         = 0.2

	# Pivot a altura del hombro
	cam_pivot.position = Vector3(0.0, cam_height, 0.0)

	# Cámara al final del SpringArm
	camera.position  = Vector3.ZERO
	camera.rotation  = Vector3.ZERO

	_setup_animations()
	_enter_state(State.IDLE)

# ---------- SETUP ANIMACIONES (stepped 24fps → efecto manga) ----------
func _setup_animations() -> void:
	var all_anims := [ANIM_IDLE, ANIM_WALK, ANIM_RUN, ANIM_JUMP, ANIM_FALL, ANIM_LAND]
	for anim_name in all_anims:
		if not anim_player.has_animation(anim_name):
			push_warning("Gensaku: animación no encontrada en setup → " + anim_name)
			continue
		var anim : Animation = anim_player.get_animation(anim_name)
		for track_idx in anim.get_track_count():
			anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)
			anim.track_set_interpolation_loop_wrap(track_idx, true)

# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw   -= event.relative.x * mouse_sensitivity
		_cam_pitch -= event.relative.y * mouse_sensitivity
		_cam_pitch  = clamp(_cam_pitch, deg_to_rad(cam_pitch_min), deg_to_rad(cam_pitch_max))
		cam_pivot.rotation.y = _cam_yaw
		cam_pivot.rotation.x = _cam_pitch

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ============================================================
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_update_state(delta)
	_handle_movement(delta)
	_update_fov()
	move_and_slide()

# ---------- GRAVEDAD ----------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * gravity_scale * delta

# ---------- MOVIMIENTO relativo a la cámara ----------
func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Dirección relativa al yaw de la cámara — ignora pitch para movimiento siempre horizontal
	var cam_basis := Basis(Vector3.UP, _cam_yaw)
	var direction := (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# Mesh rota hacia donde se mueve — Dark Souls style
	if direction != Vector3.ZERO:
		var target_angle := atan2(direction.x, direction.z)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_angle, rotation_smoothing * delta)

	var target_speed := 0.0
	match current_state:
		State.WALK:
			target_speed = walk_speed
		State.RUN:
			target_speed = run_speed
		State.JUMP, State.FALL, State.LAND:
			target_speed = run_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction != Vector3.ZERO:
		var accel := acceleration if is_on_floor() else acceleration * air_control
		velocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, accel * delta)
	else:
		var decel := deceleration if is_on_floor() else deceleration * air_control
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

# ---------- FOV DINÁMICO ----------
func _update_fov() -> void:
	var h_speed := Vector2(velocity.x, velocity.z).length()
	var t := clampf(h_speed / max(run_speed, 0.1), 0.0, 1.0)
	camera.fov = lerpf(fov_base, fov_max, t)

# ============================================================
#  STATE MACHINE — TRANSICIONES
# ============================================================
func _update_state(delta: float) -> void:
	var has_input    := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1
	var is_sprinting := Input.is_action_pressed("sprint")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var on_floor     := is_on_floor()

	match current_state:
		State.IDLE:
			if not on_floor:
				_enter_state(State.FALL)
			elif jump_pressed:
				_jump()
			elif has_input:
				_enter_state(State.RUN if is_sprinting else State.WALK)

		State.WALK:
			if not on_floor:
				_enter_state(State.FALL)
			elif jump_pressed:
				_jump()
			elif not has_input:
				_enter_state(State.IDLE)
			elif is_sprinting:
				_enter_state(State.RUN)

		State.RUN:
			if not on_floor:
				_enter_state(State.FALL)
			elif jump_pressed:
				_jump()
			elif not has_input:
				_enter_state(State.IDLE)
			elif not is_sprinting:
				_enter_state(State.WALK)

		State.JUMP:
			if velocity.y < 0.0:
				_enter_state(State.FALL)

		State.FALL:
			if on_floor:
				_enter_state(State.LAND)

		State.LAND:
			land_timer -= delta
			if land_timer <= 0.0:
				var has_input_now := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1
				_enter_state(State.RUN if (has_input_now and is_sprinting) else State.WALK if has_input_now else State.IDLE)

# ---------- SALTO ----------
func _jump() -> void:
	velocity.y = jump_force
	_enter_state(State.JUMP)

# ============================================================
#  STATE MACHINE — ANIMACIONES
# ============================================================
func _enter_state(new_state: State) -> void:
	previous_state = current_state
	current_state  = new_state

	match new_state:
		State.IDLE:
			_play(ANIM_IDLE, 0.2,  true,  1.0)
		State.WALK:
			_play(ANIM_WALK, 0.2,  true,  anim_walk_speed)
		State.RUN:
			_play(ANIM_RUN,  0.15, true,  anim_run_speed)
		State.JUMP:
			_play(ANIM_JUMP, 0.1,  false, 1.0)
		State.FALL:
			_play(ANIM_FALL, 0.2,  true,  1.0)
		State.LAND:
			land_timer = LAND_DURATION
			_play(ANIM_LAND, 0.1,  false, 1.0)

# ---------- HELPER ----------
func _play(anim_name: String, blend: float = 0.2, loop: bool = true, speed: float = 1.0) -> void:
	if not anim_player.has_animation(anim_name):
		push_warning("Gensaku: animación no encontrada → " + anim_name)
		return
	var anim : Animation = anim_player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim_player.speed_scale = speed
	anim_player.play(anim_name, blend)
