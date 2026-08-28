class_name AIClient
extends Node

signal decision_received(decision: Dictionary)
signal request_failed(error_text: String)

@export var server_url := "http://127.0.0.1:8000"
@export var request_timeout_seconds := 8.0
var _http := HTTPRequest.new()

func _ready() -> void:
	add_child(_http)
	_http.timeout = request_timeout_seconds
	_http.request_completed.connect(_on_request_completed)

func request_decision(agent_state: Dictionary) -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		request_failed.emit("A previous request is still pending")
		return
	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := _http.request(server_url + "/decide", headers, HTTPClient.METHOD_POST, JSON.stringify(agent_state))
	if error != OK:
		request_failed.emit("Could not start HTTP request (%s)" % error)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("Server unavailable or request timed out")
		return
	if response_code < 200 or response_code >= 300:
		request_failed.emit("Server returned HTTP %s" % response_code)
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		request_failed.emit("Server returned invalid JSON")
		return
	decision_received.emit(json.data)
