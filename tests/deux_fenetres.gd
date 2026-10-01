extends SceneTree
## Une partie à deux vraies fenêtres sur ce poste (◉, phases 14 et 19 ; la CI la déroule sans rendu (pas « Captures »)) : un hôte
## et un client passent par l'écran En ligne et le salon, jouent une manche courte au clavier simulé,
## voient le même écran Résultats, puis l'hôte quitte et le client le voit partir. Deux processus :
##   godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=<dossier>
##   godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier=<dossier>
## (dans n'importe quel ordre : le client attend que l'hôte héberge). Chaque fenêtre capture sa vue au même instant que l'autre (fichiers
## de rendez-vous dans le dossier) : `hote_*.png`, `client_*.png`. Sans rendu (headless), le déroulé seul
## se vérifie, rien n'est écrit. N'utilise ni le port 7777 d'une vraie partie, ni les records
## et réglages du joueur.

const PORT := 17990
## La manche, raccourcie sur les deux postes (le chrono de l'hôte la termine ; celui du client s'affiche).
const DUREE_MANCHE := 15.0

var dossier := ""
var role := ""
## L'instant de lancement de ce processus (epoch Unix) : un fichier de rendez-vous plus
## ancien (d'un tour précédent dans le même `--dossier`) ne compte pas comme passé.
var debut_epoch := 0.0


func _init() -> void:
	debut_epoch = Time.get_unix_time_from_system()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
		elif arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	call_deferred("_run")


func _attendre(condition: Callable, secondes := 30.0) -> bool:
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		await process_frame
	return condition.call()


func _pause(secondes: float) -> void:
	await create_timer(secondes, true).timeout


func _scene_est(nom: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://Scenes/%s.tscn" % nom and current_scene.is_node_ready()


func _shot(nom: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("📸 %s_%s (headless : rien d'écrit)" % [role, nom])
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var chemin := dossier.path_join("%s_%s.png" % [role, nom])
	image.save_png(chemin)
	print("📸 %s (%dx%d, fenêtre %s)" % [chemin, image.get_width(), image.get_height(), DisplayServer.window_get_size()])


## Ce poste a passé l'étape `nom` : un fichier de rendez-vous dans le dossier.
func _signaler(nom: String) -> void:
	FileAccess.open(dossier.path_join("%s_%s" % [role, nom]), FileAccess.WRITE).store_string("ok")


## Attend que l'autre poste ait passé l'étape `nom` (30 s au plus). N'accepte un fichier de
## rendez-vous existant que s'il date d'au plus tôt le lancement de ce poste (moins 1 s) :
## sinon c'est un fichier d'un tour précédent dans le même `--dossier`, laissé par `_signaler`.
func _attendre_l_autre(nom: String) -> void:
	var autre := "client" if role == "hote" else "hote"
	var chemin := dossier.path_join("%s_%s" % [autre, nom])
	var frais := func() -> bool:
		return FileAccess.file_exists(chemin) and FileAccess.get_modified_time(chemin) >= debut_epoch - 1
	if not await _attendre(frais):
		printerr("❌ l'autre poste n'a pas passé l'étape « %s »" % nom)


## Supprime les fichiers de rendez-vous que CE poste a lui-même écrits (jamais ceux de
## l'autre, ni ses captures : un rendez-vous n'a pas d'extension) : appelé au tout début (un tour
## précédent dans le même dossier) et après `fin`.
func _nettoyer_mes_fichiers() -> void:
	var dir := DirAccess.open(dossier)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.begins_with(role + "_") and f.get_extension().is_empty():
			dir.remove(f)
		f = dir.get_next()
	dir.list_dir_end()


## Les deux postes au même point.
func _rendez_vous(nom: String) -> void:
	_signaler(nom)
	await _attendre_l_autre(nom)


func _run() -> void:
	if dossier.is_empty() or not role in ["hote", "client"]:
		printerr("--role=hote|client et --dossier=<chemin>")
		quit(1)
		return
	_nettoyer_mes_fichiers()
	var reseau: Node = root.get_node("Reseau")
	var scores: Node = root.get_node("Scores")
	var gs: Node = root.get_node("GameState")
	scores.chemin = "user://scores_deux_fenetres_%s.cfg" % role
	scores.effacer()
	root.get_node("Parametres").definir_langue("fr")
	ReglesBataille.duree_manche = DUREE_MANCHE
	# Une fenêtre, même si les réglages de ce poste demandent le plein écran (préférence non modifiée) :
	# `Regles.appliquer_ecran` ne règle que les fenêtres.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _pause(0.5)
	DisplayServer.window_set_position(Vector2i(20, 40) if role == "hote" else Vector2i(740, 440))
	DisplayServer.window_set_size(Vector2i(700, 227))  # la fenêtre du solo, en plus petit : deux tiennent à l'écran

	# L'écran En ligne, puis le salon
	change_scene_to_file("res://Scenes/EcranEnLigne.tscn")
	await _attendre(func() -> bool: return _scene_est("EcranEnLigne"))
	var ecran: Node = current_scene
	ecran.port_jeu = PORT
	ecran.champ_pseudo.text = "Hôte" if role == "hote" else "Invitée"
	if role == "hote":
		ecran.creer_partie()
		_signaler("heberge")
	else:
		await _attendre_l_autre("heberge")
		ecran.champ_code.text = "127.0.0.1:%d" % PORT
		ecran.rejoindre()
	await _attendre(func() -> bool: return _scene_est("Salon"))
	var salon: Node = current_scene
	if role == "hote":
		await _attendre(func() -> bool: return reseau.table_salon.size() == 2)
	salon.basculer_pret()
	await _pause(0.5)
	await _shot("0_salon")
	if role == "hote":
		await _attendre(func() -> bool: return not salon.bouton_demarrer.disabled)
		salon.demarrer()

	# La manche : descendre vers la ville, puis la peindre vers l'autre joueur
	await _attendre(func() -> bool: return _scene_est("Main"))
	var main: Node = current_scene
	await _attendre(func() -> bool: return gs.pret)
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - 233.0
	Input.action_press("deplacer_bas")
	await _attendre(func() -> bool: return main.lion != null and main.lion.position.y >= cible, 5.0)
	Input.action_release("deplacer_bas")
	var sens := "deplacer_droite" if role == "hote" else "deplacer_gauche"
	Input.action_press(sens)
	Input.action_press("vomir")
	await _pause(1.5)
	await _rendez_vous("en_vol")
	await _shot("1_manche")
	await _pause(1.5)
	Input.action_release(sens)
	Input.action_release("vomir")
	await _pause(1.0)
	await _rendez_vous("peint")
	await _shot("2_ville_peinte")
	if role == "hote":
		main.menu_pause.ouvrir()
		await _pause(0.3)
		await _shot("3_menu_local")
		main.menu_pause.reprendre()

	# La fin au chrono de l'hôte : le même écran Résultats sur les deux postes
	await _attendre(func() -> bool: return main.resultats != null, DUREE_MANCHE + 10.0)
	await _pause(0.3)
	main.resultats.terminer_animation()
	await _pause(0.3)
	await _rendez_vous("resultats")
	await _shot("4_resultats")

	# L'hôte quitte ; le client le voit partir, puis revient au titre
	await _rendez_vous("fin")
	if role == "hote":
		reseau.quitter()
		await _pause(0.5)
	else:
		await _attendre(func() -> bool: return main.get_node_or_null("HotePerdu") != null, 10.0)
		await _pause(0.2)
		await _shot("5_hote_perdu")
		await _attendre(func() -> bool: return _scene_est("Titre"), 5.0)
		await _pause(0.3)
		await _shot("6_titre")
	ReglesBataille.duree_manche = ReglesBataille.DUREE_MANCHE
	scores.effacer()
	# Après `fin` (et non juste après, pour laisser à l'autre poste le temps de la voir avant
	# qu'elle disparaisse : sinon une course entre sa détection et cette suppression) : ne pas
	# laisser de fichiers de rendez-vous pour un tour suivant dans le même `--dossier`.
	_nettoyer_mes_fichiers()
	quit(0)
