class_name Regles
extends RefCounted
## Règles d'une partie : reçoivent les événements du jeu et décident de leurs effets.
## Chaque événement concerne le joueur reçu, qui n'est pas forcément le joueur local.
## Sans effet par défaut ; chaque mode (solo, bataille) en dérive. Les événements (coups,
## pastilles, chocs, vols, progression) ne s'exécutent que sur l'hôte (en solo, le poste
## est son propre hôte) ; les requêtes de mode (`taille_ecran`, `compte_le_territoire`,
## apparitions) sont lues sur chaque poste, qui doit donc brancher les mêmes règles (le salon
## appelle `GameState.configurer_bataille_reseau` sur chaque poste avant la scène de jeu).

## Durée de la gerbe XXL donnée par une étoile, la même en solo et en bataille.
const DUREE_ETOILE := 8.0
## Écran du solo (spec §7) : la taille de référence des hauteurs d'apparition et du peintre, qui
## gardent en bataille leurs dimensions du solo.
const TAILLE_ECRAN_SOLO := Vector2i(2000, 648)

## État de la partie (l'autoload GameState, typé par sa classe EtatPartie), fourni à la
## construction : les règles ne dépendent pas d'un global, ce qui permet de les tester (un test
## `--script` est compilé avant l'enregistrement des autoloads).
var partie: EtatPartie


func _init(partie_: EtatPartie = null) -> void:
	partie = partie_


## Couleurs que le joueur vomit dès le départ d'une partie (lu par `nouvelle_partie`).
func couleurs_de_depart(_joueur: Joueur) -> Array[Color]:
	return []


## Vrai si la partie se joue au territoire (bataille) : la ville tient alors, en plus de sa
## mesure de couverture, une grille de propriété (`Territoire`) qui compte les cellules de
## chaque joueur. Lu par la ville quand elle charge sa skyline.
func compte_le_territoire() -> bool:
	return false


## Taille de l'écran du mode (`content_scale_size`, spec §7), appliquée par `Main` en entrant
## dans la scène de jeu, et par le titre (qui remet le solo) : celle du solo par défaut.
func taille_ecran() -> Vector2i:
	return TAILLE_ECRAN_SOLO


## Met l'écran à `taille` (`content_scale_size`, spec §7) et, dans une fenêtre (ni plein écran, ni
## maximisée, ni headless) : quand l'écran change de format, règle la hauteur de la fenêtre sur le
## nouveau format en gardant sa largeur (hors du solo, écran En ligne, salon, bataille en 16:9, l'écran ne
## s'affiche plus avec des bandes dans la fenêtre du solo : 1400×454 devient 1400×788, et le titre la
## rend au solo) ; puis, toujours, la garde dans la zone utile de son écran (M7 de la revue finale 14 :
## sans la barre des tâches, barre de titre comprise), réduite au même format et recentrée au besoin (une
## fenêtre du solo élargie à 1920 px passait en 1920×1080 plus sa barre de titre sur un écran 1080p : le
## bas de la ville et le HUD sous la barre des tâches). Une fenêtre qui tient déjà dans son écran, au même
## format, reste telle que le joueur l'a mise. Appelée par le titre (le premier écran du jeu), l'écran
## Réseau, le salon et la scène de jeu.
static func appliquer_ecran(arbre: SceneTree, taille: Vector2i) -> void:
	var avant := arbre.root.content_scale_size
	arbre.root.content_scale_size = taille
	if DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var fenetre := DisplayServer.window_get_size()
	var voulue := fenetre if avant == taille else taille_fenetre(taille, fenetre)
	var zone := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var bords := DisplayServer.window_get_size_with_decorations() - fenetre
	voulue = taille_bornee(voulue, zone.size - bords)
	if voulue != fenetre:
		DisplayServer.window_set_size(voulue)
	var coin := DisplayServer.window_get_position_with_decorations()
	var place := position_dans(coin, voulue + bords, zone)
	if place != coin:
		DisplayServer.window_set_position(place + DisplayServer.window_get_position() - coin)


## La fenêtre de largeur `fenetre.x` au format de l'écran `ecran`.
static func taille_fenetre(ecran: Vector2i, fenetre: Vector2i) -> Vector2i:
	return Vector2i(fenetre.x, roundi(fenetre.x * float(ecran.y) / ecran.x))


## La fenêtre `fenetre`, réduite à son format pour tenir dans `place` (M7) ; telle quelle si elle y tient
## déjà, ou si `place` n'a pas de surface (écran inconnu). Le côté qui limite prend exactement la place.
static func taille_bornee(fenetre: Vector2i, place: Vector2i) -> Vector2i:
	if place.x <= 0 or place.y <= 0 or (fenetre.x <= place.x and fenetre.y <= place.y):
		return fenetre
	if fenetre.x * place.y >= fenetre.y * place.x:
		return Vector2i(place.x, floori(place.x * float(fenetre.y) / fenetre.x))
	return Vector2i(floori(place.y * float(fenetre.x) / fenetre.y), place.y)


## Le coin d'une fenêtre de taille `taille` (bords compris) posée en `coin`, ramené dans la zone `zone`
## (M7) : inchangé si elle y tient ; collé au bord qu'elle dépasse sinon ; au coin de la zone si elle est
## plus grande qu'elle. Comme `taille_bornee` : `coin` inchangé si `zone` n'a pas de surface (écran
## inconnu) plutôt que de reposer la fenêtre au hasard.
static func position_dans(coin: Vector2i, taille: Vector2i, zone: Rect2i) -> Vector2i:
	if zone.size.x <= 0 or zone.size.y <= 0:
		return coin
	return Vector2i(
		clampi(coin.x, zone.position.x, maxi(zone.position.x, zone.end.x - taille.x)),
		clampi(coin.y, zone.position.y, maxi(zone.position.y, zone.end.y - taille.y)))


## Avancement de la partie, de 0 (début) à 1 (fin en vue), qui accélère le peintre et les
## apparitions d'ennemis. Peut dépasser 1 : les appelants le bornent. Nul par défaut (rien
## n'accélère).
func avancement() -> float:
	return 0.0


## Couches de musique à entendre (0 : la base seule, 1 : + arpèges, 2 : + mélodie ; au-delà, `Audio`
## borne) : une par tiers de l'avancement (en solo, la ville peinte rapportée au seuil ; en
## bataille, les arpèges à 30 s de jeu et la mélodie à 60 s, spec §8).
func intensite_musique() -> int:
	return int(avancement() * 3.0)


## Le temps de la partie vient d'avancer (`GameState._process`, chez l'hôte seulement) : sans effet
## par défaut (le chrono du solo ne fait que compter) ; en bataille, le chrono termine la manche.
func temps_ecoule_change() -> void:
	pass


## Index de la couleur de l'arc-en-ciel de la prochaine pastille à faire apparaître, -1 pour
## aucune (lu par le Spawner quand une pastille est due). Aucune par défaut.
func pastille_a_offrir() -> int:
	return -1


## Vrai si l'étoile XXL peut apparaître maintenant (lu par le Spawner à chaque échéance).
func etoile_peut_apparaitre() -> bool:
	return false


## Vrai si une pastille doit apparaître loin du centre de chaque lion, au plus loin des dix essais du
## Spawner quand aucun ne l'est assez ; faux (le solo, inchangé) : loin du coin du lion, le dernier
## essai gardé.
func pastilles_loin_des_lions() -> bool:
	return false


## Pastilles de couleur présentes en même temps au plus : après chaque arrivée, le Spawner en programme
## une autre tant qu'il y en a moins. Une seule par défaut (le solo : la suivante n'arrive qu'après le
## départ de la précédente).
func pastilles_en_meme_temps() -> int:
	return 1


## Vrai si une pastille peut arriver alors que `presentes` sont déjà là : toujours par défaut (le solo,
## inchangé) ; en bataille, sous le plafond (`pastilles_en_meme_temps`).
func pastille_peut_arriver(_presentes: int) -> bool:
	return true


## Délai avant l'arrivée de la pastille suivante (après le départ d'une pastille ou, sous le plafond,
## l'arrivée de la précédente), en secondes : celui du Spawner par défaut (le solo, 6 s).
func delai_entre_pastilles(delai_du_spawner: float) -> float:
	return delai_du_spawner


## Durée de vie d'une pastille de couleur que personne ne ramasse, en secondes ; 0 : illimitée (le
## solo). Sa fin (`Pastille._expirer`) est un départ comme un autre : la suivante est programmée.
func duree_de_vie_pastille() -> float:
	return 0.0


## Facteur de la pause du peintre entre deux passages : 1 par défaut (le solo).
func facteur_repos_peintre() -> float:
	return 1.0


## La zone des pastilles (échelle du solo, 648 px de haut) ajustée pour ce mode, appelée une fois par
## le Spawner à son démarrage : inchangée par défaut (le solo, sans HUD au-dessus de l'écran de jeu).
func zone_pickups_ajustee(zone: Rect2) -> Rect2:
	return zone


## Vrai si la partie a des cœurs à ramasser (le Spawner ne programme leurs apparitions que si
## c'est le cas).
func coeurs_en_jeu() -> bool:
	return false


## Vrai si un cœur peut apparaître maintenant (lu par le Spawner à chaque échéance, quand la
## partie a des cœurs).
func coeur_peut_apparaitre() -> bool:
	return false


## Un ennemi (soucoupe, coccinelle, peintre) touche le lion du joueur. `origine` vient de
## `Ennemi.origine_du_coup` (le peintre donne x du peintre, y du lion), pour le recul
## (Vector2.INF si inconnue). Le peintre le signale à chaque frame de chevauchement : un
## joueur déjà frappé doit être ignoré.
func lion_touche_par_ennemi(_joueur: Joueur, _origine: Vector2) -> void:
	pass


## Le vomi du lion d'`agresseur` touche le lion de `victime`, à `origine` (point de la gerbe,
## pour le recul). Signalé à chaque frame de contact, comme le peintre.
func lion_touche_par_vomi(_victime: Joueur, _agresseur: Joueur, _origine: Vector2) -> void:
	pass


## Les lions de `a` et `b` viennent de se rentrer dedans (signalé une fois par contact).
func choc_entre_lions(_a: Joueur, _b: Joueur) -> void:
	pass


## Renvoie true si la pastille a eu un effet (elle disparaît dans tous les cas ; la valeur de
## retour ne sert qu'au feedback). `index_couleur` ne compte que pour les règles qui utilisent
## l'arc-en-ciel ; les règles de bataille l'ignorent.
func pastille_ramassee(_joueur: Joueur, _index_couleur: int) -> bool:
	return false


func etoile_ramassee(_joueur: Joueur) -> void:
	pass


## Renvoie true si le cœur a eu un effet (il disparaît dans tous les cas ; la valeur de retour
## ne sert qu'au feedback).
func coeur_ramasse(_joueur: Joueur) -> bool:
	return false


## La ville vient de mesurer la part peinte (0 à 1).
func progression_mesuree(_ratio: float) -> void:
	pass


## Un tampon du lion de `voleur` vient de lui faire posséder `nb` cellules (au moins une) qui
## comptaient en dernier pour d'autres joueurs (territoire, bataille). Signalé par la ville de
## l'hôte, une fois par tampon.
func vol_de_cellules(_voleur: Joueur, _nb: int) -> void:
	pass


## Vrai pendant le jeu proprement dit : partie en cours et intro « Prêt ? Vomissez ! » finie.
## Lu aussi par la ville, qui ne tamponne le territoire que pendant la manche.
func manche_en_cours() -> bool:
	return partie.partie_en_cours and partie.pret
