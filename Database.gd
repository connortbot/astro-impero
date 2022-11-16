extends Node #AUTOLOADED ON START as "Database"

############### SPACE TERMINALS ###############
## Created by Connor T. Loi ##

## Design Recipe for all functions ##

## (function) function purpose
# @param - param name: param value
# => USER: host or client, or both
# => RESULT: result or returned value of the function


############### MAIN AGENDA ###############
# Main focus is to make the host hold all info, and allow clients to query data as
# opposed to accessing their own.
# ====> Packets are recursive -> they cause methods that send packets back in an infinite loop
#========> This is applicable to all packets except the MOVE_SHIP one
############### MAIN AGENDA ###############


#### FULL FIRST RELEASE ####
#more accessible ui information (buffs, modifiers, hover windows)
#battle window debuffs and buffs icons

#### Further Updates ####
#high command
#troop exp
#space superiority
#stations (forts)
#ship upgrades


############### SPACE TERMINALS ###############



## Player Client-Specific Variables ##
var LOCAL_USERNAME = ""
var LOCAL_ID = 0

## Lobby Usernames ##
var USERNAMES = ["",""]

## PLANETS ##
var PLANETS = {
	"Botra": "",
	"Anaxes": ""
}

## PLAYERS ##
#ID: [username,metal,fuel,energy,active]
var PLAYERS = {
	0: ["",0,0,0,false],
	1: ["",0,0,0,false]
}

#Tracks movement and building queues (if it takes multiple turns)
#type, what turn it was started on
var PLAYER_QUEUE = {
	0: {},
	1: {}
}

#SOLAR ID: SIDE 1: {SHIPS:SHIPINFO}, SIDE 2: {SHIPS:SHIPINFO}
var BATTLE_QUEUE = {}
var evasion_rands = []

#PLANET ID: [all participating ship ids, [all garrison ids], TURN_STARTED
var LAND_QUEUE = {}

var global_id_counter = 0
var global_turn_counter = 0


var PRODUCTION_QUEUE = {
	0: {
		"slots": 0,
		"production": [], #[ship type, amount,spawn_solar]
		"active_production": [] #[ship type, turn started,spawn_solar,amount]
	},
	1: {
		"slots": 0,
		"production": [],
		"active_production": []
	}
}

var SUPPLY_SYSTEM = {
	0: {
		"QUOTA": 0,
		"SUPPLIER_SCORE": 0,
		"SUPPLY_LOSS": 0.0
	},
	1: {
		"QUOTA": 0,
		"SUPPLIER_SCORE": 0,
		"SUPPLY_LOSS": 0.0
	}
}

var GALACTIC_DATA = {
	#[SystemID][SystemName,Solar][Planet,Ships][Owner,Buildings]
	1: {
		101: {
			"Anaxes": {
				"Owner": "",
				"building_slots": 3
			},
			"Isaac": {
				"Owner": "",
				"building_slots": 1
			}
		},
		102: {},
		103: {},
		104: {},
		105: {}
	},
	2: {
		201: {},
		202: {},
		203: {
			"Hosharri": {
				"Owner": "",
				"building_slots": 2
			}
		},
		204: {},
		205: {}
	},
	3: {
		301: {},
		302: {},
		303: {},
		304: {},
		305: {}
	},
	4: {
		401: {
			"Botra": {
				"Owner": "",
				"building_slots": 4
			},
			"Yaowei": {
				"Owner": "",
				"building_slots": 2
			}
		},
		402: {},
		403: {},
		404: {},
		405: {
			"Ustoh": {
				"Owner": "",
				"building_slots": 1
			}
		}
	},
	5: {
		501: {},
		502: {
			"Sol": {
				"Owner": "",
				"building_slots": 1
			}
		},
		503: {},
		504: {
			"Fol": {
				"Owner": "",
				"building_slots": 1
			}
		},
		505: {
			"Iol": {
				"Owner": "",
				"building_slots": 1
			}
		}
	},
	6: {
		601: {},
		602: {},
		603: {},
		604: {},
		605: {
			"Autumn": {
				"Owner": "",
				"building_slots": 6
			}
		}
	},
	7: {
		701: {
			"Agumuun": {
				"Owner": "",
				"building_slots": 5
			}
		},
		702: {
			"Naivoh": {
				"Owner": "",
				"building_slots": 1
			}
		},
		703: {},
		704: {},
		705: {}
	},
	8: {
		801: {
			"Riga": {
				"Owner": "",
				"building_slots": 6
			},
			"Edavellir": {
				"Owner": "",
				"building_slots": 2
			}
		},
		802: {},
		803: {},
		804: {},
		805: {}
	},
	9: {
		901: {},
		902: {
			"Hestea": {
				"Owner": "",
				"building_slots": 2
			}
		},
		903: {},
		904: {},
		905: {}
	},
}

var SHIPS = {
	"DESTROYER": {
		"OWNER": 0,
		"CLASS": "ECC",
		
		"FUEL_USAGE": 60,
		"ENERGY_USAGE": 50,
		"REPAIR_METAL_USAGE": 10,
		
		"ATTACK": 10,
		"EVASION": 0.4,
		"ARMOR": 0.05,
		"HEALTH": 20,
		"MAX_HEALTH": 20,
		
		"RECENT_DAMAGE_OUTPUT": 0,
		"RECENT_TAKEN_DAMAGE": 0,
		
		"BATTALIONS": 3,
		"LEGIONS": 0,
		
		"PRESENCE": 5,
		
		"SPEED": 5,
		"MOVEABLE": true,
		
		"REQUIRED_STATIONS": 4,
		"REQUIRED_TURNS": 2,
	},
	"CRUISER": {
		"OWNER": 0,
		"CLASS": "ECC",
		
		"FUEL_USAGE": 100,
		"ENERGY_USAGE": 80,
		"REPAIR_METAL_USAGE": 15,
		
		"ATTACK": 10,
		"EVASION": 0.2,
		"ARMOR": 0.25,
		"HEALTH": 35,
		"MAX_HEALTH": 35,
		
		"RECENT_DAMAGE_OUTPUT": 0,
		"RECENT_TAKEN_DAMAGE": 0,
		
		"BATTALIONS": 5,
		"LEGIONS": 0,
		
		"PRESENCE": 8,
		
		"SPEED": 4,
		"MOVEABLE": true,
		
		"REQUIRED_STATIONS": 6,
		"REQUIRED_TURNS": 4,
	},
	"BATTLESHIP": {
		"OWNER": 0,
		"CLASS": "ECC",
		
		"FUEL_USAGE": 300,
		"ENERGY_USAGE": 220,
		"REPAIR_METAL_USAGE": 50,
		
		"ATTACK": 30,
		"EVASION": 0.05,
		"ARMOR": 0.4,
		"HEALTH": 150,
		"MAX_HEALTH": 150,
		
		"RECENT_DAMAGE_OUTPUT": 0,
		"RECENT_TAKEN_DAMAGE": 0,
		
		"BATTALIONS": 10,
		"LEGIONS": 1,
		
		"PRESENCE": 20,
		
		"SPEED": 3,
		"MOVEABLE": true,
		
		"REQUIRED_STATIONS": 12,
		"REQUIRED_TURNS": 6,
	},
	"DREADNOUGHT": {
		"OWNER": 0,
		"CLASS": "ECC",
		
		"FUEL_USAGE": 500,
		"ENERGY_USAGE": 325,
		"REPAIR_METAL_USAGE": 100,
		
		"ATTACK": 40,
		"EVASION": 0.0,
		"ARMOR": 0.7,
		"HEALTH": 200,
		"MAX_HEALTH": 200,
		
		"RECENT_DAMAGE_OUTPUT": 0,
		"RECENT_TAKEN_DAMAGE": 0,
		
		"BATTALIONS": 15,
		"LEGIONS": 2,
		
		"PRESENCE": 40,
		
		"SPEED": 2,
		"MOVEABLE": true,
		
		"REQUIRED_STATIONS": 15,
		"REQUIRED_TURNS": 8,
	}
}
var SUPPLIERS = {
	"FREIGHTER": {
		"OWNER": 0,
		"CLASS": "ESS",
		"REQUIRED_STATIONS": 1,
		"REQUIRED_TURNS": 3,
		
		"SUPPLIER_SCORE": 1000,
		"SUPPLY_LOSS_NEGATION": 0.0,
		"DEFENDER": false
	},
	"CONVOY": {
		"OWNER": 0,
		"CLASS": "ESS",
		"REQUIRED_STATIONS": 1,
		"REQUIRED_TURNS": 1,
		
		"SUPPLIER_SCORE": 200,
		"SUPPLY_LOSS_NEGATION": 0.0,
		"DEFENDER": false
	},
	"CORVETTE": {
		"OWNER": 0,
		"CLASS": "ESS",
		"REQUIRED_STATIONS": 2,
		"REQUIRED_TURNS": 3,
		
		"SUPPLIER_SCORE": 0,
		"SUPPLY_LOSS_NEGATION": 0.01,
		"DEFENDER": true
	},
	"FRIGATE": {
		"OWNER": 0,
		"CLASS": "ESS",
		"REQUIRED_STATIONS": 4,
		"REQUIRED_TURNS": 4,
		
		"SUPPLIER_SCORE": 0,
		"SUPPLY_LOSS_NEGATION": 0.025,
		"DEFENDER": true
	},
}

var BUILDINGS = {
	"FUEL_MINE": {
		"OWNER": 0,
		"PRODUCTION": 1200,
		"BUILD_TIME": 2
	},
	"METALS_MINE": {
		"OWNER": 0,
		"PRODUCTION": 100,
		"BUILD_TIME": 3
	},
	"ENERGY_MINE": {
		"OWNER": 0,
		"PRODUCTION": 800,
		"BUILD_TIME": 2
	},
	"GARRISON": {
		"OWNER": 0,
		"BATTALIONS": 5,
		"BUILD_TIME": 3
	},
	"MILITARY_STATION": {
		"OWNER": 0,
		"BUILD_TIME": 3
	}
}

var SYSTEM_SIBLINGS = {
	1: [2,7,8,9],
	2: [1,3,7,8],
	3: [2,4,8],
	4: [3,5,8],
	5: [4,6],
	6: [5,7,9],
	7: [1,2,6],
	8: [1,2,3,4,9],
	9: [1,6,8],
}


func save(savenum):
	var save_game = File.new()
	save_game.open("user://savegame"+str(savenum)+".save",File.WRITE)
	
	var save_data = {
		"PLAYERS": PLAYERS,
		"PLAYER_QUEUE": PLAYER_QUEUE,
		"BATTLE_QUEUE": BATTLE_QUEUE,
		"LAND_QUEUE": LAND_QUEUE,
		"global_id_counter": global_id_counter,
		"global_turn_counter": global_turn_counter,
		"PRODUCTION_QUEUE": PRODUCTION_QUEUE,
		"SUPPLY_SYSTEM": SUPPLY_SYSTEM,
		"GALACTIC_DATA": GALACTIC_DATA,
		"active_id": Network.active_id
	}
	print(Network.active_id)
	save_game.store_var(save_data)
	save_game.close()
func load_save(savenum):
	var save_game = File.new()
	if not save_game.file_exists("user://savegame"+str(savenum)+".save"):
		return
	save_game.open("user://savegame"+str(savenum)+".save",File.READ)
	var save_data = save_game.get_var()
	for property in save_data.keys():
		if property != "active_id":
			set(property,save_data[property])
		else:
			Network.active_id = save_data[property]
	save_game.close()
func delete_save(savenum):
	var dir = Directory.new()
	dir.remove("user://savegame"+str(savenum)+".save")

func reset():
	pass #replace with resetting everything to default values
