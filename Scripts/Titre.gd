extends Control
## Écran titre : difficulté et niveau se choisissent (mémorisés), Jouer lance la partie,
## Multijoueur ouvre l'écran En ligne. Les niveaux affichent le record pour la difficulté choisie.
## `_ready` remet aussi ce poste hors réseau et le solo (`GameState.configurer_solo()` et l'écran
## 2000×648), même au retour d'une bataille ou de l'écran En ligne. Une page ouverte sur un lien
## d'invitation (`?salle=`, spec §4.4 du jeu en ligne) passe tout de suite à l'écran En ligne, le code
## rempli, une seule fois par lancement.

const SCENE_JEU := "res://Scenes/Main.tscn"
const SCENE_EN_LIGNE := "res://Scenes/EcranEnLigne.tscn"
const _EcranEnLigne := preload("res://Scripts/EcranEnLigne.gd")
const DELAI_DEMO := 15.0
const SCENE_REGLAGES := preload("res://Scenes/Reglages.tscn")

@onready var difficultes: HBoxContainer = $Centre/Colonne/RangeeDifficulte/Difficultes
@onready var niveaux: HBoxContainer = $Centre/Colonne/RangeeNiveau/Niveaux
@onready var bouton_jouer: Button = $Centre/Colonne/Jouer
@onready var bouton_reglages: Button = $BoutonReglages
@onready var bouton_arcade: Button = $BoutonArcade
## Créé par `_ready`, en bas à droite (la colonne centrale remplit déjà les 648 px de haut).
var bouton_multijoueur: Button

var boutons_difficulte: Array[Button] = []
var boutons: Array[Button] = []
var inactivite := 0.0
var demo_autorisee := true


func _ready() -> void:
	get_tree().paused = false
	# Retour depuis l'écran En ligne, le salon ou une manche quittée par le menu local, sans signal de
	# `Reseau` : ce poste revient hors réseau AVANT de remettre le solo. Sinon un ancien client
	# relancerait un solo où `multiplayer.is_server()` est faux (ennemis, pastilles, gerbe et chocs
	# inertes), et un ancien hôte émettrait encore sa balise et accepterait des joueurs.
	Reseau.quitter()
	Audio.arreter_vomi()  # filet (M5, revue finale phase 17) : aucune boucle de vomi ne survit à une partie
	# L'écran titre est celui du solo : Jouer, la démo et l'arcade y lancent des parties solo, dont
	# les règles doivent être branchées avant le changement de scène (Main._enter_tree appelle
	# nouvelle_partie), même au retour d'une bataille ; l'écran repasse en 2000×648.
	GameState.configurer_solo()
	Regles.appliquer_ecran(get_tree(), GameState.regles.taille_ecran())
	Audio.demarrer_musique("ville", 1)
	GameState.quitter_arcade()
	GameState.demo = false
	GameState.difficulte_courante = clamp(int(Scores.preference("difficulte", GameState.difficulte_courante)), 0, GameState.DIFFICULTES.size() - 1)
	GameState.niveau_courant = clamp(int(Scores.preference("niveau", GameState.niveau_courant)), 0, GameState.NIVEAUX.size() - 1)

	for i in range(GameState.DIFFICULTES.size()):
		var bouton := _bouton_choix(Vector2(340, 84), 22)
		bouton.pressed.connect(choisir_difficulte.bind(i))
		difficultes.add_child(bouton)
		boutons_difficulte.append(bouton)

	for i in range(GameState.NIVEAUX.size()):
		var bouton := _bouton_choix(Vector2(340, 84), 26)
		bouton.pressed.connect(choisir_niveau.bind(i))
		niveaux.add_child(bouton)
		boutons.append(bouton)

	bouton_multijoueur = _creer_bouton_multijoueur()
	Parametres.langue_changee.connect(func(_l: String) -> void: rafraichir_textes())
	choisir_difficulte(GameState.difficulte_courante)
	choisir_niveau(GameState.niveau_courant)
	bouton_jouer.grab_focus()
	var code := CodeSalle.prendre_code_de_la_page()
	if not code.is_empty():
		_EcranEnLigne.code_a_l_arrivee = code
		ouvrir_en_ligne.call_deferred()


## Attract mode : sans action pendant DELAI_DEMO secondes, le jeu se lance en démo.
func _process(delta: float) -> void:
	if not demo_autorisee or get_node_or_null("Reglages") != null:
		inactivite = 0.0
		return
	inactivite += delta
	if inactivite >= DELAI_DEMO:
		lancer_demo()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.length() < 2.0:
		return
	inactivite = 0.0


## Le bouton Multijoueur, en bas à droite, dans le style des boutons de coin (Arcade, Réglages) ;
## au clavier et à la manette, droite depuis Jouer y mène, gauche en revient.
func _creer_bouton_multijoueur() -> Button:
	var bouton := Button.new()
	bouton.name = "BoutonMultijoueur"
	bouton.text = "MULTIJOUEUR"
	bouton.add_theme_font_size_override("font_size", 26)
	bouton.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bouton.offset_left = -284.0
	bouton.offset_top = -100.0
	bouton.offset_right = -24.0
	bouton.offset_bottom = -24.0
	bouton.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bouton.pressed.connect(ouvrir_en_ligne)
	add_child(bouton)
	bouton_jouer.focus_neighbor_right = bouton_jouer.get_path_to(bouton)
	bouton.focus_neighbor_left = bouton.get_path_to(bouton_jouer)
	return bouton


func ouvrir_en_ligne() -> void:
	get_tree().change_scene_to_file(SCENE_EN_LIGNE)


func lancer_demo(changer_scene := true) -> void:
	inactivite = 0.0
	GameState.demo = true
	GameState.quitter_arcade()
	GameState.difficulte_courante = 0
	GameState.niveau_courant = randi() % GameState.NIVEAUX.size()
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_JEU)


func _bouton_choix(taille: Vector2, taille_police: int) -> Button:
	var bouton := Button.new()
	bouton.toggle_mode = true
	bouton.custom_minimum_size = taille
	bouton.add_theme_font_size_override("font_size", taille_police)
	Styles.appliquer_selection(bouton)
	return bouton


func choisir_difficulte(index: int) -> void:
	GameState.difficulte_courante = index
	Scores.definir_preference("difficulte", index)
	for i in range(boutons_difficulte.size()):
		boutons_difficulte[i].set_pressed_no_signal(i == index)
	rafraichir_textes()


func choisir_niveau(index: int) -> void:
	GameState.niveau_courant = index
	Scores.definir_preference("niveau", index)
	for i in range(boutons.size()):
		boutons[i].set_pressed_no_signal(i == index)


## Les libellés construits par script ne se retraduisent pas seuls.
func rafraichir_textes() -> void:
	for i in range(boutons_difficulte.size()):
		var d: Dictionary = GameState.DIFFICULTES[i]
		boutons_difficulte[i].text = "%s\n%s" % [tr(d.nom), tr(d.description)]
	for i in range(boutons.size()):
		boutons[i].text = _texte_niveau(i)
	var record_arcade: float = Scores.meilleur_temps("arcade")
	var ligne := tr("RECORD") % GameState.formater_temps(record_arcade) if record_arcade >= 0.0 else tr("ARCADE_DESC")
	bouton_arcade.text = "%s\n%s" % [tr("ARCADE"), ligne]


func lancer_arcade(changer_scene := true) -> void:
	GameState.demarrer_arcade()
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_JEU)


func _texte_niveau(index: int) -> String:
	var niveau: Dictionary = GameState.NIVEAUX[index]
	var cle := "%s/%s" % [niveau.id, GameState.difficulte().id]
	var record: float = Scores.meilleur_temps(cle)
	var ligne_record := tr("RECORD") % GameState.formater_temps(record) if record >= 0.0 else tr("PAS_ENCORE_PEINT")
	return "%s\n%s" % [tr(niveau.nom), ligne_record]


func jouer() -> void:
	get_tree().change_scene_to_file(SCENE_JEU)


## Compatibilité : choisir un niveau et lancer aussitôt.
func lancer(index: int) -> void:
	choisir_niveau(index)
	jouer()


func ouvrir_reglages() -> void:
	var reglages := SCENE_REGLAGES.instantiate()
	reglages.ferme.connect(func() -> void: bouton_reglages.grab_focus())
	add_child(reglages)
