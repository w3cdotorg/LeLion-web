extends SceneTree
## Captures pilotées, avec le vrai rendu (pas headless en local ; la CI les déroule sans rendu (pas « Captures »)) :
##   godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=<dossier> [--parties=solo,reseau,salon,bataille,resultats,mobile]
## Écrit ses PNG dans <dossier> (défaut : user://), par partie (toutes par défaut) :
##   solo       le titre, une partie solo (gerbe à 3 puis 7 couleurs, ennemis, pause, défaite), une
##              victoire avec record, le peintre du Village ;
##   reseau     le titre et son bouton Multijoueur, l'écran En ligne (phase 3 du jeu en ligne) : comme sur
##              le Web (accueil, code trop court, code à confusion, partie inconnue, pas de transport,
##              anglais, une page ouverte sur un lien d'invitation), puis sur le desktop de développement
##              (connexion à l'adresse d'un hôte ENet, refus de version) ;
##   salon      l'hôte seul (le code de sa salle et « Copier le lien »), le salon à 3 (bouton grisé puis
##              actif), à 6 aux pseudos larges, en anglais, vu d'un client (tous prêts, un joueur qui
##              arrive ; phase 13) ;
##   bataille   la manche à 6 couleurs (départ, en jeu : parts, rangs, couronnes, crans, gerbe XXL,
##              étourdi, parti ; les dix dernières secondes), une égalité à 2 en anglais (phase 17) ;
##   resultats  l'écran Résultats d'une bataille à 6 (animation, hôte local, client, hôte en réseau,
##              hôte resté seul), une égalité à 2 en anglais (phase 18) ;
##   mobile     ce que montre un téléphone (phase 6 du jeu en ligne, `Parametres.mobile`), le jeu à l'échelle
##              de l'écran du téléphone, bandes comprises : en paysage (844×390) l'écran En ligne (le lien,
##              puis un code refusé, sa rangée remontée au-dessus du clavier), le salon d'un client (les
##              flèches et PRÊT), la bataille (HUD, stick, VOMIR, pause), l'écran Résultats d'un client ; en
##              portrait (360×640) la bataille et l'écran Résultats sous le voile « Tourne ton téléphone » ;
##              en paysage, le menu pause d'un mobile en ligne (ses boutons à la taille d'un doigt).
## La partie à deux vraies fenêtres (un hôte et un client) est dans `tests/deux_fenetres.gd`, une vraie
## manche à 4 capturée dans `tests/bataille_test.gd -- --captures=<dossier>`.
## N'utilise ni le port 7777 d'une vraie partie, ni les records et réglages du joueur
## (`user://scores_captures.cfg`, effacé à la fin). Ennemis et pastilles écartés en bataille : les
## scores, crans, statistiques et départs sont posés à la main. Compilé avant les autoloads : les lit
## par `root.get_node`, charge les scènes à l'exécution.

const PARTIES := ["solo", "reseau", "salon", "bataille", "resultats", "mobile"]
## Les écrans de téléphone des captures `mobile` (px CSS) : en paysage, en portrait.
const PAYSAGE := Vector2i(844, 390)
const PORTRAIT := Vector2i(360, 640)
const PORT_JEU := 17890
const PORT_SANS_HOTE := 17891

var dossier := "user://"
var parties: PackedStringArray = PackedStringArray(PARTIES)
var GS: Node


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
		elif arg.begins_with("--parties="):
			parties = arg.trim_prefix("--parties=").split(",", false)
	call_deferred("_run")


func _attendre(secondes: float) -> void:
	await create_timer(secondes, true).timeout


func _shot(nom: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("📸 %s (headless : rien d'écrit)" % nom)  # le déroulé seul se vérifie
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var chemin := dossier.path_join(nom + ".png")
	image.save_png(chemin)
	print("📸 %s (%dx%d)" % [chemin, image.get_width(), image.get_height()])


## Une capture de ce que montre un téléphone dont l'écran fait `ecran` : l'écran du jeu mis à son échelle,
## centré, les bandes noires autour (comme l'export Web, `canvas_resize_policy` adaptatif, l'aspect gardé).
func _shot_telephone(nom: String, ecran: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		print("📸 %s (headless : rien d'écrit)" % nom)
		return
	await RenderingServer.frame_post_draw
	var jeu := root.get_texture().get_image()
	var echelle := minf(float(ecran.x) / jeu.get_width(), float(ecran.y) / jeu.get_height())
	var taille := Vector2i(roundi(jeu.get_width() * echelle), roundi(jeu.get_height() * echelle))
	jeu.resize(taille.x, taille.y, Image.INTERPOLATE_LANCZOS)
	var image := Image.create(ecran.x, ecran.y, false, jeu.get_format())
	image.fill(Color.BLACK)
	image.blit_rect(jeu, Rect2i(Vector2i.ZERO, taille), (ecran - taille) / 2)
	var chemin := dossier.path_join(nom + ".png")
	image.save_png(chemin)
	print("📸 %s (%dx%d, le jeu à l'échelle %.3f)" % [chemin, image.get_width(), image.get_height(), echelle])


func _run() -> void:
	for partie in parties:
		if not PARTIES.has(partie):
			printerr("--parties : « %s » inconnue (%s)" % [partie, ", ".join(PARTIES)])
			quit(1)
			return
	GS = root.get_node("GameState")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_captures.cfg"
	scores.effacer()
	root.get_node("Parametres").definir_langue("fr")
	if parties.has("solo"):
		await _solo()
	# Une fenêtre au format du multi, même si les réglages de ce poste demandent le plein écran
	# (préférence non modifiée) : `Regles.appliquer_ecran` ne règle que les fenêtres.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1400, 788))
	if parties.has("reseau"):
		await _reseau()
	if parties.has("salon"):
		await _salon()
	if parties.has("bataille"):
		await _bataille()
	if parties.has("resultats"):
		await _resultats()
	if parties.has("mobile"):
		await _mobile()
	root.get_node("Parametres").definir_langue("fr")
	GS.configurer_solo()
	scores.effacer()
	quit(0)


# --- Solo ------------------------------------------------------------------------------------------


func _solo() -> void:
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _attendre(0.2)
	await _shot("00_titre")
	titre.free()
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.15)
	main.get_node("Spawner").spawn_pickup(0, Vector2(900, 250))
	await _attendre(0.1)
	await _shot("01_depart")

	var lion: CharacterBody2D = main.get_node("Lion")
	var spawner: Node = main.get_node("Spawner")
	var ville: Node2D = main.get_node("Ville")
	for i in range(3):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	await _attendre(0.1)
	lion.global_position = Vector2(500, ville.position.y - 330)
	Input.action_press("vomir")
	await _attendre(1.00)
	await _shot("02_vomi_droite_3_couleurs")
	Input.action_press("deplacer_droite")
	await _attendre(1.50)
	Input.action_release("deplacer_droite")
	Input.action_release("vomir")
	await _attendre(0.1)
	for i in range(3, 7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	Input.action_press("deplacer_gauche")
	await _attendre(0.1)
	Input.action_press("vomir")
	await _attendre(0.83)
	Input.action_release("deplacer_gauche")
	spawner.spawn_soucoupe(300)
	spawner.spawn_coccinelle(250)
	spawner.spawn_bonus(Vector2(1300, 220))
	spawner.spawn_coeur(Vector2(1600, 300))
	GS.joueur_local().activer_bonus(8.0)
	GS.regles.lion_touche_par_ennemi(GS.joueur_local(), Vector2.INF)
	GS.joueur_local().invulnerable_restant = 0.0
	await _attendre(0.75)
	await _shot("03_vomi_gauche_7_couleurs_ennemis")
	Input.action_release("vomir")
	main.get_node("PauseMenu").ouvrir()
	await _attendre(0.2)
	await _shot("03b_pause")
	main.get_node("PauseMenu").reprendre()
	GS.terminer_partie(false)
	await _attendre(3.5)
	await _shot("04_game_over")

	# Victoire avec record précédent, un coup encaissé en route
	paused = false
	main.free()
	root.get_node("Scores").effacer()
	root.get_node("Scores").enregistrer("skyline/facile", 95.0)
	GS.niveau_courant = 0
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.2)
	for i in range(7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	# Phase 19 : le coup après la fin de l'intro (`GameState.demarrer`) ; pendant l'intro, les règles
	# l'ignorent (la manche n'est pas encore en cours).
	while not GS.pret:
		await process_frame
	GS.temps_ecoule = 71.0
	GS.regles.lion_touche_par_ennemi(GS.joueur_local(), Vector2.INF)
	GS.signaler_progression(0.91)
	await _attendre(1.2)
	await _shot("04b_victoire_animation")
	await _attendre(3.0)
	await _shot("04b_victoire")
	root.get_node("Scores").effacer()
	paused = false
	main.free()

	# Village : le boss au centre
	GS.niveau_courant = 2
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.2)
	var boss: Node = get_first_node_in_group("boss")
	for i in range(7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	main.get_node("Lion").global_position = Vector2(1500, 150)
	boss.cote = 1
	boss._changer_etat(boss.Etat.ENTREE)
	await _attendre(3.2)
	Input.action_press("vomir")
	await _attendre(0.8)
	await _shot("05_village_boss")
	Input.action_release("vomir")
	main.free()
	current_scene = null


# --- Écran En ligne (phase 3 du jeu en ligne) --------------------------------------------------------


func _reseau() -> void:
	var scores: Node = root.get_node("Scores")
	var params: Node = root.get_node("Parametres")
	var reseau: Node = root.get_node("Reseau")
	scores.definir_preference("pseudo", "MMMMMMMMMMMM")  # 12 caractères larges : le champ doit les tenir

	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _attendre(0.3)
	await _shot("reseau_00_titre_multijoueur")
	titre.bouton_multijoueur.grab_focus()
	await _attendre(0.1)
	await _shot("reseau_01_titre_focus_multijoueur")
	titre.free()

	# Comme sur le Web : un code de salle
	var ecran: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran.port_jeu = PORT_JEU
	ecran.codes_de_salle = true
	root.add_child(ecran)
	await _attendre(0.3)
	await _shot("reseau_02_accueil")
	ecran.champ_code.text = "K7Q2X"
	ecran.rejoindre()
	await _attendre(0.1)
	await _shot("reseau_03_code_trop_court")
	ecran.champ_code.text = "K0Q-2XM"
	ecran.rejoindre()
	await _attendre(0.1)
	await _shot("reseau_04_code_confusion")
	ecran.champ_code.text = "K7Q-2XM"
	reseau.raison_echec = Transport.ECHEC_INCONNUE  # ce que dira TransportWebRTC d'un code sans salle (phase 4)
	reseau.connexion_echouee.emit()
	reseau.raison_echec = ""
	await _attendre(0.1)
	await _shot("reseau_05_partie_inconnue")
	reseau.transport_disponible = false
	ecran.creer_partie()
	reseau.transport_disponible = true
	await _attendre(0.1)
	await _shot("reseau_06_pas_de_transport")
	params.definir_langue("en")
	ecran.champ_code.text = "K7Q2X"
	ecran.rejoindre()
	await _attendre(0.2)
	await _shot("reseau_07_anglais")
	params.definir_langue("fr")
	ecran.free()

	# Une page ouverte sur un lien d'invitation (`?salle=K7Q2XM`) : le code rempli, Rejoindre au focus
	var ecran_lien: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran_lien.codes_de_salle = true
	ecran_lien.code_a_l_arrivee = "K7Q2XM"
	root.add_child(ecran_lien)
	await _attendre(0.3)
	await _shot("reseau_08_lien")
	ecran_lien.free()

	# Le desktop de développement : l'adresse d'un hôte ENet
	var ecran_dev: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran_dev.port_jeu = PORT_JEU
	root.add_child(ecran_dev)
	ecran_dev.champ_code.text = "127.0.0.1:%d" % PORT_SANS_HOTE
	ecran_dev.rejoindre()
	await _attendre(0.3)
	await _shot("reseau_09_connexion_desktop")
	reseau.quitter()
	reseau.refuse.emit(reseau.REFUS_VERSION, "0.10")
	await _attendre(0.1)
	await _shot("reseau_10_refus_version")
	ecran_dev.free()


# --- Salon (phase 13) ------------------------------------------------------------------------------


## Un autre joueur arrive au salon de l'hôte (simulé dans `Reseau.inscrits`, comme le smoke test).
func _arrive(reseau: Node, id: int, index: int, couleur: Color, pseudo: String, pret: bool) -> void:
	reseau.inscrits[id] = {"index": index, "couleur": couleur, "pseudo": pseudo, "arrive": false, "pret": false}
	reseau._sur_pair_connecte(id)
	if pret:
		reseau.definir_pret(id, true)


func _salon() -> void:
	var params: Node = root.get_node("Parametres")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	GS.niveau_courant = 1

	# L'hôte seul, pseudo de 12 caractères larges : Démarrer grisé, « Il faut au moins 2 joueurs » ; le code
	# d'une salle de la signalisation (le Web, phase 4) et « Copier le lien »
	reseau.pseudo = "MMMMMMMMMMMM"
	reseau.heberger(PORT_JEU)
	reseau.code_partie = "K7Q2XM"
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await _attendre(0.4)
	await _shot("salon_00_hote_seul")

	# ◉ Salon à 3 : l'hôte, Bob prêt, Zoé pas encore : Démarrer grisé avec sa raison
	_arrive(reseau, 5, 1, palette[1], "Bob", true)
	_arrive(reseau, 6, 2, palette[4], "Zoé", false)
	await _attendre(0.2)
	await _shot("salon_01_a_3")

	# Tous prêts : Démarrer s'active chez l'hôte
	reseau.definir_pret(1, true)
	reseau.definir_pret(6, true)
	await _attendre(0.3)
	await _shot("salon_02_bouton_actif")
	reseau.definir_pret(6, false)
	await _attendre(0.2)

	# Six joueurs, pseudos larges, niveau Village
	_arrive(reseau, 7, 3, palette[3], "WWWWWWWWWWWW", true)
	_arrive(reseau, 8, 4, palette[2], "Chloé", false)
	_arrive(reseau, 9, 5, palette[5], "Léa-Marie 2", true)
	salon.changer_niveau(1)
	await _attendre(0.2)
	await _shot("salon_03_a_6")
	params.definir_langue("en")
	await _attendre(0.2)
	await _shot("salon_04_anglais")
	params.definir_langue("fr")
	salon.retour(false)
	salon.free()

	# Un client : sa vue de la table (celle que l'hôte lui diffuserait)
	reseau.rejoindre("127.0.0.1", PORT_SANS_HOTE)
	var id_local: int = root.multiplayer.get_unique_id()
	reseau.table_salon.assign([
		{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Hôte", "pret": true},
		{"id": id_local, "index": 1, "couleur": palette[3], "pseudo": "Moi", "pret": false},
		{"id": 12, "index": 3, "couleur": palette[5], "pseudo": "Tom", "pret": true}])
	reseau.niveau_salon = 0
	var client: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(client)
	await _attendre(0.4)
	await _shot("salon_05_client")
	reseau.table_salon[1].pret = true
	reseau.salon_change.emit()
	await _attendre(0.2)
	await _shot("salon_06_client_tous_prets")
	# Phase 18 : un joueur arrive encore (une place réservée, sans carte) : le client le sait
	reseau.places_reservees = 1
	reseau.salon_change.emit()
	await _attendre(0.2)
	await _shot("salon_07_client_joueur_qui_arrive")
	client.free()
	reseau.quitter()


# --- Bataille et Résultats (phases 17 et 18) ---------------------------------------------------------


## Donne à chaque joueur `parts[i]` cellules peignables de la ville (comptées), par le même chemin
## qu'un client (`Territoire.appliquer_changements`).
func _poser_scores(territoire: Territoire, parts: Array) -> void:
	var cellules: Array[int] = []
	for c in range(territoire.taille_grille.x * territoire.taille_grille.y):
		if territoire._peignables[c] == 1:
			cellules.append(c)
	var octets := PackedByteArray()
	var k := 0
	for i in range(parts.size()):
		for n in range(parts[i]):
			var o := octets.size()
			octets.resize(o + 3)
			octets.encode_u16(o, cellules[k])
			octets.encode_u8(o + 2, i + 1)
			k += 1
	territoire.appliquer_changements(octets)


## Une bataille locale à `nb` (ce poste est l'hôte, le joueur 1 est « TOI ») sur le niveau `niveau`,
## ennemis et pastilles écartés à chaque image, jusqu'à la fin de l'intro.
func _charger(nb: int, pseudos: Array, niveau: int) -> Node:
	paused = false
	GS.niveau_courant = niveau
	GS.difficulte_courante = 0
	GS.configurer_bataille(nb)
	for i in range(nb):
		GS.joueurs[i].pseudo = pseudos[i]
	change_scene_to_file("res://Scenes/Main.tscn")
	await _attendre(0.3)
	var main: Node = current_scene
	if not physics_frame.is_connected(_ecarter_ennemis):
		physics_frame.connect(_ecarter_ennemis)
	while not GS.pret:
		await process_frame
	return main


func _ecarter_ennemis() -> void:
	for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss") + get_nodes_in_group("pickup"):
		ennemi.queue_free()


func _poser_lions(main: Node, places: Array) -> void:
	for i in range(main.lions.size()):
		var l: Node2D = main.lions[i]
		l.global_position = places[i]
		l.deplacement.vitesse = Vector2.ZERO
		l.deplacement.recul = Vector2.ZERO


func _quitter_la_bataille() -> void:
	physics_frame.disconnect(_ecarter_ennemis)
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	GS.configurer_solo()


func _bataille() -> void:
	var params: Node = root.get_node("Parametres")
	var main := await _charger(6, ["Clément", "WWWWWWWWWWWW", "Zoé", "Bob", "Léa-Marie 2", "Max"], 1)
	var t: Territoire = main.ville.territoire
	_poser_lions(main, [Vector2(150, 520), Vector2(620, 600), Vector2(700, 600), Vector2(1250, 450), Vector2(1600, 300), Vector2(1864, 700)])
	await _attendre(0.3)
	await _shot("bataille_01_depart_a_6")

	# ◉ Manche à 6 couleurs : des parts de la ville, des crans, une gerbe XXL, un étourdi, un parti ;
	# deux lions côte à côte
	_poser_scores(t, [260, 410, 180, 90, 410, 30])
	for i in range(3):
		GS.joueurs[0].gagner_cran()
	for i in range(6):
		GS.joueurs[1].gagner_cran()
	GS.joueurs[4].gagner_cran()
	GS.regles.etoile_ramassee(GS.joueurs[0])
	GS.regles.lion_touche_par_ennemi(GS.joueurs[3], Vector2.INF)
	main.hud_bataille.marquer_parti(5)
	var parti: Node = main.lions[5]
	main._oublier_lion(parti)  # comme un départ en réseau : son lion disparaît
	parti.queue_free()
	GS.temps_ecoule = 41.2
	await _attendre(0.4)
	_poser_lions(main, [Vector2(150, 520), Vector2(620, 600), Vector2(712, 600), Vector2(1250, 450), Vector2(1600, 300)])
	await _attendre(0.1)
	await _shot("bataille_02_en_jeu_a_6")

	# Les dix dernières secondes : le chrono rouge
	GS.temps_ecoule = 84.35
	await _attendre(0.2)
	await _shot("bataille_03_dix_dernieres_secondes")

	# À deux, ex æquo, en anglais
	params.definir_langue("en")
	main = await _charger(2, ["Anna", "Bruno"], 0)
	_poser_lions(main, [Vector2(0, 500), Vector2(95, 500)])
	_poser_scores(main.ville.territoire, [300, 300])
	GS.temps_ecoule = 60.0
	await _attendre(0.3)
	await _shot("bataille_04_egalite_a_2_anglais")
	params.definir_langue("fr")
	_quitter_la_bataille()


## Un autre écran Résultats sur la même fin, vu d'un autre poste (`hote`, `en_reseau`), à la place du
## premier.
func _revoir(main: Node, hote: bool, en_reseau: bool) -> CanvasLayer:
	var bilan: BilanManche = main.resultats.bilan
	main.resultats.free()
	var vue: CanvasLayer = load("res://Scenes/Resultats.tscn").instantiate()
	main.add_child(vue)
	main.resultats = vue
	vue.afficher(bilan, hote, en_reseau)
	vue.terminer_animation()
	return vue


func _resultats() -> void:
	var params: Node = root.get_node("Parametres")
	var main := await _charger(6, ["Clément", "WWWWWWWWWWWW", "Zoé", "Bob", "Léa-Marie 2", "Max"], 1)
	_poser_scores(main.ville.territoire, [260, 410, 180, 90, 410, 30])
	var stats := [[3, 120, 9], [5, 340, 4], [0, 60, 12], [1, 0, 2], [5, 280, 4], [0, 0, 1]]
	for i in range(6):
		GS.joueurs[i].etourdissements_infliges = stats[i][0]
		GS.joueurs[i].cellules_volees = stats[i][1]
		GS.joueurs[i].chocs = stats[i][2]
	main.hud_bataille.marquer_parti(5)
	GS.temps_ecoule = 89.5
	while GS.partie_en_cours:
		await process_frame
	await _attendre(0.9)
	await _shot("resultats_01_animation")
	main.resultats.marquer_parti(5)
	await _attendre(3.0)
	await _shot("resultats_02_hote_local_a_6")
	var vue := _revoir(main, false, true)
	vue.marquer_parti(5)
	await _attendre(0.3)
	await _shot("resultats_03_client")
	vue = _revoir(main, true, true)
	vue.marquer_parti(5)
	vue._deplacer_selection(1)
	await _attendre(0.3)
	await _shot("resultats_04_hote_reseau_niveau_suivant")
	for i in range(1, 5):
		vue.marquer_parti(i)
	await _attendre(0.3)
	await _shot("resultats_05_hote_seul")
	params.definir_langue("en")
	main = await _charger(2, ["Anna", "Bruno"], 2)
	_poser_scores(main.ville.territoire, [300, 300])
	GS.joueurs[0].chocs = 6
	GS.joueurs[1].chocs = 6
	GS.temps_ecoule = 89.5
	while GS.partie_en_cours:
		await process_frame
	_revoir(main, true, true)
	await _attendre(0.3)
	await _shot("resultats_06_egalite_a_2_anglais")
	params.definir_langue("fr")
	_quitter_la_bataille()


# --- Mobiles (phase 6 du jeu en ligne) ---------------------------------------------------------------


## La fenêtre à la taille d'un écran de téléphone `ecran` (le voile suit son format) ; le voile relu tout
## de suite (sans fenêtre, en headless, rien ne change de taille).
func _tenir(ecran: Vector2i) -> void:
	DisplayServer.window_set_size(ecran)
	root.get_node("Parametres").actualiser_voile(ecran)
	await _attendre(0.2)


func _mobile() -> void:
	var params: Node = root.get_node("Parametres")
	var scores: Node = root.get_node("Scores")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	params.mobile = true
	await _tenir(PAYSAGE)

	# L'écran En ligne ouvert par un lien, le pseudo mémorisé : Rejoindre au focus, sans Créer une partie ;
	# puis un code refusé : le code en édition, sa rangée en haut, le message dessous (le clavier couvre le bas)
	scores.definir_preference("pseudo", "Léa")
	var ecran: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran.codes_de_salle = true
	ecran.code_a_l_arrivee = "K7Q2XM"
	root.add_child(ecran)
	await _attendre(0.3)
	await _shot_telephone("mobile_00_en_ligne", PAYSAGE)
	ecran.champ_code.text = "K7Q2X"
	ecran.rejoindre()
	await _attendre(0.2)
	await _shot_telephone("mobile_01_en_ligne_clavier", PAYSAGE)
	ecran.free()
	scores.definir_preference("pseudo", "")

	# Le salon d'un client : les flèches de la couleur et PRÊT, l'aide du tactile, Retour agrandi
	reseau.rejoindre("127.0.0.1", PORT_SANS_HOTE)
	var id_local: int = root.multiplayer.get_unique_id()
	reseau.table_salon.assign([
		{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Hôte", "pret": true},
		{"id": id_local, "index": 1, "couleur": palette[3], "pseudo": "Léa", "pret": false},
		{"id": 12, "index": 2, "couleur": palette[5], "pseudo": "Tom", "pret": true}])
	reseau.niveau_salon = 0
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await _attendre(0.4)
	await _shot_telephone("mobile_02_salon", PAYSAGE)
	salon.free()
	reseau.quitter()

	# La bataille (le HUD, le stick, VOMIR, la pause), puis l'écran Résultats d'un client
	var main := await _charger(4, ["Hôte", "Léa", "Tom", "WWWWWWWWWWWW"], 1)
	_poser_lions(main, [Vector2(300, 520), Vector2(800, 600), Vector2(1250, 450), Vector2(1600, 300)])
	_poser_scores(main.ville.territoire, [260, 410, 180, 90])
	GS.temps_ecoule = 41.2
	await _attendre(0.4)
	await _shot_telephone("mobile_03_bataille", PAYSAGE)
	# Le menu pause d'un mobile en ligne (ce poste héberge le temps de la capture ; le menu, ouvert sur la
	# bataille, ne la met pas en pause) : ses boutons à la taille d'un doigt, sans « Échap pour reprendre »
	reseau.heberger(PORT_JEU)
	var pause: CanvasLayer = load("res://Scenes/PauseMenu.tscn").instantiate()
	main.add_child(pause)
	pause.ouvrir()
	await _attendre(0.2)
	await _shot_telephone("mobile_07_pause", PAYSAGE)
	pause.free()
	reseau.quitter()
	await _tenir(PORTRAIT)
	await _shot_telephone("mobile_04_portrait_bataille", PORTRAIT)
	await _tenir(PAYSAGE)
	GS.temps_ecoule = 89.5
	while GS.partie_en_cours:
		await process_frame
	var vue := _revoir(main, false, true)
	await _attendre(0.3)
	await _shot_telephone("mobile_05_resultats", PAYSAGE)
	await _tenir(PORTRAIT)
	await _shot_telephone("mobile_06_portrait_resultats", PORTRAIT)
	vue.free()
	_quitter_la_bataille()
	params.mobile = false
	await _tenir(Vector2i(1400, 788))
