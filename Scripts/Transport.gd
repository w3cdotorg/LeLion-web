@abstract
class_name Transport
extends RefCounted
## Le transport d'une session (spec §3.1) : ce qui ouvre et ferme les canaux entre l'hôte et ses
## clients, sous le `MultiplayerPeer` que `Reseau` donne à `SceneMultiplayer`. Ne sait rien du salon
## ni du jeu : la poignée de main, la table, le battement et les départs restent dans `Reseau`.
## Deux implémentations : `TransportENet` (desktop de développement, tests headless) et
## `TransportWebRTC` (l'export Web).
##
## Contrat commun : `heberger()` ou `rejoindre()` une seule fois par objet ; `servir()` à chaque
## image tant qu'il renvoie vrai (session ouverte, ou départ en cours après `quitter()`) ; `servir()`
## faux sans `quitter()` ni `clore()` : la session est perdue (le transport s'est fermé de lui-même),
## `Reseau` la traite comme la perte de l'hôte (un échec de connexion avant l'inscription, ou avant
## `pret` chez l'hôte). Après `quitter()` ou `clore()`, plus aucun signal.

## Chez l'hôte : la session existe, `code` est ce qu'un client donne à `rejoindre()` (pendant
## `heberger()` en ENet ; plus tard en WebRTC, quand la salle de la signalisation existe).
signal pret(code: String)
## Chez un client : le canal vers l'hôte est ouvert, la poignée de main de `SceneMultiplayer` peut
## partir.
signal connecte()
## Chez un client : son pair existe désormais (`pair()` le rend), après le retour de `rejoindre()` : en
## WebRTC, son identifiant vient de la signalisation, et `SceneMultiplayer` refuse un pair qui n'a pas
## encore le sien. `Reseau` le pose alors. Il doit précéder le premier `poll()` du pair qui y ajoute le
## pair 1 (l'hôte) : `SceneMultiplayer` ne rejoue pas les pairs déjà connectés quand on lui donne le pair,
## et la poignée de main ne partirait jamais. Jamais chez un transport dont le pair existe dès le retour
## de `rejoindre()` (ENet), jamais pendant l'appel.
signal pair_pret()
## Chez un client : le canal ne s'ouvrira pas ; chez l'hôte, avant `pret` : la session ne sera pas
## créée (la signalisation refuse, ou ne répond pas). `raison` est une des constantes ECHEC_*. Le
## transport ne se ferme pas seul : l'appelant le quitte ensuite (`quitter()`).
signal echec(raison: String)
## Chez l'hôte, après `pret` : plus personne ne peut rejoindre la session (la salle a expiré, ou la
## signalisation s'est fermée) ; la session continue avec ceux qui sont là. `raison` : ECHEC_EXPIREE, ou
## une autre constante ECHEC_*. Jamais en ENet.
signal salle_fermee(raison: String)

## Le canal vers l'hôte ne s'est pas ouvert dans le délai du transport (en WebRTC, aussi le refus `delai`
## de la signalisation, le même mot : l'hôte n'a pas ouvert le canal à temps).
const ECHEC_DELAI := "delai"
## La signalisation n'a pas répondu à temps, ou s'est fermée sans dire pourquoi (`TransportWebRTC` ;
## spec §9 : 5 s).
const ECHEC_INJOIGNABLE := "injoignable"
## Les autres refus de la signalisation (son message `erreur`, spec §4.2), que `TransportWebRTC` rend
## tels quels, la raison exacte écrite au journal : aucune salle de ce code, salle pleine, débit
## dépassé, quota gratuit épuisé, origine refusée, salle expirée.
const ECHEC_INCONNUE := "inconnue"
const ECHEC_PLEINE := "pleine"
const ECHEC_DEBIT := "debit"
const ECHEC_QUOTA := "quota"
const ECHEC_ORIGINE := "origine"
const ECHEC_EXPIREE := "expiree"


## Ouvre une session hébergée ; `pret` part quand elle existe (pendant l'appel ou plus tard, selon le
## transport), ou `echec` si elle ne peut pas exister (jamais pendant l'appel). Une erreur laisse ce
## transport inutilisable, sans rien d'ouvert.
@abstract func heberger() -> Error


## Rejoint l'hôte désigné par `code` ; `connecte` ou `echec` suit, jamais pendant l'appel (`Reseau` ne
## branche ses signaux qu'au retour, une fois le code accepté). Un code mal formé :
## ERR_INVALID_PARAMETER, sans rien tenter.
@abstract func rejoindre(code: String) -> Error


## Ferme la session après l'envoi de ce qui est en file (l'adieu de `Reseau` compris), en arrière-plan,
## une seconde au plus : `servir()` renvoie vrai jusqu'à la fermeture.
@abstract func quitter() -> void


## Ferme tout de suite, sans rien attendre (un départ en cours est abandonné, un port se libère).
@abstract func clore() -> void


## Le pair que `Reseau` donne à `SceneMultiplayer` (null avant `heberger()` / `rejoindre()` réussis,
## et après la fermeture). Valide (en connexion ou connecté) dès le retour d'un `heberger()` réussi, et
## dès le retour d'un `rejoindre()` réussi ou plus tard, à `pair_pret` (WebRTC) : `Reseau` le pose dès
## qu'il existe.
@abstract func pair() -> MultiplayerPeer


## Chez l'hôte : ferme tout de suite le canal du pair connecté `id` (parti, muet ou exclu), sans
## attendre de réponse (un pair mort ou figé n'en enverra pas) ; son `peer_disconnected` part pendant
## l'appel. Le pair n'en est prévenu qu'au mieux (il s'en ira de lui-même ou l'apprendra par le silence
## de l'hôte).
@abstract func liberer(id: int) -> void


## Une image de service (délais, départ en cours) ; faux une fois le transport fermé, quand `Reseau`
## peut l'oublier.
@abstract func servir() -> bool
