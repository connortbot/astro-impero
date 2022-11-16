extends Control

onready var hoverwindow = get_parent().get_parent().get_parent().get_parent().get_node("HoverWindow")
var shipdata = [] #after ready: [ship_Type,owned,class,ship_id]
func _on_ShipReading_mouse_entered() -> void:
	hoverwindow.visible = true
	var current_data
	var s = 0
	var s2 = 0
	for sys in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[sys].keys():
			for object in Database.GALACTIC_DATA[sys][solar].keys():
				if object == shipdata[3]:
					s = sys
					s2 = solar
					current_data = Database.GALACTIC_DATA[sys][solar][object]
	if shipdata[0] in Database.SHIPS:
		hoverwindow.get_node("VBoxContainer/Hover1").text = "Attack: "+str(Database.GALACTIC_DATA[s][s2][shipdata[3]]["ATTACK"])
		hoverwindow.get_node("VBoxContainer/Hover2").text = "Evasion: "+str(Database.GALACTIC_DATA[s][s2][shipdata[3]]["EVASION"]*100)+"%"
		hoverwindow.get_node("VBoxContainer/Hover3").text = "Armor: "+str(Database.GALACTIC_DATA[s][s2][shipdata[3]]["ARMOR"]*100)+"%"
		hoverwindow.get_node("VBoxContainer/Hover4").text = "Max Health: "+str(stepify(Database.GALACTIC_DATA[s][s2][shipdata[3]]["MAX_HEALTH"],1))
		hoverwindow.get_node("VBoxContainer/Hover5").text = "Speed: "+str(Database.GALACTIC_DATA[s][s2][shipdata[3]]["SPEED"])
	elif shipdata[0] in Database.SUPPLIERS:
		hoverwindow.get_node("VBoxContainer/Hover1").text = "Score: "+str(Database.SUPPLIERS[shipdata[0]]["SUPPLIER_SCORE"])
		hoverwindow.get_node("VBoxContainer/Hover2").text = "Negation: "+str(Database.SUPPLIERS[shipdata[0]]["SUPPLY_LOSS_NEGATION"]*100)+"%"
		hoverwindow.get_node("VBoxContainer/Hover3").text = "-----"
		hoverwindow.get_node("VBoxContainer/Hover4").text = "-----"
		hoverwindow.get_node("VBoxContainer/Hover5").text = "-----"

func _physics_process(delta: float) -> void:
	if hoverwindow.visible:
		hoverwindow.rect_global_position = get_global_mouse_position()

func _on_ShipReading_mouse_exited() -> void:
	hoverwindow.visible = false

func _ready() -> void:
	shipdata.append(shipdata[0])
	var s = shipdata[0].split("-")
	shipdata[0] = s[1]
