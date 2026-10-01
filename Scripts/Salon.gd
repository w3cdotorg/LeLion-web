extends Control
## Salon (spec §4) : une carte par place, synchronisée par l'hôte (pseudo, aperçu du lion teinté,
## Prêt, badges « HÔTE » et « TOI ») ; gauche/droite change de couleur parmi les libres (l'hôte
## arbitre, une couleur est figée tant que son joueur est prêt) ; haut/bas change le niveau (l'hôte
## seul) ; vomir bascule Prêt. Le bouton « Démarrer la partie » de l'hôte (ou Tab, Start à la
## manette) n'est actif qu'avec au moins deux joueurs arrivés, tous prêts, sans place encore
## réservée ; grisé, il dit pourquoi (`Reseau.raison_attente`). Il lance aussitôt la manche chez
## tous (`Reseau.manche_lancee`, sans compte à rebours : la manche s'ouvre sur l'intro « Prêt ?
## Vomissez ! ») : chaque poste branche les règles de bataille et la table des joueurs
## (`GameState.configurer_bataille_reseau`), puis charge la scène de jeu. En 16:9 (spec §7).
##
## L'hôte voit le code de la partie (`Reseau.code_partie`, relu à chaque affichage) : un code de salle
## (« K7Q-2XM ») et « Copier le lien », qui met le lien d'invitation dans le presse-papiers (spec §4.4) ;
## sur le desktop de développement, l'adresse `ip:port` de l'hôte ENet, sans lien.
##
## Retour (ou Échap, B à la manette) quitte le réseau et ramène à l'écran En ligne ; un hôte perdu y
## ramène avec « L'hôte a quitté la partie ». Aucun contrôle ne prend le focus (les boutons se
## cliquent à la souris) : les flèches, la croix, le stick, vomir et démarrer arrivent tous à
## `_unhandled_input`.

const SCENE_JEU := "res://Scenes/Main.tscn"
const SCENE_EN_LIGNE := "res://Scenes/EcranEnLigne.tscn"
const _EcranEnLigne := preload("res://Scripts/EcranEnLigne.gd")
const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
## Six cartes et leurs écarts tiennent dans les 2000 px ; un pseudo de 12 caractères larges
## (« WWWWWWWWWWWW ») tient dans la carte à POLICE_PSEUDO px (vérifié par le smoke test).
const TAILLE_CARTE := Vector2(310, 470)
const POLICE_PSEUDO := 24
const COULEUR_BADGE := Color(1, 0.85, 0.2)
const COULEUR_PRET := Color(0.55, 1.0, 0.55)
const COULEUR_ATTENTE := Color(1, 1, 1, 0.55)
const COULEUR_CONTOUR := Color(0.1, 0.05, 0.15, 1)
## Secondes pendant lesquelles « Copier le lien » dit « Lien copié ! ».
const DUREE_LIEN_COPIE := 2.0
## Actions du salon, prises à l'appui (voir `_unhandled_input`).
const ACTIONS: Array[StringName] = [&"deplacer_gauche", &"deplacer_droite", &"deplacer_haut", &"deplacer_bas",
	&"vomir", &"demarrer"]
## Une carte par place, dans l'ordre des index : {"cadre": PanelContainer, "style": StyleBoxFlat,
## "badge": Label, "lion": TextureRect, "teinte": ShaderMaterial, "pseudo": Label, "etat": Label}.
var cartes: Array[Dictionary] = []

@onready var titre_niveau: Label = $Centre/Colonne/Niveau
@onready var rangee_cartes: HBoxContainer = $Centre/Colonne/Cartes
@onready var etat: Label = $Centre/Colonne/Etat
@onready var aide: Label = $Centre/Colonne/Aide
@onready var rangee_invitation: HBoxContainer = $Centre/Colonne/Invitation
@onready var etiquette_code: Label = $Centre/Colonne/Invitation/Code
@onready var bouton_copier: Button = $Centre/Colonne/Invitation/CopierLien
@onready var bouton_demarrer: Button = $Centre/Colonne/Demarrer
@onready var bouton_retour: Button = $BoutonRetour

## Vrai une fois la manche lancée : plus rien ne se décide ici pendant le changement de scène.
var _lance := false
## Actions tenues : une action n'agit qu'à l'appui, pas à la répétition du clavier ni tant que le
## stick reste penché (chaque mouvement du stick au-delà de la zone morte est un nouvel événement) ;
## relevées à l'ouverture (phase 18, M3 de la revue finale 13 : un stick déjà penché en arrivant, d'une
## manche ou de l'écran Résultats, n'agit pas une fois de lui-même).
var _tenues: Dictionary[StringName, bool] = {}


func _ready() -> void:
	# Au retour de l'écran Résultats (phase 18), l'arbre est encore en pause (la fin de manche l'a figé).
	get_tree().paused = false
	for action in ACTIONS:
		_tenues[action] = Input.is_action_pressed(action)
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
	for i in range(EtatPartie.NB_JOUEURS_MAX):
		cartes.append(_creer_carte())
	Reseau.salon_change.connect(_sur_salon_change)
	Reseau.manche_lancee.connect(_sur_manche_lancee)
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	Parametres.langue_changee.connect(_sur_langue_changee)
	if not Reseau.en_ligne():
		# L'hôte est parti entre l'inscription et l'arrivée ici : son signal n'a trouvé personne.
		_revenir_a_l_ecran_en_ligne.call_deferred(Reseau.raison_perte)
		return
	if multiplayer.is_server():
		Reseau.ouvrir_salon(GameState.niveau_courant)
	_sur_salon_change()


## M9 de la revue finale (phase 18) : la fenêtre perd le focus (alt-tab...) avec une touche tenue, dont
## le relâchement (hors focus) n'arrive jamais ici ; sans ceci, la reprise du focus la croirait tenue
## depuis toujours et un premier appui réel n'agirait pas.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_tenues.clear()


## Les autoloads survivent au salon : ne rien leur laisser. Ne quitte pas le réseau : la scène de
## jeu prend la suite d'une manche lancée ; seuls Retour et un hôte perdu le quittent.
func _exit_tree() -> void:
	Reseau.salon_change.disconnect(_sur_salon_change)
	Reseau.manche_lancee.disconnect(_sur_manche_lancee)
	Reseau.hote_perdu.disconnect(_sur_hote_perdu)
	Parametres.langue_changee.disconnect(_sur_langue_changee)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		retour()
		return
	for action in ACTIONS:
		if not event.is_action(action):
			continue
		var appuyee := event.is_action_pressed(action)
		if appuyee and not _tenues.get(action, false):
			get_viewport().set_input_as_handled()
			_agir(action)
		_tenues[action] = appuyee


## La couleur libre suivante (`sens` 1) ou précédente (-1), demandée à l'hôte.
func changer_couleur(sens: int) -> void:
	Reseau.demander_couleur(sens)


## L'hôte seul : le niveau suivant (`sens` 1) ou précédent (-1), en boucle.
func changer_niveau(sens: int) -> void:
	if multiplayer.is_server():
		Reseau.definir_niveau(Reseau.niveau_salon + sens)


## Prêt, ou plus prêt, demandé à l'hôte.
func basculer_pret() -> void:
	var fiche := _ma_fiche()
	if not fiche.is_empty():
		Reseau.demander_pret(not fiche.pret)


## L'hôte seul : démarre la partie. `Reseau.lancer_manche` revérifie le salon au moment même ; s'il
## refuse (un joueur parti ou repassé non prêt dans la même image que l'appui), le bouton se
## regrise avec sa raison.
func demarrer() -> void:
	if _lance or not multiplayer.is_server():
		return
	if not Reseau.lancer_manche():
		_afficher()


## Quitte le réseau (l'hôte : ses clients le voient partir) et revient à l'écran En ligne.
## `changer_scene` à faux pour les tests.
func retour(changer_scene := true) -> void:
	Reseau.quitter()
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_EN_LIGNE)


## L'hôte : met le lien d'invitation de sa salle dans le presse-papiers (spec §4.4). Sur le Web, l'API du
## presse-papiers exige le geste d'un clic : c'est le clic sur le bouton qui appelle ceci. Le bouton dit
## « Lien copié ! » DUREE_LIEN_COPIE secondes. Renvoie le lien copié (vide sans code de salle).
func copier_lien() -> String:
	if not CodeSalle.valide(Reseau.code_partie):
		return ""
	var lien := CodeSalle.lien(Reseau.code_partie)
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(lien)
	bouton_copier.text = "SALON_LIEN_COPIE"
	get_tree().create_timer(DUREE_LIEN_COPIE).timeout.connect(_remettre_bouton_copier)
	return lien


func _remettre_bouton_copier() -> void:
	bouton_copier.text = "SALON_COPIER_LIEN"


func _agir(action: StringName) -> void:
	match action:
		&"deplacer_gauche":
			changer_couleur(-1)
		&"deplacer_droite":
			changer_couleur(1)
		&"deplacer_haut":
			changer_niveau(-1)
		&"deplacer_bas":
			changer_niveau(1)
		&"vomir":
			basculer_pret()
		&"demarrer":
			demarrer()


## La fiche de ce poste dans la table du salon (vide tant que la table ne l'a pas).
func _ma_fiche() -> Dictionary:
	for fiche in Reseau.table_salon:
		if fiche.id == multiplayer.get_unique_id():
			return fiche
	return {}


## Le niveau du salon devient celui de la partie : chaque poste chargera ce niveau. Pas pendant un
## lancement déjà
## reçu (`_lance`) : une table plus récente du canal 0, reçue la même image que `manche_lancee` mais
## avant le changement de scène différé, ne doit pas écraser le niveau de la manche qui va se jouer
## (`entrer_en_manche` l'a déjà mis à `Reseau.niveau_manche`).
func _sur_salon_change() -> void:
	if not _lance:
		GameState.niveau_courant = Reseau.niveau_salon
	_afficher()


func _sur_manche_lancee(fiches: Array[Dictionary]) -> void:
	_lance = true
	bouton_demarrer.disabled = true
	entrer_en_manche(get_tree(), fiches)


## Sur chaque poste, au lancement d'une manche (depuis le salon, ou depuis l'écran Résultats : Revanche,
## Niveau suivant, phase 18) : le niveau de la manche lancée (`Reseau.niveau_manche`, M6) devient celui de
## la partie, les règles de bataille et la table des joueurs sont branchées
## (`GameState.configurer_bataille_reseau`), puis la scène de jeu se charge.
static func entrer_en_manche(arbre: SceneTree, fiches: Array[Dictionary]) -> void:
	GameState.niveau_courant = Reseau.niveau_manche
	GameState.configurer_bataille_reseau(fiches)
	arbre.change_scene_to_file(SCENE_JEU)


func _sur_hote_perdu() -> void:
	_revenir_a_l_ecran_en_ligne(Reseau.raison_perte)


func _sur_langue_changee(_langue: String) -> void:
	_afficher()


## Retour à l'écran En ligne, qui affiche le message `cle` en arrivant.
func _revenir_a_l_ecran_en_ligne(cle: String) -> void:
	_EcranEnLigne.message_a_l_arrivee = cle
	get_tree().change_scene_to_file(SCENE_EN_LIGNE)


func _afficher() -> void:
	var par_index := {}
	for fiche in Reseau.table_salon:
		par_index[fiche.index] = fiche
	var id_local := multiplayer.get_unique_id()
	for i in range(cartes.size()):
		cartes[i].cadre.visible = i < Reseau.places_salon
		_afficher_carte(cartes[i], par_index.get(i, {}), id_local)
	var hote := multiplayer.is_server()
	titre_niveau.text = tr("SALON_NIVEAU") % tr(GameState.NIVEAUX[Reseau.niveau_salon].nom)
	aide.text = tr("SALON_AIDE_HOTE" if hote else "SALON_AIDE")
	rangee_invitation.visible = hote and not Reseau.code_partie.is_empty()
	etiquette_code.text = tr("SALON_CODE") % CodeSalle.formater(Reseau.code_partie)
	bouton_copier.visible = CodeSalle.valide(Reseau.code_partie)
	_afficher_etat()


## Une place libre : silhouette sombre, sans couleur ; une place prise : le lion teinté de la
## couleur du joueur (le même shader qu'en jeu), son pseudo dans sa couleur, Prêt ou non, le
## contour à sa couleur (plus épais pour ce poste).
func _afficher_carte(carte: Dictionary, fiche: Dictionary, id_local: int) -> void:
	var style: StyleBoxFlat = carte.style
	var lion: TextureRect = carte.lion
	var pseudo: Label = carte.pseudo
	var etat_carte: Label = carte.etat
	var badge: Label = carte.badge
	if fiche.is_empty():
		badge.text = " "
		lion.material = null
		lion.self_modulate = Color(0, 0, 0, 0.35)
		pseudo.text = tr("SALON_LIBRE")
		pseudo.add_theme_color_override("font_color", COULEUR_ATTENTE)
		etat_carte.text = " "
		style.border_color = Color(1, 1, 1, 0.15)
		style.set_border_width_all(2)
		return
	var badges := PackedStringArray()
	if fiche.id == MultiplayerPeer.TARGET_PEER_SERVER:
		badges.append(tr("SALON_HOTE"))
	if fiche.id == id_local:
		badges.append(tr("SALON_TOI"))
	badge.text = " · ".join(badges) if not badges.is_empty() else " "
	var teinte: ShaderMaterial = carte.teinte
	teinte.set_shader_parameter("couleur_joueur", fiche.couleur)
	lion.material = teinte
	lion.self_modulate = Color.WHITE
	pseudo.text = fiche.pseudo
	pseudo.add_theme_color_override("font_color", fiche.couleur)
	etat_carte.text = tr("SALON_PRET") if fiche.pret else tr("SALON_PAS_PRET")
	etat_carte.add_theme_color_override("font_color", COULEUR_PRET if fiche.pret else COULEUR_ATTENTE)
	style.border_color = fiche.couleur
	style.set_border_width_all(8 if fiche.id == id_local else 4)


## Le bouton de l'hôte et la ligne d'état. L'hôte lit ses inscrits (places réservées comprises) et
## voit pourquoi le bouton est grisé ; un client lit la table et les places réservées que l'hôte annonce
## (`Reseau.fiches_attente`) : pourquoi la partie attend, ou que l'hôte peut démarrer.
func _afficher_etat() -> void:
	var hote := multiplayer.is_server()
	var raison := Reseau.raison_attente(Reseau.fiches_attente())
	bouton_demarrer.visible = hote
	bouton_demarrer.disabled = _lance or not raison.is_empty()
	if not raison.is_empty():
		etat.text = tr(raison)
	else:
		etat.text = tr("SALON_PRET_A_DEMARRER" if hote else "SALON_ATTENTE_HOTE")


func _creer_carte() -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(10)
	var cadre := PanelContainer.new()
	cadre.custom_minimum_size = TAILLE_CARTE
	cadre.add_theme_stylebox_override("panel", style)
	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 12)
	cadre.add_child(colonne)
	var badge := _etiquette(24, COULEUR_BADGE)
	var lion := TextureRect.new()
	lion.texture = TEXTURE_LION
	lion.custom_minimum_size = Vector2(256, 256)
	lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var teinte := ShaderMaterial.new()  # une par carte : jamais partagée
	teinte.shader = SHADER_TEINTE
	var pseudo := _etiquette(POLICE_PSEUDO, Color.WHITE)
	var etat_carte := _etiquette(28, COULEUR_ATTENTE)
	for noeud: Control in [badge, lion, pseudo, etat_carte]:
		colonne.add_child(noeud)
	rangee_cartes.add_child(cadre)
	return {"cadre": cadre, "style": style, "badge": badge, "lion": lion, "teinte": teinte, "pseudo": pseudo, "etat": etat_carte}


## Une étiquette centrée, jamais traduite d'elle-même (les textes sont traduits ici, et un pseudo
## comme « PAUSE » n'est pas une clé), coupée au bord de sa carte plutôt que de l'élargir.
func _etiquette(taille: int, couleur: Color) -> Label:
	var etiquette := Label.new()
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.add_theme_font_size_override("font_size", taille)
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.add_theme_color_override("font_outline_color", COULEUR_CONTOUR)
	etiquette.add_theme_constant_override("outline_size", 6)
	return etiquette
