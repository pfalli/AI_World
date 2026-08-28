class_name APIConfig
extends RefCounted

# This is the only place where the Godot client selects its API base URL.
const NATIVE_BASE_URL := "http://127.0.0.1:8000"
const WEB_BASE_URL := "https://aiworld-api.piero.sbs"

static func base_url() -> String:
	return WEB_BASE_URL if OS.has_feature("web") else NATIVE_BASE_URL
