class_name TransportWebRTC
extends Transport
## Le transport du jeu livré (spec §3.1, §4 et §5 du jeu en ligne) : WebRTC en étoile autour de l'hôte
## (`WebRTCMultiplayerPeer` : l'hôte en `create_server`, chaque client en `create_client`), signalé par
## le Worker de `signalisation/` (WebSocket, JSON, protocole v1). N'existe que dans l'export Web : le
## desktop n'a pas de WebRTC sans l'extension webrtc-native (hors périmètre, spec §1). Ses décisions
## (messages, file d'envoi, délais) se testent sur le desktop, par une sous-classe qui remplace ses
## entrées et sorties (`_ouvrir_socket` à `_appliquer_candidat`, `tests/unitaires.gd`).
##
## Hôte : `heberger()` crée le pair serveur et ouvre `/v1/creer` ; `salle` donne le code (`pret`) et les
## serveurs ICE ; chaque `arrivee` crée une connexion WebRTC (`add_peer`) avec les serveurs ICE neufs de
## cette arrivée, et son offre part par la salle ; le canal ouvert (`peer_connected`), l'hôte dit
## `ouvert` (la salle ferme alors la socket du client). Un arrivant dont le canal n'est pas ouvert
## DELAI_CANAL après son arrivée, ou dont la salle annonce le `depart`, est retiré ; le `depart` d'un pair
## au canal ouvert est ignoré. La socket de l'hôte vit tant que la salle vit (`ping` toutes les
## PERIODE_PING) ; fermée après `pret` (expiration, débit, coupure), la partie continue sans arrivées
## (`salle_fermee`).
##
## Client : `rejoindre(code)` ouvre `/v1/rejoindre/<code>` ; `bienvenue` donne son identifiant : son pair
## naît alors (`pair_pret`) et répond à l'offre de l'hôte ; le canal ouvert, `connecte`. Il ne ferme pas
## sa socket lui-même : il attend la fermeture 1000 `ouvert` de la salle (qui peut précéder de peu
## l'ouverture de son propre canal), et échoue (`echec`) sur une `erreur` de la salle, une fermeture
## sans `ouvert`, ou un canal fermé DELAI_CANAL après `bienvenue`.
##
## Envois : en texte seulement (`send_text` : la salle ignore une trame binaire, et ne répond pas à un
## `ping` binaire), par une file cadencée à ENVOIS_PAR_SECONDE, sur des créneaux espacés d'ECART_ENVOIS (la
## salle chasse au-delà de 20 par seconde ; six arrivées font environ 70 messages), dans l'ordre (une offre
## avant ses candidats), et seulement tant que la salle peut les relayer (`_signaler_vers`). Une image plus
## longue qu'ECART_ENVOIS (un appareil lent, phase 6) rattrape les créneaux passés depuis l'image
## précédente, pas davantage.
## Réception : tous les messages en attente sont lus, même la socket fermée, jusqu'à la fin de la
## signalisation (une `erreur`, une fermeture, le délai du canal d'un client) ; leurs identifiants (des
## flottants dans le JSON de Godot) deviennent des entiers (`decoder`). La raison d'une `erreur` est
## écrite au journal (spec §9) ; sans elle, la raison de la fermeture en tient lieu.
##
## Canaux (spec §5) : les trois par défaut de `WebRTCMultiplayerPeer` (le fiable porte la poignée de
## main et la table du salon ; les non fiables, `unreliable_lifetime` DUREE_NON_FIABLE), plus un canal
## fiable ordonné, le canal 1 de `SceneMultiplayer` (`Reseau.CANAL_ORDONNE`, `Manche.CANAL_PEINTURE`).
## `?relais=1` dans l'adresse de la page : le relais TURN seulement (`iceTransportPolicy: "relay"`,
## spec §10, diagnostic de l'essai réel).

## Le réglage de projet de l'adresse du Worker (spec §11), et sa valeur sans réglage : `wrangler dev`.
const REGLAGE_URL := "lelion/signalisation/url"
const URL_SIGNALISATION := "ws://localhost:8787"
const CHEMIN_CREER := "/v1/creer"
const CHEMIN_REJOINDRE := "/v1/rejoindre/"
## L'identifiant de pair de l'hôte (`create_server`), celui que la salle donne à l'hôte.
const ID_HOTE := 1
## Le plus grand identifiant de pair (2³¹-1).
const ID_MAX := 2147483647
## Sans `salle` (hôte) ni `bienvenue` (client) dans ce délai, en secondes : la signalisation est
## injoignable (spec §9 : 5 s).
const DELAI_SIGNALISATION := 5.0
## Canal toujours fermé ce délai après `bienvenue` (client) ou `arrivee` (hôte), en secondes (spec
## §4.3 : 15 s, la moitié du délai d'arrivée de la salle).
const DELAI_CANAL := 15.0
## Envois au plus dans toute seconde vers la salle (elle en admet 20 : un seau de 20 jetons, rempli de
## 20 par seconde), et l'écart minimal entre deux envois, en ms : sans lui, une rafale de 15 retardée par
## TCP arriverait d'un coup, avec les suivantes, et viderait le seau de la salle, qui fermerait la socket.
const ENVOIS_PAR_SECONDE := 15
const ECART_ENVOIS := 50
## Période du `ping` de l'hôte, en secondes (la salle y répond sans se réveiller, spec §4.2), et son
## texte exact.
const PERIODE_PING := 30.0
const PING := '{"t":"ping"}'
## Durée de vie d'un paquet non fiable (`unreliable_lifetime`), en ms (spec §5 : environ 100 ms).
const DUREE_NON_FIABLE := 100
## Les canaux en plus des trois par défaut : le canal 1 de `SceneMultiplayer`, fiable et ordonné.
const CANAUX := [MultiplayerPeer.TRANSFER_MODE_RELIABLE]
## Délai laissé à un départ volontaire pour vider ses canaux (l'adieu de `Reseau`), en ms.
const DELAI_DEPART := 1000
## Le motif de la fermeture d'une socket de client par la salle, son canal ouvert (code 1000).
const MOTIF_OUVERT := "ouvert"
## Le paramètre de l'adresse de la page qui force le relais TURN (`?relais=1`).
const PARAMETRE_RELAIS := "relais"
## Les raisons des `erreur` de la salle, qui sont aussi le motif de la fermeture qui suit.
const RAISONS_SALLE: Array[String] = [ECHEC_INCONNUE, ECHEC_PLEINE, ECHEC_DEBIT, ECHEC_QUOTA, ECHEC_ORIGINE, ECHEC_EXPIREE,
	ECHEC_DELAI]
## Les champs de chaque message reçu, en plus de `t`, et leur type (spec §4.2).
const CHAMPS := {
	"salle": {"code": TYPE_STRING, "id": TYPE_INT, "ice": TYPE_ARRAY},
	"bienvenue": {"id": TYPE_INT, "ice": TYPE_ARRAY},
	"arrivee": {"id": TYPE_INT, "ice": TYPE_ARRAY},
	"offre": {"de": TYPE_INT, "sdp": TYPE_STRING},
	"reponse": {"de": TYPE_INT, "sdp": TYPE_STRING},
	"candidat": {"de": TYPE_INT, "media": TYPE_STRING, "index": TYPE_INT, "nom": TYPE_STRING},
	"depart": {"id": TYPE_INT},
	"erreur": {"raison": TYPE_STRING},
	"pong": {},
}

## Vrai : les connexions n'utilisent que le relais TURN (`?relais=1`, lu à la création sur le Web).
var relais := false

## Vrai de `heberger()` / `rejoindre()` réussis à `quitter()` / `clore()`.
var _actif := false
var _hote := false
var _ws: WebSocketPeer
## Le pair de la session : chez l'hôte dès `heberger()`, chez un client à `bienvenue`.
var _pair: WebRTCMultiplayerPeer
## La connexion WebRTC de chaque pair relié (chez l'hôte, chaque arrivant ; chez un client, l'hôte),
## pour lui appliquer les offres, réponses et candidats reçus.
var _connexions: Dictionary[int, WebRTCPeerConnection] = {}
## Les serveurs ICE de la dernière `salle`, `bienvenue` ou `arrivee`.
var _ice: Array = []
## Vrai une fois `salle` (hôte) ou `bienvenue` (client) reçu.
var _identifie := false
## Vrai une fois la signalisation finie (une `erreur`, la socket fermée) : son issue est déjà dite.
var _signalisation_finie := false
## Chez un client : vrai une fois son canal vers l'hôte ouvert.
var _canal_ouvert := false
## L'instant (ms) où l'attente de `salle` / `bienvenue` échoue (-1 hors attente).
var _fin_signalisation := -1
## Chez un client : l'instant (ms) où l'attente de son canal échoue (-1 hors attente).
var _fin_canal := -1
## Chez l'hôte : les arrivants au canal encore fermé, et l'instant (ms) où l'hôte les retire.
var _arrivees: Dictionary[int, int] = {}
## Les messages en attente d'envoi, dans l'ordre, et les créneaux (ms) des ENVOIS_PAR_SECONDE derniers
## envois, du plus ancien au plus récent (la fenêtre glissante d'une seconde).
var _file: PackedStringArray = []
var _derniers_envois: Array[int] = []
## L'instant (ms) du passage précédent de `_vider_file` (-1 avant le premier) : le plus ancien créneau
## qu'une image longue peut rattraper.
var _image_precedente := -1
## Chez l'hôte : l'instant (ms) du prochain `ping` (-1 sans salle).
var _prochain_ping := -1
## La raison de la dernière `erreur` de la salle.
var _derniere_erreur := ""
## Pendant un départ : l'instant (ms) où il est clos quoi qu'il arrive (-1 hors départ).
var _fin_depart := -1


func _init() -> void:
	if OS.has_feature("web"):
		relais = lire_relais(str(JavaScriptBridge.eval("window.location.search", true)))


func heberger() -> Error:
	var pair_hote := WebRTCMultiplayerPeer.new()
	var erreur := pair_hote.create_server(CANAUX)
	if erreur != OK:
		return erreur
	erreur = _ouvrir_socket(url_signalisation() + CHEMIN_CREER)
	if erreur != OK:
		return erreur
	_hote = true
	_poser_pair(pair_hote)
	_demarrer()
	return OK


## Un code qui n'est pas un code de salle (`CodeSalle.valide`, déjà normalisé), l'adresse `ip:port` d'un
## hôte ENet comprise : ERR_INVALID_PARAMETER, sans rien tenter.
func rejoindre(code: String) -> Error:
	if not CodeSalle.valide(code):
		return ERR_INVALID_PARAMETER
	var erreur := _ouvrir_socket(url_signalisation() + CHEMIN_REJOINDRE + code)
	if erreur != OK:
		return erreur
	_hote = false
	_demarrer()
	return OK


## La socket de signalisation se ferme tout de suite (l'hôte : sa salle disparaît ; un client : la salle
## l'oublie) ; le pair se ferme une fois ses canaux vidés (l'adieu de `Reseau`), DELAI_DEPART au plus.
func quitter() -> void:
	_actif = false
	_fin_signalisation = -1
	_fin_canal = -1
	_prochain_ping = -1
	_arrivees.clear()
	_file.clear()
	_fermer_socket()
	if _fin_depart >= 0:
		return
	if _pair == null or _pair.get_peers().is_empty():
		clore()
		return
	_fin_depart = Time.get_ticks_msec() + DELAI_DEPART


func clore() -> void:
	_actif = false
	_fin_signalisation = -1
	_fin_canal = -1
	_prochain_ping = -1
	_fin_depart = -1
	_arrivees.clear()
	_file.clear()
	_connexions.clear()
	_fermer_socket()
	if _pair != null:
		_pair.close()
		_pair = null


func pair() -> MultiplayerPeer:
	return _pair


func liberer(id: int) -> void:
	if _pair == null or not _pair.has_peer(id):
		return
	_arrivees.erase(id)
	_connexions.erase(id)
	_pair.disconnect_peer(id)  # ferme sa connexion
	_pair.poll()  # le pair fermé est retiré : `peer_disconnected` part maintenant


func servir() -> bool:
	var maintenant := Time.get_ticks_msec()
	if _fin_depart >= 0:
		# Hors de `SceneMultiplayer` (Reseau est déjà hors réseau) : ce transport sert son pair lui-même.
		_pair.poll()
		if maintenant >= _fin_depart or _canaux_vides():
			clore()
	elif _actif:
		_servir_socket()
		_vider_file(maintenant)
		_surveiller(maintenant)
	return _actif or _pair != null


## L'adresse du Worker (le réglage REGLAGE_URL, URL_SIGNALISATION sans lui), sans « / » final.
static func url_signalisation() -> String:
	return str(ProjectSettings.get_setting(REGLAGE_URL, URL_SIGNALISATION)).trim_suffix("/")


## Vrai si la partie recherche d'une adresse (`location.search`) porte `relais=1`.
static func lire_relais(recherche: String) -> bool:
	for paire in recherche.trim_prefix("?").split("&", false):
		if paire == PARAMETRE_RELAIS + "=1":
			return true
	return false


## La configuration d'une connexion WebRTC (`WebRTCPeerConnection.initialize`, passée telle quelle au
## `RTCPeerConnection` du navigateur) : les serveurs ICE `ice` de la salle, et le relais seul si `relais`.
static func configuration_ice(ice: Array, relais_seul: bool) -> Dictionary:
	var configuration := {"iceServers": ice}
	if relais_seul:
		configuration["iceTransportPolicy"] = "relay"
	return configuration


## Le message de la salle `texte` (JSON, spec §4.2) : un objet de type connu, avec exactement les champs
## de son type (CHAMPS) bien typés, ses nombres entiers en `int` (le JSON de Godot donne des flottants :
## `id`, `de` de 1 à ID_MAX, `index` de 0 à ID_MAX) ; un dictionnaire vide pour tout autre texte. Un
## champ en plus est toléré (une version mineure du Worker peut en ajouter).
static func decoder(texte: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(texte) != OK or not (json.data is Dictionary):
		return {}
	var message: Dictionary = json.data
	var type: Variant = message.get("t")
	if not (type is String) or not CHAMPS.has(type):
		return {}
	var champs: Dictionary = CHAMPS[type]
	for nom: String in champs:
		var valeur: Variant = message.get(nom)
		if champs[nom] == TYPE_INT:
			if not (valeur is float or valeur is int) or float(valeur) != floorf(float(valeur)) \
					or float(valeur) < (0.0 if nom == "index" else 1.0) or float(valeur) > ID_MAX:
				return {}
			message[nom] = int(valeur)
		elif typeof(valeur) != champs[nom]:
			return {}
	return message


## Un message reçu de la salle (le texte d'une trame) ; ignoré une fois la signalisation finie (son issue
## est dite : rien de ce qui suit ne compte plus).
func recevoir(texte: String) -> void:
	if _signalisation_finie:
		return
	var message := decoder(texte)
	if message.is_empty():
		push_warning("Signalisation : message ignoré")
		return
	var de: int = message.get("de", 0)
	match message.t:
		"salle":
			if _hote and not _identifie and CodeSalle.valide(message.code):
				_identifie = true
				_fin_signalisation = -1
				_ice = message.ice
				_prochain_ping = Time.get_ticks_msec() + int(PERIODE_PING * 1000.0)
				pret.emit(message.code)
		"arrivee":
			if _hote and _identifie and message.id != ID_HOTE and not _connexions.has(message.id):
				_accueillir(message.id, message.ice)
		"bienvenue":
			if not _hote and not _identifie and message.id != ID_HOTE:
				_identifie = true
				_fin_signalisation = -1
				_ice = message.ice
				_devenir_client(message.id)
		"offre":
			if not _hote and de == ID_HOTE and _connexions.has(ID_HOTE):
				_appliquer_description(ID_HOTE, "offer", message.sdp)
		"reponse":
			if _hote and _arrivees.has(de):
				_appliquer_description(de, "answer", message.sdp)
		"candidat":
			if _connexions.has(de) and (_hote or de == ID_HOTE):
				_appliquer_candidat(de, message.media, message.index, message.nom)
		"depart":
			# Un départ après `ouvert` (le canal ouvert) ne concerne plus la signalisation : ignoré.
			if _hote and _arrivees.has(message.id):
				_arrivees.erase(message.id)
				_retirer(message.id)
		"erreur":
			_derniere_erreur = message.raison
			push_warning("Signalisation : erreur « %s »" % message.raison)
			_signalisation_perdue(message.raison)


## La socket de signalisation s'est fermée (code `code`, motif `motif`) : la fermeture 1000 `ouvert`
## d'un client est la fin normale de sa signalisation ; toute autre est perdue, avec la raison de la
## dernière `erreur`, sinon le motif s'il en est une, sinon ECHEC_INJOIGNABLE.
func _sur_socket_fermee(code: int, motif: String) -> void:
	if not _hote and code == 1000 and motif == MOTIF_OUVERT:
		_signalisation_finie = true
		return
	var raison := _derniere_erreur
	if raison.is_empty():
		raison = motif if RAISONS_SALLE.has(motif) else ECHEC_INJOIGNABLE
	_signalisation_perdue(raison)


## La signalisation s'arrête avec `raison`, une seule fois : chez l'hôte après `pret`, seules les arrivées
## cessent (`salle_fermee`) ; chez un client au canal ouvert, rien ; sinon, un échec.
func _signalisation_perdue(raison: String) -> void:
	if _signalisation_finie or not _actif:
		return
	_signalisation_finie = true
	_fin_signalisation = -1
	_prochain_ping = -1
	if _hote and _identifie:
		salle_fermee.emit(raison)
	elif not _canal_ouvert:
		_fin_canal = -1  # l'échec est dit : le délai du canal n'en ferait pas un second
		echec.emit(raison)


## Les délais à `maintenant` (ms) : la signalisation muette, le canal d'un client, les arrivants de
## l'hôte ; et le `ping` de l'hôte.
func _surveiller(maintenant: int) -> void:
	if _fin_signalisation >= 0 and maintenant >= _fin_signalisation:
		push_warning("Signalisation : pas de réponse en %.0f s" % DELAI_SIGNALISATION)
		_signalisation_perdue(ECHEC_INJOIGNABLE)
	if _fin_canal >= 0 and maintenant >= _fin_canal:
		_fin_canal = -1
		_signalisation_finie = true  # l'échec est dit : rien de reçu ensuite, ni la fermeture qui suit, ne compte
		if _actif:
			echec.emit(ECHEC_DELAI)
	for id: int in _arrivees.keys():
		if maintenant >= _arrivees[id]:
			_arrivees.erase(id)
			_retirer(id)
	if _prochain_ping >= 0 and maintenant >= _prochain_ping:
		_prochain_ping = maintenant + int(PERIODE_PING * 1000.0)
		_file.append(PING)


## Envoie les messages de la file à `maintenant` (ms), dans l'ordre, tant qu'il le peut : la socket
## ouverte, un créneau par envoi, ECART_ENVOIS ms après celui de l'envoi précédent, jamais avant l'image
## précédente (une longue attente ne s'accumule pas) ni après `maintenant`, et pas plus de
## ENVOIS_PAR_SECONDE créneaux dans une seconde. À 60 images par seconde, un envoi toutes les 50 ms ; à 2
## images par seconde (un appareil lent), une dizaine par image au lieu d'un seul, la salle (un seau de
## 20 jetons, rempli de 20 par seconde) jamais à sec.
func _vider_file(maintenant: int) -> void:
	var depuis := maintenant if _image_precedente < 0 else _image_precedente
	_image_precedente = maintenant
	if not _socket_prete():
		return
	while not _file.is_empty():
		var creneau := depuis if _derniers_envois.is_empty() else maxi(_derniers_envois[-1] + ECART_ENVOIS, depuis)
		if creneau > maintenant:
			return
		if _derniers_envois.size() == ENVOIS_PAR_SECONDE and creneau - _derniers_envois[0] < 1000:
			return
		_ecrire(_file[0])
		_file.remove_at(0)
		_derniers_envois.append(creneau)
		if _derniers_envois.size() > ENVOIS_PAR_SECONDE:
			_derniers_envois.pop_front()


## Met `message` en file (JSON, ses entiers écrits en entiers).
func _envoyer(message: Dictionary) -> void:
	_file.append(JSON.stringify(message))


func _demarrer() -> void:
	_actif = true
	_fin_signalisation = Time.get_ticks_msec() + int(DELAI_SIGNALISATION * 1000.0)


func _poser_pair(pair_session: WebRTCMultiplayerPeer) -> void:
	_pair = pair_session
	_pair.peer_connected.connect(_sur_pair_connecte)
	_pair.peer_disconnected.connect(_sur_pair_parti)


## Chez l'hôte : le client `id` arrive ; sa connexion se crée avec les serveurs ICE `ice` de son arrivée
## (des identifiants TURN neufs), son offre part, son canal a DELAI_CANAL pour s'ouvrir. Il est arrivant
## avant `_relier` : une offre prête pendant l'appel part (`_signaler_vers`) ; plus sur une erreur.
func _accueillir(id: int, ice: Array) -> void:
	_ice = ice
	_arrivees[id] = Time.get_ticks_msec() + int(DELAI_CANAL * 1000.0)
	var erreur := _relier(id)
	if erreur != OK:
		_arrivees.erase(id)
		push_error("TransportWebRTC : connexion impossible vers %d (erreur %d)" % [id, erreur])


## Chez un client : son identifiant `id` est arrivé ; son pair naît (`pair_pret`), relié à l'hôte, dont
## il attend l'offre ; son canal a DELAI_CANAL pour s'ouvrir.
func _devenir_client(id: int) -> void:
	var pair_client := WebRTCMultiplayerPeer.new()
	var erreur := pair_client.create_client(id, CANAUX)
	if erreur == OK:
		_poser_pair(pair_client)
		erreur = _relier(ID_HOTE)
	if erreur != OK:
		push_error("TransportWebRTC : connexion impossible vers l'hôte (erreur %d)" % erreur)
		_signalisation_perdue(ECHEC_DELAI)
		return
	_fin_canal = Time.get_ticks_msec() + int(DELAI_CANAL * 1000.0)
	pair_pret.emit()


## Le pair `id` a tous ses canaux ouverts : chez l'hôte, la salle l'oublie (`ouvert`) ; chez un client,
## le canal vers l'hôte est ouvert (`connecte`).
func _sur_pair_connecte(id: int) -> void:
	if _hote:
		if _arrivees.erase(id):
			_envoyer({"t": "ouvert", "id": id})
	elif id == ID_HOTE and not _canal_ouvert:
		_canal_ouvert = true
		_fin_canal = -1
		if _actif:
			connecte.emit()


## Le pair `id`, connecté, est parti (`Reseau` le sait par `SceneMultiplayer`) : sa connexion est oubliée.
func _sur_pair_parti(id: int) -> void:
	_connexions.erase(id)


## La description locale `type` (« offer » chez l'hôte, « answer » chez un client) de la connexion vers
## `id` est prête : posée, puis envoyée par la salle (si elle peut encore servir, `_signaler_vers`).
func _sur_description(type: String, sdp: String, id: int) -> void:
	var connexion: WebRTCPeerConnection = _connexions.get(id)
	if connexion != null:
		connexion.set_local_description(type, sdp)
	if _signaler_vers(id):
		_envoyer({"t": "offre" if type == "offer" else "reponse", "vers": id, "sdp": sdp})


## Un candidat ICE local de la connexion vers `id`, envoyé par la salle (si elle peut encore servir).
func _sur_candidat(media: String, index: int, nom: String, id: int) -> void:
	if _signaler_vers(id):
		_envoyer({"t": "candidat", "vers": id, "media": media, "index": index, "nom": nom})


## Vrai si la salle doit encore porter la signalisation vers `id` : chez l'hôte, un arrivant au canal pas
## encore ouvert (ni ouvert, ni parti, ni retiré) ; chez un client, tant que sa socket vit et que sa
## signalisation n'est pas finie. Sinon, rien ne part : la salle ne le relaierait à personne.
func _signaler_vers(id: int) -> bool:
	if _hote:
		return _arrivees.has(id)
	return _ws != null and not _signalisation_finie


## Vrai si aucun canal d'aucun pair n'a encore de données à envoyer.
func _canaux_vides() -> bool:
	var pairs: Dictionary = _pair.get_peers()
	for id: int in pairs:
		for canal: WebRTCDataChannel in pairs[id].channels:
			if canal.get_buffered_amount() > 0:
				return false
	return true


# Entrées et sorties, que remplace la sous-classe des tests unitaires (aucune n'a de WebRTC sur le
# desktop) : la socket de signalisation, puis les connexions WebRTC.

func _ouvrir_socket(url: String) -> Error:
	_ws = WebSocketPeer.new()
	var erreur := _ws.connect_to_url(url)
	if erreur != OK:
		_ws = null
	return erreur


## Relève la socket : chaque message en attente, même la socket fermée (une `erreur` suivie de sa
## fermeture arrive d'un coup), puis sa fermeture.
func _servir_socket() -> void:
	if _ws == null:
		return
	_ws.poll()
	var etat := _ws.get_ready_state()
	while _ws != null and _ws.get_available_packet_count() > 0:
		var paquet := _ws.get_packet()
		if _ws.was_string_packet():
			recevoir(paquet.get_string_from_utf8())
	if _ws != null and etat == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		var motif := _ws.get_close_reason()
		_ws = null
		_sur_socket_fermee(code, motif)


func _socket_prete() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func _ecrire(texte: String) -> void:
	if _ws.send_text(texte) != OK:
		push_warning("Signalisation : envoi impossible")


func _fermer_socket() -> void:
	if _ws != null:
		_ws.close()
		_ws = null


## Crée la connexion WebRTC vers `id` (les serveurs ICE `_ice`), l'ajoute au pair ; chez l'hôte, son
## offre se prépare (`_sur_description`). Sur une erreur, rien ne reste : ni connexion, ni pair à moitié
## ajouté.
func _relier(id: int) -> Error:
	var connexion := WebRTCPeerConnection.new()
	var erreur := connexion.initialize(configuration_ice(_ice, relais))
	if erreur != OK:
		return erreur
	connexion.session_description_created.connect(_sur_description.bind(id))
	connexion.ice_candidate_created.connect(_sur_candidat.bind(id))
	erreur = _pair.add_peer(connexion, id, DUREE_NON_FIABLE)
	if erreur != OK:
		connexion.close()
		return erreur
	_connexions[id] = connexion
	if not _hote:
		return OK
	erreur = connexion.create_offer()
	if erreur != OK:
		_connexions.erase(id)
		connexion.close()
		if _pair.has_peer(id):
			_pair.remove_peer(id)
	return erreur


## Retire l'arrivant `id`, au canal encore fermé (délai, `depart`) : sa connexion se ferme.
func _retirer(id: int) -> void:
	var connexion: WebRTCPeerConnection = _connexions.get(id)
	_connexions.erase(id)
	if connexion != null:
		connexion.close()
	if _pair != null and _pair.has_peer(id):
		_pair.remove_peer(id)


## La description distante `type` de la connexion vers `id` (« offer » chez un client : sa réponse se
## prépare d'elle-même ; « answer » chez l'hôte).
func _appliquer_description(id: int, type: String, sdp: String) -> void:
	_connexions[id].set_remote_description(type, sdp)


func _appliquer_candidat(id: int, media: String, index: int, nom: String) -> void:
	_connexions[id].add_ice_candidate(media, index, nom)
