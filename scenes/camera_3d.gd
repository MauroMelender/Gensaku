extends Camera3D

# Rutas corregidas que ya te funcionan
@onready var container = $"../../../SubViewportContainer"
@onready var sub_viewport = $"../../../SubViewportContainer/SubViewport"
@onready var camera_personaje = $"../../../SubViewportContainer/SubViewport/CameraPersonaje"
func _ready() -> void:
	# Eliminamos la línea conflictiva de find_world_3d()
	_adaptar_resolucion()
	get_tree().root.size_changed.connect(_adaptar_resolucion)
	

func _process(_delta: float) -> void:
	if is_instance_valid(camera_personaje):
		# Sincronización perfecta de la matriz global
		camera_personaje.global_transform = self.global_transform
		camera_personaje.fov = self.fov

func _adaptar_resolucion() -> void:
	if is_instance_valid(sub_viewport) and is_instance_valid(container):
		var pantalla_size = get_viewport().size
		container.size = pantalla_size
		sub_viewport.size = pantalla_size
