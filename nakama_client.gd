extends Node
#https://heroiclabs.com/docs/nakama/concepts/multiplayer/relayed/

# Hosted on Digital Ocean, a Nakama Droplet
# PW: ZFGFNM092304<3C

var client : NakamaClient
var socket
var session : NakamaSession

var testing_locally = true
# when set to false, will execute normally
# when set to true, uses session ids instread of player ids

# Get device id
var device_id = OS.get_unique_id()

# Session variables
var session_token

func _ready():
	# Defining the Client
	client = Nakama.create_client("defaultkey","142.93.154.142",7350,"http")
	client.timeout = 500
	
	# Device Authentication, and creating Session
	session = yield(client.authenticate_device_async(device_id), "completed")
	if session.is_exception():
		print("An error occurred: %s" % session)
		return
	print("Successfully authenticated: %s" % session)
	session_token = session.token
	print(session.expire_time)
	# Defining socket
	socket = Nakama.create_socket_from(client)
	var connected : NakamaAsyncResult = yield(socket.connect_async(session),"completed")
	if connected.is_exception():
		print("An error occured: %s" % connected)
		return
	print("Socket connected.")
	socket.connect("received_match_presence", self, "_on_match_presence")
	socket.connect("received_match_state",self,"_on_match_state")

# Session Functions
func refresh_session():
	session = NakamaClient.restore_session(session_token)
func logout_session():
	yield(client.session_logout_async(session),"completed")

### Matching Functions ###
# Match Variables
var connected_opponents = {}
var created_match : NakamaRTAPI.Match
var matchID: String
func create_match():
	created_match = yield(socket.create_match_async(),"completed")
	if created_match.is_exception():
		print("An error occurred: %s" % created_match)
		return
	matchID = created_match.match_id
func join_match(match_ID): #you have to join with the above match_id variable
	var joined_match = yield(socket.join_match_async(match_ID),"completed")
	if joined_match.is_exception():
		print("An error occurred: %s" % joined_match)
		return 'ERR'
	for presence in joined_match.presences:
		print("User id %s name %s'." % [presence.user_id,presence.username])
	matchID = match_ID
func send_match_state(data,op_code): #sends data in dict form, converts to json and sends
	print("Sending match state with op code "+str(op_code))
	socket.send_match_state_async(matchID,op_code,JSON.print(data))
	
	
#Receiving Match States
signal received_p2_username
signal received_usernames_from_host
signal client_planet_selection(planetname,username)
signal update_planetslist
signal log_update(text)

## (_on_match_state) Responses to op_code match state messages.
# @param - p_state: Nakama Real Time API match state data
# => USER: host/user
# => RESULT: varies
func _on_match_state(p_state: NakamaRTAPI.MatchData):
	var data = parse_json(p_state.data)
	print("Received match state with opcode %s, data %s" % [p_state.op_code, parse_json(p_state.data)])
	if p_state.op_code == 1:
		if Database.LOCAL_ID == 0:
			Database.USERNAMES[1] = data["LOCAL_USERNAME"]
			emit_signal("received_p2_username")
	if p_state.op_code == 2:
		if Database.LOCAL_ID == 1:
			Database.USERNAMES = data
			emit_signal("received_usernames_from_host")
	if p_state.op_code == 3:
		if Database.LOCAL_ID == 1:
			Database.PLANETS = data
			emit_signal("update_planetslist",Database.PLANETS)
	if p_state.op_code == 4:
		if Database.LOCAL_ID == 0:
			emit_signal("client_planet_selection",data["PLANET"],data["USERNAME"])
	if p_state.op_code == 5:
		if Database.LOCAL_ID == 1:
			Database.PLAYERS[0][0] = Database.USERNAMES[0]
			Database.PLAYERS[1][0] = Database.USERNAMES[1]
			Network.start_loading_game()
	
	### OP CODE 6 ###
	# CALLED BY => client
	# PURPOSE => Starts next turn cycle on host
	if p_state.op_code == 6:
		if Database.LOCAL_ID == 0:
			Network.next_player(int(data["SENDER_ID"]))
	if p_state.op_code == 7:
		if data["SENDER_ID"] != Database.LOCAL_ID:
			emit_signal("log_update",data["MESSAGE"])
	if p_state.op_code == 8:
		Network.active_id = int(data["ACTIVE_ID"])
		if data["ACTIVE_ID"] != Database.LOCAL_ID:
			get_tree().get_root().get_child(6).deactivate_console()
		else:
			get_tree().get_root().get_child(6).activate_console()
	if p_state.op_code == 9:
		Database.evasion_rands = data["EVASION_RANDS"]
	if p_state.op_code == 10:
		if Database.LOCAL_ID == 1:
			Network.deterministicTurnUpdate()
	
	### OP CODE 11 ###
	# CALLED BY => host/client
	# PURPOSE => Updates minor changes from the other presence
	if p_state.op_code == 11: 
		if Database.LOCAL_ID != data["SENDER_ID"]:
			Network.parse_packet(data["HASH"])
func leave_match():
	var leave : NakamaAsyncResult = yield(socket.leave_match_async(matchID), "completed")
	if leave.is_exception():
		print("An error occurred: %s" % leave)
		return
	print("Match left")
## OP CODES ##
#1: Send Local Username
#2: Send Usernames Dict
#3: Planet Selection Dict (Host to Client)
#4: Planet Selection (Client to Host)
#5: Load Game
#6: Match Data
#7: Log Update
#8: Deactivate console of non-active player
###############
# On a change in match presence (leave or join)
signal changed_match_presence(connected_opponents)
func _on_match_presence(p_presence : NakamaRTAPI.MatchPresenceEvent):
	for p in p_presence.joins:
		if not testing_locally:
			connected_opponents[p.user_id] = p
		else:
			connected_opponents[p.session_id] = p
	for p in p_presence.leaves:
		if not testing_locally:
			connected_opponents.erase(p.user_id)
		else:
			connected_opponents.erase(p.session_id)
	print("Connected opponents: %s" % [connected_opponents])
	emit_signal("changed_match_presence",connected_opponents)
