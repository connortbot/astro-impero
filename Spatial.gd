extends Spatial

var snappos = Vector3(0,0,0)
var zoom = 0
var y_rot = 0
var x_rot = 0
var newzoom = 30

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("up_arrow"):
		zoom -= 0.5
		zoom = clamp(zoom,-8,30)
		newzoom = 10+zoom
	if Input.is_action_pressed("down_arrow"):
		zoom += 0.5
		zoom = clamp(zoom,-8,30)
		newzoom = 10+zoom
	if Input.is_action_just_released("mouse"):
		clicked = false
		x_rot = 0
		y_rot = 0
	$InnerGimbal.rotation_degrees.x = lerp($InnerGimbal.rotation_degrees.x,$InnerGimbal.rotation_degrees.x+x_rot,panspeed*delta)
	rotation_degrees.y = lerp(rotation_degrees.y,rotation_degrees.y+y_rot,panspeed*delta)
	translation = lerp(translation,snappos,10*delta)
	$InnerGimbal/Camera.translation.z = lerp($InnerGimbal/Camera.translation.z,newzoom,zoomspeed*delta)

var clicked = false
var ray_length = 1000

func zoom(value):
	zoom = 0
	newzoom = value

var panspeed = 2.0
var zoomspeed = 3.0

var sector_list = []
var planet_list = []
var battle_list = []
func _unhandled_input(event: InputEvent) -> void:
	#Mac Support
	if event is InputEventPanGesture:
		y_rot = event.delta.x*15.0
		x_rot = event.delta.y*15.0
		get_parent().release_console_focus()
	#Mouse Support
	if event is InputEventMouseButton:
		get_parent().release_console_focus()
		if event.button_mask == BUTTON_LEFT:
			if event.pressed:
				clicked = true
		if event.button_mask == BUTTON_WHEEL_DOWN:
			zoom += 0.5
		if event.button_mask == BUTTON_WHEEL_UP:
			zoom -= 0.5
	if event is InputEventMouseMotion:
		if clicked:
			y_rot = event.relative.x*(panspeed)
			x_rot = event.relative.y*(panspeed)
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		get_parent().release_console_focus()
		var sectorhit = {}
		var planethit = {}
		var battlehit = {}
		var camera = $InnerGimbal/Camera
		### Sector Ray ###
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * ray_length
		var space_state = get_world().get_direct_space_state()
		sectorhit = space_state.intersect_ray(from,to,planet_list,2147483647,true,true)
		### Planetary Ray
		from = camera.project_ray_origin(event.position)
		to = from + camera.project_ray_normal(event.position) * ray_length
		space_state = get_world().get_direct_space_state()
		planethit = space_state.intersect_ray(from,to,sector_list,2147483647,true,true)
		### Battle Ray
		from = camera.project_ray_origin(event.position)
		to = from + camera.project_ray_normal(event.position) * ray_length
		space_state = get_world().get_direct_space_state()
		battlehit = space_state.intersect_ray(from,to,planet_list+sector_list,2147483647,true,true)
		if not battlehit.empty():
			battlehit["collider"].get_parent().get_parent().clicked()
		if not planethit.empty() and battlehit.empty():
			var planetname = planethit["collider"].get_parent().name
			get_parent().planet_name(planetname)
			planethit["collider"].get_parent().area_input()
		if planethit.empty() and battlehit.empty() and not sectorhit.empty():
				var sectorid = sectorhit["collider"].get_parent().name.replace("Sector","")
				get_parent().window(sectorid)
				sectorhit["collider"].get_parent().area_input()
func _ready() -> void:
	sector_list = []
	planet_list = []
	battle_list = []
	for child in get_node("../Galaxy").get_children():
		if child.name != "GalaxyModel" and child.name != "BlackHole":
			if "Sector" in child.name:
				sector_list.append(child.get_child(0).get_child(0))
			elif "BATTLE" in child.name:
				battle_list.append(child.get_child(0).get_child(0))
			else:
				planet_list.append(child.get_child(0))
				
