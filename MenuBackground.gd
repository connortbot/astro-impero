extends Spatial


func _physics_process(delta: float) -> void:
	$GalaxyPivot.rotate_y(0.001)
	$GalaxyPivot.rotate_x(0.0001)
	$GalaxyPivot.rotate_z(0.0001)
	 
func _ready() -> void:
	$AnimationPlayer.play("Cycle")
