# LeLion web

[Original inspiration: Laetitia Perez](https://www.instagram.com/p/Dc3SacQDsyM/?igsi=M21jMzRiMmxqdTZl)

A lion has to paint the town by puking a rainbow, while dodging enemies.
An absurd, deliciously colorful game made with [Godot 4](https://godotengine.org).

This copy of [LeLion-multi](https://github.com/w3cdotorg/LeLion-multi) (itself a fork of
[LeLion](https://github.com/w3cdotorg/LeLion)) turns the **paint battle for 2 to 6 players** into an
**online game that runs in the browser**: friends at home open a link and play, no install (WebRTC
between browsers, see the [design spec](docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md),
in French).

**Play at <https://w3cdotorg.github.io/LeLion-web/>.** One player, on a computer, opens
**Multiplayer**, picks a name and **Create a game**, then sends the link (**Copy link**); the others
(computers or phones) open it, pick a name and **Join**. How to host, invite and join, and what each
message means: [Jouer en ligne](#jouer-en-ligne), in French. The same page plays the solo game below,
unchanged; the original plays at <https://w3cdotorg.github.io/LeLion/>.

A Game Boy Advance port, rewritten in C, lives at [w3cdotorg/lelion-gba](https://github.com/w3cdotorg/lelion-gba).

![Gameplay screenshot](docs/capture.png)

![The giant painter in the Village level](docs/boss.png)

## How to play

Grab the color dots to enrich your spew, then hold the puke button while flying over the town.
You win once enough of the skyline is really covered in paint: 85% on Easy, 90% on Normal,
95% on Hardcore. A yellow tick on the progress bar marks the finish line. Enemies hurt: a saucer or a ladybug costs you a
heart, and they show up faster and faster as the town gets colored.

On the title screen, pick a difficulty: **Easy** (3 hearts, extra hearts respawn, paint 85%),
**Normal** (3 hearts, no extras, paint 90%) or **Hardcore** (one hit and it's over, paint 95%). After a hit, the lion blinks and
stays invulnerable for a second and a half. Pick one of three levels (Skyline, Metropolis,
Village), each showing your best time for the chosen difficulty, then press **Play**. In the Village, a
giant painter joins in: he announces himself on one side of the screen, moves to the center,
pauses, backs out, then comes back from the other side. Paint the half he leaves free, cross
over when he retreats.

A rainbow star appears from time to time: grab it to double the width of your spew for eight
seconds.

**Arcade** (top-left button) chains the nine stages: the three levels on Easy, then Normal,
then Hardcore, with a cumulated time and its own best time. Every stage opens on a
"READY? VOMIT!" intro, and a defeat brings up an arcade-style "CONTINUE?" countdown: press
the puke button to retry, or let it run out to see the summary.

Leave the title screen alone for fifteen seconds and the game plays itself (attract mode);
any key or tap brings the title back. The chiptune soundtrack is layered: the arpeggios join
in at a third of the way to victory, the melody at two thirds, and the Village level has its own
minor-key theme for the painter.

| Action | Keyboard | Gamepad | Touch screen |
|---|---|---|---|
| Move | Arrows, WASD / ZQSD | Left stick, D-pad | Virtual stick: put your thumb on the left half |
| Puke | Space, Enter | A | PUKE button, bottom right |
| Pause (Resume / Settings / Back to menu) | Esc, P | Start | II button, top right |

Touch controls appear on phones and on other touch screens. The **Settings** screen (title
screen or pause menu) has music and sound-effect volumes, fullscreen, an optional CRT filter
(scanlines, curvature, color bleed) and the language (French or English; the default follows
your system). Difficulty, last level, settings and best
times are all saved between sessions: on the web build they live in the browser's IndexedDB,
so they survive closing the tab.

## Multiplayer: a paint battle

On the title screen, **Multiplayer** (bottom right) opens the network screen: pick a name (up to 12
characters), then **Host a game**, pick a game in the list of games on the network, or type the
host's IP address. In the lobby, each player picks a color (Left/Right) and gets ready (Space); the
host picks the level (Up/Down) and starts (Tab, Start) once at least two players are there, all
ready.

A round lasts 90 seconds, on a 16:9 screen. Every lion pukes in its own color, in three shades, and
the town is split into 8-pixel cells: paint a cell enough and it is yours, paint over someone else's
and you steal it. The most cells at the gong wins (ties are possible). Puking on another lion stuns
it for 1.5 s (then 1 s of immunity); saucers, ladybugs and the painter stun for 2.5 s, then leave
3 s to flee. Color dots add a notch to your spew (1 to 7: a wider brush), the rainbow star doubles
it for eight seconds; there are no hearts. Lions bump into each other like bumper cars. The HUD
shows each player's share of the painted cells, rank and notches; the last ten seconds tick in red.

After the gong, every PC shows the same **Results** screen: the ranking, each player's share, stuns
dealt, cells stolen and bumps, and three titles (the nastiest, the thief, the bumper car). The host
picks **Rematch**, **Next level** or **Back to lobby** for everyone; anyone can quit, and the host
quitting ends the game for everyone (it asks first). Each player uses their own PC's keyboard or
gamepad, with the solo controls; Esc opens a local menu that does not pause the round.

Online play runs in the browser (WebRTC, the host's browser being authoritative): **Create a game**
gives a room code (`K7Q-2XM`) and **Copy link**; the others open the link, pick a name and join. The
published page talks to the signalling Worker (`signalisation/`) deployed at
`wss://lelion-web.w3cdotorg.workers.dev` (the `lelion/signalisation/url` project setting), which only
admits that page. Locally, after `npm ci` in `signalisation/` (and in `tests/web/` for the end-to-end
test below), `npm --prefix signalisation run dev` serves it on `ws://localhost:8787`, admitting
`http://localhost:*`; only the "Web pilote" export talks to it (the setting's `.pilote` variant), served
from `http://localhost:<port>` (not `127.0.0.1`).
Phones (Android, iOS) join only, by the link: no **Create a game**; lifting a finger asks for full
screen, until it is granted (three tries at most; a computer has a **Full screen** button in the lobby).
In the lobby, the arrows pick a color and **READY** gets ready; in the round, the stick and **PUKE**; the
Results screen and the online pause menu have finger-sized buttons. Held upright, a phone shows « Turn
your phone sideways » over the game, which keeps running. The host can remove a player from the lobby (the
cross on their card). How to host, invite and join, what to keep in mind (the host's tab, privacy) and what
each message means: [Jouer en ligne](#jouer-en-ligne), below, in French.
From the editor (`godot .`), desktop builds play over ENet instead: **Multiplayer** opens the Online
screen, where one player creates a game and the others join it with the host's address as the code: the host's local IP
address, as their system shows it (network settings, `ipconfig` on Windows, `ip a` on Linux),
followed by `:7777` (`192.168.1.20:7777`). The host's lobby shows `127.0.0.1:7777`, which only works
on the host's own computer.
Ready-made Windows, macOS and Linux builds of the LAN version are on
[LeLion-multi's releases](https://github.com/w3cdotorg/LeLion-multi/releases/latest) (version 0.19).

## Jouer en ligne

Le jeu en ligne se joue dans le navigateur, sans rien installer, de 2 à 6 joueurs, chacun chez soi, sur
<https://w3cdotorg.github.io/LeLion-web/>. Tout le monde doit avoir la même version : recharge la page
avant de jouer (sinon : « Version différente de l'hôte », ci-dessous).

**Créer une partie** (sur un ordinateur : un téléphone ne fait que rejoindre) : *Multijoueur* sur l'écran
titre, choisis ton pseudo (12 caractères au plus), puis *Créer une partie*. Le salon s'ouvre avec le code
de la partie (`K7Q-2XM`) et *Copier le lien*.

**Inviter** : envoie le lien (`https://w3cdotorg.github.io/LeLion-web/?salle=K7Q2XM`) par message, ou
dicte le code. Il n'y a pas de liste des parties : seuls ceux qui ont le lien ou le code peuvent venir.

**Rejoindre** : ouvre le lien ; l'écran *En ligne* s'ouvre, le code déjà rempli ; choisis ton pseudo, puis
*Rejoindre*. Sans le lien, *Multijoueur*, puis tape le code (sans 0, O, 1, I ni L) et *Rejoindre*.

**Au salon**, chacun choisit sa couleur (Gauche/Droite) et se dit prêt (Espace) ; l'hôte choisit le
niveau (Haut/Bas) et lance la partie (*Démarrer la partie*, Tab) quand tout le monde est prêt. L'hôte peut
exclure un joueur : la croix sur sa carte (à la souris). L'exclu lit « L'hôte t'a exclu de la partie. ».
Sans compte, rien ne l'empêche de revenir avec le code : l'hôte l'exclut de nouveau, ou crée une nouvelle
partie (un nouveau code) et n'envoie le lien qu'aux bons joueurs.

**Hôte : garde l'onglet du jeu au premier plan.** Le navigateur fige un onglet caché ou une fenêtre
réduite : le jeu de tout le monde s'arrête avec lui, et 10 s plus tard les autres voient « L'hôte a quitté
la partie ». Le salon de l'hôte le rappelle en haut de l'écran.

**Joueurs** : un onglet caché ou un téléphone verrouillé plus de 10 s, et l'hôte te déclare parti (ton lion
disparaît, tes cellules restent) ; à ton retour, « Tu as été déconnecté », puis l'écran *En ligne* : rouvre
le lien pour revenir au salon (pas en pleine manche : on attend la suivante au salon).

**Sur un téléphone** (Android, iPhone) : tiens-le à l'horizontale (en portrait, « Tourne ton téléphone »
couvre le jeu, qui continue) ; le plein écran se demande au premier doigt levé ; au salon, les flèches
choisissent ta couleur et **PRÊT** te dit prêt ; en manche, le stick (pose le pouce sur la moitié gauche) et
**VOMIR**. Coller un code dans un champ marche mal sur un téléphone : ouvre plutôt le lien.

**Vie privée** : aucun compte, aucun serveur de jeu ; seuls ton pseudo, tes réglages et tes meilleurs
temps (en solo) sont gardés, dans ton navigateur. GitHub Pages, qui sert la page, voit ton adresse IP quand
elle se charge. Le service de connexion (un Worker, chez Cloudflare) voit l'adresse IP de chaque joueur le
temps d'entrer dans la partie, et celle de l'hôte toute la vie de la salle (sa connexion au service reste
ouverte pour les arrivées, 4 h au plus) : il s'en sert pour limiter les créations et les arrivées par
minute, sans l'écrire dans ses journaux : ils ne gardent que les lignes du Worker (jamais d'IP), les
journaux d'invocation de Cloudflare (qui décrivent chaque requête) et les traces sont coupés
(`signalisation/wrangler.jsonc`). Les serveurs STUN (de Cloudflare et de Google), qui disent à chaque
navigateur son adresse publique, la voient aussi. Ensuite les navigateurs se parlent directement
(WebRTC) : l'hôte et chaque joueur voient l'adresse IP l'un de l'autre. Il n'y a pas de relais (TURN)
pour l'instant : aucun serveur ne voit passer la partie, mais deux réseaux trop fermés ne se relient pas
(voir « Connexion impossible avec l'hôte » ci-dessous). Le pseudo des autres ne s'affiche que comme du
texte : ni mise en forme, ni caractères invisibles.

**Dépannage**, message par message :

| Message | Ce qui se passe | Que faire |
|---|---|---|
| « Un code fait 6 caractères (ex. K7Q-2XM). » | Le code tapé n'a pas 6 caractères de l'alphabet du jeu. | Recopie-le, ou ouvre le lien. |
| « Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM). » | Un caractère qu'on confond s'est glissé dans le code. | Relis-le : ce sont sans doute un Q, un D, un 7 ou un 2. |
| « Aucune partie avec ce code. » | La partie n'existe pas, ou plus (l'hôte est parti, la salle a fermé). | Demande un nouveau lien à l'hôte. |
| « Service de connexion indisponible, réessaie dans un instant. » | Le service de connexion ne répond pas, ou refuse pour un moment (trop de tentatives depuis la même adresse IP). | Réessaie dans une minute. |
| « Trop de parties en ce moment, réessaie plus tard. » | Le quota gratuit du service de connexion est atteint pour aujourd'hui. | Réessaie plus tard (le lendemain au pire). |
| « Connexion impossible avec l'hôte (réseau trop restrictif ?) » | Les deux navigateurs n'ont pas pu se relier en 15 s : sans relais (TURN, pas encore en service), deux réseaux trop fermés ne se relient pas. | Réessaie ; sinon change de réseau (la 4G plutôt qu'un Wi-Fi d'entreprise ou d'école, ou l'inverse). Le paramètre `?relais=1` n'a pas encore de relais à imposer : il empêche toute connexion. |
| « Version différente de l'hôte (…) » | L'hôte et toi n'avez pas la même version du jeu. | Recharge la page (l'un des deux a une ancienne version en cache). |
| « Réponse incomprise : est-ce bien une partie de LeLion ? » | La réponse reçue n'est pas celle d'une partie de LeLion (un autre programme, ou une version trop différente pour se comprendre). | Vérifie le code ou le lien ; sinon, l'hôte et toi, rechargez la page. |
| « La partie est complète. » | Six joueurs au plus. | Attends qu'une place se libère. |
| « Une manche est en cours : réessaie à la fin. » | On n'arrive pas en pleine manche. | Rejoins quand l'hôte revient au salon. |
| « L'hôte t'a exclu de la partie. » | L'hôte t'a retiré du salon. | Vois avec lui. |
| « Exclu : ta partie a mis trop de temps à charger. » | Ta manche n'a pas fini de charger à temps (20 s) : la partie est partie sans toi. | Rejoins au salon suivant ; ferme les autres onglets sur un appareil lent. |
| « L'hôte a quitté la partie » | L'hôte est parti, ou son onglet est caché depuis 10 s. | Attends son nouveau lien. |
| « Tu as été déconnecté » | Ton onglet était caché (ou ton téléphone verrouillé) plus de 10 s : l'hôte t'a déclaré parti. | Rouvre le lien. |
| « Salle expirée : crée une nouvelle partie pour inviter » (hôte) | Une salle vit 4 h : la partie continue, mais plus personne ne peut arriver. | Crée une nouvelle partie pour inviter. |
| « Invitations coupées : crée une nouvelle partie pour inviter » (hôte) | Le lien avec le service de connexion s'est coupé : la partie continue, sans nouvelles arrivées. | Crée une nouvelle partie pour inviter. |

Pour l'essai réel, à plusieurs foyers et sur téléphone : [docs/essai-en-ligne.md](docs/essai-en-ligne.md).

## Running the game

Open the folder in Godot 4.7 or newer and run the main scene, or from the command line:

```sh
godot .
```

## Project layout

```
Scenes/     Titre (title), Main (a game), Intro (READY? VOMIT!), Lion, Ville (town), HUD, HUDBataille (battle HUD),
            Resultats (battle results), EcranEnLigne (online screen), Salon (lobby), PauseMenu, Reglages (settings),
            ControlesTactiles (touch controls), GameOver (CONTINUE? + summary), ColorPickup, BonusPickup,
            CoeurPickup, Soucoupe, Coccinelle, Boss
Scripts/    one script per scene; the autoloads GameState (game, players, levels, difficulties, arcade), Scores
            (records, preferences), Parametres (settings, CRT layer), Audio (sounds, layered music) and Reseau
            (handshake, lobby table, heartbeat); Transport, TransportENet and TransportWebRTC (the network
            channels: ENet on the desktop, WebRTC in the browser); CodeSalle (room codes, invitation link); Manche
            (a networked round); PiloteWeb (the end-to-end test driver, inert outside the "Web pilote" export);
            pure logic: Joueur (a player), Commandes (inputs), Regles / ReglesSolo / ReglesBataille (rules of each
            mode), Territoire (cell ownership), Peinture (deterministic stamps), EtatLion, InterpolationLion and
            PredictionLocale (lions over the network), BilanManche (end of a round), PlacementPseudos, LimiteDebit
            (the host's rate limit on each client); the lion's
            parts DeplacementLion, PareChocs, GerbeLion; Pilote (attract-mode autopilot)
Shaders/    Ville.gdshader (paint mask on the skyline), Lion.gdshader (mane tint), Crt.gdshader (optional CRT filter)
Assets/     Sprites (used), Sons (generated), Traductions (CSV → .translation), src (reference material, ignored by Godot)
tests/      unitaires, smoke_test, bataille_test, prediction_test, trace_lions (headless), reseau/ (multi-process
            network test, latency relay), screenshots and deux_fenetres (captures), web/ (end-to-end WebRTC test,
            Playwright)
tools/      generer_sons.py (effects), generer_musique.py (layered chiptune, town + boss themes), generer_skylines.py (skylines, sprites)
docs/       screenshots, the design specs (LAN, then online) and the phase plans (superpowers/)
```

The paint is an RGBA mask the size of the skyline, stamped through a native blit wherever the
spew touches the town. Progress is counted on an 8 px cell grid that only covers the opaque
parts of the skyline. A level is just a silhouette PNG: add an entry to `GameState.NIVEAUX` to
create one, with `"boss": true` to invite the painter. His collision is generated from the alpha
of his SVG sprite, so replacing `Assets/Sprites/boss_peintre.svg` is enough to change his shape.

Code identifiers and comments are in French; player-facing text goes through Godot's
translation system, with both languages in `Assets/Traductions/traductions.csv`.

## Tests

Headless suites (the CI runs all but the last one); each ends on `== 0 échec(s) ==` when green
(test messages are in French):

```sh
godot --headless --script tests/unitaires.gd                       # pure logic: territory, rules, lobby table, protocol guard…
godot --headless --script tests/smoke_test.gd                      # solo game, title, online screen, lobby, a networked round
godot --headless --fixed-fps 60 --script tests/bataille_test.gd    # a 4-lion local battle, the Results screen, rematch
godot --headless --fixed-fps 60 --script tests/prediction_test.gd  # client-side prediction under simulated latency
bash tests/reseau/lancer.sh                                        # headless Godot processes on localhost (ENet)
godot --headless --fixed-fps 60 --script tests/trace_lions.gd      # the lions' fingerprint, for refactors
```

The network test needs GNU `timeout` (coreutils) and takes about three minutes; run one suite at
a time (they share local ports).

The end-to-end test plays a real online round in three browser pages (Chromium and Firefox: the host removes a
player, who comes back with the code, and the lions bump into each other; WebKit checks **Copy link**; an
emulated Android phone, in Chromium, joins a desktop host, plays by touch, then freezes for 12 s and is told
it was disconnected),
on the "Web pilote" export and a local Worker that it starts itself (`python3` serves the export on
port 8060, `wrangler dev` listens on 8787):

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

The published export has its own checks: its settings (no `pilote` feature, the deployed Worker's
address), then the page in Chromium with a simulated signalling server (no driver, the Worker of
`project.godot`, the unreliable channels' lifetime); and, once deployed, a game between two pages driven
by the keyboard on the published page:

```sh
godot --headless --export-release Web export/web/index.html
godot --headless --script tests/export_publie.gd -- --pck=export/web/index.pck
cd tests/web && npx playwright test -c playwright.publie.config.js
npx playwright test -c playwright.en_direct.config.js   # LELION_PAGE=<url> for another page than GitHub Pages
```

Screenshots, with a real renderer (windows open while the scripts run):

```sh
godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=/output/path [--parties=solo,reseau,salon,bataille,resultats,mobile]
godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=/output/path
godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier=/output/path
godot --path . --rendering-driver opengl3 --fixed-fps 60 --script tests/bataille_test.gd -- --captures=/output/path
```

`deux_fenetres.gd` is one host and one client in two real windows (start both, in any order).
Without a renderer (`--headless`), the two capture scripts go through their whole scenario without
writing anything: that is how the CI keeps them working.

Sounds are regenerated with `python3 tools/generer_sons.py`, the music with
`python3 tools/generer_musique.py`, skylines and sprites with `python3 tools/generer_skylines.py`.

## Export and CI

`export_presets.cfg` defines the Web preset (single-threaded, so it needs no cross-origin isolation
headers), and "Web pilote", the same plus the `pilote` feature for the end-to-end test (never
published). With the export templates installed:

```sh
godot --headless --export-release Web export/web/index.html
```

The workflow in `.github/workflows/ci.yml` runs on every pull request and every push to `main`: it
installs Godot 4.7.2 and its export templates, runs the unit tests, the smoke test, the local
battle test, the prediction bench, the network test and the two capture scripts without a
renderer, then exports the Web build and publishes it as the `LeLion-web` artifact (kept 30 days).
A second job tests the signalling Worker; a third exports "Web pilote" and runs the end-to-end test.
The first job also guards the Web export (`tests/export_publie.gd`: no `pilote` feature, the deployed
Worker's address, nothing but the page's files), and the third checks it in Chromium
(`tests/web/playwright.publie.config.js`: no driver, the deployed Worker's address, the unreliable
channels' 100 ms lifetime).

Nothing goes online from a pull request or a push to `main`. A tag `vX.Y`, equal to
`application/config/version`, runs the same jobs and then, if they all pass, deploys the Worker
(`wrangler deploy`, then `signalisation/outils/sonder.mjs`: a room from the published page's origin,
STUN only, `localhost` refused) and the page (the `LeLion-web` artifact of that run, checked against the
deployed Worker, then GitHub Pages, then a game between two Chromium pages on the published page,
`tests/web/playwright.en_direct.config.js`). It needs the repository secrets `CLOUDFLARE_API_TOKEN`
(template "Edit Cloudflare Workers") and `CLOUDFLARE_ACCOUNT_ID`, and the `github-pages` environment
allowing `v*` tags. No TURN secret: the Worker hands out STUN servers only.

```sh
git tag v0.21 && git push origin v0.21   # deploy version 0.21 (after merging the version bump on main)
```

To go back to an earlier version, re-run that tag's workflow (`gh run rerun <run id>`); the Worker
alone can also be rolled back from Cloudflare's dashboard (Deployments) or with `npx wrangler rollback`.
