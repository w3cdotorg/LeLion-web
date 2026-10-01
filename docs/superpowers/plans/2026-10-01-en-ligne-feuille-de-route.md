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
| 0 | **Dépôt et CI Web seule** : création de `w3cdotorg/LeLion-web` (public, sans lien de fork) avec l'utilisateur ; exports Windows, Linux, macOS et job Release retirés ; l'export Web publié en artefact ; README recentré. | ✏️ `.github/workflows/ci.yml` ✏️ `export_presets.cfg` ✏️ `README.md` ➖ `docs/essai-lan.md` | Dépôt en ligne, CI verte, artefact `LeLion-web`. |
| 1 | **Transport** : Step 0 sur `Reseau.gd` (977 lignes : code mort, journaux), puis interface `Transport` et `TransportENet` extrait de `Reseau.gd` (qui ne nomme plus aucune classe ENet) ; battement applicatif d'une seconde et silence de 10 s pour tous (30 s au chargement) à la place des délais d'ENet ; départ volontaire par message fiable. Version 0.20, `PROTOCOLE_EMPREINTE` renotée. | ➕ `Scripts/Transport.gd` ➕ `Scripts/TransportENet.gd` ✏️ `Scripts/Reseau.gd` ✏️ `tests/unitaires.gd` ✏️ `tests/reseau/joueur.gd` | Les 13 scénarios réseau verts, scénario 11 allongé (silence de 10 s). |
| 2 | **Signalisation** : Worker et Durable Object `Salle` (§4 et §8.1 du spec : messages, plafonds, origine, expiration, identifiants TURN, hibernation), tests `vitest` dans l'environnement local de Cloudflare ; job CI du Worker. Vérifier ici : limitation de débit sur l'offre gratuite. | ➕ `signalisation/package.json` ➕ `signalisation/wrangler.jsonc` ➕ `signalisation/src/index.js` ➕ `signalisation/test/salle.test.js` ✏️ `.github/workflows/ci.yml` | `npm test` vert en local et en CI, sans compte Cloudflare. |
| 3 | **Écran En ligne** : remplace l'écran Réseau (pseudo, *Créer une partie*, *Rejoindre* avec un code) ; code de salle (alphabet, format `K7Q-2XM`, validation), lecture de `?salle=` ; le salon affiche le code et *Copier le lien*. Sur desktop (dev), le code est `ip:port` pour `TransportENet`. ◉ | ➕ `Scripts/CodeSalle.gd` ➕ `Scenes/EcranEnLigne.tscn` ➕ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `Assets/Traductions/traductions.csv` | Parcours Titre → En ligne → Salon en ENet ; unitaires du code de salle. |
| 3 bis | **Retrait de la découverte** : `Decouverte.gd`, son autoload, l'écran Réseau, les scénarios de découverte et `DIFFUSION=1` ; tests adaptés à l'écran En ligne. | ➖ `Scripts/Decouverte.gd` ➖ `Scenes/EcranReseau.tscn` ✏️ `project.godot` ✏️ tests (`smoke_test`, `screenshots`, `deux_fenetres`, `unitaires`, `reseau/`) | Plus aucune référence à `Decouverte` ; captures à jour (compte de la CI ajusté). |
| 4 | **WebRTC** : `TransportWebRTC` (signalisation en `WebSocketPeer`, `WebRTCMultiplayerPeer` en étoile, canaux §5, délai de 15 s, `?relais=1`) ; test de bout en bout Playwright (Chromium et Firefox, 3 pages, Worker en `wrangler dev`) en CI. | ➕ `Scripts/TransportWebRTC.gd` ✏️ `Scripts/Reseau.gd` (choix du transport) ➕ `tests/web/bout_en_bout.spec.js` ➕ `tests/web/playwright.config.js` ✏️ `.github/workflows/ci.yml` | Une manche de 10 s à 3 pages, même empreinte, départ de l'hôte vu. |
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
