extends Node2D
## Racine de la partie : met l'écran à la taille du mode, place la ville, le ciel, la caméra et
## un lion par joueur, écoute la fin de partie et affiche le bilan du solo.
## En réseau (phase 14), la manche synchronisée (`Manche`) passe entre l'hôte et les clients : le
## lion de la scène (celui du solo) est retiré, tous les lions apparaissent par le
## `MultiplayerSpawner` de la scène (`Apparitions`, par l'index de leur joueur, sa `spawn_function`
## leur donnant joueur et commandes avant l'ajout), comme les ennemis et les pastilles que fait
## apparaître le Spawner de l'hôte ; lions, Spawner et intro attendent la barrière de chargement.
## Échap y ouvre un menu local qui ne met pas la partie en pause ; un hôte perdu ramène au titre
## après son message (à l'écran En ligne un poste revenu d'un onglet caché, déclaré parti
## entre-temps). Une bataille finie (phase 18) montre l'écran Résultats (`Resultats`) sur le bilan de
## l'hôte, et suit le choix qu'on y fait.

@export var game_over_scene: PackedScene

@export var force_tremblement := 14.0
@export var duree_tremblement := 0.35
@export var duree_demo := 45.0
## Plusieurs lions (bataille) : hauteur de départ, en part de la hauteur de l'écran (en haut du ciel).
@export var hauteur_depart_lions := 0.12

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCENE_SALON := "res://Scenes/Salon.tscn"
const SCENE_EN_LIGNE := "res://Scenes/EcranEnLigne.tscn"
const _Salon := preload("res://Scripts/Salon.gd")
const _EcranEnLigne := preload("res://Scripts/EcranEnLigne.gd")
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
const SCENE_LION := preload("res://Scenes/Lion.tscn")
const SCENE_HUD_BATAILLE := preload("res://Scenes/HUDBataille.tscn")
const SCENE_RESULTATS := preload("res://Scenes/Resultats.tscn")
## Temps pendant lequel « L'hôte a quitté la partie » reste affiché avant le retour au titre.
const DELAI_HOTE_PERDU := 2.5

@onready var ville: Node2D = $Ville
@onready var camera: Camera2D = $Camera
@onready var ciel: TextureRect = $Ciel
@onready var apparitions: MultiplayerSpawner = $Apparitions
@onready var manche: Node = $Manche
@onready var menu_pause: CanvasLayer = $PauseMenu
@onready var controles_tactiles: CanvasLayer = $ControlesTactiles

## Le lion du joueur local : celui de la scène hors réseau ; en réseau, celui qui apparaît pour le
## joueur de ce poste (null avant son apparition).
var lion: Lion
## Un lion par joueur, dans l'ordre de `GameState.joueurs` (des index) : hors réseau, le premier est
## celui de la scène, le lion du joueur local ; en réseau, ceux qui ont apparu, sans les partis.
var lions: Array[Lion] = []
## Vrai pour une bataille en réseau (fixé en entrant dans l'arbre).
var en_reseau := false
## Le HUD d'une bataille (phase 17), à la place de celui du solo ; null en solo.
var hud_bataille: CanvasLayer
## L'écran Résultats d'une bataille finie (phase 18) ; null avant la fin, et en solo.
var resultats: CanvasLayer

var _tremblement_restant := 0.0
var _demo_restant := 0.0


const ACTIONS_DE_JEU := ["deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas", "vomir"]


## Avant les _ready des enfants : le lion et le HUD lisent l'état de partie en se construisant,
## le peintre et les apparitions la taille de l'écran. Les règles du mode sont branchées AVANT le
## changement de scène (`GameState.configurer_solo` / `configurer_bataille`), jamais ici.
func _enter_tree() -> void:
	# Une manche relancée depuis l'écran Résultats (phase 18) arrive l'arbre encore en pause (la fin l'a
	# figé) : la scène de jeu part toujours dépausée, comme le titre (`Titre._ready`).
	get_tree().paused = false
	for action in ACTIONS_DE_JEU:
		Input.action_release(action)
	Regles.appliquer_ecran(get_tree(), GameState.regles.taille_ecran())
	GameState.nouvelle_partie()
	en_reseau = Reseau.en_ligne()
	# Avant le `_ready` de l'intro : en réseau, elle attend la barrière de chargement.
	$Intro.automatique = not en_reseau


func _ready() -> void:
	Audio.demarrer_musique("boss" if GameState.niveau().get("boss", false) else "ville", 0)
	GameState.progression_changee.connect(_on_progression_changee)
	GameState.partie_terminee.connect(_on_partie_terminee)
	GameState.joueur_local().touche.connect(_on_lion_touche)
	ville.charger_skyline(load(GameState.niveau().texture))
	_placer_ville()
	_placer_ciel_et_camera()
	if GameState.regles.compte_le_territoire():
		_installer_hud_bataille()
	if en_reseau:
		_preparer_manche_en_reseau()
		return
	lion = $Lion
	_ajouter_lions()
	$Spawner.demarrer()
	if GameState.demo:
		_installer_demo()


## Bataille (locale ou en réseau) : le HUD de la bataille remplace celui du solo (cœurs, arc-en-ciel,
## chrono qui monte), une fois la ville chargée (son territoire tient les scores).
func _installer_hud_bataille() -> void:
	var hud_solo: Node = $HUD
	remove_child(hud_solo)
	hud_solo.free()
	hud_bataille = SCENE_HUD_BATAILLE.instantiate()
	hud_bataille.ville = ville
	add_child(hud_bataille)


## En réseau : le lion de la scène (celui du solo) s'en va avant tout tick, les lions viendront
## d'`apparitions` ; la manche commence (barrière de chargement).
func _preparer_manche_en_reseau() -> void:
	var lion_du_solo: Node = $Lion
	remove_child(lion_du_solo)
	lion_du_solo.free()
	apparitions.spawn_function = _creer_lion
	apparitions.spawned.connect(_sur_apparition)
	manche.barriere_passee.connect(_sur_barriere_passee)
	manche.joueur_parti.connect(_sur_joueur_parti)
	manche.depart_vu.connect(_sur_depart_vu)
	manche.bilan_recu.connect(_afficher_resultats)
	menu_pause.visibility_changed.connect(_suspendre_commandes)
	# M2 (revue finale) : `Reseau.hote_perdu` peut aussi partir chez l'hôte (son propre pair ENet en
	# erreur, N4 de `Reseau.gd`) ; sans ce branchement, l'hôte continuait seul une manche que
	# personne ne recevait plus, sans aucun message.
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	# Phase 18 : depuis l'écran Résultats, l'hôte relance une manche (chaque poste recharge la scène de
	# jeu) ou ramène tout le monde au salon.
	Reseau.manche_lancee.connect(_sur_manche_relancee)
	Reseau.salon_rouvert.connect(_sur_salon_rouvert)
	manche.demarrer(ville)


## Les autoloads survivent à la scène de jeu : ne rien leur laisser.
func _exit_tree() -> void:
	for connexion: Array in [[Reseau.hote_perdu, _sur_hote_perdu], [Reseau.manche_lancee, _sur_manche_relancee],
			[Reseau.salon_rouvert, _sur_salon_rouvert]]:
		if (connexion[0] as Signal).is_connected(connexion[1]):
			(connexion[0] as Signal).disconnect(connexion[1])


## Sur chaque poste : l'hôte relance une manche avec les mêmes joueurs (Revanche, Niveau suivant) : la
## scène de jeu se recharge, comme depuis le salon (`Salon.entrer_en_manche`).
func _sur_manche_relancee(fiches: Array[Dictionary]) -> void:
	_Salon.entrer_en_manche(get_tree(), fiches)


## Sur chaque poste : l'hôte ramène tout le monde au salon.
func _sur_salon_rouvert() -> void:
	get_tree().change_scene_to_file(SCENE_SALON)


## La `spawn_function` d'`apparitions`, sur chaque poste : le lion du joueur d'index `index`, avec
## son joueur et ses commandes avant l'ajout à l'arbre, à sa place de départ. Chez l'hôte, le lion du
## joueur local lit les actions de ce poste, les autres des commandes manuelles (celles que chaque
## client envoie) ; sur un client, le lion du joueur local est prédit (phase 16) : sa prédiction lit
## les actions de ce poste une fois par tick et les écrit dans ses commandes manuelles.
func _creer_lion(index: Variant) -> Node:
	if not (index is int) or index < 0 or index >= GameState.joueurs.size():
		push_error("Main : apparition d'un lion pour un index inconnu (%s)" % [index])
		return null
	var joueur: Joueur = GameState.joueurs[index]
	var nouveau: Lion = SCENE_LION.instantiate()
	nouveau.name = "Lion%d" % (index + 1)
	nouveau.joueur = joueur
	var local := joueur == GameState.joueur_local()
	nouveau.commandes = Commandes.locales() if local and multiplayer.is_server() else Commandes.manuelles()
	if local and not multiplayer.is_server():
		nouveau.prediction = PredictionLocale.new()
	nouveau.position = _position_de_depart(index, GameState.joueurs.size())
	return nouveau


## Barrière passée : chez l'hôte, un lion par joueur encore là, puis les apparitions du Spawner ; sur
## chaque poste, l'intro.
func _sur_barriere_passee() -> void:
	if multiplayer.is_server():
		for i in range(GameState.joueurs.size()):
			if manche.joue(i):
				_enregistrer_lion(apparitions.spawn(i))
		$Spawner.demarrer()
	$Intro.lancer()


## Chez un client : un nœud apparu par `apparitions` (un lion, ou un ennemi, une pastille).
func _sur_apparition(noeud: Node) -> void:
	if noeud is Lion:
		_enregistrer_lion(noeud)


func _enregistrer_lion(nouveau: Lion) -> void:
	lions.append(nouveau)
	lions.sort_custom(func(a: Lion, b: Lion) -> bool: return a.joueur.index < b.joueur.index)
	if nouveau.joueur == GameState.joueur_local():
		lion = nouveau
		_suspendre_commandes()
	manche.suivre_lion(nouveau)
	nouveau.tree_exited.connect(_oublier_lion.bind(nouveau))


func _oublier_lion(parti: Lion) -> void:
	lions.erase(parti)
	if lion == parti:
		lion = null


## Chez l'hôte : le joueur d'index `index` a quitté la manche ; son lion s'en va chez tous (sa
## disparition est répliquée), ses cellules restent au territoire.
func _sur_joueur_parti(index: int) -> void:
	for l in lions:
		if l.joueur.index == index:
			l.queue_free()


## Sur chaque poste : le joueur d'index `index` a quitté la manche (en pleine manche, ou sur l'écran
## Résultats) : le HUD et l'écran Résultats le grisent.
func _sur_depart_vu(index: int) -> void:
	hud_bataille.marquer_parti(index)
	if resultats != null:
		resultats.marquer_parti(index)


## Menu local ouvert pendant une manche en réseau : les commandes de ce poste valent le repos.
func _suspendre_commandes() -> void:
	if lion != null:
		lion.commandes.suspendues = menu_pause.visible


## L'hôte est parti, vu d'un client, ou son propre pair ENet en erreur chez l'hôte lui-même (M2 de
## la revue finale) : ce poste est déjà hors réseau. Tout se fige sous le message (« L'hôte a quitté la
## partie », ou l'exclusion de ce poste par la barrière de chargement : `Reseau.raison_perte`, phase 18),
## puis retour au titre (spec §9) ; ou, pour un poste revenu d'un onglet caché (« Tu as été déconnecté »,
## phase 7 du jeu en ligne), à l'écran En ligne.
func _sur_hote_perdu() -> void:
	# M5 (revue finale phase 17) : l'arbre se fige avant qu'aucun lion n'arrête la boucle du vomi d'un
	# joueur qui tenait Espace ; elle continuerait sur le titre.
	Audio.arreter_vomi()
	# M1 (revue finale) : ce poste est déjà hors réseau (`Reseau.en_ligne()` est faux) ; sans ceci,
	# Échap ouvrirait le menu local par-dessus le message (il se croit encore hors ligne comme en
	# solo) puis un second Échap dépauserait l'arbre en le refermant, repartant la ville figée.
	menu_pause.hide()
	menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
	if resultats != null:
		resultats.hide()  # une manche finie : le message remplace l'écran Résultats
		# M4 de la revue finale (phase 18) : caché mais toujours dans l'arbre, il prenait encore les
		# touches (Échap y aurait rouvert la confirmation de départ, sous le message).
		resultats.process_mode = Node.PROCESS_MODE_DISABLED
	var couche := CanvasLayer.new()
	couche.name = "HotePerdu"
	couche.layer = 10
	couche.process_mode = Node.PROCESS_MODE_ALWAYS
	var message := Label.new()
	message.name = "Message"
	message.text = Reseau.raison_perte
	message.add_theme_font_size_override("font_size", 56)
	message.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	message.add_theme_constant_override("outline_size", 10)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message.grow_vertical = Control.GROW_DIRECTION_BOTH
	couche.add_child(message)
	add_child(couche)
	get_tree().paused = true
	get_tree().create_timer(DELAI_HOTE_PERDU, true).timeout.connect(_apres_la_perte.bind(Reseau.raison_perte))


## Après le message de la perte de l'hôte, de raison `raison` : le titre (spec §9, comme au LAN), sauf pour un
## poste revenu d'un onglet caché ou d'un téléphone verrouillé (`Reseau.PERTE_DECONNECTE`) : l'écran En
## ligne, qui redit le message (spec §9 : « Tu as été déconnecté » puis écran En ligne), d'où le lien
## d'invitation le ramène.
func _apres_la_perte(raison: String) -> void:
	if raison != Reseau.PERTE_DECONNECTE:
		_revenir_au_titre()
		return
	get_tree().paused = false
	_EcranEnLigne.message_a_l_arrivee = raison
	get_tree().change_scene_to_file(SCENE_EN_LIGNE)


func _revenir_au_titre() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_TITRE)


## Attract mode : un pilote automatique joue, une étiquette clignote, toute touche ramène au titre.
func _installer_demo() -> void:
	_demo_restant = duree_demo
	var pilote := Node.new()
	pilote.name = "Pilote"
	pilote.set_script(SCRIPT_PILOTE)
	add_child(pilote)
	var couche := CanvasLayer.new()
	couche.name = "Demo"
	couche.layer = 7
	var etiquette := Label.new()
	etiquette.text = "DEMO"
	etiquette.add_theme_font_size_override("font_size", 44)
	etiquette.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	etiquette.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	etiquette.grow_horizontal = Control.GROW_DIRECTION_BOTH
	etiquette.position.y -= 90.0
	couche.add_child(etiquette)
	add_child(couche)
	var clignote := create_tween().set_loops()
	clignote.tween_property(etiquette, "modulate:a", 0.15, 0.6)
	clignote.tween_property(etiquette, "modulate:a", 1.0, 0.6)


func _input(event: InputEvent) -> void:
	if not GameState.demo:
		return
	var pression := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
		or event is InputEventScreenTouch) and event.is_pressed()
	if pression:
		quitter_demo()
		get_viewport().set_input_as_handled()


func quitter_demo(changer_scene := true) -> void:
	if not GameState.demo:
		return
	GameState.demo = false
	get_tree().paused = false
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_TITRE)


func _placer_ville() -> void:
	var screen_size := get_viewport_rect().size
	var texture_size: Vector2 = ville.get_node("Sprite2D").texture.get_size()
	ville.position = Vector2(screen_size.x / 2, screen_size.y - texture_size.y / 2)


## Le ciel couvre l'écran du mode et la caméra en vise le centre (en solo : 2000×648 et
## (1000, 324), les valeurs de la scène).
func _placer_ciel_et_camera() -> void:
	var taille := get_viewport_rect().size
	ciel.size = taille
	camera.position = taille / 2.0


## Un lion par joueur. Le lion de la scène prend de lui-même le joueur local ; chaque autre lion
## reçoit son joueur et des commandes manuelles AVANT l'ajout à l'arbre, sinon il prendrait en
## silence le joueur local et le clavier de ce poste (en phase 14, ses commandes viendront du
## réseau). Plusieurs lions partent en haut du ciel, répartis sur la largeur.
func _ajouter_lions() -> void:
	lions.clear()
	lions.append(lion)
	for i in range(1, GameState.joueurs.size()):
		var autre: Lion = SCENE_LION.instantiate()
		autre.name = "Lion%d" % (i + 1)
		autre.joueur = GameState.joueurs[i]
		autre.commandes = Commandes.manuelles()
		add_child(autre)
		move_child(autre, lion.get_index() + i)
		lions.append(autre)
	if lions.size() > 1:
		_repartir_lions()


## Centres des lions régulièrement espacés sur la largeur, tous à la même hauteur.
func _repartir_lions() -> void:
	for i in range(lions.size()):
		lions[i].position = _position_de_depart(i, lions.size())


## Place de départ du lion `i` sur `nb` : centres régulièrement espacés sur la largeur, en haut du ciel.
func _position_de_depart(i: int, nb: int) -> Vector2:
	var taille := get_viewport_rect().size
	return Vector2(taille.x * (i + 0.5) / nb - Lion.CENTRE.x, taille.y * hauteur_depart_lions)


func _process(delta: float) -> void:
	if not lions.is_empty():
		_placer_pseudos()
	if hud_bataille != null:
		Audio.definir_intensite(GameState.regles.intensite_musique())  # le temps de la manche
	if GameState.demo and GameState.partie_en_cours:
		_demo_restant -= delta
		if _demo_restant <= 0.0:
			quitter_demo()
			return
	if _tremblement_restant <= 0.0:
		return
	_tremblement_restant = max(0.0, _tremblement_restant - delta)
	var intensite := force_tremblement * (_tremblement_restant / duree_tremblement)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensite
	if _tremblement_restant == 0.0:
		camera.offset = Vector2.ZERO


## Les pseudos des lions d'une bataille, écartés s'ils se recouvrent et gardés dans l'écran
## (`PlacementPseudos`), là où chaque lion est affiché.
func _placer_pseudos() -> void:
	var visibles: Array[Lion] = []
	var textes: Array[Rect2] = []
	for l in lions:
		if l.etiquette_pseudo.visible:
			visibles.append(l)
			textes.append(l.rect_pseudo())
	var xs := PlacementPseudos.repartir(textes, get_viewport_rect().size.x)
	for i in range(visibles.size()):
		visibles[i].placer_pseudo(xs[i])


## La musique gagne une couche par tiers de l'avancement : en solo, du chemin vers la victoire ; en
## bataille, du temps de la manche (aussi suivi à chaque image, `_process`).
func _on_progression_changee(_ratio: float) -> void:
	Audio.definir_intensite(GameState.regles.intensite_musique())


func trembler() -> void:
	_tremblement_restant = duree_tremblement


## Le lion du joueur local est touché : l'écran tremble.
func _on_lion_touche(_origine: Vector2) -> void:
	trembler()


func _on_partie_terminee(victoire: bool) -> void:
	if GameState.demo:
		if not victoire:
			lion.hide()
		get_tree().paused = true
		get_tree().create_timer(2.5, true).timeout.connect(quitter_demo)
		return
	if GameState.regles.compte_le_territoire():
		# Bataille : tout se fige, scores compris. Le menu local se ferme et se tait (Échap est à l'écran
		# Résultats). En réseau, l'écran Résultats attend le bilan de l'hôte (`Manche.bilan_recu`, juste
		# après : chez l'hôte, sa manche le relève ; chez un client, il est arrivé avec la fin) ; hors
		# réseau, ce poste le relève lui-même.
		menu_pause.hide()
		menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().paused = true
		if not en_reseau:
			_afficher_resultats(_bilan_local())
		return
	if not victoire:
		lion.hide()
	var overlay := game_over_scene.instantiate()
	add_child(overlay)
	overlay.afficher(victoire, GameState.progression, GameState.temps_ecoule)
	get_tree().paused = true


## Bataille locale : le bilan de la manche, relevé sur ce poste (son territoire, ses joueurs) : ni départ
## ni lion à poser (aucun client).
func _bilan_local() -> BilanManche:
	var cellules: Array[int] = []
	for j in GameState.joueurs:
		cellules.append(ville.territoire.cellules_de(j.index))
	return BilanManche.relever(GameState.joueurs, cellules, [] as Array[int], {} as Dictionary[int, PackedByteArray], GameState.temps_ecoule)


## Une bataille finie : l'écran Résultats sur le bilan `bilan` (celui de l'hôte), à la place du HUD de la
## bataille et des contrôles tactiles de la manche (relâchés, sourds), les pseudos des lions remis à leur
## place finale. Une fois.
func _afficher_resultats(bilan: BilanManche) -> void:
	if resultats != null:
		return
	if not lions.is_empty():
		_placer_pseudos()
	hud_bataille.hide()
	controles_tactiles.cacher()
	resultats = SCENE_RESULTATS.instantiate()
	resultats.choix_fait.connect(_sur_choix_resultats)
	add_child(resultats)
	resultats.afficher(bilan, multiplayer.is_server(), en_reseau)


## Le choix fait sur l'écran Résultats. Quitter : le titre (qui quitte le réseau ; l'hôte qui part ramène
## ses clients au titre, « L'hôte a quitté la partie »). Revanche et Niveau suivant : la scène de jeu se
## recharge, sur le même niveau ou le suivant (en boucle), avec les mêmes joueurs (les partis en moins) :
## un territoire, un Spawner, un chrono, une manche tout neufs ; en réseau, l'hôte la relance chez tous
## (`Reseau.relancer_manche`, puis `_sur_manche_relancee` sur chaque poste). Retour au salon (l'hôte, en
## réseau) : chaque poste revient au salon, sur la même table (`Reseau.revenir_au_salon`). Un choix que
## l'hôte ne peut plus suivre au moment même (plus assez de joueurs) se regrise.
func _sur_choix_resultats(choix: StringName) -> void:
	var niveau := GameState.niveau_courant + (1 if choix == &"suivant" else 0)
	match choix:
		&"quitter":
			get_tree().change_scene_to_file(SCENE_TITRE)
		&"revanche", &"suivant":
			if en_reseau:
				if not Reseau.relancer_manche(niveau):
					resultats.annuler_choix()
			else:
				GameState.niveau_courant = posmod(niveau, GameState.NIVEAUX.size())
				get_tree().reload_current_scene()
		&"salon":
			if not Reseau.revenir_au_salon():
				resultats.annuler_choix()
