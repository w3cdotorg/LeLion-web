# Phase 4 : WebRTC

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le jeu en ligne livré, de navigateur à navigateur : `TransportWebRTC` (spec §3.1), un `WebRTCMultiplayerPeer` en étoile autour de l'hôte (son navigateur fait autorité), signalé par le Worker de `signalisation/` (phase 2) ; dans l'export Web, *Créer une partie* et *Rejoindre* passent par lui (`transport_disponible` vrai partout). Le contrat de `Transport` s'ouvre à ce qui arrive après coup en WebRTC : le pair d'un client (son identifiant vient de `bienvenue`), la partie de l'hôte (son code vient de `salle`), son échec avant ce code, la fermeture de sa salle pendant la partie. L'écran En ligne attend le code (état CRÉATION) ; le salon de l'hôte dit la salle expirée. Un test de bout en bout Playwright (`tests/web/`) joue une vraie manche à trois pages sous Chromium et Firefox, et *Copier le lien* sous WebKit, en CI. Sortie : **une manche de 10 s à trois pages, la même empreinte partout, le départ de l'hôte vu** (spec §10), les suites Godot et le test réseau ENet inchangés et verts.

**Architecture:**
- **`Transport`** gagne `pair_pret()` (chez un client : son pair existe désormais, `Reseau` le donne alors à `SceneMultiplayer`, qui refuse un `WebRTCMultiplayerPeer` avant `create_client`) et `salle_fermee(raison)` (chez l'hôte après `pret` : plus d'arrivées, la partie continue) ; `echec(raison)` vaut aussi chez l'hôte avant `pret`. `TransportENet` n'émet ni l'un ni l'autre : rien n'y change.
- **`Reseau`** pose le pair dès qu'il existe (au retour de `rejoindre()`, ou à `pair_pret`), suit la création d'une partie jusqu'au `pret` de son transport (`_creation_en_cours` : un échec ou une fermeture d'ici là est un échec de connexion, `connexion_echouee` + `raison_echec`), émet `salon_change` au `pret` (le salon relit `code_partie`) et à la salle fermée (`raison_salle_fermee`), et choisit `TransportWebRTC` quand `OS.has_feature("web")` ; `fabrique_transport` (un `Callable`) laisse les tests y mettre un transport simulé.
- **`TransportWebRTC`** (`Scripts/TransportWebRTC.gd`, `class_name`) : la signalisation par `WebSocketPeer` (adresse : réglage de projet `lelion/signalisation/url`, `ws://localhost:8787` par défaut, celle de `wrangler dev`), messages décodés en entiers (`decoder`), envois en texte seulement par une file à 15 messages par seconde au plus (fenêtre glissante), le `ping` toutes les 30 s ; chez l'hôte `create_server` puis une `WebRTCPeerConnection` par `arrivee` (`add_peer`, serveurs ICE de l'arrivée, offre, `ouvert` au canal ouvert, retrait après 15 s ou sur `depart`), chez un client `create_client(id)` à `bienvenue` puis `pair_pret` ; délais de 5 s (signalisation) et 15 s (canal) ; canaux §5 (`unreliable_lifetime` 100 ms, un canal fiable en plus : le canal 1 de `SceneMultiplayer`) ; `?relais=1` → `iceTransportPolicy: "relay"`. Ses entrées et sorties (socket, connexions) sont des méthodes qu'une sous-classe des tests unitaires remplace : le desktop n'a pas de WebRTC.
- **`EcranEnLigne`** : un état CREATION entre *Créer une partie* et le salon, qui attend le code (`salon_change`) ; un échec y a son message (§9). **`Salon`** : une salle fermée remplace le code par « Salle expirée : crée une nouvelle partie pour inviter » (ou « Invitations coupées … »), sans lien.
- **Le pilote** (`Scripts/PiloteWeb.gd`, autoload inerte hors de l'export « Web pilote », préréglage d'export à la fonctionnalité `pilote`) : la page lui pousse des commandes (`window.lelionPilote.commandes` : créer, rejoindre, prêt, démarrer, peindre, quitter) et relit son état (`window.lelionPilote.etat`), par les vrais écrans du jeu ; il écrit l'empreinte de la manche dans la console.
- **Tests** : unitaires (le contrat tardif sur un transport simulé ; `TransportWebRTC` sans navigateur : aides pures, hôte, client, échecs, file) ; smoke (CRÉATION, échec avant le code, salle fermée au salon) ; `tests/web/` (Playwright 1.63.0 : Chromium et Firefox, une manche à trois pages, même empreinte lue dans la console, départ de l'hôte vu avant les 10 s de silence ; WebKit, *Copier le lien* sous un vrai clic) ; un job CI `bout-en-bout`.

**Tech Stack:** Godot 4.7.2 (GDScript typé, `WebRTCMultiplayerPeer`, `WebRTCPeerConnection`, `WebSocketPeer`, `JavaScriptBridge`, `SceneMultiplayer`), export Web single-thread (templates `web_nothreads_*` 4.7.2), Worker de la phase 2 en local (`wrangler dev` 4.146.0, Node 24.21.0 en CI), Playwright 1.63.0 (`@playwright/test`, navigateurs chromium 1243, firefox 1543, webkit 2359 ; image `mcr.microsoft.com/playwright:v1.63.0-noble`), Xvfb (`xvfb-run`), Python 3 (`http.server`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§2, §3.1 `Transport` et `TransportWebRTC`, §4 protocole tel que construit, §5 canaux, §8, §9, §10 bout en bout, §11) · feuille de route `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 4, « Notes de la revue de la phase 2 », « Notes de la revue de la phase 3 », « Vérification commune », « Points de vigilance ») · plan de la phase 3 (écarts 5 et 7 : `creer_partie` / `rejoindre_partie`, `raison_echec`, `Transport.ECHEC_*`) · prérequis : **phase 3 bis fusionnée** ; branche `phase-04-webrtc` depuis `main`.

## Global Constraints

- Transport (spec §2, §3.1) : « `WebRTCMultiplayerPeer`, en étoile autour de l'hôte (l'hôte en `create_server`, chaque client en `create_client`). Natif dans l'export Web de Godot, sans extension. » ; « Le choix du transport : `TransportWebRTC` quand `OS.has_feature("web")`, `TransportENet` sinon (ou forcé par les tests). » Pas d'extension webrtc-native (spec §1, hors périmètre) : sur le desktop, `WebRTCPeerConnection` n'a pas d'implémentation (« No default WebRTC extension configured ») ; `WebRTCMultiplayerPeer` y existe (`create_server`, `create_client`) sans connexion.
- Protocole de la salle (spec §4.2, tel que construit en phase 2, `signalisation/src/salle.js`) : reçus `{t:"salle", code, id:1, ice}`, `{t:"bienvenue", id, ice}`, `{t:"arrivee", id, ice}`, `{t:"offre"|"reponse", de, sdp}`, `{t:"candidat", de, media, index, nom}`, `{t:"depart", id}`, `{t:"erreur", raison}`, `{t:"pong"}` ; envoyés `{t:"offre"|"reponse", vers, sdp}`, `{t:"candidat", vers, media, index, nom}` (exactement ces champs : la salle ignore tout autre message), `{t:"ouvert", id}`, et le ping au texte exact `{"t":"ping"}`. Raisons : `inconnue`, `pleine`, `debit`, `quota`, `origine`, `expiree`, `delai`, aussi motif de la fermeture 1000 qui suit ; un client au canal ouvert est fermé 1000 `ouvert`, sans `erreur`.
- Notes de la revue de la phase 2 (feuille de route), mot pour mot : « Envoyer en texte seulement (`send_text`) » ; « Cadencer les envois de l'hôte (file, 15 par seconde au plus) […]. Cadencer aussi les clients. » ; « Identifiants : `int()` (le JSON de Godot donne des flottants). Le client apprend son id par `bienvenue.id` ; l'hôte est 1. » ; « Après `bienvenue`, le client ne ferme pas sa socket : il attend la fermeture 1000 `ouvert` de la salle. L'hôte ignore un `depart` d'un pair déjà connecté. » ; « Lire tous les paquets en attente même à l'état CLOSING ou CLOSED ; la raison de fermeture vaut la raison de l'`erreur` (repli). » ; « La fermeture de la socket de signalisation de l'hôte (`expiree`, son propre `debit`, coupure réseau) n'arrête pas la partie : seules les arrivées cessent. » ; « Pages de test sur `localhost`, pas `127.0.0.1` ».
- Notes de la revue de la phase 3 (feuille de route) : « Traiter `erreur delai` côté client […] et le `depart` qui suit côté hôte. » ; « Échec de création côté hôte avant `pret` […] le router en `connexion_echouee` + `raison_echec` » ; « `en_ligne()` […] est faux pour un client WebRTC entre `rejoindre_partie` et `bienvenue` […] ; l'écran ne doit pas s'y fier pendant la connexion. » ; « Sur le Web, un code `ip:port` doit être refusé proprement (ERR_INVALID_PARAMETER, message de format). » ; « un état CRÉATION qui attend `pret` […] ; émettre `salon_change` sur `pret` » ; « *Copier le lien* sous Safari/WebKit […] à tester sous WebKit (Playwright). »
- Délais (spec §4.3, §9) : 5 s sans `salle` ni `bienvenue` (« Service de connexion indisponible, réessaie dans un instant. ») ; canal fermé 15 s après `bienvenue` (« Connexion impossible avec l'hôte (réseau trop restrictif ?) »), et l'hôte retire le pair ; salle expirée : « Salle expirée : crée une nouvelle partie pour inviter » ; « Trop de parties en ce moment, réessaie plus tard. » (`quota`).
- Canaux (spec §5) : « canal 0 en non fiable […] `unreliable_lifetime` d'environ 100 ms […], canal 1 fiable et ordonné […] `CANAL_ORDONNE`, inchangé), configuré à la création du pair (`create_server` / `create_client` avec un canal fiable en plus des canaux par défaut). Le fiable du canal 0 […] reste sur le canal fiable par défaut. »
- `iceTransportPolicy` : vérifié dans les sources de Godot 4.7.2-stable (`modules/webrtc/library_godot_webrtc.js`, `godot_js_rtc_pc_create`) : la configuration de `WebRTCPeerConnection.initialize` est passée telle quelle, `new RTCPeerConnection(JSON.parse(config))` ; `{"iceServers": ice, "iceTransportPolicy": "relay"}` arrive donc entière au navigateur.
- Bout en bout (spec §10) : Chromium et Firefox, 3 pages, Worker en `wrangler dev`, export servi sur `http://localhost:8060` (la salle n'admet que `http://localhost:*`), en IPv4 (`--bind 127.0.0.1`) ; Worker sur `ws://localhost:8787` ; `@playwright/test` **1.63.0** exactement ; image locale `mcr.microsoft.com/playwright:v1.63.0-noble` ; Firefox avec une fenêtre sous Xvfb (sans affichage, il n'a pas de WebGL 2) ; l'exclusion (phase 7) n'y est pas encore.
- Version et protocole (feuille de route) : `config/version` reste **0.20** ; l'empreinte ne bouge pas (aucune RPC ni aucun format réseau ne change) : `PROTOCOLE 0.20 2553814265 (67 lignes)` avant comme après, mesurée sur ce plan appliqué à une copie du dépôt.
- Commandes : `export PATH="/opt/homebrew/bin:$PATH"` puis `cd ~/Sites/LeLion-web` ; chaque commande godot sous `timeout`, options écrites en clair (zsh ne découpe pas une variable non quotée : `--fixed-fps` sauterait en silence). Un test qui doit échouer sur une erreur de script peut se bloquer : `timeout -k 5 120`. Sur ce Mac, `docker` est celui d'OrbStack (`~/.orbstack/bin`, dans le `PATH` de `~/.zshrc`).
- Ports : les suites Godot et le test réseau prennent les ports 17777 à 19990 de ce poste ; un autre agent qui lance les mêmes suites en même temps fait échouer l'une ou l'autre (« un autre programme occupe le port … », vu en préparant ce plan) : une suite ne tourne qu'avec aucun autre `godot --headless` (`pgrep -f '^godot --headless'` vide), et un échec de port se relance une fois avant d'être diagnostiqué.
- Un test `--script` est compilé **avant** les autoloads : il récupère `Reseau`, `Scores`, `GameState`, `Parametres`, `PiloteWeb` par `root.get_node(...)`, ne les nomme jamais ; il peut nommer `Transport`, `TransportENet`, `TransportWebRTC`, `CodeSalle`, `EtatPartie` (aucun ne nomme d'autoload). `PiloteWeb.gd` nomme des autoloads : pas de `class_name`. Après la création d'un script (`TransportWebRTC`, `PiloteWeb`) : `godot --headless --import .` (il génère le `.uid`, à committer avec le script). Après une modification de `traductions.csv`, l'import régénère `traductions.fr.translation` et `traductions.en.translation` : les committer avec le CSV.
- Les blocs « Dans X, remplacer … par … » citent le texte exact laissé par la tâche précédente (vérifié en appliquant ce plan, tâche après tâche, à une copie de `main` où la phase 3 bis était fusionnée) ; chacun se fait avec l'outil Edit (texte exact, une seule occurrence), dans l'ordre donné. Les blocs « Créer X » donnent le fichier entier. Les blocs sont entourés de quatre accents graves (le README en contient trois).
- Identifiants, commentaires et messages en français, docstrings `##`, tabulations (GDScript, JavaScript, JSON du dépôt). Aucune séquence `\u…` tapée dans un fichier ; après chaque écriture, `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/web/*.js` ne sort rien. Aucun message de test ne contient `SCRIPT ERROR` ni `SHADER ERROR`.
- Bruit connu des sorties : celui des plans précédents (« ObjectDB instances were leaked », « resources still in use at exit », `ERROR: Couldn't create an ENet host.`, `ERROR: The local port number must be between 0 and 65535`), et désormais les `WARNING: Signalisation : erreur « … »` et `WARNING: Signalisation : pas de réponse en 5 s` des unitaires (le journal des raisons exactes, spec §9). Dans les pages du bout en bout : `WARNING: Lion : état de l'hôte illisible, ignoré` (trois fois par client à l'apparition des lions), et sous Firefox l'avertissement de WebAssembly sur l'instruction `try`.
- Commits en français, terminés par :
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT
  ```

## Review Focus

1. **Un client WebRTC qui ne rejoint jamais** (son pair posé avant `create_client` et refusé par `SceneMultiplayer`, un identifiant resté flottant, la fermeture 1000 `ouvert` prise pour un échec, une offre ou un candidat d'un autre que l'hôte appliqué) : `pair_pret` pose le pair, avec l'identifiant de `bienvenue` ; `ouvert` n'est jamais un échec, même avant le canal du client. → unitaires `_tester_transport_tardif` (« pair_pret : SceneMultiplayer prend le pair du transport, avec son identifiant ») et `_tester_transport_webrtc` (« les identifiants … deviennent des entiers », « bienvenue : son pair naît … », « la salle ferme la socket (1000 ouvert) sans échec … ») (Tasks 1, 2) ; bout en bout `@manche`, Anna et Bruno au salon (Task 5).
2. **Une salle qui chasse l'hôte ou l'ignore** (un envoi binaire, plus de 20 messages par seconde à six arrivées, un ping binaire ou reformaté, des entiers écrits en flottants) : `send_text` seulement, la file à 15 par seconde, le ping texte exact. → unitaires « la file attend la socket ouverte, puis envoie 15 messages au plus par seconde, tous, dans l'ordre », « toutes les 30 s, l'hôte envoie le ping, ce texte exact », « son offre puis ses candidats partent … les entiers en entiers » (Task 2).
3. **Une création qui échoue en silence** (l'hôte coincé sur un salon sans code, ou à l'accueil sans message, ou « hôte perdu » au lieu de « Trop de parties ») : l'échec avant `pret` est un échec de connexion, avec sa raison ; l'écran attend en CRÉATION. → unitaires « un échec du transport avant son pret : connexion échouée chez l'hôte … », « avant pret, la création échoue (une fois) … » (Tasks 1, 2) ; smoke « sans code du transport, Créer une partie attend … », « la création échoue avant le code (quota) … » (Task 3).
4. **Une partie arrêtée par la signalisation** (`expiree` ou une coupure de la socket de l'hôte pendant une manche, un `depart` d'un pair au canal ouvert) : seules les arrivées cessent, le salon le dit, la session continue. → unitaires « la salle expire après pret : seulement salle_fermee (une fois), la session continue », « un depart après ouvert est ignoré … », « la salle fermée après coup : la partie continue … » (Tasks 1, 2) ; smoke « la salle expire : « Salle expirée … », sans lien, la partie continue » (Task 3).
5. **Un bout en bout qui ment ou ne se reproduit pas** (une page figée hors du premier plan, une empreinte comparée sans que rien n'ait été peint, un départ vu seulement par le silence de 10 s, le pilote actif dans l'export livré, un pare-feu qui bloque WebRTC en local) : chaque poste peint, les trois empreintes de la console sont égales, le départ est vu en moins de 9 s, le pilote est inerte hors du préréglage « Web pilote » ; en local, le test tourne dans l'image Playwright. → `tests/web/bout_en_bout.spec.js` (`@manche`, `@lien`) (Task 5) ; unitaire « le pilote du test de bout en bout est inerte hors de l'export Web pilote » (Task 4) ; job CI `bout-en-bout` (Task 6).

## Écarts assumés

1. **Une seule PR pour la ligne 4**, comme la feuille de route le veut (« le WebRTC et son test de bout en bout vont ensemble ») : sans le bout en bout, rien ne prouverait que `TransportWebRTC` relie deux navigateurs (le desktop n'a pas de WebRTC). Fichiers au-delà de la ligne 4 : `Scripts/Transport.gd`, `Scripts/EcranEnLigne.gd`, `Scripts/Salon.gd`, `Assets/Traductions/traductions.csv` (+ `.translation`), `Scripts/PiloteWeb.gd`, `project.godot`, `export_presets.cfg`, `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/web/package.json` (+ `package-lock.json`, `.gitignore`, `.gdignore`), la spec et le README. Chaque tâche touche 5 fichiers de code au plus (plafond levé par l'utilisateur depuis la phase 1 ; tenu ici quand même).
2. **Le contrat de `Transport` (note de la revue de la phase 2)** : plutôt que de faire attendre `pair()` (que `Reseau` pose au retour de `rejoindre()`), un signal `pair_pret()` dit qu'il existe ; `Reseau` le pose alors, et `en_ligne()` reste faux d'ici là (documenté). `echec(raison)` vaut aussi chez l'hôte avant `pret` ; après `pret`, la fermeture de la salle n'est pas un échec mais `salle_fermee(raison)`, un signal à part (le même signal pour deux sens aurait fait dépendre sa lecture de l'état). `TransportENet` n'émet ni `pair_pret` ni `salle_fermee` : ses onze scénarios réseau ne bougent pas.
3. **`Reseau` : `_creation_en_cours`, `raison_salle_fermee`, `fabrique_transport`.** Le premier fait d'un échec ou d'une fermeture avant `pret` un `connexion_echouee` (comme `_connexion_en_cours` chez un client) ; le deuxième dit au salon pourquoi plus personne n'arrive ; le troisième (un `Callable`, invalide dans le jeu) est l'entrée des tests : un transport simulé, celui de l'unitaire (`TransportTardif`) ou du smoke (`TransportSalle`), sans réseau. `salon_change` part au `pret` et à la salle fermée.
4. **`TransportWebRTC` se teste sans navigateur par ses coutures** : ses entrées et sorties sont des méthodes (`_ouvrir_socket`, `_servir_socket`, `_socket_prete`, `_ecrire`, `_fermer_socket`, `_relier`, `_retirer`, `_appliquer_description`, `_appliquer_candidat`) que la sous-classe `TransportWebRTCSimule` des unitaires remplace ; tout le reste (messages, file, délais, signaux) est le code livré. Le vrai WebRTC n'est vérifié que de bout en bout (Task 5). La lecture des paquets à l'état CLOSED (`_servir_socket`) n'est donc couverte que par le bout en bout (la fermeture `ouvert` de chaque client).
5. **La file : une fenêtre glissante de 15 envois par seconde**, pas un envoi toutes les 67 ms : à 60 images par seconde, un écart fixe arrondi à l'image n'en envoyait que 13 (mesuré) ; une rafale de 15 après un silence reste sous le seau de 20 jetons de la salle, qui se remplit de 20 par seconde. Le `ping` passe par la même file.
6. **Délais** : 5 s pour `salle` (hôte) ou `bienvenue` (client) ; 15 s pour le canal d'un client depuis `bienvenue`, et chez l'hôte depuis `arrivee` (il retire alors l'arrivant ; la salle le dira `depart` plus tard). `erreur delai` est `ECHEC_DELAI` (« Connexion impossible avec l'hôte … »). Une socket fermée sans `ouvert` avant le canal d'un client est un échec : la raison de la dernière `erreur`, sinon le motif de la fermeture s'il est une raison connue, sinon `injoignable`. La fermeture `ouvert` arrive parfois avant l'ouverture du canal chez le client (l'hôte l'a vu ouvert d'abord) : elle n'arrête rien, le délai de 15 s continue.
7. **Réception tolérante, envoi strict** : un message reçu doit avoir les champs de son type, bien typés (les entiers convertis par `int()`, bornés à 1..2³¹-1, `index` à 0..2³¹-1) ; un champ en plus est toléré (un Worker plus récent peut en ajouter), un message mal formé est ignoré avec un avertissement, sans fermer la socket (spec §8.1).
8. **Deux messages de salle fermée** : `expiree` donne le texte du §9 ; les autres fermetures après `pret` (son propre `debit`, une coupure) « Invitations coupées : crée une nouvelle partie pour inviter », une clé de plus (`SALON_SALLE_FERMEE`). Le §9 de la spec est complété (Task 7).
9. **`transport_disponible` reste**, vrai partout depuis cette phase : c'est le garde-fou d'une plateforme sans transport, son message (« Pas encore de jeu en ligne … ») et ses tests (unitaire, smoke, capture `reseau_06_pas_de_transport`) restent tels quels ; seule sa docstring change. Le retirer aurait touché trois suites et le compte de captures de la CI pour un chemin que les tests gardent.
10. **L'adresse du Worker** : le réglage de projet `lelion/signalisation/url` (spec §11), `ws://localhost:8787` dans le dépôt (celle de `wrangler dev`) ; la phase 5 y mettra l'adresse déployée. Pas d'en-tête `Origin` (note de la revue de la phase 2) : `TransportWebRTC` ne sert que dans l'export Web, dont le navigateur l'envoie ; un `WebSocketPeer` natif ne parle jamais au Worker.
11. **Le pilote plutôt que des clics dans le canevas** : un test qui vise des pixels dépend de la mise à l'échelle et de la mise en page, et ne lit pas l'état du jeu ; le pilote mène les vrais écrans (`EcranEnLigne.creer_partie`, `rejoindre`, `Salon.basculer_pret`, `demarrer`, les touches du lion comme le test réseau) et rend un état JSON. Il ne vit que dans l'export « Web pilote » (préréglage d'export à la fonctionnalité `pilote`, jamais publié) : l'export livré ne l'active pas, même par un paramètre d'adresse. Commandes et état passent par `JavaScriptBridge.eval` à chaque image (pas de rappels JavaScript : rien à garder en vie). *Copier le lien*, lui, est cliqué pour de vrai (`page.mouse.click` au centre du bouton, que le pilote donne en pixels CSS) : c'est le geste de l'utilisateur que WebKit exige.
12. **L'empreinte du bout en bout** : territoire (propriétaire compté de chaque cellule), scores, tampons (nombre et empreinte de leur suite), joueurs de la manche, écrite dans la console (`EMPREINTE …`) à la fin de la manche sur chaque poste, et lue là par le test (spec §10). Pas la position des lions (le test réseau ENet la compare, au prix d'un gel au repos que trois navigateurs n'offrent pas) : ce que la manche décide chez l'hôte et diffuse, fiable et ordonné, y est. Chaque poste peint (sa passe : descendre vers la ville, peindre 2,5 s), et le test vérifie que chacun a des cellules.
13. **L'environnement du bout en bout (mesuré en préparant ce plan)** : Firefox sans affichage n'a pas de WebGL 2 (« Exhausted GL driver options »), d'où une fenêtre sous Xvfb (`headless: false`, `xvfb-run -a`) ; sous Xvfb sans gestionnaire de fenêtres, Firefox ne dessine plus une fenêtre entièrement couverte (0 image par seconde, le jeu figé) : chaque page a une fenêtre plus petite que la précédente. Une page chargée par `::1` ne donne à Firefox aucun candidat ICE dans un conteneur sans IPv6 : le serveur de l'export écoute `127.0.0.1`, la page reste `http://localhost:8060`. Sur ce Mac, le pare-feu bloque les connexions entrantes des navigateurs de Playwright (non signés) : WebRTC n'y relie jamais deux pages (vérifié avec deux `RTCPeerConnection` d'une même page) ; le bout en bout local tourne donc dans l'image `mcr.microsoft.com/playwright:v1.63.0-noble` (Docker, OrbStack ici), qui est aussi ce que voit la CI (Linux). WebKit (WebKitGTK) n'y relie pas deux pages non plus : il ne sert qu'à *Copier le lien*, qui n'a besoin que de la signalisation.
14. **Le job CI `bout-en-bout`** installe Godot et ses templates comme le job existant (mêmes commandes), exporte « Web pilote », installe Node 24.21.0, la signalisation et Playwright (`npx playwright install --with-deps chromium firefox webkit`), puis `xvfb-run -a npx playwright test` ; le rapport Playwright part en artefact en cas d'échec. Les jobs existants ne changent pas.
15. **Reporté** : « Garde cet onglet au premier plan pendant la partie. » (spec §5) va avec la section « Jouer en ligne » du README et « Tu as été déconnecté » (phase 7) ; l'exclusion et son étape du bout en bout (phase 7) ; `?relais=1` n'est pas joué de bout en bout (le TURN exige les secrets du Worker, phase 5) : seule sa configuration est vérifiée (unitaire).
16. **Version et protocole** : rien de ce que deux postes se disent ne change (le transport est sous `SceneMultiplayer`) : version 0.20, empreinte inchangée (mesurée).
17. **Step 0** (règle du projet, `Reseau.gd` 1140 lignes, `Salon.gd` 342 lignes) : rien à retirer (vérifié, Task 0) ; la phase n'y fait pas de refonte structurelle.

---

### Task 0 : préparation, Step 0 et références

Ce plan est commité par le commit de planification : ne pas le recommiter, ne jamais le modifier.

**Files:** aucun (vérifications seulement).

**Interfaces:** aucune.

- [ ] **Step 1 : la branche**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
git switch main && git pull --ff-only
git log --oneline main | grep -m1 "phase-03bis-retrait-decouverte" || echo "PHASE 3 BIS ABSENTE"
git switch -c phase-04-webrtc
wc -l Scripts/Reseau.gd Scripts/Salon.gd Scripts/EcranEnLigne.gd Scripts/Transport.gd tests/unitaires.gd tests/smoke_test.gd
grep -n 'config/version' project.godot
grep -rln "Decouverte\|EcranReseau\|DIFFUSION" Scripts Scenes tests project.godot .github README.md; echo "grep $?"
```

Expected : la fusion de la PR de la phase 3 bis (`Merge pull request #… from w3cdotorg/phase-03bis-retrait-decouverte`) ; `1140 Scripts/Reseau.gd`, `342 Scripts/Salon.gd`, `290 Scripts/EcranEnLigne.gd`, `77 Scripts/Transport.gd`, `2714 tests/unitaires.gd`, `2415 tests/smoke_test.gd` ; `config/version="0.20"` ; `grep 1`. « PHASE 3 BIS ABSENTE » ou d'autres longueurs : s'arrêter et le signaler (les blocs de ce plan citent le texte de `main` après la 3 bis).

- [ ] **Step 2 : Step 0 (règle du projet, `Reseau.gd` et `Salon.gd` font plus de 300 lignes)**

```bash
for f in Scripts/Reseau.gd Scripts/Salon.gd; do
	for n in $(grep -oE "^(const|var|func|static func|signal|enum) [A-Za-z_]+" $f | awk '{print $NF}'); do
		[ "$(grep -rwo "$n" Scripts tests Scenes | wc -l | tr -d ' ')" -lt 2 ] && echo "seul : $f $n"
	done
	grep -nE "^[[:space:]]*(print|prints|printt|print_debug|breakpoint)\b" $f
done
```

Expected (mesuré) : rien. **Pas de commit de nettoyage.** Une ligne `seul :` ou un `print` : le retirer dans un commit à part (`Step 0 : code mort retiré`) avant la Task 1.

- [ ] **Step 3 : les références, et ce qu'il faut au bout en bout**

```bash
pgrep -f '^godot --headless' || echo "aucun autre godot"
timeout 300 godot --headless --import . > /dev/null 2>&1
timeout -k 5 300 godot --headless --script tests/unitaires.gd 2>&1 | grep -E "PROTOCOLE|== "
SECONDS=0; timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r0.log" 2>&1; echo "code $? en ${SECONDS} s"
grep -E "❌|== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r0.log"
(cd signalisation && npm ci --silent && npm test 2>&1 | tail -3)
ls "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/" | grep web_nothreads
docker image inspect mcr.microsoft.com/playwright:v1.63.0-noble > /dev/null 2>&1 || docker pull -q mcr.microsoft.com/playwright:v1.63.0-noble
```

Expected : « aucun autre godot » (sinon attendre qu'ils finissent : mêmes ports) ; `PROTOCOLE 0.20 2553814265 (67 lignes)`, `== 0 échec(s) ==` ; réseau `code 0`, `== 0 échec(s) ==`, 155 à 170 s (mesuré 160 s) ; les tests du Worker verts ; `web_nothreads_debug.zip` et `web_nothreads_release.zip` ; l'image Playwright présente (ou tirée, une trentaine de secondes). Sans les templates Web (installation locale permise, dossier standard de l'utilisateur) :

```bash
T="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"; mkdir -p "$T"
curl -sSL -o "$TMPDIR/tpl.tpz" "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
unzip -j -o "$TMPDIR/tpl.tpz" templates/version.txt templates/web_nothreads_debug.zip templates/web_nothreads_release.zip -d "$T"; rm "$TMPDIR/tpl.tpz"
```

Noter les mesures pour la PR (jamais commitées).

---

### Task 1 : le contrat de `Transport` pour ce qui arrive après coup (pair d'un client, partie de l'hôte)

**Files:**
- Modify: `Scripts/Transport.gd` (signaux `pair_pret`, `salle_fermee` ; `echec` chez l'hôte avant `pret` ; docstrings de `heberger`, `pair`)
- Modify: `Scripts/Reseau.gd` (le pair posé à `pair_pret`, `_creation_en_cours`, `raison_salle_fermee`, `fabrique_transport`, `salon_change` au `pret`)
- Modify: `tests/unitaires.gd` (`_tester_transport_tardif`, classe `TransportTardif`)

**Interfaces:**
- `Transport` : `signal pair_pret()`, `signal salle_fermee(raison: String)` ; `signal echec(raison: String)` (chez un client, ou chez l'hôte avant `pret`).
- `Reseau` : `var raison_salle_fermee := ""`, `var fabrique_transport := Callable()` (`func(port: int) -> Transport`) ; `_sur_transport_pair_pret(generation: int)`, `_sur_transport_salle_fermee(raison: String, generation: int)` ; `connexion_echouee` aussi chez l'hôte avant le `pret` de son transport.

- [ ] **Step 1 : le test qui échoue**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	await _tester_battement()
	await _tester_parties_en_ligne()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

par :

````gdscript
	await _tester_battement()
	await _tester_parties_en_ligne()
	await _tester_transport_tardif()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
## valeur.
````

par :

````gdscript
## Phase 4 du jeu en ligne : un transport dont la partie et le pair arrivent après coup, comme
## `TransportWebRTC` (simulé : `TransportTardif`) : la création qui attend le `pret` du transport (et son
## échec, routé comme un échec de connexion), la salle fermée après coup (la partie continue), le pair d'un
## client posé à `pair_pret`.
func _tester_transport_tardif() -> void:
	print("-- Transport tardif (phase 4)")
	var reseau: Node = root.get_node("Reseau")  # autoload : jamais nommé (compilé avant lui)
	var transports: Array[TransportTardif] = []
	reseau.fabrique_transport = func(_port: int) -> Transport:
		transports.append(TransportTardif.new())
		return transports[-1]
	var changes := [0]
	var sur_change := func() -> void: changes[0] += 1
	reseau.salon_change.connect(sur_change)
	var echecs: Array[String] = []
	var sur_echec := func() -> void: echecs.append(reseau.raison_echec)
	reseau.connexion_echouee.connect(sur_echec)
	var pertes := [0]
	var sur_perte := func() -> void: pertes[0] += 1
	reseau.hote_perdu.connect(sur_perte)

	# L'hôte : la partie a son code au `pret` du transport, qui ne vient pas pendant l'appel.
	_check(reseau.creer_partie() == OK and reseau.en_ligne() and root.multiplayer.is_server() and reseau.code_partie.is_empty()
		and reseau.inscrits.size() == 1,
		"créer une partie : ce poste héberge et s'inscrit, sans code tant que le transport ne l'a pas donné")
	changes[0] = 0
	transports[-1].pret.emit("K7Q2XM")
	_check(reseau.code_partie == "K7Q2XM" and changes[0] == 1,
		"le pret du transport donne son code à la partie, que le salon relit (un salon_change)")
	transports[-1].echec.emit(Transport.ECHEC_QUOTA)
	await process_frame
	await process_frame
	_check(echecs.is_empty() and reseau.en_ligne(), "un échec du transport après son pret ne défait pas une partie créée")
	transports[-1].salle_fermee.emit(Transport.ECHEC_EXPIREE)
	_check(reseau.raison_salle_fermee == Transport.ECHEC_EXPIREE and changes[0] == 2 and reseau.en_ligne() and reseau.code_partie == "K7Q2XM",
		"la salle fermée après coup : la partie continue, le salon le sait (raison_salle_fermee, un salon_change)")
	reseau.quitter()
	_check(reseau.raison_salle_fermee.is_empty() and transports[-1].quitte, "quitter oublie la salle fermée et quitte le transport")

	# L'hôte : la création échoue avant le pret.
	_check(reseau.creer_partie() == OK and reseau.en_ligne(), "(pré-condition) une nouvelle partie en création")
	transports[-1].echec.emit(Transport.ECHEC_QUOTA)
	_check(await _attendre(func() -> bool: return echecs.size() == 1, 1.0) and echecs == [Transport.ECHEC_QUOTA] and not reseau.en_ligne()
		and pertes[0] == 0,
		"un échec du transport avant son pret : connexion échouée chez l'hôte, sa raison dans raison_echec, hors réseau (%s)" % [echecs])
	_check(reseau.creer_partie() == OK, "(pré-condition) une autre partie en création")
	transports[-1].perdu = true  # le transport se ferme de lui-même, sans raison
	_check(await _attendre(func() -> bool: return echecs.size() == 2, 1.0) and echecs[1].is_empty() and pertes[0] == 0 and not reseau.en_ligne(),
		"un transport fermé de lui-même avant son pret : connexion échouée aussi, pas un hôte perdu (%s)" % [echecs])
	transports[-1].salle_fermee.emit(Transport.ECHEC_EXPIREE)
	_check(reseau.raison_salle_fermee.is_empty(), "le signal d'un transport quitté ne fait plus rien")

	# Le client : son pair n'existe qu'à pair_pret (son identifiant vient de la signalisation).
	_check(reseau.rejoindre_partie("K7Q2XM") == OK and not reseau.en_ligne() and reseau._connexion_en_cours,
		"rejoindre : en connexion, mais pas en ligne tant que le pair du transport n'existe pas")
	transports[-1].donner_identifiant(123456789)
	_check(reseau.en_ligne() and root.multiplayer.multiplayer_peer == transports[-1].pair()
		and root.multiplayer.get_unique_id() == 123456789 and not root.multiplayer.is_server(),
		"pair_pret : SceneMultiplayer prend le pair du transport, avec son identifiant (%d)" % root.multiplayer.get_unique_id())
	transports[-1].echec.emit(Transport.ECHEC_DELAI)
	_check(await _attendre(func() -> bool: return echecs.size() == 3, 1.0) and echecs[2] == Transport.ECHEC_DELAI and not reseau.en_ligne(),
		"le canal ne s'ouvre pas : connexion échouée, raison delai (%s)" % [echecs])
	_check(reseau.rejoindre_partie("K7Q2XM") == OK, "(pré-condition) une nouvelle connexion")
	reseau.quitter()
	transports[-1].donner_identifiant(42)
	_check(not reseau.en_ligne(), "le pair_pret d'un transport quitté n'est pas posé")
	_check(reseau.rejoindre_partie("K7Q2XM") == OK, "(pré-condition) encore une connexion")
	transports[-1].perdu = true
	_check(await _attendre(func() -> bool: return echecs.size() == 4, 1.0) and echecs[3].is_empty() and pertes[0] == 0 and not reseau.en_ligne(),
		"un client dont le transport se ferme avant son pair : connexion échouée, pas un hôte perdu (%s)" % [echecs])

	reseau.salon_change.disconnect(sur_change)
	reseau.connexion_echouee.disconnect(sur_echec)
	reseau.hote_perdu.disconnect(sur_perte)
	reseau.fabrique_transport = Callable()
	await _attendre(func() -> bool: return reseau._partants.is_empty(), 2.0)


## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
## valeur.
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	func servir() -> bool:
		return reel.servir() and not perdu
````

par :

````gdscript
	func servir() -> bool:
		return reel.servir() and not perdu


## Un transport simulé (`_tester_transport_tardif`) : `heberger()` et `rejoindre()` réussissent sans
## rien ouvrir ni rien dire ; le test émet lui-même `pret`, `echec` et `salle_fermee`, comme le ferait
## `TransportWebRTC`. Son pair est un `WebRTCMultiplayerPeer` (il existe sur le desktop, sans connexion) :
## celui de l'hôte dès `heberger()`, celui d'un client à `donner_identifiant` (puis `pair_pret`).
## `servir()` faux dès que `perdu` est vrai (fermé de lui-même), ou une fois quitté.
class TransportTardif extends Transport:
	var perdu := false
	var quitte := false
	var _pair: WebRTCMultiplayerPeer

	func heberger() -> Error:
		_pair = WebRTCMultiplayerPeer.new()
		return _pair.create_server()

	func rejoindre(_code: String) -> Error:
		return OK

	## Chez un client : son identifiant arrive (`bienvenue`) ; son pair naît, puis `pair_pret`.
	func donner_identifiant(id: int) -> void:
		_pair = WebRTCMultiplayerPeer.new()
		_pair.create_client(id)
		pair_pret.emit()

	func quitter() -> void:
		quitte = true
		clore()

	func clore() -> void:
		if _pair != null:
			_pair.close()
			_pair = null

	func pair() -> MultiplayerPeer:
		return _pair

	func liberer(_id: int) -> void:
		pass

	func servir() -> bool:
		return not perdu and not quitte
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "SCRIPT ERROR|Parse Error|pair_pret|salle_fermee" "$TMPDIR/u.log" | head -4
```

Expected : `unitaires 0` (Godot sort en 0 sans rien lancer) et `SCRIPT ERROR: Parse Error: Identifier "pair_pret" not declared in the current scope.` (`res://tests/unitaires.gd:2817`, dans `TransportTardif`) : la suite ne se compile pas (`Failed to load script "res://tests/unitaires.gd"`), aucun test ne tourne.

- [ ] **Step 3 : le contrat**

Dans `Scripts/Transport.gd`, remplacer :

````gdscript
## clients, sous le `MultiplayerPeer` que `Reseau` donne à `SceneMultiplayer`. Ne sait rien du salon
## ni du jeu : la poignée de main, la table, le battement et les départs restent dans `Reseau`.
## Deux implémentations : `TransportENet` (desktop de développement, tests headless), puis
## `TransportWebRTC` (l'export Web, phase 4).
##
## Contrat commun : `heberger()` ou `rejoindre()` une seule fois par objet ; `servir()` à chaque
## image tant qu'il renvoie vrai (session ouverte, ou départ en cours après `quitter()`) ; `servir()`
## faux sans `quitter()` ni `clore()` : la session est perdue (le transport s'est fermé de lui-même),
## `Reseau` la traite comme la perte de l'hôte (un échec de connexion avant l'inscription). Après
## `quitter()` ou `clore()`, plus aucun signal.

## Chez l'hôte : la session existe, `code` est ce qu'un client donne à `rejoindre()`.
signal pret(code: String)
## Chez un client : le canal vers l'hôte est ouvert, la poignée de main de `SceneMultiplayer` peut
## partir.
signal connecte()
## Chez un client : le canal ne s'ouvrira pas ; `raison` est une des constantes ECHEC_*. Le transport ne
## se ferme pas seul : l'appelant le quitte ensuite (`quitter()`).
signal echec(raison: String)

## Le canal vers l'hôte ne s'est pas ouvert dans le délai du transport (en WebRTC, aussi le refus `delai`
## de la signalisation, le même mot : l'hôte n'a pas ouvert le canal à temps).
const ECHEC_DELAI := "delai"
## La signalisation n'a pas répondu à temps (`TransportWebRTC`, phase 4 ; spec §9 : 5 s).
const ECHEC_INJOIGNABLE := "injoignable"
## Les autres refus de la signalisation (son message `erreur`, spec §4.2), que `TransportWebRTC` (phase 4)
## rend tels quels, la raison exacte écrite au journal : aucune salle de ce code, salle pleine, débit
## dépassé, quota gratuit épuisé, origine refusée, salle expirée.
const ECHEC_INCONNUE := "inconnue"
````

par :

````gdscript
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
## encore le sien. `Reseau` le pose alors. Jamais chez un transport dont le pair existe dès le retour de
## `rejoindre()` (ENet), jamais pendant l'appel.
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
````

Dans `Scripts/Transport.gd`, remplacer :

````gdscript
## Ouvre une session hébergée ; `pret` part quand elle existe (pendant l'appel ou plus tard, selon le
## transport). Une erreur laisse ce transport inutilisable, sans rien d'ouvert.
@abstract func heberger() -> Error
````

par :

````gdscript
## Ouvre une session hébergée ; `pret` part quand elle existe (pendant l'appel ou plus tard, selon le
## transport), ou `echec` si elle ne peut pas exister (jamais pendant l'appel). Une erreur laisse ce
## transport inutilisable, sans rien d'ouvert.
@abstract func heberger() -> Error
````

Dans `Scripts/Transport.gd`, remplacer :

````gdscript
## Le pair que `Reseau` donne à `SceneMultiplayer` (null avant `heberger()` / `rejoindre()` réussis,
## et après la fermeture). Valide (en connexion ou connecté) dès le retour d'un `heberger()` ou d'un
## `rejoindre()` réussi : `Reseau` le pose aussitôt. Un client WebRTC ne le pourra pas (son identifiant
## vient de la signalisation) : contrat à revoir en phase 4.
@abstract func pair() -> MultiplayerPeer
````

par :

````gdscript
## Le pair que `Reseau` donne à `SceneMultiplayer` (null avant `heberger()` / `rejoindre()` réussis,
## et après la fermeture). Valide (en connexion ou connecté) dès le retour d'un `heberger()` réussi, et
## dès le retour d'un `rejoindre()` réussi ou plus tard, à `pair_pret` (WebRTC) : `Reseau` le pose dès
## qu'il existe.
@abstract func pair() -> MultiplayerPeer
````

- [ ] **Step 4 : `Reseau`**

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## `quitter()` y revient toujours.
##
## Transport (phase 1 du jeu en ligne) : les canaux sont ceux d'un `Transport` (`TransportENet`, puis
## `TransportWebRTC` en phase 4), dont ce script donne le pair à `SceneMultiplayer` et qu'il sert à
## chaque image ; il ne nomme aucune classe d'ENet. Un transport quitté finit son départ en
## arrière-plan (`_partants`).
##
## Battement et silences : chaque poste en session envoie un battement par seconde (`_battement`, non
````

par :

````gdscript
## `quitter()` y revient toujours.
##
## Transport (phase 1 du jeu en ligne) : les canaux sont ceux d'un `Transport` (`TransportENet`, ou
## `TransportWebRTC` dans l'export Web), dont ce script donne le pair à `SceneMultiplayer` dès qu'il
## existe (au retour de `rejoindre()`, ou plus tard : `Transport.pair_pret`) et qu'il sert à chaque
## image ; il ne nomme aucune classe d'ENet. Un transport quitté finit son départ en arrière-plan
## (`_partants`). Chez l'hôte, la partie n'existe qu'au `pret` du transport (son code) : un échec avant
## est un échec de connexion ; après, la fermeture de la salle (`Transport.salle_fermee`) n'arrête que
## les arrivées.
##
## Battement et silences : chaque poste en session envoie un battement par seconde (`_battement`, non
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
signal refuse(raison: String, version_hote: String)
## Chez le client : pas d'inscription (le transport n'a pas ouvert son canal, ou la poignée de main n'a
## pas fini dans son délai). Le poste est déjà revenu hors réseau quand le signal part ; `raison_echec`
## dit pourquoi.
signal connexion_echouee()
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
````

par :

````gdscript
signal refuse(raison: String, version_hote: String)
## Chez le client : pas d'inscription (le transport n'a pas ouvert son canal, ou la poignée de main n'a
## pas fini dans son délai). Chez l'hôte : la partie n'a pas pu être créée (le transport échoue avant son
## `pret` : la signalisation refuse ou ne répond pas). Le poste est déjà revenu hors réseau quand le
## signal part ; `raison_echec` dit pourquoi.
signal connexion_echouee()
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Sur chaque poste en session : la table du salon (`table_salon`), son niveau ou ses places ont
## changé ; chez l'hôte, aussi quand une place se réserve ou se libère (le bouton Démarrer en
## dépend, `raison_attente`).
signal salon_change()
## Sur chaque poste en session : l'hôte lance la manche. `fiches` : une fiche
````

par :

````gdscript
## Sur chaque poste en session : la table du salon (`table_salon`), son niveau ou ses places ont
## changé ; chez l'hôte, aussi quand une place se réserve ou se libère (le bouton Démarrer en
## dépend, `raison_attente`), quand la partie a son code (`code_partie`) et quand plus personne ne peut
## la rejoindre (`raison_salle_fermee`).
signal salon_change()
## Sur chaque poste en session : l'hôte lance la manche. `fiches` : une fiche
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Chez un client : pourquoi la dernière connexion a échoué, posé juste avant `connexion_echouee` : la raison
## du transport (Transport.ECHEC_*), ou vide (la poignée de main sans réponse dans son délai, un transport
## fermé de lui-même) ; ce que montre l'écran En ligne (spec §9).
var raison_echec := ""
## Vrai si ce poste a un transport pour jouer en réseau : ENet hors du Web (le desktop de développement, les
## tests) ; faux dans l'export Web jusqu'à `TransportWebRTC` (phase 4) : `creer_partie` et
## `rejoindre_partie` y renvoient ERR_UNAVAILABLE sans rien ouvrir. Modifiable par les tests.
var transport_disponible := not OS.has_feature("web")
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
var index_local := -1
````

par :

````gdscript
## avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Chez un client, ou chez l'hôte dont la partie n'a pas pu être créée : pourquoi la dernière connexion a
## échoué, posé juste avant `connexion_echouee` : la raison du transport (Transport.ECHEC_*), ou vide (la
## poignée de main sans réponse dans son délai, un transport fermé de lui-même) ; ce que montre l'écran En
## ligne (spec §9).
var raison_echec := ""
## Chez l'hôte : pourquoi plus personne ne peut rejoindre la partie (`Transport.salle_fermee` :
## Transport.ECHEC_EXPIREE, ou une autre raison), vide tant que la salle accueille ; le salon le dit à la
## place du code. La partie continue. Vide hors réseau et chez un client.
var raison_salle_fermee := ""
## Vrai si ce poste a un transport pour jouer en réseau : ENet hors du Web (le desktop de développement, les
## tests) ; faux dans l'export Web jusqu'à `TransportWebRTC` (phase 4) : `creer_partie` et
## `rejoindre_partie` y renvoient ERR_UNAVAILABLE sans rien ouvrir. Modifiable par les tests.
var transport_disponible := not OS.has_feature("web")
## Si valide, fabrique le transport de chaque nouvelle session à la place de `_nouveau_transport`
## (`func(port: int) -> Transport`) : les tests y mettent un transport simulé. Invalide dans le jeu.
var fabrique_transport := Callable()
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
var index_local := -1
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## de connexion, pas un hôte perdu.
var _connexion_en_cours := false
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
````

par :

````gdscript
## de connexion, pas un hôte perdu.
var _connexion_en_cours := false
## Chez l'hôte : vrai de `heberger()` au `pret` du transport, quand il ne vient pas pendant l'appel
## (WebRTC : la salle de la signalisation) ; un échec ou une fermeture pendant ce temps est un échec de
## connexion : la partie n'a jamais existé.
var _creation_en_cours := false
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
		return erreur
	_transport = transport
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = transport.pair()
````

par :

````gdscript
		return erreur
	_transport = transport
	_creation_en_cours = code_partie.is_empty()  # `pret` n'est pas parti pendant l'appel : il viendra
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = transport.pair()
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## réponse arrive par `inscrit`, `refuse` ou `connexion_echouee` (au plus tard après le délai du canal du
## transport, puis DELAI_CONNEXION). Renvoie l'erreur du transport si le client ne peut même pas être créé.
func rejoindre_partie(code: String) -> Error:
	if not transport_disponible:
````

par :

````gdscript
## réponse arrive par `inscrit`, `refuse` ou `connexion_echouee` (au plus tard après le délai du canal du
## transport, puis DELAI_CONNEXION). Renvoie l'erreur du transport si le client ne peut même pas être créé.
## Le pair du transport est posé dès qu'il existe : au retour (ENet), ou à `Transport.pair_pret` (WebRTC,
## à l'arrivée de son identifiant) ; d'ici là `en_ligne()` reste faux.
func rejoindre_partie(code: String) -> Error:
	if not transport_disponible:
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
	_connexion_en_cours = true
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = transport.pair()
	return OK
````

par :

````gdscript
	_connexion_en_cours = true
	_activer_poignee_de_main()
	if transport.pair() != null:
		multiplayer.multiplayer_peer = transport.pair()
	return OK
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
	_entendus.clear()
	code_partie = ""
	_raison_transport = ""
	_connexion_en_cours = false
	niveau_salon = 0
	places_salon = EtatPartie.NB_JOUEURS_MAX
````

par :

````gdscript
	_entendus.clear()
	code_partie = ""
	raison_salle_fermee = ""
	_raison_transport = ""
	_connexion_en_cours = false
	_creation_en_cours = false
	niveau_salon = 0
	places_salon = EtatPartie.NB_JOUEURS_MAX
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Le transport d'une nouvelle session : ENet (le desktop, les tests ; WebRTC dans l'export Web, phase 4).
func _nouveau_transport(port: int) -> Transport:
	return TransportENet.new(port, places)
````

par :

````gdscript
## Le transport d'une nouvelle session : celui de `fabrique_transport` (les tests), sinon ENet (le
## desktop, les tests ; WebRTC dans l'export Web, phase 4).
func _nouveau_transport(port: int) -> Transport:
	if fabrique_transport.is_valid():
		return fabrique_transport.call(port)
	return TransportENet.new(port, places)
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
	transport.pret.connect(_sur_transport_pret.bind(_generation))
	transport.connecte.connect(_sur_transport_connecte.bind(_generation))
	transport.echec.connect(_sur_transport_echec.bind(_generation))
````

par :

````gdscript
	transport.pret.connect(_sur_transport_pret.bind(_generation))
	transport.connecte.connect(_sur_transport_connecte.bind(_generation))
	transport.pair_pret.connect(_sur_transport_pair_pret.bind(_generation))
	transport.echec.connect(_sur_transport_echec.bind(_generation))
	transport.salle_fermee.connect(_sur_transport_salle_fermee.bind(_generation))
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Vrai si ce poste est en réseau (hôte ou client), faux hors réseau (solo).
func en_ligne() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
````

par :

````gdscript
## Vrai si ce poste est en réseau (hôte ou client), faux hors réseau (solo), et chez un client tant que
## le pair de son transport n'existe pas (WebRTC : avant l'arrivée de son identifiant, `pair_pret`) :
## l'écran En ligne ne s'y fie pas pendant une connexion.
func en_ligne() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## L'hôte ferme la connexion, ou le transport de la session s'est fermé de lui-même (`_process`). Avant
## l'inscription, c'est un échec de connexion, pas un hôte perdu : ce poste n'a jamais été dans la partie.
## Chez l'hôte, la session est perdue : `hote_perdu` aussi, le chemin de N4 (son pair tombé en erreur).
## Idempotent (`_decider`).
func _sur_hote_perdu() -> void:
	_decider("connexion_echouee" if _connexion_en_cours else "hote_perdu")
````

par :

````gdscript
## L'hôte ferme la connexion, ou le transport de la session s'est fermé de lui-même (`_process`). Avant
## l'inscription, c'est un échec de connexion, pas un hôte perdu : ce poste n'a jamais été dans la partie ;
## de même chez l'hôte avant le `pret` de son transport. Chez l'hôte, la session est perdue : `hote_perdu`
## aussi, le chemin de N4 (son pair tombé en erreur). Idempotent (`_decider`).
func _sur_hote_perdu() -> void:
	_decider("connexion_echouee" if _connexion_en_cours or _creation_en_cours else "hote_perdu")
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Chez l'hôte : la session du transport existe ; son code est celui de la partie.
func _sur_transport_pret(code: String, generation: int) -> void:
	if generation == _generation:
		code_partie = code
````

par :

````gdscript
## Chez l'hôte : la session du transport existe ; son code est celui de la partie (le salon le relit).
func _sur_transport_pret(code: String, generation: int) -> void:
	if generation == _generation:
		code_partie = code
		_creation_en_cours = false
		salon_change.emit()
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Chez un client : le canal vers l'hôte ne s'ouvrira pas : un échec de connexion, dont `raison`
## (Transport.ECHEC_*) devient `raison_echec`.
func _sur_transport_echec(raison: String, generation: int) -> void:
	if generation == _generation and _connexion_en_cours and not _issue_decidee:
		_raison_transport = raison
		_decider("connexion_echouee")
````

par :

````gdscript
## Chez un client : le pair du transport existe désormais (WebRTC : son identifiant est arrivé) ;
## `SceneMultiplayer` le prend, la connexion continue.
func _sur_transport_pair_pret(generation: int) -> void:
	if generation == _generation and _connexion_en_cours and _transport != null:
		multiplayer.multiplayer_peer = _transport.pair()


## Chez un client, le canal vers l'hôte ne s'ouvrira pas ; chez l'hôte, la partie ne sera pas créée (avant
## le `pret` de son transport) : un échec de connexion, dont `raison` (Transport.ECHEC_*) devient
## `raison_echec`. Ailleurs (une partie créée, un client inscrit), sans effet.
func _sur_transport_echec(raison: String, generation: int) -> void:
	if generation == _generation and (_connexion_en_cours or _creation_en_cours) and not _issue_decidee:
		_raison_transport = raison
		_decider("connexion_echouee")


## Chez l'hôte : plus personne ne peut rejoindre la partie (la salle a expiré, ou la signalisation s'est
## fermée) ; la partie continue, le salon le dit (`raison_salle_fermee`).
func _sur_transport_salle_fermee(raison: String, generation: int) -> void:
	if generation == _generation and multiplayer.is_server() and en_ligne():
		raison_salle_fermee = raison
		salon_change.emit()
````

- [ ] **Step 5 : le test passe, rien d'autre ne bouge**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u.log"; grep -c "✅" "$TMPDIR/u.log"
sed -n '/-- Transport tardif/,/^--/p' "$TMPDIR/u.log" | grep -c "✅"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"
SECONDS=0; timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/r.log"
```

Expected : rien à l'import ; unitaires `0`, `PROTOCOLE 0.20 2553814265 (67 lignes)`, `== 0 échec(s) ==`, 477 ✅ en tout, dont 17 dans « -- Transport tardif (phase 4) » ; smoke `0`, `== 0 échec(s) ==` ; réseau `0`, `== 0 échec(s) ==` (ENet n'émet ni `pair_pret` ni `salle_fermee` : ses onze scénarios sont ceux de la Task 0).

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Transport.gd Scripts/Reseau.gd tests/unitaires.gd
git commit -m "Transport : pair_pret (le pair d'un client qui naît après rejoindre, son identifiant venu de la signalisation), echec chez l'hôte avant pret (routé en connexion_echouee et raison_echec), salle_fermee après pret (la partie continue) ; Reseau pose le pair à pair_pret, suit la création jusqu'au pret, émet salon_change au pret et à la salle fermée ; fabrique_transport pour les tests

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 2 : `TransportWebRTC`

**Files:**
- Create: `Scripts/TransportWebRTC.gd` (+ `Scripts/TransportWebRTC.gd.uid`, généré par l'import)
- Modify: `project.godot` (réglage `lelion/signalisation/url`)
- Modify: `tests/unitaires.gd` (`_tester_transport_webrtc`, classe `TransportWebRTCSimule`)

**Interfaces:**
- `class_name TransportWebRTC extends Transport` ; `_init()` (sur le Web, `relais` lu de `location.search`) ; `heberger() -> Error`, `rejoindre(code: String) -> Error` (ERR_INVALID_PARAMETER sans code de salle normalisé), `quitter()`, `clore()`, `pair() -> MultiplayerPeer`, `liberer(id: int)`, `servir() -> bool` ; `var relais := false`.
- Constantes : `REGLAGE_URL := "lelion/signalisation/url"`, `URL_SIGNALISATION := "ws://localhost:8787"`, `CHEMIN_CREER := "/v1/creer"`, `CHEMIN_REJOINDRE := "/v1/rejoindre/"`, `ID_HOTE := 1`, `ID_MAX := 2147483647`, `DELAI_SIGNALISATION := 5.0`, `DELAI_CANAL := 15.0`, `ENVOIS_PAR_SECONDE := 15`, `PERIODE_PING := 30.0`, `PING := '{"t":"ping"}'`, `DUREE_NON_FIABLE := 100`, `CANAUX := [MultiplayerPeer.TRANSFER_MODE_RELIABLE]`, `DELAI_DEPART := 1000`, `MOTIF_OUVERT := "ouvert"`, `PARAMETRE_RELAIS := "relais"`, `RAISONS_SALLE: Array[String]`, `CHAMPS` (les champs de chaque message reçu).
- Aides pures : `static func url_signalisation() -> String`, `static func lire_relais(recherche: String) -> bool`, `static func configuration_ice(ice: Array, relais_seul: bool) -> Dictionary`, `static func decoder(texte: String) -> Dictionary`.
- Décisions (appelées par les tests) : `recevoir(texte: String)`, `_sur_socket_fermee(code: int, motif: String)`, `_surveiller(maintenant: int)`, `_vider_file(maintenant: int)`, `_sur_pair_connecte(id: int)`, `_sur_description(type: String, sdp: String, id: int)`, `_sur_candidat(media: String, index: int, nom: String, id: int)`.
- Coutures (remplacées par `TransportWebRTCSimule`) : `_ouvrir_socket(url: String) -> Error`, `_servir_socket()`, `_socket_prete() -> bool`, `_ecrire(texte: String)`, `_fermer_socket()`, `_relier(id: int) -> Error`, `_retirer(id: int)`, `_appliquer_description(id: int, type: String, sdp: String)`, `_appliquer_candidat(id: int, media: String, index: int, nom: String)`.

- [ ] **Step 1 : le test qui échoue**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	await _tester_parties_en_ligne()
	await _tester_transport_tardif()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

par :

````gdscript
	await _tester_parties_en_ligne()
	await _tester_transport_tardif()
	_tester_transport_webrtc()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
## valeur.
````

par :

````gdscript
## Phase 4 du jeu en ligne : `TransportWebRTC` sans navigateur. Ses aides pures (adresse du Worker,
## `?relais=1`, configuration ICE, messages de la salle et leurs entiers), puis ses décisions, sur une
## sous-classe qui remplace la socket et les connexions WebRTC (`TransportWebRTCSimule`) : l'hôte (salle,
## arrivées, offre et candidats, `ouvert`, `depart`, délais, `ping`, salle fermée), le client
## (`bienvenue` et son pair, réponse, fermeture `ouvert`, délai du canal), les échecs de la signalisation
## (`erreur`, fermeture, silence), et la file cadencée.
func _tester_transport_webrtc() -> void:
	print("-- Transport WebRTC (phase 4, sans navigateur)")
	_check(TransportWebRTC.url_signalisation() == "ws://localhost:8787",
		"l'adresse du Worker vient du réglage lelion/signalisation/url (wrangler dev en local) : %s" % TransportWebRTC.url_signalisation())
	_check(TransportWebRTC.lire_relais("?salle=K7Q2XM&relais=1") and TransportWebRTC.lire_relais("relais=1")
		and not TransportWebRTC.lire_relais("?relais=0") and not TransportWebRTC.lire_relais("?relaisx=1")
		and not TransportWebRTC.lire_relais(""),
		"?relais=1 force le relais TURN, rien d'autre ne le fait")
	var ice := [{"urls": ["stun:stun.cloudflare.com:3478"]}, {"urls": ["turn:turn.cloudflare.com:3478"], "username": "u", "credential": "c"}]
	_check(TransportWebRTC.configuration_ice(ice, false) == {"iceServers": ice}
		and TransportWebRTC.configuration_ice(ice, true) == {"iceServers": ice, "iceTransportPolicy": "relay"},
		"la configuration ICE : les serveurs de la salle tels quels, et iceTransportPolicy relay avec ?relais=1")

	var bienvenue := TransportWebRTC.decoder('{"t":"bienvenue","id":123456789,"ice":[]}')
	var candidat := TransportWebRTC.decoder('{"t":"candidat","de":2147483647,"media":"0","index":0,"nom":"candidate:1"}')
	_check(typeof(bienvenue.get("id")) == TYPE_INT and bienvenue.id == 123456789 and typeof(candidat.get("de")) == TYPE_INT
		and candidat.de == 2147483647 and typeof(candidat.get("index")) == TYPE_INT and candidat.index == 0,
		"les identifiants et l'index d'un message deviennent des entiers (le JSON de Godot donne des flottants)")
	var invalides := ['pas du JSON', '[1, 2]', '{"t":"inconnu"}', '{"id":5}', '{"t":"bienvenue","ice":[]}',
		'{"t":"bienvenue","id":1.5,"ice":[]}', '{"t":"bienvenue","id":0,"ice":[]}', '{"t":"bienvenue","id":2147483648,"ice":[]}',
		'{"t":"bienvenue","id":"5","ice":[]}', '{"t":"bienvenue","id":5,"ice":{}}', '{"t":"offre","de":1,"sdp":5}',
		'{"t":"candidat","de":1,"media":"0","index":-1,"nom":"c"}', '{"t":"erreur"}']
	_check(invalides.all(func(t: String) -> bool: return TransportWebRTC.decoder(t).is_empty()),
		"un message mal formé (pas un objet, type inconnu, champ absent ou mal typé, identifiant hors de 1..2³¹-1) est vide")
	_check(TransportWebRTC.decoder('{"t":"depart","id":7,"plus":true}').get("id") == 7, "un champ en plus est toléré")
	_check(TransportWebRTC.new().rejoindre("127.0.0.1:7777") == ERR_INVALID_PARAMETER and TransportWebRTC.new().rejoindre("k7q2xm") == ERR_INVALID_PARAMETER,
		"un code qui n'est pas un code de salle normalisé (l'adresse ip:port d'un hôte ENet comprise) est refusé sans rien tenter")

	# L'hôte
	var hote := TransportWebRTCSimule.new()
	_check(hote.heberger() == OK and hote.url == "ws://localhost:8787/v1/creer" and hote.pair() is WebRTCMultiplayerPeer
		and hote.pair().get_unique_id() == 1 and hote.signaux.is_empty(),
		"héberger : le pair serveur existe (identifiant 1), /v1/creer s'ouvre, rien n'est dit pendant l'appel")
	hote.recevoir('{"t":"salle","code":"K7Q2XM","id":1,"ice":[]}')
	_check(hote.signaux == ["pret K7Q2XM"], "la salle existe : pret avec son code (%s)" % [hote.signaux])
	hote.recevoir('{"t":"arrivee","id":5,"ice":[{"urls":["stun:neuf"]}]}')
	_check(hote.appels == ["relier 5"] and hote._ice == [{"urls": ["stun:neuf"]}],
		"une arrivée : sa connexion se crée avec les serveurs ICE neufs de l'arrivée (%s)" % [hote.appels])
	hote._sur_description("offer", "SDP-O", 5)
	hote._sur_candidat("0", 0, "candidate:1", 5)
	_check(Array(hote._file) == ['{"sdp":"SDP-O","t":"offre","vers":5}', '{"index":0,"media":"0","nom":"candidate:1","t":"candidat","vers":5}'],
		"son offre puis ses candidats partent par la salle, dans l'ordre, les entiers en entiers (%s)" % [hote._file])
	hote.recevoir('{"t":"reponse","de":5,"sdp":"SDP-R"}')
	hote.recevoir('{"t":"candidat","de":5,"media":"0","index":0,"nom":"candidate:2"}')
	hote.recevoir('{"t":"reponse","de":9,"sdp":"SDP-X"}')
	_check(hote.appels == ["relier 5", "description 5 answer SDP-R", "candidat 5 0 0 candidate:2"],
		"sa réponse et ses candidats s'appliquent à sa connexion ; ceux d'un inconnu sont ignorés (%s)" % [hote.appels])
	hote._file.clear()
	hote._sur_pair_connecte(5)
	_check(Array(hote._file) == ['{"id":5,"t":"ouvert"}'], "son canal ouvert : l'hôte dit ouvert à la salle (%s)" % [hote._file])
	hote.recevoir('{"t":"depart","id":5}')
	hote.recevoir('{"t":"arrivee","id":6,"ice":[]}')
	hote.recevoir('{"t":"depart","id":6}')
	hote.recevoir('{"t":"arrivee","id":7,"ice":[]}')
	hote._surveiller(Time.get_ticks_msec() + int(TransportWebRTC.DELAI_CANAL * 1000.0) + 1)
	_check(hote.appels.slice(3) == ["relier 6", "retirer 6", "relier 7", "retirer 7"],
		"un depart après ouvert est ignoré ; un arrivant parti, ou au canal fermé 15 s après son arrivée, est retiré (%s)" % [hote.appels.slice(3)])
	hote._file.clear()
	hote._surveiller(Time.get_ticks_msec() + int(TransportWebRTC.PERIODE_PING * 1000.0) + 1)
	_check(Array(hote._file) == ['{"t":"ping"}'], "toutes les 30 s, l'hôte envoie le ping, ce texte exact")
	hote.recevoir('{"t":"pong"}')
	hote.recevoir('{"t":"erreur","raison":"expiree"}')
	hote._sur_socket_fermee(1000, "expiree")
	_check(hote.signaux == ["pret K7Q2XM", "salle_fermee expiree"] and hote.servir(),
		"la salle expire après pret : seulement salle_fermee (une fois), la session continue (%s)" % [hote.signaux])
	hote.quitter()
	_check(not hote.servir() and hote.pair() == null and hote.appels[-1] == "fermer socket",
		"quitter sans pair connecté : la socket se ferme, le transport aussi")

	# La création échoue avant pret
	var refuse := TransportWebRTCSimule.new()
	refuse.heberger()
	refuse.recevoir('{"t":"erreur","raison":"quota"}')
	refuse._sur_socket_fermee(1000, "quota")
	var coupe := TransportWebRTCSimule.new()
	coupe.heberger()
	coupe._sur_socket_fermee(1006, "")
	var muet := TransportWebRTCSimule.new()
	muet.heberger()
	muet._surveiller(Time.get_ticks_msec() + int(TransportWebRTC.DELAI_SIGNALISATION * 1000.0) + 1)
	var motif := TransportWebRTCSimule.new()
	motif.heberger()
	motif._sur_socket_fermee(1000, "debit")
	_check(refuse.signaux == ["echec quota"] and coupe.signaux == ["echec injoignable"] and muet.signaux == ["echec injoignable"]
		and motif.signaux == ["echec debit"],
		"avant pret, la création échoue (une fois) : l'erreur de la salle, une socket coupée, 5 s sans salle, ou le motif de la fermeture (%s, %s, %s, %s)"
		% [refuse.signaux, coupe.signaux, muet.signaux, motif.signaux])

	# Le client
	var client := TransportWebRTCSimule.new()
	_check(client.rejoindre("K7Q2XM") == OK and client.url == "ws://localhost:8787/v1/rejoindre/K7Q2XM" and client.pair() == null
		and client.servir(),
		"rejoindre : /v1/rejoindre/K7Q2XM s'ouvre, pas encore de pair (son identifiant vient de la salle)")
	client.recevoir('{"t":"bienvenue","id":123456789,"ice":[]}')
	_check(client.signaux == ["pair_pret"] and client.pair() != null and client.pair().get_unique_id() == 123456789
		and client.appels == ["relier 1"],
		"bienvenue : son pair naît avec son identifiant, relié à l'hôte (pair_pret) (%s)" % [client.signaux])
	client.recevoir('{"t":"offre","de":1,"sdp":"SDP-O"}')
	client.recevoir('{"t":"candidat","de":1,"media":"0","index":0,"nom":"candidate:3"}')
	client.recevoir('{"t":"candidat","de":8,"media":"0","index":0,"nom":"candidate:4"}')
	client._sur_description("answer", "SDP-R", 1)
	_check(client.appels.slice(1) == ["description 1 offer SDP-O", "candidat 1 0 0 candidate:3"]
		and Array(client._file) == ['{"sdp":"SDP-R","t":"reponse","vers":1}'],
		"l'offre et les candidats de l'hôte s'appliquent (pas ceux d'un autre), sa réponse part (%s)" % [client.appels])
	client._sur_socket_fermee(1000, "ouvert")
	client._sur_pair_connecte(1)
	client._surveiller(Time.get_ticks_msec() + int(TransportWebRTC.DELAI_CANAL * 1000.0) + 1)
	_check(client.signaux == ["pair_pret", "connecte"] and client.appels.count("fermer socket") == 0,
		"la salle ferme la socket (1000 ouvert) sans échec, le canal s'ouvre : connecte ; le client n'a pas fermé sa socket (%s)" % [client.signaux])
	var lent := TransportWebRTCSimule.new()
	lent.rejoindre("K7Q2XM")
	lent.recevoir('{"t":"bienvenue","id":42,"ice":[]}')
	lent._sur_socket_fermee(1000, "ouvert")
	lent._surveiller(Time.get_ticks_msec() + int(TransportWebRTC.DELAI_CANAL * 1000.0) + 1)
	var retarde := TransportWebRTCSimule.new()
	retarde.rejoindre("K7Q2XM")
	retarde.recevoir('{"t":"bienvenue","id":43,"ice":[]}')
	retarde.recevoir('{"t":"erreur","raison":"delai"}')
	var inconnu := TransportWebRTCSimule.new()
	inconnu.rejoindre("K7Q2XM")
	inconnu.recevoir('{"t":"erreur","raison":"inconnue"}')
	inconnu._sur_socket_fermee(1000, "inconnue")
	var perdu := TransportWebRTCSimule.new()
	perdu.rejoindre("K7Q2XM")
	perdu.recevoir('{"t":"bienvenue","id":44,"ice":[]}')
	perdu._sur_socket_fermee(1006, "")
	_check(lent.signaux == ["pair_pret", "echec delai"] and retarde.signaux == ["pair_pret", "echec delai"]
		and inconnu.signaux == ["echec inconnue"] and perdu.signaux == ["pair_pret", "echec injoignable"],
		"un client échoue : canal fermé 15 s après bienvenue, erreur delai de la salle, salle inconnue, socket coupée avant ouvert (%s, %s, %s, %s)"
		% [lent.signaux, retarde.signaux, inconnu.signaux, perdu.signaux])

	# La file cadencée
	var file := TransportWebRTCSimule.new()
	file.rejoindre("K7Q2XM")
	for i in range(20):
		file._envoyer({"t": "candidat", "vers": 1, "media": "0", "index": i, "nom": "c"})
	file.ouverte = false
	file._vider_file(100000)
	var avant_ouverture := file.ecrits.size()
	file.ouverte = true
	for t in range(100000, 101000, 16):  # une seconde, une image toutes les 16 ms
		file._vider_file(t)
	var en_une_seconde := file.ecrits.size()
	for t in range(101000, 103000, 16):
		file._vider_file(t)
	_check(avant_ouverture == 0 and en_une_seconde == TransportWebRTC.ENVOIS_PAR_SECONDE and file.ecrits.size() == 20
		and file.ecrits == range(20).map(func(i: int) -> String: return JSON.stringify({"t": "candidat", "vers": 1, "media": "0", "index": i, "nom": "c"})),
		"la file attend la socket ouverte, puis envoie 15 messages au plus par seconde, tous, dans l'ordre (%d, %d, %d)"
		% [avant_ouverture, en_une_seconde, file.ecrits.size()])


## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
## valeur.
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	func servir() -> bool:
		return not perdu and not quitte
````

par :

````gdscript
	func servir() -> bool:
		return not perdu and not quitte


## `TransportWebRTC` sans socket ni WebRTC (`_tester_transport_webrtc`) : la socket s'ouvre toujours
## (`url` retenue), `ouverte` dit si elle est prête, ses écritures vont dans `ecrits` ; les connexions
## WebRTC ne sont que notées dans `appels` (leur pair, un `WebRTCMultiplayerPeer`, est réel). Ses signaux
## vont dans `signaux`.
class TransportWebRTCSimule extends TransportWebRTC:
	var url := ""
	var ouverte := true
	var ecrits: Array[String] = []
	var appels: Array[String] = []
	var signaux: Array[String] = []

	func _init() -> void:
		pret.connect(func(code: String) -> void: signaux.append("pret " + code))
		pair_pret.connect(func() -> void: signaux.append("pair_pret"))
		connecte.connect(func() -> void: signaux.append("connecte"))
		echec.connect(func(raison: String) -> void: signaux.append("echec " + raison))
		salle_fermee.connect(func(raison: String) -> void: signaux.append("salle_fermee " + raison))

	func _ouvrir_socket(adresse: String) -> Error:
		url = adresse
		return OK

	func _servir_socket() -> void:
		pass

	func _socket_prete() -> bool:
		return ouverte

	func _ecrire(texte: String) -> void:
		ecrits.append(texte)

	func _fermer_socket() -> void:
		appels.append("fermer socket")

	func _relier(id: int) -> Error:
		_connexions[id] = null
		appels.append("relier %d" % id)
		return OK

	func _retirer(id: int) -> void:
		appels.append("retirer %d" % id)
		super._retirer(id)

	func _appliquer_description(id: int, type: String, sdp: String) -> void:
		appels.append("description %d %s %s" % [id, type, sdp])

	func _appliquer_candidat(id: int, media: String, index: int, nom: String) -> void:
		appels.append("candidat %d %s %d %s" % [id, media, index, nom])
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "SCRIPT ERROR|Parse Error|TransportWebRTC" "$TMPDIR/u.log" | head -4
```

Expected : `unitaires 0` et `SCRIPT ERROR: Parse Error: Could not find base class "TransportWebRTC".` (`res://tests/unitaires.gd:3000`, la classe `TransportWebRTCSimule`) : la suite ne se compile pas.

- [ ] **Step 3 : le réglage de l'adresse du Worker**

Dans `project.godot`, remplacer :

````ini
page/url="https://w3cdotorg.github.io/LeLion-web/"

[rendering]
````

par :

````ini
page/url="https://w3cdotorg.github.io/LeLion-web/"
signalisation/url="ws://localhost:8787"

[rendering]
````

- [ ] **Step 4 : le transport**

Créer `Scripts/TransportWebRTC.gd` :

````gdscript
class_name TransportWebRTC
extends Transport
## Le transport du jeu livré (spec §3.1, §4 et §5 du jeu en ligne) : WebRTC en étoile autour de l'hôte
## (`WebRTCMultiplayerPeer` : l'hôte en `create_server`, chaque client en `create_client`), signalé par
## le Worker de `signalisation/` (WebSocket, JSON, protocole v1). N'existe que dans l'export Web : le
## desktop n'a pas de WebRTC sans l'extension webrtc-native (hors périmètre, spec §1). Ses décisions
## (messages, file d'envoi, délais) se testent sur le desktop, par une sous-classe qui remplace ses
## entrées et sorties (`_ouvrir_socket` à `_appliquer_candidat`, `tests/unitaires.gd`).
##
## Hôte : `heberger()` crée le pair serveur et ouvre `/v1/creer` ; `salle` donne le code (`pret`) et les
## serveurs ICE ; chaque `arrivee` crée une connexion WebRTC (`add_peer`) avec les serveurs ICE neufs de
## cette arrivée, et son offre part par la salle ; le canal ouvert (`peer_connected`), l'hôte dit
## `ouvert` (la salle ferme alors la socket du client). Un arrivant dont le canal n'est pas ouvert
## DELAI_CANAL après son arrivée, ou dont la salle annonce le `depart`, est retiré ; le `depart` d'un pair
## au canal ouvert est ignoré. La socket de l'hôte vit tant que la salle vit (`ping` toutes les
## PERIODE_PING) ; fermée après `pret` (expiration, débit, coupure), la partie continue sans arrivées
## (`salle_fermee`).
##
## Client : `rejoindre(code)` ouvre `/v1/rejoindre/<code>` ; `bienvenue` donne son identifiant : son pair
## naît alors (`pair_pret`) et répond à l'offre de l'hôte ; le canal ouvert, `connecte`. Il ne ferme pas
## sa socket lui-même : il attend la fermeture 1000 `ouvert` de la salle (qui peut précéder de peu
## l'ouverture de son propre canal), et échoue (`echec`) sur une `erreur` de la salle, une fermeture
## sans `ouvert`, ou un canal fermé DELAI_CANAL après `bienvenue`.
##
## Envois : en texte seulement (`send_text` : la salle ignore une trame binaire, et ne répond pas à un
## `ping` binaire), par une file cadencée à ENVOIS_PAR_SECONDE (la salle chasse au-delà de 20 par
## seconde ; six arrivées font environ 70 messages), dans l'ordre (une offre avant ses candidats).
## Réception : tous les messages en attente sont lus, même la socket fermée ; leurs identifiants (des
## flottants dans le JSON de Godot) deviennent des entiers (`decoder`). La raison d'une `erreur` est
## écrite au journal (spec §9) ; sans elle, la raison de la fermeture en tient lieu.
##
## Canaux (spec §5) : les trois par défaut de `WebRTCMultiplayerPeer` (le fiable porte la poignée de
## main et la table du salon ; les non fiables, `unreliable_lifetime` DUREE_NON_FIABLE), plus un canal
## fiable ordonné, le canal 1 de `SceneMultiplayer` (`Reseau.CANAL_ORDONNE`, `Manche.CANAL_PEINTURE`).
## `?relais=1` dans l'adresse de la page : le relais TURN seulement (`iceTransportPolicy: "relay"`,
## spec §10, diagnostic de l'essai réel).

## Le réglage de projet de l'adresse du Worker (spec §11), et sa valeur sans réglage : `wrangler dev`.
const REGLAGE_URL := "lelion/signalisation/url"
const URL_SIGNALISATION := "ws://localhost:8787"
const CHEMIN_CREER := "/v1/creer"
const CHEMIN_REJOINDRE := "/v1/rejoindre/"
## L'identifiant de pair de l'hôte (`create_server`), celui que la salle donne à l'hôte.
const ID_HOTE := 1
## Le plus grand identifiant de pair (2³¹-1).
const ID_MAX := 2147483647
## Sans `salle` (hôte) ni `bienvenue` (client) dans ce délai, en secondes : la signalisation est
## injoignable (spec §9 : 5 s).
const DELAI_SIGNALISATION := 5.0
## Canal toujours fermé ce délai après `bienvenue` (client) ou `arrivee` (hôte), en secondes (spec
## §4.3 : 15 s, la moitié du délai d'arrivée de la salle).
const DELAI_CANAL := 15.0
## Envois au plus dans toute seconde vers la salle (elle en admet 20 : un seau de 20 jetons, rempli de
## 20 par seconde).
const ENVOIS_PAR_SECONDE := 15
## Période du `ping` de l'hôte, en secondes (la salle y répond sans se réveiller, spec §4.2), et son
## texte exact.
const PERIODE_PING := 30.0
const PING := '{"t":"ping"}'
## Durée de vie d'un paquet non fiable (`unreliable_lifetime`), en ms (spec §5 : environ 100 ms).
const DUREE_NON_FIABLE := 100
## Les canaux en plus des trois par défaut : le canal 1 de `SceneMultiplayer`, fiable et ordonné.
const CANAUX := [MultiplayerPeer.TRANSFER_MODE_RELIABLE]
## Délai laissé à un départ volontaire pour vider ses canaux (l'adieu de `Reseau`), en ms.
const DELAI_DEPART := 1000
## Le motif de la fermeture d'une socket de client par la salle, son canal ouvert (code 1000).
const MOTIF_OUVERT := "ouvert"
## Le paramètre de l'adresse de la page qui force le relais TURN (`?relais=1`).
const PARAMETRE_RELAIS := "relais"
## Les raisons des `erreur` de la salle, qui sont aussi le motif de la fermeture qui suit.
const RAISONS_SALLE: Array[String] = [ECHEC_INCONNUE, ECHEC_PLEINE, ECHEC_DEBIT, ECHEC_QUOTA, ECHEC_ORIGINE, ECHEC_EXPIREE,
	ECHEC_DELAI]
## Les champs de chaque message reçu, en plus de `t`, et leur type (spec §4.2).
const CHAMPS := {
	"salle": {"code": TYPE_STRING, "id": TYPE_INT, "ice": TYPE_ARRAY},
	"bienvenue": {"id": TYPE_INT, "ice": TYPE_ARRAY},
	"arrivee": {"id": TYPE_INT, "ice": TYPE_ARRAY},
	"offre": {"de": TYPE_INT, "sdp": TYPE_STRING},
	"reponse": {"de": TYPE_INT, "sdp": TYPE_STRING},
	"candidat": {"de": TYPE_INT, "media": TYPE_STRING, "index": TYPE_INT, "nom": TYPE_STRING},
	"depart": {"id": TYPE_INT},
	"erreur": {"raison": TYPE_STRING},
	"pong": {},
}

## Vrai : les connexions n'utilisent que le relais TURN (`?relais=1`, lu à la création sur le Web).
var relais := false

## Vrai de `heberger()` / `rejoindre()` réussis à `quitter()` / `clore()`.
var _actif := false
var _hote := false
var _ws: WebSocketPeer
## Le pair de la session : chez l'hôte dès `heberger()`, chez un client à `bienvenue`.
var _pair: WebRTCMultiplayerPeer
## La connexion WebRTC de chaque pair relié (chez l'hôte, chaque arrivant ; chez un client, l'hôte),
## pour lui appliquer les offres, réponses et candidats reçus.
var _connexions: Dictionary[int, WebRTCPeerConnection] = {}
## Les serveurs ICE de la dernière `salle`, `bienvenue` ou `arrivee`.
var _ice: Array = []
## Vrai une fois `salle` (hôte) ou `bienvenue` (client) reçu.
var _identifie := false
## Vrai une fois la signalisation finie (une `erreur`, la socket fermée) : son issue est déjà dite.
var _signalisation_finie := false
## Chez un client : vrai une fois son canal vers l'hôte ouvert.
var _canal_ouvert := false
## L'instant (ms) où l'attente de `salle` / `bienvenue` échoue (-1 hors attente).
var _fin_signalisation := -1
## Chez un client : l'instant (ms) où l'attente de son canal échoue (-1 hors attente).
var _fin_canal := -1
## Chez l'hôte : les arrivants au canal encore fermé, et l'instant (ms) où l'hôte les retire.
var _arrivees: Dictionary[int, int] = {}
## Les messages en attente d'envoi, dans l'ordre, et les instants (ms) des ENVOIS_PAR_SECONDE derniers
## envois, du plus ancien au plus récent (la fenêtre glissante d'une seconde).
var _file: PackedStringArray = []
var _derniers_envois: Array[int] = []
## Chez l'hôte : l'instant (ms) du prochain `ping` (-1 sans salle).
var _prochain_ping := -1
## La raison de la dernière `erreur` de la salle.
var _derniere_erreur := ""
## Pendant un départ : l'instant (ms) où il est clos quoi qu'il arrive (-1 hors départ).
var _fin_depart := -1


func _init() -> void:
	if OS.has_feature("web"):
		relais = lire_relais(str(JavaScriptBridge.eval("window.location.search", true)))


func heberger() -> Error:
	var pair_hote := WebRTCMultiplayerPeer.new()
	var erreur := pair_hote.create_server(CANAUX)
	if erreur != OK:
		return erreur
	erreur = _ouvrir_socket(url_signalisation() + CHEMIN_CREER)
	if erreur != OK:
		return erreur
	_hote = true
	_poser_pair(pair_hote)
	_demarrer()
	return OK


## Un code qui n'est pas un code de salle (`CodeSalle.valide`, déjà normalisé), l'adresse `ip:port` d'un
## hôte ENet comprise : ERR_INVALID_PARAMETER, sans rien tenter.
func rejoindre(code: String) -> Error:
	if not CodeSalle.valide(code):
		return ERR_INVALID_PARAMETER
	var erreur := _ouvrir_socket(url_signalisation() + CHEMIN_REJOINDRE + code)
	if erreur != OK:
		return erreur
	_hote = false
	_demarrer()
	return OK


## La socket de signalisation se ferme tout de suite (l'hôte : sa salle disparaît ; un client : la salle
## l'oublie) ; le pair se ferme une fois ses canaux vidés (l'adieu de `Reseau`), DELAI_DEPART au plus.
func quitter() -> void:
	_actif = false
	_fin_signalisation = -1
	_fin_canal = -1
	_prochain_ping = -1
	_arrivees.clear()
	_file.clear()
	_fermer_socket()
	if _fin_depart >= 0:
		return
	if _pair == null or _pair.get_peers().is_empty():
		clore()
		return
	_fin_depart = Time.get_ticks_msec() + DELAI_DEPART


func clore() -> void:
	_actif = false
	_fin_signalisation = -1
	_fin_canal = -1
	_prochain_ping = -1
	_fin_depart = -1
	_arrivees.clear()
	_file.clear()
	_connexions.clear()
	_fermer_socket()
	if _pair != null:
		_pair.close()
		_pair = null


func pair() -> MultiplayerPeer:
	return _pair


func liberer(id: int) -> void:
	if _pair == null or not _pair.has_peer(id):
		return
	_arrivees.erase(id)
	_connexions.erase(id)
	_pair.disconnect_peer(id)  # ferme sa connexion
	_pair.poll()  # le pair fermé est retiré : `peer_disconnected` part maintenant


func servir() -> bool:
	var maintenant := Time.get_ticks_msec()
	if _fin_depart >= 0:
		# Hors de `SceneMultiplayer` (Reseau est déjà hors réseau) : ce transport sert son pair lui-même.
		_pair.poll()
		if maintenant >= _fin_depart or _canaux_vides():
			clore()
	elif _actif:
		_servir_socket()
		_vider_file(maintenant)
		_surveiller(maintenant)
	return _actif or _pair != null


## L'adresse du Worker (le réglage REGLAGE_URL, URL_SIGNALISATION sans lui), sans « / » final.
static func url_signalisation() -> String:
	return str(ProjectSettings.get_setting(REGLAGE_URL, URL_SIGNALISATION)).trim_suffix("/")


## Vrai si la partie recherche d'une adresse (`location.search`) porte `relais=1`.
static func lire_relais(recherche: String) -> bool:
	for paire in recherche.trim_prefix("?").split("&", false):
		if paire == PARAMETRE_RELAIS + "=1":
			return true
	return false


## La configuration d'une connexion WebRTC (`WebRTCPeerConnection.initialize`, passée telle quelle au
## `RTCPeerConnection` du navigateur) : les serveurs ICE `ice` de la salle, et le relais seul si `relais`.
static func configuration_ice(ice: Array, relais_seul: bool) -> Dictionary:
	var configuration := {"iceServers": ice}
	if relais_seul:
		configuration["iceTransportPolicy"] = "relay"
	return configuration


## Le message de la salle `texte` (JSON, spec §4.2) : un objet de type connu, avec exactement les champs
## de son type (CHAMPS) bien typés, ses nombres entiers en `int` (le JSON de Godot donne des flottants :
## `id`, `de` de 1 à ID_MAX, `index` de 0 à ID_MAX) ; un dictionnaire vide pour tout autre texte. Un
## champ en plus est toléré (une version mineure du Worker peut en ajouter).
static func decoder(texte: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(texte) != OK or not (json.data is Dictionary):
		return {}
	var message: Dictionary = json.data
	var type: Variant = message.get("t")
	if not (type is String) or not CHAMPS.has(type):
		return {}
	var champs: Dictionary = CHAMPS[type]
	for nom: String in champs:
		var valeur: Variant = message.get(nom)
		if champs[nom] == TYPE_INT:
			if not (valeur is float or valeur is int) or float(valeur) != floorf(float(valeur)) \
					or float(valeur) < (0.0 if nom == "index" else 1.0) or float(valeur) > ID_MAX:
				return {}
			message[nom] = int(valeur)
		elif typeof(valeur) != champs[nom]:
			return {}
	return message


## Un message reçu de la salle (le texte d'une trame).
func recevoir(texte: String) -> void:
	var message := decoder(texte)
	if message.is_empty():
		push_warning("Signalisation : message ignoré")
		return
	var de: int = message.get("de", 0)
	match message.t:
		"salle":
			if _hote and not _identifie and CodeSalle.valide(message.code):
				_identifie = true
				_fin_signalisation = -1
				_ice = message.ice
				_prochain_ping = Time.get_ticks_msec() + int(PERIODE_PING * 1000.0)
				pret.emit(message.code)
		"arrivee":
			if _hote and _identifie and message.id != ID_HOTE and not _connexions.has(message.id):
				_accueillir(message.id, message.ice)
		"bienvenue":
			if not _hote and not _identifie and message.id != ID_HOTE:
				_identifie = true
				_fin_signalisation = -1
				_ice = message.ice
				_devenir_client(message.id)
		"offre":
			if not _hote and de == ID_HOTE and _connexions.has(ID_HOTE):
				_appliquer_description(ID_HOTE, "offer", message.sdp)
		"reponse":
			if _hote and _arrivees.has(de):
				_appliquer_description(de, "answer", message.sdp)
		"candidat":
			if _connexions.has(de) and (_hote or de == ID_HOTE):
				_appliquer_candidat(de, message.media, message.index, message.nom)
		"depart":
			# Un départ après `ouvert` (le canal ouvert) ne concerne plus la signalisation : ignoré.
			if _hote and _arrivees.has(message.id):
				_arrivees.erase(message.id)
				_retirer(message.id)
		"erreur":
			_derniere_erreur = message.raison
			push_warning("Signalisation : erreur « %s »" % message.raison)
			_signalisation_perdue(message.raison)


## La socket de signalisation s'est fermée (code `code`, motif `motif`) : la fermeture 1000 `ouvert`
## d'un client est la fin normale de sa signalisation ; toute autre est perdue, avec la raison de la
## dernière `erreur`, sinon le motif s'il en est une, sinon ECHEC_INJOIGNABLE.
func _sur_socket_fermee(code: int, motif: String) -> void:
	if not _hote and code == 1000 and motif == MOTIF_OUVERT:
		_signalisation_finie = true
		return
	var raison := _derniere_erreur
	if raison.is_empty():
		raison = motif if RAISONS_SALLE.has(motif) else ECHEC_INJOIGNABLE
	_signalisation_perdue(raison)


## La signalisation s'arrête avec `raison`, une seule fois : chez l'hôte après `pret`, seules les arrivées
## cessent (`salle_fermee`) ; chez un client au canal ouvert, rien ; sinon, un échec.
func _signalisation_perdue(raison: String) -> void:
	if _signalisation_finie or not _actif:
		return
	_signalisation_finie = true
	_fin_signalisation = -1
	_prochain_ping = -1
	if _hote and _identifie:
		salle_fermee.emit(raison)
	elif not _canal_ouvert:
		echec.emit(raison)


## Les délais à `maintenant` (ms) : la signalisation muette, le canal d'un client, les arrivants de
## l'hôte ; et le `ping` de l'hôte.
func _surveiller(maintenant: int) -> void:
	if _fin_signalisation >= 0 and maintenant >= _fin_signalisation:
		push_warning("Signalisation : pas de réponse en %.0f s" % DELAI_SIGNALISATION)
		_signalisation_perdue(ECHEC_INJOIGNABLE)
	if _fin_canal >= 0 and maintenant >= _fin_canal:
		_fin_canal = -1
		if _actif:
			echec.emit(ECHEC_DELAI)
	for id: int in _arrivees.keys():
		if maintenant >= _arrivees[id]:
			_arrivees.erase(id)
			_retirer(id)
	if _prochain_ping >= 0 and maintenant >= _prochain_ping:
		_prochain_ping = maintenant + int(PERIODE_PING * 1000.0)
		_file.append(PING)


## Envoie les messages de la file à `maintenant` (ms), dans l'ordre, tant qu'il le peut : la socket
## ouverte, et pas plus de ENVOIS_PAR_SECONDE dans la seconde qui précède.
func _vider_file(maintenant: int) -> void:
	if not _socket_prete():
		return
	while not _file.is_empty():
		if _derniers_envois.size() == ENVOIS_PAR_SECONDE and maintenant - _derniers_envois[0] < 1000:
			return
		_ecrire(_file[0])
		_file.remove_at(0)
		_derniers_envois.append(maintenant)
		if _derniers_envois.size() > ENVOIS_PAR_SECONDE:
			_derniers_envois.pop_front()


## Met `message` en file (JSON, ses entiers écrits en entiers).
func _envoyer(message: Dictionary) -> void:
	_file.append(JSON.stringify(message))


func _demarrer() -> void:
	_actif = true
	_fin_signalisation = Time.get_ticks_msec() + int(DELAI_SIGNALISATION * 1000.0)


func _poser_pair(pair_session: WebRTCMultiplayerPeer) -> void:
	_pair = pair_session
	_pair.peer_connected.connect(_sur_pair_connecte)
	_pair.peer_disconnected.connect(_sur_pair_parti)


## Chez l'hôte : le client `id` arrive ; sa connexion se crée avec les serveurs ICE `ice` de son arrivée
## (des identifiants TURN neufs), son offre part, son canal a DELAI_CANAL pour s'ouvrir.
func _accueillir(id: int, ice: Array) -> void:
	_ice = ice
	var erreur := _relier(id)
	if erreur != OK:
		push_error("TransportWebRTC : connexion impossible vers %d (erreur %d)" % [id, erreur])
		return
	_arrivees[id] = Time.get_ticks_msec() + int(DELAI_CANAL * 1000.0)


## Chez un client : son identifiant `id` est arrivé ; son pair naît (`pair_pret`), relié à l'hôte, dont
## il attend l'offre ; son canal a DELAI_CANAL pour s'ouvrir.
func _devenir_client(id: int) -> void:
	var pair_client := WebRTCMultiplayerPeer.new()
	var erreur := pair_client.create_client(id, CANAUX)
	if erreur == OK:
		_poser_pair(pair_client)
		erreur = _relier(ID_HOTE)
	if erreur != OK:
		push_error("TransportWebRTC : connexion impossible vers l'hôte (erreur %d)" % erreur)
		_signalisation_perdue(ECHEC_DELAI)
		return
	_fin_canal = Time.get_ticks_msec() + int(DELAI_CANAL * 1000.0)
	pair_pret.emit()


## Le pair `id` a tous ses canaux ouverts : chez l'hôte, la salle l'oublie (`ouvert`) ; chez un client,
## le canal vers l'hôte est ouvert (`connecte`).
func _sur_pair_connecte(id: int) -> void:
	if _hote:
		if _arrivees.erase(id):
			_envoyer({"t": "ouvert", "id": id})
	elif id == ID_HOTE and not _canal_ouvert:
		_canal_ouvert = true
		_fin_canal = -1
		if _actif:
			connecte.emit()


## Le pair `id`, connecté, est parti (`Reseau` le sait par `SceneMultiplayer`) : sa connexion est oubliée.
func _sur_pair_parti(id: int) -> void:
	_connexions.erase(id)


## La description locale `type` (« offer » chez l'hôte, « answer » chez un client) de la connexion vers
## `id` est prête : posée, puis envoyée par la salle.
func _sur_description(type: String, sdp: String, id: int) -> void:
	var connexion: WebRTCPeerConnection = _connexions.get(id)
	if connexion != null:
		connexion.set_local_description(type, sdp)
	_envoyer({"t": "offre" if type == "offer" else "reponse", "vers": id, "sdp": sdp})


## Un candidat ICE local de la connexion vers `id`, envoyé par la salle.
func _sur_candidat(media: String, index: int, nom: String, id: int) -> void:
	_envoyer({"t": "candidat", "vers": id, "media": media, "index": index, "nom": nom})


## Vrai si aucun canal d'aucun pair n'a encore de données à envoyer.
func _canaux_vides() -> bool:
	var pairs: Dictionary = _pair.get_peers()
	for id: int in pairs:
		for canal: WebRTCDataChannel in pairs[id].channels:
			if canal.get_buffered_amount() > 0:
				return false
	return true


# Entrées et sorties, que remplace la sous-classe des tests unitaires (aucune n'a de WebRTC sur le
# desktop) : la socket de signalisation, puis les connexions WebRTC.

func _ouvrir_socket(url: String) -> Error:
	_ws = WebSocketPeer.new()
	var erreur := _ws.connect_to_url(url)
	if erreur != OK:
		_ws = null
	return erreur


## Relève la socket : chaque message en attente, même la socket fermée (une `erreur` suivie de sa
## fermeture arrive d'un coup), puis sa fermeture.
func _servir_socket() -> void:
	if _ws == null:
		return
	_ws.poll()
	var etat := _ws.get_ready_state()
	while _ws != null and _ws.get_available_packet_count() > 0:
		var paquet := _ws.get_packet()
		if _ws.was_string_packet():
			recevoir(paquet.get_string_from_utf8())
	if _ws != null and etat == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		var motif := _ws.get_close_reason()
		_ws = null
		_sur_socket_fermee(code, motif)


func _socket_prete() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func _ecrire(texte: String) -> void:
	if _ws.send_text(texte) != OK:
		push_warning("Signalisation : envoi impossible")


func _fermer_socket() -> void:
	if _ws != null:
		_ws.close()
		_ws = null


## Crée la connexion WebRTC vers `id` (les serveurs ICE `_ice`), l'ajoute au pair ; chez l'hôte, son
## offre se prépare (`_sur_description`).
func _relier(id: int) -> Error:
	var connexion := WebRTCPeerConnection.new()
	var erreur := connexion.initialize(configuration_ice(_ice, relais))
	if erreur != OK:
		return erreur
	connexion.session_description_created.connect(_sur_description.bind(id))
	connexion.ice_candidate_created.connect(_sur_candidat.bind(id))
	erreur = _pair.add_peer(connexion, id, DUREE_NON_FIABLE)
	if erreur != OK:
		connexion.close()
		return erreur
	_connexions[id] = connexion
	return connexion.create_offer() if _hote else OK


## Retire l'arrivant `id`, au canal encore fermé (délai, `depart`) : sa connexion se ferme.
func _retirer(id: int) -> void:
	var connexion: WebRTCPeerConnection = _connexions.get(id)
	_connexions.erase(id)
	if connexion != null:
		connexion.close()
	if _pair != null and _pair.has_peer(id):
		_pair.remove_peer(id)


## La description distante `type` de la connexion vers `id` (« offer » chez un client : sa réponse se
## prépare d'elle-même ; « answer » chez l'hôte).
func _appliquer_description(id: int, type: String, sdp: String) -> void:
	_connexions[id].set_remote_description(type, sdp)


func _appliquer_candidat(id: int, media: String, index: int, nom: String) -> void:
	_connexions[id].add_ice_candidate(media, index, nom)
````

- [ ] **Step 5 : le test passe**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; ls Scripts/TransportWebRTC.gd.uid
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u.log"
sed -n '/-- Transport WebRTC/,/^--/p' "$TMPDIR/u.log" | grep -c "✅"
```

Expected : rien à l'import, le `.uid` créé ; unitaires `0`, `PROTOCOLE 0.20 2553814265 (67 lignes)`, `== 0 échec(s) ==` ; 24 ✅ dans la partie WebRTC (avec les `WARNING: Signalisation : …` du journal, voulus).

- [ ] **Step 6 : Commit**

```bash
git add Scripts/TransportWebRTC.gd Scripts/TransportWebRTC.gd.uid project.godot tests/unitaires.gd
git commit -m "TransportWebRTC : signalisation en WebSocketPeer (texte seulement, file à 15 envois par seconde, identifiants en entiers, ping toutes les 30 s, délais de 5 s et 15 s, fermeture ouvert attendue, salle fermée après pret), WebRTCMultiplayerPeer en étoile (create_server, une connexion par arrivée, create_client à bienvenue puis pair_pret), canaux du §5, ?relais=1 ; réglage lelion/signalisation/url ; unitaires sans navigateur sur une sous-classe simulée

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 3 : WebRTC dans l'export Web, l'état CRÉATION, la salle fermée au salon

**Files:**
- Modify: `Scripts/Reseau.gd` (`_nouveau_transport` : WebRTC sur le Web ; `transport_disponible` vrai ; docstrings)
- Modify: `Scripts/EcranEnLigne.gd` (état CREATION, `_sur_salon_change`)
- Modify: `Scripts/Salon.gd` (la salle fermée à la place du code)
- Modify: `Assets/Traductions/traductions.csv` (+ `.translation`) (`ENLIGNE_CREATION`, `SALON_SALLE_EXPIREE`, `SALON_SALLE_FERMEE`)
- Modify: `tests/smoke_test.gd` (création, échec avant le code, salle fermée ; classe `TransportSalle`)

**Interfaces:**
- `EcranEnLigne` : `enum Etat { ACCUEIL, CREATION, CONNEXION, SALON }` ; `_sur_salon_change()`.
- `Reseau` : `var transport_disponible := true` ; `_nouveau_transport(port)` → `TransportWebRTC.new()` quand `OS.has_feature("web")`.

- [ ] **Step 1 : le test qui échoue**

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text.is_empty(), "Échap (ou B) arrête d'héberger et revient à l'accueil")

	# Port occupé, autre erreur ; changer de langue retraduit le message
	var occupant := ENetMultiplayerPeer.new()
````

par :

````gdscript
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text.is_empty(), "Échap (ou B) arrête d'héberger et revient à l'accueil")

	# Créer une partie dont le transport ne donne son code qu'après coup (WebRTC : la salle de la
	# signalisation, simulée par `TransportSalle`) : l'écran attend (CREATION), sans se fier à
	# `en_ligne()` ; un échec avant le code a son message ; le salon s'ouvre au code, et dit la salle fermée
	var transports: Array[TransportSalle] = []
	reseau.fabrique_transport = func(_port: int) -> Transport:
		transports.append(TransportSalle.new())
		return transports[-1]
	ecran.creer_partie()
	_check(ecran.etat == ecran.Etat.CREATION and reseau.code_partie.is_empty() and ecran.message.text == "Création de la partie…"
		and ecran.bouton_creer.disabled and ecran.bouton_rejoindre.disabled and ecran.bouton_retour.has_focus(),
		"sans code du transport, Créer une partie attend : « Création de la partie… », tout grisé sauf Retour (%s)" % ecran.message.text)
	reseau.salon_change.emit()
	_check(ecran.etat == ecran.Etat.CREATION, "une table du salon sans code ne suffit pas")
	transports[-1].echec.emit(Transport.ECHEC_QUOTA)
	var fin_creation := Time.get_ticks_msec() + 1000
	while ecran.etat != ecran.Etat.ACCUEIL and Time.get_ticks_msec() < fin_creation:
		await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == "Trop de parties en ce moment, réessaie plus tard."
		and ecran.bouton_creer.has_focus(),
		"la création échoue avant le code (quota) : son message, retour à l'accueil, Créer une partie au focus (%s)" % ecran.message.text)
	ecran.creer_partie()
	ecran.retour(false)
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and transports[-1].pair() == null,
		"Retour pendant la création l'annule : l'accueil, hors réseau, le transport quitté")
	ecran.creer_partie()
	transports[-1].pret.emit("K7Q2XM")
	_check(ecran.etat == ecran.Etat.SALON and reseau.code_partie == "K7Q2XM", "le code arrive (pret) : en route vers le salon")
	var salon_salle: Node = await _attendre_scene("res://Scenes/Salon.tscn")
	_check(salon_salle != null and salon_salle.rangee_invitation.visible and salon_salle.etiquette_code.text == "Code de la partie : K7Q-2XM"
		and salon_salle.bouton_copier.visible,
		"le salon de l'hôte montre le code et Copier le lien")
	if salon_salle != null:
		transports[-1].salle_fermee.emit(Transport.ECHEC_EXPIREE)
		_check(salon_salle.etiquette_code.text == "Salle expirée : crée une nouvelle partie pour inviter" and not salon_salle.bouton_copier.visible
			and reseau.en_ligne() and root.multiplayer.is_server(),
			"la salle expire : « Salle expirée : crée une nouvelle partie pour inviter », sans lien, la partie continue (%s)" % salon_salle.etiquette_code.text)
		transports[-1].salle_fermee.emit(Transport.ECHEC_INJOIGNABLE)
		_check(salon_salle.etiquette_code.text == "Invitations coupées : crée une nouvelle partie pour inviter" and not salon_salle.bouton_copier.visible,
			"la signalisation coupée : « Invitations coupées : crée une nouvelle partie pour inviter » (%s)" % salon_salle.etiquette_code.text)
		salon_salle.free()
	ecran.retour(false)  # l'écran, resté en SALON (le salon a pris la suite), revient à l'accueil, hors réseau
	reseau.fabrique_transport = Callable()

	# Port occupé, autre erreur ; changer de langue retraduit le message
	var occupant := ENetMultiplayerPeer.new()
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	_check(reseau.inscrit.get_connections().is_empty() and reseau.refuse.get_connections().is_empty()
		and reseau.connexion_echouee.get_connections().is_empty() and reseau.hote_perdu.get_connections().is_empty()
		and langue_pendant == connexions_langue + 1 and params.langue_changee.get_connections().size() == connexions_langue,
		"l'écran retiré de l'arbre ne laisse aucune connexion aux autoloads, Parametres.langue_changee compris (%d connexion(s) avant l'écran, %d pendant, %d après)"
			% [connexions_langue, langue_pendant, params.langue_changee.get_connections().size()])
````

par :

````gdscript
	_check(reseau.inscrit.get_connections().is_empty() and reseau.refuse.get_connections().is_empty()
		and reseau.connexion_echouee.get_connections().is_empty() and reseau.hote_perdu.get_connections().is_empty()
		and reseau.salon_change.get_connections().is_empty() and langue_pendant == connexions_langue + 1 and params.langue_changee.get_connections().size() == connexions_langue,
		"l'écran retiré de l'arbre ne laisse aucune connexion aux autoloads, Parametres.langue_changee compris (%d connexion(s) avant l'écran, %d pendant, %d après)"
			% [connexions_langue, langue_pendant, params.langue_changee.get_connections().size()])
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	reseau.quitter()
	reseau.pseudo = ""
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	GS.niveau_courant = 0
````

par :

````gdscript
	reseau.quitter()
	reseau.pseudo = ""
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	GS.niveau_courant = 0


## Un transport simulé (`_tester_ecran_en_ligne`, phase 4) : héberge sans rien ouvrir ni rien dire (son pair,
## un `WebRTCMultiplayerPeer` serveur, existe sur le desktop, sans connexion) ; le test émet lui-même `pret`,
## `echec` et `salle_fermee`, comme `TransportWebRTC`.
class TransportSalle extends Transport:
	var _pair: WebRTCMultiplayerPeer

	func heberger() -> Error:
		_pair = WebRTCMultiplayerPeer.new()
		return _pair.create_server()

	func rejoindre(_code: String) -> Error:
		return ERR_UNAVAILABLE

	func quitter() -> void:
		clore()

	func clore() -> void:
		if _pair != null:
			_pair.close()
			_pair = null

	func pair() -> MultiplayerPeer:
		return _pair

	func liberer(_id: int) -> void:
		pass

	func servir() -> bool:
		return _pair != null
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "SCRIPT ERROR|❌" "$TMPDIR/s.log" | head -4
```

Expected : `smoke 1` et `SCRIPT ERROR: Invalid access to property or key 'CREATION' on a base object of type 'Dictionary'.` : `_tester_ecran_en_ligne` s'arrête là, et l'écran resté dans l'arbre fait échouer la suite (11 échecs mesurés, dont « le bouton Multijoueur tient dans l'écran du titre … »).

- [ ] **Step 3 : `Reseau` choisit WebRTC sur le Web**

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## place du code. La partie continue. Vide hors réseau et chez un client.
var raison_salle_fermee := ""
## Vrai si ce poste a un transport pour jouer en réseau : ENet hors du Web (le desktop de développement, les
## tests) ; faux dans l'export Web jusqu'à `TransportWebRTC` (phase 4) : `creer_partie` et
## `rejoindre_partie` y renvoient ERR_UNAVAILABLE sans rien ouvrir. Modifiable par les tests.
var transport_disponible := not OS.has_feature("web")
## Si valide, fabrique le transport de chaque nouvelle session à la place de `_nouveau_transport`
## (`func(port: int) -> Transport`) : les tests y mettent un transport simulé. Invalide dans le jeu.
````

par :

````gdscript
## place du code. La partie continue. Vide hors réseau et chez un client.
var raison_salle_fermee := ""
## Vrai si ce poste a un transport pour jouer en réseau : ENet sur le desktop (le développement, les
## tests), WebRTC dans l'export Web (phase 4). Les tests le mettent à faux : `creer_partie` et
## `rejoindre_partie` renvoient alors ERR_UNAVAILABLE sans rien ouvrir (le garde-fou d'une plateforme
## sans transport, et son message à l'écran En ligne).
var transport_disponible := true
## Si valide, fabrique le transport de chaque nouvelle session à la place de `_nouveau_transport`
## (`func(port: int) -> Transport`) : les tests y mettent un transport simulé. Invalide dans le jeu.
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Crée une partie (l'écran En ligne) : `heberger(port)` si ce poste a un transport pour jouer en réseau
## (`transport_disponible`), sinon ERR_UNAVAILABLE sans rien changer. Son code (`code_partie`) vient du
## transport : `ip:port` en ENet, un code de salle en WebRTC (phase 4).
func creer_partie(port := PORT) -> Error:
	if not transport_disponible:
````

par :

````gdscript
## Crée une partie (l'écran En ligne) : `heberger(port)` si ce poste a un transport pour jouer en réseau
## (`transport_disponible`), sinon ERR_UNAVAILABLE sans rien changer. Son code (`code_partie`) vient du
## transport : `ip:port` en ENet, pendant l'appel ; un code de salle en WebRTC, plus tard, quand la salle de
## la signalisation existe (`salon_change`), ou `connexion_echouee` si elle ne peut pas exister.
func creer_partie(port := PORT) -> Error:
	if not transport_disponible:
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Rejoint la partie `code` avec le transport de ce poste (l'écran En ligne) : un code de salle en WebRTC
## (phase 4), le code `ip:port` (ou `ip`) d'un hôte en ENet. Un code que le transport refuse
## (ERR_INVALID_PARAMETER, M8 : aucun nom d'hôte, dont la résolution bloquerait le jeu), ou aucun transport
## (`transport_disponible` faux : ERR_UNAVAILABLE), ne change rien, pas même la session en cours. La
````

par :

````gdscript
## Rejoint la partie `code` avec le transport de ce poste (l'écran En ligne) : un code de salle en WebRTC
## (l'export Web, qui refuse une adresse `ip:port`), le code `ip:port` (ou `ip`) d'un hôte en ENet. Un code que le transport refuse
## (ERR_INVALID_PARAMETER, M8 : aucun nom d'hôte, dont la résolution bloquerait le jeu), ou aucun transport
## (`transport_disponible` faux : ERR_UNAVAILABLE), ne change rien, pas même la session en cours. La
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Le transport d'une nouvelle session : celui de `fabrique_transport` (les tests), sinon ENet (le
## desktop, les tests ; WebRTC dans l'export Web, phase 4).
func _nouveau_transport(port: int) -> Transport:
	if fabrique_transport.is_valid():
		return fabrique_transport.call(port)
	return TransportENet.new(port, places)
````

par :

````gdscript
## Le transport d'une nouvelle session (spec §3.1) : celui de `fabrique_transport` (les tests), sinon
## WebRTC dans l'export Web (`port` n'y sert pas), ENet ailleurs (le desktop, les tests).
func _nouveau_transport(port: int) -> Transport:
	if fabrique_transport.is_valid():
		return fabrique_transport.call(port)
	if OS.has_feature("web"):
		return TransportWebRTC.new()
	return TransportENet.new(port, places)
````

- [ ] **Step 4 : l'écran En ligne attend le code**

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
## entier), refusé à la saisie s'il est mal formé ; sur le desktop de développement, l'adresse `ip:port`
## (ou `ip`) d'un hôte `TransportENet` (`codes_de_salle` faux). Sans transport pour jouer en réseau
## (`Reseau.transport_disponible` : l'export Web avant la phase 4), Créer et Rejoindre le disent sans
## rien ouvrir.
##
## Trois états : ACCUEIL (tout est permis), CONNEXION (en attente de l'hôte) et SALON (partie créée, ou
## inscription reçue : en route vers le salon, tout reste grisé le temps du changement de scène). Retour
## (ou Échap, B à la manette) annule l'état en cours, puis ramène au titre. Le salon revient ici avec un
## message (`message_a_l_arrivee`) si l'hôte est perdu ; le titre y vient avec le code du lien de la page
## (`code_a_l_arrivee`).

enum Etat { ACCUEIL, CONNEXION, SALON }

const SCENE_TITRE := "res://Scenes/Titre.tscn"
````

par :

````gdscript
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

enum Etat { ACCUEIL, CREATION, CONNEXION, SALON }

const SCENE_TITRE := "res://Scenes/Titre.tscn"
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
	Reseau.connexion_echouee.connect(_sur_connexion_echouee)
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	Parametres.langue_changee.connect(_sur_langue_changee)
	_changer_etat(Etat.ACCUEIL)
````

par :

````gdscript
	Reseau.connexion_echouee.connect(_sur_connexion_echouee)
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	Reseau.salon_change.connect(_sur_salon_change)
	Parametres.langue_changee.connect(_sur_langue_changee)
	_changer_etat(Etat.ACCUEIL)
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
	Reseau.connexion_echouee.disconnect(_sur_connexion_echouee)
	Reseau.hote_perdu.disconnect(_sur_hote_perdu)
	Parametres.langue_changee.disconnect(_sur_langue_changee)
````

par :

````gdscript
	Reseau.connexion_echouee.disconnect(_sur_connexion_echouee)
	Reseau.hote_perdu.disconnect(_sur_hote_perdu)
	Reseau.salon_change.disconnect(_sur_salon_change)
	Parametres.langue_changee.disconnect(_sur_langue_changee)
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
## Crée une partie avec le pseudo saisi (hors du Web, ENet sur `port_jeu`).
func creer_partie() -> void:
	if etat != Etat.ACCUEIL:
````

par :

````gdscript
## Crée une partie avec le pseudo saisi (hors du Web, ENet sur `port_jeu`) : le salon s'ouvre quand elle a
## son code, tout de suite en ENet, à la salle de la signalisation en WebRTC (CREATION d'ici là).
func creer_partie() -> void:
	if etat != Etat.ACCUEIL:
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
	elif erreur != OK:
		_afficher_message("RESEAU_HEBERGER_IMPOSSIBLE", [erreur], true)
	else:
		_ouvrir_salon()
````

par :

````gdscript
	elif erreur != OK:
		_afficher_message("RESEAU_HEBERGER_IMPOSSIBLE", [erreur], true)
	elif Reseau.code_partie.is_empty():
		_changer_etat(Etat.CREATION)
		_afficher_message("ENLIGNE_CREATION", [], false)
	else:
		_ouvrir_salon()
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
func _sur_inscription(_index: int, _couleur: Color) -> void:
	if etat == Etat.CONNEXION:
````

par :

````gdscript
## La partie en création a son code (le `pret` du transport, qui émet `salon_change`) : le salon.
func _sur_salon_change() -> void:
	if etat == Etat.CREATION and not Reseau.code_partie.is_empty():
		_ouvrir_salon()


func _sur_inscription(_index: int, _couleur: Color) -> void:
	if etat == Etat.CONNEXION:
````

- [ ] **Step 5 : le salon dit la salle fermée**

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
## L'hôte voit le code de la partie (`Reseau.code_partie`, relu à chaque affichage) : un code de salle
## (« K7Q-2XM ») et « Copier le lien », qui met le lien d'invitation dans le presse-papiers (spec §4.4) ;
## sur le desktop de développement, l'adresse `ip:port` de l'hôte ENet, sans lien.
##
## Retour (ou Échap, B à la manette) quitte le réseau et ramène à l'écran En ligne ; un hôte perdu y
````

par :

````gdscript
## L'hôte voit le code de la partie (`Reseau.code_partie`, relu à chaque affichage) : un code de salle
## (« K7Q-2XM ») et « Copier le lien », qui met le lien d'invitation dans le presse-papiers (spec §4.4) ;
## sur le desktop de développement, l'adresse `ip:port` de l'hôte ENet, sans lien. Une salle qui
## n'accueille plus personne (`Reseau.raison_salle_fermee`) : son message à la place du code, sans lien
## (spec §4.3 : « Salle expirée : crée une nouvelle partie pour inviter »).
##
## Retour (ou Échap, B à la manette) quitte le réseau et ramène à l'écran En ligne ; un hôte perdu y
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
	aide.text = tr("SALON_AIDE_HOTE" if hote else "SALON_AIDE")
	rangee_invitation.visible = hote and not Reseau.code_partie.is_empty()
	etiquette_code.text = tr("SALON_CODE") % CodeSalle.formater(Reseau.code_partie)
	bouton_copier.visible = CodeSalle.valide(Reseau.code_partie)
	_afficher_etat()
````

par :

````gdscript
	aide.text = tr("SALON_AIDE_HOTE" if hote else "SALON_AIDE")
	rangee_invitation.visible = hote and not Reseau.code_partie.is_empty()
	if Reseau.raison_salle_fermee.is_empty():
		etiquette_code.text = tr("SALON_CODE") % CodeSalle.formater(Reseau.code_partie)
		bouton_copier.visible = CodeSalle.valide(Reseau.code_partie)
	else:
		var expiree := Reseau.raison_salle_fermee == Transport.ECHEC_EXPIREE
		etiquette_code.text = tr("SALON_SALLE_EXPIREE" if expiree else "SALON_SALLE_FERMEE")
		bouton_copier.visible = false
	_afficher_etat()
````

- [ ] **Step 6 : les textes**

Dans `Assets/Traductions/traductions.csv`, remplacer :

````csv
ENLIGNE_INDISPONIBLE,"Pas encore de jeu en ligne dans cette version : il arrive bientôt.","No online play in this version yet: coming soon."
ENLIGNE_REJOINDRE_IMPOSSIBLE,Impossible de rejoindre (erreur %d),Can't join (error %d)
SALON,Salon,Lobby
SALON_NIVEAU,Niveau : %s,Level: %s
````

par :

````csv
ENLIGNE_INDISPONIBLE,"Pas encore de jeu en ligne dans cette version : il arrive bientôt.","No online play in this version yet: coming soon."
ENLIGNE_REJOINDRE_IMPOSSIBLE,Impossible de rejoindre (erreur %d),Can't join (error %d)
ENLIGNE_CREATION,Création de la partie…,Creating the game…
SALON,Salon,Lobby
SALON_NIVEAU,Niveau : %s,Level: %s
````

Dans `Assets/Traductions/traductions.csv`, remplacer :

````csv
SALON_COPIER_LIEN,Copier le lien,Copy link
SALON_LIEN_COPIE,Lien copié !,Link copied!
PAUSE_RESEAU,La partie continue,The game goes on
QUITTER_PARTIE,Quitter la partie,Leave the game
````

par :

````csv
SALON_COPIER_LIEN,Copier le lien,Copy link
SALON_LIEN_COPIE,Lien copié !,Link copied!
SALON_SALLE_EXPIREE,Salle expirée : crée une nouvelle partie pour inviter,Room expired: create a new game to invite
SALON_SALLE_FERMEE,Invitations coupées : crée une nouvelle partie pour inviter,Invitations closed: create a new game to invite
PAUSE_RESEAU,La partie continue,The game goes on
QUITTER_PARTIE,Quitter la partie,Leave the game
````

- [ ] **Step 7 : le test passe**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; git status --short Assets/Traductions
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"
grep -E "Création de la partie|la création échoue avant le code|Retour pendant la création|Salle expirée|Invitations coupées" "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u.log"
```

Expected : rien à l'import, les trois fichiers de traductions modifiés ; smoke `0`, `== 0 échec(s) ==`, les cinq lignes ✅ (création, quota, Retour, salle expirée, invitations coupées) ; unitaires `0`, `== 0 échec(s) ==` (« hors du Web, ce poste a un transport pour jouer en réseau (ENet) » reste vrai).

- [ ] **Step 8 : Commit**

```bash
git add Scripts/Reseau.gd Scripts/EcranEnLigne.gd Scripts/Salon.gd Assets/Traductions/ tests/smoke_test.gd
git commit -m "Export Web : Créer et Rejoindre passent par TransportWebRTC ; l'écran En ligne attend le code de la partie (état CRÉATION, « Création de la partie… », l'échec avant le code a son message) ; le salon de l'hôte dit la salle expirée (« Salle expirée : crée une nouvelle partie pour inviter ») ou les invitations coupées, sans lien

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 4 : le pilote de l'export « Web pilote »

**Files:**
- Create: `Scripts/PiloteWeb.gd` (+ `.uid`)
- Modify: `project.godot` (l'autoload `PiloteWeb`)
- Modify: `export_presets.cfg` (le préréglage « Web pilote », fonctionnalité `pilote`, `export/web-pilote/index.html`)
- Modify: `tests/unitaires.gd` (le pilote inerte)

**Interfaces:**
- Autoload `PiloteWeb` (pas de `class_name`) : `var actif := OS.has_feature("web") and OS.has_feature("pilote")` ; `etat() -> Dictionary` (`scene`, `en_ligne`, `hote`, `code`, `pertes`, `echecs`, `empreinte`, `scores`, et selon l'écran `ecran` {`etat`, `code`, `message`}, `salon` {`table`, `attente`, `invitation`, `copier`, `bouton_copier`}, `manche` {`barriere`, `en_cours`, `finie`}) ; `static func empreinte_manche(main: Node) -> String` ; commandes `["duree", s]`, `["creer", pseudo]`, `["rejoindre", pseudo, code?]`, `["pret"]`, `["demarrer"]`, `["peindre", sens]`, `["quitter"]`.
- Page : `window.lelionPilote = {commandes: [], etat: "<JSON>"}` ; la console reçoit `PILOTE PRET` puis `EMPREINTE <empreinte>`.

- [ ] **Step 1 : le test qui échoue**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
func _tester_transport_webrtc() -> void:
	print("-- Transport WebRTC (phase 4, sans navigateur)")
	_check(TransportWebRTC.url_signalisation() == "ws://localhost:8787",
		"l'adresse du Worker vient du réglage lelion/signalisation/url (wrangler dev en local) : %s" % TransportWebRTC.url_signalisation())
````

par :

````gdscript
func _tester_transport_webrtc() -> void:
	print("-- Transport WebRTC (phase 4, sans navigateur)")
	var pilote: Node = root.get_node("PiloteWeb")  # autoload : jamais nommé
	_check(not pilote.actif and not pilote.is_processing(), "le pilote du test de bout en bout est inerte hors de l'export Web pilote")
	_check(TransportWebRTC.url_signalisation() == "ws://localhost:8787",
		"l'adresse du Worker vient du réglage lelion/signalisation/url (wrangler dev en local) : %s" % TransportWebRTC.url_signalisation())
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "SCRIPT ERROR|❌|PiloteWeb" "$TMPDIR/u.log" | head -4
```

Expected : `unitaires 0`, `ERROR: Node not found: "PiloteWeb" (relative to "/root").` puis `SCRIPT ERROR: Invalid access to property or key 'actif' on a base object of type 'null instance'.` : la partie WebRTC s'arrête là (`== 0 échec(s) ==` quand même : c'est le `SCRIPT ERROR` que la CI refuse).

- [ ] **Step 3 : le pilote**

Créer `Scripts/PiloteWeb.gd` :

````gdscript
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
##   dans le sens `sens` (1 : à droite, -1 : à gauche) DUREE_PASSE secondes (la passe du test réseau) ;
## - `["quitter"]` : retour au titre (qui quitte le réseau : l'adieu, spec §5).
## État : `window.lelionPilote.etat`, un texte JSON réécrit à chaque image (`etat()`), que la page relit.
##
## Autoload : les tests `--script` ne le nomment pas.

const SCENE_TITRE := "res://Scenes/Titre.tscn"
## La hauteur de peinture, au-dessus des toits (celle du pilote de la démo), en px ; la durée d'une passe,
## en secondes ; le délai de la descente, en ms.
const HAUTEUR_PEINTURE := 233.0
const DUREE_PASSE := 2.5
const DELAI_DESCENTE := 5000

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
		"code": Reseau.code_partie, "pertes": _pertes, "echecs": _echecs, "empreinte": _empreinte, "scores": _scores}
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


## La passe du lion de ce poste dans la scène de jeu `main` (comme celle du test réseau) : il descend à
## HAUTEUR_PEINTURE au-dessus des toits (DELAI_DESCENTE au plus), puis peint la ville en allant dans le
## sens `sens`, DUREE_PASSE secondes, touches pressées comme un joueur.
func _peindre(main: Node, sens: int) -> void:
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - HAUTEUR_PEINTURE
	var fin := Time.get_ticks_msec() + DELAI_DESCENTE
	Input.action_press("deplacer_bas")
	while is_instance_valid(main) and main.lion != null and main.lion.position.y < cible and Time.get_ticks_msec() < fin:
		await get_tree().process_frame
	Input.action_release("deplacer_bas")
	var action := "deplacer_droite" if sens > 0 else "deplacer_gauche"
	Input.action_press(action)
	Input.action_press("vomir")
	await get_tree().create_timer(DUREE_PASSE, true).timeout
	Input.action_release(action)
	Input.action_release("vomir")
````

Dans `project.godot`, remplacer :

````ini
Audio="*res://Scripts/Audio.gd"
Reseau="*res://Scripts/Reseau.gd"

[display]
````

par :

````ini
Audio="*res://Scripts/Audio.gd"
Reseau="*res://Scripts/Reseau.gd"
PiloteWeb="*res://Scripts/PiloteWeb.gd"

[display]
````

Dans `export_presets.cfg`, remplacer :

````ini
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
````

par :

````ini
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)

[preset.1]

name="Web pilote"
platform="Web"
runnable=false
advanced_options=false
dedicated_server=false
custom_features="pilote"
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, docs/*, Assets/src/*"
export_path="export/web-pilote/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=true
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
````

- [ ] **Step 4 : le test passe, les deux exports se font**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; ls Scripts/PiloteWeb.gd.uid
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== |pilote" "$TMPDIR/u.log"
mkdir -p export/web export/web-pilote
timeout 600 godot --headless --export-release Web export/web/index.html > "$TMPDIR/e.log" 2>&1; echo "export $?"
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
ls export/web-pilote/index.html export/web-pilote/index.wasm; git status --short --ignored export | head -3
```

Expected : rien à l'import, le `.uid` créé ; unitaires `0`, `PROTOCOLE 0.20 2553814265 (67 lignes)` (un autoload sans RPC ne change pas le protocole), `== 0 échec(s) ==`, la ligne ✅ du pilote inerte ; `export 0`, `export pilote 0` ; les deux fichiers ; `export/` ignoré par git (`!! export/`).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/PiloteWeb.gd Scripts/PiloteWeb.gd.uid project.godot export_presets.cfg tests/unitaires.gd
git commit -m "Pilote du test de bout en bout : un autoload inerte hors de l'export « Web pilote » (préréglage à la fonctionnalité pilote, jamais publié), qui prend les commandes de la page (créer, rejoindre, prêt, démarrer, peindre, quitter) par window.lelionPilote, lui rend l'état du jeu et écrit l'empreinte de la manche dans la console

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 5 : le test de bout en bout (Playwright)

**Files:**
- Create: `tests/web/package.json`, `tests/web/package-lock.json` (généré par `npm install`), `tests/web/.gitignore`, `tests/web/.gdignore` (vide : Godot n'importe pas `node_modules`)
- Create: `tests/web/playwright.config.js`
- Create: `tests/web/bout_en_bout.spec.js`

**Interfaces:**
- `cd tests/web && npx playwright test` : lance lui-même le serveur de l'export (`python3 -m http.server 8060 --bind 127.0.0.1 --directory ../../export/web-pilote`) et la signalisation (`npm --prefix ../../signalisation run dev -- --port 8787 --ip localhost`) ; projets `chromium` et `firefox` (`@manche`), `webkit` (`@lien`) ; un test à la fois.

- [ ] **Step 1 : le paquet**

```bash
mkdir -p tests/web && touch tests/web/.gdignore
```

Créer `tests/web/package.json` :

````json
{
	"name": "lelion-bout-en-bout",
	"version": "0.0.0",
	"private": true,
	"description": "Test de bout en bout de LeLion web : trois pages, WebRTC, la signalisation en local (wrangler dev).",
	"type": "module",
	"engines": {
		"node": ">=22"
	},
	"scripts": {
		"test": "playwright test"
	},
	"devDependencies": {
		"@playwright/test": "1.63.0"
	}
}
````

Créer `tests/web/.gitignore` :

````
node_modules/
test-results/
playwright-report/
````

```bash
(cd tests/web && npm install --silent && grep -A1 '"node_modules/playwright-core"' package-lock.json | grep version)
```

Expected : `"version": "1.63.0",`.

- [ ] **Step 2 : la configuration et le test**

Créer `tests/web/playwright.config.js` :

````js
// Le test de bout en bout du jeu en ligne (spec §10) : l'export « Web pilote » servi sur
// http://localhost:8060 (l'origine que la signalisation admet, http://localhost:* ; pas 127.0.0.1), en IPv4
// seulement (une page chargée par ::1, Firefox ne trouve aucun candidat ICE dans un conteneur sans IPv6),
// la signalisation en local (`wrangler dev` sur ws://localhost:8787, l'adresse par défaut du réglage
// lelion/signalisation/url), puis Chromium et Firefox (la manche à trois pages) et WebKit (Copier le lien).
// L'export se fait avant : godot --headless --export-release "Web pilote" export/web-pilote/index.html.
import { defineConfig } from "@playwright/test";

export default defineConfig({
	testDir: ".",
	// Trois pages de 40 Mo de WebAssembly par test : un test à la fois.
	workers: 1,
	fullyParallel: false,
	retries: 0,
	timeout: 180_000,
	expect: { timeout: 30_000 },
	reporter: [["list"], ["html", { open: "never" }]],
	use: {
		baseURL: "http://localhost:8060",
		// Les textes du jeu en français (sa langue suit celle du navigateur).
		locale: "fr-FR",
		trace: "retain-on-failure",
	},
	projects: [
		{ name: "chromium", grep: /@manche/, use: { browserName: "chromium" } },
		// Firefox sans affichage n'a pas de WebGL 2 (aucun pilote GL) : avec une fenêtre, sous Xvfb (xvfb-run).
		{ name: "firefox", grep: /@manche/, use: { browserName: "firefox", headless: false } },
		{ name: "webkit", grep: /@lien/, use: { browserName: "webkit" } },
	],
	webServer: [
		{
			command: "python3 -m http.server 8060 --bind 127.0.0.1 --directory ../../export/web-pilote",
			url: "http://127.0.0.1:8060/index.html",
			stderr: "ignore",  // une ligne par fichier servi
			reuseExistingServer: false,
			timeout: 30_000,
		},
		{
			// Chaque lancement a une signalisation neuve : ses limites par IP (5 salles par minute) repartent de zéro.
			command: "npm --prefix ../../signalisation run dev -- --port 8787 --ip localhost",
			port: 8787,
			reuseExistingServer: false,
			timeout: 120_000,
			env: { WRANGLER_SEND_METRICS: "false" },
		},
	],
});
````

Créer `tests/web/bout_en_bout.spec.js` :

````js
// Le jeu en ligne de bout en bout (spec §10) : de vrais navigateurs, de vraies connexions WebRTC, la
// signalisation en local. Chaque page est menée par le pilote de l'export « Web pilote »
// (Scripts/PiloteWeb.gd) : des commandes poussées dans window.lelionPilote.commandes, son état relu
// dans window.lelionPilote.etat, par les vrais écrans du jeu (titre, En ligne, salon, manche).
import { expect, test } from "@playwright/test";

const ALPHABET = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;
const HOTE_PARTI = "L'hôte a quitté la partie";

/**
 * Une page neuve, la `rang`-ième (son propre contexte : rien de partagé entre joueurs), le pilote prêt.
 * Chaque fenêtre est plus petite que la précédente : sous Xvfb (sans gestionnaire de fenêtres, toutes en
 * haut à gauche), Firefox ne dessine plus une fenêtre entièrement couverte, et son jeu s'y fige.
 */
async function ouvrir(navigateur, chemin, consoles, rang = 0) {
	const largeur = 1280 - 160 * rang;
	const contexte = await navigateur.newContext({ viewport: { width: largeur, height: Math.round((largeur * 9) / 16) } });
	const page = await contexte.newPage();
	const lignes = [];
	consoles?.push(lignes);
	page.on("console", (message) => lignes.push(message.text()));
	await page.goto(chemin);
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
	return page;
}

const etat = (page) => page.evaluate(() => JSON.parse(window.lelionPilote.etat));
const commander = (page, ...commande) => page.evaluate((c) => window.lelionPilote.commandes.push(c), commande);

/** Relit l'état de `page` jusqu'à ce que `condition` le vérifie ; le rend. */
async function attendre(page, condition, message, delai = 30_000) {
	let dernier = null;
	try {
		await expect
			.poll(async () => condition((dernier = await etat(page))), { timeout: delai, intervals: [100, 250] })
			.toBe(true);
	} catch {
		throw new Error(`${message} : pas en ${delai} ms (dernier état ${JSON.stringify(dernier)})`);
	}
	return dernier;
}

test("une manche à trois pages par le lien d'invitation : même empreinte partout, départ de l'hôte vu @manche", async ({ browser }) => {
	const consoles = [];
	const hote = await ouvrir(browser, "/", consoles);
	await commander(hote, "duree", 10);
	await commander(hote, "creer", "Hote");
	const salle = await attendre(hote, (e) => e.scene === "Salon" && ALPHABET.test(e.code), "l'hôte a sa salle");
	const code = salle.code;
	expect(salle.salon.invitation).toBe(`Code de la partie : ${code.slice(0, 3)}-${code.slice(3)}`);

	const invites = [];
	for (const [rang, pseudo] of [[1, "Anna"], [2, "Bruno"]]) {
		const page = await ouvrir(browser, `/?salle=${code}`, consoles, rang);
		// Le lien ouvre l'écran En ligne, le code rempli, sans rien tenter avant le Rejoindre du joueur.
		const accueil = await attendre(page, (e) => e.scene === "EcranEnLigne", `${pseudo} : le lien ouvre l'écran En ligne`);
		expect(accueil.ecran.code).toBe(`${code.slice(0, 3)}-${code.slice(3)}`);
		expect(accueil.en_ligne).toBe(false);
		await commander(page, "duree", 10);
		await commander(page, "rejoindre", pseudo);
		await attendre(page, (e) => e.scene === "Salon", `${pseudo} arrive au salon (canal WebRTC ouvert, poignée de main faite)`);
		invites.push(page);
	}
	const pages = [hote, ...invites];
	for (const page of pages) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna,Bruno", "la même table du salon partout");
	}

	for (const page of pages) await commander(page, "pret");
	await commander(hote, "demarrer");
	for (const page of pages) await attendre(page, (e) => e.manche?.en_cours === true, "la manche commence partout", 60_000);
	for (const [page, sens] of [[hote, 1], [invites[0], -1], [invites[1], 1]]) await commander(page, "peindre", sens);

	const fins = [];
	for (const page of pages) fins.push(await attendre(page, (e) => e.empreinte !== "", "la manche de 10 s finit partout", 60_000));
	const empreintes = consoles.map((lignes) => lignes.find((l) => l.startsWith("EMPREINTE ")));
	expect(empreintes[0]).toBeTruthy();
	expect(empreintes[1]).toBe(empreintes[0]);
	expect(empreintes[2]).toBe(empreintes[0]);
	for (const fin of fins) expect(fin.scores.slice(0, 3).every((cellules) => cellules > 0), `chacun a peint : ${fin.scores}`).toBe(true);

	const depart = Date.now();
	await commander(hote, "quitter");
	for (const page of invites) await attendre(page, (e) => e.pertes.includes(HOTE_PARTI), "les autres voient l'hôte partir", 9_000);
	// Avant les 10 s de silence : c'est l'adieu de l'hôte, ou la fermeture de son pair, qui l'a dit.
	expect(Date.now() - depart).toBeLessThan(9_000);
});

test("Copier le lien, sous un vrai clic, met le lien d'invitation dans le presse-papiers @lien", async ({ browser }) => {
	const contexte = await browser.newContext();
	// Le presse-papiers lui-même n'est pas lisible ici (WebKit n'accorde pas sa lecture) : on relève ce que le
	// jeu lui donne, et si le navigateur l'accepte (un writeText refusé faute de geste de l'utilisateur échoue).
	await contexte.addInitScript(() => {
		const ecrire = navigator.clipboard.writeText.bind(navigator.clipboard);
		window.presse = { texte: null, issue: "aucune" };
		navigator.clipboard.writeText = (texte) => {
			window.presse.texte = texte;
			return ecrire(texte).then(
				() => { window.presse.issue = "acceptee"; },
				(erreur) => { window.presse.issue = `refusee : ${erreur}`; throw erreur; },
			);
		};
	});
	const page = await contexte.newPage();
	await page.goto("/");
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
	await commander(page, "creer", "Hote");
	const salle = await attendre(page, (e) => e.scene === "Salon" && ALPHABET.test(e.code) && e.salon.bouton_copier.length === 2, "l'hôte a sa salle");
	const [x, y] = salle.salon.bouton_copier;
	await page.mouse.click(x, y);
	await attendre(page, (e) => e.salon.copier === "SALON_LIEN_COPIE", "le bouton dit « Lien copié ! »");
	await expect.poll(() => page.evaluate(() => window.presse)).toEqual({ texte: `http://localhost:8060/?salle=${salle.code}`, issue: "acceptee" });
});
````

- [ ] **Step 3 : sans l'export, il échoue**

```bash
rm -rf export/web-pilote
docker run --rm --init -v "$PWD":/depot -v lelion-modules-signalisation:/depot/signalisation/node_modules -v lelion-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test' > "$TMPDIR/e2e.log" 2>&1; echo "bout en bout $?"; grep -E "webServer|Error:|passed|failed" "$TMPDIR/e2e.log" | head -4
```

Expected : `bout en bout 1` et `Error: Timed out waiting 30000ms from config.webServer.` (le serveur de l'export ne trouve pas `index.html`), en une minute environ.

Le conteneur garde son propre `node_modules` (volumes `lelion-modules-*`) : la signalisation du Mac garde le sien (son `workerd` est celui de macOS).

- [ ] **Step 4 : avec l'export, il passe**

```bash
mkdir -p export/web-pilote
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
SECONDS=0; timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion-modules-signalisation:/depot/signalisation/node_modules -v lelion-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test' > "$TMPDIR/e2e.log" 2>&1; echo "bout en bout $? en ${SECONDS} s"; grep -E "✓|✘|passed|failed|Error" "$TMPDIR/e2e.log"
git status --short tests/web
```

Expected : `export pilote 0` ; `bout en bout 0`, environ 70 s (mesuré 67 s, `npm ci` compris) ; `✓ [chromium] … @manche` (environ 30 s), `✓ [firefox] … @manche` (environ 25 s), `✓ [webkit] … @lien` (environ 3 s), `3 passed`. `git status` ne montre que les fichiers de la tâche (`test-results/`, `playwright-report/`, `node_modules/` ignorés). Un échec : lire le message (le dernier état du pilote y est), et `test-results/*/trace.zip` (`npx playwright show-trace`).

Sous Linux (la CI), le même test sans conteneur : `cd tests/web && npx playwright install --with-deps chromium firefox webkit && xvfb-run -a npx playwright test`. Sur ce Mac, sans conteneur, Chromium et Firefox échouent à relier deux pages (pare-feu, écart 13) : ce n'est pas un défaut du jeu.

- [ ] **Step 5 : Commit**

```bash
git add tests/web/.gdignore tests/web/.gitignore tests/web/package.json tests/web/package-lock.json tests/web/playwright.config.js tests/web/bout_en_bout.spec.js
git commit -m "Test de bout en bout (Playwright 1.63.0) : l'export Web pilote et la signalisation en local, une manche de 10 s à trois pages sous Chromium et Firefox (le lien d'invitation, Prêt, chacun peint, la même empreinte dans les trois consoles, le départ de l'hôte vu avant les 10 s de silence), Copier le lien sous un vrai clic sous WebKit

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 6 : le bout en bout en CI

**Files:**
- Modify: `.github/workflows/ci.yml` (job `bout-en-bout`, à la fin ; les deux jobs existants inchangés)

**Interfaces:** job `bout-en-bout` (« Bout en bout WebRTC (Playwright, trois pages) »), `ubuntu-latest`, 20 min.

- [ ] **Step 1 : le job**

Dans `.github/workflows/ci.yml`, remplacer :

````yaml
      - name: Configuration de déploiement valide (sans compte)
        run: npx wrangler deploy --dry-run --outdir "$RUNNER_TEMP/signalisation"
````

par :

````yaml
      - name: Configuration de déploiement valide (sans compte)
        run: npx wrangler deploy --dry-run --outdir "$RUNNER_TEMP/signalisation"

  bout-en-bout:
    name: Bout en bout WebRTC (Playwright, trois pages)
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v5

      - name: Installer Godot et les templates d'export
        run: |
          set -euo pipefail
          BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
          curl -sSLO "$BASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          curl -sSLO "$BASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
          unzip -q "Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          sudo mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot
          mkdir -p "$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
          unzip -q "Godot_v${GODOT_VERSION}-stable_export_templates.tpz" -d /tmp/templates
          mv /tmp/templates/templates/* "$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable/"
          godot --version

      - name: Importer les ressources
        run: godot --headless --import . || true

      - name: Exporter en Web, avec le pilote du test (préréglage « Web pilote »)
        shell: bash
        run: |
          mkdir -p export/web-pilote
          timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html
          test -f export/web-pilote/index.html

      - name: Installer Node
        uses: actions/setup-node@v6
        with:
          node-version: 24.21.0
          cache: npm
          cache-dependency-path: |
            signalisation/package-lock.json
            tests/web/package-lock.json

      - name: Installer la signalisation, Playwright et ses navigateurs (package-lock.json)
        run: |
          (cd signalisation && npm ci)
          (cd tests/web && npm ci && npx playwright install --with-deps chromium firefox webkit)

      - name: Test de bout en bout (Chromium et Firefox, une manche à trois pages ; WebKit, Copier le lien)
        working-directory: tests/web
        run: xvfb-run -a npx playwright test

      - name: Publier le rapport Playwright (en cas d'échec)
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: rapport-playwright
          path: tests/web/playwright-report
          retention-days: 7
````

- [ ] **Step 2 : il se lit**

```bash
python3 -c "import yaml; d = yaml.safe_load(open('.github/workflows/ci.yml')); print(list(d['jobs'])); print([s.get('name') for s in d['jobs']['bout-en-bout']['steps']][-3:])"
git diff --stat .github/workflows/ci.yml
```

Expected : `['test-et-export', 'signalisation', 'bout-en-bout']`, puis les trois derniers pas (« Installer la signalisation, Playwright … », « Test de bout en bout … », « Publier le rapport Playwright … ») ; seulement des lignes ajoutées. Le job ne tourne que sur GitHub (Task 8, Step 4).

- [ ] **Step 3 : Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "CI : job bout-en-bout (Godot et ses templates, export Web pilote, signalisation et Playwright, xvfb-run npx playwright test, rapport en artefact en cas d'échec)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 7 : la spec et le README

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§3.1 `Transport` et `TransportWebRTC`, §9, §10)
- Modify: `README.md` (jeu en ligne, `Scripts/`, `tests/`, le bout en bout, les préréglages et la CI)

**Interfaces:** aucune.

- [ ] **Step 1 : la spec**

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
|---|---|---|
| `Reseau` (autoload, allégé) | Poignée de main (authentification de `SceneMultiplayer`, inchangée), table du salon, barrière de chargement, relance de manche, départs. Ne nomme plus aucune classe ENet. Tient le **battement** : chaque poste envoie un battement par seconde (non fiable) ; tout paquet de `Reseau` reçu d'un pair, battement ou RPC, remet son silence à zéro (`SceneMultiplayer` ne donne ni l'heure de réception par pair ni un signal par RPC reçue : le trafic de la manche n'est pas compté, le battement y suffit) ; 10 s de silence (30 s au chargement) le déclarent parti. Départ volontaire : un adieu fiable, puis le transport ferme une fois l'adieu envoyé (§5). Un exclu part de lui-même à l'annonce, fiable ; l'hôte le libère ensuite. Ajoute l'**exclusion** par l'hôte (§8). | `Transport`, `GameState` |
| `Transport` (interface `@abstract`, `RefCounted`) | `heberger() -> Error`, `rejoindre(code: String) -> Error`, `quitter()` (ferme une fois envoyé ce qui est en file, en arrière-plan), `clore()` (tout de suite), `pair() -> MultiplayerPeer`, `liberer(id)` (chez l'hôte : ferme sur-le-champ le canal d'un pair parti, muet ou exclu, sans attendre de réponse ; son `peer_disconnected` part pendant l'appel), `servir() -> bool` (à chaque image ; faux une fois fermé) ; signaux `pret(code)` (chez l'hôte : la salle existe), `connecte()` (chez le client : canal ouvert, la poignée de main peut partir), `echec(raison)`. Ne sait rien du salon ni du jeu. | rien |
| `TransportWebRTC` | Le transport livré : la signalisation (§4), un `WebRTCPeerConnection` par client chez l'hôte, la configuration ICE reçue du Worker, les canaux (§5). | `Transport`, `WebSocketPeer` |
| `TransportENet` | Le transport ENet de LeLion-multi, extrait de `Reseau.gd`, gardé pour la **version desktop de développement et les tests headless** (le test réseau, le relais de latence). Jamais choisi dans l'export Web. Le « code » y est `ip:port`. | `Transport` |
| `EcranEnLigne` (remplace `EcranReseau`) | Pseudo (mémorisé dans `Scores`), *Créer une partie* (absent sur mobile), *Rejoindre* avec un champ de code (pré-rempli par `?salle=`), messages d'erreur (§9). Le salon de l'hôte affiche le code et *Copier le lien*. Le code (`CodeSalle`) : un code de salle sur le Web ; l'adresse `ip:port` d'un hôte `TransportENet` sur le desktop de développement. Passe par `Reseau.creer_partie()` et `Reseau.rejoindre_partie(code)`, qui choisissent le transport. | `Reseau`, `CodeSalle` |
````

par :

````markdown
|---|---|---|
| `Reseau` (autoload, allégé) | Poignée de main (authentification de `SceneMultiplayer`, inchangée), table du salon, barrière de chargement, relance de manche, départs. Ne nomme plus aucune classe ENet. Tient le **battement** : chaque poste envoie un battement par seconde (non fiable) ; tout paquet de `Reseau` reçu d'un pair, battement ou RPC, remet son silence à zéro (`SceneMultiplayer` ne donne ni l'heure de réception par pair ni un signal par RPC reçue : le trafic de la manche n'est pas compté, le battement y suffit) ; 10 s de silence (30 s au chargement) le déclarent parti. Départ volontaire : un adieu fiable, puis le transport ferme une fois l'adieu envoyé (§5). Un exclu part de lui-même à l'annonce, fiable ; l'hôte le libère ensuite. Ajoute l'**exclusion** par l'hôte (§8). | `Transport`, `GameState` |
| `Transport` (interface `@abstract`, `RefCounted`) | `heberger() -> Error`, `rejoindre(code: String) -> Error`, `quitter()` (ferme une fois envoyé ce qui est en file, en arrière-plan), `clore()` (tout de suite), `pair() -> MultiplayerPeer`, `liberer(id)` (chez l'hôte : ferme sur-le-champ le canal d'un pair parti, muet ou exclu, sans attendre de réponse ; son `peer_disconnected` part pendant l'appel), `servir() -> bool` (à chaque image ; faux une fois fermé) ; signaux `pret(code)` (chez l'hôte : la salle existe, pendant `heberger()` en ENet, plus tard en WebRTC), `connecte()` (chez le client : canal ouvert, la poignée de main peut partir), `pair_pret()` (chez le client WebRTC : son pair existe, son identifiant venu de `bienvenue` ; `SceneMultiplayer` refuse un `WebRTCMultiplayerPeer` avant `create_client`), `echec(raison)` (chez le client, ou chez l'hôte avant `pret` : routé en échec de connexion), `salle_fermee(raison)` (chez l'hôte après `pret` : plus d'arrivées, la partie continue). Ne sait rien du salon ni du jeu. | rien |
| `TransportWebRTC` | Le transport livré : la signalisation (§4 ; envois en texte, cadencés à 15 par seconde, identifiants en entiers ; adresse du Worker dans le réglage `lelion/signalisation/url`, `ws://localhost:8787` en local), un `WebRTCPeerConnection` par client chez l'hôte, la configuration ICE reçue du Worker (`?relais=1` : `iceTransportPolicy: "relay"`, passée telle quelle au `RTCPeerConnection` du navigateur), les canaux (§5). Ses décisions se testent sans navigateur (`tests/unitaires.gd`, socket et connexions simulées). | `Transport`, `WebSocketPeer` |
| `TransportENet` | Le transport ENet de LeLion-multi, extrait de `Reseau.gd`, gardé pour la **version desktop de développement et les tests headless** (le test réseau, le relais de latence). Jamais choisi dans l'export Web. Le « code » y est `ip:port`. | `Transport` |
| `EcranEnLigne` (remplace `EcranReseau`) | Pseudo (mémorisé dans `Scores`), *Créer une partie* (absent sur mobile), *Rejoindre* avec un champ de code (pré-rempli par `?salle=`), messages d'erreur (§9). Le salon de l'hôte affiche le code et *Copier le lien*. Le code (`CodeSalle`) : un code de salle sur le Web ; l'adresse `ip:port` d'un hôte `TransportENet` sur le desktop de développement. Passe par `Reseau.creer_partie()` et `Reseau.rejoindre_partie(code)`, qui choisissent le transport. | `Reseau`, `CodeSalle` |
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
| Client revenu d'un onglet caché, déclaré parti entre-temps (silence) | « Tu as été déconnecté » puis écran En ligne |
| Salle expirée (4 h) | Chez l'hôte, dans le salon : « Salle expirée : crée une nouvelle partie pour inviter » |

## 10. Tests
````

par :

````markdown
| Client revenu d'un onglet caché, déclaré parti entre-temps (silence) | « Tu as été déconnecté » puis écran En ligne |
| Salle expirée (4 h) | Chez l'hôte, dans le salon : « Salle expirée : crée une nouvelle partie pour inviter » |
| Signalisation de l'hôte fermée autrement (débit, coupure) | Chez l'hôte, dans le salon : « Invitations coupées : crée une nouvelle partie pour inviter » ; la partie continue |
| Création refusée ou sans réponse (avant le code) | Les messages ci-dessus (quota, service indisponible), l'écran En ligne revenu à l'accueil |

## 10. Tests
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
  4 h, délai d'arrivée de 30 s, identifiants TURN (API Cloudflare simulée), réponses automatiques
  `ping`.
- **De bout en bout WebRTC** (Playwright, Chromium et Firefox, en CI) : l'export Web servi en local,
  le Worker en local (`wrangler dev`), 3 pages. Création, arrivée de deux pages par le lien, Prêt,
  manche de 10 s, même empreinte sur les 3 pages (lue dans la console), exclusion d'un joueur, départ
  de l'hôte vu par les autres. Le TURN ne se teste pas en local.
- **Essai réel** : `docs/essai-en-ligne.md` (hôte sur ordinateur, au moins un mobile en 4G, un joueur
  dans un autre foyer ; une manche avec le relais TURN forcé par `?relais=1`, paramètre de
````

par :

````markdown
  4 h, délai d'arrivée de 30 s, identifiants TURN (API Cloudflare simulée), réponses automatiques
  `ping`.
- **De bout en bout WebRTC** (`tests/web/`, Playwright, Chromium et Firefox, en CI) : l'export « Web
  pilote » (l'export Web plus la fonctionnalité `pilote`, qui active `Scripts/PiloteWeb.gd` : la page
  mène le jeu par ses vrais écrans et relit son état, sans viser de pixels) servi sur
  `http://localhost:8060`, le Worker en local (`wrangler dev`), 3 pages. Création, arrivée de deux pages
  par le lien, Prêt, manche de 10 s où chacun peint, même empreinte sur les 3 pages (lue dans la
  console), départ de l'hôte vu par les autres avant les 10 s de silence ; sous WebKit, *Copier le lien*
  sous un vrai clic. L'exclusion d'un joueur s'y ajoute avec elle (phase 7). Le TURN ne se teste pas en
  local.
- **Essai réel** : `docs/essai-en-ligne.md` (hôte sur ordinateur, au moins un mobile en 4G, un joueur
  dans un autre foyer ; une manche avec le relais TURN forcé par `?relais=1`, paramètre de
````

- [ ] **Step 2 : le README**

Dans `README.md`, remplacer :

````markdown
gamepad, with the solo controls; Esc opens a local menu that does not pause the round.

Until online play lands (in the browser, by room code or invitation link), run the game from the
editor (`godot .`) on each computer: **Multiplayer** opens the Online screen, where one player
creates a game and the others join it with the host's address as the code: the host's local IP
address, as their system shows it (network settings, `ipconfig` on Windows, `ip a` on Linux),
followed by `:7777` (`192.168.1.20:7777`). The host's lobby shows `127.0.0.1:7777`, which only works
````

par :

````markdown
gamepad, with the solo controls; Esc opens a local menu that does not pause the round.

Online play runs in the browser (WebRTC, the host's browser being authoritative): **Create a game**
gives a room code (`K7Q-2XM`) and **Copy link**; the others open the link, pick a name and join. It
needs the signalling Worker (`signalisation/`, deployed with the page in a later phase); locally,
`npm --prefix signalisation run dev` serves it on `ws://localhost:8787` (the `lelion/signalisation/url`
project setting), and the Web export must be served from `http://localhost:<port>` (not `127.0.0.1`).
From the editor (`godot .`), desktop builds play over ENet instead: **Multiplayer** opens the Online
screen, where one player creates a game and the others join it with the host's address as the code: the host's local IP
address, as their system shows it (network settings, `ipconfig` on Windows, `ip a` on Linux),
followed by `:7777` (`192.168.1.20:7777`). The host's lobby shows `127.0.0.1:7777`, which only works
````

Dans `README.md`, remplacer :

````markdown
Scripts/    one script per scene; the autoloads GameState (game, players, levels, difficulties, arcade), Scores
            (records, preferences), Parametres (settings, CRT layer), Audio (sounds, layered music) and Reseau
            (handshake, lobby table, heartbeat); Transport and TransportENet (the network channels); CodeSalle
            (room codes, invitation link); Manche (a networked round);
            pure logic: Joueur (a player), Commandes (inputs), Regles / ReglesSolo / ReglesBataille (rules of each
            mode), Territoire (cell ownership), Peinture (deterministic stamps), EtatLion, InterpolationLion and
````

par :

````markdown
Scripts/    one script per scene; the autoloads GameState (game, players, levels, difficulties, arcade), Scores
            (records, preferences), Parametres (settings, CRT layer), Audio (sounds, layered music) and Reseau
            (handshake, lobby table, heartbeat); Transport, TransportENet and TransportWebRTC (the network
            channels: ENet on the desktop, WebRTC in the browser); CodeSalle (room codes, invitation link); Manche
            (a networked round); PiloteWeb (the end-to-end test driver, inert outside the "Web pilote" export);
            pure logic: Joueur (a player), Commandes (inputs), Regles / ReglesSolo / ReglesBataille (rules of each
            mode), Territoire (cell ownership), Peinture (deterministic stamps), EtatLion, InterpolationLion and
````

Dans `README.md`, remplacer :

````markdown
Assets/     Sprites (used), Sons (generated), Traductions (CSV → .translation), src (reference material, ignored by Godot)
tests/      unitaires, smoke_test, bataille_test, prediction_test, trace_lions (headless), reseau/ (multi-process
            network test, latency relay), screenshots and deux_fenetres (captures)
tools/      generer_sons.py (effects), generer_musique.py (layered chiptune, town + boss themes), generer_skylines.py (skylines, sprites)
docs/       screenshots, the design specs (LAN, then online) and the phase plans (superpowers/)
````

par :

````markdown
Assets/     Sprites (used), Sons (generated), Traductions (CSV → .translation), src (reference material, ignored by Godot)
tests/      unitaires, smoke_test, bataille_test, prediction_test, trace_lions (headless), reseau/ (multi-process
            network test, latency relay), screenshots and deux_fenetres (captures), web/ (end-to-end WebRTC test,
            Playwright)
tools/      generer_sons.py (effects), generer_musique.py (layered chiptune, town + boss themes), generer_skylines.py (skylines, sprites)
docs/       screenshots, the design specs (LAN, then online) and the phase plans (superpowers/)
````

Dans `README.md`, remplacer :

````markdown
a time (they share local ports).

Screenshots, with a real renderer (windows open while the scripts run):
````

par :

````markdown
a time (they share local ports).

The end-to-end test plays a real online round in three browser pages (Chromium and Firefox; WebKit
checks **Copy link**), on the "Web pilote" export and a local Worker that it starts itself
(`python3` serves the export on port 8060, `wrangler dev` listens on 8787):

```sh
godot --headless --export-release "Web pilote" export/web-pilote/index.html
(cd signalisation && npm ci) && cd tests/web && npm ci && npx playwright install chromium firefox webkit
xvfb-run -a npx playwright test   # Linux; Firefox needs a display for WebGL 2
```

On a Mac whose firewall blocks incoming connections to Playwright's browsers (WebRTC between two
pages then never connects), run it in the Playwright image instead (Docker or OrbStack), from the
repository root, after the export:

```sh
docker run --rm --init -v "$PWD":/depot -v lelion-modules-signalisation:/depot/signalisation/node_modules \
  -v lelion-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble \
  bash -c '(cd ../../signalisation && npm ci) && npm ci && xvfb-run -a npx playwright test'
```

Screenshots, with a real renderer (windows open while the scripts run):
````

Dans `README.md`, remplacer :

````markdown
## Export and CI

`export_presets.cfg` defines a single Web preset (single-threaded, so it needs no cross-origin
isolation headers). With the export templates installed:

```sh
````

par :

````markdown
## Export and CI

`export_presets.cfg` defines the Web preset (single-threaded, so it needs no cross-origin isolation
headers), and "Web pilote", the same plus the `pilote` feature for the end-to-end test (never
published). With the export templates installed:

```sh
````

Dans `README.md`, remplacer :

````markdown
The workflow in `.github/workflows/ci.yml` runs on every pull request and every push to `main`: it
installs Godot 4.7.2 and its export templates, runs the unit tests, the smoke test, the local
battle test, the prediction bench, the network test (real broadcast included) and the two capture
scripts without a renderer, then exports the Web build and publishes it as the `LeLion-web`
artifact (kept 30 days). Deployment to GitHub Pages comes with online play.
````

par :

````markdown
The workflow in `.github/workflows/ci.yml` runs on every pull request and every push to `main`: it
installs Godot 4.7.2 and its export templates, runs the unit tests, the smoke test, the local
battle test, the prediction bench, the network test and the two capture scripts without a
renderer, then exports the Web build and publishes it as the `LeLion-web` artifact (kept 30 days).
A second job tests the signalling Worker; a third exports "Web pilote" and runs the end-to-end test.
Deployment to GitHub Pages comes with the Worker's (a later phase).
````

- [ ] **Step 3 : Commit**

```bash
git diff --stat
git add docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md README.md
git commit -m "Spec et README : le contrat de Transport pour WebRTC (pair_pret, echec avant pret, salle_fermee), TransportWebRTC, la salle fermée au salon, le bout en bout (export Web pilote, Playwright, Xvfb, conteneur sur un Mac à pare-feu)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 8 : vérification commune, feuille de route, PR et fusion de la phase 4

**Files:**
- Modify: `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 4 : fichiers réels, « Faite (PR #N) »)

**Interfaces:** aucune.

- [ ] **Step 1 : la vérification commune (feuille de route), sans relance**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
pgrep -f '^godot --headless' || echo "aucun autre godot"
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|PROTOCOLE|== " "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd > "$TMPDIR/b.log" 2>&1; echo "bataille $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/b.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "banc $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/p.log"
SECONDS=0; timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r.log"
(cd signalisation && npm test 2>&1 | tail -4)
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/dc.log" 2>&1 &
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/dh.log" 2>&1; echo "deux fenêtres hôte $?"; wait; grep -c "📸" "$TMPDIR/dh.log" "$TMPDIR/dc.log"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/dh.log" "$TMPDIR/dc.log"
mkdir -p export/web export/web-pilote
timeout 600 godot --headless --export-release Web export/web/index.html > "$TMPDIR/e.log" 2>&1; echo "export $?"
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
SECONDS=0; timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion-modules-signalisation:/depot/signalisation/node_modules -v lelion-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test' > "$TMPDIR/e2e.log" 2>&1; echo "bout en bout $? en ${SECONDS} s"; grep -E "✓|✘|passed|failed" "$TMPDIR/e2e.log"
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/web/*.js
git status --short
```

Expected : « aucun autre godot » ; pas de « ÉCHEC COMPILATION » ; chaque suite Godot sort en 0 sur `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR` ; `PROTOCOLE 0.20 2553814265 (67 lignes)` ; réseau en 155 à 170 s (mesuré 159 et 160 s sur ce plan appliqué), ses trois mesures ; les tests du Worker verts ; 38 📸 pour les captures, 5 et 6 pour les deux fenêtres (aucun écran capturé ne change) ; `export 0`, `export pilote 0` ; `bout en bout 0`, `3 passed` ; rien au `perl` ; `git status` propre. Un échec : le corriger dans la tâche qu'il concerne (commit à part), puis tout relancer.

- [ ] **Step 2 : la branche poussée, la PR ouverte** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
git push -u origin phase-04-webrtc
cat > "$TMPDIR/pr.md" <<'EOF'
Phase 4 de la feuille de route du jeu en ligne : WebRTC, et son test de bout en bout.

- `Transport` : `pair_pret` (le pair d'un client qui naît à `bienvenue` : `SceneMultiplayer` refuse un `WebRTCMultiplayerPeer` avant `create_client`), `echec` chez l'hôte avant `pret` (routé en `connexion_echouee` + `raison_echec`), `salle_fermee` après `pret` (la partie continue). `TransportENet` inchangé.
- `TransportWebRTC` : signalisation en `WebSocketPeer` (texte seulement, 15 envois par seconde au plus, identifiants en entiers, `ping` toutes les 30 s, délais de 5 s et 15 s, fermeture `ouvert` attendue, `erreur delai` et `depart` traités), `WebRTCMultiplayerPeer` en étoile, canaux du §5, `?relais=1` (`iceTransportPolicy: "relay"`, passé tel quel par Godot 4.7.2 au `RTCPeerConnection`). Adresse du Worker : réglage `lelion/signalisation/url` (`ws://localhost:8787`, la phase 5 y mettra l'adresse déployée).
- Export Web : Créer et Rejoindre passent par WebRTC ; l'écran En ligne attend le code (CRÉATION) ; le salon dit la salle expirée.
- Pilote (`Scripts/PiloteWeb.gd`, export « Web pilote » seulement) et `tests/web/` (Playwright 1.63.0) : une manche de 10 s à trois pages sous Chromium et Firefox, la même empreinte dans les trois consoles, le départ de l'hôte vu ; *Copier le lien* sous un vrai clic sous WebKit. Job CI `bout-en-bout`.

Mesures (ce Mac, Step 1) : MESURES

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
gh pr create --repo w3cdotorg/LeLion-web --base main --head phase-04-webrtc --title "Phase 4 : WebRTC" --body-file "$TMPDIR/pr.md"
N=$(gh pr view --repo w3cdotorg/LeLion-web phase-04-webrtc --json number -q .number); echo "PR #$N"
```

Entre l'écriture de `$TMPDIR/pr.md` et `gh pr create`, y remplacer `MESURES` (outil Edit) par les mesures du Step 1 : la durée du test réseau, celle du bout en bout, les trois tests passés.

- [ ] **Step 3 : la feuille de route**

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

````markdown
| ➕ `Scripts/TransportWebRTC.gd` ✏️ `Scripts/Reseau.gd` (choix du transport) ➕ `tests/web/bout_en_bout.spec.js` ➕ `tests/web/playwright.config.js` ✏️ `.github/workflows/ci.yml` | Une manche de 10 s à 3 pages, même empreinte, départ de l'hôte vu. |
````

par (`NUMERO` est le numéro de la PR, `$N` du Step 2) :

````markdown
| ➕ `Scripts/TransportWebRTC.gd` ➕ `Scripts/PiloteWeb.gd` ✏️ `Scripts/Transport.gd` ✏️ `Scripts/Reseau.gd` (choix du transport, pair tardif, création jusqu'au code) ✏️ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `project.godot` ✏️ `export_presets.cfg` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ➕ `tests/web/` (`bout_en_bout.spec.js`, `playwright.config.js`, `package.json`) ✏️ `.github/workflows/ci.yml` ✏️ spec ✏️ `README.md` | Une manche de 10 s à 3 pages, même empreinte, départ de l'hôte vu (Chromium et Firefox), *Copier le lien* sous WebKit. Faite (PR #NUMERO). |
````

puis :

```bash
perl -pi -e "s/PR #NUMERO/PR #$N/" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
grep -c "Faite (PR #$N)" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git add docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git commit -m "Feuille de route : phase 4 faite (PR #$N)

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

Expected : les trois jobs verts (le job `bout-en-bout` tourne ici pour la première fois sur GitHub : un échec propre à son environnement, par exemple Firefox sans fenêtre ou un délai de 15 s dépassé sur une machine lente, se diagnostique avec l'artefact `rapport-playwright` avant toute retouche) ; la fusion faite, `main` à jour. La CI rouge : ne pas fusionner, diagnostiquer.
