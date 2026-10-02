extends Node
## Réglages persistants : volumes, plein écran, langue. Appliqués au démarrage et à chaque
## changement ; sauvegardés via Scores (ConfigFile dans user://, IndexedDB sur le Web).
## Et la plateforme du jeu en ligne (spec §6) : un mobile (`mobile`) n'a pas Créer une partie, a les
## contrôles tactiles et des cibles agrandies pour le doigt (`agrandir`), demande le plein écran au
## relâchement d'un toucher tant qu'il ne l'a pas (TENTATIVES_PLEIN_ECRAN fois au plus) ; un ordinateur a le
## bouton Plein écran du salon (`basculer_plein_ecran`). Tenu en
## portrait, un mobile montre le voile « Tourne ton téléphone » (`voile`) par-dessus le jeu, qui continue.

signal volumes_changes()
signal langue_changee(langue: String)

const LANGUES := ["fr", "en"]
const SHADER_CRT := preload("res://Shaders/Crt.gdshader")
## Hauteur minimale d'une cible au doigt, en px de l'écran du jeu (2000×1125 hors du solo) : les 44 px CSS
## conseillés pour une cible tactile à l'échelle 0,30 d'un iPhone en paysage sous les barres de Safari
## (340 px CSS de haut : 340 / 1125) ; 52 px CSS sur un 844×390.
const CIBLE_TACTILE := 150
## Demandes de plein écran au plus, sur un mobile : Safari sur iPhone n'a pas de plein écran pour un canevas,
## et chaque demande refusée écrit une erreur ; sans plafond, une à chaque toucher.
const TENTATIVES_PLEIN_ECRAN := 3

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
## Les demandes de plein écran faites sur ce mobile (au relâchement d'un toucher), TENTATIVES_PLEIN_ECRAN au
## plus ; jamais mémorisées.
var tentatives_plein_ecran := 0
## Vrai une fois la fenêtre vue en plein écran (`suivre_plein_ecran`) : plus aucune demande ensuite, pour
## toute la page (un joueur qui en sort n'y est pas ramené au toucher suivant).
var plein_ecran_obtenu := false
## Le voile du portrait (spec §6), au-dessus de tous les écrans et sous le filtre CRT : visible sur un mobile
## tenu en portrait (`actualiser_voile`), sans rien arrêter ni rien intercepter (le jeu continue derrière).
var voile: CanvasLayer
## La taille de la fenêtre à l'image précédente : le voile suit ses changements (le téléphone tourné), que la
## racine ne signale pas (sa taille est l'écran fixe du mode, `content_scale_size`).
var _taille_fenetre := Vector2i(-1, -1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # le premier toucher compte aussi sur un écran figé
	musique = clampf(float(Scores.preference("musique", musique)), 0.0, 1.0)
	effets = clampf(float(Scores.preference("effets", effets)), 0.0, 1.0)
	plein_ecran = bool(Scores.preference("plein_ecran", false))
	langue = str(Scores.preference("langue", _langue_systeme()))
	TranslationServer.set_locale(langue)
	crt = bool(Scores.preference("crt", false))
	_creer_couche_crt()
	_creer_voile()
	# Sur le Web, le plein écran exige un geste de l'utilisateur : on ne l'applique qu'au clic.
	if plein_ecran and not OS.has_feature("web"):
		_appliquer_plein_ecran()


func _process(_delta: float) -> void:
	var taille := DisplayServer.window_get_size()
	if taille != _taille_fenetre:
		_taille_fenetre = taille
		actualiser_voile(taille)
	if tentatives_plein_ecran > 0 and not plein_ecran_obtenu:
		suivre_plein_ecran(_mode_fenetre_mobile())


## Sur un mobile, le relâchement d'un toucher demande le plein écran (spec §6) : le navigateur ne l'accorde
## que pendant un geste de l'utilisateur, et `touchend` en est un (`touchstart` non). Redemandé au relâchement
## suivant tant qu'il n'est pas obtenu, TENTATIVES_PLEIN_ECRAN fois au plus. Pas mémorisé dans les préférences.
## Dans l'export Web, la page entière passe en plein écran, pas le seul canevas (celui de
## `DisplayServer.window_set_mode`) : le champ de saisie posé par-dessus le jeu (`SaisieWeb`) en est, et
## reste visible.
func _input(event: InputEvent) -> void:
	if mobile and not plein_ecran_obtenu and tentatives_plein_ecran < TENTATIVES_PLEIN_ECRAN \
			and event is InputEventScreenTouch and not event.pressed:
		tentatives_plein_ecran += 1
		if OS.has_feature("web"):
			JavaScriptBridge.eval("document.documentElement.requestFullscreen?.()?.catch(() => {})", true)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Le mode de la fenêtre d'un mobile : dans l'export Web, plein écran si la page l'est (`_input`).
func _mode_fenetre_mobile() -> DisplayServer.WindowMode:
	if OS.has_feature("web"):
		var plein: Variant = JavaScriptBridge.eval("document.fullscreenElement !== null", true)
		return DisplayServer.WINDOW_MODE_FULLSCREEN if plein == true else DisplayServer.WINDOW_MODE_WINDOWED
	return DisplayServer.window_get_mode()


## Le mode `mode` de la fenêtre, lu à chaque image après une demande (`_process`) : un mobile vu en plein
## écran l'a obtenu, et n'en demande plus (le toucher qui l'a demandé ne le dit pas : le navigateur l'accorde
## plus tard, ou jamais).
func suivre_plein_ecran(mode: DisplayServer.WindowMode) -> void:
	if mobile and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		plein_ecran_obtenu = true


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


## Le voile : un fond sombre presque opaque et « Tourne ton téléphone », sur l'écran du mode (16:9 ou celui
## du solo, que la fenêtre montre à l'échelle).
func _creer_voile() -> void:
	voile = CanvasLayer.new()
	voile.name = "VoilePortrait"
	voile.layer = 90
	var fond := ColorRect.new()
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.color = Color(0.06, 0.05, 0.14, 0.92)
	var texte := Label.new()
	texte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte.text = "VOILE_PORTRAIT"
	texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.add_theme_font_size_override("font_size", 120)
	texte.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	fond.add_child(texte)
	voile.add_child(fond)
	voile.visible = false
	add_child(voile)


## Montre le voile sur un mobile dont la fenêtre `taille` (par défaut, celle du jeu) est plus haute que
## large, le cache sinon. Appelée à la première image, puis à chaque changement de taille de la fenêtre
## (le téléphone tourné).
func actualiser_voile(taille: Vector2i = DisplayServer.window_get_size()) -> void:
	voile.visible = mobile and taille.y > taille.x


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
