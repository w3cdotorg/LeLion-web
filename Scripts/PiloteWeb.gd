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
## - `["peindre", sens]` : en manche, le lion de ce poste descend vers la ville, puis la peint en allant
##   dans le sens `sens` (1 : à droite, -1 : à gauche) TICKS_PASSE ticks physiques (la passe du test
##   réseau, comptée en temps de jeu) ;
## - `["quitter"]` : retour au titre (qui quitte le réseau : l'adieu, spec §5).
## État : `window.lelionPilote.etat`, un texte JSON réécrit à chaque image (`etat()`), que la page relit.
##
## Autoload : les tests `--script` ne le nomment pas.

const SCENE_TITRE := "res://Scenes/Titre.tscn"
## La hauteur de peinture, au-dessus des toits (celle du pilote de la démo), en px ; la durée d'une passe,
## en ticks physiques (2,5 s de jeu). Comptée en temps de jeu, jamais à l'horloge murale : une page lente
## (la CI sous Chromium, en rendu logiciel, tourne à 0,4× le temps réel ou moins) joue au ralenti, et
## une passe minutée en millisecondes s'y arrêtait avant que le lion n'atteigne la ville.
const HAUTEUR_PEINTURE := 233.0
const TICKS_PASSE := 150

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
	while not _commandes.is_empty() and _executer(_commandes[0]):
		_commandes.pop_front()
	var scene := get_tree().current_scene
	if _empreinte.is_empty() and scene != null and scene.name == "Main" and scene.get_node("Manche").finie:
		_empreinte = empreinte_manche(scene)
		_scores = Array(scene.get_node("Ville").territoire.scores())
		print("EMPREINTE %s" % _empreinte)  # lue dans la console par le test de bout en bout
	JavaScriptBridge.eval("window.lelionPilote.etat = %s;" % JSON.stringify(JSON.stringify(etat())), true)


## L'état de ce poste, pour la page : l'écran, le réseau, l'écran En ligne, le salon, la manche.
func etat() -> Dictionary:
	var scene := get_tree().current_scene
	var nom := "" if scene == null else str(scene.name)
	var e := {"scene": nom, "en_ligne": Reseau.en_ligne(), "hote": Reseau.en_ligne() and multiplayer.is_server(),
		"code": Reseau.code_partie, "pertes": _pertes, "echecs": _echecs, "empreinte": _empreinte, "scores": _scores,
		"fps": Engine.get_frames_per_second(), "passe": _passe}
	if nom == "EcranEnLigne":
		e["ecran"] = {"etat": scene.etat, "code": scene.champ_code.text, "message": scene.message.text}
	elif nom == "Salon":
		var table: Array = Reseau.table_salon.map(func(f: Dictionary) -> Dictionary: return {"pseudo": f.pseudo, "pret": f.pret})
		var bouton: Button = scene.bouton_copier
		var centre := get_viewport().get_screen_transform() * bouton.get_global_rect().get_center()
		var echelle := float(JavaScriptBridge.eval("window.devicePixelRatio", true))
		e["salon"] = {"table": table, "attente": Reseau.raison_attente(Reseau.fiches_attente()),
			"invitation": scene.etiquette_code.text, "copier": bouton.text,
			"bouton_copier": [centre.x / echelle, centre.y / echelle] if bouton.is_visible_in_tree() else []}
	elif nom == "Main":
		var manche: Node = scene.get_node("Manche")
		e["manche"] = {"barriere": manche.barriere, "en_cours": GameState.pret and GameState.partie_en_cours, "finie": manche.finie}
	return e


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


## Exécute la commande `commande` (`[nom, arguments…]`) ; faux si elle ne le peut pas encore.
func _executer(commande: Variant) -> bool:
	if not (commande is Array) or commande.is_empty():
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
		_:
			push_warning("PiloteWeb : commande inconnue %s" % [commande])
	return true


## La passe du lion de ce poste dans la scène de jeu `main` (comme celle du test réseau), en ticks
## physiques : il descend à HAUTEUR_PEINTURE au-dessus des toits (la position du lion d'un client est
## celle que l'hôte lui renvoie), aussi longtemps qu'il le faut, puis peint la ville en allant dans le
## sens `sens` TICKS_PASSE ticks, touches pressées comme un joueur ; la fin de la manche arrête l'une
## ou l'autre. Aucun plafond en millisecondes.
func _peindre(main: Node, sens: int) -> void:
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - HAUTEUR_PEINTURE
	_passe = {"descente": 0}
	Input.action_press("deplacer_bas")
	while _en_manche(main) and main.lion.position.y < cible:
		await get_tree().physics_frame
		_passe["descente"] += 1
	Input.action_release("deplacer_bas")
	_passe["peinture"] = 0
	var action := "deplacer_droite" if sens > 0 else "deplacer_gauche"
	Input.action_press(action)
	Input.action_press("vomir")
	while _en_manche(main) and _passe["peinture"] < TICKS_PASSE:
		await get_tree().physics_frame
		_passe["peinture"] += 1
	Input.action_release(action)
	Input.action_release("vomir")


## Vrai tant que la manche de la scène de jeu `main` se joue sur ce poste, son lion là.
func _en_manche(main: Node) -> bool:
	return is_instance_valid(main) and main.lion != null and GameState.partie_en_cours \
		and not main.get_node("Manche").finie
