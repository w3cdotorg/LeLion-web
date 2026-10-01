# LeLion web : la bataille de peinture en ligne, dans le navigateur

Date : 2026-10-01 · Statut : validé en brainstorming, à relire avant le plan

Dépôt : `w3cdotorg/LeLion-web` (copie de `w3cdotorg/LeLion-multi` à la version 0.19, avec son
historique, sans lien de fork). La spec du LAN (`2026-09-25-multijoueur-lan-design.md`) reste la
référence pour tout ce que celle-ci ne change pas : règles, salon, manche, prédiction, HUD, Résultats.

## 1. Objectif

Des amis, **chacun chez soi**, ouvrent un lien et jouent une bataille de peinture de 2 à 6 joueurs
**dans leur navigateur**, sans rien installer. L'hôte crée la partie sur un **ordinateur** ; les
autres la rejoignent depuis un ordinateur ou un **mobile** (Android, iOS), y compris en 4G/5G.

Critère de réussite : une manche complète à au moins 3 joueurs, dont un mobile en 4G et un joueur
dans un autre foyer, sans installation ni réglage réseau (fiche `docs/essai-en-ligne.md`, §10).

Contraintes posées par l'utilisateur :
- **WebRTC de pair à pair** : le navigateur de l'hôte est l'hôte autoritaire (option B du
  brainstorming), pas de serveur de jeu.
- **Pas d'auto-hébergement** : aucun serveur à louer ni à administrer. La page est statique (GitHub
  Pages) ; la signalisation et le TURN passent par l'offre gratuite de Cloudflare (Worker + Durable
  Object, TURN Cloudflare), déployée par la CI.
- **Navigateur seulement** : les exe desktop ne jouent pas en ligne.

### Hors périmètre (YAGNI)

- Liste publique des salles (on ne rejoint qu'avec un code ou un lien).
- Hôte sur mobile (le bouton *Créer une partie* n'y existe pas) et migration d'hôte.
- Exe Windows, macOS, Linux livrés ; jeu en ligne depuis un exe ; extension webrtc-native.
- Comptes, chat, spectateurs, arrivée en cours de manche (inchangé depuis le LAN).
- Découverte LAN et saisie d'IP (retirées).

## 2. Décisions

| Sujet | Décision |
|---|---|
| Transport du jeu livré | `WebRTCMultiplayerPeer`, en étoile autour de l'hôte (l'hôte en `create_server`, chaque client en `create_client`). Natif dans l'export Web de Godot, sans extension. |
| Signalisation | Un Worker Cloudflare et un Durable Object `Salle` par partie, parlés en WebSocket (JSON) par Godot (`WebSocketPeer`). |
| STUN / TURN | STUN Google et Cloudflare, TURN Cloudflare (UDP, TCP, TLS 443). Identifiants TURN fabriqués par le Worker, valables 2 h, donnés seulement aux membres d'une salle. |
| Rejoindre | Code de salle de 6 caractères (alphabet sans 0/O, 1/I/L), affiché `K7Q-2XM`, et lien `https://w3cdotorg.github.io/LeLion-web/?salle=K7Q2XM`. Privé : pas de liste. |
| Hôte | Ordinateur seulement. Il doit garder l'onglet au premier plan (le navigateur fige un onglet caché). |
| Silence | **10 s pour tout le monde** (hôte comme client) avant de déclarer un poste parti ; 30 s pendant le chargement de la manche (inchangé). Battement applicatif, indépendant du transport. |
| Mobiles | Rejoignent seulement ; contrôles tactiles en salon et en manche, écran « Tourne ton téléphone » en portrait, plein écran au premier toucher. |
| Exclusion | L'hôte peut exclure un joueur depuis le salon (croix sur sa carte). |
| Distribution | Export Web single-thread sur GitHub Pages, déployé avec le Worker sur un tag `vX.Y`. |

## 3. Architecture

Principe inchangé : **un socle commun, des règles interchangeables, un seul chemin d'autorité**. Ce
qui change est sous `Reseau` : le transport devient une unité à part, avec deux implémentations.

### 3.1 Unités

| Unité | Rôle | Dépend de |
|---|---|---|
| `Reseau` (autoload, allégé) | Poignée de main (authentification de `SceneMultiplayer`, inchangée), table du salon, barrière de chargement, relance de manche, départs. Ne nomme plus aucune classe ENet. Tient le **battement** : chaque poste envoie un battement par seconde (non fiable) ; tout paquet de `Reseau` reçu d'un pair, battement ou RPC, remet son silence à zéro (`SceneMultiplayer` ne donne ni l'heure de réception par pair ni un signal par RPC reçue : le trafic de la manche n'est pas compté, le battement y suffit) ; 10 s de silence (30 s au chargement) le déclarent parti. Départ volontaire : un adieu fiable, puis le transport ferme une fois l'adieu envoyé (§5). Un exclu part de lui-même à l'annonce, fiable ; l'hôte le libère ensuite. Ajoute l'**exclusion** par l'hôte (§8). | `Transport`, `GameState` |
| `Transport` (interface `@abstract`, `RefCounted`) | `heberger() -> Error`, `rejoindre(code: String) -> Error`, `quitter()` (ferme une fois envoyé ce qui est en file, en arrière-plan), `clore()` (tout de suite), `pair() -> MultiplayerPeer`, `liberer(id)` (chez l'hôte : ferme sur-le-champ le canal d'un pair parti, muet ou exclu, sans attendre de réponse ; son `peer_disconnected` part pendant l'appel), `servir() -> bool` (à chaque image ; faux une fois fermé) ; signaux `pret(code)` (chez l'hôte : la salle existe), `connecte()` (chez le client : canal ouvert, la poignée de main peut partir), `echec(raison)`. Ne sait rien du salon ni du jeu. | rien |
| `TransportWebRTC` | Le transport livré : la signalisation (§4), un `WebRTCPeerConnection` par client chez l'hôte, la configuration ICE reçue du Worker, les canaux (§5). | `Transport`, `WebSocketPeer` |
| `TransportENet` | Le transport ENet de LeLion-multi, extrait de `Reseau.gd`, gardé pour la **version desktop de développement et les tests headless** (le test réseau, le relais de latence). Jamais choisi dans l'export Web. Le « code » y est `ip:port`. | `Transport` |
| `EcranEnLigne` (remplace `EcranReseau`) | Pseudo (mémorisé dans `Scores`), *Créer une partie* (absent sur mobile), *Rejoindre* avec un champ de code (pré-rempli par `?salle=`), messages d'erreur (§9). Le salon de l'hôte affiche le code et *Copier le lien*. Le code (`CodeSalle`) : un code de salle sur le Web ; l'adresse `ip:port` d'un hôte `TransportENet` sur le desktop de développement. Passe par `Reseau.creer_partie()` et `Reseau.rejoindre_partie(code)`, qui choisissent le transport. | `Reseau`, `CodeSalle` |
| `signalisation/` (Worker + Durable Object `Salle`, JavaScript) | Crée les salles, relaie offres, réponses et candidats entre l'hôte et chaque arrivant, fournit les identifiants TURN, applique les plafonds (§8). Ne lit pas le contenu WebRTC. Six modules (`index`, `origine`, `code`, `protocole`, `ice`, `salle`, environ 440 lignes), avec ses tests `vitest` dans l'environnement local de Cloudflare (`@cloudflare/vitest-plugin`). | API TURN de Cloudflare |

Le choix du transport : `TransportWebRTC` quand `OS.has_feature("web")`, `TransportENet` sinon (ou
forcé par les tests).

### 3.2 Ce qui disparaît

`Scripts/Decouverte.gd` (balises UDP 7778), la saisie d'IP, l'écran Réseau du LAN, les préréglages
d'export Windows, macOS et Linux, le job de Release et ses vérifications (wrestool, application
universelle), la section « Jouer en LAN » du README. Les tests de découverte (scénarios et
`DIFFUSION=1`) partent avec elle.

## 4. Salles et signalisation

### 4.1 Points d'entrée du Worker

Tous sous `wss://<worker>/v1/…` : la version du protocole de signalisation est dans le chemin, pour
qu'une page ancienne restée ouverte ne casse pas contre un Worker neuf (un `/v2` coexiste le temps
d'une transition). La version du jeu reste vérifiée par la poignée de main.

- `GET /v1/creer` (upgrade WebSocket) : l'hôte. Le Worker tire un code libre (nouvel essai si la
  salle de ce code a déjà un hôte, 5 essais au plus, puis `erreur` `quota`), crée le Durable Object
  `Salle` de ce code (`idFromName`) et lui passe la socket.
- `GET /v1/rejoindre/<code>` (upgrade WebSocket) : un arrivant. Code mal formé : 400 (le code s'y
  écrit sans tiret, en majuscules ou en minuscules) ; salle sans hôte : message `erreur` `inconnue`
  puis fermeture.
- Les autres refus (origine, débit, quota, salle pleine) passent eux aussi par une socket acceptée
  le temps d'un message `erreur` : un navigateur ne montre pas au jeu le statut HTTP d'une WebSocket
  refusée. Hors de ces deux chemins : 404 ; autre méthode que GET : 405 ; sans upgrade : 426.

### 4.2 Messages (JSON, champ `t`)

| De → vers | Message | Sens |
|---|---|---|
| Salle → hôte | `{t:"salle", code, id:1, ice}` | La salle existe ; `ice` = liste `iceServers` (STUN + TURN, identifiants 2 h). |
| Salle → client | `{t:"bienvenue", id, ice}` | `id` : identifiant de pair tiré au hasard dans 2..2³¹-1, unique dans la salle. |
| Salle → hôte | `{t:"arrivee", id, ice}` | Un client arrive ; `ice` neuf (les identifiants de l'hôte se renouvellent ainsi, la salle vivant jusqu'à 4 h). |
| Hôte ↔ client (relayé) | `{t:"offre"\|"reponse", vers, sdp}`, `{t:"candidat", vers, media, index, nom}` | La salle vérifie que `vers` est membre, remplace l'émetteur par `de` et relaie (`{t, de, sdp}`, `{t, de, media, index, nom}` : les champs des signaux de `WebRTCPeerConnection`). Seulement entre l'hôte et un client, jamais entre deux clients. Un message invalide (type inconnu, champ en plus ou en moins, mauvais type, `vers` absent de la salle) est ignoré, sans fermer la socket. |
| Salle → hôte | `{t:"depart", id}` | La socket d'un client s'est fermée avant que l'hôte ait dit `ouvert` : fermée par le client, ou par la salle qui l'a chassé (`debit`, `delai`). |
| Hôte → salle | `{t:"ouvert", id}` | Le canal WebRTC avec `id` est ouvert : la salle oublie ce client et ferme sa socket (code 1000, motif `ouvert`, sans `erreur` : le client ne la prend pas pour un échec). |
| Hôte → salle | `{t:"ping"}` | Toutes les 30 s ; réponse automatique `{t:"pong"}` (hibernation du Durable Object, §8). |
| Salle → tous | `{t:"erreur", raison}` puis fermeture | `inconnue`, `pleine`, `debit`, `quota`, `origine`, `expiree` (§4.3, point 4), `delai` (arrivant que l'hôte n'a pas dit `ouvert` 30 s après son arrivée, §4.3 point 3, §8.1). Fermeture : code 1000, la raison en motif. |

### 4.3 Déroulé

1. **Création** : l'hôte ouvre `/v1/creer`, reçoit `salle`, affiche le salon avec le code. Sa socket
   reste ouverte tant que la salle vit, retour de manche compris. Socket fermée (onglet fermé, retour
   au titre), ou hôte au-delà d'un plafond (§8.1) : la salle est supprimée, ses arrivants en cours
   reçoivent `erreur` `inconnue`.
2. **Arrivée** : le client ouvre `/v1/rejoindre/<code>`, reçoit `bienvenue` ; l'hôte reçoit `arrivee`,
   crée la connexion WebRTC (`create_server` déjà fait, `add_peer(id)`), envoie son offre ; offre,
   réponse et candidats passent par la salle. Canal ouvert : l'hôte envoie `ouvert`, la salle ferme
   la socket du client (le client ne la ferme pas lui-même : il attend cette fermeture 1000 `ouvert`),
   puis la poignée de main du LAN se déroule (version, pseudo, refus partie pleine ou manche en cours).
3. **Délai** : canal non ouvert 15 s après `bienvenue` : échec côté client (« Connexion impossible
   avec l'hôte (réseau trop restrictif ?) »), et l'hôte retire le pair. Côté salle, un arrivant que
   l'hôte n'a pas dit `ouvert` 30 s après son arrivée est oublié (`erreur` `delai`, `depart` à l'hôte,
   sa place libérée) : le filet d'un client qui ne ferme pas sa socket (§8.1).
4. Une salle vit **4 h au plus** (alarme du Durable Object), puis elle envoie `erreur` `expiree` et
   ferme toutes ses sockets (la partie en cours continue
   en WebRTC, mais plus personne ne peut arriver ; le salon de l'hôte affiche « Salle expirée : crée
   une nouvelle partie pour inviter »).

### 4.4 Lien

`?salle=K7Q2XM` est lu au démarrage par `JavaScriptBridge` (`location.search`). S'il est présent et
valide, le jeu ouvre l'écran En ligne sur *Rejoindre*, code rempli ; il ne rejoint qu'après le pseudo
validé. *Copier le lien* passe par `DisplayServer.clipboard_set` (sur le Web, l'API du presse-papiers,
qui exige le geste du clic : le bouton le fournit). Le lien part de l'adresse de la page ouverte
(origine et chemin, sans paramètres : `https://w3cdotorg.github.io/LeLion-web/` une fois publiée), ou,
hors du Web, du réglage de projet `lelion/page/url`. Le lien ne sert qu'une fois par lancement (un
retour au titre ne rouvre pas l'écran En ligne).

## 5. En jeu

- **Canaux** : canal 0 en non fiable (commandes, états, battement : `unreliable_lifetime` d'environ
  100 ms, 1 seul envoi), canal 1 fiable et ordonné (tampons, territoire, fin, lancement, table de
  relance : `CANAL_ORDONNE`, inchangé), configuré à la création du pair (`create_server` /
  `create_client` avec un canal fiable en plus des canaux par défaut). Le fiable du canal 0 (poignée
  de main, table du salon) reste sur le canal fiable par défaut.
- **Redondance des commandes**, prédiction du lion local, interpolation des lions distants : inchangées.
  Le banc de la prédiction gagne un **profil mobile** (150 ms de latence, 60 ms de gigue, 8 % de
  pertes) ; `InterpolationLion.RETARD` (6 ticks aujourd'hui) et les seuils de `PredictionLocale` ne
  se règlent que sur ses mesures.
- **Onglet caché ou téléphone verrouillé** :
  - un client caché n'envoie plus rien : 10 s après, l'hôte le déclare parti (son lion disparaît, ses
    cellules restent, comme au LAN). À son retour, son poste voit « Tu as été déconnecté » et revient
    à l'écran En ligne ;
  - l'hôte caché fige le jeu de tous : le salon lui affiche « Garde cet onglet au premier plan
    pendant la partie. » ; 10 s de silence de l'hôte donnent aux clients « L'hôte a quitté la
    partie » (retour à l'écran En ligne depuis le salon, au titre depuis une manche, comme au LAN).
- **Départ volontaire** : un message fiable « je pars » puis fermeture du pair après son envoi (au
  plus 1 s) ; l'autre côté le voit parti tout de suite, sans attendre les 10 s.
- **Pause** : aucune en réseau (inchangé).

## 6. Mobiles

- Détection par `OS.has_feature("web_android")` / `OS.has_feature("web_ios")` : *Créer une partie*
  absent, contrôles tactiles affichés.
- `ControlesTactiles` (joystick et bouton Vomir du solo) s'étend au salon (couleur, Prêt) et à la
  manche, dans le viewport 16:9 de 2000×1125, mis à l'échelle sur petit écran.
- En portrait : un voile « Tourne ton téléphone » par-dessus le jeu, qui continue de tourner.
- Plein écran au premier toucher sur mobile ; bouton *Plein écran* dans le salon sur ordinateur
  (les navigateurs exigent un geste, `Parametres.gd` le respecte déjà).
- Son : `audio/general/default_playback_type.web` en `Stream` (plantage de Safari iOS connu en
  lecture `Sample` après 10 à 30 min).

## 7. Viewport, HUD, Résultats

Inchangés. Le HUD et l'écran Résultats sont vérifiés en captures à 360×640 (portrait refusé, voile
compris) et 844×390 (paysage mobile) en plus du 16:9 desktop.

## 8. Sécurité

### 8.1 Worker

- **Origine** : WebSocket acceptée seulement depuis `https://w3cdotorg.github.io` et
  `http://localhost:*` (variable du Worker `ORIGINES` ; `:*` = tout port ou aucun). Ça freine le
  pillage, ça ne protège pas seul. Sans en-tête `Origin` : refusée (le jeu livré est l'export Web,
  dont le navigateur l'envoie toujours ; le desktop de développement joue en ENet).
- **Plafonds par salle** : 7 sockets (l'hôte et 6 arrivants en cours) ; messages de 16 Ko au plus
  (16 384 octets UTF-8) ; 20 messages par seconde et par socket (seau de jetons de 20, rempli de 20
  par seconde, gardé dans la fiche de la socket) ; au-delà, `erreur` puis fermeture (`pleine` pour
  la 8e socket, `debit` pour la taille et le débit ; un client au-delà est chassé, `depart` à l'hôte ;
  un hôte au-delà ferme sa salle, ses arrivants reçoivent `inconnue`). Le `ping`, servi par le
  runtime, ne compte pas. Une trame binaire n'est jamais relayée, mais se mesure et prend son jeton.
- **Délai d'arrivée** : 30 s pour que l'hôte dise `ouvert` (le double des 15 s du client, §4.3) ;
  au-delà, la salle oublie l'arrivant (`erreur` `delai`, `depart` à l'hôte) et sa place se libère.
  Les échéances (expiration de la salle chez l'hôte, délai de chaque arrivant) vivent dans les fiches
  des sockets ; une seule alarme, posée à la plus proche, les balaie et se repose à la suivante.
- **Limite par IP** : 5 salles créées et 30 arrivées par minute et par IP (`cf-connecting-ip`), par
  la limitation de débit des Workers (bindings `ratelimits` `LIMITE_CREATION` et `LIMITE_ARRIVEE`,
  générale depuis le 19/09/2025, simulée par Miniflare en local et testée) ; au-delà, `erreur`
  `debit` (l'arrivée est comptée avant la salle, code inconnu compris). Une IPv6 compte pour son /64
  (un abonné en reçoit en général un entier), une IPv4 mappée (`::ffff:a.b.c.d`) pour son IPv4.
  Compteurs par point de présence et cohérents à terme : un frein, pas un compte exact. Un limiteur
  injoignable laisse passer (ouvert par défaut, journalisé) : sa panne ne ferme pas le service.
  Vérifié en phase 2 (documentation du 01/10/2026) : ni la page *Rate Limiting* ni les tarifs et
  limites des Workers ne la réservent à une offre, sans dire en toutes lettres qu'elle existe sur
  l'offre gratuite ; le premier `wrangler deploy` (phase 5) le tranche, et sinon un Durable Object
  compteur la remplace.
- **Validation** : type de message connu, `vers` membre de la salle, champs attendus seulement ; un
  message invalide est ignoré, sans fermer la socket (un relais vers un client parti à l'instant est
  une course normale) ; le contenu SDP n'est ni lu ni journalisé.
- **TURN** : la clé TURN et le jeton d'API restent dans les secrets du Worker ; identifiants à 2 h,
  donnés seulement par `salle`, `bienvenue` et `arrivee`. Fabriqués par
  `POST https://rtc.live.cloudflare.com/v1/turn/keys/<TURN_KEY_ID>/credentials/generate-ice-servers`
  (`Authorization: Bearer <TURN_KEY_API_TOKEN>`, corps `{"ttl": 7200}`, réponse 201 `iceServers` ;
  vérifié dans la documentation TURN de Cloudflare le 01/10/2026), URL du port 53 retirées (bloqué
  par les navigateurs) ; un seul jeu par arrivée, donné à l'arrivant et à l'hôte. Sans secrets
  (développement local), API en erreur ou muette 3 s : STUN seul (Cloudflare et Google).
- **Coût** : Durable Object en hibernation de WebSocket (pas de durée facturée pour une socket
  inactive) ; quota gratuit dépassé : `erreur quota`, le jeu dit « Trop de parties en ce moment,
  réessaie plus tard. ». Sur l'offre gratuite, une opération au-delà du quota quotidien des Durable
  Objects échoue (tarifs des Durable Objects) : le Worker répond `erreur quota` à tout appel de salle
  qui échoue. Le quota du Worker lui-même (requêtes par jour) ne se détecte pas de l'intérieur :
  Cloudflare répond à sa place, le jeu y voit un service injoignable.

### 8.2 Jeu

- RPC des clients : en plus des vérifications de type et d'émetteur déjà faites, l'hôte jette au-delà
  de 2 paquets de commandes par tick et par client, et de 10 demandes de salon (couleur, Prêt) par
  seconde.
- Poignée de main : bornée en taille (inchangé), décodée sans objets (`bytes_to_var`, inchangé).
- Pseudos : 12 caractères (inchangé), caractères de contrôle et sauts de ligne retirés ; jamais de
  BBCode interprété (`RichTextLabel` avec `bbcode_enabled` interdit pour un pseudo).
- **Exclusion** : l'hôte exclut un joueur du salon (croix sur sa carte) ; l'exclu reçoit « L'hôte
  t'a exclu de la partie. » puis l'hôte ferme son pair. Sans compte, rien n'identifie durablement
  un joueur : un exclu peut revenir avec le code, et l'hôte l'exclut à nouveau (§13).
- Vie privée : aucun compte, rien de stocké. Cloudflare voit les IP le temps de la signalisation ;
  hôte et client voient l'IP l'un de l'autre, sauf connexion par le TURN. Le README le dit.

## 9. Gestion des erreurs

| Situation | Comportement |
|---|---|
| Code mal formé | Refusé à la saisie : « Un code fait 6 caractères (ex. K7Q-2XM). » ; un 0, O, 1, I ou L, jamais remplacé en silence : « Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM). » |
| Code inconnu, salle fermée | « Aucune partie avec ce code. » |
| Worker injoignable (5 s) | « Service de connexion indisponible, réessaie dans un instant. » |
| Origine refusée, débit dépassé | « Service de connexion indisponible, réessaie dans un instant. » (journal : raison exacte) |
| Quota gratuit dépassé | « Trop de parties en ce moment, réessaie plus tard. » |
| Canal WebRTC toujours fermé 15 s après `bienvenue` | « Connexion impossible avec l'hôte (réseau trop restrictif ?) » |
| Version différente, partie pleine, manche en cours | Refus du LAN, inchangés (`Reseau.REFUS_*`) |
| Exclu par l'hôte | « L'hôte t'a exclu de la partie. » |
| Hôte muet 10 s | « L'hôte a quitté la partie » (retours du LAN) |
| Client revenu d'un onglet caché, déclaré parti entre-temps (silence) | « Tu as été déconnecté » puis écran En ligne |
| Salle expirée (4 h) | Chez l'hôte, dans le salon : « Salle expirée : crée une nouvelle partie pour inviter » |

## 10. Tests

- **Conservés** : `tests/unitaires.gd`, `smoke_test.gd`, `bataille_test.gd`, `prediction_test.gd`
  (profil mobile en plus), le test réseau (11 scénarios, numérotés 1 à 5 et 8 à 13 : les 6 et 7 de
  la découverte retirés en phase 3 bis ; sur `TransportENet`, relais de latence compris),
  `trace_lions.gd`, `screenshots.gd` (écran En ligne, salon avec code,
  contrôles tactiles, voile portrait) et `deux_fenetres.gd`. Le silence passe de 3 à 8 s à 10 s : les
  scénarios qui attendent un départ par silence (11 : client arraché) s'allongent d'autant.
- **Unitaires nouveaux** : format et alphabet du code, lecture de `?salle=`, nettoyage des pseudos,
  battement et silence, limites de débit des RPC, exclusion.
- **Worker** (`signalisation/`, `vitest` dans l'environnement local de Cloudflare, sans compte) :
  création, code unique, arrivée, relais limité à hôte ↔ client, `depart`, `ouvert`, plafonds (7
  sockets, 16 Ko, 20 msg/s), limites par IP (création, arrivée, /64), origine refusée, expiration à
  4 h, délai d'arrivée de 30 s, identifiants TURN (API Cloudflare simulée), réponses automatiques
  `ping`.
- **De bout en bout WebRTC** (Playwright, Chromium et Firefox, en CI) : l'export Web servi en local,
  le Worker en local (`wrangler dev`), 3 pages. Création, arrivée de deux pages par le lien, Prêt,
  manche de 10 s, même empreinte sur les 3 pages (lue dans la console), exclusion d'un joueur, départ
  de l'hôte vu par les autres. Le TURN ne se teste pas en local.
- **Essai réel** : `docs/essai-en-ligne.md` (hôte sur ordinateur, au moins un mobile en 4G, un joueur
  dans un autre foyer ; une manche avec le relais TURN forcé par `?relais=1`, paramètre de
  diagnostic qui pose `iceTransportPolicy: "relay"`). Ses réponses font la phase 6 bis.

## 11. Build, déploiement et prérequis

- **CI sur `main`** : tests Godot, tests du Worker, export Web, test Playwright ; l'export en
  artefact. Rien n'est mis en ligne.
- **Tag `vX.Y`** (= `application/config/version`) : déploiement du Worker (`wrangler deploy`), puis
  de la page sur GitHub Pages (`actions/deploy-pages`). L'URL du Worker est écrite dans l'export
  (réglage de projet `lelion/signalisation/url`).
- **Prérequis côté utilisateur** (phase 4) : un compte Cloudflare (offre gratuite), une application
  TURN créée dans le tableau de bord (clé TURN et jeton), un jeton d'API pour `wrangler`, et les
  secrets correspondants dans le dépôt GitHub (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`) et
  dans le Worker (`TURN_KEY_ID`, `TURN_KEY_API_TOKEN`). Pages activé sur le dépôt (source : GitHub
  Actions). Rien n'est créé sans l'utilisateur.
- **Dépôt public** : GitHub Pages gratuit l'exige pour une organisation sur l'offre gratuite.
- README : en anglais comme aujourd'hui, avec une section « Jouer en ligne » en français (créer,
  inviter, rejoindre, onglet au premier plan, mobiles, vie privée, dépannage message par message).

## 12. Phases (le découpage exact viendra du plan)

Le découpage exact est celui de la feuille de route (`docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`), qui fait foi : elle le revoit (la découverte LAN part avec l'écran En ligne, en 3 bis ; le WebRTC et son test de bout en bout vont ensemble, en 4 ; le déploiement a sa phase, 5). Le tableau ci-dessous garde le découpage du brainstorming.

Chaque phase touche 5 fichiers au plus, se termine par les tests verts et attend une validation.

| # | Contenu |
|---|---|
| 0 | Création du dépôt GitHub (avec l'utilisateur) ; Step 0 : retrait de la découverte LAN, de la saisie d'IP, des exports desktop et des Releases ; README. Les tests restants verts. |
| 1 | Interface `Transport` et `TransportENet` extrait de `Reseau.gd` ; battement applicatif à 10 s. Les 13 scénarios (moins la découverte) verts. |
| 2 | Worker de signalisation et ses tests `vitest`. |
| 3 | `TransportWebRTC`, écran En ligne (code, lien, *Copier le lien*), `?salle=`. |
| 4 | Test Playwright de bout en bout, déploiement par la CI (compte Cloudflare prêt). |
| 5 | Mobiles : tactile au salon et en manche, voile portrait, plein écran, son `Stream`, création réservée aux ordinateurs, profil mobile du banc. |
| 6 | Sécurité du jeu (débit des RPC, pseudos, exclusion), README « Jouer en ligne », fiche d'essai. |
| 6 bis | Réglages après l'essai réel. |

## 13. Risques

- **Onglet de l'hôte caché** : le jeu se fige pour tous (contrainte du navigateur). Parades :
  hôte sur ordinateur, consigne dans le salon, 10 s de tolérance.
- **NAT stricts en 4G/5G** (25 à 35 % des connexions mobiles sans TURN) : TURN Cloudflare en UDP,
  TCP et TLS 443 ; mesuré à l'essai avec `?relais=1`.
- **Latence Internet** (30 à 120 ms, plus en 4G) : prédiction déjà éprouvée sous 80/40/5 ; profil
  mobile ajouté au banc, réglages sur mesures seulement.
- **Offre gratuite de Cloudflare** : Durable Objects gratuits avec le stockage SQLite seulement
  (`new_sqlite_classes`, phase 2) ; limitation de débit : aucune restriction d'offre dans la
  documentation (phase 2, §8.1), le premier déploiement le confirme (phase 5) ; TURN : 1 000 Go
  gratuits, reste à vérifier en phase 5 s'il exige une carte bancaire pour être activé.
- **Safari iOS** : WebGL 2 et son ; un ancien ticket Godot (WebRTC bloqué en « connecting », 4.2) n'a
  pas été revérifié : à tester en phase 5 sur un vrai iPhone.
- **Exclu qui revient** : sans compte, rien n'identifie durablement un joueur. L'exclusion est
  rejouable par l'hôte à chaque retour ; le code n'est connu que de ceux qui ont le lien.
- **Deux transports à tenir** : `TransportENet` ne sert qu'aux tests ; tout ce qui n'est pas du
  transport reste dans `Reseau`, couvert des deux côtés (scénarios ENet, Playwright WebRTC).
