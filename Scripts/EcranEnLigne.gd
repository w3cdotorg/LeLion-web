extends Control
## Écran En ligne (spec §3.1, §4.4 et §9 du jeu en ligne) : pseudo mémorisé, Créer une partie, Rejoindre
## avec un code (rempli d'avance par le lien `?salle=`), messages des refus et des échecs. En 16:9, comme
## le salon ; le titre remet l'écran du solo au retour.
##
## Le code : sur le Web, un code de salle (`CodeSalle`, « K7Q-2XM », ou le lien d'invitation collé
## entier), refusé à la saisie s'il est mal formé ; sur le desktop de développement, l'adresse `ip:port`
## (ou `ip`) d'un hôte `TransportENet` (`codes_de_salle` faux). Sans transport pour jouer en réseau
## (`Reseau.transport_disponible` faux : les tests), Créer et Rejoindre le disent sans rien ouvrir.
##
## Quatre états : ACCUEIL (tout est permis), CREATION (la partie attend son code : en WebRTC, la salle de
## la signalisation ; `Reseau.connexion_echouee` si elle ne vient pas), CONNEXION (en attente de l'hôte)
## et SALON (partie créée, ou inscription reçue : en route vers le salon, tout reste grisé le temps du
## changement de scène). Pendant une création ou une connexion, l'écran ne se fie pas à
## `Reseau.en_ligne()` (faux chez un client WebRTC avant son identifiant), seulement aux signaux. Retour
## (ou Échap, B à la manette) annule l'état en cours, puis ramène au titre. Le salon revient ici avec un
## message (`message_a_l_arrivee`) si l'hôte est perdu ; le titre y vient avec le code du lien de la page
## (`code_a_l_arrivee`).
##
## Mobiles (spec §6, `Parametres.mobile`) : pas de Créer une partie (un mobile ne fait que rejoindre, le
## plus souvent par le lien : coller dans un champ y est peu fiable) ; champs et boutons agrandis pour le
## doigt, textes lisibles à l'échelle d'un téléphone ; le focus va au premier contrôle visible
## (`_donner_focus`). Un champ en édition remonte à MARGE_CLAVIER px du haut de l'écran, au-dessus du
## clavier virtuel du navigateur, le message sous le code, et redescend ensuite ; Rejoindre agit à l'appui
## (au relâchement, il aurait déjà redescendu sous le doigt).

enum Etat { ACCUEIL, CREATION, CONNEXION, SALON }

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCENE_SALON := "res://Scenes/Salon.tscn"
const COULEUR_INFO := Color(1, 1, 1, 0.85)
## Le remplissage blanc porte le contraste ; le contour distingue un refus ou un échec (saumon) d'une
## simple information (sombre).
const COULEUR_ERREUR := Color(1, 1, 1, 0.95)
const COULEUR_CONTOUR_INFO := Color(0.1, 0.05, 0.12, 0.85)
const COULEUR_CONTOUR_ERREUR := Color(0.85, 0.22, 0.14, 0.9)
## Le message de chaque raison d'échec d'un transport (`Reseau.raison_echec`, spec §9).
const MESSAGES_ECHEC := {
	Transport.ECHEC_INCONNUE: "ENLIGNE_SALLE_INCONNUE",
	Transport.ECHEC_EXPIREE: "ENLIGNE_SALLE_INCONNUE",
	Transport.ECHEC_PLEINE: "RESEAU_REFUS_PLEIN",
	Transport.ECHEC_QUOTA: "ENLIGNE_QUOTA",
	Transport.ECHEC_DEBIT: "ENLIGNE_SERVICE_INDISPONIBLE",
	Transport.ECHEC_ORIGINE: "ENLIGNE_SERVICE_INDISPONIBLE",
	Transport.ECHEC_INJOIGNABLE: "ENLIGNE_SERVICE_INDISPONIBLE",
	Transport.ECHEC_DELAI: "ENLIGNE_ECHEC_CANAL",
}
## Un échec sans raison du transport (la poignée de main sans réponse) ou d'une raison inconnue.
const ECHEC_PAR_DEFAUT := "ENLIGNE_ECHEC_CANAL"
## Longueur permise dans le champ du code : un lien d'invitation collé entier (codes de salle), ou une
## adresse `ip:port` (le desktop).
const LONGUEUR_LIEN := 256
const LONGUEUR_ADRESSE := 21
## Sur un mobile, le haut d'une rangée en édition, en px de l'écran (le clavier virtuel couvre le bas).
const MARGE_CLAVIER := 40

## Port de jeu de Créer une partie hors du Web (ENet ; modifiable par les tests).
var port_jeu: int = Reseau.PORT
## Vrai si le code se saisit en code de salle (le Web) ; faux sur le desktop de développement, où c'est
## l'adresse `ip:port` (ou `ip`) d'un hôte ENet. Modifiable par les tests.
var codes_de_salle := OS.has_feature("web")
var etat := Etat.ACCUEIL
## Clé d'un message d'erreur à afficher à la prochaine ouverture de l'écran, puis oubliée : le salon la
## pose avant d'y revenir (« L'hôte a quitté la partie »).
static var message_a_l_arrivee := ""
## Le code d'une salle à rejoindre, posé par le titre quand la page s'ouvre sur un lien `?salle=` (spec
## §4.4), puis oublié : l'écran s'ouvre ce code rempli, sur Rejoindre ; ce poste ne rejoint qu'au
## Rejoindre du joueur, son pseudo choisi.
static var code_a_l_arrivee := ""

@onready var champ_pseudo: LineEdit = $Centre/Colonne/RangeePseudo/Pseudo
@onready var bouton_creer: Button = $Centre/Colonne/Creer
@onready var champ_code: LineEdit = $Centre/Colonne/RangeeCode/Code
@onready var bouton_rejoindre: Button = $Centre/Colonne/RangeeCode/Rejoindre
@onready var message: Label = $Centre/Colonne/Message
@onready var bouton_retour: Button = $BoutonRetour
@onready var centre: CenterContainer = $Centre
@onready var etiquette_ou: Label = $Centre/Colonne/Ou

## Le message affiché, gardé en clé et arguments pour être retraduit au changement de langue.
var _message := {"cle": "", "arguments": [], "erreur": false}
## Vrai pendant une tentative lancée par Rejoindre : un refus ou un échec rend le focus au code (sinon à
## Créer une partie).
var _par_le_code := false


func _ready() -> void:
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
	champ_pseudo.max_length = Reseau.PSEUDO_MAX
	champ_pseudo.text = Reseau.pseudo_valide(str(Scores.preference("pseudo", "")))
	champ_code.placeholder_text = "K7Q-2XM" if codes_de_salle else "192.168.1.20:%d" % Reseau.PORT
	# Sur le Web, de quoi coller le lien d'invitation entier ; sur le desktop, « 255.255.255.255:65535 ».
	champ_code.max_length = LONGUEUR_LIEN if codes_de_salle else LONGUEUR_ADRESSE
	Reseau.inscrit.connect(_sur_inscription)
	Reseau.refuse.connect(_sur_refus)
	Reseau.connexion_echouee.connect(_sur_connexion_echouee)
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	Reseau.salon_change.connect(_sur_salon_change)
	Parametres.langue_changee.connect(_sur_langue_changee)
	champ_pseudo.editing_toggled.connect(_sur_edition.bind(champ_pseudo))
	champ_code.editing_toggled.connect(_sur_edition.bind(champ_code))
	if Parametres.mobile:
		_mettre_en_page_mobile()
	_changer_etat(Etat.ACCUEIL)
	if not code_a_l_arrivee.is_empty():
		champ_code.text = CodeSalle.formater(code_a_l_arrivee)
		code_a_l_arrivee = ""
		_afficher_message("ENLIGNE_INVITATION", [], false)
		if champ_pseudo.text.is_empty():
			champ_pseudo.grab_focus()
		else:
			bouton_rejoindre.grab_focus()
	if not message_a_l_arrivee.is_empty():
		_afficher_message(message_a_l_arrivee, [], true)
		message_a_l_arrivee = ""


## Les autoloads survivent à l'écran : ne rien leur laisser. Ne quitte pas le réseau : le salon prend la
## suite d'une partie créée ou rejointe.
func _exit_tree() -> void:
	Reseau.inscrit.disconnect(_sur_inscription)
	Reseau.refuse.disconnect(_sur_refus)
	Reseau.connexion_echouee.disconnect(_sur_connexion_echouee)
	Reseau.hote_perdu.disconnect(_sur_hote_perdu)
	Reseau.salon_change.disconnect(_sur_salon_change)
	Parametres.langue_changee.disconnect(_sur_langue_changee)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Échap dans un champ en édition n'en sort pas de lui-même : on en sort d'abord, un second Échap
	# ramène à l'accueil ou au titre.
	var proprietaire := get_viewport().gui_get_focus_owner()
	if proprietaire is LineEdit and (proprietaire as LineEdit).is_editing():
		(proprietaire as LineEdit).unedit()
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	retour()


## Crée une partie avec le pseudo saisi : sur le Web, en WebRTC (`TransportWebRTC`), le salon s'ouvre à la
## salle de la signalisation, qui donne son code (CREATION d'ici là, ou l'échec et son message ; une
## signalisation qui ne s'ouvre même pas, ERR_CANT_CONNECT : « Service de connexion indisponible ») ; hors du
## Web, en ENet sur `port_jeu`, tout de suite.
func creer_partie() -> void:
	if etat != Etat.ACCUEIL:
		return
	_appliquer_pseudo()
	_par_le_code = false
	var erreur: Error = Reseau.creer_partie(port_jeu)
	if erreur == ERR_UNAVAILABLE:
		_afficher_message("ENLIGNE_INDISPONIBLE", [], true)
	elif erreur == ERR_CANT_CONNECT:
		_afficher_message("ENLIGNE_SERVICE_INDISPONIBLE", [], true)
	elif erreur == ERR_CANT_CREATE:
		_afficher_message("RESEAU_PORT_OCCUPE", [port_jeu], true)
	elif erreur != OK:
		_afficher_message("RESEAU_HEBERGER_IMPOSSIBLE", [erreur], true)
	elif Reseau.code_partie.is_empty():
		_changer_etat(Etat.CREATION)
		_afficher_message("ENLIGNE_CREATION", [], false)
	else:
		_ouvrir_salon()


## Rejoint la partie du code saisi, avec le pseudo saisi ; un code mal formé est refusé d'emblée (spec
## §9), sans rien tenter. Le code s'affiche alors sous sa forme normale (« K7Q-2XM », ou l'adresse de
## l'hôte ENet) ; un transport qui le refuse d'emblée donne son code d'erreur, le focus au code.
func rejoindre() -> void:
	if etat != Etat.ACCUEIL:
		return
	var code := _lire_code()
	if code.is_empty():
		champ_code.grab_focus()
		return
	champ_code.text = CodeSalle.formater(code)
	_appliquer_pseudo()
	_par_le_code = true
	var erreur: Error = Reseau.rejoindre_partie(code)
	if erreur == ERR_UNAVAILABLE:
		_afficher_message("ENLIGNE_INDISPONIBLE", [], true)
		return
	if erreur == ERR_CANT_CONNECT:
		# La signalisation ne s'ouvre même pas (`TransportWebRTC._ouvrir_signalisation`) : le code n'y est pour rien.
		_afficher_message("ENLIGNE_SERVICE_INDISPONIBLE", [], true)
		champ_code.grab_focus()
		return
	if erreur != OK:
		# Le transport refuse d'emblée (un code qu'il ne sait pas lire, un pair qu'il ne peut créer) : rien
		# n'est ouvert, le code est à reprendre.
		_afficher_message("ENLIGNE_REJOINDRE_IMPOSSIBLE", [erreur], true)
		champ_code.grab_focus()
		return
	_changer_etat(Etat.CONNEXION)
	_afficher_message("RESEAU_CONNEXION", [champ_code.text], false)


## Hors de l'accueil : annule (quitte le réseau, revient à l'accueil). À l'accueil : retour au titre (qui
## quitte aussi le réseau). `changer_scene` à faux pour les tests.
func retour(changer_scene := true) -> void:
	Reseau.quitter()
	if etat != Etat.ACCUEIL:
		_changer_etat(Etat.ACCUEIL)
		_afficher_message("", [], false)
		return
	_appliquer_pseudo()
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_TITRE)


## Le message de l'échec de connexion `raison` (`Reseau.raison_echec`, Transport.ECHEC_*, spec §9) ;
## ECHEC_PAR_DEFAUT sans raison ou pour une raison inconnue.
static func cle_echec(raison: String) -> String:
	return MESSAGES_ECHEC.get(raison, ECHEC_PAR_DEFAUT)


## Le code saisi, tel que `Reseau.rejoindre_partie` l'attend (un code de salle normalisé, celui d'un lien
## d'invitation collé entier compris, ou l'adresse `ip:port` de l'hôte ENet sous sa forme normale) ; vide
## s'il est mal formé, son message affiché.
func _lire_code() -> String:
	if codes_de_salle:
		var erreur := CodeSalle.erreur(champ_code.text)
		if not erreur.is_empty():
			_afficher_message(erreur, [], true)
			return ""
		return CodeSalle.lire_saisie(champ_code.text)
	var cible := TransportENet.lire_code(champ_code.text)
	if cible.is_empty():
		_afficher_message("ENLIGNE_ADRESSE_INVALIDE", [], true)
		return ""
	return "%s:%d" % [cible.ip, cible.port]


## Entrée dans le champ du pseudo : Rejoindre si un code attend (celui d'un lien), sinon Créer une partie
## prend le focus.
func _sur_pseudo_valide(_texte: String) -> void:
	if champ_code.text.strip_edges().is_empty():
		_donner_focus([bouton_creer, champ_code])
	else:
		rejoindre()


## Le pseudo saisi, nettoyé comme l'hôte le nettoiera, devient celui de ce poste et est mémorisé.
func _appliquer_pseudo() -> void:
	var pseudo := Reseau.pseudo_valide(champ_pseudo.text)
	champ_pseudo.text = pseudo
	Reseau.pseudo = pseudo
	Scores.definir_preference("pseudo", pseudo)


func _changer_etat(nouvel_etat: Etat) -> void:
	etat = nouvel_etat
	var accueil := etat == Etat.ACCUEIL
	champ_pseudo.editable = accueil
	champ_code.editable = accueil
	bouton_creer.disabled = not accueil
	bouton_rejoindre.disabled = not accueil
	if accueil:
		_donner_focus([bouton_creer, bouton_rejoindre])
	else:
		bouton_retour.grab_focus()


## Le focus au premier contrôle visible de `candidats` (sur un mobile, Créer une partie n'existe pas).
func _donner_focus(candidats: Array[Control]) -> void:
	for controle in candidats:
		if controle.is_visible_in_tree():
			controle.grab_focus()
			return


## Sur un mobile : ni Créer une partie ni « ou rejoins… » ; les champs, Rejoindre et Retour à la hauteur
## d'une cible au doigt, les textes agrandis (le champ du pseudo tient toujours 12 caractères larges).
func _mettre_en_page_mobile() -> void:
	bouton_creer.visible = false
	etiquette_ou.visible = false
	Parametres.agrandir(champ_pseudo, 56)
	Parametres.agrandir(champ_code, 56)
	Parametres.agrandir(bouton_rejoindre, 52)
	Parametres.agrandir(bouton_retour, 40)
	champ_pseudo.custom_minimum_size.x = 760
	bouton_rejoindre.custom_minimum_size.x = 340
	bouton_rejoindre.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	for etiquette: Label in [$Centre/Colonne/RangeePseudo/Etiquette, $Centre/Colonne/RangeeCode/Etiquette, message]:
		etiquette.add_theme_font_size_override("font_size", 44)


## Le champ `champ` entre en édition (`actif`) ou en sort : sur un mobile, sa rangée remonte à
## MARGE_CLAVIER px du haut de l'écran (le titre et ce qui la précède sortent par le haut), puis tout
## redescend.
func _sur_edition(actif: bool, champ: LineEdit) -> void:
	if not Parametres.mobile:
		return
	centre.position.y = 0.0
	if actif:
		centre.position.y = minf(0.0, MARGE_CLAVIER - champ.get_parent().get_global_rect().position.y)


func _afficher_message(cle: String, arguments: Array, erreur: bool) -> void:
	_message = {"cle": cle, "arguments": arguments, "erreur": erreur}
	_rendre_message()


func _rendre_message() -> void:
	var cle: String = _message.cle
	var arguments: Array = _message.arguments
	message.text = "" if cle.is_empty() else (tr(cle) % arguments if not arguments.is_empty() else tr(cle))
	message.add_theme_color_override("font_color", COULEUR_ERREUR if _message.erreur else COULEUR_INFO)
	message.add_theme_color_override("font_outline_color", COULEUR_CONTOUR_ERREUR if _message.erreur else COULEUR_CONTOUR_INFO)


## Après un refus ou un échec (déjà revenu à l'accueil, Créer une partie au focus) : le focus au code si
## la tentative venait de Rejoindre.
func _reprendre_focus_echec() -> void:
	if _par_le_code:
		champ_code.grab_focus()


## La partie en création a son code (le `pret` du transport, qui émet `salon_change`) : le salon.
func _sur_salon_change() -> void:
	if etat == Etat.CREATION and not Reseau.code_partie.is_empty():
		_ouvrir_salon()


func _sur_inscription(_index: int, _couleur: Color) -> void:
	if etat == Etat.CONNEXION:
		# La tentative a réussi : un « hôte perdu » bien plus tard rend le focus à Créer, comme d'habitude.
		_par_le_code = false
		_ouvrir_salon()


## Une partie créée ou rejointe continue au salon ; tout est grisé d'ici au changement de scène (un second
## Créer dans la même image ne relance rien).
func _ouvrir_salon() -> void:
	_changer_etat(Etat.SALON)
	get_tree().change_scene_to_file(SCENE_SALON)


## `Reseau` a déjà remis ce poste hors réseau quand ses signaux d'échec partent.
func _sur_refus(raison: String, version_hote: String) -> void:
	var connues := [Reseau.REFUS_VERSION, Reseau.REFUS_PLEIN, Reseau.REFUS_MANCHE, Reseau.REFUS_DEMANDE]
	var cle := raison if connues.has(raison) else Reseau.REFUS_DEMANDE
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message(cle, [version_hote] if cle == Reseau.REFUS_VERSION else [], true)


## Le message de l'échec (`cle_echec`) ; pendant une création (CREATION), une raison vide ou inconnue est
## la signalisation qui n'a pas abouti (ENLIGNE_SERVICE_INDISPONIBLE), pas un hôte : il n'y en a pas.
func _sur_connexion_echouee() -> void:
	var cle := cle_echec(Reseau.raison_echec)
	if etat == Etat.CREATION and not MESSAGES_ECHEC.has(Reseau.raison_echec):
		cle = "ENLIGNE_SERVICE_INDISPONIBLE"
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message(cle, [], true)


func _sur_hote_perdu() -> void:
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message(Reseau.raison_perte, [], true)


func _sur_langue_changee(_langue: String) -> void:
	_rendre_message()
