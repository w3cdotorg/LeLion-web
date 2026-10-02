# Phase 5 : déploiement

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le jeu en ligne est publié : un tag `v0.21` déploie le Worker de signalisation (`wrangler deploy`, nom `lelion-web`, à `https://lelion-web.w3cdotorg.workers.dev`, à la place du Worker « Hello world » qui y répond) puis la page (`https://w3cdotorg.github.io/LeLion-web/`, GitHub Pages), en STUN seul (aucun TURN, décision de l'utilisateur). La page publiée parle au Worker déployé (`wss://lelion-web.w3cdotorg.workers.dev`, réglage `lelion/signalisation/url`), le test de bout en bout reste local (`lelion/signalisation/url.pilote="ws://localhost:8787"`). La production n'admet que l'origine de la page publiée ; ses journaux n'écrivent jamais l'IP. Rien ne se déploie depuis une PR ni un push sur `main` ; un tag ne déploie qu'après tous les tests de son commit, puis vérifie à chaque étape ce qu'il a mis en ligne (la sonde du Worker, l'export publié face au Worker déployé, une partie de deux pages sur la page publiée). Sortie : **première partie en ligne sur `https://w3cdotorg.github.io/LeLion-web/`** (feuille de route, ligne 5), puis l'essai réel (`docs/essai-en-ligne.md`).

**Architecture:**
- **Partie A, le code** (sans compte, branche `phase-05-deploiement`, une PR) :
  - **Worker** (`signalisation/`) : `wrangler.jsonc` de production (nom `lelion-web`, `workers_dev`, sans adresses de préversion, `ORIGINES` = la page publiée seule, journaux d'invocation et traces coupés, migration `v1` et date de compatibilité inchangées) ; `npm run dev` ajoute `http://localhost:*` par `--var` ; `admis` tolère un binding de limite absent (le repli si l'offre gratuite refusait `ratelimits`) ; `outils/sonder.mjs`, la sonde du Worker déployé (une salle depuis l'origine de la page, STUN seul ; `localhost` refusé).
  - **Jeu** : `project.godot` porte l'adresse du Worker déployé et sa variante `.pilote` ; `TransportWebRTC.url_signalisation` la lit avec ses variantes (`get_setting_with_override` : `get_setting` les ignore, mesuré) ; une signalisation qui ne s'ouvre même pas (`_ouvrir_signalisation` : aucune adresse, `connect_to_url` qui refuse d'emblée, comme le contenu mixte) rend `ERR_CANT_CONNECT`, que `EcranEnLigne` dit « Service de connexion indisponible ».
  - **Gardes de l'export publié** : `tests/export_publie.gd` (les réglages écrits dans le paquet : pas de `pilote`, l'adresse du Worker en `wss://`, aucune adresse locale hors des variantes `.pilote`, la version) ; `tests/web/export_publie.spec.js` (Chromium, signalisation simulée : pas de `window.lelionPilote` ni « PILOTE PRET », la page appelle le Worker de `project.godot`, un refus s'y lit au journal ; chaque canal non fiable a 100 ms) ; `tests/web/en_direct.spec.js` (sur la page publiée : deux pages menées au clavier, une salle, une arrivée, le canal WebRTC ouvert, STUN seul).
  - **CI** (`ci.yml`) : sur un tag `v*`, après les trois jobs de test, `deploiement-worker` (tag = version, `wrangler deploy`, la sonde) puis `deploiement-page` (l'artefact `LeLion-web` de ce passage, contrôlé face au Worker déployé, `upload-pages-artifact`, `deploy-pages`, le paquet servi, la partie de deux pages) ; sur toute PR, l'export Web gardé et contrôlé.
  - **Documentation** : README (l'adresse du jeu, comment jouer, la vie privée telle qu'elle est, le déploiement et le retour en arrière), `docs/essai-en-ligne.md` (sans TURN ; le contrôle à la main des canaux sur la page publiée), la spec telle que construite (§2, §8.1, §10, §11, §13).
- **Partie B, la mise en ligne** (le contrôleur, avec l'utilisateur, une fois la PR fusionnée) : l'environnement `github-pages` ouvert aux tags `v*`, le tag `v0.21`, le passage suivi, le Worker et la page vérifiés depuis ce poste, une partie de contrôle, l'essai réel ; le retour en arrière.

**Tech Stack:** Godot 4.7.2 (GDScript typé, `WebSocketPeer`, `WebRTCMultiplayerPeer`, `ProjectSettings.get_setting_with_override`, `load_resource_pack`), export Web single-thread (templates `web_nothreads_*` 4.7.2), Cloudflare Workers et Durable Objects (wrangler 4.146.0, `@cloudflare/vitest-plugin` 1.3.5, vitest 4.1.11), Node 24.21.0 (WebSocket d'undici, option `headers`), Playwright 1.63.0 (`routeWebSocket`, image `mcr.microsoft.com/playwright:v1.63.0-noble`), GitHub Actions (`actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`, `actions/download-artifact@v4`), actionlint.

**Spec:** `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§2, §8.1, §9, §10, §11, §13) · feuille de route `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 5 ; parties **Phase 5** des « Notes de la revue » des phases 2, 4, 6 et 7 ; « Vérification commune » ; « Points de vigilance ») · prérequis : phases 0 à 4, 6 et 7 fusionnées (`main` à `ce22ce6`, PR #8) ; branche `phase-05-deploiement` depuis `main`. Faits de l'utilisateur (02/10/2026, vérifiés par le contrôleur) : sous-domaine `w3cdotorg.workers.dev`, un Worker « Hello world » nommé `lelion-web` y répond (créé dans le tableau de bord, sans Durable Object) ; secrets du dépôt `CLOUDFLARE_API_TOKEN` et `CLOUDFLARE_ACCOUNT_ID` posés ; Pages activé (`build_type=workflow`) ; pas de TURN.

## Global Constraints

- Spec §11, mot pour mot : « **CI sur `main`** : tests Godot, tests du Worker, export Web, test Playwright ; l'export en artefact. Rien n'est mis en ligne. » ; « **Tag `vX.Y`** (= `application/config/version`) : déploiement du Worker (`wrangler deploy`), puis de la page sur GitHub Pages (`actions/deploy-pages`). L'URL du Worker est écrite dans l'export (réglage de projet `lelion/signalisation/url`). » Spec §8.1 : « Ne jamais redescendre la date de compatibilité sous 2026-04-07 » (feuille de route) ; « Migration `v1` figée. » ; table du §9 : « Worker injoignable (5 s) | « Service de connexion indisponible, réessaie dans un instant. » ».
- Notes de la revue (feuille de route), parties **Phase 5**, mot pour mot : « Secrets par `wrangler secret put` (`TURN_KEY_ID`, `TURN_KEY_API_TOKEN`). » (sans objet : pas de TURN, décision de l'utilisateur ; documenté pour plus tard, spec §13) ; « Identifiants de namespace ratelimit 1001 et 1002 uniques sur le compte ; vérifier que le binding est accepté sur l'offre gratuite (sinon compteur en Durable Object). » ; « Ne jamais redescendre la date de compatibilité sous 2026-04-07 (auto-réponse à la fermeture, `deleteAll` qui supprime l'alarme). Migration `v1` figée. » ; « Retirer `localhost` des `ORIGINES` de production. » ; « Workers Logs : un événement par invocation du Durable Object, sur 200 000 par jour. » ; « `lelion/signalisation/url` devient l'adresse `wss://` déployée ; `lelion/signalisation/url.pilote="ws://localhost:8787"` pour que l'e2e reste local (l'unitaire qui vérifie l'URL change). » ; « La CI vérifie que le pck publié ne contient ni `pilote` (`_custom_features`) ni une URL localhost ; un contrôle de bout en bout sur l'artefact publié : `window.lelionPilote === undefined`, aucun « PILOTE PRET ». » ; « Un échec synchrone de `connect_to_url` (URL mal formée, contenu mixte) affiche aujourd'hui « Impossible d'héberger/rejoindre (erreur N) » : sur le Web, le rapporter en « Service de connexion indisponible ». » ; « Trancher si les `ORIGINES` de production gardent `http://localhost:*`. » ; « Les limites de 5 créations et 30 arrivées par minute et par IP touchent les réseaux d'école (une seule IP pour tous). » ; « Pages ne publie que `export/web`, construit depuis une extraction propre. » ; « Ne déployer que le préréglage « Web » (`PiloteWeb` est fermé par la fonctionnalité `pilote`, vérifié). » ; « Garder le modèle HTML par défaut, sans `viewport-fit=cover` (sinon revoir les marges : Retour est à 24 px du coin). » ; « Premier essai sur un vrai iPhone : WebRTC, son en `Stream`, pas de plein écran, défilement du clavier virtuel (spec §13). » ; « Déployer depuis le tag v0.21. » ; « Vérifier si les journaux d'invocation de Workers Logs enregistrent l'IP du client ; les couper, ou garder le README en accord. » ; « Mettre à jour l'URL et le paragraphe de vie privée du README. » ; « Le correctif des canaux part aussi dans le préréglage « Web » ordinaire (il n'est pas derrière le pilote) : vérifier à la main la durée de vie d'un canal sur la page déployée. »
- Décisions de l'utilisateur (contraignantes) : **pas de TURN** (STUN Google et Cloudflare seuls ; le Worker sert déjà du STUN seul sans `TURN_KEY_ID`/`TURN_KEY_API_TOKEN` : rien n'exige ces secrets) ; le compte, le sous-domaine, le jeton et les secrets sont à l'utilisateur ; déploiement sur le tag `vX.Y` = `application/config/version` (0.21), le Worker d'abord, puis la page ; rien sur les push et PR ordinaires.
- Valeurs de cette phase : Worker `name: "lelion-web"`, `workers_dev: true`, `preview_urls: false`, `ORIGINES` de production `"https://w3cdotorg.github.io"`, en `wrangler dev` (`npm run dev`) `"https://w3cdotorg.github.io,http://localhost:*"` ; `observability.logs.invocation_logs: false`, `observability.traces.enabled: false` ; `compatibility_date` `2026-10-01` (inchangée), migration `v1` (inchangée), `ratelimits` 1001 et 1002 (inchangés) ; réglage `lelion/signalisation/url="wss://lelion-web.w3cdotorg.workers.dev"` (sans chemin : les routes `/v1/creer`, `/v1/rejoindre/<code>` restent dans `TransportWebRTC`), `lelion/signalisation/url.pilote="ws://localhost:8787"` ; `TransportWebRTC.URL_SIGNALISATION := ""` ; l'erreur `ERR_CANT_CONNECT` (25) ; port du contrôle de l'export publié 8061 ; port de `wrangler dev` pour la sonde locale 8797 (le 8787 reste au bout de bout et aux autres agents).
- Version et protocole : **inchangés**, `config/version="0.21"`, `PROTOCOLE 0.21 1188810746 (67 lignes)` (aucune RPC ne change) ; le premier déploiement est `v0.21`.
- Commandes : `export PATH="$HOME/.orbstack/bin:/opt/homebrew/bin:$PATH"` puis `cd ~/Sites/LeLion-web` ; chaque commande godot sous `timeout`, options écrites en clair (zsh ne découpe pas une variable non quotée : `--fixed-fps` sauterait en silence). Une suite `--script` qui ne se compile pas sort en 0 : lire sa sortie, jamais son seul code.
- Ports et processus : les suites Godot et le test réseau prennent les ports 17777 à 19990 de ce poste ; une suite ne tourne qu'avec aucun autre `godot --headless` (`pgrep -f 'godot --headless'` vide), et un échec de port ou de chrono du test réseau se relance une fois avant d'être diagnostiqué (mesuré pendant l'écriture de ce plan : un `FIN2` à 0,759 s d'écart sous une charge de 4,9, vert à la relance en 161 s).
- Un test `--script` est compilé **avant** les autoloads : il ne nomme aucun autoload. Un script neuf (`tests/export_publie.gd`) : l'import crée son `.uid`, à committer avec lui.
- Le bout en bout et les contrôles Playwright locaux tournent dans l'image `mcr.microsoft.com/playwright:v1.63.0-noble` (Docker d'OrbStack ; le pare-feu de ce Mac bloque WebRTC entre les navigateurs de Playwright), avec des volumes de modules propres à cette phase (`lelion5-modules-*`). L'export se refait avant chaque passage (`export/web`, `export/web-pilote`), dans un dossier `export/` qui a son `.gdignore`.
- Rien de cette partie A ne touche Cloudflare ni GitHub, hors `git push`, `gh pr` et `gh api` en lecture : les effets externes (push, PR, fusion, réglages du dépôt, tag) sont au contrôleur, avec l'accord de l'utilisateur. La sonde (Task 2, Step 4) fait **une** requête au Worker « Hello world » actuel : sans effet.
- Les blocs « Dans X, remplacer … par … » citent le texte exact de `main` à `ce22ce6` (générés depuis ce plan appliqué à une copie de `main`, puis vérifiés par une seconde application mécanique sur une copie neuve) ; chacun se fait avec l'outil Edit (texte exact, une seule occurrence), dans l'ordre donné. « Créer X » et « Remplacer X en entier » donnent le fichier entier (outil Write). Les blocs sont entourés de quatre accents graves (le README en contient trois).
- Identifiants, commentaires et messages en français, docstrings `##`, tabulations (GDScript, JavaScript, JSON du dépôt), deux espaces (YAML). Aucune séquence `\u…` tapée dans un fichier ; après chaque écriture, `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/web/*.js signalisation/outils/*.mjs` ne sort rien. Aucun message de test ne contient `SCRIPT ERROR` ni `SHADER ERROR`.
- Bruit connu des sorties : celui des plans précédents (« ObjectDB instances were leaked », « resources still in use at exit », `ERROR: Couldn't create an ENet host.`, `ERROR: The local port number must be between 0 and 65535`, les `WARNING: Signalisation : …` des unitaires) ; neuf, voulu, dans les unitaires et le smoke : `WARNING: Signalisation : aucune adresse (réglage lelion/signalisation/url)`, `ERROR: Invalid URL: ws://exemple.net:99999/v1/creer` (et `/v1/rejoindre/K7Q2XM`), `WARNING: Signalisation : ws://exemple.net:99999/v1/… ne s'ouvre pas (erreur 31)`.
- Commits en français, terminés par :
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT
  ```

## Review Focus

1. **La page publiée qui parle au mauvais service, ou qui embarque le pilote** (l'adresse `ws://localhost:8787` dans l'export publié ; un export « Web pilote » publié ; un réglage `.pilote` qui l'emporte hors du pilote ; une adresse en `ws://` que le navigateur refuse depuis une page `https://`) : l'adresse dans `project.godot`, ses variantes, les gardes. → unitaire « l'adresse du Worker : wss://lelion-web.w3cdotorg.workers.dev publié (lelion/signalisation/url), ws://localhost:8787 sous la fonctionnalité pilote seulement, lue avec ses variantes » (Task 3) ; `tests/export_publie.gd` (« l'export publié n'a pas la fonctionnalité pilote », « l'adresse du Worker de l'export … en wss:// », « aucune adresse locale hors des variantes .pilote » ; l'export « Web pilote » le fait échouer, mesuré ; Task 4) ; `export_publie.spec.js` (`typeof window.lelionPilote` `"undefined"`, aucun « PILOTE PRET », la page appelle `wss://lelion-web.w3cdotorg.workers.dev/v1/rejoindre/K7Q2XM` ; sur l'export « Web pilote », il échoue sur `ws://localhost:8787/…`, mesuré ; Task 4) ; au déploiement, le même contrôle face au Worker déployé, puis `en_direct.spec.js` sur la page publiée (Tasks 5, 6 ; runbook R3).
2. **Le bout en bout qui part en production sans qu'on le voie** (Godot 4.7.2 : `ProjectSettings.get_setting` ignore les variantes d'un réglage ; l'export « Web pilote » parlait alors au Worker déployé, mesuré par le contrôle de l'export publié lancé sur `export/web-pilote` : `wss://…` au lieu de `ws://localhost:8787`) : `get_setting_with_override`. → unitaire (le source lit le réglage par `get_setting_with_override(REGLAGE_URL)`, Task 3) ; le contrôle négatif sur `export/web-pilote` (Task 4, Step 3) ; le bout en bout vert sur `ws://localhost:8787` (`4 passed`, Task 8).
3. **Une origine de trop, ou de moins** (la production admet `http://localhost:*` ; `wrangler dev` refuse les pages du bout en bout ; un journal qui garde l'IP) : `ORIGINES` de production, `--var` en développement, journaux d'invocation et traces coupés. → vitest « origine refusée … » (`http://localhost:8060` refusée par la configuration de production ; Task 1, échoue avant) ; `npx wrangler deploy --dry-run` (`env.ORIGINES ("https://w3cdotorg.github.io")`) ; la sonde (`localhost` refusée sous les variables de production, admise sous `npm run dev` ; Task 2) ; le bout en bout (servi par `npm run dev`, Task 8) ; au déploiement, la sonde et le contrôle de l'export face au Worker (`Signalisation : erreur « origine »` pour une page servie de `http://localhost:8061` ; runbook R2).
4. **Un déploiement au mauvais moment ou à moitié** (une PR qui déploie ; un tag qui ne vaut pas la version ; un commit aux tests rouges déployé ; la page publiée avant un Worker qui marche ; deux déploiements qui se croisent ; un export reconstruit ailleurs que dans le passage testé ; l'environnement `github-pages` qui refuse le tag) : les `if`, `needs`, la vérification du tag, `concurrency`, l'artefact du passage, la règle de l'environnement. → actionlint, l'analyse YAML (les `needs` et `if` relus, Task 6) ; les étapes bash rejouées dans un conteneur Linux (Task 6) ; runbook R1 (la règle `v*` de `github-pages`, mesurée absente : seule `main` y est permise), R2 (le passage suivi job par job).
5. **Un échec qui dit faux ou qui ne dit rien** (« Impossible d'héberger (erreur 31) » pour une signalisation qui ne s'ouvre pas ; un binding de limite refusé qui casse le premier déploiement ; « ou ajoute &relais=1 » sans TURN, qui empêche alors toute connexion ; le paragraphe de vie privée qui parle d'un relais absent) : `ERR_CANT_CONNECT`, `admis` sans binding, la documentation. → unitaire « la signalisation qui ne s'ouvre pas : ERR_CANT_CONNECT à l'hôte comme au client, rien d'ouvert » (`[[31, …]]` avant, Task 3) ; smoke « la signalisation qui ne s'ouvre pas : « Service de connexion indisponible, réessaie dans un instant. » à la création comme à l'arrivée » (« Impossible d'héberger (erreur 31) » avant, Task 3) ; vitest « sans binding … : tout passe, sans rien journaliser » (Task 1) ; la relecture des sections du README et de la fiche (Task 7).

## Écarts assumés

1. **L'adresse du Worker est écrite dans `project.godot`, pas dans une variable du dépôt** (le choix laissé par le contrôleur). Connue depuis le 02/10/2026 (`lelion-web.w3cdotorg.workers.dev`), elle fait partie du tag : l'export d'un tag est le même où qu'on le refasse (un retour en arrière republie exactement l'ancienne page), l'unitaire la vérifie, le garde de l'export la compare au paquet, la sonde du déploiement la lit au même endroit. Une variable de dépôt rendrait l'export d'un ancien tag dépendant de sa valeur du jour, et ajouterait une injection dans le job. Sans chemin (`wss://lelion-web.w3cdotorg.workers.dev`, pas `…/v1`) : `TransportWebRTC` ajoute `/v1/creer` et `/v1/rejoindre/<code>` (la version du protocole de signalisation est dans ses routes, phase 2) ; la note « l'adresse `wss://…/v1` » se lit ainsi.
2. **Le Worker s'appelle `lelion-web`** (le nom du Worker « Hello world » que l'utilisateur a créé à cette adresse ; `lelion-signalisation` jusqu'ici) : le premier `wrangler deploy` remplace ce Worker sans Durable Object, et la migration `v1` crée la classe `Salle` dans un espace neuf. `package.json` garde son nom de paquet (`lelion-signalisation`, jamais déployé). Les plans des phases précédentes, figés, gardent l'ancien nom.
3. **`ORIGINES` : la production dans `wrangler.jsonc`, le développement par `--var` dans `npm run dev`.** Pas `.dev.vars` (ignoré par git : la CI et chaque poste devraient l'écrire, et un `wrangler dev` lancé sans lui refuserait le bout en bout sans le dire), pas un `env` de wrangler (un autre nom de Worker, et les bindings `durable_objects` et `ratelimits`, qui ne s'héritent pas, à recopier). Les tests vitest lisent la configuration de production (`env.ORIGINES`) : `http://localhost:8060` y est refusée. La sonde vérifie les deux (mesuré, Task 2).
4. **La limitation de débit : pas de compteur en Durable Object d'avance.** La documentation de Cloudflare ne réserve le binding à aucune offre (page *Rate Limiting*, relue le 02/10/2026) ; l'annonce de sa disponibilité générale (19/09/2025) le donne sur les offres gratuite et payante (sources secondaires). Repli décidé : si le premier `wrangler deploy` refuse le bloc `ratelimits`, le retirer (runbook R2, branche B) ; `admis` admet alors tout **sans journaliser** (sinon une ligne par requête userait le quota de Workers Logs ; vitest, Task 1), les plafonds de chaque salle restent ; un compteur en Durable Object (migration `v2`) seulement si des abus l'exigent. Un compteur prêt d'avance, derrière un drapeau, ajouterait une classe, une migration et leurs tests pour un cas qui n'arrivera probablement pas. Les namespaces 1001 et 1002 : uniques sur un compte neuf.
5. **Workers Logs : les journaux d'invocation et les traces sont coupés.** La documentation dit qu'ils contiennent « la requête, la réponse et les métadonnées liées » sans dire si l'IP du client (`cf-connecting-ip`) en fait partie : dans le doute, ils sont coupés (`invocation_logs: false`, `traces.enabled: false`), et le README dit vrai sans dépendre d'une réponse inconnue : les journaux ne gardent que les lignes de `journal`, sans IP. Effet de bord voulu : un événement de moins par invocation sur les 200 000 par jour de l'offre gratuite.
6. **`get_setting_with_override`** (constaté en écrivant ce plan) : `ProjectSettings.get_setting` de Godot 4.7.2 ignore les variantes de fonctionnalité ; le contrôle de l'export publié, lancé sur `export/web-pilote`, a vu la page appeler `wss://lelion-web.w3cdotorg.workers.dev` au lieu de `ws://localhost:8787`. `url_signalisation` lit donc le réglage par `get_setting_with_override` (et `has_setting` : celle-ci n'a pas de valeur par défaut) ; l'unitaire garde l'appel dans le source (le desktop n'a pas la fonctionnalité `pilote`), le bout en bout le prouve en marche.
7. **Le garde du paquet publié lit ses réglages, il ne cherche pas un texte.** Mesuré : le paquet de l'export « Web » contient `ws://localhost:8787`, sous la clé `lelion/signalisation/url.pilote` (Godot écrit toutes les variantes dans `project.binary`), et les scripts y sont compressés (`script_export_mode=2`), donc illisibles à `grep`. La note « ni une URL localhost » se lit : ni `pilote` dans `_custom_features`, une adresse du Worker en `wss://` égale à celle de `project.godot`, et aucune valeur qui contienne `localhost` hors d'une variante `.pilote` (que seul l'export « Web pilote » choisit). `tests/export_publie.gd` monte le paquet (`load_resource_pack`) et décode `project.binary` (« ECFG », puis clés et Variants) ; l'export « Web pilote » le fait échouer (mesuré). Le source de `TransportWebRTC.gd` ne contient plus `localhost` (`URL_SIGNALISATION := ""`, vérifié par l'unitaire).
8. **Une signalisation qui ne s'ouvre pas rend `ERR_CANT_CONNECT`** (aucune adresse ; `connect_to_url` qui refuse : `ERR_INVALID_PARAMETER` pour une adresse mal formée, mesuré, `FAILED` sur le Web pour le contenu mixte), pas l'erreur de `connect_to_url` : `ERR_INVALID_PARAMETER` est déjà la réponse de `rejoindre` à un code mal formé, et l'écran ne pourrait pas les distinguer. `EcranEnLigne` dit « Service de connexion indisponible, réessaie dans un instant. » pour la création comme pour l'arrivée (le focus au code après Rejoindre), sur le Web comme sur le desktop (ENet ne rend jamais `ERR_CANT_CONNECT`). Sans réglage, aucune adresse (`URL_SIGNALISATION := ""`) : un export sans service ne tente rien.
9. **La page publiée est l'artefact `LeLion-web` du passage du tag**, pas un export refait : `test-et-export` le construit depuis l'extraction du tag et le garde (`tests/export_publie.gd`, la liste exacte de ses 9 fichiers, pas de `viewport-fit`), `deploiement-page` le reprend (`download-artifact`), le contrôle face au Worker déployé, puis le publie (`upload-pages-artifact` sur `export/web` seul). `export/.gdignore` : sans lui, l'éditeur importe les images de l'export pendant l'export et y laisse trois `.import` (mesuré), qui seraient publiés.
10. **Le déploiement vit dans `ci.yml`**, derrière `needs: [test-et-export, signalisation, bout-en-bout]` et `if: startsWith(github.ref, 'refs/tags/v')` : un tag ne déploie que si tous les tests de son commit passent, dans le même passage (un second workflow sur le tag ne saurait pas attendre ceux du premier). `concurrency: deploiement` (sans annulation) sérialise deux tags poussés de suite. `permissions: contents: read` partout, `pages: write` et `id-token: write` au seul job de la page.
11. **Les vérifications du déploiement, à chaque étape** : avant le Worker, le tag vaut la version ; après, la sonde (une salle depuis l'origine de la page, ses serveurs ICE en STUN seul, `localhost` refusé) ; l'adresse de `wrangler deploy` comparée à celle de `project.godot` n'est qu'un avertissement (son format de sortie n'est pas un contrat : la sonde tranche) ; avant la page, l'export face au Worker déployé (la page, servie de `http://localhost:8061`, lit `Signalisation : erreur « origine »`) ; après, le paquet de cette version servi (même taille, `?v=<commit>` contre le cache de Pages, 5 min au plus), puis la partie de deux pages (`en_direct.spec.js`). Deux pages d'un même poste se relient par leurs candidats locaux : cette partie prouve la page, le Worker et le relais de la signalisation, pas la traversée des NAT, qui est l'affaire de l'essai réel.
12. **La partie de contrôle se joue au clavier, comme un joueur** (la page publiée n'a pas de pilote) : sur le titre, Droite (Multijoueur, voisin de Jouer), Entrée, Entrée (Créer une partie a le focus sur un ordinateur) ; le code se lit dans les messages de la signalisation (`page.on("websocket")`) ; l'invité ouvre le lien, Entrée (deux fois au plus : l'édition du pseudo, puis la validation, qui rejoint puisque le code est là). Mesuré en local sur un export « Web » qui visait `wrangler dev` : 6,8 s.
13. **Pas de TURN : `?relais=1` reste dans le jeu**, sans relais à imposer (il empêche alors toute connexion) ; le README et la fiche le disent, la manche « par le relais » de la fiche devient le relevé des réseaux qui ne se relient pas (ce qui décidera du TURN, spec §13 : le TURN de Cloudflare avec une carte bancaire, ou l'offre gratuite d'un autre fournisseur, Metered par exemple, dont le Worker fabriquerait les identifiants).
14. **Les canaux de la page publiée** : vérifiés automatiquement (le contrôle de l'export, salle simulée qui accueille la page : 4 canaux, `durée=100` sur les deux non fiables, mesuré) et à la main sur la page déployée (la fiche : une ligne à coller dans la console avant de créer la partie ; la même enveloppe que le contrôle, vérifiée collée après le chargement, mesuré).
15. **La sonde** (`signalisation/outils/sonder.mjs`) : le WebSocket de Node (undici) accepte l'option `headers` (l'en-tête `Origin`) ; vérifié sous Node 24.21.0 (le conteneur `node:24.21.0-slim`) et 26.10.0. Elle ouvre une salle (une des 5 créations par minute de son IP), aussitôt fermée.
16. **Une seule PR pour la ligne 5.** Fichiers au-delà de la ligne 5 de la feuille de route (qui citait `ci.yml`, `project.godot`, `wrangler.jsonc`, `README.md`) : `signalisation/package.json`, `signalisation/src/index.js`, `signalisation/test/entree.test.js`, `signalisation/outils/sonder.mjs` ; `Scripts/TransportWebRTC.gd`, `Scripts/EcranEnLigne.gd` (l'échec synchrone) ; `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/export_publie.gd` (+ `.uid`) ; `tests/web/playwright.config.js`, `tests/web/export_publie.spec.js`, `tests/web/playwright.publie.config.js`, `tests/web/en_direct.spec.js`, `tests/web/playwright.en_direct.config.js` ; `docs/essai-en-ligne.md`, la spec, la feuille de route. Chaque tâche touche 5 fichiers au plus.
17. **Step 0** (règle du projet : `TransportWebRTC.gd` 595 lignes, `EcranEnLigne.gd` 360, touchés) : rien à retirer (vérifié, Task 0).

---

## Partie A : le code (sans compte)

### Task 0 : préparation, Step 0 et références

Ce plan est commité par le commit de planification : ne pas le recommiter, ne jamais le modifier.

**Files:** aucun (vérifications seulement).

**Interfaces:** aucune.

- [ ] **Step 1 : la branche**

```bash
export PATH="$HOME/.orbstack/bin:/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
git switch main && git pull --ff-only
git log --oneline -1 main
git switch -c phase-05-deploiement
wc -l Scripts/TransportWebRTC.gd Scripts/EcranEnLigne.gd tests/unitaires.gd tests/smoke_test.gd README.md docs/essai-en-ligne.md .github/workflows/ci.yml signalisation/wrangler.jsonc signalisation/src/index.js signalisation/test/entree.test.js tests/web/playwright.config.js docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md project.godot
grep -n 'config/version\|signalisation/url' project.godot; ls tests/export_publie.gd signalisation/outils 2>&1 | head -2
```

Expected : `ce22ce6 Merge pull request #8 from w3cdotorg/phase-07-securite` (ou le commit de planification de ce plan juste après) ; `595 Scripts/TransportWebRTC.gd`, `360 Scripts/EcranEnLigne.gd`, `3650 tests/unitaires.gd`, `3019 tests/smoke_test.gd`, `292 README.md`, `171 docs/essai-en-ligne.md`, `186 .github/workflows/ci.yml`, `35 signalisation/wrangler.jsonc`, `90 signalisation/src/index.js`, `198 signalisation/test/entree.test.js`, `53 tests/web/playwright.config.js`, `380 docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, `111 project.godot` ; `config/version="0.21"`, `signalisation/url="ws://localhost:8787"` ; les deux chemins absents. D'autres longueurs : s'arrêter et le signaler (les blocs de ce plan citent `main` à `ce22ce6`).

- [ ] **Step 2 : Step 0 (règle du projet, deux fichiers touchés font plus de 300 lignes)**

```bash
for f in Scripts/TransportWebRTC.gd Scripts/EcranEnLigne.gd; do
	for n in $(grep -oE "^(const|var|func|static func|signal|enum) [A-Za-z_0-9]+" $f | awk '{print $NF}'); do
		[ "$(grep -rwo "$n" Scripts tests Scenes | wc -l | tr -d ' ')" -lt 2 ] && echo "seul : $f $n"
	done
done
grep -nE "^[[:space:]]*(print|prints|printt|print_debug|breakpoint)\b" Scripts/TransportWebRTC.gd Scripts/EcranEnLigne.gd
echo fin
```

Expected (mesuré) : `fin` seul. **Pas de commit de nettoyage.** Une ligne `seul :` ou un `print` : le retirer dans un commit à part (`Step 0 : code mort retiré`) avant la Task 1.

- [ ] **Step 3 : les références**

```bash
pgrep -f 'godot --headless' || echo "aucun autre godot"
timeout 300 godot --headless --import . > /dev/null 2>&1
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u0.log" 2>&1; grep -E "PROTOCOLE|== " "$TMPDIR/u0.log"; grep -c "✅" "$TMPDIR/u0.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s0.log" 2>&1; grep -E "== " "$TMPDIR/s0.log"; grep -c "✅" "$TMPDIR/s0.log"
(cd signalisation && npm ci --silent && npm test 2>&1 | grep "Tests ")
command -v actionlint || brew install actionlint
docker image inspect mcr.microsoft.com/playwright:v1.63.0-noble > /dev/null 2>&1 || docker pull -q mcr.microsoft.com/playwright:v1.63.0-noble
gh api repos/w3cdotorg/LeLion-web/environments/github-pages/deployment-branch-policies -q '.branch_policies[] | "\(.type) \(.name)"'
curl -s -m 10 https://lelion-web.w3cdotorg.workers.dev/; echo
```

Expected : « aucun autre godot » (sinon attendre) ; `PROTOCOLE 0.21 1188810746 (67 lignes)`, `== 0 échec(s) ==`, `574` ✅ ; smoke `== 0 échec(s) ==`, `472` ✅ ; `Tests  70 passed (70)` ; un chemin d'`actionlint` ; l'image présente ; `branch main` seul (la règle `v*` vient au runbook R1) ; `Hello world` (le Worker que le premier déploiement remplacera).

---

### Task 1 : le Worker de production (`wrangler.jsonc`, `npm run dev`, le repli sans limiteur)

**Files:**
- Modify: `signalisation/test/entree.test.js` (« origine refusée … » : `http://localhost:8060` ; « sans binding … »)
- Modify: `signalisation/wrangler.jsonc` (en entier)
- Modify: `signalisation/package.json` (`dev`)
- Modify: `signalisation/src/index.js` (`admis`)

**Interfaces:**
- `wrangler.jsonc` : `name: "lelion-web"`, `workers_dev: true`, `preview_urls: false`, `vars.ORIGINES: "https://w3cdotorg.github.io"`, `observability.logs.invocation_logs: false`, `observability.traces.enabled: false` ; `compatibility_date`, `durable_objects`, `migrations` (`v1`), `ratelimits` (1001, 1002) inchangés.
- `npm run dev` = `wrangler dev --var 'ORIGINES:https://w3cdotorg.github.io,http://localhost:*'` (les options qui suivent `--` s'y ajoutent : `--port 8787 --ip localhost` du bout en bout).
- `admis(limite, cle)` : `limite === undefined` → `true`, sans journal.

- [ ] **Step 1 : les tests qui échouent**

Dans `signalisation/test/entree.test.js`, remplacer :

````js
	it("origine refusée : erreur origine puis fermeture, à la création comme à l'arrivée", async () => {
		for (const chemin of ["/v1/creer", "/v1/rejoindre/K7Q2XM"]) {
			for (const origine of [null, "https://exemple.net"]) {
				const socket = await ouvrir(chemin, { origine });
				expect(socket.reponse.status).toBe(101);
````

par :

````js
	it("origine refusée : erreur origine puis fermeture, à la création comme à l'arrivée", async () => {
		for (const chemin of ["/v1/creer", "/v1/rejoindre/K7Q2XM"]) {
			// http://localhost:8060 : la configuration de production (wrangler.jsonc) n'admet que la page publiée.
			for (const origine of [null, "https://exemple.net", "http://localhost:8060"]) {
				const socket = await ouvrir(chemin, { origine });
				expect(socket.reponse.status).toBe(101);
````

Dans `signalisation/test/entree.test.js`, remplacer :

````js
	});

	it("arrivée au-delà de la limite de l'IP : erreur debit, sans appeler la salle", async () => {
		const SALLE_INTERDITE = {
````

par :

````js
	});

	it("sans binding (le bloc ratelimits retiré, repli de la phase 5) : tout passe, sans rien journaliser", async () => {
		const journal = vi.spyOn(console, "log").mockImplementation(() => {});
		journal.mockClear(); // l'espion du test précédent, s'il reste, garde ses appels
		const env = envFactice(SALLE_FACTICE, { LIMITE_CREATION: undefined, LIMITE_ARRIVEE: undefined });
		for (const chemin of ["/v1/creer", "/v1/rejoindre/K7Q2XM"]) {
			const reponse = await worker.fetch(requete(chemin), env);
			expect(await reponse.text(), chemin).toBe("salle factice");
		}
		expect(journal).not.toHaveBeenCalled();
		journal.mockRestore();
	});

	it("arrivée au-delà de la limite de l'IP : erreur debit, sans appeler la salle", async () => {
		const SALLE_INTERDITE = {
````


- [ ] **Step 2 : les lancer**

```bash
cd signalisation && npm test 2>&1 | grep -E "×|Tests "; cd ..
```

Expected (mesuré) : `× origine refusée : erreur origine puis fermeture, à la création comme à l'arrivée` (la configuration actuelle admet `http://localhost:*`), `× sans binding (le bloc ratelimits retiré, repli de la phase 5) : tout passe, sans rien journaliser` (`limite.limit` d'un binding absent lève, et le journal dit « limite injoignable »), `Tests  2 failed | 69 passed (71)`.

- [ ] **Step 3 : la configuration de production et le repli**

Remplacer `signalisation/wrangler.jsonc` en entier (outil Write) par :

````jsonc
{
	"$schema": "./node_modules/wrangler/config-schema.json",
	"name": "lelion-web",
	"main": "src/index.js",
	// Jamais sous 2026-04-07 : l'auto-réponse au ping après la fermeture, deleteAll qui efface l'alarme (phase 2).
	"compatibility_date": "2026-10-01",
	// L'adresse publique : https://lelion-signalisation.<sous-domaine>.workers.dev (phase 5) ; aucune adresse
	// de préversion (une par version déployée : autant d'adresses à surveiller pour rien).
	"workers_dev": true,
	"preview_urls": false,
	// Origines admises, séparées par des virgules ; « :* » = tout port (spec §8.1). La production n'admet que la
	// page publiée ; `npm run dev` (wrangler dev, le bout en bout) y ajoute http://localhost:* par --var.
	"vars": {
		"ORIGINES": "https://w3cdotorg.github.io"
	},
	// Secrets (jamais dans le dépôt) : TURN_KEY_ID, TURN_KEY_API_TOKEN. Absents (le déploiement de la phase 5) :
	// STUN seul.
	// Une salle par code (idFromName) ; SQLite obligatoire sur l'offre gratuite.
	"durable_objects": {
		"bindings": [{ "name": "SALLES", "class_name": "Salle" }]
	},
	// Figée : un déploiement ne réécrit jamais une migration déjà appliquée (une classe neuve = une v2).
	"migrations": [{ "tag": "v1", "new_sqlite_classes": ["Salle"] }],
	// Limitation de débit des Workers, par point de présence : 5 créations et 30 arrivées par minute et par IP.
	// namespace_id : entier unique sur le compte. Si le premier déploiement refuse ce bloc, le retirer : sans
	// binding, le Worker admet tout (`admis`), les plafonds de chaque salle restent.
	"ratelimits": [
		{
			"name": "LIMITE_CREATION",
			"namespace_id": "1001",
			"simple": { "limit": 5, "period": 60 }
		},
		{
			"name": "LIMITE_ARRIVEE",
			"namespace_id": "1002",
			"simple": { "limit": 30, "period": 60 }
		}
	],
	// Workers Logs : les lignes de `journal` seulement (jamais d'IP, protocole.js). Les journaux d'invocation
	// (la requête et ses métadonnées) et les traces sont coupés : rien ne garantit qu'ils n'écrivent pas l'IP du
	// client, et chacun compterait sur les 200 000 événements par jour de l'offre gratuite.
	"observability": {
		"enabled": true,
		"logs": { "enabled": true, "head_sampling_rate": 1, "invocation_logs": false },
		"traces": { "enabled": false }
	}
}
````


Dans `signalisation/package.json`, remplacer :

````json
	"scripts": {
		"test": "vitest run",
		"dev": "wrangler dev"
	},
	"devDependencies": {
````

par :

````json
	"scripts": {
		"test": "vitest run",
		"dev": "wrangler dev --var 'ORIGINES:https://w3cdotorg.github.io,http://localhost:*'"
	},
	"devDependencies": {
````


Dans `signalisation/src/index.js`, remplacer :

````js
/**
 * Vrai si le limiteur `limite` (binding ratelimits) admet encore `cle`. Injoignable, il laisse passer
 * (ouvert par défaut) : c'est un frein, et sa panne ne doit pas fermer le service.
 */
async function admis(limite, cle) {
	try {
		return (await limite.limit({ key: cle })).success;
````

par :

````js
/**
 * Vrai si le limiteur `limite` (binding ratelimits) admet encore `cle`. Injoignable, il laisse passer
 * (ouvert par défaut) : c'est un frein, et sa panne ne doit pas fermer le service. Absent (le bloc
 * `ratelimits` retiré de wrangler.jsonc, le repli de la phase 5 si l'offre gratuite le refusait), il laisse
 * tout passer sans rien journaliser : une ligne par requête userait le quota de Workers Logs.
 */
async function admis(limite, cle) {
	if (limite === undefined) return true;
	try {
		return (await limite.limit({ key: cle })).success;
````


- [ ] **Step 4 : les relancer, et la configuration de déploiement**

```bash
cd signalisation
npm test 2>&1 | grep -E "×|Tests "
npx wrangler deploy --dry-run --outdir "$TMPDIR/signalisation-essai" 2>&1 | grep -E "env\.|warn|WARN|exiting"
cd ..
```

Expected (mesuré) : `Tests  71 passed (71)` ; `env.SALLES (Salle)`, `env.LIMITE_CREATION (5 requests/60s)`, `env.LIMITE_ARRIVEE (30 requests/60s)`, `env.ORIGINES ("https://w3cdotorg.github.io")`, `--dry-run: exiting now.`, aucun avertissement (le schéma de wrangler 4.146.0 connaît `workers_dev`, `preview_urls` et `invocation_logs`).

- [ ] **Step 5 : commit**

```bash
git add signalisation/wrangler.jsonc signalisation/package.json signalisation/src/index.js signalisation/test/entree.test.js
git commit -m "Signalisation de production : le Worker lelion-web, la page publiée seule admise (localhost sous npm run dev), journaux d'invocation et traces coupés ; sans binding de limite, tout passe sans journal (le repli si l'offre gratuite refusait ratelimits)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 2 : la sonde du Worker déployé (`signalisation/outils/sonder.mjs`)

**Files:**
- Create: `signalisation/outils/sonder.mjs`

**Interfaces:**
- `node outils/sonder.mjs <adresse> [origine refusée]` (depuis `signalisation/`) : `<adresse>` = `wss://hôte` (ou `ws://localhost:<port>`), sans chemin ; l'origine refusée vaut `http://localhost:8060` par défaut. Sort en 0 après deux lignes (`salle XXXXXX créée depuis https://w3cdotorg.github.io, ICE : stun:… stun:…`, `origine … refusée (erreur origine)`), en 1 sur une ligne `::error::…` (une annotation dans GitHub Actions).

- [ ] **Step 1 : la sonde**

Créer `signalisation/outils/sonder.mjs` :

````js
// La sonde du Worker déployé (phase 5) : node outils/sonder.mjs <adresse wss://…> [origine refusée]
// 1. /v1/creer depuis l'origine de la page publiée : la salle répond `salle` (un code, l'hôte 1), ses serveurs
//    ICE sont du STUN seul (ni TURN ni identifiants : le déploiement sans TURN) ;
// 2. /v1/creer depuis une origine que la production refuse (http://localhost:8060 par défaut) : `erreur origine`.
// Sort en 0 si tout est vu, en 1 sinon (le message dit quoi). Ouvre une seule salle, aussitôt fermée (l'hôte
// parti, la salle s'efface) : elle compte pour 1 des 5 créations par minute de l'IP qui sonde.
// WebSocket de Node (undici) : l'option `headers` pose l'en-tête Origin, qu'un navigateur poserait lui-même.
const [adresse, refusee = "http://localhost:8060"] = process.argv.slice(2);
const PAGE = "https://w3cdotorg.github.io";
const DELAI_MS = 10_000;

function premierMessage(url, origine) {
	return new Promise((resoudre, rejeter) => {
		const ws = new WebSocket(url, { headers: { Origin: origine } });
		const minuterie = setTimeout(() => {
			ws.close();
			rejeter(new Error(`${url} (Origin ${origine}) : aucun message en ${DELAI_MS} ms`));
		}, DELAI_MS);
		ws.addEventListener("message", (evenement) => {
			clearTimeout(minuterie);
			ws.close(1000, "sonde");
			resoudre(JSON.parse(evenement.data));
		});
		ws.addEventListener("error", () => {
			clearTimeout(minuterie);
			rejeter(new Error(`${url} (Origin ${origine}) : connexion impossible`));
		});
	});
}

function echouer(message) {
	console.error(`::error::${message}`);
	process.exit(1);
}

if (!/^wss:\/\/[a-z0-9.-]+$/.test(adresse ?? "") && !/^ws:\/\/localhost:\d+$/.test(adresse ?? "")) {
	echouer(`adresse du Worker invalide : « ${adresse} » (attendu wss://hôte, sans chemin ni « / » final)`);
}
try {
	const salle = await premierMessage(`${adresse}/v1/creer`, PAGE);
	if (salle.t !== "salle" || !/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/.test(salle.code) || salle.id !== 1) {
		echouer(`depuis ${PAGE}, attendu une salle, reçu ${JSON.stringify(salle)}`);
	}
	const urls = (salle.ice ?? []).flatMap((serveur) => serveur.urls ?? []);
	const turn = (salle.ice ?? []).some((serveur) => serveur.username || serveur.credential) || urls.some((url) => !url.startsWith("stun:"));
	if (urls.length === 0 || turn) echouer(`serveurs ICE inattendus (STUN seul attendu) : ${JSON.stringify(salle.ice)}`);
	console.log(`salle ${salle.code} créée depuis ${PAGE}, ICE : ${urls.join(" ")}`);
	const refus = await premierMessage(`${adresse}/v1/creer`, refusee);
	if (refus.t !== "erreur" || refus.raison !== "origine") echouer(`depuis ${refusee}, attendu erreur origine, reçu ${JSON.stringify(refus)}`);
	console.log(`origine ${refusee} refusée (erreur origine)`);
} catch (erreur) {
	echouer(erreur.message);
}
````


- [ ] **Step 2 : la sonde face à la configuration de production, en local** (le port 8797 : le 8787 peut servir au bout en bout d'un autre agent)

```bash
cd signalisation
export WRANGLER_SEND_METRICS=false
(npx wrangler dev --port 8797 --ip localhost > "$TMPDIR/wd-prod.log" 2>&1 &)
for i in $(seq 60); do curl -s -o /dev/null localhost:8797 && break; sleep 1; done
node outils/sonder.mjs ws://localhost:8797; echo "code $?"
node outils/sonder.mjs ws://localhost:8797 https://exemple.net; echo "code $?"
pkill -f "wrangler dev --port 8797"; sleep 3
```

Expected (mesuré) : `salle XXXXXX créée depuis https://w3cdotorg.github.io, ICE : stun:stun.cloudflare.com:3478 stun:stun.l.google.com:19302`, `origine http://localhost:8060 refusée (erreur origine)`, `code 0` ; puis la même salle et `origine https://exemple.net refusée (erreur origine)`, `code 0`.

- [ ] **Step 3 : la même sonde face à `npm run dev`** (le développement admet `localhost` : la sonde doit échouer)

```bash
(npm run dev -- --port 8797 --ip localhost > "$TMPDIR/wd-dev.log" 2>&1 &)
for i in $(seq 60); do curl -s -o /dev/null localhost:8797 && break; sleep 1; done
node outils/sonder.mjs ws://localhost:8797; echo "code $?"
node outils/sonder.mjs ws://localhost:8797 https://exemple.net; echo "code $?"
pkill -f "port 8797"; sleep 2; pgrep -f "port 8797" || echo "arrêté"
```

Expected (mesuré) : `::error::depuis http://localhost:8060, attendu erreur origine, reçu {"t":"salle",…}`, `code 1` (le `--var` de `npm run dev` admet `http://localhost:*`) ; `origine https://exemple.net refusée (erreur origine)`, `code 0` ; `arrêté`.

- [ ] **Step 4 : la sonde face au Worker actuel** (une requête au Worker « Hello world » : sans effet)

```bash
node outils/sonder.mjs wss://lelion-web.w3cdotorg.workers.dev; echo "code $?"
cd ..
```

Expected (mesuré) : `::error::wss://lelion-web.w3cdotorg.workers.dev/v1/creer (Origin https://w3cdotorg.github.io) : connexion impossible`, `code 1` (pas encore de signalisation à cette adresse : ce que le job de déploiement verrait si `wrangler deploy` n'avait rien changé).

- [ ] **Step 5 : commit**

```bash
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' signalisation/outils/*.mjs
git add signalisation/outils/sonder.mjs
git commit -m "Signalisation : la sonde du Worker déployé (une salle depuis l'origine de la page publiée, STUN seul ; localhost refusé)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 3 : l'adresse du Worker dans le jeu, et la signalisation qui ne s'ouvre pas

**Files:**
- Modify: `tests/unitaires.gd` (`URL_WORKER` ; `_tester_transport_webrtc` : l'adresse et ses variantes, `ERR_CANT_CONNECT`, les adresses des transports simulés)
- Modify: `tests/smoke_test.gd` (`_tester_ecran_en_ligne` : « Service de connexion indisponible » d'un vrai `TransportWebRTC`)
- Modify: `project.godot` (`[lelion]`)
- Modify: `Scripts/TransportWebRTC.gd` (`URL_SIGNALISATION`, `heberger`, `rejoindre`, `url_signalisation`, `_ouvrir_signalisation`)
- Modify: `Scripts/EcranEnLigne.gd` (`creer_partie`, `rejoindre`)

**Interfaces:**
- `project.godot` : `signalisation/url="wss://lelion-web.w3cdotorg.workers.dev"`, `signalisation/url.pilote="ws://localhost:8787"`.
- `TransportWebRTC` : `const URL_SIGNALISATION := ""` ; `static func url_signalisation() -> String` (par `get_setting_with_override`) ; `func _ouvrir_signalisation(chemin: String) -> Error` (OK ou `ERR_CANT_CONNECT`) ; `heberger()` et `rejoindre(code)` rendent `ERR_CANT_CONNECT` quand la signalisation ne s'ouvre pas (`rejoindre` d'un code mal formé : toujours `ERR_INVALID_PARAMETER`, avant).
- `EcranEnLigne` : `ERR_CANT_CONNECT` → `ENLIGNE_SERVICE_INDISPONIBLE` (clé existante), à la création comme à l'arrivée.
- unitaires : `const URL_WORKER := "wss://lelion-web.w3cdotorg.workers.dev"`.

- [ ] **Step 1 : les tests qui échouent**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
const PROTOCOLE_VERSION := "0.21"
const PROTOCOLE_EMPREINTE := 1188810746


````

par :

````gdscript
const PROTOCOLE_VERSION := "0.21"
const PROTOCOLE_EMPREINTE := 1188810746
## L'adresse du Worker déployé (phase 5), sans chemin : le réglage lelion/signalisation/url de l'export publié.
const URL_WORKER := "wss://lelion-web.w3cdotorg.workers.dev"


````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
		_check(exclus.call(web).has("export/*") and exclus.call(pilote_s).has("export/*"),
			"aucun préréglage n'emporte un export précédent (export/* exclu) (%s, %s)" % [exclus.call(web), exclus.call(pilote_s)])
	_check(TransportWebRTC.url_signalisation() == "ws://localhost:8787",
		"l'adresse du Worker vient du réglage lelion/signalisation/url (wrangler dev en local) : %s" % TransportWebRTC.url_signalisation())
	_check(TransportWebRTC.lire_relais("?salle=K7Q2XM&relais=1") and TransportWebRTC.lire_relais("relais=1")
		and not TransportWebRTC.lire_relais("?relais=0") and not TransportWebRTC.lire_relais("?relaisx=1")
````

par :

````gdscript
		_check(exclus.call(web).has("export/*") and exclus.call(pilote_s).has("export/*"),
			"aucun préréglage n'emporte un export précédent (export/* exclu) (%s, %s)" % [exclus.call(web), exclus.call(pilote_s)])
	# Phase 5 (spec §11) : l'export publié parle au Worker déployé ; l'export « Web pilote » (le bout en bout) à
	# wrangler dev, par la variante `.pilote` du réglage ; le script ne connaît aucune adresse locale.
	var projet := ConfigFile.new()
	_check(projet.load("res://project.godot") == OK, "(pré-condition) project.godot se lit")
	_check(TransportWebRTC.url_signalisation() == URL_WORKER and projet.get_value("lelion", "signalisation/url", "") == URL_WORKER
		and projet.get_value("lelion", "signalisation/url.pilote", "") == "ws://localhost:8787"
		and not FileAccess.get_file_as_string("res://Scripts/TransportWebRTC.gd").contains("localhost")
		and FileAccess.get_file_as_string("res://Scripts/TransportWebRTC.gd").contains("ProjectSettings.get_setting_with_override(REGLAGE_URL)"),
		"l'adresse du Worker : %s publié (lelion/signalisation/url), ws://localhost:8787 sous la fonctionnalité pilote seulement, lue avec ses variantes (%s)"
		% [URL_WORKER, TransportWebRTC.url_signalisation()])
	# Une signalisation qui ne s'ouvre même pas (aucune adresse ; une adresse que connect_to_url refuse d'emblée,
	# comme le contenu mixte sur le Web) : ERR_CANT_CONNECT, rien d'ouvert ; un code mal formé reste
	# ERR_INVALID_PARAMETER (il ne tente rien)
	var refus: Array = []
	var url_avant: Variant = ProjectSettings.get_setting(TransportWebRTC.REGLAGE_URL)
	for adresse: String in ["", "ws://exemple.net:99999"]:
		ProjectSettings.set_setting(TransportWebRTC.REGLAGE_URL, adresse)
		var sans_service := TransportWebRTC.new()
		refus.append([sans_service.heberger(), sans_service.pair() == null, sans_service.servir(), TransportWebRTC.new().rejoindre("K7Q2XM"),
			TransportWebRTC.new().rejoindre("K7Q-2XM")])
	ProjectSettings.set_setting(TransportWebRTC.REGLAGE_URL, url_avant)
	var attendu := [ERR_CANT_CONNECT, true, false, ERR_CANT_CONNECT, ERR_INVALID_PARAMETER]
	_check(refus == [attendu, attendu], "la signalisation qui ne s'ouvre pas : ERR_CANT_CONNECT à l'hôte comme au client, rien d'ouvert (%s)" % [refus])
	_check(TransportWebRTC.lire_relais("?salle=K7Q2XM&relais=1") and TransportWebRTC.lire_relais("relais=1")
		and not TransportWebRTC.lire_relais("?relais=0") and not TransportWebRTC.lire_relais("?relaisx=1")
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	# L'hôte
	var hote := TransportWebRTCSimule.new()
	_check(hote.heberger() == OK and hote.url == "ws://localhost:8787/v1/creer" and hote.pair() is WebRTCMultiplayerPeer
		and hote.pair().get_unique_id() == 1 and hote.signaux.is_empty(),
		"héberger : le pair serveur existe (identifiant 1), /v1/creer s'ouvre, rien n'est dit pendant l'appel")
````

par :

````gdscript
	# L'hôte
	var hote := TransportWebRTCSimule.new()
	_check(hote.heberger() == OK and hote.url == URL_WORKER + "/v1/creer" and hote.pair() is WebRTCMultiplayerPeer
		and hote.pair().get_unique_id() == 1 and hote.signaux.is_empty(),
		"héberger : le pair serveur existe (identifiant 1), /v1/creer s'ouvre, rien n'est dit pendant l'appel")
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	# Le client
	var client := TransportWebRTCSimule.new()
	_check(client.rejoindre("K7Q2XM") == OK and client.url == "ws://localhost:8787/v1/rejoindre/K7Q2XM" and client.pair() == null
		and client.servir(),
		"rejoindre : /v1/rejoindre/K7Q2XM s'ouvre, pas encore de pair (son identifiant vient de la salle)")
````

par :

````gdscript
	# Le client
	var client := TransportWebRTCSimule.new()
	_check(client.rejoindre("K7Q2XM") == OK and client.url == URL_WORKER + "/v1/rejoindre/K7Q2XM" and client.pair() == null
		and client.servir(),
		"rejoindre : /v1/rejoindre/K7Q2XM s'ouvre, pas encore de pair (son identifiant vient de la salle)")
````


Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	reseau.fabrique_transport = Callable()

	# Port occupé, autre erreur ; changer de langue retraduit le message
	var occupant := ENetMultiplayerPeer.new()
````

par :

````gdscript
	reseau.fabrique_transport = Callable()

	# Phase 5 : un vrai `TransportWebRTC` dont la signalisation ne s'ouvre même pas (aucune adresse ; une adresse
	# que connect_to_url refuse d'emblée, comme le contenu mixte sur le Web) : « Service de connexion
	# indisponible », à la création comme à l'arrivée, rien d'ouvert ; après Rejoindre, le focus au code
	reseau.fabrique_transport = func(_port: int) -> Transport: return TransportWebRTC.new()
	var url_avant: Variant = ProjectSettings.get_setting(TransportWebRTC.REGLAGE_URL)
	var codes_avant: bool = ecran.codes_de_salle
	ecran.codes_de_salle = true
	var sans_service: Array = []
	for adresse: String in ["", "ws://exemple.net:99999"]:
		ProjectSettings.set_setting(TransportWebRTC.REGLAGE_URL, adresse)
		ecran.creer_partie()
		sans_service.append([ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne(), ecran.message.text])
		ecran.champ_code.text = "K7Q2XM"
		ecran.bouton_creer.grab_focus()
		ecran.rejoindre()
		sans_service.append([ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.champ_code.has_focus(), ecran.message.text])
	ProjectSettings.set_setting(TransportWebRTC.REGLAGE_URL, url_avant)
	ecran.codes_de_salle = codes_avant
	reseau.fabrique_transport = Callable()
	_check(sans_service == [[true, service], [true, service], [true, service], [true, service]],
		"la signalisation qui ne s'ouvre pas : « %s » à la création comme à l'arrivée, rien d'ouvert (%s)" % [service, sans_service])

	# Port occupé, autre erreur ; changer de langue retraduit le message
	var occupant := ENetMultiplayerPeer.new()
````


- [ ] **Step 2 : les lancer**

```bash
pgrep -f 'godot --headless' || echo "aucun autre godot"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u3.log" 2>&1; grep -E "❌|== " "$TMPDIR/u3.log" | cut -c1-260
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s3.log" 2>&1; grep -E "❌|== " "$TMPDIR/s3.log" | cut -c1-260
```

Expected (mesuré) : unitaires `== 4 échec(s) ==` : « l'adresse du Worker : wss://lelion-web.w3cdotorg.workers.dev publié … (ws://localhost:8787) », « la signalisation qui ne s'ouvre pas : ERR_CANT_CONNECT … ([[31, true, false, 31, 31], [31, true, false, 31, 31]]) », « héberger : le pair serveur existe … », « rejoindre : /v1/rejoindre/K7Q2XM s'ouvre … » ; smoke `== 1 échec(s) ==` : « la signalisation qui ne s'ouvre pas : « Service de connexion indisponible, réessaie dans un instant. » … ([[true, "Impossible d'héberger (erreur 31)"], [true, "Impossible de rejoindre (erreur 31)"], … »).

- [ ] **Step 3 : l'adresse, ses variantes, l'échec synchrone**

Dans `project.godot`, remplacer :

````ini

page/url="https://w3cdotorg.github.io/LeLion-web/"
signalisation/url="ws://localhost:8787"

[rendering]
````

par :

````ini

page/url="https://w3cdotorg.github.io/LeLion-web/"
signalisation/url="wss://lelion-web.w3cdotorg.workers.dev"
signalisation/url.pilote="ws://localhost:8787"

[rendering]
````


Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
## spec §10, diagnostic de l'essai réel).

## Le réglage de projet de l'adresse du Worker (spec §11), et sa valeur sans réglage : `wrangler dev`.
const REGLAGE_URL := "lelion/signalisation/url"
const URL_SIGNALISATION := "ws://localhost:8787"
const CHEMIN_CREER := "/v1/creer"
const CHEMIN_REJOINDRE := "/v1/rejoindre/"
````

par :

````gdscript
## spec §10, diagnostic de l'essai réel).

## Le réglage de projet de l'adresse du Worker (spec §11, sans chemin : les routes portent la version du
## protocole, `/v1/…`) : le Worker déployé (`wss://`) ; dans l'export « Web pilote » du test de bout en bout,
## `wrangler dev` sur ce poste (sa fonctionnalité `pilote` choisit `lelion/signalisation/url.pilote`).
## Sans réglage, aucune adresse : la signalisation ne s'ouvre pas (ERR_CANT_CONNECT).
const REGLAGE_URL := "lelion/signalisation/url"
const URL_SIGNALISATION := ""
const CHEMIN_CREER := "/v1/creer"
const CHEMIN_REJOINDRE := "/v1/rejoindre/"
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
	if erreur != OK:
		return erreur
	erreur = _ouvrir_socket(url_signalisation() + CHEMIN_CREER)
	if erreur != OK:
		return erreur
	_hote = true
	_poser_pair(pair_hote)
````

par :

````gdscript
	if erreur != OK:
		return erreur
	if _ouvrir_signalisation(CHEMIN_CREER) != OK:
		return ERR_CANT_CONNECT
	_hote = true
	_poser_pair(pair_hote)
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript

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
````

par :

````gdscript

## Un code qui n'est pas un code de salle (`CodeSalle.valide`, déjà normalisé), l'adresse `ip:port` d'un
## hôte ENet comprise : ERR_INVALID_PARAMETER, sans rien tenter. Une signalisation qui ne peut même pas
## s'ouvrir : ERR_CANT_CONNECT (`_ouvrir_signalisation`), comme pour `heberger()`.
func rejoindre(code: String) -> Error:
	if not CodeSalle.valide(code):
		return ERR_INVALID_PARAMETER
	if _ouvrir_signalisation(CHEMIN_REJOINDRE + code) != OK:
		return ERR_CANT_CONNECT
	_hote = false
	_demarrer()
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript


## L'adresse du Worker (le réglage REGLAGE_URL, URL_SIGNALISATION sans lui), sans « / » final.
static func url_signalisation() -> String:
	return str(ProjectSettings.get_setting(REGLAGE_URL, URL_SIGNALISATION)).trim_suffix("/")


````

par :

````gdscript


## L'adresse du Worker (le réglage REGLAGE_URL, URL_SIGNALISATION sans lui), sans espaces ni « / » final. Lu
## avec ses variantes (`get_setting_with_override`) : `get_setting` ignore `lelion/signalisation/url.pilote`, et
## l'export « Web pilote » parlerait au Worker déployé (vu en phase 5).
static func url_signalisation() -> String:
	if not ProjectSettings.has_setting(REGLAGE_URL):
		return URL_SIGNALISATION
	return str(ProjectSettings.get_setting_with_override(REGLAGE_URL)).strip_edges().trim_suffix("/")


````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
func _envoyer(message: Dictionary) -> void:
	_file.append(JSON.stringify(message))


````

par :

````gdscript
func _envoyer(message: Dictionary) -> void:
	_file.append(JSON.stringify(message))


## Ouvre la socket de signalisation vers `chemin` du Worker (`url_signalisation`). Sans adresse, ou si la
## socket ne peut même pas s'ouvrir (`connect_to_url` refuse d'emblée : une adresse mal formée ; sur le Web, un
## `ws://` depuis une page `https://`, le contenu mixte) : ERR_CANT_CONNECT, que l'écran En ligne dit « Service
## de connexion indisponible » (spec §9), rien d'ouvert, la raison au journal.
func _ouvrir_signalisation(chemin: String) -> Error:
	var base := url_signalisation()
	if base.is_empty():
		push_warning("Signalisation : aucune adresse (réglage %s)" % REGLAGE_URL)
		return ERR_CANT_CONNECT
	var erreur := _ouvrir_socket(base + chemin)
	if erreur != OK:
		push_warning("Signalisation : %s ne s'ouvre pas (erreur %d)" % [base + chemin, erreur])
		return ERR_CANT_CONNECT
	return OK


````


Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript

## Crée une partie avec le pseudo saisi : sur le Web, en WebRTC (`TransportWebRTC`), le salon s'ouvre à la
## salle de la signalisation, qui donne son code (CREATION d'ici là, ou l'échec et son message) ; hors du
## Web, en ENet sur `port_jeu`, tout de suite.
func creer_partie() -> void:
````

par :

````gdscript

## Crée une partie avec le pseudo saisi : sur le Web, en WebRTC (`TransportWebRTC`), le salon s'ouvre à la
## salle de la signalisation, qui donne son code (CREATION d'ici là, ou l'échec et son message ; une
## signalisation qui ne s'ouvre même pas, ERR_CANT_CONNECT : « Service de connexion indisponible ») ; hors du
## Web, en ENet sur `port_jeu`, tout de suite.
func creer_partie() -> void:
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
	if erreur == ERR_UNAVAILABLE:
		_afficher_message("ENLIGNE_INDISPONIBLE", [], true)
	elif erreur == ERR_CANT_CREATE:
		_afficher_message("RESEAU_PORT_OCCUPE", [port_jeu], true)
````

par :

````gdscript
	if erreur == ERR_UNAVAILABLE:
		_afficher_message("ENLIGNE_INDISPONIBLE", [], true)
	elif erreur == ERR_CANT_CONNECT:
		_afficher_message("ENLIGNE_SERVICE_INDISPONIBLE", [], true)
	elif erreur == ERR_CANT_CREATE:
		_afficher_message("RESEAU_PORT_OCCUPE", [port_jeu], true)
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
	if erreur == ERR_UNAVAILABLE:
		_afficher_message("ENLIGNE_INDISPONIBLE", [], true)
		return
	if erreur != OK:
````

par :

````gdscript
	if erreur == ERR_UNAVAILABLE:
		_afficher_message("ENLIGNE_INDISPONIBLE", [], true)
		return
	if erreur == ERR_CANT_CONNECT:
		# La signalisation ne s'ouvre même pas (`TransportWebRTC._ouvrir_signalisation`) : le code n'y est pour rien.
		_afficher_message("ENLIGNE_SERVICE_INDISPONIBLE", [], true)
		champ_code.grab_focus()
		return
	if erreur != OK:
````


- [ ] **Step 4 : les relancer**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u3.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u3.log"; grep -c "✅" "$TMPDIR/u3.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s3.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s3.log"; grep -c "✅" "$TMPDIR/s3.log"
grep -c localhost Scripts/TransportWebRTC.gd
```

Expected (mesuré) : `unitaires 0`, `PROTOCOLE 0.21 1188810746 (67 lignes)`, `== 0 échec(s) ==`, `576` ✅ ; `smoke 0`, `== 0 échec(s) ==`, `473` ✅ ; `0`. Dans les sorties, le bruit voulu (Global Constraints) : `WARNING: Signalisation : aucune adresse …`, `ERROR: Invalid URL: ws://exemple.net:99999/…`.

- [ ] **Step 5 : commit**

```bash
git add project.godot Scripts/TransportWebRTC.gd Scripts/EcranEnLigne.gd tests/unitaires.gd tests/smoke_test.gd
git commit -m "L'adresse du Worker déployé (wss://lelion-web.w3cdotorg.workers.dev), ws://localhost:8787 sous la fonctionnalité pilote : le réglage lu avec ses variantes (get_setting les ignore, et l'export Web pilote parlait au Worker déployé) ; une signalisation qui ne s'ouvre même pas : ERR_CANT_CONNECT, « Service de connexion indisponible »

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 4 : les gardes de l'export publié (`tests/export_publie.gd`, le contrôle Chromium)

**Files:**
- Create: `tests/export_publie.gd` (+ `tests/export_publie.gd.uid`, créé par l'import)
- Create: `tests/web/playwright.publie.config.js`
- Create: `tests/web/export_publie.spec.js`
- Modify: `tests/web/playwright.config.js` (`testIgnore`, l'en-tête)

**Interfaces:**
- `godot --headless --script tests/export_publie.gd -- --pck=<index.pck>` : `== 0 échec(s) ==` et code 0 si l'export est publiable ; une ligne `VERSION_EXPORT 0.21`. `static func lire_reglages(octets: PackedByteArray) -> Dictionary`.
- `npx playwright test -c playwright.publie.config.js` (depuis `tests/web/`) : sert `../../export/web` sur `http://localhost:8061` ; deux tests `@publie` ; `SIGNALISATION_EN_DIRECT=1` : sans simulation, face au Worker de `project.godot` (le second test est alors sauté).
- `playwright.config.js` : `testIgnore: ["export_publie.spec.js", "en_direct.spec.js"]` (le second vient en Task 5).

- [ ] **Step 1 : le garde et le contrôle**

Créer `tests/export_publie.gd` :

````gdscript
extends SceneTree
## Le garde de l'export publié (phase 5, spec §11) : godot --headless --script tests/export_publie.gd -- --pck=<index.pck>
## Lit les réglages que l'export a écrits dans son paquet (`project.binary`, monté par `load_resource_pack`) et
## vérifie ce que la page publiée sera : sans la fonctionnalité `pilote` (le pilote du bout en bout reste inerte),
## l'adresse du Worker celle de project.godot, en `wss://`, et aucune adresse locale ailleurs que sous une variante
## `.pilote` (que seul l'export « Web pilote » choisit) ; la version celle de project.godot (le tag la vérifie).
## Sort en 0 sur `== 0 échec(s) ==`.

const REGLAGE_URL := "lelion/signalisation/url"

var _echecs := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("== garde de l'export publié ==")
	var pck := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pck="):
			pck = argument.trim_prefix("--pck=")
	_check(not pck.is_empty() and FileAccess.file_exists(pck), "(pré-condition) le paquet existe : « %s »" % pck)
	var reglages := {}
	if _echecs == 0:
		_check(ProjectSettings.load_resource_pack(pck, false), "(pré-condition) le paquet se monte : %s" % pck)
		reglages = lire_reglages(FileAccess.get_file_as_bytes("res://project.binary"))
	_check(not reglages.is_empty(), "(pré-condition) les réglages de l'export se lisent (%d)" % reglages.size())
	if not reglages.is_empty():
		var fonctions := str(reglages.get("_custom_features", "")).replace(" ", "").split(",", false)
		_check(not fonctions.has("pilote"), "l'export publié n'a pas la fonctionnalité pilote (%s)" % [fonctions])
		var url := str(reglages.get(REGLAGE_URL, ""))
		var attendue := str(ProjectSettings.get_setting(REGLAGE_URL, ""))
		_check(url == attendue and url.begins_with("wss://") and not url.contains("localhost"),
			"l'adresse du Worker de l'export : %s, celle de project.godot (%s), en wss://" % [url, attendue])
		var locales: Array[String] = []
		for cle: String in reglages:
			if str(reglages[cle]).contains("localhost") and not cle.ends_with(".pilote"):
				locales.append(cle)
		_check(locales.is_empty(), "aucune adresse locale hors des variantes .pilote (%s)" % [locales])
		var version := str(reglages.get("application/config/version", ""))
		_check(version == str(ProjectSettings.get_setting("application/config/version")),
			"la version de l'export : %s, celle de project.godot" % version)
		print("VERSION_EXPORT %s" % version)
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## Les réglages d'un `project.binary` (`ProjectSettings.save_custom`) : « ECFG », leur nombre (32 bits), puis
## chacun : sa clé (longueur 32 bits, UTF-8), sa valeur (longueur 32 bits, une Variant encodée) ; vide s'il est
## illisible.
static func lire_reglages(octets: PackedByteArray) -> Dictionary:
	if octets.size() < 8 or octets.slice(0, 4).get_string_from_ascii() != "ECFG":
		return {}
	var reglages := {}
	var position := 8
	for i in octets.decode_u32(4):
		if position + 4 > octets.size():
			return {}
		var longueur := octets.decode_u32(position)
		var cle := octets.slice(position + 4, position + 4 + longueur).get_string_from_utf8()
		position += 4 + longueur
		if position + 4 > octets.size():
			return {}
		longueur = octets.decode_u32(position)
		reglages[cle] = bytes_to_var(octets.slice(position + 4, position + 4 + longueur))
		position += 4 + longueur
	return reglages


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ✅ " + message)
	else:
		_echecs += 1
		print("  ❌ " + message)
````


Créer `tests/web/playwright.publie.config.js` :

````js
// Le contrôle de l'export publié (phase 5, spec §11) : l'export « Web » (export/web, celui que Pages publie),
// servi sur http://localhost:8061, dans Chromium. Rien du test de bout en bout : ni pilote, ni wrangler dev.
// Par défaut, la signalisation est simulée par la page (routeWebSocket : aucun réseau) ; avec
// SIGNALISATION_EN_DIRECT=1 (le job de déploiement, le Worker venant d'être déployé), la page parle au vrai
// Worker, qui refuse son origine (http://localhost:8061 n'est pas la page publiée).
// L'export se fait avant : godot --headless --export-release Web export/web/index.html.
import { defineConfig } from "@playwright/test";

export default defineConfig({
	testDir: ".",
	testMatch: "export_publie.spec.js",
	workers: 1,
	retries: 0,
	timeout: 120_000,
	reporter: [["list"]],
	use: { baseURL: "http://localhost:8061", locale: "fr-FR", browserName: "chromium" },
	webServer: {
		command: "python3 -m http.server 8061 --bind 127.0.0.1 --directory ../../export/web",
		url: "http://127.0.0.1:8061/index.html",
		stderr: "ignore",
		reuseExistingServer: false,
		timeout: 30_000,
	},
});
````


Créer `tests/web/export_publie.spec.js` :

````js
// L'export publié tel que Pages le sert (phase 5, spec §11 ; playwright.publie.config.js) : sans pilote (ni
// window.lelionPilote, ni « PILOTE PRET »), il parle au Worker de project.godot (lelion/signalisation/url), et
// un refus de la signalisation s'y lit au journal. La page s'ouvre sur un lien d'invitation : le titre passe à
// l'écran En ligne, le code rempli, le focus au pseudo ; Entrée (deux fois : l'édition, puis la validation)
// lance Rejoindre, sans viser de pixels.
import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

const PROJET = readFileSync(new URL("../../project.godot", import.meta.url), "utf8");
const URL_WORKER = /^signalisation\/url="([^"]*)"$/m.exec(PROJET)?.[1];
const EN_DIRECT = process.env.SIGNALISATION_EN_DIRECT === "1";
const CODE = "K7Q2XM";

test("l'export publié : le pilote inerte, la signalisation du Worker de project.godot @publie", async ({ page }) => {
	expect(URL_WORKER, "lelion/signalisation/url de project.godot").toMatch(/^wss:\/\/[a-z0-9.-]+$/);
	const lignes = [];
	page.on("console", (message) => lignes.push(message.text()));
	page.on("pageerror", (erreur) => lignes.push(`PAGEERROR ${erreur.message}`));
	const sockets = [];
	if (EN_DIRECT) {
		page.on("websocket", (ws) => sockets.push(ws.url()));
	} else {
		// La salle simulée refuse l'origine, comme le vrai Worker refuse une page servie hors de Pages.
		await page.routeWebSocket(/.*/, (ws) => {
			sockets.push(ws.url());
			ws.send(JSON.stringify({ t: "erreur", raison: "origine" }));
			ws.close({ code: 1000, reason: "origine" });
		});
	}
	await page.goto(`/?salle=${CODE}`);
	await expect.poll(() => lignes.some((ligne) => ligne.startsWith("Godot Engine v")), { timeout: 60_000 }).toBe(true);
	await expect
		.poll(
			async () => {
				if (sockets.length === 0) await page.keyboard.press("Enter");
				return sockets.length;
			},
			{ timeout: 60_000, intervals: [500] },
		)
		.toBeGreaterThan(0);
	expect(sockets).toEqual([`${URL_WORKER}/v1/rejoindre/${CODE}`]);
	await expect
		.poll(() => lignes.some((ligne) => ligne.includes("Signalisation : erreur « origine »")), { timeout: 15_000 })
		.toBe(true);
	expect(await page.evaluate(() => typeof window.lelionPilote)).toBe("undefined");
	expect(lignes.filter((ligne) => /PILOTE PRET|SCRIPT ERROR|PAGEERROR|ws:\/\/localhost/.test(ligne))).toEqual([]);
	console.log(`Export publié : ${sockets[0]}, refus lu au journal (${EN_DIRECT ? "Worker déployé" : "signalisation simulée"})`);
});

test("l'export publié : les canaux non fiables gardent un paquet 100 ms au plus (le correctif des canaux, hors du pilote) @publie", async ({ page }) => {
	test.skip(EN_DIRECT, "la salle simulée seulement : le Worker déployé refuse cette origine avant toute connexion");
	const lignes = [];
	page.on("console", (message) => lignes.push(message.text()));
	page.on("pageerror", (erreur) => lignes.push(`PAGEERROR ${erreur.message}`));
	// Ce qu'on colle dans la console du navigateur pour le contrôle à la main (docs/essai-en-ligne.md), posé avant
	// le jeu : chaque canal créé y est écrit, tel que le navigateur l'a pris (le correctif s'enroule par-dessus).
	await page.addInitScript(() => {
		const creer = RTCPeerConnection.prototype.createDataChannel;
		RTCPeerConnection.prototype.createDataChannel = function (nom, options) {
			const canal = creer.call(this, nom, options);
			console.log(`canal ${nom} ordonné=${canal.ordered} durée=${canal.maxPacketLifeTime} renvois=${canal.maxRetransmits}`);
			return canal;
		};
	});
	// La salle simulée accueille ce poste (son identifiant, aucun serveur ICE) : son pair naît, et ses canaux.
	await page.routeWebSocket(/.*/, (ws) => ws.send(JSON.stringify({ t: "bienvenue", id: 5, ice: [] })));
	await page.goto(`/?salle=${CODE}`);
	await expect.poll(() => lignes.some((ligne) => ligne.startsWith("Godot Engine v")), { timeout: 60_000 }).toBe(true);
	const canaux = () => lignes.filter((ligne) => ligne.startsWith("canal "));
	await expect
		.poll(
			async () => {
				if (canaux().length === 0) await page.keyboard.press("Enter");
				return canaux().length;
			},
			{ timeout: 60_000, intervals: [500] },
		)
		.toBeGreaterThanOrEqual(4);
	const durees = canaux().map((ligne) => /durée=(\S+)/.exec(ligne)[1]);
	expect(durees.filter((duree) => duree === "100"), canaux().join(" | ")).toHaveLength(2);
	expect(lignes.filter((ligne) => /SCRIPT ERROR|PAGEERROR/.test(ligne))).toEqual([]);
	console.log(`Canaux de l'export publié : ${canaux().join(" | ")}`);
});
````


Dans `tests/web/playwright.config.js`, remplacer :

````js
// Le test de bout en bout du jeu en ligne (spec §10) : l'export « Web pilote » servi sur
// http://localhost:8060 (l'origine que la signalisation admet, http://localhost:* ; pas 127.0.0.1), en IPv4
// seulement (une page chargée par ::1, Firefox ne trouve aucun candidat ICE dans un conteneur sans IPv6),
// la signalisation en local (`wrangler dev` sur ws://localhost:8787, l'adresse par défaut du réglage
// lelion/signalisation/url), puis Chromium et Firefox (la manche à trois pages), WebKit (Copier le lien) et un
// mobile émulé par Chromium (un Android en paysage, au doigt, face à un hôte de bureau).
// L'export se fait avant : godot --headless --export-release "Web pilote" export/web-pilote/index.html.
````

par :

````js
// Le test de bout en bout du jeu en ligne (spec §10) : l'export « Web pilote » servi sur
// http://localhost:8060 (l'origine que `npm run dev` admet, http://localhost:* ; pas 127.0.0.1), en IPv4
// seulement (une page chargée par ::1, Firefox ne trouve aucun candidat ICE dans un conteneur sans IPv6),
// la signalisation en local (`wrangler dev` sur ws://localhost:8787, la variante lelion/signalisation/url.pilote
// du réglage, que choisit l'export « Web pilote »), puis Chromium et Firefox (la manche à trois pages), WebKit (Copier le lien) et un
// mobile émulé par Chromium (un Android en paysage, au doigt, face à un hôte de bureau).
// L'export se fait avant : godot --headless --export-release "Web pilote" export/web-pilote/index.html.
````

Dans `tests/web/playwright.config.js`, remplacer :

````js
export default defineConfig({
	testDir: ".",
	// Trois pages de 40 Mo de WebAssembly par test : un test à la fois.
	workers: 1,
````

par :

````js
export default defineConfig({
	testDir: ".",
	// Le contrôle de l'export publié et la partie sur la page déployée ont leurs propres configurations
	// (playwright.publie.config.js, playwright.en_direct.config.js).
	testIgnore: ["export_publie.spec.js", "en_direct.spec.js"],
	// Trois pages de 40 Mo de WebAssembly par test : un test à la fois.
	workers: 1,
````


- [ ] **Step 2 : les deux exports, le garde sur chacun**

```bash
timeout 300 godot --headless --import . > /dev/null 2>&1; ls tests/export_publie.gd.uid
rm -rf export; mkdir -p export/web export/web-pilote; touch export/.gdignore
timeout 600 godot --headless --export-release Web export/web/index.html > "$TMPDIR/e.log" 2>&1; echo "export $?"
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
ls export/web | tr '\n' ' '; echo
for d in web web-pilote; do timeout 60 godot --headless --script tests/export_publie.gd -- --pck=export/$d/index.pck 2>&1 | grep -E "❌|== |VERSION"; done
grep -c viewport-fit export/web/index.html
```

Expected (mesuré) : le `.uid` ; `export 0`, `export pilote 0` ; `index.apple-touch-icon.png index.audio.position.worklet.js index.audio.worklet.js index.html index.icon.png index.js index.pck index.png index.wasm` (aucun `.import` : `export/.gdignore`) ; pour `web` : `VERSION_EXPORT 0.21`, `== 0 échec(s) ==` ; pour `web-pilote` : `❌ l'export publié n'a pas la fonctionnalité pilote (["pilote"])`, `VERSION_EXPORT 0.21`, `== 1 échec(s) ==` ; `0`.

- [ ] **Step 3 : le contrôle Chromium sur l'export publié, puis sur l'export « Web pilote »** (celui-ci doit échouer)

```bash
docker run --rm --init -v "$PWD":/depot -v lelion5-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble \
  bash -c 'npm ci --silent && npx playwright test -c playwright.publie.config.js' > "$TMPDIR/publie.log" 2>&1; echo "publié $?"
grep -E "✓|✘|passed|failed|Export publié|Canaux" "$TMPDIR/publie.log"
sed 's|--directory ../../export/web"|--directory ../../export/web-pilote"|' tests/web/playwright.publie.config.js > tests/web/playwright.negatif.config.js
docker run --rm --init -v "$PWD":/depot -v lelion5-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble \
  bash -c 'npx playwright test -c playwright.negatif.config.js' > "$TMPDIR/negatif.log" 2>&1; echo "négatif $?"
grep -E "^\s+[-+]\s+\"|Expected|Received|passed|failed" "$TMPDIR/negatif.log" | head -6
rm tests/web/playwright.negatif.config.js
```

Expected (mesuré) : `publié 0`, `Export publié : wss://lelion-web.w3cdotorg.workers.dev/v1/rejoindre/K7Q2XM, refus lu au journal (signalisation simulée)`, `Canaux de l'export publié : canal reliable ordonné=true durée=null renvois=null | canal ordered ordonné=true durée=100 renvois=null | canal unreliable ordonné=false durée=100 renvois=null | canal 4 ordonné=true durée=null renvois=null`, `2 passed` (moins de 5 s) ; `négatif 1`, `-   "wss://lelion-web.w3cdotorg.workers.dev/v1/rejoindre/K7Q2XM",` / `+   "ws://localhost:8787/v1/rejoindre/K7Q2XM",` (l'export « Web pilote » choisit sa variante ; sans `get_setting_with_override`, la Task 3, ce contrôle passait sur l'adresse publiée : c'est ainsi que l'écart 6 a été trouvé) ; `git status --short` ne montre pas `playwright.negatif.config.js`.

- [ ] **Step 4 : commit**

```bash
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' tests/*.gd tests/web/*.js
git add tests/export_publie.gd tests/export_publie.gd.uid tests/web/playwright.publie.config.js tests/web/export_publie.spec.js tests/web/playwright.config.js
git commit -m "Gardes de l'export publié : ses réglages (sans pilote, l'adresse du Worker en wss://, aucune adresse locale hors des variantes .pilote) ; dans Chromium, sans pilote, la signalisation du Worker de project.godot, les canaux non fiables à 100 ms

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 5 : la partie de contrôle sur la page déployée (`tests/web/en_direct.spec.js`)

**Files:**
- Create: `tests/web/playwright.en_direct.config.js`
- Create: `tests/web/en_direct.spec.js`

**Interfaces:**
- `LELION_PAGE=<adresse de la page> npx playwright test -c playwright.en_direct.config.js` (depuis `tests/web/` ; par défaut `https://w3cdotorg.github.io/LeLion-web/`) : un test, sans serveur lancé ; sa ligne `Salle XXXXXX : <socket de l'hôte> ; <socket de l'invité> ; canal ouvert ; ICE […]`.

- [ ] **Step 1 : la partie**

Créer `tests/web/playwright.en_direct.config.js` :

````js
// La partie de contrôle sur la page déployée (phase 5) : deux pages Chromium, un hôte qui crée par le clavier,
// un invité qui rejoint par le lien, reliés en WebRTC par le Worker de la page. LELION_PAGE : l'adresse de la
// page (par défaut celle de GitHub Pages). Rien n'est servi ni lancé ici : la page et son Worker existent déjà.
import { defineConfig } from "@playwright/test";

export default defineConfig({
	testDir: ".",
	testMatch: "en_direct.spec.js",
	workers: 1,
	retries: 0,
	timeout: 180_000,
	reporter: [["list"]],
	use: { baseURL: process.env.LELION_PAGE ?? "https://w3cdotorg.github.io/LeLion-web/", locale: "fr-FR", browserName: "chromium" },
});
````


Créer `tests/web/en_direct.spec.js` :

````js
// Une partie de contrôle sur la page déployée (phase 5, playwright.en_direct.config.js) : la page telle que les
// joueurs l'ouvrent (sans pilote), menée au clavier comme un joueur : l'hôte, sur le titre, Droite (Multijoueur)
// puis Entrée, puis Entrée (Créer une partie, au focus) ; son code se lit dans les messages de la signalisation
// (`salle`) ; l'invité ouvre le lien d'invitation et fait Entrée (Rejoindre). Réussite : l'hôte dit `ouvert` à
// la salle (le canal WebRTC des deux pages est ouvert), les serveurs ICE sont du STUN seul.
import { expect, test } from "@playwright/test";

/** Une page neuve (son propre contexte) qui note sa console et les messages de ses WebSockets. */
async function ouvrir(navigateur, chemin) {
	const page = await (await navigateur.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
	const journal = { lignes: [], recus: [], envoyes: [], sockets: [] };
	page.on("console", (message) => journal.lignes.push(message.text()));
	page.on("pageerror", (erreur) => journal.lignes.push(`PAGEERROR ${erreur.message}`));
	page.on("websocket", (ws) => {
		journal.sockets.push(ws.url());
		ws.on("framereceived", (trame) => journal.recus.push(JSON.parse(trame.payload)));
		ws.on("framesent", (trame) => journal.envoyes.push(JSON.parse(trame.payload)));
	});
	await page.goto(chemin);
	await expect.poll(() => journal.lignes.some((ligne) => ligne.startsWith("Godot Engine v")), { timeout: 90_000 }).toBe(true);
	return { page, journal };
}

/** Appuie sur `touches` (une fois chacune, dans l'ordre) jusqu'à ce que `condition` soit vraie. */
async function jusqua(page, touches, condition, message, delai = 60_000) {
	await expect
		.poll(
			async () => {
				if (!condition()) for (const touche of touches) await page.keyboard.press(touche);
				return condition();
			},
			{ message, timeout: delai, intervals: [1500] },
		)
		.toBe(true);
}

test("deux pages jouent ensemble sur la page déployée : une salle, une arrivée, le canal WebRTC ouvert, STUN seul", async ({ browser }) => {
	const hote = await ouvrir(browser, "./");
	const salle = () => hote.journal.recus.find((message) => message.t === "salle");
	// Le titre a le focus sur Jouer : Droite va à Multijoueur ; l'écran En ligne a le focus sur Créer une partie.
	await jusqua(hote.page, ["ArrowRight", "Enter", "Enter"], () => salle() !== undefined, "l'hôte crée une partie");
	const { code, ice } = salle();
	expect(code).toMatch(/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/);
	const invite = await ouvrir(browser, `./?salle=${code}`);
	const ouvert = () => hote.journal.envoyes.some((message) => message.t === "ouvert");
	await jusqua(invite.page, ["Enter"], () => invite.journal.sockets.length > 0, "l'invité rejoint par le lien");
	await expect.poll(ouvert, { message: "le canal WebRTC entre les deux pages s'ouvre (l'hôte dit ouvert)", timeout: 30_000 }).toBe(true);
	const bienvenue = invite.journal.recus.find((message) => message.t === "bienvenue");
	for (const serveurs of [ice, bienvenue?.ice]) {
		const urls = (serveurs ?? []).flatMap((serveur) => serveur.urls);
		expect(urls.length > 0 && urls.every((url) => url.startsWith("stun:")), JSON.stringify(serveurs)).toBe(true);
	}
	expect(await hote.page.evaluate(() => typeof window.lelionPilote), "le pilote du bout en bout absent de la page").toBe("undefined");
	const erreurs = [hote, invite].flatMap(({ journal }) => journal.lignes.filter((ligne) => /SCRIPT ERROR|ERROR:|PAGEERROR|PILOTE PRET/.test(ligne)));
	expect(erreurs).toEqual([]);
	console.log(`Salle ${code} : ${hote.journal.sockets[0]} ; ${invite.journal.sockets[0]} ; canal ouvert ; ICE ${JSON.stringify(ice)}`);
});
````


- [ ] **Step 2 : la jouer en local, sur un export « Web » qui vise `wrangler dev`** (le temps de l'export, l'adresse de `project.godot` est changée, puis rendue par git)

```bash
pgrep -f 'godot --headless' || echo "aucun autre godot"
sed -i '' 's|^signalisation/url="wss://lelion-web.w3cdotorg.workers.dev"$|signalisation/url="ws://localhost:8787"|' project.godot
mkdir -p export/web-local; touch export/.gdignore
timeout 600 godot --headless --export-release Web export/web-local/index.html > "$TMPDIR/el.log" 2>&1; echo "export local $?"
git checkout -- project.godot; git status --short project.godot; grep -c 'url="wss://lelion-web' project.godot
docker run --rm --init -v "$PWD":/depot -v lelion5-modules-signalisation:/depot/signalisation/node_modules -v lelion5-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble \
  bash -c '(cd ../../signalisation && npm ci --silent) && (python3 -m http.server 8060 --bind 127.0.0.1 --directory ../../export/web-local > /dev/null 2>&1 &) && (WRANGLER_SEND_METRICS=false npm --prefix ../../signalisation run dev -- --port 8787 --ip localhost > /tmp/wd.log 2>&1 &) && for i in $(seq 90); do curl -s -o /dev/null localhost:8787 && break; sleep 1; done; LELION_PAGE=http://localhost:8060/ npx playwright test -c playwright.en_direct.config.js' > "$TMPDIR/en_direct.log" 2>&1; echo "en direct (local) $?"
grep -E "Salle|✓|✘|passed|failed" "$TMPDIR/en_direct.log"
rm -rf export/web-local
```

Expected (mesuré) : `export local 0` ; rien pour `git status` ; `1` ; `en direct (local) 0`, `Salle XXXXXX : ws://localhost:8787/v1/creer ; ws://localhost:8787/v1/rejoindre/XXXXXX ; canal ouvert ; ICE [{"urls":["stun:stun.cloudflare.com:3478","stun:stun.l.google.com:19302"]}]`, `1 passed` (6,8 s mesurées).

- [ ] **Step 3 : commit**

```bash
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' tests/web/*.js
git add tests/web/playwright.en_direct.config.js tests/web/en_direct.spec.js
git commit -m "La partie de contrôle sur la page déployée : deux pages menées au clavier, une salle, une arrivée par le lien, le canal WebRTC ouvert, STUN seul, sans pilote

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 6 : la CI (l'export gardé sur chaque PR, le déploiement sur un tag)

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- `on.push.tags: ["v*"]` ; `permissions: contents: read`.
- `test-et-export` : `export/.gdignore`, l'étape « Garder l'export publié … ».
- `bout-en-bout` : l'export « Web » en plus, l'étape « Contrôle de l'export publié … (simulée) ».
- `deploiement-worker` (`needs` les trois, `if` tag) : le tag = `v` + `config/version`, `npm ci`, `npx wrangler deploy` (secrets `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`), la sonde.
- `deploiement-page` (`needs: [deploiement-worker]`, `if` tag, environnement `github-pages`, `pages: write`, `id-token: write`) : l'artefact `LeLion-web`, Playwright et Chromium, le contrôle face au Worker déployé (`SIGNALISATION_EN_DIRECT=1`), `upload-pages-artifact@v5` (`export/web`), `deploy-pages@v5` (`id: pages`), le paquet servi, la partie de contrôle (`LELION_PAGE` = `steps.pages.outputs.page_url`).

- [ ] **Step 1 : le workflow**

Dans `.github/workflows/ci.yml`, remplacer :

````yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

env:
````

par :

````yaml
name: CI

# Sur main et sur chaque PR : les tests, l'export Web en artefact ; rien n'est mis en ligne. Sur un tag vX.Y
# (= application/config/version, spec §11), les mêmes jobs, puis, s'ils sont tous verts, le Worker
# (wrangler deploy), puis la page (GitHub Pages) : l'artefact LeLion-web de ce passage, rien d'autre.
on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:

permissions:
  contents: read

env:
````

Dans `.github/workflows/ci.yml`, remplacer :

````yaml
        run: |
          mkdir -p export/web
          timeout 600 godot --headless --export-release Web export/web/index.html
          test -f export/web/index.html

      - name: Publier l'export Web (artefact)
````

par :

````yaml
        run: |
          mkdir -p export/web
          touch export/.gdignore  # sinon l'éditeur importe les images de l'export et y laisse des .import
          timeout 600 godot --headless --export-release Web export/web/index.html
          test -f export/web/index.html

      - name: Garder l'export publié (sans pilote, l'adresse du Worker déployé, rien que les fichiers de la page)
        shell: bash
        run: |
          set -o pipefail
          timeout 120 godot --headless --script tests/export_publie.gd -- --pck=export/web/index.pck 2>&1 | tee export_publie.log
          if grep -nE "SCRIPT ERROR|❌" export_publie.log || ! grep -q "== 0 échec(s) ==" export_publie.log; then echo "::error::l'export Web n'est pas publiable"; exit 1; fi
          attendus="index.apple-touch-icon.png index.audio.position.worklet.js index.audio.worklet.js index.html index.icon.png index.js index.pck index.png index.wasm"
          trouves="$(find export/web -mindepth 1 -printf '%f\n' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
          [ "$trouves" = "$attendus" ] || { echo "::error::fichiers inattendus dans export/web : $trouves"; exit 1; }
          if grep -q "viewport-fit" export/web/index.html; then echo "::error::la page a viewport-fit (le modèle HTML par défaut, sans lui)"; exit 1; fi

      - name: Publier l'export Web (artefact)
````

Dans `.github/workflows/ci.yml`, remplacer :

````yaml
        run: godot --headless --import . || true

      - name: Exporter en Web, avec le pilote du test (préréglage « Web pilote »)
        shell: bash
        run: |
          mkdir -p export/web-pilote
          timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html
          test -f export/web-pilote/index.html

      - name: Installer Node
````

par :

````yaml
        run: godot --headless --import . || true

      - name: Exporter en Web, avec le pilote du test (préréglage « Web pilote »), et sans lui (« Web », le contrôle de l'export publié)
        shell: bash
        run: |
          mkdir -p export/web-pilote export/web
          touch export/.gdignore
          timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html
          timeout 600 godot --headless --export-release Web export/web/index.html
          test -f export/web-pilote/index.html && test -f export/web/index.html

      - name: Installer Node
````

Dans `.github/workflows/ci.yml`, remplacer :

````yaml
        run: xvfb-run -a npx playwright test

      - name: Publier le rapport Playwright (en cas d'échec)
        if: failure()
````

par :

````yaml
        run: xvfb-run -a npx playwright test

      - name: Contrôle de l'export publié (sans pilote, la signalisation du Worker de project.godot, simulée)
        working-directory: tests/web
        run: npx playwright test -c playwright.publie.config.js

      - name: Publier le rapport Playwright (en cas d'échec)
        if: failure()
````

Dans `.github/workflows/ci.yml`, remplacer :

````yaml
          path: tests/web/playwright-report
          retention-days: 7
````

par :

````yaml
          path: tests/web/playwright-report
          retention-days: 7

  deploiement-worker:
    name: Déploiement du Worker (tag vX.Y)
    if: startsWith(github.ref, 'refs/tags/v')
    needs: [test-et-export, signalisation, bout-en-bout]
    runs-on: ubuntu-latest
    timeout-minutes: 10
    concurrency:
      group: deploiement
      cancel-in-progress: false
    defaults:
      run:
        working-directory: signalisation
    steps:
      - uses: actions/checkout@v5

      - name: Le tag est la version du jeu (application/config/version)
        shell: bash
        run: |
          version="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' ../project.godot)"
          [ "$GITHUB_REF_NAME" = "v$version" ] || { echo "::error::le tag $GITHUB_REF_NAME n'est pas v$version (project.godot)"; exit 1; }

      - name: Installer Node
        uses: actions/setup-node@v6
        with:
          node-version: 24.21.0
          cache: npm
          cache-dependency-path: signalisation/package-lock.json

      - name: Installer les dépendances (package-lock.json)
        run: npm ci

      - name: Déployer (wrangler deploy ; sans secrets TURN, donc STUN seul)
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          WRANGLER_SEND_METRICS: "false"
        shell: bash
        run: |
          set -o pipefail
          npx wrangler deploy 2>&1 | tee "$RUNNER_TEMP/deploiement.log"
          url="$(sed -n 's/^signalisation\/url="\(.*\)"$/\1/p' ../project.godot)"
          grep -qF "https://${url#wss://}" "$RUNNER_TEMP/deploiement.log" \
            || echo "::warning::wrangler n'a pas écrit l'adresse https://${url#wss://} : la sonde tranche"

      - name: Sonder le Worker déployé (une salle depuis la page publiée, STUN seul ; localhost refusé)
        shell: bash
        run: node outils/sonder.mjs "$(sed -n 's/^signalisation\/url="\(.*\)"$/\1/p' ../project.godot)"

  deploiement-page:
    name: Déploiement de la page (GitHub Pages, tag vX.Y)
    if: startsWith(github.ref, 'refs/tags/v')
    needs: [deploiement-worker]
    runs-on: ubuntu-latest
    timeout-minutes: 15
    concurrency:
      group: deploiement
      cancel-in-progress: false
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.pages.outputs.page_url }}
    steps:
      - uses: actions/checkout@v5

      - name: Reprendre l'export Web de ce passage (artefact LeLion-web, gardé par test-et-export)
        uses: actions/download-artifact@v4
        with:
          name: LeLion-web
          path: export/web

      - name: Installer Node
        uses: actions/setup-node@v6
        with:
          node-version: 24.21.0
          cache: npm
          cache-dependency-path: tests/web/package-lock.json

      - name: Installer Playwright et Chromium (package-lock.json)
        working-directory: tests/web
        run: npm ci && npx playwright install --with-deps chromium

      - name: Contrôle de l'export publié face au Worker déployé (qui refuse une page servie hors de Pages)
        working-directory: tests/web
        env:
          SIGNALISATION_EN_DIRECT: "1"
        run: npx playwright test -c playwright.publie.config.js

      - name: Préparer la page (export/web seulement)
        uses: actions/upload-pages-artifact@v5
        with:
          path: export/web

      - name: Publier sur GitHub Pages
        id: pages
        uses: actions/deploy-pages@v5

      - name: La page publiée répond (index.html et le paquet de cette version)
        shell: bash
        run: |
          base="${{ steps.pages.outputs.page_url }}"
          for _ in $(seq 1 30); do
            taille="$(curl -sf "${base}index.pck?v=${GITHUB_SHA}" | wc -c | tr -d ' ')"
            [ "$taille" = "$(wc -c < export/web/index.pck | tr -d ' ')" ] && curl -sf "${base}?v=${GITHUB_SHA}" | grep -q "index.js" && { echo "page publiée : $base"; exit 0; }
            sleep 10
          done
          echo "::error::$base ne sert pas le paquet de cette version (taille ${taille:-?})"; exit 1

      - name: Une partie de contrôle sur la page publiée (deux pages Chromium, le Worker déployé, STUN seul)
        working-directory: tests/web
        env:
          LELION_PAGE: ${{ steps.pages.outputs.page_url }}
        run: npx playwright test -c playwright.en_direct.config.js
````


- [ ] **Step 2 : le vérifier sans GitHub**

```bash
actionlint .github/workflows/ci.yml && echo "actionlint ok"
python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/ci.yml')); j=d['jobs']; print(d[True]); print({k: (v.get('needs'), v.get('if')) for k, v in j.items()}); print(j['deploiement-page']['permissions'], d['permissions'])"
docker run --rm -v "$PWD":/d -w /d mcr.microsoft.com/playwright:v1.63.0-noble bash -c '
  attendus="index.apple-touch-icon.png index.audio.position.worklet.js index.audio.worklet.js index.html index.icon.png index.js index.pck index.png index.wasm"
  trouves="$(find export/web -mindepth 1 -printf "%f\n" | LC_ALL=C sort | tr "\n" " " | sed "s/ $//")"; [ "$trouves" = "$attendus" ] && echo "fichiers ok" || echo "ÉCART : $trouves"
  version="$(sed -n "s/^config\/version=\"\(.*\)\"$/\1/p" project.godot)"; GITHUB_REF_NAME=v0.21; [ "$GITHUB_REF_NAME" = "v$version" ] && echo "tag ok ($version)"
  GITHUB_REF_NAME=v0.20; [ "$GITHUB_REF_NAME" = "v$version" ] || echo "tag v0.20 refusé"
  url="$(sed -n "s/^signalisation\/url=\"\(.*\)\"$/\1/p" project.godot)"; echo "sonde : $url ; wrangler : https://${url#wss://}"'
```

Expected (mesuré) : `actionlint ok` (le workflow de `main` est déjà propre) ; `{'push': {'branches': ['main'], 'tags': ['v*']}, 'pull_request': None}` ; `{'test-et-export': (None, None), 'signalisation': (None, None), 'bout-en-bout': (None, None), 'deploiement-worker': (['test-et-export', 'signalisation', 'bout-en-bout'], "startsWith(github.ref, 'refs/tags/v')"), 'deploiement-page': (['deploiement-worker'], "startsWith(github.ref, 'refs/tags/v')")}` ; `{'pages': 'write', 'id-token': 'write'} {'contents': 'read'}` ; `fichiers ok`, `tag ok (0.21)`, `tag v0.20 refusé`, `sonde : wss://lelion-web.w3cdotorg.workers.dev ; wrangler : https://lelion-web.w3cdotorg.workers.dev` (l'export de la Task 4 doit encore être là ; sinon le refaire comme au Task 4, Step 2).

- [ ] **Step 3 : commit**

```bash
git add .github/workflows/ci.yml
git commit -m "CI : l'export Web gardé et contrôlé sur chaque PR ; sur un tag vX.Y, tous les tests verts, le Worker (le tag vaut la version, wrangler deploy, la sonde) puis la page (l'artefact du passage contrôlé face au Worker déployé, GitHub Pages, le paquet servi, une partie de deux pages)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 7 : la documentation (README, fiche de l'essai, spec telle que construite)

**Files:**
- Modify: `README.md` (l'introduction, « Multiplayer », « Jouer en ligne » : l'adresse, la vie privée, le dépannage ; « Tests » ; « Export and CI »)
- Modify: `docs/essai-en-ligne.md` (sans TURN ; les canaux de la page publiée à la main ; la section 2)
- Modify: `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§2, §8.1, §10, §11, §13)

**Interfaces:** aucune.

- [ ] **Step 1 : le README**

Dans `README.md`, remplacer :

````markdown

This copy of [LeLion-multi](https://github.com/w3cdotorg/LeLion-multi) (itself a fork of
[LeLion](https://github.com/w3cdotorg/LeLion)) is turning the **paint battle for 2 to 6 players**
into an **online game that runs in the browser**: friends at home open a link and play, no install
(WebRTC between browsers, see the
[design spec](docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md), in French). Work in
progress: for now the battle still runs on a local network, from the Godot editor (see
[Multiplayer](#multiplayer-a-paint-battle)). The solo game below is unchanged; the original plays in
a browser at <https://w3cdotorg.github.io/LeLion/>.

A Game Boy Advance port, rewritten in C, lives at [w3cdotorg/lelion-gba](https://github.com/w3cdotorg/lelion-gba).
````

par :

````markdown

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
````

Dans `README.md`, remplacer :

````markdown

Online play runs in the browser (WebRTC, the host's browser being authoritative): **Create a game**
gives a room code (`K7Q-2XM`) and **Copy link**; the others open the link, pick a name and join. It
needs the signalling Worker (`signalisation/`, deployed with the page in a later phase); locally, after
`npm ci` in `signalisation/` (and in `tests/web/` for the end-to-end test below),
`npm --prefix signalisation run dev` serves it on `ws://localhost:8787` (the `lelion/signalisation/url`
project setting), and the Web export must be served from `http://localhost:<port>` (not `127.0.0.1`).
Phones (Android, iOS) join only, by the link: no **Create a game**; lifting a finger asks for full
screen, until it is granted (three tries at most; a computer has a **Full screen** button in the lobby).
````

par :

````markdown

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
````

Dans `README.md`, remplacer :

````markdown
## Jouer en ligne

Le jeu en ligne se joue dans le navigateur, sans rien installer, de 2 à 6 joueurs, chacun chez soi. Il
sera publié sur <https://w3cdotorg.github.io/LeLion-web/> avec sa signalisation (le déploiement est la
prochaine étape) ; d'ici là, il se joue en local, comme le décrit la section précédente.

**Créer une partie** (sur un ordinateur : un téléphone ne fait que rejoindre) : *Multijoueur* sur l'écran
````

par :

````markdown
## Jouer en ligne

Le jeu en ligne se joue dans le navigateur, sans rien installer, de 2 à 6 joueurs, chacun chez soi, sur
<https://w3cdotorg.github.io/LeLion-web/>. Tout le monde doit avoir la même version : recharge la page
avant de jouer (sinon : « Version différente de l'hôte », ci-dessous).

**Créer une partie** (sur un ordinateur : un téléphone ne fait que rejoindre) : *Multijoueur* sur l'écran
````

Dans `README.md`, remplacer :

````markdown
temps d'entrer dans la partie, et celle de l'hôte toute la vie de la salle (sa connexion au service reste
ouverte pour les arrivées, 4 h au plus) : il s'en sert pour limiter les créations et les arrivées par
minute, et le Worker ne l'écrit pas dans ses journaux. Les serveurs STUN (de Cloudflare et de Google), qui
disent à chaque navigateur son adresse publique, la voient aussi. Ensuite les navigateurs se parlent
directement (WebRTC) : l'hôte et chaque joueur voient l'adresse IP l'un de l'autre, sauf quand la
connexion passe par le relais de Cloudflare (TURN : les réseaux trop fermés, ou `?relais=1` ajouté au
lien, un réglage de diagnostic qui l'impose) ; Cloudflare relaie alors tout le trafic de la partie,
chiffré. Le pseudo des autres ne s'affiche que comme du texte : ni mise en forme, ni caractères
invisibles.

**Dépannage**, message par message :
````

par :

````markdown
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
````

Dans `README.md`, remplacer :

````markdown
| « Service de connexion indisponible, réessaie dans un instant. » | Le service de connexion ne répond pas, ou refuse pour un moment (trop de tentatives depuis la même adresse IP). | Réessaie dans une minute. |
| « Trop de parties en ce moment, réessaie plus tard. » | Le quota gratuit du service de connexion est atteint pour aujourd'hui. | Réessaie plus tard (le lendemain au pire). |
| « Connexion impossible avec l'hôte (réseau trop restrictif ?) » | Les deux navigateurs n'ont pas pu se relier en 15 s. | Réessaie ; sinon change de réseau (la 4G plutôt qu'un Wi-Fi d'entreprise ou d'école), ou ajoute `&relais=1` au lien. |
| « Version différente de l'hôte (…) » | L'hôte et toi n'avez pas la même version du jeu. | Recharge la page (l'un des deux a une ancienne version en cache). |
| « Réponse incomprise : est-ce bien une partie de LeLion ? » | La réponse reçue n'est pas celle d'une partie de LeLion (un autre programme, ou une version trop différente pour se comprendre). | Vérifie le code ou le lien ; sinon, l'hôte et toi, rechargez la page. |
````

par :

````markdown
| « Service de connexion indisponible, réessaie dans un instant. » | Le service de connexion ne répond pas, ou refuse pour un moment (trop de tentatives depuis la même adresse IP). | Réessaie dans une minute. |
| « Trop de parties en ce moment, réessaie plus tard. » | Le quota gratuit du service de connexion est atteint pour aujourd'hui. | Réessaie plus tard (le lendemain au pire). |
| « Connexion impossible avec l'hôte (réseau trop restrictif ?) » | Les deux navigateurs n'ont pas pu se relier en 15 s : sans relais (TURN, pas encore en service), deux réseaux trop fermés ne se relient pas. | Réessaie ; sinon change de réseau (la 4G plutôt qu'un Wi-Fi d'entreprise ou d'école, ou l'inverse). Le paramètre `?relais=1` n'a pas encore de relais à imposer : il empêche toute connexion. |
| « Version différente de l'hôte (…) » | L'hôte et toi n'avez pas la même version du jeu. | Recharge la page (l'un des deux a une ancienne version en cache). |
| « Réponse incomprise : est-ce bien une partie de LeLion ? » | La réponse reçue n'est pas celle d'une partie de LeLion (un autre programme, ou une version trop différente pour se comprendre). | Vérifie le code ou le lien ; sinon, l'hôte et toi, rechargez la page. |
````

Dans `README.md`, remplacer :

````markdown
```

Screenshots, with a real renderer (windows open while the scripts run):

````

par :

````markdown
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

````

Dans `README.md`, remplacer :

````markdown
renderer, then exports the Web build and publishes it as the `LeLion-web` artifact (kept 30 days).
A second job tests the signalling Worker; a third exports "Web pilote" and runs the end-to-end test.
Deployment to GitHub Pages comes with the Worker's (a later phase).
````

par :

````markdown
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
````


- [ ] **Step 2 : la fiche de l'essai réel**

Dans `docs/essai-en-ligne.md`, remplacer :

````markdown
regarder et, pour chaque réponse, ce que la phase 7 bis changera. Rien n'y est décidé d'avance : la
prédiction a été réglée au banc (profil mobile : 150 ms, 60 ms de gigue, 8 % de pertes), les mobiles en
émulation, le TURN jamais (il ne se teste pas en local). Le critère de réussite (spec §1) : **une manche
complète à au moins 3 joueurs, dont un mobile en 4G et un joueur dans un autre foyer, sans installation
ni réglage réseau.**

Comment la remplir : cocher ce qui a été essayé, entourer ou écrire la réponse, noter sur quel appareil.
````

par :

````markdown
regarder et, pour chaque réponse, ce que la phase 7 bis changera. Rien n'y est décidé d'avance : la
prédiction a été réglée au banc (profil mobile : 150 ms, 60 ms de gigue, 8 % de pertes), les mobiles en
émulation. Cette version n'a **pas de relais TURN** (STUN seul, phase 5) : deux réseaux trop fermés ne se
relient pas, et c'est l'une des questions de la soirée (section 2). Le critère de réussite (spec §1) :
**une manche complète à au moins 3 joueurs, dont un mobile en 4G et un joueur dans un autre foyer, sans
installation ni réglage réseau.**

Comment la remplir : cocher ce qui a été essayé, entourer ou écrire la réponse, noter sur quel appareil.
````

Dans `docs/essai-en-ligne.md`, remplacer :

````markdown
  le tag de la version 0.21 ou d'une suivante (deux versions différentes ne jouent pas ensemble : chacun
  recharge la page avant de commencer) : oui / non
- [ ] Les captures de la phase 7 (le salon de l'hôte avec les croix d'exclusion et la consigne de
  l'onglet ; celles de la phase 6 pour un téléphone) ne sont pas dans le dépôt : la personne qui pilote
````

par :

````markdown
  le tag de la version 0.21 ou d'une suivante (deux versions différentes ne jouent pas ensemble : chacun
  recharge la page avant de commencer) : oui / non
- [ ] Sur l'ordinateur de l'hôte, la durée de vie des canaux de la page publiée (le correctif des canaux de
  la phase 7, qui n'est pas derrière le pilote ; une fois suffit) : Chrome ou Firefox, ouvrir la page,
  F12, onglet Console, y coller la ligne ci-dessous, Entrée, **puis seulement** *Multijoueur*, *Créer une
  partie*, et faire rejoindre un joueur. La console écrit une ligne `canal …` par canal (quatre par
  joueur) : deux disent `durée=100`, les deux autres `durée=null` : oui / non (si non, recopier les
  lignes : _______________)

  ```js
  { const creer = RTCPeerConnection.prototype.createDataChannel; RTCPeerConnection.prototype.createDataChannel = function (nom, options) { const canal = creer.call(this, nom, options); console.log(`canal ${nom} ordonné=${canal.ordered} durée=${canal.maxPacketLifeTime} renvois=${canal.maxRetransmits}`); return canal; }; }
  ```

- [ ] Les captures de la phase 7 (le salon de l'hôte avec les croix d'exclusion et la consigne de
  l'onglet ; celles de la phase 6 pour un téléphone) ne sont pas dans le dépôt : la personne qui pilote
````

Dans `docs/essai-en-ligne.md`, remplacer :

````markdown
|---|---|
| Tout arrive vite | Rien. |
| « Connexion impossible avec l'hôte (réseau trop restrictif ?) » | Noter les deux réseaux ; refaire avec `&relais=1` ajouté au lien (section 2) : si le relais passe, le TURN fait son travail ; sinon, le journal de la console des deux navigateurs (`TransportWebRTC`, `DELAI_CANAL` 15 s). |
| « Service de connexion indisponible » | La console du navigateur : la raison exacte (`origine`, `debit`, Worker injoignable) ; les limites de 5 créations et 30 arrivées par minute et par IP (`signalisation/`) touchent un réseau partagé (école, entreprise). |
| L'arrivée prend plus de 10 s | Noter le réseau : les candidats ICE et le délai de 15 s (`TransportWebRTC.DELAI_CANAL`). |

## 2. Une manche normale, puis une manche par le relais

Manche 1 : au moins 3 joueurs (le téléphone en 4G et le joueur de l'autre foyer compris), niveau au choix.
````

par :

````markdown
|---|---|
| Tout arrive vite | Rien. |
| « Connexion impossible avec l'hôte (réseau trop restrictif ?) » | Noter les deux réseaux (section 2) : sans TURN, c'est attendu sur certains réseaux ; s'ils sont nombreux, un TURN (spec §13) ; sinon, le journal de la console des deux navigateurs (`TransportWebRTC`, `DELAI_CANAL` 15 s). |
| « Service de connexion indisponible » | La console du navigateur : la raison exacte (`origine`, `debit`, Worker injoignable) ; les limites de 5 créations et 30 arrivées par minute et par IP (`signalisation/`) touchent un réseau partagé (école, entreprise). |
| L'arrivée prend plus de 10 s | Noter le réseau : les candidats ICE et le délai de 15 s (`TransportWebRTC.DELAI_CANAL`). |

## 2. Une manche, et les réseaux qui ne se relient pas

Manche 1 : au moins 3 joueurs (le téléphone en 4G et le joueur de l'autre foyer compris), niveau au choix.
````

Dans `docs/essai-en-ligne.md`, remplacer :

````markdown
- [ ] Les chocs entre lions et les étourdissements (une gerbe reçue) paraissent justes : oui / non

Manche 2, par le relais TURN imposé : l'hôte recharge la page avec `?relais=1` au bout de son adresse,
crée une nouvelle partie et envoie le **nouveau** lien (l'ancien code est fermé) ; chaque joueur ajoute
`&relais=1` à la fin de ce nouveau lien avant de l'ouvrir.

- [ ] Tout le monde arrive au salon : oui / non (appareils qui échouent : ______)
- [ ] La manche paraît : pareille / plus lente / saccadée, qu'en manche 1

| Réponse | Ce que fera la phase 7 bis |
````

par :

````markdown
- [ ] Les chocs entre lions et les étourdissements (une gerbe reçue) paraissent justes : oui / non

Pas de manche par le relais : cette version n'a pas de TURN, et `?relais=1` (qui impose le relais)
empêche alors toute connexion. À la place, pour chaque joueur qui lit « Connexion impossible avec
l'hôte » :

- [ ] Son réseau et celui de l'hôte (Wi-Fi d'une box, Wi-Fi d'entreprise ou d'école, 4G, 5G,
  opérateur) : _______________
- [ ] Il réessaie depuis un autre réseau (la 4G au lieu du Wi-Fi, ou l'inverse) : ça passe : oui / non

| Réponse | Ce que fera la phase 7 bis |
````

Dans `docs/essai-en-ligne.md`, remplacer :

````markdown
| Des sauts | `PredictionLocale.SEUIL_RECALAGE` (200 px), et la console de l'appareil (un recalage est une désynchronisation). |
| Autres lions saccadés (en 4G surtout) | `InterpolationLion.RETARD` (6 ticks, 100 ms : 8 à 10 absorbent un réseau plus mauvais, au prix d'un peu de retard) ; par à-coups pendant une coupure : `InterpolationLion.EXTRAPOLATION_MAX` (3 ticks). |
| Le relais échoue | Le TURN de Cloudflare (identifiants, ports bloqués) : la console (`iceServers`, l'état ICE). |
| Le relais est bien plus lent | Noter la ville des joueurs : le point de présence du TURN ; aucun réglage du jeu n'y peut rien. |

## 3. L'hôte et ses onglets
````

par :

````markdown
| Des sauts | `PredictionLocale.SEUIL_RECALAGE` (200 px), et la console de l'appareil (un recalage est une désynchronisation). |
| Autres lions saccadés (en 4G surtout) | `InterpolationLion.RETARD` (6 ticks, 100 ms : 8 à 10 absorbent un réseau plus mauvais, au prix d'un peu de retard) ; par à-coups pendant une coupure : `InterpolationLion.EXTRAPOLATION_MAX` (3 ticks). |
| Des joueurs ne se relient pas (« Connexion impossible avec l'hôte ») | Un TURN (spec §13) : des identifiants fabriqués par le Worker (`fabriquerIce`), chez Cloudflare (TURN Cloudflare, une carte bancaire) ou un fournisseur à offre gratuite ; puis rejouer cette section avec `?relais=1`. |
| Tout le monde se relie, même en 4G | Rien : le TURN reste à faire le jour où un réseau l'exige. |

## 3. L'hôte et ses onglets
````


- [ ] **Step 3 : la spec telle que construite**

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
| Transport du jeu livré | `WebRTCMultiplayerPeer`, en étoile autour de l'hôte (l'hôte en `create_server`, chaque client en `create_client`). Natif dans l'export Web de Godot, sans extension. |
| Signalisation | Un Worker Cloudflare et un Durable Object `Salle` par partie, parlés en WebSocket (JSON) par Godot (`WebSocketPeer`). |
| STUN / TURN | STUN Google et Cloudflare, TURN Cloudflare (UDP, TCP, TLS 443). Identifiants TURN fabriqués par le Worker, valables 2 h, donnés seulement aux membres d'une salle. |
| Rejoindre | Code de salle de 6 caractères (alphabet sans 0/O, 1/I/L), affiché `K7Q-2XM`, et lien `https://w3cdotorg.github.io/LeLion-web/?salle=K7Q2XM`. Privé : pas de liste. |
| Hôte | Ordinateur seulement. Il doit garder l'onglet au premier plan (le navigateur fige un onglet caché). |
````

par :

````markdown
| Transport du jeu livré | `WebRTCMultiplayerPeer`, en étoile autour de l'hôte (l'hôte en `create_server`, chaque client en `create_client`). Natif dans l'export Web de Godot, sans extension. |
| Signalisation | Un Worker Cloudflare et un Durable Object `Salle` par partie, parlés en WebSocket (JSON) par Godot (`WebSocketPeer`). |
| STUN / TURN | STUN Google et Cloudflare, TURN Cloudflare (UDP, TCP, TLS 443). Identifiants TURN fabriqués par le Worker, valables 2 h, donnés seulement aux membres d'une salle. **Mis en ligne (phase 5) en STUN seul** : le Worker ne donne de TURN qu'avec ses secrets TURN, absents ; le TURN vient plus tard s'il le faut (§13). |
| Rejoindre | Code de salle de 6 caractères (alphabet sans 0/O, 1/I/L), affiché `K7Q-2XM`, et lien `https://w3cdotorg.github.io/LeLion-web/?salle=K7Q2XM`. Privé : pas de liste. |
| Hôte | Ordinateur seulement. Il doit garder l'onglet au premier plan (le navigateur fige un onglet caché). |
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
### 8.1 Worker

- **Origine** : WebSocket acceptée seulement depuis `https://w3cdotorg.github.io` et
  `http://localhost:*` (variable du Worker `ORIGINES` ; `:*` = tout port ou aucun). Ça freine le
  pillage, ça ne protège pas seul. Sans en-tête `Origin` : refusée (le jeu livré est l'export Web,
  dont le navigateur l'envoie toujours ; le desktop de développement joue en ENet).
````

par :

````markdown
### 8.1 Worker

- **Origine** : WebSocket acceptée seulement depuis `https://w3cdotorg.github.io` en production
  (variable du Worker `ORIGINES`, `signalisation/wrangler.jsonc`), et aussi depuis `http://localhost:*`
  sous `wrangler dev` (`npm run dev` l'ajoute par `--var` ; `:*` = tout port ou aucun). Ça freine le
  pillage, ça ne protège pas seul. Sans en-tête `Origin` : refusée (le jeu livré est l'export Web,
  dont le navigateur l'envoie toujours ; le desktop de développement joue en ENet).
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
  Vérifié en phase 2 (documentation du 01/10/2026) : ni la page *Rate Limiting* ni les tarifs et
  limites des Workers ne la réservent à une offre, sans dire en toutes lettres qu'elle existe sur
  l'offre gratuite ; le premier `wrangler deploy` (phase 5) le tranche, et sinon un Durable Object
  compteur la remplace.
- **Validation** : type de message connu, `vers` membre de la salle, champs attendus seulement ; un
  message invalide est ignoré, sans fermer la socket (un relais vers un client parti à l'instant est
````

par :

````markdown
  Vérifié en phase 2 (documentation du 01/10/2026) : ni la page *Rate Limiting* ni les tarifs et
  limites des Workers ne la réservent à une offre, sans dire en toutes lettres qu'elle existe sur
  l'offre gratuite ; le premier `wrangler deploy` (phase 5) le tranche. Repli s'il refusait le binding :
  retirer le bloc `ratelimits` (sans binding, le Worker admet tout sans journaliser, les plafonds de
  chaque salle restent), puis, si les abus l'exigent, un Durable Object compteur (une migration `v2`).
- **Validation** : type de message connu, `vers` membre de la salle, champs attendus seulement ; un
  message invalide est ignoré, sans fermer la socket (un relais vers un client parti à l'instant est
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
  vérifié dans la documentation TURN de Cloudflare le 01/10/2026), URL du port 53 retirées (bloqué
  par les navigateurs) ; un seul jeu par arrivée, donné à l'arrivant et à l'hôte. Sans secrets
  (développement local), API en erreur ou muette 3 s : STUN seul (Cloudflare et Google).
- **Coût** : Durable Object en hibernation de WebSocket (pas de durée facturée pour une socket
  inactive) ; quota gratuit dépassé : `erreur quota`, le jeu dit « Trop de parties en ce moment,
````

par :

````markdown
  vérifié dans la documentation TURN de Cloudflare le 01/10/2026), URL du port 53 retirées (bloqué
  par les navigateurs) ; un seul jeu par arrivée, donné à l'arrivant et à l'hôte. Sans secrets
  (développement local, et le déploiement de la phase 5), API en erreur ou muette 3 s : STUN seul
  (Cloudflare et Google).
- **Journaux** (Workers Logs) : seulement les lignes de `journal` (jamais de SDP, de candidat ni d'IP) ;
  les journaux d'invocation (`invocation_logs: false`) et les traces sont coupés : la documentation ne dit
  pas s'ils gardent l'IP du client, et chaque événement compte sur les 200 000 par jour de l'offre gratuite.
- **Coût** : Durable Object en hibernation de WebSocket (pas de durée facturée pour une socket
  inactive) ; quota gratuit dépassé : `erreur quota`, le jeu dit « Trop de parties en ce moment,
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
  client limité par l'hôte, fait échouer le test. Le TURN ne se teste pas en
  local.
- **Essai réel** : `docs/essai-en-ligne.md` (hôte sur ordinateur, au moins un mobile en 4G, un joueur
  dans un autre foyer ; une manche avec le relais TURN forcé par `?relais=1`, paramètre de
````

par :

````markdown
  client limité par l'hôte, fait échouer le test. Le TURN ne se teste pas en
  local.
- **L'export publié** (phase 5) : `tests/export_publie.gd` lit les réglages écrits dans son paquet (sans
  la fonctionnalité `pilote`, l'adresse du Worker de `project.godot` en `wss://`, aucune adresse locale
  hors des variantes `.pilote`) ; `tests/web/playwright.publie.config.js` l'ouvre dans Chromium, la
  signalisation simulée (aucun `window.lelionPilote`, ni « PILOTE PRET » ; la page appelle le Worker de
  `project.godot` ; chaque canal non fiable garde un paquet 100 ms au plus), puis, au déploiement, face au
  Worker déployé (qui refuse son origine) ; `tests/web/playwright.en_direct.config.js` joue, sur la page
  publiée, une partie de deux pages menées au clavier (une salle, une arrivée, le canal ouvert, STUN
  seul).
- **Essai réel** : `docs/essai-en-ligne.md` (hôte sur ordinateur, au moins un mobile en 4G, un joueur
  dans un autre foyer ; une manche avec le relais TURN forcé par `?relais=1`, paramètre de
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
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
````

par :

````markdown
## 11. Build, déploiement et prérequis

- **CI sur `main` et les PR** : tests Godot, tests du Worker, export Web gardé (`tests/export_publie.gd`,
  le contrôle Chromium de l'export publié), test Playwright ; l'export en artefact. Rien n'est mis en
  ligne.
- **Tag `vX.Y`** (= `application/config/version`, vérifié) : les mêmes jobs, puis, tous verts, le
  Worker (`wrangler deploy`, nom `lelion-web`, puis la sonde `signalisation/outils/sonder.mjs`), puis la
  page : l'artefact `LeLion-web` de ce passage (construit depuis l'extraction du tag, jamais
  `web-pilote`), contrôlé face au Worker déployé, publié par `actions/deploy-pages`, puis une partie de
  deux pages sur la page publiée. L'URL du Worker est écrite dans `project.godot` (réglage
  `lelion/signalisation/url` = `wss://lelion-web.w3cdotorg.workers.dev`, sans chemin : les routes ont
  `/v1`), donc dans l'export ; `lelion/signalisation/url.pilote` = `ws://localhost:8787` pour l'export
  « Web pilote » (lu par `get_setting_with_override`). Retour en arrière : relancer le passage du tag
  précédent ; le Worker seul : son tableau de bord ou `wrangler rollback`.
- **Prérequis côté utilisateur** (faits le 02/10/2026) : un compte Cloudflare (offre gratuite, sous-domaine
  `w3cdotorg.workers.dev`), un jeton d'API pour `wrangler` (modèle « Edit Cloudflare Workers »), les
  secrets du dépôt `CLOUDFLARE_API_TOKEN` et `CLOUDFLARE_ACCOUNT_ID`, Pages activé (source : GitHub
  Actions) et l'environnement `github-pages` ouvert aux tags `v*`. Pas d'application TURN (STUN seul) :
  `TURN_KEY_ID` et `TURN_KEY_API_TOKEN` n'existent pas. Rien n'est créé sans l'utilisateur.
- **Dépôt public** : GitHub Pages gratuit l'exige pour une organisation sur l'offre gratuite.
- README : en anglais comme aujourd'hui, avec une section « Jouer en ligne » en français (créer,
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
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
````

par :

````markdown
- **Onglet de l'hôte caché** : le jeu se fige pour tous (contrainte du navigateur). Parades :
  hôte sur ordinateur, consigne dans le salon, 10 s de tolérance.
- **NAT stricts en 4G/5G** (25 à 35 % des connexions mobiles sans TURN) : mis en ligne sans TURN
  (phase 5, décision de l'utilisateur), l'essai réel compte les joueurs qui ne se relient pas. S'il en
  faut un : le Worker fabrique déjà les identifiants (`fabriquerIce`) ; soit le TURN de Cloudflare (UDP,
  TCP et TLS 443 ; ses secrets `TURN_KEY_ID`, `TURN_KEY_API_TOKEN` par `wrangler secret put` ; une carte
  bancaire au compte), soit l'offre gratuite d'un autre fournisseur (Metered, par exemple), dont le Worker
  fabriquerait les identifiants de la même façon (une variante de `fabriquerIce`) ; puis mesuré avec
  `?relais=1`.
- **Latence Internet** (30 à 120 ms, plus en 4G) : prédiction déjà éprouvée sous 80/40/5 ; profil
  mobile ajouté au banc, réglages sur mesures seulement.
- **Offre gratuite de Cloudflare** : Durable Objects gratuits avec le stockage SQLite seulement
  (`new_sqlite_classes`, phase 2) ; limitation de débit : aucune restriction d'offre dans la
  documentation (phase 2, §8.1), le premier déploiement le confirme (phase 5, repli au §8.1) ; TURN :
  absent de la mise en ligne (ci-dessus).
- **Safari iOS** : WebGL 2 et son ; un ancien ticket Godot (WebRTC bloqué en « connecting », 4.2) n'a
  pas été revérifié : à tester à l'essai réel sur un vrai iPhone (`docs/essai-en-ligne.md`, section 4).
- **Exclu qui revient** : sans compte, rien n'identifie durablement un joueur. L'exclusion est
  rejouable par l'hôte à chaque retour ; le code n'est connu que de ceux qui ont le lien.
````


- [ ] **Step 4 : relire, et la ligne de la console de la fiche, collée pour de vrai**

```bash
grep -n "Work in progress\|later phase\|prochaine étape\|ajoute \`&relais=1\` au lien" README.md || echo "plus rien de périmé"
grep -n "relais" README.md docs/essai-en-ligne.md | cut -c1-150
sed -n '/^  ```js$/,/^  ```$/p' docs/essai-en-ligne.md | sed '1d;$d' | sed 's/^  //' > tests/web/_ligne.txt
cat > tests/web/_ligne.spec.js <<'EOF'
import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";
test("la ligne de la fiche, collée dans la console après le chargement", async ({ page }) => {
	const lignes = [];
	page.on("console", (m) => lignes.push(m.text()));
	await page.routeWebSocket(/.*/, (ws) => ws.send(JSON.stringify({ t: "bienvenue", id: 5, ice: [] })));
	await page.goto("/?salle=K7Q2XM");
	await expect.poll(() => lignes.some((l) => l.startsWith("Godot Engine v")), { timeout: 60_000 }).toBe(true);
	await page.evaluate(readFileSync(new URL("./_ligne.txt", import.meta.url), "utf8"));
	await expect.poll(async () => { const n = lignes.filter((l) => l.startsWith("canal ")).length; if (n === 0) await page.keyboard.press("Enter"); return n; }, { timeout: 60_000, intervals: [500] }).toBeGreaterThanOrEqual(4);
	console.log(lignes.filter((l) => l.startsWith("canal ")).join(" | "));
});
EOF
sed 's|testMatch: "export_publie.spec.js"|testMatch: "_ligne.spec.js"|' tests/web/playwright.publie.config.js > tests/web/_ligne.config.js
docker run --rm --init -v "$PWD":/depot -v lelion5-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble \
  bash -c 'npx playwright test -c _ligne.config.js' 2>&1 | grep -E "canal|passed|failed"
rm tests/web/_ligne.txt tests/web/_ligne.spec.js tests/web/_ligne.config.js; git status --short tests/web
```

Expected (mesuré) : `plus rien de périmé` ; les lignes `relais` disent qu'il n'y a pas encore de relais (README : la vie privée, le dépannage ; la fiche : l'introduction, la section 2 et son tableau) ; `canal reliable ordonné=true durée=null renvois=null | canal ordered ordonné=true durée=100 renvois=null | canal unreliable ordonné=false durée=100 renvois=null | canal 4 ordonné=true durée=null renvois=null`, `1 passed` (l'export `export/web` de la Task 4) ; rien pour `git status`.

- [ ] **Step 5 : commit**

```bash
git add README.md docs/essai-en-ligne.md docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
git commit -m "Documentation du déploiement : l'adresse du jeu et comment jouer, la vie privée telle qu'elle est (STUN seul, aucun relais, journaux sans IP), le déploiement sur un tag et son retour en arrière ; la fiche de l'essai sans TURN, les canaux de la page publiée à la main ; la spec telle que construite

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 8 : vérification commune, PR et fusion de la phase 5

**Files:**
- Modify: `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 5 : fichiers réels, « Faite (PR #N) »)

**Interfaces:** aucune.

- [ ] **Step 1 : la vérification commune (feuille de route), sans relance**

```bash
export PATH="$HOME/.orbstack/bin:/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
pgrep -f 'godot --headless' || echo "aucun autre godot"
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|PROTOCOLE|== " "$TMPDIR/u.log"; grep -c "✅" "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/s.log"; grep -c "✅" "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd > "$TMPDIR/b.log" 2>&1; echo "bataille $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/b.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "banc $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/p.log"; grep -c "✅" "$TMPDIR/p.log"
SECONDS=0; timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|^== " "$TMPDIR/r.log"
(cd signalisation && npm ci --silent && npm test 2>&1 | grep "Tests " && npx wrangler deploy --dry-run --outdir "$TMPDIR/signalisation-essai" 2>&1 | grep -E "ORIGINES|exiting")
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/dc.log" 2>&1 &
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/dh.log" 2>&1; echo "deux fenêtres hôte $?"; wait; grep -c "📸" "$TMPDIR/dh.log" "$TMPDIR/dc.log"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/dh.log" "$TMPDIR/dc.log"
rm -rf export; mkdir -p export/web export/web-pilote; touch export/.gdignore
timeout 600 godot --headless --export-release Web export/web/index.html > "$TMPDIR/e.log" 2>&1; echo "export $?"
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
timeout 120 godot --headless --script tests/export_publie.gd -- --pck=export/web/index.pck 2>&1 | grep -E "❌|== "
for n in 1 2; do SECONDS=0; timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion5-modules-signalisation:/depot/signalisation/node_modules -v lelion5-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test && npx playwright test -c playwright.publie.config.js' > "$TMPDIR/e2e$n.log" 2>&1; echo "bout en bout $n : $? en ${SECONDS} s"; grep -E "✓|✘|passed|failed|Rencontre|Départ|Export publié" "$TMPDIR/e2e$n.log"; done
actionlint .github/workflows/ci.yml && echo "actionlint ok"
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/web/*.js signalisation/outils/*.mjs
git status --short
```

Expected (mesuré sur ce plan appliqué) : « aucun autre godot » ; pas de « ÉCHEC COMPILATION » ; chaque suite Godot sort en 0 sur `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR` ; `PROTOCOLE 0.21 1188810746 (67 lignes)`, 576 ✅ unitaires, 473 ✅ smoke, 78 ✅ au banc ; réseau en 155 à 170 s (mesuré 160 et 161 s ; un `FIN2` de chrono sous charge se relance une fois, Global Constraints) ; `Tests  71 passed (71)`, `env.ORIGINES ("https://w3cdotorg.github.io")`, `--dry-run: exiting now.` ; 46 📸, 5 et 6 pour les deux fenêtres ; `export 0`, `export pilote 0`, `== 0 échec(s) ==` pour le garde ; les deux passages `0`, chacun `4 passed` (mesurés 140 et 141 s, leurs lignes `Rencontre` et `Départ`) puis `2 passed` et la ligne `Export publié : wss://lelion-web.w3cdotorg.workers.dev/v1/rejoindre/K7Q2XM, …` ; `actionlint ok` ; rien au `perl` ; `git status` propre. Un échec : le corriger dans la tâche qu'il concerne (commit à part), puis tout relancer.

- [ ] **Step 2 : la branche poussée, la PR ouverte** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
git push -u origin phase-05-deploiement
cat > "$TMPDIR/pr.md" <<'EOF'
Phase 5 de la feuille de route du jeu en ligne : le déploiement (spec §11, §8.1, §13). Cette PR ne met rien en ligne : le tag `v0.21`, après sa fusion, déploie (runbook du plan, partie B).

- Worker de production `lelion-web` (`https://lelion-web.w3cdotorg.workers.dev`, à la place du Worker « Hello world ») : seule la page publiée est admise (`localhost` sous `npm run dev` seulement, par `--var`) ; journaux d'invocation et traces coupés (la documentation ne dit pas s'ils gardent l'IP) ; STUN seul (aucun secret TURN) ; si l'offre gratuite refusait `ratelimits`, retirer le bloc suffit (sans binding, le Worker admet tout sans journaliser). La sonde `signalisation/outils/sonder.mjs` vérifie le Worker déployé.
- Le jeu : `lelion/signalisation/url` = `wss://lelion-web.w3cdotorg.workers.dev`, `ws://localhost:8787` sous la fonctionnalité `pilote` ; lu par `get_setting_with_override` (`get_setting` ignore les variantes : l'export « Web pilote » parlait au Worker déployé, vu par le contrôle de l'export). Une signalisation qui ne s'ouvre même pas (adresse mal formée, contenu mixte) : « Service de connexion indisponible ».
- Gardes de l'export publié, sur chaque PR : ses réglages (`tests/export_publie.gd` : sans `pilote`, l'adresse du Worker, aucune adresse locale hors des variantes `.pilote`, ses 9 fichiers, pas de `viewport-fit`) ; dans Chromium (sans `window.lelionPilote` ni « PILOTE PRET », la signalisation du Worker de `project.godot`, les canaux non fiables à 100 ms).
- CI : sur un tag `vX.Y` égal à la version, tous les tests verts, le Worker (`wrangler deploy`, la sonde), puis la page : l'artefact `LeLion-web` du passage, contrôlé face au Worker déployé, GitHub Pages, le paquet servi, une partie de deux pages menées au clavier sur la page publiée (`tests/web/en_direct.spec.js`).
- README (l'adresse du jeu, la vie privée sans relais, le déploiement et le retour en arrière), la fiche de l'essai sans TURN (et les canaux de la page publiée, à la main), la spec telle que construite.

Version et protocole inchangés (`PROTOCOLE 0.21 1188810746`).

Mesures (ce Mac, Task 8, Step 1) : MESURES

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
```

Remplacer `MESURES` (outil Edit) par les mesures du Step 1 : la durée du test réseau, celles des deux passages du bout en bout et leurs lignes `Rencontre`, puis :

```bash
gh pr create --repo w3cdotorg/LeLion-web --base main --head phase-05-deploiement --title "Phase 5 : déploiement" --body-file "$TMPDIR/pr.md"
N=$(gh pr view --repo w3cdotorg/LeLion-web phase-05-deploiement --json number -q .number); echo "PR #$N"
```

- [ ] **Step 3 : la feuille de route**

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

````markdown
| 5 | **Déploiement** (compte Cloudflare, application TURN et secrets prêts, avec l'utilisateur) : tag `vX.Y` → `wrangler deploy` puis GitHub Pages ; URL du Worker dans le réglage `lelion/signalisation/url`. Vérifier ici : TURN sans carte bancaire. | ✏️ `.github/workflows/ci.yml` ✏️ `project.godot` ✏️ `signalisation/wrangler.jsonc` ✏️ `README.md` | Première partie en ligne sur `https://w3cdotorg.github.io/LeLion-web/`. |
````

par (`NUMERO` est le numéro de la PR, `$N` du Step 2) :

````markdown
| 5 | **Déploiement** (compte Cloudflare et secrets prêts, avec l'utilisateur ; **sans TURN**, décision de l'utilisateur : STUN seul) : tag `vX.Y` → `wrangler deploy` (Worker `lelion-web`) puis GitHub Pages ; URL du Worker dans le réglage `lelion/signalisation/url` (`wss://lelion-web.w3cdotorg.workers.dev`, `.pilote` pour le bout en bout). | ✏️ `.github/workflows/ci.yml` (gardes de l'export, déploiement sur un tag) ✏️ `project.godot` ✏️ `signalisation/wrangler.jsonc` ✏️ `signalisation/package.json` ✏️ `signalisation/src/index.js` ✏️ `signalisation/test/entree.test.js` ➕ `signalisation/outils/sonder.mjs` ✏️ `Scripts/TransportWebRTC.gd` ✏️ `Scripts/EcranEnLigne.gd` ✏️ tests (`unitaires`, `smoke_test`, ➕ `export_publie.gd`, `web/` : ➕ `export_publie.spec.js`, ➕ `en_direct.spec.js` et leurs configurations) ✏️ spec ✏️ `README.md` ✏️ `docs/essai-en-ligne.md` | Première partie en ligne sur `https://w3cdotorg.github.io/LeLion-web/`. Code fait (PR #NUMERO) ; mise en ligne : runbook du plan de la phase 5. |
````

puis :

```bash
perl -pi -e "s/PR #NUMERO/PR #$N/" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
grep -c "Code fait (PR #$N)" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git add docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git commit -m "Feuille de route : phase 5, le code fait (PR #$N)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
git push
```

Expected : `1`.

- [ ] **Step 4 : la CI, puis la fusion** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
gh pr checks --repo w3cdotorg/LeLion-web "$N" --watch
gh run list --repo w3cdotorg/LeLion-web --branch phase-05-deploiement --limit 1 --json databaseId -q '.[0].databaseId' | xargs -I{} gh run view --repo w3cdotorg/LeLion-web {} --json jobs -q '.jobs[] | "\(.name) \(.conclusion)"'
gh pr merge --repo w3cdotorg/LeLion-web "$N" --merge
git switch main && git pull --ff-only && git log --oneline -3
```

Expected : les trois jobs de test verts (« Tests + export Web » avec son étape « Garder l'export publié … », « Tests du Worker de signalisation », « Bout en bout WebRTC » avec « Contrôle de l'export publié … ») ; `Déploiement du Worker (tag vX.Y)` et `Déploiement de la page (GitHub Pages, tag vX.Y)` `skipped` (une PR ne déploie rien) ; la fusion faite, `main` à jour. La CI rouge : ne pas fusionner, diagnostiquer (l'artefact `rapport-playwright` pour le bout en bout).

---

## Partie B : la mise en ligne (runbook)

Exécuté par le contrôleur, chaque effet externe avec l'accord explicite de l'utilisateur, une fois la PR de la partie A fusionnée. Depuis `~/Sites/LeLion-web`, sur `main` à jour, `export PATH="$HOME/.orbstack/bin:/opt/homebrew/bin:$PATH"`. Aucun jeton Cloudflare sur ce poste : tout ce qui touche Cloudflare passe par la CI (ses secrets) ou par l'utilisateur (son tableau de bord).

### R1 : les préalables

- [ ] **Step 1 : relire l'état** (lecture seule)

```bash
git log --oneline -1; grep -n 'config/version\|signalisation/url' project.godot
gh secret list --repo w3cdotorg/LeLion-web
gh api repos/w3cdotorg/LeLion-web/pages -q '"\(.build_type) \(.html_url)"'
gh api repos/w3cdotorg/LeLion-web/environments/github-pages/deployment-branch-policies -q '.branch_policies[] | "\(.type) \(.name)"'
git ls-remote --tags origin 'v*'
curl -s -m 10 https://lelion-web.w3cdotorg.workers.dev/; echo
```

Expected : la fusion de la PR de la phase 5 ; `config/version="0.21"`, `signalisation/url="wss://lelion-web.w3cdotorg.workers.dev"`, `signalisation/url.pilote="ws://localhost:8787"` ; `CLOUDFLARE_ACCOUNT_ID` et `CLOUDFLARE_API_TOKEN` (aucun secret TURN : voulu) ; `workflow https://w3cdotorg.github.io/LeLion-web/` ; `branch main` seul ; aucun tag `v*` ; `Hello world`.

- [ ] **Step 2 : ouvrir l'environnement `github-pages` aux tags `v*`** (effet externe ; sans lui, `deploy-pages` refuse le tag : « Tag "v0.21" is not allowed to deploy to github-pages due to environment protection rules »)

```bash
gh api -X POST repos/w3cdotorg/LeLion-web/environments/github-pages/deployment-branch-policies -f name='v*' -f type=tag -q '"\(.type) \(.name)"'
gh api repos/w3cdotorg/LeLion-web/environments/github-pages/deployment-branch-policies -q '.branch_policies[] | "\(.type) \(.name)"'
```

Expected : `tag v*` ; puis `branch main` et `tag v*`.

- [ ] **Step 3 : avec l'utilisateur, dans le tableau de bord de Cloudflare** : le jeton de `CLOUDFLARE_API_TOKEN` est du modèle « Edit Cloudflare Workers » sur ce compte (Workers Scripts, Workers Routes, Account Settings en lecture… : ce que le modèle donne) ; le Worker `lelion-web` est bien le « Hello world » (rien à garder) ; aucune variable ni aucun secret ajouté à la main sur ce Worker (le déploiement efface les variables qui ne sont pas dans `wrangler.jsonc`, et garde les secrets). Noter la réponse.

### R2 : le tag `v0.21`, le passage suivi

- [ ] **Step 1 : le tag** (effet externe : la mise en ligne)

```bash
git tag -a v0.21 -m "LeLion web 0.21 : première mise en ligne (STUN seul)" && git push origin v0.21
sleep 5; R=$(gh run list --repo w3cdotorg/LeLion-web --event push --branch v0.21 --limit 1 --json databaseId -q '.[0].databaseId'); echo "passage $R"
gh run watch --repo w3cdotorg/LeLion-web "$R" --exit-status; echo "fin $?"
gh run view --repo w3cdotorg/LeLion-web "$R" --json jobs -q '.jobs[] | "\(.name) \(.conclusion)"'
gh run view --repo w3cdotorg/LeLion-web "$R" --log --job "$(gh run view --repo w3cdotorg/LeLion-web "$R" --json jobs -q '.jobs[] | select(.name | startswith("Déploiement du Worker")) | .databaseId')" | grep -E "Deployed|workers.dev|salle .* créée|refusée|::warning::|::error::"
```

Expected : les cinq jobs `success`, dans l'ordre (les trois de test, puis le Worker, puis la page : 20 à 25 min) ; au journal du Worker, l'adresse `https://lelion-web.w3cdotorg.workers.dev`, `salle XXXXXX créée depuis https://w3cdotorg.github.io, ICE : stun:stun.cloudflare.com:3478 stun:stun.l.google.com:19302`, `origine http://localhost:8060 refusée (erreur origine)`, aucun `::error::`. Au job de la page : `Export publié : wss://lelion-web.w3cdotorg.workers.dev/v1/rejoindre/K7Q2XM, refus lu au journal (Worker déployé)`, `page publiée : https://w3cdotorg.github.io/LeLion-web/`, puis `Salle XXXXXX : wss://lelion-web.w3cdotorg.workers.dev/v1/creer ; …/v1/rejoindre/XXXXXX ; canal ouvert ; ICE [{"urls":["stun:…","stun:…"]}]`.

- [ ] **Step 2 : si un job échoue** (une branche, puis reprendre au Step 1 du R3)

  - **A. Le tag ne vaut pas la version** : impossible ici (`v0.21` = `0.21`) ; sinon supprimer le tag (`git push --delete origin vX.Y && git tag -d vX.Y`), rien n'a été déployé.
  - **B. `wrangler deploy` refuse le bloc `ratelimits`** (l'offre gratuite, ou un namespace pris : le journal le dit) : rien n'a changé chez Cloudflare. Une PR qui retire le bloc `ratelimits` de `signalisation/wrangler.jsonc` (le commentaire au-dessus le prévoit ; spec §8.1 : « Repli s'il refusait le binding »), le vitest « sans binding … » la couvre ; fusionnée, déplacer le tag sur son commit (`git push --delete origin v0.21 && git tag -d v0.21`, puis le Step 1) : la page n'a pas été publiée, le tag n'a servi à personne. Noter le refus dans la spec (§8.1, §13) et la feuille de route.
  - **C. `wrangler deploy` refuse de remplacer le Worker du tableau de bord** (un message sur des changements faits dans le tableau de bord, ou sur le Worker existant) : l'utilisateur supprime le Worker « Hello world » `lelion-web` dans le tableau de bord (Workers et Pages, `lelion-web`, Settings, Delete), puis `gh run rerun --repo w3cdotorg/LeLion-web "$R" --failed`.
  - **D. La sonde échoue après un déploiement réussi** (le Worker est déployé, la page ne l'est pas) : lire son `::error::` (une origine admise ou refusée à tort : `ORIGINES` ; un TURN inattendu : un secret ajouté à la main, que l'utilisateur retire ; « connexion impossible » : le Worker ne répond pas sur `workers.dev`, à voir avec l'utilisateur dans le tableau de bord, Settings, Domains & Routes) ; corriger par une PR, nouvelle version si le jeu change (`0.22`, `PROTOCOLE_EMPREINTE` inchangée si aucune RPC ne change) ou le même tag déplacé sinon (comme en B : la page de `v0.21` n'a jamais été publiée).
  - **E. `deploy-pages` refuse l'environnement** : le Step 2 du R1 manque ; le faire, puis `gh run rerun --repo w3cdotorg/LeLion-web "$R" --failed`.
  - **F. La page publiée, ou la partie de contrôle, échoue** : la page est en ligne. Lire le rapport (`gh run view "$R" --log-failed`) ; si la page est cassée pour les joueurs, le retour en arrière (R6) ; sinon corriger par une PR et un nouveau tag (`v0.22`).

### R3 : vérifier le Worker et la page depuis ce poste

- [ ] **Step 1 : le Worker en ligne**

```bash
(cd signalisation && node outils/sonder.mjs wss://lelion-web.w3cdotorg.workers.dev; echo "sonde $?")
curl -s -o /dev/null -w "%{http_code}\n" https://lelion-web.w3cdotorg.workers.dev/v1/creer
curl -s -o /dev/null -w "%{http_code}\n" https://lelion-web.w3cdotorg.workers.dev/
```

Expected : la salle depuis `https://w3cdotorg.github.io`, STUN seul, `origine http://localhost:8060 refusée (erreur origine)`, `sonde 0` ; `426` (une WebSocket est attendue) ; `404` (plus de « Hello world »).

- [ ] **Step 2 : la page en ligne**

```bash
curl -sI https://w3cdotorg.github.io/LeLion-web/ | grep -iE "^HTTP|content-type"
curl -sI https://w3cdotorg.github.io/LeLion-web/index.wasm | grep -iE "^HTTP|content-type"
curl -s https://w3cdotorg.github.io/LeLion-web/ | grep -c "viewport-fit"
docker run --rm --init -v "$PWD":/depot -v lelion5-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble \
  bash -c 'npm ci --silent && npx playwright test -c playwright.en_direct.config.js' 2>&1 | grep -E "Salle|✓|✘|passed|failed"
```

Expected : `HTTP/2 200`, `text/html` ; `HTTP/2 200`, `application/wasm` ; `0` ; `Salle XXXXXX : wss://lelion-web.w3cdotorg.workers.dev/v1/creer ; wss://lelion-web.w3cdotorg.workers.dev/v1/rejoindre/XXXXXX ; canal ouvert ; ICE [{"urls":["stun:stun.cloudflare.com:3478","stun:stun.l.google.com:19302"]}]`, `1 passed` (la page publiée, sans pilote, ses deux pages reliées par le Worker déployé ; depuis le conteneur de ce Mac, dont le pare-feu ne voit pas le trafic entre ses navigateurs).

- [ ] **Step 3 : à la main, dans un vrai navigateur de ce Mac** : ouvrir <https://w3cdotorg.github.io/LeLion-web/>, le titre puis *Multijoueur*, *Créer une partie* : le salon montre un code en moins de 5 s ; la console (F12) ne dit ni `ERROR` ni `PILOTE PRET` ; `window.lelionPilote` y vaut `undefined`. Dans le tableau de bord de Cloudflare (avec l'utilisateur) : Workers, `lelion-web`, Observability : les lignes de `journal` seulement (« origine refusée » de la sonde), aucune ligne d'invocation ni d'IP. Noter les réponses dans la PR de la feuille de route (R5).

### R4 : l'essai réel, avec l'utilisateur

- [ ] **Step 1** : envoyer à l'utilisateur la fiche `docs/essai-en-ligne.md` (sur `main`, version 0.21) et l'adresse <https://w3cdotorg.github.io/LeLion-web/> ; la case « Avant la soirée » sur la durée de vie des canaux se fait sur l'ordinateur de l'hôte (la ligne à coller dans la console) ; l'iPhone (section 4) et les réseaux qui ne se relient pas (section 2, sans TURN) sont les points neufs de cette version. La partie avec au moins 3 joueurs, dont un mobile en 4G et un joueur d'un autre foyer, est le critère de réussite de la spec (§1) et la sortie de la ligne 5.
- [ ] **Step 2** : la fiche remplie revient : ses réponses font la phase 7 bis (feuille de route), dont la décision du TURN (spec §13).

### R5 : la feuille de route et la mémoire

- [ ] **Step 1** (une PR de documentation, effet externe avec l'accord de l'utilisateur) : dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, ligne 5, remplacer `Code fait (PR #N) ; mise en ligne : runbook du plan de la phase 5.` par `Faite (PR #N), en ligne depuis le tag v0.21 (passage R) ; essai réel : <date ou « à venir »>.` (N, R : les numéros du Task 8 et du R2), et noter sous « Notes de la revue » ce que R2 et R3 ont appris (le binding `ratelimits` accepté ou non sur l'offre gratuite, ce que montre Observability, la durée du passage du tag).
- [ ] **Step 2** : la mémoire du contrôleur (le projet LeLion-web) : le Worker `lelion-web`, l'adresse, la règle `v*` de `github-pages`, le retour en arrière.

### R6 : le retour en arrière

- **La page et le Worker d'une version précédente** : relancer le passage de son tag (`gh run list --repo w3cdotorg/LeLion-web --branch vX.Y --limit 1`, puis `gh run rerun --repo w3cdotorg/LeLion-web <id>`) : il refait tout depuis l'extraction de ce tag (les tests, le Worker, la page). Pour `v0.21`, il n'y a pas de version précédente : corriger par un nouveau tag.
- **Le Worker seul** (la page reste) : l'utilisateur, dans le tableau de bord de Cloudflare (Workers, `lelion-web`, Deployments, la version précédente, Rollback), ou `npx wrangler rollback` depuis `signalisation/` avec son jeton (`CLOUDFLARE_API_TOKEN` et `CLOUDFLARE_ACCOUNT_ID` dans son terminal). Une version du Worker plus ancienne que la page n'est sûre que si le protocole de signalisation (`/v1`) n'a pas changé entre elles (aucune phase ne l'a changé depuis la phase 2). Les salles ouvertes se ferment (leurs parties continuent en WebRTC, sans nouvelles arrivées : « Invitations coupées »).
- **Retirer le jeu de la circulation** (le pire cas) : l'utilisateur désactive la route `workers.dev` du Worker (Settings, Domains & Routes) : la page dit alors « Service de connexion indisponible » à chaque création et arrivée ; Pages reste en ligne (le solo marche). La remettre : la réactiver, ou redéployer par un tag.
- Jamais de `--force` sur un tag publié, jamais de `wrangler delete` (il effacerait l'espace des Durable Objects et la migration `v1`, que le déploiement suivant recréerait vide : sans dommage pour des salles de 4 h au plus, mais inutile).
