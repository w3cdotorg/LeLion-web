extends SceneTree
## Tests unitaires headless : godot --headless --script tests/unitaires.gd
## Logique pure (Joueur, puis territoire, couleurs, protocole…), sans charger de scène de jeu.

var _echecs := 0
## La version du protocole et son empreinte, mesurées (`_tester_protocole`).
const PROTOCOLE_VERSION := "0.19"
const PROTOCOLE_EMPREINTE := 2537463811


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _run() -> void:
	print("== tests unitaires LeLion ==")
	_tester_joueur()
	_tester_game_state()
	_tester_commandes()
	_tester_regles_solo()
	_tester_regles_bataille()
	_tester_delegation_regles()
	_tester_modes()
	_tester_facade_retiree()
	_tester_territoire()
	_tester_reseau()
	_tester_joueur_local()
	_tester_palette()
	_tester_decouverte()
	_tester_bataille_reseau()
	_tester_salon()
	_tester_peinture()
	_tester_territoire_reseau()
	_tester_joueur_replique()
	_tester_reseau_manche()
	_tester_deplacement_lion()
	_tester_commandes_reseau()
	_tester_commandes_dette()
	_tester_etat_lion()
	_tester_interpolation_lion()
	_tester_chrono_bataille()
	_tester_placement_pseudos()
	_tester_bilan_manche()
	_tester_manches_enchainees()
	_tester_transport_enet()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _tester_joueur() -> void:
	print("-- Joueur")
	var j := Joueur.new()
	j.reinitialiser(3)
	_check(j.vies == 3 and j.coups_recus == 0 and j.couleurs_debloquees.is_empty(), "un joueur réinitialisé a ses vies et aucune couleur")

	# Couleurs
	var recues: Array[Color] = []
	j.couleur_debloquee.connect(func(c: Color) -> void: recues.append(c))
	_check(j.debloquer_couleur(Color.RED), "débloquer une couleur nouvelle renvoie true")
	_check(not j.debloquer_couleur(Color.RED), "débloquer deux fois la même couleur renvoie false")
	_check(j.couleurs_debloquees == [Color.RED] and recues == [Color.RED], "la couleur est ajoutée et signalée une seule fois")

	# Coups : ordre des signaux, invulnérabilité, coup fatal
	var journal: Array[String] = []
	j.vies_changees.connect(func(v: int) -> void: journal.append("vies:%d" % v))
	j.touche.connect(func(o: Vector2) -> void: journal.append("touche:%d,%d" % [int(o.x), int(o.y)]))
	_check(j.encaisser_coup(Vector2(10, 20), 1.5) == 2, "un coup renvoie les vies restantes (2)")
	_check(journal == ["vies:2", "touche:10,20"], "ordre des signaux : vies_changees puis touche (%s)" % [journal])
	_check(j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 1.5) and j.coups_recus == 1, "après un coup : invulnérable 1,5 s, un coup compté")
	j.avancer(1.0)
	_check(is_equal_approx(j.invulnerable_restant, 0.5), "avancer décompte l'invulnérabilité")
	j.avancer(2.0)
	_check(j.invulnerable_restant == 0.0 and not j.est_invulnerable(), "l'invulnérabilité s'arrête à zéro, jamais en négatif")
	journal.clear()
	j.vies = 1
	_check(j.encaisser_coup(Vector2.INF, 1.5) == 0, "le dernier coup renvoie 0")
	_check(journal == ["vies:0"], "le coup fatal n'émet pas touche (%s)" % [journal])
	_check(not j.est_invulnerable(), "le coup fatal ne rend pas invulnérable")

	# Vies
	j.reinitialiser(3)
	_check(not j.gagner_vie(3), "impossible de dépasser le maximum de vies")
	j.vies = 2
	_check(j.gagner_vie(3) and j.vies == 3, "gagner une vie sous le maximum")

	# Bonus : une émission à l'activation, une à l'expiration
	var bonus: Array[bool] = []
	j.bonus_change.connect(func(actif: bool) -> void: bonus.append(actif))
	j.activer_bonus(8.0)
	j.activer_bonus(4.0)
	_check(bonus == [true] and is_equal_approx(j.bonus_restant, 8.0), "prolonger un bonus actif ne réémet pas et garde la durée la plus longue")
	j.avancer(7.9)
	_check(j.bonus_actif() and bonus == [true], "le bonus est encore actif avant son terme")
	j.avancer(0.2)
	_check(not j.bonus_actif() and j.bonus_restant == 0.0 and bonus == [true, false], "le bonus expire et le signale une fois")
	j.avancer(1.0)
	_check(bonus == [true, false], "pas de nouvelle émission après l'expiration")

	# Réinitialiser en plein bonus : silencieux (le lion est recréé par la nouvelle partie)
	j.activer_bonus(8.0)
	j.debloquer_couleur(Color.BLUE)
	bonus.clear()
	recues.clear()
	journal.clear()
	j.reinitialiser(1)
	_check(bonus.is_empty() and recues.is_empty() and journal.is_empty(), "reinitialiser n'émet aucun signal")
	_check(j.vies == 1 and not j.bonus_actif() and j.couleurs_debloquees.is_empty() and j.coups_recus == 0,
		"reinitialiser remet vies, bonus, couleurs et coups à l'état de départ")

	# Crans de gerbe : de 1 à CRANS_MAX, signalés
	var crans_recus: Array[int] = []
	j.crans_changes.connect(func(c: int) -> void: crans_recus.append(c))
	_check(j.crans == 1, "un joueur réinitialisé a un cran de gerbe")
	for i in range(Joueur.CRANS_MAX - 1):
		j.gagner_cran()
	_check(j.crans == Joueur.CRANS_MAX and crans_recus == [2, 3, 4, 5, 6, 7], "chaque cran gagné est signalé, jusqu'à 7 (%s)" % [crans_recus])
	_check(not j.gagner_cran() and j.crans == Joueur.CRANS_MAX and crans_recus.size() == 6, "au maximum, un cran de plus est refusé sans signal")

	# Nuances de la gerbe de bataille
	j.couleur = Color(0.16, 0.39, 0.95)
	var n: Array[Color] = j.nuances()
	_check(n.size() == 3 and n[1] == j.couleur and n[0].get_luminance() < n[1].get_luminance()
		and n[2].get_luminance() > n[1].get_luminance() and n.all(func(c: Color) -> bool: return c.a == 1.0),
		"trois nuances opaques : foncée, la couleur du joueur, claire")

	# Étourdissement puis immunité : une seule minuterie de protection
	var etourdissements: Array[String] = []
	j.etourdi.connect(func(o: Vector2, b: Color) -> void: etourdissements.append("etourdi:%d,%d:%s" % [int(o.x), int(o.y), b.to_html()]))
	j.etourdissement_fini.connect(func() -> void: etourdissements.append("fini"))
	j.etourdir(1.5, 1.0, Vector2(5, 6), Color.RED)
	_check(etourdissements == ["etourdi:5,6:%s" % Color.RED.to_html()], "etourdir signale l'origine et la couleur du barbouillage (%s)" % [etourdissements])
	_check(j.est_etourdi() and is_equal_approx(j.etourdi_restant, 1.5) and j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 2.5),
		"étourdi 1,5 s, et invulnérable pendant l'étourdissement puis 1 s d'immunité")
	j.avancer(1.0)
	_check(j.est_etourdi() and etourdissements.size() == 1, "l'étourdissement dure encore")
	j.avancer(0.6)
	_check(not j.est_etourdi() and j.etourdi_restant == 0.0 and etourdissements.back() == "fini",
		"la fin de l'étourdissement est signalée, jamais en négatif")
	_check(j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 0.9), "puis l'immunité continue seule (0,9 s restantes)")
	j.avancer(1.0)
	_check(not j.est_invulnerable() and etourdissements.size() == 2, "l'immunité s'arrête, la fin n'est signalée qu'une fois")

	# Réinitialiser : crans, étourdissement et statistiques repartent de zéro, en silence
	j.gagner_cran()
	j.etourdir(1.5, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	j.etourdissements_infliges = 2
	j.cellules_volees = 30
	j.chocs = 4
	crans_recus.clear()
	etourdissements.clear()
	j.reinitialiser(3)
	_check(j.crans == 1 and not j.est_etourdi() and not j.est_invulnerable() and j.etourdissements_infliges == 0
		and j.cellules_volees == 0 and j.chocs == 0 and crans_recus.is_empty() and etourdissements.is_empty(),
		"reinitialiser remet crans, étourdissement et statistiques à zéro sans signal")
	j.reinitialiser(3, j.nuances())
	_check(j.couleurs_debloquees == j.nuances() and recues.is_empty(), "reinitialiser peut donner des couleurs de départ, sans les signaler")
	var avant: Array[Color] = j.couleurs_debloquees
	j.reinitialiser(3)
	_check(j.couleurs_debloquees.is_empty() and is_same(avant, j.couleurs_debloquees),
		"les couleurs sont remises à zéro en place (le tableau lu par le lion et le HUD reste le même)")


func _tester_game_state() -> void:
	print("-- GameState (état de partie)")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	_check(gs.joueurs.size() == 1 and gs.joueur_local() == gs.joueurs[0], "en solo, un seul joueur, qui est le joueur local")
	var j: Joueur = gs.joueur_local()
	_check(j.vies == 3, "nouvelle_partie donne au joueur les vies de la difficulté")

	# Les minuteries du joueur ne tournent qu'en partie, une fois prêt
	j.bonus_restant = 0.5
	j.invulnerable_restant = 0.25
	gs.pret = false
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.25) and is_equal_approx(j.bonus_restant, 0.5), "pendant l'intro, les minuteries ne décomptent pas")
	gs.pret = true
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.05) and is_equal_approx(j.bonus_restant, 0.3), "une fois prêt, GameState fait avancer le joueur")
	gs.terminer_partie(false)
	j.invulnerable_restant = 0.4
	j.bonus_restant = 0.6
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.4) and is_equal_approx(j.bonus_restant, 0.6),
		"après la fin de partie, les minuteries ne décomptent plus")

	# Nouvelle partie : repart de zéro
	j.activer_bonus(8.0)
	j.coups_recus = 2
	gs.nouvelle_partie()
	_check(j.couleurs_debloquees.is_empty() and j.vies == 3 and j.coups_recus == 0 and not j.bonus_actif(),
		"nouvelle_partie remet le joueur local à zéro")
	gs.partie_en_cours = false
	gs.pret = false


func _tester_commandes() -> void:
	print("-- Commandes")
	var m := Commandes.manuelles()
	_check(m.source == Commandes.Source.MANUELLES and m.direction() == Vector2.ZERO and not m.vomir(),
		"des commandes manuelles neuves sont au repos")
	m.direction_voulue = Vector2(0.6, -0.8)
	m.vomir_voulu = true
	_check(m.direction() == Vector2(0.6, -0.8) and m.vomir(), "les commandes manuelles renvoient ce qu'on y écrit")

	var l := Commandes.locales()
	_check(l.source == Commandes.Source.LOCALES, "Commandes.locales() crée des commandes locales")
	_check(l.direction() == Vector2.ZERO and not l.vomir(), "sans action pressée, les commandes locales sont au repos")
	Input.action_press("deplacer_droite")
	Input.action_press("vomir")
	_check(l.direction().x > 0.99 and absf(l.direction().y) < 0.01 and l.vomir(), "les commandes locales lisent les actions de ce poste")
	m.direction_voulue = Vector2.ZERO
	m.vomir_voulu = false
	_check(m.direction() == Vector2.ZERO and not m.vomir(), "les commandes manuelles ignorent le clavier et la manette")
	l.direction_voulue = Vector2.LEFT
	_check(l.direction().x > 0.99, "écrire direction_voulue ne change pas des commandes locales")
	Input.action_release("deplacer_droite")
	Input.action_release("vomir")
	_check(l.direction() == Vector2.ZERO and not l.vomir(), "relâcher les actions remet les commandes locales au repos")
	m.direction_voulue = Vector2(3, 4)
	_check(is_equal_approx(m.direction().length(), 1.0) and m.direction().is_equal_approx(Vector2(0.6, 0.8)),
		"direction() borne les commandes manuelles à une longueur de 1")
	# Phase 14 : le menu local d'une manche en réseau suspend les commandes de ce poste
	Input.action_press("deplacer_gauche")
	Input.action_press("vomir")
	m.vomir_voulu = true
	l.suspendues = true
	m.suspendues = true
	_check(l.direction() == Vector2.ZERO and not l.vomir() and m.direction() == Vector2.ZERO and not m.vomir(),
		"des commandes suspendues (menu local ouvert) valent le repos, quelle que soit leur source")
	l.suspendues = false
	m.suspendues = false
	_check(l.direction().x < -0.99 and l.vomir() and m.vomir(), "levée la suspension, elles lisent de nouveau leur source")
	Input.action_release("deplacer_gauche")
	Input.action_release("vomir")


func _tester_regles_solo() -> void:
	print("-- Règles")
	var gs: Node = root.get_node("GameState")
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true

	# Règles de base : aucun effet
	var base := Regles.new(gs)
	var j := Joueur.new()
	j.reinitialiser(3)
	base.lion_touche_par_ennemi(j, Vector2.ZERO)
	base.etoile_ramassee(j)
	base.progression_mesuree(1.0)
	_check(j.vies == 3 and not j.bonus_actif() and not base.pastille_ramassee(j, 0)
		and j.couleurs_debloquees.is_empty() and fins.is_empty(), "les règles de base n'ont aucun effet")
	j.vies = 2
	_check(not base.coeur_ramasse(j) and j.vies == 2, "coeur_ramasse des règles de base n'a aucun effet, même sous le maximum")
	j.vies = 3
	var autre := Joueur.new()
	autre.reinitialiser(3)
	base.lion_touche_par_vomi(j, autre, Vector2.ZERO)
	base.choc_entre_lions(j, autre)
	base.vol_de_cellules(j, 4)
	_check(base.couleurs_de_depart(j).is_empty() and not j.est_etourdi() and not j.est_invulnerable()
		and autre.etourdissements_infliges == 0 and j.chocs == 0 and autre.chocs == 0 and j.cellules_volees == 0,
		"sans règles de mode, ni couleur de départ, ni effet du vomi, des chocs ou des vols")
	_check(not base.compte_le_territoire() and not ReglesSolo.new(gs).compte_le_territoire(),
		"ni les règles de base ni celles du solo ne se jouent au territoire")
	_check(base.pastille_a_offrir() == -1 and not base.etoile_peut_apparaitre() and not base.coeurs_en_jeu()
		and not base.coeur_peut_apparaitre() and base.avancement() == 0.0 and base.taille_ecran() == Regles.TAILLE_ECRAN_SOLO,
		"les règles de base ne font rien apparaître, rien n'accélère, l'écran est celui du solo (2000×648)")
	_check(base.has_method("manche_en_cours") and not base.has_method("_manche_en_cours"),
		"manche_en_cours() est publique : la ville la lit")

	# Règles solo : elles agissent sur le joueur reçu, pas sur le joueur local
	var r := ReglesSolo.new(gs)
	var local: Joueur = gs.joueur_local()
	var touches_locales: Array[Vector2] = []
	var sur_touche_locale := func(o: Vector2) -> void: touches_locales.append(o)
	local.touche.connect(sur_touche_locale)
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2 and j.est_invulnerable() and local.vies == 3 and touches_locales.is_empty(),
		"un coup d'ennemi touche le joueur reçu, pas le joueur local, et ne lui signale aucun coup")
	local.touche.disconnect(sur_touche_locale)
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2, "pas de coup pendant l'invulnérabilité")
	j.invulnerable_restant = 0.0
	gs.pret = false
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2, "pas de coup pendant l'intro")
	gs.pret = true

	# Pastilles, étoile, cœur
	_check(r.pastille_ramassee(j, 2) and j.couleurs_debloquees == [gs.couleur(2)], "une pastille débloque sa couleur de l'arc-en-ciel chez le joueur reçu")
	_check(j.crans == 2, "en solo, chaque nouvelle couleur donne aussi un cran de gerbe")
	_check(not r.pastille_ramassee(j, 2) and j.crans == 2, "une couleur déjà débloquée n'a pas d'effet, pas même un cran")
	_check(not r.pastille_ramassee(j, -1) and not r.pastille_ramassee(j, gs.nb_couleurs_total()) and j.couleurs_debloquees.size() == 1
		and j.crans == 2, "un index de couleur hors bornes est refusé")
	var toutes := Joueur.new()
	toutes.reinitialiser(3)
	for i in range(gs.nb_couleurs_total()):
		r.pastille_ramassee(toutes, i)
	_check(toutes.couleurs_debloquees.size() == 7 and toutes.crans == Joueur.CRANS_MAX,
		"les sept couleurs débloquées, la gerbe plafonne à son dernier cran (7)")
	r.etoile_ramassee(j)
	_check(j.bonus_actif() and is_equal_approx(j.bonus_restant, Regles.DUREE_ETOILE), "l'étoile active la gerbe XXL pour DUREE_ETOILE secondes")
	_check(r.coeur_ramasse(j) and j.vies == 3, "un cœur rend une vie")
	_check(not r.coeur_ramasse(j) and j.vies == gs.VIES_MAX, "un cœur ne dépasse pas le maximum de vies")

	# Apparitions du solo : elles suivent le joueur local, l'unique joueur (lues par le Spawner)
	local.reinitialiser(3)
	_check(r.pastille_a_offrir() == 0 and not r.etoile_peut_apparaitre(),
		"sans couleur, la prochaine pastille est la première de l'arc-en-ciel ; pas d'étoile")
	local.debloquer_couleur(gs.couleur(0))
	_check(r.pastille_a_offrir() == 1 and not r.etoile_peut_apparaitre(),
		"une couleur : la pastille suivante est la deuxième, toujours pas d'étoile")
	local.debloquer_couleur(gs.couleur(1))
	_check(r.pastille_a_offrir() == 2 and r.etoile_peut_apparaitre(), "dès deux couleurs, l'étoile peut apparaître")
	local.activer_bonus(1.0)
	_check(not r.etoile_peut_apparaitre(), "pas d'étoile pendant une gerbe XXL")
	local.bonus_restant = 0.0
	for i in range(2, gs.nb_couleurs_total() - 1):
		local.debloquer_couleur(gs.couleur(i))
	_check(r.pastille_a_offrir() == gs.nb_couleurs_total() - 1, "six couleurs : la dernière pastille (violet) est encore offerte")
	local.debloquer_couleur(gs.couleur(gs.nb_couleurs_total() - 1))
	_check(r.pastille_a_offrir() == -1, "toutes les couleurs débloquées : plus de pastille à offrir")
	_check(r.coeurs_en_jeu() and not r.coeur_peut_apparaitre(), "en Facile, des cœurs, mais aucun tant que le joueur a toutes ses vies")
	local.vies = 2
	_check(r.coeur_peut_apparaitre(), "un cœur peut apparaître dès qu'une vie manque")
	gs.difficulte_courante = 1
	var sans_coeur_moyen := not r.coeurs_en_jeu()
	gs.difficulte_courante = 2
	_check(sans_coeur_moyen and not r.coeurs_en_jeu(), "ni en Moyen ni en Hardcore")
	gs.difficulte_courante = 0
	local.reinitialiser(3)
	gs.progression = 0.425
	_check(is_equal_approx(r.avancement(), 0.5), "l'avancement du solo est la ville peinte rapportée au seuil (0,425 / 0,85)")
	gs.progression = 0.9
	_check(r.avancement() > 1.0, "au-delà du seuil, l'avancement dépasse 1 (les appelants le bornent)")
	gs.progression = 0.0
	_check(r.taille_ecran() == Vector2i(2000, 648), "l'écran du solo reste en 2000×648")

	# Progression : victoire au seuil, une seule fois
	r.progression_mesuree(gs.seuil_victoire() - 0.01)
	_check(fins.is_empty() and gs.partie_en_cours, "sous le seuil, la partie continue")
	r.progression_mesuree(gs.seuil_victoire())
	_check(fins == [true] and not gs.partie_en_cours, "au seuil de la difficulté, la partie est gagnée")
	r.progression_mesuree(1.0)
	_check(fins == [true], "la victoire n'est signalée qu'une fois")

	# Coup fatal : défaite, et plus aucun coup ensuite
	gs.nouvelle_partie()
	gs.pret = true
	fins.clear()
	j.reinitialiser(1)
	r.lion_touche_par_ennemi(j, Vector2.INF)
	_check(j.vies == 0 and fins == [false] and not gs.partie_en_cours, "le dernier coup termine la partie en défaite")
	r.lion_touche_par_ennemi(j, Vector2.INF)
	_check(j.vies == 0 and fins == [false], "après la fin de partie, un lion à 0 vie n'est plus frappé")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


func _tester_regles_bataille() -> void:
	print("-- Règles de bataille")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	var r := ReglesBataille.new(gs)
	var rouge := Joueur.new()
	rouge.couleur = Color(0.90, 0.16, 0.16)
	var bleu := Joueur.new()
	bleu.couleur = Color(0.16, 0.39, 0.95)
	for j: Joueur in [rouge, bleu]:
		j.reinitialiser(3, r.couleurs_de_depart(j))
	_check(rouge.couleurs_debloquees == rouge.nuances() and bleu.couleurs_debloquees == bleu.nuances(),
		"en bataille, chaque joueur vomit dès le départ dans ses trois nuances")
	var barbouillages: Array[Color] = []
	bleu.etourdi.connect(func(_o: Vector2, b: Color) -> void: barbouillages.append(b))

	# Vomi : 1,5 s d'étourdissement, barbouillé de la couleur de l'agresseur, puis 1 s d'immunité
	r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(bleu.est_etourdi() and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_VOMI)
		and is_equal_approx(bleu.invulnerable_restant, ReglesBataille.DUREE_ETOURDI_VOMI + ReglesBataille.DUREE_IMMUNITE)
		and barbouillages == [rouge.couleur],
		"le vomi d'un autre lion étourdit 1,5 s, barbouille de la couleur de l'agresseur, puis immunise 1 s")
	_check(rouge.etourdissements_infliges == 1 and bleu.vies == 3 and fins.is_empty(),
		"l'étourdissement compte pour l'agresseur ; aucune vie perdue, la manche continue")
	for i in range(10):
		r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(barbouillages.size() == 1 and rouge.etourdissements_infliges == 1 and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_VOMI),
		"un lion déjà étourdi n'est pas ré-étourdi (contact signalé à chaque frame)")
	bleu.avancer(ReglesBataille.DUREE_ETOURDI_VOMI + 0.1)
	r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(not bleu.est_etourdi() and bleu.est_invulnerable() and barbouillages.size() == 1 and rouge.etourdissements_infliges == 1,
		"un lion immunisé n'est pas étourdi et ne compte pas")
	bleu.avancer(ReglesBataille.DUREE_IMMUNITE)
	r.lion_touche_par_vomi(rouge, rouge, Vector2.ZERO)
	_check(not rouge.est_etourdi() and rouge.etourdissements_infliges == 1, "son propre vomi n'étourdit pas")
	rouge.etourdir(1.0, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	rouge.etourdi_a_la_frame = Engine.get_physics_frames() - 1  # simule un étourdissement d'une frame passée
	r.lion_touche_par_vomi(bleu, rouge, Vector2.ZERO)
	_check(not bleu.est_etourdi() and rouge.etourdissements_infliges == 1, "un lion étourdi lors d'une frame passée n'étourdit personne")
	rouge.avancer(2.0)

	# Trade tête-à-tête : deux lions se vomissent dessus la même frame, les deux rapports portent
	var a := Joueur.new()
	a.couleur = Color(0.90, 0.16, 0.16)
	var b := Joueur.new()
	b.couleur = Color(0.16, 0.39, 0.95)
	for j: Joueur in [a, b]:
		j.reinitialiser(3, r.couleurs_de_depart(j))
	r.lion_touche_par_vomi(b, a, Vector2.ZERO)
	r.lion_touche_par_vomi(a, b, Vector2.ZERO)
	_check(a.est_etourdi() and b.est_etourdi() and a.etourdissements_infliges == 1 and b.etourdissements_infliges == 1,
		"un trade tête-à-tête dans la même frame étourdit les deux lions (aucun n'est ignoré comme agresseur déjà étourdi)")

	# Ennemis : 2,5 s sans barbouillage, puis 3 s de répit (phase 17 : le temps de fuir le peintre) ;
	# aucune vie perdue
	for i in range(10):
		r.lion_touche_par_ennemi(bleu, Vector2(1, 2))  # le peintre signale le contact à chaque frame
	_check(bleu.est_etourdi() and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_ENNEMI)
		and is_equal_approx(bleu.invulnerable_restant, ReglesBataille.DUREE_ETOURDI_ENNEMI + ReglesBataille.DUREE_REPIT_ENNEMI)
		and barbouillages.size() == 2 and barbouillages[1].a == 0.0 and bleu.vies == 3,
		"un ennemi étourdit 2,5 s sans barbouillage (un seul étourdissement pour dix contacts), sans vie perdue, puis laisse 3 s de répit")
	bleu.avancer(ReglesBataille.DUREE_ETOURDI_ENNEMI + ReglesBataille.DUREE_REPIT_ENNEMI - 0.1)
	r.lion_touche_par_ennemi(bleu, Vector2(1, 2))
	_check(barbouillages.size() == 2, "un ennemi ne ré-étourdit pas un lion pendant son répit (le peintre encore dessus)")
	bleu.avancer(0.2)
	gs.pret = false
	r.lion_touche_par_ennemi(bleu, Vector2(1, 2))
	r.lion_touche_par_vomi(bleu, rouge, Vector2.ZERO)
	_check(barbouillages.size() == 2, "rien n'étourdit pendant l'intro")
	gs.pret = true

	# Chocs : comptés des deux côtés, jamais d'étourdissement
	r.choc_entre_lions(rouge, bleu)
	_check(rouge.chocs == 1 and bleu.chocs == 1 and not rouge.est_etourdi() and not bleu.est_etourdi(),
		"un choc compte pour les deux lions et n'étourdit personne")
	r.choc_entre_lions(rouge, rouge)
	_check(rouge.chocs == 1, "un lion ne se choque pas lui-même")

	# Pastilles, étoile, cœur, progression
	_check(r.pastille_ramassee(rouge, 5) and rouge.crans == 2 and rouge.couleurs_debloquees == rouge.nuances(),
		"une pastille donne un cran de gerbe, quelle que soit sa couleur, sans débloquer de couleur")
	for i in range(10):
		r.pastille_ramassee(rouge, 0)
	_check(rouge.crans == Joueur.CRANS_MAX and not r.pastille_ramassee(rouge, 0), "les crans plafonnent à 7")
	r.etoile_ramassee(bleu)
	_check(bleu.bonus_actif() and is_equal_approx(bleu.bonus_restant, Regles.DUREE_ETOILE), "l'étoile XXL est celle du solo (même durée, constante de la base)")
	bleu.vies = 2
	_check(not r.coeur_ramasse(bleu) and bleu.vies == 2, "aucun cœur en bataille")
	r.progression_mesuree(1.0)
	_check(fins.is_empty() and gs.partie_en_cours, "peindre toute la ville ne termine pas la manche (elle finit au chrono)")

	# Territoire : la bataille s'y joue, les vols comptent pour « Le voleur »
	_check(r.compte_le_territoire(), "la bataille se joue au territoire")
	r.vol_de_cellules(rouge, 5)
	r.vol_de_cellules(rouge, 0)
	_check(rouge.cellules_volees == 5 and bleu.cellules_volees == 0, "les cellules volées comptent pour le voleur seul (%d)" % rouge.cellules_volees)
	gs.pret = false
	r.vol_de_cellules(rouge, 2)
	_check(rouge.cellules_volees == 5, "un vol pendant l'intro ne compte pas")
	gs.pret = true

	# Apparitions et écran de la bataille : rien ne dépend du joueur local
	var indices_valides := true
	for i in range(50):
		var k := r.pastille_a_offrir()
		if k < 0 or k >= gs.nb_couleurs_total():
			indices_valides = false
	_check(indices_valides, "une pastille est toujours offerte, d'une couleur valide de l'arc-en-ciel (pour l'œil)")
	var local: Joueur = gs.joueur_local()
	local.reinitialiser(1)
	local.activer_bonus(1.0)
	_check(r.etoile_peut_apparaitre(), "l'étoile peut toujours apparaître, même si le joueur local n'a pas de couleur ou est en gerbe XXL")
	_check(gs.difficulte_courante == 0 and not r.coeurs_en_jeu() and not r.coeur_peut_apparaitre(),
		"aucun cœur en bataille, même en Facile et même quand le joueur local a perdu des vies")
	local.reinitialiser(3)
	gs.temps_ecoule = 45.0
	gs.progression = 1.0
	_check(is_equal_approx(r.avancement(), 0.5) and is_equal_approx(ReglesBataille.DUREE_MANCHE, 90.0),
		"l'avancement de la bataille est le temps de la manche (45 s sur 90), pas la ville peinte")
	gs.temps_ecoule = 0.0
	gs.progression = 0.0
	_check(r.avancement() == 0.0, "au départ de la manche, l'avancement est nul")
	_check(r.taille_ecran() == Vector2i(2000, 1125), "l'écran de la bataille est en 16:9 (2000×1125)")
	gs.terminer_partie(false)
	bleu.invulnerable_restant = 0.0
	bleu.etourdi_restant = 0.0
	var etourdissements_avant := rouge.etourdissements_infliges
	r.lion_touche_par_ennemi(bleu, Vector2.ZERO)
	r.lion_touche_par_vomi(bleu, rouge, Vector2.ZERO)
	r.choc_entre_lions(rouge, bleu)
	r.vol_de_cellules(rouge, 3)
	_check(not bleu.est_etourdi() and bleu.chocs == 1 and rouge.etourdissements_infliges == etourdissements_avant
		and rouge.cellules_volees == 5,
		"après la fin de manche, plus d'étourdissement (ennemi ou vomi), de choc ni de vol compté")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


func _tester_delegation_regles() -> void:
	print("-- GameState délègue aux règles")
	var gs: Node = root.get_node("GameState")
	_check(gs.regles is ReglesSolo, "par défaut, GameState applique les règles du solo")
	var solo: Regles = gs.regles
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)

	# Des règles sans effet : la victoire ne vient plus de GameState
	gs.regles = Regles.new(gs)
	gs.signaler_progression(1.0)
	_check(fins.is_empty() and gs.partie_en_cours and is_equal_approx(gs.progression, 1.0),
		"signaler_progression enregistre toujours la progression mais laisse la victoire aux règles branchées")

	# Retour aux règles du solo : la même progression gagne la partie
	gs.regles = solo
	gs.signaler_progression(1.0)
	_check(fins == [true] and not gs.partie_en_cours, "avec les règles du solo, la même progression gagne la partie")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


func _tester_modes() -> void:
	print("-- Mise en place des modes")
	var gs: Node = root.get_node("GameState")
	var tableau: Array[Joueur] = gs.joueurs
	var local: Joueur = gs.joueur_local()
	gs.configurer_bataille(4)
	_check(gs.regles is ReglesBataille and gs.joueurs.size() == 4, "configurer_bataille(4) branche les règles de bataille pour 4 joueurs")
	_check(is_same(tableau, gs.joueurs) and gs.joueur_local() == local,
		"les joueurs sont ajoutés en place : même tableau, joueur local inchangé (Audio y est abonné)")
	var indices: Array = gs.joueurs.map(func(j: Joueur) -> int: return j.index)
	var couleurs: Array = gs.joueurs.map(func(j: Joueur) -> Color: return j.couleur)
	_check(indices == [0, 1, 2, 3] and couleurs == gs.PALETTE_BATAILLE.slice(0, 4),
		"chaque joueur a son index et sa couleur de la palette (%s)" % [indices])
	var troisieme: Joueur = gs.joueurs[2]
	gs.nouvelle_partie()
	_check(gs.joueurs.all(func(j: Joueur) -> bool: return j.crans == 1 and j.couleurs_debloquees == j.nuances()),
		"une nouvelle partie de bataille donne à chacun un cran et ses trois nuances")
	gs.pret = true
	troisieme.etourdir(1.0, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	gs._process(0.4)
	_check(is_equal_approx(troisieme.etourdi_restant, 0.6), "GameState fait avancer tous les joueurs, pas seulement le joueur local")
	gs.configurer_bataille(2)
	_check(gs.joueurs.size() == 2 and is_same(tableau, gs.joueurs) and gs.joueur_local() == local, "moins de joueurs : retirés en place")
	gs.configurer_solo()
	_check(gs.regles is ReglesSolo and gs.joueurs.size() == 1 and gs.joueur_local() == local and is_same(tableau, gs.joueurs),
		"bataille puis solo : règles du solo et un seul joueur, le même")
	gs.nouvelle_partie()
	_check(not local.a_une_couleur() and local.couleurs_debloquees.is_empty() and local.crans == 1,
		"le joueur du solo n'a plus de couleur (son lion retrouve son rendu d'origine) et repart sans couleur débloquée")
	gs.partie_en_cours = false
	gs.pret = false


func _tester_facade_retiree() -> void:
	print("-- GameState sans façade")
	var gs: Node = root.get_node("GameState")
	var restes: Array[String] = []
	for nom in ["couleurs_debloquees", "vies", "coups_recus", "invulnerable_restant", "bonus_restant"]:
		if nom in gs:
			restes.append(nom)
	for nom in ["est_invulnerable", "toucher_lion", "gagner_vie", "debloquer_couleur", "bonus_actif", "activer_bonus"]:
		if gs.has_method(nom):
			restes.append(nom + "()")
	for nom in ["couleur_debloquee", "bonus_change", "vies_changees", "lion_touche"]:
		if gs.has_signal(nom):
			restes.append("signal " + nom)
	_check(restes.is_empty(), "GameState n'expose plus l'état par joueur (restes : %s)" % [restes])


func _tester_territoire() -> void:
	print("-- Territoire")
	# Grille de 4 × 3 cellules de 8 px, rangée par rangée ; la cellule 11 (colonne 3, rangée 2)
	# n'est pas peignable. La cellule 5 (colonne 1, rangée 1) a son centre en (12, 12) : un tampon
	# de 5 px qui y est centré ne touche qu'elle (le centre de ses voisines est à 8 px).
	var peignables := PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0])
	var centre_5 := Vector2i(12, 12)
	var n_prise := ceili(float(Territoire.SEUIL_POSSESSION) / Territoire.GAIN)
	var n_vider := ceili(float(Territoire.CHARGE_MAX) / Territoire.GAIN)
	_check(n_prise == 3 and n_vider == 3,
		"réglages : 3 tampons pour posséder une cellule vierge, 3 pour vider une cellule qui compte déjà (CHARGE_MAX = SEUIL_POSSESSION) (%d, %d)" % [n_prise, n_vider])
	var t := Territoire.new(Vector2i(4, 3), peignables)
	_check(t.nb_peignables == 11 and t.cellules_de(0) == 0 and t.cellules_de(Territoire.PERSONNE) == 11
		and t.proprietaire(5) == Territoire.PERSONNE and t.extraire_changements().is_empty(),
		"un territoire neuf est vierge : 11 cellules peignables, qui ne comptent pour personne")

	# Peindre une cellule vierge : chargée au premier tampon, comptée au troisième
	_check(t.tamponner(0, centre_5, 5) == 0 and t.proprietaire(5) == 0 and t.charge(5) == Territoire.GAIN
		and t.cellules_de(0) == 0 and t.proprietaire_compte(5) == Territoire.PERSONNE,
		"un tampon sur une cellule vierge la charge pour le peintre, sans la faire compter encore")
	_check(range(12).all(func(i: int) -> bool: return i == 5 or t.charge(i) == 0),
		"le tampon ne touche que les cellules dont le centre est à moins de son rayon")
	for i in range(n_prise - 1):
		t.tamponner(0, centre_5, 5)
	_check(t.cellules_de(0) == 1 and t.proprietaire_compte(5) == 0 and t.cellules_de(Territoire.PERSONNE) == 10,
		"au troisième tampon, la cellule compte pour le peintre")
	_check(t.extraire_changements() == PackedInt32Array([5]) and t.extraire_changements().is_empty(),
		"la cellule qui se met à compter est listée une fois, et la liste se vide à la lecture")
	for i in range(10):
		t.tamponner(0, centre_5, 5)
	_check(t.charge(5) == Territoire.CHARGE_MAX and t.cellules_de(0) == 1 and t.extraire_changements().is_empty(),
		"repeinte par son propriétaire, la charge reste à son plafond (déjà atteint dès le seuil de possession), sans nouveau changement")

	# Vol : l'adversaire vide la cellule, la prend, puis la possède
	var vols := 0
	for i in range(n_vider - 1):
		vols += t.tamponner(1, centre_5, 5)
	_check(t.proprietaire(5) == 0 and t.proprietaire_compte(5) == Territoire.PERSONNE and t.cellules_de(0) == 0
		and t.cellules_de(1) == 0 and vols == 0,
		"un adversaire décharge la cellule : sous le seuil, elle ne compte plus pour personne, mais reste au premier peintre")
	vols += t.tamponner(1, centre_5, 5)
	_check(t.proprietaire(5) == 1 and t.charge(5) == 0 and vols == 0, "vidée, la cellule passe à l'adversaire, sans charge et sans vol encore")
	for i in range(n_prise):
		vols += t.tamponner(1, centre_5, 5)
	_check(t.cellules_de(1) == 1 and t.proprietaire_compte(5) == 1 and vols == 1,
		"dès qu'elle compte pour lui, c'est un vol, compté une fois (%d)" % vols)
	_check(t.extraire_changements() == PackedInt32Array([5]), "la cellule volée est listée une fois, même passée par « personne »")
	for i in range(n_vider + n_prise):
		vols += t.tamponner(0, centre_5, 5)
	_check(t.proprietaire_compte(5) == 0 and vols == 2, "la reprendre à son voleur est aussi un vol")

	# Vol à trois : A possède, B décharge sans prendre, C prend : le vol est crédité à C, pas à B.
	var t2 := Territoire.new(Vector2i(4, 3), peignables)
	for i in range(n_prise):
		t2.tamponner(0, centre_5, 5)  # A prend la cellule
	for i in range(n_vider - 1):
		t2.tamponner(1, centre_5, 5)  # B la décharge sous le seuil, sans la faire compter pour lui
	_check(t2.proprietaire(5) == 0 and t2.proprietaire_compte(5) == Territoire.PERSONNE,
		"B décharge la cellule d'A sous le seuil sans la lui prendre")
	var vols_c := 0
	for i in range(1 + n_prise):
		vols_c += t2.tamponner(2, centre_5, 5)  # C la prend et la fait compter
	_check(t2.proprietaire_compte(5) == 2 and vols_c == 1,
		"le vol est crédité à C, qui fait compter la cellule, pas à B, qui l'avait seulement déchargée")

	# Reprise sans vol : B prend la cellule brute d'A (sous le seuil), puis A la reprend : comme la
	# cellule n'a jamais compté pour B, la reprise d'A n'est pas un vol.
	var t3 := Territoire.new(Vector2i(4, 3), peignables)
	for i in range(n_prise):
		t3.tamponner(0, centre_5, 5)  # A prend et fait compter la cellule
	for i in range(n_vider):
		t3.tamponner(1, centre_5, 5)  # B la vide et se la fait attribuer, sans atteindre le seuil
	_check(t3.proprietaire(5) == 1 and t3.proprietaire_compte(5) == Territoire.PERSONNE,
		"la cellule vidée passe à B sans compter pour lui")
	var vols_retour := 0
	for i in range(n_prise):
		vols_retour += t3.tamponner(0, centre_5, 5)  # A la reprend et la refait compter
	_check(t3.proprietaire_compte(5) == 0 and vols_retour == 0,
		"A reprend une cellule que B n'a jamais fait compter : ce n'est pas un vol")

	# Réglage (fiche de correction du 25/09) : depuis CHARGE_MAX = SEUIL_POSSESSION, une passe pleine
	# vitesse d'un adversaire vole des cellules au lieu de seulement les effacer. On reprend la forme
	# de sonde du plan de la phase 9 : 60 tampons par seconde à 350 px/s, rayons 16 puis 21 (les deux
	# premiers crans de gerbe).
	var n_saturer := ceili(float(Territoire.CHARGE_MAX) / Territoire.GAIN)
	for rayon_b in [16, 21]:
		var largeur := 60
		var hauteur := 4
		var taille_cellule_bande := 8
		var bande := PackedByteArray()
		bande.resize(largeur * hauteur)
		bande.fill(1)
		var v := Territoire.new(Vector2i(largeur, hauteur), bande, taille_cellule_bande)
		# A charge sa bande au maximum, comme une passe pleine vitesse (5 à 7 tampons par cellule) :
		# chargée au seul seuil (n_prise tampons), la vérification passait aussi avec l'ancien
		# CHARGE_MAX = 24, qu'elle doit refuser.
		for i in range(n_saturer):
			v.tamponner(0, Vector2i(largeur * taille_cellule_bande / 2, hauteur * taille_cellule_bande / 2), 400)
		var avant_a := v.cellules_de(0)
		_check(v.charge(0) == Territoire.CHARGE_MAX and avant_a == largeur * hauteur,
			"(pré-condition) A possède toute la bande, chargée au maximum (%d)" % v.charge(0))
		var x := 0.0
		while x < largeur * taille_cellule_bande:
			v.tamponner(1, Vector2i(int(x), hauteur * taille_cellule_bande / 2), rayon_b)  # B traverse à 350 px/s, 60 tampons/s
			x += 350.0 / 60.0
		_check(v.cellules_de(1) > 0 and v.cellules_de(0) < avant_a,
			"une passe pleine vitesse de B (rayon %d) sur la bande d'A lui vole des cellules (B : %d, A : %d → %d)"
				% [rayon_b, v.cellules_de(1), avant_a, v.cellules_de(0)])

	# Deux peintres qui se disputent une cellule vierge tampon après tampon
	var u := Territoire.new(Vector2i(4, 3), peignables)
	var vols_disputes := 0
	for i in range(20):
		vols_disputes += u.tamponner(0, centre_5, 5)
		vols_disputes += u.tamponner(1, centre_5, 5)
	_check(vols_disputes == 0 and u.cellules_de(0) == 0 and u.cellules_de(1) == 0,
		"deux peintres qui se disputent une cellule que personne n'a possédée ne se volent rien")

	# Bords et cellules non peignables
	u.tamponner(2, Vector2i(16, 12), 40)  # couvre toute la grille
	_check(u.charge(11) == 0 and u.proprietaire(11) == Territoire.PERSONNE and u.proprietaire(0) == 2,
		"une cellule non peignable ne change jamais")
	var w := Territoire.new(Vector2i(4, 3), peignables)
	w.tamponner(0, Vector2i(-2, 12), 8)
	_check(w.charge(4) == Territoire.GAIN and range(12).all(func(i: int) -> bool: return i == 4 or w.charge(i) == 0),
		"un tampon débordant à gauche ne touche que la première colonne, jamais la fin de la rangée précédente")
	_check(w.tamponner(3, Vector2i(5000, -5000), 46) == 0 and range(12).all(func(i: int) -> bool: return i == 4 or w.charge(i) == 0),
		"un tampon hors de la grille ne touche rien")
	w.reinitialiser()
	_check(w.charge(4) == 0 and w.proprietaire(4) == Territoire.PERSONNE and w.cellules_de(Territoire.PERSONNE) == 11
		and w.extraire_changements().is_empty(), "reinitialiser rend toute la ville vierge")

	# Index de joueur hors plage : la garde d'exécution (pas seulement l'assert de debug, retirée
	# à l'export release) refuse le tampon sans rien changer.
	_check(w.tamponner(-1, centre_5, 5) == 0 and w.tamponner(EtatPartie.NB_JOUEURS_MAX, centre_5, 5) == 0
		and w.charge(5) == 0 and w.proprietaire(5) == Territoire.PERSONNE
		and w.cellules_de(Territoire.PERSONNE) == 11 and w.extraire_changements().is_empty(),
		"un index de joueur hors plage (négatif ou ≥ NB_JOUEURS_MAX) ne touche aucune cellule")

	# Déterminisme et scores, sur une suite de tampons pseudo-aléatoire à trois joueurs
	var grande := PackedByteArray()
	grande.resize(40 * 20)
	for i in range(grande.size()):
		grande[i] = 0 if i % 7 == 0 else 1
	var a := Territoire.new(Vector2i(40, 20), grande)
	var b := Territoire.new(Vector2i(40, 20), grande)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(600):
		var joueur := rng.randi_range(0, 2)
		var centre := Vector2i(rng.randi_range(-20, 340), rng.randi_range(-20, 180))
		var rayon := rng.randi_range(8, 46)
		a.tamponner(joueur, centre, rayon)
		b.tamponner(joueur, centre, rayon)
	var identiques := true
	var recompte := [0, 0, 0]
	for i in range(grande.size()):
		if a.proprietaire(i) != b.proprietaire(i) or a.charge(i) != b.charge(i):
			identiques = false
		var p := a.proprietaire_compte(i)
		if p != Territoire.PERSONNE:
			recompte[p] += 1
	_check(identiques, "mêmes tampons dans le même ordre, même territoire (calcul entier, déterministe)")
	_check(recompte == [a.cellules_de(0), a.cellules_de(1), a.cellules_de(2)] and recompte.all(func(n: int) -> bool: return n > 0)
		and a.cellules_de(Territoire.PERSONNE) + recompte[0] + recompte[1] + recompte[2] == a.nb_peignables,
		"les scores tenus tampon après tampon égalent un recompte complet (%s)" % [recompte])
	var liste := a.extraire_changements()
	var listees := {}
	for i in liste:
		listees[i] = true
	_check(listees.size() == liste.size()
		and range(grande.size()).all(func(i: int) -> bool: return a.proprietaire_compte(i) == Territoire.PERSONNE or listees.has(i)),
		"chaque cellule qui compte figure dans la liste des changements, une seule fois (%d)" % liste.size())

	# Coût : une seconde de bataille à 6 lions (60 tampons par lion) sur une grille de 250 × 81
	var pleine := PackedByteArray()
	pleine.resize(250 * 81)
	pleine.fill(1)
	var c := Territoire.new(Vector2i(250, 81), pleine)
	var debut := Time.get_ticks_usec()
	for i in range(360):
		c.tamponner(i % 6, Vector2i(rng.randi_range(0, 2000), rng.randi_range(0, 648)), 46)
	var ms := (Time.get_ticks_usec() - debut) / 1000.0
	_check(ms < 60.0, "360 tampons de 46 px (une seconde à 6 lions) coûtent %.1f ms au territoire (moins de 60 ms)" % ms)


func _tester_reseau() -> void:
	print("-- Réseau (poignée de main, attribution)")
	var reseau: Node = root.get_node("Reseau")  # autoload : jamais nommé (compilé avant lui)
	var api: SceneMultiplayer = root.multiplayer
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	_check(not reseau.en_ligne() and api.multiplayer_peer is OfflineMultiplayerPeer and api.is_server(),
		"hors réseau par défaut : pair hors ligne, ce poste est son propre hôte (le solo)")
	_check(not reseau.version.is_empty() and reseau.version == ProjectSettings.get_setting("application/config/version"),
		"la version présentée est celle du projet (%s)" % reseau.version)

	# Attribution : le plus petit index libre et la première couleur libre, chacun de son côté
	var occupes: Dictionary[int, Dictionary] = {}
	_check(reseau.premier_index_libre(occupes, 6) == 0 and reseau.premiere_couleur_libre(occupes) == palette[0],
		"partie vide : index 0 et première couleur")
	occupes[1] = {"index": 0, "couleur": palette[0], "pseudo": "Hôte"}
	occupes[77] = {"index": 2, "couleur": palette[1], "pseudo": "B"}
	_check(reseau.premier_index_libre(occupes, 6) == 1 and reseau.premiere_couleur_libre(occupes) == palette[2],
		"après un départ : l'index 1 et la troisième couleur sont les premiers libres (index et couleur indépendants)")
	_check(reseau.premier_index_libre(occupes, 2) == 1 and reseau.premier_index_libre(occupes, 1) == -1,
		"les places bornent les index : 1 est libre sur 2 places, rien sur 1")
	occupes[78] = {"index": 1, "couleur": palette[2], "pseudo": "C"}
	for i in range(3, EtatPartie.NB_JOUEURS_MAX):
		occupes[100 + i] = {"index": i, "couleur": palette[i], "pseudo": ""}
	_check(occupes.size() == EtatPartie.NB_JOUEURS_MAX and reseau.premier_index_libre(occupes, 9) == -1
		and reseau.premiere_couleur_libre(occupes) == Color.TRANSPARENT,
		"à %d joueurs, plus d'index ni de couleur, même si l'on demande plus de places" % EtatPartie.NB_JOUEURS_MAX)
	_check(reseau.pseudo_valide("  Léa\n\t ") == "Léa" and reseau.pseudo_valide("Zoé la grande dompteuse") == "Zoé la grand"
		and reseau.pseudo_valide("Zoé la grande dompteuse").length() == reseau.PSEUDO_MAX,
		"le pseudo est nettoyé (contrôles, espaces) et coupé à %d caractères" % reseau.PSEUDO_MAX)
	var brut := "a" + char(0x007F) + "b" + char(0x009C) + "c" + char(0x200B) + "d" + char(0x202E) \
		+ "e" + char(0x2028) + "f" + char(0xFEFF) + "g"
	_check(reseau.pseudo_valide(brut) == "abcdefg",
		"le pseudo est aussi nettoyé du DEL, des contrôles C1, des forçages de sens et des caractères invisibles")
	_check(reseau.pseudo_valide("abcdefghijk lmn") == "abcdefghijk",
		"la coupe à %d caractères ne laisse pas d'espace finale (nettoyage après la coupe)" % reseau.PSEUDO_MAX)
	_check(reseau.pseudo_valide("   \n\t  ") == "", "un pseudo qui ne contient rien d'affichable devient une chaîne vide")
	_check(reseau.pseudo_ou_defaut("   ", 3) == "Joueur 4" and reseau.pseudo_ou_defaut("Zita", 3) == "Zita",
		"un pseudo vide après nettoyage retombe sur « Joueur N » (N = index + 1) ; un pseudo valable reste inchangé")

	# Décision de l'hôte sur une demande
	var version: String = reseau.version
	var places: int = reseau.places
	var demande := {"jeu": reseau.JEU, "version": version, "pseudo": "  Zoé la grande dompteuse "}
	reseau.inscrits[1] = {"index": 0, "couleur": palette[0], "pseudo": "Hôte"}
	var r: Dictionary = reseau.examiner_demande(demande)
	_check(r.accepte and r.index == 1 and r.couleur == palette[1] and r.pseudo == "Zoé la grand",
		"demande valable : acceptée avec l'index 1, la deuxième couleur et le pseudo nettoyé (%s)" % [r])
	_check(reseau.inscrits.size() == 1, "examiner une demande n'inscrit personne")
	var autre_version := demande.duplicate()
	autre_version.version = "0.0-ancienne"
	r = reseau.examiner_demande(autre_version)
	_check(not r.accepte and r.raison == reseau.REFUS_VERSION and r.version_hote == version,
		"version différente : refusée, avec la version de l'hôte pour le message (%s)" % [r])
	reseau.manche_en_cours = true
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_MANCHE, "manche en cours : refusée")
	_check(reseau.examiner_demande(autre_version).raison == reseau.REFUS_VERSION,
		"une version différente se dit avant tout autre refus (le joueur sait quoi mettre à jour)")
	reseau.manche_en_cours = false
	reseau.places = 2
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "B"}
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_PLEIN, "partie pleine (2 places sur 2) : refusée")
	reseau.places = places
	for i in range(2, EtatPartie.NB_JOUEURS_MAX):
		reseau.inscrits[10 + i] = {"index": i, "couleur": palette[i], "pseudo": ""}
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_PLEIN,
		"partie pleine à %d joueurs : refusée" % EtatPartie.NB_JOUEURS_MAX)
	reseau.inscrits.clear()
	var mal_formees: Array = [null, 42, "LELION", {}, {"jeu": "AUTRE", "version": version, "pseudo": "x"},
		{"jeu": reseau.JEU, "version": 11, "pseudo": "x"}, {"jeu": reseau.JEU, "version": version},
		{"jeu": reseau.JEU, "version": version, "pseudo": ["x"]}]
	var refus_demande := mal_formees.all(func(d: Variant) -> bool:
		var reponse: Dictionary = reseau.examiner_demande(d)
		return not reponse.accepte and reponse.raison == reseau.REFUS_DEMANDE)
	_check(refus_demande, "une demande mal formée ou d'un autre programme est refusée, sans erreur")
	var demande_vide := {"jeu": reseau.JEU, "version": version, "pseudo": "   "}
	var r_vide: Dictionary = reseau.examiner_demande(demande_vide)
	_check(r_vide.accepte and r_vide.pseudo == "Joueur %d" % (r_vide.index + 1),
		"un pseudo vide après nettoyage est accepté avec un repli « Joueur N » (%s)" % [r_vide])

	# Taille de la poignée de main avant décodage : bytes_to_var ne doit rien coûter pour un envoi
	# trop gros (M2), quel qu'en soit le contenu.
	var petite := var_to_bytes(demande)
	_check(reseau.decoder_poignee_de_main(petite) == demande,
		"une poignée de main de taille normale (%d octets) se décode normalement" % petite.size())
	var enorme := PackedByteArray()
	enorme.resize(reseau.TAILLE_POIGNEE_DE_MAIN_MAX + 1)
	_check(reseau.decoder_poignee_de_main(enorme) == null,
		"une poignée de main de plus de %d octets n'est pas décodée" % reseau.TAILLE_POIGNEE_DE_MAIN_MAX)

	# Départs vus par l'hôte
	var partis: Array[int] = []
	var sur_depart := func(id: int) -> void: partis.append(id)
	reseau.joueur_parti.connect(sur_depart)
	reseau.inscrits[42] = {"index": 1, "couleur": palette[1], "pseudo": "Fantôme"}
	reseau._sur_echec_poignee_de_main(42)
	_check(not reseau.inscrits.has(42) and partis.is_empty(),
		"un accepté qui ne finit pas sa poignée de main libère sa place, sans être signalé comme parti")
	reseau.inscrits[43] = {"index": 1, "couleur": palette[1], "pseudo": "B"}
	reseau._sur_pair_deconnecte(43)
	reseau._sur_pair_deconnecte(99)
	_check(not reseau.inscrits.has(43) and partis == [43], "un inscrit qui part est signalé une fois ; un inconnu, jamais (%s)" % [partis])
	reseau.joueur_parti.disconnect(sur_depart)

	# Hébergement : port occupé, puis libre, puis retour hors réseau
	var port := 17790
	var occupant := ENetMultiplayerPeer.new()
	_check(occupant.create_server(port) == OK, "un autre programme occupe le port %d" % port)
	var erreur: int = reseau.heberger(port)
	_check(erreur != OK and not reseau.en_ligne() and api.is_server() and reseau.inscrits.is_empty(),
		"port occupé : heberger renvoie l'erreur (%d) et le poste reste hors réseau" % erreur)
	occupant.close()
	reseau.pseudo = "Hôte"
	_check(reseau.heberger(port) == OK and reseau.en_ligne() and api.is_server() and reseau.inscrits.size() == 1
		and reseau.index_local == 0 and reseau.couleur_locale == palette[0] and reseau.inscrits[1].pseudo == "Hôte",
		"port libre : l'hôte écoute et s'inscrit lui-même (index 0, première couleur, son pseudo)")
	reseau.quitter()
	_check(not reseau.en_ligne() and api.multiplayer_peer is OfflineMultiplayerPeer and api.is_server()
		and reseau.inscrits.is_empty() and reseau.index_local == -1 and api.auth_callback.is_null(),
		"quitter revient hors réseau : pair hors ligne, hôte de soi-même, plus d'inscrits ni de poignée de main")

	# places est bornée à l'hébergement (N3) : sinon un hôte à 0 place ne trouverait pas d'index
	reseau.places = 0
	_check(reseau.heberger(port) == OK and reseau.places == 2 and reseau.index_local == 0,
		"places <= 0 est bornée à 2 par heberger() : l'hôte trouve tout de même son index")
	reseau.quitter()
	reseau.places = EtatPartie.NB_JOUEURS_MAX + 5
	_check(reseau.heberger(port) == OK and reseau.places == EtatPartie.NB_JOUEURS_MAX,
		"places au-delà de NB_JOUEURS_MAX est bornée à NB_JOUEURS_MAX par heberger()")
	reseau.quitter()
	reseau.places = places
	reseau.manche_en_cours = true
	reseau.quitter()
	_check(not reseau.manche_en_cours and reseau.examiner_demande(demande).accepte,
		"quitter() remet manche_en_cours à faux : un hôte relancé après une manche quittée accepte de nouveau")

	# Pseudo vide à l'hébergement : l'hôte s'inscrit lui-même avec le repli « Joueur 1 »
	reseau.pseudo = ""
	_check(reseau.heberger(port) == OK and reseau.inscrits[1].pseudo == "Joueur 1",
		"un hôte au pseudo vide s'inscrit lui-même avec le repli « Joueur 1 »")

	# Fermeture différée obsolète (M5) : si une nouvelle session commence avant qu'un appel différé
	# de _decider ne s'exécute, il ne doit ni la fermer, ni émettre son signal périmé.
	reseau.pseudo = "Hôte"
	reseau.heberger(port)
	var generation_perimee: int = reseau._generation
	var refus_recu := false
	var sur_refus_perime := func(_r: String, _v: String) -> void: refus_recu = true
	reseau.refuse.connect(sur_refus_perime)
	reseau.quitter()
	reseau.heberger(port)  # une nouvelle session a démarré entre-temps : sa génération a changé
	_check(reseau._generation != generation_perimee, "la génération change à chaque quitter() (donc à chaque nouvelle session)")
	reseau._fermer_puis_emettre("refuse", ["x", "y"], generation_perimee)
	_check(not refus_recu and reseau.en_ligne() and reseau.inscrits.size() == 1,
		"une fermeture différée obsolète (génération périmée) ne ferme pas la nouvelle session ni n'émet son signal")
	reseau.refuse.disconnect(sur_refus_perime)
	reseau.quitter()
	reseau.pseudo = ""


func _tester_joueur_local() -> void:
	print("-- Joueur local par identifiant réseau")
	var gs: Node = root.get_node("GameState")
	var son_pastille := Callable(root.get_node("Audio"), "_on_couleur_debloquee")
	var tableau: Array[Joueur] = gs.joueurs
	var solo: Joueur = gs.joueurs[0]
	_check(solo.id_reseau == MultiplayerPeer.TARGET_PEER_SERVER and gs.joueur_local() == solo and root.multiplayer.get_unique_id() == 1,
		"hors réseau, le joueur du solo porte l'identifiant de l'hôte (1), celui de ce poste : c'est le joueur local")
	_check(Joueur.new().id_reseau == Joueur.SANS_PAIR, "un nouveau joueur n'appartient à aucun poste")
	_check(solo.couleur_debloquee.is_connected(son_pastille), "Audio joue le son de pastille du joueur local")

	# N2 (revue phase 11 bis) : deux joueurs pour que le check discrimine vraiment le dernier
	# joueur local annoncé (celui de _init, ici relogé en case 1) d'un simple joueurs[0] (un décor
	# en case 0) — sans is_inside_tree() dans _id_reseau_local(), l'identifiant se perd et ce check
	# retomberait sur le décor.
	var hors_arbre := EtatPartie.new()
	var annonce_initiale := hors_arbre.joueurs[0]
	hors_arbre.joueurs.append(Joueur.new())
	hors_arbre.joueurs[0] = hors_arbre.joueurs[1]
	hors_arbre.joueurs[1] = annonce_initiale
	hors_arbre.joueurs[0].id_reseau = 5
	hors_arbre.joueurs[1].id_reseau = MultiplayerPeer.TARGET_PEER_SERVER
	_check(hors_arbre.joueur_local() == hors_arbre.joueurs[1],
		"un état de partie hors de l'arbre a pour joueur local le dernier annoncé, l'identifiant de l'hôte (1), pas forcément joueurs[0]")
	hors_arbre.free()

	# Bataille locale : les couleurs viennent de la palette, ou de l'appelant (le salon, phase 13)
	gs.configurer_bataille(3)
	_check(gs.joueur_local() == solo and gs.joueurs.slice(1).all(func(j: Joueur) -> bool: return j.id_reseau == Joueur.SANS_PAIR),
		"bataille locale : le joueur local reste le premier, les autres n'appartiennent à aucun poste")
	var choisies: Array[Color] = [EtatPartie.PALETTE_BATAILLE[4], EtatPartie.PALETTE_BATAILLE[0], EtatPartie.PALETTE_BATAILLE[2]]
	gs.configurer_bataille(3, choisies)
	_check(gs.joueurs.map(func(j: Joueur) -> Color: return j.couleur) == choisies
		and gs.joueurs.map(func(j: Joueur) -> int: return j.index) == [0, 1, 2],
		"configurer_bataille garde les couleurs qu'on lui donne (celles du salon), par index")

	# Un client : le sous-arbre de GameState reçoit un pair client ENet jamais connecté, dont
	# l'identifiant est tiré à sa création.
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 17791) == OK, "un pair client est créé")
	api.multiplayer_peer = pair
	set_multiplayer(api, gs.get_path())
	var client: Joueur = gs.joueurs[2]
	client.id_reseau = pair.get_unique_id()
	client.pseudo = "Client"
	var annonces: Array[Joueur] = []
	var sur_annonce := func(j: Joueur) -> void: annonces.append(j)
	gs.joueur_local_change.connect(sur_annonce)
	_check(client.id_reseau > 1 and gs.joueur_local() == client,
		"sur un client, le joueur local est celui qui porte l'identifiant du poste (%d), pas le premier" % client.id_reseau)
	gs.configurer_bataille(3)  # M3 : le salon le rappelle avant la manche (phase 13) ; l'annonce vient d'ici
	_check(annonces == [client] and client.couleur_debloquee.is_connected(son_pastille) and not solo.couleur_debloquee.is_connected(son_pastille),
		"configurer_bataille annonce le nouveau joueur local : Audio le suit et lâche l'ancien")
	gs.nouvelle_partie()
	_check(annonces.size() == 1, "le joueur local n'est annoncé qu'à son changement (configurer_bataille l'a déjà fait)")

	# Hôte perdu : le pair se ferme et le poste revient hors réseau AVANT le retour au titre
	pair.close()
	_check(gs.joueur_local() == client,
		"pair fermé (M1, revue phase 11 bis) : plus d'identifiant de client, le joueur local reste le dernier annoncé, pas celui de l'hôte")
	set_multiplayer(null, gs.get_path())
	gs.partie_en_cours = false
	gs.pret = false
	gs.configurer_solo()
	_check(gs.joueurs.size() == 1 and gs.joueurs[0] == client and is_same(tableau, gs.joueurs),
		"retour au solo : le joueur de ce poste pendant la partie passe en tête, dans le même tableau (%s)" % gs.joueurs[0].pseudo)
	_check(client.index == 0 and client.id_reseau == MultiplayerPeer.TARGET_PEER_SERVER and not client.a_une_couleur()
		and client.pseudo == "Client" and gs.joueur_local() == client,
		"… avec l'index 0, l'identifiant de l'hôte, sans couleur, son pseudo gardé : c'est le joueur local hors réseau")
	_check(annonces == [client] and client.couleur_debloquee.is_connected(son_pastille),
		"Audio écoute toujours ce joueur (aucune annonce de plus : il n'a pas changé)")
	gs.joueur_local_change.disconnect(sur_annonce)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false

	# Hôte en session : seul l'identifiant fait foi, même si le salon a donné à un autre poste
	# l'objet du dernier joueur local annoncé (ici `client`, en tête depuis le retour au solo).
	var api_hote := SceneMultiplayer.new()
	var pair_hote := ENetMultiplayerPeer.new()
	_check(pair_hote.create_server(17792) == OK, "un pair hôte est créé")
	api_hote.multiplayer_peer = pair_hote
	set_multiplayer(api_hote, gs.get_path())
	gs.joueurs.resize(2)
	gs.joueurs[1] = Joueur.new()
	client.id_reseau = 7
	gs.joueurs[1].id_reseau = MultiplayerPeer.TARGET_PEER_SERVER
	_check(gs.joueur_local() == gs.joueurs[1],
		"hôte en session : le joueur local est celui de l'identifiant 1, pas l'ancien objet donné à un autre poste")
	pair_hote.close()
	set_multiplayer(null, gs.get_path())
	client.id_reseau = MultiplayerPeer.TARGET_PEER_SERVER
	gs.joueurs.resize(1)
	gs.configurer_solo()
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


func _tester_palette() -> void:
	print("-- Palette de bataille (deutéranopie)")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var normales: Array[Vector3] = []
	var deuteranopes: Array[Vector3] = []
	for c in palette:
		var lineaire := c.srgb_to_linear()
		normales.append(_oklab(Vector3(lineaire.r, lineaire.g, lineaire.b)))
		deuteranopes.append(_oklab(_deuteranopie(Vector3(lineaire.r, lineaire.g, lineaire.b))))
	var min_normale := INF
	var min_deuteranope := INF
	for i in range(palette.size()):
		for k in range(i + 1, palette.size()):
			min_normale = minf(min_normale, normales[i].distance_to(normales[k]))
			min_deuteranope = minf(min_deuteranope, deuteranopes[i].distance_to(deuteranopes[k]))
	_check(palette.size() == EtatPartie.NB_JOUEURS_MAX and palette.all(func(c: Color) -> bool: return c.a == 1.0),
		"une couleur opaque par joueur possible")
	_check(normales.all(func(v: Vector3) -> bool: return v.x >= 0.5), "chaque couleur reste claire (OKLab L >= 0,5) : lisible sur le haut du ciel, bleu nuit")
	_check(min_normale >= 0.2, "deux couleurs se distinguent nettement (écart OKLab minimal %.3f, au moins 0,2)" % min_normale)
	_check(min_deuteranope >= 0.18,
		"en deutéranopie simulée aussi (écart OKLab minimal %.3f, au moins 0,18 ; 0,115 pour la planche de la phase 7)" % min_deuteranope)

	# M2 (revue finale phase 11 bis) : la ville se peint dans les trois nuances de chaque joueur
	# (foncée, pure, claire), pas seulement la couleur pure — c'est là que des joueurs différents se
	# rapprochent le plus en deutéranopie (magenta pur ≈ cyan foncé, rouge ≈ vert foncé, etc.).
	var moyennes_nuances: Array[Vector3] = []
	for c in palette:
		var somme := Vector3.ZERO
		for nuance in [c.darkened(Joueur.ECART_NUANCES), c, c.lightened(Joueur.ECART_NUANCES)]:
			var lineaire_n: Color = nuance.srgb_to_linear()
			somme += _oklab(_deuteranopie(Vector3(lineaire_n.r, lineaire_n.g, lineaire_n.b)))
		moyennes_nuances.append(somme / 3.0)
	var min_nuances := INF
	for i in range(palette.size()):
		for k in range(i + 1, palette.size()):
			min_nuances = minf(min_nuances, moyennes_nuances[i].distance_to(moyennes_nuances[k]))
	_check(min_nuances >= 0.14,
		"les nuances moyennes de deux joueurs se distinguent aussi en deutéranopie (écart OKLab minimal %.3f, au moins 0,14 ; 0,098 pour la planche de la phase 7)" % min_nuances)


## Deutéranopie simulée (Machado 2009, sévérité 1), en RVB linéaire.
func _deuteranopie(l: Vector3) -> Vector3:
	return Vector3(
		0.367322 * l.x + 0.860646 * l.y - 0.227968 * l.z,
		0.280085 * l.x + 0.672501 * l.y + 0.047413 * l.z,
		-0.011820 * l.x + 0.042940 * l.y + 0.968881 * l.z).clamp(Vector3.ZERO, Vector3.ONE)


## OKLab (Ottosson 2020) d'une couleur en RVB linéaire : la distance entre deux couleurs y suit
## l'écart perçu.
func _oklab(l: Vector3) -> Vector3:
	var lms := Vector3(
		0.4122214708 * l.x + 0.5363325363 * l.y + 0.0514459929 * l.z,
		0.2119034982 * l.x + 0.6806995451 * l.y + 0.1073969566 * l.z,
		0.0883024619 * l.x + 0.2817188376 * l.y + 0.6299787005 * l.z)
	var r := Vector3(pow(lms.x, 1.0 / 3.0), pow(lms.y, 1.0 / 3.0), pow(lms.z, 1.0 / 3.0))
	return Vector3(
		0.2104542553 * r.x + 0.7936177850 * r.y - 0.0040720468 * r.z,
		1.9779984951 * r.x - 2.4285922050 * r.y + 0.4505937099 * r.z,
		0.0259040371 * r.x + 0.7827717662 * r.y - 0.8086757660 * r.z)


func _tester_decouverte() -> void:
	print("-- Découverte (balise, liste des parties, adresse saisie)")
	var decouverte: Node = root.get_node("Decouverte")  # autoload : jamais nommé (compilé avant lui)
	var reseau: Node = root.get_node("Reseau")
	var version: String = reseau.version

	# Balise : un texte, le pseudo (seul texte libre) en dernier, relu tel quel
	var balise: PackedByteArray = decouverte.encoder_balise(version, 7777, 2, 6, false, 1, "Zoé|la|reine")
	_check(balise.get_string_from_utf8() == "LELION|%s|7777|2|6|0|1|Zoé|la|reine" % version,
		"la balise est « LELION|version|port|joueurs|places|manche|niveau|pseudo » (%s)" % balise.get_string_from_utf8())
	var fiche: Dictionary = decouverte.decoder_balise(balise)
	_check(fiche == {"version": version, "port": 7777, "nb_joueurs": 2, "places": 6, "manche_en_cours": false, "niveau": 1, "pseudo": "Zoé|la|reine"},
		"une balise se relit telle quelle, même avec des « | » dans le pseudo (%s)" % [fiche])
	var pleine: Dictionary = decouverte.decoder_balise(decouverte.encoder_balise(version, 17778, 6, 6, true, 2, "   "))
	_check(pleine.get("manche_en_cours") == true and pleine.get("nb_joueurs") == 6 and pleine.get("pseudo") == "Joueur 1",
		"manche en cours et partie pleine se relisent ; un pseudo vide devient « Joueur 1 » (l'hôte)")
	var hostile := "\u202eAbc\u0007defghijklmnopq"
	_check(decouverte.decoder_balise(decouverte.encoder_balise(version, 7777, 1, 6, false, 0, hostile)).get("pseudo") == reseau.pseudo_valide(hostile),
		"le pseudo d'une balise est nettoyé comme celui d'un joueur (forçages de sens, contrôles, %d caractères)" % reseau.PSEUDO_MAX)

	# Tout ce qui n'est pas une balise valide est ignoré (autre programme, balise tronquée ou forgée)
	var trop_longue := PackedByteArray()
	trop_longue.resize(decouverte.TAILLE_BALISE_MAX + 1)
	trop_longue.fill(65)
	# Préfixe corrompu (premier octet), mais assez long pour comparer les 7 premiers : rejeté sur les
	# octets, jamais passé à get_string_from_utf8() (Minor 2 : pas de ligne ERROR pour ce genre de
	# datagramme, mesuré au scénario 6 du test réseau).
	var prefixe_corrompu := PackedByteArray([0xFF, 69, 76, 73, 79, 78, 124, 65, 66])
	var invalides: Array[PackedByteArray] = [PackedByteArray(), trop_longue, prefixe_corrompu]
	for texte: String in ["LELION", "AUTRE|0.11|7777|1|6|0|0|x", "LELION|0.11|7777|1|6|0|0",
			"LELION|0.11|0|1|6|0|0|x", "LELION|0.11|65536|1|6|0|0|x", "LELION|0.11|port|1|6|0|0|x",
			"LELION|0.11|7777|0|6|0|0|x", "LELION|0.11|7777|7|6|0|0|x", "LELION|0.11|7777|1|1|0|0|x",
			"LELION|0.11|7777|3|2|0|0|x", "LELION|0.11|7777|1|7|0|0|x", "LELION|0.11|7777|1|6|2|0|x",
			"LELION|0.11|7777|1|6|0|-1|x", "LELION|0.11|7777|1|6|0|%d|x" % EtatPartie.NIVEAUX.size(),
			"LELION||7777|1|6|0|0|x", "LELION|0.11 beta|7777|1|6|0|0|x", "LELION|0123456789abcdefg|7777|1|6|0|0|x",
			# Champ numérique hors de l'int64 (Minor 2) : rejeté sur sa longueur, jamais passé à to_int().
			"LELION|0.11|999999999999999999999|1|6|0|0|x"]:
		invalides.append(texte.to_utf8_buffer())
	var acceptees := invalides.filter(func(d: PackedByteArray) -> bool: return not decouverte.decoder_balise(d).is_empty())
	_check(acceptees.is_empty(), "%d datagrammes invalides, aucun pris pour une balise, dont un préfixe étranger invalide en UTF-8 et un entier hors int64 (%s)"
		% [invalides.size(), acceptees.map(func(d: PackedByteArray) -> String: return d.get_string_from_utf8())])

	# La liste : une partie par adresse et port de jeu, rafraîchie, changée, expirée, plafonnée
	var liste: Dictionary[String, Dictionary] = {}
	_check(decouverte.enregistrer_partie(liste, "192.168.1.20", fiche, 1000) and liste.size() == 1
		and liste["192.168.1.20:7777"].ip == "192.168.1.20" and liste["192.168.1.20:7777"].vue_a == 1000,
		"une partie nouvelle entre dans la liste, avec son adresse et l'heure de sa balise")
	_check(not decouverte.enregistrer_partie(liste, "192.168.1.20", fiche, 1900) and liste["192.168.1.20:7777"].vue_a == 1900,
		"la même balise répétée rafraîchit l'heure sans changer la liste affichée")
	var arrivee := fiche.duplicate()
	arrivee["nb_joueurs"] = 3
	_check(decouverte.enregistrer_partie(liste, "192.168.1.20", arrivee, 2500) and liste["192.168.1.20:7777"].nb_joueurs == 3,
		"une balise différente (un joueur de plus) change la liste")
	_check(decouverte.enregistrer_partie(liste, "192.168.1.21", fiche, 2500) and liste.size() == 2,
		"même port de jeu, autre adresse : une autre partie")
	_check(not decouverte.purger_parties(liste, 5500, 3000) and liste.size() == 2, "une partie vue il y a 3 s pile reste")
	_check(decouverte.purger_parties(liste, 5501, 3000) and liste.is_empty(), "sans balise depuis plus de 3 s, les parties disparaissent")
	for i in range(decouverte.PARTIES_MAX):
		decouverte.enregistrer_partie(liste, "10.0.0.%d" % (i + 1), fiche, 0)
	_check(not decouverte.enregistrer_partie(liste, "10.0.1.1", fiche, 0) and liste.size() == decouverte.PARTIES_MAX
		and not decouverte.enregistrer_partie(liste, "10.0.0.1", fiche, 10) and liste["10.0.0.1:7777"].vue_a == 10,
		"liste pleine (%d parties) : une nouvelle est ignorée, les connues se rafraîchissent encore" % decouverte.PARTIES_MAX)

	# Destinations de la balise : tous les réseaux privés, dans l'ordre reçu (jamais triés, jamais
	# privés de 169.254 : Minor 6, destinations_balise n'en dépend pas)
	var adresses := PackedStringArray(["fe80:0:0:0:0:0:0:1", "127.0.0.1", "192.168.1.17", "10.0.3.4", "172.20.1.2",
		"172.32.0.1", "8.8.8.8", "169.254.10.20", "192.168.1.30"])
	_check(decouverte.destinations_balise(adresses) == PackedStringArray(["255.255.255.255", "192.168.1.255", "10.0.3.255", "172.20.1.255", "169.254.255.255"]),
		"la balise part en diffusion limitée et dirigée, une fois par réseau privé (%s)" % decouverte.destinations_balise(adresses))
	_check(decouverte.destinations_balise(PackedStringArray()) == PackedStringArray(["255.255.255.255"]),
		"sans adresse privée connue, la diffusion limitée seule")

	# Adresses de l'hôte à afficher (Minor 6) : IPv4 privées seulement, mais triées pour la lecture à
	# voix haute — 192.168/16 réel d'abord (hors 192.168.56/24, VirtualBox Host-Only), puis 10/8, puis
	# 172.16/12 (souvent une carte virtuelle sous Windows, 192.168.56/24 avec elle), 169.254 en tout
	# dernier recours (jamais si une autre adresse existe)
	var adresses_tri := PackedStringArray(["fe80:0:0:0:0:0:0:1", "127.0.0.1", "172.20.1.2", "10.0.3.4",
		"172.32.0.1", "8.8.8.8", "192.168.56.1", "192.168.1.17", "169.254.10.20", "192.168.1.30"])
	_check(decouverte.adresses_privees(adresses_tri) == PackedStringArray(["192.168.1.17", "192.168.1.30", "10.0.3.4", "172.20.1.2", "192.168.56.1"]),
		"les adresses de l'hôte à afficher, filtrées (IPv4 privées, IPv6/loopback/publique/hors-plage exclues) puis triées : cartes réelles d'abord, virtuelles ensuite, 169.254 tue si une autre existe (%s)"
			% decouverte.adresses_privees(adresses_tri))
	_check(decouverte.adresses_privees(PackedStringArray(["169.254.10.20", "169.254.1.2", "8.8.8.8"])) == PackedStringArray(["169.254.10.20", "169.254.1.2"]),
		"169.254 s'affiche s'il n'y a vraiment rien d'autre à lire")

	# I1 (revue finale 12 bis) : adresses de l'hôte triées par interface (physique d'abord, virtuelle
	# en dernier recours), à rang IPv4 égal — IP.get_local_interfaces() donne {name, friendly, index,
	# addresses}, friendly == name sur ce Mac et sur Linux
	var mac := [
		{"name": "en0", "friendly": "en0", "index": 4, "addresses": PackedStringArray(["192.168.1.17"])},
		{"name": "bridge100", "friendly": "bridge100", "index": 12, "addresses": PackedStringArray(["192.168.139.3"])},
		{"name": "bridge101", "friendly": "bridge101", "index": 13, "addresses": PackedStringArray(["192.168.215.0"])},
	]
	_check(decouverte.adresses_hote(mac) == PackedStringArray(["192.168.1.17"]),
		"sur ce Mac, en0 (physique) passe devant les bridges virtuels, même si les trois sont en 192.168/16 (%s)"
			% decouverte.adresses_hote(mac))
	var windows := [
		{"name": "{GUID-WIFI}", "friendly": "Wi-Fi", "index": 12, "addresses": PackedStringArray(["192.168.1.23"])},
		{"name": "{GUID-WSL}", "friendly": "vEthernet (WSL)", "index": 45, "addresses": PackedStringArray(["172.29.144.1"])},
		{"name": "{GUID-VMWARE}", "friendly": "VMware Network Adapter VMnet8", "index": 22, "addresses": PackedStringArray(["192.168.47.1"])},
		{"name": "{GUID-VBOX}", "friendly": "VirtualBox Host-Only Network", "index": 30, "addresses": PackedStringArray(["192.168.56.1"])},
	]
	_check(decouverte.adresses_hote(windows) == PackedStringArray(["192.168.1.23"]),
		"sous Windows, le Wi-Fi passe devant vEthernet (WSL), VMware et VirtualBox, même rang IPv4 privé (%s)"
			% decouverte.adresses_hote(windows))
	var inconnue := [
		{"name": "{GUID-LAN}", "friendly": "Connexion au réseau local", "index": 8, "addresses": PackedStringArray(["10.0.0.5"])},
		{"name": "{GUID-WSL2}", "friendly": "vEthernet (WSL)", "index": 50, "addresses": PackedStringArray(["172.20.0.1"])},
	]
	_check(decouverte.adresses_hote(inconnue) == PackedStringArray(["10.0.0.5"]),
		"un nom d'interface non reconnu (ancien Windows localisé) passe quand même devant une carte virtuelle identifiée (%s)"
			% decouverte.adresses_hote(inconnue))
	var tout_virtuel := [
		{"name": "vEthernet (WSL)", "friendly": "vEthernet (WSL)", "index": 50, "addresses": PackedStringArray(["172.20.0.1"])},
		{"name": "VirtualBox Host-Only Network", "friendly": "VirtualBox Host-Only Network", "index": 30, "addresses": PackedStringArray(["192.168.56.1"])},
	]
	_check(decouverte.adresses_hote(tout_virtuel) == PackedStringArray(["172.20.0.1", "192.168.56.1"]),
		"si tout est virtuel, la liste sort quand même (dernier recours), dans l'ordre de rang IPv4 existant (%s)"
			% decouverte.adresses_hote(tout_virtuel))
	_check(decouverte.adresses_hote([]).is_empty(), "aucune interface : aucune adresse à lire")

	# Adresse saisie : IPv4 seulement, normalisée ; jamais un nom (résolution bloquante)
	var valides := {"192.168.1.20": "192.168.1.20", " 192.168.001.010 ": "192.168.1.10", "127.0.0.1": "127.0.0.1", "10.0.0.255": "10.0.0.255"}
	_check(valides.keys().all(func(t: String) -> bool: return decouverte.adresse_ipv4(t) == valides[t]),
		"une adresse IPv4 saisie est acceptée, sans zéros ni espaces superflus")
	var refusees := ["", "192.168.1", "192.168.1.256", "192.168.1.2.3", "localhost", "lelion.local", "::1", "0.1.2.3",
		"224.0.0.1", "255.255.255.255", "1.2.3.-4", "1.2.3.+4", "1.2.3.4a", "1..3.4", "1234.1.1.1", "１.２.３.４"]
	var passees := refusees.filter(func(t: String) -> bool: return not decouverte.adresse_ipv4(t).is_empty())
	_check(passees.is_empty(), "noms d'hôte, IPv6, adresses incomplètes, hors plage ou de diffusion refusés (%s)" % [passees])

	# Écoute : un port libre, puis déjà pris (deux LeLion sur un même PC) : une erreur, jamais un plantage
	var port_balise := 17891
	decouverte.port_balise = port_balise
	_check(decouverte.ecouter() == OK and decouverte.ecoute_active() and decouverte.erreur_ecoute == OK, "l'écoute s'ouvre sur un port libre")
	var intrus := PacketPeerUDP.new()
	_check(intrus.bind(port_balise, "0.0.0.0") != OK, "(pré-condition) l'écoute tient son port : un autre ne peut pas l'ouvrir")
	var signaux := [0]
	var compter := func() -> void: signaux[0] += 1
	decouverte.parties_changees.connect(compter)
	decouverte.parties["10.0.0.9:7777"] = fiche.merged({"ip": "10.0.0.9", "vue_a": 0})
	decouverte.arreter_ecoute()
	_check(not decouverte.ecoute_active() and decouverte.parties.is_empty() and signaux[0] == 1,
		"arrêter l'écoute ferme le port et vide la liste, signalé une fois")
	decouverte.arreter_ecoute()
	_check(signaux[0] == 1, "arrêter une écoute déjà arrêtée ne signale rien")
	_check(intrus.bind(port_balise, "0.0.0.0") == OK, "le port d'écoute est rendu à la fermeture")
	var erreur: int = decouverte.ecouter()
	_check(erreur != OK and not decouverte.ecoute_active() and decouverte.erreur_ecoute == erreur,
		"port déjà pris : ecouter() renvoie l'erreur (%d) sans planter ni écouter" % erreur)

	# Nouvel essai périodique (Minor 5, appelé en vrai jeu par la minuterie) : le port libéré profite
	# à l'écoute qui le voulait encore, sans repasser par ecouter() ni revenir à l'accueil
	intrus.close()
	signaux[0] = 0
	decouverte._reessayer_ecoute()
	_check(decouverte.ecoute_active() and decouverte.erreur_ecoute == OK and signaux[0] == 1,
		"le port libéré par un autre poste profite au prochain essai (deux fenêtres sur un même PC), signalé")
	decouverte._reessayer_ecoute()
	_check(signaux[0] == 1, "un nouvel essai alors que l'écoute est déjà ouverte ne fait rien de plus")
	decouverte.arreter_ecoute()
	signaux[0] = 0
	decouverte._reessayer_ecoute()
	_check(not decouverte.ecoute_active() and signaux[0] == 0, "un nouvel essai ne fait rien si l'écoute n'est plus voulue (arreter_ecoute() l'a annulée)")
	decouverte.parties_changees.disconnect(compter)

	# Balise de l'hôte : ce qu'émet `Reseau` en ligne et hôte, rien hors réseau ni chez un client
	var recepteur := PacketPeerUDP.new()
	_check(recepteur.bind(port_balise, "0.0.0.0") == OK, "(pré-condition) un récepteur écoute les balises de test")
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	var gs: Node = root.get_node("GameState")
	gs.niveau_courant = 2
	decouverte._emettre_balise()
	_check(_datagrammes_recus(recepteur).is_empty() and decouverte._emetteur == null, "hors réseau (le solo), aucune balise")
	reseau.pseudo = "Zoé"
	reseau.places = 4
	var port_jeu := 17792
	_check(reseau.heberger(port_jeu) == OK, "(pré-condition) ce poste héberge sur le port %d" % port_jeu)
	reseau.manche_en_cours = true
	decouverte._emettre_balise()
	var recus := _datagrammes_recus(recepteur)
	var recue: Dictionary = decouverte.decoder_balise(recus[0]) if recus.size() == 1 else {}
	_check(recue == {"version": version, "port": port_jeu, "nb_joueurs": 1, "places": 4, "manche_en_cours": true, "niveau": 2, "pseudo": "Zoé"},
		"l'hôte émet une balise : version, port de jeu, joueurs inscrits, places, manche, niveau, pseudo (%s)" % [recue])
	reseau.quitter()
	decouverte._emettre_balise()
	_check(_datagrammes_recus(recepteur).is_empty() and decouverte._emetteur == null, "après quitter(), la balise s'arrête et sa socket se ferme")
	_check(reseau.rejoindre("127.0.0.1", port_jeu + 1) == OK and not root.multiplayer.is_server(), "(pré-condition) ce poste est un client qui attend son hôte")
	decouverte._emettre_balise()
	_check(_datagrammes_recus(recepteur).is_empty(), "un client n'émet aucune balise")
	reseau.quitter()
	recepteur.close()
	reseau.pseudo = ""
	reseau.places = EtatPartie.NB_JOUEURS_MAX
	gs.niveau_courant = 0
	decouverte.destinations_forcees = PackedStringArray()
	decouverte.port_balise = decouverte.PORT_BALISE


## Les datagrammes arrivés sur `recepteur` dans les 0,3 s, quels qu'ils soient (valides ou non :
## « aucune balise » veut dire aucun datagramme). Attente active et bornée : sur localhost, un
## datagramme émis est déjà là ou presque ; 0,3 s de silence suffit à conclure qu'il n'y en a pas.
func _datagrammes_recus(recepteur: PacketPeerUDP) -> Array[PackedByteArray]:
	var recus: Array[PackedByteArray] = []
	var fin := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < fin:
		while recepteur.get_available_packet_count() > 0:
			recus.append(recepteur.get_packet())
		OS.delay_msec(5)
	return recus


## Phase 13 : la bataille configurée par les fiches du salon (`configurer_bataille_reseau`), les
## couleurs corrigées (M4) et le nombre de joueurs ramené dans ses bornes.
func _tester_bataille_reseau() -> void:
	print("-- Bataille en réseau (fiches du salon, couleurs, nombre de joueurs)")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	_check(EtatPartie.couleurs_de_bataille(3, []) == palette.slice(0, 3), "sans couleurs données : la palette dans l'ordre")
	var donnees: Array[Color] = [palette[4], palette[0]]
	_check(EtatPartie.couleurs_de_bataille(4, donnees) == [palette[4], palette[0], palette[1], palette[2]],
		"trop peu de couleurs : les manquantes prennent les premières de la palette encore libres (plus de doublon)")
	var fautives: Array[Color] = [palette[2], Color.TRANSPARENT, palette[2], palette[5], palette[1]]
	_check(EtatPartie.couleurs_de_bataille(4, fautives) == [palette[2], palette[0], palette[1], palette[5]],
		"une couleur transparente ou en double est remplacée, celles en trop ignorées")
	var gs: Node = root.get_node("GameState")
	var tableau: Array[Joueur] = gs.joueurs
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 17794) == OK, "(pré-condition) un pair client, pour que ce poste ait son propre identifiant")
	api.multiplayer_peer = pair
	set_multiplayer(api, gs.get_path())
	var id_local := pair.get_unique_id()
	var annonces: Array[Joueur] = []
	var sur_annonce := func(j: Joueur) -> void: annonces.append(j)
	gs.joueur_local_change.connect(sur_annonce)
	var fiches_salon: Array[Dictionary] = [{"id_reseau": 1, "pseudo": "Hôte", "couleur": palette[4]},
		{"id_reseau": 7, "pseudo": "Bob", "couleur": palette[0]}, {"id_reseau": id_local, "pseudo": "Chloé", "couleur": palette[2]}]
	gs.configurer_bataille_reseau(fiches_salon)
	_check(gs.regles is ReglesBataille and is_same(tableau, gs.joueurs) and gs.joueurs.size() == 3
		and gs.joueurs.map(func(j: Joueur) -> int: return j.index) == [0, 1, 2],
		"configurer_bataille_reseau : règles de bataille, un joueur par fiche, dans le même tableau, index 0..2")
	_check(gs.joueurs.map(func(j: Joueur) -> int: return j.id_reseau) == [1, 7, id_local]
		and gs.joueurs.map(func(j: Joueur) -> String: return j.pseudo) == ["Hôte", "Bob", "Chloé"]
		and gs.joueurs.map(func(j: Joueur) -> Color: return j.couleur) == [palette[4], palette[0], palette[2]],
		"chaque index reçoit l'identifiant, le pseudo et la couleur de sa fiche, l'index 0 (l'hôte, 1) compris")
	_check(gs.joueur_local() == gs.joueurs[2] and annonces == [gs.joueurs[2]],
		"le joueur local est celui de ce poste (index 2), annoncé une seule fois, identifiants déjà posés")
	gs.joueur_local_change.disconnect(sur_annonce)
	pair.close()
	set_multiplayer(null, gs.get_path())
	gs.configurer_bataille(9)
	_check(gs.joueurs.size() == EtatPartie.NB_JOUEURS_MAX and gs.regles is ReglesBataille,
		"9 joueurs demandés : ramenés à %d avec une erreur signalée, sans planter (ligne ERROR attendue)" % EtatPartie.NB_JOUEURS_MAX)
	gs.configurer_solo()
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


## Phase 13 : la logique du salon dans `Reseau` (adresse de `rejoindre`, démarrage permis ou non,
## couleurs, index compactés, table diffusée et relue, lancement de la manche).
func _tester_salon() -> void:
	print("-- Salon (table, couleurs, démarrage de l'hôte, index compactés)")
	var reseau: Node = root.get_node("Reseau")  # autoload : jamais nommé (compilé avant lui)
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE

	# Adresse de rejoindre() : une IPv4 seulement, refusée sans rien changer sinon (M8)
	_check(reseau.rejoindre("lelion.local", 17793) == ERR_INVALID_PARAMETER and not reseau.en_ligne()
		and reseau.rejoindre("192.168.1", 17793) == ERR_INVALID_PARAMETER and reseau.rejoindre("::1", 17793) == ERR_INVALID_PARAMETER,
		"rejoindre() refuse un nom d'hôte, une adresse incomplète ou IPv6, sans rien tenter (aucune résolution bloquante)")
	_check(reseau.rejoindre(" 127.000.0.1 ", 17793) == OK and reseau.en_ligne() and not root.multiplayer.is_server(),
		"une IPv4 saisie avec des zéros et des espaces est normalisée et rejointe")
	_check(reseau.rejoindre("lelion.local", 17793) == ERR_INVALID_PARAMETER and reseau.en_ligne(),
		"une adresse refusée ne ferme pas la session en cours")
	reseau.quitter()

	# Démarrage permis : au moins deux joueurs arrivés, aucune place seulement réservée, tous prêts ;
	# sinon, la raison que voit l'hôte (et, sans les places réservées qu'ils ne voient pas, les clients)
	var hote := {"index": 0, "couleur": palette[0], "pseudo": "Hôte", "arrive": true, "pret": true}
	var occupes: Dictionary[int, Dictionary] = {1: hote.duplicate()}
	_check(not reseau.salon_pret(occupes) and reseau.raison_attente(occupes.values()) == reseau.ATTENTE_JOUEURS,
		"seul, l'hôte prêt ne peut pas démarrer : « il faut au moins 2 joueurs »")
	occupes[7] = {"index": 2, "couleur": palette[2], "pseudo": "Rita", "arrive": false, "pret": false}
	_check(reseau.raison_attente(occupes.values()) == reseau.ATTENTE_JOUEURS,
		"une place seulement réservée ne compte pas comme un deuxième joueur")
	occupes[5] = {"index": 1, "couleur": palette[1], "pseudo": "Bob", "arrive": true, "pret": true}
	_check(not reseau.salon_pret(occupes) and reseau.raison_attente(occupes.values()) == reseau.ATTENTE_ARRIVEE,
		"deux arrivés prêts, mais une place encore réservée (poignée de main en cours) : pas encore (son joueur arrivera non prêt)")
	occupes.erase(7)
	_check(reseau.salon_pret(occupes) and reseau.raison_attente(occupes.values()).is_empty(),
		"deux joueurs arrivés et prêts, aucune place réservée : l'hôte peut démarrer")
	occupes[5].pret = false
	_check(not reseau.salon_pret(occupes) and reseau.raison_attente(occupes.values()) == reseau.ATTENTE_PRETS,
		"l'un repasse non prêt : « tous les joueurs doivent être prêts »")
	occupes[5].pret = true
	var vue_client: Array[Dictionary] = reseau.table_de(occupes)
	_check(reseau.raison_attente(vue_client).is_empty() and reseau.raison_attente(vue_client.slice(0, 1)) == reseau.ATTENTE_JOUEURS,
		"la même règle sur la table d'un client (arrivés seulement) : l'hôte peut démarrer, ou pourquoi pas")

	# Couleur voisine libre : dans les deux sens, en boucle, places réservées comprises
	occupes[7] = {"index": 2, "couleur": palette[3], "pseudo": "Rita", "arrive": false, "pret": false}
	_check(reseau.couleur_voisine_libre(occupes, 1, 1) == palette[2] and reseau.couleur_voisine_libre(occupes, 5, 1) == palette[2],
		"suivante : la première libre après la sienne (%s)" % reseau.couleur_voisine_libre(occupes, 5, 1))
	_check(reseau.couleur_voisine_libre(occupes, 1, -1) == palette[5] and reseau.couleur_voisine_libre(occupes, 5, -1) == palette[5],
		"précédente : en boucle, en sautant les prises (celle d'une place réservée comprise)")
	var pleins: Dictionary[int, Dictionary] = {}
	for i in range(EtatPartie.NB_JOUEURS_MAX):
		pleins[10 + i] = {"index": i, "couleur": palette[i], "pseudo": "", "arrive": true, "pret": false}
	_check(reseau.couleur_voisine_libre(pleins, 12, 1) == palette[2] and reseau.couleur_voisine_libre(occupes, 99, 1) == Color.TRANSPARENT,
		"aucune couleur libre : la sienne ; un inconnu : aucune")

	# Index compactés : dans leur ordre, sur 0..n-1
	var troues: Dictionary[int, Dictionary] = {1: {"index": 0}, 9: {"index": 5}, 7: {"index": 2}}
	reseau.compacter_index(troues)
	_check(troues[1].index == 0 and troues[7].index == 1 and troues[9].index == 2, "des index troués (0, 2, 5) deviennent 0, 1, 2 dans leur ordre")
	reseau.compacter_index(troues)
	_check(troues[1].index == 0 and troues[7].index == 1 and troues[9].index == 2, "des index déjà compacts ne changent pas")

	# Table du salon : les arrivés seulement, triés par index
	var table: Array[Dictionary] = reseau.table_de(occupes)
	_check(table.map(func(f: Dictionary) -> int: return f.id) == [1, 5] and table[1] == {"id": 5, "index": 1, "couleur": palette[1], "pseudo": "Bob", "pret": true},
		"la table ne montre que les joueurs arrivés, triés par index, avec leur identifiant (M4 : jamais une carte fantôme)")

	# Lecture de la table reçue de l'hôte : tout ce qui n'est pas une table valide est refusé
	var recue: Array = [{"id": 5, "index": 1, "couleur": palette[1], "pseudo": " Bob" + char(0x202E) + " ", "pret": false},
		{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Hôte", "pret": true}]
	var lue: Array[Dictionary] = reseau.lire_table(recue)
	_check(lue.size() == 2 and lue[0].id == 1 and lue[1].pseudo == "Bob", "une table valide est relue triée, pseudos nettoyés (%s)" % [lue])
	var invalides: Array = ["x", [recue[0], recue[0]], [recue[0].merged({"id": 0}, true)], [recue[0].merged({"index": 6}, true)],
		[recue[0].merged({"couleur": Color(0.5, 0.5, 0.5)}, true)], [recue[0], recue[1].merged({"couleur": palette[1]}, true)],
		[recue[0], recue[1].merged({"index": 1}, true)], [recue[0].merged({"pret": 1}, true)], [{"id": 5}], [recue[0], recue[1], 3]]
	var trop: Array = []
	for i in range(EtatPartie.NB_JOUEURS_MAX + 1):
		trop.append({"id": i + 1, "index": i % 6, "couleur": palette[i % 6], "pseudo": "", "pret": false})
	invalides.append(trop)
	var passees := invalides.filter(func(t: Variant) -> bool: return not reseau.lire_table(t).is_empty())
	_check(passees.is_empty(), "%d tables mal formées refusées (types, identifiant nul, index hors plage, couleur hors palette, doublons, trop de joueurs) (%s)" % [invalides.size(), passees])

	# Fiches de la manche : une table compactée d'au moins deux joueurs, qui contient ce poste
	var compacte: Array[Dictionary] = reseau.lire_table([{"id": 1, "index": 0, "couleur": palette[4], "pseudo": "Hôte", "pret": true},
		{"id": 9, "index": 1, "couleur": palette[2], "pseudo": "Chloé", "pret": true}])
	var fiches: Array[Dictionary] = reseau.fiches_de_manche(compacte, 9)
	_check(fiches == [{"id_reseau": 1, "pseudo": "Hôte", "couleur": palette[4]}, {"id_reseau": 9, "pseudo": "Chloé", "couleur": palette[2]}],
		"les fiches de la manche : identifiant, pseudo et couleur de chaque index, dans l'ordre (%s)" % [fiches])
	var trouee: Array[Dictionary] = reseau.lire_table([compacte[0], compacte[1].merged({"index": 3}, true)])
	_check(reseau.fiches_de_manche(compacte, 42).is_empty() and reseau.fiches_de_manche(trouee, 9).is_empty()
		and reseau.fiches_de_manche(compacte.slice(0, 1), 1).is_empty(),
		"pas de manche pour un poste absent de la table, des index troués ou un seul joueur")

	# L'hôte : couleurs arbitrées une à une, Prêt, niveau, lancement (index compactés, manche en
	# cours)
	reseau.pseudo = "Hôte"
	_check(reseau.heberger(17793) == OK and reseau.inscrits[1].arrive and not reseau.inscrits[1].pret
		and reseau.table_salon.size() == 1 and reseau.table_salon[0].id == 1, "l'hôte s'inscrit arrivé, pas prêt, seul dans la table")
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "Bob", "arrive": false, "pret": false}
	reseau.inscrits[9] = {"index": 3, "couleur": palette[2], "pseudo": "Chloé", "arrive": false, "pret": false}
	_check(not reseau.changer_couleur(5, 1) and not reseau.definir_pret(5, true), "une place seulement réservée ne change ni de couleur ni d'état")
	var changements := [0]
	var compter_changements := func() -> void: changements[0] += 1
	reseau.salon_change.connect(compter_changements)
	reseau.inscrits[11] = {"index": 4, "couleur": palette[5], "pseudo": "Lent", "arrive": false, "pret": false}
	reseau._sur_echec_poignee_de_main(11)
	reseau._sur_echec_poignee_de_main(12)
	_check(changements[0] == 1 and not reseau.inscrits.has(11),
		"une place réservée qui se libère est signalée (le bouton Démarrer de l'hôte en dépend), un pair inconnu non")
	reseau.salon_change.disconnect(compter_changements)
	reseau._sur_pair_connecte(5)
	reseau._sur_pair_connecte(9)
	_check(reseau.table_salon.map(func(f: Dictionary) -> int: return f.index) == [0, 1, 3], "(pré-condition) un trou à l'index 2, laissé par un départ")
	_check(reseau.changer_couleur(5, 1) and reseau.inscrits[5].couleur == palette[3] and reseau.changer_couleur(9, 1) and reseau.inscrits[9].couleur == palette[4],
		"deux demandes pour la même couleur : la première l'obtient, la seconde passe à la suivante libre")
	var niveaux: Array[int] = []
	reseau.definir_niveau(2)
	niveaux.append(reseau.niveau_salon)
	reseau.definir_niveau(3)
	niveaux.append(reseau.niveau_salon)
	reseau.definir_niveau(-1)
	niveaux.append(reseau.niveau_salon)
	_check(niveaux == [2, 0, 2], "le niveau du salon reste dans la liste, en boucle (%s)" % [niveaux])
	var lancees: Array = []
	var sur_lancement := func(f: Array[Dictionary]) -> void: lancees.append(f)
	reseau.manche_lancee.connect(sur_lancement)
	for id in [1, 5]:
		reseau.definir_pret(id, true)
	_check(not reseau.lancer_manche() and lancees.is_empty() and not reseau.manche_en_cours, "pas de lancement tant que quelqu'un n'est pas prêt")
	reseau.definir_pret(9, true)
	reseau.inscrits[9].pret = false  # repassé non prêt dans la même image que l'appui, avant tout affichage
	_check(not reseau.lancer_manche() and lancees.is_empty() and not reseau.manche_en_cours,
		"l'hôte revérifie au moment de démarrer : un joueur repassé non prêt dans la même image fait refuser le lancement")
	reseau.inscrits[9].pret = true
	_check(reseau.lancer_manche() and reseau.manche_en_cours and reseau.examiner_demande({"jeu": reseau.JEU, "version": reseau.version, "pseudo": "Tard"}).raison == reseau.REFUS_MANCHE,
		"tous prêts : la manche se lance, plus personne n'entre (refus « manche en cours »)")
	_check(reseau.inscrits[9].index == 2 and reseau.table_salon.map(func(f: Dictionary) -> int: return f.index) == [0, 1, 2]
		and lancees.size() == 1 and lancees[0].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 5, 9],
		"au lancement, les index sont compactés (Chloé passe de 3 à 2) et les fiches suivent cet ordre")
	_check(not reseau.lancer_manche() and not reseau.changer_couleur(1, 1) and not reseau.definir_pret(5, false) and lancees.size() == 1,
		"pendant la manche : ni second lancement, ni couleur, ni Prêt")
	# Phase 18 : depuis l'écran Résultats, l'hôte relance une manche avec les joueurs encore là (Revanche,
	# Niveau suivant), ou ramène tout le monde au salon
	reseau._sur_pair_deconnecte(5)  # Bob part pendant la manche : un trou à l'index 1
	reseau.scenes_chargees.assign([1, 9])
	var niveau_avant: int = reseau.niveau_salon
	_check(reseau.relancer_manche(niveau_avant + 1 + EtatPartie.NIVEAUX.size()) and reseau.manche_en_cours and lancees.size() == 2
		and reseau.niveau_salon == posmod(niveau_avant + 1, EtatPartie.NIVEAUX.size())
		and lancees[1].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 9] and reseau.inscrits[9].index == 1
		and reseau.table_salon.map(func(f: Dictionary) -> int: return f.index) == [0, 1] and reseau.scenes_chargees.is_empty()
		and reseau.silence == reseau.SILENCE_CHARGEMENT
		and reseau.examiner_demande({"jeu": reseau.JEU, "version": reseau.version, "pseudo": "Tard"}).raison == reseau.REFUS_MANCHE,
		"Niveau suivant : une manche neuve avec les joueurs encore là (index recompactés), le niveau suivant en boucle, toujours sans arrivée")
	var rouverts := [0]
	var sur_salon := func() -> void: rouverts[0] += 1
	reseau.salon_rouvert.connect(sur_salon)
	_check(reseau.revenir_au_salon() and not reseau.manche_en_cours and rouverts[0] == 1 and reseau.silence == reseau.SILENCE_SESSION
		and reseau.inscrits.values().all(func(f: Dictionary) -> bool: return not f.pret)
		and reseau.table_salon.map(func(f: Dictionary) -> int: return f.id) == [1, 9],
		"Retour au salon : plus de manche en cours (arrivées acceptées), personne n'est prêt, la même table sans les partis")
	_check(not reseau.revenir_au_salon() and not reseau.relancer_manche(0) and rouverts[0] == 1 and lancees.size() == 2,
		"hors d'une manche (au salon), ni retour au salon ni relance : c'est « Démarrer la partie »")
	reseau.manche_en_cours = true
	reseau._sur_pair_deconnecte(9)
	_check(not reseau.relancer_manche(0) and lancees.size() == 2 and reseau.manche_en_cours,
		"seul, l'hôte ne relance pas de manche (Revanche : au moins deux joueurs)")
	reseau.salon_rouvert.disconnect(sur_salon)
	reseau.ouvrir_salon(1)
	_check(not reseau.manche_en_cours and reseau.inscrits.values().all(func(f: Dictionary) -> bool: return not f.pret) and reseau.niveau_salon == 1,
		"rouvrir le salon (à l'ouverture de la scène du salon) : arrivées acceptées, personne n'est prêt")
	reseau.manche_lancee.disconnect(sur_lancement)
	reseau.quitter()
	_check(reseau.table_salon.is_empty() and reseau.niveau_salon == 0 and reseau.places_salon == EtatPartie.NB_JOUEURS_MAX,
		"quitter() oublie la table du salon")
	reseau.pseudo = ""


## Phase 14 : la peinture identique sur chaque poste (jeux de tampons tirés de leur clé, tirage d'un
## tampon par sa graine) et le format réseau des tampons.
func _tester_peinture() -> void:
	print("-- Peinture (jeux de tampons, tirage, format réseau des tampons)")
	var nuances: Array[Color] = [Color(0.5, 0.1, 0.0), Color(0.81, 0.14, 0.01), Color(0.9, 0.5, 0.4)]
	seed(1)
	var jeu_a := Peinture.generer_tampons(21, nuances)
	seed(2)
	randi()
	var jeu_b := Peinture.generer_tampons(21, nuances)
	var memes := jeu_a.size() == Peinture.NB_TAMPONS and jeu_b.size() == Peinture.NB_TAMPONS
	for i in range(mini(jeu_a.size(), jeu_b.size())):
		memes = memes and jeu_a[i].get_data() == jeu_b[i].get_data()
	_check(memes and jeu_a[0].get_width() == 43, "un jeu de tampons est le même d'un poste à l'autre, quel que soit le hasard global (graine tirée de sa clé)")
	_check(jeu_a[0].get_data() != jeu_a[1].get_data(), "les variantes d'un même jeu diffèrent")
	var autres: Array[Color] = [Color(0.1, 0.2, 0.6), Color(0.24, 0.38, 1.0), Color(0.5, 0.6, 1.0)]
	_check(Peinture.generer_tampons(21, autres)[0].get_data() != jeu_a[0].get_data(), "un autre jeu de couleurs donne d'autres tampons")
	seed(3)
	var etat_global := randi()
	seed(3)
	Peinture.generer_tampons(16, nuances)
	Peinture.tirage(12345, 16, 3)
	_check(randi() == etat_global, "générer un jeu et tirer un tampon ne consomment pas le hasard global (Spawner, ennemis)")
	_check(Peinture.tirage(40000, 30, 3) == Peinture.tirage(40000, 30, 3) and Peinture.tirage(40000, 30, 3) != Peinture.tirage(40001, 30, 3),
		"le tirage d'un tampon ne dépend que de sa graine (le même sur chaque poste)")
	var coulures := 0
	var bornes := true
	for graine in range(2000):
		var t := Peinture.tirage(graine, 30, 3)
		coulures += 1 if t.coulure else 0
		bornes = bornes and t.variante >= 0 and t.variante < Peinture.NB_TAMPONS and t.dx >= -30 and t.dx <= 30 \
			and t.dy >= 0 and t.dy <= 30 and t.longueur >= 14 and t.longueur <= 44 and t.couleur >= 0 and t.couleur < 3
	_check(bornes and absf(coulures / 2000.0 - Peinture.CHANCE_COULURE) < 0.04,
		"tirages dans leurs bornes, une coulure pour %.0f %% des tampons (%d sur 2000)" % [Peinture.CHANCE_COULURE * 100.0, coulures])
	var lot: Array[Dictionary] = [
		{"index": 0, "x": 1000, "y": 150, "rayon": 16, "graine": 0},
		{"index": 5, "x": -40, "y": -12, "rayon": 92, "graine": Peinture.GRAINE_MAX},
		{"index": 3, "x": 2010, "y": 330, "rayon": 46, "graine": 777},
	]
	var octets := Peinture.encoder_tampons(lot)
	_check(octets.size() == 3 * Peinture.OCTETS_PAR_TAMPON and Peinture.decoder_tampons(octets) == lot,
		"un lot de tampons fait 8 octets par tampon et se relit à l'identique, dans l'ordre, centres négatifs compris (i16)")
	var hors_plage: Array[Dictionary] = [{"index": 1, "x": 40000, "y": -40000, "rayon": 300, "graine": 70000}]
	_check(Peinture.decoder_tampons(Peinture.encoder_tampons(hors_plage)) == [{"index": 1, "x": 32767, "y": -32768, "rayon": 255, "graine": 65535}],
		"des valeurs hors de leur plage sont ramenées dans leurs bornes, jamais bouclées")
	var tronque := octets.slice(0, 7)
	var mauvais_joueur := octets.duplicate()
	mauvais_joueur.encode_u8(Peinture.OCTETS_PAR_TAMPON, EtatPartie.NB_JOUEURS_MAX)
	_check(Peinture.decoder_tampons(tronque).is_empty() and Peinture.decoder_tampons(mauvais_joueur).is_empty()
		and Peinture.decoder_tampons("tampons").is_empty() and Peinture.decoder_tampons(PackedByteArray()).is_empty(),
		"un lot tronqué, un index de joueur hors plage ou autre chose qu'un lot d'octets est ignoré en entier")


## Phase 14 : le territoire d'un client suit celui de l'hôte par la liste des cellules changées.
func _tester_territoire_reseau() -> void:
	print("-- Territoire en réseau (cellules changées, scores)")
	var taille := Vector2i(20, 6)
	var peignables := PackedByteArray()
	peignables.resize(taille.x * taille.y)
	peignables.fill(1)
	peignables[0] = 0
	var hote := Territoire.new(taille, peignables, 8)
	var client := Territoire.new(taille, peignables, 8)
	for i in range(3):
		hote.tamponner(0, Vector2i(40, 24), 20)
		hote.tamponner(1, Vector2i(100, 24), 20)
	var premier := hote.extraire_changements()
	_check(client.appliquer_changements(hote.encoder_changements(premier)) and premier.size() > 0,
		"(pré-condition) des cellules changées chez l'hôte, appliquées chez le client")
	for i in range(6):
		hote.tamponner(1, Vector2i(56, 24), 20)  # le joueur 1 vole une partie des cellules du joueur 0
	hote.tamponner(2, Vector2i(140, 30), 12)  # une passe qui ne suffit pas à compter
	var second := hote.extraire_changements()
	var octets := hote.encoder_changements(second)
	_check(octets.size() == second.size() * Territoire.OCTETS_PAR_CHANGEMENT and client.appliquer_changements(octets),
		"3 octets par cellule changée (index u16, propriétaire compté u8)")
	var memes := true
	for i in range(peignables.size()):
		memes = memes and client.proprietaire_compte(i) == hote.proprietaire_compte(i)
	_check(memes and client.scores() == hote.scores() and client.cellules_de(0) == hote.cellules_de(0)
		and client.cellules_de(1) == hote.cellules_de(1) and hote.cellules_de(0) > 0 and hote.cellules_de(1) > 0,
		"le client a le même propriétaire compté par cellule et les mêmes scores que l'hôte (%s)" % [client.scores()])
	var avant := client.scores()
	var mauvaise_cellule := PackedByteArray([0, 0, 1])  # la cellule 0 n'est pas peignable
	var hors_grille := PackedByteArray([0xFF, 0xFF, 1])
	var mauvais_joueur := PackedByteArray([5, 0, EtatPartie.NB_JOUEURS_MAX + 1])
	_check(not client.appliquer_changements(mauvaise_cellule) and not client.appliquer_changements(hors_grille)
		and not client.appliquer_changements(mauvais_joueur) and not client.appliquer_changements(PackedByteArray([1, 0]))
		and not client.appliquer_changements(octets.slice(0, 3) + PackedByteArray([0xFF, 0xFF, 1])) and client.scores() == avant,
		"un lot mal formé (cellule non peignable ou hors grille, joueur hors plage, taille tronquée) est refusé sans rien changer")
	var vide := client.extraire_changements()
	_check(vide.is_empty(), "appliquer les changements de l'hôte n'en crée pas d'autres chez le client")



## Phase 14 : chez un client, les réactions des joueurs viennent de l'hôte (signaux compris), qui seul
## décompte leurs minuteries ; la fenêtre suit le format de l'écran.
func _tester_joueur_replique() -> void:
	print("-- Joueur répliqué (réactions reçues de l'hôte, minuteries de l'hôte)")
	var j := Joueur.new()
	j.reinitialiser(3)
	var journal: Array[String] = []
	j.crans_changes.connect(func(c: int) -> void: journal.append("crans:%d" % c))
	j.etourdissement_fini.connect(func() -> void: journal.append("fin_etourdi"))
	j.bonus_change.connect(func(actif: bool) -> void: journal.append("bonus:%s" % actif))
	j.recevoir_crans(4)
	j.recevoir_crans(4)
	j.recevoir_crans(99)
	_check(journal == ["crans:4", "crans:%d" % Joueur.CRANS_MAX] and j.crans == Joueur.CRANS_MAX,
		"les crans de l'hôte sont posés et signalés une fois, dans leurs bornes (%s)" % [journal])
	journal.clear()
	j.recevoir_fin_etourdissement(0.5)
	j.etourdir(1.5, 1.0, Vector2.INF, Color.RED)
	j.recevoir_fin_etourdissement(0.97)
	j.recevoir_fin_etourdissement(0.9)
	_check(journal == ["fin_etourdi"] and not j.est_etourdi() and is_equal_approx(j.invulnerable_restant, 0.97),
		"la fin d'étourdissement de l'hôte n'est signalée qu'à un joueur étourdi, une fois, avec l'immunité qui reste chez l'hôte")
	journal.clear()
	j.recevoir_fin_bonus()
	j.activer_bonus(8.0)
	j.recevoir_fin_bonus()
	j.recevoir_fin_bonus()
	_check(journal == ["bonus:true", "bonus:false"] and not j.bonus_actif(), "la fin de la gerbe XXL de l'hôte est signalée une fois (%s)" % [journal])

	var gs: Node = root.get_node("GameState")
	gs.configurer_bataille(2)
	gs.nouvelle_partie()
	gs.pret = true
	var joueur: Joueur = gs.joueurs[1]
	joueur.etourdir(1.5, 1.0, Vector2.INF, Color.RED)
	var fins: Array[int] = []
	var sur_fin := func() -> void: fins.append(1)
	joueur.etourdissement_fini.connect(sur_fin)
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 17795) == OK, "(pré-condition) GameState sur un pair client")
	api.multiplayer_peer = pair
	set_multiplayer(api, gs.get_path())
	gs._process(2.0)
	_check(is_equal_approx(gs.temps_ecoule, 2.0) and joueur.est_etourdi() and is_equal_approx(joueur.etourdi_restant, 1.5) and fins.is_empty(),
		"sur un client, le chrono tourne mais les minuteries des joueurs attendent l'hôte (aucune fin émise)")
	set_multiplayer(null, gs.get_path())
	pair.close()
	gs._process(2.0)
	_check(not joueur.est_etourdi() and fins.size() == 1, "sur l'hôte (hors réseau compris), GameState décompte les minuteries des joueurs")
	joueur.etourdissement_fini.disconnect(sur_fin)
	gs.configurer_solo()
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false

	_check(Regles.taille_fenetre(ReglesBataille.TAILLE_ECRAN, Vector2i(1400, 454)) == Vector2i(1400, 788)
		and Regles.taille_fenetre(Regles.TAILLE_ECRAN_SOLO, Vector2i(1400, 788)) == Vector2i(1400, 454),
		"hors du solo, la fenêtre prend le format 16:9 (1400×788), et le reprend du solo au retour (1400×454)")
	# Phase 19 (M7 de la revue finale 14) : la fenêtre tient dans la zone utile de son écran, au même format
	var place_1080p := Vector2i(1920, 1040 - 31)  # 1080p moins la barre des tâches (40) et la barre de titre (31)
	_check(Regles.taille_bornee(Vector2i(1920, 1080), place_1080p) == Vector2i(1793, 1009)
		and Regles.taille_bornee(Vector2i(1400, 788), place_1080p) == Vector2i(1400, 788)
		and Regles.taille_bornee(Vector2i(1400, 454), Vector2i(1366, 697)) == Vector2i(1366, 442)
		and Regles.taille_bornee(Vector2i(1400, 788), Vector2i.ZERO) == Vector2i(1400, 788),
		"une fenêtre qui dépasse la zone utile se réduit à son format (1920×1080 : 1793×1009 sur un écran 1080p ; 1400×454 : 1366×442 sur 1366 px), une fenêtre qui tient ne change pas")
	var zone := Rect2i(0, 0, 1920, 1040)
	_check(Regles.position_dans(Vector2i(300, 200), Vector2i(1400, 819), zone) == Vector2i(300, 200)
		and Regles.position_dans(Vector2i(700, 400), Vector2i(1400, 819), zone) == Vector2i(520, 221)
		and Regles.position_dans(Vector2i(-50, -10), Vector2i(1400, 819), zone) == Vector2i(0, 0)
		and Regles.position_dans(Vector2i(1920 + 100, 0), Vector2i(1400, 819), Rect2i(1920, 0, 1280, 984)) == Vector2i(1920, 0),
		"une fenêtre qui sort de la zone utile y revient, collée au bord qu'elle dépassait (au coin si elle est plus grande, second écran compris)")
	_check(Regles.position_dans(Vector2i(700, 400), Vector2i(1400, 819), Rect2i(0, 0, 0, 0)) == Vector2i(700, 400)
		and Regles.position_dans(Vector2i(700, 400), Vector2i(1400, 819), Rect2i(0, 0, 1920, 0)) == Vector2i(700, 400),
		"une zone utile sans surface (écran inconnu) ne fait pas reposer la fenêtre, comme taille_bornee")



## Phase 14 : ce que `Reseau` ajoute pour la manche (relais du serveur coupé, fiches revérifiées au
## lancement, silences, barrière de chargement, départ propre).
func _tester_reseau_manche() -> void:
	print("-- Réseau de la manche (relais, lancement revérifié, silences, scènes chargées, départ)")
	var reseau: Node = root.get_node("Reseau")
	var api := root.multiplayer as SceneMultiplayer
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	reseau.pseudo = "Hôte"
	_check(reseau.heberger(17788) == OK and not api.server_relay and reseau.silence == reseau.SILENCE_SESSION,
		"l'hôte écoute, sans relais entre clients (M5), silence de session")
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "Bob", "arrive": true, "pret": true}
	reseau.inscrits[9] = {"index": 3, "couleur": palette[2], "pseudo": "Chloé", "arrive": true, "pret": true}
	var hote: Dictionary = reseau.inscrits[1]
	reseau.inscrits.erase(1)  # une table où l'hôte n'est plus : `fiches_de_manche` la refuse
	var lancees: Array = []
	var sur_lancement := func(f: Array[Dictionary]) -> void: lancees.append(f)
	reseau.manche_lancee.connect(sur_lancement)
	_check(reseau.salon_pret(reseau.inscrits) and not reseau.lancer_manche() and not reseau.manche_en_cours and lancees.is_empty()
		and reseau.inscrits[9].index == 3 and reseau.silence == reseau.SILENCE_SESSION,
		"M1 : des fiches de manche incohérentes font refuser le lancement sans rien changer, même quand le salon est prêt (ligne ERROR attendue)")
	hote.pret = true
	reseau.inscrits[1] = hote
	reseau.signaler_scene_chargee()
	_check(reseau.lancer_manche() and reseau.manche_en_cours and lancees.size() == 1 and reseau.scenes_chargees.is_empty()
		and reseau.silence == reseau.SILENCE_CHARGEMENT,
		"au lancement : plus aucune scène chargée d'une manche précédente, silence de chargement")
	var chargees: Array[int] = []
	var sur_scene := func(id: int) -> void: chargees.append(id)
	reseau.scene_chargee.connect(sur_scene)
	reseau.signaler_scene_chargee()
	reseau.signaler_scene_chargee()
	_check(reseau.scenes_chargees == [1] and chargees == [1], "chez l'hôte, sa scène chargée est notée et signalée une fois")
	reseau.scene_chargee.disconnect(sur_scene)
	reseau.manche_lancee.disconnect(sur_lancement)
	# Phase 18 : un exclu de la barrière apprend son exclusion avant d'être déconnecté ; la perte de
	# l'hôte qui suit le dit (`raison_perte`), une fois
	var raisons: Array[String] = []
	var sur_perte := func() -> void: raisons.append(reseau.raison_perte)
	reseau.hote_perdu.connect(sur_perte)
	reseau._recevoir_exclusion()
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau.hote_perdu.disconnect(sur_perte)
	_check(raisons == [reseau.PERTE_EXCLU, reseau.PERTE_HOTE] and not reseau._exclu,
		"l'hôte perdu après une exclusion : « exclu » ; la perte suivante, de nouveau « l'hôte a quitté la partie » (%s)" % [raisons])
	_check(reseau.heberger(17788) == OK, "(pré-condition) l'hôte écoute de nouveau")
	reseau.definir_silence(reseau.SILENCE_SESSION)
	_check(reseau.silence == reseau.SILENCE_SESSION, "fin du chargement : silence de session")
	reseau.quitter()
	_check(reseau.scenes_chargees.is_empty() and reseau._partants.is_empty() and reseau.heberger(17788) == OK,
		"quitter oublie les scènes chargées ; sans autre poste connecté, le port se libère aussitôt")
	# Un autre poste connecté au niveau d'ENet (sa poignée de main ne finit jamais) : un départ propre
	# le prévient par un DISCONNECT fiable, renvoyé jusqu'à son accusé de réception.
	var autre := ENetMultiplayerPeer.new()
	_check(autre.create_client("127.0.0.1", 17788) == OK, "(pré-condition) un autre poste se connecte à l'hôte")
	_check(_connecter(autre, reseau), "(pré-condition) connecté au niveau d'ENet")
	reseau.quitter()
	_check(reseau._partants.size() == 1 and not reseau.en_ligne(), "quitter avec un poste connecté : ce poste est hors réseau, son départ part en arrière-plan")
	var prevenu := false
	for i in range(200):
		autre.poll()
		reseau._process(0.0)
		if autre.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and reseau._partants.is_empty():
			prevenu = true
			break
		OS.delay_msec(5)
	_check(prevenu, "l'autre poste reçoit le départ, qui est clos une fois reçu")
	autre = ENetMultiplayerPeer.new()
	_check(reseau.heberger(17788) == OK and autre.create_client("127.0.0.1", 17788) == OK, "(pré-condition) l'hôte rouvre, l'autre poste se reconnecte")
	var connecte := _connecter(autre, reseau)
	reseau.quitter()
	_check(connecte and reseau._partants.size() == 1 and reseau.heberger(17788) == OK and reseau._partants.is_empty(),
		"héberger aussitôt après un départ en cours : le port de la session quittée est libéré d'abord")
	reseau.quitter()
	autre.close()
	reseau.pseudo = ""



## Phase 15 bis : le déplacement d'un lion, en logique pure (`DeplacementLion`), que `Lion.avancer`
## fait avancer d'un pas par tick et que la prédiction du lion local rejouera (phase 16).
func _tester_deplacement_lion() -> void:
	print("-- Déplacement d'un lion (logique pure)")
	var d := DeplacementLion.new()
	var dt := 1.0 / 60.0
	var v := d.vitesse_du_pas(Vector2.RIGHT, dt)
	_check(is_equal_approx(v.x, d.acceleration * dt) and v.y == 0.0 and d.recul == Vector2.ZERO,
		"un pas vers la droite : la vitesse commandée gagne une accélération d'un tick (%.1f px/s)" % v.x)
	for i in range(30):
		v = d.vitesse_du_pas(Vector2.RIGHT, dt)
	_check(v == Vector2(d.speed, 0.0), "elle plafonne à la vitesse du lion (%s)" % v)
	d.arreter()
	_check(d.vitesse == Vector2.ZERO, "arrêter annule la vitesse commandée (début d'un étourdissement)")
	d.repousser(Vector2(100, 100), Vector2(40, 100), 1)
	_check(d.recul == Vector2(d.force_recul, 0.0), "un coup venu de la gauche repousse vers la droite, de toute la force du recul")
	d.repousser(Vector2(100, 100), Vector2.INF, 1)
	_check(d.recul == Vector2(-d.force_recul, 0.0), "origine inconnue : recul vers l'arrière du lion (tourné à droite)")
	d.repousser(Vector2(100, 100), Vector2(100, 100), -1)
	_check(d.recul == Vector2(d.force_recul, 0.0), "origine confondue avec le centre : recul vers l'arrière du lion (tourné à gauche)")
	var pas := 0
	while d.recul != Vector2.ZERO and pas < 60:
		v = d.vitesse_du_pas(Vector2.ZERO, dt)
		pas += 1
	_check(pas == ceili(d.force_recul / (d.acceleration * 1.5 * dt)) and v == Vector2.ZERO,
		"sans commande, le recul s'amortit jusqu'à zéro en %d ticks, et le lion s'arrête" % pas)
	var a := DeplacementLion.new()
	var b := DeplacementLion.new()
	for i in range(20):
		a.vitesse_du_pas(Vector2(1, 1).normalized(), dt)
		b.vitesse_du_pas(Vector2(1, 1).normalized(), dt)
	_check(a.vitesse == b.vitesse and a.recul == b.recul, "les mêmes commandes donnent les mêmes pas (ce que rejouera la prédiction)")


## Phase 16 : les commandes d'un client, numérotées et redondantes (la dernière et les 3 précédentes
## dans chaque paquet) ; chez l'hôte, une file dont le lion applique une commande par tick, dans
## l'ordre, jamais deux fois.
func _tester_commandes_reseau() -> void:
	print("-- Commandes numérotées et redondantes (phase 16)")
	var octets := Commandes.encoder_paquet(7, [[Vector2(0.5, 0.0), false], [Vector2(1, 0), true], [Vector2(0, -1), false], [Vector2(0.6, 0.8), true]])
	var paquet := Commandes.decoder_paquet(octets)
	_check(octets.size() == Commandes.TAILLE_ENTETE + 4 * Commandes.TAILLE_COMMANDE and paquet.size() == 4
		and paquet.map(func(c: Dictionary) -> int: return c.numero) == [4, 5, 6, 7]
		and paquet[3].direction == Vector2(0.6, 0.8) and paquet[3].vomir and paquet[1].vomir and not paquet[0].vomir,
		"un paquet porte la dernière commande et les 3 précédentes, numérotées, de la plus ancienne à la dernière (%d octets)" % octets.size())
	var cinq: Array = []
	for i in range(5):
		cinq.append([Vector2.ZERO, false])
	_check(Commandes.decoder_paquet(octets.slice(0, octets.size() - 1)).is_empty() and Commandes.decoder_paquet(Commandes.encoder_paquet(9, cinq)).is_empty()
		and Commandes.decoder_paquet(Commandes.encoder_paquet(3, [[Vector2(INF, 0), false]])).is_empty()
		and Commandes.decoder_paquet(Commandes.encoder_paquet(0, [[Vector2.ZERO, false]])).is_empty()
		and Commandes.decoder_paquet("paquet").is_empty() and Commandes.decoder_paquet(PackedByteArray()).is_empty(),
		"un paquet tronqué, trop long, non fini, numéroté sous 1 ou d'un autre type est refusé")

	var c := Commandes.manuelles()
	_check(_recevoir_paquet(c, 2, [[Vector2.RIGHT, false], [Vector2.DOWN, true]]) == 2 and _recevoir_paquet(c, 4, [[Vector2.RIGHT, false],
		[Vector2.DOWN, true], [Vector2.LEFT, false], [Vector2.UP, true]]) == 2 and c.en_attente() == 4 and c.numero_applique == 0,
		"deux paquets qui se chevauchent : chaque commande entre une fois dans la file (4 en attente)")
	_check(_recevoir_paquet(c, 3, [[Vector2.RIGHT, false], [Vector2.DOWN, true], [Vector2.LEFT, false]]) == 0 and c.en_attente() == 4,
		"un paquet en retard, déjà couvert par un plus récent, n'ajoute rien")
	var vues: Array[int] = []
	for i in range(4):
		c.appliquer_suivante()
		vues.append(c.numero_applique)
	_check(vues == [1, 2, 3, 4] and c.direction() == Vector2.UP and c.vomir() and c.appliquees == 4 and c.sautees == 0,
		"une commande par tick, dans l'ordre (%s)" % [vues])
	c.appliquer_suivante()
	_check(c.numero_applique == 4 and c.direction() == Vector2.UP and c.appliquees == 4,
		"file vide (commande en retard) : la dernière appliquée tient encore un tick, sans être comptée deux fois")
	# La tenue ci-dessus a laissé une dette (I1) : remise à zéro pour garder ce trou-de-numéros isolé
	# de la dette, testée séparément plus bas (`_tester_commandes_dette`).
	c.remettre_au_repos()
	_recevoir_paquet(c, 10, [[Vector2.LEFT, false], [Vector2.LEFT, false], [Vector2.LEFT, false], [Vector2(3, 4), true]])
	for i in range(4):
		c.appliquer_suivante()
	_check(c.numero_applique == 10 and c.sautees == 2 and c.appliquees + c.sautees == c.numero_applique
		and c.direction().is_equal_approx(Vector2(0.6, 0.8)),
		"trois paquets perdus de suite (5 à 9) : 5 et 6 manquent, sautés et comptés ; aucune commande n'est appliquée deux fois ; la direction reçue reste bornée")
	# I2 (revue finale phase 17, désync-report) : une vraie perte réseau (jamais reçue, pas de rattrapage
	# ici, la dette venant d'être remise à zéro) ne compte que dans `perdues`, jamais dans `rattrapees`.
	_check(c.perdues == 2 and c.rattrapees == 0,
		"un numéro jamais reçu incrémente perdues (%d), pas rattrapees (%d) : ce n'est pas un rattrapage volontaire" % [c.perdues, c.rattrapees])
	var neuves := 0
	for dernier in range(14, 31, 4):
		neuves += _recevoir_paquet(c, dernier, [[Vector2.RIGHT, false], [Vector2.RIGHT, false], [Vector2.RIGHT, false], [Vector2.RIGHT, true]])
	_check(c.en_attente() == Commandes.FILE_MAX and neuves == 20 and c.file_max_vue == Commandes.FILE_MAX,
		"un rattrapage d'un coup (20 commandes neuves) : la file garde les %d plus récentes" % Commandes.FILE_MAX)
	c.appliquer_suivante()
	_check(c.numero_applique == 30 - Commandes.FILE_MAX + 1 and c.appliquees + c.sautees == c.numero_applique,
		"les plus anciennes sont sautées, comptées, jamais appliquées (reprise à la %d)" % c.numero_applique)

	# Protocole des commandes (scénario 12, désync-report) : au-delà de la redondance, un client qui
	# rattrape une rafale après une image longue peut voir ses paquets réordonnés par le Wi-Fi (ou le
	# relais de test) ; l'hôte doit combler les trous dans l'ordre des numéros, pas de leur arrivée,
	# et ne refuser qu'un numéro déjà appliqué (jamais un numéro seulement vu passer avant lui).
	var c2 := Commandes.manuelles()
	for n in range(1, 6):
		c2.recevoir(n, Vector2.RIGHT, false)
	for i in range(5):
		c2.appliquer_suivante()
	_check(c2.numero_applique == 5 and c2.appliquees == 5 and c2.sautees == 0, "(base) cinq commandes reçues et appliquées dans l'ordre")
	_check(not c2.recevoir(5, Vector2.LEFT, true) and not c2.recevoir(3, Vector2.LEFT, true) and c2.en_attente() == 0,
		"un numéro au plus grand déjà appliqué est ignoré (5 et 3, la dernière appliquée est la 5), même s'il n'a jamais été vu avant")
	_check(c2.recevoir(9, Vector2.UP, false) and c2.recevoir(7, Vector2.DOWN, false) and c2.recevoir(6, Vector2.LEFT, false)
		and not c2.recevoir(7, Vector2.DOWN, false) and c2.en_attente() == 3,
		"9, 7 puis 6 arrivées dans le désordre entrent quand même dans la file ; un doublon tardif du 7, déjà en file, est ignoré")
	_check(c2.recevoir(8, Vector2.RIGHT, true) and c2.en_attente() == 4,
		"le 8 manquant, arrivé en dernier, comble le trou entre 6 et 9")
	for i in range(4):
		c2.appliquer_suivante()
	_check(c2.numero_applique == 9 and c2.sautees == 0 and c2.appliquees == 9 and c2.direction() == Vector2.UP,
		"une fois le trou comblé, la file applique dans l'ordre des numéros (6, 7, 8, 9), pas de leur arrivée : aucune sautée malgré le désordre")
	for n in range(29, 9, -1):
		c2.recevoir(n, Vector2.RIGHT, false)
	_check(c2.en_attente() == Commandes.FILE_MAX and c2.file_max_vue == Commandes.FILE_MAX,
		"un rattrapage de 20 commandes reçues à l'envers (29 à 10) garde quand même les %d plus récentes" % Commandes.FILE_MAX)
	c2.appliquer_suivante()
	_check(c2.numero_applique == 29 - Commandes.FILE_MAX + 1 and c2.appliquees + c2.sautees == c2.numero_applique,
		"les plus petites sont sautées, comptées, jamais appliquées (reprise à la %d), même reçues en dernier" % c2.numero_applique)
	c2.remettre_au_repos()
	_check(c2.en_attente() == 0 and c2.direction() == Vector2.ZERO and not c2.vomir()
		and not c2.recevoir(c2.numero_applique, Vector2.RIGHT, true) and c2.recevoir(c2.numero_applique + 1, Vector2.RIGHT, true) and c2.en_attente() == 1,
		"client muet : repos, file vidée ; seul un numéro déjà appliqué reste refusé, un numéro seulement vidé par le repos redevient acceptable")


## I1 (revue finale de la phase 16, `Commandes.appliquer_suivante`) : une file vide (l'hôte tient la
## dernière commande) laisse une dette de tenues ; le rattrapage qui suit doit la rembourser en
## sautant une commande de plus par tick tant que la file dépasse SEUIL_RATTRAPAGE (un vrai accroc, pas
## la gigue courante), pour que le numéro appliqué ne reste pas durablement en retard sur le temps
## réel, et sans qu'aucune commande ne soit appliquée deux fois (direction tenue constante : aucun
## mouvement en trop, spec §10).
func _tester_commandes_dette() -> void:
	print("-- Dette de tenues et rattrapage (I1, revue finale phase 16)")
	var sans_accroc := Commandes.manuelles()  # référence : jamais de tenue, reçoit à l'heure
	var c := Commandes.manuelles()  # l'hôte testé : subit l'accroc réseau
	var appliquer := func(cmd: Commandes, numero: int) -> void:
		cmd.recevoir(numero, Vector2.RIGHT, false)
		cmd.appliquer_suivante()

	# Dix ticks sans accroc, des deux côtés : la référence et l'hôte testé restent synchronisés.
	for n in range(1, 11):
		appliquer.call(sans_accroc, n)
		appliquer.call(c, n)
	_check(c.numero_applique == 10 and c.dette() == 0 and c.en_attente() == 0 and c.rejouees == 0,
		"(dette) en régime permanent, sans tenue, la file reste vide")

	# Accroc réseau de 6 tenues (host hitch, revue finale) : la file de l'hôte testé reste vide (rien
	# n'arrive), mais la dette grandit ; la référence continue de recevoir ses commandes à l'heure (le
	# joueur, lui, n'a pas cessé de jouer).
	for n in range(11, 17):
		appliquer.call(sans_accroc, n)
		c.appliquer_suivante()
	_check(c.numero_applique == 10 and c.dette() == 6 and c.en_attente() == 0 and c.appliquees == 10,
		"(dette) un accroc de 6 tenues : la dette grandit, sans rien appliquer deux fois ni en trop")

	# Rattrapage : les 6 commandes en retard (11 à 16) arrivent d'un coup chez l'hôte testé, en même
	# temps que celle de ce tick (17, elle, arrivée à l'heure) ; puis le réseau continue, une commande
	# neuve par tick, sans plus aucune tenue.
	for n in range(11, 17):
		c.recevoir(n, Vector2.RIGHT, false)
	appliquer.call(sans_accroc, 17)
	c.recevoir(17, Vector2.RIGHT, false)
	c.appliquer_suivante()
	for n in range(18, 24):
		appliquer.call(sans_accroc, n)
		appliquer.call(c, n)
	_check(sans_accroc.numero_applique == 23, "(pré-condition) sans accroc, 23 ticks appliquent 23 commandes")
	_check(c.rejouees == 0 and c.appliquees + c.sautees == c.numero_applique,
		"(dette) aucune commande appliquée deux fois pendant le rattrapage (%d appliquées, %d sautées, jusqu'à la %d)"
			% [c.appliquees, c.sautees, c.numero_applique])
	# I2 (revue finale phase 17, désync-report) : ce rattrapage n'est pas une perte réseau (toutes les
	# commandes 11 à 16 ont fini par arriver) ; il doit être compté à part de `perdues`.
	_check(c.rattrapees > 0 and c.perdues == 0,
		"(dette) un délestage volontaire du rattrapage incrémente rattrapees (%d), pas perdues (%d) : ce n'est pas une perte réseau" % [c.rattrapees, c.perdues])
	_check(sans_accroc.numero_applique - c.numero_applique < 23 - 10,
		"(dette) le chemin appliqué se rapproche de celui sans accroc (%d contre %d), pas le plein retard de l'accroc (resterait à %d sans la dette)"
			% [c.numero_applique, sans_accroc.numero_applique, 10])
	_check(c.en_attente() <= Commandes.SEUIL_RATTRAPAGE,
		"(dette) la file revient sous son seuil de rattrapage (%d au plus) dans les ticks qui suivent (%d en attente)" % [Commandes.SEUIL_RATTRAPAGE, c.en_attente()])
	_check(c.direction() == Vector2.RIGHT and not c.vomir(), "(dette) la direction tenue constante reste correcte de bout en bout")


func _recevoir_paquet(c: Commandes, dernier: int, commandes: Array) -> int:
	var neuves := 0
	for commande in Commandes.decoder_paquet(Commandes.encoder_paquet(dernier, commandes)):
		if c.recevoir(commande.numero, commande.direction, commande.vomir):
			neuves += 1
	return neuves


## Phase 16 : l'état d'un lion chez l'hôte, au format réseau (ce que recopie son `Synchro`).
func _tester_etat_lion() -> void:
	print("-- État d'un lion au format réseau (phase 16)")
	var octets := EtatLion.encoder(123456, 789, Vector2(512.5, -30.25), Vector2(350, -12.5), Vector2(-700, 0), -1)
	var e := EtatLion.decoder(octets)
	_check(octets.size() == EtatLion.TAILLE and e.instant == 123456 and e.commande == 789 and e.position == Vector2(512.5, -30.25)
		and e.vitesse == Vector2(350, -12.5) and e.recul == Vector2(-700, 0) and e.direction == -1,
		"instant, dernière commande appliquée, position, vitesse commandée, recul et orientation font l'aller-retour (%d octets)" % octets.size())
	var nan := EtatLion.encoder(1, 0, Vector2(NAN, 0), Vector2.ZERO, Vector2.ZERO, 1)
	var sans_sens := EtatLion.encoder(1, 0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0)
	_check(EtatLion.decoder(nan).is_empty() and EtatLion.decoder(sans_sens).is_empty() and EtatLion.decoder(octets.slice(1)).is_empty()
		and EtatLion.decoder("état").is_empty(), "un état non fini, sans orientation, tronqué ou d'un autre type est refusé")


## Phase 16 : un lion distant sur un client, interpolé entre les états reçus avec RETARD ticks de
## retard ; ici sous une gigue de ±1,2 tick (±20 ms) autour de 3 ticks de latence et 5 % de pertes.
func _tester_interpolation_lion() -> void:
	print("-- Interpolation d'un lion distant (phase 16)")
	var interp := InterpolationLion.new(60)
	interp.avancer(1.0)
	_check(interp.echantillon().is_empty(), "sans état reçu, rien à afficher (le lion garde sa place)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	var vitesse := 350.0
	var en_route: Array = []  # [tick d'arrivée, instant de l'hôte]
	var xs: Array[float] = []
	var retards: Array[float] = []
	var dernier_recu := -1
	for t in range(600):
		if rng.randf() >= 0.05:
			en_route.append([t + 3.0 + rng.randf_range(-1.2, 1.2), t])
		for m: Array in en_route:
			if m[0] <= t:
				interp.ajouter(m[1], Vector2(m[1] * vitesse / 60.0, 100.0), Vector2(vitesse, 0.0), 1)
				dernier_recu = maxi(dernier_recu, m[1])
		en_route = en_route.filter(func(m: Array) -> bool: return m[0] > t)
		interp.avancer(1.0)
		var vu := interp.echantillon()
		if not vu.is_empty():
			xs.append(vu.position.x)
			retards.append(t - vu.position.x * 60.0 / vitesse)
	var pas_min := INF
	var pas_max := -INF
	for i in range(120, xs.size()):
		pas_min = minf(pas_min, xs[i] - xs[i - 1])
		pas_max = maxf(pas_max, xs[i] - xs[i - 1])
	var retard_moyen := 0.0
	for i in range(120, retards.size()):
		retard_moyen += retards[i] / (retards.size() - 120)
	_check(pas_min > 0.8 * vitesse / 60.0 and pas_max < 1.2 * vitesse / 60.0,
		"sous la gigue et les pertes, le lion affiché avance d'un pas régulier, sans recul ni saut (%.2f à %.2f px par tick, pour %.2f)" % [pas_min, pas_max, vitesse / 60.0])
	_check(retard_moyen > InterpolationLion.RETARD + 1.0 and retard_moyen < InterpolationLion.RETARD + 5.0,
		"avec %.1f ticks de retard en moyenne sur l'hôte (le retard d'affichage et la latence)" % retard_moyen)
	# Plus aucun état (un hôte figé) : le lion va un peu plus loin sur sa vitesse, puis s'arrête là, sans
	# jamais revenir en arrière (M2, revue finale phase 16 ; en fin de manche, le bilan de l'hôte pose
	# l'état final de chaque lion, phase 18)
	var dernier_etat := Vector2(dernier_recu * vitesse / 60.0, 100.0)
	var plus_loin := -INF
	var recule := false
	var avant_x := -INF
	for t in range(30):
		interp.avancer(1.0)
		var x: float = interp.echantillon().position.x
		recule = recule or x < avant_x - 0.001
		avant_x = x
		plus_loin = maxf(plus_loin, x)
	var arret: Dictionary = interp.echantillon()
	_check(plus_loin > dernier_etat.x and plus_loin <= dernier_etat.x + InterpolationLion.EXTRAPOLATION_MAX * vitesse / 60.0 + 0.01,
		"plus aucun état : le lion continue sur sa vitesse %d ticks au plus (%.2f px au-delà du dernier état)" % [int(InterpolationLion.EXTRAPOLATION_MAX), plus_loin - dernier_etat.x])
	_check(not recule and is_equal_approx(arret.position.x, plus_loin) and arret.vitesse == Vector2.ZERO,
		"M2 : puis il s'arrête là, sans revenir en arrière vers le dernier état reçu (x = %.2f, dernier état %.2f)" % [arret.position.x, dernier_etat.x])
	# M2 : un accroc du Wi-Fi de 300 ms en pleine course, puis la reprise : l'affichage ne recule jamais
	var accroc := InterpolationLion.new(60)
	var pas_accroc: Array[float] = []
	var x_avant := -INF
	for t in range(240):
		if t < 120 or t >= 138:
			accroc.ajouter(t, Vector2(t * vitesse / 60.0, 100.0), Vector2(vitesse, 0.0), 1)
		accroc.avancer(1.0)
		var vu_accroc := accroc.echantillon()
		if vu_accroc.is_empty():
			continue  # le premier état n'est pas encore affiché (RETARD)
		if x_avant > -INF:
			pas_accroc.append(vu_accroc.position.x - x_avant)
		x_avant = vu_accroc.position.x
	_check(pas_accroc.min() >= -0.001,
		"M2 : pendant un accroc de 300 ms et à la reprise, le lion distant ne recule jamais (plus petit pas %.2f px)" % pas_accroc.min())
	var desordre := InterpolationLion.new(60)
	desordre.ajouter(10, Vector2(0, 0), Vector2.ZERO, 1)
	desordre.ajouter(12, Vector2(20, 0), Vector2.ZERO, -1)
	desordre.ajouter(11, Vector2(100, 0), Vector2.ZERO, 1)  # arrivé après le 12
	desordre.ajouter(11, Vector2(999, 0), Vector2.ZERO, 1)  # doublon
	for t in range(int(InterpolationLion.RETARD)):
		desordre.avancer(1.0)
	var horloge := 12.0 - desordre.retard()
	var milieu: Dictionary = desordre.echantillon()
	_check(horloge > 10.0 and horloge < 11.0 and is_equal_approx(milieu.position.x, (horloge - 10.0) * 100.0) and milieu.direction == 1,
		"un état arrivé en retard se range à son instant, un doublon est ignoré (x = %.1f à l'instant %.2f)" % [milieu.position.x, horloge])
	desordre.ajouter(200, Vector2(200, 0), Vector2.ZERO, 1)
	desordre.avancer(1.0)
	_check(is_equal_approx(desordre.retard(), InterpolationLion.RETARD), "un saut de plus d'ECART_MAX ticks (un poste figé) recale l'horloge d'un coup")


## Phase 17 : le chrono de la manche (affichage, fin chez l'hôte seulement), le classement et les
## couches de musique.
func _tester_chrono_bataille() -> void:
	print("-- Chrono et classement de la bataille (phase 17)")
	var gs: Node = root.get_node("GameState")
	gs.configurer_bataille(2)
	gs.nouvelle_partie()
	gs.pret = true
	var r: ReglesBataille = gs.regles
	var affiches: Array[int] = []
	for t in [0.0, 0.5, 80.0, 80.2, 89.99, 90.0, 95.0]:
		gs.temps_ecoule = t
		affiches.append(r.secondes_restantes())
	_check(affiches == [90, 90, 10, 10, 1, 0, 0] and r.temps_restant() == 0.0,
		"le chrono affiche les secondes restantes arrondies au-dessus : 1:30 au départ, 0:01 jusqu'au bout, 0:00 à la fin (%s)" % [affiches])
	var musique: Array[int] = []
	for t in [0.0, 29.9, 30.0, 59.9, 60.0, 90.0]:
		gs.temps_ecoule = t
		musique.append(r.intensite_musique())
	_check(musique == [0, 0, 1, 1, 2, 3], "en bataille, les arpèges entrent à 30 s de jeu, la mélodie à 60 s (%s)" % [musique])
	gs.temps_ecoule = 0.0
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	# Sur un client : son chrono tourne, jamais il ne termine la manche lui-même
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 17796) == OK, "(pré-condition) GameState sur un pair client")
	api.multiplayer_peer = pair
	set_multiplayer(api, gs.get_path())
	gs._process(ReglesBataille.DUREE_MANCHE + 5.0)
	_check(gs.partie_en_cours and fins.is_empty() and r.secondes_restantes() == 0,
		"sur un client, le chrono passé à zéro ne termine pas la manche : elle attend la fin de l'hôte")
	set_multiplayer(null, gs.get_path())
	pair.close()
	# Sur l'hôte (hors réseau compris) : la manche se termine quand le chrono arrive à zéro, pas avant
	gs.nouvelle_partie()
	gs.pret = true
	gs._process(ReglesBataille.DUREE_MANCHE - 0.5)
	_check(gs.partie_en_cours and fins.is_empty(), "sur l'hôte, la manche continue tant que le chrono n'est pas à zéro")
	gs._process(0.5)
	_check(not gs.partie_en_cours and fins == [true], "sur l'hôte, le chrono à zéro termine la manche, une fois (%s)" % [fins])
	gs._process(1.0)
	_check(fins.size() == 1 and is_equal_approx(gs.temps_ecoule, ReglesBataille.DUREE_MANCHE),
		"une manche finie ne se retermine pas, son chrono reste arrêté")
	# Une manche courte (le test réseau) : la durée se règle sur le script des règles
	var script_regles: Script = load("res://Scripts/ReglesBataille.gd")
	script_regles.duree_manche = 10.0
	gs.nouvelle_partie()
	gs.pret = true
	gs._process(10.0)
	_check(not gs.partie_en_cours and fins.size() == 2 and is_equal_approx(r.avancement(), 1.0),
		"une manche réglée sur 10 s (test réseau) se termine à 10 s")
	script_regles.duree_manche = ReglesBataille.DUREE_MANCHE
	gs.partie_terminee.disconnect(sur_fin)
	# En solo, le chrono compte sans jamais finir la partie ; la musique suit la ville peinte
	gs.configurer_solo()
	gs.nouvelle_partie()
	gs.pret = true
	gs._process(500.0)
	gs.progression = gs.seuil_victoire() * 0.7
	_check(gs.partie_en_cours and gs.regles.intensite_musique() == 2,
		"en solo, le chrono ne finit jamais la partie, et la musique suit la ville peinte (une couche par tiers du seuil)")
	gs.progression = 0.0
	gs.partie_en_cours = false
	gs.pret = false

	_check(ReglesBataille.rangs([0, 0, 0]) == [0, 0, 0], "au départ, personne n'est classé (aucune cellule)")
	_check(ReglesBataille.rangs([5, 9, 5, 0]) == [2, 1, 2, 0] and ReglesBataille.rangs([7, 7, 3]) == [1, 1, 3],
		"le plus de cellules est premier ; des ex æquo partagent leur rang, le suivant saute d'autant")
	_check(ReglesBataille.parts([0, 0, 0]) == [0, 0, 0] and ReglesBataille.parts([3, 0]) == [100, 0],
		"la part des cellules peintes : 0 % pour tous tant que personne ne possède rien (aucune division par zéro), 100 % pour le seul peintre")
	var parts_a_4 := ReglesBataille.parts([349, 274, 326, 426])
	_check(ReglesBataille.parts([1, 1, 1]) == [34, 33, 33] and ReglesBataille.parts([2, 1]) == [67, 33]
		and ReglesBataille.parts([5, 9, 5, 0]) == [26, 48, 26, 0] and parts_a_4 == [25, 20, 24, 31],
		"les parts font 100 à elles toutes, le reste de l'arrondi aux plus grands restes, jamais à un joueur sans cellule (%s)" % [parts_a_4])

	# Le rythme de la manche (phase 17) : pastilles et peintre ; le solo ne change pas
	var solo := ReglesSolo.new(gs)
	_check(solo.pastilles_en_meme_temps() == 1 and solo.pastille_peut_arriver(5) and solo.delai_entre_pastilles(6.0) == 6.0
		and solo.duree_de_vie_pastille() == 0.0 and solo.facteur_repos_peintre() == 1.0
		and not solo.pastilles_loin_des_lions(),
		"en solo, une pastille à la fois, 6 s après le départ de la précédente, sans fin de vie ; le peintre se repose comme avant")
	var plafonds: Array[int] = []
	for nb in [2, 3, 4, 6]:
		gs.configurer_bataille(nb)
		plafonds.append(gs.regles.pastilles_en_meme_temps())
	var b6: Regles = gs.regles
	_check(plafonds == [2, 2, 3, 3] and b6.pastille_peut_arriver(2) and not b6.pastille_peut_arriver(3),
		"en bataille, deux pastilles à la fois de 2 à 3 joueurs, trois de 4 à 6, jamais plus (%s)" % [plafonds])
	_check(b6.delai_entre_pastilles(6.0) == ReglesBataille.DELAI_ENTRE_PASTILLES and ReglesBataille.DELAI_ENTRE_PASTILLES == 4.0
		and b6.duree_de_vie_pastille() == 12.0 and b6.facteur_repos_peintre() == 2.0 and b6.pastilles_loin_des_lions(),
		"en bataille, une pastille toutes les 4 s, qui expire au bout de 12 s si personne ne la prend ; le peintre se repose deux fois plus")
	# Extra (revue de capture) : la zone des pastilles remonte sous la bande du HUD en bataille (les
	# vignettes), jamais en solo (pas de HUD au-dessus du jeu)
	var zone_repere := Rect2(150, 80, 1700, 300)
	_check(solo.zone_pickups_ajustee(zone_repere) == zone_repere,
		"en solo, la zone des pastilles n'est pas ajustée (pas de bande de HUD au-dessus du jeu)")
	var zone_ajustee: Rect2 = b6.zone_pickups_ajustee(zone_repere)
	var echelle_bataille := ReglesBataille.TAILLE_ECRAN.y / float(Regles.TAILLE_ECRAN_SOLO.y)
	_check(zone_ajustee.position.y > zone_repere.position.y and is_equal_approx(zone_ajustee.end.y, zone_repere.end.y)
		and is_equal_approx(zone_ajustee.position.y * echelle_bataille, ReglesBataille.HAUTEUR_BANDE_HUD),
		"en bataille, la zone des pastilles remonte sous la bande du HUD, sans changer son bas (%s)" % [zone_ajustee])
	gs.configurer_solo()


## Phase 17 : les étiquettes de pseudo de lions qui se touchent s'écartent à l'horizontale, sans
## sortir de l'écran (2000 px).
func _tester_placement_pseudos() -> void:
	print("-- Étiquettes de pseudo (phase 17)")
	var voisins: Array[Rect2] = [Rect2(100, 50, 120, 30), Rect2(180, 50, 120, 30)]
	var xs := PlacementPseudos.repartir(voisins, 2000.0)
	_check(is_equal_approx(xs[0], 77.0) and is_equal_approx(xs[1], 203.0),
		"deux pseudos à la même hauteur qui se recouvrent s'écartent chacun de la moitié de ce qui manque (%s)" % [xs])
	var etages: Array[Rect2] = [Rect2(100, 50, 120, 30), Rect2(150, 90, 120, 30)]
	_check(PlacementPseudos.repartir(etages, 2000.0) == [100.0, 150.0], "deux pseudos l'un au-dessus de l'autre restent où ils sont")
	var bords: Array[Rect2] = [Rect2(-40, 50, 120, 30), Rect2(1950, 400, 120, 30)]
	_check(PlacementPseudos.repartir(bords, 2000.0) == [0.0, 1880.0], "un pseudo qui déborde d'un bord y est ramené")
	var au_bord: Array[Rect2] = [Rect2(-10, 50, 120, 30), Rect2(60, 50, 120, 30)]
	xs = PlacementPseudos.repartir(au_bord, 2000.0)
	_check(xs[0] == 0.0 and is_equal_approx(xs[1], 126.0), "contre le bord, l'autre pseudo prend tout l'écart (%s)" % [xs])
	var tas: Array[Rect2] = []
	for i in range(6):
		tas.append(Rect2(1700 + 3 * i, 50, 260, 30))  # six pseudos de 12 caractères larges, sur le même lion
	xs = PlacementPseudos.repartir(tas, 2000.0)
	var separes := true
	for i in range(6):
		separes = separes and xs[i] >= 0.0 and xs[i] + 260.0 <= 2000.0
		for j in range(6):
			if i != j and xs[i] < xs[j]:
				separes = separes and xs[i] + 260.0 + PlacementPseudos.ECART <= xs[j] + 0.01
	_check(separes, "six pseudos larges en tas contre un bord s'étalent sans se recouvrir, dans l'écran (%s)" % [xs])
	# I1 (revue finale phase 17) : un pseudo court (lion à x=1000) à côté d'un pseudo large de 12
	# capitales (lion à x=1092, 92 px à droite : distance de contact entre deux lions). Chaque texte
	# est centré sur son lion (comme `Lion.rect_pseudo`) : le texte large, plus il est large, a un
	# bord gauche plus à gauche que le texte court, bien que son lion soit à droite. Trier par bord
	# gauche (l'ancien code) inverse alors l'ordre des deux étiquettes ; trier par centre le préserve.
	var court := Rect2(1000.0 - 23.0, 50, 46, 30)  # centré sur le lion de gauche (x=1000)
	var large := Rect2(1092.0 - 147.5, 50, 295, 30)  # centré sur le lion de droite (x=1092)
	_check(large.position.x < court.position.x, "(pré-condition) le bord gauche du texte large est bien avant celui du texte court")
	xs = PlacementPseudos.repartir([court, large], 2000.0)
	_check(xs[0] + court.size.x + PlacementPseudos.ECART <= xs[1],
		"deux lions à distance de contact (92 px) : le pseudo large reste sur le lion de droite, jamais basculé sur celui de gauche (%s)" % [xs])


## Phase 18 : le bilan de la manche, relevé par l'hôte au gong et envoyé à chaque client (format
## réseau), et ce que l'écran Résultats en tire : classement, parts, meneurs, les trois titres.
func _tester_bilan_manche() -> void:
	print("-- Bilan de la manche (phase 18)")
	var joueurs: Array[Joueur] = []
	for i in range(4):
		var j := Joueur.new()
		j.index = i
		j.reinitialiser(3)
		joueurs.append(j)
	joueurs[1].crans = 5
	joueurs[0].etourdissements_infliges = 3
	joueurs[2].etourdissements_infliges = 3
	joueurs[3].cellules_volees = 120
	joueurs[1].chocs = 7
	var etats: Dictionary[int, PackedByteArray] = {
		0: EtatLion.encoder(900, 0, Vector2(100.5, 200.25), Vector2(350, 0), Vector2.ZERO, 1),
		1: EtatLion.encoder(900, 42, Vector2(640, 300), Vector2.ZERO, Vector2(-80, 10), -1),
		3: EtatLion.encoder(880, 7, Vector2(1500, 410), Vector2.ZERO, Vector2.ZERO, 1)}
	var bilan := BilanManche.relever(joueurs, [300, 900, 300, 0] as Array[int], [3] as Array[int], etats, 90.004)
	_check(bilan.nb_joueurs() == 4 and bilan.cellules == [300, 900, 300, 0] and bilan.crans == [1, 5, 1, 1]
		and bilan.etourdissements == [3, 0, 3, 0] and bilan.volees == [0, 0, 0, 120] and bilan.chocs == [0, 7, 0, 0]
		and bilan.partis == [false, false, false, true] and bilan.lions.keys() == [0, 1] and is_equal_approx(bilan.temps, 90.004),
		"le bilan relève, par joueur, cellules, crans, statistiques de l'hôte et départ ; l'état final des lions encore là (pas celui d'un parti)")
	var recu := BilanManche.decoder(bilan.encoder(), 4)
	_check(recu != null and recu.resume() == bilan.resume() and recu.lions[1] == etats[1],
		"le bilan fait l'aller-retour du format réseau, états des lions compris (%s)" % ("" if recu == null else recu.resume()))
	_check(bilan.encoder()[2].size() == 2 * BilanManche.TAILLE_LION and bilan.resume().contains("L1@640.0,300.0,-1"),
		"deux lions de %d octets ; le résumé donne leur place et leur sens" % BilanManche.TAILLE_LION)
	var e: Array = bilan.encoder()
	var entiers_crans_nuls: PackedInt32Array = (e[1] as PackedInt32Array).duplicate()
	entiers_crans_nuls[1] = 0
	var lions_doubles: PackedByteArray = (e[2] as PackedByteArray).duplicate()
	lions_doubles.append_array((e[2] as PackedByteArray).slice(0, BilanManche.TAILLE_LION))
	var lion_parti: PackedByteArray = (e[2] as PackedByteArray).duplicate()
	lion_parti.append(3)
	lion_parti.append_array(etats[3])
	var lion_illisible: PackedByteArray = (e[2] as PackedByteArray).duplicate()
	lion_illisible[BilanManche.TAILLE_LION - 1] = 0  # l'orientation du premier lion : ni 1 ni -1
	var refuses: Array = [null, "bilan", [], [90.0, e[1]], [NAN, e[1], e[2]], [-1.0, e[1], e[2]], [90.0, e[1], e[2]].slice(0, 2),
		[90.0, (e[1] as PackedInt32Array).slice(1), e[2]], [90.0, entiers_crans_nuls, e[2]], [90.0, e[1], lions_doubles],
		[90.0, e[1], lion_parti], [90.0, e[1], lion_illisible], [90.0, e[1], (e[2] as PackedByteArray).slice(1)], [90, e[1], e[2]]]
	_check(refuses.all(func(r: Variant) -> bool: return BilanManche.decoder(r, 4) == null) and BilanManche.decoder(e, 3) == null,
		"un bilan mal formé est refusé : autre type, chrono non fini, négatif ou entier, champs manquants, crans nuls, lion en double, d'un parti, illisible ou tronqué, autre nombre de joueurs")
	_check(bilan.rangs() == [2, 1, 2, 0] and bilan.parts() == [20, 60, 20, 0] and bilan.meneurs() == [1],
		"rangs, parts et meneurs viennent des cellules du bilan (%s, %s)" % [bilan.rangs(), bilan.parts()])
	_check(bilan.classement() == [1, 0, 2, 3], "le classement : le plus de cellules d'abord, les ex æquo par index, sans cellule à la fin (%s)" % [bilan.classement()])
	_check(bilan.laureats(&"vicieux") == [0, 2] and bilan.record(&"vicieux") == 3 and bilan.laureats(&"voleur") == [3]
		and bilan.laureats(&"tamponneur") == [1] and bilan.record(&"tamponneur") == 7,
		"les trois titres : les ex æquo le partagent, un parti peut le porter (le voleur, parti)")
	var vide := BilanManche.relever(joueurs.slice(0, 2) as Array[Joueur], [0, 0] as Array[int], [] as Array[int], {} as Dictionary[int, PackedByteArray], 90.0)
	for j in joueurs:
		j.reinitialiser(3)
	var calme := BilanManche.relever(joueurs, [0, 0, 0, 0] as Array[int], [] as Array[int], {} as Dictionary[int, PackedByteArray], 90.0)
	_check(vide.meneurs().is_empty() and vide.parts() == [0, 0] and vide.classement() == [0, 1]
		and BilanManche.TITRES.all(func(t: StringName) -> bool: return calme.laureats(t).is_empty() and calme.record(t) == 0),
		"personne n'a peint : aucun meneur, 0 % partout ; personne n'a étourdi, volé ni percuté : aucun titre")


## Phase 18 : des manches enchaînées depuis l'écran Résultats ne se mélangent pas chez un client. Le
## lancement et le retour au salon partent sur le canal fiable ordonné de la manche (celui de ses
## tampons, de son territoire et de sa fin), avec leur table : une manche relancée n'arrive qu'après tout
## ce que la précédente y a envoyé. La table seule reste sur le canal 0, celui de la poignée de main. Et
## une réaction ou un départ de la manche précédente (canal 0) arrivé après le rechargement de la scène
## ne touche pas la manche neuve tant que sa barrière n'est pas passée.
func _tester_manches_enchainees() -> void:
	print("-- Manches enchaînées (phase 18)")
	var reseau: Node = root.get_node("Reseau")
	var rpc_reseau: Dictionary = reseau.get_script().get_rpc_config()
	var script_manche: Script = load("res://Scripts/Manche.gd")
	var rpc_manche: Dictionary = script_manche.get_rpc_config()
	var canal: int = rpc_manche[&"_recevoir_fin_manche"].get("channel", 0)
	_check(canal == reseau.CANAL_ORDONNE and canal != 0 and rpc_manche[&"_recevoir_tampons"].get("channel", 0) == canal
		and rpc_manche[&"_recevoir_territoire"].get("channel", 0) == canal
		and [&"_recevoir_manche", &"_recevoir_retour_salon"].all(func(m: StringName) -> bool: return rpc_reseau[m].get("channel", 0) == canal)
		and rpc_reseau[&"_recevoir_salon"].get("channel", 0) == 0,
		"le lancement et le retour au salon partent sur le canal des tampons, du territoire et de la fin (%d) ; la table seule, sur celui de la poignée de main (0)" % canal)
	# Ils portent leur table : un client la prend d'eux, même si la table du canal 0 ne les a pas précédés
	reseau.quitter()
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var table := [{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Moi", "pret": true},
		{"id": 5, "index": 1, "couleur": palette[3], "pseudo": "Bob", "pret": true}]
	var lancements: Array = []
	var sur_lancement := func(f: Array[Dictionary]) -> void: lancements.append(f)
	var retours := [0]
	var sur_retour := func() -> void: retours[0] += 1
	reseau.manche_lancee.connect(sur_lancement)
	reseau.salon_rouvert.connect(sur_retour)
	reseau._recevoir_manche(table, 2, 6, 0, 1)
	_check(lancements.size() == 1 and lancements[0].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 5] and reseau.niveau_salon == 2
		and reseau.niveau_manche == 2 and reseau.table_salon.size() == 2 and reseau.manche_en_cours and reseau.numero_table == 1,
		"le lancement pose sa table, son niveau et son numéro, puis lance la manche sur elle")
	reseau._recevoir_retour_salon(table, 1, 4, 0, 2)
	_check(retours[0] == 1 and not reseau.manche_en_cours and reseau.niveau_salon == 1 and reseau.places_salon == 4 and reseau.numero_table == 2,
		"le retour au salon pose sa table, son niveau et ses places, puis ramène au salon")
	# M6 (revue finale de la phase 18) : les deux canaux ne s'attendent pas ; une table plus ancienne que
	# la dernière posée n'est jamais reposée. Zoé arrive au salon rouvert (canal 0, table 4, une place
	# encore réservée) avant un retour au salon plus ancien, perdu puis renvoyé (canal ordonné, table 3).
	var avec_zoe := table + [{"id": 7, "index": 2, "couleur": palette[5], "pseudo": "Zoé", "pret": false}]
	reseau._recevoir_salon(avec_zoe, 1, 4, 1, 4)
	reseau._recevoir_retour_salon(table, 0, 6, 0, 3)
	_check(retours[0] == 2 and not reseau.manche_en_cours and reseau.table_salon.size() == 3 and reseau.places_reservees == 1
		and reseau.niveau_salon == 1 and reseau.places_salon == 4 and reseau.numero_table == 4,
		"M6 : un retour au salon plus ancien que la table posée ramène au salon sans la remplacer (Zoé reste, sa place réservée aussi)")
	reseau._recevoir_salon(table, 0, 6, 0, 3)
	reseau._recevoir_salon(avec_zoe, 1, 4, 0, "5")
	_check(reseau.table_salon.size() == 3 and reseau.places_reservees == 1 and reseau.numero_table == 4,
		"une table plus ancienne, ou sans numéro lisible, n'est pas posée")
	# Un lancement plus ancien que la table posée (Zoé partie pendant le chargement : table 6 sur le canal 0,
	# arrivée avant le lancement de la table 5) : la manche se joue sur la table et le niveau du lancement,
	# ceux de l'hôte ; la table plus récente reste posée.
	reseau._recevoir_salon(table, 1, 4, 0, 6)
	reseau._recevoir_manche(avec_zoe, 2, 4, 0, 5)
	_check(lancements.size() == 2 and lancements[1].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 5, 7] and reseau.niveau_manche == 2
		and reseau.niveau_salon == 1 and reseau.table_salon.size() == 2 and reseau.numero_table == 6 and reseau.manche_en_cours,
		"M6 : un lancement plus ancien que la table posée lance la manche sur sa propre table et son niveau, sans reposer la table")
	reseau.quitter()
	_check(reseau.numero_table == 0 and reseau.niveau_manche == 0, "hors session, plus de numéro de table ni de niveau de manche")
	# Chez l'hôte, chaque table diffusée a un numéro de plus
	reseau.ouvrir_salon(0)
	var premier: int = reseau.numero_table
	reseau.definir_niveau(1)
	_check(premier == 1 and reseau.numero_table == 2, "chez l'hôte, chaque table diffusée prend le numéro suivant (%d puis %d)" % [premier, reseau.numero_table])
	# Le lancement diffuse une table de plus et porte son numéro (M6) ; le niveau de la manche
	# (`Reseau.niveau_manche`) devient celui du salon au lancement
	var id_hote: int = root.multiplayer.get_unique_id()
	reseau.inscrits[id_hote] = {"index": 0, "couleur": palette[0], "pseudo": "Hôte", "arrive": true, "pret": true}
	reseau.inscrits[99] = {"index": 1, "couleur": palette[1], "pseudo": "Autre", "arrive": true, "pret": true}
	var avant_lancement: int = reseau.numero_table
	var niveau_salon_avant: int = reseau.niveau_salon
	_check(reseau.lancer_manche() and reseau.numero_table == avant_lancement + 1 and reseau.niveau_manche == niveau_salon_avant
		and lancements[-1].map(func(f: Dictionary) -> int: return f.id_reseau) == [id_hote, 99],
		"le lancement diffuse une table de plus (%d) et porte son numéro, le niveau de la manche est celui du salon" % reseau.numero_table)
	reseau.quitter()
	reseau.manche_lancee.disconnect(sur_lancement)
	reseau.salon_rouvert.disconnect(sur_retour)
	reseau.quitter()
	var gs: Node = root.get_node("GameState")
	gs.configurer_bataille(2)
	gs.nouvelle_partie()
	var manche: Node = script_manche.new()
	manche.actif = true
	manche._recevoir_crans(1, 4)
	manche._recevoir_depart(1)
	var departs := [0]
	manche.depart_vu.connect(func(_i: int) -> void: departs[0] += 1)
	manche._recevoir_depart(1)
	_check(gs.joueurs[1].crans == 1 and departs[0] == 0,
		"avant sa barrière, une manche neuve ignore les réactions et les départs d'une manche précédente arrivés en retard")
	manche.barriere = true
	manche._recevoir_crans(1, 4)
	manche._recevoir_depart(1)
	_check(gs.joueurs[1].crans == 4 and departs[0] == 1, "sa barrière passée, elle les applique")
	manche.free()
	gs.configurer_solo()
	gs.nouvelle_partie()
	gs.partie_en_cours = false


## Phase 19 (M7 de la revue de la phase 11) : `application/config/version` est aussi la version du
## protocole, présentée à la poignée de main et dans la balise ; deux postes de versions différentes se
## refusent (« Version différente de l'hôte »), deux postes de la même version doivent donc parler le même
## protocole. Son empreinte (`_signature_protocole`) change avec lui : une empreinte neuve sous la même
## version fait échouer ce test, jusqu'à ce que la version augmente et que PROTOCOLE_VERSION et
## PROTOCOLE_EMPREINTE la notent (la ligne PROTOCOLE de la sortie les donne).
func _tester_protocole() -> void:
	print("-- Version du protocole (phase 19)")
	var lignes := _signature_protocole()
	var empreinte := "\n".join(lignes).hash()
	var version: String = ProjectSettings.get_setting("application/config/version")
	print("PROTOCOLE %s %d (%d lignes)" % [version, empreinte, lignes.size()])
	if version != PROTOCOLE_VERSION:
		_check(false, "la version (%s) n'est plus celle que note ce test (%s) : noter ici la version et l'empreinte de la ligne PROTOCOLE" % [version, PROTOCOLE_VERSION])
	else:
		_check(empreinte == PROTOCOLE_EMPREINTE,
			"le protocole (RPC, réplication, formats réseau, balise) est celui de la version %s ; s'il a changé, augmenter application/config/version, puis noter ici la version et l'empreinte de la ligne PROTOCOLE" % version)


## Ce qui fait le protocole réseau, une ligne par élément, dans un ordre fixe : chaque RPC des scripts qui
## en déclarent (nom, nombre d'arguments, mode, transfert, appel local, canal), les propriétés répliquées
## des scènes (`MultiplayerSynchronizer`) et les scènes que fait apparaître la scène de jeu (`root_path`,
## `spawn_path`, les en-têtes `[node …]` des `MultiplayerSynchronizer` et `MultiplayerSpawner`, M9 de la
## revue finale : renommer un tel nœud ou changer son `spawn_path` doit faire échouer ce test), les
## tailles des formats réseau, et une balise de découverte.
func _signature_protocole() -> PackedStringArray:
	var lignes := PackedStringArray()
	for fichier in _fichiers_du_dossier("res://Scripts", ".gd"):
		var chemin := "res://Scripts".path_join(fichier)
		if not FileAccess.get_file_as_string(chemin).contains("@rpc"):
			continue
		var script: Script = load(chemin)
		var nb_arguments := {}
		for methode: Dictionary in script.get_script_method_list():
			nb_arguments[String(methode.name)] = methode.args.size()
		var config: Dictionary = script.get_rpc_config()
		var noms: Array[String] = []
		for nom: StringName in config:
			noms.append(String(nom))
		noms.sort()  # des String : un tri de StringName ne suit pas l'ordre alphabétique
		for nom in noms:
			var c: Dictionary = config[StringName(nom)]
			lignes.append("%s %s(%d) %s %s %s %s" % [fichier, nom, nb_arguments.get(nom, -1), c.get("rpc_mode"),
				c.get("transfer_mode"), c.get("call_local"), c.get("channel", 0)])
	for fichier in _fichiers_du_dossier("res://Scenes", ".tscn"):
		for ligne in FileAccess.get_file_as_string("res://Scenes".path_join(fichier)).split("\n"):
			if ligne.begins_with("properties/") or ligne.begins_with("_spawnable_scenes") \
					or ligne.begins_with("root_path") or ligne.begins_with("spawn_path") \
					or (ligne.begins_with("[node") and (ligne.contains("type=\"MultiplayerSynchronizer\"") or ligne.contains("type=\"MultiplayerSpawner\""))):
				lignes.append("%s %s" % [fichier, ligne.strip_edges()])
	lignes.append("formats %d %d %d %d %d %d %d %d" % [EtatLion.TAILLE, BilanManche.CHAMPS, BilanManche.TAILLE_LION,
		Commandes.TAILLE_ENTETE, Commandes.TAILLE_COMMANDE, Commandes.REDONDANCE, Peinture.OCTETS_PAR_TAMPON,
		Territoire.OCTETS_PAR_CHANGEMENT])
	lignes.append("balise " + load("res://Scripts/Decouverte.gd").encoder_balise("V", 1, 2, 3, true, 0, "P").get_string_from_utf8())
	return lignes


## Phase 1 du jeu en ligne : le transport ENet, seul (sans `Reseau` ni `SceneMultiplayer`) : son code,
## l'ouverture du canal, le délai d'un client sans hôte, la libération d'un pair figé (I1), le départ
## (DISCONNECT après la file, servi par `servir()`), la fermeture immédiate.
func _tester_transport_enet() -> void:
	print("-- Transport ENet (phase 1)")
	_check(TransportENet.lire_code(" 127.000.0.1 :17785") == {"ip": "127.0.0.1", "port": 17785}
		and TransportENet.lire_code("192.168.1.10") == {"ip": "192.168.1.10", "port": TransportENet.PORT},
		"un code ENet : une IPv4 normalisée et son port, ou le port par défaut")
	var mauvais := ["", "lelion.local:7777", "192.168.1:7777", "::1", "[::1]:7777", "127.0.0.1:", "127.0.0.1:0",
		"127.0.0.1:65536", "127.0.0.1:77a", "127.0.0.1:-5", "127.0.0.1:1:2", "0.0.0.0:7777"]
	_check(mauvais.all(func(c: String) -> bool: return TransportENet.lire_code(c).is_empty()),
		"refusés : un nom d'hôte, une IPv4 incomplète ou injoignable, une IPv6, un port vide, nul, trop grand ou non numérique")
	var refuse := TransportENet.new()
	_check(refuse.rejoindre("lelion.local") == ERR_INVALID_PARAMETER and refuse.pair() == null and not refuse.servir(),
		"un code refusé n'ouvre rien (aucune résolution de nom)")

	var port := 17785
	var hote := TransportENet.new(port, 2)
	var codes: Array[String] = []
	hote.pret.connect(func(code: String) -> void: codes.append(code))
	_check(hote.heberger() == OK and codes == ["127.0.0.1:%d" % port] and hote.pair() is ENetMultiplayerPeer and hote.servir(),
		"l'hôte ouvre sa session : « pret » part avec le code de ce poste (%s)" % [codes])
	var occupe := TransportENet.new(port, 2)
	_check(occupe.heberger() != OK and occupe.pair() == null, "un port déjà pris : l'erreur d'ENet, rien d'ouvert (ligne ERROR attendue)")
	var connectes: Array[int] = []
	var partis: Array[int] = []
	hote.pair().peer_connected.connect(func(id: int) -> void: connectes.append(id))
	hote.pair().peer_disconnected.connect(func(id: int) -> void: partis.append(id))

	var fige := TransportENet.new()
	var ouverts := [0]
	fige.connecte.connect(func() -> void: ouverts[0] += 1)
	_check(fige.rejoindre("127.0.0.1:%d" % port) == OK, "(pré-condition) un client part vers l'hôte")
	_check(_servir_transports([hote, fige], func() -> bool: return ouverts[0] == 1 and connectes.size() == 1, 2.0),
		"le canal s'ouvre : « connecte » chez le client, le pair chez l'hôte")
	# I1 : le client ne répond plus du tout (ni servi ni relevé) ; l'hôte le libère : il part sur-le-champ
	hote.liberer(connectes[0])
	_check(partis == [connectes[0]], "un pair libéré qui ne répond plus part pendant l'appel, sans accusé de réception (I1)")
	fige.clore()
	_check(fige.pair() == null and not fige.servir(), "clore() ferme tout de suite")

	var partant := TransportENet.new()
	partant.rejoindre("127.0.0.1:%d" % port)
	_check(_servir_transports([hote, partant], func() -> bool: return connectes.size() == 2, 2.0), "(pré-condition) un autre client est connecté")
	partant.quitter()
	_check(partant.servir() and partant.pair() != null, "quitter() : le départ part en arrière-plan, servi par servir()")
	var depart_a := Time.get_ticks_msec()
	_check(_servir_transports([hote, partant], func() -> bool: return partis.size() == 2 and partant.pair() == null, 1.5),
		"l'hôte reçoit le départ ; le client se ferme une fois le départ reçu (%d ms)" % (Time.get_ticks_msec() - depart_a))

	var seul := TransportENet.new()
	seul.delai_canal = 0.3
	var echecs: Array[String] = []
	seul.echec.connect(func(raison: String) -> void: echecs.append(raison))
	_check(seul.rejoindre("127.0.0.1:%d" % (port + 1)) == OK, "(pré-condition) un client part vers un port sans hôte")
	_servir_transports([seul], func() -> bool: return not echecs.is_empty(), 1.0)
	_check(echecs == [Transport.ECHEC_DELAI], "sans hôte : « echec » (délai du canal) (%s)" % [echecs])
	seul.quitter()
	var muet := TransportENet.new()
	muet.delai_canal = 0.1
	muet.echec.connect(func(raison: String) -> void: echecs.append(raison))
	muet.rejoindre("127.0.0.1:%d" % (port + 1))
	muet.quitter()
	_servir_transports([muet], func() -> bool: return false, 0.3)
	_check(echecs.size() == 1 and muet.pair() == null and seul.pair() == null,
		"quitter() pendant l'attente du canal : fermé aussitôt, plus aucun signal ensuite")
	hote.quitter()
	_check(not hote.servir() and hote.pair() == null, "un hôte sans client connecté se ferme aussitôt")


## Sert les transports `transports` (leur pair relevé, `servir()`) jusqu'à ce que `condition` soit
## vraie, `delai` secondes au plus ; renvoie sa dernière valeur.
func _servir_transports(transports: Array, condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		for t: Transport in transports:
			var p := t.pair()
			if p != null and p.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
				p.poll()
			t.servir()
		OS.delay_msec(5)
	return condition.call()


## Les fichiers du dossier `dossier` qui finissent par `suffixe`, triés.
func _fichiers_du_dossier(dossier: String, suffixe: String) -> PackedStringArray:
	var fichiers := PackedStringArray()
	for f in DirAccess.get_files_at(dossier):
		if f.ends_with(suffixe):
			fichiers.append(f)
	fichiers.sort()
	return fichiers


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
func _connecter(autre: ENetMultiplayerPeer, reseau: Node) -> bool:
	var tours_apres := -1
	for i in range(200):
		autre.poll()
		reseau.multiplayer.poll()
		if tours_apres < 0 and autre.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			tours_apres = 0
		if tours_apres >= 0:
			tours_apres += 1
			if tours_apres > 10:
				return true
		OS.delay_msec(5)
	return false
