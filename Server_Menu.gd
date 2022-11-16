extends Control

var username: String
var matchID
onready var client = get_node("Client")

func _on_CreateButton_pressed() -> void:
	yield(client.create_match(),"completed")
	#get_tree().get_root().get_child(3).add_child(load("res://LobbyMenu.tscn").instance())
	#self.queue_free()
	$Window/MarginContainer/VBoxContainer/ID.text = "ID: '"+client.matchID+"'"
func _on_JoinButton_pressed() -> void:
	var join = client.join_match(matchID)



func _on_IDEntry_text_changed(new_text):
	matchID = new_text
func _on_UserEntry_text_changed(new_text):
	username = new_text
