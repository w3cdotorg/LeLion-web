class_name TransportENet
extends Transport
## Le transport ENet (UDP) de LeLion-multi, extrait de `Reseau` (phase 1) : gardé pour la version
## desktop de développement et les tests headless (scénarios réseau, relais de latence), jamais choisi
## dans l'export Web. Son code est `ip:port` (une IPv4 seulement, M8 : un nom d'hôte serait résolu par
## `create_client` en bloquant le jeu, plusieurs secondes sous Windows pour une faute de frappe), ou
## une IPv4 seule pour le port PORT.
##
## Silences : `Reseau` décide seul qu'un pair est parti (son battement : 10 s, 30 s au chargement).
## ENet n'abandonne donc lui-même un pair connecté qu'au-delà (SILENCE_ENET). Un pair libéré
## (`liberer`) est fermé sur-le-champ (`peer_disconnect_now` : un seul DISCONNECT, non fiable), sans
## attendre un accusé de réception qu'un pair mort ou figé n'enverra jamais (I1, revue finale de la
## phase 14).
##
## Départ (`quitter`, M6) : chaque pair connecté reçoit un DISCONNECT fiable après ce qui est encore
## en file (`peer_disconnect_later` : l'adieu de `Reseau` part d'abord, là où `peer_disconnect` vide
## la file), renvoyé jusqu'à son accusé de réception, DELAI_DEPART au plus, servi par `servir()`.
## `close()` seul n'enverrait qu'un datagramme non fiable.

const PORT := 7777
## L'adresse du code annoncé par `pret` : celle de ce poste vu de lui-même (les tests, le
## développement sur un seul PC), que le salon de l'hôte affiche (« 127.0.0.1:7777 ») et qui ne vaut que
## pour lui. Les autres postes du réseau local prennent l'adresse IP locale de l'hôte, celle que donne
## son système (réglages réseau, `ipconfig`, `ip a`), suivie de `:7777`.
const ADRESSE_LOCALE := "127.0.0.1"
## Connexions ENet (`max_clients`) acceptées au-delà des places : l'hôte ne consomme pas de connexion
## vers lui-même, donc `places - 1` suffiraient aux vrais clients ; ce solde donne de quoi recevoir, et
## refuser explicitement, les demandes d'une partie déjà pleine au lieu de les laisser échouer sans
## explication côté ENet (N1 : la marge réelle est donc de CONNEXIONS_EN_TROP + 1).
const CONNEXIONS_EN_TROP := 2
## Délai d'ouverture du canal vers l'hôte, en secondes (spec §9 : 5 s puis message) ; au-delà,
## `echec(ECHEC_DELAI)`.
const DELAI_CANAL := 5.0
## Délai laissé à un départ volontaire pour être reçu (accusé de réception du DISCONNECT), en ms.
const DELAI_DEPART := 1000
## Essais de renvoi d'ENet avant de compter le silence (son défaut).
const ESSAIS_SILENCE := 32
## Silence d'un pair connecté au-delà duquel ENet l'abandonne lui-même (`ENetPacketPeer.set_timeout`,
## en ms : minimum, maximum) : bien au-delà du plus long silence de `Reseau` (30 s, au chargement),
## pour que ce soit toujours `Reseau` qui décide.
const SILENCE_ENET := Vector2i(45000, 60000)

## Délai d'ouverture du canal de ce transport (DELAI_CANAL ; les tests le raccourcissent).
var delai_canal := DELAI_CANAL

var _port: int
var _places: int
var _pair: ENetMultiplayerPeer
## Faux après `quitter()` ou `clore()` : plus aucun signal.
var _actif := false
## Chez un client : l'instant (ms) où l'attente du canal échoue ; -1 hors attente.
var _fin_canal := -1
## Pendant un départ : les pairs prévenus, et l'instant (ms) où le départ est clos quoi qu'il arrive
## (-1 hors départ).
var _prevenus: Array[ENetPacketPeer] = []
var _fin_depart := -1


## `port` : celui de la session hébergée (le code donne celui d'une session rejointe) ; `places` :
## les joueurs d'une partie hébergée, hôte compris.
func _init(port := PORT, places := EtatPartie.NB_JOUEURS_MAX) -> void:
	_port = port
	_places = places


func heberger() -> Error:
	var pair_hote := ENetMultiplayerPeer.new()
	var erreur := pair_hote.create_server(_port, _places + CONNEXIONS_EN_TROP)
	if erreur != OK:
		return erreur
	_ouvrir(pair_hote)
	pret.emit("%s:%d" % [ADRESSE_LOCALE, _port])
	return OK


func rejoindre(code: String) -> Error:
	var cible := lire_code(code)
	if cible.is_empty():
		return ERR_INVALID_PARAMETER
	var pair_client := ENetMultiplayerPeer.new()
	var erreur := pair_client.create_client(cible.ip, cible.port)
	if erreur != OK:
		return erreur
	_ouvrir(pair_client)
	_fin_canal = Time.get_ticks_msec() + int(delai_canal * 1000.0)
	return OK


func quitter() -> void:
	_actif = false
	_fin_canal = -1
	if _pair == null or _fin_depart >= 0:
		return
	# Un pair déjà fermé par ENet (un client dont l'hôte est parti) n'a plus d'hôte ENet à lire.
	if _pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		clore()
		return
	var connexion := _pair.host
	if connexion == null:
		clore()
		return
	_prevenus.clear()
	for p: ENetPacketPeer in connexion.get_peers():
		if p.get_state() == ENetPacketPeer.STATE_CONNECTED:
			_prevenus.append(p)
	if _prevenus.is_empty():
		clore()
		return
	for p in _prevenus:
		p.peer_disconnect_later()
	connexion.flush()
	_fin_depart = Time.get_ticks_msec() + DELAI_DEPART


func clore() -> void:
	_actif = false
	_fin_canal = -1
	_fin_depart = -1
	_prevenus.clear()
	if _pair != null:
		_pair.close()
		_pair = null


func pair() -> MultiplayerPeer:
	return _pair


func liberer(id: int) -> void:
	if _pair == null or _pair.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var paquet := _pair.get_peer(id)
	if paquet == null or not paquet.is_active():
		return
	paquet.peer_disconnect_now()  # sa place se libère tout de suite
	_pair.poll()  # ENet rend compte du pair fermé : `peer_disconnected` part maintenant


func servir() -> bool:
	if _fin_depart >= 0:
		# Hors de `SceneMultiplayer` (Reseau est déjà hors réseau) : ce transport sert son pair lui-même.
		if _pair.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			_pair.poll()
		var recus := _prevenus.all(func(p: ENetPacketPeer) -> bool: return p.get_state() == ENetPacketPeer.STATE_DISCONNECTED)
		if recus or Time.get_ticks_msec() >= _fin_depart:
			clore()
	elif _fin_canal >= 0 and Time.get_ticks_msec() >= _fin_canal:
		_fin_canal = -1
		echec.emit(ECHEC_DELAI)
	return _pair != null


## La cible d'un code `ip:port` ou `ip` (port PORT) : `{"ip": String, "port": int}`, l'IPv4 sous sa
## forme normale (`adresse_ipv4`) et un port de 1 à 65535 ; un dictionnaire vide pour tout autre texte.
static func lire_code(code: String) -> Dictionary:
	var morceaux := code.strip_edges().split(":")
	if morceaux.size() > 2:
		return {}
	var ip := adresse_ipv4(morceaux[0])
	var port := PORT
	if morceaux.size() == 2:
		var texte_port := morceaux[1].strip_edges()
		if texte_port.is_empty() or not texte_port.lstrip("0123456789").is_empty():
			return {}
		port = texte_port.to_int()
	if ip.is_empty() or port < 1 or port > 65535:
		return {}
	return {"ip": ip, "port": port}


## L'adresse IPv4 saisie `texte` sous sa forme normale (« 192.168.001.010 » → « 192.168.1.10 »), ou
## une chaîne vide si ce n'est pas une adresse joignable : quatre nombres de 0 à 255 d'un à trois
## chiffres, ni 0.x.x.x, ni multidiffusion ou réservée (224 et au-delà, 255.255.255.255 compris).
## Jamais de nom d'hôte : sa résolution bloquerait le thread principal (Windows : plusieurs
## secondes pour une faute de frappe).
static func adresse_ipv4(texte: String) -> String:
	var morceaux := texte.strip_edges().split(".")
	if morceaux.size() != 4:
		return ""
	var octets := PackedStringArray()
	for morceau in morceaux:
		if morceau.is_empty() or morceau.length() > 3 or not morceau.lstrip("0123456789").is_empty():
			return ""
		var valeur := morceau.to_int()
		if valeur > 255:
			return ""
		octets.append(str(valeur))
	var premier := octets[0].to_int()
	if premier == 0 or premier >= 224:
		return ""
	return ".".join(octets)


func _ouvrir(pair_ouvert: ENetMultiplayerPeer) -> void:
	_pair = pair_ouvert
	_actif = true
	_pair.peer_connected.connect(_sur_pair_connecte)


## Un pair ENet se connecte (chez l'hôte, avant sa poignée de main ; chez un client, l'hôte) : son
## silence toléré par ENet devient SILENCE_ENET ; chez un client, le canal est ouvert.
func _sur_pair_connecte(id: int) -> void:
	_pair.get_peer(id).set_timeout(ESSAIS_SILENCE, SILENCE_ENET.x, SILENCE_ENET.y)
	if _fin_canal >= 0:
		_fin_canal = -1
		if _actif:
			connecte.emit()
