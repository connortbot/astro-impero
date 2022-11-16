extends Control

#AUTOLOADED ON START as "InventoryManager"



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Network.connect("add_client_building", self, "add_building")
	Network.connect("add_new_ship", self, "add_ship")
	Network.connect("add_new_supplier",self,"add_supplier")


#### ADDING OBJECTS ####
# Args [player's id that is getting the new object, type (e.g what kind of ship) and where they're putting it]
func add_building(playerid,type,planetname):
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			for planet in Database.GALACTIC_DATA[system][solar].keys():
				if planet == planetname:
					var building_id = "BUILDING-"+type+"-"+str(Database.global_id_counter)
					Database.GALACTIC_DATA[system][solar][planet][building_id] = Database.BUILDINGS[type].duplicate()
					Database.GALACTIC_DATA[system][solar][planet][building_id]["OWNER"] = playerid
					Database.global_id_counter += 1

func add_ship(playerid,type,solar_id):
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			if solar == solar_id:
				var ship_id = "SHIP-"+type+"-"+str(Database.global_id_counter)
				Database.GALACTIC_DATA[system][solar][ship_id] = Database.SHIPS[type].duplicate()
				Database.GALACTIC_DATA[system][solar][ship_id]["OWNER"] = playerid
				Database.global_id_counter += 1

func add_supplier(playerid,type,supplyhub_id):
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			if solar == supplyhub_id:
				var supplier_id = "SUPPLIER-"+type+"-"+str(Database.global_id_counter)
				Database.GALACTIC_DATA[system][solar][supplier_id] = Database.SUPPLIERS[type].duplicate()
				Database.GALACTIC_DATA[system][solar][supplier_id]["OWNER"] = playerid
				Database.global_id_counter += 1

func move_ship(start,destination,ship_id,packeted):
	var cache = ["",{}] #shipid, ship data
	var found_ship = false
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			if solar == start:
				for object in Database.GALACTIC_DATA[system][solar].keys():
					var object_tags = object.split("-")
					if object_tags[0] == "SHIP":
						if object == ship_id:
							cache[0] = object
							cache[1] = Database.GALACTIC_DATA[system][solar][object].duplicate()
							Database.GALACTIC_DATA[system][solar].erase(object)
							found_ship = true
	if found_ship:
		for system in Database.GALACTIC_DATA.keys():
			for solar in Database.GALACTIC_DATA[system].keys():
				if solar == destination:
					Database.GALACTIC_DATA[system][solar][cache[0]] = cache[1]
					Database.GALACTIC_DATA[system][solar][cache[0]]["MOVEABLE"] = false
					if not packeted:
						ship_id = ship_id.replace("-","/")
						Network.packets.append("MOVE_SHIP-"+str(start)+"-"+str(destination)+"-"+str(ship_id))
						print("PACKET APPEND: MOVE_SHIP")
					return
	
func remove_ship(shipID):
	for system in Database.GALACTIC_DATA.keys():
		for solar in Database.GALACTIC_DATA[system].keys():
			for object in Database.GALACTIC_DATA[system][solar].keys():
				if object == shipID:
					var objecttags = object.split("-")
					var shipOwner = Database.GALACTIC_DATA[system][solar][shipID]["OWNER"]
					Database.GALACTIC_DATA[system][solar].erase(shipID)
					Network.emit_signal("log_update",objecttags[1]+" destroyed in the battle of Sector "+str(solar)+"!")
					return
func change_planet_owner(system,solar,planetname,username):
	Database.GALACTIC_DATA[system][solar][planetname]["Owner"] = username
