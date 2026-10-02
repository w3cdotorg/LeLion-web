extends Node
## La manche synchronisée (phase 14, spec §3.2) : ce qui passe entre l'hôte et les clients pendant
## une manche en réseau, sur ce nœud de la scène de jeu (`/root/Main/Manche`, au même chemin sur
## chaque poste). Hors réseau (solo, bataille locale), la scène de jeu ne l'appelle pas : il ne fait
## rien. L'hôte simule tout (lions, ennemis, pastilles, étourdissements, territoire) ; un client
## n'envoie que ses commandes et affiche ce que l'hôte décide.
## - Barrière de chargement : chaque poste signale sa scène de jeu chargée
##   (`Reseau.signaler_scene_chargee`) ; l'hôte attend tous les joueurs de la manche encore là, au
##   plus `delai_chargement` secondes de jeu, puis exclut les absents (l'exclu part de lui-même à
##   l'annonce, l'hôte ne le libère qu'en secours : son départ est un départ comme un autre) ; alors
##   seulement (`barriere_passee`, chez l'hôte puis chez chaque client) les lions apparaissent, le
##   Spawner démarre et l'intro se lance chez tous.
## - Commandes (phase 16) : chaque client envoie à chaque tick physique la commande que la prédiction
##   de son lion vient de lire, numérotée, avec les 3 précédentes (`PredictionLocale.paquet`, RPC
##   `unreliable`, non ordonnée : un Wi-Fi ou un relais qui réordonne une rafale de rattrapage ne doit
##   pas faire jeter par ENet un paquet plus récent arrivé en premier) ; l'hôte met chaque numéro
##   supérieur à la dernière commande appliquée et pas déjà en file dans la file des commandes
##   manuelles de ce lion, à sa place (`Commandes.recevoir`), qui en applique une par tick, dans
##   l'ordre, jamais deux fois, et renvoie le numéro de la dernière appliquée dans l'état du lion
##   (`Lion.etat_reseau`) ; si le numéro attendu manque encore à son tick, il est sauté (compté,
##   jamais appliqué en retard) : seules la redondance (3 précédentes par paquet) et l'insertion dans
##   le désordre le couvrent. Il remet le lion au repos après SILENCE_COMMANDES de temps de jeu sans
##   paquet (pas l'horloge murale, M4 de la revue finale : un rattrapage de ticks physiques après un
##   gel de l'hôte ne doit pas se lire comme un silence). Il admet COMMANDES_PAR_TICK paquets par tick
##   et par client (spec §8.2 du jeu en ligne) et jette le reste (`admettre_commandes`).
## - Tampons : chaque tampon de la ville de l'hôte (`Ville.tampon_peint`) est diffusé, regroupé par
##   tick physique, sur le canal fiable 1 (`Peinture.encoder_tampons`) ; un client le dessine
##   (`Ville.peindre_tampon_recu`).
## - Territoire : toutes les INTERVALLE_TERRITOIRE secondes, l'hôte diffuse les cellules dont le
##   propriétaire compté a changé et les scores (même canal fiable) ; un client les applique
##   (`Territoire.appliquer_changements`) et vérifie qu'il a les mêmes scores.
## - Réactions des joueurs : étourdissement et sa fin, crans, gerbe XXL et sa fin partent de l'hôte en
##   RPC fiables, qui appellent chez chaque client les méthodes du `Joueur` qui émettent les mêmes
##   signaux (Lion, HUD, Audio).
## - Départs : un client parti (`Reseau.joueur_parti`) perd son lion chez l'hôte (sa disparition est
##   répliquée), ses cellules restent ; l'hôte annonce son départ à chaque client (`depart_vu` : le HUD
##   le grise, phase 17) ; un hôte perdu arrête la manche du client (la scène de jeu affiche le message
##   et revient au titre).
## - Fin de manche (phase 17) : décidée par l'hôte seul (son chrono, ses règles), elle part après ses
##   derniers tampons et son territoire, sur le même canal fiable ordonné, avec son bilan (phase 18,
##   `BilanManche` : son chrono, les cellules, crans et statistiques de chaque joueur, les départs,
##   l'état final de chaque lion) ; chaque client la reçoit, prend le chrono de l'hôte, pose l'état final
##   de chaque lion (sa prédiction s'arrête), les crans et les statistiques de l'hôte, et termine sa
##   manche (tout se fige), puis n'envoie plus de commandes. Sur chaque poste, `bilan_recu` donne ce
##   bilan à l'écran Résultats. Le chrono d'un client, parti à la fin de sa propre intro, ne termine
##   jamais rien lui-même.
## Nœud de scène : il nomme `Reseau` et `GameState` ; les tests `--script` ne le nomment pas.

## Chez l'hôte puis chez chaque client : la barrière de chargement est passée, la manche commence.
signal barriere_passee()
## Chez l'hôte : le joueur d'index `index` a quitté la manche (déconnecté, ou exclu faute de scène
## chargée à temps).
signal joueur_parti(index: int)
## Sur chaque poste : le joueur d'index `index` a quitté la manche (chez l'hôte à son départ ; chez un
## client quand l'hôte l'annonce, en passant la barrière pour un départ d'avant) : le HUD le grise.
signal depart_vu(index: int)
## Sur chaque poste, une fois la manche finie (phase 18) : le bilan de l'hôte (chez l'hôte, relevé au
## gong ; chez un client, reçu avec la fin et déjà appliqué), que montre l'écran Résultats.
signal bilan_recu(bilan: BilanManche)

## Délai de la barrière de chargement, en secondes : au-delà, les joueurs dont la scène n'est pas
## chargée sont exclus.
const DELAI_CHARGEMENT := 20.0
## Sans commande d'un client depuis ce délai (ms de temps de jeu, pas l'horloge murale : M4 de la
## revue finale), l'hôte remet son lion au repos (point de vigilance des phases 14 et 16 : un client
## planté ne laisse pas son lion filer ou vomir). Bien au-dessus de la latence du Wi-Fi simulée par
## les tests (40 ms ± 20 ms par sens) et de trois paquets perdus de suite, que la redondance couvre.
const SILENCE_COMMANDES := 500
## Période de diffusion du territoire (cellules changées et scores), en secondes (spec §6).
const INTERVALLE_TERRITOIRE := 0.2
## Canal ENet des tampons et du territoire (spec §4 : canal 1, fiable ordonné).
const CANAL_PEINTURE := 1
## Paquets de commandes admis par tick et par client, chez l'hôte (spec §8.2) : un client en envoie un par
## tick ; au-delà de deux, l'hôte les jette (`LimiteDebit`). Le tick est celui de la cadence du jeu
## (`Engine.physics_ticks_per_second`, 60 : 120 paquets par seconde), mesuré à l'horloge de l'hôte, pas à
## ses ticks physiques : un hôte lent, qui en fait moins (la CI sous Firefox, mesuré), jetterait les paquets
## d'un client qui joue. La rafale admise d'un coup : RAFALE_COMMANDES, deux secondes d'un client (un hôte
## figé deux secondes, un onglet ralenti, ne jette aucun des paquets accumulés).
const COMMANDES_PAR_TICK := 2
const RAFALE_COMMANDES := 120

## Délai de la barrière de chargement de la prochaine manche : DELAI_CHARGEMENT, réglable par les
## tests réseau (le script de la manche, `load("res://Scripts/Manche.gd")`, porte cette variable).
static var delai_chargement := DELAI_CHARGEMENT

## Vrai une fois `demarrer` appelé, jusqu'à ce que l'hôte soit perdu (un client ne devient jamais
## hôte : revenu hors réseau, il attend le retour au titre).
var actif := false
## Vrai une fois la barrière passée (chez l'hôte et chez chaque client).
var barriere := false
## Statistiques de la manche, lues par le test réseau : tampons diffusés (hôte) ou reçus (client),
## et l'empreinte de leur suite (chaque lot, dans l'ordre), la même chez l'hôte et chez chaque client
## qui a tout reçu.
var tampons_diffuses := 0
var tampons_recus := 0
var empreinte_tampons := 0
## Vrai une fois la manche finie sur ce poste : chez l'hôte à sa fin (ses règles, ou le test réseau
## qui la fige), chez un client à la fin reçue de l'hôte.
var finie := false
## Client : le chrono de l'hôte moins celui de ce poste quand la fin est arrivée, en secondes (lu par
## le test réseau : le décalage de la latence, sans conséquence, puisque le chrono de ce poste prend
## celui de l'hôte).
var ecart_chrono_fin := 0.0
## Le bilan de la manche une fois finie (`bilan_recu`) ; null avant.
var bilan: BilanManche
## Hôte : la suite des méthodes passées à `_envoyer`, dans l'ordre (I2, revue finale phase 17) : lue
## par les tests (smoke, réseau) pour prouver que les derniers tampons et le territoire partent
## avant la fin de manche, sur le même canal fiable ordonné. Jamais vidée d'elle-même : au test de
## la vider avant la mesure qui l'intéresse.
var envois_ordre: Array[StringName] = []

var _hote := false
var _ville: Node2D
## Hôte : les commandes manuelles du lion de chaque client, par index de joueur. Jamais rempli chez un
## client (phase 16) : les commandes de son propre lion partent par sa prédiction (`_prediction`),
## jamais par ce dictionnaire.
var _commandes: Dictionary[int, Commandes] = {}
## Hôte : par index de joueur, l'instant (ms de temps de jeu) du dernier paquet de commandes reçu.
var _recues: Dictionary[int, int] = {}
## Hôte : le débit des paquets de commandes de chaque client (COMMANDES_PAR_TICK par tick), en secondes.
var _limite_commandes := LimiteDebit.new(COMMANDES_PAR_TICK * Engine.physics_ticks_per_second, RAFALE_COMMANDES)
## Hôte : les clients dont la scène est chargée, destinataires de tout ce que diffuse la manche.
var _prets: Array[int] = []
## Hôte : les clients exclus par la barrière, qui partent.
var _exclus: Array[int] = []
## Hôte : les index des joueurs partis de la manche (exclus compris), annoncés à chaque client prêt.
var _partis: Array[int] = []
var _tampons: Array[Dictionary] = []
var _temps_territoire := 0.0
## Hôte : temps de jeu (ticks physiques) écoulé depuis le début du chargement. Pas l'horloge
## murale : un hôte figé (chargement, compilation des shaders) n'exclut personne en reprenant, avant
## d'avoir lu les « scène chargée » arrivés pendant qu'il était figé.
var _temps_chargement := 0.0
## Hôte, après la barrière : temps de jeu écoulé (ticks physiques additionnés en secondes), utilisé
## pour SILENCE_COMMANDES. Pas l'horloge murale (M4, revue finale) : après un gel de l'hôte
## (compilation d'un shader), plusieurs ticks physiques de rattrapage passent avant le sondage
## réseau du même `process` ; comptés à l'horloge murale, ce rattrapage se lirait comme un silence
## des commandes et remettrait chaque lion distant au repos pour rien.
var _temps_manche := 0.0
## Client : la prédiction du lion de ce poste, qui lit ses commandes et les numérote.
var _prediction: PredictionLocale
## Sur chaque poste : le lion de chaque joueur, par index (`suivre_lion`) ; chez l'hôte, leur état final
## entre dans le bilan ; chez un client, chacun y prend le sien. Celui d'un joueur parti y reste, libéré :
## chaque lecture passe par `_lion_de`.
var _lions: Dictionary[int, Lion] = {}


func _ready() -> void:
	# Après les lions et leurs traceuses (priorité 0) : les tampons d'un tick partent dans ce tick ; et
	# après la prédiction du lion local d'un client (priorité -10) : la commande de ce tick part dans ce
	# tick.
	process_physics_priority = 100


## Commence la manche en réseau, sur la ville `ville` de la scène de jeu : appelé par `Main` en
## réseau seulement, une fois sa scène prête. La manche continue alors même quand l'arbre est en
## pause (fin de manche) : ses derniers tampons et son territoire partent quand même.
func demarrer(ville: Node2D) -> void:
	actif = true
	_ville = ville
	_hote = multiplayer.is_server()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	if _hote:
		Reseau.scene_chargee.connect(_sur_scene_chargee)
		Reseau.joueur_parti.connect(_sur_depart_reseau)
		GameState.partie_terminee.connect(_sur_fin_de_partie)
		# Revue de la tâche 5 (phase 18) : l'ancienne manche s'est désabonnée de `Reseau.joueur_parti`
		# dans son `_exit_tree`, cette manche neuve ne s'y abonne qu'ici, une image plus tard ; un pair
		# parti entre-temps n'a déclenché ni l'une ni l'autre. Le même chemin qu'un départ normal le
		# rattrape, pour que les clients l'apprennent en passant la barrière, comme les départs d'avant
		# elle (`_partis`, plus bas).
		for j in GameState.joueurs:
			if not Reseau.inscrits.has(j.id_reseau):
				_sur_depart_reseau(j.id_reseau)
	Reseau.signaler_scene_chargee()
	if _hote:
		_verifier_barriere()


## Les autoloads survivent à la scène de jeu : ne rien leur laisser.
func _exit_tree() -> void:
	for connexion: Array in [[Reseau.hote_perdu, _sur_hote_perdu], [Reseau.scene_chargee, _sur_scene_chargee],
			[Reseau.joueur_parti, _sur_depart_reseau], [GameState.partie_terminee, _sur_fin_de_partie]]:
		if (connexion[0] as Signal).is_connected(connexion[1]):
			(connexion[0] as Signal).disconnect(connexion[1])


## Le lion `lion` vient d'apparaître sur ce poste (appelé par `Main`) : chez l'hôte, les commandes
## manuelles du lion d'un client y seront écrites ; chez un client, les commandes de son propre lion,
## lues et numérotées par sa prédiction, partiront vers l'hôte (jamais par `_commandes`, qu'un client
## ne remplit pas).
func suivre_lion(lion: Lion) -> void:
	_lions[lion.joueur.index] = lion
	var local := lion.joueur == GameState.joueur_local()
	if _hote and not local:
		_commandes[lion.joueur.index] = lion.commandes
	if not _hote and local:
		_prediction = lion.prediction


## Chez l'hôte : vrai si le joueur d'index `index` est encore dans la manche (inscrit, ni parti ni
## exclu) : son lion doit apparaître.
func joue(index: int) -> bool:
	if index < 0 or index >= GameState.joueurs.size():
		return false
	var id := GameState.joueurs[index].id_reseau
	return Reseau.inscrits.has(id) and not _exclus.has(id)


func _physics_process(delta: float) -> void:
	if not actif:
		return
	if not _hote:
		_envoyer_commandes()
		return
	if not barriere:
		_temps_chargement += delta
		_verifier_barriere()
		return
	_temps_manche += delta
	verifier_silences(int(_temps_manche * 1000.0))
	_diffuser_tampons()
	_temps_territoire += delta
	if _temps_territoire >= INTERVALLE_TERRITOIRE:
		_temps_territoire = 0.0
		_diffuser_territoire()


# --- Barrière de chargement (hôte) ---------------------------------------------------------------


func _sur_scene_chargee(_id: int) -> void:
	_verifier_barriere()


## Les identifiants réseau des joueurs de la manche encore inscrits chez l'hôte (hôte compris).
func _attendus() -> Array[int]:
	var ids: Array[int] = []
	for j in GameState.joueurs:
		if Reseau.inscrits.has(j.id_reseau):
			ids.append(j.id_reseau)
	return ids


## Passe la barrière quand chaque joueur encore là a chargé sa scène. Délai passé, les absents sont
## exclus (chacun part de lui-même à l'annonce, l'hôte ne le libère qu'en secours) : la barrière attend
## alors leur départ, qui les retire des attendus.
func _verifier_barriere() -> void:
	if barriere or not actif:
		return
	var absents := _attendus().filter(func(id: int) -> bool: return not Reseau.scenes_chargees.has(id))
	if not absents.is_empty():
		if _temps_chargement >= delai_chargement:
			for id: int in absents:
				_exclure(id)
		return
	barriere = true
	_prets.clear()
	for id in Reseau.scenes_chargees:
		# M5 (revue finale) : un exclu encore connecté qui a fini de charger entre-temps ne doit pas
		# recevoir l'intro ni les diffusions ; la barrière continue d'attendre son départ (il reste
		# dans les attendus).
		if id != multiplayer.get_unique_id() and Reseau.inscrits.has(id) and not _exclus.has(id):
			_prets.append(id)
	Reseau.definir_silence(Reseau.SILENCE_SESSION)
	_ville.tampon_peint.connect(_sur_tampon_peint)
	for j in GameState.joueurs:
		j.etourdi.connect(_sur_etourdi.bind(j))
		j.etourdissement_fini.connect(_sur_fin_etourdissement.bind(j))
		j.crans_changes.connect(_sur_crans.bind(j))
		j.bonus_change.connect(_sur_bonus.bind(j))
		j.bonus_dure.connect(_sur_bonus_dure.bind(j))
	barriere_passee.emit()  # la scène fait apparaître les lions : leurs apparitions partent avant l'intro
	_envoyer(&"_lancer_intro", [])
	for index in _partis:  # les départs d'avant la barrière (exclus compris)
		_envoyer(&"_recevoir_depart", [index])


## Chez l'hôte : `id` n'a pas chargé sa scène à temps. Il apprend son exclusion et part de lui-même
## (`Reseau.exclure` : il voit « exclu », pas « L'hôte a quitté la partie ») ; l'hôte ne le libère qu'en
## secours, s'il est encore là peu après (figé, il n'a pas lu l'annonce). Son départ arrive ici par
## `Reseau.joueur_parti`.
func _exclure(id: int) -> void:
	if _exclus.has(id):
		return
	_exclus.append(id)
	push_warning("Manche : le joueur %d n'a pas chargé sa scène à temps, exclu" % id)
	Reseau.exclure(id)


## Chez un client : la barrière est passée chez l'hôte.
@rpc("authority", "call_remote", "reliable")
func _lancer_intro() -> void:
	if not actif or barriere:
		return
	barriere = true
	Reseau.definir_silence(Reseau.SILENCE_SESSION)
	barriere_passee.emit()


# --- Commandes -------------------------------------------------------------------------------------


## Chez un client : la commande de ce tick, lue par la prédiction du lion de ce poste, avec les 3
## précédentes, une fois par tick physique.
func _envoyer_commandes() -> void:
	if not barriere or finie or _prediction == null or not is_instance_valid(_prediction):
		return
	var octets := _prediction.paquet()
	if not octets.is_empty():
		_recevoir_commandes.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, octets)


## Chez l'hôte : un paquet de commandes d'un client, pour son lion.
@rpc("any_peer", "call_remote", "unreliable")
func _recevoir_commandes(octets: Variant) -> void:
	if not _hote:
		return
	var id := multiplayer.get_remote_sender_id()
	if not admettre_commandes(id):
		return
	for j in GameState.joueurs:
		if j.id_reseau == id:
			recevoir_paquet_de(j.index, octets, int(_temps_manche * 1000.0))
			return


## Chez l'hôte : vrai si le paquet de commandes du client `id` passe (COMMANDES_PAR_TICK par tick du jeu,
## RAFALE_COMMANDES d'un coup, spec §8.2), lisible ou non ; au-delà, il est jeté (un avertissement au premier
## rejet de ce client, pas à chacun). Un client qui joue n'en envoie qu'un par tick : il n'est jamais limité.
func admettre_commandes(id: int) -> bool:
	if _limite_commandes.admettre(id, Time.get_ticks_msec() / 1000.0):
		return true
	if _limite_commandes.rejets[id] == 1:
		push_warning("Manche : le client %d envoie plus de %d paquets de commandes par tick, l'excédent est jeté" % [id, COMMANDES_PAR_TICK])
	return false


## Chez l'hôte : le paquet de commandes `octets` du joueur d'index `index` (la dernière et jusqu'à 3
## précédentes, `Commandes.encoder_paquet`), reçu à `maintenant` (ms de temps de jeu) : chaque
## commande neuve entre dans la file des commandes de son lion, qui en applique une par tick. Renvoie
## le nombre de commandes neuves, ou -1 pour un lion inconnu ou un paquet mal formé. Un paquet reçu
## deux fois (aucune commande neuve) ne repousse pas le silence : sinon un client planté qui ne fait
## que redonder son dernier paquet (jamais de commande neuve) semblerait vivant indéfiniment.
func recevoir_paquet_de(index: int, octets: Variant, maintenant: int) -> int:
	var c: Commandes = _commandes.get(index)
	var paquet := Commandes.decoder_paquet(octets)
	if c == null or paquet.is_empty():
		return -1
	var neuves := 0
	for commande in paquet:
		if c.recevoir(commande.numero, commande.direction, commande.vomir):
			neuves += 1
	if neuves > 0:
		_recues[index] = maintenant
	return neuves


## Chez l'hôte : le lion d'un client dont aucun paquet de commandes n'est arrivé depuis
## SILENCE_COMMANDES ms de temps de jeu (à `maintenant`) revient au repos, sa file vidée.
func verifier_silences(maintenant: int) -> void:
	for index: int in _recues:
		if maintenant - _recues[index] > SILENCE_COMMANDES and _commandes.has(index):
			_commandes[index].remettre_au_repos()


# --- Tampons et territoire -------------------------------------------------------------------------


func _sur_tampon_peint(tampon: Dictionary) -> void:
	_tampons.append(tampon)


## Chez l'hôte : les tampons de ce tick, en un seul envoi.
func _diffuser_tampons() -> void:
	if _tampons.is_empty():
		return
	var octets := Peinture.encoder_tampons(_tampons)
	tampons_diffuses += _tampons.size()
	empreinte_tampons = hash([empreinte_tampons, octets])
	_envoyer(&"_recevoir_tampons", [octets])
	_tampons.clear()


## Chez un client : les tampons d'un tick de l'hôte, dessinés dans l'ordre.
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_tampons(octets: Variant) -> void:
	if not actif:
		return
	var tampons := Peinture.decoder_tampons(octets)
	if tampons.is_empty():
		push_warning("Manche : lot de tampons illisible, ignoré")
		return
	for tampon in tampons:
		_ville.peindre_tampon_recu(tampon)
	tampons_recus += tampons.size()
	empreinte_tampons = hash([empreinte_tampons, octets])


## Chez l'hôte : les cellules changées depuis le dernier envoi et les scores.
func _diffuser_territoire() -> void:
	var territoire: Territoire = _ville.territoire
	if territoire == null:
		return
	var changees := territoire.extraire_changements()
	if changees.is_empty():
		return
	_envoyer(&"_recevoir_territoire", [territoire.encoder_changements(changees), territoire.scores()])


## Chez un client : les cellules changées chez l'hôte, appliquées ; les scores doivent alors être
## ceux de l'hôte (sinon, une désynchronisation est signalée).
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_territoire(octets: Variant, scores: Variant) -> void:
	var territoire: Territoire = null if _ville == null else _ville.territoire
	if not actif or territoire == null:
		return
	if not territoire.appliquer_changements(octets):
		push_warning("Manche : cellules changées illisibles, ignorées")
		return
	if not (scores is PackedInt32Array) or scores != territoire.scores():
		push_error("Manche : territoire désynchronisé de l'hôte (%s au lieu de %s)" % [territoire.scores(), scores])


# --- Réactions des joueurs -------------------------------------------------------------------------


func _sur_etourdi(origine: Vector2, barbouillage: Color, j: Joueur) -> void:
	_envoyer(&"_recevoir_etourdi", [j.index, j.etourdi_restant, j.invulnerable_restant - j.etourdi_restant, origine, barbouillage])


func _sur_fin_etourdissement(j: Joueur) -> void:
	_envoyer(&"_recevoir_fin_etourdissement", [j.index, j.invulnerable_restant])


func _sur_crans(crans: int, j: Joueur) -> void:
	_envoyer(&"_recevoir_crans", [j.index, crans])


func _sur_bonus(actif_: bool, j: Joueur) -> void:
	if not actif_:
		_envoyer(&"_recevoir_fin_bonus", [j.index])


## M2 (revue finale phase 17) : `bonus_dure` part à chaque activation de la gerbe XXL, première
## activation et prolongation confondues (contrairement à `bonus_change`, qui ne l'est qu'une fois) :
## un client recale ainsi son décompte quand une deuxième étoile prolonge la gerbe en cours.
func _sur_bonus_dure(duree: float, j: Joueur) -> void:
	_envoyer(&"_recevoir_bonus", [j.index, duree])


@rpc("authority", "call_remote", "reliable")
func _recevoir_etourdi(index: Variant, duree: Variant, immunite: Variant, origine: Variant, barbouillage: Variant) -> void:
	var j := _joueur_recu(index)
	# M4 (revue finale) : bornées (l'hôte est de confiance sur un LAN, mais une valeur non finie
	# rendrait `est_etourdi()` faux) ; `origine` vaut légitimement `Vector2.INF` (origine inconnue,
	# `DeplacementLion.repousser` la gère), jamais bornée à `is_finite()`.
	if j != null and _duree_valide(duree) and _duree_valide(immunite) and origine is Vector2 and barbouillage is Color:
		j.etourdir(duree, immunite, origine, barbouillage)


@rpc("authority", "call_remote", "reliable")
func _recevoir_fin_etourdissement(index: Variant, immunite: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and _duree_valide(immunite):
		j.recevoir_fin_etourdissement(immunite)


@rpc("authority", "call_remote", "reliable")
func _recevoir_crans(index: Variant, crans: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and crans is int:
		j.recevoir_crans(crans)


@rpc("authority", "call_remote", "reliable")
func _recevoir_bonus(index: Variant, duree: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and _duree_valide(duree):
		j.activer_bonus(duree)


@rpc("authority", "call_remote", "reliable")
func _recevoir_fin_bonus(index: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null:
		j.recevoir_fin_bonus()


## Le joueur d'index `index` reçu de l'hôte, ou null (index d'un autre type ou hors de la table, ou la
## barrière pas encore passée : phase 18, une réaction ou un départ d'une manche précédente, sur le canal
## 0, arrivé après que ce poste a rechargé la scène pour une revanche, ne touche pas la manche neuve ;
## ceux de la manche neuve partent après son intro, sur le même canal).
func _joueur_recu(index: Variant) -> Joueur:
	if not actif or not barriere or not (index is int) or index < 0 or index >= GameState.joueurs.size():
		return null
	return GameState.joueurs[index]


## M4 (revue finale) : une durée ou une immunité reçue de l'hôte, bornée à [0, 30] et finie (une
## RPC de l'hôte n'a qu'un effet visuel hors plage, mais NaN ou l'infini casserait `est_etourdi()`).
func _duree_valide(v: Variant) -> bool:
	return v is float and is_finite(v) and v >= 0.0 and v <= 30.0


# --- Fin de manche ------------------------------------------------------------------------------


## Chez l'hôte : la manche est finie (son chrono, ou le test réseau qui la fige). Ses derniers tampons
## et son territoire partent d'abord, puis la fin et son bilan, sur le même canal fiable ordonné : chez
## un client, la fin arrive après eux, les scores définitifs déjà appliqués.
func _sur_fin_de_partie(_victoire: bool) -> void:
	if not barriere or finie:
		return
	finie = true
	_diffuser_tampons()
	_diffuser_territoire()
	bilan = relever_bilan()
	_envoyer(&"_recevoir_fin_manche", [bilan.encoder()])
	bilan_recu.emit(bilan)


## Le bilan de la manche tel que ce poste le voit en ce moment : le chrono, les cellules de chaque
## joueur (le territoire), ses crans et ses statistiques, les départs, l'état de chaque lion encore là.
## Celui de l'hôte au gong fait foi (`_sur_fin_de_partie`).
func relever_bilan() -> BilanManche:
	var etats: Dictionary[int, PackedByteArray] = {}
	for index: int in _lions:
		var l := _lion_de(index)
		if l != null:
			etats[index] = EtatLion.encoder(Engine.get_physics_frames(), l.commandes.numero_applique, l.position,
				l.deplacement.vitesse, l.deplacement.recul, l.direction_du_lion)
	return BilanManche.relever(GameState.joueurs, _cellules_par_joueur(), _partis, etats, GameState.temps_ecoule)


## Le lion du joueur d'index `index` s'il est encore dans l'arbre, sinon null (jamais apparu, ou parti :
## libéré).
func _lion_de(index: int) -> Lion:
	var l: Variant = _lions.get(index)
	return l if is_instance_valid(l) and (l as Lion).is_inside_tree() else null


## Les cellules de chaque joueur, dans l'ordre des index, lues sur le territoire (aucune sans lui).
func _cellules_par_joueur() -> Array[int]:
	var territoire: Territoire = null if _ville == null else _ville.territoire
	var cellules: Array[int] = []
	for j in GameState.joueurs:
		cellules.append(0 if territoire == null else territoire.cellules_de(j.index))
	return cellules


## Chez un client : la manche est finie chez l'hôte ; `recu`, son bilan (`BilanManche.encoder`), arrive
## après son dernier territoire sur le même canal (des cellules qui diffèrent sont signalées). Le chrono
## de ce poste prend celui de l'hôte, chaque lion son état final (la prédiction du lion de ce poste
## s'arrête), chaque joueur ses crans et ses statistiques de l'hôte (qui seul les tient) ; les départs
## du bilan sont vus (ceux dont l'annonce, sur un autre canal, n'est pas encore arrivée) ; puis la manche
## se termine ici aussi. Un bilan illisible (jamais d'un hôte de la même version) est signalé, et la
## manche se termine sur ce que sait ce poste. Les réactions de l'hôte encore en route (canal 0)
## s'appliquent encore à leur arrivée : elles précèdent sa fin chez lui ; l'écran Résultats ne lit que le
## bilan.
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_fin_manche(recu: Variant) -> void:
	if not actif or finie:
		return
	var lu := BilanManche.decoder(recu, GameState.joueurs.size())
	if lu == null:
		push_error("Manche : bilan de fin de l'hôte illisible, la manche se termine sur ce que sait ce poste")
		lu = relever_bilan()
	finie = true
	if _cellules_par_joueur() != lu.cellules:
		push_error("Manche : scores de fin désynchronisés de l'hôte (%s au lieu de %s)" % [_cellules_par_joueur(), lu.cellules])
	ecart_chrono_fin = lu.temps - GameState.temps_ecoule
	GameState.temps_ecoule = lu.temps
	for index: int in lu.lions:
		var l := _lion_de(index)
		if l != null:
			l.poser_etat_final(lu.lions[index])
	for i in range(lu.nb_joueurs()):
		var j: Joueur = GameState.joueurs[i]
		j.recevoir_crans(lu.crans[i])
		j.etourdissements_infliges = lu.etourdissements[i]
		j.cellules_volees = lu.volees[i]
		j.chocs = lu.chocs[i]
		if lu.partis[i]:
			depart_vu.emit(i)
	bilan = lu
	GameState.terminer_partie(true)
	bilan_recu.emit(bilan)


# --- Départs ----------------------------------------------------------------------------------------


## Chez l'hôte : le client `id` est parti (ou a été exclu).
func _sur_depart_reseau(id: int) -> void:
	_prets.erase(id)
	_limite_commandes.oublier(id)
	for j in GameState.joueurs:
		if j.id_reseau == id:
			_commandes.erase(j.index)
			_recues.erase(j.index)
			joueur_parti.emit(j.index)
			_annoncer_depart(j.index)
	_verifier_barriere()


## Chez l'hôte : le joueur d'index `index` est parti ; chaque client prêt l'apprend (les autres, en
## passant la barrière).
func _annoncer_depart(index: int) -> void:
	if _partis.has(index):
		return
	_partis.append(index)
	depart_vu.emit(index)
	_envoyer(&"_recevoir_depart", [index])


## Chez un client : l'hôte annonce le départ du joueur d'index `index`.
@rpc("authority", "call_remote", "reliable")
func _recevoir_depart(index: Variant) -> void:
	if _joueur_recu(index) != null:
		depart_vu.emit(index)


## Chez un client : l'hôte est perdu (ce poste est déjà hors réseau) ; la manche s'arrête là.
func _sur_hote_perdu() -> void:
	actif = false


## Chez l'hôte : appelle la RPC `methode` chez chaque client prêt et encore connecté (jamais chez un
## client dont la scène de jeu n'est pas chargée : le nœud de la manche n'y existe pas encore ; ni
## chez un client déjà déconnecté dont le départ n'est pas encore arrivé ici).
func _envoyer(methode: StringName, arguments: Array) -> void:
	envois_ordre.append(methode)
	var connectes := multiplayer.get_peers()
	for id in _prets:
		if connectes.has(id):
			callv("rpc_id", [id, methode] + arguments)
