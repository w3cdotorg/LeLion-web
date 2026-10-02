# LeLion web

[Original inspiration: Laetitia Perez](https://www.instagram.com/p/Dc3SacQDsyM/?igsi=M21jMzRiMmxqdTZl)

A lion has to paint the town by puking a rainbow, while dodging enemies.
An absurd, deliciously colorful game made with [Godot 4](https://godotengine.org).

This copy of [LeLion-multi](https://github.com/w3cdotorg/LeLion-multi) (itself a fork of
[LeLion](https://github.com/w3cdotorg/LeLion)) is turning the **paint battle for 2 to 6 players**
into an **online game that runs in the browser**: friends at home open a link and play, no install
(WebRTC between browsers, see the
[design spec](docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md), in French). Work in
progress: for now the battle still runs on a local network, from the Godot editor (see
[Multiplayer](#multiplayer-a-paint-battle)). The solo game below is unchanged; the original plays in
a browser at <https://w3cdotorg.github.io/LeLion/>.

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

Touch controls only appear on devices with a touch screen. The **Settings** screen (title
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
gives a room code (`K7Q-2XM`) and **Copy link**; the others open the link, pick a name and join. It
needs the signalling Worker (`signalisation/`, deployed with the page in a later phase); locally,
`npm --prefix signalisation run dev` serves it on `ws://localhost:8787` (the `lelion/signalisation/url`
project setting), and the Web export must be served from `http://localhost:<port>` (not `127.0.0.1`).
From the editor (`godot .`), desktop builds play over ENet instead: **Multiplayer** opens the Online
screen, where one player creates a game and the others join it with the host's address as the code: the host's local IP
address, as their system shows it (network settings, `ipconfig` on Windows, `ip a` on Linux),
followed by `:7777` (`192.168.1.20:7777`). The host's lobby shows `127.0.0.1:7777`, which only works
on the host's own computer.
Ready-made Windows, macOS and Linux builds of the LAN version are on
[LeLion-multi's releases](https://github.com/w3cdotorg/LeLion-multi/releases/latest) (version 0.19).

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
            PredictionLocale (lions over the network), BilanManche (end of a round), PlacementPseudos; the lion's
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

```sh
godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=/output/path [--parties=solo,reseau,salon,bataille,resultats]
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
Deployment to GitHub Pages comes with the Worker's (a later phase).
