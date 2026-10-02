extends SceneTree
## Le garde de l'export publié (phase 5, spec §11) : godot --headless --script tests/export_publie.gd -- --pck=<index.pck>
## Lit les réglages que l'export a écrits dans son paquet (`project.binary`, monté par `load_resource_pack`) et
## vérifie ce que la page publiée sera : sans la fonctionnalité `pilote` (le pilote du bout en bout reste inerte),
## l'adresse du Worker celle de project.godot, en `wss://`, et aucune adresse locale ailleurs que sous une variante
## `.pilote` (que seul l'export « Web pilote » choisit) ; la version celle de project.godot (le tag la vérifie).
## Sort en 0 sur `== 0 échec(s) ==`.

const REGLAGE_URL := "lelion/signalisation/url"

var _echecs := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("== garde de l'export publié ==")
	var pck := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pck="):
			pck = argument.trim_prefix("--pck=")
	_check(not pck.is_empty() and FileAccess.file_exists(pck), "(pré-condition) le paquet existe : « %s »" % pck)
	var reglages := {}
	if _echecs == 0:
		_check(ProjectSettings.load_resource_pack(pck, false), "(pré-condition) le paquet se monte : %s" % pck)
		reglages = lire_reglages(FileAccess.get_file_as_bytes("res://project.binary"))
	_check(not reglages.is_empty(), "(pré-condition) les réglages de l'export se lisent (%d)" % reglages.size())
	if not reglages.is_empty():
		var fonctions := str(reglages.get("_custom_features", "")).replace(" ", "").split(",", false)
		_check(not fonctions.has("pilote"), "l'export publié n'a pas la fonctionnalité pilote (%s)" % [fonctions])
		var url := str(reglages.get(REGLAGE_URL, ""))
		var attendue := str(ProjectSettings.get_setting(REGLAGE_URL, ""))
		_check(url == attendue and url.begins_with("wss://") and not url.contains("localhost"),
			"l'adresse du Worker de l'export : %s, celle de project.godot (%s), en wss://" % [url, attendue])
		var locales: Array[String] = []
		for cle: String in reglages:
			if str(reglages[cle]).contains("localhost") and not cle.ends_with(".pilote"):
				locales.append(cle)
		_check(locales.is_empty(), "aucune adresse locale hors des variantes .pilote (%s)" % [locales])
		var version := str(reglages.get("application/config/version", ""))
		_check(version == str(ProjectSettings.get_setting("application/config/version")),
			"la version de l'export : %s, celle de project.godot" % version)
		print("VERSION_EXPORT %s" % version)
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## Les réglages d'un `project.binary` (`ProjectSettings.save_custom`) : « ECFG », leur nombre (32 bits), puis
## chacun : sa clé (longueur 32 bits, UTF-8), sa valeur (longueur 32 bits, une Variant encodée) ; vide s'il est
## illisible.
static func lire_reglages(octets: PackedByteArray) -> Dictionary:
	if octets.size() < 8 or octets.slice(0, 4).get_string_from_ascii() != "ECFG":
		return {}
	var reglages := {}
	var position := 8
	for i in octets.decode_u32(4):
		if position + 4 > octets.size():
			return {}
		var longueur := octets.decode_u32(position)
		var cle := octets.slice(position + 4, position + 4 + longueur).get_string_from_utf8()
		position += 4 + longueur
		if position + 4 > octets.size():
			return {}
		longueur = octets.decode_u32(position)
		reglages[cle] = bytes_to_var(octets.slice(position + 4, position + 4 + longueur))
		position += 4 + longueur
	return reglages


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ✅ " + message)
	else:
		_echecs += 1
		print("  ❌ " + message)
