extends SceneTree
## Banc de la prédiction du lion local (phase 16, spec §4.1 et §10), dans un seul processus :
##   godot --headless --fixed-fps 60 --script tests/prediction_test.gd
## Deux postes côte à côte, chacun dans son propre monde (une `SubViewport` de 2000×1125, dont la
## physique ne voit pas l'autre) : l'hôte (H0, le lion de son joueur ; H1, celui du client, qui applique
## les commandes reçues) et le client (C0, réplique interpolée de H0 ; C1, son lion, prédit, joué au
## clavier comme un joueur). Entre eux, des lignes à retard semées (`Ligne`), au tick près et
## reproductibles : les états de chaque lion de l'hôte (non fiables), les paquets de commandes du
## client (non fiables et non ordonnés, comme `unreliable` : un paquet plus ancien peut arriver après
## un plus récent sans être jeté, l'hôte comble les trous par numéro, pas par ordre d'arrivée,
## scénario 12), les réactions de l'hôte (fiables : retardées, renvoyées après une perte,
## jamais perdues ni mélangées). Latence (aller-retour), gigue (étendue de chaque aller) et pertes :
## celles du simulateur du test réseau (`tests/reseau/relais.gd`).
## Mesure l'erreur de prédiction (la position de l'hôte après chaque commande accusée, comparée à
## celle que le client avait prédite pour elle), les recalages, les à-coups de l'affichage, la
## convergence après l'arrêt des commandes, la régularité d'un lion distant ; vérifie qu'aucune
## commande n'est appliquée deux fois. Chaque scénario écrit sa ligne « MESURE ».
## Deux profils de lien (spec §5 du jeu en ligne) : le Wi-Fi du LAN (80 ms, 40 ms, 5 %), pour tous les
## scénarios, et le mobile en 4G (150 ms, 60 ms, 8 %, phase 6), pour le parcours, l'étourdissement et le
## choc : `InterpolationLion.RETARD` et les seuils de `PredictionLocale` ne se règlent que sur ces mesures.
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni `PredictionLocale`.

const TICK_MS := 1000.0 / 60.0
const PAS := 350.0 / 60.0  # px par tick à pleine vitesse
## Spec §4.1 et §10 : sans pertes, le lion prédit reste à moins de 4 px de l'hôte ; sous 80 ms, 40 ms
## et 5 %, l'écart converge sous 4 px en 150 ms (9 ticks) après l'arrêt des commandes.
const ECART_MAX := 4.0
const TICKS_CONVERGENCE := 9
## Au-delà, un saut de l'affichage d'un tick à l'autre (pleine vitesse, et moitié en plus) est un à-coup.
const A_COUP := PAS * 1.5
## Les profils de lien : latence (aller-retour, ms), gigue (ms), pertes (%), et ce que coûte au plus ce que
## le client ne peut pas prévoir : l'erreur de prédiction d'un étourdissement décidé par l'hôte (le lion
## court encore un aller-retour avant de l'apprendre : 30 px sous le Wi-Fi ; 60 px sous le mobile, mesuré
## 41,5 px, pour 63 px d'un aller-retour et d'une demi-gigue à pleine vitesse) et celle d'un choc contre un
## lion distant (ECART_MAX sous le Wi-Fi ; un à-coup, A_COUP, sous le mobile : mesuré 5,83 px, un pas).
const WIFI := {"nom": "80 ms, 40 ms de gigue, 5 % de pertes", "latence": 80.0, "gigue": 40.0, "pertes": 5.0,
	"erreur_etourdi": 30.0, "erreur_choc": ECART_MAX}
const MOBILE := {"nom": "mobile : 150 ms, 60 ms de gigue, 8 % de pertes", "latence": 150.0, "gigue": 60.0, "pertes": 8.0,
	"erreur_etourdi": 60.0, "erreur_choc": A_COUP}
## Le programme du joueur du client : `[ticks, direction]`, joué au clavier ; il passe par un bord
## (en haut, sous son pseudo).
const PROGRAMME: Array = [[30, Vector2.ZERO], [90, Vector2.RIGHT], [40, Vector2(1, 1)], [60, Vector2.LEFT],
	[20, Vector2.ZERO], [120, Vector2.UP], [45, Vector2(1, -1)], [90, Vector2(-1, 1)], [60, Vector2.DOWN]]

var _echecs := 0
var GS: Node
var _t := 0.0  # ms, temps du banc
var _tick := 0
var _vue_hote: SubViewport
var _vue_client: SubViewport
var _pair: ENetMultiplayerPeer
var h0: CharacterBody2D
var h1: CharacterBody2D
var c0: CharacterBody2D
var c1: CharacterBody2D
var _joueurs_client: Array[Joueur] = []
var _etats: Array[Ligne] = []
var _commandes: Ligne
var _reactions: Ligne
## Mesures du scénario en cours : sauts de l'affichage de C1, pas de C0 pendant la course de H0.
var _a_coups := 0
var _pas_c0: Array[float] = []
var _affiche_avant := Vector2.INF
var _c0_avant := Vector2.INF


## Une ligne à retard entre les deux postes : chaque message part avec un retard d'une demi-latence,
## plus ou moins une demi-gigue (tirée au hasard, semée : l'ordre d'arrivée peut changer), et se perd
## avec la probabilité `pertes` (%). Fiable : jamais perdu (une perte coûte un aller-retour de plus,
## le renvoi) et jamais doublé par un message plus récent. Ordonnée : un message qui arrive après un
## plus récent est jeté.
class Ligne:
	var rng := RandomNumberGenerator.new()
	var latence := 0.0
	var gigue := 0.0
	var pertes := 0.0
	var fiable := false
	var ordonnee := false
	var envoyes := 0
	var perdus := 0
	var _en_route: Array = []  # [arrivée (ms), numéro d'envoi, message]
	var _dernier_livre := 0
	var _derniere_arrivee := 0.0

	func _init(graine: int, latence_ms: float, gigue_ms: float, pertes_pc: float, est_fiable: bool, est_ordonnee: bool) -> void:
		rng.seed = graine
		latence = latence_ms
		gigue = gigue_ms
		pertes = pertes_pc
		fiable = est_fiable
		ordonnee = est_ordonnee

	func envoyer(message: Variant, maintenant: float) -> void:
		envoyes += 1
		var retard := latence / 2.0 + rng.randf_range(-gigue / 2.0, gigue / 2.0)
		if rng.randf() * 100.0 < pertes:
			perdus += 1
			if not fiable:
				return
			retard += latence  # le renvoi
		var arrivee := maintenant + retard
		if fiable:
			arrivee = maxf(arrivee, _derniere_arrivee)
			_derniere_arrivee = arrivee
		_en_route.append([arrivee, envoyes, message])

	func recevoir(maintenant: float) -> Array:
		var arrives := _en_route.filter(func(m: Array) -> bool: return m[0] <= maintenant)
		_en_route = _en_route.filter(func(m: Array) -> bool: return m[0] > maintenant)
		arrives.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var livres: Array = []
		for m: Array in arrives:
			if ordonnee and m[1] < _dernier_livre:
				continue
			_dernier_livre = maxi(_dernier_livre, m[1])
			livres.append(m[2])
		return livres


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _run() -> void:
	print("== banc de la prédiction LeLion ==")
	GS = root.get_node("GameState")
	await _scenario_parcours("lien parfait", 0.0, 0.0, 0.0)
	await _scenario_parcours(WIFI.nom, WIFI.latence, WIFI.gigue, WIFI.pertes)
	await _scenario_parcours(MOBILE.nom, MOBILE.latence, MOBILE.gigue, MOBILE.pertes)
	await _scenario_etourdissement(WIFI)
	await _scenario_etourdissement(MOBILE)
	await _scenario_choc(WIFI)
	await _scenario_choc(MOBILE)
	await _scenario_choc_pendant_correction()
	await _scenario_ecarts()
	await _scenario_hote_fige()
	await _scenario_fin_de_manche()
	await _scenario_journal()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## Phase 19 (M5 de la revue finale 16) : le journal des erreurs de prédiction est de l'instrumentation de
## test, tenue dans les builds de débogage seulement (les tests, l'éditeur) ; coupé (le jeu livré), il ne
## garde rien, et la prédiction ne change pas (états reçus, recalage, convergence).
func _scenario_journal() -> void:
	print("-- Journal de la prédiction coupé (le jeu livré)")
	_preparer(Vector2(300, 150), Vector2(400, 600), 80.0, 40.0, 5.0, 2100)
	var p: Node = c1.prediction
	_check(p.journal_actif == OS.is_debug_build() and p.journal_actif, "(pré-condition) les tests tournent en build de débogage : le journal y est tenu")
	p.journal_actif = false
	_presser(Vector2.RIGHT)
	for i in range(60):
		await _pas()
	_relacher()
	for i in range(30):
		await _pas()
	_check(p.etats_recus > 30 and p.etats_depuis(0) == 0 and p.erreur_max() == -1.0 and c1.position.distance_to(h1.position) < ECART_MAX,
		"journal coupé : %d états reçus, aucun gardé, et le lion du client rejoint celui de l'hôte (%.2f px)" % [p.etats_recus, c1.position.distance_to(h1.position)])
	await _liberer()


# --- Les deux postes ---------------------------------------------------------------------------------


## Les deux postes d'une partie à 2 : H0 et C0 partent de `depart0`, H1 et C1 de `depart1` ; les lignes
## à retard sous `latence` (ms, aller-retour), `gigue` (ms) et `pertes` (%), semées par `graine`.
func _preparer(depart0: Vector2, depart1: Vector2, latence: float, gigue: float, pertes: float, graine: int) -> void:
	GS.configurer_bataille(2)
	for i in range(2):
		GS.joueurs[i].pseudo = "Joueur %d" % (i + 1)
	GS.nouvelle_partie()
	GS.pret = true
	_t = 0.0
	_tick = 0
	_vue_hote = _vue("Hote")
	_vue_client = _vue("Client")
	# Le client : son propre pair (jamais connecté), comme la réplique du smoke test ; ses nœuds ne
	# sont pas l'hôte (`multiplayer.is_server()` faux).
	var api := SceneMultiplayer.new()
	_pair = ENetMultiplayerPeer.new()
	_check(_pair.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour le poste client")
	api.multiplayer_peer = _pair
	set_multiplayer(api, _vue_client.get_path())
	_joueurs_client.clear()
	for j: Joueur in GS.joueurs:
		var copie := Joueur.new()
		copie.index = j.index
		copie.pseudo = j.pseudo
		copie.couleur = j.couleur
		copie.reinitialiser(j.vies, j.couleurs_debloquees.duplicate())
		_joueurs_client.append(copie)
	h0 = _lion(_vue_hote, GS.joueurs[0], depart0, false)
	h1 = _lion(_vue_hote, GS.joueurs[1], depart1, false)
	c0 = _lion(_vue_client, _joueurs_client[0], depart0, false)
	c1 = _lion(_vue_client, _joueurs_client[1], depart1, true)
	_check(c1 != null and c1.get_node_or_null("Prediction") != null, "(pré-condition) le lion du client est prédit (PredictionLocale)")
	_etats = [Ligne.new(graine, latence, gigue, pertes, false, false), Ligne.new(graine + 1, latence, gigue, pertes, false, false)]
	# Non ordonnée (M3, revue finale phase 16) : le vrai canal (`unreliable`) ne jette pas un paquet
	# plus ancien arrivé après un plus récent, l'hôte comble les trous par numéro (`Commandes.recevoir`,
	# c838e01) ; le banc doit donc lui aussi laisser passer les paquets réordonnés par la gigue.
	_commandes = Ligne.new(graine + 2, latence, gigue, pertes, false, false)
	_reactions = Ligne.new(graine + 3, latence, gigue, pertes, true, false)
	for j: Joueur in GS.joueurs:
		j.etourdi.connect(func(origine: Vector2, barbouillage: Color) -> void:
			_reactions.envoyer(["etourdi", j.index, j.etourdi_restant, j.invulnerable_restant - j.etourdi_restant, origine, barbouillage], _t))
		j.etourdissement_fini.connect(func() -> void: _reactions.envoyer(["fin", j.index, j.invulnerable_restant], _t))
	_a_coups = 0
	_pas_c0.clear()
	_affiche_avant = Vector2.INF
	_c0_avant = Vector2.INF
	_relacher()


func _vue(nom: String) -> SubViewport:
	var vue := SubViewport.new()
	vue.name = "Poste" + nom
	vue.size = Vector2i(2000, 1125)
	vue.disable_3d = true
	root.add_child(vue)
	return vue


func _lion(vue: SubViewport, j: Joueur, depart: Vector2, predit: bool) -> CharacterBody2D:
	var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	l.joueur = j
	l.commandes = Commandes.manuelles()
	l.position = depart
	if predit:
		l.prediction = load("res://Scripts/PredictionLocale.gd").new()
	vue.add_child(l)
	return l


## La position affichée du lion `l` (phase 16) : son corps (la position prédite) plus le décalage
## d'affichage porté par `Lion.visuel`, jamais mêlés (revue de la Task 4: `PareChocs` ne doit voir que
## le corps). Égale à `l.position` pour un lion non prédit (décalage toujours nul).
static func _affiche(l: CharacterBody2D) -> Vector2:
	return l.position + l.visuel.position


func _liberer() -> void:
	_relacher()
	for j: Joueur in GS.joueurs:
		for s: Signal in [j.etourdi, j.etourdissement_fini]:
			for c: Dictionary in s.get_connections():
				if (c.callable as Callable).get_object() == self:
					s.disconnect(c.callable)
	set_multiplayer(null, _vue_client.get_path())
	_pair.close()
	_vue_hote.free()
	_vue_client.free()
	await physics_frame


## Un tick du banc, au début de l'image physique (avant la prédiction, à -10, et les lions) : chaque
## ligne livre ce qui arrive, puis part ce que chaque poste a produit au tick précédent (les états
## écrits par les lions de l'hôte, le paquet de la prédiction), comme le sondage réseau entre deux
## images physiques. Puis l'image physique suit.
func _pas() -> void:
	await physics_frame
	_tick += 1
	_t = _tick * TICK_MS
	for k in range(2):
		for octets: PackedByteArray in _etats[k].recevoir(_t):
			(c0 if k == 0 else c1).etat_reseau = octets
	for octets: PackedByteArray in _commandes.recevoir(_t):
		for c: Dictionary in Commandes.decoder_paquet(octets):
			h1.commandes.recevoir(c.numero, c.direction, c.vomir)
	for r: Array in _reactions.recevoir(_t):
		var j: Joueur = _joueurs_client[r[1]]
		if r[0] == "etourdi":
			j.etourdir(r[2], r[3], r[4], r[5])
		else:
			j.recevoir_fin_etourdissement(r[2])
	_etats[0].envoyer(h0.etat_reseau, _t)
	_etats[1].envoyer(h1.etat_reseau, _t)
	var paquet: PackedByteArray = c1.prediction.paquet()
	if not paquet.is_empty():
		_commandes.envoyer(paquet, _t)
	# Mesures : sauts de l'affichage du lion prédit, pas du lion distant
	if _affiche_avant.is_finite() and _affiche(c1).distance_to(_affiche_avant) > A_COUP + c1.deplacement.recul.length() / 60.0:
		_a_coups += 1
	_affiche_avant = _affiche(c1)
	if _c0_avant.is_finite():
		_pas_c0.append(c0.position.x - _c0_avant.x)
	_c0_avant = c0.position


func _presser(direction: Vector2) -> void:
	_basculer("deplacer_droite", direction.x > 0.0)
	_basculer("deplacer_gauche", direction.x < 0.0)
	_basculer("deplacer_bas", direction.y > 0.0)
	_basculer("deplacer_haut", direction.y < 0.0)


func _relacher() -> void:
	for action in ["deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas", "vomir"]:
		Input.action_release(action)


static func _basculer(action: String, appuyee: bool) -> void:
	if appuyee:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Le numéro de la première commande lue après cet appel.
func _prochain_numero() -> int:
	return c1.prediction.numero + 1


## Attend `ticks` ticks au repos, puis vérifie la convergence (spec §10) : les états qui accusent une
## commande lue au moins TICKS_CONVERGENCE ticks après `arret` (la première commande au repos) ont
## une erreur sous ECART_MAX, et le lion affiché est là où l'hôte a posé le sien.
func _verifier_convergence(titre: String, arret: int, ticks: int) -> void:
	for i in range(ticks):
		await _pas()
	var apres: float = c1.prediction.erreur_max(arret + TICKS_CONVERGENCE)
	_check(c1.prediction.etats_depuis(arret + TICKS_CONVERGENCE) > 0 and apres >= 0.0 and apres < ECART_MAX,
		"(%s) 150 ms après l'arrêt des commandes, l'erreur de prédiction reste sous %.0f px (au plus %.2f px)" % [titre, ECART_MAX, apres])
	_check(c1.position.distance_to(h1.position) < ECART_MAX and c1.prediction.decalage() == Vector2.ZERO,
		"(%s) au repos, le lion affiché du client est sur celui de l'hôte (%.2f px), sans décalage résiduel" % [titre, c1.position.distance_to(h1.position)])


## Aucune commande appliquée deux fois par l'hôte : chaque numéro jusqu'à la dernière appliquée l'est
## une fois ou est sauté, et les sautées restent rares (redondance). `rejouees` (M1, revue finale de la
## phase 16) fait vraiment échouer ce test si une commande était rejouée : l'égalité seule peut rester
## vraie même dans ce cas (`sautees` peut descendre au lieu de monter).
## I2 (revue finale phase 17, désync-report) : `sautees` reste la somme de `perdues` (jamais arrivées à
## temps, la vraie perte réseau) et `rattrapees` (délestées exprès par le rattrapage, pas une perte) ;
## seule `perdues` a un seuil (`perdues_max`), `rattrapees` n'est qu'une mesure rapportée à l'appelant.
func _verifier_commandes(titre: String, perdues_max: int) -> void:
	var c: Commandes = h1.commandes
	_check(c.rejouees == 0 and c.sautees >= 0 and c.appliquees + c.sautees == c.numero_applique
		and c.perdues <= perdues_max and c.numero_applique > 0,
		"(%s) aucune commande appliquée deux fois (%d rejouée(s)) : %d appliquées, %d perdues, %d rattrapées par le délestage volontaire (mesure), jusqu'à la %d (file au plus %d)"
		% [titre, c.rejouees, c.appliquees, c.perdues, c.rattrapees, c.numero_applique, c.file_max_vue])


# --- Scénarios ---------------------------------------------------------------------------------------


## Le programme du joueur du client, pendant que le lion de l'hôte file à pleine vitesse (le lion
## distant du client doit en montrer une course régulière), puis le repos.
func _scenario_parcours(titre: String, latence: float, gigue: float, pertes: float) -> void:
	print("-- Parcours : %s" % titre)
	_preparer(Vector2(300, 150), Vector2(900, 500), latence, gigue, pertes, 1600)
	var vomi_avant_hote := -1
	for segment: Array in PROGRAMME:
		_presser(segment[1])
		for i in range(segment[0]):
			h0.commandes.direction_voulue = Vector2.RIGHT if _tick >= 60 and _tick < 300 else Vector2.ZERO
			if _tick == 200:
				Input.action_press("vomir")
			await _pas()
			if _tick == 202:
				vomi_avant_hote = 1 if c1.est_en_train_de_vomir and (latence == 0.0 or not h1.est_en_train_de_vomir) else 0
			if _tick == 260:
				Input.action_release("vomir")
	_relacher()
	var arret := _prochain_numero()
	var p: Node = c1.prediction
	var etats: int = p.etats_depuis(1)
	var pas_c0 := _pas_c0.slice(110, 290)
	var pas_min: float = pas_c0.min()
	var pas_max: float = pas_c0.max()
	print("MESURE parcours (%s) : erreur max %.2f px, %d états sur %d au-delà de %.0f px, %d au-delà de 16 px ; recalages %d ; à-coups %d ; rejeu le plus long %d pas ; lion distant : %.2f à %.2f px par tick (%.2f) ; commandes sautées %d, file au plus %d"
		% [titre, p.erreur_max(), p.erreurs_au_dela(ECART_MAX), etats, ECART_MAX, p.erreurs_au_dela(16.0), p.recalages, _a_coups, p.rejeu_max,
			pas_min, pas_max, PAS, h1.commandes.sautees, h1.commandes.file_max_vue])
	if latence == 0.0:
		_check(p.erreur_max() < ECART_MAX and etats > 500,
			"(%s) sans latence ni pertes, le lion prédit reste à moins de %.0f px de l'hôte (au plus %.2f px sur %d états)" % [titre, ECART_MAX, p.erreur_max(), etats])
	else:
		_check(p.erreurs_au_dela(16.0) <= etats / 50 and p.erreur_max() < 30.0,
			"(%s) pendant la course, l'erreur de prédiction reste petite (au plus %.2f px ; %d états sur %d au-delà de 16 px)" % [titre, p.erreur_max(), p.erreurs_au_dela(16.0), etats])
	_check(p.recalages == 0 and _a_coups <= 3, "(%s) ni recalage ni à-coup visible (%d recalages, %d à-coups)" % [titre, p.recalages, _a_coups])
	_check(vomi_avant_hote == 1, "(%s) la gerbe du lion local part dès l'appui, sans attendre l'hôte" % titre)
	_check(pas_min > 0.7 * PAS and pas_max < 1.3 * PAS,
		"(%s) le lion distant (interpolé) court d'un pas régulier, sans recul ni saut (%.2f à %.2f px par tick, pour %.2f)" % [titre, pas_min, pas_max, PAS])
	await _verifier_convergence(titre, arret, 90)
	_verifier_commandes(titre, h1.commandes.numero_applique / 100)
	await _liberer()


## Un ennemi étourdit le lion du client chez l'hôte pendant qu'il court : la prédiction suit l'hôte
## (commandes ignorées, même règle que l'hôte), sans appliquer le recul deux fois, puis repart dès la
## fin de l'étourdissement reçue.
func _scenario_etourdissement(profil: Dictionary) -> void:
	print("-- Étourdissement décidé par l'hôte, sous %s" % profil.nom)
	_preparer(Vector2(300, 150), Vector2(400, 500), profil.latence, profil.gigue, profil.pertes, 1700)
	_presser(Vector2.RIGHT)
	var j_hote: Joueur = GS.joueurs[1]
	var j_client: Joueur = _joueurs_client[1]
	var tick_etourdi := -1
	var tick_fin := -1
	var repart := -1
	var bouge_etourdi := 0.0
	var x_etourdi := 0.0
	var recul_hote := 0.0
	var numero_suivi := -1
	var numero_fin := -1
	for i in range(420):
		if _tick == 60:
			GS.regles.lion_touche_par_ennemi(j_hote, h1.global_position + h1.CENTRE + Vector2(-80, 0))
			recul_hote = h1.deplacement.recul.x
		await _pas()
		if tick_etourdi < 0 and j_client.est_etourdi():
			tick_etourdi = _tick
			x_etourdi = _affiche(c1).x
		if tick_etourdi >= 0 and _tick == tick_etourdi + 2:
			numero_suivi = c1.prediction.numero
		if tick_etourdi >= 0 and tick_fin < 0 and j_client.est_etourdi():
			bouge_etourdi = _affiche(c1).x - x_etourdi
		if tick_etourdi >= 0 and tick_fin < 0 and not j_client.est_etourdi():
			tick_fin = _tick
			numero_fin = c1.prediction.numero
		if tick_fin >= 0 and repart < 0 and c1.deplacement.vitesse.x > 0.0:
			repart = _tick - tick_fin
	_relacher()
	var arret := _prochain_numero()
	var p: Node = c1.prediction
	# Les commandes lues pendant l'étourdissement connu de ce poste, sauf les 12 dernières : la fin de
	# l'étourdissement arrive ici avec un aller simple de retard, et l'hôte applique déjà les commandes
	# que ce poste croit encore ignorées (un écart attendu, qu'absorbe le recalage).
	var pendant: float = p.erreur_max(numero_suivi, numero_fin - 12)
	print("MESURE étourdissement (%s) : reçu au tick %d, fini au tick %d, recul de l'hôte %.0f px/s ; le lion du client recule de %.1f px pendant l'étourdissement ; erreur max %.2f px, %.2f px pendant l'étourdissement ; recalages %d ; à-coups %d"
		% [profil.nom, tick_etourdi, tick_fin, recul_hote, bouge_etourdi, p.erreur_max(), pendant, p.recalages, _a_coups])
	_check(tick_etourdi > 60 and tick_fin > tick_etourdi, "(pré-condition) l'étourdissement de l'hôte arrive au client, puis sa fin")
	# Le recul de l'hôte (700 px/s, amorti en 0,19 s) arrive dans ses états ; rejoué une seconde fois
	# par le client, ou ses commandes suivies malgré l'étourdissement, le lion prédit partirait devant.
	_check(numero_suivi > 0 and pendant >= 0.0 and pendant < ECART_MAX and p.recalages == 0 and p.erreur_max() < profil.erreur_etourdi,
		"(%s) étourdi, le lion du client suit l'hôte : un seul recul, ses commandes ignorées (erreur au plus %.2f px pendant l'étourdissement, %.2f px en tout, %.0f permis), sans recalage"
		% [profil.nom, pendant, p.erreur_max(), profil.erreur_etourdi])
	_check(repart >= 0 and repart <= 2, "(%s) la fin de l'étourdissement reçue, le lion repart aussitôt à ses commandes (%d tick(s))" % [profil.nom, repart])
	await _verifier_convergence("étourdissement, %s" % profil.nom, arret, 90)
	_verifier_commandes("étourdissement, %s" % profil.nom, h1.commandes.numero_applique / 100)
	await _liberer()


## Le lion du client percute celui de l'hôte, arrêté sur sa route : le choc est simulé tout de suite
## contre le lion affiché (interpolé), sans attendre l'hôte ; l'hôte le compte ; la prédiction converge.
func _scenario_choc(profil: Dictionary) -> void:
	print("-- Choc contre un lion distant, sous %s" % profil.nom)
	_preparer(Vector2(1200, 500), Vector2(700, 500), profil.latence, profil.gigue, profil.pertes, 1800)
	for i in range(30):
		await _pas()  # le lion distant s'affiche à sa place
	_presser(Vector2.RIGHT)
	var tick_client := -1
	var tick_hote := -1
	var arret := -1
	var x_min := INF
	var rebond := 0.0
	for i in range(150):
		await _pas()
		if tick_client < 0 and c1.deplacement.recul.x < 0.0:
			tick_client = _tick
			_relacher()  # le joueur lâche tout au choc : son lion repart en arrière, puis s'arrête
			arret = _prochain_numero()
		if tick_hote < 0 and h1.deplacement.recul.x < 0.0:
			tick_hote = _tick
		if tick_client >= 0:
			x_min = minf(x_min, _affiche(c1).x)
			rebond = maxf(rebond, _affiche(c1).x - x_min)
	var p: Node = c1.prediction
	print("MESURE choc (%s) : simulé chez le client au tick %d, chez l'hôte au tick %d ; erreur max %.2f px ; rebond de l'affichage %.2f px ; recalages %d ; à-coups %d"
		% [profil.nom, tick_client, tick_hote, p.erreur_max(), rebond, p.recalages, _a_coups])
	_check(tick_client > 0 and tick_hote > 0 and tick_client <= tick_hote and GS.joueurs[1].chocs >= 1,
		"(%s) le choc est simulé chez le client sans attendre l'hôte (tick %d, l'hôte au tick %d), et l'hôte le compte" % [profil.nom, tick_client, tick_hote])
	# Le lion repart en arrière et s'arrête, sans revenir vers le lion percuté : le choc simulé, noté,
	# est rejoué tant que l'hôte ne l'a pas (oublié, le lion reviendrait avant de repartir).
	_check(p.recalages == 0 and rebond < ECART_MAX and p.erreur_max() < profil.erreur_choc,
		"(%s) le choc ne fait ni recalage ni aller-retour visible (rebond de %.2f px ; erreur au plus %.2f px, %.2f permis)" % [profil.nom, rebond, p.erreur_max(), profil.erreur_choc])
	await _verifier_convergence("choc, %s" % profil.nom, arret, 90)
	await _liberer()


## Un choc simulé pendant une correction d'affichage (grand décalage, sous SEUIL_RECALAGE) : le
## pare-chocs du lion prédit ne doit réagir qu'à sa position prédite (le corps), jamais à ce qu'il
## affichait un instant avant un recalage (régression de la revue de la Task 4 : le décalage écrit dans
## `position` entre deux ticks laissait `PareChocs` voir l'affichage, pas la prédiction).
func _scenario_choc_pendant_correction() -> void:
	print("-- Choc simulé pendant une correction (grand décalage), sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(700, 500), Vector2(700, 800), 80.0, 40.0, 5.0, 2100)
	for i in range(30):
		await _pas()  # l'obstacle (C0, interpolé) affiché à sa place ; le lion local, loin, au repos
	# Le client croit un instant son lion tout près de l'obstacle (sous le seuil de contact du
	# pare-chocs) ; l'hôte, lui, le tient loin (écart sous SEUIL_RECALAGE : une correction douce, pas
	# un recalage d'un coup).
	var loin: Vector2 = c0.position + Vector2(0, 250.0)
	var pres: Vector2 = c0.position + Vector2(0, 70.0)
	c1.position = pres
	h1.global_position = loin
	var p: Node = c1.prediction
	var en_correction := false
	var avant_corps := Vector2.INF
	var pas_corps_max := 0.0
	var loin_min := INF
	for i in range(60):
		await _pas()
		if p.decalage().length() > 1.0:
			en_correction = true
		if en_correction:
			loin_min = minf(loin_min, c1.position.distance_to(c0.position))
			if avant_corps.is_finite():
				pas_corps_max = maxf(pas_corps_max, c1.position.distance_to(avant_corps))
			avant_corps = c1.position
	print("MESURE choc pendant correction : lion prédit à %.0f px au moins de l'obstacle une fois loin (jamais en contact) ; pas du corps au repos %.2f px au plus pendant la correction (décalage jusqu'à %.0f px)"
		% [loin_min, pas_corps_max, pres.distance_to(loin)])
	_check(en_correction and loin_min > 2.0 * c1.pare_chocs.rayon and pas_corps_max < 1.0,
		"pendant une correction (décalage jusqu'à %.0f px), le pare-chocs du lion prédit ne réagit qu'à sa position (le corps, loin de l'obstacle, %.0f px au moins, reste au repos, %.2f px au plus par tick)"
			% [pres.distance_to(loin), loin_min, pas_corps_max])
	await _liberer()


## L'hôte déplace le lion du client : de 60 px, le lion glisse jusqu'à lui en 100 à 150 ms
## (correction douce) ; de plus de 200 px (téléportation), il est recalé d'un coup, sans glisser.
func _scenario_ecarts() -> void:
	print("-- Écarts imposés par l'hôte (correction douce, recalage), sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(300, 150), Vector2(700, 600), 80.0, 40.0, 5.0, 1900)
	for i in range(30):
		await _pas()
	h1.global_position += Vector2(60, 0)
	var debut := -1
	var pas_max := 0.0
	var ecart_apres := -1.0
	for i in range(40):
		var avant: Vector2 = _affiche(c1)
		await _pas()
		var pas: float = _affiche(c1).distance_to(avant)
		if debut < 0 and pas > 0.0:
			debut = _tick
		pas_max = maxf(pas_max, pas)
		if debut >= 0 and _tick == debut + TICKS_CONVERGENCE:
			ecart_apres = _affiche(c1).distance_to(h1.position)
	print("MESURE écarts : 60 px résorbés en glissant, %.1f px au plus par tick, %.2f px restants 150 ms après" % [pas_max, ecart_apres])
	_check(c1.prediction.recalages == 0 and debut > 0 and pas_max < 30.0 and ecart_apres >= 0.0 and ecart_apres < ECART_MAX,
		"un écart de 60 px se résorbe en douceur : le lion glisse vers celui de l'hôte (%.1f px par tick au plus) et l'a rejoint 150 ms après (%.2f px)" % [pas_max, ecart_apres])
	h1.global_position += Vector2(500, -300)
	var saut := 0.0
	for i in range(30):
		var avant: Vector2 = _affiche(c1)
		await _pas()
		saut = maxf(saut, _affiche(c1).distance_to(avant))
	var p: Node = c1.prediction
	_check(p.recalages == 1 and saut > 500.0 and _affiche(c1).distance_to(h1.position) < ECART_MAX and p.decalage() == Vector2.ZERO,
		"au-delà de %.0f px, le lion est recalé d'un coup sur l'hôte (%d recalage, un saut de %.0f px), sans glisser jusqu'à lui" % [p.SEUIL_RECALAGE, p.recalages, saut])
	await _liberer()


## L'hôte se fige 2 s (gel, fin de manche) pendant que le client joue : aucun rejeu pendant le gel (le
## même état revient, jamais rejoué), un historique borné, puis un recalage franc sur l'hôte.
func _scenario_hote_fige() -> void:
	print("-- Hôte figé pendant que le client joue, sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(300, 150), Vector2(400, 600), 80.0, 40.0, 5.0, 2000)
	for i in range(30):
		await _pas()
	_vue_hote.process_mode = Node.PROCESS_MODE_DISABLED
	for i in range(10):
		await _pas()  # les derniers états d'avant le gel arrivent
	var etats_avant: int = c1.prediction.etats_recus
	var rejeu_avant: int = c1.prediction.rejeu_max
	_presser(Vector2.RIGHT)
	for i in range(110):
		await _pas()
	_relacher()
	var etats_pendant: int = c1.prediction.etats_recus - etats_avant
	for i in range(20):
		await _pas()
	_vue_hote.process_mode = Node.PROCESS_MODE_INHERIT
	var arret := _prochain_numero()
	await _verifier_convergence("hôte figé", arret, 60)
	var p: Node = c1.prediction
	print("MESURE hôte figé : %d états neufs pendant le gel, rejeu le plus long %d pas (avant le gel %d), %d recalage(s)"
		% [etats_pendant, p.rejeu_max, rejeu_avant, p.recalages])
	_check(etats_pendant == 0 and p.rejeu_max <= p.HISTORIQUE_MAX and p.recalages == 1,
		"pendant le gel, le même état ne se rejoue pas ; l'historique reste borné (%d pas au plus) ; au dégel, un recalage franc" % p.rejeu_max)
	_verifier_commandes("hôte figé", h1.commandes.numero_applique)
	await _liberer()


## Phase 18 (M5 de la revue finale 16) : le joueur du client tient encore sa touche au gong. L'hôte se
## fige (la fin de manche) ; sa fin arrive un aller plus tard avec l'état final de chaque lion (le bilan) :
## chaque lion du client prend celui de l'hôte, au pixel près, et le lion prédit ne bouge plus, la touche
## toujours tenue (sa prédiction s'arrête : plus de pas, plus de paquet, aucun décalage).
func _scenario_fin_de_manche() -> void:
	print("-- Fin de manche, la touche tenue au gong, sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(300, 150), Vector2(400, 600), 80.0, 40.0, 5.0, 1800)
	for i in range(30):
		await _pas()
	_presser(Vector2.RIGHT)
	for i in range(40):
		await _pas()
	_vue_hote.process_mode = Node.PROCESS_MODE_DISABLED  # le gong : tout se fige chez l'hôte
	var final0: PackedByteArray = h0.etat_reseau
	var final1: PackedByteArray = h1.etat_reseau
	for i in range(3):
		await _pas()  # la fin est en route (un aller) ; la touche est toujours tenue
	var avance: float = c1.position.x - h1.position.x
	_check(avance > ECART_MAX, "(pré-condition) la touche tenue, le lion prédit du client est parti devant celui de l'hôte figé (%.1f px)" % avance)
	_check(c0.poser_etat_final(final0) and c1.poser_etat_final(final1), "le bilan de la fin pose l'état final de l'hôte sur chaque lion du client")
	for i in range(30):
		await _pas()
	var p: Node = c1.prediction
	_check(c1.position == h1.position and _affiche(c1) == h1.position and p.arretee and p.decalage() == Vector2.ZERO and p.paquet().is_empty(),
		"la touche toujours tenue, le lion prédit reste sur l'état final de l'hôte, sans décalage ni paquet : la prédiction est arrêtée (%.2f px)"
			% c1.position.distance_to(h1.position))
	_check(c0.position == h0.position and c0.velocity == Vector2.ZERO, "le lion distant est sur celui de l'hôte, à l'arrêt (%.2f px)" % c0.position.distance_to(h0.position))
	_vue_hote.process_mode = Node.PROCESS_MODE_INHERIT
	await _liberer()
