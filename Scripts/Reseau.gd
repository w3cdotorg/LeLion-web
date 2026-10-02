extends Node
## La session réseau (spec §3.1 du jeu en ligne) : la poignée de main (version, pseudo),
## l'attribution des index et des couleurs par l'hôte, les arrivées et les départs, et la table du
## salon (phase 13) : qui est là, sa couleur, s'il est prêt, le niveau et le lancement de la
## manche, que l'hôte ne permet que si le salon est prêt (`raison_attente`). Le salon
## (`Scripts/Salon.gd`) affiche la table et porte le bouton de l'hôte. Pendant la manche (phase 14),
## la barrière de chargement : chaque poste signale sa scène de jeu chargée
## (`signaler_scene_chargee`), l'hôte les note (`scenes_chargees`) ; la manche synchronisée
## (`Scripts/Manche.gd`) attend tous les joueurs avant l'intro, et suit les départs
## (`joueur_parti`, `hote_perdu`). Après la manche (phase 18, l'écran Résultats), l'hôte en relance une
## avec les mêmes joueurs (`relancer_manche` : Revanche, Niveau suivant) ou ramène chaque poste au salon
## (`revenir_au_salon`). Hors réseau (solo, retour au titre), le pair est un
## `OfflineMultiplayerPeer` : ce poste est son propre hôte (`multiplayer.is_server()` vrai), et
## `quitter()` y revient toujours.
##
## Transport (phase 1 du jeu en ligne) : les canaux sont ceux d'un `Transport` (`TransportENet`, ou
## `TransportWebRTC` dans l'export Web), dont ce script donne le pair à `SceneMultiplayer` dès qu'il
## existe (au retour de `rejoindre()`, ou plus tard : `Transport.pair_pret`) et qu'il sert à chaque
## image ; il ne nomme aucune classe d'ENet. Un transport quitté finit son départ en arrière-plan
## (`_partants`). Chez l'hôte, la partie n'existe qu'au `pret` du transport (son code) : un échec avant
## est un échec de connexion ; après, la fermeture de la salle (`Transport.salle_fermee`) n'arrête que
## les arrivées.
##
## Battement et silences : chaque poste en session envoie un battement par seconde (`_battement`, non
## fiable) ; tout ce que ce script reçoit d'un pair, battement ou RPC, remet son silence à zéro
## (`_entendus`) ; SILENCE_SESSION sans rien de lui le déclare parti, chez l'hôte comme chez un client,
## SILENCE_CHARGEMENT pendant le chargement de la manche (un poste qui charge sa scène ou compile ses
## shaders ne répond plus). Chez l'hôte, un client parti, muet ou exclu est libéré (`_liberer`, puis
## `Transport.liberer`) : son départ arrive par `peer_disconnected`, comme tous les départs.
## `quitter()` part proprement (spec §5) : un adieu fiable (`_recevoir_adieu`), que l'autre côté traite
## aussitôt (l'hôte libère ce client, un client perd l'hôte), puis le transport ferme sa session une fois
## l'adieu envoyé (`Transport.quitter`, une seconde au plus, en arrière-plan). Le relais du serveur est
## coupé (`server_relay`) : tout passe par l'hôte.
##
## La poignée de main passe par l'authentification de `SceneMultiplayer` : des octets bruts
## (`var_to_bytes` d'un dictionnaire), échangés avant tout RPC, si bien que deux versions
## différentes du jeu peuvent encore se dire pourquoi elles ne jouent pas ensemble. Le client
## envoie `{jeu, version, pseudo}` ; l'hôte répond `{accepte: true, index, couleur, pseudo}` ou
## `{accepte: false, raison, version_hote}` ; le client refusé ferme lui-même la connexion (sinon,
## le délai de la poignée de main la ferme). Un joueur accepté est inscrit chez l'hôte dès la
## réponse (sa place est prise) : deux demandes simultanées ne peuvent ni obtenir la même place,
## ni dépasser le nombre de places.
##
## Salon : l'hôte tient la table dans `inscrits` et la diffuse, arrivés seulement, à chaque
## changement (`_recevoir_salon`, fiable) ; chaque poste la lit dans `table_salon`. Les clients
## demandent (couleur, Prêt) et l'hôte arbitre, DEMANDES_SALON_PAR_SECONDE demandes par seconde et par
## client au plus (spec §8.2 : au-delà, il les jette). Tous ces RPC passent par cet autoload, présent au
## même chemin sur chaque poste dès la connexion : une table envoyée avant que la scène du salon
## soit chargée chez un client l'y attend. Les RPC de l'hôte sont en mode "authority" (le moteur
## rejette tout autre émetteur) ; ceux des clients vérifient l'émetteur et leurs arguments. Phase 18 : le
## lancement et le retour au salon partent sur le canal fiable ordonné de la manche (CANAL_ORDONNE,
## celui des tampons, du territoire et de la fin), la table avec eux : chez un client, une manche relancée
## depuis l'écran Résultats n'arrive qu'après tout ce que la précédente a envoyé sur ce canal, sa fin
## comprise (sinon un tampon, un territoire ou une fin retardés par une perte arriveraient dans la
## manche neuve). La table diffusée à chaque changement du salon reste sur le canal 0, celui de la
## poignée de main : sur le canal 1, la première table d'un arrivant pouvait devancer la fin de son
## authentification et être jetée (vu en préparant la phase 18, sous le relais du test réseau). Phase 19
## (M6) : chaque table est numérotée ; un client ne repose jamais une table plus ancienne que la dernière
## posée, d'où qu'elle vienne, et joue chaque manche sur la table et le niveau de son lancement.
##
## Autoload : les tests `--script`, compilés avant l'enregistrement des autoloads, le récupèrent
## par `root.get_node("Reseau")` et ne le nomment pas.

## Chez l'hôte : un joueur a fini sa poignée de main (il est dans `inscrits`, les RPC passent).
signal joueur_arrive(id: int)
## Chez l'hôte : un joueur arrivé est parti ; sa place, son index et sa couleur sont libres.
signal joueur_parti(id: int)
## Chez l'hôte, pendant une manche : la scène de jeu du joueur `id` est chargée (l'hôte compris).
signal scene_chargee(id: int)
## Chez le client : l'hôte l'a accepté et la connexion est établie (`index_local`, `couleur_locale`).
signal inscrit(index: int, couleur: Color)
## Chez le client : l'hôte a refusé ; `raison` est une des constantes REFUS_* (clé de traduction
## pour l'écran En ligne), `version_hote` la version de l'hôte. Le poste est déjà
## revenu hors réseau quand le signal part.
signal refuse(raison: String, version_hote: String)
## Chez le client : pas d'inscription (le transport n'a pas ouvert son canal, ou la poignée de main n'a
## pas fini dans son délai). Chez l'hôte : la partie n'a pas pu être créée (le transport échoue avant son
## `pret` : la signalisation refuse ou ne répond pas). Le poste est déjà revenu hors réseau quand le
## signal part ; `raison_echec` dit pourquoi.
signal connexion_echouee()
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
## réseau quand le signal part ; `raison_perte` dit pourquoi (phase 18 : un joueur exclu par la barrière
## de chargement le sait). N4 : si le pair de l'hôte tombe lui-même en erreur, ou si son transport se
## ferme de lui-même (`Transport.servir` faux), ce même signal part aussi chez l'hôte (server_disconnected
## n'y distingue pas les deux cas) : le salon et la scène de jeu l'écoutent des deux côtés (l'hôte qui
## perd sa session revient à l'écran En ligne, ou au titre depuis une manche, comme un client).
signal hote_perdu()
## Sur chaque poste en session : la table du salon (`table_salon`), son niveau ou ses places ont
## changé ; chez l'hôte, aussi quand une place se réserve ou se libère (le bouton Démarrer en
## dépend, `raison_attente`), quand la partie a son code (`code_partie`) et quand plus personne ne peut
## la rejoindre (`raison_salle_fermee`).
signal salon_change()
## Sur chaque poste en session : l'hôte lance la manche. `fiches` : une fiche
## `{"id_reseau", "pseudo", "couleur"}` par joueur, dans l'ordre des index compactés (0..n-1), à
## donner à `GameState.configurer_bataille_reseau` avant de charger la scène de jeu.
signal manche_lancee(fiches: Array[Dictionary])
## Sur chaque poste en session : l'hôte ramène tout le monde au salon (phase 18, depuis l'écran
## Résultats) ; la table (sans les partis, personne prêt) est déjà arrivée, la manche n'est plus en cours.
signal salon_rouvert()

## Port de jeu par défaut : celui du transport ENet.
const PORT := TransportENet.PORT
## Identifiant de la poignée de main : une demande qui ne le porte pas vient d'un autre programme.
const JEU := "LELION"
## Délai de la poignée de main d'un client, du canal ouvert (`Transport.connecte`) à l'inscription (spec
## §9 : 5 s puis message) ; l'ouverture du canal a le délai de son transport.
const DELAI_CONNEXION := 5.0
## Délai laissé à chaque pair pour finir la poignée de main (`SceneMultiplayer.auth_timeout`).
const DELAI_POIGNEE_DE_MAIN := 3.0
## Longueur maximale d'un pseudo, en caractères, imposée par l'hôte (l'étiquette du lion est
## centrée sur lui et coupée par le bord de l'écran au-delà d'une douzaine de caractères).
const PSEUDO_MAX := 12
## Taille maximale, en octets, d'un envoi de poignée de main : au-delà, `bytes_to_var` ne décode
## pas (le coût du décodage doit rester borné, même pour un émetteur quelconque sur le port UDP).
const TAILLE_POIGNEE_DE_MAIN_MAX := 1024
const REFUS_VERSION := "RESEAU_REFUS_VERSION"
const REFUS_PLEIN := "RESEAU_REFUS_PLEIN"
const REFUS_MANCHE := "RESEAU_REFUS_MANCHE"
const REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"
## Pourquoi l'hôte est perdu (`raison_perte`), en clés de traduction : il est parti (ou ne répond
## plus), ou il a exclu ce poste (barrière de chargement, phase 18).
const PERTE_HOTE := "RESEAU_HOTE_PERDU"
const PERTE_EXCLU := "RESEAU_EXCLU"
## Entre l'annonce de son exclusion à un joueur et sa libération par l'hôte, en secondes : le temps que
## l'annonce arrive (renvoyée au besoin), et que l'exclu s'en aille de lui-même.
const DELAI_EXCLUSION := 0.5
## Pourquoi l'hôte ne peut pas encore démarrer la partie (`raison_attente`), en clés de traduction.
const ATTENTE_JOUEURS := "SALON_ATTENTE_JOUEURS"
const ATTENTE_ARRIVEE := "SALON_ATTENTE_ARRIVEE"
const ATTENTE_PRETS := "SALON_ATTENTE_PRETS"
## Période du battement, en secondes : chaque poste en session en envoie un à chacun de ses pairs.
const PERIODE_BATTEMENT := 1.0
## Silence d'un pair, en secondes, au-delà duquel il est déclaré parti (spec §2) : au salon et en
## manche, chez l'hôte comme chez un client (un poste planté, en veille, un onglet caché).
const SILENCE_SESSION := 10.0
## Pendant le chargement de la manche, du lancement à l'intro : un poste qui charge sa scène de jeu
## (ou compile ses shaders, sous Windows) ne répond plus, parfois plus de 5 s.
const SILENCE_CHARGEMENT := 30.0
## Canal du lancement et du retour au salon, table comprise : le canal fiable ordonné de la manche
## (`Manche.CANAL_PEINTURE`, spec §4), phase 18.
const CANAL_ORDONNE := 1
## Demandes de salon (couleur, Prêt) admises par seconde et par client, chez l'hôte (spec §8.2) : au-delà,
## il les jette (`LimiteDebit`, un seau de 10 jetons rempli de 10 par seconde). Un joueur n'en fait jamais
## autant : le salon n'agit qu'à l'appui d'une touche, d'un bouton ou du stick.
const DEMANDES_SALON_PAR_SECONDE := 10

## Ce que `_poser_salon` fait d'une table reçue de l'hôte (M6) : posée, plus ancienne que la dernière
## posée (ignorée), ou illisible (ignorée, signalée).
enum Pose { POSEE, PERIMEE, ILLISIBLE }

## Version présentée à la poignée de main (`application/config/version`) ; deux versions
## différentes ne jouent pas ensemble. Modifiable par les tests.
var version: String = ProjectSettings.get_setting("application/config/version", "")
## Pseudo de ce poste, présenté à l'hôte (ou inscrit tel quel quand ce poste héberge).
var pseudo := ""
## Nombre de joueurs d'une partie hébergée, hôte compris ; `heberger()` la borne à
## [2, `EtatPartie.NB_JOUEURS_MAX`] (N3 : au-delà, `premier_index_libre` renverrait -1 pour l'hôte
## lui-même).
var places := EtatPartie.NB_JOUEURS_MAX
## Posé au lancement de la manche (phase 13), et gardé tant qu'on enchaîne les manches depuis l'écran
## Résultats ; retiré au retour au salon (phase 18) : tant qu'il est vrai, l'hôte refuse tout nouveau
## venu (pas d'arrivée en cours de manche, spec §1).
var manche_en_cours := false
## Chez l'hôte : les joueurs inscrits, hôte compris, par identifiant réseau :
## `{"index": int, "couleur": Color, "pseudo": String, "arrive": bool, "pret": bool}`. Un accepté y
## entre dès la réponse de l'hôte (sa place est réservée), avec `arrive` faux jusqu'à la fin de sa
## poignée de main : seuls les arrivés sont dans `table_salon` et reçoivent des RPC. Vide chez un
## client et hors réseau.
var inscrits: Dictionary[int, Dictionary] = {}
## Sur chaque poste en session : la table du salon, la même partout, triée par index : une fiche
## `{"id": int, "index": int, "couleur": Color, "pseudo": String, "pret": bool}` par joueur ARRIVÉ
## (jamais une place seulement réservée). Construite par l'hôte depuis `inscrits`, reçue par les
## clients ; vide hors réseau.
var table_salon: Array[Dictionary] = []
## Niveau choisi par l'hôte au salon (index de `EtatPartie.NIVEAUX`), diffusé avec la table.
var niveau_salon := 0
## Places de la partie (`places` de l'hôte), diffusées avec la table.
var places_salon := EtatPartie.NB_JOUEURS_MAX
## Places seulement réservées (une poignée de main en cours, pas encore de carte), diffusées avec la
## table (phase 18, M2 de la revue finale 13 : sans elles, un client lisait « l'hôte peut démarrer »
## pendant qu'un joueur arrivait, le bouton de l'hôte grisé).
var places_reservees := 0
## Numéro de la table du salon (M6, revue finale de la phase 18) : chez l'hôte, celui de la dernière
## diffusée (un de plus à chaque `_diffuser_salon`) ; chez un client, celui de la dernière posée. La table
## voyage sur deux canaux qui ne s'attendent pas (seule sur le canal 0, avec le lancement et le retour au
## salon sur le canal ordonné) : chez un client, une table plus ancienne que la dernière posée (un
## lancement ou un retour perdu puis renvoyé, arrivé après une table plus récente du canal 0) n'est
## jamais reposée. 0 hors session.
var numero_table := 0
## Le niveau de la manche lancée (index de `EtatPartie.NIVEAUX`) : chez l'hôte, celui du salon au
## lancement ; chez un client, celui que porte le lancement, même quand une table plus récente l'a
## devancé (M6). Ce que charge chaque poste (`Salon.entrer_en_manche`). Valide d'un lancement au
## suivant ; remis à 0 par `quitter()`.
var niveau_manche := 0
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE ou PERTE_EXCLU), posé juste
## avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Chez un client, ou chez l'hôte dont la partie n'a pas pu être créée : pourquoi la dernière connexion a
## échoué, posé juste avant `connexion_echouee` : la raison du transport (Transport.ECHEC_*), ou vide (la
## poignée de main sans réponse dans son délai, un transport fermé de lui-même) ; ce que montre l'écran En
## ligne (spec §9).
var raison_echec := ""
## Chez l'hôte : pourquoi plus personne ne peut rejoindre la partie (`Transport.salle_fermee` :
## Transport.ECHEC_EXPIREE, ou une autre raison), vide tant que la salle accueille ; le salon le dit à la
## place du code. La partie continue. Vide hors réseau et chez un client.
var raison_salle_fermee := ""
## Vrai si ce poste a un transport pour jouer en réseau : ENet sur le desktop (le développement, les
## tests), WebRTC dans l'export Web (phase 4). Les tests le mettent à faux : `creer_partie` et
## `rejoindre_partie` renvoient alors ERR_UNAVAILABLE sans rien ouvrir (le garde-fou d'une plateforme
## sans transport, et son message à l'écran En ligne).
var transport_disponible := true
## Si valide, fabrique le transport de chaque nouvelle session à la place de `_nouveau_transport`
## (`func(port: int) -> Transport`) : les tests y mettent un transport simulé. Invalide dans le jeu.
var fabrique_transport := Callable()
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
var index_local := -1
var couleur_locale := Color.TRANSPARENT
## Chez l'hôte, pendant une manche : les identifiants des joueurs dont la scène de jeu est chargée,
## dans l'ordre (l'hôte compris) ; vidé au lancement de chaque manche et hors réseau.
var scenes_chargees: Array[int] = []
## Silence toléré des pairs de cette session, en secondes (SILENCE_SESSION ou SILENCE_CHARGEMENT).
var silence := SILENCE_SESSION
## Chez l'hôte : le code de la partie (`Transport.pret`), ce qu'un client donne pour la rejoindre ; vide
## hors réseau, chez un client, et tant que le transport ne l'a pas donné.
var code_partie := ""

## Vrai dès que l'issue d'une connexion est décidée (refus, échec, hôte perdu) : un seul signal
## part, même quand le transport signale ensuite la fermeture qui en découle.
var _issue_decidee := false
## Incrémenté à chaque `quitter()` (donc à chaque `heberger()` ou `rejoindre()`, qui commencent par
## lui) : la génération de la session en cours. `_decider` capture la sienne avant de différer sa
## fermeture ; si une nouvelle session a déjà commencé quand l'appel différé s'exécute, il ne doit
## ni la fermer, ni émettre un signal qui ne la concerne plus.
var _generation := 0
var _delai: Timer
## Le transport de la session en cours (null hors réseau).
var _transport: Transport
## Les transports quittés dont le départ n'est pas fini, servis par `_process` jusqu'à leur fermeture.
var _partants: Array[Transport] = []
## Chez un client : vrai de `rejoindre()` à l'inscription ; une fermeture pendant ce temps est un échec
## de connexion, pas un hôte perdu.
var _connexion_en_cours := false
## Chez l'hôte : vrai de `heberger()` au `pret` du transport, quand il ne vient pas pendant l'appel
## (WebRTC : la salle de la signalisation) ; un échec ou une fermeture pendant ce temps est un échec de
## connexion : la partie n'a jamais existé.
var _creation_en_cours := false
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
var _exclu := false
## Chez un client : la raison de l'échec du transport de la session (`Transport.echec`), jusqu'à l'échec
## de connexion qui suit (`raison_echec`).
var _raison_transport := ""
## Les pairs dont ce poste écoute le silence : par identifiant, l'instant (ms) où il a reçu d'eux pour
## la dernière fois. Chez l'hôte, chaque client arrivé (sa poignée de main finie) ; chez un client,
## l'hôte, une fois inscrit. Vide hors réseau.
var _entendus: Dictionary[int, int] = {}
## L'instant (ms) du prochain battement de ce poste.
var _prochain_battement := 0
## L'instant (ms) de la dernière écoute des silences (`_ecouter`) : celui du verdict de la suivante.
var _derniere_ecoute := 0
## Chez l'hôte : le débit des demandes de salon de chaque client (DEMANDES_SALON_PAR_SECONDE), en secondes.
var _limite_salon := LimiteDebit.new(DEMANDES_SALON_PAR_SECONDE, DEMANDES_SALON_PAR_SECONDE)


func _ready() -> void:
	# Les délais courent aussi quand l'arbre est en pause (fin de manche).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_delai = Timer.new()
	_delai.one_shot = true
	_delai.timeout.connect(_sur_delai_depasse)
	add_child(_delai)
	var api := _api()
	api.server_relay = false  # M5 : aucun client ne parle à un autre, tout passe par l'hôte
	api.peer_authenticating.connect(_sur_debut_poignee_de_main)
	api.peer_authentication_failed.connect(_sur_echec_poignee_de_main)
	api.peer_connected.connect(_sur_pair_connecte)
	api.peer_disconnected.connect(_sur_pair_deconnecte)
	api.connected_to_server.connect(_sur_connecte_a_l_hote)
	api.connection_failed.connect(_sur_connexion_echouee)
	api.server_disconnected.connect(_sur_hote_perdu)


## Héberge une partie sur `port` : quitte d'abord toute session en cours, borne `places`, puis ce
## poste s'inscrit lui-même (index 0, première couleur). Si le port est pris, renvoie l'erreur du
## transport sans rien changer de plus (spec §9 : « port occupé ») : la session précédente reste
## close, mais rien de neuf n'est créé.
func heberger(port := PORT) -> Error:
	quitter()
	_clore_partants()  # une session hébergée qui part encore tient son port : le libérer d'abord
	places = clampi(places, EtatPartie.NB_JOUEURS_MIN, EtatPartie.NB_JOUEURS_MAX)
	var transport := _nouveau_transport(port)
	_brancher(transport)  # avant `heberger()` : `pret` peut partir pendant l'appel
	var erreur := transport.heberger()
	if erreur != OK:
		return erreur
	_transport = transport
	_creation_en_cours = code_partie.is_empty()  # `pret` n'est pas parti pendant l'appel : il viendra
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = transport.pair()
	index_local = premier_index_libre(inscrits, places)
	couleur_locale = premiere_couleur_libre(inscrits)
	inscrits[multiplayer.get_unique_id()] = {"index": index_local, "couleur": couleur_locale,
		"pseudo": pseudo_ou_defaut(pseudo, index_local), "arrive": true, "pret": false}
	places_salon = places
	_diffuser_salon()
	return OK


## Rejoint l'hôte ENet à `adresse` (une IPv4) et `port` : `rejoindre_partie` avec le code `adresse:port`
## (les tests et le desktop de développement).
func rejoindre(adresse: String, port := PORT) -> Error:
	return rejoindre_partie("%s:%d" % [adresse.strip_edges(), port])


## Crée une partie (l'écran En ligne) : `heberger(port)` si ce poste a un transport pour jouer en réseau
## (`transport_disponible`), sinon ERR_UNAVAILABLE sans rien changer. Son code (`code_partie`) vient du
## transport : `ip:port` en ENet, pendant l'appel ; un code de salle en WebRTC, plus tard, quand la salle de
## la signalisation existe (`salon_change`), ou `connexion_echouee` si elle ne peut pas exister.
func creer_partie(port := PORT) -> Error:
	if not transport_disponible:
		return ERR_UNAVAILABLE
	return heberger(port)


## Rejoint la partie `code` avec le transport de ce poste (l'écran En ligne) : un code de salle en WebRTC
## (l'export Web, qui refuse une adresse `ip:port`), le code `ip:port` (ou `ip`) d'un hôte en ENet. Un
## code que le transport refuse (ERR_INVALID_PARAMETER, M8 : aucun nom d'hôte, dont la résolution
## bloquerait le jeu), ou aucun transport (`transport_disponible` faux : ERR_UNAVAILABLE), ne change rien,
## pas même la session en cours. La réponse arrive par `inscrit`, `refuse` ou `connexion_echouee` (au plus
## tard après le délai du canal du transport, puis DELAI_CONNEXION). Renvoie l'erreur du transport si le
## client ne peut même pas être créé. Le pair du transport est posé dès qu'il existe : au retour (ENet),
## ou à `Transport.pair_pret` (WebRTC, à l'arrivée de son identifiant) ; d'ici là `en_ligne()` reste faux.
func rejoindre_partie(code: String) -> Error:
	if not transport_disponible:
		return ERR_UNAVAILABLE
	var transport := _nouveau_transport(PORT)
	var erreur := transport.rejoindre(code)
	if erreur != OK:
		return erreur
	quitter()
	_brancher(transport)  # après `quitter()` : la génération de la nouvelle session
	_transport = transport
	_connexion_en_cours = true
	_activer_poignee_de_main()
	if transport.pair() != null:
		multiplayer.multiplayer_peer = transport.pair()
	return OK


## Quitte le réseau : part proprement (les autres postes voient partir ce joueur, ou l'hôte, tout de
## suite : son adieu, puis le transport ferme sa session une fois l'adieu envoyé, en arrière-plan), remet
## `OfflineMultiplayerPeer` et oublie inscrits, table du salon, index, couleur, scènes chargées, code et
## manche en cours (une session hébergée finie n'a plus lieu d'être). Sans effet visible hors réseau :
## chaque chemin de retour au titre peut l'appeler (point de vigilance des phases 12/13). Le transport
## quitté n'est plus celui de la session avant même son `quitter()` ; il rejoint `_partants` dans tous les
## cas, servi par `_process` jusqu'à sa fermeture (oublié à l'image suivante s'il n'avait personne à
## prévenir).
func quitter() -> void:
	_generation += 1
	_delai.stop()
	_dire_adieu()  # avant la fermeture : le transport l'envoie avant son DISCONNECT
	var partant := _transport
	_transport = null
	if partant != null:
		partant.quitter()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if partant != null:
		_partants.append(partant)  # son départ continue, servi par `_process`
	_api().auth_callback = Callable()
	inscrits.clear()
	table_salon.clear()
	scenes_chargees.clear()
	silence = SILENCE_SESSION
	_entendus.clear()
	_limite_salon.vider()
	code_partie = ""
	raison_salle_fermee = ""
	_raison_transport = ""
	_connexion_en_cours = false
	_creation_en_cours = false
	niveau_salon = 0
	places_salon = EtatPartie.NB_JOUEURS_MAX
	places_reservees = 0
	numero_table = 0
	niveau_manche = 0
	_exclu = false
	index_local = -1
	couleur_locale = Color.TRANSPARENT
	manche_en_cours = false
	_issue_decidee = false


## Le transport d'une nouvelle session (spec §3.1) : celui de `fabrique_transport` (les tests), sinon
## WebRTC dans l'export Web (`port` n'y sert pas), ENet ailleurs (le desktop, les tests).
func _nouveau_transport(port: int) -> Transport:
	if fabrique_transport.is_valid():
		return fabrique_transport.call(port)
	if OS.has_feature("web"):
		return TransportWebRTC.new()
	return TransportENet.new(port, places)


## Branche les signaux de `transport` sur cette session (la génération en cours) : ceux d'une session
## périmée ne font rien.
func _brancher(transport: Transport) -> void:
	transport.pret.connect(_sur_transport_pret.bind(_generation))
	transport.connecte.connect(_sur_transport_connecte.bind(_generation))
	transport.pair_pret.connect(_sur_transport_pair_pret.bind(_generation))
	transport.echec.connect(_sur_transport_echec.bind(_generation))
	transport.salle_fermee.connect(_sur_transport_salle_fermee.bind(_generation))


## En session, le transport, le battement et l'écoute des silences ; puis les départs en cours, oubliés
## une fois leur transport fermé. Un transport de session qui se ferme de lui-même (`servir()` faux sans
## `quitter()` ni `clore()`) : la session est perdue (`_sur_hote_perdu`), sans battement ni écoute.
func _process(_delta: float) -> void:
	if _transport != null and not _transport.servir():
		_sur_hote_perdu()
	elif en_ligne():
		var maintenant := Time.get_ticks_msec()
		_battre(maintenant)
		_ecouter(maintenant)
	for partant: Transport in _partants.duplicate():
		if not partant.servir():
			_partants.erase(partant)


## Ferme tout de suite les départs en cours (leurs ports se libèrent).
func _clore_partants() -> void:
	for partant: Transport in _partants:
		partant.clore()
	_partants.clear()


## Le silence toléré des pairs de cette session devient `secondes` (SILENCE_SESSION ou
## SILENCE_CHARGEMENT). Raccourci (la fin du chargement), le silence déjà écoulé ne compte plus : chaque
## pair suivi a un délai de grâce neuf, `secondes` à partir de maintenant (un hôte figé au chargement, ou
## un client figé après sa scène chargée, n'a pas encore pu battre quand l'intro passe à SILENCE_SESSION).
## Allongé, rien d'autre ne change.
func definir_silence(secondes: float) -> void:
	if secondes < silence:
		var maintenant := Time.get_ticks_msec()
		for id: int in _entendus:
			_entendus[id] = maxi(_entendus[id], maintenant)
	silence = secondes


## Le battement de ce poste, une fois par PERIODE_BATTEMENT : chez l'hôte, à chaque client arrivé ;
## chez un client, à l'hôte, une fois inscrit (avant, aucune RPC ne passe).
func _battre(maintenant: int) -> void:
	if maintenant < _prochain_battement:
		return
	_prochain_battement = maintenant + int(PERIODE_BATTEMENT * 1000.0)
	if multiplayer.is_server():
		if not multiplayer.get_peers().is_empty():
			_battement.rpc()
	elif _entendus.has(MultiplayerPeer.TARGET_PEER_SERVER):
		_battement.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


## L'écoute des silences, à `maintenant` (ms) : chez l'hôte, chaque client muet depuis plus de `silence`
## est libéré ; chez un client, l'hôte muet est perdu. Le verdict se rend à l'instant de l'écoute
## précédente, pas à `maintenant` : tout ce qui était arrivé avant elle a été relevé au début de cette
## image (`SceneTree` relève les paquets avant les `_process`), alors que ce qui arrive pendant un gel de
## ce poste (une longue image, un `_process` figé avant celui-ci) ne l'est pas encore. Un poste qui sort
## d'un gel ne déclare donc personne parti à tort, et un poste lent (quelques images par seconde) rend
## quand même son verdict, une image en retard.
func _ecouter(maintenant: int) -> void:
	var instant := _derniere_ecoute
	_derniere_ecoute = maintenant
	for id in pairs_muets(_entendus, instant, int(silence * 1000.0)):
		_entendus.erase(id)
		if multiplayer.is_server():
			_liberer(id, _generation)
		else:
			_decider("hote_perdu")


## Les identifiants de `entendus` (identifiant → instant, en ms, du dernier paquet reçu) dont le silence
## dépasse `silence_ms` à `maintenant`, dans l'ordre croissant.
static func pairs_muets(entendus: Dictionary[int, int], maintenant: int, silence_ms: int) -> Array[int]:
	var muets: Array[int] = []
	for id: int in entendus:
		if maintenant - entendus[id] > silence_ms:
			muets.append(id)
	muets.sort()
	return muets


## Un paquet de `Reseau` reçu du pair `id` (battement ou RPC) : son silence repart de zéro. Sans effet
## pour un pair dont ce poste n'écoute pas le silence.
func _entendre(id: int) -> void:
	if _entendus.has(id):
		_entendus[id] = Time.get_ticks_msec()


## Le battement d'un pair (non fiable, canal 0 : spec §5).
@rpc("any_peer", "call_remote", "unreliable")
func _battement() -> void:
	_entendre(multiplayer.get_remote_sender_id())


## Le départ volontaire de ce poste, annoncé à ses pairs (spec §5) : un adieu fiable, que le transport
## envoie avant de fermer (`Transport.quitter`). Rien hors session, ni avant l'inscription (aucune RPC
## ne passe encore).
func _dire_adieu() -> void:
	if not en_ligne() or multiplayer.get_peers().is_empty():
		return
	if multiplayer.is_server():
		_recevoir_adieu.rpc()
	else:
		_recevoir_adieu.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


## L'adieu d'un pair qui part : chez l'hôte, ce client est libéré tout de suite (une fois ses paquets en
## cours relevés) ; chez un client, l'hôte est perdu, sans attendre son silence.
@rpc("any_peer", "call_remote", "reliable")
func _recevoir_adieu() -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		_liberer.call_deferred(id, _generation)
	elif id == MultiplayerPeer.TARGET_PEER_SERVER:
		_decider("hote_perdu")


## Chez l'hôte : le joueur `id` n'a pas chargé sa scène de jeu à temps (la barrière de la manche,
## `Manche._exclure`) : il apprend son exclusion (`_recevoir_exclusion` : il verra PERTE_EXCLU, pas
## « L'hôte a quitté la partie ») et s'en va de lui-même ; DELAI_EXCLUSION plus tard, l'hôte le libère
## s'il est encore là (`_liberer` : figé, il n'a pas lu l'annonce) : son départ arrive par
## `joueur_parti`.
func exclure(id: int) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	_recevoir_exclusion.rpc_id(id)
	get_tree().create_timer(DELAI_EXCLUSION, true).timeout.connect(_liberer.bind(id, _generation))


## Chez l'hôte : libère le client `id` (muet, exclu, ou parti : son adieu), s'il est encore là dans la
## même session (`generation`) : son silence n'est plus écouté, et son transport le ferme sur-le-champ,
## sans attendre d'accusé de réception (I1, revue finale phase 14 : un pair figé, qui charge ou compile
## ses shaders, ou mort n'en enverra pas) ; son départ part aussitôt par `peer_disconnected`
## (`_sur_pair_deconnecte`).
func _liberer(id: int, generation: int) -> void:
	if generation != _generation or _transport == null or not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	_entendus.erase(id)
	_transport.liberer(id)


## Chez un client : l'hôte l'exclut de la manche (sa scène de jeu pas chargée à temps) ; ce poste s'en va
## aussitôt, et la perte de l'hôte le dit (`raison_perte` : PERTE_EXCLU). L'annonce est fiable, la
## libération par l'hôte qui suit ne l'est pas (`_liberer`).
@rpc("authority", "call_remote", "reliable")
func _recevoir_exclusion() -> void:
	_entendre(multiplayer.get_remote_sender_id())
	_exclu = true
	_decider("hote_perdu")


## Les fiches dont dépend le démarrage (`raison_attente`) : chez l'hôte, ses inscrits (places réservées
## comprises) ; chez un client, la table du salon, plus une fiche d'arrivant pas encore là par place
## réservée que l'hôte annonce (phase 18, M2 de la revue finale 13).
func fiches_attente() -> Array:
	if multiplayer.is_server():
		return inscrits.values()
	var fiches: Array = table_salon.duplicate()
	for i in range(places_reservees):
		fiches.append({"arrive": false, "pret": false})
	return fiches


## La scène de jeu de ce poste est chargée (appelé par la manche, chez chaque joueur) : chez l'hôte,
## noté tout de suite ; un client le fait savoir à l'hôte.
func signaler_scene_chargee() -> void:
	if multiplayer.is_server():
		_noter_scene_chargee(multiplayer.get_unique_id())
	else:
		_scene_chargee.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _noter_scene_chargee(id: int) -> void:
	if not scenes_chargees.has(id):
		scenes_chargees.append(id)
		scene_chargee.emit(id)


## Vrai si ce poste est en réseau (hôte ou client), faux hors réseau (solo), et chez un client tant que
## le pair de son transport n'existe pas (WebRTC : avant l'arrivée de son identifiant, `pair_pret`) :
## l'écran En ligne ne s'y fie pas pendant une connexion.
func en_ligne() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


## Décision de l'hôte sur une demande d'inscription (le dictionnaire décodé, ou n'importe quoi
## venu d'un autre programme). Dans l'ordre : demande mal formée, version différente, manche en
## cours, partie pleine ; sinon l'index et la couleur libres les plus bas, et le pseudo nettoyé.
## Ne modifie rien : c'est `_repondre` qui inscrit.
func examiner_demande(demande: Variant) -> Dictionary:
	if not (demande is Dictionary) or not _est_texte(demande, "jeu") or demande.jeu != JEU \
			or not _est_texte(demande, "version") or not _est_texte(demande, "pseudo"):
		return _refus(REFUS_DEMANDE)
	if demande.version != version:
		return _refus(REFUS_VERSION)
	if manche_en_cours:
		return _refus(REFUS_MANCHE)
	var index := premier_index_libre(inscrits, places)
	if index < 0:
		return _refus(REFUS_PLEIN)
	return {"accepte": true, "index": index, "couleur": premiere_couleur_libre(inscrits), "pseudo": pseudo_ou_defaut(demande.pseudo, index)}


## Le plus petit index de joueur qu'aucun inscrit n'occupe, parmi les `places` premiers (au plus
## NB_JOUEURS_MAX) ; -1 si la partie est pleine.
static func premier_index_libre(occupes: Dictionary[int, Dictionary], nb_places: int) -> int:
	var pris := occupes.values().map(func(fiche: Dictionary) -> int: return fiche.index)
	for i in range(mini(nb_places, EtatPartie.NB_JOUEURS_MAX)):
		if not pris.has(i):
			return i
	return -1


## La première couleur de la palette de bataille qu'aucun inscrit ne porte (transparente s'il n'y
## en a plus, ce que les places interdisent). Le salon (phase 13) laissera chacun en changer
## parmi les libres.
static func premiere_couleur_libre(occupes: Dictionary[int, Dictionary]) -> Color:
	var prises := occupes.values().map(func(fiche: Dictionary) -> Color: return fiche.couleur)
	for c in EtatPartie.PALETTE_BATAILLE:
		if not prises.has(c):
			return c
	return Color.TRANSPARENT


## Vrai pour un point de code que l'étiquette du lion ne doit jamais afficher : les contrôles C0
## (`strip_escapes` ne va que jusqu'à U+001F) et C1, les caractères invisibles (espaces et joints de
## largeur nulle, U+FEFF) et les forçages de sens (RLO/LRO, isolats) qui casseraient la lecture ou
## la mise en page d'un pseudo hostile.
static func _code_point_interdit(c: int) -> bool:
	return c <= 0x1F or (c >= 0x7F and c <= 0x9F) \
		or (c >= 0x200B and c <= 0x200F) or c == 0x2028 or c == 0x2029 \
		or (c >= 0x202A and c <= 0x202E) or (c >= 0x2060 and c <= 0x206F) or c == 0xFEFF


## Le pseudo tel que l'hôte l'inscrit : sans caractères de contrôle, invisibles ni forçages de sens
## (voir `_code_point_interdit`), coupé à PSEUDO_MAX caractères puis sans espaces autour (pour ne
## pas laisser d'espace finale à la coupe). Peut être vide : c'est `pseudo_ou_defaut` qui y met un
## repli.
static func pseudo_valide(texte: String) -> String:
	var propre := ""
	for i in texte.length():
		var c := texte.unicode_at(i)
		if not _code_point_interdit(c):
			propre += texte.substr(i, 1)
	# Un premier strip_edges avant la coupe ne gâche pas le quota sur des espaces qui l'entourent ;
	# le second retire celle que la coupe peut exposer en fin de chaîne (spec M3).
	return propre.strip_edges().left(PSEUDO_MAX).strip_edges()


## `pseudo_valide(texte)`, ou « Joueur N » (N = index + 1) si le nettoyage ne laisse rien : un
## pseudo vide ne doit jamais atteindre `inscrits` ni l'étiquette du lion.
static func pseudo_ou_defaut(texte: String, index: int) -> String:
	var propre := pseudo_valide(texte)
	return propre if not propre.is_empty() else "Joueur %d" % (index + 1)


## Chez l'hôte, à l'ouverture du salon (et au retour d'une manche, phase 18) : plus de manche en
## cours (les arrivées sont de nouveau acceptées), personne n'est prêt, le
## niveau est `niveau` (ramené dans la liste des niveaux).
func ouvrir_salon(niveau: int) -> void:
	if not multiplayer.is_server():
		return
	manche_en_cours = false
	for fiche: Dictionary in inscrits.values():
		fiche.pret = false
	niveau_salon = posmod(niveau, EtatPartie.NIVEAUX.size())
	_diffuser_salon()


## Chez l'hôte : le niveau du salon, ramené dans la liste des niveaux (en boucle). Sans effet
## pendant une manche.
func definir_niveau(niveau: int) -> void:
	if not multiplayer.is_server() or manche_en_cours:
		return
	niveau_salon = posmod(niveau, EtatPartie.NIVEAUX.size())
	_diffuser_salon()


## Demande de ce poste : la couleur libre suivante (`sens` 1) ou précédente (-1). L'hôte arbitre
## (`changer_couleur`) ; un client lui envoie sa demande.
func demander_couleur(sens: int) -> void:
	if multiplayer.is_server():
		changer_couleur(multiplayer.get_unique_id(), sens)
	else:
		_demande_couleur.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, sens)


## Demande de ce poste : prêt ou non. L'hôte arbitre (`definir_pret`) ; un client lui envoie sa
## demande.
func demander_pret(pret: bool) -> void:
	if multiplayer.is_server():
		definir_pret(multiplayer.get_unique_id(), pret)
	else:
		_demande_pret.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, pret)


## Chez l'hôte : le joueur `id` prend la couleur libre voisine de la sienne dans le sens `sens`
## (`couleur_voisine_libre`). Refusé (faux, rien ne change) pour un inconnu, un joueur pas encore
## arrivé ou déjà prêt (sa couleur est figée tant qu'il est prêt), un `sens` autre que 1 ou -1,
## pendant une manche, ou s'il n'y a aucune couleur libre. Les demandes sont traitées une à une :
## deux joueurs qui visent la même couleur ne peuvent pas l'obtenir tous les deux.
func changer_couleur(id: int, sens: int) -> bool:
	var fiche: Dictionary = inscrits.get(id, {})
	if not multiplayer.is_server() or manche_en_cours or absi(sens) != 1 or fiche.is_empty() \
			or not fiche.arrive or fiche.pret:
		return false
	var couleur := couleur_voisine_libre(inscrits, id, sens)
	if couleur == fiche.couleur:
		return false
	fiche.couleur = couleur
	if id == multiplayer.get_unique_id():
		couleur_locale = couleur
	_diffuser_salon()
	return true


## Chez l'hôte : le joueur `id` est prêt ou non. Refusé (faux) pour un inconnu, un joueur pas
## encore arrivé, pendant une manche, ou si rien ne change.
func definir_pret(id: int, pret: bool) -> bool:
	var fiche: Dictionary = inscrits.get(id, {})
	if not multiplayer.is_server() or manche_en_cours or fiche.is_empty() or not fiche.arrive or fiche.pret == pret:
		return false
	fiche.pret = pret
	_diffuser_salon()
	return true


## Chez l'hôte, quand il appuie sur « Démarrer la partie » : la manche commence. Plus aucune arrivée
## (`manche_en_cours`), index compactés sur 0..n-1 (des départs ont pu
## laisser des trous), table compactée diffusée (chaque client y lit son nouvel `index_local`),
## puis le lancement (`_recevoir_manche`, sur le même canal fiable que la table : il arrive
## après elle) ; `manche_lancee` part aussi ici. La demande est revérifiée ici, au moment même :
## faux, sans rien changer, si le salon n'est plus prêt (`salon_pret` : un joueur parti ou repassé
## non prêt dans la même image que l'appui, alors que le bouton n'était pas encore regrisé).
##
## M1 : les fiches de la manche sont aussi revérifiées avant tout engagement (défense en profondeur) :
## une table que `fiches_de_manche` refuse, une fois les index compactés (l'hôte n'y serait plus,
## par exemple), fait refuser le lancement, sans rien changer. Le chargement commence : le silence
## toléré devient SILENCE_CHARGEMENT, et plus aucune scène n'est chargée.
func lancer_manche() -> bool:
	if not multiplayer.is_server() or manche_en_cours or not salon_pret(inscrits):
		return false
	return _lancer()


## Chez l'hôte, depuis l'écran Résultats (phase 18) : une manche neuve avec les joueurs encore là, sur le
## niveau `niveau` (ramené dans la liste, en boucle : Revanche, le même ; Niveau suivant, le suivant),
## comme `lancer_manche` (index recompactés, table diffusée, lancement, chargement), sans repasser par le
## salon : la manche reste en cours (aucune arrivée) et personne n'a à se redire prêt. Faux, sans rien
## changer, chez un client, hors d'une manche, ou à moins de NB_JOUEURS_MIN joueurs encore là.
func relancer_manche(niveau: int) -> bool:
	if not multiplayer.is_server() or not manche_en_cours or table_de(inscrits).size() < EtatPartie.NB_JOUEURS_MIN:
		return false
	niveau_salon = posmod(niveau, EtatPartie.NIVEAUX.size())
	return _lancer()


## Chez l'hôte, depuis l'écran Résultats (phase 18) : chaque poste revient au salon, sur la même table
## (les partis en moins) : le salon s'ouvre chez l'hôte (`ouvrir_salon` : plus de manche en cours, les
## arrivées de nouveau acceptées, personne prêt, la table diffusée), puis
## chaque client change de scène (`_recevoir_retour_salon`, sur le canal ordonné, avec la table) ;
## `salon_rouvert` part aussi ici. Faux chez un client, ou hors d'une manche.
func revenir_au_salon() -> bool:
	if not multiplayer.is_server() or not manche_en_cours:
		return false
	definir_silence(SILENCE_SESSION)
	ouvrir_salon(niveau_salon)
	if en_ligne():
		_recevoir_retour_salon.rpc(table_salon, niveau_salon, places_salon, places_reservees, numero_table)
	salon_rouvert.emit()
	return true


## La manche part (`lancer_manche`, `relancer_manche`), une fois les fiches revérifiées (M1).
func _lancer() -> bool:
	var essai: Dictionary[int, Dictionary] = inscrits.duplicate(true)
	compacter_index(essai)
	if fiches_de_manche(table_de(essai), multiplayer.get_unique_id()).is_empty():
		push_error("Reseau.lancer_manche : fiches de la manche incohérentes, lancement refusé")
		return false
	manche_en_cours = true
	scenes_chargees.clear()
	definir_silence(SILENCE_CHARGEMENT)
	compacter_index(inscrits)
	index_local = inscrits[multiplayer.get_unique_id()].index
	niveau_manche = niveau_salon
	_diffuser_salon()
	if en_ligne():
		_recevoir_manche.rpc(table_salon, niveau_salon, places_salon, places_reservees, numero_table)
	manche_lancee.emit(fiches_de_manche(table_salon, multiplayer.get_unique_id()))
	return true


## Vrai si l'hôte peut démarrer la partie (`raison_attente` vide).
static func salon_pret(occupes: Dictionary[int, Dictionary]) -> bool:
	return raison_attente(occupes.values()).is_empty()


## Pourquoi la partie ne peut pas encore démarrer, dans cet ordre : moins de
## `EtatPartie.NB_JOUEURS_MIN` joueurs arrivés (ATTENTE_JOUEURS), une place encore réservée par une
## poignée de main en cours (ATTENTE_ARRIVEE : son joueur arrivera non prêt), quelqu'un qui n'est
## pas prêt (ATTENTE_PRETS) ; vide si elle peut démarrer. `fiches` : les fiches d'`inscrits` chez
## l'hôte, ou `table_salon` chez un client (arrivés seulement : une fiche sans `arrive` est une
## fiche d'arrivé).
static func raison_attente(fiches: Array) -> String:
	var arrives := fiches.filter(func(fiche: Dictionary) -> bool: return fiche.get("arrive", true))
	if arrives.size() < EtatPartie.NB_JOUEURS_MIN:
		return ATTENTE_JOUEURS
	if arrives.size() < fiches.size():
		return ATTENTE_ARRIVEE
	if not fiches.all(func(fiche: Dictionary) -> bool: return fiche.get("pret", false)):
		return ATTENTE_PRETS
	return ""


## La couleur de la palette voisine de celle du joueur `id` dans le sens `sens` (1 : suivante,
## -1 : précédente, la palette en boucle) qu'aucun autre inscrit ne porte, places réservées
## comprises ; sa propre couleur s'il n'y en a aucune ; transparente si `id` est inconnu.
static func couleur_voisine_libre(occupes: Dictionary[int, Dictionary], id: int, sens: int) -> Color:
	var fiche: Dictionary = occupes.get(id, {})
	if fiche.is_empty():
		return Color.TRANSPARENT
	var prises := occupes.keys().filter(func(autre: int) -> bool: return autre != id) \
		.map(func(autre: int) -> Color: return occupes[autre].couleur)
	var palette := EtatPartie.PALETTE_BATAILLE
	var depart := palette.find(fiche.couleur)
	for pas in range(1, palette.size() + 1):
		var c: Color = palette[posmod(depart + pas * signi(sens), palette.size())]
		if not prises.has(c):
			return c
	return fiche.couleur


## Renumérote en place les index de `occupes` sur 0..n-1, dans leur ordre (des départs ont pu
## laisser des trous que `premier_index_libre` ne comble qu'à une nouvelle arrivée).
static func compacter_index(occupes: Dictionary[int, Dictionary]) -> void:
	var ids := occupes.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return occupes[a].index < occupes[b].index)
	for i in range(ids.size()):
		occupes[ids[i]].index = i


## La table du salon tirée de `occupes` : les arrivés seulement, triés par index (voir
## `table_salon`).
static func table_de(occupes: Dictionary[int, Dictionary]) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	for id: int in occupes:
		var fiche: Dictionary = occupes[id]
		if fiche.get("arrive", false):
			table.append({"id": id, "index": fiche.index, "couleur": fiche.couleur, "pseudo": fiche.pseudo, "pret": fiche.get("pret", false)})
	table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.index < b.index)
	return table


## La table du salon reçue de l'hôte, vérifiée : au plus NB_JOUEURS_MAX fiches
## `{id, index, couleur, pseudo, pret}` aux identifiants (1 et plus), index (0 à NB_JOUEURS_MAX - 1)
## et couleurs (de la palette) tous distincts, triée par index, pseudos nettoyés comme l'hôte les
## nettoie ; un tableau vide pour toute autre chose.
static func lire_table(table: Variant) -> Array[Dictionary]:
	var lue: Array[Dictionary] = []
	if not (table is Array) or table.size() > EtatPartie.NB_JOUEURS_MAX:
		return lue
	var ids := []
	var index := []
	var couleurs := []
	for fiche: Variant in table:
		if not (fiche is Dictionary) or not (fiche.get("id") is int) or not (fiche.get("index") is int) \
				or not (fiche.get("couleur") is Color) or not (fiche.get("pseudo") is String) or not (fiche.get("pret") is bool) \
				or fiche.id < 1 or fiche.index < 0 or fiche.index >= EtatPartie.NB_JOUEURS_MAX \
				or not EtatPartie.PALETTE_BATAILLE.has(fiche.couleur) \
				or ids.has(fiche.id) or index.has(fiche.index) or couleurs.has(fiche.couleur):
			return [] as Array[Dictionary]
		ids.append(fiche.id)
		index.append(fiche.index)
		couleurs.append(fiche.couleur)
		lue.append({"id": fiche.id, "index": fiche.index, "couleur": fiche.couleur,
			"pseudo": pseudo_ou_defaut(fiche.pseudo, fiche.index), "pret": fiche.pret})
	lue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.index < b.index)
	return lue


## Les fiches de la manche tirées d'une table du salon (voir `manche_lancee`), ou un tableau vide si
## elle ne peut pas lancer de manche : moins de NB_JOUEURS_MIN joueurs, index qui ne sont pas
## exactement 0..n-1 (compactés par l'hôte), ou `id_local` absent (ce poste n'est pas dans la
## partie).
static func fiches_de_manche(table: Array[Dictionary], id_local: int) -> Array[Dictionary]:
	var fiches: Array[Dictionary] = []
	if table.size() < EtatPartie.NB_JOUEURS_MIN or not table.any(func(f: Dictionary) -> bool: return f.id == id_local):
		return fiches
	for i in range(table.size()):
		if table[i].index != i:
			return [] as Array[Dictionary]
		fiches.append({"id_reseau": table[i].id, "pseudo": table[i].pseudo, "couleur": table[i].couleur})
	return fiches


## Chez l'hôte : reconstruit `table_salon` depuis `inscrits` (arrivés seulement), la numérote (M6) et la
## diffuse aux clients (`rpc()` ne vise que les pairs connectés, donc arrivés : jamais une place seulement
## réservée, M4), puis émet `salon_change` ici.
func _diffuser_salon() -> void:
	if not multiplayer.is_server():
		return
	table_salon = table_de(inscrits)
	places_reservees = inscrits.size() - table_salon.size()
	numero_table += 1
	if en_ligne():
		_recevoir_salon.rpc(table_salon, niveau_salon, places_salon, places_reservees, numero_table)
	salon_change.emit()


## Chez l'hôte : un client demande une autre couleur.
@rpc("any_peer", "call_remote", "reliable")
func _demande_couleur(sens: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	_entendre(id)
	if admettre_demande_salon(id) and sens is int:
		changer_couleur(id, sens)


## Chez l'hôte : un client demande à être prêt, ou plus.
@rpc("any_peer", "call_remote", "reliable")
func _demande_pret(pret: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	_entendre(id)
	if admettre_demande_salon(id) and pret is bool:
		definir_pret(id, pret)


## Chez l'hôte : vrai si la demande de salon du client `id` passe (DEMANDES_SALON_PAR_SECONDE par seconde
## au plus, spec §8.2), mal formée ou non ; au-delà, elle est jetée sans réponse (un avertissement au
## premier rejet de ce client, pas à chacun : un client qui inonde l'hôte n'inonde pas son journal).
func admettre_demande_salon(id: int) -> bool:
	if _limite_salon.admettre(id, Time.get_ticks_msec() / 1000.0):
		return true
	if _limite_salon.rejets[id] == 1:
		push_warning("Reseau : le client %d fait plus de %d demandes de salon par seconde, l'excédent est jeté" % [id, DEMANDES_SALON_PAR_SECONDE])
	return false


## Chez un client : la table du salon diffusée par l'hôte (ignorée si elle est illisible ou plus ancienne
## que la dernière posée), avec le niveau, les places, les places seulement réservées et son numéro.
@rpc("authority", "call_remote", "reliable")
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	if _poser_salon(table, niveau, nb_places, reservees, numero) == Pose.ILLISIBLE:
		push_warning("Reseau : table du salon illisible, ignorée")


## Chez un client : pose la table du salon reçue de l'hôte, son niveau, ses places, ses places seulement
## réservées et son numéro ; ce poste y lit son index et sa couleur, puis `salon_change` (POSEE). Rien ne
## change pour une table illisible (`lire_table`), des valeurs hors plage (ILLISIBLE), ou une table plus
## ancienne que la dernière posée (PERIMEE, M6 : un numéro égal est la même table, arrivée par l'autre
## canal, reposée sans dommage).
func _poser_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> Pose:
	var lue := lire_table(table)
	if lue.is_empty() or not (niveau is int) or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (nb_places is int) or nb_places < EtatPartie.NB_JOUEURS_MIN or nb_places > EtatPartie.NB_JOUEURS_MAX \
			or not (reservees is int) or reservees < 0 or reservees > EtatPartie.NB_JOUEURS_MAX - lue.size() \
			or not (numero is int) or numero < 1:
		return Pose.ILLISIBLE
	if numero < numero_table:
		return Pose.PERIMEE
	numero_table = numero
	table_salon = lue
	niveau_salon = niveau
	places_salon = nb_places
	places_reservees = reservees
	for fiche in lue:
		if fiche.id == multiplayer.get_unique_id():
			index_local = fiche.index
			couleur_locale = fiche.couleur
	salon_change.emit()
	return Pose.POSEE


## Chez un client : l'hôte lance la manche, sur la table compactée et le niveau `table`, `niveau` (phase
## 18 : avec le lancement, sur le canal ordonné, que la table diffusée sur le canal 0 peut ne pas
## précéder), ses places, ses places réservées et son numéro. La manche se joue toujours sur la table et
## le niveau du lancement, ceux de l'hôte, même quand une table plus récente du canal 0 (un départ pendant
## le chargement) l'a devancé et reste posée (M6). Le chargement commence : silence toléré
## SILENCE_CHARGEMENT.
@rpc("authority", "call_remote", "reliable", CANAL_ORDONNE)
func _recevoir_manche(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	var fiches: Array[Dictionary] = []
	if _poser_salon(table, niveau, nb_places, reservees, numero) != Pose.ILLISIBLE:
		fiches = fiches_de_manche(lire_table(table), multiplayer.get_unique_id())
	if fiches.is_empty():
		push_warning("Reseau : lancement de manche sur une table illisible, ignoré")
		return
	niveau_manche = niveau
	manche_en_cours = true
	definir_silence(SILENCE_CHARGEMENT)
	manche_lancee.emit(fiches)


## Chez un client : l'hôte ramène tout le monde au salon (phase 18), sur la table `table`, son niveau, ses
## places, ses places réservées et son numéro (la même que celle diffusée juste avant, sur le canal 0).
## Une table illisible est signalée ; une table plus ancienne que la dernière posée (une arrivée au salon
## rouvert, diffusée sur le canal 0, a devancé ce retour perdu puis renvoyé) est ignorée, sans bruit
## (M6) ; le retour a lieu dans les deux cas.
@rpc("authority", "call_remote", "reliable", CANAL_ORDONNE)
func _recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	if _poser_salon(table, niveau, nb_places, reservees, numero) == Pose.ILLISIBLE:
		push_warning("Reseau : table du retour au salon illisible, ignorée")
	manche_en_cours = false
	definir_silence(SILENCE_SESSION)
	salon_rouvert.emit()


## Chez l'hôte : la scène de jeu d'un joueur de la manche est chargée (barrière avant l'intro).
@rpc("any_peer", "call_remote", "reliable")
func _scene_chargee() -> void:
	var id := multiplayer.get_remote_sender_id()
	_entendre(id)
	if multiplayer.is_server() and manche_en_cours and inscrits.has(id):
		_noter_scene_chargee(id)


func _api() -> SceneMultiplayer:
	return multiplayer as SceneMultiplayer


func _activer_poignee_de_main() -> void:
	var api := _api()
	api.auth_callback = _sur_donnees_poignee_de_main
	api.auth_timeout = DELAI_POIGNEE_DE_MAIN


func _refus(raison: String) -> Dictionary:
	return {"accepte": false, "raison": raison, "version_hote": version}


static func _est_texte(d: Dictionary, cle: String) -> bool:
	return d.get(cle) is String


## Début de la poignée de main avec `id` : le client présente sa demande, l'hôte attend la sienne.
func _sur_debut_poignee_de_main(id: int) -> void:
	if multiplayer.is_server():
		return
	_api().send_auth(id, var_to_bytes({"jeu": JEU, "version": version, "pseudo": pseudo}))


## Décode les octets d'une poignée de main, ou renvoie `null` sans décoder si `donnees` dépasse
## TAILLE_POIGNEE_DE_MAIN_MAX : le coût de `bytes_to_var` doit rester borné, quel que soit
## l'émetteur sur le port UDP (spec M2). `examiner_demande` et `_lire_reponse` refusent déjà
## n'importe quoi qui n'est pas le dictionnaire attendu, `null` y compris.
static func decoder_poignee_de_main(donnees: PackedByteArray) -> Variant:
	return null if donnees.size() > TAILLE_POIGNEE_DE_MAIN_MAX else bytes_to_var(donnees)


## Octets de poignée de main reçus de `id` : une demande (chez l'hôte) ou la réponse de l'hôte.
func _sur_donnees_poignee_de_main(id: int, donnees: PackedByteArray) -> void:
	var contenu: Variant = decoder_poignee_de_main(donnees)
	if multiplayer.is_server():
		_repondre(id, contenu)
	else:
		_lire_reponse(contenu)


func _repondre(id: int, demande: Variant) -> void:
	if inscrits.has(id):
		return  # demande répétée : la première réponse fait foi
	var reponse := examiner_demande(demande)
	if reponse.accepte:
		inscrits[id] = {"index": reponse.index, "couleur": reponse.couleur, "pseudo": reponse.pseudo, "arrive": false, "pret": false}
		_diffuser_salon()  # une place réservée : le bouton Démarrer de l'hôte se grise, ses clients le savent
	_api().send_auth(id, var_to_bytes(reponse))
	# Un refusé n'est pas déconnecté ici : le transport viderait sa file d'envoi, réponse comprise, et le
	# client ne saurait jamais pourquoi. Il part de lui-même en lisant le refus ; sinon le délai de
	# la poignée de main (DELAI_POIGNEE_DE_MAIN) le déconnecte.
	if reponse.accepte:
		_api().complete_auth(id)


func _lire_reponse(reponse: Variant) -> void:
	var valide := reponse is Dictionary and reponse.get("accepte") is bool
	if valide and reponse.accepte and reponse.get("index") is int and reponse.get("couleur") is Color \
			and reponse.index >= 0 and reponse.index < EtatPartie.NB_JOUEURS_MAX:
		index_local = reponse.index
		couleur_locale = reponse.couleur
		_api().complete_auth(MultiplayerPeer.TARGET_PEER_SERVER)
		return
	var raison: String = reponse.raison if valide and reponse.get("raison") is String else REFUS_DEMANDE
	var version_hote: String = reponse.version_hote if valide and reponse.get("version_hote") is String else ""
	_decider("refuse", [raison, version_hote])


## Chez l'hôte, un pair qui ne finit pas sa poignée de main (délai, départ) libère la place qui
## lui avait été attribuée ; il n'était jamais « arrivé », il ne « part » donc pas.
func _sur_echec_poignee_de_main(id: int) -> void:
	if multiplayer.is_server() and inscrits.erase(id):
		_diffuser_salon()  # la place réservée se libère : le bouton de l'hôte peut revenir, chez ses clients aussi


## Chez l'hôte : un accepté a fini sa poignée de main. Il est désormais arrivé : sa carte apparaît
## au salon et la table lui est envoyée avec celle des autres.
func _sur_pair_connecte(id: int) -> void:
	if multiplayer.is_server() and inscrits.has(id):
		_entendus[id] = Time.get_ticks_msec()
		inscrits[id].arrive = true
		_diffuser_salon()
		joueur_arrive.emit(id)


## Chez l'hôte : un arrivé est parti ; sa carte se libère chez tous (spec §4).
func _sur_pair_deconnecte(id: int) -> void:
	_entendus.erase(id)
	_limite_salon.oublier(id)
	if multiplayer.is_server() and inscrits.erase(id):
		_diffuser_salon()
		joueur_parti.emit(id)


func _sur_connecte_a_l_hote() -> void:
	_delai.stop()
	_connexion_en_cours = false
	_entendus[MultiplayerPeer.TARGET_PEER_SERVER] = Time.get_ticks_msec()
	inscrit.emit(index_local, couleur_locale)


func _sur_connexion_echouee() -> void:
	_decider("connexion_echouee")


## L'hôte ferme la connexion, ou le transport de la session s'est fermé de lui-même (`_process`). Avant
## l'inscription, c'est un échec de connexion, pas un hôte perdu : ce poste n'a jamais été dans la partie ;
## de même chez l'hôte avant le `pret` de son transport. Chez l'hôte, la session est perdue : `hote_perdu`
## aussi, le chemin de N4 (son pair tombé en erreur). Idempotent (`_decider`).
func _sur_hote_perdu() -> void:
	_decider("connexion_echouee" if _connexion_en_cours or _creation_en_cours else "hote_perdu")


## La poignée de main d'un client n'a pas fini dans DELAI_CONNEXION, une fois le canal ouvert.
func _sur_delai_depasse() -> void:
	if _connexion_en_cours:
		_decider("connexion_echouee")


## Chez l'hôte : la session du transport existe ; son code est celui de la partie. Le salon le relit
## (`salon_change`) seulement quand la création l'attendait (WebRTC) : un `pret` pendant `heberger()`
## (ENet) arrive avant que le pair soit posé, et le `salon_change` de l'inscription de l'hôte suit.
func _sur_transport_pret(code: String, generation: int) -> void:
	if generation == _generation:
		code_partie = code
		var attendu := _creation_en_cours
		_creation_en_cours = false
		if attendu:
			salon_change.emit()


## Chez un client : le canal vers l'hôte est ouvert ; la poignée de main (que `SceneMultiplayer` lance
## d'elle-même) a DELAI_CONNEXION pour finir.
func _sur_transport_connecte(generation: int) -> void:
	if generation == _generation and _connexion_en_cours:
		_delai.start(DELAI_CONNEXION)


## Chez un client : le pair du transport existe désormais (WebRTC : son identifiant est arrivé) ;
## `SceneMultiplayer` le prend, la connexion continue. Sans effet une fois l'issue décidée (un échec dont
## la fermeture différée n'est pas encore faite).
func _sur_transport_pair_pret(generation: int) -> void:
	if generation == _generation and _connexion_en_cours and not _issue_decidee and _transport != null:
		multiplayer.multiplayer_peer = _transport.pair()


## Chez un client, le canal vers l'hôte ne s'ouvrira pas ; chez l'hôte, la partie ne sera pas créée (avant
## le `pret` de son transport) : un échec de connexion, dont `raison` (Transport.ECHEC_*) devient
## `raison_echec`. Ailleurs (une partie créée, un client inscrit), sans effet.
func _sur_transport_echec(raison: String, generation: int) -> void:
	if generation == _generation and (_connexion_en_cours or _creation_en_cours) and not _issue_decidee:
		_raison_transport = raison
		_decider("connexion_echouee")


## Chez l'hôte : plus personne ne peut rejoindre la partie (la salle a expiré, ou la signalisation s'est
## fermée) ; la partie continue, le salon le dit (`raison_salle_fermee`). Avant le `pret` du transport,
## la partie n'existera pas : un échec de connexion, de raison `raison` (comme `_sur_transport_echec`).
func _sur_transport_salle_fermee(raison: String, generation: int) -> void:
	if generation != _generation:
		return
	if _creation_en_cours:
		if not _issue_decidee:
			_raison_transport = raison
			_decider("connexion_echouee")
	elif multiplayer.is_server() and en_ligne():
		raison_salle_fermee = raison
		salon_change.emit()


## Décide l'issue de la connexion (signal `nom`), une seule fois. Différé : on ne change pas de
## pair pendant que SceneMultiplayer traite ses paquets. Capture la génération de la session en
## cours (M5) : si une nouvelle session démarre avant que l'appel différé s'exécute, il ne doit
## rien faire à celle-ci.
func _decider(nom: StringName, arguments: Array = []) -> void:
	if _issue_decidee:
		return
	_issue_decidee = true
	_fermer_puis_emettre.call_deferred(nom, arguments, _generation)


## Revient hors réseau, puis émet le signal `nom` : ceux qui le reçoivent trouvent déjà le poste
## hors réseau (un retour au titre y relance une partie solo qui fonctionne). Sans effet si une
## nouvelle session a déjà commencé (`generation` périmée) : ni la fermer, ni émettre un signal
## qui ne la concerne plus (M5).
func _fermer_puis_emettre(nom: StringName, arguments: Array, generation: int) -> void:
	if generation != _generation:
		return
	var exclu := _exclu
	var raison_transport := _raison_transport
	quitter()
	if nom == &"hote_perdu":
		raison_perte = PERTE_EXCLU if exclu else PERTE_HOTE
	elif nom == &"connexion_echouee":
		raison_echec = raison_transport
	callv("emit_signal", [nom] + arguments)
