# LeLion web : feuille de route d'implémentation

**Spec :** `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`

Le spec couvre plusieurs sous-systèmes : transport, signalisation (Worker Cloudflare), écran En
ligne, WebRTC, déploiement, mobiles, sécurité. Méthode héritée de LeLion-multi : chaque phase a son
propre plan détaillé, écrit juste avant son exécution, contre le code réellement produit par la
phase précédente (`docs/superpowers/plans/2026-10-01-phase-NN-<objet>.md`, à la date du jour
d'écriture). Une phase se termine par les vérifications vertes et attend une validation explicite
avant la suivante (`CLAUDE.md`), sauf accord contraire de l'utilisateur.

**Écart avec le §12 du spec** (qui laissait le découpage exact au plan) : le retrait de la découverte
LAN et de la saisie d'IP ne se fait pas en phase 0 mais avec l'écran En ligne (phase 3 bis). L'écran
Réseau, le salon (adresses de l'hôte) et cinq suites de tests dépendent de `Decouverte` : le retirer
avant d'avoir l'écran qui le remplace casserait le multijoueur pendant trois phases. La phase 0 ne
retire que ce qui ne sert plus à rien dès aujourd'hui (exports desktop, Releases). Le WebRTC et son
test de bout en bout vont ensemble (phase 4), le déploiement a sa phase (5).

## Vérification commune à toutes les phases

Il n'y a ni TypeScript ni ESLint côté jeu : l'équivalent pour Godot est l'import headless (qui
compile tous les scripts) suivi des tests. Le Worker (à partir de la phase 2) a ses tests `vitest`.

```sh
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
timeout 300 godot --headless --script tests/unitaires.gd
timeout 300 godot --headless --script tests/smoke_test.gd
timeout 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd
timeout 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd
timeout 300 bash tests/reseau/lancer.sh
(cd signalisation && npm test)                                     # à partir de la phase 2
```

Les suites Godot doivent finir sur `== 0 échec(s) ==` et un code de sortie 0, sans `SCRIPT ERROR`
ni `SHADER ERROR` dans leur sortie. Options de godot toujours écrites en clair (zsh ne découpe pas
une variable non quotée : `--fixed-fps` sauterait en silence).

## Phases

Légende : ➕ création, ✏️ modification, ➖ suppression. ◉ = contrôle visuel (captures) en fin de phase.

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 0 | **Dépôt et CI Web seule** : création de `w3cdotorg/LeLion-web` (public, sans lien de fork) avec l'utilisateur ; exports Windows, Linux, macOS et job Release retirés ; l'export Web publié en artefact ; README recentré. | ✏️ `.github/workflows/ci.yml` ✏️ `export_presets.cfg` ✏️ `README.md` ➖ `docs/essai-lan.md` | Dépôt en ligne, CI verte, artefact `LeLion-web`. Faite (PR #1). |
| 1 | **Transport** : Step 0 sur `Reseau.gd` (977 lignes : code mort, journaux), puis interface `Transport` et `TransportENet` extrait de `Reseau.gd` (qui ne nomme plus aucune classe ENet) ; battement applicatif d'une seconde et silence de 10 s pour tous (30 s au chargement) à la place des délais d'ENet ; départ volontaire par message fiable. Version 0.20, `PROTOCOLE_EMPREINTE` renotée. | ➕ `Scripts/Transport.gd` ➕ `Scripts/TransportENet.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Decouverte.gd` ✏️ `Scripts/Manche.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ spec ✏️ `README.md` | Les 13 scénarios réseau verts, scénario 11 allongé (silence de 10 s). Faite (PR #2). |
| 2 | **Signalisation** : Worker et Durable Object `Salle` (§4 et §8.1 du spec : messages, plafonds, origine, expiration, identifiants TURN, hibernation), tests `vitest` dans l'environnement local de Cloudflare ; job CI du Worker. Vérifier ici : limitation de débit sur l'offre gratuite. | ➕ `signalisation/package.json` ➕ `signalisation/wrangler.jsonc` ➕ `signalisation/src/index.js` ➕ `signalisation/test/salle.test.js` ✏️ `.github/workflows/ci.yml` | `npm test` vert en local et en CI, sans compte Cloudflare. Faite (PR #3). |
| 3 | **Écran En ligne** : remplace l'écran Réseau (pseudo, *Créer une partie*, *Rejoindre* avec un code) ; code de salle (alphabet, format `K7Q-2XM`, validation), lecture de `?salle=` ; le salon affiche le code et *Copier le lien*. Sur desktop (dev), le code est `ip:port` pour `TransportENet`. ◉ | ➕ `Scripts/CodeSalle.gd` ➕ `Scenes/EcranEnLigne.tscn` ➕ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scenes/Salon.tscn` ✏️ `Scripts/Titre.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Transport.gd` ✏️ `Scripts/TransportENet.gd` ✏️ `project.godot` ✏️ `Assets/Traductions/traductions.csv` ✏️ tests (`unitaires`, `smoke_test`, `screenshots`, `deux_fenetres`, `reseau/`) ✏️ `.github/workflows/ci.yml` ✏️ spec ✏️ `README.md` | Parcours Titre → En ligne → Salon en ENet ; unitaires du code de salle. Faite (PR #4). |
| 3 bis | **Retrait de la découverte** : `Decouverte.gd`, son autoload, l'écran Réseau, les scénarios de découverte et `DIFFUSION=1` ; tests adaptés à l'écran En ligne. | ➖ `Scripts/Decouverte.gd` ➖ `Scripts/EcranReseau.gd` ➖ `Scenes/EcranReseau.tscn` ✏️ `project.godot` ✏️ `Assets/Traductions/traductions.csv` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/Titre.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Regles.gd` ✏️ tests (`smoke_test`, `screenshots`, `deux_fenetres`, `unitaires`, `reseau/`) ✏️ `.github/workflows/ci.yml` ✏️ spec ✏️ `README.md` | Plus aucune référence à `Decouverte` ; captures à jour (compte de la CI ajusté en phase 3 : 38). Faite (PR #5). |
| 4 | **WebRTC** : `TransportWebRTC` (signalisation en `WebSocketPeer`, `WebRTCMultiplayerPeer` en étoile, canaux §5, délai de 15 s, `?relais=1`) ; test de bout en bout Playwright (Chromium et Firefox, 3 pages, Worker en `wrangler dev`) en CI. | ➕ `Scripts/TransportWebRTC.gd` ➕ `Scripts/PiloteWeb.gd` ✏️ `Scripts/Transport.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/CodeSalle.gd` ✏️ `project.godot` ✏️ `export_presets.cfg` ✏️ `Assets/Traductions/traductions.csv` ➕ `tests/web/` ✏️ tests (`unitaires`, `smoke_test`) ✏️ `.github/workflows/ci.yml` ✏️ spec ✏️ `README.md` | Une manche de 10 s à 3 pages, même empreinte, départ de l'hôte vu. Faite (PR #6). |
| 5 | **Déploiement** (compte Cloudflare, application TURN et secrets prêts, avec l'utilisateur) : tag `vX.Y` → `wrangler deploy` puis GitHub Pages ; URL du Worker dans le réglage `lelion/signalisation/url`. Vérifier ici : TURN sans carte bancaire. | ✏️ `.github/workflows/ci.yml` ✏️ `project.godot` ✏️ `signalisation/wrangler.jsonc` ✏️ `README.md` | Première partie en ligne sur `https://w3cdotorg.github.io/LeLion-web/`. |
| 6 | **Mobiles** (§6) : contrôles tactiles au salon et en manche, voile portrait, plein écran au premier toucher, son en `Stream`, *Créer une partie* absent sur mobile ; profil mobile (150/60/8) du banc de la prédiction. ◉ | ✏️ `Scripts/ControlesTactiles.gd` ✏️ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `project.godot` ✏️ `tests/prediction_test.gd` | Captures 360×640 et 844×390 ; banc vert sous le profil mobile. |
| 7 | **Sécurité du jeu et documentation** (§8.2) : débit des RPC des clients, pseudos nettoyés, exclusion par l'hôte (croix sur la carte, message à l'exclu) ; README « Jouer en ligne » ; fiche `docs/essai-en-ligne.md`. ◉ | ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Salon.gd` ✏️ `tests/unitaires.gd` ✏️ `README.md` ➕ `docs/essai-en-ligne.md` | Unitaires des limites et de l'exclusion ; fiche prête pour l'essai. |
| 7 bis | **Réglages de l'essai réel** : les réponses de `docs/essai-en-ligne.md` (latence, `InterpolationLion.RETARD`, TURN, mobiles, Safari iOS). | selon l'essai | |

## Points de vigilance transverses

- **`gh` et les deux dépôts** : toujours `--repo w3cdotorg/LeLion-web`. LeLion-multi est un fork de
  LeLion, et `gh` s'y est déjà trompé de dépôt ; ici, la remote `multi` pointe vers LeLion-multi.
- **Tests Godot** : toujours sous `timeout` (une erreur de script dans un test `--script` bloque le
  processus) ; un test `--script` est compilé avant les autoloads : il les récupère par
  `root.get_node(...)` et ne les nomme pas.
- **CI en anglais** : les tests qui lisent des textes imposent `TranslationServer.set_locale("fr")`.
- **Version et protocole** : toute hausse de `config/version` renote `PROTOCOLE_EMPREINTE`
  (`tests/unitaires.gd`).
- **Secrets** : aucun secret dans le dépôt public ; la clé TURN et les jetons ne vivent que dans les
  secrets du Worker et de GitHub, créés par l'utilisateur.
- **Réglages de LeLion-multi 19 bis** : s'ils sont faits là-bas après l'essai LAN, les reporter ici
  par `git cherry-pick` depuis la remote `multi` (règles de jeu communes).

### Notes de la revue de la phase 2 (pour les phases 4 et 5)

**Phase 4** (`TransportWebRTC`, client Godot de la signalisation) :

- Envoyer en texte seulement (`send_text`) : `put_packet` est binaire par défaut, la salle ignore les
  trames binaires sans rien dire et un ping binaire n'a jamais son pong. Le ping est le texte exact
  `{"t":"ping"}`.
- Cadencer les envois de l'hôte (file, 15 par seconde au plus) : six arrivées simultanées font environ
  70 messages, soit environ 5 s, sur les 15 s du client. Cadencer aussi les clients. Pas de
  regroupement des candidats : la v1 n'accepte que les champs exacts d'un `candidat` (il faudrait un
  nouveau type).
- Identifiants : `int()` (le JSON de Godot donne des flottants). Le client apprend son id par
  `bienvenue.id` ; l'hôte est 1.
- Après `bienvenue`, le client ne ferme pas sa socket : il attend la fermeture 1000 `ouvert` de la
  salle. L'hôte ignore un `depart` d'un pair déjà connecté.
- Lire tous les paquets en attente même à l'état CLOSING ou CLOSED ; la raison de fermeture vaut la
  raison de l'`erreur` (repli).
- La fermeture de la socket de signalisation de l'hôte (`expiree`, son propre `debit`, coupure
  réseau) n'arrête pas la partie : seules les arrivées cessent.
- Pages de test sur `localhost`, pas `127.0.0.1` ; une IP du réseau local exige `.dev.vars`
  (`ORIGINES`, déjà ignoré par git).
- Un `WebSocketPeer` natif n'envoie pas d'`Origin` : `handshake_headers` si besoin (l'export Web
  l'envoie toujours).
- Contrat de `Transport.pair()` à revoir (phase 1) : SceneMultiplayer refuse un
  `WebRTCMultiplayerPeer` avant `create_client`, dont l'id vient de la signalisation.

**Phase 5** (déploiement) :

- Secrets par `wrangler secret put` (`TURN_KEY_ID`, `TURN_KEY_API_TOKEN`).
- Identifiants de namespace ratelimit 1001 et 1002 uniques sur le compte ; vérifier que le binding est
  accepté sur l'offre gratuite (sinon compteur en Durable Object).
- Ne jamais redescendre la date de compatibilité sous 2026-04-07 (auto-réponse à la fermeture,
  `deleteAll` qui supprime l'alarme). Migration `v1` figée.
- Retirer `localhost` des `ORIGINES` de production.
- Les identifiants TURN vont à quiconque ouvre `/v1/creer` (l'`Origin` se falsifie) : 2 h de relais
  par identifiant ; plafonner la dépense ou poser des alertes si une carte est exigée.
- Workers Logs : un événement par invocation du Durable Object, sur 200 000 par jour.
- Le job CI du Worker n'a pas encore tourné sur GitHub avant le push de la phase 2.

### Notes de la revue de la phase 3 (pour les phases 3 bis, 4 et 6)

**Phase 3 bis** (retrait de la découverte) :

- Décider si `adresses_hote` passe dans `TransportENet` (l'hôte ENet du desktop afficherait ses
  adresses locales, au lieu de `127.0.0.1:7777` qui ne vaut que pour lui) plutôt que d'être supprimé
  avec `Decouverte`.

**Phase 4** (`TransportWebRTC`) :

- Traiter `erreur delai` côté client (arrivée non ouverte en 30 s) et le `depart` qui suit côté hôte.
- Échec de création côté hôte avant `pret` (`erreur quota|debit|origine`, Worker injoignable) : le
  contrat actuel (`Transport.echec` « chez un client », `_sur_transport_echec` seulement si
  `_connexion_en_cours`) ne le route pas. Permettre `echec` chez l'hôte jusqu'à `pret`, et le router en
  `connexion_echouee` + `raison_echec` (§9 : « Trop de parties en ce moment »), docstrings à jour.
- `en_ligne()` (pair ≠ Offline) est faux pour un client WebRTC entre `rejoindre_partie` et `bienvenue`
  (pair posé tard) ; l'écran ne doit pas s'y fier pendant la connexion.
- Sur le Web, un code `ip:port` doit être refusé proprement (ERR_INVALID_PARAMETER, message de format).
- `EcranEnLigne.creer_partie` ouvre le salon dès que `heberger` rend OK : avec WebRTC, un état
  CRÉATION qui attend `pret` (le salon n'écoute pas `connexion_echouee`) ; émettre `salon_change` sur
  `pret` (le salon relit `code_partie` à chaque affichage).
- *Copier le lien* sous Safari/WebKit : Godot traite le clic hors du gestionnaire d'événement du
  navigateur, `writeText` peut être refusé faute de geste de l'utilisateur ; à tester sous WebKit
  (Playwright).

**Phase 6** (mobiles) :

- Le focus de l'accueil va à `bouton_creer`, caché sur mobile : passer par une aide qui choisit le
  premier contrôle visible.
- À 844×390, l'échelle est 0,35 : Rejoindre et Copier le lien font environ 22 à 25 px de haut (moins
  que les 44 px d'une cible tactile).
- Le clavier virtuel couvre le champ du code et le message.
- La rangée d'invitation du salon touche le bas de l'écran (zone sûre).
- Coller dans un champ Godot sur mobile est peu fiable : le lien d'invitation est le chemin principal.

### Notes de la revue de la phase 4 (pour les phases 5 à 7)

**Phase 5** :

- `lelion/signalisation/url` devient l'adresse `wss://` déployée ; `lelion/signalisation/url.pilote="ws://localhost:8787"`
  pour que l'e2e reste local (l'unitaire qui vérifie l'URL change).
- La CI vérifie que le pck publié ne contient ni `pilote` (`_custom_features`) ni une URL localhost ; un
  contrôle de bout en bout sur l'artefact publié : `window.lelionPilote === undefined`, aucun « PILOTE PRET ».
- Un échec synchrone de `connect_to_url` (URL mal formée, contenu mixte) affiche aujourd'hui « Impossible
  d'héberger/rejoindre (erreur N) » : sur le Web, le rapporter en « Service de connexion indisponible ».
- Trancher si les `ORIGINES` de production gardent `http://localhost:*`.
- Les limites de 5 créations et 30 arrivées par minute et par IP touchent les réseaux d'école (une seule IP
  pour tous).
- Pages ne publie que `export/web`, construit depuis une extraction propre.

**Phase 6** :

- Toute option changée dans le préréglage « Web » doit l'être dans « Web pilote » (l'unitaire de la phase 4
  le vérifie) ; `experimental_virtual_keyboard` pour taper le pseudo.
- Envisager un client e2e en viewport mobile.
- Un onglet caché arrête `_process` : battements et pings s'arrêtent avec lui.
- iOS n'est couvert que par l'essai réel (WebKit ne relie pas deux pages dans le conteneur).
- La CI montre qu'un appareil lent joue au ralenti, et qu'un hôte lent ralentit tout le monde.

**Phase 7** :

- L'étape d'exclusion dans l'e2e.
- « Garde cet onglet au premier plan » et « Tu as été déconnecté ».
- La formulation du §5 (« 1 seul envoi » contre maxPacketLifetime 100 ms).
- Élargir l'e2e : capter les exceptions JS (`pageerror`) en plus de la console, et refaire se croiser les lions (étourdissements, chocs) dans la manche à trois pages.

**Phase 6** (complément de la revue de la phase 4) :

- Sur un appareil lent, `_vider_file` n'envoie qu'un message par image quand une image dure plus de 50 ms (≈ 2 messages/s à 2 i/s) : plusieurs arrivées simultanées sur un hôte très lent peuvent dépasser `DELAI_CANAL` (15 s).
- Délai du test `@manche` : 180 s (Chromium bridé à 1,5 CPU : 150 s ; CI : 66 s) ; le relever à 300 s si un passage CI dépasse 120 s.

### Notes de la revue de la phase 6 (pour les phases 5 et 7)

**Phase 5** :

- Ne déployer que le préréglage « Web » (`PiloteWeb` est fermé par la fonctionnalité `pilote`, vérifié).
- Garder le modèle HTML par défaut, sans `viewport-fit=cover` (sinon revoir les marges : Retour est à 24 px du coin).
- Premier essai sur un vrai iPhone : WebRTC, son en `Stream`, pas de plein écran, défilement du clavier virtuel (spec §13).

**Phase 7** :

- La phase 6 ne change ni le protocole ni la surface d'attaque.
- Fiche de l'essai réel : plein écran Android au relâchement ; premier toucher sur le champ pseudo (clavier et plein écran en même temps) ; lisibilité des textes des Résultats (~10 px CSS) ; zone morte effective du joystick (0,5) ; appareil lent ; Retour à 24 px du coin ; contraste du libellé PRÊT/VOMIR (rose sur anneau rose) ; une tranche de la rangée du pseudo au bord haut quand le clavier est ouvert ; un hôte desktop tactile voit les flèches du salon ; le réglage Plein écran ne reflète pas le mode du téléphone ; position du joystick codée en dur dans le pilote.
- « Tu as été déconnecté » et « Garde cet onglet au premier plan ».
