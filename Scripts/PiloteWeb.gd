extends Node
## Le pilote du test de bout en bout (`tests/web/`, spec §10 du jeu en ligne) : seulement dans l'export
## « Web pilote » (la fonctionnalité `pilote` de son préréglage d'export, jamais dans l'export livré), il
## expose l'état du jeu à la page et y prend des commandes, pour que Playwright mène trois pages par les
## vrais écrans (En ligne, salon, manche) sans viser des pixels dans le canevas. Inerte partout ailleurs :
## l'export livré, le desktop, les tests headless.
##
## Commandes : la page pousse `[nom, arguments…]` dans `window.lelionPilote.commandes` ; à chaque image,
## ce nœud les prend dans l'ordre. Une commande qui ne peut pas encore s'exécuter (pas le bon écran, un
## salon pas prêt) reste en tête et se retente à l'image suivante :
## - `["duree", secondes]` : la durée des manches de ce poste (`ReglesBataille.duree_manche`) ;
## - `["creer", pseudo]` : depuis le titre ou l'écran En ligne, Créer une partie ;
## - `["rejoindre", pseudo, code]` : sur l'écran En ligne, Rejoindre ; sans `code`, celui que le lien
##   `?salle=` a rempli ;
## - `["pret"]` : au salon, ce poste se dit prêt ;
## - `["demarrer"]` : au salon, l'hôte démarre dès que le salon est prêt ;
## - `["peindre", sens]` : en manche, le lion de ce poste descend vers la ville, puis la peint TICKS_PASSE
##   ticks physiques (comptés en temps de jeu), un aller dans le sens `sens` (1 : à droite, -1 : à gauche)
##   puis le retour ;
## - `["quitter"]` : retour au titre (qui quitte le réseau : l'adieu, spec §5).
## Une commande mal formée (nom inconnu, nombre ou types d'arguments, `erreur_commande`) est rejetée
## (`push_warning`) et retirée de la file, sans bloquer celles qui la suivent.
## État : `window.lelionPilote.etat`, un texte JSON réécrit à chaque image (`etat()`), que la page relit.
## Pour un client mobile (phase 6), qui joue au doigt (de vrais touchers de la page, jamais des commandes),
## l'état donne aussi, en px CSS de la page, ce qu'un toucher vise : Rejoindre, les boutons tactiles du
## salon et de la manche, le stick ; et la hauteur où peindre.
##
## Autoload : les tests `--script` ne le nomment pas.

const SCENE_TITRE := "res://Scenes/Titre.tscn"
## La hauteur de peinture, au-dessus des toits (celle du pilote de la démo), en px ; la durée d'une passe,
## en ticks physiques (2,5 s de jeu), et celle de son aller (la moitié). Comptée en temps de jeu, jamais à l'horloge murale : une page lente
## (la CI sous Chromium, en rendu logiciel, tourne à 0,4× le temps réel ou moins) joue au ralenti, et
## une passe minutée en millisecondes s'y arrêtait avant que le lion n'atteigne la ville.
const HAUTEUR_PEINTURE := 233.0
const TICKS_PASSE := 150
const TICKS_ALLER := 75
## Les arguments de chaque commande, leurs types dans l'ordre (les nombres arrivent du JSON en flottants),
## et combien sont facultatifs à la fin (le code de `rejoindre`).
const ARGUMENTS := {"duree": [TYPE_FLOAT], "creer": [TYPE_STRING], "rejoindre": [TYPE_STRING, TYPE_STRING],
	"pret": [], "demarrer": [], "peindre": [TYPE_FLOAT], "quitter": []}
const FACULTATIFS := {"rejoindre": 1}

## Vrai dans l'export « Web pilote » seulement.
var actif := OS.has_feature("web") and OS.has_feature("pilote")
## Les commandes reçues pas encore exécutées, dans l'ordre.
var _commandes: Array = []
## Les messages de perte de l'hôte (`Reseau.hote_perdu`, traduits) et d'échec de connexion vus ici.
var _pertes: Array[String] = []
var _echecs: Array[String] = []
## Vrai une fois l'écran En ligne demandé depuis le titre, jusqu'à ce que le titre parte (un seul
## changement de scène : un second ouvrirait un écran En ligne sans le code du lien).
var _vers_en_ligne := false
## L'empreinte de la dernière manche finie sur ce poste (`empreinte_manche`) et ses scores, vides avant.
var _empreinte := ""
var _scores: Array = []
## La passe de ce poste (`_peindre`), pour la page et ses messages d'échec : ticks physiques de la
## descente, puis de la peinture, comptés pendant qu'elle se fait ; vide avant.
var _passe := {}


func _ready() -> void:
	if not actif:
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS  # la fin de manche fige l'arbre : le pilote la lit encore
	Reseau.hote_perdu.connect(func() -> void: _pertes.append(tr(Reseau.raison_perte)))
	Reseau.connexion_echouee.connect(func() -> void: _echecs.append(Reseau.raison_echec))
	JavaScriptBridge.eval("window.lelionPilote = {commandes: [], etat: '{}'};", true)
	print("PILOTE PRET")


func _process(_delta: float) -> void:
	var recues: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.lelionPilote.commandes.splice(0))", true)))
	if recues is Array:
		_commandes.append_array(recues)
	_vider_commandes()
	var scene := get_tree().current_scene
	if _empreinte.is_empty() and scene != null and scene.name == "Main" and scene.get_node("Manche").finie:
		_empreinte = empreinte_manche(scene)
		_scores = Array(scene.get_node("Ville").territoire.scores())
		print("EMPREINTE %s" % _empreinte)  # lue dans la console par le test de bout en bout
	JavaScriptBridge.eval("window.lelionPilote.etat = %s;" % JSON.stringify(JSON.stringify(etat())), true)


## Exécute les commandes en attente, dans l'ordre, jusqu'à la première qui ne le peut pas encore.
func _vider_commandes() -> void:
	while not _commandes.is_empty() and _executer(_commandes[0]):
		_commandes.pop_front()


## L'état de ce poste, pour la page : l'écran, le réseau, l'écran En ligne, le salon, la manche.
func etat() -> Dictionary:
	var scene := get_tree().current_scene
	var nom := "" if scene == null else str(scene.name)
	var e := {"scene": nom, "en_ligne": Reseau.en_ligne(), "hote": Reseau.en_ligne() and multiplayer.is_server(),
		"code": Reseau.code_partie, "pertes": _pertes, "echecs": _echecs, "empreinte": _empreinte, "scores": _scores,
		"fps": Engine.get_frames_per_second(), "passe": _passe, "mobile": Parametres.mobile, "voile": Parametres.voile.visible,
		"images": Engine.get_process_frames()}
	if nom == "EcranEnLigne":
		var rejoindre: Rect2 = scene.bouton_rejoindre.get_global_rect()
		e["ecran"] = {"etat": scene.etat, "code": scene.champ_code.text, "message": scene.message.text,
			"creer": scene.bouton_creer.visible, "rejoindre": _css(rejoindre.position) + _css(rejoindre.end)}
	elif nom == "Salon":
		var table: Array = Reseau.table_salon.map(func(f: Dictionary) -> Dictionary:
			return {"pseudo": f.pseudo, "pret": f.pret, "couleur": f.couleur.to_html(false)})
		var bouton: Button = scene.bouton_copier
		var tactile: CanvasLayer = scene.controles_tactiles
		e["salon"] = {"table": table, "attente": Reseau.raison_attente(Reseau.fiches_attente()),
			"invitation": scene.etiquette_code.text, "copier": bouton.text,
			"bouton_copier": _css(bouton.get_global_rect().get_center()) if bouton.is_visible_in_tree() else [],
			"tactile": {"visible": tactile.visible, "gauche": _css_bouton(tactile.bouton_gauche), "droite": _css_bouton(tactile.bouton_droite),
				"pret": _css_bouton(tactile.bouton_vomir)}}
	elif nom == "Main":
		var manche: Node = scene.get_node("Manche")
		var tactile: CanvasLayer = scene.get_node("ControlesTactiles")
		var stick: Control = tactile.joystick
		e["manche"] = {"barriere": manche.barriere, "en_cours": GameState.pret and GameState.partie_en_cours, "finie": manche.finie,
			"temps": GameState.temps_ecoule, "lion": [] if scene.lion == null else [scene.lion.position.x, scene.lion.position.y],
			"cible": _hauteur_peinture(scene),
			"tactile": {"visible": tactile.visible, "vomir": _css_bouton(tactile.bouton_vomir),
				"stick": _css(Vector2(stick.rayon * 3.0, stick.get_viewport_rect().size.y - stick.rayon * 3.0)),
				"rayon": _css(Vector2(stick.rayon, 0))[0] - _css(Vector2.ZERO)[0]}}
	return e


## Le point `point` de l'écran du jeu, en px CSS de la page (ce que vise un clic ou un toucher de la page).
func _css(point: Vector2) -> Array:
	var ecran := get_viewport().get_screen_transform() * point
	var echelle := float(JavaScriptBridge.eval("window.devicePixelRatio", true))
	return [ecran.x / echelle, ecran.y / echelle]


## Le centre d'un bouton tactile en px CSS de la page, et son côté : `[x, y, côté]`.
func _css_bouton(bouton: TouchScreenButton) -> Array:
	var cote := bouton.texture_normal.get_size() * bouton.scale
	var coin := _css(bouton.position)
	return _css(bouton.position + cote / 2.0) + [_css(bouton.position + cote)[0] - coin[0]]


## L'ordonnée où peindre dans la scène de jeu `main` : HAUTEUR_PEINTURE au-dessus des toits.
static func _hauteur_peinture(main: Node) -> float:
	var ville: Node2D = main.get_node("Ville")
	return ville.position.y - ville.tex_size.y / 2.0 - HAUTEUR_PEINTURE


## L'empreinte de la manche finie de la scène de jeu `main` (la même sur chaque poste qui a tout reçu) :
## territoire (propriétaire compté de chaque cellule), scores, tampons (diffusés par l'hôte, reçus par un
## client, et l'empreinte de leur suite), joueurs de la manche.
static func empreinte_manche(main: Node) -> String:
	var territoire: Territoire = main.get_node("Ville").territoire
	var manche: Node = main.get_node("Manche")
	var proprietaires := PackedByteArray()
	proprietaires.resize(territoire.taille_grille.x * territoire.taille_grille.y)
	for i in range(proprietaires.size()):
		proprietaires[i] = territoire.proprietaire_compte(i) + 1
	var hote: bool = main.multiplayer.is_server()
	var joueurs: Array = GameState.joueurs.map(func(j: Joueur) -> String: return "%d:%s:%s" % [j.id_reseau, j.pseudo, j.couleur.to_html(false)])
	return "territoire=%d scores=%s tampons=%d:%d joueurs=%s" % [hash(proprietaires), territoire.scores(),
		manche.tampons_diffuses if hote else manche.tampons_recus, manche.empreinte_tampons, ";".join(joueurs)]


## La fiche de ce poste dans la table du salon (vide tant que la table ne l'a pas).
func _ma_fiche() -> Dictionary:
	for fiche in Reseau.table_salon:
		if fiche.id == multiplayer.get_unique_id():
			return fiche
	return {}


## Pourquoi `commande` n'est pas une commande du pilote (`[nom, arguments…]`, ARGUMENTS) : vide si elle
## en est une. `duree` est un nombre de secondes positif, `peindre` un sens, 1 ou -1.
static func erreur_commande(commande: Variant) -> String:
	if not (commande is Array) or commande.is_empty() or not (commande[0] is String):
		return "pas une liste [nom, arguments…]"
	if not ARGUMENTS.has(commande[0]):
		return "commande inconnue"
	var types: Array = ARGUMENTS[commande[0]]
	var nb: int = commande.size() - 1
	if nb > types.size() or nb < types.size() - int(FACULTATIFS.get(commande[0], 0)):
		return "%d argument(s) au lieu de %d" % [nb, types.size()]
	for i in range(nb):
		if typeof(commande[i + 1]) != types[i]:
			return "argument %d de type %s" % [i + 1, type_string(typeof(commande[i + 1]))]
	if commande[0] == "duree" and not (commande[1] > 0.0):
		return "durée non positive"
	if commande[0] == "peindre" and absf(commande[1]) != 1.0:
		return "sens ni 1 ni -1"
	return ""


## Exécute la commande `commande` (`[nom, arguments…]`) ; faux si elle ne le peut pas encore. Mal formée,
## elle est rejetée (un avertissement), donc retirée de la file.
func _executer(commande: Variant) -> bool:
	var erreur := erreur_commande(commande)
	if not erreur.is_empty():
		push_warning("PiloteWeb : commande rejetée %s (%s)" % [commande, erreur])
		return true
	var scene := get_tree().current_scene
	var nom := "" if scene == null else str(scene.name)
	if nom != "Titre":
		_vers_en_ligne = false
	match str(commande[0]):
		"duree":
			ReglesBataille.duree_manche = float(commande[1])
		"creer", "rejoindre":
			if nom == "Titre":
				if not _vers_en_ligne:
					_vers_en_ligne = true
					scene.ouvrir_en_ligne()
				return false
			if nom != "EcranEnLigne" or scene.etat != scene.Etat.ACCUEIL:
				return false
			scene.champ_pseudo.text = str(commande[1])
			if commande.size() > 2:
				scene.champ_code.text = str(commande[2])
			if commande[0] == "creer":
				scene.creer_partie()
			else:
				scene.rejoindre()
		"pret":
			var fiche := _ma_fiche()
			if nom != "Salon" or fiche.is_empty():
				return false
			if not fiche.pret:
				scene.basculer_pret()
		"demarrer":
			if nom != "Salon" or not Reseau.raison_attente(Reseau.fiches_attente()).is_empty():
				return false
			scene.demarrer()
		"peindre":
			if nom != "Main" or not GameState.pret or scene.lion == null:
				return false
			_peindre(scene, int(commande[1]))
		"quitter":
			get_tree().change_scene_to_file(SCENE_TITRE)
	return true


## La passe du lion de ce poste dans la scène de jeu `main`, en ticks physiques : il descend à
## HAUTEUR_PEINTURE au-dessus des toits (la position du lion d'un client est celle que l'hôte lui
## renvoie), aussi longtemps qu'il le faut, puis peint la ville TICKS_PASSE ticks à cette hauteur,
## touches pressées comme un joueur : la moitié en allant dans le sens `sens`, l'autre en revenant ; la
## fin de la manche arrête l'une ou l'autre. Aucun plafond en millisecondes. L'aller-retour garde chaque
## lion près de son départ : des lions qui partent dans le même sens ne se rattrapent pas, et celui qu'un
## bord arrête (sa gerbe, qui tombe devant lui, y sort de la ville) peint au retour.
func _peindre(main: Node, sens: int) -> void:
	var cible := _hauteur_peinture(main)
	_passe = {"descente": 0}
	Input.action_press("deplacer_bas")
	while _en_manche(main) and main.lion.position.y < cible:
		await get_tree().physics_frame
		_passe["descente"] += 1
	Input.action_release("deplacer_bas")
	_passe["peinture"] = 0
	var aller := "deplacer_droite" if sens > 0 else "deplacer_gauche"
	var retour := "deplacer_gauche" if sens > 0 else "deplacer_droite"
	Input.action_press("vomir")
	for etape: Array in [[aller, TICKS_ALLER], [retour, TICKS_PASSE]]:  # l'action, et le tick où elle finit
		Input.action_press(etape[0])
		while _en_manche(main) and _passe["peinture"] < etape[1]:
			# La hauteur se tient pendant la passe : chez un client, la prédiction atteint la hauteur avant
			# que l'hôte ne l'y mette (une page lente : l'hôte saute des commandes), puis l'hôte le recale
			# plus haut, d'où sa gerbe tomberait au-dessus des toits.
			if main.lion.position.y < cible:
				Input.action_press("deplacer_bas")
			else:
				Input.action_release("deplacer_bas")
			await get_tree().physics_frame
			_passe["peinture"] += 1
		Input.action_release(etape[0])
	Input.action_release("deplacer_bas")
	Input.action_release("vomir")


## Vrai tant que la manche de la scène de jeu `main` se joue sur ce poste, son lion là.
func _en_manche(main: Node) -> bool:
	return is_instance_valid(main) and main.lion != null and GameState.partie_en_cours \
		and not main.get_node("Manche").finie
