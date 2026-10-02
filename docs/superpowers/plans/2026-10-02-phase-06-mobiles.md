# Phase 6 : mobiles

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** un téléphone (Android, iOS) rejoint une partie en ligne et la joue au doigt (spec §6) : sur un mobile, *Créer une partie* n'existe pas, l'écran En ligne a des cibles à la taille d'un doigt et sa rangée en édition remonte au-dessus du clavier virtuel, le salon a les flèches de la couleur et PRÊT, la manche le stick et VOMIR ; tenu en portrait, un voile « Tourne ton téléphone » couvre le jeu, qui continue ; le premier toucher passe en plein écran (sur ordinateur, un bouton *Plein écran* au salon) ; le son du Web se lit en `Stream`. Le banc de la prédiction gagne le profil mobile (150 ms, 60 ms, 8 %) et ses mesures décident des réglages (aucun ne change) ; la file de la signalisation rattrape ses créneaux sur un appareil lent. Sortie : **captures 360×640 et 844×390, banc vert sous le profil mobile** (feuille de route, ligne 6), et un client mobile émulé qui joue une manche au doigt dans le test de bout en bout, en CI.

**Architecture:**
- **`Parametres`** (autoload) devient aussi la plateforme du jeu en ligne : `mobile` (`OS.has_feature("web_android") or OS.has_feature("web_ios")`, la couture que les tests forcent), `CIBLE_TACTILE` (150 px de l'écran du jeu) et `agrandir(controle, police)`, le plein écran au premier toucher d'un mobile (`_input`, une fois par page) et `basculer_plein_ecran()` (le bouton du salon, d'après la fenêtre), le voile du portrait (`voile`, une `CanvasLayer` à la couche 90, relue à chaque changement de taille de la fenêtre, `actualiser_voile(taille)`).
- **`ControlesTactiles`** a deux dispositions, placées sur l'écran du mode (`placer`) : JEU (le stick, VOMIR en bas à droite, la pause sous le HUD) dans la scène de jeu, SALON (les flèches de la couleur et PRÊT, des `TouchScreenButton` qui poussent `deplacer_gauche`, `deplacer_droite`, `vomir` comme des touches) dans le salon. Affichés sur un mobile ou un écran tactile (`affiches()`).
- **`Salon`** instancie les contrôles tactiles (SALON), applique l'écran 16:9 dans `_enter_tree` (avant le placement des boutons), agrandit Retour, l'état et l'aide sur un mobile (l'aide du tactile pour un client), montre *Plein écran* sur ordinateur ; sa colonne se resserre (l'invitation de l'hôte à 63 px du bas).
- **`EcranEnLigne`** sur un mobile : ni *Créer une partie* ni « ou rejoins… », le focus au premier contrôle visible (`_donner_focus`), champs et boutons de 150 px de haut, textes agrandis, Rejoindre à l'appui ; un champ en édition (Godot 4.7 : il y entre en prenant le focus) remonte sa rangée à `MARGE_CLAVIER` px du haut, au-dessus du clavier virtuel.
- **`TransportWebRTC._vider_file`** : des créneaux d'envoi espacés de 50 ms ; une image longue (un appareil lent) rattrape les créneaux passés depuis l'image précédente, pas davantage.
- **Tests** : unitaires (le desktop n'est pas un mobile, `Stream`, le clavier virtuel des deux préréglages, la file lente et le seau de la salle) ; smoke (`_tester_mobile` : plein écran, voile, contrôles tactiles en jeu et au salon, écran En ligne) ; banc (profils `WIFI` et `MOBILE`) ; captures (`--parties=mobile`, 7 de plus : 45) ; bout en bout (`@mobile` : un Pixel 7 émulé par Chromium, de vrais touchers, face à un hôte de bureau).

**Tech Stack:** Godot 4.7.2 (GDScript typé, `TouchScreenButton`, `LineEdit.editing_toggled`, `DisplayServer`), export Web single-thread (templates `web_nothreads_*` 4.7.2), Playwright 1.63.0 (`@playwright/test`, `devices["Pixel 7 landscape"]`, CDP `Input.dispatchTouchEvent` ; image `mcr.microsoft.com/playwright:v1.63.0-noble`), Worker de la phase 2 en local (`wrangler dev`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§2 Mobiles, §5 profil mobile du banc, §6, §7, §10, §13) · feuille de route `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 6, « Notes de la revue de la phase 3 » et « Notes de la revue de la phase 4 », parties **Phase 6**, « Vérification commune », « Points de vigilance ») · plan de la phase 4 (le pilote, `tests/web/`, l'environnement du bout en bout) · prérequis : **phase 4 fusionnée** (PR #6) ; branche `phase-06-mobiles` depuis `main`. La phase 5 (déploiement) attend le compte Cloudflare : cette phase passe avant elle et ne dépend d'aucun Worker déployé (tout se joue sur `ws://localhost:8787`).

## Global Constraints

- Spec §6, mot pour mot : « Détection par `OS.has_feature("web_android")` / `OS.has_feature("web_ios")` : *Créer une partie* absent, contrôles tactiles affichés. » ; « `ControlesTactiles` (joystick et bouton Vomir du solo) s'étend au salon (couleur, Prêt) et à la manche, dans le viewport 16:9 de 2000×1125, mis à l'échelle sur petit écran. » ; « En portrait : un voile « Tourne ton téléphone » par-dessus le jeu, qui continue de tourner. » ; « Plein écran au premier toucher sur mobile ; bouton *Plein écran* dans le salon sur ordinateur (les navigateurs exigent un geste, `Parametres.gd` le respecte déjà). » ; « Son : `audio/general/default_playback_type.web` en `Stream` (plantage de Safari iOS connu en lecture `Sample` après 10 à 30 min). »
- Spec §5 et §7 : « Le banc de la prédiction gagne un **profil mobile** (150 ms de latence, 60 ms de gigue, 8 % de pertes) ; `InterpolationLion.RETARD` (6 ticks aujourd'hui) et les seuils de `PredictionLocale` ne se règlent que sur ses mesures. » ; « Le HUD et l'écran Résultats sont vérifiés en captures à 360×640 (portrait refusé, voile compris) et 844×390 (paysage mobile) en plus du 16:9 desktop. »
- Notes de la revue (feuille de route), parties **Phase 6**, mot pour mot : « Le focus de l'accueil va à `bouton_creer`, caché sur mobile : passer par une aide qui choisit le premier contrôle visible. » ; « À 844×390, l'échelle est 0,35 : Rejoindre et Copier le lien font environ 22 à 25 px de haut (moins que les 44 px d'une cible tactile). » ; « Le clavier virtuel couvre le champ du code et le message. » ; « La rangée d'invitation du salon touche le bas de l'écran (zone sûre). » ; « Coller dans un champ Godot sur mobile est peu fiable : le lien d'invitation est le chemin principal. » ; « Toute option changée dans le préréglage « Web » doit l'être dans « Web pilote » (l'unitaire de la phase 4 le vérifie) ; `experimental_virtual_keyboard` pour taper le pseudo. » ; « Envisager un client e2e en viewport mobile. » ; « Un onglet caché arrête `_process` : battements et pings s'arrêtent avec lui. » ; « iOS n'est couvert que par l'essai réel (WebKit ne relie pas deux pages dans le conteneur). » ; « La CI montre qu'un appareil lent joue au ralenti, et qu'un hôte lent ralentit tout le monde. » ; « Sur un appareil lent, `_vider_file` n'envoie qu'un message par image quand une image dure plus de 50 ms (≈ 2 messages/s à 2 i/s) […] » ; « Délai du test `@manche` : 180 s […] ; le relever à 300 s si un passage CI dépasse 120 s. »
- Valeurs de cette phase : `Parametres.CIBLE_TACTILE := 150` (px de l'écran du jeu : 44 px CSS à l'échelle 0,30 d'un iPhone en paysage sous les barres de Safari, 340 px CSS de haut ; 52 px CSS sur un 844×390, 48 sur le Pixel 7 du bout en bout) ; `ControlesTactiles.MARGE := 60` (px des bords) et `HAUT_PAUSE := 140` ; `EcranEnLigne.MARGE_CLAVIER := 40` ; la couche du voile `90` (contrôles tactiles 6, Résultats et intro 8, menu 9, CRT 100) ; profils du banc `WIFI` (80 ms, 40 ms, 5 %) et `MOBILE` (150 ms, 60 ms, 8 %) ; captures `PAYSAGE := Vector2i(844, 390)`, `PORTRAIT := Vector2i(360, 640)` ; `audio/general/default_playback_type.web=0` (l'énumération du réglage : 0 Stream, 1 Sample).
- Version et protocole (feuille de route) : `config/version` reste **0.20** ; aucune RPC ni aucun format réseau ne change : `PROTOCOLE 0.20 2553814265 (67 lignes)` avant comme après (mesuré sur ce plan appliqué).
- Commandes : `export PATH="$HOME/.orbstack/bin:/opt/homebrew/bin:$PATH"` puis `cd ~/Sites/LeLion-web` ; chaque commande godot sous `timeout`, options écrites en clair (zsh ne découpe pas une variable non quotée : `--fixed-fps` sauterait en silence). Un test qui doit échouer sur une erreur de script peut se bloquer : `timeout -k 5 120`. Une suite `--script` qui ne se compile pas sort en 0 : lire sa sortie, jamais son seul code.
- Ports : les suites Godot et le test réseau prennent les ports 17777 à 19990 de ce poste ; un autre agent qui lance les mêmes suites en même temps fait échouer l'une ou l'autre : une suite ne tourne qu'avec aucun autre `godot --headless` (`pgrep -f 'godot --headless'` vide), et un échec de port se relance une fois avant d'être diagnostiqué.
- Un test `--script` est compilé **avant** les autoloads : il récupère `Reseau`, `Scores`, `GameState`, `Parametres`, `PiloteWeb` par `root.get_node(...)`, ne les nomme jamais. `ControlesTactiles.gd` nomme `Parametres` : pas de `class_name` (les tests le prennent par sa scène). Aucun script neuf dans cette phase (aucun `.uid` à générer) ; après une modification de `traductions.csv`, l'import régénère `traductions.fr.translation` et `traductions.en.translation` : les committer avec le CSV.
- Le bout en bout local tourne dans l'image `mcr.microsoft.com/playwright:v1.63.0-noble` (Docker d'OrbStack ici) : le pare-feu de ce Mac bloque WebRTC entre les navigateurs de Playwright (plan de la phase 4, écart 13). L'export « Web pilote » se refait avant chaque passage (le test lit `export/web-pilote`).
- Les blocs « Dans X, remplacer … par … » citent le texte exact laissé par la tâche précédente (générés depuis ce plan appliqué, tâche après tâche, à une copie de la branche de la phase 4, et vérifiés par une seconde application mécanique sur une copie neuve) ; chacun se fait avec l'outil Edit (texte exact, une seule occurrence), dans l'ordre donné. « Remplacer tout le contenu de X » et « Créer X » donnent le fichier entier (outil Write) ; « À la fin de X, ajouter » colle le bloc après la dernière ligne, séparé par le nombre de lignes vides dit. Les blocs sont entourés de quatre accents graves (le README en contient trois).
- Identifiants, commentaires et messages en français, docstrings `##`, tabulations (GDScript, JavaScript, JSON du dépôt). Aucune séquence `\u…` tapée dans un fichier ; après chaque écriture, `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/web/*.js` ne sort rien. Aucun message de test ne contient `SCRIPT ERROR` ni `SHADER ERROR`.
- Bruit connu des sorties : celui des plans précédents (« ObjectDB instances were leaked », « resources still in use at exit », `ERROR: Couldn't create an ENet host.`, `ERROR: The local port number must be between 0 and 65535`, les `WARNING: Signalisation : …` des unitaires) ; dans les pages du bout en bout, `WARNING: Lion : état de l'hôte illisible, ignoré` et, sous Firefox, l'avertissement de WebAssembly sur l'instruction `try`.
- Commits en français, terminés par :
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT
  ```

## Review Focus

1. **Un mobile qui ne peut pas jouer** (*Créer une partie* encore là, le focus sur un bouton caché, des cibles de 22 px CSS, des contrôles tactiles absents du salon ou mal placés sur l'écran 16:9, Rejoindre qui rate le premier toucher pendant une saisie) : la couture `Parametres.mobile`, 150 px par cible, les dispositions JEU et SALON placées sur l'écran du mode, Rejoindre à l'appui. → smoke « sur un mobile, ni Créer une partie ni « ou rejoins… » … le premier contrôle visible », « les champs, Rejoindre et Retour font 150 px de haut au moins … », « en jeu, un mobile a le stick, VOMIR en bas à droite et la pause sous le HUD … », « au salon, un mobile a les flèches de la couleur et PRÊT … » (Tasks 1, 3, 4) ; bout en bout `@mobile` (Rejoindre et les boutons tactiles à 44 px CSS au moins, touchés pour de vrai) (Task 7).
2. **Des boutons tactiles qui agissent deux fois ou cassent les autres commandes** (une flèche tenue ou touchée d'un deuxième doigt qui change deux fois la couleur, PRÊT qui bascule deux fois, le clavier ou la manette du salon qui ne répondent plus, des boutons sur l'aide ou les cartes) : les boutons poussent leurs actions comme des touches, le salon garde sa règle de la phase 18. → smoke « la flèche droite touchée : la couleur suivante, une seule fois tant qu'elle est tenue (même d'un deuxième doigt) … », « PRÊT touché : prêt, puis plus prêt », « le clavier (et la manette) changent toujours la couleur à côté du tactile », « les boutons tactiles ne couvrent ni les cartes, ni l'état … ni l'aide d'un client … » ; les tests du salon des phases 13 et 18, inchangés (Task 3).
3. **Un mobile qui ne voit plus le jeu, ou qui s'arrête** (le voile qui met en pause, prend les touchers, ne suit pas le téléphone qui tourne ou couvre un ordinateur ; le champ en saisie et son message sous le clavier virtuel) : le voile relu à chaque changement de taille de la fenêtre, sans pause ni filtre d'entrées ; la rangée en édition remontée. → smoke « le voile ne couvre qu'un mobile en portrait … », « « Tourne ton téléphone » par-dessus les écrans … sans rien intercepter ni mettre en pause », « un refus rend le code en édition : sa rangée remonte à 40 px du haut, le message dessous dans les 40 % du haut … » (Tasks 2, 4) ; bout en bout `@mobile` (« en portrait, le voile », « le jeu continue derrière le voile », « en paysage, plus de voile ») (Task 7).
4. **Des réglages du Web oubliés ou divergents** (le son resté en `Sample`, le clavier virtuel dans un préréglage et pas l'autre, le plein écran demandé hors d'un geste ou à chaque toucher, mémorisé à tort) : `default_playback_type.web=0`, `experimental_virtual_keyboard` dans les deux préréglages (identiques option par option), le plein écran au premier toucher, une fois. → unitaires « le son du Web se lit en Stream … », « phase 6 : le clavier virtuel du navigateur s'ouvre sur un mobile … », « les deux préréglages sont identiques option par option … » (Task 1) ; smoke « un mobile demande le plein écran à son premier toucher … ; un ordinateur non », « Plein écran, cliqué : le plein écran » (Tasks 1, 3) ; bout en bout `@mobile` (« le premier toucher met le mobile en plein écran ») (Task 7).
5. **Des mesures qui mentent** (des constantes de la prédiction retouchées sans mesure, le profil mobile jugé aux seuils du Wi-Fi, une file qui étrangle un appareil lent ou vide le seau de la salle, un « client mobile » mené par des touches de clavier simulées) : chaque profil écrit ses lignes MESURE, les seuils des événements imprévisibles dépendent du profil (mesurés, justifiés), aucune constante ne change ; la file rattrape ses créneaux et le seau simulé n'est jamais à sec ; le mobile du bout en bout joue par de vrais touchers et peint. → banc « (mobile : …) … » (Task 5) ; unitaires « à 2 images par seconde, la file rattrape les créneaux de 50 ms … », « … le seau de la salle (20 jetons, 20 par seconde) n'est jamais à sec … » (Task 6) ; bout en bout `@mobile` (même empreinte sur les deux pages, « le mobile a peint au doigt ») (Task 7).

## Écarts assumés

1. **Une seule PR pour la ligne 6.** Fichiers au-delà de la ligne 6 de la feuille de route (qui ne citait que `ControlesTactiles.gd`, `EcranEnLigne.gd`, `Salon.gd`, `project.godot`, `prediction_test.gd`) : `Scripts/Parametres.gd` (la couture, le plein écran et le voile y vivent : il respecte déjà le geste du navigateur), `Scenes/ControlesTactiles.tscn`, `Scenes/Salon.tscn`, `Scripts/TransportWebRTC.gd` (la note sur `_vider_file`), `Scripts/PiloteWeb.gd`, `export_presets.cfg` (le clavier virtuel), `Assets/Traductions/traductions.csv` (+ `.translation`), `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/screenshots.gd`, `tests/web/bout_en_bout.spec.js`, `tests/web/playwright.config.js`, `.github/workflows/ci.yml`, la spec et le README. Chaque tâche touche 5 fichiers de code au plus (plafond levé par l'utilisateur depuis la phase 1 ; tenu ici quand même).
2. **La couture des tests : `Parametres.mobile`**, une variable, pas un appel à `OS.has_feature` dans chaque écran : le desktop n'a ni `web_android` ni `web_ios` (ces fonctionnalités se lisent dans l'agent utilisateur du navigateur, vérifié dans `godot.js` des templates 4.7.2 : « Android », « iPhone », « iPad », « iPod »), les tests la forcent et la remettent à faux. Les écrans la lisent à leur ouverture. Un iPad sous iPadOS se présente en « Macintosh » : il est un ordinateur pour le jeu (il peut héberger ; ses contrôles tactiles s'affichent quand même, l'écran étant tactile).
3. **Une cible au doigt fait 150 px de l'écran du jeu, pas 127** : 44 px CSS à 0,347 (844×390) donneraient 127 px, mais un iPhone en paysage sous les barres de Safari n'a que 340 px CSS de haut (0,30) et ne peut pas passer en plein écran ; le Pixel 7 du bout en bout en a 360 (0,32). Les boutons tactiles (160 px) et la pause (agrandie de 64 à 160 px, descendue sous le bandeau du HUD de la bataille) la tiennent ; Retour, les champs et Rejoindre aussi, sur un mobile. *Copier le lien* (64 px, 22 px CSS à 844×390) ne change pas : seul l'hôte le voit, et l'hôte est un ordinateur, à la souris.
4. **Les contrôles du salon sont des boutons, pas le stick** : un `TouchScreenButton` à `action` pousse un `InputEventAction` (appui, puis relâchement), que `Salon._unhandled_input` reçoit comme une touche : la règle de la phase 18 (une action à l'appui, jamais tenue) vaut telle quelle, le clavier et la manette ne changent pas. Le stick, lui, tient ses actions par `Input.action_press` sans événement : le salon ne le verrait pas. Les flèches sont des `Polygon2D` (la police de l'export Web n'a pas ◀ ni ▶) ; PRÊT est le bouton VOMIR du solo, renommé. Les tests touchent les boutons par `root.push_input(toucher, true)` : headless, la fenêtre fait 0×0 et un toucher en coordonnées de la fenêtre n'arrive à aucun bouton (mesuré).
5. **Placement sur l'écran du mode** : les boutons se placent à l'ouverture d'après la taille de l'écran (VOMIR reste en 1780×428 sur l'écran du solo, passe en 1780×905 sur celui de la bataille) ; le salon applique son écran 16:9 dans `_enter_tree`, comme `Main`, pour que ses contrôles tactiles (des enfants, prêts avant lui) se placent sur le bon écran. `ControlesTactiles.ecran_tactile()`, jamais appelé (Step 0), part dans la réécriture, remplacé par `affiches()`.
6. **Le clavier virtuel** : le Web ne donne pas sa hauteur ; sur un mobile, la rangée du champ en édition remonte à 40 px du haut de l'écran (le titre sort par le haut), le message sous le code, dans les 40 % du haut qu'un clavier en paysage laisse voir, et tout redescend à la fin de l'édition. Godot 4.7 : un `LineEdit` entre en édition quand il prend le focus (`NOTIFICATION_FOCUS_ENTER` émet `editing_toggled(true)`) et en sort quand il le perd ; `edit()` et `unedit()` n'émettent rien (lu dans `scene/gui/line_edit.cpp` de 4.7.2) : les tests passent par le focus. Rejoindre agit à l'appui sur un mobile : toucher Rejoindre pendant une saisie fait perdre le focus au champ, la rangée redescend, et un bouton qui agit au relâchement ne serait plus sous le doigt. Coller reste peu fiable : le lien d'invitation (le code déjà rempli) est le chemin principal, et un pseudo vide devient « Joueur N » chez l'hôte.
7. **Le voile** suit la taille de la fenêtre à chaque image (`Parametres._process`) : la racine ne signale pas un téléphone qui tourne (en étirement `viewport`, sa taille est l'écran du mode, fixe ; mesuré dans le bout en bout, où `size_changed` ne venait jamais). Il couvre l'écran du jeu (2000×1125 ou 2000×648 à l'échelle), pas les bandes noires autour, qui ne sont pas au jeu ; il ne met rien en pause et ne prend aucun toucher.
8. **Le plein écran** se demande au premier toucher d'un mobile, une fois par page, sans le mémoriser : un joueur qui en sort n'y est pas ramené. `Parametres` reçoit `_input` après la scène ; le premier toucher d'une page arrive à l'écran En ligne (le lien) ou au titre, où rien ne le prend avant. Safari sur iPhone n'a pas de plein écran pour un canevas : rien ne se passe (l'essai réel le dira). Sur ordinateur, *Plein écran* au salon bascule d'après la fenêtre elle-même (Échap en sort sans passer par le jeu) et mémorise la préférence, comme les Réglages.
9. **Le son en `Stream`** (spec) : l'export single-thread mélange alors le son sur le fil principal ; un téléphone lent peut grésiller (ce que `Sample` évitait). Laissé à l'essai réel (phase 7 bis).
10. **Le client mobile du bout en bout** (la note « Envisager un client e2e en viewport mobile ») est faisable et ajouté : Chromium émule un Pixel 7 en paysage (`web_android` par l'agent utilisateur, écran tactile ; densité 1 pour ménager le rendu logiciel), rejoint un hôte de bureau par le lien, touche Rejoindre, la flèche et PRÊT (`page.touchscreen.tap`), joue la manche de deux pouces (CDP `Input.dispatchTouchEvent` : le stick tenu, VOMIR tenu), voit le voile en portrait puis revient en paysage. Playwright ne retaille pas une fenêtre en plein écran : la page en sort avant de tourner. Le stick pousse aux quatre cinquièmes pour descendre (la zone morte des actions est 0,5 : le lion va à 60 % de sa vitesse, et une relecture tardive ne l'amène pas jusqu'aux toits ; à pleine vitesse, mesuré, un passage sur trois finissait sous les toits sans peindre). L'hôte ne peint pas (les lions ne se croisent pas). Mesuré : 27 s, et 1 min 30 à 1 min 50 bridé à 1,5 CPU (2 à 4 images par seconde : le mobile joue au ralenti, et peint quand même) ; le délai de 180 s par test reste. iOS n'est pas couvert (WebKit ne relie pas deux pages dans le conteneur).
11. **Le banc** : deux profils (`WIFI`, `MOBILE`) ; le mobile rejoue le parcours, l'étourdissement et le choc. Mesures (ce plan appliqué) : le parcours mobile tient tous les seuils du Wi-Fi (erreur au plus 5,83 px, aucun état au-delà de 16 px, aucun recalage, aucun à-coup, le lion distant à 4,83 à 6,44 px par tick pour 5,83) ; l'étourdissement coûte 41,50 px (5 à-coups, aucun recalage) et le choc 5,83 px : aux seuils du Wi-Fi (30 px, 4 px), les deux échoueraient. Ce sont des événements que le client ne peut pas prévoir : le lion court un aller-retour avant de les apprendre (63 px à pleine vitesse sous 150 ms et une demi-gigue) ; aucune constante n'y peut rien. Les seuils de ces deux scénarios deviennent ceux du profil (60 px et `A_COUP` sous le mobile, inchangés sous le Wi-Fi) ; `InterpolationLion.RETARD` (6), `PredictionLocale.SEUIL_RECALAGE` (200) et `DUREE_CORRECTION` (0,04) ne changent pas : aucune mesure ne le demande.
12. **La file lente** (note de la revue de la phase 4) : des créneaux d'envoi espacés de 50 ms, datés à leur créneau ; une image longue rattrape ceux qui sont passés depuis l'image précédente (jamais plus tôt : une longue attente ne s'accumule pas en rafale), toujours 15 créneaux au plus par seconde. À 2 images par seconde, une réponse et ses 8 candidats partent en 2 images au lieu de 9 ; le seau de la salle (20 jetons, 20 par seconde), simulé à 16, 200, 500 et 1000 ms par image, n'est jamais à sec. À 60 images par seconde, rien ne change (les deux unitaires de la phase 4 restent verts).
13. **L'invitation loin du bas** : la colonne du salon se resserre (écart 28 → 16 px) ; la rangée d'invitation de l'hôte finit à 63 px du bas (27 avant), la marge des boutons tactiles. Les captures du salon en changent un peu ; aucun compte ne bouge.
14. **Reporté** : un mobile revenu d'un onglet caché ou d'un écran verrouillé voit aujourd'hui « L'hôte a quitté la partie » (son propre silence de 10 s) ; « Tu as été déconnecté » et « Garde cet onglet au premier plan » vont avec la phase 7 (feuille de route, notes de la phase 4). L'écran Résultats ne change pas (spec §7) : son Quitter fait environ 20 px CSS de haut sur un téléphone (un client y attend le choix de l'hôte), et les contrôles tactiles restent visibles sous lui ; la zone morte effective du stick est celle des actions (0,5), pas la sienne (0,15) ; l'écran titre (le solo, 2000×648), où un mobile n'arrive que sans lien, garde ses boutons de 84 px (35 px CSS) ; un appareil lent joue au ralenti (constaté, sans seuil) : tout cela va à la fiche de l'essai réel (phase 7) et à ses réglages (7 bis).
15. **Version et protocole** : rien de ce que deux postes se disent ne change : version 0.20, empreinte inchangée (mesurée).
16. **Step 0** (règle du projet : `EcranEnLigne.gd` 310 lignes, `Salon.gd` 348, `TransportWebRTC.gd` 564, `tests/prediction_test.gd` 607 touchés) : rien à retirer (vérifié, Task 0).

---

### Task 0 : préparation, Step 0 et références

Ce plan est commité par le commit de planification : ne pas le recommiter, ne jamais le modifier.

**Files:** aucun (vérifications seulement).

**Interfaces:** aucune.

- [ ] **Step 1 : la branche**

```bash
export PATH="$HOME/.orbstack/bin:/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
git switch main && git pull --ff-only
git log --oneline main | grep -m1 "phase-04-webrtc" || echo "PHASE 4 ABSENTE"
git switch -c phase-06-mobiles
wc -l Scripts/Parametres.gd Scripts/ControlesTactiles.gd Scripts/EcranEnLigne.gd Scripts/Salon.gd Scripts/PiloteWeb.gd Scripts/TransportWebRTC.gd tests/unitaires.gd tests/smoke_test.gd tests/prediction_test.gd tests/screenshots.gd tests/web/bout_en_bout.spec.js
grep -n 'config/version\|default_playback_type' project.godot; grep -c 'experimental_virtual_keyboard=false' export_presets.cfg
```

Expected : la fusion de la PR de la phase 4 (`Merge pull request #6 from w3cdotorg/phase-04-webrtc`) ; `92 Scripts/Parametres.gd`, `18 Scripts/ControlesTactiles.gd`, `310 Scripts/EcranEnLigne.gd`, `348 Scripts/Salon.gd`, `245 Scripts/PiloteWeb.gd`, `564 Scripts/TransportWebRTC.gd`, `3195 tests/unitaires.gd`, `2508 tests/smoke_test.gd`, `607 tests/prediction_test.gd`, `516 tests/screenshots.gd`, `145 tests/web/bout_en_bout.spec.js` ; `config/version="0.20"` seul (pas de `default_playback_type`) ; `2`. « PHASE 4 ABSENTE » ou d'autres longueurs : s'arrêter et le signaler (les blocs de ce plan citent le texte de la branche de la phase 4 à `660a023`).

- [ ] **Step 2 : Step 0 (règle du projet, quatre fichiers touchés font plus de 300 lignes)**

```bash
for f in Scripts/EcranEnLigne.gd Scripts/Salon.gd Scripts/TransportWebRTC.gd tests/prediction_test.gd; do
	for n in $(grep -oE "^(const|var|func|static func|signal|enum) [A-Za-z_0-9]+" $f | awk '{print $NF}'); do
		[ "$(grep -rwo "$n" Scripts tests Scenes | wc -l | tr -d ' ')" -lt 2 ] && echo "seul : $f $n"
	done
done
grep -nE "^[[:space:]]*(print|prints|printt|print_debug|breakpoint)\b" Scripts/EcranEnLigne.gd Scripts/Salon.gd Scripts/TransportWebRTC.gd
grep -rwo "ecran_tactile" Scripts tests Scenes
```

Expected (mesuré) : rien pour les deux premières commandes (les `print` du banc sont son rapport, pas des journaux de débogage : seuls les scripts du jeu sont cherchés) ; `Scripts/ControlesTactiles.gd:ecran_tactile` une seule fois (jamais appelé : la Task 3 le retire en réécrivant le fichier, 18 lignes). **Pas de commit de nettoyage.** Une autre ligne `seul :` ou un `print` : le retirer dans un commit à part (`Step 0 : code mort retiré`) avant la Task 1.

- [ ] **Step 3 : les références**

```bash
pgrep -f 'godot --headless' || echo "aucun autre godot"
timeout 300 godot --headless --import . > /dev/null 2>&1
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u0.log" 2>&1; grep -E "PROTOCOLE|== " "$TMPDIR/u0.log"; grep -c "✅" "$TMPDIR/u0.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s0.log" 2>&1; grep -E "== " "$TMPDIR/s0.log"; grep -c "✅" "$TMPDIR/s0.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p0.log" 2>&1; grep -E "MESURE parcours|== " "$TMPDIR/p0.log"; grep -c "✅" "$TMPDIR/p0.log"
ls "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/" | grep web_nothreads
docker image inspect mcr.microsoft.com/playwright:v1.63.0-noble > /dev/null 2>&1 || docker pull -q mcr.microsoft.com/playwright:v1.63.0-noble
```

Expected : « aucun autre godot » (sinon attendre : mêmes ports) ; `PROTOCOLE 0.20 2553814265 (67 lignes)`, `== 0 échec(s) ==`, `525` ✅ ; smoke `== 0 échec(s) ==`, `425` ✅ ; banc : les deux lignes `MESURE parcours` (lien parfait, puis « 80 ms, 40 ms de gigue, 5 % de pertes » : erreur max 5.83 px, 0 au-delà de 16 px), `== 0 échec(s) ==`, `55` ✅ ; `web_nothreads_debug.zip` et `web_nothreads_release.zip` ; l'image Playwright présente. Noter les mesures pour la PR (jamais commitées).

---

### Task 1 : la couture `Parametres.mobile`, le plein écran, le son en `Stream`, le clavier virtuel

**Files:**
- Modify: `Scripts/Parametres.gd` (`CIBLE_TACTILE`, `mobile`, `plein_ecran_demande`, `_input`, `basculer_plein_ecran`, `agrandir`)
- Modify: `project.godot` (`[audio] general/default_playback_type.web=0`)
- Modify: `export_presets.cfg` (`html/experimental_virtual_keyboard=true` dans « Web » et « Web pilote »)
- Modify: `tests/unitaires.gd` (`_tester_mobile` ; le clavier virtuel dans la vérification des préréglages)
- Modify: `tests/smoke_test.gd` (`_tester_mobile`, `_toucher`)

**Interfaces:**
- `Parametres` : `const CIBLE_TACTILE := 150` ; `var mobile: bool` ; `var plein_ecran_demande := false` ; `func basculer_plein_ecran() -> void` ; `static func agrandir(controle: Control, police: int) -> void` ; `_input` (le premier toucher d'un mobile : `DisplayServer.window_set_mode(WINDOW_MODE_FULLSCREEN)`) ; `process_mode` à `PROCESS_MODE_ALWAYS`.
- smoke : `func _toucher(position: Vector2, appui: bool, index := 0) -> void` (un `InputEventScreenTouch` poussé en coordonnées du viewport).

- [ ] **Step 1 : le test qui échoue**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	_tester_transport_webrtc()
	_tester_protocole()
````

par :

````gdscript
	_tester_transport_webrtc()
	_tester_mobile()
	_tester_protocole()
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	gs.partie_en_cours = false


## Phase 19 (M7 de la revue de la phase 11) : `application/config/version` est aussi la version du
````

par :

````gdscript
	gs.partie_en_cours = false


## Phase 6 du jeu en ligne (spec §6) : un mobile se reconnaît aux fonctionnalités `web_android` et
## `web_ios` de l'export Web, que le desktop n'a pas ; le son du Web se lit en Stream (Safari iOS plante en
## lecture Sample après 10 à 30 min).
func _tester_mobile() -> void:
	print("-- Mobiles (phase 6)")
	var params: Node = root.get_node("Parametres")  # autoload : jamais nommé
	_check(not params.mobile and not params.plein_ecran_demande and params.CIBLE_TACTILE == 150,
		"le desktop n'est pas un mobile (ni web_android ni web_ios) ; une cible au doigt fait 150 px (44 px CSS à l'échelle 0,30 d'un iPhone en paysage sous les barres de Safari)")
	# L'énumération du réglage : 0 Stream, 1 Sample (pas celle d'AudioServer.PlaybackType).
	_check(ProjectSettings.get_setting("audio/general/default_playback_type.web") == 0,
		"le son du Web se lit en Stream (audio/general/default_playback_type.web = 0), pas en Sample")


## Phase 19 (M7 de la revue de la phase 11) : `application/config/version` est aussi la version du
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
		_check(ecarts.is_empty(), "les deux préréglages sont identiques option par option, hors name, custom_features, export_path, runnable (%s)" % [ecarts])
		var exclus := func(section: String) -> PackedStringArray:
````

par :

````gdscript
		_check(ecarts.is_empty(), "les deux préréglages sont identiques option par option, hors name, custom_features, export_path, runnable (%s)" % [ecarts])
		_check(prereglages.get_value(web + ".options", "html/experimental_virtual_keyboard", false) == true,
			"phase 6 : le clavier virtuel du navigateur s'ouvre sur un mobile pour taper le pseudo (html/experimental_virtual_keyboard)")
		var exclus := func(section: String) -> PackedStringArray:
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	await _tester_salon(params)

	# Scores
````

par :

````gdscript
	await _tester_salon(params)
	await _tester_mobile(params)

	# Scores
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	GS.niveau_courant = 0


## Un appui (ou un relâchement) de `action`, comme le clavier ou la manette l'envoient au jeu.
````

par :

````gdscript
	GS.niveau_courant = 0


## Phase 6 du jeu en ligne (spec §6) : ce que fait un mobile (`Parametres.mobile`, forcé ici : le desktop
## n'en est pas un), et le plein écran sur ordinateur ; `mobile` revient à faux à la fin.
func _tester_mobile(params: Node) -> void:
	print("-- Mobiles (phase 6)")
	var scores: Node = root.get_node("Scores")
	# Le plein écran au premier toucher d'un mobile, une seule fois par page ; jamais sur ordinateur
	await _toucher(Vector2(1000, 500), true)
	await _toucher(Vector2(1000, 500), false)
	var sur_ordinateur: bool = params.plein_ecran_demande
	params.mobile = true
	await _toucher(Vector2(1000, 500), true)
	await _toucher(Vector2(1000, 500), false)
	_check(not sur_ordinateur and params.plein_ecran_demande and not bool(scores.preference("plein_ecran", false)),
		"un mobile demande le plein écran à son premier toucher (le geste que le navigateur exige), sans le mémoriser ; un ordinateur non")
	# Le bouton Plein écran d'un ordinateur bascule d'après la fenêtre (fenêtrée ici) : il la met en plein écran
	params.basculer_plein_ecran()
	_check(params.plein_ecran and bool(scores.preference("plein_ecran", false)), "Plein écran, depuis une fenêtre : le plein écran, mémorisé")
	params.definir_plein_ecran(false)
	# Une cible au doigt : 150 px de haut au moins, sa police agrandie
	var bouton := Button.new()
	bouton.custom_minimum_size = Vector2(260, 72)
	params.agrandir(bouton, 44)
	_check(bouton.custom_minimum_size == Vector2(260, params.CIBLE_TACTILE) and bouton.get_theme_font_size("font_size") == 44,
		"agrandir : %d px de haut au moins, la police à 44 px" % params.CIBLE_TACTILE)
	bouton.free()
	params.mobile = false
	params.plein_ecran_demande = false


## Un toucher (ou son relâchement) du doigt `index` en `position` (px de l'écran du jeu), comme un écran
## tactile l'envoie.
func _toucher(position: Vector2, appui: bool, index := 0) -> void:
	var toucher := InputEventScreenTouch.new()
	toucher.index = index
	toucher.position = position
	toucher.pressed = appui
	root.push_input(toucher, true)  # coordonnées du viewport, pas de la fenêtre
	await process_frame


## Un appui (ou un relâchement) de `action`, comme le clavier ou la manette l'envoient au jeu.
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "SCRIPT ERROR|❌|== " "$TMPDIR/u.log"
timeout -k 5 120 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "SCRIPT ERROR|❌|== " "$TMPDIR/s.log"
```

Expected : `unitaires 1`, `❌ phase 6 : le clavier virtuel du navigateur s'ouvre sur un mobile pour taper le pseudo (html/experimental_virtual_keyboard)`, `SCRIPT ERROR: Invalid access to property or key 'mobile' on a base object of type 'Node (Parametres.gd)'.` (`_tester_mobile`, `res://tests/unitaires.gd:2199`), `== 1 échec(s) ==` ; `smoke 0` mais `SCRIPT ERROR: Invalid access to property or key 'plein_ecran_demande' on a base object of type 'Node (Parametres.gd)'.` (`res://tests/smoke_test.gd:2155`) : la CI échoue sur cette ligne.

- [ ] **Step 3 : `Parametres`**

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
## changement ; sauvegardés via Scores (ConfigFile dans user://, IndexedDB sur le Web).

signal volumes_changes()
````

par :

````gdscript
## changement ; sauvegardés via Scores (ConfigFile dans user://, IndexedDB sur le Web).
## Et la plateforme du jeu en ligne (spec §6) : un mobile (`mobile`) n'a pas Créer une partie, a les
## contrôles tactiles et des cibles agrandies pour le doigt (`agrandir`), passe en plein écran à son
## premier toucher ; un ordinateur a le bouton Plein écran du salon (`basculer_plein_ecran`).

signal volumes_changes()
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
const SHADER_CRT := preload("res://Shaders/Crt.gdshader")

var musique := 0.7
````

par :

````gdscript
const SHADER_CRT := preload("res://Shaders/Crt.gdshader")
## Hauteur minimale d'une cible au doigt, en px de l'écran du jeu (2000×1125 hors du solo) : les 44 px CSS
## conseillés pour une cible tactile à l'échelle 0,30 d'un iPhone en paysage sous les barres de Safari
## (340 px CSS de haut : 340 / 1125) ; 52 px CSS sur un 844×390.
const CIBLE_TACTILE := 150

var musique := 0.7
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
var couche_crt: CanvasLayer


func _ready() -> void:
````

par :

````gdscript
var couche_crt: CanvasLayer
## Vrai sur un mobile (Android, iOS) dans l'export Web (spec §6 : `web_android`, `web_ios`, lus dans
## l'agent utilisateur du navigateur) ; faux ailleurs. Lu par les écrans à leur ouverture ; modifiable par
## les tests (le desktop n'a ni l'un ni l'autre).
var mobile := OS.has_feature("web_android") or OS.has_feature("web_ios")
## Vrai une fois le plein écran demandé par un premier toucher (une seule fois par page : un joueur qui
## en sort n'y est pas ramené au toucher suivant).
var plein_ecran_demande := false


func _ready() -> void:
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
func _ready() -> void:
	musique = clampf(float(Scores.preference("musique", musique)), 0.0, 1.0)
````

par :

````gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # le premier toucher compte aussi sur un écran figé
	musique = clampf(float(Scores.preference("musique", musique)), 0.0, 1.0)
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
		_appliquer_plein_ecran()


func _langue_systeme() -> String:
````

par :

````gdscript
		_appliquer_plein_ecran()


## Sur un mobile, le premier toucher demande le plein écran (spec §6) : le navigateur ne l'accorde que
## pendant un geste de l'utilisateur, et ce toucher en est un. Pas mémorisé dans les préférences.
func _input(event: InputEvent) -> void:
	if mobile and not plein_ecran_demande and event is InputEventScreenTouch and event.pressed:
		plein_ecran_demande = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _langue_systeme() -> String:
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
	_appliquer_plein_ecran()


func definir_langue(nouvelle: String) -> void:
````

par :

````gdscript
	_appliquer_plein_ecran()


## Le bouton Plein écran du salon, sur ordinateur (spec §6 ; un clic, le geste que le navigateur exige) :
## bascule d'après la fenêtre elle-même, pas d'après la préférence (sur le Web, Échap sort du plein écran
## sans passer par le jeu).
func basculer_plein_ecran() -> void:
	definir_plein_ecran(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)


func definir_langue(nouvelle: String) -> void:
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
		DisplayServer.WINDOW_MODE_FULLSCREEN if plein_ecran else DisplayServer.WINDOW_MODE_WINDOWED)


## dB à appliquer à un lecteur pour un volume linéaire 0..1 (silence total à 0).
````

par :

````gdscript
		DisplayServer.WINDOW_MODE_FULLSCREEN if plein_ecran else DisplayServer.WINDOW_MODE_WINDOWED)


## Agrandit `controle` pour le doigt (sur un mobile) : CIBLE_TACTILE px de haut au moins, sa police à
## `police` px.
static func agrandir(controle: Control, police: int) -> void:
	controle.custom_minimum_size.y = maxf(controle.custom_minimum_size.y, CIBLE_TACTILE)
	controle.add_theme_font_size_override("font_size", police)


## dB à appliquer à un lecteur pour un volume linéaire 0..1 (silence total à 0).
````

- [ ] **Step 4 : le son et le clavier virtuel**

Dans `project.godot`, remplacer :

````ini
config/icon="res://icon.png"

[autoload]
````

par :

````ini
config/icon="res://icon.png"

[audio]

general/default_playback_type.web=0

[autoload]
````

Dans `export_presets.cfg`, remplacer partout (2 occurrences : « Web », puis « Web pilote ») :

````ini
html/experimental_virtual_keyboard=false
````

par :

````ini
html/experimental_virtual_keyboard=true
````

Les deux préréglages changent ensemble (l'unitaire de la phase 4 les veut identiques option par option) : l'outil Edit avec `replace_all`, puis `grep -c 'experimental_virtual_keyboard=true' export_presets.cfg` donne `2`.

- [ ] **Step 5 : le test passe**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u.log"; grep -c "✅" "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"; grep -c "✅" "$TMPDIR/s.log"
```

Expected : rien à l'import ; unitaires `0`, `PROTOCOLE 0.20 2553814265 (67 lignes)`, `== 0 échec(s) ==`, 528 ✅ ; smoke `0`, `== 0 échec(s) ==`, 428 ✅.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Parametres.gd project.godot export_presets.cfg tests/unitaires.gd tests/smoke_test.gd
git commit -m "Mobiles : la couture Parametres.mobile, le plein écran au premier toucher, le bouton Plein écran, le son en Stream, le clavier virtuel

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 2 : le voile du portrait, et les textes du tactile

**Files:**
- Modify: `Scripts/Parametres.gd` (`voile`, `_taille_fenetre`, `_process`, `_creer_voile`, `actualiser_voile`)
- Modify: `Assets/Traductions/traductions.csv` (+ `traductions.fr.translation`, `traductions.en.translation`, régénérés par l'import) : `SALON_AIDE_TACTILE`, `SALON_PLEIN_ECRAN`, `TACTILE_PRET`, `VOILE_PORTRAIT`
- Modify: `tests/smoke_test.gd` (le voile dans `_tester_mobile`)

**Interfaces:**
- `Parametres` : `var voile: CanvasLayer` (couche 90 : un `ColorRect` plein écran, `MOUSE_FILTER_IGNORE`, et l'étiquette `VOILE_PORTRAIT`) ; `func actualiser_voile(taille: Vector2i = DisplayServer.window_get_size()) -> void` (visible si `mobile` et `taille.y > taille.x`) ; `_process` la rappelle à chaque changement de taille de la fenêtre.

- [ ] **Step 1 : le test qui échoue**

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	bouton.free()
	params.mobile = false
````

par :

````gdscript
	bouton.free()
	# Le voile du portrait : sur un mobile tenu en portrait seulement, au-dessus des écrans et des contrôles
	# tactiles, sous le filtre CRT ; il n'intercepte rien et n'arrête rien
	var voile: CanvasLayer = params.voile
	var vus := {}
	for taille: Vector2i in [Vector2i(360, 640), Vector2i(844, 390), Vector2i(0, 0)]:
		params.actualiser_voile(taille)
		vus[taille] = voile.visible
	params.mobile = false
	params.actualiser_voile(Vector2i(360, 640))
	var portrait_ordinateur: bool = voile.visible
	params.mobile = true
	params.actualiser_voile(Vector2i(360, 640))
	var fond: ColorRect = voile.get_child(0)
	var texte: Label = fond.get_child(0)
	_check(vus == {Vector2i(360, 640): true, Vector2i(844, 390): false, Vector2i(0, 0): false} and not portrait_ordinateur,
		"le voile ne couvre qu'un mobile en portrait (360×640) : ni en paysage (844×390), ni sans fenêtre, ni sur un ordinateur (%s)" % [vus])
	_check(voile.layer > 9 and voile.layer < params.couche_crt.layer and fond.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and texte.mouse_filter == Control.MOUSE_FILTER_IGNORE and tr(texte.text) == "Tourne ton téléphone" and not paused,
		"« Tourne ton téléphone » par-dessus les écrans (couche %d : contrôles tactiles 6, Résultats 8, menu 9), sous le CRT, sans rien intercepter ni mettre en pause" % voile.layer)
	params.actualiser_voile(Vector2i(844, 390))
	params.mobile = false
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "SCRIPT ERROR|❌|== " "$TMPDIR/s.log"
```

Expected : `SCRIPT ERROR: Invalid access to property or key 'voile' on a base object of type 'Node (Parametres.gd)'.` (`_tester_mobile`, `res://tests/smoke_test.gd:2174`).

- [ ] **Step 3 : le voile**

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
## contrôles tactiles et des cibles agrandies pour le doigt (`agrandir`), passe en plein écran à son
## premier toucher ; un ordinateur a le bouton Plein écran du salon (`basculer_plein_ecran`).

signal volumes_changes()
````

par :

````gdscript
## contrôles tactiles et des cibles agrandies pour le doigt (`agrandir`), passe en plein écran à son
## premier toucher ; un ordinateur a le bouton Plein écran du salon (`basculer_plein_ecran`). Tenu en
## portrait, un mobile montre le voile « Tourne ton téléphone » (`voile`) par-dessus le jeu, qui continue.

signal volumes_changes()
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
var plein_ecran_demande := false


func _ready() -> void:
````

par :

````gdscript
var plein_ecran_demande := false
## Le voile du portrait (spec §6), au-dessus de tous les écrans et sous le filtre CRT : visible sur un mobile
## tenu en portrait (`actualiser_voile`), sans rien arrêter ni rien intercepter (le jeu continue derrière).
var voile: CanvasLayer
## La taille de la fenêtre à l'image précédente : le voile suit ses changements (le téléphone tourné), que la
## racine ne signale pas (sa taille est l'écran fixe du mode, `content_scale_size`).
var _taille_fenetre := Vector2i(-1, -1)


func _ready() -> void:
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
	_creer_couche_crt()
	# Sur le Web, le plein écran exige un geste de l'utilisateur : on ne l'applique qu'au clic.
````

par :

````gdscript
	_creer_couche_crt()
	_creer_voile()
	# Sur le Web, le plein écran exige un geste de l'utilisateur : on ne l'applique qu'au clic.
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
		_appliquer_plein_ecran()


## Sur un mobile, le premier toucher demande le plein écran (spec §6) : le navigateur ne l'accorde que
````

par :

````gdscript
		_appliquer_plein_ecran()


func _process(_delta: float) -> void:
	var taille := DisplayServer.window_get_size()
	if taille != _taille_fenetre:
		_taille_fenetre = taille
		actualiser_voile(taille)


## Sur un mobile, le premier toucher demande le plein écran (spec §6) : le navigateur ne l'accorde que
````

Dans `Scripts/Parametres.gd`, remplacer :

````gdscript
	couche_crt.visible = crt


func definir_crt(actif: bool) -> void:
````

par :

````gdscript
	couche_crt.visible = crt


## Le voile : un fond sombre presque opaque et « Tourne ton téléphone », sur l'écran du mode (16:9 ou celui
## du solo, que la fenêtre montre à l'échelle).
func _creer_voile() -> void:
	voile = CanvasLayer.new()
	voile.name = "VoilePortrait"
	voile.layer = 90
	var fond := ColorRect.new()
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.color = Color(0.06, 0.05, 0.14, 0.92)
	var texte := Label.new()
	texte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte.text = "VOILE_PORTRAIT"
	texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.add_theme_font_size_override("font_size", 120)
	texte.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	fond.add_child(texte)
	voile.add_child(fond)
	voile.visible = false
	add_child(voile)


## Montre le voile sur un mobile dont la fenêtre `taille` (par défaut, celle du jeu) est plus haute que
## large, le cache sinon. Appelée à la première image, puis à chaque changement de taille de la fenêtre
## (le téléphone tourné).
func actualiser_voile(taille: Vector2i = DisplayServer.window_get_size()) -> void:
	voile.visible = mobile and taille.y > taille.x


func definir_crt(actif: bool) -> void:
````

- [ ] **Step 4 : les textes**

Dans `Assets/Traductions/traductions.csv`, remplacer :

````csv
SALON_SALLE_FERMEE,Invitations coupées : crée une nouvelle partie pour inviter,Invitations closed: create a new game to invite
PAUSE_RESEAU,La partie continue,The game goes on
````

par :

````csv
SALON_SALLE_FERMEE,Invitations coupées : crée une nouvelle partie pour inviter,Invitations closed: create a new game to invite
SALON_AIDE_TACTILE,"Flèches : ta couleur   ·   PRÊT : prêt ou pas","Arrows: your color   ·   READY: ready or not"
SALON_PLEIN_ECRAN,Plein écran,Full screen
TACTILE_PRET,PRÊT,READY
VOILE_PORTRAIT,Tourne ton téléphone,Turn your phone sideways
PAUSE_RESEAU,La partie continue,The game goes on
````
```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
git status --short Assets/Traductions
```

Expected : rien à l'import ; le CSV et les deux `.translation` modifiés.

- [ ] **Step 5 : le test passe**

```bash
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"; grep -c "✅" "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u.log"
```

Expected : smoke `0`, `== 0 échec(s) ==`, 430 ✅ ; unitaires `0`, `== 0 échec(s) ==`.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Parametres.gd Assets/Traductions/traductions.csv Assets/Traductions/traductions.fr.translation Assets/Traductions/traductions.en.translation tests/smoke_test.gd
git commit -m "Mobiles : le voile « Tourne ton téléphone » en portrait, et les textes du tactile

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 3 : les contrôles tactiles au salon et en manche ; Plein écran ; l'invitation loin du bas

**Files:**
- Modify: `Scenes/ControlesTactiles.tscn` (réécrit : étiquettes enfants de leurs boutons, la pause à 160 px sous le HUD, `BoutonGauche` et `BoutonDroite`)
- Modify: `Scripts/ControlesTactiles.gd` (réécrit : `Disposition`, `MARGE`, `HAUT_PAUSE`, `affiches()`, `placer()` ; `ecran_tactile()` retiré)
- Modify: `Scenes/Salon.tscn` (l'écart de la colonne, `BoutonPleinEcran`, l'instance `ControlesTactiles` en SALON)
- Modify: `Scripts/Salon.gd` (`_enter_tree`, la mise en page mobile, `basculer_plein_ecran`, l'aide du tactile)
- Modify: `tests/smoke_test.gd` (`_tester_tactile_mobile`, `_rect_du_texte`)

**Interfaces:**
- `ControlesTactiles` (sans `class_name`) : `enum Disposition { JEU, SALON }`, `const MARGE := 60`, `const HAUT_PAUSE := 140`, `@export var disposition := Disposition.JEU` ; `joystick`, `bouton_vomir`, `etiquette_vomir`, `bouton_pause`, `bouton_gauche`, `bouton_droite` ; `static func affiches() -> bool` ; `func placer(taille: Vector2) -> void`.
- `Salon` : `bouton_plein_ecran: Button`, `controles_tactiles: CanvasLayer` ; `func basculer_plein_ecran() -> void`.

- [ ] **Step 1 : le test qui échoue**

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	params.actualiser_voile(Vector2i(844, 390))
	params.mobile = false
	params.plein_ecran_demande = false


## Un toucher (ou son relâchement) du doigt `index` en `position` (px de l'écran du jeu), comme un écran
````

par :

````gdscript
	params.actualiser_voile(Vector2i(844, 390))
	await _tester_tactile_mobile(params)
	params.mobile = false
	params.plein_ecran_demande = false


## Phase 6 : les contrôles tactiles d'un mobile, en jeu (sur l'écran du solo et sur celui de la bataille)
## et au salon (la couleur et Prêt au doigt, une action par appui), Retour agrandi ; sur ordinateur, le
## bouton Plein écran du salon, et la rangée d'invitation loin du bas de l'écran.
func _tester_tactile_mobile(params: Node) -> void:
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var cible: int = params.CIBLE_TACTILE
	# En jeu : le stick, VOMIR en bas à droite et la pause, sur l'écran du mode, chaque bouton à MARGE px des
	# bords, de CIBLE_TACTILE px au moins
	var places := {}
	var dedans := true
	for taille: Vector2i in [Vector2i(2000, 648), Vector2i(2000, 1125)]:
		root.content_scale_size = taille
		var jeu: CanvasLayer = load("res://Scenes/ControlesTactiles.tscn").instantiate()
		root.add_child(jeu)
		places[taille] = [jeu.bouton_vomir.position, jeu.bouton_pause.position]
		for bouton: TouchScreenButton in [jeu.bouton_vomir, jeu.bouton_pause]:
			var rect := Rect2(bouton.position, bouton.texture_normal.get_size() * bouton.scale)
			dedans = dedans and rect.size.x >= cible and Rect2(Vector2.ONE * jeu.MARGE, Vector2(taille) - Vector2.ONE * 2 * jeu.MARGE).encloses(rect)
		dedans = dedans and jeu.visible and jeu.joystick.visible and not jeu.bouton_gauche.visible and not jeu.bouton_droite.visible
		jeu.free()
	_check(dedans and places[Vector2i(2000, 648)] == [Vector2(1780, 428), Vector2(1780, 140)] and places[Vector2i(2000, 1125)] == [Vector2(1780, 905), Vector2(1780, 140)],
		"en jeu, un mobile a le stick, VOMIR en bas à droite et la pause sous le HUD, à %d px des bords, de %d px au moins, sur l'écran du solo comme sur celui de la bataille (%s)" % [60, cible, places])

	# Au salon, sur un mobile : les flèches de la couleur et PRÊT, ni stick ni pause ; Retour agrandi, pas de
	# Plein écran
	reseau.pseudo = "Mo"
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await process_frame
	var tactile: CanvasLayer = salon.controles_tactiles
	_check(tactile.visible and tactile.disposition == tactile.Disposition.SALON and tactile.bouton_gauche.visible and tactile.bouton_droite.visible
		and tactile.bouton_vomir.visible and not tactile.joystick.visible and not tactile.bouton_pause.visible and tr(tactile.etiquette_vomir.text) == "PRÊT"
		and tactile.bouton_gauche.action == "deplacer_gauche" and tactile.bouton_droite.action == "deplacer_droite" and tactile.bouton_vomir.action == "vomir",
		"au salon, un mobile a les flèches de la couleur et PRÊT, sans stick ni pause")
	_check(not salon.bouton_plein_ecran.visible and salon.bouton_retour.size.y >= cible and salon.etat.get_theme_font_size("font_size") == 48
		and salon.aide.get_theme_font_size("font_size") == 40, "un mobile n'a pas Plein écran ; Retour fait %d px de haut, l'état et l'aide sont agrandis" % salon.bouton_retour.size.y)
	var centre := func(bouton: TouchScreenButton) -> Vector2: return bouton.position + bouton.texture_normal.get_size() / 2.0
	await _toucher(centre.call(tactile.bouton_droite), true)
	await _toucher(centre.call(tactile.bouton_droite), true, 1)  # un deuxième doigt sur la flèche déjà tenue
	var tenue: Color = reseau.inscrits[1].couleur
	await _toucher(centre.call(tactile.bouton_droite), false, 1)
	await _toucher(centre.call(tactile.bouton_droite), false)
	await _toucher(centre.call(tactile.bouton_droite), true)
	await _toucher(centre.call(tactile.bouton_droite), false)
	var deux_fois: Color = reseau.inscrits[1].couleur
	await _toucher(centre.call(tactile.bouton_gauche), true)
	await _toucher(centre.call(tactile.bouton_gauche), false)
	_check(tenue == palette[1] and deux_fois == palette[2] and reseau.inscrits[1].couleur == palette[1],
		"la flèche droite touchée : la couleur suivante, une seule fois tant qu'elle est tenue (même d'un deuxième doigt), puis encore ; la gauche : la précédente")
	await _toucher(centre.call(tactile.bouton_vomir), true)
	await _toucher(centre.call(tactile.bouton_vomir), false)
	var pret: bool = reseau.inscrits[1].pret
	await _toucher(centre.call(tactile.bouton_vomir), true)
	await _toucher(centre.call(tactile.bouton_vomir), false)
	_check(pret and not reseau.inscrits[1].pret, "PRÊT touché : prêt, puis plus prêt")
	await _appuyer(&"deplacer_droite", true)
	await _appuyer(&"deplacer_droite", false)
	_check(reseau.inscrits[1].couleur == palette[2], "le clavier (et la manette) changent toujours la couleur à côté du tactile")
	salon.retour(false)
	salon.free()
	# Un client (le seul rôle d'un mobile) : l'aide du tactile ; les boutons tactiles ne couvrent ni les
	# cartes, ni l'état, ni le texte de l'aide
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est un client")
	var client: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(client)
	await process_frame
	_check(client.aide.text == tr("SALON_AIDE_TACTILE") and tr("SALON_AIDE_TACTILE").begins_with("Flèches : ta couleur"),
		"un client sur mobile lit l'aide du tactile : « %s »" % client.aide.text)
	var couverts: Array[String] = []
	for langue in ["fr", "en"]:
		params.definir_langue(langue)
		for cle in ["SALON_ATTENTE_JOUEURS", "SALON_ATTENTE_ARRIVEE", "SALON_ATTENTE_PRETS", "SALON_ATTENTE_HOTE"]:
			client.etat.text = tr(cle)
			await process_frame
			for bouton: TouchScreenButton in [client.controles_tactiles.bouton_gauche, client.controles_tactiles.bouton_droite, client.controles_tactiles.bouton_vomir]:
				var rect := Rect2(bouton.position, bouton.texture_normal.get_size())
				for zone: Array in [["cartes", client.rangee_cartes.get_global_rect()], [cle, _rect_du_texte(client.etat)], ["aide", _rect_du_texte(client.aide)]]:
					if rect.intersects(zone[1]):
						couverts.append("%s sur %s (%s)" % [bouton.name, zone[0], langue])
	params.definir_langue("fr")
	_check(couverts.is_empty(), "les boutons tactiles ne couvrent ni les cartes, ni l'état (chacun de ses textes), ni l'aide d'un client, en français comme en anglais (%s)" % [couverts])
	client.retour(false)
	client.free()

	# Sur ordinateur : pas de tactile (pas d'écran tactile ici), le bouton Plein écran en haut à droite ; la
	# rangée d'invitation de l'hôte reste à 60 px au moins du bas de l'écran
	params.mobile = false
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	reseau.code_partie = "K7Q2XM"
	var bureau: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(bureau)
	await process_frame
	var plein: Rect2 = bureau.bouton_plein_ecran.get_global_rect()
	_check(not bureau.controles_tactiles.visible and bureau.bouton_plein_ecran.visible and plein.end.x <= 2000 - 20 and plein.position.y <= 30
		and bureau.bouton_plein_ecran.focus_mode == Control.FOCUS_NONE and tr(bureau.bouton_plein_ecran.text) == "Plein écran",
		"sur ordinateur : pas de tactile, « Plein écran » en haut à droite, sans focus")
	bureau.bouton_plein_ecran.pressed.emit()
	_check(params.plein_ecran, "Plein écran, cliqué : le plein écran")
	params.definir_plein_ecran(false)
	var bas: float = bureau.rangee_invitation.get_global_rect().end.y
	_check(bureau.rangee_invitation.visible and bas <= 1125 - 60, "la rangée d'invitation de l'hôte finit à %d px du bas de l'écran (60 au moins : la zone sûre)" % (1125 - bas))
	bureau.retour(false)
	bureau.free()
	reseau.pseudo = ""
	params.mobile = true


## Le rectangle (px de l'écran) du texte d'une étiquette centrée sur une ligne, plus étroit qu'elle.
func _rect_du_texte(etiquette: Label) -> Rect2:
	var largeur: float = etiquette.get_theme_font("font").get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		etiquette.get_theme_font_size("font_size")).x
	return Rect2(etiquette.global_position + Vector2((etiquette.size.x - largeur) / 2.0, 0), Vector2(largeur, etiquette.size.y))


## Un toucher (ou son relâchement) du doigt `index` en `position` (px de l'écran du jeu), comme un écran
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "SCRIPT ERROR|❌|== " "$TMPDIR/s.log"
```

Expected : `SCRIPT ERROR: Invalid access to property or key 'bouton_vomir' on a base object of type 'CanvasLayer (ControlesTactiles.gd)'.` (`_tester_tactile_mobile`, `res://tests/smoke_test.gd:2212`).

- [ ] **Step 3 : les contrôles tactiles**

Remplacer tout le contenu de `Scenes/ControlesTactiles.tscn` par :

````ini
[gd_scene load_steps=4 format=3 uid="uid://dleliontactil"]

[ext_resource type="Script" path="res://Scripts/ControlesTactiles.gd" id="1_tactile"]
[ext_resource type="Script" path="res://Scripts/Joystick.gd" id="2_joystick"]
[ext_resource type="Texture2D" path="res://Assets/Sprites/anneau.png" id="3_anneau"]

[node name="ControlesTactiles" type="CanvasLayer"]
process_mode = 3
layer = 6
script = ExtResource("1_tactile")

[node name="Joystick" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("2_joystick")

[node name="BoutonVomir" type="TouchScreenButton" parent="."]
modulate = Color(1, 0.6, 0.85, 0.85)
position = Vector2(1780, 428)
texture_normal = ExtResource("3_anneau")
action = "vomir"

[node name="Etiquette" type="Label" parent="BoutonVomir"]
offset_right = 160.0
offset_bottom = 160.0
mouse_filter = 2
theme_override_font_sizes/font_size = 34
text = "VOMIR"
horizontal_alignment = 1
vertical_alignment = 1

[node name="BoutonPause" type="TouchScreenButton" parent="."]
modulate = Color(1, 1, 1, 0.7)
position = Vector2(1780, 140)
texture_normal = ExtResource("3_anneau")
action = "pause"

[node name="Etiquette" type="Label" parent="BoutonPause"]
offset_right = 160.0
offset_bottom = 160.0
mouse_filter = 2
theme_override_font_sizes/font_size = 52
text = "II"
horizontal_alignment = 1
vertical_alignment = 1

[node name="BoutonGauche" type="TouchScreenButton" parent="."]
visible = false
modulate = Color(1, 1, 1, 0.85)
position = Vector2(60, 905)
texture_normal = ExtResource("3_anneau")
action = "deplacer_gauche"

[node name="Fleche" type="Polygon2D" parent="BoutonGauche"]
polygon = PackedVector2Array(108, 40, 108, 120, 44, 80)

[node name="BoutonDroite" type="TouchScreenButton" parent="."]
visible = false
modulate = Color(1, 1, 1, 0.85)
position = Vector2(280, 905)
texture_normal = ExtResource("3_anneau")
action = "deplacer_droite"

[node name="Fleche" type="Polygon2D" parent="BoutonDroite"]
polygon = PackedVector2Array(52, 40, 52, 120, 116, 80)
````

Remplacer tout le contenu de `Scripts/ControlesTactiles.gd` par :

````gdscript
extends CanvasLayer
## Les contrôles tactiles (spec §6 du jeu en ligne) : affichés sur un mobile (`Parametres.mobile`) ou sur
## un écran tactile (`affiches`), ou forcés pour un ordinateur (`forcer_affichage`). Deux dispositions,
## placées sur l'écran du mode à l'ouverture (2000×648 en solo, 2000×1125 en bataille et au salon, que la
## fenêtre montre à l'échelle) :
## - JEU (la scène de jeu) : le stick (là où le pouce touche la moitié gauche), VOMIR en bas à droite, la
##   pause en haut à droite, sous le bandeau du HUD de la bataille ;
## - SALON : les flèches de la couleur (`deplacer_gauche`, `deplacer_droite`) en bas à gauche, PRÊT
##   (`vomir`) en bas à droite.
## Chaque bouton (`TouchScreenButton.action`) pousse son action comme une touche, à l'appui puis au
## relâchement : le salon n'agit qu'à l'appui, jamais tenu (phase 18), comme au clavier et à la manette,
## inchangés. Chaque bouton fait `Parametres.CIBLE_TACTILE` px de côté au moins et reste à MARGE px des
## bords de l'écran (la zone sûre d'un téléphone : ses coins arrondis, sa barre du bas).

enum Disposition { JEU, SALON }

## Marge des boutons aux bords de l'écran, en px du jeu (18 à 21 px CSS sur un téléphone en paysage).
const MARGE := 60
## Le haut du bouton de pause : sous le bandeau des vignettes du HUD de la bataille (10 + 112 px).
const HAUT_PAUSE := 140

@export var forcer_affichage := false  # pour tester sur un ordinateur
@export var disposition := Disposition.JEU

@onready var joystick: Control = $Joystick
@onready var bouton_vomir: TouchScreenButton = $BoutonVomir
@onready var etiquette_vomir: Label = $BoutonVomir/Etiquette
@onready var bouton_pause: TouchScreenButton = $BoutonPause
@onready var bouton_gauche: TouchScreenButton = $BoutonGauche
@onready var bouton_droite: TouchScreenButton = $BoutonDroite


func _ready() -> void:
	visible = forcer_affichage or affiches()
	var jeu := disposition == Disposition.JEU
	joystick.visible = jeu
	bouton_pause.visible = jeu
	bouton_gauche.visible = not jeu
	bouton_droite.visible = not jeu
	etiquette_vomir.text = "VOMIR" if jeu else "TACTILE_PRET"
	placer(get_viewport().get_visible_rect().size)
	for enfant in get_children():
		if enfant is TouchScreenButton:
			enfant.set_process_input(visible and enfant.visible)
	joystick.set_process_input(visible and jeu)


## Vrai si ce poste montre les contrôles tactiles : un mobile, ou tout écran tactile.
static func affiches() -> bool:
	return Parametres.mobile or DisplayServer.is_touchscreen_available()


## Place les boutons sur l'écran `taille` (px du jeu) : VOMIR (PRÊT au salon) en bas à droite, les flèches
## en bas à gauche, la pause en haut à droite ; le stick, lui, suit le pouce.
func placer(taille: Vector2) -> void:
	var cote := bouton_vomir.texture_normal.get_size().x
	var bas := taille.y - MARGE - cote
	bouton_vomir.position = Vector2(taille.x - MARGE - cote, bas)
	bouton_gauche.position = Vector2(MARGE, bas)
	bouton_droite.position = Vector2(MARGE + cote + MARGE, bas)
	bouton_pause.position = Vector2(taille.x - MARGE - cote, HAUT_PAUSE)
````

- [ ] **Step 4 : le salon**

Dans `Scenes/Salon.tscn`, remplacer :

````ini
[gd_scene load_steps=4 format=3 uid="uid://dlelionsalon"]

[ext_resource type="Script" path="res://Scripts/Salon.gd" id="1_salon"]

[sub_resource type="Gradient" id="Gradient_ciel"]
````

par :

````ini
[gd_scene load_steps=5 format=3 uid="uid://dlelionsalon"]

[ext_resource type="Script" path="res://Scripts/Salon.gd" id="1_salon"]
[ext_resource type="PackedScene" uid="uid://dleliontactil" path="res://Scenes/ControlesTactiles.tscn" id="2_tactile"]

[sub_resource type="Gradient" id="Gradient_ciel"]
````

Dans `Scenes/Salon.tscn`, remplacer :

````ini
layout_mode = 2
theme_override_constants/separation = 28
alignment = 1
````

par :

````ini
layout_mode = 2
theme_override_constants/separation = 16
alignment = 1
````

Dans `Scenes/Salon.tscn`, remplacer :

````ini
text = "RETOUR"

[connection signal="pressed" from="BoutonRetour" to="." method="retour"]
[connection signal="pressed" from="Centre/Colonne/Demarrer" to="." method="demarrer"]
````

par :

````ini
text = "RETOUR"

[node name="BoutonPleinEcran" type="Button" parent="."]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -344.0
offset_top = 24.0
offset_right = -24.0
offset_bottom = 100.0
grow_horizontal = 0
focus_mode = 0
theme_override_font_sizes/font_size = 26
text = "SALON_PLEIN_ECRAN"

[node name="ControlesTactiles" parent="." instance=ExtResource("2_tactile")]
disposition = 1

[connection signal="pressed" from="BoutonRetour" to="." method="retour"]
[connection signal="pressed" from="BoutonPleinEcran" to="." method="basculer_plein_ecran"]
[connection signal="pressed" from="Centre/Colonne/Demarrer" to="." method="demarrer"]
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
## cliquent à la souris) : les flèches, la croix, le stick, vomir et démarrer arrivent tous à
## `_unhandled_input`.

const SCENE_JEU := "res://Scenes/Main.tscn"
````

par :

````gdscript
## cliquent à la souris) : les flèches, la croix, le stick, vomir et démarrer arrivent tous à
## `_unhandled_input`, comme les boutons tactiles (`ControlesTactiles`, disposition SALON : les flèches
## de la couleur et PRÊT, qui poussent leurs actions à l'appui).
##
## Mobiles (spec §6, `Parametres.mobile`) : Retour agrandi pour le doigt, l'état et l'aide (celle du
## tactile) lisibles à l'échelle d'un téléphone. Sur un ordinateur, le bouton Plein écran (en haut à
## droite : le navigateur exige le geste d'un clic).

const SCENE_JEU := "res://Scenes/Main.tscn"
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
@onready var bouton_retour: Button = $BoutonRetour

## Vrai une fois la manche lancée : plus rien ne se décide ici pendant le changement de scène.
````

par :

````gdscript
@onready var bouton_retour: Button = $BoutonRetour
@onready var bouton_plein_ecran: Button = $BoutonPleinEcran
@onready var controles_tactiles: CanvasLayer = $ControlesTactiles

## Vrai une fois la manche lancée : plus rien ne se décide ici pendant le changement de scène.
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
var _tenues: Dictionary[StringName, bool] = {}


func _ready() -> void:
````

par :

````gdscript
var _tenues: Dictionary[StringName, bool] = {}


## Avant les _ready des enfants : les contrôles tactiles se placent sur l'écran du salon (16:9).
func _enter_tree() -> void:
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)


func _ready() -> void:
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
		_tenues[action] = Input.is_action_pressed(action)
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
	for i in range(EtatPartie.NB_JOUEURS_MAX):
````

par :

````gdscript
		_tenues[action] = Input.is_action_pressed(action)
	bouton_plein_ecran.visible = not Parametres.mobile
	if Parametres.mobile:
		Parametres.agrandir(bouton_retour, 40)
		etat.add_theme_font_size_override("font_size", 48)
		aide.add_theme_font_size_override("font_size", 40)
	for i in range(EtatPartie.NB_JOUEURS_MAX):
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
	return lien


func _remettre_bouton_copier() -> void:
````

par :

````gdscript
	return lien


## Sur un ordinateur : le plein écran, ou la fenêtre (le clic sur le bouton est le geste du navigateur).
func basculer_plein_ecran() -> void:
	Parametres.basculer_plein_ecran()


func _remettre_bouton_copier() -> void:
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
	titre_niveau.text = tr("SALON_NIVEAU") % tr(GameState.NIVEAUX[Reseau.niveau_salon].nom)
	aide.text = tr("SALON_AIDE_HOTE" if hote else "SALON_AIDE")
	rangee_invitation.visible = hote and not Reseau.code_partie.is_empty()
````

par :

````gdscript
	titre_niveau.text = tr("SALON_NIVEAU") % tr(GameState.NIVEAUX[Reseau.niveau_salon].nom)
	aide.text = tr("SALON_AIDE_HOTE" if hote else ("SALON_AIDE_TACTILE" if Parametres.mobile else "SALON_AIDE"))
	rangee_invitation.visible = hote and not Reseau.code_partie.is_empty()
````

- [ ] **Step 5 : le test passe, rien d'autre ne bouge**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"; grep -c "✅" "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd > "$TMPDIR/b.log" 2>&1; echo "bataille $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/b.log"
```

Expected : rien à l'import ; smoke `0`, `== 0 échec(s) ==`, 444 ✅ (dont « la rangée d'invitation de l'hôte finit à 63 px du bas de l'écran ») ; unitaires et bataille `0`, `== 0 échec(s) ==` (la scène de jeu garde ses contrôles en disposition JEU).

- [ ] **Step 6 : Commit**

```bash
git add Scenes/ControlesTactiles.tscn Scripts/ControlesTactiles.gd Scenes/Salon.tscn Scripts/Salon.gd tests/smoke_test.gd
git commit -m "Mobiles : les contrôles tactiles au salon (la couleur et Prêt au doigt) et en manche, sur l'écran du mode ; Retour agrandi ; Plein écran sur ordinateur ; l'invitation loin du bas

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 4 : l'écran En ligne d'un mobile

**Files:**
- Modify: `Scripts/EcranEnLigne.gd` (`MARGE_CLAVIER`, `centre`, `etiquette_ou`, `_donner_focus`, `_mettre_en_page_mobile`, `_sur_edition`)
- Modify: `tests/smoke_test.gd` (`_tester_en_ligne_mobile`)

**Interfaces:**
- `EcranEnLigne` : `const MARGE_CLAVIER := 40` ; `centre: CenterContainer`, `etiquette_ou: Label` ; `func _donner_focus(candidats: Array[Control]) -> void` ; `func _sur_edition(actif: bool, champ: LineEdit) -> void` (branchée sur `editing_toggled` des deux champs).

- [ ] **Step 1 : le test qui échoue**

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	await _tester_tactile_mobile(params)
	params.mobile = false
````

par :

````gdscript
	await _tester_tactile_mobile(params)
	await _tester_en_ligne_mobile(params)
	params.mobile = false
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	params.mobile = true


## Le rectangle (px de l'écran) du texte d'une étiquette centrée sur une ligne, plus étroit qu'elle.
````

par :

````gdscript
	params.mobile = true


## Phase 6 : l'écran En ligne d'un mobile : sans Créer une partie, le focus au premier contrôle visible,
## les cibles au doigt, la rangée en édition au-dessus du clavier virtuel ; sur ordinateur, rien ne change.
func _tester_en_ligne_mobile(params: Node) -> void:
	var scores: Node = root.get_node("Scores")
	var cible: int = params.CIBLE_TACTILE
	scores.definir_preference("pseudo", "MMMMMMMMMMMM")
	var ecran: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran.codes_de_salle = true
	root.add_child(ecran)
	await process_frame
	_check(not ecran.bouton_creer.visible and not ecran.etiquette_ou.visible and ecran.bouton_rejoindre.has_focus(),
		"sur un mobile, ni Créer une partie ni « ou rejoins… » ; à l'accueil, le focus va à Rejoindre, le premier contrôle visible")
	var petits: Array[String] = []
	for controle: Control in [ecran.champ_pseudo, ecran.champ_code, ecran.bouton_rejoindre, ecran.bouton_retour]:
		if controle.size.y < cible:
			petits.append("%s %d px" % [controle.name, controle.size.y])
	var champ: LineEdit = ecran.champ_pseudo
	var largeur_m: float = champ.get_theme_font("font").get_string_size("MMMMMMMMMMMM", HORIZONTAL_ALIGNMENT_LEFT, -1, champ.get_theme_font_size("font_size")).x
	var colonne: Rect2 = ecran.get_node("Centre/Colonne").get_global_rect()
	_check(petits.is_empty() and ecran.message.get_theme_font_size("font_size") == 44 and largeur_m <= champ.size.x - 30
		and Rect2(0, 0, 2000, 1125).encloses(colonne) and ecran.bouton_rejoindre.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS,
		"les champs, Rejoindre et Retour font %d px de haut au moins (%s), le message 44 px, 12 caractères larges tiennent dans le pseudo (%d px), tout dans l'écran ; Rejoindre agit à l'appui" % [cible, petits, largeur_m])
	ecran.champ_code.text = ""
	ecran._sur_pseudo_valide(ecran.champ_pseudo.text)
	_check(ecran.champ_code.has_focus(), "Entrée dans le pseudo, sans code : le focus va au code (Créer une partie n'existe pas)")
	# Le clavier virtuel couvre le bas de l'écran : la rangée en édition remonte en haut, le message dessous.
	# Un champ entre en édition quand il prend le focus (au doigt, ou rendu par un refus : Godot 4.7) et en
	# sort quand il le perd.
	ecran.bouton_rejoindre.grab_focus()
	ecran.champ_code.text = "K7Q2X"
	ecran.rejoindre()
	await process_frame
	var rangee_code: Rect2 = ecran.champ_code.get_parent().get_global_rect()
	var message: Rect2 = ecran.message.get_global_rect()
	var pendant: float = ecran.centre.position.y
	var en_edition: bool = ecran.champ_code.is_editing()
	ecran.bouton_rejoindre.grab_focus()
	await process_frame
	var apres: float = ecran.centre.position.y
	ecran.champ_pseudo.grab_focus()
	await process_frame
	var rangee_pseudo: Rect2 = ecran.champ_pseudo.get_parent().get_global_rect()
	ecran.bouton_rejoindre.grab_focus()
	await process_frame
	_check(en_edition and pendant < 0.0 and rangee_code.position.y == ecran.MARGE_CLAVIER and message.end.y <= 1125 * 0.4 and ecran.message.text == tr("ENLIGNE_CODE_FORMAT")
		and apres == 0.0 and rangee_pseudo.position.y == ecran.MARGE_CLAVIER and ecran.centre.position.y == 0.0,
		"un refus rend le code en édition : sa rangée remonte à %d px du haut, le message dessous dans les 40 %% du haut (fin à %d px) ; le pseudo aussi ; tout redescend à la fin de l'édition"
			% [ecran.MARGE_CLAVIER, message.end.y])
	ecran.free()

	# Sur ordinateur : Créer une partie et son focus, rien ne bouge en édition
	params.mobile = false
	var bureau: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	bureau.codes_de_salle = true
	root.add_child(bureau)
	await process_frame
	bureau.champ_code.grab_focus()
	await process_frame
	_check(bureau.bouton_creer.visible and bureau.etiquette_ou.visible and bureau.centre.position.y == 0.0
		and bureau.bouton_rejoindre.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE and bureau.bouton_rejoindre.size.y < cible,
		"sur ordinateur, l'écran En ligne ne change pas : Créer une partie, rien ne remonte en édition")
	bureau.free()
	params.mobile = true
	scores.definir_preference("pseudo", "")


## Le rectangle (px de l'écran) du texte d'une étiquette centrée sur une ligne, plus étroit qu'elle.
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "SCRIPT ERROR|❌|== " "$TMPDIR/s.log"
```

Expected : `smoke 1`, `❌ sur un mobile, ni Créer une partie ni « ou rejoins… » …`, `❌ les champs, Rejoindre et Retour font 150 px de haut au moins (["Pseudo 72 px", "Code 72 px", "Rejoindre 72 px", "BoutonRetour 76 px"]) …`, `❌ Entrée dans le pseudo, sans code : le focus va au code …`, puis `SCRIPT ERROR: Invalid access to property or key 'centre' on a base object of type 'Control (EcranEnLigne.gd)'.` (`res://tests/smoke_test.gd:2341`) ; l'écran, jamais libéré par le test interrompu, fait aussi échouer « ❌ les scènes de jeu fermées et le salon ne laissent aucune connexion aux autoloads » : `== 4 échec(s) ==`.

- [ ] **Step 3 : l'écran En ligne**

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
## (`code_a_l_arrivee`).

enum Etat { ACCUEIL, CREATION, CONNEXION, SALON }
````

par :

````gdscript
## (`code_a_l_arrivee`).
##
## Mobiles (spec §6, `Parametres.mobile`) : pas de Créer une partie (un mobile ne fait que rejoindre, le
## plus souvent par le lien : coller dans un champ y est peu fiable) ; champs et boutons agrandis pour le
## doigt, textes lisibles à l'échelle d'un téléphone ; le focus va au premier contrôle visible
## (`_donner_focus`). Un champ en édition remonte à MARGE_CLAVIER px du haut de l'écran, au-dessus du
## clavier virtuel du navigateur, le message sous le code, et redescend ensuite ; Rejoindre agit à l'appui
## (au relâchement, il aurait déjà redescendu sous le doigt).

enum Etat { ACCUEIL, CREATION, CONNEXION, SALON }
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
const LONGUEUR_ADRESSE := 21

## Port de jeu de Créer une partie hors du Web (ENet ; modifiable par les tests).
````

par :

````gdscript
const LONGUEUR_ADRESSE := 21
## Sur un mobile, le haut d'une rangée en édition, en px de l'écran (le clavier virtuel couvre le bas).
const MARGE_CLAVIER := 40

## Port de jeu de Créer une partie hors du Web (ENet ; modifiable par les tests).
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
@onready var bouton_retour: Button = $BoutonRetour

## Le message affiché, gardé en clé et arguments pour être retraduit au changement de langue.
````

par :

````gdscript
@onready var bouton_retour: Button = $BoutonRetour
@onready var centre: CenterContainer = $Centre
@onready var etiquette_ou: Label = $Centre/Colonne/Ou

## Le message affiché, gardé en clé et arguments pour être retraduit au changement de langue.
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
	Parametres.langue_changee.connect(_sur_langue_changee)
	_changer_etat(Etat.ACCUEIL)
````

par :

````gdscript
	Parametres.langue_changee.connect(_sur_langue_changee)
	champ_pseudo.editing_toggled.connect(_sur_edition.bind(champ_pseudo))
	champ_code.editing_toggled.connect(_sur_edition.bind(champ_code))
	if Parametres.mobile:
		_mettre_en_page_mobile()
	_changer_etat(Etat.ACCUEIL)
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
	if champ_code.text.strip_edges().is_empty():
		bouton_creer.grab_focus()
	else:
````

par :

````gdscript
	if champ_code.text.strip_edges().is_empty():
		_donner_focus([bouton_creer, champ_code])
	else:
````

Dans `Scripts/EcranEnLigne.gd`, remplacer :

````gdscript
	if accueil:
		bouton_creer.grab_focus()
	else:
		bouton_retour.grab_focus()


func _afficher_message(cle: String, arguments: Array, erreur: bool) -> void:
````

par :

````gdscript
	if accueil:
		_donner_focus([bouton_creer, bouton_rejoindre])
	else:
		bouton_retour.grab_focus()


## Le focus au premier contrôle visible de `candidats` (sur un mobile, Créer une partie n'existe pas).
func _donner_focus(candidats: Array[Control]) -> void:
	for controle in candidats:
		if controle.is_visible_in_tree():
			controle.grab_focus()
			return


## Sur un mobile : ni Créer une partie ni « ou rejoins… » ; les champs, Rejoindre et Retour à la hauteur
## d'une cible au doigt, les textes agrandis (le champ du pseudo tient toujours 12 caractères larges).
func _mettre_en_page_mobile() -> void:
	bouton_creer.visible = false
	etiquette_ou.visible = false
	Parametres.agrandir(champ_pseudo, 56)
	Parametres.agrandir(champ_code, 56)
	Parametres.agrandir(bouton_rejoindre, 52)
	Parametres.agrandir(bouton_retour, 40)
	champ_pseudo.custom_minimum_size.x = 760
	bouton_rejoindre.custom_minimum_size.x = 340
	bouton_rejoindre.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	for etiquette: Label in [$Centre/Colonne/RangeePseudo/Etiquette, $Centre/Colonne/RangeeCode/Etiquette, message]:
		etiquette.add_theme_font_size_override("font_size", 44)


## Le champ `champ` entre en édition (`actif`) ou en sort : sur un mobile, sa rangée remonte à
## MARGE_CLAVIER px du haut de l'écran (le titre et ce qui la précède sortent par le haut), puis tout
## redescend.
func _sur_edition(actif: bool, champ: LineEdit) -> void:
	if not Parametres.mobile:
		return
	centre.position.y = 0.0
	if actif:
		centre.position.y = minf(0.0, MARGE_CLAVIER - champ.get_parent().get_global_rect().position.y)


func _afficher_message(cle: String, arguments: Array, erreur: bool) -> void:
````

- [ ] **Step 4 : le test passe**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"; grep -c "✅" "$TMPDIR/s.log"
```

Expected : rien à l'import ; smoke `0`, `== 0 échec(s) ==`, 449 ✅ (les tests de l'écran En ligne des phases 3 et 4, sur ordinateur, inchangés).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/EcranEnLigne.gd tests/smoke_test.gd
git commit -m "Mobiles : l'écran En ligne sans Créer une partie, le focus au premier contrôle visible, les cibles au doigt, la rangée en édition au-dessus du clavier virtuel

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 5 : le profil mobile du banc de la prédiction

**Files:**
- Modify: `tests/prediction_test.gd` (`WIFI`, `MOBILE` ; le parcours, l'étourdissement et le choc sous les deux profils)

**Interfaces:**
- `const WIFI`, `const MOBILE` : `{"nom", "latence", "gigue", "pertes", "erreur_etourdi", "erreur_choc"}` ; `_scenario_etourdissement(profil: Dictionary)`, `_scenario_choc(profil: Dictionary)`.

Le banc mesure le code tel qu'il est : pas de test rouge. La décision vient des mesures (écart 11).

- [ ] **Step 1 : les profils**

Dans `tests/prediction_test.gd`, remplacer :

````gdscript
## commande n'est appliquée deux fois. Chaque scénario écrit sa ligne « MESURE ».
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni `PredictionLocale`.
````

par :

````gdscript
## commande n'est appliquée deux fois. Chaque scénario écrit sa ligne « MESURE ».
## Deux profils de lien (spec §5 du jeu en ligne) : le Wi-Fi du LAN (80 ms, 40 ms, 5 %), pour tous les
## scénarios, et le mobile en 4G (150 ms, 60 ms, 8 %, phase 6), pour le parcours, l'étourdissement et le
## choc : `InterpolationLion.RETARD` et les seuils de `PredictionLocale` ne se règlent que sur ces mesures.
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni `PredictionLocale`.
````

Dans `tests/prediction_test.gd`, remplacer :

````gdscript
const A_COUP := PAS * 1.5
## Le programme du joueur du client : `[ticks, direction]`, joué au clavier ; il passe par un bord
````

par :

````gdscript
const A_COUP := PAS * 1.5
## Les profils de lien : latence (aller-retour, ms), gigue (ms), pertes (%), et ce que coûte au plus ce que
## le client ne peut pas prévoir : l'erreur de prédiction d'un étourdissement décidé par l'hôte (le lion
## court encore un aller-retour avant de l'apprendre : 30 px sous le Wi-Fi ; 60 px sous le mobile, mesuré
## 41,5 px, pour 63 px d'un aller-retour et d'une demi-gigue à pleine vitesse) et celle d'un choc contre un
## lion distant (ECART_MAX sous le Wi-Fi ; un à-coup, A_COUP, sous le mobile : mesuré 5,83 px, un pas).
const WIFI := {"nom": "80 ms, 40 ms de gigue, 5 % de pertes", "latence": 80.0, "gigue": 40.0, "pertes": 5.0,
	"erreur_etourdi": 30.0, "erreur_choc": ECART_MAX}
const MOBILE := {"nom": "mobile : 150 ms, 60 ms de gigue, 8 % de pertes", "latence": 150.0, "gigue": 60.0, "pertes": 8.0,
	"erreur_etourdi": 60.0, "erreur_choc": A_COUP}
## Le programme du joueur du client : `[ticks, direction]`, joué au clavier ; il passe par un bord
````

Dans `tests/prediction_test.gd`, remplacer :

````gdscript
	await _scenario_parcours("lien parfait", 0.0, 0.0, 0.0)
	await _scenario_parcours("80 ms, 40 ms de gigue, 5 % de pertes", 80.0, 40.0, 5.0)
	await _scenario_etourdissement()
	await _scenario_choc()
	await _scenario_choc_pendant_correction()
````

par :

````gdscript
	await _scenario_parcours("lien parfait", 0.0, 0.0, 0.0)
	await _scenario_parcours(WIFI.nom, WIFI.latence, WIFI.gigue, WIFI.pertes)
	await _scenario_parcours(MOBILE.nom, MOBILE.latence, MOBILE.gigue, MOBILE.pertes)
	await _scenario_etourdissement(WIFI)
	await _scenario_etourdissement(MOBILE)
	await _scenario_choc(WIFI)
	await _scenario_choc(MOBILE)
	await _scenario_choc_pendant_correction()
````

Dans `tests/prediction_test.gd`, remplacer :

````gdscript
## fin de l'étourdissement reçue.
func _scenario_etourdissement() -> void:
	print("-- Étourdissement décidé par l'hôte, sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(300, 150), Vector2(400, 500), 80.0, 40.0, 5.0, 1700)
	_presser(Vector2.RIGHT)
````

par :

````gdscript
## fin de l'étourdissement reçue.
func _scenario_etourdissement(profil: Dictionary) -> void:
	print("-- Étourdissement décidé par l'hôte, sous %s" % profil.nom)
	_preparer(Vector2(300, 150), Vector2(400, 500), profil.latence, profil.gigue, profil.pertes, 1700)
	_presser(Vector2.RIGHT)
````

Dans `tests/prediction_test.gd`, remplacer :

````gdscript
	var pendant: float = p.erreur_max(numero_suivi, numero_fin - 12)
	print("MESURE étourdissement : reçu au tick %d, fini au tick %d, recul de l'hôte %.0f px/s ; le lion du client recule de %.1f px pendant l'étourdissement ; erreur max %.2f px, %.2f px pendant l'étourdissement ; recalages %d ; à-coups %d"
		% [tick_etourdi, tick_fin, recul_hote, bouge_etourdi, p.erreur_max(), pendant, p.recalages, _a_coups])
	_check(tick_etourdi > 60 and tick_fin > tick_etourdi, "(pré-condition) l'étourdissement de l'hôte arrive au client, puis sa fin")
````

par :

````gdscript
	var pendant: float = p.erreur_max(numero_suivi, numero_fin - 12)
	print("MESURE étourdissement (%s) : reçu au tick %d, fini au tick %d, recul de l'hôte %.0f px/s ; le lion du client recule de %.1f px pendant l'étourdissement ; erreur max %.2f px, %.2f px pendant l'étourdissement ; recalages %d ; à-coups %d"
		% [profil.nom, tick_etourdi, tick_fin, recul_hote, bouge_etourdi, p.erreur_max(), pendant, p.recalages, _a_coups])
	_check(tick_etourdi > 60 and tick_fin > tick_etourdi, "(pré-condition) l'étourdissement de l'hôte arrive au client, puis sa fin")
````

Dans `tests/prediction_test.gd`, remplacer :

````gdscript
	# par le client, ou ses commandes suivies malgré l'étourdissement, le lion prédit partirait devant.
	_check(numero_suivi > 0 and pendant >= 0.0 and pendant < ECART_MAX and p.recalages == 0 and p.erreur_max() < 30.0,
		"étourdi, le lion du client suit l'hôte : un seul recul, ses commandes ignorées (erreur au plus %.2f px pendant l'étourdissement, %.2f px en tout), sans recalage" % [pendant, p.erreur_max()])
	_check(repart >= 0 and repart <= 2, "la fin de l'étourdissement reçue, le lion repart aussitôt à ses commandes (%d tick(s))" % repart)
	await _verifier_convergence("étourdissement", arret, 90)
	_verifier_commandes("étourdissement", h1.commandes.numero_applique / 100)
	await _liberer()
````

par :

````gdscript
	# par le client, ou ses commandes suivies malgré l'étourdissement, le lion prédit partirait devant.
	_check(numero_suivi > 0 and pendant >= 0.0 and pendant < ECART_MAX and p.recalages == 0 and p.erreur_max() < profil.erreur_etourdi,
		"(%s) étourdi, le lion du client suit l'hôte : un seul recul, ses commandes ignorées (erreur au plus %.2f px pendant l'étourdissement, %.2f px en tout, %.0f permis), sans recalage"
		% [profil.nom, pendant, p.erreur_max(), profil.erreur_etourdi])
	_check(repart >= 0 and repart <= 2, "(%s) la fin de l'étourdissement reçue, le lion repart aussitôt à ses commandes (%d tick(s))" % [profil.nom, repart])
	await _verifier_convergence("étourdissement, %s" % profil.nom, arret, 90)
	_verifier_commandes("étourdissement, %s" % profil.nom, h1.commandes.numero_applique / 100)
	await _liberer()
````

Dans `tests/prediction_test.gd`, remplacer :

````gdscript
## contre le lion affiché (interpolé), sans attendre l'hôte ; l'hôte le compte ; la prédiction converge.
func _scenario_choc() -> void:
	print("-- Choc contre un lion distant, sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(1200, 500), Vector2(700, 500), 80.0, 40.0, 5.0, 1800)
	for i in range(30):
````

par :

````gdscript
## contre le lion affiché (interpolé), sans attendre l'hôte ; l'hôte le compte ; la prédiction converge.
func _scenario_choc(profil: Dictionary) -> void:
	print("-- Choc contre un lion distant, sous %s" % profil.nom)
	_preparer(Vector2(1200, 500), Vector2(700, 500), profil.latence, profil.gigue, profil.pertes, 1800)
	for i in range(30):
````

Dans `tests/prediction_test.gd`, remplacer :

````gdscript
	var p: Node = c1.prediction
	print("MESURE choc : simulé chez le client au tick %d, chez l'hôte au tick %d ; erreur max %.2f px ; rebond de l'affichage %.2f px ; recalages %d ; à-coups %d"
		% [tick_client, tick_hote, p.erreur_max(), rebond, p.recalages, _a_coups])
	_check(tick_client > 0 and tick_hote > 0 and tick_client <= tick_hote and GS.joueurs[1].chocs >= 1,
		"le choc est simulé chez le client sans attendre l'hôte (tick %d, l'hôte au tick %d), et l'hôte le compte" % [tick_client, tick_hote])
	# Le lion repart en arrière et s'arrête, sans revenir vers le lion percuté : le choc simulé, noté,
	# est rejoué tant que l'hôte ne l'a pas (oublié, le lion reviendrait avant de repartir).
	_check(p.recalages == 0 and rebond < ECART_MAX and p.erreur_max() < ECART_MAX,
		"le choc ne fait ni recalage ni aller-retour visible (rebond de %.2f px ; erreur au plus %.2f px)" % [rebond, p.erreur_max()])
	await _verifier_convergence("choc", arret, 90)
	await _liberer()
````

par :

````gdscript
	var p: Node = c1.prediction
	print("MESURE choc (%s) : simulé chez le client au tick %d, chez l'hôte au tick %d ; erreur max %.2f px ; rebond de l'affichage %.2f px ; recalages %d ; à-coups %d"
		% [profil.nom, tick_client, tick_hote, p.erreur_max(), rebond, p.recalages, _a_coups])
	_check(tick_client > 0 and tick_hote > 0 and tick_client <= tick_hote and GS.joueurs[1].chocs >= 1,
		"(%s) le choc est simulé chez le client sans attendre l'hôte (tick %d, l'hôte au tick %d), et l'hôte le compte" % [profil.nom, tick_client, tick_hote])
	# Le lion repart en arrière et s'arrête, sans revenir vers le lion percuté : le choc simulé, noté,
	# est rejoué tant que l'hôte ne l'a pas (oublié, le lion reviendrait avant de repartir).
	_check(p.recalages == 0 and rebond < ECART_MAX and p.erreur_max() < profil.erreur_choc,
		"(%s) le choc ne fait ni recalage ni aller-retour visible (rebond de %.2f px ; erreur au plus %.2f px, %.2f permis)" % [profil.nom, rebond, p.erreur_max(), profil.erreur_choc])
	await _verifier_convergence("choc, %s" % profil.nom, arret, 90)
	await _liberer()
````

- [ ] **Step 2 : les mesures**

```bash
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "banc $?"; grep -E "MESURE|❌|SCRIPT ERROR|== " "$TMPDIR/p.log"; grep -c "✅" "$TMPDIR/p.log"
```

Expected (mesuré, reproductible : les lignes à retard sont semées) : `banc 0`, `== 0 échec(s) ==`, 78 ✅, et :
- `MESURE parcours (mobile : 150 ms, 60 ms de gigue, 8 % de pertes) : erreur max 5.83 px, 93 états sur 289 au-delà de 4 px, 0 au-delà de 16 px ; recalages 0 ; à-coups 0 ; rejeu le plus long 14 pas ; lion distant : 4.83 à 6.44 px par tick (5.83) ; commandes sautées 10, file au plus 5`
- `MESURE étourdissement (mobile : …) : reçu au tick 64, fini au tick 216, … erreur max 41.50 px, 0.00 px pendant l'étourdissement ; recalages 0 ; à-coups 5`
- `MESURE choc (mobile : …) : simulé chez le client au tick 105, chez l'hôte au tick 112 ; erreur max 5.83 px ; rebond de l'affichage 0.00 px ; recalages 0 ; à-coups 0`
- les lignes du Wi-Fi inchangées (parcours : erreur max 5.83 px ; étourdissement : 14.17 px ; choc : 0.64 px).

- [ ] **Step 3 : la décision (aucune constante ne change)**

Le parcours mobile tient tous les seuils du Wi-Fi ; l'étourdissement (41,50 px) et le choc (5,83 px) dépasseraient les seuils du Wi-Fi (30 px, `ECART_MAX` 4 px), d'un aller-retour de course que le client ne peut pas prévoir, sans recalage ni rebond : `InterpolationLion.RETARD`, `PredictionLocale.SEUIL_RECALAGE` et `DUREE_CORRECTION` restent tels quels, et ces mesures vont dans la PR (Task 10). Un écart à ces valeurs, ou un ❌ : ne rien régler à l'aveugle, s'arrêter et le signaler.

- [ ] **Step 4 : Commit**

```bash
git add tests/prediction_test.gd
git commit -m "Banc de la prédiction : le profil mobile (150 ms, 60 ms de gigue, 8 % de pertes) pour le parcours, l'étourdissement et le choc ; RETARD et les seuils de PredictionLocale inchangés (mesures)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 6 : la file de la signalisation sur un appareil lent

**Files:**
- Modify: `Scripts/TransportWebRTC.gd` (`_image_precedente`, `_vider_file` en créneaux)
- Modify: `tests/unitaires.gd` (la file lente et le seau de la salle, dans `_tester_transport_webrtc`)

**Interfaces:**
- `TransportWebRTC` : `var _image_precedente := -1` ; `_derniers_envois` tient désormais des créneaux (ms).

- [ ] **Step 1 : le test qui échoue**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
		"deux envois sont espacés de 50 ms au moins, en plus du plafond par seconde (une rafale retardée par TCP arriverait d'un coup à la salle) (%s)" % [instants])


## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
````

par :

````gdscript
		"deux envois sont espacés de 50 ms au moins, en plus du plafond par seconde (une rafale retardée par TCP arriverait d'un coup à la salle) (%s)" % [instants])
	# Phase 6 (note de la revue de la phase 4) : sur un appareil lent, une image dure plus de 50 ms ; la file
	# rattrape les créneaux passés depuis l'image précédente, pas plus (une réponse et ses 8 candidats, à 2
	# images par seconde : en 2 images, au lieu de 9), et la salle, un seau de 20 jetons rempli de 20 par
	# seconde, n'est jamais à sec, quelle que soit la cadence des images.
	var lente := TransportWebRTCSimule.new()
	lente.rejoindre("K7Q2XM")
	for i in range(9):
		lente._envoyer({"t": "candidat", "vers": 1, "media": "0", "index": i, "nom": "c"})
	var par_image: Array[int] = []
	for t in range(300000, 302500, 500):  # 2 images par seconde
		var avant := lente.ecrits.size()
		lente._vider_file(t)
		par_image.append(lente.ecrits.size() - avant)
	_check(par_image == [1, 8, 0, 0, 0] and lente.ecrits.size() == 9,
		"à 2 images par seconde, la file rattrape les créneaux de 50 ms de l'image écoulée : 9 messages en 2 images, pas en 9 (%s)" % [par_image])
	var seaux := {}
	for duree: int in [16, 200, 500, 1000]:
		var cadencee := TransportWebRTCSimule.new()
		cadencee.rejoindre("K7Q2XM")
		for i in range(80):
			cadencee._envoyer({"t": "candidat", "vers": 1, "media": "0", "index": i, "nom": "c"})
		var seau := 20.0
		var plus_bas := seau
		var precedent := 400000
		for t in range(400000, 412000, duree):
			seau = minf(20.0, seau + (t - precedent) * 20.0 / 1000.0)
			precedent = t
			var avant := cadencee.ecrits.size()
			cadencee._vider_file(t)
			seau -= cadencee.ecrits.size() - avant
			plus_bas = minf(plus_bas, seau)
		seaux[duree] = [snappedf(plus_bas, 0.1), cadencee.ecrits.size()]
	_check(seaux.values().all(func(v: Array) -> bool: return v[0] >= 0.0 and v[1] == 80),
		"une image de 16, 200, 500 ou 1000 ms : les 80 messages partent, et le seau de la salle (20 jetons, 20 par seconde) n'est jamais à sec ({durée: [jetons au plus bas, envoyés]} %s)" % [seaux])


## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "SCRIPT ERROR|❌|== " "$TMPDIR/u.log"
```

Expected : `unitaires 1`, `❌ à 2 images par seconde, la file rattrape les créneaux de 50 ms de l'image écoulée : 9 messages en 2 images, pas en 9 ([1, 1, 1, 1, 1])`, `❌ une image de 16, 200, 500 ou 1000 ms : les 80 messages partent … ({durée: [jetons au plus bas, envoyés]} { 16: [19.0, 80], 200: [19.0, 60], 500: [19.0, 24], 1000: [19.0, 12] })`, `== 2 échec(s) ==`.

- [ ] **Step 3 : la file en créneaux**

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
## Envois : en texte seulement (`send_text` : la salle ignore une trame binaire, et ne répond pas à un
## `ping` binaire), par une file cadencée à ENVOIS_PAR_SECONDE, espacés d'ECART_ENVOIS au moins (la
## salle chasse au-delà de 20 par seconde ; six arrivées font environ 70 messages), dans l'ordre (une offre
## avant ses candidats), et seulement tant que la salle peut les relayer (`_signaler_vers`).
## Réception : tous les messages en attente sont lus, même la socket fermée, jusqu'à la fin de la
````

par :

````gdscript
## Envois : en texte seulement (`send_text` : la salle ignore une trame binaire, et ne répond pas à un
## `ping` binaire), par une file cadencée à ENVOIS_PAR_SECONDE, sur des créneaux espacés d'ECART_ENVOIS (la
## salle chasse au-delà de 20 par seconde ; six arrivées font environ 70 messages), dans l'ordre (une offre
## avant ses candidats), et seulement tant que la salle peut les relayer (`_signaler_vers`). Une image plus
## longue qu'ECART_ENVOIS (un appareil lent, phase 6) rattrape les créneaux passés depuis l'image
## précédente, pas davantage.
## Réception : tous les messages en attente sont lus, même la socket fermée, jusqu'à la fin de la
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
var _arrivees: Dictionary[int, int] = {}
## Les messages en attente d'envoi, dans l'ordre, et les instants (ms) des ENVOIS_PAR_SECONDE derniers
## envois, du plus ancien au plus récent (la fenêtre glissante d'une seconde).
````

par :

````gdscript
var _arrivees: Dictionary[int, int] = {}
## Les messages en attente d'envoi, dans l'ordre, et les créneaux (ms) des ENVOIS_PAR_SECONDE derniers
## envois, du plus ancien au plus récent (la fenêtre glissante d'une seconde).
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
var _derniers_envois: Array[int] = []
## Chez l'hôte : l'instant (ms) du prochain `ping` (-1 sans salle).
````

par :

````gdscript
var _derniers_envois: Array[int] = []
## L'instant (ms) du passage précédent de `_vider_file` (-1 avant le premier) : le plus ancien créneau
## qu'une image longue peut rattraper.
var _image_precedente := -1
## Chez l'hôte : l'instant (ms) du prochain `ping` (-1 sans salle).
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
## Envoie les messages de la file à `maintenant` (ms), dans l'ordre, tant qu'il le peut : la socket
## ouverte, ECART_ENVOIS ms au moins après l'envoi précédent, et pas plus de ENVOIS_PAR_SECONDE dans la
## seconde qui précède.
func _vider_file(maintenant: int) -> void:
	if not _socket_prete():
````

par :

````gdscript
## Envoie les messages de la file à `maintenant` (ms), dans l'ordre, tant qu'il le peut : la socket
## ouverte, un créneau par envoi, ECART_ENVOIS ms après celui de l'envoi précédent, jamais avant l'image
## précédente (une longue attente ne s'accumule pas) ni après `maintenant`, et pas plus de
## ENVOIS_PAR_SECONDE créneaux dans une seconde. À 60 images par seconde, un envoi toutes les 50 ms ; à 2
## images par seconde (un appareil lent), une dizaine par image au lieu d'un seul, la salle (un seau de
## 20 jetons, rempli de 20 par seconde) jamais à sec.
func _vider_file(maintenant: int) -> void:
	var depuis := maintenant if _image_precedente < 0 else _image_precedente
	_image_precedente = maintenant
	if not _socket_prete():
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
	while not _file.is_empty():
		if not _derniers_envois.is_empty() and maintenant - _derniers_envois[-1] < ECART_ENVOIS:
			return
		if _derniers_envois.size() == ENVOIS_PAR_SECONDE and maintenant - _derniers_envois[0] < 1000:
			return
````

par :

````gdscript
	while not _file.is_empty():
		var creneau := depuis if _derniers_envois.is_empty() else maxi(_derniers_envois[-1] + ECART_ENVOIS, depuis)
		if creneau > maintenant:
			return
		if _derniers_envois.size() == ENVOIS_PAR_SECONDE and creneau - _derniers_envois[0] < 1000:
			return
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
		_file.remove_at(0)
		_derniers_envois.append(maintenant)
		if _derniers_envois.size() > ENVOIS_PAR_SECONDE:
````

par :

````gdscript
		_file.remove_at(0)
		_derniers_envois.append(creneau)
		if _derniers_envois.size() > ENVOIS_PAR_SECONDE:
````

- [ ] **Step 4 : le test passe**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== |images par seconde|seau de la salle|15 messages au plus|espacés de 50" "$TMPDIR/u.log"; grep -c "✅" "$TMPDIR/u.log"
```

Expected : rien à l'import ; unitaires `0`, `PROTOCOLE 0.20 2553814265 (67 lignes)`, `== 0 échec(s) ==`, 530 ✅ ; « la file attend la socket ouverte, puis envoie 15 messages au plus par seconde, tous, dans l'ordre (0, 15, 20) » et « deux envois sont espacés de 50 ms au moins … ([200000, 200050, 200100, 200150, 200200]) » inchangés ; « … ([1, 8, 0, 0, 0]) » ; « … { 16: [18.7, 80], 200: [15.0, 80], 500: [9.0, 80], 1000: [5.0, 80] } ».

- [ ] **Step 5 : Commit**

```bash
git add Scripts/TransportWebRTC.gd tests/unitaires.gd
git commit -m "Signalisation : sur un appareil lent, la file rattrape les créneaux de 50 ms de l'image écoulée (une dizaine d'envois par image à 2 images par seconde au lieu d'un), la salle jamais à sec

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 7 : le client mobile du bout en bout

**Files:**
- Modify: `tests/web/bout_en_bout.spec.js` (`MOBILE`, le test `@mobile`)
- Modify: `tests/web/playwright.config.js` (le projet `mobile`)
- Modify: `Scripts/PiloteWeb.gd` (l'état : `mobile`, `voile`, `images`, Rejoindre, les boutons tactiles, le stick, la hauteur de peinture ; `_css`, `_css_bouton`, `_hauteur_peinture`)
- Modify: `.github/workflows/ci.yml` (le nom de l'étape du bout en bout)

**Interfaces:**
- `PiloteWeb.etat()` gagne `mobile`, `voile`, `images` (`Engine.get_process_frames()`) ; `ecran.creer`, `ecran.rejoindre` (`[x0, y0, x1, y1]` en px CSS) ; `salon.table[].couleur` (`to_html(false)`), `salon.tactile` (`visible`, `gauche`, `droite`, `pret` : `[x, y, côté]` en px CSS) ; `manche.temps`, `manche.lion` (`[x, y]`, px du jeu), `manche.cible`, `manche.tactile` (`visible`, `vomir`, `stick` : `[x, y]`, `rayon` en px CSS).
- `npx playwright test --project=mobile` : un hôte Chromium de bureau, un mobile Chromium (`devices["Pixel 7 landscape"]`, `deviceScaleFactor: 1`).

- [ ] **Step 1 : le test qui échoue**

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
// (Scripts/PiloteWeb.gd) : des commandes poussées dans window.lelionPilote.commandes, son état relu
// dans window.lelionPilote.etat, par les vrais écrans du jeu (titre, En ligne, salon, manche).
import { expect, test } from "@playwright/test";

const ALPHABET = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;
````

par :

````js
// (Scripts/PiloteWeb.gd) : des commandes poussées dans window.lelionPilote.commandes, son état relu
// dans window.lelionPilote.etat, par les vrais écrans du jeu (titre, En ligne, salon, manche). Le mobile,
// lui, joue au doigt : de vrais touchers de la page, aux places que l'état du pilote donne.
import { devices, expect, test } from "@playwright/test";

const ALPHABET = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
const etat = (page) => page.evaluate(() => JSON.parse(window.lelionPilote.etat));
const commander = (page, ...commande) => page.evaluate((c) => window.lelionPilote.commandes.push(c), commande);
````

par :

````js
const etat = (page) => page.evaluate(() => JSON.parse(window.lelionPilote.etat));

/**
 * Le mobile du test : un Android en paysage (Pixel 7, 863×360 px CSS : son agent utilisateur donne
 * `web_android` au jeu, l'écran est tactile), sans écran haute densité : le jeu se met à l'échelle de la
 * page, pas de ses pixels, et un rendu logiciel 2,6 fois plus fin ralentirait le conteneur.
 */
const MOBILE = { ...devices["Pixel 7 landscape"], deviceScaleFactor: 1 };
const commander = (page, ...commande) => page.evaluate((c) => window.lelionPilote.commandes.push(c), commande);
````

À la fin de `tests/web/bout_en_bout.spec.js`, ajouter (après une ligne vide) :

````js
test("un mobile rejoint par le lien et joue au doigt ; en portrait, le voile, et le jeu continue @mobile", async ({ browser }) => {
	const consoles = [];
	const hote = await ouvrir(browser, "/", consoles);
	await commander(hote, "duree", 12);
	await commander(hote, "creer", "Hote");
	const salle = await attendre(hote, (e) => e.scene === "Salon" && ALPHABET.test(e.code), "l'hôte a sa salle");
	expect(salle.mobile).toBe(false);

	const contexte = await browser.newContext(MOBILE);
	const mobile = await contexte.newPage();
	const lignes = [];
	consoles.push(lignes);
	mobile.on("console", (message) => lignes.push(message.text()));
	await mobile.goto(`/?salle=${salle.code}`);
	await mobile.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
	// Un mobile : pas de Créer une partie, Rejoindre à la taille d'un doigt (44 px CSS au moins)
	const accueil = await attendre(mobile, (e) => e.scene === "EcranEnLigne", "le lien ouvre l'écran En ligne du mobile");
	expect(accueil.mobile).toBe(true);
	expect(accueil.ecran.creer).toBe(false);
	const [x0, y0, x1, y1] = accueil.ecran.rejoindre;
	expect(y1 - y0, `Rejoindre fait ${y1 - y0} px CSS de haut`).toBeGreaterThanOrEqual(44);
	await commander(mobile, "duree", 12);
	// Rejoindre au doigt, sans pseudo (l'hôte le nomme « Joueur 2 ») : ce premier toucher demande aussi le plein écran
	await mobile.touchscreen.tap((x0 + x1) / 2, (y0 + y1) / 2);
	await attendre(mobile, (e) => e.scene === "Salon", "le mobile arrive au salon (Rejoindre touché)");
	for (const page of [hote, mobile]) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Joueur 2", "la même table du salon partout");
	}
	// Le plein écran, demandé par ce premier toucher (Chromium l'accorde : le toucher est le geste qu'il exige)
	await expect.poll(() => mobile.evaluate(() => document.fullscreenElement !== null), { message: "le premier toucher met le mobile en plein écran" }).toBe(true);

	// Au salon, au doigt : la flèche droite change la couleur, PRÊT rend prêt (vu chez l'hôte)
	const salon = (await etat(mobile)).salon;
	expect(salon.tactile.visible).toBe(true);
	const [dx, dy, cote] = salon.tactile.droite;
	expect(cote, `les boutons tactiles font ${cote} px CSS`).toBeGreaterThanOrEqual(44);
	const couleur = salon.table[1].couleur;
	await mobile.touchscreen.tap(dx, dy);
	await attendre(hote, (e) => e.salon?.table[1].couleur !== couleur, "la flèche touchée change la couleur du mobile, chez l'hôte");
	await mobile.touchscreen.tap(salon.tactile.pret[0], salon.tactile.pret[1]);
	await attendre(hote, (e) => e.salon?.table[1].pret === true, "PRÊT touché : le mobile est prêt, chez l'hôte");

	// En portrait : le voile « Tourne ton téléphone », et le jeu qui continue derrière ; en paysage, plus rien.
	// Playwright ne tourne qu'une page hors du plein écran : le joueur en sort d'abord (le jeu le laisse en sortir).
	await mobile.evaluate(() => document.exitFullscreen());
	await expect.poll(() => mobile.evaluate(() => document.fullscreenElement === null)).toBe(true);
	const paysage = mobile.viewportSize();
	await mobile.setViewportSize({ width: paysage.height, height: paysage.width });
	const voile = await attendre(mobile, (e) => e.voile === true, "en portrait, le voile");
	await attendre(mobile, (e) => e.images > voile.images + 30, "le jeu continue derrière le voile");
	await mobile.setViewportSize(paysage);
	await attendre(mobile, (e) => e.voile === false, "en paysage, plus de voile");

	await commander(hote, "pret");
	await commander(hote, "demarrer");
	await attendre(mobile, (e) => e.manche?.en_cours === true, "la manche commence chez le mobile", 60_000);
	const jeu = (await etat(mobile)).manche;
	expect(jeu.tactile.visible).toBe(true);
	// Les doigts : des touchers Chromium (CDP), chacun tenu, comme deux pouces
	const cdp = await contexte.newCDPSession(mobile);
	const doigts = (type, points) => cdp.send("Input.dispatchTouchEvent", { type, touchPoints: points.map(([x, y], id) => ({ x, y, id })) });
	const [sx, sy] = jeu.tactile.stick;
	const pousse = jeu.tactile.rayon * 1.2;
	// Le pouce gauche pose le stick et le pousse vers le bas aux quatre cinquièmes (le lion descend à 60 % de sa
	// vitesse : la zone morte des actions est de 0,5) : le lion descend vers la ville, un peu sous la hauteur de
	// peinture (l'hôte, qui fait foi, le voit un peu plus haut que sa prédiction), jamais jusqu'aux toits, 233 px
	// plus bas, même relu 300 ms trop tard
	await doigts("touchStart", [[sx, sy]]);
	await doigts("touchMove", [[sx, sy + jeu.tactile.rayon * 0.8]]);
	await attendre(mobile, (e) => e.manche?.lion.length === 2 && e.manche.lion[1] >= e.manche.cible + 20, "le stick fait descendre le lion du mobile", 60_000);
	// Puis vers la gauche (son lion part à droite de l'écran), VOMIR tenu du pouce droit : il peint 2,5 s de jeu
	const [vx, vy] = jeu.tactile.vomir;
	await doigts("touchMove", [[sx - pousse, sy]]);
	await doigts("touchStart", [[sx - pousse, sy], [vx, vy]]);
	const debut = (await etat(mobile)).manche.temps;
	await attendre(mobile, (e) => e.manche?.finie || e.manche?.temps >= debut + 2.5, "le mobile peint 2,5 s de jeu", 60_000);
	await doigts("touchEnd", []);

	const fins = [];
	for (const page of [hote, mobile]) fins.push(await attendre(page, (e) => e.empreinte !== "", "la manche finit partout", 60_000));
	const empreintes = consoles.map((l) => l.find((ligne) => ligne.startsWith("EMPREINTE ")));
	expect(empreintes[0]).toBeTruthy();
	expect(empreintes[1]).toBe(empreintes[0]);
	console.log(`Fin de manche : scores ${fins[0].scores} ; hôte ${fins[0].fps} i/s, mobile ${fins[1].fps} i/s`);
	// Les scores du territoire : à l'index 0 les cellules de personne, puis l'hôte, puis le mobile
	expect(fins[1].scores[2], `le mobile a peint au doigt : ${fins[1].scores}`).toBeGreaterThan(0);
	expect(erreurs(consoles), "aucune erreur dans les consoles des deux pages").toEqual([[], []]);
});
````

Dans `tests/web/playwright.config.js`, remplacer :

````js
// la signalisation en local (`wrangler dev` sur ws://localhost:8787, l'adresse par défaut du réglage
// lelion/signalisation/url), puis Chromium et Firefox (la manche à trois pages) et WebKit (Copier le lien).
// L'export se fait avant : godot --headless --export-release "Web pilote" export/web-pilote/index.html.
````

par :

````js
// la signalisation en local (`wrangler dev` sur ws://localhost:8787, l'adresse par défaut du réglage
// lelion/signalisation/url), puis Chromium et Firefox (la manche à trois pages), WebKit (Copier le lien) et un
// mobile émulé par Chromium (un Android en paysage, au doigt, face à un hôte de bureau).
// L'export se fait avant : godot --headless --export-release "Web pilote" export/web-pilote/index.html.
````

Dans `tests/web/playwright.config.js`, remplacer :

````js
		{ name: "webkit", grep: /@lien/, use: { browserName: "webkit" } },
	],
````

par :

````js
		{ name: "webkit", grep: /@lien/, use: { browserName: "webkit" } },
		// Le mobile a son propre contexte (Pixel 7 en paysage) : le projet ne fixe que le navigateur.
		{ name: "mobile", grep: /@mobile/, use: { browserName: "chromium" } },
	],
````

- [ ] **Step 2 : il échoue**

```bash
mkdir -p export/web-pilote
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion-modules-signalisation:/depot/signalisation/node_modules -v lelion-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test --project=mobile' > "$TMPDIR/e2e.log" 2>&1; echo "bout en bout $?"; grep -E "✘|✓|Expected|Received|failed|passed" "$TMPDIR/e2e.log"
```

Expected : `export pilote 0` ; `bout en bout 1`, `✘ … [mobile] … @mobile`, `Expected: false`, `Received: undefined` (l'état du pilote n'a pas encore `mobile`), `1 failed`.

- [ ] **Step 3 : le pilote**

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
## État : `window.lelionPilote.etat`, un texte JSON réécrit à chaque image (`etat()`), que la page relit.
##
````

par :

````gdscript
## État : `window.lelionPilote.etat`, un texte JSON réécrit à chaque image (`etat()`), que la page relit.
## Pour un client mobile (phase 6), qui joue au doigt (de vrais touchers de la page, jamais des commandes),
## l'état donne aussi, en px CSS de la page, ce qu'un toucher vise : Rejoindre, les boutons tactiles du
## salon et de la manche, le stick ; et la hauteur où peindre.
##
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
		"code": Reseau.code_partie, "pertes": _pertes, "echecs": _echecs, "empreinte": _empreinte, "scores": _scores,
		"fps": Engine.get_frames_per_second(), "passe": _passe}
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
````

par :

````gdscript
		"code": Reseau.code_partie, "pertes": _pertes, "echecs": _echecs, "empreinte": _empreinte, "scores": _scores,
		"fps": Engine.get_frames_per_second(), "passe": _passe, "mobile": Parametres.mobile, "voile": Parametres.voile.visible,
		"images": Engine.get_process_frames()}
	if nom == "EcranEnLigne":
		var rejoindre: Rect2 = scene.bouton_rejoindre.get_global_rect()
		e["ecran"] = {"etat": scene.etat, "code": scene.champ_code.text, "message": scene.message.text,
			"creer": scene.bouton_creer.visible, "rejoindre": _css(rejoindre.position) + _css(rejoindre.end)}
	elif nom == "Salon":
		var table: Array = Reseau.table_salon.map(func(f: Dictionary) -> Dictionary:
			return {"pseudo": f.pseudo, "pret": f.pret, "couleur": f.couleur.to_html(false)})
		var bouton: Button = scene.bouton_copier
		var tactile: CanvasLayer = scene.controles_tactiles
		e["salon"] = {"table": table, "attente": Reseau.raison_attente(Reseau.fiches_attente()),
			"invitation": scene.etiquette_code.text, "copier": bouton.text,
			"bouton_copier": _css(bouton.get_global_rect().get_center()) if bouton.is_visible_in_tree() else [],
			"tactile": {"visible": tactile.visible, "gauche": _css_bouton(tactile.bouton_gauche), "droite": _css_bouton(tactile.bouton_droite),
				"pret": _css_bouton(tactile.bouton_vomir)}}
	elif nom == "Main":
		var manche: Node = scene.get_node("Manche")
		var tactile: CanvasLayer = scene.get_node("ControlesTactiles")
		var stick: Control = tactile.joystick
		e["manche"] = {"barriere": manche.barriere, "en_cours": GameState.pret and GameState.partie_en_cours, "finie": manche.finie,
			"temps": GameState.temps_ecoule, "lion": [] if scene.lion == null else [scene.lion.position.x, scene.lion.position.y],
			"cible": _hauteur_peinture(scene),
			"tactile": {"visible": tactile.visible, "vomir": _css_bouton(tactile.bouton_vomir),
				"stick": _css(Vector2(stick.rayon * 3.0, stick.get_viewport_rect().size.y - stick.rayon * 3.0)),
				"rayon": _css(Vector2(stick.rayon, 0))[0] - _css(Vector2.ZERO)[0]}}
	return e


## Le point `point` de l'écran du jeu, en px CSS de la page (ce que vise un clic ou un toucher de la page).
func _css(point: Vector2) -> Array:
	var ecran := get_viewport().get_screen_transform() * point
	var echelle := float(JavaScriptBridge.eval("window.devicePixelRatio", true))
	return [ecran.x / echelle, ecran.y / echelle]


## Le centre d'un bouton tactile en px CSS de la page, et son côté : `[x, y, côté]`.
func _css_bouton(bouton: TouchScreenButton) -> Array:
	var cote := bouton.texture_normal.get_size() * bouton.scale
	var coin := _css(bouton.position)
	return _css(bouton.position + cote / 2.0) + [_css(bouton.position + cote)[0] - coin[0]]


## L'ordonnée où peindre dans la scène de jeu `main` : HAUTEUR_PEINTURE au-dessus des toits.
static func _hauteur_peinture(main: Node) -> float:
	var ville: Node2D = main.get_node("Ville")
	return ville.position.y - ville.tex_size.y / 2.0 - HAUTEUR_PEINTURE


## L'empreinte de la manche finie de la scène de jeu `main` (la même sur chaque poste qui a tout reçu) :
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
func _peindre(main: Node, sens: int) -> void:
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - HAUTEUR_PEINTURE
	_passe = {"descente": 0}
````

par :

````gdscript
func _peindre(main: Node, sens: int) -> void:
	var cible := _hauteur_peinture(main)
	_passe = {"descente": 0}
````

- [ ] **Step 4 : la CI**

Dans `.github/workflows/ci.yml`, remplacer :

````yaml
          (cd tests/web && npm ci && npx playwright install --with-deps chromium firefox webkit)

      - name: Test de bout en bout (Chromium et Firefox, une manche à trois pages ; WebKit, Copier le lien)
        working-directory: tests/web
````

par :

````yaml
          (cd tests/web && npm ci && npx playwright install --with-deps chromium firefox webkit)

      - name: Test de bout en bout (Chromium et Firefox, une manche à trois pages ; WebKit, Copier le lien ; un mobile émulé, au doigt)
        working-directory: tests/web
````

Le job `bout-en-bout` lance déjà tous les projets (`xvfb-run -a npx playwright test`) et installe Chromium : rien d'autre ne change.

- [ ] **Step 5 : le test passe, et les autres aussi**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|== |pilote du test" "$TMPDIR/u.log"
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
SECONDS=0; timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion-modules-signalisation:/depot/signalisation/node_modules -v lelion-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test' > "$TMPDIR/e2e.log" 2>&1; echo "bout en bout $? en ${SECONDS} s"; grep -E "✓|✘|passed|failed|Fin de manche|Départ" "$TMPDIR/e2e.log"
```

Expected : rien à l'import ; unitaires `0`, « le pilote du test de bout en bout est inerte hors de l'export Web pilote » ; `export pilote 0` ; `bout en bout 0` en 90 à 100 s (mesuré 96 s), `4 passed` : `[chromium]` et `[firefox]` `@manche`, `[webkit]` `@lien`, `[mobile]` `@mobile` (mesuré 27 s ; « Fin de manche : scores 4167,0,566,… ; hôte 26 i/s, mobile 24 i/s » : le troisième score, celui du mobile, au-dessus de 0). Un échec du mobile : lire son « dernier état » dans le message (la position du lion, `cible`) avant toute retouche.

- [ ] **Step 6 : Commit**

```bash
git add tests/web/bout_en_bout.spec.js tests/web/playwright.config.js Scripts/PiloteWeb.gd .github/workflows/ci.yml
git commit -m "Bout en bout : un mobile émulé (Pixel 7 en paysage) rejoint par le lien et joue au doigt (Rejoindre, la couleur, PRÊT, le stick et VOMIR), voit le voile en portrait ; le pilote donne ce que visent ses touchers

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 8 : les captures d'un téléphone

**Files:**
- Modify: `tests/screenshots.gd` (la partie `mobile`, `PAYSAGE`, `PORTRAIT`, `_shot_telephone`, `_tenir`)
- Modify: `.github/workflows/ci.yml` (45 captures)

**Interfaces:**
- `--parties=mobile` : `mobile_00_en_ligne`, `mobile_01_en_ligne_clavier`, `mobile_02_salon`, `mobile_03_bataille`, `mobile_05_resultats` (844×390), `mobile_04_portrait_bataille`, `mobile_06_portrait_resultats` (360×640) ; `func _shot_telephone(nom: String, ecran: Vector2i) -> void` (l'écran du jeu à l'échelle du téléphone, centré, les bandes noires autour).

- [ ] **Step 1 : les captures**

Dans `tests/screenshots.gd`, remplacer :

````gdscript
## Captures pilotées, avec le vrai rendu (pas headless en local ; la CI les déroule sans rendu (pas « Captures »)) :
##   godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=<dossier> [--parties=solo,reseau,salon,bataille,resultats]
## Écrit ses PNG dans <dossier> (défaut : user://), par partie (toutes par défaut) :
````

par :

````gdscript
## Captures pilotées, avec le vrai rendu (pas headless en local ; la CI les déroule sans rendu (pas « Captures »)) :
##   godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=<dossier> [--parties=solo,reseau,salon,bataille,resultats,mobile]
## Écrit ses PNG dans <dossier> (défaut : user://), par partie (toutes par défaut) :
````

Dans `tests/screenshots.gd`, remplacer :

````gdscript
##   resultats  l'écran Résultats d'une bataille à 6 (animation, hôte local, client, hôte en réseau,
##              hôte resté seul), une égalité à 2 en anglais (phase 18).
## La partie à deux vraies fenêtres (un hôte et un client) est dans `tests/deux_fenetres.gd`, une vraie
````

par :

````gdscript
##   resultats  l'écran Résultats d'une bataille à 6 (animation, hôte local, client, hôte en réseau,
##              hôte resté seul), une égalité à 2 en anglais (phase 18) ;
##   mobile     ce que montre un téléphone (phase 6 du jeu en ligne, `Parametres.mobile`), le jeu à l'échelle
##              de l'écran du téléphone, bandes comprises : en paysage (844×390) l'écran En ligne (le lien,
##              puis un code refusé, sa rangée remontée au-dessus du clavier), le salon d'un client (les
##              flèches et PRÊT), la bataille (HUD, stick, VOMIR, pause), l'écran Résultats d'un client ; en
##              portrait (360×640) la bataille et l'écran Résultats sous le voile « Tourne ton téléphone ».
## La partie à deux vraies fenêtres (un hôte et un client) est dans `tests/deux_fenetres.gd`, une vraie
````

Dans `tests/screenshots.gd`, remplacer :

````gdscript
## par `root.get_node`, charge les scènes à l'exécution.

const PARTIES := ["solo", "reseau", "salon", "bataille", "resultats"]
const PORT_JEU := 17890
````

par :

````gdscript
## par `root.get_node`, charge les scènes à l'exécution.

const PARTIES := ["solo", "reseau", "salon", "bataille", "resultats", "mobile"]
## Les écrans de téléphone des captures `mobile` (px CSS) : en paysage, en portrait.
const PAYSAGE := Vector2i(844, 390)
const PORTRAIT := Vector2i(360, 640)
const PORT_JEU := 17890
````

Dans `tests/screenshots.gd`, remplacer :

````gdscript
	print("📸 %s (%dx%d)" % [chemin, image.get_width(), image.get_height()])


func _run() -> void:
````

par :

````gdscript
	print("📸 %s (%dx%d)" % [chemin, image.get_width(), image.get_height()])


## Une capture de ce que montre un téléphone dont l'écran fait `ecran` : l'écran du jeu mis à son échelle,
## centré, les bandes noires autour (comme l'export Web, `canvas_resize_policy` adaptatif, l'aspect gardé).
func _shot_telephone(nom: String, ecran: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		print("📸 %s (headless : rien d'écrit)" % nom)
		return
	await RenderingServer.frame_post_draw
	var jeu := root.get_texture().get_image()
	var echelle := minf(float(ecran.x) / jeu.get_width(), float(ecran.y) / jeu.get_height())
	var taille := Vector2i(roundi(jeu.get_width() * echelle), roundi(jeu.get_height() * echelle))
	jeu.resize(taille.x, taille.y, Image.INTERPOLATE_LANCZOS)
	var image := Image.create(ecran.x, ecran.y, false, jeu.get_format())
	image.fill(Color.BLACK)
	image.blit_rect(jeu, Rect2i(Vector2i.ZERO, taille), (ecran - taille) / 2)
	var chemin := dossier.path_join(nom + ".png")
	image.save_png(chemin)
	print("📸 %s (%dx%d, le jeu à l'échelle %.3f)" % [chemin, image.get_width(), image.get_height(), echelle])


func _run() -> void:
````

Dans `tests/screenshots.gd`, remplacer :

````gdscript
		await _resultats()
	root.get_node("Parametres").definir_langue("fr")
````

par :

````gdscript
		await _resultats()
	if parties.has("mobile"):
		await _mobile()
	root.get_node("Parametres").definir_langue("fr")
````

À la fin de `tests/screenshots.gd`, ajouter (après 2 lignes vides) :

````gdscript
# --- Mobiles (phase 6 du jeu en ligne) ---------------------------------------------------------------


## La fenêtre à la taille d'un écran de téléphone `ecran` (le voile suit son format) ; le voile relu tout
## de suite (sans fenêtre, en headless, rien ne change de taille).
func _tenir(ecran: Vector2i) -> void:
	DisplayServer.window_set_size(ecran)
	root.get_node("Parametres").actualiser_voile(ecran)
	await _attendre(0.2)


func _mobile() -> void:
	var params: Node = root.get_node("Parametres")
	var scores: Node = root.get_node("Scores")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	params.mobile = true
	await _tenir(PAYSAGE)

	# L'écran En ligne ouvert par un lien, le pseudo mémorisé : Rejoindre au focus, sans Créer une partie ;
	# puis un code refusé : le code en édition, sa rangée en haut, le message dessous (le clavier couvre le bas)
	scores.definir_preference("pseudo", "Léa")
	var ecran: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran.codes_de_salle = true
	ecran.code_a_l_arrivee = "K7Q2XM"
	root.add_child(ecran)
	await _attendre(0.3)
	await _shot_telephone("mobile_00_en_ligne", PAYSAGE)
	ecran.champ_code.text = "K7Q2X"
	ecran.rejoindre()
	await _attendre(0.2)
	await _shot_telephone("mobile_01_en_ligne_clavier", PAYSAGE)
	ecran.free()
	scores.definir_preference("pseudo", "")

	# Le salon d'un client : les flèches de la couleur et PRÊT, l'aide du tactile, Retour agrandi
	reseau.rejoindre("127.0.0.1", PORT_SANS_HOTE)
	var id_local: int = root.multiplayer.get_unique_id()
	reseau.table_salon.assign([
		{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Hôte", "pret": true},
		{"id": id_local, "index": 1, "couleur": palette[3], "pseudo": "Léa", "pret": false},
		{"id": 12, "index": 2, "couleur": palette[5], "pseudo": "Tom", "pret": true}])
	reseau.niveau_salon = 0
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await _attendre(0.4)
	await _shot_telephone("mobile_02_salon", PAYSAGE)
	salon.free()
	reseau.quitter()

	# La bataille (le HUD, le stick, VOMIR, la pause), puis l'écran Résultats d'un client
	var main := await _charger(4, ["Hôte", "Léa", "Tom", "WWWWWWWWWWWW"], 1)
	_poser_lions(main, [Vector2(300, 520), Vector2(800, 600), Vector2(1250, 450), Vector2(1600, 300)])
	_poser_scores(main.ville.territoire, [260, 410, 180, 90])
	GS.temps_ecoule = 41.2
	await _attendre(0.4)
	await _shot_telephone("mobile_03_bataille", PAYSAGE)
	await _tenir(PORTRAIT)
	await _shot_telephone("mobile_04_portrait_bataille", PORTRAIT)
	await _tenir(PAYSAGE)
	GS.temps_ecoule = 89.5
	while GS.partie_en_cours:
		await process_frame
	var vue := _revoir(main, false, true)
	await _attendre(0.3)
	await _shot_telephone("mobile_05_resultats", PAYSAGE)
	await _tenir(PORTRAIT)
	await _shot_telephone("mobile_06_portrait_resultats", PORTRAIT)
	vue.free()
	_quitter_la_bataille()
	params.mobile = false
	await _tenir(Vector2i(1400, 788))
````

Dans `.github/workflows/ci.yml`, remplacer :

````yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR|❌" captures.log deux_fenetres_hote.log deux_fenetres_client.log; then echo "::error::erreur dans un script de captures"; exit 1; fi
          [ "$(grep -c "📸" captures.log)" -eq 38 ] || { echo "::error::tests/screenshots.gd n'a pas déroulé ses 38 captures"; exit 1; }
          [ "$(grep -c "📸" deux_fenetres_hote.log)" -eq 5 ] && [ "$(grep -c "📸" deux_fenetres_client.log)" -eq 6 ] \
````

par :

````yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR|❌" captures.log deux_fenetres_hote.log deux_fenetres_client.log; then echo "::error::erreur dans un script de captures"; exit 1; fi
          [ "$(grep -c "📸" captures.log)" -eq 45 ] || { echo "::error::tests/screenshots.gd n'a pas déroulé ses 45 captures"; exit 1; }
          [ "$(grep -c "📸" deux_fenetres_hote.log)" -eq 5 ] && [ "$(grep -c "📸" deux_fenetres_client.log)" -eq 6 ] \
````

- [ ] **Step 2 : le déroulé sans rendu (ce que voit la CI)**

```bash
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"; grep "mobile_" "$TMPDIR/c.log"
```

Expected : `captures 0 : 45 📸`, rien d'autre ; les sept `mobile_…` dans l'ordre 00, 01, 02, 03, 04, 05, 06.

- [ ] **Step 3 : Commit**

```bash
git add tests/screenshots.gd .github/workflows/ci.yml
git commit -m "Captures : ce que montre un téléphone, en paysage (844×390 : En ligne, clavier, salon, bataille, Résultats) et en portrait (360×640 : le voile) ; 45 captures en CI

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 9 : la spec et le README

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§5 les mesures du profil mobile, §6 tel que construit, §10 le client mobile du bout en bout)
- Modify: `README.md` (les contrôles tactiles, les téléphones en ligne, le bout en bout, `--parties=…,mobile`)

**Interfaces:** aucune.

- [ ] **Step 1 : la spec**

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
  pertes) ; `InterpolationLion.RETARD` (6 ticks aujourd'hui) et les seuils de `PredictionLocale` ne
  se règlent que sur ses mesures.
- **Onglet caché ou téléphone verrouillé** :
````

par :

````markdown
  pertes) ; `InterpolationLion.RETARD` (6 ticks aujourd'hui) et les seuils de `PredictionLocale` ne
  se règlent que sur ses mesures. Phase 6 : sous ce profil, le parcours tient les seuils du Wi-Fi (aucun
  recalage, aucun à-coup, le lion distant à 4,83 à 6,44 px par tick pour 5,83), un étourdissement coûte
  41,5 px de prédiction sans recalage, un choc un pas (5,83 px) : constantes inchangées.
- **Onglet caché ou téléphone verrouillé** :
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
  lecture `Sample` après 10 à 30 min).

## 7. Viewport, HUD, Résultats
````

par :

````markdown
  lecture `Sample` après 10 à 30 min).
- Tel que construit (phase 6) : la détection est `Parametres.mobile`, que les tests forcent (le desktop
  n'a ni `web_android` ni `web_ios`). Une cible au doigt fait 150 px de l'écran du jeu au moins
  (`Parametres.CIBLE_TACTILE` : 44 px CSS à l'échelle 0,30 d'un iPhone en paysage sous les barres de
  Safari) ; les boutons tactiles restent à 60 px des bords (zone sûre). Écran En ligne d'un mobile : le
  focus au premier contrôle visible, un champ en édition remonte en haut de l'écran au-dessus du
  clavier virtuel (`html/experimental_virtual_keyboard`, dans les deux préréglages Web), Rejoindre agit à
  l'appui ; le lien reste le chemin principal (coller y est peu fiable). Au salon, les flèches de la
  couleur et PRÊT poussent leurs actions comme des touches : une action par appui (phase 18). Le voile
  suit la taille de la fenêtre à chaque image ; il couvre l'écran du jeu, pas les bandes noires autour.
  Le plein écran se demande une fois par page (Safari sur iPhone n'en a pas pour un canevas : rien ne
  se passe).

## 7. Viewport, HUD, Résultats
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
  console), départ de l'hôte vu par les autres avant les 10 s de silence ; sous WebKit, *Copier le lien*
  sous un vrai clic. L'exclusion d'un joueur s'y ajoute avec elle (phase 7). Le TURN ne se teste pas en
  local.
````

par :

````markdown
  console), départ de l'hôte vu par les autres avant les 10 s de silence ; sous WebKit, *Copier le lien*
  sous un vrai clic ; un mobile émulé par Chromium (Android en paysage) rejoint un hôte de bureau par le
  lien et joue au doigt (Rejoindre, la couleur, PRÊT, le stick et VOMIR : de vrais touchers), voit le
  voile en portrait (phase 6). L'exclusion d'un joueur s'y ajoute avec elle (phase 7). Le TURN ne se teste pas en
  local.
````

- [ ] **Step 2 : le README**

Dans `README.md`, remplacer :

````markdown
| Pause (Resume / Settings / Back to menu) | Esc, P | Start | II button, top right |

Touch controls only appear on devices with a touch screen. The **Settings** screen (title
screen or pause menu) has music and sound-effect volumes, fullscreen, an optional CRT filter
````

par :

````markdown
| Pause (Resume / Settings / Back to menu) | Esc, P | Start | II button, top right |

Touch controls appear on phones and on other touch screens. The **Settings** screen (title
screen or pause menu) has music and sound-effect volumes, fullscreen, an optional CRT filter
````

Dans `README.md`, remplacer :

````markdown
project setting), and the Web export must be served from `http://localhost:<port>` (not `127.0.0.1`).
From the editor (`godot .`), desktop builds play over ENet instead: **Multiplayer** opens the Online
````

par :

````markdown
project setting), and the Web export must be served from `http://localhost:<port>` (not `127.0.0.1`).
Phones (Android, iOS) join only, by the link: no **Create a game**; their first touch goes full screen
(a computer has a **Full screen** button in the lobby). In the lobby, the arrows pick a color and
**READY** gets ready; in the round, the stick and **PUKE**. Held upright, a phone shows « Tourne ton
téléphone » over the game, which keeps running.
From the editor (`godot .`), desktop builds play over ENet instead: **Multiplayer** opens the Online
````

Dans `README.md`, remplacer :

````markdown
The end-to-end test plays a real online round in three browser pages (Chromium and Firefox; WebKit
checks **Copy link**), on the "Web pilote" export and a local Worker that it starts itself
(`python3` serves the export on port 8060, `wrangler dev` listens on 8787):

```sh
````

par :

````markdown
The end-to-end test plays a real online round in three browser pages (Chromium and Firefox; WebKit
checks **Copy link**; an emulated Android phone, in Chromium, joins a desktop host and plays by touch),
on the "Web pilote" export and a local Worker that it starts itself (`python3` serves the export on
port 8060, `wrangler dev` listens on 8787):

```sh
````

Dans `README.md`, remplacer :

````markdown
```sh
godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=/output/path [--parties=solo,reseau,salon,bataille,resultats]
godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=/output/path
````

par :

````markdown
```sh
godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=/output/path [--parties=solo,reseau,salon,bataille,resultats,mobile]
godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=/output/path
````

- [ ] **Step 3 : Commit**

```bash
git add README.md docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
git commit -m "Spec et README : les mobiles tels que construits (couture, cibles au doigt, clavier, voile, plein écran), le client mobile du bout en bout, les mesures du profil mobile

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 10 : vérification commune, captures ◉, feuille de route, PR et fusion de la phase 6

**Files:**
- Modify: `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 6 : fichiers réels, « Faite (PR #N) »)

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
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "banc $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== |MESURE.*mobile" "$TMPDIR/p.log"
SECONDS=0; timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r.log"
(cd signalisation && npm ci --silent && npm test 2>&1 | tail -4)
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/dc.log" 2>&1 &
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/dh.log" 2>&1; echo "deux fenêtres hôte $?"; wait; grep -c "📸" "$TMPDIR/dh.log" "$TMPDIR/dc.log"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/dh.log" "$TMPDIR/dc.log"
mkdir -p export/web export/web-pilote
timeout 600 godot --headless --export-release Web export/web/index.html > "$TMPDIR/e.log" 2>&1; echo "export $?"
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
SECONDS=0; timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion-modules-signalisation:/depot/signalisation/node_modules -v lelion-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test' > "$TMPDIR/e2e.log" 2>&1; echo "bout en bout $? en ${SECONDS} s"; grep -E "✓|✘|passed|failed|Fin de manche|Départ" "$TMPDIR/e2e.log"
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/web/*.js
git status --short
```

Expected : « aucun autre godot » ; pas de « ÉCHEC COMPILATION » ; chaque suite Godot sort en 0 sur `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR` ; `PROTOCOLE 0.20 2553814265 (67 lignes)`, 530 ✅ unitaires, 449 ✅ smoke ; les trois lignes `MESURE … (mobile : …)` de la Task 5 ; réseau en 155 à 170 s (mesuré 160 s), ses trois mesures ; les tests du Worker verts (`70 passed`) ; 45 📸 pour les captures, 5 et 6 pour les deux fenêtres ; `export 0`, `export pilote 0` ; `bout en bout 0`, `4 passed` (mesuré 96 s) ; rien au `perl` ; `git status` propre. Un échec : le corriger dans la tâche qu'il concerne (commit à part), puis tout relancer.

- [ ] **Step 2 : les captures avec le vrai rendu ◉ (contrôle visuel)**

```bash
D="$TMPDIR/captures-phase6"; mkdir -p "$D"
timeout 300 godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier="$D" --parties=salon,mobile > "$TMPDIR/cv.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/cv.log") 📸"; ls "$D"
```

Expected : `captures 0 : 15 📸` (une fenêtre s'ouvre, change de taille, se ferme). À regarder (le contrôleur, `Read` sur chaque PNG) :
- `mobile_00_en_ligne.png` (844×390, échelle 0,347) : sans *Créer une partie* ni « ou rejoins… », le pseudo, le code `K7Q-2XM`, Rejoindre grand (52 px CSS), « Invitation reçue … », Retour agrandi ;
- `mobile_01_en_ligne_clavier.png` : la rangée du code en haut (le titre sorti par le haut), « Un code fait 6 caractères (ex. K7Q-2XM). » juste dessous, le bas libre pour le clavier ;
- `mobile_02_salon.png` : les cartes, l'état, « Flèches : ta couleur · PRÊT : prêt ou pas », les deux flèches en bas à gauche et PRÊT en bas à droite, sans chevauchement ;
- `mobile_03_bataille.png` : le HUD lisible, le stick en bas à gauche, VOMIR en bas à droite, la pause sous les vignettes ;
- `mobile_05_resultats.png` : l'écran Résultats d'un client (« En attente de l'hôte… », Quitter), les contrôles tactiles estompés dessous (écart 14) ;
- `mobile_04_portrait_bataille.png`, `mobile_06_portrait_resultats.png` (360×640, échelle 0,18) : le jeu en bandeau au milieu, sous le voile « Tourne ton téléphone », lisible ;
- `salon_00_hote_seul.png` (2000×1125) : *Plein écran* en haut à droite, l'invitation (« Code de la partie : K7Q-2XM », Copier le lien) à 63 px du bas.

Noter ce qui ne va pas (texte coupé, chevauchement, contraste) pour la PR ; ne rien retoucher sans accord.

- [ ] **Step 3 : la branche poussée, la PR ouverte** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
git push -u origin phase-06-mobiles
cat > "$TMPDIR/pr.md" <<'EOF'
Phase 6 de la feuille de route du jeu en ligne : les mobiles (spec §6).

- Un mobile (`Parametres.mobile` : `web_android` ou `web_ios`) n'a pas Créer une partie ; ses cibles font 150 px de l'écran du jeu (44 px CSS sur un iPhone en paysage sous les barres de Safari) ; le focus va au premier contrôle visible ; un champ en édition remonte au-dessus du clavier virtuel (`html/experimental_virtual_keyboard`, dans les deux préréglages), Rejoindre agit à l'appui.
- Contrôles tactiles : au salon, les flèches de la couleur et PRÊT (des boutons qui poussent leurs actions comme des touches : une action par appui, clavier et manette inchangés) ; en manche, le stick, VOMIR et la pause, placés sur l'écran du mode. Sur ordinateur, *Plein écran* au salon ; sur un mobile, le plein écran au premier toucher. L'invitation de l'hôte à 63 px du bas.
- En portrait, le voile « Tourne ton téléphone » par-dessus le jeu, qui continue. Le son du Web en `Stream`.
- Banc de la prédiction : le profil mobile (150 ms, 60 ms, 8 %) ; aucune constante ne change (mesures ci-dessous).
- Signalisation : sur un appareil lent, la file rattrape ses créneaux de 50 ms (2 images au lieu de 9 pour 9 messages à 2 i/s), la salle jamais à sec.
- Bout en bout : un mobile émulé (Pixel 7 en paysage) rejoint par le lien et joue une manche au doigt, voit le voile en portrait. Captures 844×390 et 360×640 (45 en CI).

Mesures (ce Mac, Step 1) : MESURES

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
gh pr create --repo w3cdotorg/LeLion-web --base main --head phase-06-mobiles --title "Phase 6 : mobiles" --body-file "$TMPDIR/pr.md"
N=$(gh pr view --repo w3cdotorg/LeLion-web phase-06-mobiles --json number -q .number); echo "PR #$N"
```

Entre l'écriture de `$TMPDIR/pr.md` et `gh pr create`, y remplacer `MESURES` (outil Edit) par les mesures du Step 1 : les trois lignes `MESURE … (mobile : …)` du banc, la durée du test réseau, celle du bout en bout et la ligne « Fin de manche » du mobile, et ce que le Step 2 a relevé.

- [ ] **Step 4 : la feuille de route**

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

````markdown
| ✏️ `Scripts/ControlesTactiles.gd` ✏️ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `project.godot` ✏️ `tests/prediction_test.gd` | Captures 360×640 et 844×390 ; banc vert sous le profil mobile. |
````

par (`NUMERO` est le numéro de la PR, `$N` du Step 3) :

````markdown
| ✏️ `Scripts/Parametres.gd` (couture `mobile`, plein écran, voile) ✏️ `Scripts/ControlesTactiles.gd` ✏️ `Scenes/ControlesTactiles.tscn` ✏️ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scenes/Salon.tscn` ✏️ `Scripts/TransportWebRTC.gd` (file lente) ✏️ `Scripts/PiloteWeb.gd` ✏️ `project.godot` ✏️ `export_presets.cfg` ✏️ `Assets/Traductions/traductions.csv` ✏️ tests (`unitaires`, `smoke_test`, `prediction_test`, `screenshots`, `web/`) ✏️ `.github/workflows/ci.yml` ✏️ spec ✏️ `README.md` | Captures 360×640 et 844×390 ; banc vert sous le profil mobile (aucune constante changée) ; un mobile émulé joue une manche au doigt de bout en bout. Faite (PR #NUMERO). |
````

puis :

```bash
perl -pi -e "s/PR #NUMERO/PR #$N/" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
grep -c "Faite (PR #$N)" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git add docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git commit -m "Feuille de route : phase 6 faite (PR #$N)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
git push
```

Expected : `1`.

- [ ] **Step 5 : la CI, puis la fusion** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
gh pr checks --repo w3cdotorg/LeLion-web "$N" --watch
gh pr merge --repo w3cdotorg/LeLion-web "$N" --merge
git switch main && git pull --ff-only && git log --oneline -3
```

Expected : les trois jobs verts (le projet `mobile` tourne ici pour la première fois sur GitHub : un échec propre à son environnement se diagnostique avec l'artefact `rapport-playwright` avant toute retouche ; un passage du job au-delà de 120 s par test relève le délai de `playwright.config.js` à 300 s, note de la revue de la phase 4) ; la fusion faite, `main` à jour. La CI rouge : ne pas fusionner, diagnostiquer.
