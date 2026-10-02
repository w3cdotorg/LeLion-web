extends Node
## Réglages persistants : volumes, plein écran, langue. Appliqués au démarrage et à chaque
## changement ; sauvegardés via Scores (ConfigFile dans user://, IndexedDB sur le Web).
## Et la plateforme du jeu en ligne (spec §6) : un mobile (`mobile`) n'a pas Créer une partie, a les
## contrôles tactiles et des cibles agrandies pour le doigt (`agrandir`), passe en plein écran à son
## premier toucher ; un ordinateur a le bouton Plein écran du salon (`basculer_plein_ecran`).

signal volumes_changes()
signal langue_changee(langue: String)

const LANGUES := ["fr", "en"]
const SHADER_CRT := preload("res://Shaders/Crt.gdshader")
## Hauteur minimale d'une cible au doigt, en px de l'écran du jeu (2000×1125 hors du solo) : les 44 px CSS
## conseillés pour une cible tactile à l'échelle 0,30 d'un iPhone en paysage sous les barres de Safari
## (340 px CSS de haut : 340 / 1125) ; 52 px CSS sur un 844×390.
const CIBLE_TACTILE := 150

var musique := 0.7
var effets := 1.0
var plein_ecran := false
var langue := "en"
var crt := false
var couche_crt: CanvasLayer
## Vrai sur un mobile (Android, iOS) dans l'export Web (spec §6 : `web_android`, `web_ios`, lus dans
## l'agent utilisateur du navigateur) ; faux ailleurs. Lu par les écrans à leur ouverture ; modifiable par
## les tests (le desktop n'a ni l'un ni l'autre).
var mobile := OS.has_feature("web_android") or OS.has_feature("web_ios")
## Vrai une fois le plein écran demandé par un premier toucher (une seule fois par page : un joueur qui
## en sort n'y est pas ramené au toucher suivant).
var plein_ecran_demande := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # le premier toucher compte aussi sur un écran figé
	musique = clampf(float(Scores.preference("musique", musique)), 0.0, 1.0)
	effets = clampf(float(Scores.preference("effets", effets)), 0.0, 1.0)
	plein_ecran = bool(Scores.preference("plein_ecran", false))
	langue = str(Scores.preference("langue", _langue_systeme()))
	TranslationServer.set_locale(langue)
	crt = bool(Scores.preference("crt", false))
	_creer_couche_crt()
	# Sur le Web, le plein écran exige un geste de l'utilisateur : on ne l'applique qu'au clic.
	if plein_ecran and not OS.has_feature("web"):
		_appliquer_plein_ecran()


## Sur un mobile, le premier toucher demande le plein écran (spec §6) : le navigateur ne l'accorde que
## pendant un geste de l'utilisateur, et ce toucher en est un. Pas mémorisé dans les préférences.
func _input(event: InputEvent) -> void:
	if mobile and not plein_ecran_demande and event is InputEventScreenTouch and event.pressed:
		plein_ecran_demande = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _langue_systeme() -> String:
	return "fr" if OS.get_locale_language() == "fr" else "en"


func definir_musique(valeur: float) -> void:
	musique = clampf(valeur, 0.0, 1.0)
	Scores.definir_preference("musique", musique)
	volumes_changes.emit()


func definir_effets(valeur: float) -> void:
	effets = clampf(valeur, 0.0, 1.0)
	Scores.definir_preference("effets", effets)
	volumes_changes.emit()


func definir_plein_ecran(actif: bool) -> void:
	plein_ecran = actif
	Scores.definir_preference("plein_ecran", actif)
	_appliquer_plein_ecran()


## Le bouton Plein écran du salon, sur ordinateur (spec §6 ; un clic, le geste que le navigateur exige) :
## bascule d'après la fenêtre elle-même, pas d'après la préférence (sur le Web, Échap sort du plein écran
## sans passer par le jeu).
func basculer_plein_ecran() -> void:
	definir_plein_ecran(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)


func definir_langue(nouvelle: String) -> void:
	if not nouvelle in LANGUES:
		return
	langue = nouvelle
	Scores.definir_preference("langue", langue)
	TranslationServer.set_locale(langue)
	langue_changee.emit(langue)


## Le filtre CRT est un ColorRect plein écran au-dessus de tout, qui relit l'écran rendu.
func _creer_couche_crt() -> void:
	couche_crt = CanvasLayer.new()
	couche_crt.name = "FiltreCrt"
	couche_crt.layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var materiau := ShaderMaterial.new()
	materiau.shader = SHADER_CRT
	rect.material = materiau
	couche_crt.add_child(rect)
	add_child(couche_crt)
	couche_crt.visible = crt


func definir_crt(actif: bool) -> void:
	crt = actif
	Scores.definir_preference("crt", actif)
	couche_crt.visible = actif


func _appliquer_plein_ecran() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if plein_ecran else DisplayServer.WINDOW_MODE_WINDOWED)


## Agrandit `controle` pour le doigt (sur un mobile) : CIBLE_TACTILE px de haut au moins, sa police à
## `police` px.
static func agrandir(controle: Control, police: int) -> void:
	controle.custom_minimum_size.y = maxf(controle.custom_minimum_size.y, CIBLE_TACTILE)
	controle.add_theme_font_size_override("font_size", police)


## dB à appliquer à un lecteur pour un volume linéaire 0..1 (silence total à 0).
static func en_db(volume: float) -> float:
	return linear_to_db(volume) if volume > 0.001 else -80.0
