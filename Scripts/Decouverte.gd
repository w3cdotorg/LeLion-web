extends Node
## Découverte des parties sur le réseau local (spec §4) : la balise UDP de l'hôte et l'écoute de
## l'écran Réseau.
##
## Balise : tant que ce poste héberge (`Reseau` en ligne et hôte), une fois par PERIODE_BALISE, un
## datagramme texte vers le port PORT_BALISE de chaque destination de diffusion :
## `LELION|<version>|<port de jeu>|<nb joueurs>|<places>|<manche 0/1>|<niveau>|<pseudo hôte>`.
## Le pseudo, seul texte libre, vient en dernier : il peut contenir `|` sans décaler les autres
## champs. Personne n'a à démarrer ni à arrêter la balise : elle suit l'état de `Reseau` (un
## `Reseau.quitter()` l'arrête à la période suivante), jusque dans le salon (phase 13).
##
## Écoute : `ecouter()` ouvre le port PORT_BALISE (l'écran Réseau, tant qu'il cherche des parties),
## `arreter_ecoute()` le ferme. Les balises reçues remplissent `parties`, par « ip:port de jeu » ;
## une partie dont la balise ne revient pas pendant DELAI_EXPIRATION disparaît. Rien ne bloque le
## thread principal : sockets non bloquantes, adresses IP littérales (jamais de résolution de nom).
##
## Autoload : les tests `--script` le récupèrent par `root.get_node("Decouverte")` et ne le nomment
## pas. Ce script ne nomme aucun autoload (il trouve `Reseau` et `GameState` par leur chemin) : les
## fonctions statiques se testent sans eux.

## Une partie est apparue, a disparu, ou sa balise a changé (joueurs, manche, niveau…).
signal parties_changees()

const _Reseau := preload("res://Scripts/Reseau.gd")

const PORT_BALISE := 7778
## Secondes entre deux balises (spec §4 : toutes les secondes).
const PERIODE_BALISE := 1.0
## Une partie sans balise depuis ce délai, en secondes, disparaît de la liste (spec §4 : 3 s).
const DELAI_EXPIRATION := 3.0
## Adresse de diffusion limitée : tout le segment de l'interface par défaut.
const DIFFUSION := "255.255.255.255"
## Au-delà, un datagramme n'est pas une balise (le décodage reste borné, quel que soit l'émetteur).
const TAILLE_BALISE_MAX := 512
## Parties gardées au plus : des balises forgées ne font pas grossir la liste sans fin.
const PARTIES_MAX := 16
## Datagrammes lus au plus par image : un déluge sur le port ne gèle pas l'image, le reste attend
## l'image suivante.
const PAQUETS_PAR_IMAGE_MAX := 32
const _NB_CHAMPS := 8
## Une version reste courte et sans séparateur (elle s'affiche dans le refus « version différente »).
const _MOTIF_VERSION := "^[0-9A-Za-z._-]{1,16}$"

## Port des balises, émises et écoutées. Modifiable par les tests (jamais le 7778 d'une vraie partie).
var port_balise := PORT_BALISE
## Si non vide, les destinations des balises à la place de la diffusion (les tests : 127.0.0.1).
var destinations_forcees := PackedStringArray()
## Parties entendues, par « ip:port » : {version, port, nb_joueurs, places, manche_en_cours, niveau,
## pseudo, ip, vue_a (Time.get_ticks_msec de la dernière balise)}.
var parties: Dictionary[String, Dictionary] = {}
## Résultat du dernier `ecouter()` : OK, ou l'erreur du port (déjà pris par un autre programme ou
## un autre LeLion sur ce PC).
var erreur_ecoute := OK

var _ecouteur: PacketPeerUDP
var _emetteur: PacketPeerUDP
var _destinations := PackedStringArray()
## Vrai entre un `ecouter()` et son `arreter_ecoute()`, même si le port était pris au moment de
## l'appel : la minuterie réessaie tant que ce souhait tient (Minor 5, deux fenêtres sur un PC).
var _ecoute_voulue := false
static var _motif_version: RegEx = RegEx.create_from_string(_MOTIF_VERSION)
## Le préfixe exact de toute balise, en octets : un datagramme qui ne commence pas par ces octets
## n'est jamais passé à `get_string_from_utf8()` (Minor 2 : pas de ligne ERROR pour un autre
## programme, ou un déluge, sur le port des balises).
static var _prefixe_octets: PackedByteArray = "LELION|".to_ascii_buffer()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var minuterie := Timer.new()
	minuterie.wait_time = PERIODE_BALISE
	minuterie.timeout.connect(_sur_minuterie)
	add_child(minuterie)
	minuterie.start()


## Chaque PERIODE_BALISE : la balise (si ce poste héberge), puis un nouvel essai d'écoute (si le
## port était pris à la dernière tentative et l'est peut-être libéré depuis, Minor 5).
func _sur_minuterie() -> void:
	_emettre_balise()
	_reessayer_ecoute()


## Ouvre l'écoute des balises sur `port_balise` (repart d'une liste vide). Renvoie OK, ou l'erreur
## si le port est déjà pris : rien ne plante, `ecoute_active()` reste faux, `erreur_ecoute` la
## garde, et la minuterie réessaie toute seule (Minor 5) tant qu'`arreter_ecoute()` n'a pas annulé
## ce souhait : une seconde fenêtre lancée pendant que la première héberge encore n'a pas besoin de
## revenir à l'accueil pour profiter du port libéré.
func ecouter() -> Error:
	_fermer_socket_ecoute()
	_ecoute_voulue = true
	return _essayer_ecoute()


## Ferme l'écoute et oublie les parties entendues. Sans effet si rien n'écoute.
func arreter_ecoute() -> void:
	_ecoute_voulue = false
	_fermer_socket_ecoute()


func _fermer_socket_ecoute() -> void:
	if _ecouteur != null:
		_ecouteur.close()
		_ecouteur = null
	if not parties.is_empty():
		parties.clear()
		parties_changees.emit()


## Une tentative de `bind()`, sans toucher à `_ecoute_voulue` ni à la liste des parties (appelée par
## `ecouter()` comme par la minuterie).
func _essayer_ecoute() -> Error:
	var ecouteur := PacketPeerUDP.new()
	# Une socket IPv4 (et non « * », à double pile sous Windows) : les diffusions IPv4 y arrivent.
	erreur_ecoute = ecouteur.bind(port_balise, "0.0.0.0")
	if erreur_ecoute == OK:
		_ecouteur = ecouteur
	return erreur_ecoute


## Rien tant que l'écoute n'est pas voulue, ou qu'elle écoute déjà. Sinon, un nouvel essai (le port
## d'un autre LeLion sur ce PC, ou d'un autre programme, a pu se libérer depuis) ; la liste affichée
## change si l'essai réussit.
func _reessayer_ecoute() -> void:
	if _ecoute_voulue and _ecouteur == null and _essayer_ecoute() == OK:
		parties_changees.emit()


func ecoute_active() -> bool:
	return _ecouteur != null


## Les parties entendues, triées par pseudo puis par adresse (un ordre stable pour la liste).
func parties_triees() -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	liste.assign(parties.values())
	liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ordre: int = a.pseudo.nocasecmp_to(b.pseudo)
		return ordre < 0 if ordre != 0 else "%s:%d" % [a.ip, a.port] < "%s:%d" % [b.ip, b.port])
	return liste


func _process(_delta: float) -> void:
	if _ecouteur == null:
		return
	var maintenant := Time.get_ticks_msec()
	var change := false
	var lus := 0
	while lus < PAQUETS_PAR_IMAGE_MAX and _ecouteur.get_available_packet_count() > 0:
		lus += 1
		var donnees := _ecouteur.get_packet()
		var fiche := decoder_balise(donnees)
		if not fiche.is_empty():
			change = enregistrer_partie(parties, _ecouteur.get_packet_ip(), fiche, maintenant) or change
	change = purger_parties(parties, maintenant, int(DELAI_EXPIRATION * 1000.0)) or change
	if change:
		parties_changees.emit()


## Chaque seconde : une balise si ce poste héberge, sinon la socket d'émission se ferme.
func _emettre_balise() -> void:
	var reseau := get_node_or_null(^"/root/Reseau")
	var pair := multiplayer.multiplayer_peer
	if reseau == null or not reseau.en_ligne() or not multiplayer.is_server() or not (pair is ENetMultiplayerPeer):
		_fermer_emetteur()
		return
	if _emetteur == null:
		_ouvrir_emetteur()
	var partie := get_node_or_null(^"/root/GameState")
	var hote: Dictionary = reseau.inscrits.get(multiplayer.get_unique_id(), {})
	var balise := encoder_balise(reseau.version, (pair as ENetMultiplayerPeer).host.get_local_port(),
		reseau.inscrits.size(), reseau.places, reseau.manche_en_cours,
		partie.niveau_courant if partie != null else 0, hote.get("pseudo", ""))
	for destination in _destinations:
		# set_dest_address() n'échoue que pour un nom à résoudre (jamais ici, des adresses
		# littérales) ; une destination injoignable (interface tombée, pas de route) fait échouer
		# put_packet(), dont l'erreur est ignorée : elle n'empêche pas les autres destinations.
		if _emetteur.set_dest_address(destination, port_balise) == OK:
			_emetteur.put_packet(balise)


func _ouvrir_emetteur() -> void:
	_emetteur = PacketPeerUDP.new()
	_emetteur.set_broadcast_enabled(true)
	_emetteur.bind(0, "0.0.0.0")  # port quelconque, IPv4 : la diffusion part de cette socket
	# Les interfaces sont relues à chaque session hébergée (câble branché, Wi-Fi changé entre-temps).
	_destinations = destinations_forcees if not destinations_forcees.is_empty() \
		else destinations_balise(IP.get_local_addresses())


func _fermer_emetteur() -> void:
	if _emetteur != null:
		_emetteur.close()
		_emetteur = null


## La balise d'une partie, en octets UTF-8.
static func encoder_balise(version: String, port: int, nb_joueurs: int, places: int, manche_en_cours: bool,
		niveau: int, pseudo: String) -> PackedByteArray:
	return "|".join(PackedStringArray([_Reseau.JEU, version, str(port), str(nb_joueurs), str(places),
		"1" if manche_en_cours else "0", str(niveau), pseudo])).to_utf8_buffer()


## La fiche d'une balise reçue : {version, port, nb_joueurs, places, manche_en_cours, niveau,
## pseudo} ; un dictionnaire vide pour tout ce qui n'est pas une balise valide (autre programme,
## datagramme tronqué ou forgé). Le pseudo est nettoyé comme l'hôte nettoie ceux de ses joueurs.
## Le préfixe `LELION|` est vérifié en octets avant tout décodage UTF-8 (Minor 2) : un datagramme
## d'un autre programme, ou invalide en UTF-8, n'imprime donc aucune ligne ERROR dans le journal.
static func decoder_balise(donnees: PackedByteArray) -> Dictionary:
	if donnees.size() < _prefixe_octets.size() or donnees.size() > TAILLE_BALISE_MAX \
			or donnees.slice(0, _prefixe_octets.size()) != _prefixe_octets:
		return {}
	var champs := donnees.get_string_from_utf8().split("|", true, _NB_CHAMPS - 1)
	if champs.size() != _NB_CHAMPS or champs[0] != _Reseau.JEU:
		return {}
	if _motif_version.search(champs[1]) == null:
		return {}
	# Au plus 5 caractères (le port va jusqu'à 65535) avant `is_valid_int()` : un entier hors de
	# l'int64 forgé dans un champ ne passe plus par `to_int()`, qui imprimerait une ligne ERROR.
	for i in [2, 3, 4, 6]:
		if champs[i].length() > 5 or not champs[i].is_valid_int():
			return {}
	var port := champs[2].to_int()
	var nb_joueurs := champs[3].to_int()
	var places := champs[4].to_int()
	var niveau := champs[6].to_int()
	if port < 1 or port > 65535 or places < 2 or places > EtatPartie.NB_JOUEURS_MAX \
			or nb_joueurs < 1 or nb_joueurs > places or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (champs[5] == "0" or champs[5] == "1"):
		return {}
	return {"version": champs[1], "port": port, "nb_joueurs": nb_joueurs, "places": places,
		"manche_en_cours": champs[5] == "1", "niveau": niveau, "pseudo": _Reseau.pseudo_ou_defaut(champs[7], 0)}


## Inscrit (ou rafraîchit) dans `liste` la partie de la fiche `fiche` entendue depuis `ip` à
## `maintenant_ms`. Renvoie vrai si la liste affichée change (partie nouvelle ou balise différente),
## faux pour une simple balise répétée, ou pour une partie nouvelle quand la liste est pleine
## (PARTIES_MAX).
static func enregistrer_partie(liste: Dictionary[String, Dictionary], ip: String, fiche: Dictionary,
		maintenant_ms: int) -> bool:
	var cle := "%s:%d" % [ip, fiche.port]
	var ancienne: Dictionary = liste.get(cle, {})
	if ancienne.is_empty() and liste.size() >= PARTIES_MAX:
		return false
	var nouvelle := fiche.duplicate()
	nouvelle["ip"] = ip
	nouvelle["vue_a"] = maintenant_ms
	liste[cle] = nouvelle
	return ancienne.is_empty() or _sans_date(ancienne) != _sans_date(nouvelle)


static func _sans_date(partie: Dictionary) -> Dictionary:
	var copie := partie.duplicate()
	copie.erase("vue_a")
	return copie


## Retire de `liste` les parties sans balise depuis plus de `delai_ms`. Renvoie vrai si une partie
## a disparu.
static func purger_parties(liste: Dictionary[String, Dictionary], maintenant_ms: int, delai_ms: int) -> bool:
	var perimees := liste.keys().filter(func(cle: String) -> bool: return maintenant_ms - int(liste[cle].vue_a) > delai_ms)
	for cle: String in perimees:
		liste.erase(cle)
	return not perimees.is_empty()


## Destinations des balises pour les adresses locales `adresses` (`IP.get_local_addresses()`) : la
## diffusion limitée, plus la diffusion dirigée de chaque réseau privé IPv4 (a.b.c.255, en
## supposant un /24, le cas des box ; 169.254.255.255 pour une liaison directe sans DHCP). Sous
## Windows, 255.255.255.255 ne sort que par une interface, pas forcément celle du Wi-Fi de la LAN
## (VPN, cartes virtuelles) : la diffusion dirigée couvre les autres. N'utilise jamais l'ordre trié
## ni le filtre 169.254 de `adresses_privees` (Minor 6) : elle vise tous les réseaux privés, quel
## que soit ce que l'hôte doit lire à voix haute (revue de la phase 12, constat 6).
static func destinations_balise(adresses: PackedStringArray) -> PackedStringArray:
	var destinations := PackedStringArray([DIFFUSION])
	for adresse in _adresses_privees_brutes(adresses):
		var octets := adresse.split(".")
		var dirigee := "169.254.255.255" if octets[0] == "169" else "%s.%s.%s.255" % [octets[0], octets[1], octets[2]]
		if not destinations.has(dirigee):
			destinations.append(dirigee)
	return destinations


## Les adresses IPv4 privées ou de liaison locale parmi `adresses` (10/8, 172.16/12, 192.168/16,
## 169.254/16), dans l'ordre reçu : la matière première commune à `destinations_balise` (chaque
## réseau reçoit sa diffusion dirigée, sans tri d'affichage) et à `adresses_privees` (triées pour
## l'hôte).
static func _adresses_privees_brutes(adresses: PackedStringArray) -> PackedStringArray:
	var privees := PackedStringArray()
	for adresse in adresses:
		var normale := adresse_ipv4(adresse)
		if normale.is_empty():
			continue
		var octets := normale.split(".")
		var a := octets[0].to_int()
		var b := octets[1].to_int()
		if a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 169 and b == 254):
			if not privees.has(normale):
				privees.append(normale)
	return privees


## Les adresses IPv4 privées ou de liaison locale de `adresses`, triées pour l'affichage à l'hôte
## (l'écran Réseau, « ton adresse : … ») : les cartes réelles d'une LAN domestique d'abord
## (192.168/16, hors 192.168.56/24 réservé à VirtualBox Host-Only), puis 10/8, puis 172.16/12
## (souvent une carte virtuelle sous Windows : vEthernet Hyper-V, WSL2, Docker Desktop — groupée
## avec 192.168.56/24), enfin 169.254/16 (liaison directe sans DHCP), affichée seulement s'il n'y a
## rien d'autre. Ordre stable au sein d'un même rang (revue de la phase 12, constat 6). Sous
## Windows, `GetAdaptersAddresses` liste souvent les cartes virtuelles avant le Wi-Fi ; sans ce tri,
## l'hôte lisait à voix haute une adresse que le client ne pouvait pas joindre.
static func adresses_privees(adresses: PackedStringArray) -> PackedStringArray:
	var rangs: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray()]
	for normale in _adresses_privees_brutes(adresses):
		var octets := normale.split(".")
		var a := octets[0].to_int()
		var b := octets[1].to_int()
		var c := octets[2].to_int()
		if a == 192 and b == 168:
			rangs[2 if c == 56 else 0].append(normale)
		elif a == 10:
			rangs[1].append(normale)
		elif a == 172:
			rangs[2].append(normale)
		else:  # 169.254
			rangs[3].append(normale)
	if not (rangs[0].is_empty() and rangs[1].is_empty() and rangs[2].is_empty()):
		rangs[3] = PackedStringArray()
	var privees := PackedStringArray()
	for rang in rangs:
		for normale in rang:
			privees.append(normale)
	return privees


## Motifs (en minuscules) qui trahissent une carte virtuelle dans son nom ou son libellé : testés
## avant les motifs physiques, car « vEthernet » contient « ethernet » (I1, revue finale de la
## phase 12 bis : virtuelle en dernier recours, l'hôte ne peut pas y répondre).
const _MOTIFS_INTERFACE_VIRTUELLE := ["vethernet", "virtualbox", "vboxnet", "vmware", "vmnet",
	"hyper-v", "wsl", "docker", "bridge", "br-", "virbr", "veth", "utun", "tun", "tap", "tailscale",
	"zerotier", "hamachi", "wireguard", "openvpn", "nordlynx", "vpn", "awdl", "llw", "anpi",
	"loopback", "npcap"]
## Débuts de libellé qui trahissent une vraie carte réseau (Wi-Fi, Ethernet) : testés seulement si
## aucun motif virtuel n'a déjà répondu.
const _PREFIXES_INTERFACE_PHYSIQUE := ["wi-fi", "wlan", "ethernet", "eth", "wl", "enp"]
static var _motif_interface_en: RegEx = RegEx.create_from_string("^en\\d+$")


## Le rang de `interface` (un élément d'`IP.get_local_interfaces()`) : 0 une carte probablement
## physique (Wi-Fi, Ethernet, en0…), 2 une carte probablement virtuelle (vEthernet, VirtualBox,
## VMware, Hyper-V, WSL, Docker, bridges, tunnels VPN…), 1 sinon (nom inconnu ou libellé localisé,
## par exemple « Connexion au réseau local »).
static func _rang_interface(interface: Dictionary) -> int:
	var etiquette: String = ("%s %s" % [str(interface.get("friendly", "")), str(interface.get("name", ""))]).to_lower()
	for motif in _MOTIFS_INTERFACE_VIRTUELLE:
		if etiquette.contains(motif):
			return 2
	var friendly: String = str(interface.get("friendly", "")).to_lower()
	for prefixe in _PREFIXES_INTERFACE_PHYSIQUE:
		if friendly.begins_with(prefixe):
			return 0
	if _motif_interface_en.search(friendly) != null:
		return 0
	return 1


## Les adresses à lire à voix haute pour héberger (I1, revue finale de la phase 12 bis) : parmi
## `interfaces` (la forme d'`IP.get_local_interfaces()` : des dictionnaires {name, friendly, index,
## addresses, …}), celles du meilleur rang d'interface non vide (`_rang_interface` : les cartes
## physiques d'abord, les virtuelles seulement en dernier recours), triées à l'intérieur du rang
## comme `adresses_privees` (cartes réelles d'une LAN domestique d'abord, puis 10/8, puis
## 172.16/12, 169.254 en tout dernier recours). Fonction statique pure : testée sur de faux
## tableaux, sans l'OS. `Decouverte` n'est plus gelé à partir de cette phase (le salon de la phase
## 13 réutilisera cette fonction pour afficher l'adresse de l'hôte).
static func adresses_hote(interfaces: Array) -> PackedStringArray:
	var brutes := PackedStringArray()
	var rangs_par_adresse: Dictionary[String, int] = {}
	for interface: Dictionary in interfaces:
		var rang: int = _rang_interface(interface)
		for adresse: String in interface.get("addresses", PackedStringArray()):
			brutes.append(adresse)
			if not rangs_par_adresse.has(adresse) or rang < rangs_par_adresse[adresse]:
				rangs_par_adresse[adresse] = rang
	var triees := adresses_privees(brutes)
	if triees.is_empty():
		return PackedStringArray()
	var meilleur_rang := 2
	for adresse in triees:
		meilleur_rang = mini(meilleur_rang, rangs_par_adresse.get(adresse, 1))
	var hote := PackedStringArray()
	for adresse in triees:
		if rangs_par_adresse.get(adresse, 1) == meilleur_rang:
			hote.append(adresse)
	return hote


## L'adresse IPv4 saisie `texte` sous sa forme normale, ou une chaîne vide (voir
## `TransportENet.adresse_ipv4`, qui la porte depuis la phase 1 : le code d'une partie ENet).
static func adresse_ipv4(texte: String) -> String:
	return TransportENet.adresse_ipv4(texte)
