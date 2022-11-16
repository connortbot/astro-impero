extends Control


var battledata = {}

func _ready() -> void:
	pass # Replace with function body.
var selected = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask == BUTTON_MASK_LEFT:
			selected = true
		else:
			selected = false

func _process(delta: float) -> void:
	if Input.is_action_pressed("escape"):
		visible = false
		for child in get_children():
			if child.name != "Textures":
				child.visible = false
	if selected and mouse_in:
		rect_global_position = lerp(rect_global_position,get_global_mouse_position(),25*delta)

var mouse_in = false
func _on_PopupWindow_mouse_entered() -> void:
	mouse_in = true


func _on_PopupWindow_mouse_exited() -> void:
	mouse_in = false

onready var shipbattleReading = load("res://Instances/ShipBattleReading.tscn")
func battle_intel(battleData,solar):
	visible = false
	get_node("../FadeIn/AnimationPlayer").play("PopupSwing")
	var NBM = $NavalBattleMode #navalbattlemode
	NBM.visible = true
	var total_health = [0,0]
	for child in $NavalBattleMode/FriendlySide/VBoxContainer.get_children():
		child.queue_free()
	for child in $NavalBattleMode/EnemySide/VBoxContainer.get_children():
		child.queue_free()
	for side in battleData.keys():
		for ship in battleData[side].keys():
			var newReading = shipbattleReading.instance()
			newReading.data = battleData[side][ship]
			newReading.solar = solar
			newReading.id = ship
			newReading.name = ship
			var ship_tags = ship.split("-")
			var ship_type = ship_tags[1]
			var ship_type_raw = ship_type
			ship_type = ship_type.replace("_"," ")
			newReading.get_node("HBoxContainer2/ShipName").text = battleData[side][ship]["CLASS"]+" "+ship_type
			var ship_max = battleData[side][ship]["MAX_HEALTH"]
			var current_health = battleData[side][ship]["HEALTH"]
			newReading.get_node("HBoxContainer/HealthBar/ProgressBar").value = 100*(current_health/ship_max)
			if battleData[side][ship]["OWNER"] == Network.active_id:
				newReading.get_node("HBoxContainer/Body").texture = load("res://GUI_Assets/Friendly.png")
				$NavalBattleMode/FriendlySide/VBoxContainer.add_child(newReading)
				total_health[0] += battleData[side][ship]["HEALTH"]
			else:
				newReading.get_node("HBoxContainer/Body").texture = load("res://GUI_Assets/Enemy.png")
				$NavalBattleMode/EnemySide/VBoxContainer.add_child(newReading)
				total_health[1] += battleData[side][ship]["HEALTH"]
	var h1 = float(total_health[0])
	var h2 = float(total_health[1])
	$NavalBattleMode/BalanceBar.value = 100*(h1/(h1+h2))
	
