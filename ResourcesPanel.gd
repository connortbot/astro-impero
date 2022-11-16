extends Control

#AUTOLOADED ON START as "ResourcesPanel"

var metals_cell
var fuel_cell
var energy_cell

#Gets the nodes that display amount
func get_cells():
	metals_cell = get_node("ResourcesButton/MetalsButton/MetalsAmount")
	fuel_cell = get_node("ResourcesButton/MetalsButton/FuelAmount")
	energy_cell = get_node("ResourcesButton/MetalsButton/EnergyAmount")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Network.connect("update_stats", self, "_update_stats")
	Network.connect("update_cells", self, "update_cell")

func update_cell(amount,type):
	amount = float(int(amount))
	get_cells()
	var cell
	if type == "metals":
		cell = metals_cell
	elif type == "fuel":
		cell = fuel_cell
	elif type == "energy":
		cell = energy_cell
	if amount > 999:
		amount = amount/1000.00
		amount = stepify(amount,0.01)
		cell.text = str(amount)+"K"
	else:
		cell.text = str(amount)

func _update_stats(id,amount,type):
	if type == "metals":
		update_metals(amount,id)
	elif type == "fuel":
		update_fuel(amount,id)
	elif type == "energy":
		update_energy(amount,id)


func update_metals(amount,id):
	Database.PLAYERS[id][1] += amount
	update_cell(Database.PLAYERS[id][1],"metals")
		
func update_fuel(amount,id):
	Database.PLAYERS[id][2] += amount
	update_cell(Database.PLAYERS[id][2],"fuel")

func update_energy(amount,id):
	Database.PLAYERS[id][3] += amount
	update_cell(Database.PLAYERS[id][3],"energy")

func update_panel():
	for child in get_node("IndustryButton/Datawindow/ScrollContainer/VBoxContainer").get_children():
		child.queue_free()
	$IndustryButton/StationAmount.text = str(Database.PRODUCTION_QUEUE[Network.active_id]["slots"])
	for product in Database.PRODUCTION_QUEUE[Network.active_id]["active_production"]:
		#[ship type, turn started,spawn_planet,amount]
		var newProdReading = load("res://Instances/ProductionQueueReading.tscn").instance()
		newProdReading.get_node("HBoxContainer/AmountLabel").text = "x"+str(product[3])
		var txt = ""
		if product[0] in Database.SHIPS.keys():
			txt = Database.SHIPS[product[0]]["CLASS"]+" "+product[0]
		elif product[0] in Database.SUPPLIERS.keys():
			txt = Database.SUPPLIERS[product[0]]["CLASS"]+" "+product[0]
		newProdReading.get_node("HBoxContainer/Body/MarginContainer/HBoxContainer/ShipName").text = txt
		if product[0] in Database.SHIPS.keys():
			newProdReading.get_node("HBoxContainer/PlanetLabel").text = "Spawns in "+product[2]+" in "+str(Database.SHIPS[product[0]]["REQUIRED_TURNS"]-(Database.global_turn_counter-product[1]) )+" turns..."
		elif product[0] in Database.SUPPLIERS.keys():
			newProdReading.get_node("HBoxContainer/PlanetLabel").text = "Spawns in "+product[2]+" in "+str(Database.SUPPLIERS[product[0]]["REQUIRED_TURNS"]-(Database.global_turn_counter-product[1]) )+" turns..."
		$IndustryButton/Datawindow/ScrollContainer/VBoxContainer.add_child(newProdReading)
func _on_IndustryButton_pressed() -> void:
	update_panel()
	for child in $ResourcesButton.get_children():
		child.visible = false
	for child in $IndustryButton.get_children():
		child.visible = true
	for child in $SupplyButton.get_children():
		child.visible = false

func _on_ResourcesButton_pressed() -> void:
	update_panel()
	for child in $IndustryButton.get_children():
		child.visible = false
	for child in $ResourcesButton.get_children():
		child.visible = true
	for child in $SupplyButton.get_children():
		child.visible = false


func _on_SupplyButton_pressed() -> void:
	update_supply_panel()
	for child in $IndustryButton.get_children():
		child.visible = false
	for child in $ResourcesButton.get_children():
		child.visible = false
	for child in $SupplyButton.get_children():
		child.visible = true

func update_supply_panel():
	var supplyoutput = 0.0 #supply score fulfillment
	supplyoutput = float(Database.SUPPLY_SYSTEM[Network.active_id]["SUPPLIER_SCORE"])/float(Database.SUPPLY_SYSTEM[Network.active_id]["QUOTA"])
	$SupplyButton/SupplyFulfillment.text = str(stepify(100*supplyoutput,0.01))+"%"
