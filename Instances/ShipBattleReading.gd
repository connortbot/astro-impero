extends Control

var data = {}
var solar = 0
var id = ""
func _ready() -> void:
	pass
	
onready var hoverwindow = get_parent().get_parent().get_parent().get_node("HoverWindow")

func _on_ShipBattleReading_mouse_entered() -> void:
	hoverwindow.visible = true
	var player_id
	for side in Database.BATTLE_QUEUE[solar].keys():
		for ship in Database.BATTLE_QUEUE[solar][side].keys():
			if ship == id:
				player_id = side
				break
	hoverwindow.get_node("VBoxContainer/Armor").text = "Armor: "+str(stepify(100*data["ARMOR"],0.1))+"%"
	hoverwindow.get_node("VBoxContainer/Health").text = "Health: "+str(stepify(Database.BATTLE_QUEUE[solar][player_id][id]["HEALTH"],0.1))
	hoverwindow.get_node("VBoxContainer/Evasion").text = "Evasion: "+str(stepify(100*data["EVASION"],0.1))+"%"
	hoverwindow.get_node("VBoxContainer/Dmg").text = "DMG: "+str(stepify(Database.BATTLE_QUEUE[solar][player_id][id]["RECENT_DAMAGE_OUTPUT"],0.1))
	hoverwindow.get_node("VBoxContainer/Loss").text = "Loss: "+str(stepify(Database.BATTLE_QUEUE[solar][player_id][id]["RECENT_TAKEN_DAMAGE"],0.1))


func _physics_process(delta: float) -> void:
	if hoverwindow.visible:
		hoverwindow.rect_global_position = get_global_mouse_position()


func _on_ShipBattleReading_mouse_exited() -> void:
	hoverwindow.visible = false
