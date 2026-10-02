extends CanvasLayer
## Les contrôles tactiles (spec §6 du jeu en ligne) : affichés sur un mobile (`Parametres.mobile`) ou sur
## un écran tactile (`affiches`), ou forcés pour un ordinateur (`forcer_affichage`). Deux dispositions,
## placées sur l'écran du mode à l'ouverture (2000×648 en solo, 2000×1125 en bataille et au salon, que la
## fenêtre montre à l'échelle) :
## - JEU (la scène de jeu) : le stick (là où le pouce touche la moitié gauche), VOMIR en bas à droite, la
##   pause en haut à droite, sous le bandeau du HUD de la bataille ;
## - SALON : les flèches de la couleur (`deplacer_gauche`, `deplacer_droite`) en bas à gauche, PRÊT
##   (`vomir`) en bas à droite.
## Chaque bouton (`TouchScreenButton.action`) pousse son action comme une touche, à l'appui puis au
## relâchement : le salon n'agit qu'à l'appui, jamais tenu (phase 18), comme au clavier et à la manette,
## inchangés. Chaque bouton fait `Parametres.CIBLE_TACTILE` px de côté au moins et reste à MARGE px des
## bords de l'écran (la zone sûre d'un téléphone : ses coins arrondis, sa barre du bas).

enum Disposition { JEU, SALON }

## Marge des boutons aux bords de l'écran, en px du jeu (18 à 21 px CSS sur un téléphone en paysage).
const MARGE := 60
## Le haut du bouton de pause : sous le bandeau des vignettes du HUD de la bataille (10 + 112 px).
const HAUT_PAUSE := 140

@export var forcer_affichage := false  # pour tester sur un ordinateur
@export var disposition := Disposition.JEU

@onready var joystick: Control = $Joystick
@onready var bouton_vomir: TouchScreenButton = $BoutonVomir
@onready var etiquette_vomir: Label = $BoutonVomir/Etiquette
@onready var bouton_pause: TouchScreenButton = $BoutonPause
@onready var bouton_gauche: TouchScreenButton = $BoutonGauche
@onready var bouton_droite: TouchScreenButton = $BoutonDroite


func _ready() -> void:
	visible = forcer_affichage or affiches()
	var jeu := disposition == Disposition.JEU
	joystick.visible = jeu
	bouton_pause.visible = jeu
	bouton_gauche.visible = not jeu
	bouton_droite.visible = not jeu
	etiquette_vomir.text = "VOMIR" if jeu else "TACTILE_PRET"
	placer(get_viewport().get_visible_rect().size)
	for enfant in get_children():
		if enfant is TouchScreenButton:
			enfant.set_process_input(visible and enfant.visible)
	joystick.set_process_input(visible and jeu)


## Vrai si ce poste montre les contrôles tactiles : un mobile, ou tout écran tactile.
static func affiches() -> bool:
	return Parametres.mobile or DisplayServer.is_touchscreen_available()


## Place les boutons sur l'écran `taille` (px du jeu) : VOMIR (PRÊT au salon) en bas à droite, les flèches
## en bas à gauche, la pause en haut à droite ; le stick, lui, suit le pouce.
func placer(taille: Vector2) -> void:
	var cote := bouton_vomir.texture_normal.get_size().x
	var bas := taille.y - MARGE - cote
	bouton_vomir.position = Vector2(taille.x - MARGE - cote, bas)
	bouton_gauche.position = Vector2(MARGE, bas)
	bouton_droite.position = Vector2(MARGE + cote + MARGE, bas)
	bouton_pause.position = Vector2(taille.x - MARGE - cote, HAUT_PAUSE)
