extends Spatial

export var data = {}
var solar = 0

func _ready() -> void:
	refresh_colour()

func refresh_colour():
	var side1health = 0
	var side2health = 0
	for side in data.keys():
		if side == Network.active_id: #our side
			for ship in data[side].keys():
				side1health += data[side][ship]["HEALTH"]
		else:
			for ship in data[side].keys():
				side2health += data[side][ship]["HEALTH"]
	if side1health > side2health:
		var mat = $Bubble.get_surface_material(0)
		mat.emission = Color(0,1,0)
	if side1health < side2health:
		var mat = $Bubble.get_surface_material(0)
		mat.emission = Color(1,0,0)

onready var map = get_parent()
func clicked():
	map = get_parent()
	map.battle_popup(data,solar)
