@tool
extends MeshInstance3D

# ============================================================
#  GENSAKU — Manga Post-Process Controller v8.0
# ============================================================

@export_group("Blanco y Negro")
@export var ink_contrast : float = 1.6 :
	set(v): ink_contrast = v; _sp("ink_contrast", v)
@export var brightness   : float = 1.0 :
	set(v): brightness = v;   _sp("brightness", v)

@export_group("Bordes")
@export var edge_threshold     : float = 0.06 :
	set(v): edge_threshold = v;     _sp("edge_threshold", v)
@export var edge_thickness_min : float = 0.8  :
	set(v): edge_thickness_min = v; _sp("edge_thickness_min", v)
@export var edge_thickness_max : float = 2.6  :
	set(v): edge_thickness_max = v; _sp("edge_thickness_max", v)
@export var edge_var_scale     : float = 6.0  :
	set(v): edge_var_scale = v;     _sp("edge_var_scale", v)

@export_group("Protagonista")
@export var protagonist_color   : Color = Color(0.29, 0.56, 0.85, 1.0) :
	set(v): protagonist_color = v;   _sp("protagonist_color", v)
@export var color_hue_range     : float = 0.13 :
	set(v): color_hue_range = v;     _sp("color_hue_range", v)
@export var color_sat_threshold : float = 0.28 :
	set(v): color_sat_threshold = v; _sp("color_sat_threshold", v)
@export var color_preserve      : float = 0.88 :
	set(v): color_preserve = v;      _sp("color_preserve", v)

@export_group("Global")
@export var vignette_strength : float = 0.28 :
	set(v): vignette_strength = v; _sp("vignette_strength", v)

# ============================================================
var _mat : ShaderMaterial = null

func _ready() -> void:
	_mat = get_surface_override_material(0) as ShaderMaterial
	if _mat == null:
		push_warning("MangaController: no se encontró ShaderMaterial en surface 0")
		return
	_apply_all()
	_fit_to_screen()

func _process(_delta: float) -> void:
	_fit_to_screen()

func _sp(param: String, value: Variant) -> void:
	if _mat:
		_mat.set_shader_parameter(param, value)

func _apply_all() -> void:
	_sp("ink_contrast",        ink_contrast)
	_sp("brightness",          brightness)
	_sp("edge_threshold",      edge_threshold)
	_sp("edge_thickness_min",  edge_thickness_min)
	_sp("edge_thickness_max",  edge_thickness_max)
	_sp("edge_var_scale",      edge_var_scale)
	_sp("protagonist_color",   protagonist_color)
	_sp("color_hue_range",     color_hue_range)
	_sp("color_sat_threshold", color_sat_threshold)
	_sp("color_preserve",      color_preserve)
	_sp("vignette_strength",   vignette_strength)

func _fit_to_screen() -> void:
	var cam : Camera3D = get_parent() as Camera3D
	if cam == null:
		return
	var dist    : float    = abs(position.z)
	var fov_rad : float    = deg_to_rad(cam.fov)
	var vp_size : Vector2  = get_viewport().get_visible_rect().size
	var height  : float    = 2.0 * dist * tan(fov_rad * 0.5)
	var width   : float    = height * (vp_size.x / vp_size.y)
	var quad    : QuadMesh = mesh as QuadMesh
	if quad:
		quad.size = Vector2(width, height)
