extends Node

signal connection_succeeded(peer_id: int)
signal connection_failed()
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal server_disconnected()
signal lan_server_found(server_name: String, ip: String, port: int)
signal ezcha_lobby_created(join_code: String)
signal ezcha_lobby_joined()
signal ezcha_lobby_error(code: int, message: String)

enum ConnectionMode { NONE, HOST, CLIENT }

var mode: int = ConnectionMode.NONE
var host_port: int = 34197
var target_ip: String = "127.0.0.1"

var _lan_broadcaster: PacketPeerUDP = null
var _lan_listener: PacketPeerUDP = null
var _lan_listen_active: bool = false
var _lan_servers: Array[Dictionary] = []
var _lan_broadcast_timer: float = 0.0
var _lan_cleanup_timer: float = 0.0
const LAN_PORT: int = 34198
const LAN_MAGIC: String = "IOI_LAN"

var _ezcha_peer: EzchaRelayMultiplayerPeer = null
var _ezcha_hosting_in_progress: bool = false
var _ezcha_joining_in_progress: bool = false

var _eos_initialized: bool = false
var _eos_lobby: HLobby = null
var _eos_peer: EOSGMultiplayerPeer = null
var _eos_hosting_in_progress: bool = false
var _eos_joining_in_progress: bool = false
var _eos_join_code: String = ""

const EOS_SOCKET_ID: String = "ioip2p"
const EOS_BUCKET_ID: String = "ioi_online"
const EOS_JOIN_CODE_ATTR: String = "ioi_join_code"

func host(port: int = 34197) -> void:
	if mode != ConnectionMode.NONE:
		disconnect_from_server()

	_disconnect_multiplayer_signals()

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 8)
	if err != OK:
		push_error("NetworkManager: Failed to create server: ", err)
		connection_failed.emit()
		return

	multiplayer.multiplayer_peer = peer
	mode = ConnectionMode.HOST
	host_port = port

	_connect_multiplayer_signals()
	_start_lan_broadcast()
	connection_succeeded.emit(1)
	print("NetworkManager: Hosting on port ", port)

func join(ip: String, port: int = 34197) -> void:
	if mode != ConnectionMode.NONE:
		disconnect_from_server()

	_disconnect_multiplayer_signals()

	target_ip = ip
	host_port = port

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("NetworkManager: Failed to connect: ", err)
		connection_failed.emit()
		return

	multiplayer.multiplayer_peer = peer
	mode = ConnectionMode.CLIENT

	_connect_multiplayer_signals()
	_stop_lan_listen()
	print("NetworkManager: Connecting to ", ip, ":", port)

func host_via_ezcha(lobby_name: String = "", max_players: int = 8) -> void:
	if mode != ConnectionMode.NONE:
		disconnect_from_server()
	if _ezcha_hosting_in_progress or _ezcha_joining_in_progress:
		return

	if lobby_name.is_empty():
		lobby_name = GameManager.player_name + "'s Farm"

	_ezcha_hosting_in_progress = true
	_disconnect_multiplayer_signals()
	_do_host_via_ezcha(lobby_name, max_players)

func join_via_ezcha_code(join_code: String) -> void:
	if mode != ConnectionMode.NONE:
		disconnect_from_server()
	if _ezcha_hosting_in_progress or _ezcha_joining_in_progress:
		return

	if join_code.is_empty():
		return

	_ezcha_joining_in_progress = true
	_disconnect_multiplayer_signals()
	_do_join_via_ezcha_code(join_code)

func host_via_eos(lobby_name: String = "", max_players: int = 8) -> void:
	if mode != ConnectionMode.NONE:
		disconnect_from_server()
	if _eos_hosting_in_progress or _eos_joining_in_progress:
		return

	if lobby_name.is_empty():
		lobby_name = GameManager.player_name + "'s Farm"

	_eos_hosting_in_progress = true
	_disconnect_multiplayer_signals()
	_do_host_via_eos(lobby_name, max_players)

func join_via_eos_code(join_code: String) -> void:
	if mode != ConnectionMode.NONE:
		disconnect_from_server()
	if _eos_hosting_in_progress or _eos_joining_in_progress:
		return

	if join_code.is_empty():
		return

	_eos_joining_in_progress = true
	_disconnect_multiplayer_signals()
	_do_join_via_eos_code(join_code)

func disconnect_from_server() -> void:
	if mode == ConnectionMode.NONE:
		return
	_stop_lan_broadcast()
	_stop_lan_listen()
	_disconnect_multiplayer_signals()
	_ezcha_hosting_in_progress = false
	_ezcha_joining_in_progress = false
	_eos_hosting_in_progress = false
	_eos_joining_in_progress = false
	if _eos_lobby:
		if _eos_lobby.is_valid() and _eos_lobby.is_owner():
			_eos_lobby.destroy_async()
		elif _eos_lobby.is_valid():
			_eos_lobby.leave_async()
		_eos_lobby = null
	multiplayer.multiplayer_peer = null
	_eos_peer = null
	_ezcha_peer = null
	mode = ConnectionMode.NONE
	print("NetworkManager: Disconnected")

func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed_impl):
		multiplayer.connection_failed.connect(_on_connection_failed_impl)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _disconnect_multiplayer_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed_impl):
		multiplayer.connection_failed.disconnect(_on_connection_failed_impl)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)
	print("NetworkManager: Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)
	print("NetworkManager: Peer disconnected: ", id)

func _on_connected_to_server() -> void:
	var id := multiplayer.get_unique_id()
	connection_succeeded.emit(id)
	print("NetworkManager: Connected to server, peer ID: ", id)

func _on_connection_failed_impl() -> void:
	mode = ConnectionMode.NONE
	connection_failed.emit()
	print("NetworkManager: Connection failed")

func _on_server_disconnected() -> void:
	mode = ConnectionMode.NONE
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()
	print("NetworkManager: Server disconnected")

func is_host() -> bool:
	return mode == ConnectionMode.HOST

func is_client() -> bool:
	return mode == ConnectionMode.CLIENT

func is_network_active() -> bool:
	return mode != ConnectionMode.NONE

func start_lan_discovery() -> void:
	if _lan_listen_active:
		return
	_lan_servers.clear()
	_lan_listener = PacketPeerUDP.new()
	var err := _lan_listener.bind(LAN_PORT)
	if err != OK:
		push_error("NetworkManager: LAN listen bind failed: ", err)
		_lan_listener = null
		return
	_lan_listen_active = true
	_lan_listener.set_broadcast_enabled(true)
	print("NetworkManager: LAN discovery started")

func stop_lan_discovery() -> void:
	_stop_lan_listen()
	_lan_servers.clear()

func get_lan_servers() -> Array[Dictionary]:
	return _lan_servers.duplicate()

func _start_lan_broadcast() -> void:
	_stop_lan_broadcast()
	_lan_broadcaster = PacketPeerUDP.new()
	_lan_broadcaster.set_broadcast_enabled(true)
	_lan_broadcast_timer = 0.0

func _stop_lan_broadcast() -> void:
	if _lan_broadcaster:
		_lan_broadcaster.close()
		_lan_broadcaster = null

func _stop_lan_listen() -> void:
	_lan_listen_active = false
	if _lan_listener:
		_lan_listener.close()
		_lan_listener = null

func _process(delta: float) -> void:
	# Host: broadcast LAN beacon every 2 seconds
	if _lan_broadcaster:
		_lan_broadcast_timer += delta
		if _lan_broadcast_timer >= 2.0:
			_lan_broadcast_timer = 0.0
			var beacon := LAN_MAGIC + "|" + str(host_port) + "|" + GameManager.player_name
			var packet := beacon.to_utf8_buffer()
			_lan_broadcaster.set_dest_address("255.255.255.255", LAN_PORT)
			_lan_broadcaster.put_packet(packet)

	# Client: listen for LAN beacons
	if _lan_listen_active and _lan_listener:
		while _lan_listener.get_available_packet_count() > 0:
			var sender_ip: String = _lan_listener.get_packet_ip()
			var raw: PackedByteArray = _lan_listener.get_packet()
			var text: String = raw.get_string_from_utf8()
			if not text.begins_with(LAN_MAGIC):
				continue
			var parts := text.split("|")
			if parts.size() < 3:
				continue
			var port: int = parts[1].to_int()
			var srv_name: String = parts[2]
			# Avoid duplicates
			var found := false
			for existing in _lan_servers:
				if existing.ip == sender_ip and existing.port == port:
					found = true
					break
			if not found:
				var entry := {"name": srv_name, "ip": sender_ip, "port": port}
				_lan_servers.append(entry)
				lan_server_found.emit(srv_name, sender_ip, port)
				print("NetworkManager: LAN server found: ", srv_name, " at ", sender_ip, ":", port)

		# Clean up stale servers (no beacon for 8+ seconds)
		_lan_cleanup_timer += delta
		if _lan_cleanup_timer >= 4.0:
			_lan_cleanup_timer = 0.0

func _ezcha_available() -> bool:
	if not has_node("/root/Ezcha"):
		push_error("NetworkManager: Ezcha plugin not available")
		return false
	var game_id: String = Ezcha.get_game_id()
	if game_id.is_empty():
		push_error("NetworkManager: Ezcha game_id not configured (Project Settings > ezcha_network)")
		return false
	return true

func _do_host_via_ezcha(lobby_name: String, max_players: int) -> void:
	if not _ezcha_available():
		_ezcha_hosting_in_progress = false
		connection_failed.emit()
		return

	print("NetworkManager: Ezcha hosting lobby: ", lobby_name)

	var auth_ok := await Ezcha.client.authenticate()
	if not auth_ok:
		push_error("NetworkManager: Ezcha authentication failed")
		_ezcha_hosting_in_progress = false
		connection_failed.emit()
		return

	print("NetworkManager: Ezcha authenticated as ", Ezcha.client.user.username)

	var server := await Ezcha.client.determine_relay_server()
	if server == null:
		push_error("NetworkManager: No Ezcha relay servers available")
		_ezcha_hosting_in_progress = false
		connection_failed.emit()
		return

	print("NetworkManager: Using relay server: ", server.name, " (", server.region, ")")

	_ezcha_peer = EzchaRelayMultiplayerPeer.new()
	_ezcha_peer.lobby_created.connect(_on_ezcha_lobby_created)
	_ezcha_peer.error.connect(_on_ezcha_error)
	_ezcha_peer.lobby_connected.connect(_on_ezcha_lobby_connected)

	_ezcha_peer.create_lobby(server, lobby_name, max_players, 0, EzchaRelayMultiplayerPeer.Visibility.PUBLIC, true)

func _do_join_via_ezcha_code(join_code: String) -> void:
	if not _ezcha_available():
		_ezcha_joining_in_progress = false
		connection_failed.emit()
		return

	print("NetworkManager: Ezcha joining lobby: ", join_code)

	_ezcha_peer = EzchaRelayMultiplayerPeer.new()
	_ezcha_peer.lobby_joined.connect(_on_ezcha_lobby_joined)
	_ezcha_peer.error.connect(_on_ezcha_error)
	_ezcha_peer.lobby_connected.connect(_on_ezcha_lobby_connected)

	_ezcha_peer.resolve_lobby(join_code)

func _on_ezcha_lobby_connected() -> void:
	print("NetworkManager: Ezcha relay connected")

func _on_ezcha_lobby_created() -> void:
	print("NetworkManager: Ezcha lobby created, join code: ", _ezcha_peer.get_join_code())
	_connect_ezcha_user_signals()
	multiplayer.multiplayer_peer = _ezcha_peer
	mode = ConnectionMode.HOST
	_connect_multiplayer_signals()
	_ezcha_hosting_in_progress = false
	ezcha_lobby_created.emit(_ezcha_peer.get_join_code())
	connection_succeeded.emit(1)

func _on_ezcha_lobby_joined() -> void:
	print("NetworkManager: Ezcha lobby joined")
	_connect_ezcha_user_signals()
	multiplayer.multiplayer_peer = _ezcha_peer
	mode = ConnectionMode.CLIENT
	_connect_multiplayer_signals()
	_ezcha_joining_in_progress = false
	ezcha_lobby_joined.emit()
	connection_succeeded.emit(multiplayer.get_unique_id())

func _connect_ezcha_user_signals() -> void:
	if _ezcha_peer == null:
		return
	if not _ezcha_peer.user_connected.is_connected(_on_ezcha_user_connected):
		_ezcha_peer.user_connected.connect(_on_ezcha_user_connected)
	if not _ezcha_peer.user_disconnected.is_connected(_on_ezcha_user_disconnected):
		_ezcha_peer.user_disconnected.connect(_on_ezcha_user_disconnected)

func _on_ezcha_user_connected(peer_id: int, user: EzchaUser) -> void:
	print("NetworkManager: Ezcha user connected: ", peer_id, " (", user.username, ")")
	peer_connected.emit(peer_id)

func _on_ezcha_user_disconnected(peer_id: int, user: EzchaUser) -> void:
	print("NetworkManager: Ezcha user disconnected: ", peer_id, " (", user.username, ")")
	peer_disconnected.emit(peer_id)

func _on_ezcha_error(code: int, message: String) -> void:
	push_error("NetworkManager: Ezcha error: ", message, " (", code, ")")
	ezcha_lobby_error.emit(code, message)
	_ezcha_hosting_in_progress = false
	_ezcha_joining_in_progress = false
	if mode == ConnectionMode.NONE:
		connection_failed.emit()

func _eos_fail(message: String) -> void:
	push_error("NetworkManager: EOS error: ", message)
	ezcha_lobby_error.emit(-1, message)
	_eos_hosting_in_progress = false
	_eos_joining_in_progress = false
	if mode == ConnectionMode.NONE:
		connection_failed.emit()

func _ensure_eos_ready() -> bool:
	if _eos_initialized and not HAuth.product_user_id.is_empty():
		return true
	var creds := HCredentials.new()
	creds.product_name = "Isles of Inconstance"
	creds.product_version = "1.0"
	creds.product_id = "27b7bb7d5b124764a643713e339172fa"
	creds.sandbox_id = "2a3ed2f024084b84b4fccdb50f39185f"
	creds.deployment_id = "13fa672371f7485b8fb1322c2e79b9ee"
	creds.client_id = "xyza7891W6xu1SzEYyYS2McY9kwbAVI3"
	creds.client_secret = "Tl8StjTblzjYmWBtu/aQm/wx0qkdClAvxuORp1NIEUE"
	var setup_ok: bool = await HPlatform.setup_eos_async(creds)
	if not setup_ok:
		_eos_fail("EOS setup failed")
		return false
	_eos_initialized = true
	if HAuth.product_user_id.is_empty():
		var login_ok: bool = await HAuth.login_anonymous_async(GameManager.player_name)
		if not login_ok:
			_eos_fail("EOS login failed")
			return false
	print("NetworkManager: EOS ready, user id: ", HAuth.product_user_id)
	HP2P.set_relay_control(EOS.P2P.RelayControl.ForceRelays)
	return true

func _generate_join_code() -> String:
	const pool := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := ""
	for i in 6:
		code += pool[rng.randi_range(0, pool.length() - 1)]
	return code

func _do_host_via_eos(lobby_name: String, max_players: int) -> void:
	if not await _ensure_eos_ready():
		return
	print("NetworkManager: EOS hosting lobby: ", lobby_name)

	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.local_user_id = HAuth.product_user_id
	opts.max_lobby_members = max_players
	opts.bucket_id = EOS_BUCKET_ID
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.enable_join_by_id = true
	var lobby: HLobby = await HLobbies.create_lobby_async(opts)
	if lobby == null:
		_eos_fail("Failed to create lobby")
		return

	_eos_join_code = _generate_join_code()
	lobby.add_attribute(EOS_JOIN_CODE_ATTR, _eos_join_code)
	var update_ok: bool = await lobby.update_async()
	if not update_ok:
		_eos_fail("Failed to set lobby join code")
		return
	_eos_lobby = lobby
	print("NetworkManager: EOS lobby created: ", lobby.lobby_id, " code: ", _eos_join_code)

	_eos_peer = EOSGMultiplayerPeer.new()
	_eos_peer.set_is_polling(true)
	_eos_peer.set_auto_accept_connection_requests(true)
	var server_err := _eos_peer.create_server(EOS_SOCKET_ID)
	if server_err != OK:
		_eos_fail("Failed to create EOS P2P server: " + str(server_err))
		return

	multiplayer.multiplayer_peer = _eos_peer
	mode = ConnectionMode.HOST
	_connect_multiplayer_signals()
	_eos_hosting_in_progress = false
	ezcha_lobby_created.emit(_eos_join_code)
	connection_succeeded.emit(1)
	print("NetworkManager: EOS hosting started")

func _do_join_via_eos_code(join_code: String) -> void:
	if not await _ensure_eos_ready():
		return
	print("NetworkManager: EOS searching lobby for code: ", join_code)

	var search_opts := EOS.Lobby.CreateLobbySearchOptions.new()
	search_opts.max_results = 25
	var search: EOSGLobbySearch = HLobbies.create_search(search_opts)
	if search == null:
		_eos_fail("Failed to create lobby search")
		return
	search.set_parameter(EOS.Lobby.SEARCH_BUCKET_ID, EOS_BUCKET_ID, EOS.ComparisonOp.Equal)
	search.set_parameter(EOS_JOIN_CODE_ATTR, join_code, EOS.ComparisonOp.Equal)
	var results: Array = await HLobbies.search_async(search)
	if results == null:
		_eos_fail("Lobby search failed")
		return
	if results.is_empty():
		_eos_fail("No lobby found for join code")
		return

	var lobby: HLobby = null
	for candidate in results:
		print("NetworkManager: EOS search result lobby: ", candidate.lobby_id, " owner=", candidate.owner_product_user_id)
		if lobby == null:
			var attr: Dictionary = {}
			for a in candidate.attributes:
				if String(a.get("key", "")).to_lower() == EOS_JOIN_CODE_ATTR.to_lower():
					attr = a
					break
			if String(attr.get("value", "")) == join_code:
				lobby = candidate
	if lobby == null:
		_eos_fail("No lobby found for join code")
		return

	var host_id: String = lobby.owner_product_user_id
	if host_id.is_empty():
		_eos_fail("Lobby owner not found")
		return
	print("NetworkManager: EOS found lobby, host: ", host_id)

	_eos_peer = EOSGMultiplayerPeer.new()
	_eos_peer.set_is_polling(true)
	var client_err := _eos_peer.create_client(EOS_SOCKET_ID, host_id)
	if client_err != OK:
		_eos_fail("Failed to create EOS P2P client: " + str(client_err))
		return

	multiplayer.multiplayer_peer = _eos_peer
	mode = ConnectionMode.CLIENT
	_connect_multiplayer_signals()
	_eos_joining_in_progress = false
	print("NetworkManager: EOS connecting to host")
