class_name CodeSalle
extends RefCounted
## Le code d'une salle de la signalisation (spec §2, §4.4 du jeu en ligne) : 6 caractères d'un alphabet
## sans 0/O ni 1/I/L, affiché « K7Q-2XM », et le lien d'invitation qui le porte (`?salle=K7Q2XM`).
## Logique pure, sans autoload : la saisie d'un joueur se lit sans casse, sans espaces ni tirets, ceux
## qu'un copier-coller apporte compris (espace insécable, tirets typographiques, saut de ligne ; le
## Worker refuse le tiret : le jeu l'enlève) ; un caractère qu'on confond (0, O, 1, I, L) est refusé
## avec son propre message plutôt que remplacé en silence (un O lu comme un 0 mènerait chez un autre).

## Les 31 caractères d'un code : ceux du Worker (`signalisation/src/code.js`, ALPHABET).
const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const LONGUEUR := 6
## Les caractères qu'on prend pour d'autres, absents de l'alphabet.
const CONFUSIONS := "01ILO"
## Ce que la saisie ignore : espaces et tirets (« K7Q-2XM », « k7q 2xm »), et ce qu'un copier-coller
## depuis un message ou un traitement de texte y met : saut de ligne (LF, CR), espace insécable (U+00A0)
## et fine insécable (U+202F), trait d'union (U+2010) et trait d'union insécable (U+2011), tiret
## numérique (U+2012), demi-cadratin (U+2013), cadratin (U+2014), signe moins (U+2212). « _ » et « . »
## restent refusés : ce ne sont pas des tirets.
const SEPARATEURS := " \t-" + char(0x0A) + char(0x0D) + char(0xA0) + char(0x202F) + char(0x2010) + char(0x2011) \
	+ char(0x2012) + char(0x2013) + char(0x2014) + char(0x2212)
## Le paramètre de l'adresse de la page qui porte le code (`?salle=K7Q2XM`).
const PARAMETRE := "salle"
## L'adresse de la page du jeu en ligne (spec §2), si le réglage `lelion/page/url` manque.
const URL_PAGE := "https://w3cdotorg.github.io/LeLion-web/"
## Pourquoi une saisie n'est pas un code (`erreur`), en clés de traduction (spec §9).
const ERREUR_FORMAT := "ENLIGNE_CODE_FORMAT"
const ERREUR_CONFUSION := "ENLIGNE_CODE_CONFUSION"

## Si non vide, tient lieu de `location.search` (les tests, hors du Web).
static var recherche_forcee := ""
## Vrai une fois le lien de la page lu (`prendre_code_de_la_page`) : il ne sert qu'une fois par lancement.
static var _page_lue := false


## `texte` sans ses SEPARATEURS (espaces, tirets, sauts de ligne), ses lettres ASCII en majuscules ;
## rien d'autre ne change (un autre caractère hors ASCII reste tel quel, et le code est alors refusé :
## aucune lettre accentuée, ni « ſ », ni le signe Kelvin n'y devient une lettre de l'alphabet).
static func normaliser(texte: String) -> String:
	var sortie := ""
	for c in texte:
		if SEPARATEURS.contains(c):
			continue
		sortie += c.to_upper() if c >= "a" and c <= "z" else c
	return sortie


## Vrai si `code`, déjà normalisé, est un code de salle : LONGUEUR caractères de l'ALPHABET.
static func valide(code: String) -> bool:
	if code.length() != LONGUEUR:
		return false
	for c in code:
		if not ALPHABET.contains(c):
			return false
	return true


## Le code que porte la saisie `texte` d'un joueur, à valider (`valide`) : un lien d'invitation collé
## entier (« https://…/?salle=K7Q2XM », tout texte qui a un « ? ») donne le code de son `?salle=` (après
## le « ? », coupé au « # » : `lire_recherche`), vide s'il n'en porte pas de valide ; un code tapé est
## normalisé (`normaliser`), valide ou non.
static func lire_saisie(texte: String) -> String:
	var debut := texte.find("?")
	if debut < 0:
		return normaliser(texte)
	return lire_recherche(texte.substr(debut + 1).get_slice("#", 0))


## Pourquoi la saisie `texte` (`lire_saisie` : un code ou un lien collé) n'est pas un code :
## ERREUR_CONFUSION si un code tapé a un 0, un O, un 1, un I ou un L (en minuscules aussi), ERREUR_FORMAT
## pour tout le reste, un lien sans code valide compris (ses lettres ne sont pas un code) ; vide si c'en
## est un.
static func erreur(texte: String) -> String:
	var code := lire_saisie(texte)
	if valide(code):
		return ""
	for c in code:
		if CONFUSIONS.contains(c):
			return ERREUR_CONFUSION
	return ERREUR_FORMAT


## Le code tel qu'il s'affiche, « K7Q-2XM » ; un texte qui n'est pas un code reste tel quel (l'adresse
## `ip:port` d'un hôte ENet, sur le desktop de développement).
static func formater(code: String) -> String:
	return "%s-%s" % [code.substr(0, 3), code.substr(3)] if valide(code) else code


## Le lien d'invitation à la salle `code` : l'adresse de la page (`url_page`), puis `?salle=<code>`.
static func lien(code: String) -> String:
	return "%s?%s=%s" % [url_page(), PARAMETRE, code]


## L'adresse de la page du jeu : sur le Web, celle de la page ouverte (son origine et son chemin, sans ses
## paramètres : un lien copié d'une préversion ou d'un test local y ramène) ; ailleurs, le réglage
## `lelion/page/url` (URL_PAGE par défaut).
static func url_page() -> String:
	if OS.has_feature("web"):
		var page: Variant = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
		if page is String and not (page as String).is_empty():
			return page
	return str(ProjectSettings.get_setting("lelion/page/url", URL_PAGE))


## Le code que porte la partie recherche d'une adresse (`location.search` : « ?salle=K7Q2XM&… ») : le
## premier paramètre `salle`, décodé et normalisé, s'il est un code ; vide sinon.
static func lire_recherche(recherche: String) -> String:
	for paire in recherche.trim_prefix("?").split("&", false):
		var morceaux := paire.split("=", true, 1)
		if morceaux[0] == PARAMETRE and morceaux.size() == 2:
			var code := normaliser(morceaux[1].uri_decode())
			return code if valide(code) else ""
	return ""


## Le code du lien qui a ouvert la page (`?salle=`, spec §4.4), une seule fois par lancement : le premier
## écran titre emmène le joueur à l'écran En ligne ; vide ensuite, hors du Web, ou sans code valide.
static func prendre_code_de_la_page() -> String:
	if _page_lue:
		return ""
	_page_lue = true
	var recherche := recherche_forcee
	if recherche.is_empty() and OS.has_feature("web"):
		recherche = str(JavaScriptBridge.eval("window.location.search", true))
	return lire_recherche(recherche)
