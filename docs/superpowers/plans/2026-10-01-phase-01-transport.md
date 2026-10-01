# Phase 1 : transport

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** sortir le transport de `Reseau` : une interface `Transport` (`Scripts/Transport.gd`) et son implémentation ENet (`Scripts/TransportENet.gd`, extraite de `Reseau.gd`, qui ne nomme plus aucune classe d'ENet) ; un battement applicatif d'une seconde, indépendant du transport, qui déclare un poste parti après 10 s de silence (30 s au chargement de la manche), chez l'hôte comme chez un client, à la place des délais d'ENet ; un départ volontaire par un adieu fiable, vu tout de suite de l'autre côté. Version 0.20. Sortie : **les 13 scénarios du test réseau verts** (le 11 allongé : le client arraché est vu parti au bout des 10 s du battement), les autres suites vertes, `EcranReseau` et le salon inchangés (on rejoint toujours par IP, l'écran En ligne vient en phase 3).

**Architecture:**
- **`Transport`** (`RefCounted`, `@abstract`) : `heberger()`, `rejoindre(code)`, `quitter()`, `clore()`, `pair()`, `liberer(id)`, `servir()` ; signaux `pret(code)`, `connecte()`, `echec(raison)`. Ne sait rien du salon ni du jeu. `Reseau` donne `pair()` à `SceneMultiplayer` et appelle `servir()` à chaque image ; un transport quitté reste dans `Reseau._partants`, servi jusqu'à sa fermeture.
- **`TransportENet`** : `create_server` / `create_client`, port, code `ip:port` (IPv4 seulement, `adresse_ipv4` déménage ici depuis `Decouverte`), silence d'ENet repoussé à 45-60 s (c'est le battement qui décide), départ par `peer_disconnect_later` (le DISCONNECT part après l'adieu, renvoyé jusqu'à son accusé de réception, 1 s au plus), libération d'un pair par `peer_disconnect_now` puis `poll()` (son `peer_disconnected` part pendant l'appel, sans attendre l'accusé qu'un pair figé n'enverra jamais : I1).
- **Le battement dans `Reseau`** : une RPC `_battement` non fiable par seconde (l'hôte à chaque client arrivé, un client à l'hôte une fois inscrit) ; chaque paquet de `Reseau` reçu (battement ou RPC) note l'instant dans `_entendus` ; `_ecouter` déclare muet tout pair silencieux depuis plus de `silence` (`SILENCE_SESSION` 10 s, `SILENCE_CHARGEMENT` 30 s) : chez l'hôte il est libéré (`_liberer`, son départ arrive par `peer_disconnected` comme tous les départs), chez un client l'hôte est perdu. Un poste qui sort lui-même d'un gel suspend son verdict d'une image.
- **L'adieu** : `quitter()` envoie `_recevoir_adieu` (fiable) avant de fermer le transport ; l'hôte libère ce client tout de suite, un client perd l'hôte tout de suite.
- **Tests** : logique pure et transport seul dans `tests/unitaires.gd` ; un second `Reseau` client sous sa propre `SceneMultiplayer` dans le même processus (battement, silences raccourcis, adieu) ; le test réseau (13 scénarios, `TransportENet`) avec deux mesures neuves : le départ arraché du scénario 11 vu entre 8,5 et 11 s, les départs volontaires du scénario 1 vus en moins d'une seconde.

**Tech Stack:** Godot 4.7.2, GDScript typé (`class_name`, `@abstract`), `SceneMultiplayer` (authentification, RPC, `set_multiplayer` pour un second poste dans le même processus), `ENetMultiplayerPeer` / `ENetPacketPeer` (`set_timeout`, `peer_disconnect_later`, `peer_disconnect_now`), tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/prediction_test.gd`, `tests/reseau/lancer.sh` + `joueur.gd` + `relais.gd`, `tests/screenshots.gd`, `tests/deux_fenetres.gd`).

**Spec:** `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§2 silence, §3.1 unités `Reseau` / `Transport` / `TransportENet`, §5 canaux et départ volontaire, §9, §10) · feuille de route : `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 1, « Vérification commune », « Points de vigilance ») · prérequis : **phase 0 fusionnée** (PR #1) ; nouvelle branche `phase-01-transport` depuis `main`.

## Global Constraints

- Silence (spec §2) : « **10 s pour tout le monde** (hôte comme client) avant de déclarer un poste parti ; 30 s pendant le chargement de la manche (inchangé). Battement applicatif, indépendant du transport. »
- Battement (spec §3.1) : « chaque poste envoie un battement par seconde (non fiable) ; tout paquet reçu d'un pair, battement ou non, remet son silence à zéro ; 10 s de silence (30 s au chargement) le déclarent parti. »
- Départ volontaire (spec §5) : « un message fiable « je pars » puis fermeture du pair après son envoi (au plus 1 s) ; l'autre côté le voit parti tout de suite, sans attendre les 10 s. »
- `Transport` (spec §3.1) : « `heberger() -> Error`, `rejoindre(code: String) -> Error`, `quitter()`, `pair() -> MultiplayerPeer` ; signaux `pret(code)` (chez l'hôte : la salle existe), `connecte()` (chez le client : canal ouvert, la poignée de main peut partir), `echec(raison)`. Ne sait rien du salon ni du jeu. »
- `TransportENet` (spec §3.1) : « gardé pour la version desktop de développement et les tests headless (les 13 scénarios réseau, le relais de latence). Jamais choisi dans l'export Web. Le « code » y est `ip:port`. »
- `Reseau` (spec §3.1) : « Ne nomme plus aucune classe ENet. »
- Canaux (spec §5) : « canal 0 en non fiable (commandes, états, battement […]) » ; `CANAL_ORDONNE` inchangé.
- Tests (spec §10) : « Le silence passe de 3 à 8 s à 10 s : les scénarios qui attendent un départ par silence (11 : client arraché) s'allongent d'autant. »
- Version et protocole (feuille de route) : « toute hausse de `config/version` renote `PROTOCOLE_EMPREINTE` (`tests/unitaires.gd`) » : **0.20**, empreinte mesurée sur ce plan appliqué à une copie du dépôt : `PROTOCOLE 0.20 322872843 (67 lignes)` après la Task 2, `PROTOCOLE 0.20 815376087 (68 lignes)` après la Task 4. Une autre valeur trahit un écart avec le code du plan : le retrouver avant de noter quoi que ce soit.
- Commandes : `export PATH="/opt/homebrew/bin:$PATH"` puis `cd ~/Sites/LeLion-web`, branche `phase-01-transport` ; chaque commande godot sous `timeout`, options écrites en clair (zsh ne découpe pas une variable non quotée : `--fixed-fps` sauterait en silence).
- Un test `--script` est compilé **avant** les autoloads : il récupère `Reseau` par `root.get_node("Reseau")`, ne le nomme jamais ; il peut nommer `Transport`, `TransportENet` et `EtatPartie` (aucun ne nomme d'autoload). Les tests qui lisent des textes posent `TranslationServer.set_locale("fr")` (déjà le cas de `joueur.gd`).
- Après la création d'un script à `class_name` : `godot --headless --import .` avant les tests (il génère le `.uid`, à committer avec le script).
- Les blocs « remplacer … par … » citent le texte exact laissé par la tâche précédente (vérifié en appliquant ce plan, tâche après tâche, à une copie de `main`) ; chacun se fait avec l'outil Edit (texte exact, une seule occurrence), dans l'ordre donné.
- Identifiants, commentaires et messages en français, docstrings `##`, tabulations. Aucune séquence `\u…` tapée dans un fichier ; après chaque écriture, `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh` ne sort rien. Aucun message de test ne contient `SCRIPT ERROR` ni `SHADER ERROR`.
- Bruit connu des sorties : « ObjectDB instances were leaked », « resources still in use at exit », les `ERROR` voulues des plans précédents, et désormais `ERROR: Couldn't create an ENet host.` (une fois de plus dans les unitaires : le port pris de `_tester_transport_enet`).
- Commits en français, terminés par :
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT
  ```

## Review Focus

1. **Un poste tué sans un mot** (KILL, Wi-Fi coupé, onglet fermé de force) : vu parti au bout des 10 s du battement, pas avant (ENet ne décide plus : `SILENCE_ENET`), et pas jamais (un pair dont l'ENet répond encore mais dont le jeu se tait). → unitaires « client muet » et « hôte muet » de `_tester_battement` (Task 2 : seul le battement peut les déclarer partis) ; scénario 11, `ECART_DEPART` de 8 500 à 11 000 ms (Task 2 : l'ancien code le voit en 3 à 8 s et échoue).
2. **Un poste lui-même figé** (chargement de la manche, compilation des shaders, gel) : aucun faux départ. → scénarios 9 (hôte figé 6,5 s au chargement, 30 s tolérés) et 10 (muet figé 10 s) ; unitaire « au sortir d'un gel de ce poste, le verdict attend une image » (Task 2).
3. **Un départ volontaire sous pertes** : l'adieu part avant la fermeture (`peer_disconnect_later`, jamais `peer_disconnect` qui vide la file), le DISCONNECT est renvoyé une seconde au plus, le processus n'en sort pas avant. → unitaires « l'adieu d'un client », « l'adieu de l'hôte » (adieu seul, silence de 30 s : seul l'adieu peut expliquer le départ) et « un client qui quitte » (Task 4) ; départ du transport seul (Task 1) ; scénario 1, départs vus en moins de 1 000 ms (Task 4) ; `joueur.gd` attend la fin du départ avant de sortir (Task 3) ; scénarios 12 et 13 sous le relais (5 % de pertes).
4. **Un pair figé ou mort à libérer** (exclusion de la barrière, I1 ; silence) : la libération n'attend aucun accusé de réception, `peer_disconnected` part pendant l'appel ; l'exclu vivant part de lui-même à l'annonce (fiable). → unitaire « un pair libéré qui ne répond plus part pendant l'appel » (Task 1) ; scénario 10, `ECART_EXCLUSION` sous 2 000 ms (mesuré 512 ms) ; scénario 9, le muet voit `RESEAU_EXCLU` (Task 2).
5. **Une session périmée qui parle encore** (transport ancien, signal différé, code refusé) : les signaux d'un transport sont liés à la génération de leur session (`_brancher`), plus aucun signal après `quitter()`, un code refusé ne ferme pas la session en cours, un port d'une session qui part encore se libère avant `heberger()`. → unitaires « quitter() pendant l'attente du canal : plus aucun signal ensuite » (Task 1), « une adresse refusée ne ferme pas la session en cours » et « héberger aussitôt après un départ en cours » (existants, Task 3), « la session passe par son transport », « Reseau ne nomme aucune classe d'ENet » (Task 3).

## Écarts assumés

1. **L'interface `Transport` a trois méthodes de plus que la spec** : `servir() -> bool` (le transport n'est pas un nœud : `Reseau` le sert à chaque image ; un transport quitté doit finir son départ hors de `SceneMultiplayer`, et `TransportWebRTC` devra relever sa signalisation), `liberer(id)` (chez l'hôte, fermer le canal d'un pair muet, exclu ou parti sans attendre de réponse est propre à chaque transport : ENet attend un accusé de réception qu'un pair figé n'envoie jamais), `clore()` (fermer tout de suite, pour libérer le port d'une session qui part encore avant `heberger()`). `quitter()` garde le nom de la spec et prend le sens de son §5 (fermeture après l'envoi de la file, en arrière-plan). La spec §3.1 est mise à jour (Task 5).
2. **« Tout paquet reçu » = tout paquet de `Reseau`** (battement et RPC de `Reseau`) : `SceneMultiplayer` (Godot 4.7.2, vérifié dans `ClassDB` et dans `modules/multiplayer/scene_multiplayer.cpp` au tag `4.7.2-stable`) ne donne ni l'heure de réception par pair, ni un signal par RPC reçue (`peer_packet` ne sert que `send_bytes`). Observer aussi les RPC de la manche et les `MultiplayerSynchronizer` demanderait un `MultiplayerPeerExtension` enveloppant le pair du transport (un appel de script par paquet, et `Decouverte` lit encore `ENetMultiplayerPeer.host`) : rejeté. Un battement par seconde suffit : 10 s de silence, c'est dix battements perdus de suite (à 8 % de pertes, environ 10⁻¹¹).
3. **Le silence se mesure à l'horloge murale** (`Time.get_ticks_msec`), comme le faisait ENet ; passer de 30 s à 10 s compte le silence déjà écoulé (comme `set_timeout` d'ENet). Pour qu'un poste qui sort lui-même d'un gel (une image de plus de `GEL_LOCAL` = 250 ms) ne déclare pas partis des pairs dont les paquets attendent encore d'être relevés (`SceneTree` relève les paquets avant les `_process`, mais un gel dans un `_process` passe avant celui de `Reseau`), son verdict attend une image.
4. **La libération d'un pair est immédiate et non fiable** (`peer_disconnect_now` puis `poll()` : `peer_disconnected` part pendant l'appel), au lieu du DISCONNECT fiable à silence raccourci (1 à 2 s) de la phase 14 (I1). Les cas où le pair libéré est vivant se passent de l'avertir : celui qui a dit adieu s'en va déjà ; l'exclu de la barrière **part de lui-même à l'annonce de son exclusion**, fiable (`_recevoir_exclusion` décide la perte de l'hôte, `PERTE_EXCLU`) ; l'hôte ne le libère que s'il est encore là `DELAI_EXCLUSION` plus tard (figé, il n'a pas lu l'annonce). Ce que la phase 7 reprendra pour l'exclusion depuis le salon.
5. **`Reseau.heberger(port)` et `Reseau.rejoindre(adresse, port)` gardent leur signature** : `EcranReseau`, `Salon`, `smoke_test`, `screenshots`, `deux_fenetres` et `joueur.gd` les appellent ; `rejoindre` en fait le code `adresse:port` de `TransportENet`. L'écran En ligne (phase 3) passera au code de salle ; `Reseau.code_partie` (le code donné par `pret`) l'y attend.
6. **Les délais de connexion d'un client se partagent** : le transport tient l'ouverture du canal (`TransportENet.DELAI_CANAL`, 5 s, puis `echec`), `Reseau` la poignée de main une fois le canal ouvert (`DELAI_CONNEXION`, 5 s, à partir de `connecte`). Hors cas d'erreur, rien ne change (sans hôte : échec à 5 s, comme avant) ; `TransportWebRTC` y mettra ses 15 s (spec §9) sans toucher `Reseau`.
7. **Le code d'un hôte ENet est `127.0.0.1:port`** (ce poste vu de lui-même) : ENet écoute sur toutes les interfaces et ne sait pas laquelle les autres joindront ; le salon affiche déjà les adresses de l'hôte (`Decouverte.adresses_hote`).
8. **Fichiers : 11 au lieu des 5 de la feuille de route** (le plafond du §12 de la spec) : il faut aussi `project.godot` (la version), `Scripts/Decouverte.gd` (`adresse_ipv4` déménage, Découverte délègue), `tests/reseau/lancer.sh` (bornes des scénarios 1, 10, 11), la spec et le README (Task 5), la feuille de route (Task 6). Chaque tâche touche 5 fichiers de code au plus.
9. **Step 0 : rien à retirer de `Reseau.gd`** (vérifié, Task 0) : chaque identifiant déclaré est cité ailleurs, aucun `print`, les quatre `push_warning` / `push_error` sont des diagnostics voulus (tables illisibles, fiches incohérentes), `joueur_arrive` n'a d'écouteur que le test réseau mais fait partie de l'interface (l'hôte y voit ses arrivées). Le préchargement `_Decouverte` ne devient mort qu'avec la Task 3, qui le retire.
10. **CI** : le pas « Test réseau » a pris 175 s sur la dernière CI (`timeout 300`) et 172 s sur ce Mac ; ce plan appliqué à une copie, 172 à 180 s sur ce Mac (+4 s au scénario 11 ; le reste inchangé, grâce à l'adieu et à l'attente de la fin du départ dans `joueur.gd`). Aucune option de test pour raccourcir le silence n'est nécessaire.

---

### Task 0 : préparation, Step 0 et référence

Ce plan est commité par le commit de planification : ne pas le recommiter, ne jamais le modifier.

- [ ] **Step 1 : la branche**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
git switch main && git pull --ff-only && git switch -c phase-01-transport
git log --oneline -1; wc -l Scripts/Reseau.gd; grep -n 'config/version' project.godot
```

Expected : `main` contient la fusion de la PR #1 ; `977 Scripts/Reseau.gd` ; `config/version="0.19"`. Sinon, s'arrêter et le signaler.

- [ ] **Step 2 : Step 0 (règle du projet, `Reseau.gd` fait plus de 300 lignes)**

```bash
f=Scripts/Reseau.gd
for n in $(grep -oE "^(const|var|func|static func|signal|enum) [A-Za-z_]+" $f | awk '{print $NF}'); do
	[ "$(grep -rwo "$n" Scripts tests Scenes | wc -l | tr -d ' ')" -lt 2 ] && echo "seul : $n"
done
grep -nE "^[[:space:]]*(print|prints|printt|print_debug|breakpoint)\b" $f
for s in joueur_arrive joueur_parti scene_chargee inscrit refuse connexion_echouee hote_perdu salon_change manche_lancee salon_rouvert; do
	echo "$s : $(grep -rln "$s\.connect" Scripts tests | tr '\n' ' ')"
done
```

Expected (mesuré) : aucune ligne `seul :`, aucun `print` ; chaque signal a au moins un écouteur (`joueur_arrive` : `tests/reseau/joueur.gd` seulement, gardé : voir l'écart 9). Rien à retirer : **pas de commit de nettoyage**. Si une ligne `seul :` ou un `print` apparaît (le code a bougé depuis ce plan), le retirer dans un commit à part (`Reseau : Step 0, code mort retiré`) avant la Task 1.

- [ ] **Step 3 : la référence du test réseau**

```bash
SECONDS=0; DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r0.log" 2>&1; echo "code $? en ${SECONDS} s"
grep -E "❌|== |\(I1\)|départ arraché" "$TMPDIR/r0.log"
```

Expected : `code 0`, `== 0 échec(s) ==`, environ 170 s ; le départ arraché vu en 3 000 à 8 000 ms (mesuré 5 388 ms), l'écart exclusion → barrière sous 2 000 ms (mesuré 846 ms). Noter les trois valeurs pour la PR (jamais commitées).

---

### Task 1 : l'interface `Transport` et le transport ENet, seuls

**Files:**
- Create: `Scripts/Transport.gd` (+ `.uid` généré par l'import)
- Create: `Scripts/TransportENet.gd` (+ `.uid`)
- Modify: `Scripts/Decouverte.gd:396-416` (`adresse_ipv4` délègue à `TransportENet`)
- Test: `tests/unitaires.gd` (`_run`, nouvelles `_tester_transport_enet` et `_servir_transports` avant `_fichiers_du_dossier`)

**Interfaces:**
- Consumes : `EtatPartie.NB_JOUEURS_MAX` ; `ENetMultiplayerPeer`, `ENetPacketPeer` (Godot 4.7.2).
- Produces (Tasks 2 à 4) :
  - `Transport` (`@abstract class_name Transport extends RefCounted`) : `signal pret(code: String)`, `signal connecte()`, `signal echec(raison: String)` ; `const ECHEC_DELAI := "delai"` ; `func heberger() -> Error`, `func rejoindre(code: String) -> Error`, `func quitter() -> void`, `func clore() -> void`, `func pair() -> MultiplayerPeer`, `func liberer(id: int) -> void`, `func servir() -> bool`.
  - `TransportENet` (`extends Transport`) : `func _init(port := PORT, places := EtatPartie.NB_JOUEURS_MAX)` ; `const PORT := 7777`, `ADRESSE_LOCALE := "127.0.0.1"`, `CONNEXIONS_EN_TROP := 2`, `DELAI_CANAL := 5.0`, `DELAI_DEPART := 1000`, `ESSAIS_SILENCE := 32`, `SILENCE_ENET := Vector2i(45000, 60000)` ; `var delai_canal := DELAI_CANAL` ; `static func lire_code(code: String) -> Dictionary` (`{"ip": String, "port": int}` ou `{}`) ; `static func adresse_ipv4(texte: String) -> String`.
  - `Decouverte.adresse_ipv4(texte)` inchangée pour ses appelants (elle délègue).

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_manches_enchainees()
	_tester_protocole()
```

par :

```gdscript
	_tester_manches_enchainees()
	_tester_transport_enet()
	_tester_protocole()
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
## Les fichiers du dossier `dossier` qui finissent par `suffixe`, triés.
```

par :

```gdscript
## Phase 1 du jeu en ligne : le transport ENet, seul (sans `Reseau` ni `SceneMultiplayer`) : son code,
## l'ouverture du canal, le délai d'un client sans hôte, la libération d'un pair figé (I1), le départ
## (DISCONNECT après la file, servi par `servir()`), la fermeture immédiate.
func _tester_transport_enet() -> void:
	print("-- Transport ENet (phase 1)")
	_check(TransportENet.lire_code(" 127.000.0.1 :17785") == {"ip": "127.0.0.1", "port": 17785}
		and TransportENet.lire_code("192.168.1.10") == {"ip": "192.168.1.10", "port": TransportENet.PORT},
		"un code ENet : une IPv4 normalisée et son port, ou le port par défaut")
	var mauvais := ["", "lelion.local:7777", "192.168.1:7777", "::1", "[::1]:7777", "127.0.0.1:", "127.0.0.1:0",
		"127.0.0.1:65536", "127.0.0.1:77a", "127.0.0.1:-5", "127.0.0.1:1:2", "0.0.0.0:7777"]
	_check(mauvais.all(func(c: String) -> bool: return TransportENet.lire_code(c).is_empty()),
		"refusés : un nom d'hôte, une IPv4 incomplète ou injoignable, une IPv6, un port vide, nul, trop grand ou non numérique")
	var refuse := TransportENet.new()
	_check(refuse.rejoindre("lelion.local") == ERR_INVALID_PARAMETER and refuse.pair() == null and not refuse.servir(),
		"un code refusé n'ouvre rien (aucune résolution de nom)")

	var port := 17785
	var hote := TransportENet.new(port, 2)
	var codes: Array[String] = []
	hote.pret.connect(func(code: String) -> void: codes.append(code))
	_check(hote.heberger() == OK and codes == ["127.0.0.1:%d" % port] and hote.pair() is ENetMultiplayerPeer and hote.servir(),
		"l'hôte ouvre sa session : « pret » part avec le code de ce poste (%s)" % [codes])
	var occupe := TransportENet.new(port, 2)
	_check(occupe.heberger() != OK and occupe.pair() == null, "un port déjà pris : l'erreur d'ENet, rien d'ouvert (ligne ERROR attendue)")
	var connectes: Array[int] = []
	var partis: Array[int] = []
	hote.pair().peer_connected.connect(func(id: int) -> void: connectes.append(id))
	hote.pair().peer_disconnected.connect(func(id: int) -> void: partis.append(id))

	var fige := TransportENet.new()
	var ouverts := [0]
	fige.connecte.connect(func() -> void: ouverts[0] += 1)
	_check(fige.rejoindre("127.0.0.1:%d" % port) == OK, "(pré-condition) un client part vers l'hôte")
	_check(_servir_transports([hote, fige], func() -> bool: return ouverts[0] == 1 and connectes.size() == 1, 2.0),
		"le canal s'ouvre : « connecte » chez le client, le pair chez l'hôte")
	# I1 : le client ne répond plus du tout (ni servi ni relevé) ; l'hôte le libère : il part sur-le-champ
	hote.liberer(connectes[0])
	_check(partis == [connectes[0]], "un pair libéré qui ne répond plus part pendant l'appel, sans accusé de réception (I1)")
	fige.clore()
	_check(fige.pair() == null and not fige.servir(), "clore() ferme tout de suite")

	var partant := TransportENet.new()
	partant.rejoindre("127.0.0.1:%d" % port)
	_check(_servir_transports([hote, partant], func() -> bool: return connectes.size() == 2, 2.0), "(pré-condition) un autre client est connecté")
	partant.quitter()
	_check(partant.servir() and partant.pair() != null, "quitter() : le départ part en arrière-plan, servi par servir()")
	var depart_a := Time.get_ticks_msec()
	_check(_servir_transports([hote, partant], func() -> bool: return partis.size() == 2 and partant.pair() == null, 1.5),
		"l'hôte reçoit le départ ; le client se ferme une fois le départ reçu (%d ms)" % (Time.get_ticks_msec() - depart_a))

	var seul := TransportENet.new()
	seul.delai_canal = 0.3
	var echecs: Array[String] = []
	seul.echec.connect(func(raison: String) -> void: echecs.append(raison))
	_check(seul.rejoindre("127.0.0.1:%d" % (port + 1)) == OK, "(pré-condition) un client part vers un port sans hôte")
	_servir_transports([seul], func() -> bool: return not echecs.is_empty(), 1.0)
	_check(echecs == [Transport.ECHEC_DELAI], "sans hôte : « echec » (délai du canal) (%s)" % [echecs])
	seul.quitter()
	var muet := TransportENet.new()
	muet.delai_canal = 0.1
	muet.echec.connect(func(raison: String) -> void: echecs.append(raison))
	muet.rejoindre("127.0.0.1:%d" % (port + 1))
	muet.quitter()
	_servir_transports([muet], func() -> bool: return false, 0.3)
	_check(echecs.size() == 1 and muet.pair() == null and seul.pair() == null,
		"quitter() pendant l'attente du canal : fermé aussitôt, plus aucun signal ensuite")
	hote.quitter()
	_check(not hote.servir() and hote.pair() == null, "un hôte sans client connecté se ferme aussitôt")


## Sert les transports `transports` (leur pair relevé, `servir()`) jusqu'à ce que `condition` soit
## vraie, `delai` secondes au plus ; renvoie sa dernière valeur.
func _servir_transports(transports: Array, condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		for t: Transport in transports:
			var p := t.pair()
			if p != null and p.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
				p.poll()
			t.servir()
		OS.delay_msec(5)
	return condition.call()


## Les fichiers du dossier `dossier` qui finissent par `suffixe`, triés.
```

- [ ] **Step 2 : ils échouent**

```bash
timeout 120 godot --headless --import . > "$TMPDIR/import.log" 2>&1
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"
grep -E "❌|SCRIPT ERROR|Parse Error|== " "$TMPDIR/u.log" | head
```

Expected : `SCRIPT ERROR: Parse Error: Identifier "TransportENet" not declared in the current scope.` (plusieurs fois), aucune ligne `== n échec(s) ==` (le script ne compile pas : le code de sortie peut être 0).

- [ ] **Step 3 : l'interface**

Créer `Scripts/Transport.gd` :

```gdscript
@abstract
class_name Transport
extends RefCounted
## Le transport d'une session (spec §3.1) : ce qui ouvre et ferme les canaux entre l'hôte et ses
## clients, sous le `MultiplayerPeer` que `Reseau` donne à `SceneMultiplayer`. Ne sait rien du salon
## ni du jeu : la poignée de main, la table, le battement et les départs restent dans `Reseau`.
## Deux implémentations : `TransportENet` (desktop de développement, tests headless), puis
## `TransportWebRTC` (l'export Web, phase 4).
##
## Contrat commun : `heberger()` ou `rejoindre()` une seule fois par objet ; `servir()` à chaque
## image tant qu'il renvoie vrai (session ouverte, ou départ en cours après `quitter()`) ; après
## `quitter()` ou `clore()`, plus aucun signal.

## Chez l'hôte : la session existe, `code` est ce qu'un client donne à `rejoindre()`.
signal pret(code: String)
## Chez un client : le canal vers l'hôte est ouvert, la poignée de main de `SceneMultiplayer` peut
## partir.
signal connecte()
## Chez un client : le canal ne s'ouvrira pas ; `raison` est une des constantes ECHEC_*.
signal echec(raison: String)

## Le canal vers l'hôte ne s'est pas ouvert dans le délai du transport.
const ECHEC_DELAI := "delai"


## Ouvre une session hébergée ; `pret` part quand elle existe (pendant l'appel ou plus tard, selon le
## transport). Une erreur laisse ce transport inutilisable, sans rien d'ouvert.
@abstract func heberger() -> Error


## Rejoint l'hôte désigné par `code` ; `connecte` ou `echec` suit. Un code mal formé :
## ERR_INVALID_PARAMETER, sans rien tenter.
@abstract func rejoindre(code: String) -> Error


## Ferme la session après l'envoi de ce qui est en file (l'adieu de `Reseau` compris), en arrière-plan,
## une seconde au plus : `servir()` renvoie vrai jusqu'à la fermeture.
@abstract func quitter() -> void


## Ferme tout de suite, sans rien attendre (un départ en cours est abandonné, un port se libère).
@abstract func clore() -> void


## Le pair que `Reseau` donne à `SceneMultiplayer` (null avant `heberger()` / `rejoindre()` réussis,
## et après la fermeture).
@abstract func pair() -> MultiplayerPeer


## Chez l'hôte : ferme tout de suite le canal du pair connecté `id` (parti, muet ou exclu), sans
## attendre de réponse (un pair mort ou figé n'en enverra pas) ; son `peer_disconnected` part pendant
## l'appel. Le pair n'en est prévenu qu'au mieux (il s'en ira de lui-même ou l'apprendra par le silence
## de l'hôte).
@abstract func liberer(id: int) -> void


## Une image de service (délais, départ en cours) ; faux une fois le transport fermé, quand `Reseau`
## peut l'oublier.
@abstract func servir() -> bool
```

- [ ] **Step 4 : le transport ENet**

Créer `Scripts/TransportENet.gd` :

```gdscript
class_name TransportENet
extends Transport
## Le transport ENet (UDP) de LeLion-multi, extrait de `Reseau` (phase 1) : gardé pour la version
## desktop de développement et les tests headless (scénarios réseau, relais de latence), jamais choisi
## dans l'export Web. Son code est `ip:port` (une IPv4 seulement, M8 : un nom d'hôte serait résolu par
## `create_client` en bloquant le jeu, plusieurs secondes sous Windows pour une faute de frappe), ou
## une IPv4 seule pour le port PORT.
##
## Silences : `Reseau` décide seul qu'un pair est parti (son battement : 10 s, 30 s au chargement).
## ENet n'abandonne donc lui-même un pair connecté qu'au-delà (SILENCE_ENET). Un pair libéré
## (`liberer`) est fermé sur-le-champ (`peer_disconnect_now` : un seul DISCONNECT, non fiable), sans
## attendre un accusé de réception qu'un pair mort ou figé n'enverra jamais (I1, revue finale de la
## phase 14).
##
## Départ (`quitter`, M6) : chaque pair connecté reçoit un DISCONNECT fiable après ce qui est encore
## en file (`peer_disconnect_later` : l'adieu de `Reseau` part d'abord, là où `peer_disconnect` vide
## la file), renvoyé jusqu'à son accusé de réception, DELAI_DEPART au plus, servi par `servir()`.
## `close()` seul n'enverrait qu'un datagramme non fiable.

const PORT := 7777
## L'adresse du code annoncé par `pret` : celle de ce poste vu de lui-même (les tests, le
## développement sur un seul PC) ; les autres postes du réseau local prennent une des adresses que le
## salon affiche.
const ADRESSE_LOCALE := "127.0.0.1"
## Connexions ENet (`max_clients`) acceptées au-delà des places : l'hôte ne consomme pas de connexion
## vers lui-même, donc `places - 1` suffiraient aux vrais clients ; ce solde donne de quoi recevoir, et
## refuser explicitement, les demandes d'une partie déjà pleine au lieu de les laisser échouer sans
## explication côté ENet (N1 : la marge réelle est donc de CONNEXIONS_EN_TROP + 1).
const CONNEXIONS_EN_TROP := 2
## Délai d'ouverture du canal vers l'hôte, en secondes (spec §9 : 5 s puis message) ; au-delà,
## `echec(ECHEC_DELAI)`.
const DELAI_CANAL := 5.0
## Délai laissé à un départ volontaire pour être reçu (accusé de réception du DISCONNECT), en ms.
const DELAI_DEPART := 1000
## Essais de renvoi d'ENet avant de compter le silence (son défaut).
const ESSAIS_SILENCE := 32
## Silence d'un pair connecté au-delà duquel ENet l'abandonne lui-même (`ENetPacketPeer.set_timeout`,
## en ms : minimum, maximum) : bien au-delà du plus long silence de `Reseau` (30 s, au chargement),
## pour que ce soit toujours `Reseau` qui décide.
const SILENCE_ENET := Vector2i(45000, 60000)

## Délai d'ouverture du canal de ce transport (DELAI_CANAL ; les tests le raccourcissent).
var delai_canal := DELAI_CANAL

var _port: int
var _places: int
var _pair: ENetMultiplayerPeer
## Faux après `quitter()` ou `clore()` : plus aucun signal.
var _actif := false
## Chez un client : l'instant (ms) où l'attente du canal échoue ; -1 hors attente.
var _fin_canal := -1
## Pendant un départ : les pairs prévenus, et l'instant (ms) où le départ est clos quoi qu'il arrive
## (-1 hors départ).
var _prevenus: Array[ENetPacketPeer] = []
var _fin_depart := -1


## `port` : celui de la session hébergée (le code donne celui d'une session rejointe) ; `places` :
## les joueurs d'une partie hébergée, hôte compris.
func _init(port := PORT, places := EtatPartie.NB_JOUEURS_MAX) -> void:
	_port = port
	_places = places


func heberger() -> Error:
	var pair_hote := ENetMultiplayerPeer.new()
	var erreur := pair_hote.create_server(_port, _places + CONNEXIONS_EN_TROP)
	if erreur != OK:
		return erreur
	_ouvrir(pair_hote)
	pret.emit("%s:%d" % [ADRESSE_LOCALE, _port])
	return OK


func rejoindre(code: String) -> Error:
	var cible := lire_code(code)
	if cible.is_empty():
		return ERR_INVALID_PARAMETER
	var pair_client := ENetMultiplayerPeer.new()
	var erreur := pair_client.create_client(cible.ip, cible.port)
	if erreur != OK:
		return erreur
	_ouvrir(pair_client)
	_fin_canal = Time.get_ticks_msec() + int(delai_canal * 1000.0)
	return OK


func quitter() -> void:
	_actif = false
	_fin_canal = -1
	if _pair == null or _fin_depart >= 0:
		return
	var connexion := _pair.host
	if _pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED or connexion == null:
		clore()
		return
	_prevenus.clear()
	for p: ENetPacketPeer in connexion.get_peers():
		if p.get_state() == ENetPacketPeer.STATE_CONNECTED:
			_prevenus.append(p)
	if _prevenus.is_empty():
		clore()
		return
	for p in _prevenus:
		p.peer_disconnect_later()
	connexion.flush()
	_fin_depart = Time.get_ticks_msec() + DELAI_DEPART


func clore() -> void:
	_actif = false
	_fin_canal = -1
	_fin_depart = -1
	_prevenus.clear()
	if _pair != null:
		_pair.close()
		_pair = null


func pair() -> MultiplayerPeer:
	return _pair


func liberer(id: int) -> void:
	if _pair == null or _pair.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var paquet := _pair.get_peer(id)
	if paquet == null or not paquet.is_active():
		return
	paquet.peer_disconnect_now()  # sa place se libère tout de suite
	_pair.poll()  # ENet rend compte du pair fermé : `peer_disconnected` part maintenant


func servir() -> bool:
	if _fin_depart >= 0:
		# Hors de `SceneMultiplayer` (Reseau est déjà hors réseau) : ce transport sert son pair lui-même.
		if _pair.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			_pair.poll()
		var recus := _prevenus.all(func(p: ENetPacketPeer) -> bool: return p.get_state() == ENetPacketPeer.STATE_DISCONNECTED)
		if recus or Time.get_ticks_msec() >= _fin_depart:
			clore()
	elif _fin_canal >= 0 and Time.get_ticks_msec() >= _fin_canal:
		_fin_canal = -1
		echec.emit(ECHEC_DELAI)
	return _pair != null


## La cible d'un code `ip:port` ou `ip` (port PORT) : `{"ip": String, "port": int}`, l'IPv4 sous sa
## forme normale (`adresse_ipv4`) et un port de 1 à 65535 ; un dictionnaire vide pour tout autre texte.
static func lire_code(code: String) -> Dictionary:
	var morceaux := code.strip_edges().split(":")
	if morceaux.size() > 2:
		return {}
	var ip := adresse_ipv4(morceaux[0])
	var port := PORT
	if morceaux.size() == 2:
		var texte_port := morceaux[1].strip_edges()
		if texte_port.is_empty() or not texte_port.lstrip("0123456789").is_empty():
			return {}
		port = texte_port.to_int()
	if ip.is_empty() or port < 1 or port > 65535:
		return {}
	return {"ip": ip, "port": port}


## L'adresse IPv4 saisie `texte` sous sa forme normale (« 192.168.001.010 » → « 192.168.1.10 »), ou
## une chaîne vide si ce n'est pas une adresse joignable : quatre nombres de 0 à 255 d'un à trois
## chiffres, ni 0.x.x.x, ni multidiffusion ou réservée (224 et au-delà, 255.255.255.255 compris).
## Jamais de nom d'hôte : sa résolution bloquerait le thread principal (Windows : plusieurs
## secondes pour une faute de frappe).
static func adresse_ipv4(texte: String) -> String:
	var morceaux := texte.strip_edges().split(".")
	if morceaux.size() != 4:
		return ""
	var octets := PackedStringArray()
	for morceau in morceaux:
		if morceau.is_empty() or morceau.length() > 3 or not morceau.lstrip("0123456789").is_empty():
			return ""
		var valeur := morceau.to_int()
		if valeur > 255:
			return ""
		octets.append(str(valeur))
	var premier := octets[0].to_int()
	if premier == 0 or premier >= 224:
		return ""
	return ".".join(octets)


func _ouvrir(pair_ouvert: ENetMultiplayerPeer) -> void:
	_pair = pair_ouvert
	_actif = true
	_pair.peer_connected.connect(_sur_pair_connecte)


## Un pair ENet se connecte (chez l'hôte, avant sa poignée de main ; chez un client, l'hôte) : son
## silence toléré par ENet devient SILENCE_ENET ; chez un client, le canal est ouvert.
func _sur_pair_connecte(id: int) -> void:
	_pair.get_peer(id).set_timeout(ESSAIS_SILENCE, SILENCE_ENET.x, SILENCE_ENET.y)
	if _fin_canal >= 0:
		_fin_canal = -1
		if _actif:
			connecte.emit()
```

- [ ] **Step 5 : `Decouverte` délègue la validation des adresses**

Dans `Scripts/Decouverte.gd`, remplacer :

```gdscript
## L'adresse IPv4 saisie `texte` sous sa forme normale (« 192.168.001.010 » → « 192.168.1.10 »), ou
## une chaîne vide si ce n'est pas une adresse joignable : quatre nombres de 0 à 255 d'un à trois
## chiffres, ni 0.x.x.x, ni multidiffusion ou réservée (224 et au-delà, 255.255.255.255 compris).
## Jamais de nom d'hôte : sa résolution bloquerait le thread principal (Windows : plusieurs
## secondes pour une faute de frappe).
static func adresse_ipv4(texte: String) -> String:
	var morceaux := texte.strip_edges().split(".")
	if morceaux.size() != 4:
		return ""
	var octets := PackedStringArray()
	for morceau in morceaux:
		if morceau.is_empty() or morceau.length() > 3 or not morceau.lstrip("0123456789").is_empty():
			return ""
		var valeur := morceau.to_int()
		if valeur > 255:
			return ""
		octets.append(str(valeur))
	var premier := octets[0].to_int()
	if premier == 0 or premier >= 224:
		return ""
	return ".".join(octets)
```

par :

```gdscript
## L'adresse IPv4 saisie `texte` sous sa forme normale, ou une chaîne vide (voir
## `TransportENet.adresse_ipv4`, qui la porte depuis la phase 1 : le code d'une partie ENet).
static func adresse_ipv4(texte: String) -> String:
	return TransportENet.adresse_ipv4(texte)
```

- [ ] **Step 6 : ils passent**

```bash
timeout 120 godot --headless --import . > "$TMPDIR/import.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$TMPDIR/import.log"
ls Scripts/Transport.gd.uid Scripts/TransportENet.gd.uid
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"
grep -E "❌|SCRIPT ERROR|== |PROTOCOLE" "$TMPDIR/u.log"; sed -n '/Transport ENet (phase 1)/,/Version du protocole/p' "$TMPDIR/u.log" | grep -E "✅|❌"
```

Expected : rien à l'import ; les deux `.uid` existent ; `code 0`, `== 0 échec(s) ==`, `PROTOCOLE 0.19 2537463811 (66 lignes)` (le protocole ne change pas : `Transport` n'a aucune RPC) ; les 16 vérifications du transport en ✅ (mesuré : départ reçu en 14 à 20 ms).

- [ ] **Step 7 : Commit**

```bash
git add Scripts/Transport.gd Scripts/Transport.gd.uid Scripts/TransportENet.gd Scripts/TransportENet.gd.uid Scripts/Decouverte.gd tests/unitaires.gd
git commit -m "Transport : l'interface d'un transport (héberger, rejoindre, quitter, clore, libérer, servir ; prêt, connecté, échec) ; TransportENet : le transport ENet, code ip:port, silence d'ENet repoussé derrière le battement, départ après la file, libération immédiate (I1) ; Decouverte délègue adresse_ipv4 ; tests unitaires

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 2 : le battement et les silences dans `Reseau` (version 0.20)

`Reseau` garde encore ici son pair ENet (la Task 3 le déménage) : seuls changent les silences, la libération d'un pair et l'exclusion. Les blocs ENet de cette tâche (`_reculer_silence_enet`, le corps de `_liberer`) sont ceux que la Task 3 remplace par le transport.

**Files:**
- Modify: `Scripts/Reseau.gd` (en-tête l. 16-21 ; constantes l. 118-127 et 111-113 ; `silence` l. 196-198 ; variables après `_exclu` l. 213-215 ; `quitter` l. 298 ; `_process` l. 331-334 ; `definir_silence` l. 350-359 ; `exclure`, `_deconnecter`, `_recevoir_exclusion` l. 362-389 ; RPC des clients et de l'hôte l. 749-838 ; `_sur_pair_connecte`, `_sur_pair_deconnecte`, `_sur_connecte_a_l_hote` l. 919-937)
- Modify: `project.godot:18` (`config/version="0.20"`)
- Test: `tests/unitaires.gd` (version, `_run`, nouvelles `_tester_battement` et `_attendre`)
- Test: `tests/reseau/lancer.sh` (scénarios 10 et 11), `tests/reseau/joueur.gd` (commentaire du rôle bout-hôte)

**Interfaces:**
- Consumes : rien de la Task 1 (le transport n'est branché qu'en Task 3).
- Produces :
  - `Reseau.PERIODE_BATTEMENT := 1.0`, `SILENCE_SESSION := 10.0`, `SILENCE_CHARGEMENT := 30.0` (des secondes, en `float`), `GEL_LOCAL := 250` (ms) ; `var silence: float` ; `func definir_silence(secondes: float) -> void` (les appels de `Manche.gd` restent valables tels quels) ;
  - `static func pairs_muets(entendus: Dictionary[int, int], maintenant: int, silence_ms: int) -> Array[int]` ;
  - `var _entendus: Dictionary[int, int]`, `var _derniere_ecoute: int`, `func _battre(maintenant: int)`, `func _ecouter(maintenant: int)`, `func _entendre(id: int)`, `func _liberer(id: int, generation: int)` (lus et appelés par les tests) ;
  - RPC `_battement()` (`any_peer`, `call_remote`, `unreliable`, canal 0) ;
  - `_recevoir_exclusion()` : l'exclu décide lui-même la perte de l'hôte (`PERTE_EXCLU`).

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_transport_enet()
	_tester_protocole()
```

par :

```gdscript
	_tester_transport_enet()
	await _tester_battement()
	_tester_protocole()
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
const PROTOCOLE_VERSION := "0.19"
const PROTOCOLE_EMPREINTE := 2537463811
```

par :

```gdscript
const PROTOCOLE_VERSION := "0.20"
const PROTOCOLE_EMPREINTE := 322872843
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
## Sert les transports `transports`
```

par :

```gdscript
## Phase 1 du jeu en ligne : le battement et les silences de `Reseau`, d'abord en logique pure, puis
## entre l'autoload, hôte, et un second poste client dans ce même processus : un second `Reseau` (le
## script chargé : l'autoload n'est pas nommé) sous sa propre `SceneMultiplayer`, posée par
## `set_multiplayer` sur un nœud à lui (le `SceneTree` la relève aussi). Les silences y sont raccourcis
## (`definir_silence`) ; un poste se tait par `set_process(false)` (plus de battement, mais sa
## `SceneMultiplayer` et son ENet tournent encore : seul le battement peut le déclarer parti).
func _tester_battement() -> void:
	print("-- Battement et silences (phase 1)")
	var hote: Node = root.get_node("Reseau")  # autoload : jamais nommé (compilé avant lui)
	var entendus: Dictionary[int, int] = {12: 2400, 5: 1000, 9: 4000}
	_check(hote.pairs_muets(entendus, 4500, 2000) == [5, 12] and hote.pairs_muets(entendus, 3000, 2000).is_empty()
		and hote.pairs_muets(entendus, 3001, 2000) == [5],
		"un pair est muet au-delà du silence toléré, pas à sa limite, dans l'ordre des identifiants (%s)" % [hote.pairs_muets(entendus, 4500, 2000)])
	var port := 17786
	_check(hote.heberger(port) == OK, "(pré-condition) ce poste héberge")
	var maintenant := Time.get_ticks_msec()
	hote._entendus[77] = maintenant - 20000  # un pair muet depuis 20 s (inconnu de SceneMultiplayer)
	hote._derniere_ecoute = maintenant - 2000  # ce poste sort lui-même d'un gel de 2 s
	hote._ecouter(maintenant)
	var suspendu: bool = hote._entendus.has(77)
	hote._ecouter(maintenant + 16)
	_check(suspendu and not hote._entendus.has(77),
		"au sortir d'un gel de ce poste, le verdict attend une image (ce qu'il a reçu pendant le gel n'est pas encore relevé), puis tombe")
	hote.quitter()

	var noeud := Node.new()
	noeud.name = "PosteClient"
	root.add_child(noeud)
	var chemin := noeud.get_path()
	set_multiplayer(SceneMultiplayer.new(), chemin)
	var client: Node = load("res://Scripts/Reseau.gd").new()
	client.name = "Reseau"  # vu de sa propre API, au même chemin que l'autoload : les RPC s'y retrouvent
	noeud.add_child(client)
	var arrives: Array[int] = []
	var partis: Array[int] = []
	var pertes: Array[String] = []
	var sur_arrivee := func(id: int) -> void: arrives.append(id)
	var sur_depart := func(id: int) -> void: partis.append(id)
	var sur_perte := func() -> void: pertes.append(client.raison_perte)
	hote.joueur_arrive.connect(sur_arrivee)
	hote.joueur_parti.connect(sur_depart)
	client.hote_perdu.connect(sur_perte)
	hote.pseudo = "Hôte"
	client.pseudo = "Client"

	# Le battement tient la session : chacun a entendu l'autre il y a moins d'une période et demie
	_check(hote.heberger(port) == OK and client.rejoindre("127.0.0.1", port) == OK, "(pré-condition) un hôte et un client dans ce processus")
	_check(await _attendre(func() -> bool: return arrives.size() == 1 and client._entendus.has(1), 3.0), "(pré-condition) le client est arrivé")
	var id_client: int = arrives[0] if arrives.size() == 1 else -1
	await create_timer(2.5).timeout
	var ecart_hote: int = Time.get_ticks_msec() - hote._entendus.get(id_client, 0)
	var ecart_client: int = Time.get_ticks_msec() - client._entendus.get(1, 0)
	_check(partis.is_empty() and pertes.is_empty() and ecart_hote <= 1500 and ecart_client <= 1500,
		"un battement par seconde : 2,5 s plus tard, l'hôte a entendu le client il y a %d ms, le client l'hôte il y a %d ms" % [ecart_hote, ecart_client])

	# Un client muet : l'hôte le déclare parti au bout du silence toléré, pas avant
	hote.definir_silence(1.5)
	client.set_process(false)
	var client_muet_depuis: int = hote._entendus.get(id_client, 0)
	_check(await _attendre(func() -> bool: return partis.size() == 1, 5.0), "l'hôte voit partir un client muet (son ENet répondait encore)")
	var vu_apres: int = Time.get_ticks_msec() - client_muet_depuis
	_check(partis == [id_client] and vu_apres >= 1500 and vu_apres <= 2500,
		"... %d ms après son dernier battement : son silence de 1,5 s, pas avant" % vu_apres)
	client.set_process(true)
	_check(await _attendre(func() -> bool: return pertes.size() == 1, 3.0) and not client.en_ligne(),
		"le client libéré se retrouve hors réseau, l'hôte perdu")

	# L'hôte muet : le client le déclare perdu au bout de son silence toléré
	_check(hote.heberger(port) == OK and client.rejoindre("127.0.0.1", port) == OK, "(pré-condition) le client rejoint de nouveau")
	_check(await _attendre(func() -> bool: return arrives.size() == 2 and client._entendus.has(1), 3.0), "(pré-condition) le client est de nouveau arrivé")
	client.definir_silence(1.5)
	hote.set_process(false)
	var hote_muet_depuis: int = client._entendus.get(1, 0)
	_check(await _attendre(func() -> bool: return pertes.size() == 2, 5.0), "le client perd un hôte muet")
	var perdu_apres: int = Time.get_ticks_msec() - hote_muet_depuis
	hote.set_process(true)
	_check(perdu_apres >= 1500 and perdu_apres <= 2500 and pertes.size() == 2 and pertes[1] == client.PERTE_HOTE and not client.en_ligne(),
		"... %d ms après son dernier battement (silence de 1,5 s) : « L'hôte a quitté la partie »" % perdu_apres)

	hote.quitter()
	client.quitter()
	await _attendre(func() -> bool: return hote._partants.is_empty() and client._partants.is_empty(), 2.0)
	hote.joueur_arrive.disconnect(sur_arrivee)
	hote.joueur_parti.disconnect(sur_depart)
	noeud.queue_free()
	set_multiplayer(null, chemin)
	hote.pseudo = ""


## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
## valeur.
func _attendre(condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		await process_frame
	return condition.call()


## Sert les transports `transports`
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
func _run() -> void:
	print("== tests unitaires LeLion ==")
```

par :

```gdscript
func _run() -> void:
	print("== tests unitaires LeLion ==")
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# 10. I1 (revue finale phase 14) : un muet dont le fil principal se fige tout entier (ENet muet,
#     comme un poste qui compile ses shaders) après le lancement de la manche. Le correctif
#     d'_exclure (silence ENet raccourci avant disconnect_peer, sans force) doit faire passer la
#     barrière bien avant le silence de chargement par défaut (20 à 30 s) : l'hôte chronomètre
#     lui-même l'écart entre l'exclusion et la barrière (--mesurer-exclusion, ECART_EXCLUSION en
#     ms). Aucune manche n'est jouée ici : les deux postes sont arrêtés dès la mesure prise.
```

par :

```bash
# 10. I1 (revue finale phase 14) : un muet dont le fil principal se fige tout entier (ENet muet,
#     comme un poste qui compile ses shaders) après le lancement de la manche. Sa libération
#     (`Reseau._liberer` : fermé sur-le-champ, sans attendre d'accusé de réception) doit faire passer
#     la barrière bien avant le silence de chargement (30 s) : l'hôte chronomètre lui-même l'écart
#     entre l'exclusion et la barrière (--mesurer-exclusion, ECART_EXCLUSION en ms). Aucune manche
#     n'est jouée ici : les deux postes sont arrêtés dès la mesure prise.
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
			|| echec "I1 : écart exclusion -> barrière de ${ecart:-?} ms (attendu bien sous 2000 ms : le correctif doit raccourcir le silence ENet du pair figé avant de le déconnecter)"
```

par :

```bash
			|| echec "I1 : écart exclusion -> barrière de ${ecart:-?} ms (attendu bien sous 2000 ms : la libération ne doit pas attendre l'accusé de réception du pair figé)"
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
#     un choc) ; puis le client qui tient le plus de territoire est arraché (KILL, sans un paquet de
#     plus) : l'hôte doit le voir partir au bout du silence de session d'ENet (SILENCE_SESSION, 3 à
#     8 s ; ECART_DEPART), son lion disparaître chez tous, ses cellules rester.
```

par :

```bash
#     un choc) ; puis le client qui tient le plus de territoire est arraché (KILL, sans un paquet de
#     plus) : l'hôte doit le voir partir au bout du silence de son battement (Reseau.SILENCE_SESSION,
#     10 s depuis le dernier battement reçu, 0 à 1 s avant l'arrachement ; ECART_DEPART), pas avant
#     (ENet ne décide plus), son lion disparaître chez tous, ses cellules rester.
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
[ -n "$ecart11" ] && [ "$ecart11" -le 10000 ] 2>/dev/null \
	|| echec "de bout en bout : départ arraché vu au bout de ${ecart11:-?} ms (attendu au plus 10000 : le silence de session d'ENet, 8 s au plus, et la marge d'une image)"
```

par :

```bash
[ -n "$ecart11" ] && [ "$ecart11" -ge 8500 ] && [ "$ecart11" -le 11000 ] 2>/dev/null \
	|| echec "de bout en bout : départ arraché vu au bout de ${ecart11:-?} ms (attendu de 8500 à 11000 : les 10 s du battement depuis son dernier, reçu 0 à 1 s avant l'arrachement, et la marge d'une image sous la charge de la CI)"
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	# Un client arraché en pleine manche (KILL : ni DISCONNECT ni aucun autre paquet), comme un PC
	# planté ou un Wi-Fi coupé : l'hôte le voit partir au bout du silence de session d'ENet.
```

par :

```gdscript
	# Un client arraché en pleine manche (KILL : ni DISCONNECT ni aucun autre paquet), comme un PC
	# planté ou un Wi-Fi coupé : l'hôte le voit partir au bout du silence de son battement (10 s).
```

- [ ] **Step 2 : ils échouent**

```bash
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"
grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u.log"
```

Expected : `code 1` ; `SCRIPT ERROR: Invalid call. Nonexistent function 'pairs_muets' in base 'Node (Reseau.gd)'.` ; `❌ la version (0.19) n'est plus celle que note ce test (0.20) …` ; `== 1 échec(s) ==`. (Le test réseau échouerait aussi au scénario 11, vu en 3 à 8 s : on ne le lance qu'au Step 5.)

- [ ] **Step 3 : le battement et les silences**

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Départs et silences (M6) : `quitter()` part proprement (un DISCONNECT fiable d'ENet, renvoyé
## jusqu'à son accusé de réception, DELAI_DEPART au plus, en arrière-plan : `_partants`), pas par
## un seul datagramme qu'une perte Wi-Fi ferait passer inaperçu ; un pair muet est considéré parti
## après SILENCE_SESSION (au lieu des 5 à 30 s d'ENet), sauf pendant le chargement de la manche
## (SILENCE_CHARGEMENT : un poste qui charge sa scène ou compile ses shaders ne répond plus). Le
## relais du serveur est coupé (`server_relay`) : tout passe par l'hôte.
```

par :

```gdscript
## Battement et silences (phase 1 du jeu en ligne) : chaque poste en session envoie un battement par
## seconde (`_battement`, non fiable) ; tout ce que ce script reçoit d'un pair, battement ou RPC, remet
## son silence à zéro (`_entendus`) ; SILENCE_SESSION sans rien de lui le déclare parti, chez l'hôte
## comme chez un client, SILENCE_CHARGEMENT pendant le chargement de la manche (un poste qui charge sa
## scène ou compile ses shaders ne répond plus). Chez l'hôte, un client muet ou exclu est libéré
## (`_liberer`) : son départ arrive par `peer_disconnected`, comme tous les départs. `quitter()` part
## proprement (M6 : un DISCONNECT fiable d'ENet, renvoyé jusqu'à son accusé de réception, DELAI_DEPART
## au plus, en arrière-plan : `_partants`), pas par un seul datagramme qu'une perte Wi-Fi ferait passer
## inaperçu. Le relais du serveur est coupé (`server_relay`) : tout passe par l'hôte.
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Silence d'un pair ENet au-delà duquel il est considéré parti (`ENetPacketPeer.set_timeout`, en
## millisecondes : minimum, maximum ; ENet le décide entre les deux selon le temps d'aller-retour).
## Au salon et en manche : un poste planté ou en veille part en 8 s au plus, au lieu des 5 à 30 s
## par défaut d'ENet.
const SILENCE_SESSION := Vector2i(3000, 8000)
## Pendant le chargement de la manche, du lancement à l'intro : un poste qui charge sa scène de jeu
## (ou compile ses shaders, sous Windows) ne répond plus, parfois plus de 5 s.
const SILENCE_CHARGEMENT := Vector2i(20000, 30000)
## Essais de renvoi d'ENet avant de compter le silence (son défaut).
const ESSAIS_SILENCE := 32
```

par :

```gdscript
## Période du battement, en secondes : chaque poste en session en envoie un à chacun de ses pairs.
const PERIODE_BATTEMENT := 1.0
## Silence d'un pair, en secondes, au-delà duquel il est déclaré parti (spec §2) : au salon et en
## manche, chez l'hôte comme chez un client (un poste planté, en veille, un onglet caché).
const SILENCE_SESSION := 10.0
## Pendant le chargement de la manche, du lancement à l'intro : un poste qui charge sa scène de jeu
## (ou compile ses shaders, sous Windows) ne répond plus, parfois plus de 5 s.
const SILENCE_CHARGEMENT := 30.0
## Une image plus longue que ce délai (ms) : ce poste était lui-même figé, et ce qu'il a reçu pendant
## ce temps ne sera relevé qu'à l'image suivante ; son verdict sur les silences attend jusque-là
## (`_ecouter`).
const GEL_LOCAL := 250
## Essais de renvoi d'ENet avant de compter le silence (son défaut).
const ESSAIS_SILENCE := 32
## Silence d'un pair au-delà duquel ENet l'abandonne lui-même (`ENetPacketPeer.set_timeout`, en ms :
## minimum, maximum) : bien au-delà de SILENCE_CHARGEMENT, pour que ce soit toujours le battement qui
## décide.
const SILENCE_ENET := Vector2i(45000, 60000)
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Silence toléré des pairs de cette session (SILENCE_SESSION ou SILENCE_CHARGEMENT), posé sur
## chaque pair connecté et sur chaque nouveau venu.
var silence := SILENCE_SESSION
```

par :

```gdscript
## Silence toléré des pairs de cette session, en secondes (SILENCE_SESSION ou SILENCE_CHARGEMENT).
var silence := SILENCE_SESSION
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
var _exclu := false
```

par :

```gdscript
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
var _exclu := false
## Les pairs dont ce poste écoute le silence : par identifiant, l'instant (ms) où il a reçu d'eux pour
## la dernière fois. Chez l'hôte, chaque client arrivé (sa poignée de main finie) ; chez un client,
## l'hôte, une fois inscrit. Vide hors réseau.
var _entendus: Dictionary[int, int] = {}
## L'instant (ms) du prochain battement de ce poste.
var _prochain_battement := 0
## L'instant (ms) de la dernière écoute des silences (`_ecouter`).
var _derniere_ecoute := 0
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	silence = SILENCE_SESSION
	niveau_salon = 0
```

par :

```gdscript
	silence = SILENCE_SESSION
	_entendus.clear()
	niveau_salon = 0
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Sert les départs en cours ; ferme ceux qui sont reçus ou dont le délai est passé.
func _process(_delta: float) -> void:
	if _partants.is_empty():
		return
	for partant
```

par :

```gdscript
## En session, le battement et l'écoute des silences ; puis les départs en cours, fermés une fois reçus
## ou leur délai passé.
func _process(_delta: float) -> void:
	if en_ligne():
		var maintenant := Time.get_ticks_msec()
		_battre(maintenant)
		_ecouter(maintenant)
	for partant
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Pose `bornes` (SILENCE_SESSION ou SILENCE_CHARGEMENT) comme silence toléré de chaque pair connecté
## de cette session, et de chaque nouveau venu (`silence`). Hors réseau, ne fait que le retenir.
func definir_silence(bornes: Vector2i) -> void:
	silence = bornes
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer and pair.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED \
			and pair.host != null:
		for p: ENetPacketPeer in pair.host.get_peers():
			if p.get_state() == ENetPacketPeer.STATE_CONNECTED:
				p.set_timeout(ESSAIS_SILENCE, bornes.x, bornes.y)
```

par :

```gdscript
## Le silence toléré des pairs de cette session devient `secondes` (SILENCE_SESSION ou
## SILENCE_CHARGEMENT). Le silence déjà écoulé compte : passer de SILENCE_CHARGEMENT à SILENCE_SESSION
## déclare parti à la prochaine écoute un pair muet depuis plus de SILENCE_SESSION.
func definir_silence(secondes: float) -> void:
	silence = secondes


## Le battement de ce poste, une fois par PERIODE_BATTEMENT : chez l'hôte, à chaque client arrivé ;
## chez un client, à l'hôte, une fois inscrit (avant, aucune RPC ne passe).
func _battre(maintenant: int) -> void:
	if maintenant < _prochain_battement:
		return
	_prochain_battement = maintenant + int(PERIODE_BATTEMENT * 1000.0)
	if multiplayer.is_server():
		if not multiplayer.get_peers().is_empty():
			_battement.rpc()
	elif _entendus.has(MultiplayerPeer.TARGET_PEER_SERVER):
		_battement.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


## L'écoute des silences, à `maintenant` (ms) : chez l'hôte, chaque client muet depuis plus de `silence`
## est libéré ; chez un client, l'hôte muet est perdu. Après une image plus longue que GEL_LOCAL, ce poste
## sort lui-même d'un gel : les paquets arrivés pendant ce temps ne sont relevés qu'à la prochaine image
## (`SceneTree` relève les paquets avant les `_process`), le verdict attend donc une image.
func _ecouter(maintenant: int) -> void:
	var ecart := maintenant - _derniere_ecoute
	_derniere_ecoute = maintenant
	if ecart > GEL_LOCAL:
		return
	for id in pairs_muets(_entendus, maintenant, int(silence * 1000.0)):
		_entendus.erase(id)
		if multiplayer.is_server():
			_liberer(id, _generation)
		else:
			_decider("hote_perdu")


## Les identifiants de `entendus` (identifiant → instant, en ms, du dernier paquet reçu) dont le silence
## dépasse `silence_ms` à `maintenant`, dans l'ordre croissant.
static func pairs_muets(entendus: Dictionary[int, int], maintenant: int, silence_ms: int) -> Array[int]:
	var muets: Array[int] = []
	for id: int in entendus:
		if maintenant - entendus[id] > silence_ms:
			muets.append(id)
	muets.sort()
	return muets


## Un paquet de `Reseau` reçu du pair `id` (battement ou RPC) : son silence repart de zéro. Sans effet
## pour un pair dont ce poste n'écoute pas le silence.
func _entendre(id: int) -> void:
	if _entendus.has(id):
		_entendus[id] = Time.get_ticks_msec()


## Le battement d'un pair (non fiable, canal 0 : spec §5).
@rpc("any_peer", "call_remote", "unreliable")
func _battement() -> void:
	_entendre(multiplayer.get_remote_sender_id())


## Pose SILENCE_ENET sur chaque pair ENet connecté, le nouveau venu compris : ENet ne doit jamais
## décider avant le battement.
func _reculer_silence_enet() -> void:
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer and pair.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED \
			and pair.host != null:
		for p: ENetPacketPeer in pair.host.get_peers():
			if p.get_state() == ENetPacketPeer.STATE_CONNECTED:
				p.set_timeout(ESSAIS_SILENCE, SILENCE_ENET.x, SILENCE_ENET.y)
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez l'hôte : le joueur `id` n'a pas chargé sa scène de jeu à temps (la barrière de la manche,
## `Manche._exclure`) : il apprend son exclusion (`_recevoir_exclusion` : il verra PERTE_EXCLU, pas
## « L'hôte a quitté la partie »), puis il est déconnecté DELAI_EXCLUSION plus tard (proprement : son
## départ arrive par `joueur_parti`). I1 (revue finale phase 14) : un pair figé (chargement,
## compilation des shaders) n'acquitte jamais ni l'annonce ni le DISCONNECT ; sans un silence court
## (1 à 2 s, posé tout de suite), ENet ne l'abandonnerait qu'à son silence de chargement
## (SILENCE_CHARGEMENT, 20 à 30 s), et la barrière l'attendrait tout ce temps.
func exclure(id: int) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	var pair := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if pair != null:
		pair.get_peer(id).set_timeout(ESSAIS_SILENCE, 1000, 2000)
	_recevoir_exclusion.rpc_id(id)
	get_tree().create_timer(DELAI_EXCLUSION, true).timeout.connect(_deconnecter.bind(id, _generation))


## Chez l'hôte : déconnecte l'exclu `id`, s'il l'est encore, dans la même session (`generation`).
func _deconnecter(id: int, generation: int) -> void:
	if generation == _generation and multiplayer.get_peers().has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)
```

par :

```gdscript
## Chez l'hôte : le joueur `id` n'a pas chargé sa scène de jeu à temps (la barrière de la manche,
## `Manche._exclure`) : il apprend son exclusion (`_recevoir_exclusion` : il verra PERTE_EXCLU, pas
## « L'hôte a quitté la partie ») et s'en va de lui-même ; DELAI_EXCLUSION plus tard, l'hôte le libère
## s'il est encore là (`_liberer` : figé, il n'a pas lu l'annonce) : son départ arrive par
## `joueur_parti`.
func exclure(id: int) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	_recevoir_exclusion.rpc_id(id)
	get_tree().create_timer(DELAI_EXCLUSION, true).timeout.connect(_liberer.bind(id, _generation))


## Chez l'hôte : libère le client `id` (muet ou exclu), s'il est encore là dans la même session
## (`generation`) : son silence n'est plus écouté, et son pair est fermé sur-le-champ, sans attendre
## d'accusé de réception (I1, revue finale phase 14 : un pair figé, qui charge ou compile ses shaders,
## ou mort n'en enverra pas) ; son départ part aussitôt par `peer_disconnected` (`_sur_pair_deconnecte`).
func _liberer(id: int, generation: int) -> void:
	if generation != _generation or not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	_entendus.erase(id)
	var pair := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var paquet := pair.get_peer(id) if pair != null else null
	if paquet != null and paquet.is_active():
		paquet.peer_disconnect_now()  # un seul DISCONNECT, non fiable : sa place se libère tout de suite
		pair.poll()  # ENet rend compte du pair fermé : `peer_disconnected` part maintenant
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez un client : l'hôte l'exclut de la manche (sa scène de jeu pas chargée à temps) ; la perte de
## l'hôte qui suit le dira (`raison_perte`).
@rpc("authority", "call_remote", "reliable")
func _recevoir_exclusion() -> void:
	_exclu = true
```

par :

```gdscript
## Chez un client : l'hôte l'exclut de la manche (sa scène de jeu pas chargée à temps) ; ce poste s'en va
## aussitôt, et la perte de l'hôte le dit (`raison_perte` : PERTE_EXCLU). L'annonce est fiable, la
## libération par l'hôte qui suit ne l'est pas (`_liberer`).
@rpc("authority", "call_remote", "reliable")
func _recevoir_exclusion() -> void:
	_entendre(multiplayer.get_remote_sender_id())
	_exclu = true
	_decider("hote_perdu")
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Entre l'annonce de son exclusion à un joueur et sa déconnexion, en secondes : le temps que
## l'annonce arrive, renvoyée au besoin par ENet (une déconnexion vide la file d'envoi).
```

par :

```gdscript
## Entre l'annonce de son exclusion à un joueur et sa libération par l'hôte, en secondes : le temps que
## l'annonce arrive (renvoyée au besoin), et que l'exclu s'en aille de lui-même.
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _demande_couleur(sens: Variant) -> void:
	if sens is int:
```

par :

```gdscript
func _demande_couleur(sens: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	if sens is int:
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _demande_pret(pret: Variant) -> void:
	if pret is bool:
```

par :

```gdscript
func _demande_pret(pret: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	if pret is bool:
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	if _poser_salon
```

par :

```gdscript
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	if _poser_salon
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _recevoir_manche(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	var fiches
```

par :

```gdscript
func _recevoir_manche(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	var fiches
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	if _poser_salon
```

par :

```gdscript
func _recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	if _poser_salon
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _scene_chargee() -> void:
	var id := multiplayer.get_remote_sender_id()
```

par :

```gdscript
func _scene_chargee() -> void:
	var id := multiplayer.get_remote_sender_id()
	_entendre(id)
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	if multiplayer.is_server() and inscrits.has(id):
		definir_silence(silence)  # le nouveau venu aussi
		inscrits[id].arrive = true
```

par :

```gdscript
	if multiplayer.is_server() and inscrits.has(id):
		_reculer_silence_enet()  # le nouveau venu aussi
		_entendus[id] = Time.get_ticks_msec()
		inscrits[id].arrive = true
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _sur_pair_deconnecte(id: int) -> void:
	if multiplayer.is_server() and inscrits.erase(id):
```

par :

```gdscript
func _sur_pair_deconnecte(id: int) -> void:
	_entendus.erase(id)
	if multiplayer.is_server() and inscrits.erase(id):
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _sur_connecte_a_l_hote() -> void:
	_delai.stop()
	definir_silence(silence)
```

par :

```gdscript
func _sur_connecte_a_l_hote() -> void:
	_delai.stop()
	_reculer_silence_enet()
	_entendus[MultiplayerPeer.TARGET_PEER_SERVER] = Time.get_ticks_msec()
```

- [ ] **Step 4 : la version**

Dans `project.godot`, remplacer :

```
config/version="0.19"
```

par :

```
config/version="0.20"
```

- [ ] **Step 5 : ils passent, le réseau aussi**

```bash
timeout 120 godot --headless --import . > "$TMPDIR/import.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$TMPDIR/import.log"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"
grep -E "❌|SCRIPT ERROR|== |PROTOCOLE" "$TMPDIR/u.log"; sed -n '/Battement et silences/,/Version du protocole/p' "$TMPDIR/u.log" | grep -E "✅|❌"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log" | tail -2
DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"
grep -E "❌|✅ |== |\(I1\)|départ arraché" "$TMPDIR/r.log"
```

Expected : `PROTOCOLE 0.20 322872843 (67 lignes)`, `== 0 échec(s) ==` (mesuré : le client muet vu 1 518 ms après son dernier battement, l'hôte muet 1 513 ms) ; smoke `== 0 échec(s) ==` ; test réseau `code 0`, `== 0 échec(s) ==`, écart exclusion → barrière d'environ 500 ms (mesuré 512 ms), départ arraché vu de 8 500 à 11 000 ms (mesuré 9 262 ms), environ 180 s.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Reseau.gd project.godot tests/unitaires.gd tests/reseau/lancer.sh tests/reseau/joueur.gd
git commit -m "Reseau : battement applicatif d'une seconde, silence de 10 s pour tous (30 s au chargement) au lieu des délais d'ENet, verdict suspendu au sortir d'un gel ; un pair muet ou exclu libéré sur-le-champ ; l'exclu part de lui-même à l'annonce ; version 0.20 ; scénario 11 vu entre 8,5 et 11 s

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 3 : `Reseau` passe par son transport

**Files:**
- Modify: `Scripts/Reseau.gd` (état laissé par la Task 2 : en-tête, constantes `PORT` à `CANAL_ORDONNE`, préchargement `_Decouverte`, variables `_issue_decidee` à `_connexion_en_cours`, de `heberger` à `_clore_partants`, `_reculer_silence_enet`, `_liberer`, `_repondre`, `_sur_pair_connecte`, `_sur_connecte_a_l_hote`, `_sur_hote_perdu`, `_sur_delai_depasse`, et trois gestionnaires neufs des signaux du transport)
- Test: `tests/unitaires.gd` (`_tester_reseau` : hébergement)
- Test: `tests/reseau/joueur.gd` (en-tête, fin de `_run`, `_jouer_hote`, rôle client « echec »)

**Interfaces:**
- Consumes (Task 1) : `Transport` (ses sept méthodes et trois signaux), `TransportENet.new(port, places)`, `TransportENet.PORT`, `TransportENet.DELAI_CANAL`.
- Produces :
  - `Reseau.PORT := TransportENet.PORT` (`EcranReseau.port_jeu` le lit) ; `heberger(port := PORT) -> Error` et `rejoindre(adresse: String, port := PORT) -> Error` inchangées pour leurs appelants ;
  - `var code_partie: String` (le code de `Transport.pret`, vide hors réseau) : l'écran En ligne et le salon de la phase 3 ;
  - `var _transport: Transport`, `var _partants: Array[Transport]` (lus par les tests), `var _connexion_en_cours: bool` ;
  - `func _nouveau_transport(port: int) -> Transport` (le choix du transport : la phase 4 y mettra `TransportWebRTC` sous `OS.has_feature("web")`) ;
  - `DELAI_CONNEXION` court désormais de `Transport.connecte` à l'inscription ;
  - `Reseau.gd` ne contient plus aucun nom de classe d'ENet (`\bENet[A-Z]\w*`), ni `CONNEXIONS_EN_TROP`, `ESSAIS_SILENCE`, `SILENCE_ENET`, `DELAI_DEPART`, `_partir`, `_reculer_silence_enet`, `_Decouverte` (tous dans `TransportENet`, ou inutiles).

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_check(reseau.heberger(port) == OK and reseau.en_ligne() and api.is_server() and reseau.inscrits.size() == 1
		and reseau.index_local == 0 and reseau.couleur_locale == palette[0] and reseau.inscrits[1].pseudo == "Hôte",
		"port libre : l'hôte écoute et s'inscrit lui-même (index 0, première couleur, son pseudo)")
	reseau.quitter()
	_check(not reseau.en_ligne() and api.multiplayer_peer is OfflineMultiplayerPeer and api.is_server()
		and reseau.inscrits.is_empty() and reseau.index_local == -1 and api.auth_callback.is_null(),
		"quitter revient hors réseau : pair hors ligne, hôte de soi-même, plus d'inscrits ni de poignée de main")
```

par :

```gdscript
	_check(reseau.heberger(port) == OK and reseau.en_ligne() and api.is_server() and reseau.inscrits.size() == 1
		and reseau.index_local == 0 and reseau.couleur_locale == palette[0] and reseau.inscrits[1].pseudo == "Hôte",
		"port libre : l'hôte écoute et s'inscrit lui-même (index 0, première couleur, son pseudo)")
	_check(reseau.code_partie == "127.0.0.1:%d" % port and reseau._transport is TransportENet
		and api.multiplayer_peer == reseau._transport.pair(),
		"phase 1 : la session passe par son transport (ENet), qui donne le code de la partie (%s)" % reseau.code_partie)
	reseau.quitter()
	_check(not reseau.en_ligne() and api.multiplayer_peer is OfflineMultiplayerPeer and api.is_server()
		and reseau.inscrits.is_empty() and reseau.index_local == -1 and api.auth_callback.is_null()
		and reseau.code_partie.is_empty() and reseau._transport == null,
		"quitter revient hors réseau : pair hors ligne, hôte de soi-même, plus d'inscrits, de poignée de main, de code ni de transport")
	var source_reseau := FileAccess.get_file_as_string("res://Scripts/Reseau.gd")
	var classes_enet := RegEx.create_from_string("\\bENet[A-Z]\\w*").search_all(source_reseau).map(func(r: RegExMatch) -> String: return r.get_string())
	_check(classes_enet.is_empty(), "phase 1 : Reseau ne nomme aucune classe d'ENet, tout passe par son transport (%s)" % [classes_enet])
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
			_check(_issue == "echec" and duree >= reseau.DELAI_CONNEXION - 0.5 and duree <= reseau.DELAI_CONNEXION + 2.0,
				"sans hôte, la connexion échoue après le délai de %.0f s (%.1f s)" % [reseau.DELAI_CONNEXION, duree])
```

par :

```gdscript
			_check(_issue == "echec" and duree >= TransportENet.DELAI_CANAL - 0.5 and duree <= TransportENet.DELAI_CANAL + 2.0,
				"sans hôte, la connexion échoue après le délai du canal de %.0f s (%.1f s)" % [TransportENet.DELAI_CANAL, duree])
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
```

par :

```gdscript
	# Le départ de ce poste part en arrière-plan (le DISCONNECT de son transport ne part qu'une fois sa file
	# envoyée) : le processus ne sort qu'une fois le transport fermé (une seconde au plus), sans quoi
	# l'autre poste attendrait les 10 s du battement.
	_check(await _attendre(func() -> bool: return reseau._partants.is_empty(), 2.0), "le départ de ce poste est fini (son transport fermé)")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	reseau.quitter()  # close() envoie ses paquets de façon synchrone (N7) : pas de pause à ajouter ici
```

par :

```gdscript
	reseau.quitter()  # son départ s'achève en arrière-plan : `_run` l'attend avant de sortir
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
## `Decouverte`, ni `GameState`, ni le salon (il peut nommer `EtatPartie`, dont le script ne nomme
## aucun autoload, et `ReglesBataille`).
```

par :

```gdscript
## `Decouverte`, ni `GameState`, ni le salon (il peut nommer `EtatPartie`, dont le script ne nomme
## aucun autoload, `ReglesBataille` et `TransportENet`).
```

- [ ] **Step 2 : ils échouent**

```bash
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"
grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u.log" | head -4
```

Expected : `code 1` ; `SCRIPT ERROR: Invalid access to property or key 'code_partie' on a base object of type 'Node (Reseau.gd)'.`, puis des ❌ en cascade (la fonction `_tester_reseau` s'est arrêtée en laissant ce poste hôte).

- [ ] **Step 3 : `Reseau` sur son transport**

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Transport LAN (spec §4) : le pair ENet (port UDP 7777), la poignée de main (version, pseudo),
```

par :

```gdscript
## La session réseau (spec §3.1 du jeu en ligne) : la poignée de main (version, pseudo),
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Battement et silences (phase 1 du jeu en ligne) : chaque poste en session envoie un battement par
## seconde (`_battement`, non fiable) ; tout ce que ce script reçoit d'un pair, battement ou RPC, remet
## son silence à zéro (`_entendus`) ; SILENCE_SESSION sans rien de lui le déclare parti, chez l'hôte
## comme chez un client, SILENCE_CHARGEMENT pendant le chargement de la manche (un poste qui charge sa
## scène ou compile ses shaders ne répond plus). Chez l'hôte, un client muet ou exclu est libéré
## (`_liberer`) : son départ arrive par `peer_disconnected`, comme tous les départs. `quitter()` part
## proprement (M6 : un DISCONNECT fiable d'ENet, renvoyé jusqu'à son accusé de réception, DELAI_DEPART
## au plus, en arrière-plan : `_partants`), pas par un seul datagramme qu'une perte Wi-Fi ferait passer
## inaperçu. Le relais du serveur est coupé (`server_relay`) : tout passe par l'hôte.
```

par :

```gdscript
## Transport (phase 1 du jeu en ligne) : les canaux sont ceux d'un `Transport` (`TransportENet`, puis
## `TransportWebRTC` en phase 4), dont ce script donne le pair à `SceneMultiplayer` et qu'il sert à
## chaque image ; il ne nomme aucune classe d'ENet. Un transport quitté finit son départ en
## arrière-plan (`_partants`).
##
## Battement et silences : chaque poste en session envoie un battement par seconde (`_battement`, non
## fiable) ; tout ce que ce script reçoit d'un pair, battement ou RPC, remet son silence à zéro
## (`_entendus`) ; SILENCE_SESSION sans rien de lui le déclare parti, chez l'hôte comme chez un client,
## SILENCE_CHARGEMENT pendant le chargement de la manche (un poste qui charge sa scène ou compile ses
## shaders ne répond plus). Chez l'hôte, un client muet ou exclu est libéré (`_liberer`, puis
## `Transport.liberer`) : son départ arrive par `peer_disconnected`, comme tous les départs.
## `quitter()` part proprement : le transport ferme sa session après l'envoi de ce qui est en file
## (`Transport.quitter`, une seconde au plus, en arrière-plan). Le relais du serveur est coupé
## (`server_relay`) : tout passe par l'hôte.
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## de chargement le sait). N4 : si le pair ENet de l'hôte tombe lui-même en erreur, ce même
```

par :

```gdscript
## de chargement le sait). N4 : si le pair de l'hôte tombe lui-même en erreur, ce même
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
const PORT := 7777
## Identifiant de la poignée de main : une demande qui ne le porte pas vient d'un autre programme.
const JEU := "LELION"
## Délai d'une connexion jusqu'à l'inscription (spec §9 : 5 s puis message).
const DELAI_CONNEXION := 5.0
```

par :

```gdscript
## Port de jeu par défaut : celui du transport ENet.
const PORT := TransportENet.PORT
## Identifiant de la poignée de main : une demande qui ne le porte pas vient d'un autre programme.
const JEU := "LELION"
## Délai de la poignée de main d'un client, du canal ouvert (`Transport.connecte`) à l'inscription (spec
## §9 : 5 s puis message) ; l'ouverture du canal a le délai de son transport.
const DELAI_CONNEXION := 5.0
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
const PSEUDO_MAX := 12
## Connexions ENet (`max_clients`) acceptées au-delà de `places` : l'hôte ne consomme pas de
## connexion vers lui-même, donc `places - 1` suffiraient aux vrais clients ; ce solde donne de quoi
## recevoir, et refuser explicitement, les demandes d'une partie déjà pleine au lieu de les laisser
## échouer sans explication côté ENet (N1 : la marge réelle est donc de CONNEXIONS_EN_TROP + 1).
const CONNEXIONS_EN_TROP := 2
```

par :

```gdscript
const PSEUDO_MAX := 12
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Essais de renvoi d'ENet avant de compter le silence (son défaut).
const ESSAIS_SILENCE := 32
## Silence d'un pair au-delà duquel ENet l'abandonne lui-même (`ENetPacketPeer.set_timeout`, en ms :
## minimum, maximum) : bien au-delà de SILENCE_CHARGEMENT, pour que ce soit toujours le battement qui
## décide.
const SILENCE_ENET := Vector2i(45000, 60000)
## Délai laissé à un départ volontaire pour être reçu (accusé de réception du DISCONNECT), en
## millisecondes.
const DELAI_DEPART := 1000
## Canal ENet du lancement
```

par :

```gdscript
## Canal du lancement
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Pour `adresse_ipv4`, la validation de l'écran Réseau (fonction statique : l'autoload n'est pas
## nommé). `Decouverte.gd` précharge aussi ce script : ce préchargement croisé passe en Godot 4.7.
const _Decouverte := preload("res://Scripts/Decouverte.gd")

## Version présentée
```

par :

```gdscript
## Version présentée
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## part, même quand ENet signale ensuite la fermeture qui en découle.
```

par :

```gdscript
## part, même quand le transport signale ensuite la fermeture qui en découle.
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
var silence := SILENCE_SESSION
```

par :

```gdscript
var silence := SILENCE_SESSION
## Chez l'hôte : le code de la partie (`Transport.pret`), ce qu'un client donne pour la rejoindre ; vide
## hors réseau, chez un client, et tant que le transport ne l'a pas donné.
var code_partie := ""
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Sessions quittées dont le départ n'est pas encore reçu : `{"pair": ENetMultiplayerPeer,
## "paquets": Array (ses ENetPacketPeer), "fin": int (ms)}`, servies par `_process` jusqu'à ce que
## chaque autre poste ait accusé réception, ou jusqu'à `fin`, puis fermées.
var _partants: Array[Dictionary] = []
```

par :

```gdscript
## Le transport de la session en cours (null hors réseau).
var _transport: Transport
## Les transports quittés dont le départ n'est pas fini, servis par `_process` jusqu'à leur fermeture.
var _partants: Array[Transport] = []
## Chez un client : vrai de `rejoindre()` à l'inscription ; une fermeture pendant ce temps est un échec
## de connexion, pas un hôte perdu.
var _connexion_en_cours := false
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Héberge une partie sur `port` : quitte d'abord toute session en cours, borne `places`, puis ce
## poste s'inscrit lui-même (index 0, première couleur). Si le port est pris, renvoie l'erreur
## d'ENet sans rien changer de plus (spec §9 : « port occupé ») : la session précédente reste
## close, mais rien de neuf n'est créé.
func heberger(port := PORT) -> Error:
	quitter()
	_clore_partants()  # une session hébergée qui part encore tient son port : le libérer d'abord
	places = clampi(places, EtatPartie.NB_JOUEURS_MIN, EtatPartie.NB_JOUEURS_MAX)
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_server(port, places + CONNEXIONS_EN_TROP)
	if erreur != OK:
		return erreur
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = pair
	index_local = premier_index_libre(inscrits, places)
	couleur_locale = premiere_couleur_libre(inscrits)
	inscrits[multiplayer.get_unique_id()] = {"index": index_local, "couleur": couleur_locale,
		"pseudo": pseudo_ou_defaut(pseudo, index_local), "arrive": true, "pret": false}
	places_salon = places
	_diffuser_salon()
	return OK


## Rejoint l'hôte à `adresse`, une IPv4 (M8 : un nom d'hôte serait résolu par `create_client` en
## bloquant le jeu, plusieurs secondes sous Windows pour une faute de frappe) : toute adresse que
## `Decouverte.adresse_ipv4` ne reconnaît pas est refusée (ERR_INVALID_PARAMETER) sans rien
## changer, pas même la session en cours. La réponse arrive par `inscrit`, `refuse` ou
## `connexion_echouee` (au plus tard après DELAI_CONNEXION). Renvoie l'erreur d'ENet si le client
## ne peut même pas être créé.
func rejoindre(adresse: String, port := PORT) -> Error:
	var ipv4: String = _Decouverte.adresse_ipv4(adresse)
	if ipv4.is_empty():
		return ERR_INVALID_PARAMETER
	quitter()
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_client(ipv4, port)
	if erreur != OK:
		return erreur
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = pair
	_delai.start(DELAI_CONNEXION)
	return OK


## Quitte le réseau : part proprement (les autres postes voient partir ce joueur, ou l'hôte : voir
## `_partir`), remet `OfflineMultiplayerPeer` et oublie inscrits, table du salon, index, couleur,
## scènes chargées et manche en cours (une session hébergée finie n'a plus lieu d'être). Sans effet
## visible hors réseau : chaque chemin de retour au titre peut l'appeler (point de vigilance des
## phases 12/13).
func quitter() -> void:
	_generation += 1
	_delai.stop()
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer:
		_partir(pair)
	elif pair != null and not (pair is OfflineMultiplayerPeer):
		pair.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_api().auth_callback = Callable()
	inscrits.clear()
	table_salon.clear()
	scenes_chargees.clear()
	silence = SILENCE_SESSION
	_entendus.clear()
	niveau_salon = 0
	places_salon = EtatPartie.NB_JOUEURS_MAX
	places_reservees = 0
	numero_table = 0
	niveau_manche = 0
	_exclu = false
	index_local = -1
	couleur_locale = Color.TRANSPARENT
	manche_en_cours = false
	_issue_decidee = false


## Départ volontaire d'une session ENet (M6) : chaque autre poste connecté reçoit un DISCONNECT fiable,
## envoyé tout de suite, puis renvoyé par `_process` jusqu'à son accusé de réception (DELAI_DEPART au
## plus) ; la session est alors fermée. `close()` seul n'envoie qu'un datagramme non fiable : perdu
## en Wi-Fi, le départ ne serait vu qu'au bout du silence de l'autre poste.
func _partir(pair: ENetMultiplayerPeer) -> void:
	if pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		pair.close()
		return
	var connexion := pair.host
	var paquets: Array = [] if connexion == null else connexion.get_peers().filter(
		func(p: ENetPacketPeer) -> bool: return p.get_state() == ENetPacketPeer.STATE_CONNECTED)
	if paquets.is_empty():
		pair.close()
		return
	for p: ENetPacketPeer in paquets:
		p.peer_disconnect()
	connexion.flush()
	_partants.append({"pair": pair, "paquets": paquets, "fin": Time.get_ticks_msec() + DELAI_DEPART})


## En session, le battement et l'écoute des silences ; puis les départs en cours, fermés une fois reçus
## ou leur délai passé.
func _process(_delta: float) -> void:
	if en_ligne():
		var maintenant := Time.get_ticks_msec()
		_battre(maintenant)
		_ecouter(maintenant)
	for partant: Dictionary in _partants.duplicate():
		partant.pair.poll()
		var recus: bool = partant.paquets.all(func(p: ENetPacketPeer) -> bool: return p.get_state() == ENetPacketPeer.STATE_DISCONNECTED)
		if recus or Time.get_ticks_msec() >= partant.fin:
			partant.pair.close()
			_partants.erase(partant)


## Ferme tout de suite les départs en cours (leurs ports se libèrent).
func _clore_partants() -> void:
	for partant: Dictionary in _partants:
		partant.pair.close()
	_partants.clear()
```

par :

```gdscript
## Héberge une partie sur `port` : quitte d'abord toute session en cours, borne `places`, puis ce
## poste s'inscrit lui-même (index 0, première couleur). Si le port est pris, renvoie l'erreur du
## transport sans rien changer de plus (spec §9 : « port occupé ») : la session précédente reste
## close, mais rien de neuf n'est créé.
func heberger(port := PORT) -> Error:
	quitter()
	_clore_partants()  # une session hébergée qui part encore tient son port : le libérer d'abord
	places = clampi(places, EtatPartie.NB_JOUEURS_MIN, EtatPartie.NB_JOUEURS_MAX)
	var transport := _nouveau_transport(port)
	_brancher(transport)  # avant `heberger()` : `pret` peut partir pendant l'appel
	var erreur := transport.heberger()
	if erreur != OK:
		return erreur
	_transport = transport
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = transport.pair()
	index_local = premier_index_libre(inscrits, places)
	couleur_locale = premiere_couleur_libre(inscrits)
	inscrits[multiplayer.get_unique_id()] = {"index": index_local, "couleur": couleur_locale,
		"pseudo": pseudo_ou_defaut(pseudo, index_local), "arrive": true, "pret": false}
	places_salon = places
	_diffuser_salon()
	return OK


## Rejoint l'hôte à `adresse` (une IPv4) et `port` : le code `adresse:port` du transport, qui refuse
## tout autre texte (ERR_INVALID_PARAMETER, M8 : aucun nom d'hôte, dont la résolution bloquerait le jeu)
## avant que rien ne change, pas même la session en cours. La réponse arrive par `inscrit`, `refuse` ou
## `connexion_echouee` (au plus tard après le délai du canal du transport, puis DELAI_CONNEXION). Renvoie
## l'erreur du transport si le client ne peut même pas être créé.
func rejoindre(adresse: String, port := PORT) -> Error:
	var transport := _nouveau_transport(port)
	var erreur := transport.rejoindre("%s:%d" % [adresse.strip_edges(), port])
	if erreur != OK:
		return erreur
	quitter()
	_brancher(transport)  # après `quitter()` : la génération de la nouvelle session
	_transport = transport
	_connexion_en_cours = true
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = transport.pair()
	return OK


## Quitte le réseau : part proprement (les autres postes voient partir ce joueur, ou l'hôte : le
## transport ferme sa session une fois ce qui est en file envoyé, en arrière-plan), remet
## `OfflineMultiplayerPeer` et oublie inscrits, table du salon, index, couleur, scènes chargées, code et
## manche en cours (une session hébergée finie n'a plus lieu d'être). Sans effet visible hors réseau :
## chaque chemin de retour au titre peut l'appeler (point de vigilance des phases 12/13).
func quitter() -> void:
	_generation += 1
	_delai.stop()
	if _transport != null:
		_transport.quitter()
		if _transport.servir():
			_partants.append(_transport)  # son départ continue, servi par `_process`
		_transport = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_api().auth_callback = Callable()
	inscrits.clear()
	table_salon.clear()
	scenes_chargees.clear()
	silence = SILENCE_SESSION
	_entendus.clear()
	code_partie = ""
	_connexion_en_cours = false
	niveau_salon = 0
	places_salon = EtatPartie.NB_JOUEURS_MAX
	places_reservees = 0
	numero_table = 0
	niveau_manche = 0
	_exclu = false
	index_local = -1
	couleur_locale = Color.TRANSPARENT
	manche_en_cours = false
	_issue_decidee = false


## Le transport d'une nouvelle session : ENet (le desktop, les tests ; WebRTC dans l'export Web, phase 4).
func _nouveau_transport(port: int) -> Transport:
	return TransportENet.new(port, places)


## Branche les signaux de `transport` sur cette session (la génération en cours) : ceux d'une session
## périmée ne font rien.
func _brancher(transport: Transport) -> void:
	transport.pret.connect(_sur_transport_pret.bind(_generation))
	transport.connecte.connect(_sur_transport_connecte.bind(_generation))
	transport.echec.connect(_sur_transport_echec.bind(_generation))


## En session, le transport, le battement et l'écoute des silences ; puis les départs en cours, oubliés
## une fois leur transport fermé.
func _process(_delta: float) -> void:
	if _transport != null:
		_transport.servir()
	if en_ligne():
		var maintenant := Time.get_ticks_msec()
		_battre(maintenant)
		_ecouter(maintenant)
	for partant: Transport in _partants.duplicate():
		if not partant.servir():
			_partants.erase(partant)


## Ferme tout de suite les départs en cours (leurs ports se libèrent).
func _clore_partants() -> void:
	for partant: Transport in _partants:
		partant.clore()
	_partants.clear()
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _battement() -> void:
	_entendre(multiplayer.get_remote_sender_id())


## Pose SILENCE_ENET sur chaque pair ENet connecté, le nouveau venu compris : ENet ne doit jamais
## décider avant le battement.
func _reculer_silence_enet() -> void:
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer and pair.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED \
			and pair.host != null:
		for p: ENetPacketPeer in pair.host.get_peers():
			if p.get_state() == ENetPacketPeer.STATE_CONNECTED:
				p.set_timeout(ESSAIS_SILENCE, SILENCE_ENET.x, SILENCE_ENET.y)
```

par :

```gdscript
func _battement() -> void:
	_entendre(multiplayer.get_remote_sender_id())
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez l'hôte : libère le client `id` (muet ou exclu), s'il est encore là dans la même session
## (`generation`) : son silence n'est plus écouté, et son pair est fermé sur-le-champ, sans attendre
## d'accusé de réception (I1, revue finale phase 14 : un pair figé, qui charge ou compile ses shaders,
## ou mort n'en enverra pas) ; son départ part aussitôt par `peer_disconnected` (`_sur_pair_deconnecte`).
func _liberer(id: int, generation: int) -> void:
	if generation != _generation or not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	_entendus.erase(id)
	var pair := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var paquet := pair.get_peer(id) if pair != null else null
	if paquet != null and paquet.is_active():
		paquet.peer_disconnect_now()  # un seul DISCONNECT, non fiable : sa place se libère tout de suite
		pair.poll()  # ENet rend compte du pair fermé : `peer_disconnected` part maintenant
```

par :

```gdscript
## Chez l'hôte : libère le client `id` (muet ou exclu), s'il est encore là dans la même session
## (`generation`) : son silence n'est plus écouté, et son transport le ferme sur-le-champ, sans attendre
## d'accusé de réception (I1, revue finale phase 14 : un pair figé, qui charge ou compile ses shaders,
## ou mort n'en enverra pas) ; son départ part aussitôt par `peer_disconnected` (`_sur_pair_deconnecte`).
func _liberer(id: int, generation: int) -> void:
	if generation != _generation or _transport == null or not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	_entendus.erase(id)
	_transport.liberer(id)
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	# Un refusé n'est pas déconnecté ici : ENet viderait sa file d'envoi, réponse comprise, et le
```

par :

```gdscript
	# Un refusé n'est pas déconnecté ici : le transport viderait sa file d'envoi, réponse comprise, et le
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
		_reculer_silence_enet()  # le nouveau venu aussi
		_entendus[id] = Time.get_ticks_msec()
```

par :

```gdscript
		_entendus[id] = Time.get_ticks_msec()
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _sur_connecte_a_l_hote() -> void:
	_delai.stop()
	_reculer_silence_enet()
	_entendus[MultiplayerPeer.TARGET_PEER_SERVER] = Time.get_ticks_msec()
```

par :

```gdscript
func _sur_connecte_a_l_hote() -> void:
	_delai.stop()
	_connexion_en_cours = false
	_entendus[MultiplayerPeer.TARGET_PEER_SERVER] = Time.get_ticks_msec()
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## L'hôte ferme la connexion. Avant l'inscription (délai encore en cours), c'est un échec de
## connexion, pas un hôte perdu : ce poste n'a jamais été dans la partie.
func _sur_hote_perdu() -> void:
	_decider("connexion_echouee" if not _delai.is_stopped() else "hote_perdu")


func _sur_delai_depasse() -> void:
	if en_ligne() and not multiplayer.is_server():
		_decider("connexion_echouee")
```

par :

```gdscript
## L'hôte ferme la connexion. Avant l'inscription, c'est un échec de connexion, pas un hôte perdu : ce
## poste n'a jamais été dans la partie.
func _sur_hote_perdu() -> void:
	_decider("connexion_echouee" if _connexion_en_cours else "hote_perdu")


## La poignée de main d'un client n'a pas fini dans DELAI_CONNEXION, une fois le canal ouvert.
func _sur_delai_depasse() -> void:
	if _connexion_en_cours:
		_decider("connexion_echouee")


## Chez l'hôte : la session du transport existe ; son code est celui de la partie.
func _sur_transport_pret(code: String, generation: int) -> void:
	if generation == _generation:
		code_partie = code


## Chez un client : le canal vers l'hôte est ouvert ; la poignée de main (que `SceneMultiplayer` lance
## d'elle-même) a DELAI_CONNEXION pour finir.
func _sur_transport_connecte(generation: int) -> void:
	if generation == _generation and _connexion_en_cours:
		_delai.start(DELAI_CONNEXION)


## Chez un client : le canal vers l'hôte ne s'ouvrira pas (`raison`, Transport.ECHEC_* : l'écran En
## ligne, phase 3, en fera un message ; ici, un échec de connexion).
func _sur_transport_echec(_raison: String, generation: int) -> void:
	if generation == _generation and _connexion_en_cours:
		_decider("connexion_echouee")
```

- [ ] **Step 4 : ils passent, le réseau aussi**

```bash
timeout 120 godot --headless --import . > "$TMPDIR/import.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$TMPDIR/import.log"
grep -nE "\bENet[A-Z]\w*|_Decouverte|CONNEXIONS_EN_TROP|SILENCE_ENET|DELAI_DEPART|_partir\b" Scripts/Reseau.gd
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|== |PROTOCOLE|phase 1 :" "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log" | tail -2
DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"
grep -E "❌|✅ |== |\(I1\)|départ arraché" "$TMPDIR/r.log"
```

Expected : rien à l'import ni au `grep` de `Reseau.gd` ; unitaires `== 0 échec(s) ==`, `PROTOCOLE 0.20 322872843 (67 lignes)` (aucune RPC ne change), les deux lignes « phase 1 : » en ✅ (code `127.0.0.1:17790`) ; smoke `== 0 échec(s) ==` ; test réseau `code 0`, `== 0 échec(s) ==`, environ 175 s (mesuré 173 s : sans l'attente de la fin du départ dans `joueur.gd`, chaque poste sortait avant d'envoyer son DISCONNECT, et plusieurs scénarios prenaient 10 s de plus).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Reseau.gd tests/unitaires.gd tests/reseau/joueur.gd
git commit -m "Reseau : la session passe par son transport (TransportENet), servi à chaque image, ses départs finis en arrière-plan ; plus aucune classe d'ENet dans Reseau ; le code de la partie (Transport.pret) ; le délai de connexion court du canal ouvert à l'inscription ; joueur.gd attend la fin de son départ avant de sortir

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 4 : l'adieu (départ volontaire)

**Files:**
- Modify: `Scripts/Reseau.gd` (état laissé par la Task 3 : en-tête, doc de `quitter`, `quitter`, après `_battement` : `_dire_adieu` et la RPC `_recevoir_adieu`, doc de `_liberer`)
- Test: `tests/unitaires.gd` (`_tester_battement`, avant son nettoyage ; `PROTOCOLE_EMPREINTE`)
- Test: `tests/reseau/joueur.gd` (`_jouer_hote`, `_jouer_client`, `_sur_depart`, `_ajouter_issue`, nouvelle `_horodatage`)
- Test: `tests/reseau/lancer.sh` (fonction `ecart_ms`, scénario 1)

**Interfaces:**
- Consumes (Tasks 2 et 3) : `_liberer(id, generation)`, `_decider(nom)`, `Transport.quitter()` (qui envoie la file avant de fermer).
- Produces : RPC `_recevoir_adieu()` (`any_peer`, `call_remote`, `reliable`, canal 0) ; `func _dire_adieu() -> void`, appelée par `quitter()` avant `Transport.quitter()`. `joueur.gd` écrit `ADIEU <ms>` avant un départ volontaire, `DEPART_RECU <ms>` à chaque départ vu par un hôte, `HOTE_PERDU_RECU <ms>` à chaque hôte perdu (horloge du système) ; `lancer.sh` les compare avec `ecart_ms <nom_a> <repère_a> <nom_b> <repère_b>`.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
		"... %d ms après son dernier battement (silence de 1,5 s) : « L'hôte a quitté la partie »" % perdu_apres)

	hote.quitter()
	client.quitter()
```

par :

```gdscript
		"... %d ms après son dernier battement (silence de 1,5 s) : « L'hôte a quitté la partie »" % perdu_apres)

	# Départ volontaire (spec §5), sous un silence de 30 s : vu tout de suite, par l'adieu. D'abord l'adieu
	# seul (le poste ne quitte pas : son transport ne dit rien), puis un vrai `quitter()`.
	_check(hote.heberger(port) == OK and client.rejoindre("127.0.0.1", port) == OK, "(pré-condition) le client rejoint une troisième fois")
	_check(await _attendre(func() -> bool: return arrives.size() == 3 and client._entendus.has(1), 3.0), "(pré-condition) le client est arrivé")
	hote.definir_silence(30.0)
	client.definir_silence(30.0)
	var partis_avant := partis.size()
	var pertes_avant := pertes.size()
	var adieu_a := Time.get_ticks_msec()
	client._recevoir_adieu.rpc_id(1)
	_check(await _attendre(func() -> bool: return partis.size() == partis_avant + 1, 1.0),
		"l'adieu d'un client : l'hôte le voit partir tout de suite (%d ms), sans attendre son silence" % (Time.get_ticks_msec() - adieu_a))
	_check(await _attendre(func() -> bool: return pertes.size() == pertes_avant + 1, 1.0) and not client.en_ligne(),
		"(le client libéré se retrouve hors réseau)")
	_check(hote.heberger(port) == OK and client.rejoindre("127.0.0.1", port) == OK, "(pré-condition) le client rejoint une quatrième fois")
	_check(await _attendre(func() -> bool: return arrives.size() == 4 and client._entendus.has(1), 3.0), "(pré-condition) le client est arrivé")
	hote.definir_silence(30.0)
	client.definir_silence(30.0)
	pertes_avant = pertes.size()
	adieu_a = Time.get_ticks_msec()
	hote._recevoir_adieu.rpc()
	_check(await _attendre(func() -> bool: return pertes.size() == pertes_avant + 1, 1.0) and pertes[-1] == client.PERTE_HOTE,
		"l'adieu de l'hôte : le client le perd tout de suite (%d ms), « L'hôte a quitté la partie »" % (Time.get_ticks_msec() - adieu_a))
	_check(hote.heberger(port) == OK and client.rejoindre("127.0.0.1", port) == OK, "(pré-condition) le client rejoint une cinquième fois")
	_check(await _attendre(func() -> bool: return arrives.size() == 5 and client._entendus.has(1), 3.0), "(pré-condition) le client est arrivé")
	hote.definir_silence(30.0)
	client.definir_silence(30.0)
	partis_avant = partis.size()
	var transport_client: Transport = client._transport
	client.quitter()
	_check(not client.en_ligne() and client._partants.has(transport_client), "quitter() : ce poste est hors réseau aussitôt, son départ continue en arrière-plan")
	var quitte_a := Time.get_ticks_msec()
	_check(await _attendre(func() -> bool: return partis.size() == partis_avant + 1 and not client._partants.has(transport_client), 1.5),
		"un client qui quitte : l'hôte le voit partir, son transport se ferme une fois l'adieu envoyé (%d ms)" % (Time.get_ticks_msec() - quitte_a))

	hote.quitter()
	client.quitter()
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
const PROTOCOLE_EMPREINTE := 322872843
```

par :

```gdscript
const PROTOCOLE_EMPREINTE := 815376087
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	reseau.quitter()  # son départ s'achève en arrière-plan : `_run` l'attend avant de sortir
```

par :

```gdscript
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	print("ADIEU %d" % _horodatage())
	reseau.quitter()  # son départ s'achève en arrière-plan : `_run` l'attend avant de sortir
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
				await _pause(0.5)
				reseau.quitter()
				_check(_issue == "inscrit", "partir de soi-même n'émet ni échec ni hôte perdu (%s)" % _issue)
```

par :

```gdscript
				await _pause(0.5)
				print("ADIEU %d" % _horodatage())
				reseau.quitter()
				_check(_issue == "inscrit", "partir de soi-même n'émet ni échec ni hôte perdu (%s)" % _issue)
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
func _sur_depart(id: int) -> void:
	_departs.append(id)
```

par :

```gdscript
func _sur_depart(id: int) -> void:
	_departs.append(id)
	print("DEPART_RECU %d" % _horodatage())
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
func _ajouter_issue(quoi: String) -> void:
	_issue = quoi if _issue.is_empty() else _issue + "+" + quoi
```

par :

```gdscript
func _ajouter_issue(quoi: String) -> void:
	_issue = quoi if _issue.is_empty() else _issue + "+" + quoi
	if quoi == "hote_perdu":
		print("HOTE_PERDU_RECU %d" % _horodatage())


## L'heure de l'horloge du système, en ms : la même pour tous les postes de ce PC (lancer.sh compare les
## horodatages de deux journaux).
func _horodatage() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# compter <motif> <nom…> : nombre de lignes qui contiennent le motif dans les journaux nommés.
```

par :

```bash
# ecart_ms <nom_a> <repère_a> <nom_b> <repère_b> : l'écart, en ms, entre l'horodatage de la première
# ligne « <repère_a> <ms> » du journal de <nom_a> et celui de la première « <repère_b> <ms> » du journal
# de <nom_b> (l'horloge du système, la même pour tous les postes) ; rien si l'une manque.
ecart_ms() {
	local a b
	a=$(sed -n "s/^$2 \([0-9]*\)$/\1/p" "$JOURNAUX/$1.log" 2>/dev/null | head -1)
	b=$(sed -n "s/^$4 \([0-9]*\)$/\1/p" "$JOURNAUX/$3.log" 2>/dev/null | head -1)
	[ -n "$a" ] && [ -n "$b" ] && echo $((b - a))
}

# compter <motif> <nom…> : nombre de lignes qui contiennent le motif dans les journaux nommés.
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# 1. Hôte + 2 clients ; un troisième se présente avec une autre version. L'un des deux clients
#    repart de lui-même, puis l'hôte quitte : l'autre le voit partir.
```

par :

```bash
# 1. Hôte + 2 clients ; un troisième se présente avec une autre version. L'un des deux clients
#    repart de lui-même, puis l'hôte quitte : l'autre le voit partir. Chaque départ est vu en moins
#    d'une seconde (phase 1 : l'adieu), pas au bout des 10 s du battement.
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
terminer "hôte + 2 clients, départ d'un client et de l'hôte, version différente refusée"
```

par :

```bash
terminer "hôte + 2 clients, départ d'un client et de l'hôte, version différente refusée"
ecart1=$(ecart_ms partant1 ADIEU hote1 DEPART_RECU)
ecart1h=$(ecart_ms hote1 ADIEU reste1 HOTE_PERDU_RECU)
echo "  (départs) le client parti vu par l'hôte en ${ecart1:-?} ms, l'hôte parti vu par l'autre client en ${ecart1h:-?} ms"
[ -n "$ecart1" ] && [ "$ecart1" -le 1000 ] && [ -n "$ecart1h" ] && [ "$ecart1h" -le 1000 ] \
	|| echec "départs volontaires : chacun doit être vu en moins d'une seconde (l'adieu), pas au bout du silence du battement"
```

- [ ] **Step 2 : ils échouent**

```bash
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"
grep -E "❌|SCRIPT ERROR|== |PROTOCOLE" "$TMPDIR/u.log"
```

Expected : `code 1` ; `SCRIPT ERROR: Invalid access to property or key '_recevoir_adieu' on a base object of type 'Node (Reseau.gd)'.` ; `PROTOCOLE 0.20 322872843 (67 lignes)` et `❌ le protocole (RPC, réplication, formats réseau, balise) est celui de la version 0.20 …` ; `== 1 échec(s) ==`.

- [ ] **Step 3 : l'adieu**

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## `Transport.liberer`) : son départ arrive par `peer_disconnected`, comme tous les départs.
## `quitter()` part proprement : le transport ferme sa session après l'envoi de ce qui est en file
## (`Transport.quitter`, une seconde au plus, en arrière-plan). Le relais du serveur est coupé
## (`server_relay`) : tout passe par l'hôte.
```

par :

```gdscript
## `Transport.liberer`) : son départ arrive par `peer_disconnected`, comme tous les départs.
## `quitter()` part proprement (spec §5) : un adieu fiable (`_recevoir_adieu`), que l'autre côté traite
## aussitôt (l'hôte libère ce client, un client perd l'hôte), puis le transport ferme sa session une fois
## l'adieu envoyé (`Transport.quitter`, une seconde au plus, en arrière-plan). Le relais du serveur est
## coupé (`server_relay`) : tout passe par l'hôte.
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Quitte le réseau : part proprement (les autres postes voient partir ce joueur, ou l'hôte : le
## transport ferme sa session une fois ce qui est en file envoyé, en arrière-plan), remet
```

par :

```gdscript
## Quitte le réseau : part proprement (les autres postes voient partir ce joueur, ou l'hôte, tout de
## suite : son adieu, puis le transport ferme sa session une fois l'adieu envoyé, en arrière-plan), remet
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	_generation += 1
	_delai.stop()
	if _transport != null:
		_transport.quitter()
```

par :

```gdscript
	_generation += 1
	_delai.stop()
	_dire_adieu()
	if _transport != null:
		_transport.quitter()
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Le battement d'un pair (non fiable, canal 0 : spec §5).
@rpc("any_peer", "call_remote", "unreliable")
func _battement() -> void:
	_entendre(multiplayer.get_remote_sender_id())
```

par :

```gdscript
## Le battement d'un pair (non fiable, canal 0 : spec §5).
@rpc("any_peer", "call_remote", "unreliable")
func _battement() -> void:
	_entendre(multiplayer.get_remote_sender_id())


## Le départ volontaire de ce poste, annoncé à ses pairs (spec §5) : un adieu fiable, que le transport
## envoie avant de fermer (`Transport.quitter`). Rien hors session, ni avant l'inscription (aucune RPC
## ne passe encore).
func _dire_adieu() -> void:
	if not en_ligne() or multiplayer.get_peers().is_empty():
		return
	if multiplayer.is_server():
		_recevoir_adieu.rpc()
	else:
		_recevoir_adieu.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


## L'adieu d'un pair qui part : chez l'hôte, ce client est libéré tout de suite (une fois ses paquets en
## cours relevés) ; chez un client, l'hôte est perdu, sans attendre son silence.
@rpc("any_peer", "call_remote", "reliable")
func _recevoir_adieu() -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		_liberer.call_deferred(id, _generation)
	elif id == MultiplayerPeer.TARGET_PEER_SERVER:
		_decider("hote_perdu")
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez l'hôte : libère le client `id` (muet ou exclu), s'il est encore là
```

par :

```gdscript
## Chez l'hôte : libère le client `id` (muet, exclu, ou parti : son adieu), s'il est encore là
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## shaders ne répond plus). Chez l'hôte, un client muet ou exclu est libéré (`_liberer`, puis
```

par :

```gdscript
## shaders ne répond plus). Chez l'hôte, un client parti, muet ou exclu est libéré (`_liberer`, puis
```

- [ ] **Step 4 : ils passent, le réseau aussi**

```bash
timeout 120 godot --headless --import . > "$TMPDIR/import.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$TMPDIR/import.log"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|== |PROTOCOLE|adieu|qui quitte" "$TMPDIR/u.log"
DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"
grep -E "❌|✅ |== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r.log"
```

Expected : `PROTOCOLE 0.20 815376087 (68 lignes)`, `== 0 échec(s) ==` (mesuré : l'adieu d'un client vu en 13 ms, celui de l'hôte en 12 ms, le transport du client qui quitte fermé en 11 ms) ; test réseau `code 0`, `== 0 échec(s) ==`, la ligne `(départs) le client parti vu par l'hôte en … ms, l'hôte parti vu par l'autre client en … ms` (mesuré 4 et 6 ms), environ 175 s.

Point connu, sans lien avec cette phase : le scénario 13 peut échouer une fois sur quelques passages sur `ECART_CHRONO` (une fin bloquée derrière une retransmission sous 5 % de pertes, au-delà des 0,6 s tolérés) ; mesuré aussi sur `main` (−0,610 s). Relancer une fois ; s'il échoue deux fois de suite, c'est un vrai échec : le diagnostiquer.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Reseau.gd tests/unitaires.gd tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Reseau : départ volontaire par un adieu fiable, envoyé avant que le transport ferme ; l'hôte libère aussitôt le client qui part, le client perd aussitôt l'hôte qui part ; scénario 1 : départs vus en moins d'une seconde ; empreinte du protocole renotée

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 5 : la spec et le README

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md:57-58` (§3.1, lignes `Reseau` et `Transport`), `:249-251` (§12)
- Modify: `README.md:86-87` (section Multiplayer)

**Interfaces:** aucune (documentation).

- [ ] **Step 1 : la vérification d'abord (elle échoue)**

```bash
grep -c "liberer(id)" docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md; grep -c "fait foi" docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md; grep -c "LeLion-multi/releases" README.md
```

Expected : `0`, `0`, `0`.

- [ ] **Step 2 : la spec, §3.1**

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

```
tout paquet reçu d'un pair, battement ou non, remet son silence à zéro ; 10 s de silence (30 s au chargement) le déclarent parti. Ajoute l'**exclusion** par l'hôte (§8).
```

par :

```
tout paquet de `Reseau` reçu d'un pair, battement ou RPC, remet son silence à zéro (`SceneMultiplayer` ne donne ni l'heure de réception par pair ni un signal par RPC reçue : le trafic de la manche n'est pas compté, le battement y suffit) ; 10 s de silence (30 s au chargement) le déclarent parti. Départ volontaire : un adieu fiable, puis le transport ferme une fois l'adieu envoyé (§5). Un exclu part de lui-même à l'annonce, fiable ; l'hôte le libère ensuite. Ajoute l'**exclusion** par l'hôte (§8).
```

Dans le même fichier, remplacer :

```
| `Transport` (interface, `RefCounted`) | `heberger() -> Error`, `rejoindre(code: String) -> Error`, `quitter()`, `pair() -> MultiplayerPeer` ;
```

par :

```
| `Transport` (interface `@abstract`, `RefCounted`) | `heberger() -> Error`, `rejoindre(code: String) -> Error`, `quitter()` (ferme une fois envoyé ce qui est en file, en arrière-plan), `clore()` (tout de suite), `pair() -> MultiplayerPeer`, `liberer(id)` (chez l'hôte : ferme sur-le-champ le canal d'un pair parti, muet ou exclu, sans attendre de réponse ; son `peer_disconnected` part pendant l'appel), `servir() -> bool` (à chaque image ; faux une fois fermé) ;
```

- [ ] **Step 3 : la spec, §12**

Dans le même fichier, remplacer :

```
## 12. Phases (le découpage exact viendra du plan)

Chaque phase touche 5 fichiers au plus, se termine par les tests verts et attend une validation.
```

par :

```
## 12. Phases (le découpage exact viendra du plan)

Le découpage exact est celui de la feuille de route (`docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`), qui fait foi : elle le revoit (la découverte LAN part avec l'écran En ligne, en 3 bis ; le WebRTC et son test de bout en bout vont ensemble, en 4 ; le déploiement a sa phase, 5). Le tableau ci-dessous garde le découpage du brainstorming.

Chaque phase touche 5 fichiers au plus, se termine par les tests verts et attend une validation.
```

- [ ] **Step 4 : le README**

Dans `README.md`, remplacer :

```
Until online play lands, run the game from the editor (`godot .`) on each computer of the same
local network: games are found automatically (UDP broadcast) or joined by the host's IP address.
```

par :

```
Until online play lands, run the game from the editor (`godot .`) on each computer of the same
local network: games are found automatically (UDP broadcast) or joined by the host's IP address.
Ready-made Windows, macOS and Linux builds of the LAN version are on
[LeLion-multi's releases](https://github.com/w3cdotorg/LeLion-multi/releases/latest) (version 0.19).
```

- [ ] **Step 5 : la vérification passe**

```bash
grep -c "liberer(id)" docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md; grep -c "fait foi" docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md; grep -c "LeLion-multi/releases" README.md
```

Expected : `1`, `1`, `1`.

- [ ] **Step 6 : Commit**

```bash
git add docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md README.md
git commit -m "Spec : l'interface Transport telle que la phase 1 l'a faite (clore, libérer, servir), le battement compte les paquets de Reseau, l'adieu, l'exclu qui part de lui-même ; la feuille de route fait foi pour le découpage ; README : les exe LAN de LeLion-multi

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 6 : vérification commune, feuille de route, PR et fusion

**Files:**
- Modify: `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md:47` (ligne 1 : fichiers réels, « Faite (PR #N) »)

**Interfaces:** aucune.

- [ ] **Step 1 : la vérification commune (feuille de route), sans relance**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd > "$TMPDIR/b.log" 2>&1; echo "bataille $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/b.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "banc $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/p.log"
SECONDS=0; DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r.log"
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/dc.log" 2>&1 &
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/dh.log" 2>&1; echo "deux fenêtres hôte $?"; wait; grep -c "📸" "$TMPDIR/dh.log" "$TMPDIR/dc.log"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/dh.log" "$TMPDIR/dc.log"
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh
git status --short
```

Expected : pas de « ÉCHEC COMPILATION » ; chaque suite sort en 0 sur `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR` ; réseau en 180 s environ (moins de 300 s) avec les trois mesures (exclusion ≈ 500 ms, départ arraché de 8 500 à 11 000 ms, départs volontaires sous 1 000 ms) ; 37 📸 pour les captures, 5 et 6 pour les deux fenêtres ; rien au `perl` ; `git status` propre. Un échec : le corriger dans la tâche qu'il concerne (commit à part), puis tout relancer.

- [ ] **Step 2 : la branche poussée, la PR ouverte** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
git push -u origin phase-01-transport
cat > "$TMPDIR/pr.md" <<'EOF'
Phase 1 de la feuille de route du jeu en ligne : le transport sort de `Reseau`.

- `Scripts/Transport.gd` : l'interface d'un transport (`heberger`, `rejoindre`, `quitter`, `clore`, `pair`, `liberer`, `servir` ; `pret`, `connecte`, `echec`), trois méthodes de plus que la spec (§3.1 mise à jour).
- `Scripts/TransportENet.gd` : le transport ENet extrait de `Reseau.gd` (code `ip:port`, silence d'ENet repoussé derrière le battement, départ après la file, libération immédiate) ; `Reseau.gd` ne nomme plus aucune classe d'ENet.
- Battement applicatif d'une seconde : 10 s de silence pour tous (30 s au chargement) ; départ volontaire par un adieu fiable ; l'exclu de la barrière part de lui-même à l'annonce.
- Version 0.20, `PROTOCOLE_EMPREINTE` renotée.

Tests : unitaires (transport seul, battement et adieu entre deux `Reseau` d'un même processus), les 13 scénarios réseau verts ; le client arraché du scénario 11 vu au bout des 10 s du battement, les départs du scénario 1 en moins d'une seconde.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
gh pr create --repo w3cdotorg/LeLion-web --base main --head phase-01-transport --title "Phase 1 : transport" --body-file "$TMPDIR/pr.md"
N=$(gh pr view --repo w3cdotorg/LeLion-web phase-01-transport --json number -q .number); echo "PR #$N"
```

Ajouter au corps de la PR, avant la dernière ligne, les mesures de la Task 0 (référence) et du Step 1 (`gh pr edit --repo w3cdotorg/LeLion-web "$N" --body-file "$TMPDIR/pr.md"` après les avoir écrites dans le fichier).

- [ ] **Step 3 : la feuille de route**

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

```
| ➕ `Scripts/Transport.gd` ➕ `Scripts/TransportENet.gd` ✏️ `Scripts/Reseau.gd` ✏️ `tests/unitaires.gd` ✏️ `tests/reseau/joueur.gd` | Les 13 scénarios réseau verts, scénario 11 allongé (silence de 10 s). |
```

par (`NUMERO` est le numéro de la PR, `$N` du Step 2) :

```
| ➕ `Scripts/Transport.gd` ➕ `Scripts/TransportENet.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Decouverte.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ spec ✏️ `README.md` | Les 13 scénarios réseau verts, scénario 11 allongé (silence de 10 s). Faite (PR #NUMERO). |
```

puis :

```bash
perl -pi -e "s/PR #NUMERO/PR #$N/" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
grep -c "Faite (PR #$N)" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git add docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git commit -m "Feuille de route : phase 1 faite (PR #$N)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
git push
```

Expected : `1`.

- [ ] **Step 4 : la CI, puis la fusion** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
gh pr checks --repo w3cdotorg/LeLion-web "$N" --watch
gh pr merge --repo w3cdotorg/LeLion-web "$N" --merge
git switch main && git pull --ff-only && git log --oneline -3
```

Expected : la CI verte (le pas « Test réseau » sous ses 300 s : regarder sa durée, `gh run view --repo w3cdotorg/LeLion-web --json jobs`) ; la fusion faite, `main` à jour. La CI rouge : ne pas fusionner, diagnostiquer (le scénario 13 et son `ECART_CHRONO` : voir la Task 4, Step 4).
