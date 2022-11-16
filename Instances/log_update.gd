extends HBoxContainer




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func log_update(text):
	var label = get_node("Update")
	label.text = "     "+text
