extends Control

onready var hoverwindow = get_parent().get_parent().get_parent().get_parent().get_node("HoverWindow")

var planetdata = []


func _on_PlanetReading_mouse_entered() -> void:
	hoverwindow.visible = true
	var garrisons = planetdata[6]
	var metals = planetdata[2]
	var energy = planetdata[4]
	var fuel = planetdata[3]
	var station = planetdata[5]
	hoverwindow.get_node("VBoxContainer/Hover1").text = "Garrisons: "+str(garrisons)
	hoverwindow.get_node("VBoxContainer/Hover2").text = "Metal Mines: "+str(metals)
	hoverwindow.get_node("VBoxContainer/Hover3").text = "Energy Mines: "+str(energy)
	hoverwindow.get_node("VBoxContainer/Hover4").text = "Fuel Mines: "+str(fuel)
	hoverwindow.get_node("VBoxContainer/Hover5").text = "Stations: "+str(station)

func _physics_process(delta: float) -> void:
	if hoverwindow.visible:
		hoverwindow.rect_global_position = get_global_mouse_position()

func _on_PlanetReading_mouse_exited() -> void:
	hoverwindow.visible = false
