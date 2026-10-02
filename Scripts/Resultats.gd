extends CanvasLayer
## L'écran Résultats d'une bataille (phase 18, spec §8), posé par la scène de jeu sur la ville figée, à
## la place du HUD de la bataille, sur chaque poste : le même, tiré du seul bilan de l'hôte
## (`BilanManche`) et de la table des joueurs. En haut, « FIN DE LA MANCHE ! » et le gagnant (ou les ex
## æquo) ; puis le classement, une ligne par joueur (le plus de cellules d'abord) : son rang, son lion
## teint (couronné pour chaque meneur), son pseudo, une barre à sa couleur de sa part des cellules
## peintes (le podium en barres, animé comme le bilan du solo, `GameOver`), ses statistiques
## (étourdissements infligés, cellules volées, chocs), « TOI » ou « PARTI » ; puis les trois titres (« Le plus
## vicieux », « Le voleur », « L'auto-tamponneur ») et les choix. L'hôte choisit pour tous : Revanche
## (le même niveau), Niveau suivant, Retour au salon (en réseau seulement) ; Revanche et Niveau suivant
## demandent au moins deux joueurs encore là. Un client voit « En attente de l'hôte… ». Chacun peut
## quitter (Quitter, Échap : le titre, qui quitte le réseau). Le choix part en signal (`choix_fait`) :
## c'est la scène de jeu qui le suit.
## Commandes : aucun bouton ne prend le focus (la souris les clique, ignorée pendant l'animation : voir
## M2 de la revue finale, `mouse_filter` dans `_animer`/`terminer_animation`) ; gauche et droite
## choisissent parmi les choix de l'hôte, vomir (ou Tab, Start) valide, Échap (ou B) quitte ; une action
## n'agit qu'à l'appui, jamais tenue depuis la manche (Espace tenu au gong ne choisit rien) ; pendant
## l'animation, seules gauche, droite et Échap la terminent (M1 de la revue finale : vomir, Tab/Start et
## la validation restent sans effet, pour ne pas relancer la manche d'un Espace martelé au gong) ; un
## choix au clavier n'est pris que DELAI_CHOIX après la fin de l'animation. Tourne l'arbre en pause (la
## manche finie le fige).
## Extra (décision utilisateur, 27/09) : le départ de l'hôte ramène tout le monde au titre (le réseau
## quitté, ou l'unique poste de la bataille locale) ; Échap ou le bouton Quitter lui demandent donc
## confirmation (« Quitter la partie pour tout le monde ? », Oui mis en évidence comme le choix
## sélectionné, P1 de la revue finale) avant d'agir. Un second Échap ou Oui confirment aussitôt ; vomir
## ou la touche de validation ne confirment qu'après DELAI_CHOIX depuis l'ouverture de la confirmation
## (`_depuis_confirmation`, M1 de la revue finale : sinon le même geste qui l'ouvre la validerait) et
## sont ignorés avant (ni confirmation ni annulation) ; toute autre touche ou bouton de manette, mappé
## ou non (M3 de la revue finale), ou Non, annulent. Un client, dont le départ ne retire que lui, n'a
## pas cette confirmation.
## Sur un mobile (`Parametres.mobile`, phase 6 du jeu en ligne) : les choix, Quitter, Oui et Non à la taille
## d'un doigt (`Parametres.agrandir`), sans les aides du clavier ; à 6 joueurs, tout tient dans l'écran.

signal choix_fait(choix: StringName)

const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
const _HUD := preload("res://Scripts/HUDBataille.gd")
const COULEUR_CONTOUR := Color(0.1, 0.05, 0.15, 1)
const COULEUR_NOM := Color(1, 1, 1, 0.7)
const OPACITE_PARTI := 0.45
## Largeur de la barre d'une part de 100 %, et sa hauteur ; largeur de la colonne des pseudos (12
## caractères larges, « WWWWWWWWWWWW », y tiennent : vérifié par tests/bataille_test.gd).
const TAILLE_BARRE := Vector2(480, 34)
const LARGEUR_PSEUDO := 360
## Le rythme du bilan du solo (`GameOver`) : une ligne toutes les DELAI_LIGNE s, sa barre et son
## compteur en DUREE_COMPTEUR s ; puis un titre toutes les DELAI_TITRE s. À 6 joueurs, moins de 3 s en
## tout.
const DELAI_LIGNE := 0.3
const DUREE_COMPTEUR := 0.45
const DELAI_TITRE := 0.2
## La police des boutons sur un mobile (30 px sur ordinateur).
const POLICE_TACTILE := 40
## Après l'animation, délai avant qu'un choix au clavier soit pris (secondes).
const DELAI_CHOIX := 1.0
## Les choix de l'hôte, dans l'ordre des boutons, puis Quitter (de chacun).
const CHOIX: Array[StringName] = [&"revanche", &"suivant", &"salon", &"quitter"]
const ACTIONS: Array[StringName] = [&"deplacer_gauche", &"deplacer_droite", &"vomir", &"demarrer", &"ui_accept", &"ui_cancel"]

## Le bilan affiché (`afficher`).
var bilan: BilanManche
## Vrai sur le poste qui choisit pour tous (l'hôte ; en bataille locale, ce poste).
var hote := true
## Le choix fait (`choisir`), vide avant : un seul part, jusqu'à `annuler_choix`.
var choix := &""
## Vrai en réseau : Retour au salon existe.
var en_reseau := false
## Par index de joueur : vrai une fois parti (dans le bilan, ou annoncé depuis : `marquer_parti`).
var partis: Array[bool] = []
## Une ligne par joueur, dans l'ordre du classement : {"index": int, "ligne": HBoxContainer, "rang": Label,
## "lion": TextureRect, "couronne": Control, "pseudo": Label, "barre": Panel, "part": Label,
## "stats": Array[Label] (étourdissements infligés, cellules volées, chocs : l'ordre des titres),
## "badge": Label, "cible": int (part en %)}.
var lignes: Array[Dictionary] = []
## Les trois titres, dans l'ordre de BilanManche.TITRES : {"cadre": PanelContainer, "nom": Label, "valeur": Label}.
var cartes_titres: Array[Dictionary] = []
## Le choix sélectionné au clavier (un de CHOIX).
var selection: StringName = &"revanche"
var animation_finie := false
## Vrai le temps que l'hôte confirme un départ (Échap ou le bouton Quitter, une première fois) :
## « Quitter la partie pour tout le monde ? », Oui/Non, avant d'émettre `choix_fait`. Un second Échap
## ou le bouton Oui valent Oui aussitôt ; vomir ou la touche de validation ne valent Oui qu'après
## DELAI_CHOIX (`_depuis_confirmation`, M1 de la revue finale) ; toute autre touche ou bouton de
## manette, ou le bouton Non, annulent, sans rien choisir d'autre.
var confirmation_quitter := false

@onready var titre: Label = $Centre/Colonne/Titre
@onready var gagnant: Label = $Centre/Colonne/Gagnant
@onready var tableau: VBoxContainer = $Centre/Colonne/Tableau
@onready var rangee_titres: HBoxContainer = $Centre/Colonne/Titres
@onready var boutons: HBoxContainer = $Centre/Colonne/Boutons
@onready var etat: Label = $Centre/Colonne/Etat
@onready var aide: Label = $Centre/Colonne/Aide
@onready var bouton_revanche: Button = $Centre/Colonne/Boutons/Revanche
@onready var bouton_suivant: Button = $Centre/Colonne/Boutons/Suivant
@onready var bouton_salon: Button = $Centre/Colonne/Boutons/Salon
@onready var bouton_quitter: Button = $Centre/Colonne/Boutons/Quitter
@onready var confirmation_quitter_conteneur: HBoxContainer = $Centre/Colonne/ConfirmationQuitter
@onready var bouton_oui: Button = $Centre/Colonne/ConfirmationQuitter/Oui
@onready var bouton_non: Button = $Centre/Colonne/ConfirmationQuitter/Non

var _tween: Tween
## Temps écoulé depuis la fin de l'animation (secondes) : DELAI_CHOIX avant un choix au clavier.
var _depuis_animation := 0.0
## Temps écoulé depuis l'ouverture de la confirmation de départ (secondes) : DELAI_CHOIX avant que
## vomir ou la touche de validation ne valent Oui (M1 de la revue finale phase 18) ; avant ce délai,
## ils sont ignorés, pour ne pas confirmer par le même geste qui vient d'ouvrir la confirmation.
var _depuis_confirmation := 0.0
## Actions tenues : une action n'agit qu'à l'appui (voir `_unhandled_input`), jamais tenue depuis la
## manche : l'état de chaque action est relevé à l'ouverture.
var _tenues: Dictionary[StringName, bool] = {}
var _style_selection := StyleBoxFlat.new()


func _ready() -> void:
	for action in ACTIONS:
		_tenues[action] = Input.is_action_pressed(action)
	_style_selection.bg_color = Color(0.32, 0.2, 0.28, 1.0)
	_style_selection.border_color = Styles.JAUNE
	_style_selection.set_border_width_all(4)
	_style_selection.set_corner_radius_all(6)
	_style_selection.set_content_margin_all(8)
	if Parametres.mobile:
		for b: Button in _boutons() + [bouton_oui, bouton_non]:
			Parametres.agrandir(b, POLICE_TACTILE)
		aide.hide()


## M9 de la revue finale : la fenêtre perd le focus (alt-tab...) avec une touche tenue, dont le
## relâchement (hors focus) n'arrive jamais ici ; sans ceci, la reprise du focus la croirait tenue
## depuis toujours et un premier appui réel n'agirait pas.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_tenues.clear()


## Montre le bilan `bilan_` : `hote_` vrai sur le poste qui choisit pour tous, `en_reseau_` vrai en
## réseau (Retour au salon).
func afficher(bilan_: BilanManche, hote_: bool, en_reseau_: bool) -> void:
	bilan = bilan_
	hote = hote_
	en_reseau = en_reseau_
	partis.assign(bilan.partis)
	var meneurs := PackedStringArray()
	for i in bilan.meneurs():
		meneurs.append(_nom(i))
	gagnant.text = texte_gagnant(meneurs)
	_creer_entete()
	var rangs := bilan.rangs()
	var parts := bilan.parts()
	for i in bilan.classement():
		lignes.append(_creer_ligne(i, rangs[i], parts[i]))
	for t in BilanManche.TITRES:
		cartes_titres.append(_creer_titre(t))
	bouton_salon.visible = hote and en_reseau
	bouton_revanche.visible = hote
	bouton_suivant.visible = hote
	var suivant: Dictionary = GameState.NIVEAUX[posmod(GameState.niveau_courant + 1, GameState.NIVEAUX.size())]
	bouton_suivant.text = tr("RESULTATS_SUIVANT") % tr(suivant.nom)
	selection = &"revanche" if hote else &"quitter"
	rafraichir()
	_animer()


func _process(delta: float) -> void:
	if animation_finie:
		_depuis_animation += delta
	if confirmation_quitter:
		_depuis_confirmation += delta


func _unhandled_input(event: InputEvent) -> void:
	for action in ACTIONS:
		if not event.is_action(action):
			continue
		var appuyee := event.is_action_pressed(action)
		var nouvel_appui: bool = appuyee and not _tenues.get(action, false)
		_tenues[action] = appuyee
		if nouvel_appui:
			get_viewport().set_input_as_handled()
			_agir(action)
		return
	# M3 de la revue finale : pendant la confirmation de départ, n'importe quelle autre touche du
	# clavier ou bouton de manette (mappé ou non à une action connue) l'annule, pas seulement
	# deplacer_gauche/droite. Un relâchement (`not event.is_pressed()`) n'annule rien : sinon le
	# relâchement de la touche qui a ouvert la confirmation l'annulerait aussitôt.
	if confirmation_quitter and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		annuler_confirmation_quitter()


## Un appui sur `action` (jamais tenue depuis l'ouverture). Pendant la confirmation de départ de
## l'hôte, seuls comptent : un second Échap (confirme aussitôt), vomir ou la validation (confirment
## seulement après DELAI_CHOIX depuis l'ouverture, sinon ignorés : M1 de la revue finale), ou toute
## autre touche mappée (annule, comme `_unhandled_input` pour les autres).
func _agir(action: StringName) -> void:
	if confirmation_quitter:
		if action == &"ui_cancel":
			choisir(&"quitter")
		elif action in [&"vomir", &"demarrer", &"ui_accept"]:
			if _depuis_confirmation >= DELAI_CHOIX:
				choisir(&"quitter")
			# sinon : ignoré, ni confirmation ni annulation (le geste qui vient d'ouvrir la
			# confirmation ne doit pas la valider tout seul)
		else:
			annuler_confirmation_quitter()
		return
	if action == &"ui_cancel":
		choisir(&"quitter")
		return
	if not animation_finie:
		# M1 de la revue finale : seules les flèches terminent l'animation ; vomir, Tab/Start et la
		# validation (Espace martelé au gong, par exemple) n'ont plus aucun effet pendant qu'elle tourne.
		if action in [&"deplacer_gauche", &"deplacer_droite"]:
			terminer_animation()
		return
	if not hote or _depuis_animation < DELAI_CHOIX:
		return
	match action:
		&"deplacer_gauche":
			_deplacer_selection(-1)
		&"deplacer_droite":
			_deplacer_selection(1)
		_:
			choisir(selection)


## Le choix `voulu` (un de CHOIX), au bouton ou au clavier : Quitter pour chacun ; les autres pour
## l'hôte seulement, s'ils sont possibles (`possible`). Part en `choix_fait`, une seule fois : les
## boutons se grisent jusqu'à `annuler_choix`. Le départ de l'hôte (`quitter`) ramènerait tout le
## monde au titre : une première fois, il ouvre la confirmation (`confirmation_quitter`) au lieu de
## partir tout de suite ; un client, dont le départ n'affecte que lui, part sans confirmation.
## Garde-fou (M2 de la revue finale) : les boutons sont invisibles (`modulate.a`) et leur `mouse_filter`
## ignoré tant que l'animation tourne (`_animer`), mais un appui direct (`.pressed.emit()`, un test par
## exemple) doit rester sans effet : seul Quitter (Échap ou son bouton) peut agir avant la fin, en la
## terminant lui-même.
func choisir(voulu: StringName) -> void:
	if bilan == null or not choix.is_empty() or not possible(voulu):
		return
	if not animation_finie and voulu != &"quitter":
		return
	if voulu == &"quitter" and hote and not confirmation_quitter:
		if not animation_finie:
			terminer_animation()  # la question ne s'ouvre pas sur des barres encore en train de monter
		confirmation_quitter = true
		_depuis_confirmation = 0.0
		rafraichir()
		return
	confirmation_quitter = false
	choix = voulu
	rafraichir()
	choix_fait.emit(voulu)


## Le choix fait n'a pas pu se suivre (l'hôte n'a plus assez de joueurs au moment même, par exemple) :
## on peut de nouveau choisir.
func annuler_choix() -> void:
	choix = &""
	rafraichir()


## La confirmation de départ de l'hôte annulée (Non, ou toute autre touche) : la partie continue,
## sans rien choisir.
func annuler_confirmation_quitter() -> void:
	if not confirmation_quitter:
		return
	confirmation_quitter = false
	rafraichir()


## Le joueur d'index `index` est parti (annoncé par l'hôte après le gong) : sa ligne se grise ; Revanche
## et Niveau suivant attendent deux joueurs encore là.
func marquer_parti(index: int) -> void:
	if index < 0 or index >= partis.size() or partis[index]:
		return
	partis[index] = true
	rafraichir()


## Les boutons et les lignes à jour : départs, choix possibles, sélection, et la confirmation de
## départ de l'hôte (qui masque les boutons habituels derrière Oui/Non, Oui mis en évidence : P1 de la
## revue finale).
func rafraichir() -> void:
	if hote:
		# M5 de la revue finale : la sélection ne doit jamais rester sur un choix devenu impossible ou
		# invisible (un joueur qui part rend Revanche/Niveau suivant impossibles, par exemple), sans
		# quoi rien ne serait mis en évidence et vomir/la validation ne choisiraient plus rien.
		var possibles := _choix_possibles()
		if not selection in possibles and not possibles.is_empty():
			selection = possibles[0]
	for l in lignes:
		var i: int = l.index
		var badges := PackedStringArray()
		if GameState.joueurs[i] == GameState.joueur_local():
			badges.append(tr("SALON_TOI"))
		if partis[i]:
			badges.append(tr("BATAILLE_PARTI"))
		(l.badge as Label).text = " · ".join(badges)
		if animation_finie:  # sinon, l'animation fait apparaître la ligne (et la grise à sa fin)
			(l.ligne as Control).modulate.a = OPACITE_PARTI if partis[i] else 1.0
	for i in range(CHOIX.size()):
		var b: Button = _boutons()[i]
		b.disabled = not choix.is_empty() or not possible(CHOIX[i])
		var choisi := CHOIX[i] == selection and hote
		for nom in ["normal", "hover"]:
			if choisi:
				b.add_theme_stylebox_override(nom, _style_selection)
			else:
				b.remove_theme_stylebox_override(nom)
	for nom in ["normal", "hover"]:
		if confirmation_quitter:
			bouton_oui.add_theme_stylebox_override(nom, _style_selection)
		else:
			bouton_oui.remove_theme_stylebox_override(nom)
	boutons.visible = not confirmation_quitter
	confirmation_quitter_conteneur.visible = confirmation_quitter
	if confirmation_quitter:
		etat.text = tr("RESULTATS_QUITTER_CONFIRMATION")
		aide.text = tr("RESULTATS_AIDE_CONFIRMATION")
	else:
		aide.text = tr("RESULTATS_AIDE_HOTE" if hote else "RESULTATS_AIDE")
		if hote:
			etat.text = "" if possible(&"revanche") else tr("SALON_ATTENTE_JOUEURS")
		else:
			etat.text = tr("RESULTATS_ATTENTE_HOTE")


## Vrai si le choix `voulu` peut se faire sur ce poste : Quitter toujours ; Revanche et Niveau suivant
## pour l'hôte, avec au moins deux joueurs encore là ; Retour au salon pour l'hôte, en réseau.
func possible(voulu: StringName) -> bool:
	match voulu:
		&"quitter":
			return true
		&"revanche", &"suivant":
			return hote and partis.count(false) >= EtatPartie.NB_JOUEURS_MIN
		&"salon":
			return hote and en_reseau
	return false


## Le classement tel qu'il s'affiche, en une ligne (tests : le même sur chaque poste, sans le « TOI » de
## chacun) : pour chaque ligne, rang, pseudo, part, statistiques et départ ; puis les lauréats de chaque
## titre.
func resume() -> String:
	var morceaux := PackedStringArray()
	for l in lignes:
		var stats: Array = (l.stats as Array).map(func(e: Label) -> String: return e.text)
		morceaux.append("%s:%s:%d %%:%s%s" % [(l.rang as Label).text, (l.pseudo as Label).text, l.cible, ",".join(stats), ":parti" if partis[l.index] else ""])
	for c in cartes_titres:
		morceaux.append("%s=%s" % [(c.titre as Label).text, (c.nom as Label).text])
	return "|".join(morceaux)


## La ligne du gagnant pour les meneurs `meneurs` (leurs noms) : le gagnant, les ex æquo, ou personne
## (aucune cellule peinte).
func texte_gagnant(meneurs: PackedStringArray) -> String:
	if meneurs.is_empty():
		return tr("BATAILLE_PERSONNE")
	if meneurs.size() == 1:
		return tr("BATAILLE_GAGNANT") % meneurs[0]
	return tr("BATAILLE_EGALITE") % ", ".join(meneurs)


## Affiche tout d'un coup (fin de l'animation, ou un appui qui la coupe). M2 de la revue finale : les
## boutons de choix reprennent leur clic (`mouse_filter`), invisibles et ignorés jusque-là.
func terminer_animation() -> void:
	if animation_finie:
		return
	animation_finie = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for l in lignes:
		(l.ligne as Control).modulate.a = OPACITE_PARTI if partis[l.index] else 1.0
		_ecrire_part(l, float(l.cible))
	for c in cartes_titres:
		(c.cadre as Control).modulate.a = 1.0
	boutons.modulate.a = 1.0
	for b in _boutons():
		b.mouse_filter = Control.MOUSE_FILTER_STOP


func _animer() -> void:
	for l in lignes:
		(l.ligne as Control).modulate.a = 0.0
		_ecrire_part(l, 0.0)
	for c in cartes_titres:
		(c.cadre as Control).modulate.a = 0.0
	boutons.modulate.a = 0.0
	# M2 de la revue finale : les boutons sont invisibles (`modulate.a`) mais recevraient encore les
	# clics sans ceci.
	for b in _boutons():
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = create_tween().set_parallel(true)
	var debut := 0.0
	for l in lignes:
		_tween.tween_property(l.ligne, "modulate:a", OPACITE_PARTI if partis[l.index] else 1.0, 0.15).set_delay(debut)
		_tween.tween_method(func(v: float) -> void: _ecrire_part(l, v), 0.0, float(l.cible), DUREE_COMPTEUR).set_delay(debut)
		debut += DELAI_LIGNE
	debut += DUREE_COMPTEUR - DELAI_LIGNE
	for c in cartes_titres:
		_tween.tween_property(c.cadre, "modulate:a", 1.0, 0.2).set_delay(debut)
		debut += DELAI_TITRE
	_tween.tween_property(boutons, "modulate:a", 1.0, 0.25).set_delay(debut)
	_tween.tween_callback(terminer_animation).set_delay(debut + 0.25)


## La barre et le compteur de la ligne `l` à `part` % (animés de 0 à sa part).
func _ecrire_part(l: Dictionary, part: float) -> void:
	(l.barre as Control).custom_minimum_size.x = maxf(TAILLE_BARRE.x * part / 100.0, 0.0)
	(l.part as Label).text = "%d %%" % int(round(part))


func _deplacer_selection(sens: int) -> void:
	var possibles := _choix_possibles()
	if possibles.is_empty():
		return
	var k := possibles.find(selection)
	selection = possibles[posmod(k + sens, possibles.size())] if k >= 0 else possibles[0]
	rafraichir()


## Les choix (parmi CHOIX, dans son ordre) à la fois possibles (`possible`) et visibles sur ce poste.
func _choix_possibles() -> Array[StringName]:
	var possibles: Array[StringName] = []
	for c in CHOIX:
		if possible(c) and (_boutons()[CHOIX.find(c)] as Button).visible:
			possibles.append(c)
	return possibles


func _boutons() -> Array[Button]:
	return [bouton_revanche, bouton_suivant, bouton_salon, bouton_quitter]


func _nom(index: int) -> String:
	return _HUD.nom_affiche(GameState.joueurs[index])


func _creer_entete() -> void:
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", 16)
	for cle_largeur: Array in [["", 60], ["", 64], ["", LARGEUR_PSEUDO], ["RESULTATS_PART", TAILLE_BARRE.x + 16 + 110],
			["RESULTATS_ETOURDIS", 200], ["RESULTATS_VOLEES", 200], ["RESULTATS_CHOCS", 200], ["", 110]]:
		var e := _etiquette(22, COULEUR_NOM)
		e.text = tr(cle_largeur[0]) if not (cle_largeur[0] as String).is_empty() else ""
		e.custom_minimum_size.x = cle_largeur[1]
		entete.add_child(e)
	tableau.add_child(entete)


func _creer_ligne(index: int, rang: int, part: int) -> Dictionary:
	var joueur: Joueur = GameState.joueurs[index]
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 16)
	var etiquette_rang := _etiquette(34, Styles.JAUNE if rang == 1 else Color.WHITE)
	etiquette_rang.text = tr("BATAILLE_RANG_%d" % rang) if rang > 0 else "–"
	etiquette_rang.custom_minimum_size.x = 60
	var lion := TextureRect.new()
	lion.texture = TEXTURE_LION
	lion.custom_minimum_size = Vector2(64, 64)
	lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var teinte := ShaderMaterial.new()  # une par ligne : jamais partagée
	teinte.shader = SHADER_TEINTE
	teinte.set_shader_parameter("couleur_joueur", joueur.couleur)
	lion.material = teinte
	var couronne := _HUD.Couronne.new()
	couronne.position = _HUD.PLACE_COURONNE * (64.0 / 56.0)
	couronne.size = _HUD.TAILLE_COURONNE * (64.0 / 56.0)
	couronne.pivot_offset = couronne.size / 2.0
	couronne.rotation = _HUD.INCLINAISON_COURONNE
	couronne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couronne.visible = rang == 1
	lion.add_child(couronne)
	var pseudo := _etiquette(30, joueur.couleur, true)
	pseudo.text = _nom(index)
	pseudo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pseudo.custom_minimum_size.x = LARGEUR_PSEUDO
	var fond_barre := Panel.new()
	fond_barre.custom_minimum_size = TAILLE_BARRE
	fond_barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fond_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_fond := StyleBoxFlat.new()
	style_fond.bg_color = Color(1, 1, 1, 0.08)
	style_fond.set_corner_radius_all(8)
	fond_barre.add_theme_stylebox_override("panel", style_fond)
	var barre := Panel.new()
	barre.custom_minimum_size = Vector2(0, TAILLE_BARRE.y)
	barre.size = Vector2(0, TAILLE_BARRE.y)
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_barre := StyleBoxFlat.new()
	style_barre.bg_color = joueur.couleur
	style_barre.set_corner_radius_all(8)
	barre.add_theme_stylebox_override("panel", style_barre)
	var boite_barre := HBoxContainer.new()  # la barre part de la gauche du fond
	boite_barre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boite_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite_barre.add_child(barre)
	fond_barre.add_child(boite_barre)
	var etiquette_part := _etiquette(32, Color.WHITE)
	etiquette_part.custom_minimum_size.x = 110
	etiquette_part.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var stats: Array[Label] = []
	for valeur in [bilan.etourdissements[index], bilan.volees[index], bilan.chocs[index]]:  # l'ordre des titres
		var e := _etiquette(30, Color.WHITE)
		e.text = str(valeur)
		e.custom_minimum_size.x = 200
		stats.append(e)
	var badge := _etiquette(22, Styles.JAUNE)
	badge.custom_minimum_size.x = 110
	for noeud: Control in [etiquette_rang, lion, pseudo, fond_barre, etiquette_part]:
		ligne.add_child(noeud)
	for e in stats:
		ligne.add_child(e)
	ligne.add_child(badge)
	tableau.add_child(ligne)
	return {"index": index, "ligne": ligne, "rang": etiquette_rang, "lion": lion, "couronne": couronne, "pseudo": pseudo,
		"barre": barre, "part": etiquette_part, "stats": stats, "badge": badge, "cible": part}


func _creer_titre(t: StringName) -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.border_color = Styles.JAUNE
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	var cadre := PanelContainer.new()
	cadre.custom_minimum_size = Vector2(520, 0)
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_theme_stylebox_override("panel", style)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	cadre.add_child(colonne)
	var etiquette_titre := _etiquette(26, Styles.JAUNE)
	etiquette_titre.text = tr("RESULTATS_" + String(t).to_upper())
	var laureats := bilan.laureats(t)
	# Les lauréats un par ligne (ex æquo compris), chacun dans sa couleur s'il est seul
	var nom := _etiquette(30, GameState.joueurs[laureats[0]].couleur if laureats.size() == 1 else Color.WHITE)
	var noms := PackedStringArray()
	for i in laureats:
		noms.append(_nom(i))
	nom.text = "\n".join(noms) if not noms.is_empty() else tr("RESULTATS_PERSONNE")
	var valeur := _etiquette(22, COULEUR_NOM)
	valeur.text = (tr("RESULTATS_" + String(t).to_upper() + "_VALEUR") % bilan.record(t)) if not laureats.is_empty() else " "
	for noeud: Control in [etiquette_titre, nom, valeur]:
		colonne.add_child(noeud)
	rangee_titres.add_child(cadre)
	return {"cadre": cadre, "titre": etiquette_titre, "nom": nom, "valeur": valeur}


## Une étiquette jamais traduite d'elle-même (les textes sont traduits ici, et un pseudo comme « PAUSE »
## n'est pas une clé), au contour sombre ; `coupee` : coupée au bord plutôt que de s'élargir (un pseudo).
func _etiquette(taille: int, couleur: Color, coupee := false) -> Label:
	var etiquette := Label.new()
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiquette.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	etiquette.clip_text = coupee
	if coupee:
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.add_theme_font_size_override("font_size", taille)
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.add_theme_color_override("font_outline_color", COULEUR_CONTOUR)
	etiquette.add_theme_constant_override("outline_size", 6)
	return etiquette
