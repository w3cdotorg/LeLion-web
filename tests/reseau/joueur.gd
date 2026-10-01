extends SceneTree
## Un poste du test réseau, lancé par tests/reseau/lancer.sh (un processus Godot par poste) :
##   godot --headless --script tests/reseau/joueur.gd -- --role=<rôle> [options]
## Rôles : hote, client, lent, salon-hote, salon-client, manche-hote, manche-client, manche-muet,
## bout-hote, bout-client, latence-hote, latence-client, chrono-hote, chrono-client.
## Communes : --port=N (défaut 17777), --pseudo=texte.
## Hôte : --places=N (joueurs, hôte compris ; défaut 6), --clients=N (clients qui doivent arriver),
##   --partants=N (clients qui repartiront d'eux-mêmes), --manche (manche en cours : tout nouveau
##   venu est refusé), --refus=N (poignées de main qui doivent échouer : demandes refusées, dont le
##   client ferme la connexion en lisant le refus, ou jamais finies, coupées par le délai ; l'hôte
##   les compte par `peer_authentication_failed` et reste ouvert jusqu'à la N-ième, DELAI_ETAPE au
##   plus), --delai-poignee=S (délai de poignée de main de cette session, en secondes, au lieu de
##   `Reseau.DELAI_POIGNEE_DE_MAIN`), --rester=chemin (une fois ses vérifications faites, écrit
##   « HOTE RESTE » et ne quitte le réseau qu'une fois ce fichier créé par lancer.sh, DELAI_ETAPE au
##   plus). Écrit « HOTE PRET » quand il écoute
##   et « POIGNEE ECHOUEE n » à chaque poignée de main échouée (n = leur compte, après que `Reseau` a
##   libéré la place), puis quitte le réseau (ses clients doivent voir l'hôte partir).
## Client : --attendu=inscrit|inscrit_ou_plein|refus_plein|refus_version|refus_manche|echec,
##   --version=x.y (se présente avec cette version au lieu de la sienne), --partir (une fois inscrit
##   et un autre client en vue dans la table de l'hôte, quitte de lui-même ; sinon, attend que
##   l'hôte parte), --feu=chemin
##   (écrit « ATTEND LE FEU » puis ne rejoint l'hôte qu'une fois ce fichier créé par lancer.sh,
##   DELAI_ETAPE au plus : le démarrage de Godot est déjà fait quand la demande doit partir). Écrit
##   une ligne « RESULTAT … » que lancer.sh compte d'un poste à l'autre. `refus_plein` est la
##   version déterministe d'`inscrit_ou_plein` (un seul dénouement possible, pas une course).
## Lent : présente sa demande sur sa propre poignée de main (son propre `ENetMultiplayerPeer` et
##   `SceneMultiplayer`, posé par `set_multiplayer` sur un nœud à lui : le `SceneTree` interroge
##   aussi ces API), mais n'appelle jamais `complete_auth` — sa poignée de main ne finit donc
##   jamais, et son propre délai de poignée de main est coupé (`auth_timeout` à 0) : seul l'hôte
##   peut y mettre fin. Écrit « ACCEPTE index=N » dès la réponse de l'hôte, puis attend que l'hôte
##   le coupe et vérifie que c'est au bout de --delai-poignee=S secondes (le délai de l'hôte ;
##   défaut `Reseau.DELAI_POIGNEE_DE_MAIN`). Preuve de bout en bout (Focus 2, Focus 5) que la place
##   d'un accepté est réservée dès la réponse et libérée par le vrai `auth_timeout` de l'hôte.
## Salon (phase 13), par les vraies scènes : l'écran En ligne (Créer une partie, ou Rejoindre avec le
##   code « 127.0.0.1:--port »), qui passe la main au salon, puis la scène de jeu. Chaque poste écrit
##   « SALON OUVERT » à l'ouverture de son salon, note la ligne d'état du salon après chaque
##   `salon_change` (vérifiée à la fin), et écrit « MANCHE <empreinte> » une fois la scène de jeu
##   chargée (identifiant, pseudo et couleur de chaque index de `GameState.joueurs`, puis le
##   niveau : la même sur tous les postes).
##   Salon-hôte : --clients=N (arrivées attendues), --partants=K (départs attendus), --niveau=L (le
##   niveau qu'il choisit, par haut/bas), --rester=chemin (comme l'hôte). Écrit « HOTE PRET » une
##   fois son salon ouvert, « SALON COMPLET » quand la table compte 1 + N - K joueurs, puis se
##   déclare prêt ; « BOUTON ACTIF » chaque fois que « Démarrer la partie » s'active. La première
##   fois, il attend qu'un client repasse non prêt (le bouton se regrise), essaie quand même de
##   démarrer (« DEMARRAGE REFUSE » : la manche ne part pas) ; la seconde, il démarre.
##   Salon-client : --voir=N (attend d'avoir vu la table compter N joueurs : « SALON VU N »), puis
##   --partir (quitte le salon par Retour : l'écran En ligne revient) ou --reste=M (attend que la
##   table compte M joueurs ; défaut 2), --couleur=S et --feu=chemin (« ATTEND LE FEU », puis
##   demande la couleur voisine dans le sens S au feu : « COULEUR <html> »), prêt ensuite ;
##   --annuler=chemin (une fois ce fichier créé, repasse non prêt : « PLUS PRET » ; puis se
##   redéclare prêt une fois --relance=chemin créé), --index=K (son index attendu dans la manche,
##   compactés compris). Vérifie à la fin avoir vu « l'hôte peut démarrer », puis attend le départ
##   de l'hôte.
## Manche (phase 14), par les vraies scènes jusqu'à la scène de jeu, puis une manche jouée au clavier
##   de chaque poste (actions pressées comme un joueur : `Input.action_press`).
##   Manche-hôte : --clients=N (arrivées attendues, le muet compris), --gel=S (fige son processus S
##   secondes dès sa scène de jeu chargée : ses clients, qui chargent, ne doivent pas le croire
##   parti), --delai-chargement=S (délai de la barrière), --rester=chemin, --mesurer-exclusion (I1,
##   revue finale phase 14 : chronomètre l'écart entre l'exclusion d'un absent et la barrière,
##   « ECART_EXCLUSION <ms> »). Écrit « HOTE PRET »,
##   « BARRIERE prets=… exclus=… », « DEPART VU », puis, une fois les lions arrêtés et les coulures
##   finies, fige la manche, lions au repos (`_figer_au_repos`) : « EMPREINTE <territoire, scores,
##   tampons, lions, apparitions> » et « FIGE ».
##   Manche-client : --sens=1|-1 (sa passe de peinture, vers la droite ou la gauche), --partir (quitte
##   la manche par le menu local une fois sa passe faite : « PARTI »), --fige=chemin (une fois ce
##   fichier créé par lancer.sh, attend ses coulures puis écrit sa propre « EMPREINTE »), puis attend
##   le départ de l'hôte (« L'hôte a quitté la partie », puis le titre).
##   Manche-muet : rejoint l'hôte sans scène (pas de salon ni de scène de jeu), se dit prêt, reçoit le
##   lancement de la manche mais ne charge jamais sa scène : l'hôte doit l'exclure après le délai de
##   la barrière (« EXCLU », avec la raison de la perte de l'hôte : exclu, phase 18). --figer=S (I1, revue finale phase 14) : dès le lancement de la manche
##   reçu, fige tout le processus S secondes (« FIGE_MUET ») avant de reprendre et sortir en 0, sans
##   rien vérifier lui-même : son ENet ne peut acquitter aucun DISCONNECT pendant ce temps, comme un
##   poste dont le fil principal compile ses shaders.
## Manche de bout en bout (phase 15), par les vraies scènes : 1 hôte + 3 clients jouent une manche
##   entière au clavier, chacun selon son programme (des commandes au hasard tirées de --graine=N,
##   voir `Programme`), sur le niveau --niveau=L choisi par l'hôte au salon ; chaque poste mesure sa
##   frame la plus longue (« MESURE ») et compte les réactions de chaque joueur reçues ou décidées.
##   Bout-hôte : --clients=N, --niveau=L, --duree=S (défaut : la manche entière,
##   `ReglesBataille.DUREE_MANCHE`), --tue=chemin, --rester=chemin. Après DEBUT_RENCONTRES s de jeu,
##   orchestre les rencontres (il ne décide que des lieux : il déplace des lions et fait apparaître
##   pastilles, étoile et soucoupe sur eux ; les effets passent par le jeu) : une pastille ramassée au
##   vol par chaque client, une étoile, une soucoupe, sa gerbe sur un client, la gerbe d'un client sur
##   lui, un choc. Écrit « RENCONTRES », puis désigne le client qui tient le plus de territoire et
##   écrit « A TUER <pseudo> » : lancer.sh arrache son poste (KILL, sans un paquet de plus) et crée
##   --tue ; l'hôte chronomètre la détection du départ (« ECART_DEPART <ms> ») et écrit « DEPART VU ».
##   À DUREE_CALME s de la fin, écrit « CALME » ; lions arrêtés, coulures finies et la manche arrivée
##   à son terme, il la fige, lions au repos :
##   « STATS … », « EMPREINTE … », « FIGE ».
##   Bout-client : --graine=N, --calme=chemin (joue son programme jusqu'à ce fichier, puis écrit
##   « CALME VU »), --fige=chemin (comme un client de la manche : sa propre « EMPREINTE »).
## Prédiction sous latence simulée (phase 16), par les vraies scènes : 1 hôte + 2 clients, les clients
##   passant par le relais de `tests/reseau/relais.gd` (leur --port est celui du relais), sur le niveau
##   --niveau=L choisi par l'hôte au salon.
##   Latence-hôte : --clients=N, --niveau=L, --duree=S, --rester=chemin. Reste immobile, écarte les
##   ennemis (la prédiction se mesure sur les commandes des joueurs ; un étourdissement est couvert par
##   `tests/prediction_test.gd`) ; à DUREE_CALME s de la fin, écrit « CALME » ; lions arrêtés, coulures
##   finies, la manche à son terme, il écrit pour chaque client « COMMANDES <pseudo> … » (aucune
##   commande appliquée deux fois, presque aucune sautée), fige la manche : « EMPREINTE … », « FIGE ».
##   Latence-client : --graine=N, --moitie=0|1 (sa moitié de la bande de peinture : les deux clients
##   ne se croisent pas), --calme=chemin (joue son programme jusqu'à ce fichier, puis lâche tout),
##   --fige=chemin. Une fois ses commandes d'après l'arrêt accusées par l'hôte, écrit « PREDICTION … »
##   (erreurs de prédiction, recalages, à-coups, plus long rejeu) et vérifie : aucun recalage, l'erreur
##   rarement au-delà de 16 px, sous 4 px 150 ms après l'arrêt ; puis sa propre « EMPREINTE ».
## Fin de manche au chrono (phase 17), résultats, revanche et retour au salon (phase 18), par les vraies
##   scènes : 1 hôte + 2 clients (derrière le relais), une manche courte de --duree-manche=S secondes
##   (`ReglesBataille.duree_manche`, sur chaque poste), sur le niveau --niveau=L choisi par l'hôte. Chaque
##   poste peint (--sens) sans lâcher ses touches jusqu'à la fin : chez l'hôte par son chrono, chez un
##   client par la fin reçue de l'hôte (son chrono pris sur celui de l'hôte : « ECART_CHRONO FIN <s> »,
##   l'écart qu'il avait) ; tout se fige, 0:00, les tics des dernières secondes comptés, l'écran
##   Résultats à la place du HUD ; « FIN <HUD, bilan, lions affichés> » et « RESULTATS FIN <écran> » (les
##   mêmes lignes sur chaque poste : les lions, lancés au gong, posés sur l'état final de l'hôte). Puis
##   l'hôte choisit Revanche au clavier : chaque poste recharge la scène de jeu (le même niveau, une manche
##   neuve de --duree-revanche=S secondes), qui finit de même (« FIN2 », « RESULTATS FIN2 ») ; le client
##   --quitte quitte l'écran Résultats par Échap (« QUITTE », le titre) ; les autres le voient partir
##   (« DEPART VU ») ; l'hôte choisit Retour au salon : chacun y revient, la même table sans le partant,
##   personne prêt (« SALON <table> », la même ligne) ; puis l'hôte quitte le salon et l'autre client
##   revient à l'écran En ligne, « L'hôte a quitté la partie ».
##   Chrono-hôte : --clients=N, --niveau=L, --duree-manche=S, --duree-revanche=S, --revanche=chemin
##   (choisit Revanche une fois ce fichier créé par lancer.sh), --salon=chemin (Retour au salon, de même),
##   --rester=chemin (quitte le salon, de même).
##   Chrono-client : --sens=1|-1, --duree-manche=S, --duree-revanche=S, --quitte=chemin (quitte le second
##   écran Résultats une fois ce fichier créé).
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
## `Reseau`, `GameState` et `Scores` par `root.get_node`, ne nomme ni `Reseau`, ni `GameState`, ni le
## salon (il peut nommer `EtatPartie`, dont le script ne nomme
## aucun autoload, `ReglesBataille` et `TransportENet`).

const DELAI_ETAPE := 15.0  # secondes au plus pour chaque attente
## Manche de bout en bout : secondes de jeu avant les rencontres, puis avant la fin où tout se calme.
const DEBUT_RENCONTRES := 20.0
const DUREE_CALME := 4.0
## Ticks physiques de l'hôte (500 ms) pendant lesquels chaque lion reste au repos avant que l'hôte fige
## la manche (`_figer_au_repos`) : bien plus que le retard d'affichage d'un lion distant chez un client
## (6 ticks) et la latence de localhost, même sous charge.
const TICKS_REPOS_AVANT_GEL := 30
## Prédiction sous latence : l'erreur de prédiction doit converger sous ECART_PREDICTION px en
## TICKS_CONVERGENCE ticks (150 ms) après l'arrêt des commandes (spec §10) ; au-delà d'A_COUP px d'une
## image physique à l'autre (pleine vitesse et moitié en plus), l'affichage du lion local saute.
const ECART_PREDICTION := 4.0
const TICKS_CONVERGENCE := 9
const A_COUP := 350.0 / 60.0 * 1.5
## Fin de manche au chrono : écart toléré entre le chrono de l'hôte et celui d'un client quand la fin y
## arrive, en secondes (la latence de l'intro et celle de la fin se compensent : reste la gigue du relais,
## 40 ms, et une image de chaque côté ; 0,25 s au départ). I2 (revue finale phase 17) : le scénario 13
## peint sans s'arrêter jusqu'au gong (des tampons et le territoire en vol au moment de la fin, sur le
## même canal fiable ordonné que la fin) : un tampon ou un changement de territoire perdu sous les 5 %
## de pertes simulées peut bloquer la fin derrière lui (canal ordonné) le temps d'une retransmission
## ENet (mesuré une fois à 0,332 s sous charge CPU) ; les scores restants identiques chez tous (« FIN »),
## seule cette marge purement latence a besoin d'être plus large qu'avant ce scénario plus réaliste.
const ECART_CHRONO := 0.6
## Vitesse (px/s) au-delà de laquelle un lion ramasse une pastille « au vol », ou percute l'hôte.
const VITESSE_AU_VOL := 150.0
const VITESSE_CHOC := 250.0
## Une pastille posée sur un lion n'est à lui que si aucun autre lion n'est à moins de cette distance
## (de centre à centre) : deux lions au contact la toucheraient tous les deux, premier arrivé, premier
## servi.
const ISOLEMENT := 200.0

var _echecs := 0
var _options := {}
var reseau: Node
var _arrivees: Array[int] = []
var _departs: Array[int] = []
var _poignees_echouees: Array[int] = []  # hôte : pairs dont la poignée de main a échoué, dans l'ordre
var _issue := ""  # client : les signaux reçus, dans l'ordre (voir `_ajouter_issue`)
var _raison := ""
var _version_hote := ""
var _index := -1
var _couleur := Color.TRANSPARENT
var _fiches_manche: Array[Dictionary] = []  # salon : les fiches reçues avec le lancement de la manche
## Salon : la taille de la table à chaque `salon_change` reçu, dans l'ordre. Une table à 4 joueurs
## qui ne dure qu'une image (un départ aussitôt après une arrivée) y reste, là où une attente qui
## relirait la table à chaque image pourrait la manquer.
var _tailles_vues: Array[int] = []
## Salon : la ligne d'état du salon notée après chaque `salon_change`, une fois l'affichage à jour.
var _textes_etat: Array[String] = []
## Manche de bout en bout : par index de joueur, les réactions vues sur ce poste depuis la barrière
## (`[étourdissements, crans, gerbes XXL]`, voir `_suivre_reactions`).
var _reactions: Dictionary[int, Array] = {}
## Manche de bout en bout : la frame la plus longue de ce poste (ms), de l'intro au calme, et la plus
## longue de celles qui ont généré des jeux de tampons (point de vigilance de la phase 15).
var _pire_frame_ms := 0.0
var _pire_frame_generation_ms := 0.0
var _instant_frame := 0
var _ville_mesuree: Node2D
var _jeux_vus := 0
var _jeux_generes := 0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var morceaux := arg.trim_prefix("--").split("=", true, 1)
		_options[morceaux[0]] = morceaux[1] if morceaux.size() > 1 else "oui"
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _option(nom: String, defaut: String) -> String:
	return _options.get(nom, defaut)


## Attend (au plus `delai` secondes, DELAI_ETAPE par défaut) que `condition` soit vraie ; renvoie sa
## dernière valeur.
func _attendre(condition: Callable, delai := DELAI_ETAPE) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		await process_frame
	return condition.call()


func _pause(secondes: float) -> void:
	await create_timer(secondes).timeout


func _run() -> void:
	# Textes attendus en français, quelle que soit la langue du système (la CI tourne en anglais).
	TranslationServer.set_locale("fr")
	reseau = root.get_node("Reseau")
	reseau.pseudo = _option("pseudo", "Poste")
	var role := _option("role", "")
	print("== poste réseau : %s (%s) ==" % [role, reseau.pseudo])
	if role == "hote":
		await _jouer_hote()
	elif role == "client":
		await _jouer_client()
	elif role == "lent":
		await _jouer_lent()
	elif role == "salon-hote" or role == "salon-client":
		await _jouer_salon(role == "salon-hote")
	elif role == "manche-hote" or role == "manche-client":
		await _jouer_manche(role == "manche-hote")
	elif role == "manche-muet":
		await _jouer_muet()
	elif role == "bout-hote" or role == "bout-client":
		await _jouer_bout(role == "bout-hote")
	elif role == "latence-hote" or role == "latence-client":
		await _jouer_latence(role == "latence-hote")
	elif role == "chrono-hote" or role == "chrono-client":
		await _jouer_chrono(role == "chrono-hote")
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, salon-hote, salon-client, manche-hote, manche-client, manche-muet, bout-hote, bout-client, latence-hote, latence-client, chrono-hote ou chrono-client")
	# Le départ de ce poste part en arrière-plan (le DISCONNECT de son transport ne part qu'une fois sa file
	# envoyée) : le processus ne sort qu'une fois le transport fermé (une seconde au plus), sans quoi
	# l'autre poste attendrait les 10 s du battement.
	_check(await _attendre(func() -> bool: return reseau._partants.is_empty(), 2.0), "le départ de ce poste est fini (son transport fermé)")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1,
		"à la fin, le poste est revenu hors réseau (pair hors ligne, hôte de lui-même, plus d'inscrits)")
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _jouer_hote() -> void:
	var nb_clients := int(_option("clients", "0"))
	var nb_partants := int(_option("partants", "0"))
	var nb_refus := int(_option("refus", "0"))
	reseau.places = int(_option("places", str(EtatPartie.NB_JOUEURS_MAX)))
	reseau.joueur_arrive.connect(_sur_arrivee)
	reseau.joueur_parti.connect(_sur_depart)
	# Branché après le gestionnaire de Reseau (connecté dans son _ready) : quand « POIGNEE ECHOUEE »
	# s'écrit, la place réservée est déjà libérée.
	root.multiplayer.peer_authentication_failed.connect(_sur_poignee_echouee)
	var erreur: int = reseau.heberger(int(_option("port", "17777")))
	_check(erreur == OK, "l'hôte écoute (erreur %d)" % erreur)
	if erreur != OK:
		return
	# manche_en_cours après heberger() : quitter() (que heberger() appelle en premier) le remet à
	# faux à chaque nouvelle session (I1).
	reseau.manche_en_cours = _options.has("manche")
	# heberger() vient de poser DELAI_POIGNEE_DE_MAIN sur l'API (avant toute poignée de main, avant
	# « HOTE PRET ») : c'est le vrai délai de poignée de main du jeu, couvert ici même quand
	# --delai-poignee l'écrase ensuite pour ce scénario (Scripts/Reseau.gd non touché).
	var api := root.multiplayer as SceneMultiplayer
	_check(api.auth_timeout == reseau.DELAI_POIGNEE_DE_MAIN and reseau.DELAI_POIGNEE_DE_MAIN > 0.0,
		"heberger() pose le délai de poignée de main du jeu (%.1f s)" % api.auth_timeout)
	if _options.has("delai-poignee"):
		# Après cette vérification et avant « HOTE PRET » : aucune poignée de main n'a commencé.
		# SceneMultiplayer relit auth_timeout à chaque image.
		api.auth_timeout = float(_option("delai-poignee", ""))
	print("HOTE PRET")
	var hote: Dictionary = reseau.inscrits[root.multiplayer.get_unique_id()]
	_check(root.multiplayer.is_server() and hote.index == 0 and hote.couleur == EtatPartie.PALETTE_BATAILLE[0]
		and hote.pseudo == reseau.pseudo, "l'hôte s'inscrit lui-même : index 0, première couleur, son pseudo")

	# Les poignées de main échouées d'abord : dans le scénario 5, l'arrivée attendue ne peut venir
	# qu'après la dernière (la place du client lent libérée par le délai). Les comptes ne font que
	# croître : l'ordre des attentes ne change rien aux autres scénarios.
	_check(await _attendre(func() -> bool: return _poignees_echouees.size() >= nb_refus),
		"%d poignée(s) de main échouée(s) sur %d attendue(s) (refus lus, ou délai dépassé)" % [_poignees_echouees.size(), nb_refus])
	_check(await _attendre(func() -> bool: return _arrivees.size() >= nb_clients),
		"%d client(s) arrivé(s) sur %d attendu(s)" % [_arrivees.size(), nb_clients])
	var indices: Array = reseau.inscrits.values().map(func(f: Dictionary) -> int: return f.index)
	var couleurs: Array = reseau.inscrits.values().map(func(f: Dictionary) -> Color: return f.couleur)
	indices.sort()
	var couleurs_distinctes := couleurs.all(func(c: Color) -> bool: return couleurs.count(c) == 1)
	var couleurs_de_la_palette := couleurs.all(func(c: Color) -> bool: return EtatPartie.PALETTE_BATAILLE.has(c))
	_check(indices == range(nb_clients + 1) and couleurs_distinctes and couleurs_de_la_palette,
		"les inscrits ont les index 0 à %d et chacun sa couleur de la palette (%s)" % [nb_clients, indices])

	if nb_partants > 0:
		_check(await _attendre(func() -> bool: return _departs.size() >= nb_partants),
			"%d client(s) parti(s) sur %d attendu(s)" % [_departs.size(), nb_partants])
		var libere: int = nb_clients + 1 - nb_partants
		_check(_departs.all(func(id: int) -> bool: return not reseau.inscrits.has(id)) and reseau.inscrits.size() == libere,
			"un client parti n'est plus inscrit (%d inscrits)" % reseau.inscrits.size())
		_check(reseau.premier_index_libre(reseau.inscrits, reseau.places) < nb_clients + 1,
			"son index est de nouveau libre")

	_check(_arrivees.size() == nb_clients and _poignees_echouees.size() == nb_refus,
		"ni arrivée ni poignée de main échouée de trop : %d client(s), %d échec(s) de poignée de main" % [_arrivees.size(), _poignees_echouees.size()])
	if _options.has("rester"):
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	print("ADIEU %d" % _horodatage())
	reseau.quitter()  # son départ s'achève en arrière-plan : `_run` l'attend avant de sortir


func _jouer_client() -> void:
	var attendu := _option("attendu", "inscrit")
	var version_projet: String = reseau.version
	if _options.has("version"):
		reseau.version = _option("version", "")
	reseau.inscrit.connect(_sur_inscription)
	reseau.refuse.connect(_sur_refus)
	reseau.connexion_echouee.connect(_ajouter_issue.bind("echec"))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	if _options.has("feu"):
		var feu := _option("feu", "")
		print("ATTEND LE FEU")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(feu)), "lancer.sh donne le feu (%s)" % feu)
	var debut := Time.get_ticks_msec()
	var erreur: int = reseau.rejoindre("127.0.0.1", int(_option("port", "17777")))
	_check(erreur == OK, "le client est créé (erreur %d)" % erreur)
	if erreur != OK:
		return
	await _attendre(func() -> bool: return not _issue.is_empty())
	var duree := (Time.get_ticks_msec() - debut) / 1000.0
	match _issue:
		"inscrit":
			print("RESULTAT inscrit index=%d" % _index)
		"refuse":
			print("RESULTAT refus %s" % _raison)
		_:
			print("RESULTAT %s" % _issue)

	match attendu:
		"inscrit", "inscrit_ou_plein":
			if attendu == "inscrit_ou_plein" and _issue == "refuse":
				_check(_raison == reseau.REFUS_PLEIN and _version_hote == version_projet,
					"refusé parce que la partie est pleine (%s)" % _raison)
				await _pause(1.0)
				_check(_issue == "refuse", "un refus n'est suivi d'aucun autre signal (%s)" % _issue)
				return
			_check(_issue == "inscrit" and _index >= 1 and _index < EtatPartie.NB_JOUEURS_MAX
				and _couleur == EtatPartie.PALETTE_BATAILLE[_index] and reseau.index_local == _index,
				"inscrit par l'hôte : index %d, couleur de la palette à cet index" % _index)
			if _issue != "inscrit":
				return
			if _options.has("partir"):
				# Sans relais du serveur (phase 14, M5), un client ne voit que l'hôte parmi ses pairs :
				# l'autre client est vu dans la table que l'hôte diffuse (hôte et deux clients).
				_check(await _attendre(func() -> bool: return reseau.table_salon.size() >= 3),
					"un autre client est en vue dans la table de l'hôte (%d joueurs)" % reseau.table_salon.size())
				await _pause(0.5)
				print("ADIEU %d" % _horodatage())
				reseau.quitter()
				_check(_issue == "inscrit", "partir de soi-même n'émet ni échec ni hôte perdu (%s)" % _issue)
			else:
				_check(await _attendre(func() -> bool: return _issue != "inscrit"), "l'hôte finit par partir")
				_check(_issue == "inscrit+hote_perdu", "le départ de l'hôte est signalé une fois, comme hôte perdu (%s)" % _issue)
		"refus_plein":
			_check(_issue == "refuse" and _raison == reseau.REFUS_PLEIN and _version_hote == version_projet,
				"refusé parce que la partie est pleine, sans course possible (%s, %s)" % [_raison, _issue])
			await _pause(1.0)
			_check(_issue == "refuse", "un refus n'est suivi d'aucun autre signal (%s)" % _issue)
		"refus_version", "refus_manche":
			var raison_attendue: String = reseau.REFUS_VERSION if attendu == "refus_version" else reseau.REFUS_MANCHE
			_check(_issue == "refuse" and _raison == raison_attendue and _version_hote == version_projet,
				"refusé avec la raison %s et la version de l'hôte %s (%s, %s)" % [raison_attendue, version_projet, _raison, _version_hote])
			await _pause(1.0)
			_check(_issue == "refuse", "un refus n'est suivi d'aucun autre signal (%s)" % _issue)
		"echec":
			_check(_issue == "echec" and duree >= TransportENet.DELAI_CANAL - 0.5 and duree <= TransportENet.DELAI_CANAL + 2.0,
				"sans hôte, la connexion échoue après le délai du canal de %.0f s (%.1f s)" % [TransportENet.DELAI_CANAL, duree])
		_:
			_check(false, "issue attendue inconnue : %s" % attendu)


## Rôle de test « lent » (I2, Focus 2 et 5) : une poignée de main qui ne finit jamais, sur sa propre
## API (jamais celle de `Reseau`, jamais nommée). Preuve de bout en bout que la place d'un accepté
## est réservée dès la réponse de l'hôte (pas à l'arrivée), et libérée par le vrai `auth_timeout`.
func _jouer_lent() -> void:
	var noeud := Node.new()
	root.add_child(noeud)
	var api := SceneMultiplayer.new()
	set_multiplayer(api, noeud.get_path())  # ce script est déjà le SceneTree
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_client("127.0.0.1", int(_option("port", "17777")))
	_check(erreur == OK, "le client lent est créé (erreur %d)" % erreur)
	if erreur == OK:
		var pseudo_lent: String = reseau.pseudo
		# Un Dictionary, pas un bool local : une lambda GDScript capture les variables locales par
		# valeur, pas par référence ; `etat.accepte` reste, lui, partagé avec `_attendre` ci-dessous.
		var etat := {"accepte": false}
		api.peer_authenticating.connect(func(id: int) -> void:
			api.send_auth(id, var_to_bytes({"jeu": reseau.JEU, "version": reseau.version, "pseudo": pseudo_lent})))
		api.auth_callback = func(_id: int, donnees: PackedByteArray) -> void:
			var reponse: Variant = bytes_to_var(donnees)
			if reponse is Dictionary and reponse.get("accepte") == true:
				etat.accepte = true
				print("ACCEPTE index=%d" % reponse.index)
			# Jamais de complete_auth ici : la poignée de main ne finit pas, exprès.
		# Son propre délai coupé (0 = aucun) : sinon ce poste abandonnerait lui-même la poignée de
		# main au bout de 3 s (le défaut de SceneMultiplayer), et la coupure ne prouverait plus rien
		# du délai de l'hôte.
		# Pris avant la connexion (le délai de l'hôte ne peut démarrer qu'après) : « duree >= delai »
		# est une borne exacte, sans tolérance.
		var accepte_a := Time.get_ticks_msec()
		api.auth_timeout = 0.0
		api.multiplayer_peer = pair
		_check(await _attendre(func() -> bool: return etat.accepte), "le client lent reçoit une acceptation, sans jamais finir sa poignée de main")
		if etat.accepte:
			var delai := float(_option("delai-poignee", str(reseau.DELAI_POIGNEE_DE_MAIN)))
			var coupe := await _attendre(func() -> bool: return pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED)
			var duree := (Time.get_ticks_msec() - accepte_a) / 1000.0
			print("COUPE apres=%.1f s" % duree)
			_check(coupe and duree >= delai,
				"l'hôte coupe le client lent au bout de son délai de poignée de main (%.1f s, attendu %.0f s)" % [duree, delai])
	pair.close()
	noeud.queue_free()


## Rôles « salon-hote » et « salon-client » (phase 13, voir l'en-tête) : un poste passe par l'écran
## En ligne et le salon comme un joueur, jusqu'à la scène de jeu.
func _jouer_salon(hote: bool) -> void:
	var scores: Node = root.get_node("Scores")
	var gs: Node = root.get_node("GameState")
	scores.chemin = "user://scores_reseau_%s.cfg" % reseau.pseudo  # jamais les préférences du joueur
	scores.effacer()
	reseau.salon_change.connect(func() -> void: _noter_etat.call_deferred())
	reseau.salon_change.connect(func() -> void: _tailles_vues.append(reseau.table_salon.size()))
	reseau.manche_lancee.connect(func(fiches: Array[Dictionary]) -> void: _fiches_manche.assign(fiches))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	await _ouvrir_la_partie(hote)
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran En ligne passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return
	var salon: Node = current_scene
	print("SALON OUVERT")
	if hote:
		await _animer_salon_hote(salon, gs)
	else:
		if not await _animer_salon_client(salon):
			scores.effacer()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))
			return
	# La scène de jeu, chargée par le salon sur chaque poste, avec la même table des joueurs
	_check(await _attendre(func() -> bool: return _scene_est("Main")), "le salon charge la scène de jeu")
	var empreinte := ";".join(gs.joueurs.map(func(j: Joueur) -> String: return "%d:%s:%s" % [j.id_reseau, j.pseudo, j.couleur.to_html(false)]))
	var attendues := ";".join(_fiches_manche.map(func(f: Dictionary) -> String: return "%d:%s:%s" % [f.id_reseau, f.pseudo, f.couleur.to_html(false)]))
	var moi: Joueur = gs.joueur_local()
	_check(gs.regles is ReglesBataille and gs.joueurs.size() == _fiches_manche.size() and empreinte == attendues
		and gs.joueurs.map(func(j: Joueur) -> int: return j.index) == range(gs.joueurs.size()),
		"règles de bataille et un joueur par fiche reçue, index 0..n-1, identifiants, pseudos et couleurs de l'hôte (%s)" % empreinte)
	_check(moi.id_reseau == root.multiplayer.get_unique_id() and moi.index == reseau.index_local and moi.couleur == reseau.couleur_locale
		and gs.joueurs[0].id_reseau == 1 and root.content_scale_size == Vector2i(ReglesBataille.TAILLE_ECRAN),
		"le joueur local est celui de ce poste (index %d), l'index 0 celui de l'hôte, écran 16:9" % moi.index)
	if _options.has("index"):
		_check(moi.index == int(_option("index", "")), "index compacté attendu : %s (%d)" % [_option("index", ""), moi.index])
	_check(gs.niveau_courant == int(_option("niveau", str(gs.niveau_courant))), "le niveau choisi au salon (%d)" % gs.niveau_courant)
	print("MANCHE %s|%d" % [empreinte, gs.niveau_courant])
	if hote:
		_check(_textes_etat.has(tr("SALON_ATTENTE_PRETS")) and _textes_etat.has(tr("SALON_PRET_A_DEMARRER")),
			"l'hôte a vu pourquoi le bouton était grisé, puis « tu peux démarrer la partie »")
		_check(reseau.manche_en_cours, "manche lancée : l'hôte refuse désormais tout nouveau venu")
		if _options.has("rester"):
			var rester := _option("rester", "")
			print("HOTE RESTE")
			_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
		reseau.quitter()
	else:
		_check(_textes_etat.has(tr("SALON_ATTENTE_HOTE")), "un client a vu « Tout le monde est prêt : l'hôte peut démarrer. »")
		_check(await _attendre(func() -> bool: return _issue.ends_with("hote_perdu")), "l'hôte finit par partir")
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))


func _animer_salon_hote(salon: Node, gs: Node) -> void:
	var niveau := int(_option("niveau", "0"))
	while reseau.niveau_salon != niveau:
		salon.changer_niveau(1)
	_check(gs.niveau_courant == niveau, "le niveau choisi au salon devient celui de la partie (%d)" % niveau)
	print("HOTE PRET")
	var nb_clients := int(_option("clients", "0"))
	var nb_partants := int(_option("partants", "0"))
	reseau.joueur_arrive.connect(_sur_arrivee)
	reseau.joueur_parti.connect(_sur_depart)
	var complet := func() -> bool:
		return _arrivees.size() >= nb_clients and _departs.size() >= nb_partants and reseau.table_salon.size() == 1 + nb_clients - nb_partants
	_check(await _attendre(complet),
		"%d arrivée(s), %d départ(s) : la table compte %d joueurs" % [_arrivees.size(), _departs.size(), reseau.table_salon.size()])
	print("SALON COMPLET")
	salon.basculer_pret()
	var bouton: Button = salon.bouton_demarrer
	_check(await _attendre(func() -> bool: return not bouton.disabled), "tous prêts : « Démarrer la partie » s'active")
	print("BOUTON ACTIF")
	_check(await _attendre(func() -> bool: return bouton.disabled), "un client repasse non prêt : le bouton se regrise")
	salon.demarrer()
	_check(not reseau.manche_en_cours and _scene_est("Salon"), "démarrer quand même est refusé : la manche ne part pas")
	print("DEMARRAGE REFUSE")
	_check(await _attendre(func() -> bool: return not bouton.disabled), "de nouveau tous prêts : le bouton revient")
	print("BOUTON ACTIF")
	salon.demarrer()


## Renvoie faux si ce poste quitte le salon avant la manche (--partir).
func _animer_salon_client(salon: Node) -> bool:
	if _options.has("voir"):
		var voir := int(_option("voir", ""))
		_check(await _attendre(func() -> bool: return _tailles_vues.has(voir)), "la table du salon a compté %d joueurs (%s)" % [voir, _tailles_vues])
		print("SALON VU %d" % voir)
	if _options.has("partir"):
		salon.retour()
		_check(await _attendre(func() -> bool: return _scene_est("EcranEnLigne")) and not reseau.en_ligne(),
			"Retour quitte le réseau et ramène à l'écran En ligne")
		return false
	var reste := int(_option("reste", "2"))
	_check(await _attendre(func() -> bool: return reseau.table_salon.size() == reste), "la table compte %d joueurs (%s)" % [reste, _tailles_vues])
	print("SALON VU %d" % reste)
	if _options.has("feu"):
		var avant: Color = reseau.couleur_locale
		print("ATTEND LE FEU")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("feu", ""))), "lancer.sh donne le feu")
		salon.changer_couleur(int(_option("couleur", "1")))
		_check(await _attendre(func() -> bool: return reseau.couleur_locale != avant), "l'hôte change la couleur de ce poste")
		var couleurs: Array = reseau.table_salon.map(func(f: Dictionary) -> Color: return f.couleur)
		_check(couleurs.all(func(c: Color) -> bool: return couleurs.count(c) == 1), "chacun garde une couleur à lui (%s)" % [couleurs])
		print("COULEUR %s" % reseau.couleur_locale.to_html(false))
	salon.basculer_pret()
	if _options.has("annuler"):
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("annuler", ""))), "lancer.sh demande de repasser non prêt")
		salon.basculer_pret()
		_check(await _attendre(func() -> bool: return not _ma_fiche_pret()), "l'hôte enregistre ce poste non prêt")
		print("PLUS PRET")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("relance", ""))), "lancer.sh relance (%s)" % _option("relance", ""))
		salon.basculer_pret()
	return true


## L'écran En ligne, puis Créer une partie (l'hôte, ENet sur --port) ou Rejoindre avec le code
## « 127.0.0.1:--port » (un client), comme un joueur.
func _ouvrir_la_partie(hote: bool) -> void:
	change_scene_to_file("res://Scenes/EcranEnLigne.tscn")
	_check(await _attendre(func() -> bool: return _scene_est("EcranEnLigne")), "l'écran En ligne s'ouvre")
	if not _scene_est("EcranEnLigne"):
		return
	var ecran: Node = current_scene
	ecran.port_jeu = int(_option("port", "17777"))
	ecran.champ_pseudo.text = reseau.pseudo
	if hote:
		ecran.creer_partie()
	else:
		ecran.champ_code.text = "127.0.0.1:%d" % ecran.port_jeu
		ecran.rejoindre()


func _scene_est(nom: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://Scenes/%s.tscn" % nom and current_scene.is_node_ready()


## Appelé en différé après chaque `salon_change` : le salon a déjà mis sa ligne d'état à jour.
func _noter_etat() -> void:
	if _scene_est("Salon"):
		_textes_etat.append(current_scene.etat.text)


## Vrai si la table du salon dit ce poste prêt.
func _ma_fiche_pret() -> bool:
	for fiche: Dictionary in reseau.table_salon:
		if fiche.id == root.multiplayer.get_unique_id():
			return fiche.pret
	return false


func _sur_arrivee(id: int) -> void:
	_arrivees.append(id)
	var fiche: Dictionary = reseau.inscrits[id]
	print("  arrivée de %d : index %d, « %s »" % [id, fiche.index, fiche.pseudo])


func _sur_depart(id: int) -> void:
	_departs.append(id)
	print("DEPART_RECU %d" % _horodatage())


func _sur_poignee_echouee(id: int) -> void:
	_poignees_echouees.append(id)
	print("POIGNEE ECHOUEE %d (pair %d)" % [_poignees_echouees.size(), id])


func _sur_inscription(index: int, couleur: Color) -> void:
	_ajouter_issue("inscrit")
	_index = index
	_couleur = couleur


func _sur_refus(raison: String, version_hote: String) -> void:
	_ajouter_issue("refuse")
	_raison = raison
	_version_hote = version_hote


## Chaque signal reçu s'ajoute à l'issue : « inscrit+hote_perdu » est le parcours normal d'un
## client qui reste ; « refuse+echec » trahirait un double signal.
func _ajouter_issue(quoi: String) -> void:
	_issue = quoi if _issue.is_empty() else _issue + "+" + quoi
	if quoi == "hote_perdu":
		print("HOTE_PERDU_RECU %d" % _horodatage())


## L'heure de l'horloge du système, en ms : la même pour tous les postes de ce PC (lancer.sh compare les
## horodatages de deux journaux).
func _horodatage() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)



## Rôles « manche-hote » et « manche-client » (phase 14, voir l'en-tête) : du salon à une manche
## jouée, jusqu'au départ de l'hôte.
func _jouer_manche(hote: bool) -> void:
	var main := await _rejoindre_la_manche(hote)
	if main == null:
		return
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
	if hote and _options.has("gel"):
		# Tout le processus se fige, comme un hôte qui charge ou compile ses shaders : ses clients
		# chargent pendant ce temps, et leurs « scène chargée » l'attendent.
		print("GEL")
		OS.delay_msec(int(float(_option("gel", "0")) * 1000.0))
	# I1 (revue finale phase 14) : avec --mesurer-exclusion, l'hôte chronomètre lui-même l'écart
	# entre l'exclusion d'un absent et la barrière qui passe (ECART_EXCLUSION, en ms) : le
	# correctif d'`_exclure` doit le tenir bien sous le silence de chargement par défaut.
	var mesurer_exclusion := hote and _options.has("mesurer-exclusion")
	var ticks_exclu := -1
	if mesurer_exclusion:
		_check(await _attendre(func() -> bool: return not manche._exclus.is_empty()), "(I1) un poste est exclu de la barrière")
		ticks_exclu = Time.get_ticks_msec()
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	if mesurer_exclusion and ticks_exclu >= 0:
		var ecart_exclusion := Time.get_ticks_msec() - ticks_exclu
		# lancer.sh arrête ce poste dès la mesure écrite (scénario 10) : ses scores de test s'effacent avant.
		_effacer_scores()
		print("ECART_EXCLUSION %d" % ecart_exclusion)
	_check(_issue.is_empty(), "personne ne s'est cru abandonné pendant le chargement (%s)" % _issue)
	if hote:
		var exclus: Array = manche._exclus
		print("BARRIERE prets=%s exclus=%s" % [manche._prets, exclus])
		_check(manche._prets.size() == int(_option("clients", "0")) - 1 and exclus.size() == 1,
			"les clients chargés sont prêts, le muet est exclu (%s, %s)" % [manche._prets, exclus])
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1), "un lion par joueur resté (%d)" % main.lions.size())
	var moi: Joueur = gs.joueur_local()
	var lion_local_ok: bool = main.lion != null and main.lion.joueur == moi and (
		main.lion.commandes.source == Commandes.Source.LOCALES and main.lion.prediction == null if hote
		else main.lion.commandes.source == Commandes.Source.MANUELLES and main.lion.prediction != null)
	_check(lion_local_ok and main.lions.all(func(l: Node) -> bool:
			return l == main.lion or (l.commandes.source == Commandes.Source.MANUELLES and l.prediction == null)),
		"le lion de ce poste lit ses commandes (hôte) ou les prédit (client, phase 16) ; les autres ont des commandes manuelles")
	if not hote:
		_check(root.multiplayer.get_peers() == PackedInt32Array([1]) and not root.multiplayer.is_server(),
			"sans relais du serveur, un client ne voit que l'hôte parmi ses pairs (%s)" % [root.multiplayer.get_peers()])
	_check(await _attendre(func() -> bool: return gs.pret), "l'intro se termine chez tous")
	print("INTRO")
	await _jouer_passe(main, int(_option("sens", "1")))
	if hote:
		await _finir_manche_hote(main, manche, gs)
	elif _options.has("partir"):
		main.get_node("PauseMenu").ouvrir()
		await _pause(0.3)
		_check(main.lion.commandes.suspendues and not paused, "le menu local suspend les commandes sans mettre la partie en pause")
		main.get_node("PauseMenu")._on_menu_pressed()  # « Quitter la partie »
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not reseau.en_ligne(), "quitter la partie ramène au titre, hors réseau")
		print("PARTI")
	else:
		await _finir_manche_client(main, manche)
	_effacer_scores()


## Du salon à la scène de jeu d'une manche (rôles « manche-… » et « bout-… »), par les vraies scènes :
## l'écran En ligne (`_ouvrir_la_partie`), le salon (l'hôte y choisit
## --niveau, attend 1 + --clients joueurs et démarre quand tous sont prêts), puis la scène de jeu.
## Renvoie la scène de jeu, ou null si ce poste n'y arrive pas (il a alors quitté le réseau).
func _rejoindre_la_manche(hote: bool) -> Node:
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_reseau_%s.cfg" % reseau.pseudo  # jamais les préférences du joueur
	scores.effacer()
	var script_manche: Script = load("res://Scripts/Manche.gd")
	script_manche.delai_chargement = float(_option("delai-chargement", str(script_manche.DELAI_CHARGEMENT)))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	reseau.joueur_parti.connect(_sur_depart)
	await _ouvrir_la_partie(hote)
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran En ligne passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return null
	var salon: Node = current_scene
	if hote:
		var niveau := int(_option("niveau", "0"))
		while reseau.niveau_salon != niveau:
			salon.changer_niveau(1)
		print("HOTE PRET")
		var nb := 1 + int(_option("clients", "0"))
		_check(await _attendre(func() -> bool: return reseau.table_salon.size() == nb), "%d joueurs au salon" % nb)
		salon.basculer_pret()
		var bouton: Button = salon.bouton_demarrer
		_check(await _attendre(func() -> bool: return not bouton.disabled), "tous prêts : « Démarrer la partie » s'active")
		salon.demarrer()
	else:
		# Se déclarer prêt une fois à la table seulement : avant que la table de l'hôte arrive, le salon
		# n'a pas la fiche de ce poste et `basculer_pret` ne fait rien (vu une fois sur dix, 3 clients).
		var ma_fiche := func() -> bool:
			return reseau.table_salon.any(func(f: Dictionary) -> bool: return f.id == root.multiplayer.get_unique_id())
		_check(await _attendre(ma_fiche), "ce poste est à la table du salon")
		salon.basculer_pret()
		_check(await _attendre(_ma_fiche_pret), "l'hôte enregistre ce poste prêt")
	_check(await _attendre(func() -> bool: return _scene_est("Main")), "le salon charge la scène de jeu")
	if not _scene_est("Main"):
		reseau.quitter()
		return null
	return current_scene


## Les scores de test de ce poste (`_rejoindre_la_manche`) : effacés, fichier compris.
func _effacer_scores() -> void:
	var scores: Node = root.get_node("Scores")
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))


## La passe de ce poste : descendre jusqu'à la hauteur de peinture (celle du pilote de la démo, 233 px
## au-dessus des toits ; la position du lion de ce poste est celle que l'hôte lui renvoie), puis
## peindre la ville en allant dans le sens `sens`.
func _jouer_passe(main: Node, sens: int) -> void:
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - 233.0
	Input.action_press("deplacer_bas")
	_check(await _attendre(func() -> bool: return main.lion.position.y >= cible), "le lion de ce poste descend vers la ville (%.0f)" % main.lion.position.y)
	Input.action_release("deplacer_bas")
	var action := "deplacer_droite" if sens > 0 else "deplacer_gauche"
	Input.action_press(action)
	Input.action_press("vomir")
	var pire := 0.0
	var fin := Time.get_ticks_msec() + 2500
	var avant := Time.get_ticks_msec()
	while Time.get_ticks_msec() < fin:
		await process_frame
		pire = maxf(pire, Time.get_ticks_msec() - avant)
		avant = Time.get_ticks_msec()
	Input.action_release(action)
	Input.action_release("vomir")
	print("MESURE %s : %d jeux de tampons en cache, frame la plus longue %.0f ms pendant la passe" % [reseau.pseudo, main.get_node("Ville")._tampons.size(), pire])


## Comme `_jouer_passe`, mais peint sans s'arrêter jusqu'au gong (`gs.partie_en_cours` devient faux),
## au lieu de s'arrêter après 2,5 s et d'attendre le reste de la manche les mains vides (I2, revue
## finale phase 17) : garantit que ce poste a des tampons et une case de territoire en vol au moment
## où la fin de manche part, pour que le scénario 13 mette réellement à l'épreuve l'ordre
## tampons/territoire puis fin (`_diffuser_tampons` → `_diffuser_territoire` → `_recevoir_fin_manche`).
## Vrai si la manche s'est bien terminée avant `delai` secondes.
func _peindre_jusquau_gong(main: Node, sens: int, gs: Node, delai: float) -> bool:
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - 233.0
	Input.action_press("deplacer_bas")
	_check(await _attendre(func() -> bool: return main.lion.position.y >= cible), "le lion de ce poste descend vers la ville (%.0f)" % main.lion.position.y)
	Input.action_release("deplacer_bas")
	var action := "deplacer_droite" if sens > 0 else "deplacer_gauche"
	Input.action_press(action)
	Input.action_press("vomir")
	var fin := Time.get_ticks_msec() + int(delai * 1000)
	while gs.partie_en_cours and Time.get_ticks_msec() < fin:
		await process_frame
	Input.action_release(action)
	Input.action_release("vomir")
	return not gs.partie_en_cours


## L'empreinte de la manche sur ce poste : territoire (propriétaire compté de chaque cellule), scores,
## tampons (nombre diffusé par l'hôte ou reçu par un client, et l'empreinte de leur suite), lions
## (position, orientation, crans, étourdi, gerbe XXL), apparitions (ennemis et pastilles : nom et position),
## niveau, le HUD de la bataille (phase 17 : chrono, pseudos, parts, rangs, départs) et, pour la manche
## de bout en bout, les réactions de chaque joueur vues ici. Pas l'image
## de la ville : les mêmes tampons y sont dessinés à l'identique (smoke test), mais une coulure qui
## descend encore quand un tampon la recouvre passe dessus ou dessous selon le rythme de chaque poste.
func _empreinte(main: Node, manche: Node, hote: bool) -> String:
	var ville: Node2D = main.get_node("Ville")
	var territoire: Territoire = ville.territoire
	var proprietaires := PackedByteArray()
	proprietaires.resize(territoire.taille_grille.x * territoire.taille_grille.y)
	for i in range(proprietaires.size()):
		proprietaires[i] = territoire.proprietaire_compte(i) + 1
	var lions: Array = main.lions.map(func(l: Node) -> String:
		return "%s:%.1f,%.1f,%d,%d,%s,%s,%s" % [l.name, l.position.x, l.position.y, l.direction_du_lion, l.joueur.crans,
			l.joueur.est_etourdi(), l.joueur.bonus_actif(), l.etiquette_pseudo.visible])
	var scenes: Array[String] = []
	var spawner: MultiplayerSpawner = main.get_node("Apparitions")
	for i in range(spawner.get_spawnable_scene_count()):
		scenes.append(spawner.get_spawnable_scene(i))
	var apparitions: Array[String] = []
	for enfant in main.get_children():
		if scenes.has(enfant.scene_file_path):
			apparitions.append("%s@%.0f,%.0f" % [enfant.name, enfant.position.x, enfant.position.y])
	apparitions.sort()
	var reactions: Array[String] = []
	var indices := _reactions.keys()
	indices.sort()
	for i: int in indices:
		reactions.append("%d:%d,%d,%d" % [i, _reactions[i][0], _reactions[i][1], _reactions[i][2]])
	return "territoire=%d scores=%s tampons=%d:%d lions=%s apparitions=%s niveau=%d hud=%s reactions=%s" % [hash(proprietaires), territoire.scores(),
		manche.tampons_diffuses if hote else manche.tampons_recus, manche.empreinte_tampons, ";".join(lions), ";".join(apparitions),
		root.get_node("GameState").niveau_courant, main.hud_bataille.resume(), ";".join(reactions)]


## Fige la manche chez l'hôte (`terminer_partie` : l'arbre se met en pause, la manche diffuse encore)
## une fois chaque lion au repos, dans l'état qu'il diffuse (ni vitesse, ni vitesse commandée, ni
## recul), depuis TICKS_REPOS_AVANT_GEL ticks au moins ; faux si ce repos n'arrive pas dans
## DELAI_ETAPE (la manche se fige quand même). Les empreintes de fin de manche ne sont des égalités
## que si rien ne bouge plus quand l'hôte se fige : il n'envoie plus d'état neuf, et la prédiction
## d'un client, qui ne distingue pas un hôte figé d'un Wi-Fi coupé, continue ce que fait son propre
## lion sans plus jamais se recaler (plan de la phase 16, point 5 de la revue ; une fin de manche
## décidée par l'hôte et appliquée à réception reste à faire). Le calme vérifié plus tôt ne suffit
## pas : pendant l'attente du terme, un ennemi ou un choc relance un lion (mesuré : un recul encore en
## cours au gel, 0,7 px d'écart chez le client dont c'est le lion). Ni le repos à la seule image du
## gel : chez un client, les lions distants s'affichent 6 ticks en retard, et son lion prédit peut
## encore buter contre l'un d'eux, là où il était chez l'hôte (mesuré : 2,5 px d'écart, lions
## étourdis ensemble juste avant le gel). Le repos se vérifie jusque dans l'image où la manche se
## fige, sans tick physique entre les deux.
func _figer_au_repos(main: Node, gs: Node) -> bool:
	var au_repos := func() -> bool:
		return main.lions.all(func(l: Node) -> bool:
			return l.velocity == Vector2.ZERO and l.deplacement.vitesse == Vector2.ZERO and l.deplacement.recul == Vector2.ZERO)
	# Pas de lambda pour `depuis` : une lambda capture les variables locales par valeur.
	var depuis := -1  # tick physique où le repos de tous a commencé (-1 : un lion bouge)
	var fin := Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while Time.get_ticks_msec() < fin:
		if not au_repos.call():
			depuis = -1
		elif depuis < 0:
			depuis = Engine.get_physics_frames()
		if depuis >= 0 and Engine.get_physics_frames() - depuis >= TICKS_REPOS_AVANT_GEL:
			break
		await process_frame
	var repos: bool = au_repos.call() and depuis >= 0 and Engine.get_physics_frames() - depuis >= TICKS_REPOS_AVANT_GEL
	gs.terminer_partie(false)  # tout se fige chez l'hôte (bataille) ; la manche diffuse encore
	return repos


func _finir_manche_hote(main: Node, manche: Node, gs: Node) -> void:
	var ville: Node2D = main.get_node("Ville")
	_check(await _attendre(func() -> bool: return _departs.size() >= 2), "le client parti en pleine manche (et le muet exclu) sont partis (%d)" % _departs.size())
	var index_parti := -1
	for j: Joueur in gs.joueurs:
		if j.id_reseau == _departs[-1]:
			index_parti = j.index
	var cellules_parti: int = ville.territoire.cellules_de(index_parti)
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 2) and cellules_parti > 0,
		"son lion disparaît, ses cellules restent au territoire (%d)" % cellules_parti)
	print("DEPART VU")
	# Les réactions d'Anna, décidées ici : un cran, la gerbe XXL, un étourdissement (elle les reçoit
	# par la manche ; son empreinte doit les montrer)
	var restants: Array = gs.joueurs.filter(func(j: Joueur) -> bool: return j.id_reseau != 1 and reseau.inscrits.has(j.id_reseau))
	_check(restants.size() == 1, "(pré-condition) il reste un client, Anna")
	if restants.size() == 1:
		var anna: Joueur = restants[0]
		var crans_avant := anna.crans  # une pastille a pu être ramassée pendant sa passe
		gs.regles.pastille_ramassee(anna, 0)
		gs.regles.etoile_ramassee(anna)
		anna.invulnerable_restant = 0.0
		gs.regles.lion_touche_par_ennemi(anna, Vector2.INF)
		_check(anna.crans == mini(crans_avant + 1, Joueur.CRANS_MAX) and anna.bonus_actif() and anna.est_etourdi(),
			"Anna gagne un cran et la gerbe XXL, puis un ennemi l'étourdit")
	var calme := func() -> bool:
		return main.lions.all(func(l: Node) -> bool: return l.velocity == Vector2.ZERO) and ville.coulures.is_empty()
	_check(await _attendre(calme), "les lions s'arrêtent, les coulures finissent")
	await _pause(0.3)
	_check(await _figer_au_repos(main, gs), "chaque lion au repos depuis %d ticks quand l'hôte fige la manche" % TICKS_REPOS_AVANT_GEL)
	await _pause(1.0)
	_check(ville.territoire.cellules_de(index_parti) == cellules_parti, "les cellules du parti restent jusqu'au bout")
	print("EMPREINTE %s" % _empreinte(main, manche, true))
	print("FIGE")
	if _options.has("rester"):
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	paused = false
	reseau.quitter()


func _finir_manche_client(main: Node, manche: Node) -> void:
	var ville: Node2D = main.get_node("Ville")
	_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("fige", ""))), "l'hôte a figé la manche")
	_check(await _attendre(func() -> bool: return ville.coulures.is_empty()), "les coulures de ce poste finissent")
	await _pause(0.5)  # les dernières positions et cellules de l'hôte figé
	print("EMPREINTE %s" % _empreinte(main, manche, false))
	_check(await _attendre(func() -> bool: return _issue == "hote_perdu"), "l'hôte finit par partir")
	var message: Node = main.get_node_or_null("HotePerdu/Message")
	_check(message != null and message.text == "RESEAU_HOTE_PERDU" and paused, "« L'hôte a quitté la partie » s'affiche, la partie se fige")
	_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
		"puis retour au titre, hors réseau")


## Rôle « manche-muet » (phase 14) : un joueur prêt qui ne charge jamais sa scène de jeu.
func _jouer_muet() -> void:
	reseau.inscrit.connect(_sur_inscription)
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	var lancee := [0]
	reseau.manche_lancee.connect(func(_f: Array[Dictionary]) -> void: lancee[0] = Time.get_ticks_msec())
	_check(reseau.rejoindre("127.0.0.1", int(_option("port", "17777"))) == OK, "le client muet est créé")
	_check(await _attendre(func() -> bool: return _issue == "inscrit"), "le muet est inscrit")
	_check(await _attendre(func() -> bool: return reseau.table_salon.any(func(f: Dictionary) -> bool: return f.id == root.multiplayer.get_unique_id())),
		"le muet est à la table du salon")
	reseau.demander_pret(true)
	_check(await _attendre(func() -> bool: return lancee[0] > 0), "le muet reçoit le lancement de la manche, sans charger de scène")
	if _options.has("figer"):
		# I1 (revue finale phase 14) : le fil principal se fige tout entier, comme un poste qui
		# compile ses shaders : son ENet n'acquitte plus rien, y compris le DISCONNECT de l'hôte qui
		# l'exclut (le correctif d'`_exclure` ne doit pas en dépendre pour autant).
		print("FIGE_MUET")
		OS.delay_msec(int(float(_option("figer", "0")) * 1000.0))
	var fin := Time.get_ticks_msec() + int((DELAI_ETAPE + float(_option("gel", "0"))) * 1000.0)
	while _issue != "inscrit+hote_perdu" and Time.get_ticks_msec() < fin:
		await process_frame
	var apres: float = (Time.get_ticks_msec() - lancee[0]) / 1000.0
	print("EXCLU apres=%.1f s raison=%s" % [apres, reseau.raison_perte])
	_check(_issue == "inscrit+hote_perdu" and apres >= float(_option("delai-chargement", "0")),
		"l'hôte l'exclut après le délai de la barrière (%.1f s)" % apres)
	_check(reseau.raison_perte == reseau.PERTE_EXCLU,
		"phase 18 : l'exclu l'apprend de l'hôte avant d'être déconnecté (%s, pas « L'hôte a quitté la partie »)" % reseau.raison_perte)


## Rôles « bout-hote » et « bout-client » (phase 15, voir l'en-tête) : une manche entière à 1 hôte et
## 3 clients, chacun au clavier selon son programme, avec les rencontres de l'hôte et un client
## arraché en pleine manche ; la même empreinte chez l'hôte et chez chaque client resté.
func _jouer_bout(hote: bool) -> void:
	var main := await _rejoindre_la_manche(hote)
	if main == null:
		return
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	_suivre_reactions(gs)
	if hote:
		_check(manche._prets.size() == gs.joueurs.size() - 1 and manche._exclus.is_empty(),
			"chaque client a chargé sa scène, personne n'est exclu (%s)" % [manche._prets])
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size()) and gs.joueurs.size() == 4,
		"un lion par joueur, 1 hôte et 3 clients (%d)" % main.lions.size())
	_check(await _attendre(func() -> bool: return gs.pret), "l'intro se termine chez tous")
	_check(gs.niveau_courant == int(_option("niveau", str(gs.niveau_courant))) and get_first_node_in_group("boss") != null,
		"le niveau choisi au salon (%d), avec son peintre" % gs.niveau_courant)
	print("INTRO")
	_commencer_mesure(main)
	var programme := Programme.new(int(_option("graine", "1")), main.get_node("Ville"))
	if hote:
		await _animer_bout_hote(main, manche, gs, programme)
	else:
		await _animer_bout_client(main, manche, gs, programme)
	_effacer_scores()


## Le programme de jeu d'un poste de la manche de bout en bout : des commandes au hasard, tirées de
## sa graine, jouées au clavier comme un joueur (`Input.action_press`). Une cible au hasard dans la
## bande de peinture (au-dessus des toits, comme le pilote de la démo), rejointe en huit directions et
## remplacée une fois atteinte ou au bout de DUREE_CIBLE ms ; le vomi par périodes de 0,2 à 0,8 s,
## trois fois sur quatre. Comme le pilote de la démo, il fuit d'abord un ennemi proche, et le peintre
## (plus grand) de plus loin : sans quoi le peintre, qui couvre la bande de peinture du Village,
## étourdirait les lions sans relâche et plus personne ne jouerait.
class Programme:
	const DUREE_CIBLE := 1500
	const DISTANCE_DANGER := 280.0
	const DISTANCE_DANGER_PEINTRE := 420.0
	const ACTIONS: Array[String] = ["deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas", "vomir"]
	var rng := RandomNumberGenerator.new()
	var bande: Rect2
	var cible := Vector2.ZERO
	var fin_cible := 0
	var fin_vomi := 0

	## `moitie` : 0 ou 1 pour ne jouer que dans la moitié gauche ou droite de la bande (assez loin de
	## l'autre pour que deux lions ne s'y touchent pas), -1 pour toute la bande.
	func _init(graine: int, ville: Node2D, moitie := -1) -> void:
		rng.seed = graine
		var haut: float = ville.position.y - ville.tex_size.y / 2.0
		bande = Rect2(100.0, haut - 300.0, 1650.0, 120.0)
		if moitie >= 0:
			bande = Rect2(100.0 + moitie * 970.0, haut - 300.0, 680.0, 120.0)

	## Une image de jeu pour `lion` (le lion de ce poste, dont la position est celle de l'hôte).
	func piloter(lion: Node2D) -> void:
		var maintenant := Time.get_ticks_msec()
		if maintenant >= fin_cible or lion.position.distance_to(cible) < 30.0:
			cible = Vector2(rng.randf_range(bande.position.x, bande.end.x), rng.randf_range(bande.position.y, bande.end.y))
			fin_cible = maintenant + DUREE_CIBLE
		if maintenant >= fin_vomi:
			_basculer("vomir", rng.randf() < 0.75)
			fin_vomi = maintenant + rng.randi_range(200, 800)
		var ecart := cible - lion.position
		var fuite := _fuite(lion)
		if fuite != Vector2.ZERO:
			ecart = fuite * 100.0
		_basculer("deplacer_gauche", ecart.x < -20.0)
		_basculer("deplacer_droite", ecart.x > 20.0)
		_basculer("deplacer_haut", ecart.y < -20.0)
		_basculer("deplacer_bas", ecart.y > 20.0)

	## La direction qui éloigne `lion` des ennemis et du peintre trop proches (nulle s'il n'y en a pas).
	func _fuite(lion: Node2D) -> Vector2:
		var centre: Vector2 = lion.position + lion.CENTRE
		var fuite := Vector2.ZERO
		for groupe: String in ["ennemi", "boss"]:
			var distance := DISTANCE_DANGER if groupe == "ennemi" else DISTANCE_DANGER_PEINTRE
			for ennemi: Node2D in lion.get_tree().get_nodes_in_group(groupe):
				var ecart: Vector2 = centre - ennemi.global_position
				if ecart.length() < distance:
					fuite += ecart.normalized() * (distance - ecart.length())
		return fuite.normalized()

	## Toutes les touches relâchées : le lion s'arrête et ne vomit plus.
	func relacher() -> void:
		for action in ACTIONS:
			Input.action_release(action)

	static func _basculer(action: String, appuyee: bool) -> void:
		if appuyee:
			Input.action_press(action)
		else:
			Input.action_release(action)


## Rôles « latence-hote » et « latence-client » (phase 16, voir l'en-tête) : une manche à 1 hôte et 2
## clients, les clients derrière le simulateur de latence ; chaque client mesure sa prédiction, l'hôte
## les commandes reçues ; la même empreinte chez tous.
func _jouer_latence(hote: bool) -> void:
	var main := await _rejoindre_la_manche(hote)
	if main == null:
		return
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size()) and gs.joueurs.size() == 3,
		"un lion par joueur, 1 hôte et 2 clients (%d)" % main.lions.size())
	_check(await _attendre(func() -> bool: return gs.pret), "l'intro se termine chez tous")
	print("INTRO")
	if hote:
		await _animer_latence_hote(main, manche, gs)
	else:
		await _animer_latence_client(main, manche)
	_effacer_scores()


func _animer_latence_hote(main: Node, manche: Node, gs: Node) -> void:
	var duree := float(_option("duree", "20"))
	var ville: Node2D = main.get_node("Ville")
	var spawner: Node = main.get_node("Spawner")
	var ecarter_ennemis := func() -> bool:
		for t: Timer in [spawner._timer_soucoupe, spawner._timer_coccinelle]:
			if t != null:
				t.stop()
		for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
			ennemi.queue_free()
		return gs.temps_ecoule >= duree - DUREE_CALME
	_check(await _attendre(ecarter_ennemis, duree + 10.0), "le jeu dure jusqu'à %.0f s de la fin, sans ennemis" % DUREE_CALME)
	print("CALME")
	var calme := func() -> bool:
		return main.lions.all(func(l: Node) -> bool: return l.velocity == Vector2.ZERO) and ville.coulures.is_empty()
	_check(await _attendre(calme), "les lions s'arrêtent, les coulures finissent")
	_check(await _attendre(func() -> bool: return gs.temps_ecoule >= duree), "la manche va jusqu'au bout de ses %.0f s" % duree)
	for l: Node in main.lions:
		if l == main.lion:
			continue
		var c: Commandes = l.commandes
		print("COMMANDES %s appliquees=%d rattrapees=%d perdues=%d numero=%d file_max=%d profondeur_moyenne=%.2f" %
			[l.joueur.pseudo, c.appliquees, c.rattrapees, c.perdues, c.numero_applique, c.file_max_vue, c.profondeur_moyenne()])
		# `rejouees` (M1, revue finale phase 16) fait vraiment échouer ce test si une commande était
		# rejouée : l'égalité seule peut rester vraie même dans ce cas (`sautees` peut descendre au
		# lieu de monter).
		# I1 (revue finale phase 16) : un vrai accroc réseau (SEUIL_RATTRAPAGE) fait maintenant compter
		# quelques commandes sautées là où l'ancien code avançait en silence (l'erreur de prédiction
		# baissait sans que rien ne l'atteste).
		# I2 (revue finale phase 17, désync-report) : un accroc hôte (donc plus fréquent sur un runner CI
		# lent) fait délester des commandes exprès (`rattrapees`) pour ne pas garder de retard ; ce n'est
		# pas une perte réseau, seule `perdues` (jamais arrivées à temps malgré la redondance, sous 5 % de
		# pertes simulées) l'est. Seule `perdues` a un seuil strict (1 %, mesuré : la redondance seule le
		# couvre largement) ; `rattrapees` n'est qu'une mesure, gardée sous une borne large de bon sens
		# (15 %) pour attraper une régression grossière sans faire échouer le test au moindre accroc hôte.
		_check(c.rejouees == 0 and c.sautees >= 0 and c.numero_applique > 600 and c.appliquees + c.sautees == c.numero_applique
			and c.perdues * 100 <= c.numero_applique and c.rattrapees * 100 <= c.numero_applique * 15,
			"les commandes de %s : aucune appliquée deux fois (%d rejouée(s)), %d perdues sur %d (perte réseau au-delà de la redondance), %d rattrapées par le délestage volontaire (mesure)"
				% [l.joueur.pseudo, c.rejouees, c.perdues, c.numero_applique, c.rattrapees])
	_check(await _figer_au_repos(main, gs), "chaque lion au repos depuis %d ticks quand l'hôte fige la manche" % TICKS_REPOS_AVANT_GEL)
	await _pause(1.0)
	print("EMPREINTE %s" % _empreinte(main, manche, true))
	print("FIGE")
	var rester := _option("rester", "")
	print("HOTE RESTE")
	_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	paused = false
	reseau.quitter()


func _animer_latence_client(main: Node, manche: Node) -> void:
	var calme := _option("calme", "")
	var programme := Programme.new(int(_option("graine", "1")), main.get_node("Ville"), int(_option("moitie", "-1")))
	var prediction: Node = main.lion.prediction
	# Adaptation (Task 4 review, 48d9586) : le décalage de correction ne bouge plus le corps
	# (`Lion.position`, toujours la position prédite), mais l'affichage (`Lion.visuel`, enfant du
	# lion). Ce que le joueur voit, et ce qu'A_COUP doit mesurer, est donc la position affichée
	# (`main.lion.visuel.global_position`, aucune rotation ni échelle sur `Lion` ni sur `Visuel`) :
	# suivre `main.lion.position` compterait à tort chaque recalage absorbé par le décalage (jamais
	# visible) comme un à-coup de l'affichage.
	var a_coups := [0, main.lion.visuel.global_position]  # partagé avec la lambda : à-coups, position affichée d'avant
	var mesurer := func() -> void:
		if main.lion != null:
			var affichee: Vector2 = main.lion.visuel.global_position
			if affichee.distance_to(a_coups[1]) > A_COUP + main.lion.deplacement.recul.length() / 60.0:
				a_coups[0] += 1
			a_coups[1] = affichee
	physics_frame.connect(mesurer)
	_check(await _jouer_jusqu_a(main, programme, func() -> bool: return FileAccess.file_exists(calme), ReglesBataille.DUREE_MANCHE),
		"le jeu dure jusqu'au calme annoncé par lancer.sh (%s)" % calme)
	programme.relacher()
	var arret: int = prediction.numero + 1
	_check(await _attendre(func() -> bool: return prediction.numero_accuse >= arret + 60),
		"l'hôte accuse les commandes d'après l'arrêt (%d, arrêt à la %d)" % [prediction.numero_accuse, arret])
	physics_frame.disconnect(mesurer)
	var etats: int = prediction.etats_depuis(1)
	var apres: float = prediction.erreur_max(arret + TICKS_CONVERGENCE)
	print("PREDICTION %s : erreur max %.2f px, %d états sur %d au-delà de 4 px, %d au-delà de 16 px ; %.2f px au plus 150 ms après l'arrêt ; recalages %d ; à-coups %d ; rejeu le plus long %d pas"
		% [reseau.pseudo, prediction.erreur_max(), prediction.erreurs_au_dela(ECART_PREDICTION), etats, prediction.erreurs_au_dela(16.0), apres,
			prediction.recalages, a_coups[0], prediction.rejeu_max])
	_check(etats > 600 and prediction.recalages == 0, "le lion prédit n'est jamais recalé d'un coup (%d états de l'hôte)" % etats)
	# Un à-coup de l'hôte (une image longue : il rattrape plusieurs ticks d'un coup, sa file se vide) lui
	# fait répéter une commande, donc une erreur de quelques pas (mesuré sur 20 clients : jusqu'à 110 px,
	# au plus 18 états sur 696 au-delà de 16 px), que la correction douce absorbe. Une prédiction cassée
	# dépasse 16 px presque à chaque état : au plus 10 % des états au-delà de 16 px.
	_check(prediction.erreurs_au_dela(16.0) * 10 <= etats, "l'erreur de prédiction dépasse rarement 16 px (%d fois sur %d)" % [prediction.erreurs_au_dela(16.0), etats])
	_check(apres >= 0.0 and apres < ECART_PREDICTION, "150 ms après l'arrêt de ses commandes, l'erreur de prédiction reste sous %.0f px (%.2f px)" % [ECART_PREDICTION, apres])
	await _finir_manche_client(main, manche)


## Rôles « chrono-hote » et « chrono-client » (phases 17 et 18, voir l'en-tête) : une manche courte que
## le chrono de l'hôte termine, le même écran Résultats partout ; l'hôte choisit Revanche, une seconde
## manche, plus courte, finit de même ; un client (--quitte) quitte alors l'écran Résultats, les autres le
## voient partir ; l'hôte ramène l'autre client au salon, la même table, puis s'en va.
func _jouer_chrono(hote: bool) -> void:
	var duree := float(_option("duree-manche", "10"))
	var script_regles: Script = load("res://Scripts/ReglesBataille.gd")
	script_regles.duree_manche = duree
	var main := await _rejoindre_la_manche(hote)
	if main != null and await _jouer_au_chrono(main, hote, duree, "FIN"):
		await _enchainer(main, hote, script_regles)
	script_regles.duree_manche = ReglesBataille.DUREE_MANCHE
	_effacer_scores()


## Une manche au chrono, de la barrière à l'écran Résultats : écrit « <etiquette> <HUD, bilan, lions> »
## et « RESULTATS <etiquette> <écran Résultats> » (les mêmes lignes sur chaque poste). Vrai si l'écran
## Résultats est là.
func _jouer_au_chrono(main: Node, hote: bool, duree: float, etiquette: String) -> bool:
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
	var hud: CanvasLayer = main.hud_bataille
	_check(await _attendre(func() -> bool: return manche.barriere), "(%s) la barrière de chargement passe" % etiquette)
	_check(await _attendre(func() -> bool: return gs.pret), "(%s) l'intro se termine chez tous" % etiquette)
	print("INTRO")
	_check(hud != null and hud.vignettes.size() == gs.joueurs.size() and gs.joueurs.size() == 3
		and hud.vignettes[gs.joueur_local().index].badge.text == "TOI",
		"(%s) le HUD de la bataille : une vignette par joueur (1 hôte et 2 clients), « TOI » sur celle de ce poste" % etiquette)
	_check(await _peindre_jusquau_gong(main, int(_option("sens", "1")), gs, duree + 10.0),
		"(%s) la manche se termine (peinte sans s'arrêter jusqu'au gong, I2 : des tampons et une case de territoire en vol quand la fin part)" % etiquette)
	if hote:
		_check(manche.finie and gs.temps_ecoule >= duree and gs.temps_ecoule < duree + 0.1,
			"(%s) le chrono de l'hôte termine la manche à %.0f s (%.3f s)" % [etiquette, duree, gs.temps_ecoule])
	else:
		print("ECART_CHRONO %s %.3f" % [etiquette, manche.ecart_chrono_fin])
		_check(manche.finie and absf(manche.ecart_chrono_fin) <= ECART_CHRONO and gs.temps_ecoule >= duree and gs.temps_ecoule < duree + 0.1,
			"(%s) la fin de l'hôte termine la manche de ce client, son chrono pris sur celui de l'hôte (%.3f s, écart %.3f s)"
				% [etiquette, gs.temps_ecoule, manche.ecart_chrono_fin])
	var tics_attendus := mini(ReglesBataille.SECONDES_TIC, ceili(duree) - 1)
	var resultats_la := await _attendre(func() -> bool: return main.resultats != null)
	_check(resultats_la and paused and main.resultats.visible and not hud.visible and hud.chrono.text == "0:00" and hud.tics_joues == tics_attendus,
		"(%s) tout se fige, l'écran Résultats à la place du HUD (le chrono à 0:00, %d tics sur %d attendus)" % [etiquette, hud.tics_joues, tics_attendus])
	print("%s %s bilan=%s lions=%s" % [etiquette, hud.resume(), manche.bilan.resume() if manche.bilan != null else "", _lions_affiches(main)])
	if resultats_la:
		_check(main.resultats.hote == hote and main.resultats.bouton_revanche.visible == hote and main.resultats.bouton_salon.visible == hote
			and (hote or main.resultats.etat.text == tr("RESULTATS_ATTENTE_HOTE")),
			"(%s) l'hôte choisit (Revanche, Niveau suivant, Retour au salon) ; un client voit « En attente de l'hôte… »" % etiquette)
		print("RESULTATS %s %s" % [etiquette, main.resultats.resume()])
	return resultats_la


## Un appui (ou un relâchement) de `action`, comme le clavier ou la manette l'envoient au jeu.
func _pousser(action: StringName, appuye: bool) -> void:
	var evenement := InputEventAction.new()
	evenement.action = action
	evenement.pressed = appuye
	root.push_input(evenement)
	await process_frame


## L'hôte choisit `choix` sur son écran Résultats au clavier, comme un joueur : droite jusqu'au bouton,
## puis vomir (une fois l'animation finie et le délai des choix passé ; vomir relâché d'abord : il était
## tenu au gong).
func _choisir_au_clavier(resultats: CanvasLayer, choix: StringName) -> void:
	_check(await _attendre(func() -> bool: return resultats.animation_finie and resultats._depuis_animation >= resultats.DELAI_CHOIX),
		"l'animation de l'écran Résultats finie, les choix sont ouverts")
	var essais := 0
	while resultats.selection != choix and essais < 4:
		await _pousser(&"deplacer_droite", true)
		await _pousser(&"deplacer_droite", false)
		essais += 1
	var choisi := [&""]  # l'écran Résultats s'en va avec la scène dès le choix suivi
	resultats.choix_fait.connect(func(c: StringName) -> void: choisi[0] = c)
	await _pousser(&"vomir", false)
	await _pousser(&"vomir", true)
	await _pousser(&"vomir", false)
	_check(choisi[0] == choix, "l'hôte choisit « %s » au clavier (%s)" % [choix, choisi[0]])


## La suite du scénario 13 (phase 18) : Revanche, une seconde manche, un client qui quitte l'écran
## Résultats, le retour au salon, puis le départ de l'hôte.
func _enchainer(premiere: Node, hote: bool, script_regles: Script) -> void:
	var gs: Node = root.get_node("GameState")
	var niveau: int = gs.niveau_courant
	var duree := float(_option("duree-revanche", "6"))
	script_regles.duree_manche = duree  # la seconde manche, sur chaque poste
	var id_premiere := premiere.get_instance_id()
	if hote:
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("revanche", ""))), "chaque poste a son écran Résultats")
		await _choisir_au_clavier(premiere.resultats, &"revanche")
	var nouvelle := func() -> bool:
		return current_scene != null and current_scene.get_instance_id() != id_premiere and _scene_est("Main") and current_scene.is_node_ready()
	_check(await _attendre(nouvelle), "Revanche : la scène de jeu se recharge sur chaque poste")
	if not nouvelle.call():
		reseau.quitter()
		return
	var main: Node = current_scene
	var territoire: Territoire = main.get_node("Ville").territoire
	_check(not paused and gs.niveau_courant == niveau and gs.joueurs.size() == 3 and reseau.manche_en_cours and main.resultats == null
		and range(3).all(func(i: int) -> bool: return territoire.cellules_de(i) == 0)
		and main.hud_bataille.chrono.text == EtatPartie.formater_temps(duree) and main.get_node("Manche").bilan == null,
		"une manche neuve, le même niveau, les mêmes joueurs : ni pause, ni cellule, ni bilan, le chrono à %s" % EtatPartie.formater_temps(duree))
	if not await _jouer_au_chrono(main, hote, duree, "FIN2"):
		reseau.quitter()
		return
	var resultats: CanvasLayer = main.resultats
	if _options.has("quitte"):
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("quitte", ""))), "chaque poste a son second écran Résultats")
		await _pousser(&"ui_cancel", true)
		await _pousser(&"ui_cancel", false)
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not reseau.en_ligne(), "Quitter (Échap) sur l'écran Résultats : le titre, hors réseau")
		print("QUITTE")
		return
	var partant := -1
	for j: Joueur in gs.joueurs:
		if j.pseudo == "Bruno":
			partant = j.index
	_check(partant >= 0 and await _attendre(func() -> bool: return resultats.partis[partant]),
		"Bruno quitte l'écran Résultats : chaque poste resté le voit partir")
	_check(resultats.lignes.any(func(l: Dictionary) -> bool: return l.index == partant and l.badge.text.contains(tr("BATAILLE_PARTI")))
		and (not hote or resultats.possible(&"revanche")),
		"sa ligne se grise ; à deux, l'hôte peut encore relancer")
	print("DEPART VU")
	if hote:
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("salon", ""))), "l'autre client a vu partir Bruno")
		# EXTRA Task 4 : un premier Échap ouvre la confirmation de départ de l'hôte, sans que personne ne
		# parte ; toute autre touche (ici déplacer à droite) l'annule sans bouger la sélection.
		await _pousser(&"ui_cancel", true)
		await _pousser(&"ui_cancel", false)
		_check(resultats.confirmation_quitter and _scene_est("Main"),
			"un premier Échap sur l'écran Résultats ouvre la confirmation de départ de l'hôte, sans que personne ne parte")
		var selection_avant: StringName = resultats.selection
		await _pousser(&"deplacer_droite", true)
		await _pousser(&"deplacer_droite", false)
		_check(not resultats.confirmation_quitter and resultats.selection == selection_avant,
			"une autre touche (déplacer à droite) annule la confirmation sans bouger la sélection")
		await _choisir_au_clavier(resultats, &"salon")
	_check(await _attendre(func() -> bool: return _scene_est("Salon") and current_scene.is_node_ready()), "Retour au salon : chaque poste resté revient au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return
	var salon: Node = current_scene
	_check(await _attendre(func() -> bool: return reseau.table_salon.size() == 2 and reseau.table_salon.all(func(f: Dictionary) -> bool: return not f.pret))
		and not reseau.manche_en_cours and not paused,
		"le salon : la même table sans Bruno, personne prêt, plus de manche en cours")
	print("SALON %s" % ";".join(reseau.table_salon.map(func(f: Dictionary) -> String: return "%d:%d:%s:%s" % [f.id, f.index, f.pseudo, f.pret])))
	if hote:
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("rester", ""))), "lancer.sh laisse partir l'hôte")
		salon.retour()
		_check(await _attendre(func() -> bool: return _scene_est("EcranEnLigne")) and not reseau.en_ligne(), "l'hôte quitte le salon : l'écran En ligne, hors réseau")
	else:
		_check(await _attendre(func() -> bool: return _scene_est("EcranEnLigne")) and not reseau.en_ligne()
			and current_scene.message.text == tr("RESEAU_HOTE_PERDU"),
			"l'hôte parti du salon : l'écran En ligne, « L'hôte a quitté la partie »")
	change_scene_to_file("res://Scenes/Titre.tscn")  # le joueur en a fini : le titre
	_check(await _attendre(func() -> bool: return _scene_est("Titre")), "puis le titre")


## Les lions de ce poste tels qu'ils s'affichent (le corps et le décalage de la prédiction), en une ligne
## (phase 18 : la même partout une fois l'état final de l'hôte posé, même lancés en pleine course au gong).
func _lions_affiches(main: Node) -> String:
	return ";".join(main.lions.map(func(l: Node) -> String:
		return "%s@%.1f,%.1f,%d" % [l.name, l.position.x + l.visuel.position.x, l.position.y + l.visuel.position.y, l.direction_du_lion]))


## Joue le programme de ce poste, image après image, jusqu'à `condition` (au plus `delai` secondes).
func _jouer_jusqu_a(main: Node, programme: Programme, condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		if main.lion != null:
			programme.piloter(main.lion)
		await process_frame
	return condition.call()


## Compte, sur ce poste, les réactions de chaque joueur : étourdissements, crans et gerbes XXL. Chez
## l'hôte, celles que décident ses règles ; chez un client, celles que sa manche reçoit de l'hôte.
## Branché dès la barrière passée : les mêmes comptes partout prouvent qu'aucune n'est perdue ni
## doublée en route.
func _suivre_reactions(gs: Node) -> void:
	for j: Joueur in gs.joueurs:
		var comptes := [0, 0, 0]  # un Array, partagé avec les lambdas (capturé par référence)
		_reactions[j.index] = comptes
		j.etourdi.connect(func(_origine: Vector2, _barbouillage: Color) -> void: comptes[0] += 1)
		j.crans_changes.connect(func(_crans: int) -> void: comptes[1] += 1)
		j.bonus_change.connect(func(actif: bool) -> void:
			if actif:
				comptes[2] += 1)


## Mesure de ce poste de l'intro au calme, à chaque image (`process_frame`) : la durée de l'image
## qui s'achève, et si des jeux de tampons y ont été générés (le cache de la ville a grandi).
func _mesurer_frame() -> void:
	var maintenant := Time.get_ticks_usec()
	var jeux: int = _ville_mesuree._tampons.size()
	if _instant_frame > 0:
		var duree := (maintenant - _instant_frame) / 1000.0
		_pire_frame_ms = maxf(_pire_frame_ms, duree)
		if jeux > _jeux_vus:
			_pire_frame_generation_ms = maxf(_pire_frame_generation_ms, duree)
			_jeux_generes += jeux - _jeux_vus
	_jeux_vus = jeux
	_instant_frame = maintenant


func _commencer_mesure(main: Node) -> void:
	_ville_mesuree = main.get_node("Ville")
	_jeux_vus = _ville_mesuree._tampons.size()
	process_frame.connect(_mesurer_frame)


## La mesure de ce poste, de l'intro au calme : jeux de tampons, frame la plus longue.
func _ecrire_mesure() -> void:
	process_frame.disconnect(_mesurer_frame)
	print("MESURE %s : %d jeux de tampons en cache, %d générés pendant la manche ; frame la plus longue %.0f ms, %.0f ms au plus pour une frame qui en génère"
		% [reseau.pseudo, _ville_mesuree._tampons.size(), _jeux_generes, _pire_frame_ms, _pire_frame_generation_ms])


## Vrai si aucun autre lion de la manche n'a son centre à moins d'ISOLEMENT de celui de `lion`.
func _isole(lion: Node2D, main: Node) -> bool:
	var centre: Vector2 = lion.global_position + lion.CENTRE
	return main.lions.all(func(l: Node) -> bool: return l == lion or centre.distance_to(l.global_position + l.CENTRE) >= ISOLEMENT)


## Attend (au plus DELAI_ETAPE) que le lion `lion` soit lancé à ses propres commandes (au moins
## VITESSE_AU_VOL, pas étourdi, et `aussi`) et seul. Le mouvement vient du client ; l'écart, de
## l'hôte, qui ne décide que des lieux : tant que le lion, libre de bouger, est collé à un autre (au
## contact, les deux se bloquent et se vomissent dessus : mesuré, jusqu'à plusieurs secondes) ou
## lent (plaqué contre un bord en fuyant), il est posé, sa vitesse intacte, à la place la plus
## libre de la bande de peinture (`_mettre_a_l_ecart`). Vrai si le lion est lancé et seul à cette
## image : ce qui est posé sur lui maintenant est à lui, aucun autre lion ne l'atteint avant.
func _lancer_a_l_ecart(lion: Node2D, main: Node, bande: Rect2, aussi: Callable) -> bool:
	var j: Joueur = lion.joueur
	var lance := func() -> bool: return lion.velocity.length() >= VITESSE_AU_VOL and not j.est_etourdi() and aussi.call()
	var fin := Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not (lance.call() and _isole(lion, main)) and Time.get_ticks_msec() < fin:
		if not j.est_etourdi() and (not _isole(lion, main) or lion.velocity.length() < VITESSE_AU_VOL):
			_mettre_a_l_ecart(lion, main, bande)
		await physics_frame
	return lance.call() and _isole(lion, main)


## Pose `lion` (le coin de son sprite), sans toucher à sa vitesse, au milieu de la hauteur de `bande`
## et, sur sa largeur, à la place la plus loin des autres lions : trois autres lions y laissent
## toujours une place à plus de 1650 / 6 = 275 px de chacun (plus qu'ISOLEMENT).
func _mettre_a_l_ecart(lion: Node2D, main: Node, bande: Rect2) -> void:
	var meilleure := Vector2(lion.global_position.x, bande.get_center().y)
	var meilleur_ecart := -1.0
	for x in range(int(bande.position.x), int(bande.end.x) + 1, 10):
		var centre: Vector2 = Vector2(x, meilleure.y) + lion.CENTRE
		var ecart := INF
		for autre: Node2D in main.lions:
			if autre != lion:
				ecart = minf(ecart, centre.distance_to(autre.global_position + autre.CENTRE))
		if ecart > meilleur_ecart:
			meilleur_ecart = ecart
			meilleure.x = x
	lion.global_position = meilleure


## La zone de contact `n` (1 à 3, de la bouche au point de chute) de la gerbe d'un lion.
func _zone_de_contact(lion: Node, n: int) -> Node2D:
	return lion.find_child("ZoneContact%d" % n, true, false)


func _animer_bout_hote(main: Node, manche: Node, gs: Node, programme: Programme) -> void:
	var duree := float(_option("duree", str(ReglesBataille.DUREE_MANCHE)))
	var ville: Node2D = main.get_node("Ville")
	_check(await _jouer_jusqu_a(main, programme, func() -> bool: return gs.temps_ecoule >= DEBUT_RENCONTRES, DEBUT_RENCONTRES + 10.0),
		"%.0f s de jeu libre avant les rencontres" % DEBUT_RENCONTRES)
	programme.relacher()
	await _rencontres(main, gs, programme.bande)
	print("RENCONTRES")

	# Un client arraché en pleine manche (KILL : ni DISCONNECT ni aucun autre paquet), comme un PC
	# planté ou un Wi-Fi coupé : l'hôte le voit partir au bout du silence de son battement (10 s).
	# Le client arraché est celui qui tient le plus de territoire à cet instant : « ses cellules
	# restent » doit porter sur des cellules. Un client désigné d'avance n'en tient pas toujours (ses
	# commandes au hasard, les étourdissements : mesuré, 0 cellule une fois sur quinze passages).
	var partant: Joueur = null
	for j: Joueur in gs.joueurs:
		if j != gs.joueur_local() and (partant == null or ville.territoire.cellules_de(j.index) > ville.territoire.cellules_de(partant.index)):
			partant = j
	_check(ville.territoire.cellules_de(partant.index) > 0,
		"(pré-condition) le client à arracher, %s, tient du territoire (%d)" % [partant.pseudo, ville.territoire.cellules_de(partant.index)])
	print("A TUER %s" % partant.pseudo)
	_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("tue", ""))), "lancer.sh arrache le poste de %s" % partant.pseudo)
	var arrache_a := Time.get_ticks_msec()
	_check(await _attendre(func() -> bool: return _departs.has(partant.id_reseau)), "l'hôte voit partir %s" % partant.pseudo)
	print("ECART_DEPART %d" % (Time.get_ticks_msec() - arrache_a))
	var sans_lui := func() -> bool:
		return main.lions.size() == gs.joueurs.size() - 1 and main.lions.all(func(l: Node) -> bool: return l.joueur != partant)
	_check(await _attendre(sans_lui) and ville.territoire.cellules_de(partant.index) > 0,
		"son lion disparaît, ses cellules restent au territoire (%d)" % ville.territoire.cellules_de(partant.index))
	print("DEPART VU")
	# Le poste arraché n'a pas pu effacer ses scores de test (`_rejoindre_la_manche`) : l'hôte le fait.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://scores_reseau_%s.cfg" % partant.pseudo))

	_check(await _jouer_jusqu_a(main, programme, func() -> bool: return gs.temps_ecoule >= duree - DUREE_CALME, duree),
		"le jeu continue jusqu'à %.0f s de la fin" % DUREE_CALME)
	programme.relacher()
	_ecrire_mesure()
	print("CALME")
	var calme := func() -> bool:
		return main.lions.all(func(l: Node) -> bool: return l.velocity == Vector2.ZERO) and ville.coulures.is_empty()
	_check(await _attendre(calme), "les lions s'arrêtent, les coulures finissent")
	_check(await _attendre(func() -> bool: return gs.temps_ecoule >= duree), "la manche va jusqu'au bout de ses %.0f s" % duree)
	_check(await _figer_au_repos(main, gs), "chaque lion au repos depuis %d ticks quand l'hôte fige la manche" % TICKS_REPOS_AVANT_GEL)
	await _pause(1.0)
	print("STATS chocs=%s etourdissements=%s vols=%s crans=%s" % [gs.joueurs.map(func(j: Joueur) -> int: return j.chocs),
		gs.joueurs.map(func(j: Joueur) -> int: return j.etourdissements_infliges),
		gs.joueurs.map(func(j: Joueur) -> int: return j.cellules_volees), gs.joueurs.map(func(j: Joueur) -> int: return j.crans)])
	print("EMPREINTE %s" % _empreinte(main, manche, true))
	print("FIGE")
	if _options.has("rester"):
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	paused = false
	reseau.quitter()


## Les rencontres de la manche de bout en bout. L'hôte ne décide que des lieux (il déplace des lions,
## fait apparaître une pastille, une étoile, une soucoupe sur eux) ; les effets passent par le jeu :
## contacts physiques chez l'hôte, règles, réactions diffusées aux clients. Les clients jouent leur
## programme pendant ce temps ; le lion de l'hôte, touches relâchées, sert d'outil.
func _rencontres(main: Node, gs: Node, bande: Rect2) -> void:
	var spawner: Node = main.get_node("Spawner")
	var lion_hote: Node2D = main.lion
	var moi: Joueur = gs.joueur_local()
	var clients: Array = main.lions.filter(func(l: Node) -> bool: return l != lion_hote)

	# Deux pastilles ramassées au vol par le lion de chaque client, l'une après l'autre
	for l: Node2D in clients + clients:
		var j: Joueur = l.joueur
		var crans_avant := j.crans
		_check(await _lancer_a_l_ecart(l, main, bande, func() -> bool: return true),
			"(pré-condition) le lion de %s est en mouvement, à l'écart des autres" % j.pseudo)
		var vitesse: float = l.velocity.length()
		spawner.spawn_pickup(0, l.global_position + l.CENTRE)
		_check(await _attendre(func() -> bool: return j.crans == mini(crans_avant + 1, Joueur.CRANS_MAX)),
			"le lion de %s ramasse au vol une pastille (%.0f px/s) : un cran de plus (%d)" % [j.pseudo, vitesse, j.crans])

	# Une étoile, au vol aussi, pour le troisième client en train de peindre : la gerbe XXL
	var l3: Node2D = clients[2]
	var j3: Joueur = l3.joueur
	var peint := func() -> bool: return l3.est_en_train_de_vomir and not j3.bonus_actif()
	_check(await _lancer_a_l_ecart(l3, main, bande, peint),
		"(pré-condition) le lion de %s vomit en mouvement, à l'écart des autres, sans gerbe XXL" % j3.pseudo)
	spawner.spawn_bonus(l3.global_position + l3.CENTRE)
	_check(await _attendre(func() -> bool: return j3.bonus_actif()), "le lion de %s ramasse une étoile : la gerbe XXL" % j3.pseudo)

	# Une soucoupe sur le lion du premier client : un ennemi l'étourdit (sans barbouillage). Une autre
	# soucoupe tant qu'il n'est pas étourdi par un ennemi : il a pu l'être entre-temps par une gerbe,
	# ou être encore immunisé quand la première est passée.
	var l1: Node2D = clients[0]
	var j1: Joueur = l1.joueur
	var par_ennemi := [false]  # des Array, partagés avec les lambdas
	var soucoupe: Node2D = null
	var soucoupes: Array[Node2D] = []  # celles posées ici : une plus ancienne, délaissée mais
	# jamais libérée, peut encore toucher le lion ; le peintre et une coccinelle de passage, non.
	var sur_ennemi := func(origine: Vector2, barbouillage: Color) -> void:
		if barbouillage.a == 0.0 and soucoupes.any(func(s: Node2D) -> bool:
				return is_instance_valid(s) and origine.distance_to(s.global_position) < 150.0):
			par_ennemi[0] = true
	j1.etourdi.connect(sur_ennemi)
	var fin := Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not par_ennemi[0] and Time.get_ticks_msec() < fin:
		var centre: Vector2 = l1.global_position + l1.CENTRE
		var partie := soucoupe == null or not is_instance_valid(soucoupe) or soucoupe.global_position.distance_to(centre) > 150.0
		if partie and not j1.est_etourdi() and not j1.est_invulnerable():
			soucoupe = spawner.spawn_soucoupe(centre.y)
			soucoupe.position.x = centre.x
			soucoupes.append(soucoupe)
		await physics_frame
	j1.etourdi.disconnect(sur_ennemi)
	_check(par_ennemi[0], "une soucoupe étourdit le lion de %s" % j1.pseudo)

	# La gerbe de l'hôte sur le lion du deuxième client, qu'il place sur la trajectoire tant qu'il peut
	# être étourdi, jusqu'à ce qu'elle l'étourdisse (barbouillé de la couleur de l'hôte : pas un ennemi)
	var l2: Node2D = clients[1]
	var j2: Joueur = l2.joueur
	var par_hote := [false]
	var sur_gerbe_hote := func(_origine: Vector2, barbouillage: Color) -> void:
		if barbouillage == moi.couleur:
			par_hote[0] = true
	j2.etourdi.connect(sur_gerbe_hote)
	lion_hote.global_position = Vector2(600, 250)
	lion_hote.direction_du_lion = 1
	Input.action_press("vomir")
	fin = Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not par_hote[0] and Time.get_ticks_msec() < fin:
		if lion_hote.est_en_train_de_vomir and not j2.est_etourdi() and not j2.est_invulnerable():
			l2.global_position = _zone_de_contact(lion_hote, 2).global_position - l2.CENTRE
		await physics_frame
	Input.action_release("vomir")
	j2.etourdi.disconnect(sur_gerbe_hote)
	_check(par_hote[0], "la gerbe de l'hôte étourdit le lion de %s, qui passe dessous" % j2.pseudo)

	# La gerbe du troisième client (ses commandes, venues du réseau) sur le lion de l'hôte, de même
	var par_client := [false]
	var sur_gerbe_client := func(_origine: Vector2, barbouillage: Color) -> void:
		if barbouillage == j3.couleur:
			par_client[0] = true
	moi.etourdi.connect(sur_gerbe_client)
	fin = Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not par_client[0] and Time.get_ticks_msec() < fin:
		if l3.est_en_train_de_vomir and not j3.est_etourdi() and not moi.est_etourdi() and not moi.est_invulnerable():
			l3.global_position = Vector2(1200, 250)
			lion_hote.global_position = _zone_de_contact(l3, 2).global_position - lion_hote.CENTRE
		await physics_frame
	moi.etourdi.disconnect(sur_gerbe_client)
	_check(par_client[0], "la gerbe de %s, vomie à ses commandes, étourdit le lion de l'hôte" % j3.pseudo)

	# Un choc : un client lancé à pleine vitesse percute le lion de l'hôte, arrêté sur sa route. L'hôte
	# n'est posé devant lui que libre de tout contact (un lion qui le touche déjà ne « rentre » plus
	# dans son pare-chocs : pas de choc, mesuré) et loin des autres lions (qui le percuteraient à la
	# place). Le choc attendu est celui qui fait bouger le compte de l'hôte, quel que soit le lion
	# (un client de passage peut le percuter avant) : il doit compter aussi pour ce lion-là, au même
	# tick. Plusieurs chocs peuvent tomber dans ce tick (mesuré : deux clients comptés au même tick,
	# 1 fois sur 200) : chaque choc comptant pour ses deux lions, les clients gagnent alors autant de
	# chocs que l'hôte, plus deux par choc entre clients ; un choc compté d'un seul côté rompt la parité.
	var chocs_hote := moi.chocs
	fin = Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	var chocs_clients: Array = []  # ceux de chaque client au début du tick que l'on attend
	var libre := func(place: Vector2, sauf: Node2D) -> bool:
		return main.lions.all(func(autre: Node2D) -> bool:
			return autre == lion_hote or autre == sauf or autre.global_position.distance_to(place) >= ISOLEMENT)
	while moi.chocs == chocs_hote and Time.get_ticks_msec() < fin:
		chocs_clients = clients.map(func(l: Node2D) -> int: return l.joueur.chocs)
		if lion_hote.velocity.length() < 1.0 and lion_hote.pare_chocs.get_overlapping_areas().is_empty():
			for l: Node2D in clients:
				var dans_le_ciel := Rect2(300, 150, 1300, 550).has_point(l.global_position)
				var place: Vector2 = l.global_position + l.velocity.normalized() * 80.0
				if l.velocity.length() >= VITESSE_CHOC and not l.joueur.est_etourdi() and dans_le_ciel and libre.call(place, l):
					lion_hote.global_position = place
					break
		await physics_frame
	var partenaires: Array[String] = []
	var gagnes_clients := 0
	for i in range(clients.size()):
		var gagnes: int = clients[i].joueur.chocs - chocs_clients[i]
		gagnes_clients += gagnes
		if gagnes != 0:
			partenaires.append(clients[i].joueur.pseudo)
	var gagnes_hote := moi.chocs - chocs_hote
	_check(gagnes_hote >= 1 and gagnes_clients >= gagnes_hote and (gagnes_clients - gagnes_hote) % 2 == 0,
		"le lion de %s percute celui de l'hôte : un choc compté pour les deux (hôte +%d, clients +%d)" % [", ".join(partenaires), gagnes_hote, gagnes_clients])


func _animer_bout_client(main: Node, manche: Node, gs: Node, programme: Programme) -> void:
	var calme := _option("calme", "")
	_check(await _jouer_jusqu_a(main, programme, func() -> bool: return FileAccess.file_exists(calme), ReglesBataille.DUREE_MANCHE + 30.0),
		"le jeu dure jusqu'au calme annoncé par lancer.sh (%s)" % calme)
	programme.relacher()
	_ecrire_mesure()
	var prediction: Node = main.lion.prediction
	# Mesure seule (phase 16) : sans latence, mais avec les rencontres, où l'hôte déplace les lions
	# (recalages attendus) et les chocs.
	print("PREDICTION %s (sans latence, rencontres comprises) : erreur max %.2f px, %d états sur %d au-delà de 4 px ; recalages %d ; rejeu le plus long %d pas"
		% [reseau.pseudo, prediction.erreur_max(), prediction.erreurs_au_dela(ECART_PREDICTION), prediction.etats_depuis(1), prediction.recalages,
			prediction.rejeu_max])
	print("CALME VU")
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1),
		"le lion du client arraché a disparu ici aussi (%d lions)" % main.lions.size())
	await _finir_manche_client(main, manche)
