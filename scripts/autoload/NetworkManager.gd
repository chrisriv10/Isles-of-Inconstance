extends Node

signal connection_succeeded(peer_id: int)
signal connection_failed()
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal server_disconnected()

enum ConnectionMode { NONE, HOST, CLIENT }

var mode: int = ConnectionMode.NONE
var host_port: int = 34197
var target_ip: String = "127.0.0.1"

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
	print("NetworkManager: Connecting to ", ip, ":", port)

func disconnect_from_server() -> void:
	if mode == ConnectionMode.NONE:
		return
	_disconnect_multiplayer_signals()
	multiplayer.multiplayer_peer = null
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
