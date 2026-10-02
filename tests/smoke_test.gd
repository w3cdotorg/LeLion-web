extends SceneTree
## Test de fumée headless : godot --headless --script tests/smoke_test.gd
## Charge Main, débloque une couleur, fait vomir le lion sur la ville, vérifie la
## peinture, puis fait apparaître un ennemi sur le lion et vérifie la défaite.

var _echecs := 0
var GS: Node
var JL: Joueur  # le joueur local (unique en solo)
## Les sons joués par `Audio` (un lecteur par son, ajouté comme enfant), par nom de fichier :
## `_sons.count("pickup")` compte les sons de ramassage.
var _sons: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _frames(n: int) -> void:
	for i in range(n):
		await physics_frame


## Attend que `current_scene` devienne celle attendue, après un `change_scene_to_file` (différé :
## la bascule se fait à une image d'écart, mais pas forcément après un nombre fixe d'images
## *physiques* — sous charge CPU (CI), la physique rattrape son retard par rafales, si bien que
## quelques `physics_frame` peuvent s'écouler avant même que le moteur ait traité l'image où la
## bascule est différée). Bornée par `max_ms`, jamais une attente à l'aveugle : renvoie
## `current_scene` dès qu'il correspond, ou tel quel au bout du délai (l'appelant garde son
## `_check`, qui échoue alors normalement plutôt que de planter).
func _attendre_scene(chemin: String, max_ms: int = 5000) -> Node:
	var fin := Time.get_ticks_msec() + max_ms
	while (current_scene == null or current_scene.scene_file_path != chemin) and Time.get_ticks_msec() < fin:
		await process_frame
	return current_scene


## Couleurs présentes sur une image (pixels non transparents), en clés `to_rgba32()`. À comparer
## à `_rgba8(couleur)`, pas à `couleur.to_rgba32()` : une image RGBA8 tronque chaque composante
## sur 8 bits (les nuances d'un joueur de bataille ne sont pas exactement représentables).
func _couleurs_peintes(image: Image) -> Dictionary:
	var couleurs := {}
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.0:
				couleurs[c.to_rgba32()] = true
	return couleurs


## Chaque lecteur ajouté à `Audio` : le nom du son qu'il joue (voir `_sons`).
func _noter_son(noeud: Node) -> void:
	if noeud is AudioStreamPlayer and noeud.stream != null:
		_sons.append(noeud.stream.resource_path.get_file().get_basename())


## La couleur telle qu'une image RGBA8 la stocke, en `to_rgba32()`.
func _rgba8(c: Color) -> int:
	var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	pixel.set_pixel(0, 0, c)
	return pixel.get_pixel(0, 0).to_rgba32()


func _run() -> void:
	print("== smoke test LeLion ==")
	GS = root.get_node("GameState")
	JL = GS.joueur_local()
	var scores: Node = root.get_node("Scores")
	var params: Node = root.get_node("Parametres")
	scores.chemin = "user://scores_test.cfg"
	scores.effacer()
	params.definir_langue("fr")
	root.get_node("Audio").child_entered_tree.connect(_noter_son)

	# Traductions et réglages
	_check(tr("CONTINUER") == "Continuer", "les traductions françaises sont chargées")
	params.definir_langue("en")
	_check(tr("CONTINUER") == "Resume" and tr("NIVEAU_METROPOLE") == "Metropolis", "le passage en anglais traduit les libellés")
	params.definir_langue("fr")
	params.definir_musique(0.3)
	params.definir_effets(0.0)
	_check(abs(float(scores.preference("musique", -1.0)) - 0.3) < 0.001 and float(scores.preference("effets", -1.0)) == 0.0, "les volumes sont sauvegardés")
	_check(root.get_node("Audio")._musique.volume_db < -20.0 and params.en_db(0.0) <= -80.0, "le volume s'applique à la musique, 0 = silence")
	params.definir_musique(0.7)
	params.definir_effets(1.0)
	_check(params.couche_crt != null and not params.couche_crt.visible, "le filtre CRT est présent et désactivé par défaut")
	params.definir_crt(true)
	_check(params.couche_crt.visible and bool(scores.preference("crt", false)), "activer le filtre CRT l'affiche et le sauvegarde")
	_check(params.couche_crt.get_child(0).material.shader != null, "la couche CRT porte le shader")
	params.definir_crt(false)

	# Écran titre : un bouton par niveau, lancer un niveau le sélectionne
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(titre.boutons.size() == GS.NIVEAUX.size(), "l'écran titre a un bouton par niveau (%d)" % titre.boutons.size())
	_check(titre.boutons_difficulte.size() == GS.DIFFICULTES.size(), "l'écran titre a un bouton par difficulté (%d)" % titre.boutons_difficulte.size())
	titre.choisir_difficulte(2)
	_check(GS.difficulte_courante == 2 and titre.boutons_difficulte[2].button_pressed, "choisir une difficulté la sélectionne")
	titre.choisir_difficulte(0)
	_check(tr("PAS_ENCORE_PEINT") in titre.boutons[1].text, "un niveau jamais gagné affiche « pas encore peint »")
	_check(tr("NIVEAU_METROPOLE") in titre.boutons[1].text and tr("DIFF_FACILE") in titre.boutons_difficulte[0].text, "l'écran titre affiche les noms traduits")
	# Clic souris réel sur le bouton Réglages (il doit être au-dessus du conteneur central)
	var centre_bouton: Vector2 = titre.bouton_reglages.get_global_rect().get_center()
	for presse in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = presse
		clic.position = centre_bouton
		clic.global_position = centre_bouton
		if presse:
			clic.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(clic, true)  # coordonnées du viewport, pas de la fenêtre
		await process_frame
	await process_frame
	var reglages: Node = titre.get_node_or_null("Reglages")
	_check(reglages != null and reglages.musique.has_focus(), "un clic souris sur Réglages ouvre l'écran de réglages")
	reglages._choisir_langue("en")
	await _frames(1)
	_check(params.langue == "en" and "Metropolis" in titre.boutons[1].text, "changer la langue retraduit l'écran titre")
	reglages._choisir_langue("fr")
	reglages.fermer()
	await _frames(1)
	_check(titre.get_node_or_null("Reglages") == null and titre.bouton_reglages.has_focus(), "Fermer referme les réglages et rend le focus")
	GS.niveau_courant = 1
	titre.free()

	# Préférences : la difficulté et le niveau choisis sont relus par l'écran titre
	scores.definir_preference("difficulte", 2)
	scores.definir_preference("niveau", 1)
	scores.charger()
	GS.difficulte_courante = 0
	GS.niveau_courant = 0
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(GS.difficulte_courante == 2 and titre.boutons_difficulte[2].button_pressed, "l'écran titre restaure la difficulté sauvegardée")
	_check(GS.niveau_courant == 1 and titre.boutons[1].button_pressed and not titre.boutons[0].button_pressed, "l'écran titre restaure le dernier niveau, sélectionné")
	_check(titre.bouton_jouer.has_focus(), "le bouton Jouer a le focus au départ")
	var style_selection: StyleBox = titre.boutons[1].get_theme_stylebox("pressed")
	_check(style_selection is StyleBoxFlat and style_selection.border_color == Styles.JAUNE, "le niveau sélectionné a une bordure jaune")
	titre.choisir_niveau(2)
	_check(GS.niveau_courant == 2 and int(scores.preference("niveau", -1)) == 2 and titre.boutons[2].button_pressed, "choisir un niveau le sélectionne et le sauvegarde")
	titre.choisir_difficulte(0)
	_check(int(scores.preference("difficulte", -1)) == 0, "changer de difficulté la sauvegarde")
	titre.free()
	scores.effacer()
	GS.niveau_courant = 0

	await _tester_ecran_en_ligne(scores, params)
	await _tester_titre_reseau(scores)
	await _tester_salon(params)
	await _tester_mobile(params)

	# Scores
	_check(scores.enregistrer("skyline/facile", 50.0) == 0 and scores.meilleur_temps("metropole/facile") < 0.0
		and scores.meilleur_temps("skyline/moyen") < 0.0, "un record ne compte que pour son niveau et sa difficulté")
	scores.effacer()
	_check(scores.enregistrer("test", 90.0) == 0, "premier temps enregistré = record")
	_check(scores.enregistrer("test", 120.0) == 1, "temps plus lent = rang 1")
	_check(scores.enregistrer("test", 60.0) == 0, "temps plus rapide = nouveau record")
	scores.charger()
	_check(scores.meilleur_temps("test") == 60.0, "les scores sont relus depuis le disque")
	GS.niveau_courant = 0
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(3)

	var ville: Node = main.get_node("Ville")
	var lion: CharacterBody2D = main.get_node("Lion")
	var spawner: Node = main.get_node("Spawner")
	_check(GS.partie_en_cours, "partie en cours après Main._ready")
	_check(lion.joueur == GS.joueur_local() and lion.commandes.source == Commandes.Source.LOCALES,
		"hors démo, le lion porte le joueur local et lit les commandes de ce poste")
	_check(not JL.a_une_couleur() and lion.sprite.material == null and not lion.etiquette_pseudo.visible,
		"en solo, le joueur n'a pas de couleur de lion : sprite sans matériau (rendu d'origine), pas de pseudo")
	_check(ville.territoire == null, "en solo, la ville ne tient pas de territoire : seule la couverture compte")

	# Intro « Prêt ? Vomissez ! » : le jeu attend
	_check(not GS.pret and main.get_node_or_null("Intro") != null, "l'intro s'affiche et le jeu n'est pas encore prêt")
	var position_avant: Vector2 = lion.global_position
	Input.action_press("deplacer_droite")
	await _frames(5)
	Input.action_release("deplacer_droite")
	_check(lion.global_position == position_avant, "le lion ne bouge pas pendant l'intro")
	_check(GS.temps_ecoule == 0.0, "le chrono ne tourne pas pendant l'intro")
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	_check(GS.pret, "demarrer() rend le jeu prêt")
	_check(root.get_node_or_null("Audio") != null, "autoload Audio présent")
	var audio: Node = root.get_node("Audio")
	_check(audio._musique.playing and audio._pistes[1].playing and audio._pistes[2].playing, "les trois pistes de musique tournent ensemble")
	_check(audio.ensemble_courant == "ville" and audio.intensite == 0, "en jeu, thème de la ville avec la base seule")
	_check(audio._pistes[2].volume_db < -60.0, "la mélodie est muette au départ")
	GS.signaler_progression(0.5)
	_check(audio.intensite == 1, "à mi-chemin, les arpèges entrent")
	GS.signaler_progression(0.6)
	_check(audio.intensite == 2, "aux deux tiers, la mélodie entre")
	GS.signaler_progression(0.0)
	audio.definir_intensite(0, true)

	# Contrôles tactiles : cachés sans écran tactile, le stick pilote les actions
	var tactile: CanvasLayer = main.get_node("ControlesTactiles")
	_check(tactile.visible == DisplayServer.is_touchscreen_available(), "les contrôles tactiles ne s'affichent que sur écran tactile (ici : %s)" % tactile.visible)
	var stick: Control = tactile.joystick
	stick.debut(Vector2(300, 500))
	stick.glisser(Vector2(300 + stick.rayon, 500 - stick.rayon * 0.5))
	_check(Input.get_action_strength("deplacer_droite") > 0.8 and Input.get_action_strength("deplacer_haut") > 0.3
		and Input.get_action_strength("deplacer_gauche") == 0.0, "le stick virtuel pilote les actions avec leur intensité")
	stick.fin()
	_check(Input.get_action_strength("deplacer_droite") == 0.0 and stick.vecteur == Vector2.ZERO, "relâcher le stick relâche les actions")
	_check(tactile.get_node("BoutonVomir").action == "vomir" and tactile.get_node("BoutonPause").action == "pause", "les boutons tactiles déclenchent vomir et pause")

	# Pause via l'action "pause"
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _frames(2)
	var menu_pause: CanvasLayer = main.get_node("PauseMenu")
	_check(paused and menu_pause.visible, "Échap met en pause et ouvre le menu de pause")
	_check(menu_pause.bouton_continuer.has_focus(), "le bouton Continuer a le focus")
	Input.parse_input_event(ev.duplicate())
	Input.flush_buffered_events()
	await _frames(2)
	_check(not paused and not menu_pause.visible, "Échap relance la partie")
	menu_pause.ouvrir()
	_check(paused, "ouvrir() met en pause")
	menu_pause.ouvrir_reglages()
	await _frames(1)
	_check(menu_pause.get_node_or_null("Reglages") != null, "les réglages s'ouvrent depuis la pause")
	menu_pause.get_node("Reglages").fermer()
	await _frames(1)
	menu_pause.reprendre()
	_check(not paused and not menu_pause.visible, "Continuer reprend la partie")
	var nb_cellules: int = ville.grille_taille.x * ville.grille_taille.y
	_check(ville.cellules_peignables > 0 and ville.cellules_peignables < nb_cellules,
		"cellules peignables = zones opaques de la skyline (%d / %d)" % [ville.cellules_peignables, nb_cellules])

	# Pickup : le lion marche dessus
	var sons_avant := _sons.count("pickup")
	var pickup: Node = spawner.spawn_pickup(0, lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(pickup), "le pickup disparaît au contact")
	_check(_sons.count("pickup") == sons_avant + 1 and JL.crans == 2,
		"une pastille du solo débloque une couleur et donne un cran : un seul son de ramassage (%d)" % (_sons.count("pickup") - sons_avant))
	_check(JL.couleurs_debloquees.size() == 1, "une couleur débloquée via pickup")
	_check(lion.gerbe.vomi_container.get_child_count() == 1, "un émetteur de particules par couleur")
	_check(lion.gerbe.traceuse_shape.shape.radius == 21.0, "avec une couleur, la gerbe peint sur 21 px (16 px + 5 px par couleur)")
	var hud: Node = main.get_node("HUD")
	_check(hud.indice.visible == false, "le HUD cache l'indice après la première couleur")
	_check(hud._pastilles[0].color == GS.couleur(0) and hud._pastilles[1].color != GS.couleur(1),
		"le HUD affiche la première pastille débloquée et la deuxième verrouillée")

	# Vomir sur la ville : on place le lion au-dessus de la skyline
	lion.global_position = Vector2(600, ville.position.y - 300)
	Input.action_press("vomir")
	await _frames(30)
	_check(lion.est_en_train_de_vomir, "le lion vomit tant que l'action est maintenue")
	var rayon_normal: float = lion.gerbe.traceuse_shape.shape.radius
	sons_avant = _sons.count("pickup")
	var bonus: Node = spawner.spawn_bonus(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(bonus) and JL.bonus_actif(), "l'étoile ramassée active la gerbe XXL")
	_check(_sons.count("pickup") == sons_avant + 1, "l'étoile joue le son de ramassage, par Audio (%d)" % (_sons.count("pickup") - sons_avant))
	_check(lion.gerbe.traceuse_shape.shape.radius == rayon_normal * 2.0, "le rayon de peinture est doublé pendant le bonus")
	_check(hud.etiquette_bonus.visible, "le HUD affiche le bonus")
	var etoile_solo: Node = spawner.spawn_bonus(Vector2(-500, -500))  # loin du lion : jamais ramassée
	etoile_solo._expirer()
	await _frames(1)
	_check(not is_instance_valid(etoile_solo), "en solo (son propre hôte), une étoile en fin de vie se libère elle-même")
	JL.bonus_restant = 0.01
	await create_timer(0.1).timeout
	await _frames(1)
	_check(not JL.bonus_actif() and lion.gerbe.traceuse_shape.shape.radius == rayon_normal, "le bonus expire et le rayon revient à la normale")
	_check(root.get_node("Audio")._vomi.playing, "la boucle sonore de vomi tourne")
	_check(ville.cellules_peintes > 0, "la ville a été peinte (%d cellules)" % ville.cellules_peintes)
	_check(GS.progression > 0.0, "la progression est remontée dans GameState (%.4f)" % GS.progression)
	_check(hud.progression.value > 0.0, "la barre de progression du HUD bouge")
	_check(spawner.difficulte() >= 0.0 and spawner.difficulte() <= 1.0, "difficulté bornée (%.3f)" % spawner.difficulte())
	var soucoupe: Node = spawner.spawn_soucoupe(20)
	_check(soucoupe.speed >= spawner.vitesse_soucoupe.x, "la soucoupe reçoit sa vitesse du spawner (%.0f)" % soucoupe.speed)
	var soucoupe_bis: Node = spawner.spawn_soucoupe(40)
	_check(not str(soucoupe.name).contains("@") and not str(soucoupe_bis.name).contains("@") and soucoupe.name != soucoupe_bis.name,
		"deux apparitions de la même scène ont des noms lisibles et distincts, que le MultiplayerSpawner peut répliquer (%s, %s)" % [soucoupe.name, soucoupe_bis.name])
	soucoupe.queue_free()
	soucoupe_bis.queue_free()
	Input.action_release("vomir")
	await _frames(3)
	_check(not lion.est_en_train_de_vomir, "le lion arrête de vomir quand l'action est relâchée")

	# Mode Facile : un coup enlève une vie et rend invulnérable un moment
	_check(JL.vies == 3 and hud._coeurs[2].visible, "mode Facile : 3 vies affichées")
	_check(abs(GS.seuil_victoire() - 0.85) < 0.001 and abs(hud.repere_seuil.offset_left + 1.5 - 0.85 * hud.progression.size.x) < 2.0,
		"seuil de victoire 85 %% en Facile, repère placé sur la barre")
	var coccinelle: Node = spawner.spawn_coccinelle(lion.global_position.y + 66)
	coccinelle.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(GS.partie_en_cours and JL.vies == 2, "un coup coûte une vie, la partie continue (%d vies)" % JL.vies)
	_check(JL.est_invulnerable() and absf(JL.invulnerable_restant - ReglesSolo.DUREE_INVULNERABILITE) < 0.2
		and not GS.get_script().get_script_constant_map().has("DUREE_INVULNERABILITE"),
		"le lion est invulnérable après un coup, pour la durée que fixent les règles du solo (plus GameState)")
	_check(lion.deplacement.recul.length() > 0.0, "le lion est repoussé par le coup (%.0f px/s)" % lion.deplacement.recul.length())
	_check(hud.flash.color.a > 0.0, "l'écran flashe en rouge")
	_check(main._tremblement_restant > 0.0, "la caméra tremble")
	_check(hud._coeurs[2].modulate == hud.COULEUR_COEUR_PERDU, "le HUD grise le cœur perdu")
	coccinelle.queue_free()
	var soucoupe2: Node = spawner.spawn_soucoupe(lion.global_position.y + 66)
	soucoupe2.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(JL.vies == 2, "un coup pendant l'invulnérabilité ne compte pas")
	soucoupe2.queue_free()
	JL.invulnerable_restant = 0.0

	# Cœur : rend une vie, jamais au-delà du maximum
	sons_avant = _sons.count("pickup")
	var coeur: Node = spawner.spawn_coeur(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(coeur) and JL.vies == 3, "un cœur ramassé rend une vie (%d)" % JL.vies)
	_check(_sons.count("pickup") == sons_avant + 1, "le cœur joue le son de ramassage, par Audio (%d)" % (_sons.count("pickup") - sons_avant))
	_check(not GS.regles.coeur_ramasse(JL), "impossible de dépasser le maximum de vies")

	# Défaite : trois coups, le doigt toujours sur le stick
	stick.debut(Vector2(300, 500))
	stick.glisser(Vector2(300 + stick.rayon, 500))
	JL.vies = 1
	coccinelle = spawner.spawn_coccinelle(lion.global_position.y + 66)
	coccinelle.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(not GS.partie_en_cours, "la partie se termine quand la dernière vie est perdue")
	_check(paused, "l'arbre est en pause après la défaite")
	var overlay: Node = main.get_node_or_null("GameOver")
	_check(overlay != null, "l'overlay GameOver est affiché")
	_check(overlay != null and overlay.phase_continue and overlay.compte.text == "9" and overlay.titre.text == tr("CONTINUE"),
		"la défaite commence par CONTINUE ? avec un compte à 9")
	_check(overlay != null and not overlay.stats.visible and not overlay.boutons.visible, "le bilan attend la fin du compte")
	overlay._decrementer()
	_check(overlay != null and overlay.compte.text == "8", "le compte descend")
	overlay._fin_continue()
	_check(overlay != null and not overlay.phase_continue and overlay.stats.visible, "à zéro, le bilan apparaît")
	_check(overlay != null and overlay.titre.text == tr("GAME_OVER"), "l'overlay affiche GAME OVER")
	_check(overlay != null and overlay._lignes.size() == 4 and overlay._lignes[2].cible == JL.coups_recus and JL.coups_recus == 2,
		"le bilan de défaite a 4 lignes et compte les coups reçus (%d)" % JL.coups_recus)
	_check(overlay != null and not overlay.sous_titre.visible, "pas de badge record sur une défaite")
	overlay._terminer_animation()
	_check(overlay != null and overlay._lignes[0].valeur.text == "%d %%" % int(round(GS.progression * 100)) and overlay.bouton_rejouer.has_focus(),
		"sauter l'animation affiche les valeurs finales et donne le focus")
	_check(overlay != null and not overlay.bouton_suivant.visible, "pas de bouton Niveau suivant après une défaite")

	_check(Input.get_action_strength("deplacer_droite") == 0.0, "la défaite relâche le stick virtuel")
	Input.action_press("deplacer_droite", 1.0)  # comme un doigt resté posé

	# Victoire sur le niveau Métropole : nouvelle partie, on peint toute la skyline
	paused = false
	main.queue_free()
	await _frames(2)
	GS.niveau_courant = 1
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	_check(Input.get_action_strength("deplacer_droite") == 0.0, "une nouvelle partie démarre avec les actions relâchées")
	_check(JL.couleurs_debloquees.is_empty() and main.get_node("Lion").gerbe.vomi_container.get_child_count() == 0
		and main.get_node("HUD")._pastilles[0].color == main.get_node("HUD").COULEUR_VERROUILLEE,
		"une nouvelle partie repart sans couleur : ni émetteur, ni pastille allumée")
	_check(JL.vies == 3 and JL.coups_recus == 0 and main.get_node("HUD")._coeurs[2].modulate == main.get_node("HUD").COULEUR_COEUR,
		"après une défaite, le niveau suivant repart avec tous ses cœurs affichés")
	# La défaite a laissé 0 vie ; `nouvelle_partie` en a remis 3 sans signal : un coup (3 → 2) n'est
	# pas une vie regagnée.
	sons_avant = _sons.count("pickup")
	JL.encaisser_coup(Vector2.INF, 0.0)
	_check(JL.vies == 2 and _sons.count("pickup") == sons_avant,
		"un coup au départ d'une nouvelle partie (vies remises sans signal) ne joue pas le son de ramassage")
	JL.vies = 3
	JL.coups_recus = 0
	ville = main.get_node("Ville")
	_check(ville.tex_size == Vector2i(2000, 320), "la ville a chargé la skyline du niveau Métropole (%s)" % ville.tex_size)
	GS.regles.pastille_ramassee(JL, 0)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	# un seul tampon clairsemé ne suffit pas : la couverture réelle est mesurée
	ville.peindre(Vector2(1000, haut + 200), 45, JL)
	ville.mesurer_progression()
	_check(GS.progression < 0.01, "un tampon isolé ne compte presque pas (couverture %.3f)" % GS.progression)
	for x in range(0, ville.tex_size.x, 40):
		for y in range(0, ville.tex_size.y, 40):
			ville.peindre(Vector2(x, haut + y), 45, JL)
	ville.mesurer_progression()
	await _frames(3)
	_check(GS.progression >= GS.seuil_victoire(), "progression >= seuil après avoir tout peint (%.2f)" % GS.progression)
	_check(ville.coulures.size() > 0 or ville.CHANCE_COULURE == 0.0, "des coulures de peinture sont en cours (%d)" % ville.coulures.size())
	_check(not GS.partie_en_cours and paused, "la partie se termine en victoire")
	overlay = main.get_node_or_null("GameOver")
	_check(overlay != null and overlay.titre.text == tr("VICTOIRE"), "l'overlay affiche VICTOIRE")
	var nb_confettis := 0
	for enfant in overlay.get_children():
		if enfant is GPUParticles2D:
			nb_confettis += 1
	_check(nb_confettis == 3, "la victoire lance des confettis (%d émetteurs)" % nb_confettis)
	_check(overlay != null and tr("NOUVEAU_RECORD") in overlay.sous_titre.text and overlay.sous_titre.visible, "la victoire affiche le badge Nouveau record")
	_check(overlay != null and overlay._lignes[1].commentaire.text == tr("PREMIER_TEMPS"), "premier temps sur ce niveau : pas de comparaison")
	_check(overlay != null and overlay._lignes[2].commentaire.text == tr("SANS_EGRATIGNURE"), "victoire sans coup reçu : « Sans une égratignure »")
	await create_timer(4.0).timeout
	_check(overlay != null and overlay._animation_finie and overlay.bouton_suivant.has_focus(), "l'animation du bilan se termine seule et donne le focus")
	_check(overlay != null and overlay.bouton_suivant.visible, "le bouton Niveau suivant est proposé")
	_check(scores.meilleur_temps("metropole/facile") >= 0.0, "le record est persisté par niveau et difficulté")
	scores.effacer()

	# Boss sur le niveau Village : cycle d'états accéléré et contact
	paused = false
	main.queue_free()
	await _frames(2)
	GS.niveau_courant = 2
	GS.difficulte_courante = 0
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	lion = main.get_node("Lion")
	var boss: Node = get_first_node_in_group("boss")
	_check(boss != null, "le niveau Village fait apparaître le boss")
	_check(root.get_node("Audio").ensemble_courant == "boss", "le Village joue le thème du boss")
	_check(main.get_node("Spawner")._facteur_ennemis == 2.0, "les autres ennemis sont deux fois moins fréquents avec un boss")
	var nb_polygones := 0
	for enfant in boss.get_children():
		if enfant is CollisionPolygon2D:
			nb_polygones += 1
	_check(nb_polygones > 0, "la collision du boss est générée depuis la silhouette (%d polygones)" % nb_polygones)
	_check(abs(boss.sprite.scale.y * boss.sprite.texture.get_height() - 648 * 0.65) < 1.0, "le boss fait 65 % de la hauteur de l'écran")
	_check(abs(boss.position.y + boss._demi_hauteur - boss.y_sol) < 0.5 and abs(boss.y_sol - (648 - 180)) < 0.5,
		"le boss est posé sur le haut de la skyline (bas=%.1f, sol=%.1f)" % [boss.position.y + boss._demi_hauteur, boss.y_sol])
	_check(boss.etat == boss.Etat.REPOS, "le boss commence hors écran, au repos")
	# on accélère le cycle
	var cote_initial: int = boss.cote
	boss.duree_repos = 0.05
	boss.duree_annonce = 0.05
	boss.duree_entree = 0.2
	boss.duree_pause = 0.05
	boss.duree_sortie = 0.2
	boss._changer_etat(boss.Etat.ANNONCE)
	var etats_vus: Array = []
	boss.etat_change.connect(func(e: int) -> void: etats_vus.append(e))
	lion.global_position = Vector2(1000 - 68, boss.position.y - 66)  # au centre, sur le passage
	var vies_avant: int = JL.vies
	await create_timer(0.9).timeout
	_check(etats_vus.has(boss.Etat.PAUSE) and etats_vus.has(boss.Etat.SORTIE) and etats_vus.has(boss.Etat.REPOS),
		"le boss enchaîne entrée, pause au centre, sortie, repos")
	_check(boss.cote == -cote_initial, "le boss change de côté après un cycle")
	_check(signf(boss.sprite.scale.x) == boss.cote, "le sprite du boss regarde vers le centre")
	var x_max_poly := -1e9
	for enfant in boss.get_children():
		if enfant is CollisionPolygon2D:
			for p in enfant.polygon:
				x_max_poly = max(x_max_poly, p.x)
	_check((boss.cote > 0 and x_max_poly > 200.0) or (boss.cote < 0 and x_max_poly < 200.0),
		"la collision du boss est en miroir avec le sprite (x max %.0f, côté %d)" % [x_max_poly, boss.cote])
	_check(JL.vies < vies_avant, "le boss blesse le lion au passage (%d → %d)" % [vies_avant, JL.vies])
	# Les deux chemins de contact du peintre : body_entered, puis le contact continu hors repos.
	# Un lion resté à son contact est frappé dès la fin de son invulnérabilité, sans nouveau
	# body_entered ; le coup part de la verticale du peintre, à la hauteur du lion : le recul est
	# horizontal.
	boss._arreter()
	boss.etat = boss.Etat.PAUSE
	boss.position.x = 1000.0
	lion.global_position = Vector2(1000 - 60 - 68, boss.position.y - 120 - 66)
	lion.direction_du_lion = -1  # dos au peintre : le repli par défaut pointerait vers lui, à l'envers
	JL.vies = 3
	JL.invulnerable_restant = 0.3
	await _frames(3)
	_check(boss.get_overlapping_bodies().has(lion) and JL.vies == 3,
		"(pré-condition) le lion, invulnérable, est au contact du peintre et n'a rien perdu")
	await create_timer(0.4).timeout
	await _frames(2)
	_check(JL.vies == 2, "un lion resté au contact du peintre est frappé dès la fin de son invulnérabilité (contact continu)")
	_check(lion.deplacement.recul.normalized().is_equal_approx(Vector2(-1, 0)),
		"le coup du peintre part de sa verticale, à la hauteur du lion : le recul est horizontal, loin du peintre (%s)" % lion.deplacement.recul)
	boss.etat = boss.Etat.REPOS  # au repos, hors de l'écran : il ne touche plus rien
	boss.position.x = boss._x_hors_ecran()
	GS.niveau_courant = 0

	# Arcade : neuf stages, Facile → Moyen → Hardcore
	GS.demarrer_arcade()
	_check(GS.mode_arcade and GS.difficulte_courante == 0 and GS.niveau_courant == 0 and GS.titre_etape() == "STAGE 1/9",
		"l'arcade démarre au stage 1 : Skyline en Facile")
	for i in range(3):
		GS.passer_etape_arcade()
	_check(GS.difficulte_courante == 1 and GS.niveau_courant == 0, "le stage 4 est Skyline en Moyen")
	for i in range(5):
		GS.passer_etape_arcade()
	_check(GS.etape_arcade == 8 and GS.difficulte_courante == 2 and GS.niveau_courant == 2 and not GS.etape_arcade_suivante_existe(),
		"le stage 9 est Village en Hardcore, dernier")
	GS.temps_arcade = 400.0
	paused = false
	main.queue_free()
	await _frames(2)
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	hud = main.get_node("HUD")
	_check(hud.etape.visible and hud.etape.text == "STAGE 9/9", "le HUD affiche le stage en arcade")
	GS.temps_ecoule = 30.0
	GS.signaler_progression(0.96)
	await _frames(3)
	overlay = main.get_node_or_null("GameOver")
	_check(overlay != null and overlay.titre.text == tr("ARCADE_TERMINE"), "gagner le stage 9 termine l'arcade")
	_check(overlay != null and not overlay.bouton_suivant.visible and not overlay.bouton_rejouer.visible, "fin d'arcade : seul Menu reste")
	_check(abs(GS.temps_arcade - 430.0) < 0.01 and abs(scores.meilleur_temps("arcade") - 430.0) < 0.01, "le temps total d'arcade est cumulé et enregistré")
	_check(overlay != null and overlay._lignes[-1].cible == 430, "le bilan affiche le temps total")
	scores.effacer()
	GS.quitter_arcade()

	# Attract mode : inactivité sur le titre → démo pilotée, toute touche en sort
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	titre.demo_autorisee = true
	titre.inactivite = titre.DELAI_DEMO
	var difficulte_avant: int = GS.difficulte_courante
	# on empêche le changement de scène en interceptant : lancer_demo(false) est l'équivalent testable
	titre.demo_autorisee = false
	titre.lancer_demo(false)
	_check(GS.demo and GS.difficulte_courante == 0, "l'inactivité lance la démo en Facile")
	titre.free()
	paused = false
	main.queue_free()
	await _frames(2)
	GS.niveau_courant = 0
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	_check(main.get_node_or_null("Pilote") != null and main.get_node_or_null("Demo") != null, "en démo, le pilote et l'étiquette DÉMO sont là")
	lion = main.get_node("Lion")
	spawner = main.get_node("Spawner")
	_check(lion.commandes.source == Commandes.Source.MANUELLES, "en démo, le lion suit des commandes manuelles")
	spawner.spawn_pickup(0, Vector2(1200, 250))
	await _frames(10)
	_check(lion.commandes.direction_voulue.length() > 0.9 and lion.deplacement.vitesse.length() > 0.0, "le pilote dirige le lion vers la pastille")
	var soucoupe3: Node = spawner.spawn_soucoupe(lion.global_position.y + 66)
	soucoupe3.position.x = lion.global_position.x + 250
	await _frames(2)
	_check(lion.commandes.direction_voulue.x < 0.0, "le pilote fuit un ennemi proche")
	soucoupe3.queue_free()
	Input.action_press("deplacer_droite")
	await _frames(2)
	Input.action_release("deplacer_droite")
	main.quitter_demo(false)
	_check(not GS.demo, "quitter la démo rend la main")
	GS.difficulte_courante = difficulte_avant

	# Hardcore : un seul coup
	paused = false
	main.queue_free()
	await _frames(2)
	GS.niveau_courant = 0
	GS.difficulte_courante = 2
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	lion = main.get_node("Lion")
	spawner = main.get_node("Spawner")
	hud = main.get_node("HUD")
	_check(JL.vies == 1 and not hud._coeurs[1].visible, "mode Hardcore : un seul cœur affiché")
	_check(abs(GS.seuil_victoire() - 0.95) < 0.001, "mode Hardcore : 95 %% à peindre")
	GS.signaler_progression(0.92)
	_check(GS.partie_en_cours, "92 %% ne suffit pas en Hardcore")
	_check(spawner._timer_coeur == null, "mode Hardcore : pas de cœurs à ramasser")
	coccinelle = spawner.spawn_coccinelle(lion.global_position.y + 66)
	coccinelle.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(not GS.partie_en_cours, "mode Hardcore : un coup et c'est fini")
	GS.difficulte_courante = 0

	# Un lion lié à un autre joueur suit ce joueur et ses propres commandes
	paused = false
	var autre := Joueur.new()
	autre.reinitialiser(3)
	var lion_autre: Node = load("res://Scenes/Lion.tscn").instantiate()
	lion_autre.joueur = autre
	lion_autre.commandes = Commandes.manuelles()
	lion_autre.position = Vector2(400, 200)
	root.add_child(lion_autre)
	await _frames(1)
	_check(lion_autre.gerbe.vomi_container.get_child_count() == 0, "un lion lié à un joueur sans couleur n'a pas d'émetteur")
	GS.regles.pastille_ramassee(JL, 3)
	_check(lion_autre.gerbe.vomi_container.get_child_count() == 0, "une couleur du joueur local ne touche pas un lion lié à un autre joueur")
	autre.debloquer_couleur(Color.RED)
	_check(lion_autre.gerbe.vomi_container.get_child_count() == 1, "le lion reconstruit sa gerbe quand son propre joueur débloque une couleur")
	var rayon_autre: float = lion_autre.gerbe.traceuse_shape.shape.radius
	JL.activer_bonus(5.0)
	_check(lion_autre.gerbe.traceuse_shape.shape.radius == rayon_autre, "le bonus du joueur local ne touche pas un lion lié à un autre joueur")
	JL.bonus_restant = 0.0
	autre.activer_bonus(5.0)
	_check(is_equal_approx(lion_autre.gerbe.traceuse_shape.shape.radius, rayon_autre * 2.0), "le bonus de son propre joueur double la gerbe du lion")
	autre.encaisser_coup(Vector2.INF, 1.5)
	_check(lion_autre.deplacement.recul.length() > 0.0, "un coup encaissé par son propre joueur repousse le lion")
	lion_autre.deplacement.recul = Vector2.ZERO  # sinon le recul contamine les vérifications de mouvement ci-dessous
	GS.pret = false
	lion_autre.commandes.direction_voulue = Vector2.RIGHT
	var x_avant: float = lion_autre.global_position.x
	await _frames(5)
	_check(lion_autre.global_position.x == x_avant, "hors jeu (intro), même des commandes manuelles sont ignorées")
	GS.pret = true
	await _frames(5)
	_check(lion_autre.global_position.x > x_avant, "le lion avance selon ses commandes manuelles")
	lion_autre.commandes.vomir_voulu = true
	await _frames(2)
	_check(lion_autre.est_en_train_de_vomir, "le lion vomit quand ses commandes manuelles le demandent")
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)

	# Ennemis et pastilles signalent le lion qu'ils touchent, pas le joueur local
	var local: Joueur = GS.joueur_local()
	var vies_local_avant: int = local.vies
	# La partie Hardcore vient de se terminer : le joueur local est à 0 vie, or
	# `Joueur.encaisser_coup` n'émet `touche` que si `vies > 0` après le coup, donc un coup
	# mal routé vers le joueur local ne déclencherait jamais `touches_locales` et la moitié
	# « pas de retour local » des vérifications ci-dessous serait toujours vraie à tort.
	# On le remet à 3 vies, invulnérabilité coupée, pour qu'il soit de nouveau touchable.
	local.vies = 3
	local.invulnerable_restant = 0.0
	var vies_local: int = local.vies
	var couleurs_local: int = local.couleurs_debloquees.size()
	var touches_locales: Array[Vector2] = []
	var sur_touche_locale := func(o: Vector2) -> void: touches_locales.append(o)
	JL.touche.connect(sur_touche_locale)
	# La coccinelle qui a infligé la défaite Hardcore n'a jamais été libérée : elle continue de
	# zigzaguer vers la gauche et peut retraverser le lion local, désormais de nouveau touchable
	# ci-dessus, ce qui rendait ce test instable. On libère tout ennemi encore en jeu (et le peintre,
	# s'il y en avait un) avant de continuer.
	for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
		ennemi.free()
	# Le Spawner de la partie Hardcore a encore des apparitions programmées (minuteries) :
	# on le libère aussi, pour que rien d'autre que cette section n'agisse pendant qu'elle tourne.
	main.get_node("Spawner").free()
	spawner = null
	GS.partie_en_cours = true  # la partie Hardcore est finie : les règles ignorent les coups hors partie
	lion_autre.commandes.direction_voulue = Vector2.ZERO
	lion_autre.global_position = Vector2(1400, 300)  # loin du lion local, resté dans la scène
	await _frames(1)
	autre.vies = 3  # deux coups à venir : jamais le coup fatal, qui terminerait la partie
	autre.invulnerable_restant = 0.0
	var centre_autre: Vector2 = lion_autre.global_position + Vector2(68, 66)
	var coccinelle_autre: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_autre.position = centre_autre
	root.add_child(coccinelle_autre)
	await _frames(3)
	_check(autre.vies == 2 and local.vies == vies_local and touches_locales.is_empty(),
		"une coccinelle retire une vie au joueur du lion touché, pas au joueur local")
	coccinelle_autre.queue_free()
	autre.invulnerable_restant = 0.0
	var soucoupe_autre: Node2D = load("res://Scenes/Soucoupe.tscn").instantiate()
	soucoupe_autre.position = centre_autre
	root.add_child(soucoupe_autre)
	await _frames(3)
	_check(autre.vies == 1 and local.vies == vies_local and touches_locales.is_empty(),
		"une soucoupe retire une vie au joueur du lion touché, pas au joueur local")
	soucoupe_autre.queue_free()
	var pastille_autre: Node2D = load("res://Scenes/ColorPickup.tscn").instantiate()
	pastille_autre.couleur_index = 4  # autre n'a que le rouge
	pastille_autre.position = centre_autre
	var sons_locaux := _sons.count("pickup")
	root.add_child(pastille_autre)
	await _frames(3)
	_check(not is_instance_valid(pastille_autre) and autre.couleurs_debloquees.has(GS.couleur(4))
		and local.couleurs_debloquees.size() == couleurs_local,
		"une pastille ramassée par un lion va à son joueur, pas au joueur local")
	var bonus_local: bool = local.bonus_actif()
	autre.bonus_restant = 0.0
	var etoile_autre: Node2D = load("res://Scenes/BonusPickup.tscn").instantiate()
	etoile_autre.position = centre_autre
	root.add_child(etoile_autre)
	await _frames(3)
	_check(not is_instance_valid(etoile_autre) and autre.bonus_actif()
		and is_equal_approx(autre.bonus_restant, Regles.DUREE_ETOILE) and local.bonus_actif() == bonus_local,
		"une étoile ramassée par un lion active la gerbe XXL de son joueur, pas celle du joueur local")
	_check(_sons.count("pickup") == sons_locaux, "ce que ramasse un autre lion ne joue pas le son de ramassage de ce poste")
	var coeur_autre: Node2D = load("res://Scenes/CoeurPickup.tscn").instantiate()
	coeur_autre.position = Vector2(-500, -500)  # hors d'atteinte : les contacts sont simulés à la main
	root.add_child(coeur_autre)
	await _frames(1)
	autre.vies = 1
	local.vies = 2
	coeur_autre._on_body_entered(lion_autre)
	coeur_autre._on_body_entered(main.get_node("Lion"))  # le lion local touche le même cœur dans la même frame
	_check(autre.vies == 2 and local.vies == 2, "premier arrivé, premier servi : un seul lion profite d'un cœur touché par deux lions")
	await _frames(1)
	_check(not is_instance_valid(coeur_autre), "le cœur ramassé disparaît")

	# Bases communes des ennemis et des pastilles : seul un lion compte (`body is Lion`, pas le
	# groupe « lion »), et seul l'hôte tranche un contact
	var bases: Array = ["Soucoupe", "Coccinelle", "Boss"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases.all(func(p: String) -> bool: return p == "res://Scripts/Ennemi.gd"),
		"soucoupe, coccinelle et peintre dérivent de la base Ennemi (%s)" % [bases])
	var bases_pastilles: Array = ["ColorPickup", "BonusPickup", "CoeurPickup"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases_pastilles.all(func(p: String) -> bool: return p == "res://Scripts/Pastille.gd"),
		"pastille de couleur, étoile et cœur dérivent de la base Pastille (%s)" % [bases_pastilles])
	# Phase 14 : chaque ennemi et chaque pastille porte son MultiplayerSynchronizer (`Synchro`) : position
	# à l'apparition (et ensuite pour les ennemis, qui bougent chez l'hôte), couleur d'une pastille, côté
	# du peintre, inclinaison de la coccinelle.
	var attendues := {
		"Soucoupe": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS]],
		"Coccinelle": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS], [^".:rotation", SceneReplicationConfig.REPLICATION_MODE_ALWAYS]],
		"Boss": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS], [^".:cote", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE],
			[^".:etat", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE]],
		"ColorPickup": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER], [^".:couleur_index", SceneReplicationConfig.REPLICATION_MODE_NEVER]],
		"BonusPickup": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER]],
		"CoeurPickup": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER]],
	}
	for nom: String in attendues:
		var instance: Node = load("res://Scenes/%s.tscn" % nom).instantiate()
		var synchro := instance.get_node_or_null("Synchro") as MultiplayerSynchronizer
		var config: SceneReplicationConfig = null if synchro == null else synchro.replication_config
		var conforme: bool = config != null and config.get_properties().size() == attendues[nom].size()
		for attendue: Array in attendues[nom]:
			conforme = conforme and config.has_property(attendue[0]) and config.property_get_spawn(attendue[0]) \
				and config.property_get_replication_mode(attendue[0]) == attendue[1]
		_check(conforme, "%s : son Synchro réplique %s à l'apparition" % [nom, attendues[nom].map(func(a: Array) -> String: return str(a[0]))])
		instance.free()
	# L'intrus a un champ `joueur`, comme un lion : sous l'ancien typage (groupe « lion » puis
	# `body.joueur`), il serait accepté.
	var script_intrus := GDScript.new()
	script_intrus.source_code = "extends CharacterBody2D\nvar joueur: Joueur = Joueur.new()\n"
	script_intrus.reload()
	var intrus := CharacterBody2D.new()  # sur la couche 1 et dans le groupe « lion », mais pas un lion
	intrus.set_script(script_intrus)
	intrus.add_to_group("lion")
	var forme_intrus := CollisionShape2D.new()
	forme_intrus.shape = CircleShape2D.new()
	forme_intrus.shape.radius = 30.0
	intrus.add_child(forme_intrus)
	intrus.position = Vector2(300, -400)  # hors de l'écran, loin des lions
	root.add_child(intrus)
	var soucoupe_intrus: Node2D = load("res://Scenes/Soucoupe.tscn").instantiate()
	soucoupe_intrus.position = intrus.position
	root.add_child(soucoupe_intrus)
	await _frames(3)
	_check(soucoupe_intrus.get_overlapping_bodies().has(intrus) and autre.vies == 2 and local.vies == 2
		and intrus.joueur.vies == 3 and not intrus.joueur.est_invulnerable(),
		"un ennemi ignore un corps qui n'est pas un lion, même dans le groupe « lion » et avec un joueur")
	soucoupe_intrus.free()
	for nom in ["ColorPickup", "BonusPickup", "CoeurPickup"]:
		var pastille_intrus: Area2D = load("res://Scenes/%s.tscn" % nom).instantiate()
		pastille_intrus.position = intrus.position
		root.add_child(pastille_intrus)
		await _frames(3)
		_check(is_instance_valid(pastille_intrus) and pastille_intrus.get_overlapping_bodies().has(intrus)
			and intrus.joueur.couleurs_debloquees.is_empty() and intrus.joueur.crans == 1 and not intrus.joueur.bonus_actif(),
			"%s : une pastille ignore un corps qui n'est pas un lion, même dans le groupe « lion » et avec un joueur" % nom)
		if is_instance_valid(pastille_intrus):
			pastille_intrus.free()
	intrus.free()
	autre.invulnerable_restant = 0.0
	lion_autre.deplacement.recul = Vector2.ZERO  # le recul des coups précédents l'éloigne encore
	lion_autre.global_position = Vector2(1400, 300)
	await _frames(1)
	var poste_client := Node2D.new()  # sous-arbre dont le pair multijoueur est un client
	poste_client.name = "PosteClient"
	root.add_child(poste_client)
	var api_client := SceneMultiplayer.new()
	var pair_client := ENetMultiplayerPeer.new()
	_check(pair_client.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client, jamais connecté : un client qui attend l'hôte")
	api_client.multiplayer_peer = pair_client
	set_multiplayer(api_client, poste_client.get_path())
	var coccinelle_client: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_client.position = lion_autre.global_position + Vector2(68, 66)
	poste_client.add_child(coccinelle_client)
	await _frames(3)
	_check(not coccinelle_client.multiplayer.is_server() and coccinelle_client.get_overlapping_bodies().has(lion_autre)
		and autre.vies == 2 and not autre.est_invulnerable(),
		"sur un client, un ennemi au contact d'un lion ne le signale pas aux règles (seul l'hôte tranche)")
	coccinelle_client.free()
	var crans_client := autre.crans
	var pastille_client: Area2D = load("res://Scenes/ColorPickup.tscn").instantiate()
	pastille_client.couleur_index = 6
	pastille_client.position = lion_autre.global_position + Vector2(68, 66)
	poste_client.add_child(pastille_client)
	var etoile_client: Area2D = load("res://Scenes/BonusPickup.tscn").instantiate()
	etoile_client.position = Vector2(-500, -500)
	poste_client.add_child(etoile_client)
	await _frames(3)
	_check(is_instance_valid(pastille_client) and pastille_client.get_overlapping_bodies().has(lion_autre)
		and not autre.couleurs_debloquees.has(GS.couleur(6)) and autre.crans == crans_client,
		"sur un client, une pastille au contact d'un lion n'est pas ramassée (seul l'hôte tranche)")
	if etoile_client.has_method("_expirer"):
		etoile_client._expirer()
	await _frames(1)
	_check(is_instance_valid(etoile_client) and etoile_client.has_method("_expirer"),
		"sur un client, une étoile en fin de vie ne se libère pas d'elle-même (l'hôte la fait disparaître)")
	# Phase 14 : sur un client, ennemis et Spawner sont inertes : des répliques de ceux de l'hôte, que
	# seul leur Synchro déplace
	var soucoupe_client: Node2D = load("res://Scenes/Soucoupe.tscn").instantiate()
	soucoupe_client.position = Vector2(300, 100)
	poste_client.add_child(soucoupe_client)
	var coccinelle_repl: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_repl.position = Vector2(900, 100)
	poste_client.add_child(coccinelle_repl)
	var boss_client: Node2D = load("res://Scenes/Boss.tscn").instantiate()
	boss_client.cote = -1  # comme l'état d'apparition reçu de l'hôte, posé avant `_ready`
	boss_client.position = Vector2(1000, 300)
	poste_client.add_child(boss_client)
	var spawner_client: Node = load("res://Scripts/Spawner.gd").new()
	poste_client.add_child(spawner_client)
	var enfants_client := poste_client.get_child_count()
	spawner_client.demarrer()
	await _frames(5)
	_check(GS.pret and soucoupe_client.position == Vector2(300, 100) and coccinelle_repl.position == Vector2(900, 100)
		and coccinelle_repl.speed == 0.0 and boss_client.position == Vector2(1000, 300) and boss_client._tween == null,
		"sur un client, un ennemi ne bouge pas de lui-même, ne tire rien au hasard et le peintre ne lance aucun tween")
	_check(boss_client.sprite.scale.x < 0.0 and boss_client.cote == -1, "sur un client, le peintre regarde du côté reçu de l'hôte (sprite en miroir)")
	# Phase 17 bis : l'annonce du peintre, décidée par l'hôte, s'entend aussi chez chaque client (son état
	# est répliqué) ; l'état répété, ou un autre état, ne rejoue rien
	var annonces_avant := _sons.count("boss")
	boss_client.etat = boss_client.Etat.ANNONCE
	boss_client.etat = boss_client.Etat.ANNONCE
	boss_client.etat = boss_client.Etat.ENTREE
	_check(_sons.count("boss") == annonces_avant + 1 and boss_client._tween == null,
		"sur un client, l'annonce du peintre reçue de l'hôte joue son son, une fois, sans lancer de tween")
	_check(not spawner_client._demarre and spawner_client._timer_soucoupe == null and poste_client.get_child_count() == enfants_client,
		"sur un client, le Spawner ne fait rien apparaître (tout vient de l'hôte)")
	# Chaque nœud synchronisé quitte le sous-arbre avant que son pair ne change (sinon l'API du client
	# le suivrait encore).
	for noeud: Node in [soucoupe_client, coccinelle_repl, boss_client, spawner_client, pastille_client, etoile_client]:
		noeud.free()
	set_multiplayer(null, poste_client.get_path())
	pair_client.close()
	poste_client.free()

	# La traceuse d'un lion peint avec les couleurs de son propre joueur. Le lion local peint
	# d'abord, avec autant de couleurs et le même rayon que l'autre lion : la ville garde ses
	# tampons par jeu de couleurs, l'autre lion ne doit donc pas reprendre ceux du lion local.
	var ville_hc: Node = main.get_node("Ville")
	GS.regles.pastille_ramassee(local, 5)  # le joueur local : vert et bleu, 3 crans
	autre.gagner_cran()  # l'autre joueur : rouge et cyan, 3 crans
	autre.avancer(Regles.DUREE_ETOILE)  # fin de la gerbe XXL de l'étoile ramassée plus haut (autre n'est pas dans GS.joueurs)
	_check(local.couleurs_debloquees.size() == autre.couleurs_debloquees.size()
		and lion.gerbe.traceuse_shape.shape.radius == lion_autre.gerbe.traceuse_shape.shape.radius
		and not local.couleurs_debloquees.any(func(c: Color) -> bool: return autre.couleurs_debloquees.has(c)),
		"(pré-condition) les deux lions ont autant de couleurs, le même rayon (%.0f px) et aucune couleur commune" % lion.gerbe.traceuse_shape.shape.radius)
	lion.global_position = Vector2(600, ville_hc.position.y - 300)
	Input.action_press("vomir")
	await _frames(20)
	Input.action_release("vomir")
	await _frames(2)
	_check(not _couleurs_peintes(ville_hc.image).is_empty(), "(pré-condition) le lion local a peint la ville le premier")
	ville_hc.image.fill(Color(0, 0, 0, 0))
	ville_hc.coulures.clear()  # celles du lion local couleraient encore dans ses couleurs
	lion_autre.commandes.vomir_voulu = true
	await _frames(20)
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)
	var couleurs_peintes := _couleurs_peintes(ville_hc.image)
	var rgba32_autre: Array = autre.couleurs_debloquees.map(_rgba8)
	_check(not couleurs_peintes.is_empty()
		and couleurs_peintes.keys().all(func(k: int) -> bool: return rgba32_autre.has(k)),
		"la traceuse d'un lion peint avec les couleurs de son joueur, même après un lion qui en a autant (%d couleur(s) sur la ville)" % couleurs_peintes.size())
	JL.touche.disconnect(sur_touche_locale)
	GS.partie_en_cours = false
	local.vies = vies_local_avant  # on restaure l'état d'avant la section, mort Hardcore compris
	lion_autre.free()
	_check(autre.couleur_debloquee.get_connections().is_empty() and autre.touche.get_connections().is_empty(),
		"le lion libéré se désabonne de son joueur")
	autre.debloquer_couleur(Color.BLUE)
	autre = null

	# Bataille : crinière à la couleur du joueur, pseudo au-dessus du lion
	var shader_lion: Shader = load("res://Shaders/Lion.gdshader")
	var uniformes: Array = [] if shader_lion == null else shader_lion.get_shader_uniform_list().map(
		func(u: Dictionary) -> String: return u.name)
	_check(uniformes.has("couleur_joueur") and uniformes.has("barbouillage_couleur") and uniformes.has("barbouillage_force"),
		"le shader du lion compile et expose couleur_joueur, barbouillage_couleur et barbouillage_force (%s)" % [uniformes])
	var rouge := Joueur.new()
	rouge.couleur = Color(0.90, 0.16, 0.16)
	rouge.pseudo = "Alice"
	var bleu := Joueur.new()
	bleu.couleur = Color(0.16, 0.39, 0.95)
	var sans_couleur := Joueur.new()
	sans_couleur.pseudo = "Solo"
	var lions_teintes: Array[Node] = []
	for j: Joueur in [rouge, bleu, sans_couleur]:
		var l: Node = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 300 * lions_teintes.size(), 0)
		root.add_child(l)
		lions_teintes.append(l)
	await _frames(1)
	var mat_rouge := lions_teintes[0].sprite.material as ShaderMaterial
	var mat_bleu := lions_teintes[1].sprite.material as ShaderMaterial
	_check(mat_rouge != null and mat_rouge.shader == shader_lion and mat_rouge.get_shader_parameter("couleur_joueur") == rouge.couleur,
		"le lion d'un joueur coloré porte le shader de teinte, à la couleur de son joueur")
	_check(mat_bleu != null and mat_bleu != mat_rouge and mat_bleu.get_shader_parameter("couleur_joueur") == bleu.couleur,
		"deux lions ont chacun leur matériau, chacun à la couleur de son joueur")
	_check(lions_teintes[2].sprite.material == null and not lions_teintes[2].etiquette_pseudo.visible,
		"un joueur sans couleur garde le rendu d'origine et n'affiche pas son pseudo, même s'il en a un")
	bleu.couleur = Color(0.10, 0.85, 0.90)
	lions_teintes[1].appliquer_apparence()
	_check(mat_bleu.get_shader_parameter("couleur_joueur") == bleu.couleur and mat_rouge.get_shader_parameter("couleur_joueur") == rouge.couleur,
		"réappliquer l'apparence après un changement de couleur ne retouche que le lion de ce joueur")
	bleu.couleur = Color.TRANSPARENT
	lions_teintes[1].appliquer_apparence()
	_check(lions_teintes[1].sprite.material == null, "un joueur redevenu sans couleur rend au lion son rendu d'origine")
	var etiquette: Label = lions_teintes[0].etiquette_pseudo
	var haut_sprite: float = lions_teintes[0].sprite.position.y - lions_teintes[0].sprite.texture.get_height() / 2.0
	_check(etiquette.visible and etiquette.text == "Alice" and etiquette.get_theme_color("font_color") == rouge.couleur,
		"le pseudo du joueur s'affiche dans sa couleur")
	_check(etiquette.get_rect().end.y <= haut_sprite and absf(etiquette.get_rect().get_center().x - lions_teintes[0].sprite.position.x) < 1.0,
		"le pseudo est au-dessus de la tête du lion, centré")
	_check(not lions_teintes[1].etiquette_pseudo.visible, "un joueur sans pseudo n'affiche pas d'étiquette")
	rouge.debloquer_couleur(Color.RED)
	GS.pret = true
	lions_teintes[0].commandes.vomir_voulu = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process et l'AnimationPlayer change de sprite au même rythme
	_check(lions_teintes[0].est_en_train_de_vomir and lions_teintes[0].sprite.texture.resource_path.ends_with("LionHeadVomit.png")
		and lions_teintes[0].sprite.material == mat_rouge,
		"en vomissant, le sprite de vomi garde le matériau de teinte du joueur")
	lions_teintes[0].commandes.vomir_voulu = false
	await _frames(2)
	for l in lions_teintes:
		l.free()

	# Bataille : lions de bataille, dans une scène propre. La partie Hardcore est libérée d'abord
	# (son lion, sa ville) : rien des sections précédentes ne doit toucher ces lions.
	paused = false
	main.free()
	main = null
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	# Ce test contourne l'intro (`GameState.demarrer`), qui émettrait `partie_prete` en jeu réel et
	# resynchroniserait Audio (vies et crans) sur le joueur local après le `reinitialiser` silencieux
	# de `nouvelle_partie` : on le fait à la main pour ne pas hériter d'un `_crans_vus` d'une section
	# précédente.
	root.get_node("Audio")._on_partie_prete()
	var j_rouge: Joueur = GS.joueurs[0]
	var j_bleu: Joueur = GS.joueurs[1]
	var lions_bataille: Array[CharacterBody2D] = []
	for j: Joueur in GS.joueurs:
		var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 1000 * lions_bataille.size(), 100)
		root.add_child(l)
		lions_bataille.append(l)
	var lr: CharacterBody2D = lions_bataille[0]
	var lb: CharacterBody2D = lions_bataille[1]
	await _frames(2)

	# Gerbe en trois nuances, rayon selon les crans
	var couleurs_gerbe: Array = lr.gerbe.vomi_container.get_children().map(
		func(e: GPUParticles2D) -> Color: return (e.process_material as ParticleProcessMaterial).color_ramp.gradient.get_color(0))
	_check(couleurs_gerbe == j_rouge.nuances(), "un lion de bataille a trois émetteurs, aux nuances de son joueur (%s)" % [couleurs_gerbe])
	_check(lr.gerbe.traceuse_shape.shape.radius == 16.0, "au premier cran, la gerbe peint sur 16 px")
	var sons_bataille := _sons.count("pickup")
	GS.regles.pastille_ramassee(j_rouge, 0)
	_check(lr.gerbe.traceuse_shape.shape.radius == 21.0 and lb.gerbe.traceuse_shape.shape.radius == 16.0, "une pastille donne un cran : 5 px de plus, pour ce lion seulement")
	_check(GS.joueur_local() == j_rouge and _sons.count("pickup") == sons_bataille + 1,
		"en bataille, le cran d'une pastille (aucune couleur débloquée) joue le son de ramassage du joueur local")
	for i in range(10):
		GS.regles.pastille_ramassee(j_rouge, 0)
	_check(lr.gerbe.traceuse_shape.shape.radius == 46.0, "au septième cran, la gerbe peint sur 46 px")
	lr.commandes.vomir_voulu = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process
	_check(lr.est_en_train_de_vomir, "un lion de bataille vomit dès le départ, sans pastille")
	_check(lr.vomi_de_l_hote, "sur l'hôte, l'état de vomi à répliquer suit celui du lion")
	lr.commandes.vomir_voulu = false
	await _frames(2)

	# Reliquats de la phase 7 : apparence appliquée trop tôt, matériau d'un autre shader
	var lion_neuf: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	lion_neuf.joueur = Joueur.new()
	lion_neuf.joueur.couleur = Color(0.18, 0.78, 0.25)
	lion_neuf.commandes = Commandes.manuelles()
	lion_neuf.position = Vector2(700, 400)
	lion_neuf.appliquer_apparence()
	root.add_child(lion_neuf)
	await _frames(1)
	_check(lion_neuf.sprite.material is ShaderMaterial and lion_neuf.sprite.material.shader == shader_lion,
		"appliquer_apparence avant l'ajout à l'arbre ne fait rien ; _ready teinte le lion")
	var materiau_etranger := ShaderMaterial.new()
	materiau_etranger.shader = load("res://Shaders/Ville.gdshader")
	lion_neuf.sprite.material = materiau_etranger
	lion_neuf.appliquer_apparence()
	_check(lion_neuf.sprite.material != materiau_etranger and lion_neuf.sprite.material.shader == shader_lion,
		"un matériau d'un autre shader sur le sprite est remplacé par celui de la teinte")
	lion_neuf.free()

	# Phase 17 bis : la boucle du vomi n'appartient qu'au lion de ce poste ; un autre lion qui arrête
	# de vomir ne la coupe plus
	lr.commandes.vomir_voulu = true
	lb.commandes.vomir_voulu = true
	for i in range(3):
		await process_frame
	lb.commandes.vomir_voulu = false
	for i in range(3):
		await process_frame
	_check(lr.est_local() and not lb.est_local() and lr.est_en_train_de_vomir and not lb.est_en_train_de_vomir and audio._vomi.playing,
		"un autre lion qui arrête de vomir ne coupe pas la boucle du vomi du lion de ce poste")
	lr.commandes.vomir_voulu = false
	for i in range(3):
		await process_frame
	_check(not audio._vomi.playing, "le lion de ce poste qui arrête de vomir coupe sa boucle")

	# Étourdissement par un ennemi : immobile, repoussé, étoiles, sans barbouillage
	var materiau_bleu := lb.sprite.material as ShaderMaterial
	lb.commandes.direction_voulue = Vector2.LEFT
	await _frames(5)
	_check(lb.deplacement.vitesse.x < 0.0, "(pré-condition) le lion bleu avance selon ses commandes")
	materiau_bleu.set_shader_parameter("barbouillage_force", 0.5)  # pour un check discriminant : un ennemi doit bien la remettre à 0
	var etourdis_avant := _sons.count("etourdi")
	GS.regles.lion_touche_par_ennemi(j_bleu, lb.global_position + lb.CENTRE + Vector2(-80, 0))
	_check(_sons.count("etourdi") == etourdis_avant + 1, "un étourdissement joue son son (phase 17 bis)")
	_check(j_bleu.est_etourdi() and lb.deplacement.vitesse == Vector2.ZERO and lb.deplacement.recul.x > 0.0 and lb.etoiles.visible,
		"un ennemi étourdit le lion : il s'arrête, il est repoussé, des étoiles tournent")
	_check(materiau_bleu.get_shader_parameter("barbouillage_force") == 0.0, "un ennemi ne barbouille pas")
	lb.commandes.vomir_voulu = true
	var position_etoile: Vector2 = lb.etoiles.get_child(0).position
	await _frames(10)
	_check(lb.deplacement.vitesse == Vector2.ZERO and not lb.est_en_train_de_vomir, "étourdi, le lion ignore ses commandes : ni déplacement ni vomi")
	_check(lb.etoiles.get_child(0).position != position_etoile, "les étoiles tournent autour de la tête")
	j_bleu.etourdi_restant = 0.05
	await create_timer(0.1).timeout
	await _frames(2)
	_check(not j_bleu.est_etourdi() and not lb.etoiles.visible and j_bleu.est_invulnerable()
		and lb._clignotement != null and lb._clignotement.is_running(),
		"à la fin de l'étourdissement, les étoiles s'en vont et l'immunité clignote")
	_check(lb.deplacement.vitesse.x < 0.0 and lb.est_en_train_de_vomir, "le lion obéit de nouveau à ses commandes")
	GS.regles.lion_touche_par_ennemi(j_bleu, Vector2.INF)
	_check(not j_bleu.est_etourdi(), "un ennemi ne ré-étourdit pas un lion immunisé")

	# Étourdissement par le vomi : tête barbouillée de la couleur de l'agresseur
	j_bleu.invulnerable_restant = 0.0
	GS.regles.lion_touche_par_vomi(j_bleu, j_rouge, lb.global_position + lb.CENTRE + Vector2(0, -80))
	_check(materiau_bleu.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur
		and is_equal_approx(materiau_bleu.get_shader_parameter("barbouillage_force"), lb.FORCE_BARBOUILLAGE)
		and materiau_bleu.get_shader_parameter("couleur_joueur") == j_bleu.couleur,
		"le vomi barbouille la tête de la couleur de l'agresseur, par-dessus la teinte du joueur")
	await _frames(3)
	_check(not lb.est_en_train_de_vomir and not lb.gerbe.traceuse.monitoring, "étourdi en plein vomi, le lion arrête de vomir")
	j_bleu.etourdi_restant = 0.05
	await create_timer(0.1).timeout
	await _frames(2)
	_check(materiau_bleu.get_shader_parameter("barbouillage_force") == 0.0, "le barbouillage s'efface à la fin de l'étourdissement")

	# Un vrai ennemi, en plein vomi : l'étourdissement part d'un rappel physique (body_entered)
	j_bleu.invulnerable_restant = 0.0
	lb.commandes.direction_voulue = Vector2.ZERO
	await _frames(3)
	_check(lb.est_en_train_de_vomir, "(pré-condition) le lion bleu vomit")
	var coccinelle_bataille: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_bataille.position = lb.global_position + lb.CENTRE
	root.add_child(coccinelle_bataille)
	await _frames(3)
	_check(j_bleu.est_etourdi() and j_bleu.vies == 3 and not lb.est_en_train_de_vomir,
		"une coccinelle étourdit le lion de bataille qu'elle touche, sans lui ôter de vie ; il arrête de vomir")
	coccinelle_bataille.free()
	lb.commandes.vomir_voulu = false
	await _frames(2)
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0

	# Auto-guérison des effets visuels : `Joueur.reinitialiser` n'émet aucun signal
	# (contrairement à `Joueur.etourdir`) ; le lion doit s'en remettre tout seul au `_process` suivant
	var couleurs_j_bleu := j_bleu.couleurs_debloquees.duplicate()
	GS.regles.lion_touche_par_vomi(j_bleu, j_rouge, lb.global_position + lb.CENTRE + Vector2(0, -80))
	await _frames(2)
	_check(j_bleu.est_etourdi() and lb.etoiles.visible and materiau_bleu.get_shader_parameter("barbouillage_force") > 0.0,
		"(pré-condition) le lion bleu est étourdi et barbouillé, étoiles visibles")
	j_bleu.reinitialiser(3, couleurs_j_bleu)
	await _frames(3)
	_check(not lb.etoiles.visible and materiau_bleu.get_shader_parameter("barbouillage_force") == 0.0,
		"Joueur.reinitialiser en plein étourdissement n'émet rien : étoiles et barbouillage se corrigent tout seuls")
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0

	# Zones de contact : trois, le long de la parabole, jusqu'au point de chute
	var zones: Array[Area2D] = lr.gerbe.zones_contact
	_check(zones.size() == 3 and zones[2].position.is_equal_approx(lr.gerbe.traceuse.position)
		and zones[0].position.y < zones[1].position.y and zones[1].position.y < zones[2].position.y
		and zones.all(func(z: Area2D) -> bool: return z.collision_layer == 0 and not z.monitoring),
		"trois zones de contact sur la parabole, la dernière au point de chute, inertes hors du vomi")
	_check(zones[0].get_child(0).shape != lb.gerbe.zones_contact[0].get_child(0).shape, "chaque lion a ses propres formes de zones de contact")
	j_bleu.invulnerable_restant = 0.0
	var infliges_avant: int = j_rouge.etourdissements_infliges
	lb.deplacement.recul = Vector2.ZERO
	lb.global_position = lr.to_global(zones[1].position) - lb.CENTRE
	await _frames(2)
	lr.commandes.vomir_voulu = true
	for i in range(30):  # vomi démarré au _process, contacts connus au tick physique suivant
		await _frames(1)
		if j_bleu.est_etourdi():
			break
	_check(j_bleu.est_etourdi() and materiau_bleu.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur
		and j_rouge.etourdissements_infliges == infliges_avant + 1 and not j_rouge.est_etourdi(),
		"la gerbe d'un lion étourdit l'autre lion qu'elle touche, barbouillé de sa couleur, et lui compte l'étourdissement")
	var etourdi_apres_coup: float = j_bleu.etourdi_restant
	await _frames(10)
	_check(j_rouge.etourdissements_infliges == infliges_avant + 1 and j_bleu.etourdi_restant < etourdi_apres_coup,
		"un lion déjà étourdi n'est pas ré-étourdi par la gerbe qui le touche encore")
	lr.commandes.vomir_voulu = false
	await _frames(3)  # le vomi s'arrête au _process suivant : pas de nouveau contact ensuite
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0

	# Auto-tamponneuses : pare-chocs réduit, recul proportionnel à la vitesse d'approche
	_check(lr.collision_mask == 0 and lr.pare_chocs.collision_layer == 16 and lr.pare_chocs.collision_mask == 16
		and is_equal_approx(lr.pare_chocs.rayon, 45.0) and lr.get_node("CollisionShape2D").shape.radius > 60.0,
		"les lions se heurtent sur leur couche dédiée, à 45 px ; le corps (63 px) reste celui que touchent ennemis et pastilles")
	lr.deplacement.recul = Vector2.ZERO
	lb.deplacement.recul = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	var boings_avant := _sons.count("boing")
	lr.commandes.direction_voulue = Vector2.RIGHT
	for i in range(90):
		await _frames(1)
		if j_rouge.chocs > 0:
			break
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_rouge.chocs == 1 and j_bleu.chocs == 1, "un choc est compté une fois, pour les deux lions")
	_check(_sons.count("boing") == boings_avant + 1, "un choc fait « boing », une fois pour les deux lions (%d)" % (_sons.count("boing") - boings_avant))
	# M6 (revue finale phase 17) : dans la même image, un son plus fort (celui du lion de ce poste) ne
	# doit jamais être masqué par un son plus discret (un choc entre deux AUTRES lions) déjà joué ;
	# et l'inverse ne double pas inutilement (un son plus discret après le son fort déjà joué est ignoré).
	# Une image neuve d'abord : le choc réel ci-dessus a déjà enregistré un « boing » sur celle-ci.
	await _frames(1)
	var _boings_db := func() -> Array[float]:
		var db: Array[float] = []
		for enfant in audio.get_children():
			if enfant is AudioStreamPlayer and enfant.stream != null and enfant.stream.resource_path.get_file().get_basename() == "boing":
				db.append(enfant.volume_db)
		return db
	var avant_m6: int = _boings_db.call().size()
	audio.jouer_boing(false)  # discret (-9 dB) : un choc entre deux autres lions, traité en premier
	audio.jouer_boing(true)  # le lion de ce poste, dans la même image : ne doit pas être masqué
	var apres_m6: Array[float] = _boings_db.call()
	_check(apres_m6.size() == avant_m6 + 2 and apres_m6[-1] > apres_m6[-2],
		"M6 : un son plus fort (ce poste) n'est jamais masqué par un son plus discret déjà joué dans la même image (%s)" % [apres_m6.slice(avant_m6)])
	await _frames(1)  # nouvelle image : la dédup par image ne doit pas retenir l'ancienne
	audio.jouer_boing(true)  # fort, joué le premier cette fois
	audio.jouer_boing(false)  # discret, après le fort déjà joué : ignoré, pas de doublon inutile
	var apres_m6_2: Array[float] = _boings_db.call()
	_check(apres_m6_2.size() == apres_m6.size() + 1,
		"un son plus discret qui arrive après un son plus fort déjà joué dans la même image ne rejoue pas (%d au lieu de %d)"
			% [apres_m6_2.size(), apres_m6.size() + 1])
	_check(lr.deplacement.recul.x < 0.0 and lb.deplacement.recul.x > 0.0 and lr._secousse_restante > 0.0 and lb._secousse_restante > 0.0,
		"au choc, les deux lions reculent chacun de son côté, et leur sprite tremble")
	_check(not j_rouge.est_etourdi() and not j_bleu.est_etourdi(), "un choc n'étourdit personne")
	var distance_min := 1e9
	for i in range(30):
		await _frames(1)
		distance_min = minf(distance_min, lr.pare_chocs.global_position.distance_to(lb.pare_chocs.global_position))
	_check(distance_min > 2 * 45.0 - 15.0 and j_rouge.chocs == 1,
		"les lions ne s'enfoncent pas l'un dans l'autre (distance min %.0f px), un seul choc compté" % distance_min)

	# Poussée continue de 2 s (120 ticks physiques) contre un lion immobile : avant cette
	# correction, seul le recul s'opposait à la vitesse commandée (qui ramenait aussitôt vers l'autre) et
	# chaque re-contact comptait, jusqu'à 14 chocs en 2 s ; la vitesse commandée doit maintenant se
	# réaccélérer et le délai anti-rafale limiter le décompte.
	lr.deplacement.recul = Vector2.ZERO
	lb.deplacement.recul = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	var chocs_rouge_avant: int = j_rouge.chocs
	var chocs_bleu_avant: int = j_bleu.chocs
	distance_min = 1e9
	lr.commandes.direction_voulue = Vector2.RIGHT
	for i in range(120):
		await _frames(1)
		distance_min = minf(distance_min, lr.pare_chocs.global_position.distance_to(lb.pare_chocs.global_position))
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_rouge.chocs - chocs_rouge_avant <= 2 and j_bleu.chocs - chocs_bleu_avant <= 2,
		"une poussée continue de 2 s ne rafale pas les chocs (%d, %d)" % [j_rouge.chocs - chocs_rouge_avant, j_bleu.chocs - chocs_bleu_avant])
	_check(distance_min >= 75.0, "les deux lions restent à au moins 75 px l'un de l'autre pendant la poussée continue (min %.0f px)" % distance_min)

	# Un lion étourdi peut être poussé
	GS.regles.lion_touche_par_ennemi(j_bleu, Vector2.INF)
	lb.deplacement.recul = Vector2.ZERO
	lr.deplacement.recul = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	var x_bleu: float = lb.global_position.x
	lr.commandes.direction_voulue = Vector2.RIGHT
	distance_min = 1e9
	for i in range(40):
		await _frames(1)
		distance_min = minf(distance_min, lr.pare_chocs.global_position.distance_to(lb.pare_chocs.global_position))
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_bleu.est_etourdi() and lb.global_position.x > x_bleu + 10.0 and j_rouge.chocs >= 2,
		"un lion étourdi est poussé par celui qui le percute (%.0f px)" % (lb.global_position.x - x_bleu))
	_check(distance_min > 2 * 45.0 - 15.0, "même en poussant sans relâche, un lion ne s'enfonce pas dans l'autre (distance min %.0f px)" % distance_min)

	# Phase 15 bis : le pas de déplacement (`Lion.avancer`), seul chemin du déplacement sur l'hôte, que
	# rejouera la prédiction du lion local (phase 16) ; chaque lion a son propre état de déplacement
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0
	lr.commandes.direction_voulue = Vector2.ZERO
	lr.global_position = Vector2(400, 300)
	lb.global_position = Vector2(1400, 300)
	await _frames(30)  # reculs amortis, contacts des pare-chocs oubliés
	_check(lr.deplacement != lb.deplacement and lr.deplacement.recul == Vector2.ZERO and lr.velocity == Vector2.ZERO,
		"(pré-condition) chaque lion a son propre déplacement ; le lion rouge est à l'arrêt")
	var x_avant_pas: float = lr.global_position.x
	var dt_pas := 1.0 / Engine.physics_ticks_per_second
	lr.avancer(Vector2.RIGHT, dt_pas)
	_check(lr.deplacement.vitesse == Vector2(lr.deplacement.acceleration * dt_pas, 0.0) and lr.velocity == lr.deplacement.vitesse
		and absf(lr.global_position.x - x_avant_pas - lr.velocity.x * dt_pas) < 0.001 and lr.direction_du_lion == 1,
		"un pas vers la droite : la vitesse gagne une accélération d'un tick, le lion avance d'autant (%.3f px)" % (lr.global_position.x - x_avant_pas))
	lr.avancer(Vector2.LEFT, dt_pas)
	_check(lr.direction_du_lion == -1 and lr.sprite.scale.x == -1.0 and lr.gerbe.bouche.position.x == lr.gerbe.BOUCHE_X_GAUCHE,
		"un pas vers la gauche retourne le lion et sa gerbe")
	lr.global_position = Vector2(-50, -50)
	lr.avancer(Vector2(-1, -1).normalized(), dt_pas)
	_check(lr.global_position == Vector2(0, -lr.etiquette_pseudo.position.y if lr.etiquette_pseudo.visible else 0.0)
		and lr.velocity == Vector2.ZERO, "un pas hors de l'écran le ramène au bord, sans vitesse fantôme (%s)" % lr.global_position)
	lr.deplacement.vitesse = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	# Phase 16 : hors d'une image physique (le sondage réseau, où arrivent les états de l'hôte), le pas
	# est refusé : `move_and_slide` y intégrerait le delta de traitement
	await process_frame
	var x_hors: float = lr.global_position.x
	_check(not lr.avancer(Vector2.RIGHT, dt_pas) and lr.global_position.x == x_hors and lr.deplacement.vitesse == Vector2.ZERO,
		"hors d'une image physique, le pas est refusé : le lion ne bouge pas (ligne ERROR attendue)")
	await _frames(1)
	# Phase 16 : chez l'hôte, chaque tick écrit l'état du lion, que son Synchro recopie chez les clients
	lr.global_position = Vector2(640, 320)
	await _frames(2)
	var etat_lr: Dictionary = EtatLion.decoder(lr.etat_reseau)
	_check(not etat_lr.is_empty() and etat_lr.position == lr.position and etat_lr.vitesse == lr.deplacement.vitesse
		and etat_lr.recul == lr.deplacement.recul and etat_lr.direction == lr.direction_du_lion and etat_lr.commande == 0,
		"chaque tick, l'hôte écrit l'état du lion : position, vitesse commandée, recul, orientation (aucune commande de client)")

	# Phase 14 : sur un client, un lion n'est qu'une réplique du lion de l'hôte (état et vomi reçus par
	# son Synchro ; réactions par les signaux de son joueur). Phase 16 : il est interpolé entre les états
	var synchro_lion := lr.get_node_or_null("Synchro") as MultiplayerSynchronizer
	var config_lion: SceneReplicationConfig = null if synchro_lion == null else synchro_lion.replication_config
	_check(config_lion != null and config_lion.get_properties() == [^".:etat_reseau", ^".:vomi_de_l_hote"]
		and config_lion.property_get_replication_mode(^".:etat_reseau") == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		and config_lion.property_get_replication_mode(^".:vomi_de_l_hote") == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		and not config_lion.property_get_spawn(^".:etat_reseau") and config_lion.property_get_spawn(^".:vomi_de_l_hote"),
		"le Synchro du lion réplique son état en continu (sans rien à l'apparition) et son vomi à chaque changement (dès l'apparition)")
	var poste_lion := Node2D.new()
	poste_lion.name = "PosteClientLion"
	root.add_child(poste_lion)
	var api_lion := SceneMultiplayer.new()
	var pair_lion := ENetMultiplayerPeer.new()
	_check(pair_lion.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour la réplique d'un lion")
	api_lion.multiplayer_peer = pair_lion
	set_multiplayer(api_lion, poste_lion.get_path())
	var j_repl := Joueur.new()
	j_repl.couleur = EtatPartie.PALETTE_BATAILLE[3]
	j_repl.reinitialiser(3, j_repl.nuances())
	var repl: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	repl.joueur = j_repl
	repl.commandes = Commandes.manuelles()
	repl.direction_du_lion = -1  # comme l'état d'apparition reçu de l'hôte, posé avant `_ready`
	repl.position = Vector2(600, 500)
	poste_lion.add_child(repl)
	await _frames(1)
	_check(repl.sprite.scale.x == -1.0 and repl.gerbe.bouche.position.x == repl.gerbe.BOUCHE_X_GAUCHE,
		"sur un client, l'orientation reçue à l'apparition est appliquée (sprite et bouche à gauche)")
	repl.commandes.direction_voulue = Vector2.RIGHT
	repl.commandes.vomir_voulu = true
	await _frames(5)
	_check(repl.position == Vector2(600, 500) and repl.velocity == Vector2.ZERO and not repl.est_en_train_de_vomir,
		"sur un client, un lion ne suit pas ses commandes : il ne bouge ni ne vomit de lui-même")
	# Ce qu'écrit le Synchro : un état par tick de l'hôte, le lion filant vers la droite à 350 px/s
	var pas_repl := 350.0 / 60.0
	for i in range(12):
		repl.etat_reseau = EtatLion.encoder(1000 + i, 0, Vector2(700 + i * pas_repl, 500), Vector2(350, 0), Vector2.ZERO, 1)
		await _frames(1)
	repl.vomi_de_l_hote = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process
	await _frames(1)
	_check(repl.position.y == 500.0 and repl.position.x > 700.0 and repl.position.x < 700.0 + 11 * pas_repl and repl.sprite.scale.x == 1.0
		and repl.velocity == Vector2(350, 0) and repl.deplacement.vitesse == Vector2(350, 0)
		and repl.est_en_train_de_vomir and repl.gerbe.vomi_container.get_children().all(func(e: GPUParticles2D) -> bool: return e.emitting),
		"la réplique suit les états reçus, interpolés avec un peu de retard (x = %.1f) : position, vitesse (son animation), orientation, vomi (particules)" % repl.position.x)
	await _frames(30)
	var arret_repl: Vector2 = repl.position
	_check(arret_repl.is_equal_approx(Vector2(700 + (11 + InterpolationLion.EXTRAPOLATION_MAX) * pas_repl, 500)) and repl.velocity == Vector2.ZERO,
		"plus aucun état (hôte figé) : la réplique continue %d ticks sur sa vitesse, puis s'arrête là, sans revenir en arrière (M2, x = %.1f)"
			% [int(InterpolationLion.EXTRAPOLATION_MAX), arret_repl.x])
	repl.vomi_de_l_hote = false
	for i in range(3):
		await process_frame
	_check(not repl.est_en_train_de_vomir, "la réplique arrête de vomir avec le lion de l'hôte")
	j_repl.etourdir(ReglesBataille.DUREE_ETOURDI_VOMI, ReglesBataille.DUREE_IMMUNITE, repl.global_position + Vector2(-50, 66), j_rouge.couleur)
	await _frames(2)
	var mat_repl := repl.sprite.material as ShaderMaterial
	_check(repl.etoiles.visible and mat_repl.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur and repl.position == arret_repl,
		"un étourdissement reçu de l'hôte s'affiche sur la réplique (étoiles, barbouillage), sans la déplacer")
	j_repl.recevoir_fin_etourdissement(ReglesBataille.DUREE_IMMUNITE)
	await _frames(2)
	_check(not repl.etoiles.visible and mat_repl.get_shader_parameter("barbouillage_force") == 0.0
		and repl._clignotement != null and repl._clignotement.is_running(),
		"la fin d'étourdissement reçue efface étoiles et barbouillage, l'immunité clignote")
	# Phase 18 : la fin de manche pose sur la réplique l'état final de l'hôte, au pixel près ; elle ne
	# bouge plus, même quand un état de l'hôte encore en route arrive après
	var final_hote := EtatLion.encoder(1011, 0, Vector2(700 + 11 * pas_repl, 500), Vector2(350, 0), Vector2(40, 0), -1)
	_check(not repl.poser_etat_final(PackedByteArray([1, 2, 3])) and not repl.fige and repl.poser_etat_final(final_hote),
		"un état final illisible est refusé sans rien changer ; celui de l'hôte est posé")
	repl.etat_reseau = EtatLion.encoder(1012, 0, Vector2(900, 500), Vector2(350, 0), Vector2.ZERO, 1)
	await _frames(3)
	_check(repl.fige and repl.position == Vector2(700 + 11 * pas_repl, 500) and repl.direction_du_lion == -1 and repl.velocity == Vector2.ZERO
		and repl.deplacement.vitesse == Vector2.ZERO and repl.deplacement.recul == Vector2.ZERO,
		"la réplique prend l'état final de l'hôte (place, sens, à l'arrêt) et ne suit plus les états arrivés après (x = %.1f)" % repl.position.x)
	repl.free()
	set_multiplayer(null, poste_lion.get_path())
	pair_lion.close()
	poste_lion.free()

	# Phase 15 bis : un lion libéré (départ d'un joueur, fin de manche) alors que son joueur reste
	# (GameState le garde) ne doit plus rien recevoir de lui : ni le lion ni ses composants
	var ids_lions: Array = lions_bataille.map(func(l: Node) -> int: return l.get_instance_id()) \
		+ lions_bataille.map(func(l: Node) -> int: return l.gerbe.get_instance_id()) \
		+ lions_bataille.map(func(l: Node) -> int: return l.pare_chocs.get_instance_id())
	for l in lions_bataille:
		l.free()
	var restes := 0
	for j: Joueur in [j_rouge, j_bleu]:
		for s: Signal in [j.couleur_debloquee, j.bonus_change, j.touche, j.crans_changes, j.etourdi, j.etourdissement_fini]:
			restes += s.get_connections().filter(func(c: Dictionary) -> bool: return ids_lions.has((c.callable as Callable).get_object_id())).size()
	_check(restes == 0, "un lion libéré n'est plus abonné aux signaux de son joueur (%d abonnements restants)" % restes)
	j_rouge.etourdir(1.0, 1.0, Vector2.INF, j_bleu.couleur)
	j_rouge.activer_bonus(1.0)
	j_bleu.recevoir_crans(3)
	j_bleu.recevoir_fin_etourdissement(0.0)
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	# Territoire : la ville d'une bataille tient la grille de propriété, dans une scène propre
	# (sa ville, ses deux lions). Aucun ennemi des sections précédentes ne doit y entrer.
	for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
		ennemi.free()
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	var j_r: Joueur = GS.joueurs[0]
	var j_b: Joueur = GS.joueurs[1]
	var ville_b: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	root.add_child(ville_b)
	ville_b.position = Vector2(1000, 648 - ville_b.tex_size.y / 2.0)  # comme Main._placer_ville
	var lions_t: Array[CharacterBody2D] = []
	for j: Joueur in GS.joueurs:
		var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 1000 * lions_t.size(), 0)
		root.add_child(l)
		lions_t.append(l)
	var l_r: CharacterBody2D = lions_t[0]
	var l_b: CharacterBody2D = lions_t[1]
	var poste_peinture := Vector2(600, ville_b.position.y - 300)
	await _frames(2)
	var t: Territoire = ville_b.territoire
	_check(t != null and t.nb_peignables == ville_b.cellules_peignables and t.cellules_de(0) == 0 and t.cellules_de(1) == 0,
		"en bataille, la ville tient un territoire vierge sur ses cellules peignables (%d)" % ville_b.cellules_peignables)
	_check(l_r.gerbe.traceuse_shape.shape.radius == l_b.gerbe.traceuse_shape.shape.radius and j_r.couleurs_debloquees.size() == j_b.couleurs_debloquees.size(),
		"(pré-condition) les deux lions ont le même rayon et autant de couleurs (trois nuances)")

	# Le lion rouge peint : ses cellules comptent pour lui, dans ses nuances
	l_r.global_position = poste_peinture
	await _frames(1)
	l_r.commandes.vomir_voulu = true
	await _frames(40)
	l_r.commandes.vomir_voulu = false
	await _frames(2)
	var cellules_rouges: int = t.cellules_de(0)
	var rgba32_rouge: Array = j_r.nuances().map(_rgba8)
	var rgba32_bleu: Array = j_b.nuances().map(_rgba8)
	_check(cellules_rouges > 0 and t.cellules_de(1) == 0, "les cellules que peint un lion comptent pour son joueur (%d)" % cellules_rouges)
	_check(not _couleurs_peintes(ville_b.image).is_empty()
		and _couleurs_peintes(ville_b.image).keys().all(func(k: int) -> bool: return rgba32_rouge.has(k)),
		"le lion rouge peint dans ses nuances")
	_check(t.extraire_changements().size() == cellules_rouges and t.extraire_changements().is_empty(),
		"les cellules qui se mettent à compter sont listées pour la synchronisation, une fois")

	# Le lion bleu repeint au même endroit : il vole les cellules du rouge, dans ses propres nuances
	l_r.global_position = Vector2(1500, 0)
	l_b.global_position = poste_peinture
	await _frames(1)
	ville_b.image.fill(Color(0, 0, 0, 0))
	ville_b.coulures.clear()
	l_b.commandes.vomir_voulu = true
	await _frames(40)
	l_b.commandes.vomir_voulu = false
	await _frames(2)
	_check(not _couleurs_peintes(ville_b.image).is_empty()
		and _couleurs_peintes(ville_b.image).keys().all(func(k: int) -> bool: return rgba32_bleu.has(k)),
		"à rayon et nombre de couleurs égaux, le second lion peint dans ses propres nuances")
	_check(t.cellules_de(1) > 0 and t.cellules_de(0) < cellules_rouges and j_b.cellules_volees > 0
		and j_b.cellules_volees == cellules_rouges - t.cellules_de(0) and j_r.cellules_volees == 0,
		"repeindre les cellules d'un autre les lui vole ; les règles comptent les vols (%d volées, %d restent au rouge)" % [j_b.cellules_volees, t.cellules_de(0)])

	# Sur un client, la ville dessine le tampon mais ne touche pas au territoire : l'hôte décide
	var api_ville := SceneMultiplayer.new()
	var pair_ville := ENetMultiplayerPeer.new()
	_check(pair_ville.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour la ville")
	api_ville.multiplayer_peer = pair_ville
	set_multiplayer(api_ville, ville_b.get_path())
	var scores_avant := [t.cellules_de(0), t.cellules_de(1)]
	var point_vierge := Vector2(1800, 648 - 20)  # bas de la skyline, à droite : jamais peint ici
	ville_b.image.fill(Color(0, 0, 0, 0))
	for i in range(10):
		ville_b.peindre(point_vierge, 30, j_r)
	_check(not ville_b.multiplayer.is_server() and not _couleurs_peintes(ville_b.image).is_empty()
		and [t.cellules_de(0), t.cellules_de(1)] == scores_avant,
		"sur un client, la ville dessine les tampons sans toucher au territoire")
	set_multiplayer(null, ville_b.get_path())
	pair_ville.close()
	for i in range(10):
		ville_b.peindre(point_vierge, 30, j_r)
	_check(t.cellules_de(0) > scores_avant[0], "de retour sur l'hôte, les mêmes tampons comptent")

	# Phase 14 : chaque tampon de l'hôte part en événement ; un client le dessine à l'identique (même
	# jeu de tampons, même variante, même coulure), centres négatifs compris, sans le rediffuser ni
	# toucher à son territoire. La traceuse d'un lion de client ne peint pas.
	var emis: Array[Dictionary] = []
	var sur_tampon := func(tampon: Dictionary) -> void: emis.append(tampon)
	ville_b.tampon_peint.connect(sur_tampon)
	ville_b.image.fill(Color(0, 0, 0, 0))
	ville_b.coulures.clear()
	ville_b._nb_tampons = 0  # comme une ville neuve : le plafond des coulures compte en tampons peints
	ville_b._tampons_des_coulures.clear()
	var coin_ville: Vector2 = ville_b.position - Vector2(ville_b.tex_size) / 2.0
	ville_b.peindre(coin_ville + Vector2(-10, 40), 30, j_r)  # déborde à gauche : x négatif
	for i in range(40):
		ville_b.peindre(coin_ville + Vector2(200 + 11 * i, 60), 21, j_b)
	ville_b.tampon_peint.disconnect(sur_tampon)
	_check(emis.size() == 41 and emis[0].index == 0 and emis[0].x == -10 and emis[0].rayon == 30 and emis[1].index == 1
		and ville_b.coulures.size() > 0,
		"sur l'hôte, chaque tampon part en événement (index du peintre, centre en pixels de la ville, rayon, graine), coulures comprises")
	var poste_c := Node2D.new()
	poste_c.name = "PosteClientVille"
	root.add_child(poste_c)
	var api_c := SceneMultiplayer.new()
	var pair_c := ENetMultiplayerPeer.new()
	_check(pair_c.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour la ville d'un client")
	api_c.multiplayer_peer = pair_c
	set_multiplayer(api_c, poste_c.get_path())
	var ville_c: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	ville_c.position = ville_b.position
	poste_c.add_child(ville_c)
	var emis_client: Array[Dictionary] = []
	ville_c.tampon_peint.connect(func(tampon: Dictionary) -> void: emis_client.append(tampon))
	for tampon in emis:
		ville_c.peindre_tampon_recu(tampon)
	_check(not ville_c.multiplayer.is_server() and ville_c.image.get_data() == ville_b.image.get_data()
		and ville_c.coulures == ville_b.coulures,
		"chez un client, les tampons reçus se dessinent pixel pour pixel comme chez l'hôte, coulures comprises (%d coulures)" % ville_c.coulures.size())
	_check(emis_client.is_empty() and ville_c.territoire.cellules_de(0) == 0 and ville_c.territoire.cellules_de(1) == 0,
		"un client ne rediffuse pas les tampons reçus et ne les compte pas dans son territoire")
	ville_c.peindre_tampon_recu({"index": 7, "x": 500, "y": 50, "rayon": 20, "graine": 1})
	_check(ville_c.image.get_data() == ville_b.image.get_data(), "un tampon reçu pour un joueur inconnu de ce poste est ignoré")
	# Les mêmes 400 tampons, l'un d'un coup, l'autre avec des coulures qui finissent entre deux
	# tampons (un autre rythme d'affichage) : les mêmes coulures sont lancées
	var ville_d: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	var ville_e: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	for v: Node2D in [ville_d, ville_e]:
		v.position = ville_b.position
		poste_c.add_child(v)
	for g in range(400):
		var tampon := {"index": 1, "x": 100 + (g * 7) % 1800, "y": 60, "rayon": 21, "graine": g}
		ville_d.peindre_tampon_recu(tampon)
		ville_e.peindre_tampon_recu(tampon)
		ville_e._avancer_coulures(1.0)
	_check(ville_d._tampons_des_coulures == ville_e._tampons_des_coulures and ville_d._tampons_des_coulures.size() > 0
		and ville_d.coulures.size() > ville_e.coulures.size(),
		"les mêmes tampons lancent les mêmes coulures, quel que soit le rythme d'affichage (plafond compté en tampons)")
	ville_d.free()
	ville_e.free()
	var lion_c: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	lion_c.joueur = j_r
	lion_c.commandes = Commandes.manuelles()
	poste_c.add_child(lion_c)
	lion_c.global_position = poste_peinture
	await _frames(2)
	emis.clear()
	ville_b.tampon_peint.connect(sur_tampon)
	lion_c.gerbe.traceuse.monitoring = true  # comme un vomi répliqué
	await _frames(5)
	_check(lion_c.gerbe.traceuse.get_overlapping_areas().size() > 0 and emis.is_empty(),
		"la traceuse d'un lion de client, au-dessus de la ville, ne peint pas (seule celle de l'hôte peint)")
	ville_b.tampon_peint.disconnect(sur_tampon)
	lion_c.free()
	set_multiplayer(null, poste_c.get_path())
	pair_c.close()
	poste_c.free()

	# Après terminer_partie, partie_en_cours retombe mais pret reste vrai (pas de retour à
	# l'intro) ; un lion peut donc encore peindre. Le tampon visuel doit rester, mais plus aucun
	# score de territoire ne doit bouger.
	GS.terminer_partie(true)
	_check(GS.pret and not GS.partie_en_cours, "(pré-condition) la manche est terminée mais le jeu reste « pret »")
	var scores_manche_finie := [t.cellules_de(0), t.cellules_de(1)]
	var volees_manche_finie := [j_r.cellules_volees, j_b.cellules_volees]
	ville_b.image.fill(Color(0, 0, 0, 0))
	ville_b.coulures.clear()
	l_r.global_position = poste_peinture  # cellules déjà possédées par le bleu : un vol s'y verrait
	await _frames(1)
	l_r.commandes.vomir_voulu = true
	await _frames(20)
	l_r.commandes.vomir_voulu = false
	await _frames(2)
	_check(_couleurs_peintes(ville_b.image).keys().any(func(k: int) -> bool: return rgba32_rouge.has(k))
		and [t.cellules_de(0), t.cellules_de(1)] == scores_manche_finie
		and [j_r.cellules_volees, j_b.cellules_volees] == volees_manche_finie,
		"après la fin de la manche, peindre dessine toujours le tampon mais ne change plus aucun score de territoire")

	# Éviction du cache des tampons : au-delà de TAMPONS_EN_CACHE_MAX jeux, le cache repart de zéro
	# (M4) ; passer par l'instance, le test ne peut pas nommer le script de la ville.
	for r in range(1, ville_b.TAMPONS_EN_CACHE_MAX + 2):
		ville_b._tampons_pour(r, j_r.couleurs_debloquees)
	_check(ville_b._tampons.size() <= ville_b.TAMPONS_EN_CACHE_MAX,
		"le cache des tampons ne dépasse jamais TAMPONS_EN_CACHE_MAX jeux (%d)" % ville_b._tampons.size())
	var gros_tampons: Array = ville_b._tampons_pour(97, j_r.couleurs_debloquees)
	_check(gros_tampons.size() == ville_b.NB_TAMPONS and gros_tampons.all(func(im: Image) -> bool: return im.get_width() == 195),
		"un jeu de tampons régénéré après éviction reste correct (rayon 97 -> 195 px)")

	for l in lions_t:
		l.free()
	ville_b.free()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	await _tester_manche_reseau()
	await _tester_resultats_reseau()

	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## Phase 3 du jeu en ligne : l'écran En ligne (pseudo, Créer une partie, Rejoindre avec un code de salle
## ou, sur le desktop, l'adresse d'un hôte ENet ; les refus, les échecs et leur message, spec §9 ; un poste
## sans transport). Les signaux de `Reseau` sont émis comme il le fait (après être revenu hors réseau pour
## les échecs) : le transport lui-même est couvert par tests/reseau/lancer.sh.
func _tester_ecran_en_ligne(scores: Node, params: Node) -> void:
	print("-- Écran En ligne")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	scores.definir_preference("pseudo", "Léa")
	var connexions_langue: int = params.langue_changee.get_connections().size()
	var ecran: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran.port_jeu = 17797
	ecran.codes_de_salle = true  # comme sur le Web
	root.add_child(ecran)
	await _frames(1)

	# Accueil : 16:9, Créer une partie au focus, pseudo mémorisé et borné, un exemple de code
	_check(root.content_scale_size == Vector2i(2000, 1125) and ecran.etat == ecran.Etat.ACCUEIL and ecran.bouton_creer.has_focus()
		and ecran.message.text.is_empty(), "l'écran En ligne passe en 16:9 ; à l'accueil, Créer une partie a le focus")
	_check(ecran.champ_pseudo.text == "Léa" and ecran.champ_pseudo.max_length == reseau.PSEUDO_MAX and ecran.champ_code.placeholder_text == "K7Q-2XM",
		"le pseudo mémorisé est repris, la saisie bornée à %d caractères ; le champ du code montre « K7Q-2XM »" % reseau.PSEUDO_MAX)

	# Un code mal formé est refusé à la saisie (spec §9), sans rien tenter, le focus sur le code
	# L'adresse ip:port d'un hôte ENet n'est pas un code sur le Web : mal formée, pas une confusion (ses 0 et
	# ses 1 ne sont pas ceux d'un code), et rien n'est tenté
	var refus := {"K7Q2X": "ENLIGNE_CODE_FORMAT", "K7Q-2XM9": "ENLIGNE_CODE_FORMAT", "": "ENLIGNE_CODE_FORMAT", "k7q-2o1": "ENLIGNE_CODE_CONFUSION",
		"192.168.1.20:7777": "ENLIGNE_CODE_FORMAT"}
	var faux: Array[String] = []
	for saisie: String in refus:
		ecran.champ_code.text = saisie
		ecran.bouton_creer.grab_focus()
		ecran.rejoindre()
		if ecran.etat != ecran.Etat.ACCUEIL or reseau.en_ligne() or ecran.message.text != tr(refus[saisie]) or not ecran.champ_code.has_focus():
			faux.append("%s → %s" % [saisie, ecran.message.text])
	_check(faux.is_empty() and tr("ENLIGNE_CODE_FORMAT") == "Un code fait 6 caractères (ex. K7Q-2XM)."
		and tr("ENLIGNE_CODE_CONFUSION") == "Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM).",
		"un code mal formé est refusé à la saisie : « Un code fait 6 caractères (ex. K7Q-2XM). », un 0, O, 1, I ou L a son message (%s)" % [faux])

	# Un code bien formé, sans transport sur ce poste (l'export Web avant la phase 4)
	reseau.transport_disponible = false
	ecran.champ_code.text = " k7q 2xm"
	ecran.rejoindre()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.champ_code.text == "K7Q-2XM"
		and ecran.message.text == tr("ENLIGNE_INDISPONIBLE"),
		"un code bien formé s'affiche « K7Q-2XM » ; sans transport, Rejoindre le dit sans rien ouvrir (%s)" % ecran.message.text)
	ecran.message.text = ""
	ecran.creer_partie()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == tr("ENLIGNE_INDISPONIBLE"),
		"... et Créer une partie aussi")
	# Le lien d'invitation collé entier dans le champ (avec le saut de ligne d'un message) : Rejoindre part
	# avec son code ; un lien sans code valide est un code mal formé (pas une confusion : ses I, L et O)
	ecran.champ_code.text = CodeSalle.lien("k7q2xm") + char(0x0A)
	var colle: int = ecran.champ_code.text.length()
	ecran.message.text = ""
	ecran.rejoindre()
	_check(ecran.champ_code.max_length == 256 and colle == CodeSalle.lien("k7q2xm").length() + 1
		and ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.champ_code.text == "K7Q-2XM"
		and ecran.message.text == tr("ENLIGNE_INDISPONIBLE"),
		"le lien d'invitation collé entier (256 caractères permis, %d collés) : Rejoindre part avec son code, affiché « %s » (%s)" % [colle, ecran.champ_code.text, ecran.message.text])
	ecran.champ_code.text = CodeSalle.url_page() + "?relais=1"
	ecran.bouton_creer.grab_focus()
	ecran.rejoindre()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == tr("ENLIGNE_CODE_FORMAT")
		and ecran.champ_code.has_focus(), "un lien sans code : « Un code fait 6 caractères (ex. K7Q-2XM). », le focus au code (%s)" % ecran.message.text)
	reseau.transport_disponible = true

	# Un échec local de Rejoindre, le code bien formé mais refusé par le transport (ici ENet, qui attend
	# ip:port : ERR_INVALID_PARAMETER) : son code d'erreur, rien d'ouvert, le focus au code
	var impossible := "Impossible de rejoindre (erreur %d)"
	ecran.champ_code.text = "K7Q2XM"
	ecran.bouton_creer.grab_focus()
	ecran.rejoindre()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == impossible % ERR_INVALID_PARAMETER
		and ecran.champ_code.has_focus() and tr("ENLIGNE_REJOINDRE_IMPOSSIBLE") == impossible
		and TranslationServer.get_translation_object("en").get_message("ENLIGNE_REJOINDRE_IMPOSSIBLE") == "Can't join (error %d)",
		"un code refusé par le transport : « Impossible de rejoindre (erreur %d) », le focus au code (%s)" % [ERR_INVALID_PARAMETER, ecran.message.text])

	# Le desktop de développement : l'adresse ENet d'un hôte ; la connexion, le pseudo nettoyé
	ecran.codes_de_salle = false
	ecran.champ_code.text = "lelion.local"
	ecran.rejoindre()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == tr("ENLIGNE_ADRESSE_INVALIDE")
		and ecran.champ_code.has_focus(), "sur le desktop, un nom d'hôte est refusé sans rien tenter (%s)" % ecran.message.text)
	ecran.champ_pseudo.text = " Zoé la grande dompteuse"
	ecran.champ_code.text = " 127.000.0.1:17796 "  # personne n'y écoute
	ecran.rejoindre()
	_check(ecran.etat == ecran.Etat.CONNEXION and reseau.en_ligne() and not root.multiplayer.is_server()
		and ecran.champ_code.text == "127.0.0.1:17796" and ecran.message.text == tr("RESEAU_CONNEXION") % "127.0.0.1:17796",
		"une adresse ENet lance la connexion, normalisée (%s)" % ecran.message.text)
	_check(reseau.pseudo == "Zoé la gran" and ecran.champ_pseudo.text == "Zoé la gran" and scores.preference("pseudo", "") == "Zoé la gran",
		"le pseudo nettoyé (sans l'espace de tête) est donné à Reseau et mémorisé (%s)" % reseau.pseudo)
	_check(ecran.bouton_creer.disabled and ecran.bouton_rejoindre.disabled and not ecran.champ_code.editable and not ecran.champ_pseudo.editable
		and ecran.bouton_retour.has_focus(), "pendant la connexion, tout est grisé sauf Retour, qui a le focus")
	reseau.inscrit.emit(2, palette[2])
	_check(ecran.etat == ecran.Etat.SALON and ecran.bouton_creer.disabled, "inscrit par l'hôte : en route vers le salon, tout reste grisé")
	var salon_client: Node = await _attendre_scene("res://Scenes/Salon.tscn")
	_check(salon_client != null and salon_client.scene_file_path == "res://Scenes/Salon.tscn" and reseau.en_ligne(),
		"puis le salon prend la suite, toujours en ligne")
	if salon_client != null:
		salon_client.free()
	reseau.quitter()
	reseau.hote_perdu.emit()
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.message.text == tr("RESEAU_HOTE_PERDU") and ecran.bouton_creer.has_focus(),
		"hôte perdu : « L'hôte a quitté la partie », retour à l'accueil, Créer une partie au focus")

	# Chaque échec de connexion a son message (spec §9), le focus rendu au code
	var service := "Service de connexion indisponible, réessaie dans un instant."
	var canal := "Connexion impossible avec l'hôte (réseau trop restrictif ?)"
	var attendus := {Transport.ECHEC_INCONNUE: "Aucune partie avec ce code.", Transport.ECHEC_EXPIREE: "Aucune partie avec ce code.",
		Transport.ECHEC_QUOTA: "Trop de parties en ce moment, réessaie plus tard.", Transport.ECHEC_PLEINE: tr("RESEAU_REFUS_PLEIN"),
		Transport.ECHEC_ORIGINE: service, Transport.ECHEC_DEBIT: service, Transport.ECHEC_INJOIGNABLE: service,
		Transport.ECHEC_DELAI: canal, "": canal, "raison_inconnue": canal}
	faux.clear()
	for raison: String in attendus:
		ecran.rejoindre()
		reseau.quitter()
		reseau.raison_echec = raison
		reseau.connexion_echouee.emit()
		if ecran.etat != ecran.Etat.ACCUEIL or ecran.message.text != attendus[raison] or not ecran.champ_code.has_focus():
			faux.append("%s → %s" % [raison, ecran.message.text])
	_check(faux.is_empty(), "chaque raison d'échec du transport a son message, le focus rendu au code (%s)" % [faux])
	reseau.raison_echec = ""
	ecran.rejoindre()
	reseau._transport.echec.emit(Transport.ECHEC_INCONNUE)  # ce que dira TransportWebRTC d'un code sans salle (phase 4)
	var fin := Time.get_ticks_msec() + 1000
	while ecran.etat != ecran.Etat.ACCUEIL and Time.get_ticks_msec() < fin:
		await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == "Aucune partie avec ce code.",
		"un vrai échec du transport, sa raison passée par Reseau : « Aucune partie avec ce code. » (%s)" % ecran.message.text)
	var refus_attendus := {reseau.REFUS_VERSION: tr("RESEAU_REFUS_VERSION") % "0.9", reseau.REFUS_PLEIN: tr("RESEAU_REFUS_PLEIN"),
		reseau.REFUS_MANCHE: tr("RESEAU_REFUS_MANCHE"), reseau.REFUS_DEMANDE: tr("RESEAU_REFUS_DEMANDE"), "RAISON_INCONNUE": tr("RESEAU_REFUS_DEMANDE")}
	faux.clear()
	for raison: String in refus_attendus:
		ecran.rejoindre()
		reseau.quitter()
		reseau.refuse.emit(raison, "0.9")
		if ecran.etat != ecran.Etat.ACCUEIL or ecran.message.text != refus_attendus[raison] or ecran.message.text.begins_with("RESEAU_"):
			faux.append("%s → %s" % [raison, ecran.message.text])
	_check(faux.is_empty(), "chaque refus de l'hôte a son texte traduit, une raison inconnue lue comme demande incomprise (%s)" % [faux])

	# Créer une partie : en ligne, hôte, puis le salon ; Échap arrête
	ecran.creer_partie()
	_check(ecran.etat == ecran.Etat.SALON and reseau.en_ligne() and root.multiplayer.is_server() and reseau.inscrits[1].pseudo == "Zoé la gran"
		and reseau.code_partie == "127.0.0.1:17797" and ecran.bouton_retour.has_focus(),
		"Créer une partie : ce poste héberge avec son pseudo, le code de la partie est celui du transport (%s)" % reseau.code_partie)
	ecran.creer_partie()
	_check(reseau.en_ligne() and reseau.inscrits.size() == 1 and ecran.etat == ecran.Etat.SALON, "un second Créer avant le changement de scène ne relance rien")
	var salon_hote: Node = await _attendre_scene("res://Scenes/Salon.tscn")
	_check(salon_hote != null and salon_hote.scene_file_path == "res://Scenes/Salon.tscn" and reseau.en_ligne() and root.multiplayer.is_server(),
		"puis le salon prend la suite, toujours hôte")
	if salon_hote != null:
		salon_hote.free()
	var echap := InputEventAction.new()
	echap.action = "ui_cancel"
	echap.pressed = true
	root.push_input(echap)
	await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text.is_empty(), "Échap (ou B) arrête d'héberger et revient à l'accueil")

	# Créer une partie dont le transport ne donne son code qu'après coup (WebRTC : la salle de la
	# signalisation, simulée par `TransportSalle`) : l'écran attend (CREATION), sans se fier à
	# `en_ligne()` ; un échec avant le code a son message ; le salon s'ouvre au code, et dit la salle fermée
	var transports: Array[TransportSalle] = []
	reseau.fabrique_transport = func(_port: int) -> Transport:
		transports.append(TransportSalle.new())
		return transports[-1]
	ecran.creer_partie()
	_check(ecran.etat == ecran.Etat.CREATION and reseau.code_partie.is_empty() and ecran.message.text == "Création de la partie…"
		and ecran.bouton_creer.disabled and ecran.bouton_rejoindre.disabled and ecran.bouton_retour.has_focus(),
		"sans code du transport, Créer une partie attend : « Création de la partie… », tout grisé sauf Retour (%s)" % ecran.message.text)
	reseau.salon_change.emit()
	_check(ecran.etat == ecran.Etat.CREATION, "une table du salon sans code ne suffit pas")
	transports[-1].echec.emit(Transport.ECHEC_QUOTA)
	var fin_creation := Time.get_ticks_msec() + 1000
	while ecran.etat != ecran.Etat.ACCUEIL and Time.get_ticks_msec() < fin_creation:
		await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == "Trop de parties en ce moment, réessaie plus tard."
		and ecran.bouton_creer.has_focus(),
		"la création échoue avant le code (quota) : son message, retour à l'accueil, Créer une partie au focus (%s)" % ecran.message.text)
	# Pendant la création, une raison vide ou inconnue est la signalisation, pas l'hôte (il n'y en a pas)
	var messages_creation: Array[String] = []
	for raison: String in ["", "bizarre"]:
		ecran.creer_partie()
		transports[-1].echec.emit(raison)
		var fin_echec := Time.get_ticks_msec() + 1000
		while ecran.etat != ecran.Etat.ACCUEIL and Time.get_ticks_msec() < fin_echec:
			await process_frame
		messages_creation.append(ecran.message.text)
	_check(messages_creation == [service, service] and ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne(),
		"la création échoue sans raison, ou d'une raison inconnue : « %s », pas « Connexion impossible avec l'hôte » (%s)" % [service, messages_creation])
	ecran.creer_partie()
	ecran.retour(false)
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and transports[-1].pair() == null,
		"Retour pendant la création l'annule : l'accueil, hors réseau, le transport quitté")
	transports[-1].pret.emit("K7Q2XM")
	await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and reseau.code_partie.is_empty() and not reseau.en_ligne()
		and (current_scene == null or current_scene.scene_file_path != "res://Scenes/Salon.tscn"),
		"le pret d'une création annulée par Retour, arrivé après, est ignoré : l'accueil reste, pas de salon")
	ecran.creer_partie()
	transports[-1].pret.emit("K7Q2XM")
	_check(ecran.etat == ecran.Etat.SALON and reseau.code_partie == "K7Q2XM", "le code arrive (pret) : en route vers le salon")
	var salon_salle: Node = await _attendre_scene("res://Scenes/Salon.tscn")
	_check(salon_salle != null and salon_salle.rangee_invitation.visible and salon_salle.etiquette_code.text == "Code de la partie : K7Q-2XM"
		and salon_salle.bouton_copier.visible,
		"le salon de l'hôte montre le code et Copier le lien")
	if salon_salle != null:
		transports[-1].salle_fermee.emit(Transport.ECHEC_EXPIREE)
		_check(salon_salle.etiquette_code.text == "Salle expirée : crée une nouvelle partie pour inviter" and not salon_salle.bouton_copier.visible
			and reseau.en_ligne() and root.multiplayer.is_server(),
			"la salle expire : « Salle expirée : crée une nouvelle partie pour inviter », sans lien, la partie continue (%s)" % salon_salle.etiquette_code.text)
		transports[-1].salle_fermee.emit(Transport.ECHEC_INJOIGNABLE)
		_check(salon_salle.etiquette_code.text == "Invitations coupées : crée une nouvelle partie pour inviter" and not salon_salle.bouton_copier.visible,
			"la signalisation coupée : « Invitations coupées : crée une nouvelle partie pour inviter » (%s)" % salon_salle.etiquette_code.text)
		salon_salle.free()
	ecran.retour(false)  # l'écran, resté en SALON (le salon a pris la suite), revient à l'accueil, hors réseau
	reseau.fabrique_transport = Callable()

	# Port occupé, autre erreur ; changer de langue retraduit le message
	var occupant := ENetMultiplayerPeer.new()
	_check(occupant.create_server(17798) == OK, "(pré-condition) un autre programme occupe le port 17798")
	ecran.port_jeu = 17798
	ecran.creer_partie()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == "Impossible d'héberger : port 17798 occupé",
		"port occupé : « Impossible d'héberger : port 17798 occupé » (%s)" % ecran.message.text)
	params.definir_langue("en")
	await _frames(1)
	_check(ecran.message.text == "Can't host: port 17798 in use" and ecran.bouton_creer.text == "ENLIGNE_CREER" and tr(ecran.bouton_creer.text) == "Create a game",
		"changer de langue retraduit le message (%s)" % ecran.message.text)
	params.definir_langue("fr")
	occupant.close()
	var erreur_attendue := ENetMultiplayerPeer.new().create_server(70000)
	ecran.port_jeu = 70000
	ecran.creer_partie()
	_check(not reseau.en_ligne() and ecran.message.text == tr("RESEAU_HEBERGER_IMPOSSIBLE") % erreur_attendue,
		"une autre erreur d'hébergement donne son code (%s)" % ecran.message.text)
	ecran.port_jeu = 17797

	# Entrée dans le champ du pseudo : sans code, Créer une partie prend le focus ; avec un code, Rejoindre
	ecran.champ_code.text = ""
	ecran.champ_pseudo.text_submitted.emit("Zoé la gran")
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.bouton_creer.has_focus(), "Entrée sur le pseudo, sans code : Créer une partie au focus")
	ecran.champ_code.text = "127.0.0.1:17796"
	ecran.champ_pseudo.text_submitted.emit("Zoé la gran")
	_check(ecran.etat == ecran.Etat.CONNEXION and reseau.en_ligne(), "Entrée sur le pseudo, un code saisi : Rejoindre")

	# Retour (sans changer de scène : la navigation vers le titre est vérifiée avec le bouton Multijoueur) ;
	# l'écran retiré de l'arbre (pas encore détruit) ne laisse aucune connexion aux autoloads
	ecran.retour(false)
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne(), "Retour pendant une connexion l'annule : l'accueil, hors réseau")
	ecran.retour(false)
	_check(not reseau.en_ligne() and scores.preference("pseudo", "") == "Zoé la gran", "Retour à l'accueil quitte le réseau et garde le pseudo mémorisé")
	var langue_pendant: int = params.langue_changee.get_connections().size()
	root.remove_child(ecran)
	_check(reseau.inscrit.get_connections().is_empty() and reseau.refuse.get_connections().is_empty()
		and reseau.connexion_echouee.get_connections().is_empty() and reseau.hote_perdu.get_connections().is_empty()
		and reseau.salon_change.get_connections().is_empty() and langue_pendant == connexions_langue + 1 and params.langue_changee.get_connections().size() == connexions_langue,
		"l'écran retiré de l'arbre ne laisse aucune connexion aux autoloads, Parametres.langue_changee compris (%d connexion(s) avant l'écran, %d pendant, %d après)"
			% [connexions_langue, langue_pendant, params.langue_changee.get_connections().size()])
	ecran.free()
	reseau.pseudo = ""
	scores.effacer()


## Phase 12 bis : le bouton Multijoueur du titre, l'aller et retour avec l'écran En ligne (phase 3 du jeu en
## ligne), la page ouverte sur un lien d'invitation, et le titre qui remet toujours ce poste hors réseau
## avant le solo.
func _tester_titre_reseau(scores: Node) -> void:
	print("-- Titre et réseau")
	var reseau: Node = root.get_node("Reseau")

	# Titre : le bouton Multijoueur, dans l'écran, sans chevaucher les autres, joignable au clavier
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	var multi: Button = titre.bouton_multijoueur
	_check(multi != null and multi.get_parent() == titre and multi.text == "MULTIJOUEUR" and tr("MULTIJOUEUR") == "Multijoueur",
		"l'écran titre a un bouton Multijoueur, traduit")
	var rect_multi: Rect2 = multi.get_global_rect()
	var autres: Array = [titre.bouton_jouer, titre.bouton_reglages, titre.bouton_arcade, titre.get_node("Centre/Colonne/Aide")]
	_check(Rect2(Vector2.ZERO, Vector2(2000, 648)).encloses(rect_multi)
		and autres.all(func(c: Control) -> bool: return not c.get_global_rect().intersects(rect_multi)),
		"le bouton Multijoueur tient dans l'écran du titre sans chevaucher Jouer, Réglages, Arcade ni l'aide (%s)" % rect_multi)
	_check(titre.bouton_jouer.get_node(titre.bouton_jouer.focus_neighbor_right) == multi
		and multi.get_node(multi.focus_neighbor_left) == titre.bouton_jouer,
		"clavier et manette : droite depuis Jouer mène à Multijoueur, gauche en revient")
	multi.pressed.emit()
	var ecran: Control = (await _attendre_scene("res://Scenes/EcranEnLigne.tscn")) as Control
	titre.free()
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn", "Multijoueur ouvre l'écran En ligne")
	_check(ecran != null and not ecran.codes_de_salle and ecran.champ_code.max_length == 21,
		"sur le desktop, le champ du code prend une adresse ip:port (21 caractères au plus)")
	# Ne sauter que les vérifications qui dépendent de `ecran` : la remise à zéro de fin de fonction
	# doit tourner même si cette précondition échoue (sinon un seul échec ici laisse reseau dans un
	# état anormal pour la suite de la fonction et pour `_tester_salon`).
	if ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn":
		ecran.bouton_retour.pressed.emit()
		var titre_retour: Control = (await _attendre_scene("res://Scenes/Titre.tscn")) as Control
		_check(titre_retour != null and titre_retour.scene_file_path == "res://Scenes/Titre.tscn" and not is_instance_valid(ecran)
			and root.content_scale_size == Vector2i(2000, 648) and not reseau.en_ligne(),
			"Retour ramène au titre, en 2000×648, hors réseau")
		if titre_retour != null:
			titre_retour.free()

	# Une page ouverte sur un lien d'invitation (`?salle=`, spec §4.4) : l'écran En ligne, le code rempli,
	# Rejoindre au focus (le pseudo est mémorisé) ; ce poste ne rejoint qu'au Rejoindre du joueur
	scores.definir_preference("pseudo", "Léa")
	CodeSalle.recherche_forcee = "?relais=1&salle=k7q2xm"
	CodeSalle._page_lue = false
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	var invite: Control = (await _attendre_scene("res://Scenes/EcranEnLigne.tscn")) as Control
	titre.free()
	CodeSalle.recherche_forcee = ""
	_check(invite != null and invite.scene_file_path == "res://Scenes/EcranEnLigne.tscn",
		"une page ouverte sur un lien ?salle= passe du titre à l'écran En ligne")
	if invite != null and invite.scene_file_path == "res://Scenes/EcranEnLigne.tscn":
		_check(invite.champ_code.text == "K7Q-2XM" and invite.etat == invite.Etat.ACCUEIL and not reseau.en_ligne()
			and invite.message.text == tr("ENLIGNE_INVITATION") and invite.bouton_rejoindre.has_focus(),
			"le code du lien rempli (« K7Q-2XM »), Rejoindre au focus, rien de tenté : « %s »" % invite.message.text)
		invite.codes_de_salle = true  # comme sur le Web
		reseau.transport_disponible = false
		invite.champ_pseudo.text_submitted.emit("Léa")
		_check(invite.message.text == tr("ENLIGNE_INDISPONIBLE") and not reseau.en_ligne(),
			"le pseudo validé (Entrée), Rejoindre part avec le code du lien (ici sans transport : « %s »)" % invite.message.text)
		reseau.transport_disponible = true
		var second_titre: Control = load("res://Scenes/Titre.tscn").instantiate()
		second_titre.demo_autorisee = false
		root.add_child(second_titre)
		await _frames(3)
		_check(current_scene == invite and CodeSalle.prendre_code_de_la_page().is_empty(),
			"le lien ne sert qu'une fois : un titre suivant reste le titre")
		second_titre.free()
		invite.free()
	scores.effacer()

	# La même invitation sans pseudo mémorisé : le focus au pseudo, à choisir avant Rejoindre
	CodeSalle.recherche_forcee = "?salle=k7q2xm"
	CodeSalle._page_lue = false
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	var invite_anonyme: Control = (await _attendre_scene("res://Scenes/EcranEnLigne.tscn")) as Control
	titre.free()
	CodeSalle.recherche_forcee = ""
	_check(invite_anonyme != null and invite_anonyme.scene_file_path == "res://Scenes/EcranEnLigne.tscn"
		and invite_anonyme.champ_pseudo.text.is_empty() and invite_anonyme.champ_code.text == "K7Q-2XM"
		and invite_anonyme.champ_pseudo.has_focus() and not reseau.en_ligne(),
		"une invitation sans pseudo mémorisé : le code rempli, le focus au pseudo, rien de tenté")
	if invite_anonyme != null:
		invite_anonyme.free()

	# Retour au titre depuis une session : hors réseau AVANT le solo (point de vigilance de la phase 12)
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and reseau.inscrits.is_empty(),
		"après un hébergement, le titre remet ce poste hors réseau (plus d'arrivée)")
	titre.free()
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK and not root.multiplayer.is_server(), "(pré-condition) ce poste est un client")
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(root.multiplayer.is_server() and not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,
		"après une connexion, le titre rend ce poste hôte de lui-même : le solo qui suit tranche ses contacts (« un coup coûte une vie »)")
	titre.free()
	reseau.pseudo = ""
	scores.effacer()


## Phase 13 : le salon, sur un seul poste (le salon à plusieurs postes, du lancement de la manche
## compris, est couvert par tests/reseau/lancer.sh, scénario 8). Les arrivées sont simulées dans
## `Reseau.inscrits`, comme `Reseau` les y inscrit : place réservée, puis arrivée.
func _tester_salon(params: Node) -> void:
	print("-- Salon")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	reseau.pseudo = "MMMMMMMMMMMM"  # 12 caractères larges : ils doivent tenir dans la carte
	GS.niveau_courant = 1
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	Input.action_press("deplacer_droite")  # phase 18 (M3, revue finale 13) : un stick déjà penché en arrivant
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await process_frame
	await _appuyer(&"deplacer_droite", true)  # un événement de plus du stick toujours penché
	_check(reseau.inscrits[1].couleur == palette[0], "M3 : un stick déjà penché à l'ouverture du salon n'y change pas la couleur")
	await _appuyer(&"deplacer_droite", false)
	Input.action_release("deplacer_droite")

	# L'hôte seul : sa carte, les places libres, le niveau du titre, le code de la partie ; aucun focus
	var c0: Dictionary = salon.cartes[0]
	_check(root.content_scale_size == Vector2i(2000, 1125) and salon.cartes.size() == 6
		and salon.cartes.all(func(c: Dictionary) -> bool: return c.cadre.visible), "le salon est en 16:9, une carte par place (6)")
	_check(c0.pseudo.text == "MMMMMMMMMMMM" and c0.badge.text == "HÔTE · TOI" and c0.etat.text == tr("SALON_PAS_PRET")
		and c0.lion.material == c0.teinte and c0.teinte.get_shader_parameter("couleur_joueur") == palette[0] and c0.style.border_color == palette[0],
		"la carte de l'hôte : pseudo, badges, pas prêt, lion et contour à sa couleur")
	var police: Font = c0.pseudo.get_theme_font("font")
	var largeur_w: float = police.get_string_size("WWWWWWWWWWWW", HORIZONTAL_ALIGNMENT_LEFT, -1, c0.pseudo.get_theme_font_size("font_size")).x \
		+ 2 * c0.pseudo.get_theme_constant("outline_size")
	_check(largeur_w <= c0.pseudo.size.x and salon.rangee_cartes.get_combined_minimum_size().x <= 2000.0,
		"12 caractères larges (« WWWWWWWWWWWW », %d px) tiennent dans une carte (%d px) ; les six cartes dans l'écran" % [largeur_w, c0.pseudo.size.x])
	_check(salon.cartes.slice(1).all(func(c: Dictionary) -> bool: return c.pseudo.text == tr("SALON_LIBRE") and c.lion.material == null),
		"les autres places sont libres : une silhouette sans couleur")
	_check(salon.titre_niveau.text == "Niveau : Métropole" and reseau.niveau_salon == 1 and salon.aide.text == tr("SALON_AIDE_HOTE")
		and salon.etat.text == tr("SALON_ATTENTE_JOUEURS") and salon.bouton_demarrer.visible and salon.bouton_demarrer.disabled,
		"le niveau choisi au titre, l'aide de l'hôte, Démarrer grisé : « Il faut au moins 2 joueurs pour démarrer. »")
	_check(salon.rangee_invitation.visible and salon.etiquette_code.text == "Code de la partie : 127.0.0.1:17797" and not salon.bouton_copier.visible
		and salon.copier_lien().is_empty(), "sur le desktop, le code de la partie ENet (son adresse), sans lien à copier (%s)" % salon.etiquette_code.text)
	_check(root.gui_get_focus_owner() == null and salon.bouton_retour.focus_mode == Control.FOCUS_NONE and salon.bouton_copier.focus_mode == Control.FOCUS_NONE,
		"aucun contrôle ne prend le focus : flèches, croix, stick, vomir et démarrer vont au salon")
	# Une salle de la signalisation (le Web, phase 4) : son code, et « Copier le lien »
	var code_enet: String = reseau.code_partie
	reseau.code_partie = "K7Q2XM"
	reseau.salon_change.emit()
	_check(salon.etiquette_code.text == "Code de la partie : K7Q-2XM" and salon.bouton_copier.visible and salon.bouton_copier.text == "SALON_COPIER_LIEN",
		"un code de salle : « Code de la partie : K7Q-2XM » et « Copier le lien », relus à chaque changement du salon (%s)" % salon.etiquette_code.text)
	_check(salon.copier_lien() == "https://w3cdotorg.github.io/LeLion-web/?salle=K7Q2XM" and salon.bouton_copier.text == "SALON_LIEN_COPIE"
		and tr(salon.bouton_copier.text) == "Lien copié !", "Copier le lien : le lien d'invitation, et « Lien copié ! »")
	await create_timer(salon.DUREE_LIEN_COPIE + 0.2).timeout
	_check(salon.bouton_copier.text == "SALON_COPIER_LIEN", "%.0f s plus tard, le bouton redit « Copier le lien »" % salon.DUREE_LIEN_COPIE)
	reseau.code_partie = code_enet
	reseau.salon_change.emit()

	# Une place réservée (poignée de main en cours) n'a pas de carte ; un joueur arrivé a la sienne
	reseau.inscrits[7] = {"index": 2, "couleur": palette[2], "pseudo": "Rita", "arrive": false, "pret": false}
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "Bob", "arrive": false, "pret": false}
	reseau._sur_pair_connecte(5)
	_check(salon.cartes[1].pseudo.text == "Bob" and salon.cartes[1].badge.text == " " and salon.cartes[2].pseudo.text == tr("SALON_LIBRE")
		and reseau.table_salon.map(func(f: Dictionary) -> int: return f.id) == [1, 5],
		"une place seulement réservée n'a pas de carte (M4) ; un joueur arrivé a la sienne")
	_check(reseau.places_reservees == 1, "phase 18 : la table part avec le nombre de places seulement réservées (%d)" % reseau.places_reservees)

	# Couleurs : la voisine libre (celle d'une place réservée est prise) ; une seule par appui
	salon.changer_couleur(1)
	_check(reseau.inscrits[1].couleur == palette[3] and reseau.couleur_locale == palette[3] and c0.teinte.get_shader_parameter("couleur_joueur") == palette[3],
		"droite : la couleur libre suivante, bleu et jaune (réservé) sautés : vert")
	salon.changer_couleur(-1)
	_check(reseau.inscrits[1].couleur == palette[0], "gauche : la libre précédente : rouge")
	await _appuyer(&"deplacer_gauche", true)
	await _appuyer(&"deplacer_gauche", true)  # le stick encore penché : un autre événement, pas un autre appui
	await _appuyer(&"deplacer_gauche", false)
	_check(reseau.inscrits[1].couleur == palette[5], "gauche tenue (clavier, croix ou stick) ne change la couleur qu'une fois, la palette en boucle : cyan")
	await _appuyer(&"deplacer_droite", true)
	await _appuyer(&"deplacer_droite", false)
	_check(reseau.inscrits[1].couleur == palette[0], "droite : de nouveau rouge, en boucle")
	_check(reseau.changer_couleur(5, 1) and reseau.inscrits[5].couleur == palette[3],
		"l'hôte arbitre la demande d'un client : Bob passe à la suivante libre, vert")
	_check(not reseau.changer_couleur(7, 1) and not reseau.changer_couleur(99, 1) and not reseau.changer_couleur(5, 2),
		"refusées : une place seulement réservée, un inconnu, un sens hors de ±1")

	# Prêt : couleur figée. Le bouton « Démarrer la partie » de l'hôte, grisé avec sa raison tant que
	# la partie ne peut pas démarrer ; l'hôte revérifie au moment de l'appui
	var bouton: Button = salon.bouton_demarrer
	await _appuyer(&"vomir", true)
	await _appuyer(&"vomir", false)
	_check(reseau.inscrits[1].pret and c0.etat.text == tr("SALON_PRET"), "vomir : prêt")
	salon.changer_couleur(1)
	_check(reseau.inscrits[1].couleur == palette[0], "prêt, sa couleur est figée")
	_check(reseau.definir_pret(5, true) and bouton.visible and bouton.disabled and bouton.focus_mode == Control.FOCUS_NONE
		and salon.etat.text == tr("SALON_ATTENTE_ARRIVEE"),
		"tous les arrivés sont prêts, mais une place est réservée : bouton grisé, « Un joueur est en train d'arriver… »")
	await _appuyer(&"demarrer", true)
	await _appuyer(&"demarrer", false)
	_check(not reseau.manche_en_cours and root.get_children().has(salon), "Tab (ou Start) sur un bouton grisé ne démarre rien")
	reseau._sur_echec_poignee_de_main(7)
	_check(not bouton.disabled and salon.etat.text == tr("SALON_PRET_A_DEMARRER"),
		"la place libérée, tous prêts : le bouton s'active, « tu peux démarrer la partie »")
	reseau.inscrits[5].pret = false  # Bob repasse non prêt dans la même image que l'appui, avant tout affichage
	salon.demarrer()
	_check(not reseau.manche_en_cours and bouton.disabled and salon.etat.text == tr("SALON_ATTENTE_PRETS") and root.get_children().has(salon),
		"l'hôte revérifie au moment de démarrer : refusé, le bouton se regrise, « tous les joueurs doivent être prêts »")
	reseau.definir_pret(5, true)
	_check(not bouton.disabled, "(Bob de nouveau prêt : le bouton revient)")
	reseau.definir_pret(5, false)
	_check(bouton.disabled and salon.etat.text == tr("SALON_ATTENTE_PRETS"), "Bob repasse non prêt : le bouton se regrise aussitôt")
	salon.changer_niveau(1)
	_check(reseau.niveau_salon == 2, "l'hôte change de niveau quand il veut, même quand tous ne sont pas prêts")
	salon.changer_niveau(-1)
	reseau._sur_pair_deconnecte(5)
	_check(salon.cartes[1].pseudo.text == tr("SALON_LIBRE") and bouton.disabled and salon.etat.text == tr("SALON_ATTENTE_JOUEURS"),
		"Bob part : sa carte se libère, « il faut au moins 2 joueurs pour démarrer »")

	# Niveau (l'hôte, haut/bas, en boucle) : la partie le suit
	await _appuyer(&"deplacer_bas", true)
	await _appuyer(&"deplacer_bas", false)
	_check(reseau.niveau_salon == 2 and GS.niveau_courant == 2 and salon.titre_niveau.text == "Niveau : Village", "bas : le niveau suivant")
	salon.changer_niveau(1)
	_check(reseau.niveau_salon == 0 and GS.niveau_courant == 0, "après le dernier, le premier (en boucle)")
	salon.changer_niveau(-1)

	# Langue ; Retour ; plus aucune connexion aux autoloads
	params.definir_langue("en")
	await process_frame
	_check(salon.titre_niveau.text == "Level: Village" and salon.cartes[1].pseudo.text == "Free slot" and c0.etat.text == "READY!"
		and salon.aide.text.begins_with("Left/Right"), "changer de langue retraduit le salon (%s)" % salon.titre_niveau.text)
	params.definir_langue("fr")
	salon.retour(false)
	_check(not reseau.en_ligne() and reseau.table_salon.is_empty(), "Retour quitte le réseau : les clients voient partir l'hôte")
	salon.free()
	_check(reseau.salon_change.get_connections().is_empty()
		and reseau.manche_lancee.get_connections().is_empty() and reseau.hote_perdu.get_connections().is_empty(),
		"le salon fermé ne laisse aucune connexion aux autoloads")

	# Un client : ni niveau ni code ; l'hôte perdu ramène à l'écran En ligne, avec son message
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est un client")
	var salon_client: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon_client)
	await process_frame
	_check(salon_client.aide.text == tr("SALON_AIDE") and not salon_client.rangee_invitation.visible and not salon_client.bouton_demarrer.visible,
		"un client : l'aide sans le niveau ni Démarrer, pas de code, pas de bouton")
	salon_client.changer_niveau(1)
	salon_client.demarrer()
	_check(reseau.niveau_salon == 0 and not reseau.manche_en_cours, "un client ne change pas le niveau et ne démarre pas la partie")
	var id_client: int = root.multiplayer.get_unique_id()
	reseau.table_salon.assign([{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Hôte", "pret": true},
		{"id": id_client, "index": 1, "couleur": palette[1], "pseudo": "Moi", "pret": false}])
	reseau.salon_change.emit()
	var attente_client: String = salon_client.etat.text
	reseau.table_salon[1].pret = true
	reseau.places_reservees = 1  # comme la table de l'hôte pendant qu'un joueur arrive
	reseau.salon_change.emit()
	var attente_arrivee: String = salon_client.etat.text
	reseau.places_reservees = 0
	reseau.salon_change.emit()
	_check(attente_client == tr("SALON_ATTENTE_PRETS") and attente_arrivee == tr("SALON_ATTENTE_ARRIVEE") and salon_client.etat.text == tr("SALON_ATTENTE_HOTE"),
		"un client voit pourquoi la partie attend (un joueur pas prêt ; M2 : un joueur qui arrive), puis « l'hôte peut démarrer » (%s | %s | %s)"
			% [attente_client, attente_arrivee, salon_client.etat.text])
	reseau.quitter()
	reseau.hote_perdu.emit()
	var ecran: Node = await _attendre_scene("res://Scenes/EcranEnLigne.tscn")
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn" and ecran.etat == ecran.Etat.ACCUEIL
		and ecran.message.text == tr("RESEAU_HOTE_PERDU"), "hôte perdu : retour à l'écran En ligne, « L'hôte a quitté la partie »")
	salon_client.free()
	if ecran != null:
		ecran.free()

	# Échap (ou B) : quitte le réseau, écran En ligne sans message (celui de l'hôte perdu ne s'affiche
	# qu'une fois)
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est de nouveau un client")
	salon_client = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon_client)
	await process_frame
	await _appuyer(&"ui_cancel", true)
	ecran = await _attendre_scene("res://Scenes/EcranEnLigne.tscn")
	_check(not reseau.en_ligne() and ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn" and ecran.message.text.is_empty(),
		"Échap (ou B) quitte le réseau et revient à l'écran En ligne, sans message")
	salon_client.free()
	if ecran != null:
		ecran.free()

	# Un salon ouvert hors réseau (l'hôte parti pendant le chargement du salon : son signal n'a
	# trouvé personne)
	var orphelin: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(orphelin)
	ecran = await _attendre_scene("res://Scenes/EcranEnLigne.tscn")
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn" and ecran.message.text == tr("RESEAU_HOTE_PERDU"),
		"un salon ouvert hors réseau revient à l'écran En ligne avec « L'hôte a quitté la partie »")
	orphelin.free()
	if ecran != null:
		ecran.free()

	reseau.pseudo = ""
	GS.niveau_courant = 0


## Phase 6 du jeu en ligne (spec §6) : ce que fait un mobile (`Parametres.mobile`, forcé ici : le desktop
## n'en est pas un), et le plein écran sur ordinateur ; `mobile` revient à faux à la fin.
func _tester_mobile(params: Node) -> void:
	print("-- Mobiles (phase 6)")
	var scores: Node = root.get_node("Scores")
	# Le plein écran d'un mobile : demandé au relâchement d'un toucher (`touchend` est un geste pour le
	# navigateur, `touchstart` non), redemandé au relâchement suivant tant qu'il n'est pas obtenu,
	# TENTATIVES_PLEIN_ECRAN fois au plus (Safari sur iPhone n'en a pas pour un canevas) ; plus rien une fois
	# obtenu, même sorti du plein écran ; jamais sur ordinateur ; jamais mémorisé
	var demandes := {}
	await _toucher(Vector2(1000, 500), true)
	await _toucher(Vector2(1000, 500), false)
	demandes["ordinateur"] = params.tentatives_plein_ecran
	params.mobile = true
	await _toucher(Vector2(1000, 500), true)
	demandes["appui"] = params.tentatives_plein_ecran
	await _toucher(Vector2(1000, 500), false)
	demandes["relâchement"] = params.tentatives_plein_ecran
	await _toucher(Vector2(1000, 500), true)
	await _toucher(Vector2(1000, 500), false)
	demandes["relâchement suivant"] = params.tentatives_plein_ecran
	params.suivre_plein_ecran(DisplayServer.WINDOW_MODE_WINDOWED)
	var refuse: bool = params.plein_ecran_obtenu
	params.suivre_plein_ecran(DisplayServer.WINDOW_MODE_FULLSCREEN)  # ce que `_process` lit de la fenêtre
	var obtenu: bool = params.plein_ecran_obtenu
	params.suivre_plein_ecran(DisplayServer.WINDOW_MODE_WINDOWED)  # le joueur en sort
	await _toucher(Vector2(1000, 500), true)
	await _toucher(Vector2(1000, 500), false)
	demandes["obtenu, puis quitté"] = params.tentatives_plein_ecran
	params.plein_ecran_obtenu = false
	for i in range(3):
		await _toucher(Vector2(1000, 500), true)
		await _toucher(Vector2(1000, 500), false)
	demandes["3 refus"] = params.tentatives_plein_ecran
	_check(demandes == {"ordinateur": 0, "appui": 0, "relâchement": 1, "relâchement suivant": 2, "obtenu, puis quitté": 2, "3 refus": params.TENTATIVES_PLEIN_ECRAN}
		and params.TENTATIVES_PLEIN_ECRAN == 3 and not refuse and obtenu and params.plein_ecran_obtenu == false
		and not bool(scores.preference("plein_ecran", false)),
		"un mobile demande le plein écran au relâchement d'un toucher (pas à l'appui), réessaie au suivant, 3 fois au plus, plus rien une fois obtenu (même quitté) ; un ordinateur jamais ; rien de mémorisé (%s)" % [demandes])
	# Le bouton Plein écran d'un ordinateur bascule d'après la fenêtre (fenêtrée ici) : il la met en plein écran
	params.basculer_plein_ecran()
	_check(params.plein_ecran and bool(scores.preference("plein_ecran", false)), "Plein écran, depuis une fenêtre : le plein écran, mémorisé")
	params.definir_plein_ecran(false)
	# Une cible au doigt : 150 px de haut au moins, sa police agrandie
	var bouton := Button.new()
	bouton.custom_minimum_size = Vector2(260, 72)
	params.agrandir(bouton, 44)
	_check(bouton.custom_minimum_size == Vector2(260, params.CIBLE_TACTILE) and bouton.get_theme_font_size("font_size") == 44,
		"agrandir : %d px de haut au moins, la police à 44 px" % params.CIBLE_TACTILE)
	bouton.free()
	# Le voile du portrait : sur un mobile tenu en portrait seulement, au-dessus des écrans et des contrôles
	# tactiles, sous le filtre CRT ; il n'intercepte rien et n'arrête rien
	var voile: CanvasLayer = params.voile
	var vus := {}
	for taille: Vector2i in [Vector2i(360, 640), Vector2i(844, 390), Vector2i(0, 0)]:
		params.actualiser_voile(taille)
		vus[taille] = voile.visible
	params.mobile = false
	params.actualiser_voile(Vector2i(360, 640))
	var portrait_ordinateur: bool = voile.visible
	params.mobile = true
	params.actualiser_voile(Vector2i(360, 640))
	var fond: ColorRect = voile.get_child(0)
	var texte: Label = fond.get_child(0)
	_check(vus == {Vector2i(360, 640): true, Vector2i(844, 390): false, Vector2i(0, 0): false} and not portrait_ordinateur,
		"le voile ne couvre qu'un mobile en portrait (360×640) : ni en paysage (844×390), ni sans fenêtre, ni sur un ordinateur (%s)" % [vus])
	_check(voile.layer > 9 and voile.layer < params.couche_crt.layer and fond.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and texte.mouse_filter == Control.MOUSE_FILTER_IGNORE and tr(texte.text) == "Tourne ton téléphone" and not paused,
		"« Tourne ton téléphone » par-dessus les écrans (couche %d : contrôles tactiles 6, Résultats 8, menu 9), sous le CRT, sans rien intercepter ni mettre en pause" % voile.layer)
	params.actualiser_voile(Vector2i(844, 390))
	await _tester_tactile_mobile(params)
	await _tester_en_ligne_mobile(params)
	params.mobile = false
	params.tentatives_plein_ecran = 0
	params.plein_ecran_obtenu = false


## Phase 6 : les contrôles tactiles d'un mobile, en jeu (sur l'écran du solo et sur celui de la bataille)
## et au salon (la couleur et Prêt au doigt, une action par appui), Retour agrandi ; sur ordinateur, le
## bouton Plein écran du salon, et la rangée d'invitation loin du bas de l'écran.
func _tester_tactile_mobile(params: Node) -> void:
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var cible: int = params.CIBLE_TACTILE
	# En jeu : le stick, VOMIR en bas à droite et la pause, sur l'écran du mode, chaque bouton à MARGE px des
	# bords, de CIBLE_TACTILE px au moins
	var places := {}
	var dedans := true
	for taille: Vector2i in [Vector2i(2000, 648), Vector2i(2000, 1125)]:
		root.content_scale_size = taille
		var jeu: CanvasLayer = load("res://Scenes/ControlesTactiles.tscn").instantiate()
		root.add_child(jeu)
		places[taille] = [jeu.bouton_vomir.position, jeu.bouton_pause.position]
		for bouton: TouchScreenButton in [jeu.bouton_vomir, jeu.bouton_pause]:
			var rect := Rect2(bouton.position, bouton.texture_normal.get_size() * bouton.scale)
			dedans = dedans and rect.size.x >= cible and Rect2(Vector2.ONE * jeu.MARGE, Vector2(taille) - Vector2.ONE * 2 * jeu.MARGE).encloses(rect)
		dedans = dedans and jeu.visible and jeu.joystick.visible and not jeu.bouton_gauche.visible and not jeu.bouton_droite.visible
		jeu.free()
	_check(dedans and places[Vector2i(2000, 648)] == [Vector2(1780, 428), Vector2(1780, 140)] and places[Vector2i(2000, 1125)] == [Vector2(1780, 905), Vector2(1780, 140)],
		"en jeu, un mobile a le stick, VOMIR en bas à droite et la pause sous le HUD, à %d px des bords, de %d px au moins, sur l'écran du solo comme sur celui de la bataille (%s)" % [60, cible, places])

	# Au salon, sur un mobile : les flèches de la couleur et PRÊT, ni stick ni pause ; Retour agrandi, pas de
	# Plein écran
	reseau.pseudo = "Mo"
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await process_frame
	var tactile: CanvasLayer = salon.controles_tactiles
	_check(tactile.visible and tactile.disposition == tactile.Disposition.SALON and tactile.bouton_gauche.visible and tactile.bouton_droite.visible
		and tactile.bouton_vomir.visible and not tactile.joystick.visible and not tactile.bouton_pause.visible and tr(tactile.etiquette_vomir.text) == "PRÊT"
		and tactile.bouton_gauche.action == "deplacer_gauche" and tactile.bouton_droite.action == "deplacer_droite" and tactile.bouton_vomir.action == "vomir",
		"au salon, un mobile a les flèches de la couleur et PRÊT, sans stick ni pause")
	_check(not salon.bouton_plein_ecran.visible and salon.bouton_retour.size.y >= cible and salon.etat.get_theme_font_size("font_size") == 48
		and salon.aide.get_theme_font_size("font_size") == 40, "un mobile n'a pas Plein écran ; Retour fait %d px de haut, l'état et l'aide sont agrandis" % salon.bouton_retour.size.y)
	var centre := func(bouton: TouchScreenButton) -> Vector2: return bouton.position + bouton.texture_normal.get_size() / 2.0
	await _toucher(centre.call(tactile.bouton_droite), true)
	await _toucher(centre.call(tactile.bouton_droite), true, 1)  # un deuxième doigt sur la flèche déjà tenue
	var tenue: Color = reseau.inscrits[1].couleur
	await _toucher(centre.call(tactile.bouton_droite), false, 1)
	await _toucher(centre.call(tactile.bouton_droite), false)
	await _toucher(centre.call(tactile.bouton_droite), true)
	await _toucher(centre.call(tactile.bouton_droite), false)
	var deux_fois: Color = reseau.inscrits[1].couleur
	await _toucher(centre.call(tactile.bouton_gauche), true)
	await _toucher(centre.call(tactile.bouton_gauche), false)
	_check(tenue == palette[1] and deux_fois == palette[2] and reseau.inscrits[1].couleur == palette[1],
		"la flèche droite touchée : la couleur suivante, une seule fois tant qu'elle est tenue (même d'un deuxième doigt), puis encore ; la gauche : la précédente")
	await _toucher(centre.call(tactile.bouton_vomir), true)
	await _toucher(centre.call(tactile.bouton_vomir), false)
	var pret: bool = reseau.inscrits[1].pret
	await _toucher(centre.call(tactile.bouton_vomir), true)
	await _toucher(centre.call(tactile.bouton_vomir), false)
	_check(pret and not reseau.inscrits[1].pret, "PRÊT touché : prêt, puis plus prêt")
	await _appuyer(&"deplacer_droite", true)
	await _appuyer(&"deplacer_droite", false)
	_check(reseau.inscrits[1].couleur == palette[2], "le clavier (et la manette) changent toujours la couleur à côté du tactile")
	salon.retour(false)
	salon.free()
	# Un client (le seul rôle d'un mobile) : l'aide du tactile ; les boutons tactiles ne couvrent ni les
	# cartes, ni l'état, ni le texte de l'aide
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est un client")
	var client: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(client)
	await process_frame
	_check(client.aide.text == tr("SALON_AIDE_TACTILE") and tr("SALON_AIDE_TACTILE").begins_with("Flèches : ta couleur"),
		"un client sur mobile lit l'aide du tactile : « %s »" % client.aide.text)
	var couverts: Array[String] = []
	for langue in ["fr", "en"]:
		params.definir_langue(langue)
		for cle in ["SALON_ATTENTE_JOUEURS", "SALON_ATTENTE_ARRIVEE", "SALON_ATTENTE_PRETS", "SALON_ATTENTE_HOTE"]:
			client.etat.text = tr(cle)
			await process_frame
			for bouton: TouchScreenButton in [client.controles_tactiles.bouton_gauche, client.controles_tactiles.bouton_droite, client.controles_tactiles.bouton_vomir]:
				var rect := Rect2(bouton.position, bouton.texture_normal.get_size())
				for zone: Array in [["cartes", client.rangee_cartes.get_global_rect()], [cle, _rect_du_texte(client.etat)], ["aide", _rect_du_texte(client.aide)]]:
					if rect.intersects(zone[1]):
						couverts.append("%s sur %s (%s)" % [bouton.name, zone[0], langue])
	params.definir_langue("fr")
	_check(couverts.is_empty(), "les boutons tactiles ne couvrent ni les cartes, ni l'état (chacun de ses textes), ni l'aide d'un client, en français comme en anglais (%s)" % [couverts])
	client.retour(false)
	client.free()

	# Sur ordinateur : pas de tactile (pas d'écran tactile ici), le bouton Plein écran en haut à droite ; la
	# rangée d'invitation de l'hôte reste à 60 px au moins du bas de l'écran
	params.mobile = false
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	reseau.code_partie = "K7Q2XM"
	var bureau: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(bureau)
	await process_frame
	var plein: Rect2 = bureau.bouton_plein_ecran.get_global_rect()
	_check(not bureau.controles_tactiles.visible and bureau.bouton_plein_ecran.visible and plein.end.x <= 2000 - 20 and plein.position.y <= 30
		and bureau.bouton_plein_ecran.focus_mode == Control.FOCUS_NONE and tr(bureau.bouton_plein_ecran.text) == "Plein écran",
		"sur ordinateur : pas de tactile, « Plein écran » en haut à droite, sans focus")
	bureau.bouton_plein_ecran.pressed.emit()
	_check(params.plein_ecran, "Plein écran, cliqué : le plein écran")
	params.definir_plein_ecran(false)
	var bas: float = bureau.rangee_invitation.get_global_rect().end.y
	_check(bureau.rangee_invitation.visible and bas <= 1125 - 60, "la rangée d'invitation de l'hôte finit à %d px du bas de l'écran (60 au moins : la zone sûre)" % (1125 - bas))
	bureau.retour(false)
	bureau.free()
	reseau.pseudo = ""
	params.mobile = true


## Phase 6 : l'écran En ligne d'un mobile : sans Créer une partie, le focus au premier contrôle visible,
## les cibles au doigt, la rangée en édition au-dessus du clavier virtuel ; sur ordinateur, rien ne change.
func _tester_en_ligne_mobile(params: Node) -> void:
	var scores: Node = root.get_node("Scores")
	var cible: int = params.CIBLE_TACTILE
	scores.definir_preference("pseudo", "MMMMMMMMMMMM")
	var ecran: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran.codes_de_salle = true
	root.add_child(ecran)
	await process_frame
	_check(not ecran.bouton_creer.visible and not ecran.etiquette_ou.visible and ecran.bouton_rejoindre.has_focus(),
		"sur un mobile, ni Créer une partie ni « ou rejoins… » ; à l'accueil, le focus va à Rejoindre, le premier contrôle visible")
	var petits: Array[String] = []
	for controle: Control in [ecran.champ_pseudo, ecran.champ_code, ecran.bouton_rejoindre, ecran.bouton_retour]:
		if controle.size.y < cible:
			petits.append("%s %d px" % [controle.name, controle.size.y])
	var champ: LineEdit = ecran.champ_pseudo
	var largeur_m: float = champ.get_theme_font("font").get_string_size("MMMMMMMMMMMM", HORIZONTAL_ALIGNMENT_LEFT, -1, champ.get_theme_font_size("font_size")).x
	var colonne: Rect2 = ecran.get_node("Centre/Colonne").get_global_rect()
	_check(petits.is_empty() and ecran.message.get_theme_font_size("font_size") == 44 and largeur_m <= champ.size.x - 30
		and Rect2(0, 0, 2000, 1125).encloses(colonne) and ecran.bouton_rejoindre.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS,
		"les champs, Rejoindre et Retour font %d px de haut au moins (%s), le message 44 px, 12 caractères larges tiennent dans le pseudo (%d px), tout dans l'écran ; Rejoindre agit à l'appui" % [cible, petits, largeur_m])
	ecran.champ_code.text = ""
	ecran._sur_pseudo_valide(ecran.champ_pseudo.text)
	_check(ecran.champ_code.has_focus(), "Entrée dans le pseudo, sans code : le focus va au code (Créer une partie n'existe pas)")
	# Le clavier virtuel couvre le bas de l'écran : la rangée en édition remonte en haut, le message dessous.
	# Un champ entre en édition quand il prend le focus (au doigt, ou rendu par un refus : Godot 4.7) et en
	# sort quand il le perd.
	ecran.bouton_rejoindre.grab_focus()
	ecran.champ_code.text = "K7Q2X"
	ecran.rejoindre()
	await process_frame
	var rangee_code: Rect2 = ecran.champ_code.get_parent().get_global_rect()
	var message: Rect2 = ecran.message.get_global_rect()
	var pendant: float = ecran.centre.position.y
	var en_edition: bool = ecran.champ_code.is_editing()
	ecran.bouton_rejoindre.grab_focus()
	await process_frame
	var apres: float = ecran.centre.position.y
	ecran.champ_pseudo.grab_focus()
	await process_frame
	var rangee_pseudo: Rect2 = ecran.champ_pseudo.get_parent().get_global_rect()
	ecran.bouton_rejoindre.grab_focus()
	await process_frame
	_check(en_edition and pendant < 0.0 and rangee_code.position.y == ecran.MARGE_CLAVIER and message.end.y <= 1125 * 0.4 and ecran.message.text == tr("ENLIGNE_CODE_FORMAT")
		and apres == 0.0 and rangee_pseudo.position.y == ecran.MARGE_CLAVIER and ecran.centre.position.y == 0.0,
		"un refus rend le code en édition : sa rangée remonte à %d px du haut, le message dessous dans les 40 %% du haut (fin à %d px) ; le pseudo aussi ; tout redescend à la fin de l'édition"
			% [ecran.MARGE_CLAVIER, message.end.y])
	ecran.free()

	# Sur ordinateur : Créer une partie et son focus, rien ne bouge en édition
	params.mobile = false
	var bureau: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	bureau.codes_de_salle = true
	root.add_child(bureau)
	await process_frame
	bureau.champ_code.grab_focus()
	await process_frame
	_check(bureau.bouton_creer.visible and bureau.etiquette_ou.visible and bureau.centre.position.y == 0.0
		and bureau.bouton_rejoindre.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE and bureau.bouton_rejoindre.size.y < cible,
		"sur ordinateur, l'écran En ligne ne change pas : Créer une partie, rien ne remonte en édition")
	bureau.free()
	params.mobile = true
	scores.definir_preference("pseudo", "")


## Le rectangle (px de l'écran) du texte d'une étiquette centrée sur une ligne, plus étroit qu'elle.
func _rect_du_texte(etiquette: Label) -> Rect2:
	var largeur: float = etiquette.get_theme_font("font").get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		etiquette.get_theme_font_size("font_size")).x
	return Rect2(etiquette.global_position + Vector2((etiquette.size.x - largeur) / 2.0, 0), Vector2(largeur, etiquette.size.y))


## Un toucher (ou son relâchement) du doigt `index` en `position` (px de l'écran du jeu), comme un écran
## tactile l'envoie.
func _toucher(position: Vector2, appui: bool, index := 0) -> void:
	var toucher := InputEventScreenTouch.new()
	toucher.index = index
	toucher.position = position
	toucher.pressed = appui
	root.push_input(toucher, true)  # coordonnées du viewport, pas de la fenêtre
	await process_frame


## Un appui (ou un relâchement) de `action`, comme le clavier ou la manette l'envoient au jeu.
func _appuyer(action: StringName, appuye: bool) -> void:
	var evenement := InputEventAction.new()
	evenement.action = action
	evenement.pressed = appuye
	root.push_input(evenement)
	await process_frame


## Phase 14 : la scène de jeu d'une bataille en réseau, chez un hôte (ce poste héberge ; l'autre
## joueur est simulé dans `Reseau.inscrits`, comme au salon) : lion de la scène retiré, lions par le
## MultiplayerSpawner après la barrière de chargement, exclusion d'un absent, départ en cours de
## manche, commandes reçues et leur silence, menu local sans pause. Les échanges entre postes sont
## couverts par tests/reseau/lancer.sh (scénario 9).
func _tester_manche_reseau() -> void:
	print("-- Manche en réseau (hôte)")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var script_manche: Script = load("res://Scripts/Manche.gd")
	var delai_du_jeu: float = script_manche.delai_chargement
	for essai in ["charge", "absent"]:
		reseau.pseudo = "Hôte"
		_check(reseau.heberger(17798) == OK, "(pré-condition, %s) ce poste héberge" % essai)
		reseau.inscrits[7] = {"index": 1, "couleur": palette[3], "pseudo": "Bob", "arrive": true, "pret": true}
		reseau.manche_en_cours = true
		GS.niveau_courant = 0
		GS.configurer_bataille_reseau([{"id_reseau": 1, "pseudo": "Hôte", "couleur": palette[0]},
			{"id_reseau": 7, "pseudo": "Bob", "couleur": palette[3]}] as Array[Dictionary])
		script_manche.delai_chargement = 0.5
		var main: Node = load("res://Scenes/Main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		await _frames(3)
		var manche: Node = main.get_node("Manche")
		_check(main.en_reseau and main.get_node_or_null("Lion") == null and main.lions.is_empty() and main.lion == null
			and not manche.barriere and reseau.scenes_chargees == [1] and not main.get_node("Intro")._lancee
			and not main.get_node("Spawner")._demarre,
			"(%s) en réseau, la scène retire le lion du solo et attend la barrière : ni lion, ni intro, ni apparition" % essai)
		if essai == "charge":
			reseau._noter_scene_chargee(7)  # comme la RPC de Bob
			await _frames(2)
		else:
			await create_timer(0.7).timeout
			await _frames(2)
			_check(manche._exclus == [7] and not manche.barriere,
				"(absent) délai passé : Bob est exclu, et la barrière attend son départ")
			reseau._sur_pair_deconnecte(7)  # son départ, vu par Reseau
			await _frames(2)
		var noms: Array = main.lions.map(func(l: Node) -> String: return str(l.name))
		var attendus_noms: Array = ["Lion1", "Lion2"] if essai == "charge" else ["Lion1"]
		_check(manche.barriere and noms == attendus_noms and main.lion == main.lions[0] and main.lion.joueur == GS.joueur_local()
			and main.lion.commandes.source == Commandes.Source.LOCALES and main.get_node("Intro")._lancee and main.get_node("Spawner")._demarre,
			"(%s) barrière passée : un lion par joueur encore là (%s), celui de ce poste lit ses commandes, l'intro et les apparitions commencent" % [essai, noms])
		var hud: CanvasLayer = main.hud_bataille
		_check(hud != null and hud.vignettes.map(func(v: Dictionary) -> String: return v.pseudo.text) == ["Hôte", "Bob"]
			and hud.vignettes[0].badge.text == "TOI",
			"(%s) le HUD de la bataille : une vignette par joueur de la table, « TOI » sur celle de l'hôte" % essai)
		if essai == "absent":
			_check(not reseau.inscrits.has(7) and main.lions.size() == 1, "(absent) un joueur exclu n'a pas de lion")
			_check(manche._partis == [1] and hud.partis == [false, true] and hud.vignettes[1].badge.text == "PARTI",
				"(absent) l'exclu reste au classement, en grisé ; son départ sera annoncé aux clients en passant la barrière")
			# Phase 18 : chez l'exclu, la perte de l'hôte dit pourquoi
			reseau.raison_perte = reseau.PERTE_EXCLU
			main._sur_hote_perdu()
			_check(main.get_node("HotePerdu/Message").text == "RESEAU_EXCLU",
				"chez un exclu, le message dit qu'il a été exclu (sa partie trop longue à charger), pas « L'hôte a quitté la partie »")
			reseau.raison_perte = reseau.PERTE_HOTE
			paused = false
			main.free()
			await _frames(1)
			reseau.quitter()
			continue
		var lion_bob: CharacterBody2D = main.lions[1]
		_check(lion_bob.joueur == GS.joueurs[1] and lion_bob.commandes.source == Commandes.Source.MANUELLES
			and lion_bob.position.x < main.lion.position.x + 2000.0 and lion_bob.position.y == main.lion.position.y,
			"le lion de Bob porte son joueur et des commandes manuelles, à sa place de départ")
		# Commandes reçues de Bob, numérotées et redondantes (phase 16), puis son silence
		var maintenant := Time.get_ticks_msec()
		var paquet_bob := Commandes.encoder_paquet(5, [[Vector2(-1, 0), false], [Vector2(0.5, 0.0), true]])
		_check(manche.recevoir_paquet_de(1, paquet_bob, maintenant) == 2 and lion_bob.commandes.en_attente() <= 2,
			"un paquet de Bob (ses commandes 4 et 5) entre dans la file des commandes de son lion")
		_check(manche.recevoir_paquet_de(1, paquet_bob, maintenant) == 0, "le même paquet reçu deux fois n'ajoute rien")
		_check(manche.recevoir_paquet_de(1, "gauche", maintenant) == -1
			and manche.recevoir_paquet_de(1, Commandes.encoder_paquet(6, [[Vector2(INF, 0), false]]), maintenant) == -1
			and manche.recevoir_paquet_de(0, Commandes.encoder_paquet(6, [[Vector2(1, 0), false]]), maintenant) == -1
			and main.lion.commandes.direction() == Vector2.ZERO,
			"un paquet mal formé, non fini ou pour le lion de l'hôte est refusé")
		await _frames(3)
		_check(lion_bob.commandes.numero_applique == 5 and lion_bob.commandes.appliquees == 2 and lion_bob.commandes.direction_voulue == Vector2(0.5, 0.0)
			and lion_bob.commandes.vomir_voulu and EtatLion.decoder(lion_bob.etat_reseau).commande == 5,
			"le lion de Bob applique une commande par tick, dans l'ordre (la 4, puis la 5), et son état accuse la 5")
		manche.verifier_silences(maintenant + manche.SILENCE_COMMANDES - 10)
		_check(lion_bob.commandes.vomir_voulu, "pas encore de silence : la dernière commande tient")
		manche.verifier_silences(maintenant + manche.SILENCE_COMMANDES + 10)
		_check(lion_bob.commandes.direction_voulue == Vector2.ZERO and not lion_bob.commandes.vomir_voulu,
			"sans commande de Bob depuis %d ms, son lion revient au repos" % manche.SILENCE_COMMANDES)
		# Chaque tampon de la ville de l'hôte part avec la manche
		var avant: int = manche.tampons_diffuses
		GS.pret = true
		var ville: Node2D = main.get_node("Ville")
		ville.peindre(ville.position, 21, GS.joueurs[0])
		await _frames(2)
		_check(manche.tampons_diffuses == avant + 1, "la manche diffuse chaque tampon de la ville de l'hôte")
		# Menu local : la partie continue, les commandes de ce poste sont suspendues
		var menu: CanvasLayer = main.get_node("PauseMenu")
		menu.ouvrir()
		await _frames(1)
		_check(menu.visible and not paused and main.lion.commandes.suspendues
			and menu.get_node("Centre/Colonne/Titre").text == "PAUSE_RESEAU" and menu.get_node("Centre/Colonne/Menu").text == "QUITTER_PARTIE",
			"en réseau, Échap ouvre un menu local : la partie continue, les commandes de ce poste sont suspendues, « Quitter la partie »")
		menu.reprendre()
		await _frames(1)
		_check(not menu.visible and not paused and not main.lion.commandes.suspendues, "le menu fermé, les commandes reprennent")
		# Bob part en pleine manche : son lion disparaît, ses cellules restent
		ville.territoire.tamponner(1, Vector2i(1000, 200), 40)
		ville.territoire.tamponner(1, Vector2i(1000, 200), 40)
		ville.territoire.tamponner(1, Vector2i(1000, 200), 40)
		var cellules_bob: int = ville.territoire.cellules_de(1)
		reseau._sur_pair_deconnecte(7)
		await _frames(2)
		_check(not is_instance_valid(lion_bob) and main.lions.size() == 1 and ville.territoire.cellules_de(1) == cellules_bob and cellules_bob > 0,
			"un joueur parti en pleine manche perd son lion, ses cellules restent au territoire (%d)" % cellules_bob)
		_check(manche._partis == [1] and hud.partis == [false, true] and hud.vignettes[1].part.text != "0 %",
			"le HUD grise Bob, parti, avec sa part des cellules peintes (%s) ; la manche annonce son départ" % hud.vignettes[1].part.text)
		# I2 (revue finale phase 17) : un tampon et une case de territoire tout juste peints, encore en
		# attente (aucune image écoulée depuis pour les diffuser normalement), doivent partir avec la fin,
		# avant elle, sur le même canal : sinon la mutation « fin sans vidage » ne serait jamais mise à
		# l'épreuve (elle passerait tous les tests sans qu'aucun tampon ni case ne soit réellement en vol).
		ville.peindre(ville.position, 22, GS.joueurs[0])
		ville.territoire.tamponner(0, Vector2i(1000, 200), 40)  # reprend la cellule de Bob, parti
		ville.territoire.tamponner(0, Vector2i(1000, 200), 40)
		ville.territoire.tamponner(0, Vector2i(1000, 200), 40)
		_check(not manche._tampons.is_empty() and not ville.territoire._changements.is_empty(),
			"(pré-condition) un tampon et une case de territoire sont en attente, pas encore diffusés")
		manche.envois_ordre.clear()
		GS.joueurs[0].chocs = 4  # les statistiques de l'hôte, que lui seul tient : elles partent avec la fin
		GS.joueurs[1].cellules_volees = 17
		var bilans_vus: Array = []
		manche.bilan_recu.connect(func(b: RefCounted) -> void: bilans_vus.append(b))
		# La fin de la manche chez l'hôte : la manche la note (elle part vers chaque client prêt, après les
		# derniers tampons et le territoire), tout se fige, l'écran Résultats remplace le HUD
		GS.terminer_partie(true)
		var resultats: CanvasLayer = main.resultats
		_check(manche.finie and paused and resultats != null and resultats.visible and not hud.visible and not menu.visible,
			"la fin de manche chez l'hôte : la manche la diffuse, tout se fige, l'écran Résultats remplace le HUD")
		_check(manche.envois_ordre == ([&"_recevoir_tampons", &"_recevoir_territoire", &"_recevoir_fin_manche"] as Array[StringName]),
			"I2 : les derniers tampons et le territoire partent avant la fin, sur le même canal (%s)" % [manche.envois_ordre])
		# Phase 18 : la fin porte le bilan de l'hôte : cellules, crans, statistiques, départs, l'état final
		# de chaque lion encore là (pas celui de Bob, parti)
		var bilan: BilanManche = manche.bilan
		var cellules_fin: Array[int] = [ville.territoire.cellules_de(0), ville.territoire.cellules_de(1)]
		_check(bilan != null and bilans_vus.size() == 1 and bilans_vus[0] == bilan and bilan.cellules == cellules_fin
			and bilan.chocs == [4, 0] and bilan.volees == [0, 17] and bilan.partis == [false, true] and bilan.lions.keys() == [0]
			and EtatLion.decoder(bilan.lions[0]).position == main.lion.position and is_equal_approx(bilan.temps, GS.temps_ecoule),
			"la fin porte le bilan de l'hôte, annoncé sur ce poste : cellules, statistiques, Bob parti, l'état final de son lion (%s)"
				% ("" if bilan == null else bilan.resume()))
		_check(bilan != null and BilanManche.decoder(bilan.encoder(), 2) != null and BilanManche.decoder(bilan.encoder(), 2).resume() == bilan.resume(),
			"le bilan envoyé se relit à l'identique chez un client")
		_check(resultats != null and resultats.hote and resultats.en_reseau and resultats.bouton_salon.visible and resultats.partis == [false, true]
			and resultats.bouton_revanche.disabled and resultats.bouton_suivant.disabled and not resultats.bouton_salon.disabled
			and resultats.etat.text == tr("SALON_ATTENTE_JOUEURS"),
			"l'écran Résultats de l'hôte en réseau : Retour au salon ; Bob parti, Revanche et Niveau suivant attendent deux joueurs")
		# Un hôte perdu (chez un client) : message, tout se fige ; M5 (revue finale phase 17) : la boucle du
		# vomi d'un joueur qui tenait Espace s'arrête
		var audio: Node = root.get_node("Audio")
		audio.demarrer_vomi()
		main._sur_hote_perdu()
		var message: Label = main.get_node("HotePerdu/Message")
		_check(message.text == "RESEAU_HOTE_PERDU" and paused and not resultats.visible and not audio._vomi.playing
			and resultats.process_mode == Node.PROCESS_MODE_DISABLED,
			"l'hôte perdu : « L'hôte a quitté la partie » (à la place de l'écran Résultats), la partie se fige, la boucle du vomi s'arrête, l'écran Résultats caché ne prend plus les touches (M4 de la revue finale)")
		paused = false
		main.free()
		await _frames(1)
		reseau.quitter()
	script_manche.delai_chargement = delai_du_jeu
	reseau.pseudo = ""
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	GS.niveau_courant = 0


## Attend la scène `chemin` qui remplace celle d'identifiant `avant` (la même scène rechargée compte),
## prête ; bornée comme `_attendre_scene`.
func _attendre_nouvelle_scene(chemin: String, avant: int, max_ms: int = 5000) -> Node:
	var fin := Time.get_ticks_msec() + max_ms
	while Time.get_ticks_msec() < fin and (current_scene == null or current_scene.get_instance_id() == avant
			or current_scene.scene_file_path != chemin or not current_scene.is_node_ready()):
		await process_frame
	return current_scene


## Une manche en réseau chez l'hôte (Bob simulé dans `Reseau.inscrits`, comme `_tester_manche_reseau`),
## jusqu'à la barrière passée : la scène de jeu `main` (déjà chargée).
func _passer_la_barriere(_main: Node) -> void:
	await _frames(2)
	root.get_node("Reseau")._noter_scene_chargee(7)  # comme la RPC de Bob
	await _frames(2)
	GS.pret = true  # sans attendre l'intro


## Phase 18 : l'écran Résultats chez l'hôte en réseau, et ses choix (les échanges entre postes sont
## couverts par tests/reseau/lancer.sh, scénario 13) : Revanche relance la manche chez tous (la scène de
## jeu se recharge, la barrière attend de nouveau chaque joueur), Niveau suivant de même sur le niveau
## suivant, un choix que l'hôte ne peut plus suivre se regrise, Retour au salon ramène au salon, la même
## table, personne prêt, les arrivées de nouveau acceptées.
func _tester_resultats_reseau() -> void:
	print("-- Écran Résultats en réseau (hôte)")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	reseau.pseudo = "Hôte"
	_check(reseau.heberger(17799) == OK, "(pré-condition) ce poste héberge")
	reseau.inscrits[7] = {"index": 1, "couleur": palette[3], "pseudo": "Bob", "arrive": true, "pret": true}
	reseau.inscrits[1].pret = true
	GS.niveau_courant = 0
	reseau.niveau_salon = 0
	_check(reseau.lancer_manche(), "(pré-condition) l'hôte lance la manche depuis le salon")
	var lancements := [0]
	var compter := func(_f: Array[Dictionary]) -> void: lancements[0] += 1
	reseau.manche_lancee.connect(compter)
	GS.configurer_bataille_reseau(reseau.fiches_de_manche(reseau.table_salon, 1))
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _passer_la_barriere(main)
	for _k in range(3):
		main.get_node("Ville").territoire.tamponner(0, Vector2i(1000, 200), 40)
	_check(main.get_node("Ville").territoire.cellules_de(0) > 0, "(pré-condition) l'hôte a peint pendant la première manche")
	GS.terminer_partie(true)
	await _frames(1)
	_check(main.resultats != null and main.resultats.hote and main.resultats.possible(&"revanche") and main.resultats.possible(&"salon"),
		"(pré-condition) la manche finie, l'écran Résultats de l'hôte, Bob encore là : Revanche possible")
	# Revanche : la manche se relance chez tous, la scène de jeu se recharge et attend chaque joueur ;
	# M7 de la revue finale : le vrai bouton cliqué (un clic n'agit qu'une fois l'animation finie, M2)
	var id_premiere := main.get_instance_id()
	main.resultats.terminer_animation()
	main.resultats.bouton_revanche.pressed.emit()
	var revanche: Node = await _attendre_nouvelle_scene("res://Scenes/Main.tscn", id_premiere)
	_check(revanche != null and revanche.get_instance_id() != id_premiere and not is_instance_valid(main) and lancements[0] == 1 and reseau.manche_en_cours
		and not paused and revanche.en_reseau and not revanche.get_node("Manche").barriere and reseau.scenes_chargees == [1]
		and GS.niveau_courant == 0 and GS.joueurs.size() == 2 and GS.joueurs[1].pseudo == "Bob" and revanche.resultats == null,
		"Revanche : la manche se relance (même niveau, mêmes joueurs), la scène de jeu se recharge et attend Bob à la barrière")
	await _passer_la_barriere(revanche)
	_check(revanche.lions.size() == 2 and revanche.get_node("Ville").territoire.cellules_de(0) == 0 and GS.temps_ecoule == 0.0,
		"la barrière passée : les deux lions, un territoire vierge, le chrono à zéro")
	# Niveau suivant : de même, sur le niveau suivant
	GS.terminer_partie(true)
	await _frames(1)
	var id_revanche := revanche.get_instance_id()
	revanche.resultats.terminer_animation()
	revanche.resultats.bouton_suivant.pressed.emit()  # M7 de la revue finale : le vrai bouton cliqué
	var suivante: Node = await _attendre_nouvelle_scene("res://Scenes/Main.tscn", id_revanche)
	_check(suivante != null and lancements[0] == 2 and GS.niveau_courant == 1 and reseau.niveau_salon == 1 and not paused,
		"Niveau suivant : la manche se relance sur le niveau suivant (Métropole), annoncé à chaque poste avec la table")
	await _passer_la_barriere(suivante)
	GS.terminer_partie(true)
	await _frames(1)
	var resultats: CanvasLayer = suivante.resultats
	# Bob part sur l'écran Résultats : il se grise ; seul, l'hôte ne peut plus relancer
	reseau._sur_pair_deconnecte(7)
	await _frames(1)
	_check(resultats.partis == [false, true] and resultats.lignes.any(func(l: Dictionary) -> bool: return l.index == 1 and l.badge.text == "PARTI")
		and not resultats.possible(&"revanche") and resultats.bouton_revanche.disabled and resultats.etat.text == tr("SALON_ATTENTE_JOUEURS"),
		"Bob part sur l'écran Résultats : sa ligne se grise, Revanche et Niveau suivant attendent deux joueurs")
	# M5 de la revue finale : Revanche (sélectionnée à l'ouverture) devient impossible avec Bob parti ;
	# la sélection ne doit pas y rester sans rien mettre en évidence : Retour au salon, le premier
	# choix de CHOIX encore possible et visible
	_check(resultats.selection == &"salon", "M5 : la sélection quitte Revanche (devenu impossible) pour Retour au salon, encore possible")
	resultats.choix = &"revanche"  # le choix fait (boutons grisés) au moment même où Bob part
	suivante._sur_choix_resultats(&"revanche")  # l'hôte qui ne peut plus suivre : refusé, le choix se regrise
	await _frames(2)
	_check(current_scene == suivante and lancements[0] == 2 and resultats.choix.is_empty() and reseau.manche_en_cours,
		"une relance que l'hôte ne peut plus suivre est refusée : l'écran reste, on peut encore choisir")
	# Retour au salon : la même table (Bob en moins), personne prêt, les arrivées de nouveau acceptées ;
	# M7 de la revue finale : le vrai bouton cliqué (un clic n'agit qu'une fois l'animation finie, M2)
	var manche_avant: bool = reseau.manche_en_cours
	# M8 de la revue finale : la vérification plus bas (aucune connexion aux autoloads) tournait après
	# que l'ancien Main (`suivante`) soit libéré par le changement de scène : un objet déjà libéré ne
	# peut plus détenir de connexion, qu'il se soit bien désabonné ou non dans `_exit_tree`, donc la
	# vérification ne pouvait jamais échouer. On la fait plutôt dans `tree_exited`, juste après que
	# `suivante` ait quitté l'arbre mais avant sa libération (encore un objet valide à cet instant).
	var connexions_avant_liberation: Array[String] = []
	suivante.tree_exited.connect(func() -> void:
		for sig: Signal in [reseau.manche_lancee, reseau.salon_rouvert, reseau.hote_perdu]:
			for connexion in sig.get_connections():
				if connexion.callable.get_object() == suivante:
					connexions_avant_liberation.append(String(sig.get_name())))
	resultats.terminer_animation()
	resultats.bouton_salon.pressed.emit()
	var salon: Node = await _attendre_scene("res://Scenes/Salon.tscn")
	_check(salon != null and salon.scene_file_path == "res://Scenes/Salon.tscn" and not paused and manche_avant and not reseau.manche_en_cours
		and reseau.table_salon.map(func(f: Dictionary) -> int: return f.id) == [1] and not reseau.inscrits[1].pret
		and salon.titre_niveau.text == "Niveau : Métropole",
		"Retour au salon : le salon de l'hôte s'ouvre sur la même table (Bob parti), personne prêt, le niveau gardé, les arrivées acceptées")
	_check(connexions_avant_liberation.is_empty(),
		"M8 : l'ancien Main (parti au retour au salon) n'avait déjà plus aucune connexion aux autoloads, avant même d'être libéré (%s)" % [connexions_avant_liberation])
	reseau.manche_lancee.disconnect(compter)
	if salon != null:
		salon.free()
	await _frames(1)
	_check(reseau.manche_lancee.get_connections().is_empty() and reseau.salon_rouvert.get_connections().is_empty()
		and reseau.hote_perdu.get_connections().is_empty(),
		"les scènes de jeu fermées et le salon ne laissent aucune connexion aux autoloads")
	# Revue de la tâche 5 (phase 18) : un pair parti dans l'image entre l'ancienne manche (désabonnée de
	# `Reseau.joueur_parti` dans son `_exit_tree`) et la neuve (abonnée seulement à `demarrer`, une image
	# plus tard) n'était jamais marqué parti : Bob quitte `Reseau.inscrits` avant même l'ajout du nouveau
	# `Main`, comme s'il était parti pendant cette image-là.
	reseau.inscrits[7] = {"index": 1, "couleur": palette[3], "pseudo": "Bob", "arrive": true, "pret": true}
	GS.niveau_courant = 0
	GS.configurer_bataille_reseau([{"id_reseau": 1, "pseudo": "Hôte", "couleur": palette[0]},
		{"id_reseau": 7, "pseudo": "Bob", "couleur": palette[3]}] as Array[Dictionary])
	reseau.inscrits.erase(7)
	var main3: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main3)
	current_scene = main3
	await _frames(2)
	var manche3: Node = main3.get_node("Manche")
	var hud3: CanvasLayer = main3.hud_bataille
	_check(manche3.barriere and manche3._partis == [1] and main3.lions.size() == 1
		and hud3.partis == [false, true] and hud3.vignettes[1].badge.text == "PARTI",
		"revue de la tâche 5 : un pair parti dans l'image entre deux manches est marqué parti dès la manche neuve, sans attendre la barrière")
	main3.free()
	await _frames(1)
	reseau.quitter()
	reseau.pseudo = ""
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	GS.niveau_courant = 0


## Un transport simulé (`_tester_ecran_en_ligne`, phase 4) : héberge sans rien ouvrir ni rien dire (son pair,
## un `WebRTCMultiplayerPeer` serveur, existe sur le desktop, sans connexion) ; le test émet lui-même `pret`,
## `echec` et `salle_fermee`, comme `TransportWebRTC`.
class TransportSalle extends Transport:
	var _pair: WebRTCMultiplayerPeer

	func heberger() -> Error:
		_pair = WebRTCMultiplayerPeer.new()
		return _pair.create_server()

	func rejoindre(_code: String) -> Error:
		return ERR_UNAVAILABLE

	func quitter() -> void:
		clore()

	func clore() -> void:
		if _pair != null:
			_pair.close()
			_pair = null

	func pair() -> MultiplayerPeer:
		return _pair

	func liberer(_id: int) -> void:
		pass

	func servir() -> bool:
		return _pair != null
