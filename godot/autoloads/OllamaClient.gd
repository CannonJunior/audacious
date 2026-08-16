extends Node
## HTTP client for a locally hosted Ollama instance.
## Emits signals on EventBus so callers never import this directly.

const BASE_URL := "http://localhost:11434"

var _chat_http:   HTTPRequest
var _models_http: HTTPRequest
var _chat_busy:   bool = false
var _models_busy: bool = false
var _current_model: String = ""

func _ready() -> void:
	_chat_http = HTTPRequest.new()
	add_child(_chat_http)
	_chat_http.request_completed.connect(_on_chat_completed)

	_models_http = HTTPRequest.new()
	add_child(_models_http)
	_models_http.request_completed.connect(_on_models_completed)

	# Probe silently on startup; callers may also call fetch_models() explicitly.
	fetch_models()

# ── Public API ────────────────────────────────────────────────────────────────

func fetch_models() -> void:
	if _models_busy:
		return
	_models_busy = true
	if _models_http.request(BASE_URL + "/api/tags") != OK:
		_models_busy = false

## Send a chat request. messages must follow the Ollama API format:
## [{"role": "user"/"assistant"/"system", "content": "..."}]
## Returns false if a request is already in flight.
func chat(messages: Array, model: String = "") -> bool:
	if _chat_busy:
		return false
	var m := model if not model.is_empty() else _current_model
	if m.is_empty():
		EventBus.ollama_error.emit("No model available — is Ollama running?")
		return false
	var body := JSON.stringify({"model": m, "messages": messages, "stream": false})
	var err := _chat_http.request(
		BASE_URL + "/api/chat",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err == OK:
		_chat_busy = true
	else:
		EventBus.ollama_error.emit("Request error %d" % err)
	return err == OK

func set_model(model: String) -> void:
	_current_model = model

func get_current_model() -> String:
	return _current_model

func is_busy() -> bool:
	return _chat_busy

# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_chat_completed(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_chat_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		EventBus.ollama_error.emit("Connection failed — is Ollama running?")
		return
	if code != 200:
		EventBus.ollama_error.emit("Ollama returned HTTP %d" % code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		EventBus.ollama_error.emit("Unexpected response format")
		return
	var data: Dictionary = parsed
	var content: String = (data.get("message", {}) as Dictionary).get("content", "")
	EventBus.ollama_response_received.emit(content, data.get("model", _current_model))

func _on_models_completed(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_models_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # Ollama not running; silently ignore
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var models: Array = []
	for entry in (parsed as Dictionary).get("models", []):
		var n: String = (entry as Dictionary).get("name", "")
		if not n.is_empty():
			models.append(n)
	if not models.is_empty() and _current_model.is_empty():
		_current_model = models[0]
	EventBus.ollama_models_loaded.emit(models)
