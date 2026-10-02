# Phase 7 : sécurité du jeu et documentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le jeu en ligne se défend contre un client qui inonde l'hôte, contre un pseudo hostile et contre un joueur indésirable, et dit vrai quand un onglet caché ou un téléphone verrouillé a coupé un joueur (spec §5, §8.2, §9) : l'hôte jette au-delà de 2 paquets de commandes par tick et par client, et de 10 demandes de salon par seconde ; les pseudos perdent aussi les caractères de mise en forme d'Unicode et ne sont jamais interprétés ; l'hôte exclut un joueur du salon par la croix de sa carte (« L'hôte t'a exclu de la partie. »), l'exclu peut revenir avec le code ; un poste revenu d'un gel plus long que le silence toléré lit « Tu as été déconnecté », le salon de l'hôte dit « Garde cet onglet au premier plan pendant la partie. ». Les canaux non fiables du navigateur gardent enfin un paquet 100 ms au plus (Godot 4.7.2 leur passe une option que les navigateurs ignorent). Le test de bout en bout gagne l'exclusion d'un vrai clic, les lions qui se croisent, le mobile revenu d'un gel et les exceptions JavaScript. Le README a sa section « Jouer en ligne » (en français), et la fiche `docs/essai-en-ligne.md` est prête pour l'essai réel. Sortie : **unitaires des limites et de l'exclusion ; fiche prête pour l'essai** (feuille de route, ligne 7).

**Architecture:**
- **`LimiteDebit`** (neuf, `class_name`, logique pure) : un seau de jetons par émetteur (`admettre(id, instant)`, `rejets`, `oublier`, `vider`), à l'horloge de l'hôte, en secondes.
- **`Manche`** (chez l'hôte) : `admettre_commandes(id)` avant `recevoir_paquet_de`, 2 paquets par tick (120 par seconde à 60 ticks par seconde), 120 d'un coup ; l'excédent est jeté, compté, un avertissement au premier rejet d'un client.
- **`Reseau`** : `admettre_demande_salon(id)` (couleur et Prêt confondus, 10 par seconde, 10 d'un coup) ; `exclure_du_salon(id)` et l'annonce `_recevoir_exclusion(par_l_hote)` (`PERTE_EXCLU_HOTE`, libération de secours au bout de `DELAI_EXCLUSION_SALON`) ; la fin d'un gel de ce poste (`_derniere_image`, `_fin_du_gel`, `au_retour_d_un_gel`) et `PERTE_DECONNECTE` ; `_code_point_interdit` élargi à la catégorie Cf d'Unicode et aux lettres vides du coréen.
- **`Salon`** : la croix d'exclusion en haut à droite de la carte de chaque autre joueur, chez l'hôte (`exclure(index)`), et la consigne de l'onglet en haut du salon de l'hôte, sur ordinateur (`Consigne`, `Scenes/Salon.tscn`). **`Main`** : un poste revenu d'un gel retourne à l'écran En ligne, pas au titre.
- **`TransportWebRTC`** : `CORRECTIF_CANAUX`, posé une fois par page (`createDataChannel` lit l'option `maxPacketLifetime` de Godot sous son nom du standard, `maxPacketLifeTime`).
- **`PiloteWeb`** : les croix des cartes (en px CSS), la durée de vie des canaux non fiables, les étourdissements et chocs du bilan ; la commande `rencontrer`. **Tests** : unitaires (`_tester_limites`, `_tester_pseudos_affiches`, `_tester_demandes_salon`, `_tester_exclusion`, `_tester_retour_de_gel` ; un second poste dans le processus par `_poste_client`) ; smoke (les paquets de Bob, la croix et la consigne, les étiquettes de pseudo, le retour d'un gel) ; bout en bout (`@manche` : l'exclusion d'un vrai clic, la rencontre, les canaux ; `@mobile` : 12 s de gel, « Tu as été déconnecté » ; `pageerror` partout).
- **Documentation** : `README.md` (« Jouer en ligne »), `docs/essai-en-ligne.md`, la spec telle que construite (§5, §8.2, §10).

**Tech Stack:** Godot 4.7.2 (GDScript typé, `SceneMultiplayer`, `WebRTCMultiplayerPeer`, `JavaScriptBridge`), export Web single-thread (templates `web_nothreads_*` 4.7.2), Playwright 1.63.0 (`@playwright/test`, image `mcr.microsoft.com/playwright:v1.63.0-noble`), Worker de la phase 2 en local (`wrangler dev`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§5 Onglet caché, §8.2, §9, §10, §13) · feuille de route `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 7, « Notes de la revue de la phase 4 » et « Notes de la revue de la phase 6 », parties **Phase 7**, « Vérification commune », « Points de vigilance ») · plans des phases 4 et 6 (le pilote, `tests/web/`, l'environnement du bout en bout) · prérequis : **phase 6 fusionnée** (PR #7) ; branche `phase-07-securite` depuis `main`. La phase 5 (déploiement) attend le compte Cloudflare : cette phase passe avant elle et ne dépend d'aucun Worker déployé (tout se joue sur `ws://localhost:8787`).

## Global Constraints

- Spec §8.2, mot pour mot : « RPC des clients : en plus des vérifications de type et d'émetteur déjà faites, l'hôte jette au-delà de 2 paquets de commandes par tick et par client, et de 10 demandes de salon (couleur, Prêt) par seconde. » ; « Poignée de main : bornée en taille (inchangé), décodée sans objets (`bytes_to_var`, inchangé). » ; « Pseudos : 12 caractères (inchangé), caractères de contrôle et sauts de ligne retirés ; jamais de BBCode interprété (`RichTextLabel` avec `bbcode_enabled` interdit pour un pseudo). » ; « **Exclusion** : l'hôte exclut un joueur du salon (croix sur sa carte) ; l'exclu reçoit « L'hôte t'a exclu de la partie. » puis l'hôte ferme son pair. Sans compte, rien n'identifie durablement un joueur : un exclu peut revenir avec le code, et l'hôte l'exclut à nouveau (§13). » ; « Vie privée : aucun compte, rien de stocké. Cloudflare voit les IP le temps de la signalisation ; hôte et client voient l'IP l'un de l'autre, sauf connexion par le TURN. Le README le dit. »
- Spec §5 et §9, mot pour mot : « un client caché n'envoie plus rien : 10 s après, l'hôte le déclare parti (son lion disparaît, ses cellules restent, comme au LAN). À son retour, son poste voit « Tu as été déconnecté » et revient à l'écran En ligne » ; « l'hôte caché fige le jeu de tous : le salon lui affiche « Garde cet onglet au premier plan pendant la partie. » » ; table du §9 : « Exclu par l'hôte | « L'hôte t'a exclu de la partie. » », « Client revenu d'un onglet caché, déclaré parti entre-temps (silence) | « Tu as été déconnecté » puis écran En ligne ». Spec §11 : « README : en anglais comme aujourd'hui, avec une section « Jouer en ligne » en français (créer, inviter, rejoindre, onglet au premier plan, mobiles, vie privée, dépannage message par message). »
- Notes de la revue (feuille de route), parties **Phase 7**, mot pour mot : « L'étape d'exclusion dans l'e2e. » ; « « Garde cet onglet au premier plan » et « Tu as été déconnecté ». » ; « La formulation du §5 (« 1 seul envoi » contre maxPacketLifetime 100 ms). » ; « Élargir l'e2e : capter les exceptions JS (`pageerror`) en plus de la console, et refaire se croiser les lions (étourdissements, chocs) dans la manche à trois pages. » ; « La phase 6 ne change ni le protocole ni la surface d'attaque. » ; « Fiche de l'essai réel : plein écran Android au relâchement ; premier toucher sur le champ pseudo (clavier et plein écran en même temps) ; lisibilité des textes des Résultats (~10 px CSS) ; zone morte effective du joystick (0,5) ; appareil lent ; Retour à 24 px du coin ; contraste du libellé PRÊT/VOMIR (rose sur anneau rose) ; une tranche de la rangée du pseudo au bord haut quand le clavier est ouvert ; un hôte desktop tactile voit les flèches du salon ; le réglage Plein écran ne reflète pas le mode du téléphone ; position du joystick codée en dur dans le pilote. »
- Valeurs de cette phase : `Manche.COMMANDES_PAR_TICK := 2`, `Manche.RAFALE_COMMANDES := 120`, le débit `COMMANDES_PAR_TICK * Engine.physics_ticks_per_second` (120 par seconde), à l'horloge de l'hôte (`Time.get_ticks_msec() / 1000.0`) ; `Reseau.DEMANDES_SALON_PAR_SECONDE := 10` (débit et plein) ; `LimiteDebit.ARRONDI := 1e-6` ; `Reseau.PERTE_EXCLU_HOTE := "RESEAU_EXCLU_HOTE"`, `Reseau.DELAI_EXCLUSION_SALON := 2.0` (la barrière garde `DELAI_EXCLUSION` 0,5) ; `Reseau.PERTE_DECONNECTE := "RESEAU_DECONNECTE"`, `Reseau.RETOUR_DE_GEL := 2.0` ; `Salon.TAILLE_CROIX := Vector2(64, 64)`, `Salon.POLICE_CROIX := 40`, le texte « × » ; la consigne `Consigne` (ancrée en haut au centre, de -560 à 560 px, de 30 à 70 px du haut, police 26) ; `PiloteWeb.TICKS_RENCONTRE := 150`, `ZONE_MILIEU := 20.0`, `HAUTEUR_RENCONTRE := 200.0`, `ZONE_HAUTEUR := 10.0` ; la manche `@manche` de 14 s, le gel du mobile de 12 s ; ports des unitaires neufs 17782 à 17784.
- Version et protocole (feuille de route) : l'annonce d'exclusion prend un argument (`_recevoir_exclusion(par_l_hote)`) : `config/version` passe à **0.21**, `PROTOCOLE_EMPREINTE` est renotée : `PROTOCOLE 0.21 1188810746 (67 lignes)` (mesuré sur ce plan appliqué ; 0.20 2553814265 avant).
- Commandes : `export PATH="$HOME/.orbstack/bin:/opt/homebrew/bin:$PATH"` puis `cd ~/Sites/LeLion-web` ; chaque commande godot sous `timeout`, options écrites en clair (zsh ne découpe pas une variable non quotée : `--fixed-fps` sauterait en silence). Une suite `--script` qui ne se compile pas sort en 0 : lire sa sortie, jamais son seul code.
- Ports : les suites Godot et le test réseau prennent les ports 17777 à 19990 de ce poste ; un autre agent qui lance les mêmes suites en même temps fait échouer l'une ou l'autre : une suite ne tourne qu'avec aucun autre `godot --headless` (`pgrep -f 'godot --headless'` vide), et un échec de port se relance une fois avant d'être diagnostiqué.
- Un test `--script` est compilé **avant** les autoloads : il récupère `Reseau`, `Scores`, `GameState`, `Parametres`, `PiloteWeb` par `root.get_node(...)`, ne les nomme jamais (il peut nommer `LimiteDebit`, `TransportWebRTC`, `BilanManche` : des `class_name` qui ne nomment aucun autoload). Un script neuf à `class_name` (`Scripts/LimiteDebit.gd`) : l'import (`godot --headless --import .`) crée son `.uid`, à committer avec lui. Après une modification de `traductions.csv`, l'import régénère `traductions.fr.translation` et `traductions.en.translation` : les committer avec le CSV.
- Le bout en bout local tourne dans l'image `mcr.microsoft.com/playwright:v1.63.0-noble` (Docker d'OrbStack ici) : le pare-feu de ce Mac bloque WebRTC entre les navigateurs de Playwright (plan de la phase 4, écart 13). L'export « Web pilote » se refait avant chaque passage (le test lit `export/web-pilote`). Les volumes des modules sont propres à cette phase (`lelion7-modules-*`) : un autre agent qui fait `npm ci` dans les volumes du README en même temps les casserait.
- Les blocs « Dans X, remplacer … par … » citent le texte exact laissé par la tâche précédente (générés depuis ce plan appliqué, tâche après tâche, à une copie de la branche de la phase 6, et vérifiés par une seconde application mécanique sur une copie neuve) ; chacun se fait avec l'outil Edit (texte exact, une seule occurrence), dans l'ordre donné. « Créer X » donne le fichier entier (outil Write). Les blocs sont entourés de quatre accents graves (le README en contient trois).
- Identifiants, commentaires et messages en français, docstrings `##`, tabulations (GDScript, JavaScript, JSON du dépôt). Aucune séquence `\u…` tapée dans un fichier (les caractères invisibles des tests passent par `char(0x…)`) ; après chaque écriture, `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/web/*.js` ne sort rien. Aucun message de test ne contient `SCRIPT ERROR` ni `SHADER ERROR`.
- Bruit connu des sorties : celui des plans précédents (« ObjectDB instances were leaked », « resources still in use at exit », `ERROR: Couldn't create an ENet host.`, `ERROR: The local port number must be between 0 and 65535`, les `WARNING: Signalisation : …` des unitaires) ; neuf, voulu : `WARNING: Reseau : le client N fait plus de 10 demandes de salon par seconde, l'excédent est jeté` (unitaires) et `WARNING: Manche : le client 7 envoie plus de 2 paquets de commandes par tick, l'excédent est jeté` (smoke) ; dans les pages du bout en bout, `WARNING: Lion : état de l'hôte illisible, ignoré` et, sous Firefox, l'avertissement de WebAssembly sur l'instruction `try`.
- Commits en français, terminés par :
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT
  ```

## Review Focus

1. **Un client qui joue limité, ou un client qui inonde l'hôte sans frein** (une limite comptée en ticks physiques de l'hôte, qui jette les paquets d'un client quand l'hôte ralentit ; une rafale légitime, après un gel de l'hôte ou un Wi-Fi qui retient, jetée ; couleur et Prêt sur deux seaux ; un client parti dont le seau reste) : un seau par client à l'horloge de l'hôte, 120 paquets d'un coup, couleur et Prêt confondus, oubliés au départ. → unitaires « 10 s d'un client qui joue (un paquet par tick), puis l'hôte figé 2 s : aucun paquet jeté ; à dix par tick, deux passent par tick … », « 130 paquets d'un coup : 120 passent … », « 30 demandes de couleur et une de Prêt d'un coup : 10 changements de couleur, 21 demandes jetées … », « le client parti, l'hôte oublie son seau et ses rejets » (Task 1) ; smoke « 150 paquets de commandes de Bob d'un coup : 120 passent … », « Bob parti, la manche oublie le compte de ses paquets » (Task 1) ; bout en bout : aucune page ne dit « l'excédent est jeté » (`erreurs`, Chromium, Firefox, le mobile ; Task 7).
2. **Une exclusion qui se trompe** (l'exclu lit « L'hôte a quitté la partie », l'hôte s'exclut lui-même, un client exclut, une exclusion en pleine manche ou d'une place réservée, un exclu qui ne peut plus revenir, un exclu figé jamais libéré, une croix sur la carte de l'hôte ou chez un client) : `exclure_du_salon` et ses refus, l'annonce qui porte sa raison, le secours à 2 s. → unitaires « refusée : l'hôte ne s'exclut pas lui-même … », « refusée pendant une manche … et pour une place seulement réservée », « l'exclu lit « L'hôte t'a exclu de la partie. » et s'en va de lui-même, en … ms … », « l'exclu revient avec le code … », « … et l'hôte l'exclut de nouveau … », « un exclu qui ne s'en va pas : l'hôte le libère au bout de … ms … » (Task 2) ; smoke « chez l'hôte, la carte de Bob a la croix d'exclusion en haut à droite … », « un client n'a aucune croix d'exclusion » (Task 4) ; bout en bout `@manche` (un vrai clic sur la croix, Bruno revient avec le code ; Task 7).
3. **Un pseudo qui se cache ou s'interprète** (des caractères invisibles ou de mise en forme qui font un pseudo vide ou qui retournent la ligne, un pseudo lu comme du BBCode, un pseudo « PAUSE » traduit par une étiquette) : `_code_point_interdit` élargi, avant la coupe à 12 ; aucun `RichTextLabel` ; chaque étiquette de pseudo sans traduction automatique. → unitaires « phase 7 : nettoyé aussi des caractères de mise en forme d'Unicode … », « un pseudo fait seulement de lettres vides et d'étiquettes retombe sur « Joueur N » », « aucun RichTextLabel ni BBCode … », « l'étiquette du pseudo d'un lion est un Label qui ne se traduit pas de lui-même » (Task 5) ; smoke « le pseudo de chaque carte … », « les pseudos du HUD … », « les pseudos de l'écran Résultats … » (Task 5).
4. **Un message faux après un onglet caché** (« L'hôte a quitté la partie » pour un joueur revenu d'un gel ; « Tu as été déconnecté » sans gel ; un gel au chargement, toléré 30 s, pris pour une coupure ; le titre au lieu de l'écran En ligne ; la consigne absente chez l'hôte, ou présente chez un client ou sur un mobile) : la fin du gel mesurée par ce poste, la décision prise au moment de la perte, `Main._apres_la_perte`. → unitaires « un gel de ce poste : plus de 10 s sans image … », « l'hôte perdu au retour d'un gel : « Tu as été déconnecté » ; sans gel, « L'hôte a quitté la partie » … », « au retour de son gel : « Tu as été déconnecté » … » (Task 3) ; smoke « revenu d'un onglet caché : « Tu as été déconnecté » … puis l'écran En ligne … » (Task 3), « chez l'hôte, sur ordinateur : « Garde cet onglet au premier plan pendant la partie. » … », « un client : … pas la consigne de l'onglet », « un mobile n'a pas Plein écran ni la consigne … » (Task 4) ; bout en bout `@mobile` (12 s de gel, « Tu as été déconnecté », l'écran En ligne ; Task 7).
5. **Le réseau qui change sans qu'on le voie** (une RPC changée sous la même version ; des canaux « non fiables » fiables dans le navigateur, un paquet perdu renvoyé sans fin ; une manche à trois pages où les lions ne se croisent plus, ou dont le bilan diffère d'une page à l'autre ; une exception JavaScript qui passe) : la version 0.21 et son empreinte, `CORRECTIF_CANAUX`, la rencontre du pilote, `pageerror`. → unitaires « le protocole … est celui de la version 0.21 … », « les canaux non fiables du navigateur : un paquet perdu renvoyé 100 ms au plus … » (Tasks 2, 6) ; bout en bout `@manche` (`[100, 100]` sur chaque page : `[0, 0]` sans le correctif, mesuré ; même empreinte et même bilan, des chocs ; Task 7) ; le test réseau, inchangé, vert (la barrière exclut encore par la même annonce, scénarios 9 et 10 ; Task 9).

## Écarts assumés

1. **Une seule PR pour la ligne 7.** Fichiers au-delà de la ligne 7 de la feuille de route (qui ne citait que `Reseau.gd`, `Salon.gd`, `unitaires.gd`, `README.md`, `docs/essai-en-ligne.md`) : `Scripts/LimiteDebit.gd` (+ `.uid`, la limite en logique pure, testée seule), `Scripts/Manche.gd` (les paquets de commandes y arrivent), `Scripts/Main.gd` (le retour à l'écran En ligne), `Scenes/Salon.tscn` (la consigne), `Scripts/TransportWebRTC.gd` (le correctif des canaux), `Scripts/PiloteWeb.gd`, `project.godot` (la version), `Assets/Traductions/traductions.csv` (+ `.translation`), `tests/smoke_test.gd`, `tests/web/bout_en_bout.spec.js`, la spec et la feuille de route. Chaque tâche touche 5 fichiers de code au plus (plafond levé par l'utilisateur depuis la phase 1 ; tenu ici quand même).
2. **Les limites de débit, chez l'hôte, par émetteur, à l'horloge de l'hôte** (la spec ne dit ni où ni comment) : un seau de jetons par client (`LimiteDebit`), pas une fenêtre par tick : une fenêtre jetterait la deuxième moitié d'une rafale que la file d'un Wi-Fi ou d'un relais délivre d'un coup. « 2 paquets par tick » se lit au tick de la cadence du jeu (60 par seconde : 120 paquets par seconde), mesuré à l'horloge de l'hôte, pas à ses ticks physiques : compté en ticks physiques (la première version de ce plan), un hôte qui ralentit en fait moins, et il jetait les paquets d'un client qui joue (vu sous Firefox, en bout en bout : « l'excédent est jeté » chez l'hôte). Le plein, 120 paquets, est deux secondes d'un client : un hôte figé deux secondes (un onglet ralenti, une compilation de shader) ne jette aucun des paquets accumulés. Un client qui inonde l'hôte passe à 2 paquets par tick ; ce qu'il coûte encore (le décodage de chaque RPC par `SceneMultiplayer`, avant le seau) est borné par le transport.
3. **L'excédent est jeté sans réponse et compté** (`rejets`), un avertissement au premier rejet d'un client (pas à chacun : un client qui inonde l'hôte n'inonde pas son journal) ; **personne n'est déconnecté pour autant** : un client qui joue n'atteint jamais ces limites (le bout en bout le vérifie), et l'hôte peut exclure du salon un client qui abuse. Les demandes de salon : couleur et Prêt dans le même seau de 10 (spec : « 10 demandes de salon (couleur, Prêt) par seconde »), une demande mal formée comptée comme les autres. `_battement`, `_scene_chargee` et l'adieu ne sont pas limités (la spec ne les nomme pas : un battement par seconde, une scène chargée par manche, un adieu par session).
4. **L'exclusion : la même annonce que la barrière, avec sa raison** (`_recevoir_exclusion(par_l_hote)` : un booléen, illisible, il vaut l'exclusion de la barrière) plutôt qu'une deuxième RPC ; une raison distincte, `PERTE_EXCLU_HOTE` (« L'hôte t'a exclu de la partie. »), le message de la barrière restant le sien. L'argument change la signature : version 0.21. La libération de secours attend 2 s au salon (0,5 s à la barrière, qu'une manche attend) : une annonce renvoyée par une 4G arrive avant la fermeture, qui dirait « L'hôte a quitté la partie » (l'exclu part en une aller-retour, mesuré 19 ms en local). **Au salon seulement** (spec : « depuis le salon ») : ni en manche ni à l'écran Résultats, `exclure_du_salon` refuse pendant une manche. Pas de confirmation (l'exclu peut revenir avec le code). La croix se clique **à la souris** (l'hôte est un ordinateur) ou au doigt ; ni le clavier ni la manette ne l'atteignent : le salon n'a pas de curseur de carte (ses flèches changent la couleur) ; ajouter un tel curseur changerait les commandes du salon (phase 18) pour un geste rare. Aucune exclusion automatique au retour d'un exclu : rien ne l'identifie (spec §13).
5. **« Tu as été déconnecté » : ce poste mesure son propre gel** (la spec ne dit pas comment un client le sait) : `_process` note chaque image ; plus que le silence toléré sans image (10 s, 30 s au chargement), c'est un gel, et l'hôte l'a alors déclaré parti (le même délai chez lui). La décision se prend au moment de la perte (`_decider`), parce que la fermeture du pair par l'hôte arrive au relevé des paquets, avant la première image du retour (`SceneTree.process` relève les paquets, puis vide les appels différés, puis appelle les `_process`) ; ou dans les `RETOUR_DE_GEL` (2 s) qui suivent cette image (le silence de l'hôte, rendu à l'image suivante). Si l'hôte est parti lui aussi pendant le gel, le message reste « Tu as été déconnecté » : c'est vrai, et rien ne distingue les deux cas. Depuis une manche, retour à l'écran En ligne (spec §9), pas au titre (« L'hôte a quitté la partie » y garde le titre, comme au LAN) ; le code n'est pas pré-rempli : le lien le rouvre. Un hôte figé ne lit rien de neuf : ses clients sont partis, son salon le montre.
6. **« Garde cet onglet au premier plan pendant la partie. »** en haut au centre du salon de l'hôte, entre Retour et Plein écran, au-dessus du titre (la colonne du salon, resserrée en phase 6, n'a plus de place en bas) ; chez l'hôte seulement, jamais sur un mobile (un mobile n'héberge pas) ; aussi sur le desktop de développement (ENet), sans dommage.
7. **Les pseudos** : nettoyés chez l'hôte (qui fait foi) et relus chez chaque client (`lire_table`, inchangé). En plus des contrôles, des forçages de sens et des caractères de largeur nulle (déjà là) : toute la catégorie Cf d'Unicode (U+00AD, U+0600 à U+0605, U+061C, U+06DD, U+070F, U+0890, U+0891, U+08E2, U+180E, U+FFF9 à U+FFFB, U+110BD, U+110CD, U+13430 à U+1343F, U+1BCA0 à U+1BCA3, U+1D173 à U+1D17A, les étiquettes U+E0001 et U+E0020 à U+E007F), le joint de graphèmes U+034F, les sélecteurs de variante mongols (U+180B à U+180F) et ceux du plan 14 (U+E0100 à U+E01EF), et les lettres vides du coréen (U+115F, U+1160, U+3164, U+FFA0), avant la coupe à 12. Gardés : les sélecteurs U+FE00 à U+FE0F (la présentation d'un emoji), les espaces visibles, les marques combinantes (un pseudo surchargé de diacritiques reste borné à 12 caractères : la carte du salon le coupe, l'étiquette du lion le borne). Il n'y a aucun `RichTextLabel` dans le jeu : un `Label` n'interprète jamais de BBCode ; le test le garde, et vérifie qu'aucune étiquette de pseudo (cartes, HUD, Résultats, lion) ne se traduit d'elle-même.
8. **Les canaux non fiables du navigateur** (la note « 1 seul envoi » contre `maxPacketLifetime` 100 ms) : mesuré dans Chromium et Firefox, `createDataChannel(…, {maxPacketLifetime: 100})`, ce que fait `WebRTCMultiplayerPeer.add_peer` de Godot 4.7.2, donne un canal sans durée de vie (`maxPacketLifeTime` vaut `null`) : le standard écrit `maxPacketLifeTime`. Les canaux « non fiables » de l'export Web étaient donc fiables (chaque paquet perdu renvoyé jusqu'à son arrivée), le contraire de la spec §5. `TransportWebRTC.CORRECTIF_CANAUX` (posé à la création du transport, une fois par page, sans effet là où WebRTC manque) passe l'option sous les deux noms ; le bout en bout lit 100 ms sur chaque canal (`[0, 0]` sans lui, mesuré). Sous 8 % de pertes, un état ou un battement perdu n'est plus renvoyé après 100 ms : c'est ce que le banc de la prédiction mesure depuis la phase 6. La spec §5 dit désormais « partiellement fiable, renvoyé 100 ms au plus », pas « 1 seul envoi » (ce que serait `maxRetransmits: 0`). Signalé pour Godot en amont (hors de cette phase).
9. **Le bout en bout élargi** : l'exclusion d'un **vrai clic** sur la croix (le pilote donne sa place en px CSS). Sous Xvfb, sans gestionnaire de fenêtres, ce clic monte la fenêtre de l'hôte au-dessus des autres : Firefox ne dessinait plus celle d'Anna, entièrement couverte (mesuré : 2 images en 3 s), et son jeu s'y figeait ; les fenêtres des invités remontent ensuite dans leur ordre (`bringToFront`). La rencontre : après sa passe, chaque lion va au milieu de l'écran en vomissant, 200 px au-dessus de la hauteur de peinture (la gerbe, qui tombe de 190 px, n'y atteint plus les toits : la rencontre ne vole aucune cellule de la passe, et « chacun a peint » tient ; au niveau de la peinture, Anna, au milieu, tombait à 15 cellules) ; la manche passe à 14 s. Mesuré (Chromium et Firefox, 6 passages) : 6 à 14 chocs, 1 à 2 étourdissements par manche ; le test exige des chocs et le même bilan sur les trois pages, et écrit les étourdissements sans les exiger (une gerbe face à face n'en donne pas à coup sûr). Le gel du mobile : la page tourne 12 s sans rendre la main (`page.evaluate`), comme un onglet caché ou un téléphone verrouillé (le navigateur ne demande plus d'image) ; l'hôte le déclare parti à 10 s. Une exception JavaScript (`pageerror`) ou un client limité par l'hôte fait échouer le test, comme une erreur de la console. Mesuré : 132 à 141 s pour les quatre tests (96 s en phase 6).
10. **Le test réseau ne change pas** : les échanges neufs (l'inondation du salon, l'exclusion et le retour de l'exclu, le gel d'un client) se jouent entre l'autoload et un second poste dans le processus des unitaires (une vraie session ENet, de vraies RPC, `_poste_client`), en quelques secondes ; le bout en bout les rejoue en WebRTC. Un scénario de plus à `lancer.sh` coûterait 15 s à une suite de 160 s pour ce que ces deux tests couvrent déjà. Le gel s'y simule par `set_process(false)` (plus d'image ni de battement ; la `SceneMultiplayer` du poste relève encore ses paquets, comme le navigateur au retour), sous des silences raccourcis (1,5 s chez l'hôte, 1 s chez le client).
11. **La fiche de l'essai réel** reprend la forme de l'ancienne fiche du LAN (cases, « Ce que fera la phase 7 bis ») : créer et rejoindre, une manche puis une manche par le relais (`?relais=1`), l'onglet de l'hôte, les téléphones (les points des notes de la revue de la phase 6, et l'iPhone de la spec §13), les départs, l'exclusion et la veille. « Position du joystick codée en dur dans le pilote » n'est pas un point d'appareil : le stick apparaît sous le pouce, partout dans la moitié gauche, et le pilote en vise un point ; la fiche le note pour l'essai, sans retouche au pilote.
12. **Le README** : la section « Jouer en ligne », en français, dit que la page n'est pas encore publiée (le déploiement est la phase 5) ; la vie privée telle qu'elle est (le pseudo et les réglages dans le navigateur ; l'IP vue par Cloudflare, qui s'en sert pour les limites par minute sans l'écrire dans ses journaux, `signalisation/src/protocole.js` ; les IP vues entre joueurs, sauf par le relais) ; le dépannage, message par message, reprend chaque message du §9 et les refus du LAN.
13. **Version et protocole** : 0.21, `PROTOCOLE 0.21 1188810746 (67 lignes)` (seul `_recevoir_exclusion` change : un argument de plus).
14. **Step 0** (règle du projet : `Reseau.gd` 1204 lignes, `Salon.gd` 369, `Manche.gd` 613, `Main.gd` 475, `TransportWebRTC.gd` 585 touchés) : rien à retirer (vérifié, Task 0).

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
git log --oneline main | grep -m1 "phase-06-mobiles" || echo "PHASE 6 ABSENTE"
git switch -c phase-07-securite
wc -l Scripts/Reseau.gd Scripts/Salon.gd Scenes/Salon.tscn Scripts/Manche.gd Scripts/Main.gd Scripts/PiloteWeb.gd Scripts/TransportWebRTC.gd Assets/Traductions/traductions.csv tests/unitaires.gd tests/smoke_test.gd tests/web/bout_en_bout.spec.js README.md docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
grep -n 'config/version' project.godot; ls Scripts/LimiteDebit.gd docs/essai-en-ligne.md 2>&1
```

Expected : la fusion de la PR de la phase 6 (`Merge pull request #7 from w3cdotorg/phase-06-mobiles`) ; `1204 Scripts/Reseau.gd`, `369 Scripts/Salon.gd`, `142 Scenes/Salon.tscn`, `613 Scripts/Manche.gd`, `475 Scripts/Main.gd`, `279 Scripts/PiloteWeb.gd`, `585 Scripts/TransportWebRTC.gd`, `147 Assets/Traductions/traductions.csv`, `3278 tests/unitaires.gd`, `2922 tests/smoke_test.gd`, `242 tests/web/bout_en_bout.spec.js`, `216 README.md`, `348 docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` ; `config/version="0.20"` ; les deux fichiers absents. « PHASE 6 ABSENTE » ou d'autres longueurs : s'arrêter et le signaler (les blocs de ce plan citent le texte de la branche de la phase 6 à `acf9fb2` ; une vague de corrections fusionnée avec elle les aurait déplacés).

- [ ] **Step 2 : Step 0 (règle du projet, cinq fichiers touchés font plus de 300 lignes)**

```bash
for f in Scripts/Reseau.gd Scripts/Salon.gd Scripts/Manche.gd Scripts/Main.gd Scripts/TransportWebRTC.gd; do
	for n in $(grep -oE "^(const|var|func|static func|signal|enum) [A-Za-z_0-9]+" $f | awk '{print $NF}'); do
		[ "$(grep -rwo "$n" Scripts tests Scenes | wc -l | tr -d ' ')" -lt 2 ] && echo "seul : $f $n"
	done
done
grep -nE "^[[:space:]]*(print|prints|printt|print_debug|breakpoint)\b" Scripts/Reseau.gd Scripts/Salon.gd Scripts/Manche.gd Scripts/Main.gd Scripts/TransportWebRTC.gd
grep -rn "RichTextLabel\|bbcode" Scripts Scenes
```

Expected (mesuré) : rien pour les trois commandes. **Pas de commit de nettoyage.** Une ligne `seul :` ou un `print` : le retirer dans un commit à part (`Step 0 : code mort retiré`) avant la Task 1.

- [ ] **Step 3 : les références**

```bash
pgrep -f 'godot --headless' || echo "aucun autre godot"
timeout 300 godot --headless --import . > /dev/null 2>&1
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u0.log" 2>&1; grep -E "PROTOCOLE|== " "$TMPDIR/u0.log"; grep -c "✅" "$TMPDIR/u0.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s0.log" 2>&1; grep -E "== " "$TMPDIR/s0.log"; grep -c "✅" "$TMPDIR/s0.log"
ls "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/" | grep web_nothreads
docker image inspect mcr.microsoft.com/playwright:v1.63.0-noble > /dev/null 2>&1 || docker pull -q mcr.microsoft.com/playwright:v1.63.0-noble
```

Expected : « aucun autre godot » (sinon attendre : mêmes ports) ; `PROTOCOLE 0.20 2553814265 (67 lignes)`, `== 0 échec(s) ==`, `531` ✅ ; smoke `== 0 échec(s) ==`, `459` ✅ ; `web_nothreads_debug.zip` et `web_nothreads_release.zip` ; l'image Playwright présente.

---

### Task 1 : le débit des clients chez l'hôte (`LimiteDebit`, les commandes de la manche, les demandes du salon)

**Files:**
- Create: `Scripts/LimiteDebit.gd` (+ `Scripts/LimiteDebit.gd.uid`, créé par l'import)
- Modify: `Scripts/Manche.gd` (`COMMANDES_PAR_TICK`, `RAFALE_COMMANDES`, `_limite_commandes`, `admettre_commandes`, `_recevoir_commandes`, `_sur_depart_reseau`)
- Modify: `Scripts/Reseau.gd` (`DEMANDES_SALON_PAR_SECONDE`, `_limite_salon`, `admettre_demande_salon`, `_demande_couleur`, `_demande_pret`, `quitter`, `_sur_pair_deconnecte`)
- Modify: `tests/unitaires.gd` (`_tester_limites`, `_tester_demandes_salon`, `_poste_client`, `_retirer_poste`)
- Modify: `tests/smoke_test.gd` (`_tester_manche_reseau` : les paquets de Bob)

**Interfaces:**
- `class_name LimiteDebit extends RefCounted` : `const ARRONDI := 1e-6` ; `var debit: float`, `var capacite: float`, `var rejets: Dictionary[int, int]` ; `func _init(jetons_par_unite: float, plein: float)` ; `func admettre(id: int, instant: float) -> bool` ; `func oublier(id: int) -> void` ; `func vider() -> void`.
- `Manche` : `const COMMANDES_PAR_TICK := 2`, `const RAFALE_COMMANDES := 120`, `var _limite_commandes: LimiteDebit`, `func admettre_commandes(id: int) -> bool`.
- `Reseau` : `const DEMANDES_SALON_PAR_SECONDE := 10`, `var _limite_salon: LimiteDebit`, `func admettre_demande_salon(id: int) -> bool`.
- unitaires : `func _poste_client(nom: String) -> Node`, `func _retirer_poste(client: Node) -> void` (attendu).

- [ ] **Step 1 : les tests qui échouent**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	_tester_transport_webrtc()
	_tester_mobile()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

par :

````gdscript
	_tester_transport_webrtc()
	_tester_mobile()
	_tester_limites()
	await _tester_demandes_salon()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript


## Phase 19 (M7 de la revue de la phase 11) : `application/config/version` est aussi la version du
## protocole, présentée à la poignée de main ; deux postes de versions différentes se
````

par :

````gdscript


## Phase 7 du jeu en ligne (spec §8.2) : le débit des demandes d'un client chez l'hôte, un seau de jetons
## par client (`LimiteDebit`) : les paquets de commandes de la manche (2 par tick, 120 par seconde à 60 ticks
## par seconde, 120 d'un coup), les demandes du salon (couleur, Prêt : 10 par seconde).
func _tester_limites() -> void:
	print("-- Limites de débit des clients (phase 7)")
	var reseau: Node = root.get_node("Reseau")  # autoload : jamais nommé
	var script_manche: Script = load("res://Scripts/Manche.gd")
	var constantes: Dictionary = script_manche.get_script_constant_map()
	_check(constantes.COMMANDES_PAR_TICK == 2 and constantes.RAFALE_COMMANDES == 2 * Engine.physics_ticks_per_second
		and reseau.DEMANDES_SALON_PAR_SECONDE == 10,
		"spec §8.2 : 2 paquets de commandes par tick (%d par seconde à l'horloge de l'hôte, autant d'un coup : deux secondes d'un client), 10 demandes de salon par seconde"
			% (2 * Engine.physics_ticks_per_second))
	var tick := 1.0 / 60.0
	var commandes := LimiteDebit.new(120.0, 120.0)
	var admis := 0
	for i in range(130):
		admis += int(commandes.admettre(5, 100.0))
	_check(admis == 120 and commandes.rejets.get(5, 0) == 10 and commandes.admettre(6, 100.0) and not commandes.rejets.has(6),
		"130 paquets d'un coup : 120 passent (le seau plein), 10 sont jetés et comptés ; un autre client a son propre seau (%d)" % admis)
	var un_tick_apres := [commandes.admettre(5, 100.0 + tick), commandes.admettre(5, 100.0 + tick), commandes.admettre(5, 100.0 + tick)]
	_check(un_tick_apres == [true, true, false] and commandes.rejets[5] == 11, "un tick plus tard : deux paquets de plus, pas trois (%s)" % [un_tick_apres])
	var apres_attente := 0
	for i in range(150):
		apres_attente += int(commandes.admettre(5, 5000.0))
	_check(apres_attente == 120, "après une longue attente, le seau n'a jamais plus que son plein (%d)" % apres_attente)
	var recul := [commandes.admettre(6, 50.0), commandes.admettre(5, 4000.0)]
	_check(recul == [true, false], "une horloge qui recule ne remplit rien (%s)" % [recul])
	commandes.oublier(5)
	_check(not commandes.rejets.has(5) and commandes.admettre(5, 5000.0), "un client oublié (parti) repart seau plein, sans rejets")
	var joueur := LimiteDebit.new(120.0, 120.0)
	var inondeur := LimiteDebit.new(120.0, 120.0)
	var jetes := 0
	var passes := 0
	for t in range(600):
		jetes += int(not joueur.admettre(1, t * tick))
		for k in range(10):
			passes += int(inondeur.admettre(1, t * tick))
	for k in range(120):  # l'hôte figé 2 s : les paquets du joueur arrivent d'un coup
		jetes += int(not joueur.admettre(1, 12.0))
	_check(jetes == 0 and passes == 120 + 2 * 599,
		"10 s d'un client qui joue (un paquet par tick), puis l'hôte figé 2 s : aucun paquet jeté ; à dix par tick, deux passent par tick (le plein du début en plus : %d)" % passes)
	var salon := LimiteDebit.new(10.0, 10.0)
	var en_rafale := 0
	for i in range(15):
		en_rafale += int(salon.admettre(9, 3.0))
	var ensuite := [salon.admettre(9, 3.1), salon.admettre(9, 3.1), salon.admettre(9, 3.35), salon.admettre(9, 3.35), salon.admettre(9, 4.4)]
	_check(en_rafale == 10 and ensuite == [true, false, true, true, true] and salon.rejets[9] == 6,
		"salon : 10 demandes d'un coup, puis une par dixième de seconde (%d, %s)" % [en_rafale, ensuite])
	salon.vider()
	_check(salon.rejets.is_empty() and salon.admettre(9, 0.0), "vidé (une session neuve) : plus aucun seau ni rejet")


## Phase 7 du jeu en ligne (spec §8.2) : entre l'autoload, hôte, et un second poste client dans ce même
## processus (comme `_tester_battement`), les demandes de salon d'un client qui inonde l'hôte : au-delà de 10
## par seconde, jetées sans réponse, couleur et Prêt confondus ; une seconde plus tard, ses demandes passent.
func _tester_demandes_salon() -> void:
	print("-- Demandes de salon d'un client (phase 7)")
	var hote: Node = root.get_node("Reseau")  # autoload : jamais nommé
	var client := _poste_client("PosteInondeur")
	var arrives: Array[int] = []
	var sur_arrivee := func(id: int) -> void: arrives.append(id)
	hote.joueur_arrive.connect(sur_arrivee)
	hote.pseudo = "Hôte"
	client.pseudo = "Inondeur"
	_check(hote.heberger(17784) == OK and client.rejoindre("127.0.0.1", 17784) == OK, "(pré-condition) un hôte et un client dans ce processus")
	_check(await _attendre(func() -> bool: return arrives.size() == 1 and client._entendus.has(1), 3.0), "(pré-condition) le client est arrivé")
	var id_client: int = arrives[0] if arrives.size() == 1 else -1
	var changements := [0]
	var compter := func() -> void: changements[0] += 1
	hote.salon_change.connect(compter)
	for i in range(30):
		client._demande_couleur.rpc_id(1, 1)
	client._demande_pret.rpc_id(1, true)
	_check(await _attendre(func() -> bool: return hote._limite_salon.rejets.get(id_client, 0) >= 21, 2.0),
		"(pré-condition) les 31 demandes sont arrivées chez l'hôte")
	await _attendre(func() -> bool: return false, 0.1)
	_check(changements[0] == 10 and hote._limite_salon.rejets.get(id_client, 0) == 21 and not hote.inscrits[id_client].pret,
		"30 demandes de couleur et une de Prêt d'un coup : 10 changements de couleur, 21 demandes jetées, Prêt compris (%d, %d)"
			% [changements[0], hote._limite_salon.rejets.get(id_client, 0)])
	await _attendre(func() -> bool: return false, 0.3)
	client.demander_pret(true)
	_check(await _attendre(func() -> bool: return hote.inscrits.get(id_client, {}).get("pret", false), 1.0),
		"trois dixièmes de seconde plus tard, sa demande passe : il est prêt")
	hote.salon_change.disconnect(compter)
	client.quitter()
	_check(await _attendre(func() -> bool: return not hote.inscrits.has(id_client), 1.0) and not hote._limite_salon.rejets.has(id_client),
		"le client parti, l'hôte oublie son seau et ses rejets")
	hote.joueur_arrive.disconnect(sur_arrivee)
	hote.quitter()
	await _retirer_poste(client)
	hote.pseudo = ""


## Phase 19 (M7 de la revue de la phase 11) : `application/config/version` est aussi la version du
## protocole, présentée à la poignée de main ; deux postes de versions différentes se
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript


## Les fichiers du dossier `dossier` qui finissent par `suffixe`, triés.
func _fichiers_du_dossier(dossier: String, suffixe: String) -> PackedStringArray:
````

par :

````gdscript


## Un second poste dans ce processus (phase 7, comme `_tester_battement`) : un second `Reseau` (le script
## chargé : l'autoload n'est pas nommé) sous sa propre `SceneMultiplayer`, posée par `set_multiplayer` sur un
## nœud à lui, nommé `nom` (le `SceneTree` la relève aussi) ; `_retirer_poste` le défait.
func _poste_client(nom: String) -> Node:
	var noeud := Node.new()
	noeud.name = nom
	root.add_child(noeud)
	set_multiplayer(SceneMultiplayer.new(), noeud.get_path())
	var client: Node = load("res://Scripts/Reseau.gd").new()
	client.name = "Reseau"  # vu de sa propre API, au même chemin que l'autoload : les RPC s'y retrouvent
	noeud.add_child(client)
	return client


## Défait le poste `client` de `_poste_client` : il quitte le réseau, son départ fini, puis son nœud et son
## API partent.
func _retirer_poste(client: Node) -> void:
	client.quitter()
	await _attendre(func() -> bool: return client._partants.is_empty(), 2.0)
	var noeud: Node = client.get_parent()
	var chemin := noeud.get_path()
	noeud.queue_free()
	set_multiplayer(null, chemin)


## Les fichiers du dossier `dossier` qui finissent par `suffixe`, triés.
func _fichiers_du_dossier(dossier: String, suffixe: String) -> PackedStringArray:
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
			and main.lion.commandes.direction() == Vector2.ZERO,
			"un paquet mal formé, non fini ou pour le lion de l'hôte est refusé")
		await _frames(3)
		_check(lion_bob.commandes.numero_applique == 5 and lion_bob.commandes.appliquees == 2 and lion_bob.commandes.direction_voulue == Vector2(0.5, 0.0)
````

par :

````gdscript
			and main.lion.commandes.direction() == Vector2.ZERO,
			"un paquet mal formé, non fini ou pour le lion de l'hôte est refusé")
		# Phase 7 du jeu en ligne (spec §8.2) : l'hôte admet 120 paquets de commandes d'un coup par client, puis
		# deux par tick (120 par seconde, à son horloge) ; il jette le reste
		var d_un_coup := 0
		for i in range(150):
			d_un_coup += int(manche.admettre_commandes(7))
		var apres_rafale := Time.get_ticks_msec()
		while Time.get_ticks_msec() - apres_rafale < 100:  # à l'horloge (un minuteur créé pendant une longue image expire à sa fin)
			await process_frame
		var attendu := int((Time.get_ticks_msec() - apres_rafale) * 0.12)
		var ensuite := 0
		for i in range(40):
			ensuite += int(manche.admettre_commandes(7))
		_check(d_un_coup == manche.RAFALE_COMMANDES and absi(ensuite - attendu) <= 1
			and manche._limite_commandes.rejets[7] == 190 - d_un_coup - ensuite and manche.admettre_commandes(8),
			"150 paquets de commandes de Bob d'un coup : %d passent ; un dixième de seconde plus tard, %d de plus (deux par tick, %d attendus) ; le reste est jeté ; un autre client a son propre compte"
				% [d_un_coup, ensuite, attendu])
		await _frames(3)
		_check(lion_bob.commandes.numero_applique == 5 and lion_bob.commandes.appliquees == 2 and lion_bob.commandes.direction_voulue == Vector2(0.5, 0.0)
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
		_check(manche._partis == [1] and hud.partis == [false, true] and hud.vignettes[1].part.text != "0 %",
			"le HUD grise Bob, parti, avec sa part des cellules peintes (%s) ; la manche annonce son départ" % hud.vignettes[1].part.text)
		# I2 (revue finale phase 17) : un tampon et une case de territoire tout juste peints, encore en
		# attente (aucune image écoulée depuis pour les diffuser normalement), doivent partir avec la fin,
````

par :

````gdscript
		_check(manche._partis == [1] and hud.partis == [false, true] and hud.vignettes[1].part.text != "0 %",
			"le HUD grise Bob, parti, avec sa part des cellules peintes (%s) ; la manche annonce son départ" % hud.vignettes[1].part.text)
		_check(not manche._limite_commandes.rejets.has(7), "phase 7 : Bob parti, la manche oublie le compte de ses paquets")
		# I2 (revue finale phase 17) : un tampon et une case de territoire tout juste peints, encore en
		# attente (aucune image écoulée depuis pour les diffuser normalement), doivent partir avec la fin,
````

- [ ] **Step 2 : ils échouent**

```bash
pgrep -f 'godot --headless' || echo "aucun autre godot"
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u1.log" 2>&1; echo "unitaires $?"; grep -E "SCRIPT ERROR|Parse Error|== " "$TMPDIR/u1.log" | head -5
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s1.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s1.log" | head -5
```

Expected : `unitaires 0` mais aucun ✅ : `SCRIPT ERROR: Parse Error: Identifier "LimiteDebit" not declared in the current scope.` (la suite ne se compile pas, elle sort en 0 sans rien vérifier : la CI échoue sur cette ligne) ; `smoke 1`, `SCRIPT ERROR: Invalid call. Nonexistent function 'admettre_commandes' in base 'Node (Manche.gd)'.`, puis la scène de jeu jamais libérée par le test interrompu fait aussi échouer « ❌ Revanche : la manche se relance … » et « ❌ les scènes de jeu fermées et le salon ne laissent aucune connexion aux autoloads » : `== 2 échec(s) ==`.

- [ ] **Step 3 : `LimiteDebit`, les commandes et les demandes du salon**

Créer `Scripts/LimiteDebit.gd` :

````gdscript
class_name LimiteDebit
extends RefCounted
## Le débit des demandes d'un client, chez l'hôte (spec §8.2 du jeu en ligne) : un seau de jetons par
## émetteur, rempli de `debit` jetons par unité de temps, `capacite` au plus (la rafale admise d'un coup) ;
## une demande prend un jeton, ou elle est jetée, comptée dans `rejets`, quand le seau est vide. L'unité
## de temps est celle des instants donnés à `admettre` : des secondes, à l'horloge de l'hôte, pour les
## paquets de commandes de la manche (`Manche`, 120 par seconde) comme pour les demandes du salon (`Reseau`,
## 10 par seconde). Logique pure, sans autoload.

## L'écart d'arrondi toléré sur un jeton.
const ARRONDI := 1e-6

## Jetons par unité de temps, et le plein du seau.
var debit: float
var capacite: float
## Par émetteur : ses demandes jetées, depuis sa première demande (ou depuis `oublier`).
var rejets: Dictionary[int, int] = {}
## Par émetteur : ses jetons, et l'instant de sa dernière demande.
var _jetons: Dictionary[int, float] = {}
var _instants: Dictionary[int, float] = {}


func _init(jetons_par_unite: float, plein: float) -> void:
	debit = jetons_par_unite
	capacite = plein


## Vrai si la demande de `id` à `instant` passe (elle prend un jeton) ; faux si son seau est vide (la
## demande est jetée, comptée dans `rejets`). Un émetteur neuf commence seau plein ; un instant antérieur
## au précédent (une horloge qui recule) ne remplit rien. Un jeton revenu à l'instant même compte, à
## l'arrondi près (ARRONDI : 1/60 s à 120 jetons par seconde font 1,99999… jetons).
func admettre(id: int, instant: float) -> bool:
	var jetons := capacite
	if _jetons.has(id):
		jetons = minf(capacite, _jetons[id] + maxf(0.0, instant - _instants[id]) * debit)
		instant = maxf(instant, _instants[id])
	_instants[id] = instant
	if jetons < 1.0 - ARRONDI:
		_jetons[id] = jetons
		rejets[id] = rejets.get(id, 0) + 1
		return false
	_jetons[id] = maxf(0.0, jetons - 1.0)
	return true


## Oublie l'émetteur `id` (parti) : son seau et ses rejets.
func oublier(id: int) -> void:
	_jetons.erase(id)
	_instants.erase(id)
	rejets.erase(id)


## Oublie tous les émetteurs (une session neuve).
func vider() -> void:
	_jetons.clear()
	_instants.clear()
	rejets.clear()
````

Dans `Scripts/Manche.gd`, remplacer :

````gdscript
##   le désordre le couvrent. Il remet le lion au repos après SILENCE_COMMANDES de temps de jeu sans
##   paquet (pas l'horloge murale, M4 de la revue finale : un rattrapage de ticks physiques après un
##   gel de l'hôte ne doit pas se lire comme un silence).
## - Tampons : chaque tampon de la ville de l'hôte (`Ville.tampon_peint`) est diffusé, regroupé par
##   tick physique, sur le canal fiable 1 (`Peinture.encoder_tampons`) ; un client le dessine
````

par :

````gdscript
##   le désordre le couvrent. Il remet le lion au repos après SILENCE_COMMANDES de temps de jeu sans
##   paquet (pas l'horloge murale, M4 de la revue finale : un rattrapage de ticks physiques après un
##   gel de l'hôte ne doit pas se lire comme un silence). Il admet COMMANDES_PAR_TICK paquets par tick
##   et par client (spec §8.2 du jeu en ligne) et jette le reste (`admettre_commandes`).
## - Tampons : chaque tampon de la ville de l'hôte (`Ville.tampon_peint`) est diffusé, regroupé par
##   tick physique, sur le canal fiable 1 (`Peinture.encoder_tampons`) ; un client le dessine
````

Dans `Scripts/Manche.gd`, remplacer :

````gdscript
## Canal ENet des tampons et du territoire (spec §4 : canal 1, fiable ordonné).
const CANAL_PEINTURE := 1

## Délai de la barrière de chargement de la prochaine manche : DELAI_CHARGEMENT, réglable par les
````

par :

````gdscript
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
````

Dans `Scripts/Manche.gd`, remplacer :

````gdscript
## Hôte : par index de joueur, l'instant (ms de temps de jeu) du dernier paquet de commandes reçu.
var _recues: Dictionary[int, int] = {}
## Hôte : les clients dont la scène est chargée, destinataires de tout ce que diffuse la manche.
var _prets: Array[int] = []
````

par :

````gdscript
## Hôte : par index de joueur, l'instant (ms de temps de jeu) du dernier paquet de commandes reçu.
var _recues: Dictionary[int, int] = {}
## Hôte : le débit des paquets de commandes de chaque client (COMMANDES_PAR_TICK par tick), en secondes.
var _limite_commandes := LimiteDebit.new(COMMANDES_PAR_TICK * Engine.physics_ticks_per_second, RAFALE_COMMANDES)
## Hôte : les clients dont la scène est chargée, destinataires de tout ce que diffuse la manche.
var _prets: Array[int] = []
````

Dans `Scripts/Manche.gd`, remplacer :

````gdscript
		return
	var id := multiplayer.get_remote_sender_id()
	for j in GameState.joueurs:
		if j.id_reseau == id:
			recevoir_paquet_de(j.index, octets, int(_temps_manche * 1000.0))
			return


````

par :

````gdscript
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


````

Dans `Scripts/Manche.gd`, remplacer :

````gdscript
func _sur_depart_reseau(id: int) -> void:
	_prets.erase(id)
	for j in GameState.joueurs:
		if j.id_reseau == id:
````

par :

````gdscript
func _sur_depart_reseau(id: int) -> void:
	_prets.erase(id)
	_limite_commandes.oublier(id)
	for j in GameState.joueurs:
		if j.id_reseau == id:
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Salon : l'hôte tient la table dans `inscrits` et la diffuse, arrivés seulement, à chaque
## changement (`_recevoir_salon`, fiable) ; chaque poste la lit dans `table_salon`. Les clients
## demandent (couleur, Prêt) et l'hôte arbitre. Tous ces RPC passent par cet autoload, présent au
## même chemin sur chaque poste dès la connexion : une table envoyée avant que la scène du salon
## soit chargée chez un client l'y attend. Les RPC de l'hôte sont en mode "authority" (le moteur
````

par :

````gdscript
## Salon : l'hôte tient la table dans `inscrits` et la diffuse, arrivés seulement, à chaque
## changement (`_recevoir_salon`, fiable) ; chaque poste la lit dans `table_salon`. Les clients
## demandent (couleur, Prêt) et l'hôte arbitre, DEMANDES_SALON_PAR_SECONDE demandes par seconde et par
## client au plus (spec §8.2 : au-delà, il les jette). Tous ces RPC passent par cet autoload, présent au
## même chemin sur chaque poste dès la connexion : une table envoyée avant que la scène du salon
## soit chargée chez un client l'y attend. Les RPC de l'hôte sont en mode "authority" (le moteur
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## (`Manche.CANAL_PEINTURE`, spec §4), phase 18.
const CANAL_ORDONNE := 1

## Ce que `_poser_salon` fait d'une table reçue de l'hôte (M6) : posée, plus ancienne que la dernière
````

par :

````gdscript
## (`Manche.CANAL_PEINTURE`, spec §4), phase 18.
const CANAL_ORDONNE := 1
## Demandes de salon (couleur, Prêt) admises par seconde et par client, chez l'hôte (spec §8.2) : au-delà,
## il les jette (`LimiteDebit`, un seau de 10 jetons rempli de 10 par seconde). Un joueur n'en fait jamais
## autant : le salon n'agit qu'à l'appui d'une touche, d'un bouton ou du stick.
const DEMANDES_SALON_PAR_SECONDE := 10

## Ce que `_poser_salon` fait d'une table reçue de l'hôte (M6) : posée, plus ancienne que la dernière
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## L'instant (ms) de la dernière écoute des silences (`_ecouter`) : celui du verdict de la suivante.
var _derniere_ecoute := 0


````

par :

````gdscript
## L'instant (ms) de la dernière écoute des silences (`_ecouter`) : celui du verdict de la suivante.
var _derniere_ecoute := 0
## Chez l'hôte : le débit des demandes de salon de chaque client (DEMANDES_SALON_PAR_SECONDE), en secondes.
var _limite_salon := LimiteDebit.new(DEMANDES_SALON_PAR_SECONDE, DEMANDES_SALON_PAR_SECONDE)


````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
	silence = SILENCE_SESSION
	_entendus.clear()
	code_partie = ""
	raison_salle_fermee = ""
````

par :

````gdscript
	silence = SILENCE_SESSION
	_entendus.clear()
	_limite_salon.vider()
	code_partie = ""
	raison_salle_fermee = ""
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
@rpc("any_peer", "call_remote", "reliable")
func _demande_couleur(sens: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	if sens is int:
		changer_couleur(multiplayer.get_remote_sender_id(), sens)


## Chez l'hôte : un client demande à être prêt, ou plus.
@rpc("any_peer", "call_remote", "reliable")
func _demande_pret(pret: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	if pret is bool:
		definir_pret(multiplayer.get_remote_sender_id(), pret)


````

par :

````gdscript
@rpc("any_peer", "call_remote", "reliable")
func _demande_couleur(sens: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	_entendre(id)
	if admettre_demande_salon(id) and sens is int:
		changer_couleur(id, sens)


## Chez l'hôte : un client demande à être prêt, ou plus.
@rpc("any_peer", "call_remote", "reliable")
func _demande_pret(pret: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	_entendre(id)
	if admettre_demande_salon(id) and pret is bool:
		definir_pret(id, pret)


## Chez l'hôte : vrai si la demande de salon du client `id` passe (DEMANDES_SALON_PAR_SECONDE par seconde
## au plus, spec §8.2), mal formée ou non ; au-delà, elle est jetée sans réponse (un avertissement au
## premier rejet de ce client, pas à chacun : un client qui inonde l'hôte n'inonde pas son journal).
func admettre_demande_salon(id: int) -> bool:
	if _limite_salon.admettre(id, Time.get_ticks_msec() / 1000.0):
		return true
	if _limite_salon.rejets[id] == 1:
		push_warning("Reseau : le client %d fait plus de %d demandes de salon par seconde, l'excédent est jeté" % [id, DEMANDES_SALON_PAR_SECONDE])
	return false


````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
func _sur_pair_deconnecte(id: int) -> void:
	_entendus.erase(id)
	if multiplayer.is_server() and inscrits.erase(id):
		_diffuser_salon()
````

par :

````gdscript
func _sur_pair_deconnecte(id: int) -> void:
	_entendus.erase(id)
	_limite_salon.oublier(id)
	if multiplayer.is_server() and inscrits.erase(id):
		_diffuser_salon()
````

- [ ] **Step 4 : l'import, puis les tests passent**

```bash
timeout 300 godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; ls Scripts/LimiteDebit.gd.uid
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u1.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u1.log"; grep -c "✅" "$TMPDIR/u1.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s1.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s1.log"; grep -c "✅" "$TMPDIR/s1.log"
```

Expected : rien à l'import, `Scripts/LimiteDebit.gd.uid` créé ; unitaires `0`, `PROTOCOLE 0.20 2553814265 (67 lignes)` (rien de ce que deux postes se disent n'a changé), `== 0 échec(s) ==`, 546 ✅ ; smoke `0`, `== 0 échec(s) ==`, 461 ✅. Dans la sortie des unitaires, une fois : `WARNING: Reseau : le client … fait plus de 10 demandes de salon par seconde, l'excédent est jeté` (voulu).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/LimiteDebit.gd Scripts/LimiteDebit.gd.uid Scripts/Manche.gd Scripts/Reseau.gd tests/unitaires.gd tests/smoke_test.gd
git commit -m "Sécurité : le débit des clients chez l'hôte, un seau de jetons par client à son horloge (2 paquets de commandes par tick, 120 d'un coup ; 10 demandes de salon par seconde), l'excédent jeté et compté

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 2 : l'exclusion par l'hôte (l'annonce et sa raison, version 0.21)

**Files:**
- Modify: `Scripts/Reseau.gd` (`PERTE_EXCLU_HOTE`, `DELAI_EXCLUSION_SALON`, `_exclusion` à la place de `_exclu`, `exclure(id, par_l_hote)`, `exclure_du_salon`, `_recevoir_exclusion(par_l_hote)`, `_fermer_puis_emettre`)
- Modify: `project.godot` (`config/version="0.21"`)
- Modify: `Assets/Traductions/traductions.csv` (`RESEAU_EXCLU_HOTE`) (+ les deux `.translation`, régénérés par l'import)
- Modify: `tests/unitaires.gd` (`_tester_reseau_manche`, `_tester_exclusion`, `PROTOCOLE_VERSION`, `PROTOCOLE_EMPREINTE`)

**Interfaces:**
- `Reseau` : `const PERTE_EXCLU_HOTE := "RESEAU_EXCLU_HOTE"`, `const DELAI_EXCLUSION_SALON := 2.0` ; `func exclure(id: int, par_l_hote := false) -> void` (la barrière l'appelle sans le second argument, inchangée) ; `func exclure_du_salon(id: int) -> bool` ; RPC `_recevoir_exclusion(par_l_hote: Variant)` (`authority`, `reliable`) ; `var _exclusion := ""` (PERTE_EXCLU ou PERTE_EXCLU_HOTE).

- [ ] **Step 1 : les tests qui échouent**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
var _echecs := 0
## La version du protocole et son empreinte, mesurées (`_tester_protocole`).
const PROTOCOLE_VERSION := "0.20"
const PROTOCOLE_EMPREINTE := 2553814265


````

par :

````gdscript
var _echecs := 0
## La version du protocole et son empreinte, mesurées (`_tester_protocole`).
const PROTOCOLE_VERSION := "0.21"
const PROTOCOLE_EMPREINTE := 1188810746


````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	_tester_limites()
	await _tester_demandes_salon()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

par :

````gdscript
	_tester_limites()
	await _tester_demandes_salon()
	await _tester_exclusion()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	var sur_perte := func() -> void: raisons.append(reseau.raison_perte)
	reseau.hote_perdu.connect(sur_perte)
	reseau._recevoir_exclusion()
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau.hote_perdu.disconnect(sur_perte)
	_check(raisons == [reseau.PERTE_EXCLU, reseau.PERTE_HOTE] and not reseau._exclu,
		"l'hôte perdu après une exclusion : « exclu » ; la perte suivante, de nouveau « l'hôte a quitté la partie » (%s)" % [raisons])
	_check(reseau.heberger(17788) == OK, "(pré-condition) l'hôte écoute de nouveau")
	reseau.definir_silence(reseau.SILENCE_SESSION)
````

par :

````gdscript
	var sur_perte := func() -> void: raisons.append(reseau.raison_perte)
	reseau.hote_perdu.connect(sur_perte)
	reseau._recevoir_exclusion(false)
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau._recevoir_exclusion(true)
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau._recevoir_exclusion("oui")
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau.hote_perdu.disconnect(sur_perte)
	_check(raisons == [reseau.PERTE_EXCLU, reseau.PERTE_HOTE, reseau.PERTE_EXCLU_HOTE, reseau.PERTE_EXCLU] and reseau._exclusion.is_empty(),
		"l'hôte perdu après une exclusion : « exclu » ; la perte suivante, de nouveau « l'hôte a quitté la partie » ; phase 7 : exclu du salon par l'hôte, « L'hôte t'a exclu de la partie. » ; une annonce illisible, l'exclusion de la barrière (%s)" % [raisons])
	_check(reseau.heberger(17788) == OK, "(pré-condition) l'hôte écoute de nouveau")
	reseau.definir_silence(reseau.SILENCE_SESSION)
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
		"le client parti, l'hôte oublie son seau et ses rejets")
	hote.joueur_arrive.disconnect(sur_arrivee)
	hote.quitter()
	await _retirer_poste(client)
````

par :

````gdscript
		"le client parti, l'hôte oublie son seau et ses rejets")
	hote.joueur_arrive.disconnect(sur_arrivee)
	hote.quitter()
	await _retirer_poste(client)
	hote.pseudo = ""


## Phase 7 du jeu en ligne (spec §8.2) : l'hôte exclut un joueur du salon (la croix de sa carte), entre
## l'autoload, hôte, et un second poste client dans ce même processus : l'exclu lit « L'hôte t'a exclu de la
## partie. » et s'en va de lui-même ; il revient avec le code, en nouvel arrivant, et l'hôte l'exclut de
## nouveau ; un exclu qui ne s'en va pas est libéré par l'hôte DELAI_EXCLUSION_SALON plus tard.
func _tester_exclusion() -> void:
	print("-- Exclusion par l'hôte (phase 7)")
	var hote: Node = root.get_node("Reseau")  # autoload : jamais nommé
	var client := _poste_client("PosteExclu")
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
	client.pseudo = "Gêneur"
	var port := 17783
	_check(hote.heberger(port) == OK and client.rejoindre("127.0.0.1", port) == OK, "(pré-condition) un hôte et un client dans ce processus")
	_check(await _attendre(func() -> bool: return arrives.size() == 1 and client._entendus.has(1), 3.0), "(pré-condition) le client est arrivé")
	var id: int = arrives[0] if arrives.size() == 1 else -1
	_check(not hote.exclure_du_salon(1) and not hote.exclure_du_salon(4242) and not client.exclure_du_salon(1),
		"refusée : l'hôte ne s'exclut pas lui-même, ni un inconnu ; un client n'exclut personne")
	hote.manche_en_cours = true
	var en_manche: bool = hote.exclure_du_salon(id)
	hote.manche_en_cours = false
	hote.inscrits[id].arrive = false
	var reservee: bool = hote.exclure_du_salon(id)
	hote.inscrits[id].arrive = true
	await _attendre(func() -> bool: return false, 0.3)
	_check(not en_manche and not reservee and pertes.is_empty() and client.en_ligne(),
		"refusée pendant une manche (seul le salon a la croix), et pour une place seulement réservée (pas de carte)")
	var exclu_a := Time.get_ticks_msec()
	_check(hote.exclure_du_salon(id), "l'hôte exclut le client du salon")
	var parti := await _attendre(func() -> bool: return pertes.size() == 1 and partis.size() == 1, 1.5)
	var apres := Time.get_ticks_msec() - exclu_a
	_check(parti and pertes == [client.PERTE_EXCLU_HOTE] and partis == [id] and not client.en_ligne() and not hote.inscrits.has(id)
		and apres < int(hote.DELAI_EXCLUSION_SALON * 1000.0),
		"l'exclu lit « L'hôte t'a exclu de la partie. » et s'en va de lui-même, en %d ms (avant le secours de l'hôte, %.0f s) ; sa place se libère"
			% [apres, hote.DELAI_EXCLUSION_SALON])
	# Sans compte, rien ne le retient : il revient avec le code, en nouvel arrivant, que l'hôte exclut de nouveau
	_check(client.rejoindre("127.0.0.1", port) == OK and await _attendre(func() -> bool: return arrives.size() == 2, 3.0) and arrives[1] != id,
		"l'exclu revient avec le code : accepté, en nouvel arrivant (un autre identifiant)")
	_check(arrives.size() == 2 and hote.exclure_du_salon(arrives[1])
		and await _attendre(func() -> bool: return pertes.size() == 2 and partis.size() == 2, 1.5) and pertes[1] == client.PERTE_EXCLU_HOTE,
		"... et l'hôte l'exclut de nouveau : « L'hôte t'a exclu de la partie. »")
	# Un exclu qui ne s'en va pas (figé, ou qui ignore l'annonce) : l'hôte le libère au bout de son délai
	_check(client.rejoindre("127.0.0.1", port) == OK and await _attendre(func() -> bool: return arrives.size() == 3, 3.0),
		"(pré-condition) il revient une troisième fois")
	client._issue_decidee = true  # ce poste n'agira pas sur l'annonce
	exclu_a = Time.get_ticks_msec()
	_check(arrives.size() == 3 and hote.exclure_du_salon(arrives[2]), "(pré-condition) l'hôte l'exclut encore")
	parti = await _attendre(func() -> bool: return partis.size() == 3, hote.DELAI_EXCLUSION_SALON + 2.0)
	apres = Time.get_ticks_msec() - exclu_a
	_check(parti and apres >= int(hote.DELAI_EXCLUSION_SALON * 1000.0) - 50 and apres <= int(hote.DELAI_EXCLUSION_SALON * 1000.0) + 1000,
		"un exclu qui ne s'en va pas : l'hôte le libère au bout de %d ms (son délai de secours : %.0f s)" % [apres, hote.DELAI_EXCLUSION_SALON])
	client._issue_decidee = false
	hote.joueur_arrive.disconnect(sur_arrivee)
	hote.joueur_parti.disconnect(sur_depart)
	client.hote_perdu.disconnect(sur_perte)
	hote.quitter()
	await _retirer_poste(client)
````

- [ ] **Step 2 : ils échouent**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u2.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u2.log" | head -8
```

Expected : `unitaires 1`, `SCRIPT ERROR: Invalid call to function '_recevoir_exclusion' in base 'Node (Reseau.gd)'. Expected 0 argument(s).` (`_tester_reseau_manche`), `SCRIPT ERROR: Invalid call. Nonexistent function 'exclure_du_salon' in base 'Node (Reseau.gd)'.` (`_tester_exclusion`), `PROTOCOLE 0.20 2553814265 (67 lignes)`, `❌ la version (0.20) n'est plus celle que note ce test (0.21) : …`, `== 1 échec(s) ==`.

- [ ] **Step 3 : l'exclusion**

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## SILENCE_CHARGEMENT pendant le chargement de la manche (un poste qui charge sa scène ou compile ses
## shaders ne répond plus). Chez l'hôte, un client parti, muet ou exclu est libéré (`_liberer`, puis
## `Transport.liberer`) : son départ arrive par `peer_disconnected`, comme tous les départs.
## `quitter()` part proprement (spec §5) : un adieu fiable (`_recevoir_adieu`), que l'autre côté traite
## aussitôt (l'hôte libère ce client, un client perd l'hôte), puis le transport ferme sa session une fois
````

par :

````gdscript
## SILENCE_CHARGEMENT pendant le chargement de la manche (un poste qui charge sa scène ou compile ses
## shaders ne répond plus). Chez l'hôte, un client parti, muet ou exclu est libéré (`_liberer`, puis
## `Transport.liberer`) : son départ arrive par `peer_disconnected`, comme tous les départs. L'hôte
## exclut un joueur du salon (phase 7 du jeu en ligne, spec §8.2 : `exclure_du_salon`, la croix de sa
## carte) comme la barrière de chargement exclut un absent (`exclure`) : l'exclu l'apprend, part de
## lui-même, et l'hôte le libère au plus tard peu après.
## `quitter()` part proprement (spec §5) : un adieu fiable (`_recevoir_adieu`), que l'autre côté traite
## aussitôt (l'hôte libère ce client, un client perd l'hôte), puis le transport ferme sa session une fois
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
const REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"
## Pourquoi l'hôte est perdu (`raison_perte`), en clés de traduction : il est parti (ou ne répond
## plus), ou il a exclu ce poste (barrière de chargement, phase 18).
const PERTE_HOTE := "RESEAU_HOTE_PERDU"
const PERTE_EXCLU := "RESEAU_EXCLU"
## Entre l'annonce de son exclusion à un joueur et sa libération par l'hôte, en secondes : le temps que
## l'annonce arrive (renvoyée au besoin), et que l'exclu s'en aille de lui-même.
const DELAI_EXCLUSION := 0.5
## Pourquoi l'hôte ne peut pas encore démarrer la partie (`raison_attente`), en clés de traduction.
const ATTENTE_JOUEURS := "SALON_ATTENTE_JOUEURS"
````

par :

````gdscript
const REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"
## Pourquoi l'hôte est perdu (`raison_perte`), en clés de traduction : il est parti (ou ne répond
## plus), il a exclu ce poste de la manche (la barrière de chargement, phase 18), ou du salon (phase 7 du
## jeu en ligne : « L'hôte t'a exclu de la partie. »).
const PERTE_HOTE := "RESEAU_HOTE_PERDU"
const PERTE_EXCLU := "RESEAU_EXCLU"
const PERTE_EXCLU_HOTE := "RESEAU_EXCLU_HOTE"
## Entre l'annonce de son exclusion à un joueur et sa libération par l'hôte, en secondes : le temps que
## l'annonce arrive (renvoyée au besoin), et que l'exclu s'en aille de lui-même. À la barrière de
## chargement, la manche attend ce départ ; au salon, rien ne l'attend : le délai y est plus long, pour
## qu'une annonce retardée (une 4G qui la renvoie) arrive avant la fermeture, qui dirait sinon « L'hôte a
## quitté la partie ».
const DELAI_EXCLUSION := 0.5
const DELAI_EXCLUSION_SALON := 2.0
## Pourquoi l'hôte ne peut pas encore démarrer la partie (`raison_attente`), en clés de traduction.
const ATTENTE_JOUEURS := "SALON_ATTENTE_JOUEURS"
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## suivant ; remis à 0 par `quitter()`.
var niveau_manche := 0
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE ou PERTE_EXCLU), posé juste
## avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Chez un client, ou chez l'hôte dont la partie n'a pas pu être créée : pourquoi la dernière connexion a
````

par :

````gdscript
## suivant ; remis à 0 par `quitter()`.
var niveau_manche := 0
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE, PERTE_EXCLU ou
## PERTE_EXCLU_HOTE), posé juste avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Chez un client, ou chez l'hôte dont la partie n'a pas pu être créée : pourquoi la dernière connexion a
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## connexion : la partie n'a jamais existé.
var _creation_en_cours := false
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
var _exclu := false
## Chez un client : la raison de l'échec du transport de la session (`Transport.echec`), jusqu'à l'échec
## de connexion qui suit (`raison_echec`).
````

par :

````gdscript
## connexion : la partie n'a jamais existé.
var _creation_en_cours := false
## Chez un client : la raison de son exclusion annoncée par l'hôte (`_recevoir_exclusion` : PERTE_EXCLU ou
## PERTE_EXCLU_HOTE), jusqu'à la perte de l'hôte qui suit ; vide sinon.
var _exclusion := ""
## Chez un client : la raison de l'échec du transport de la session (`Transport.echec`), jusqu'à l'échec
## de connexion qui suit (`raison_echec`).
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
	numero_table = 0
	niveau_manche = 0
	_exclu = false
	index_local = -1
	couleur_locale = Color.TRANSPARENT
````

par :

````gdscript
	numero_table = 0
	niveau_manche = 0
	_exclusion = ""
	index_local = -1
	couleur_locale = Color.TRANSPARENT
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript


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


````

par :

````gdscript


## Chez l'hôte : exclut le joueur `id`, qui n'a pas chargé sa scène de jeu à temps (la barrière de la
## manche, `Manche._exclure`), ou que l'hôte exclut du salon (`par_l_hote`, `exclure_du_salon`) : il apprend
## son exclusion (`_recevoir_exclusion` : il verra PERTE_EXCLU ou PERTE_EXCLU_HOTE, pas « L'hôte a quitté la
## partie ») et s'en va de lui-même ; DELAI_EXCLUSION (DELAI_EXCLUSION_SALON) plus tard, l'hôte le libère
## s'il est encore là (`_liberer` : figé, il n'a pas lu l'annonce) : son départ arrive par
## `joueur_parti`.
func exclure(id: int, par_l_hote := false) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	_recevoir_exclusion.rpc_id(id, par_l_hote)
	var delai := DELAI_EXCLUSION_SALON if par_l_hote else DELAI_EXCLUSION
	get_tree().create_timer(delai, true).timeout.connect(_liberer.bind(id, _generation))


## Chez l'hôte, depuis le salon (la croix de sa carte, spec §8.2) : exclut le joueur arrivé `id`, qui lit
## « L'hôte t'a exclu de la partie. » et s'en va (`exclure`). Faux, sans rien faire, chez un client, pendant
## une manche, pour l'hôte lui-même, un inconnu ou une place seulement réservée (pas de carte). Sans compte,
## rien n'identifie durablement un joueur (spec §13) : un exclu peut revenir avec le code, en nouvel
## arrivant, et l'hôte l'exclut de nouveau.
func exclure_du_salon(id: int) -> bool:
	var fiche: Dictionary = inscrits.get(id, {})
	if not multiplayer.is_server() or manche_en_cours or id == multiplayer.get_unique_id() or fiche.is_empty() \
			or not fiche.arrive or not multiplayer.get_peers().has(id):
		return false
	exclure(id, true)
	return true


````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript


## Chez un client : l'hôte l'exclut de la manche (sa scène de jeu pas chargée à temps) ; ce poste s'en va
## aussitôt, et la perte de l'hôte le dit (`raison_perte` : PERTE_EXCLU). L'annonce est fiable, la
## libération par l'hôte qui suit ne l'est pas (`_liberer`).
@rpc("authority", "call_remote", "reliable")
func _recevoir_exclusion() -> void:
	_entendre(multiplayer.get_remote_sender_id())
	_exclu = true
	_decider("hote_perdu")

````

par :

````gdscript


## Chez un client : l'hôte l'exclut de la manche (sa scène de jeu pas chargée à temps), ou du salon
## (`par_l_hote` vrai) ; ce poste s'en va aussitôt, et la perte de l'hôte le dit (`raison_perte` :
## PERTE_EXCLU, ou PERTE_EXCLU_HOTE). L'annonce est fiable, la libération par l'hôte qui suit ne l'est pas
## (`_liberer`).
@rpc("authority", "call_remote", "reliable")
func _recevoir_exclusion(par_l_hote: Variant) -> void:
	_entendre(multiplayer.get_remote_sender_id())
	_exclusion = PERTE_EXCLU_HOTE if par_l_hote is bool and par_l_hote else PERTE_EXCLU
	_decider("hote_perdu")

````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
	if generation != _generation:
		return
	var exclu := _exclu
	var raison_transport := _raison_transport
	quitter()
	if nom == &"hote_perdu":
		raison_perte = PERTE_EXCLU if exclu else PERTE_HOTE
	elif nom == &"connexion_echouee":
		raison_echec = raison_transport
````

par :

````gdscript
	if generation != _generation:
		return
	var exclusion := _exclusion
	var raison_transport := _raison_transport
	quitter()
	if nom == &"hote_perdu":
		raison_perte = exclusion if not exclusion.is_empty() else PERTE_HOTE
	elif nom == &"connexion_echouee":
		raison_echec = raison_transport
````

Dans `project.godot`, remplacer :

````ini

config/name="LeLion"
config/version="0.20"
run/main_scene="res://Scenes/Titre.tscn"
config/features=PackedStringArray("4.7", "Mobile")
````

par :

````ini

config/name="LeLion"
config/version="0.21"
run/main_scene="res://Scenes/Titre.tscn"
config/features=PackedStringArray("4.7", "Mobile")
````

Dans `Assets/Traductions/traductions.csv`, remplacer :

````csv
RESEAU_HOTE_PERDU,L'hôte a quitté la partie,The host left the game
RESEAU_EXCLU,"Exclu : ta partie a mis trop de temps à charger.","Removed: your game took too long to load."
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
RESEAU_HEBERGER_IMPOSSIBLE,Impossible d'héberger (erreur %d),Can't host (error %d)
````

par :

````csv
RESEAU_HOTE_PERDU,L'hôte a quitté la partie,The host left the game
RESEAU_EXCLU,"Exclu : ta partie a mis trop de temps à charger.","Removed: your game took too long to load."
RESEAU_EXCLU_HOTE,"L'hôte t'a exclu de la partie.","The host removed you from the game."
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
RESEAU_HEBERGER_IMPOSSIBLE,Impossible d'héberger (erreur %d),Can't host (error %d)
````

- [ ] **Step 4 : l'import, puis les tests passent**

```bash
timeout 300 godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; git status --short Assets/Traductions
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u2.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u2.log"; grep -c "✅" "$TMPDIR/u2.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s2.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s2.log"; grep -c "✅" "$TMPDIR/s2.log"
```

Expected : rien à l'import ; le CSV et les deux `.translation` modifiés ; unitaires `0`, `PROTOCOLE 0.21 1188810746 (67 lignes)`, `== 0 échec(s) ==`, 557 ✅ (dont « l'exclu lit « L'hôte t'a exclu de la partie. » et s'en va de lui-même, en … ms » : 19 ms mesurés, et « un exclu qui ne s'en va pas : l'hôte le libère au bout de … ms » : 2002 ms) ; smoke `0`, `== 0 échec(s) ==`, 461 ✅ (la barrière exclut comme avant).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Reseau.gd project.godot Assets/Traductions/traductions.csv Assets/Traductions/traductions.fr.translation Assets/Traductions/traductions.en.translation tests/unitaires.gd
git commit -m "Sécurité : l'hôte exclut un joueur du salon (« L'hôte t'a exclu de la partie. ») ; l'exclu part de lui-même, l'hôte le libère au plus tard 2 s plus tard ; l'annonce porte sa raison : version 0.21

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 3 : « Tu as été déconnecté » (le retour d'un gel)

**Files:**
- Modify: `Scripts/Reseau.gd` (`PERTE_DECONNECTE`, `RETOUR_DE_GEL`, `_derniere_image`, `_fin_du_gel`, `_perte_apres_gel`, `_process`, `au_retour_d_un_gel`, `_decider`, `_fermer_puis_emettre`, `quitter`)
- Modify: `Scripts/Main.gd` (`SCENE_EN_LIGNE`, `_EcranEnLigne`, `_apres_la_perte`)
- Modify: `Assets/Traductions/traductions.csv` (`RESEAU_DECONNECTE`) (+ `.translation`)
- Modify: `tests/unitaires.gd` (`_tester_retour_de_gel`)
- Modify: `tests/smoke_test.gd` (`_tester_manche_reseau` : le retour d'un gel depuis une manche)

**Interfaces:**
- `Reseau` : `const PERTE_DECONNECTE := "RESEAU_DECONNECTE"`, `const RETOUR_DE_GEL := 2.0` ; `func au_retour_d_un_gel(maintenant: int) -> bool` ; `var _derniere_image := 0`, `var _fin_du_gel := 0`, `var _perte_apres_gel := false`.
- `Main` : `func _apres_la_perte(raison: String) -> void` (le minuteur de la perte de l'hôte, à la place de `_revenir_au_titre`).

- [ ] **Step 1 : les tests qui échouent**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	await _tester_demandes_salon()
	await _tester_exclusion()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

par :

````gdscript
	await _tester_demandes_salon()
	await _tester_exclusion()
	await _tester_retour_de_gel()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript


## Phase 19 (M7 de la revue de la phase 11) : `application/config/version` est aussi la version du
## protocole, présentée à la poignée de main ; deux postes de versions différentes se
````

par :

````gdscript


## Phase 7 du jeu en ligne (spec §5 et §9) : un poste qui gèle plus longtemps que le silence toléré (un
## onglet caché, un téléphone verrouillé : plus aucune image) a été déclaré parti par l'hôte ; la perte de
## l'hôte qu'il constate à son retour dit « Tu as été déconnecté », pas « L'hôte a quitté la partie ». D'abord
## la règle, puis entre l'autoload, hôte, et un second poste client dans ce même processus : le client se tait
## (`set_process(false)` : plus d'image ni de battement ; sa `SceneMultiplayer` relève encore ses paquets,
## comme le navigateur à la première image du retour), l'hôte le libère, le client l'apprend.
func _tester_retour_de_gel() -> void:
	print("-- Retour d'un gel : « Tu as été déconnecté » (phase 7)")
	var reseau: Node = root.get_node("Reseau")  # autoload : jamais nommé
	var silence_ms := int(reseau.SILENCE_SESSION * 1000.0)
	var maintenant := Time.get_ticks_msec()
	var image_avant: int = reseau._derniere_image
	var gel_avant: int = reseau._fin_du_gel
	reseau._fin_du_gel = 0
	reseau._derniere_image = maintenant - 500
	var sans_gel: bool = reseau.au_retour_d_un_gel(maintenant)
	reseau._derniere_image = maintenant - silence_ms - 1000
	var pendant: bool = reseau.au_retour_d_un_gel(maintenant)
	reseau._derniere_image = maintenant
	reseau._fin_du_gel = maintenant - 1500
	var peu_apres: bool = reseau.au_retour_d_un_gel(maintenant)
	reseau._fin_du_gel = maintenant - int(reseau.RETOUR_DE_GEL * 1000.0) - 500
	var longtemps_apres: bool = reseau.au_retour_d_un_gel(maintenant)
	reseau.definir_silence(reseau.SILENCE_CHARGEMENT)
	reseau._derniere_image = maintenant - 15000
	var au_chargement: bool = reseau.au_retour_d_un_gel(maintenant)
	reseau.definir_silence(reseau.SILENCE_SESSION)
	_check(not sans_gel and pendant and peu_apres and not longtemps_apres and not au_chargement,
		"un gel de ce poste : plus de 10 s sans image (encore aucune image depuis), ou une image qui l'a suivi il y a %.0f s au plus ; pas une image d'il y a 0,5 s, ni 15 s pendant le chargement (30 s tolérées)"
			% reseau.RETOUR_DE_GEL)
	var raisons: Array[String] = []
	var sur_perte := func() -> void: raisons.append(reseau.raison_perte)
	reseau.hote_perdu.connect(sur_perte)
	reseau._derniere_image = Time.get_ticks_msec() - silence_ms - 1000
	reseau._decider(&"hote_perdu")
	await process_frame
	reseau._fin_du_gel = 0
	reseau._derniere_image = Time.get_ticks_msec()
	reseau._decider(&"hote_perdu")
	await process_frame
	reseau.hote_perdu.disconnect(sur_perte)
	_check(raisons == [reseau.PERTE_DECONNECTE, reseau.PERTE_HOTE] and not reseau._perte_apres_gel,
		"l'hôte perdu au retour d'un gel : « Tu as été déconnecté » ; sans gel, « L'hôte a quitté la partie » (%s)" % [raisons])
	reseau._derniere_image = maxi(image_avant, Time.get_ticks_msec())
	reseau._fin_du_gel = gel_avant

	var hote := reseau
	var client := _poste_client("PosteCache")
	var arrives: Array[int] = []
	var partis: Array[int] = []
	var pertes: Array[String] = []
	var sur_arrivee := func(id: int) -> void: arrives.append(id)
	var sur_depart := func(id: int) -> void: partis.append(id)
	var sur_perte_client := func() -> void: pertes.append(client.raison_perte)
	hote.joueur_arrive.connect(sur_arrivee)
	hote.joueur_parti.connect(sur_depart)
	client.hote_perdu.connect(sur_perte_client)
	hote.pseudo = "Hôte"
	client.pseudo = "Caché"
	_check(hote.heberger(17782) == OK and client.rejoindre("127.0.0.1", 17782) == OK, "(pré-condition) un hôte et un client dans ce processus")
	_check(await _attendre(func() -> bool: return arrives.size() == 1 and client._entendus.has(1), 3.0), "(pré-condition) le client est arrivé")
	# Des silences raccourcis : 1,5 s chez l'hôte, 1 s chez le client (son gel le dépasse quand l'hôte le libère)
	hote.definir_silence(1.5)
	client.definir_silence(1.0)
	client._prochain_battement = 0
	client._battre(Time.get_ticks_msec())  # un dernier battement, puis plus rien
	client.set_process(false)
	_check(await _attendre(func() -> bool: return partis.size() == 1 and pertes.size() == 1, 5.0),
		"l'hôte libère le client muet ; le client l'apprend au relevé de ses paquets, avant sa prochaine image")
	client.set_process(true)
	_check(pertes == [client.PERTE_DECONNECTE] and not client.en_ligne(),
		"au retour de son gel : « Tu as été déconnecté » (%s), ce poste hors réseau" % [pertes])
	hote.joueur_arrive.disconnect(sur_arrivee)
	hote.joueur_parti.disconnect(sur_depart)
	client.hote_perdu.disconnect(sur_perte_client)
	hote.quitter()
	await _retirer_poste(client)
	hote.pseudo = ""


## Phase 19 (M7 de la revue de la phase 11) : `application/config/version` est aussi la version du
## protocole, présentée à la poignée de main ; deux postes de versions différentes se
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	GS.partie_en_cours = false
	GS.pret = false
	GS.niveau_courant = 0


## Attend la scène `chemin` qui remplace celle d'identifiant `avant` (la même scène rechargée compte),
````

par :

````gdscript
	GS.partie_en_cours = false
	GS.pret = false
	GS.niveau_courant = 0
	# Phase 7 du jeu en ligne (spec §9) : un poste revenu d'un onglet caché, déclaré parti entre-temps (la
	# perte de l'hôte au retour d'un gel) : « Tu as été déconnecté », puis l'écran En ligne, pas le titre
	var main_gel: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main_gel)
	current_scene = main_gel
	await _frames(2)
	reseau.raison_perte = reseau.PERTE_DECONNECTE
	main_gel._sur_hote_perdu()
	var message_gel: String = main_gel.get_node("HotePerdu/Message").text
	var ecran_gel: Node = await _attendre_scene("res://Scenes/EcranEnLigne.tscn", 6000)
	_check(message_gel == "RESEAU_DECONNECTE" and tr(message_gel) == "Tu as été déconnecté" and ecran_gel != null
		and ecran_gel.scene_file_path == "res://Scenes/EcranEnLigne.tscn" and ecran_gel.message.text == "Tu as été déconnecté" and not paused,
		"revenu d'un onglet caché : « Tu as été déconnecté » sur la manche figée, puis l'écran En ligne qui le redit (%s)"
			% ("" if ecran_gel == null else ecran_gel.message.text))
	reseau.raison_perte = reseau.PERTE_HOTE
	if ecran_gel != null:
		ecran_gel.free()
	GS.partie_en_cours = false
	GS.pret = false


## Attend la scène `chemin` qui remplace celle d'identifiant `avant` (la même scène rechargée compte),
````

- [ ] **Step 2 : ils échouent**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u3.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u3.log" | head -5
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s3.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s3.log" | head -5
```

Expected : `unitaires 0` mais `SCRIPT ERROR: Invalid access to property or key '_derniere_image' on a base object of type 'Node (Reseau.gd)'.` (`_tester_retour_de_gel`, interrompu : 557 ✅) ; `smoke 0` mais `SCRIPT ERROR: Invalid access to property or key 'PERTE_DECONNECTE' on a base object of type 'Node (Reseau.gd)'.`, puis des `SCRIPT ERROR` de la scène de jeu laissée à l'arbre (`cellules_de` sur `Nil`, `hide` sur une valeur nulle) : la CI échoue sur ces lignes.

- [ ] **Step 3 : le gel, la perte qui le suit, l'écran En ligne**

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## exclut un joueur du salon (phase 7 du jeu en ligne, spec §8.2 : `exclure_du_salon`, la croix de sa
## carte) comme la barrière de chargement exclut un absent (`exclure`) : l'exclu l'apprend, part de
## lui-même, et l'hôte le libère au plus tard peu après.
## `quitter()` part proprement (spec §5) : un adieu fiable (`_recevoir_adieu`), que l'autre côté traite
## aussitôt (l'hôte libère ce client, un client perd l'hôte), puis le transport ferme sa session une fois
````

par :

````gdscript
## exclut un joueur du salon (phase 7 du jeu en ligne, spec §8.2 : `exclure_du_salon`, la croix de sa
## carte) comme la barrière de chargement exclut un absent (`exclure`) : l'exclu l'apprend, part de
## lui-même, et l'hôte le libère au plus tard peu après. Un poste qui gèle plus longtemps que le silence
## toléré (un onglet caché, un téléphone verrouillé : le navigateur arrête ses images) a été déclaré parti
## pendant ce temps : la perte de l'hôte qu'il constate à son retour est la sienne (`au_retour_d_un_gel`,
## « Tu as été déconnecté », spec §5 et §9).
## `quitter()` part proprement (spec §5) : un adieu fiable (`_recevoir_adieu`), que l'autre côté traite
## aussitôt (l'hôte libère ce client, un client perd l'hôte), puis le transport ferme sa session une fois
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
const PERTE_EXCLU := "RESEAU_EXCLU"
const PERTE_EXCLU_HOTE := "RESEAU_EXCLU_HOTE"
## Entre l'annonce de son exclusion à un joueur et sa libération par l'hôte, en secondes : le temps que
## l'annonce arrive (renvoyée au besoin), et que l'exclu s'en aille de lui-même. À la barrière de
````

par :

````gdscript
const PERTE_EXCLU := "RESEAU_EXCLU"
const PERTE_EXCLU_HOTE := "RESEAU_EXCLU_HOTE"
## Pourquoi l'hôte est perdu, encore : ce poste revient d'un gel plus long que le silence toléré (un onglet
## caché, un téléphone verrouillé), pendant lequel l'hôte l'a déclaré parti : « Tu as été déconnecté » (phase
## 7 du jeu en ligne, spec §9).
const PERTE_DECONNECTE := "RESEAU_DECONNECTE"
## Après la fin d'un gel de ce poste, en secondes : une perte de l'hôte constatée pendant ce temps est due au
## gel (la fermeture du pair par l'hôte, ou le silence de l'hôte, se voient dès la première ou la deuxième
## image qui suit).
const RETOUR_DE_GEL := 2.0
## Entre l'annonce de son exclusion à un joueur et sa libération par l'hôte, en secondes : le temps que
## l'annonce arrive (renvoyée au besoin), et que l'exclu s'en aille de lui-même. À la barrière de
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## suivant ; remis à 0 par `quitter()`.
var niveau_manche := 0
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE, PERTE_EXCLU ou
## PERTE_EXCLU_HOTE), posé juste avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Chez un client, ou chez l'hôte dont la partie n'a pas pu être créée : pourquoi la dernière connexion a
````

par :

````gdscript
## suivant ; remis à 0 par `quitter()`.
var niveau_manche := 0
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE, PERTE_EXCLU, PERTE_EXCLU_HOTE
## ou PERTE_DECONNECTE), posé juste avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Chez un client, ou chez l'hôte dont la partie n'a pas pu être créée : pourquoi la dernière connexion a
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## Chez l'hôte : le débit des demandes de salon de chaque client (DEMANDES_SALON_PAR_SECONDE), en secondes.
var _limite_salon := LimiteDebit.new(DEMANDES_SALON_PAR_SECONDE, DEMANDES_SALON_PAR_SECONDE)


````

par :

````gdscript
## Chez l'hôte : le débit des demandes de salon de chaque client (DEMANDES_SALON_PAR_SECONDE), en secondes.
var _limite_salon := LimiteDebit.new(DEMANDES_SALON_PAR_SECONDE, DEMANDES_SALON_PAR_SECONDE)
## L'instant (ms) de la dernière image de ce poste (`_process`), en session ou non, et celui de la fin de son
## dernier gel plus long que le silence toléré (0 : jamais) : voir `au_retour_d_un_gel`.
var _derniere_image := 0
var _fin_du_gel := 0
## Vrai si la perte de l'hôte décidée (`_decider`) suit un gel de ce poste : PERTE_DECONNECTE.
var _perte_apres_gel := false


````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
	niveau_manche = 0
	_exclusion = ""
	index_local = -1
	couleur_locale = Color.TRANSPARENT
````

par :

````gdscript
	niveau_manche = 0
	_exclusion = ""
	_perte_apres_gel = false
	index_local = -1
	couleur_locale = Color.TRANSPARENT
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript


## En session, le transport, le battement et l'écoute des silences ; puis les départs en cours, oubliés
## une fois leur transport fermé. Un transport de session qui se ferme de lui-même (`servir()` faux sans
## `quitter()` ni `clore()`) : la session est perdue (`_sur_hote_perdu`), sans battement ni écoute.
func _process(_delta: float) -> void:
	if _transport != null and not _transport.servir():
		_sur_hote_perdu()
	elif en_ligne():
		var maintenant := Time.get_ticks_msec()
		_battre(maintenant)
		_ecouter(maintenant)
````

par :

````gdscript


## La fin d'un gel de ce poste (`au_retour_d_un_gel`), puis, en session, le transport, le battement et
## l'écoute des silences ; puis les départs en cours, oubliés une fois leur transport fermé. Un transport de
## session qui se ferme de lui-même (`servir()` faux sans `quitter()` ni `clore()`) : la session est perdue
## (`_sur_hote_perdu`), sans battement ni écoute.
func _process(_delta: float) -> void:
	var maintenant := Time.get_ticks_msec()
	if _derniere_image > 0 and maintenant - _derniere_image > int(silence * 1000.0):
		_fin_du_gel = maintenant
	_derniere_image = maintenant
	if _transport != null and not _transport.servir():
		_sur_hote_perdu()
	elif en_ligne():
		_battre(maintenant)
		_ecouter(maintenant)
````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
		else:
			_decider("hote_perdu")


````

par :

````gdscript
		else:
			_decider("hote_perdu")


## Vrai si ce poste revient, à `maintenant` (ms), d'un gel plus long que le silence toléré : sans image
## depuis plus que `silence` (la première image après un onglet caché ou un téléphone verrouillé n'est pas
## encore passée : la fermeture de son pair par l'hôte arrive au relevé des paquets, avant elle), ou une
## image qui a suivi un tel gel il y a RETOUR_DE_GEL secondes au plus. L'hôte l'a alors déclaré parti : son
## silence a dépassé le même délai chez lui (spec §2 : 10 s pour tout le monde).
func au_retour_d_un_gel(maintenant: int) -> bool:
	return (_derniere_image > 0 and maintenant - _derniere_image > int(silence * 1000.0)) \
		or (_fin_du_gel > 0 and maintenant - _fin_du_gel <= int(RETOUR_DE_GEL * 1000.0))


````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
		return
	_issue_decidee = true
	_fermer_puis_emettre.call_deferred(nom, arguments, _generation)

````

par :

````gdscript
		return
	_issue_decidee = true
	_perte_apres_gel = nom == &"hote_perdu" and au_retour_d_un_gel(Time.get_ticks_msec())
	_fermer_puis_emettre.call_deferred(nom, arguments, _generation)

````

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
		return
	var exclusion := _exclusion
	var raison_transport := _raison_transport
	quitter()
	if nom == &"hote_perdu":
		raison_perte = exclusion if not exclusion.is_empty() else PERTE_HOTE
	elif nom == &"connexion_echouee":
		raison_echec = raison_transport
````

par :

````gdscript
		return
	var exclusion := _exclusion
	var apres_gel := _perte_apres_gel
	var raison_transport := _raison_transport
	quitter()
	if nom == &"hote_perdu":
		raison_perte = exclusion if not exclusion.is_empty() else (PERTE_DECONNECTE if apres_gel else PERTE_HOTE)
	elif nom == &"connexion_echouee":
		raison_echec = raison_transport
````

Dans `Scripts/Main.gd`, remplacer :

````gdscript
## apparaître le Spawner de l'hôte ; lions, Spawner et intro attendent la barrière de chargement.
## Échap y ouvre un menu local qui ne met pas la partie en pause ; un hôte perdu ramène au titre
## après son message. Une bataille finie (phase 18) montre l'écran Résultats (`Resultats`) sur le bilan
## de l'hôte, et suit le choix qu'on y fait.

````

par :

````gdscript
## apparaître le Spawner de l'hôte ; lions, Spawner et intro attendent la barrière de chargement.
## Échap y ouvre un menu local qui ne met pas la partie en pause ; un hôte perdu ramène au titre
## après son message (à l'écran En ligne un poste revenu d'un onglet caché, déclaré parti entre-temps). Une bataille finie (phase 18) montre l'écran Résultats (`Resultats`) sur le bilan
## de l'hôte, et suit le choix qu'on y fait.

````

Dans `Scripts/Main.gd`, remplacer :

````gdscript
const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCENE_SALON := "res://Scenes/Salon.tscn"
const _Salon := preload("res://Scripts/Salon.gd")
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
const SCENE_LION := preload("res://Scenes/Lion.tscn")
````

par :

````gdscript
const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCENE_SALON := "res://Scenes/Salon.tscn"
const SCENE_EN_LIGNE := "res://Scenes/EcranEnLigne.tscn"
const _Salon := preload("res://Scripts/Salon.gd")
const _EcranEnLigne := preload("res://Scripts/EcranEnLigne.gd")
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
const SCENE_LION := preload("res://Scenes/Lion.tscn")
````

Dans `Scripts/Main.gd`, remplacer :

````gdscript
## la revue finale) : ce poste est déjà hors réseau. Tout se fige sous le message (« L'hôte a quitté la
## partie », ou l'exclusion de ce poste par la barrière de chargement : `Reseau.raison_perte`, phase 18),
## puis retour au titre (spec §9).
func _sur_hote_perdu() -> void:
	# M5 (revue finale phase 17) : l'arbre se fige avant qu'aucun lion n'arrête la boucle du vomi d'un
````

par :

````gdscript
## la revue finale) : ce poste est déjà hors réseau. Tout se fige sous le message (« L'hôte a quitté la
## partie », ou l'exclusion de ce poste par la barrière de chargement : `Reseau.raison_perte`, phase 18),
## puis retour au titre (spec §9) ; ou, pour un poste revenu d'un onglet caché (« Tu as été déconnecté »,
## phase 7 du jeu en ligne), à l'écran En ligne.
func _sur_hote_perdu() -> void:
	# M5 (revue finale phase 17) : l'arbre se fige avant qu'aucun lion n'arrête la boucle du vomi d'un
````

Dans `Scripts/Main.gd`, remplacer :

````gdscript
	add_child(couche)
	get_tree().paused = true
	get_tree().create_timer(DELAI_HOTE_PERDU, true).timeout.connect(_revenir_au_titre)


````

par :

````gdscript
	add_child(couche)
	get_tree().paused = true
	get_tree().create_timer(DELAI_HOTE_PERDU, true).timeout.connect(_apres_la_perte.bind(Reseau.raison_perte))


## Après le message de la perte de l'hôte, de raison `raison` : le titre (spec §9, comme au LAN), sauf pour un
## poste revenu d'un onglet caché ou d'un téléphone verrouillé (`Reseau.PERTE_DECONNECTE`) : l'écran En
## ligne, qui redit le message (spec §9 : « Tu as été déconnecté » puis écran En ligne), d'où le lien
## d'invitation le ramène.
func _apres_la_perte(raison: String) -> void:
	if raison != Reseau.PERTE_DECONNECTE:
		_revenir_au_titre()
		return
	get_tree().paused = false
	_EcranEnLigne.message_a_l_arrivee = raison
	get_tree().change_scene_to_file(SCENE_EN_LIGNE)


````

Dans `Assets/Traductions/traductions.csv`, remplacer :

````csv
RESEAU_EXCLU,"Exclu : ta partie a mis trop de temps à charger.","Removed: your game took too long to load."
RESEAU_EXCLU_HOTE,"L'hôte t'a exclu de la partie.","The host removed you from the game."
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
RESEAU_HEBERGER_IMPOSSIBLE,Impossible d'héberger (erreur %d),Can't host (error %d)
````

par :

````csv
RESEAU_EXCLU,"Exclu : ta partie a mis trop de temps à charger.","Removed: your game took too long to load."
RESEAU_EXCLU_HOTE,"L'hôte t'a exclu de la partie.","The host removed you from the game."
RESEAU_DECONNECTE,Tu as été déconnecté,You were disconnected
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
RESEAU_HEBERGER_IMPOSSIBLE,Impossible d'héberger (erreur %d),Can't host (error %d)
````

- [ ] **Step 4 : l'import, puis les tests passent**

```bash
timeout 300 godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u3.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u3.log"; grep -c "✅" "$TMPDIR/u3.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s3.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s3.log"; grep -c "✅" "$TMPDIR/s3.log"
```

Expected : rien à l'import ; unitaires `0`, `PROTOCOLE 0.21 1188810746 (67 lignes)`, `== 0 échec(s) ==`, 563 ✅ ; smoke `0`, `== 0 échec(s) ==`, 462 ✅.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Reseau.gd Scripts/Main.gd Assets/Traductions/traductions.csv Assets/Traductions/traductions.fr.translation Assets/Traductions/traductions.en.translation tests/unitaires.gd tests/smoke_test.gd
git commit -m "Onglet caché : un poste revenu d'un gel plus long que le silence toléré, déclaré parti entre-temps, lit « Tu as été déconnecté », puis l'écran En ligne

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 4 : le salon de l'hôte (la croix d'exclusion, la consigne de l'onglet)

**Files:**
- Modify: `Scripts/Salon.gd` (`TAILLE_CROIX`, `POLICE_CROIX`, `consigne`, `exclure`, `_creer_carte(index)` et sa croix, `_afficher_carte`, `_afficher`, `_sur_langue_changee`)
- Modify: `Scenes/Salon.tscn` (le nœud `Consigne`)
- Modify: `Assets/Traductions/traductions.csv` (`SALON_PREMIER_PLAN`, `SALON_EXCLURE`) (+ `.translation`)
- Modify: `tests/smoke_test.gd` (`_tester_salon`, `_tester_tactile_mobile`)

**Interfaces:**
- `Salon` : `const TAILLE_CROIX := Vector2(64, 64)`, `const POLICE_CROIX := 40` ; `@onready var consigne: Label = $Consigne` ; `func exclure(index: int) -> bool` (la croix de la carte d'index `index`) ; chaque carte gagne `"croix": Button`.

- [ ] **Step 1 : le test qui échoue**

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
		"une place seulement réservée n'a pas de carte (M4) ; un joueur arrivé a la sienne")
	_check(reseau.places_reservees == 1, "phase 18 : la table part avec le nombre de places seulement réservées (%d)" % reseau.places_reservees)

	# Couleurs : la voisine libre (celle d'une place réservée est prise) ; une seule par appui
````

par :

````gdscript
		"une place seulement réservée n'a pas de carte (M4) ; un joueur arrivé a la sienne")
	_check(reseau.places_reservees == 1, "phase 18 : la table part avec le nombre de places seulement réservées (%d)" % reseau.places_reservees)
	# Phase 7 du jeu en ligne (spec §8.2) : chez l'hôte, la croix d'exclusion en haut à droite de la carte de
	# chaque autre joueur arrivé, à la souris (sans focus), sans couvrir le lion ; elle exclut le joueur de sa
	# carte (`exclure`, par son index)
	await process_frame  # la croix, montrée, prend sa place à l'image suivante
	var croix_bob: Button = salon.cartes[1].croix
	var cadre_bob: Rect2 = salon.cartes[1].cadre.get_global_rect()
	var rect_croix := croix_bob.get_global_rect()
	_check(croix_bob.visible and not c0.croix.visible and salon.cartes.slice(2).all(func(c: Dictionary) -> bool: return not c.croix.visible)
		and cadre_bob.encloses(rect_croix) and rect_croix.end.x >= cadre_bob.end.x - 20 and rect_croix.position.y <= cadre_bob.position.y + 20
		and rect_croix.size.x >= 64 and rect_croix.size.y >= 64 and not rect_croix.intersects(salon.cartes[1].lion.get_global_rect())
		and croix_bob.focus_mode == Control.FOCUS_NONE and croix_bob.tooltip_text == "Exclure ce joueur",
		"chez l'hôte, la carte de Bob a la croix d'exclusion en haut à droite (%s dans %s), sans couvrir son lion ; ni la sienne ni les places libres"
			% [rect_croix, cadre_bob])
	var liens := croix_bob.pressed.get_connections()
	_check(liens.size() == 1 and (liens[0].callable as Callable).get_method() == &"exclure" and (liens[0].callable as Callable).get_bound_arguments() == [1]
		and not salon.exclure(0) and not salon.exclure(3) and not salon.exclure(1),
		"la croix de Bob exclut le joueur de la carte 1 ; ni l'hôte, ni une place libre (ni ici Bob, simulé : pas un vrai pair) ne s'excluent")

	# Couleurs : la voisine libre (celle d'une place réservée est prise) ; une seule par appui
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	await process_frame
	_check(salon.titre_niveau.text == "Level: Village" and salon.cartes[1].pseudo.text == "Free slot" and c0.etat.text == "READY!"
		and salon.aide.text.begins_with("Left/Right"), "changer de langue retraduit le salon (%s)" % salon.titre_niveau.text)
	params.definir_langue("fr")
	salon.retour(false)
````

par :

````gdscript
	await process_frame
	_check(salon.titre_niveau.text == "Level: Village" and salon.cartes[1].pseudo.text == "Free slot" and c0.etat.text == "READY!"
		and salon.aide.text.begins_with("Left/Right") and salon.cartes[1].croix.tooltip_text == "Remove this player"
		and salon.consigne.text == "Keep this tab in front during the game.", "changer de langue retraduit le salon (%s)" % salon.titre_niveau.text)
	params.definir_langue("fr")
	salon.retour(false)
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	root.add_child(salon_client)
	await process_frame
	_check(salon_client.aide.text == tr("SALON_AIDE") and not salon_client.rangee_invitation.visible and not salon_client.bouton_demarrer.visible,
		"un client : l'aide sans le niveau ni Démarrer, pas de code, pas de bouton")
	salon_client.changer_niveau(1)
	salon_client.demarrer()
````

par :

````gdscript
	root.add_child(salon_client)
	await process_frame
	_check(salon_client.aide.text == tr("SALON_AIDE") and not salon_client.rangee_invitation.visible and not salon_client.bouton_demarrer.visible
		and not salon_client.consigne.visible,
		"un client : l'aide sans le niveau ni Démarrer, pas de code, pas de bouton, pas la consigne de l'onglet")
	salon_client.changer_niveau(1)
	salon_client.demarrer()
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
		{"id": id_client, "index": 1, "couleur": palette[1], "pseudo": "Moi", "pret": false}])
	reseau.salon_change.emit()
	var attente_client: String = salon_client.etat.text
	reseau.table_salon[1].pret = true
````

par :

````gdscript
		{"id": id_client, "index": 1, "couleur": palette[1], "pseudo": "Moi", "pret": false}])
	reseau.salon_change.emit()
	_check(salon_client.cartes.all(func(c: Dictionary) -> bool: return not c.croix.visible), "un client n'a aucune croix d'exclusion")
	var attente_client: String = salon_client.etat.text
	reseau.table_salon[1].pret = true
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
		"au salon, un mobile a les flèches de la couleur et PRÊT, sans stick ni pause")
	_check(not salon.bouton_plein_ecran.visible and salon.bouton_retour.size.y >= cible and salon.etat.get_theme_font_size("font_size") == 48
		and salon.aide.get_theme_font_size("font_size") == 40, "un mobile n'a pas Plein écran ; Retour fait %d px de haut, l'état et l'aide sont agrandis" % salon.bouton_retour.size.y)
	var centre := func(bouton: TouchScreenButton) -> Vector2: return bouton.position + bouton.texture_normal.get_size() / 2.0
	await _toucher(centre.call(tactile.bouton_droite), true)
````

par :

````gdscript
		"au salon, un mobile a les flèches de la couleur et PRÊT, sans stick ni pause")
	_check(not salon.bouton_plein_ecran.visible and salon.bouton_retour.size.y >= cible and salon.etat.get_theme_font_size("font_size") == 48
		and salon.aide.get_theme_font_size("font_size") == 40 and not salon.consigne.visible,
		"un mobile n'a pas Plein écran ni la consigne de l'onglet de l'hôte ; Retour fait %d px de haut, l'état et l'aide sont agrandis" % salon.bouton_retour.size.y)
	var centre := func(bouton: TouchScreenButton) -> Vector2: return bouton.position + bouton.texture_normal.get_size() / 2.0
	await _toucher(centre.call(tactile.bouton_droite), true)
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
		and bureau.bouton_plein_ecran.focus_mode == Control.FOCUS_NONE and tr(bureau.bouton_plein_ecran.text) == "Plein écran",
		"sur ordinateur : pas de tactile, « Plein écran » en haut à droite, sans focus")
	bureau.bouton_plein_ecran.pressed.emit()
	_check(params.plein_ecran, "Plein écran, cliqué : le plein écran")
````

par :

````gdscript
		and bureau.bouton_plein_ecran.focus_mode == Control.FOCUS_NONE and tr(bureau.bouton_plein_ecran.text) == "Plein écran",
		"sur ordinateur : pas de tactile, « Plein écran » en haut à droite, sans focus")
	# Phase 7 (spec §5) : la consigne de l'hôte, en haut, entre Retour et Plein écran, au-dessus du titre
	var consigne: Rect2 = _rect_du_texte(bureau.consigne)
	var titre_salon: Rect2 = _rect_du_texte(bureau.get_node("Centre/Colonne/Titre"))
	_check(bureau.consigne.visible and bureau.consigne.text == "Garde cet onglet au premier plan pendant la partie."
		and consigne.position.x >= bureau.bouton_retour.get_global_rect().end.x + 20 and consigne.end.x <= plein.position.x - 20
		and consigne.position.y >= 20 and consigne.end.y <= titre_salon.position.y + 20,
		"chez l'hôte, sur ordinateur : « Garde cet onglet au premier plan pendant la partie. » en haut (%s), entre Retour et Plein écran, au-dessus du titre (%s)"
			% [consigne, titre_salon])
	bureau.bouton_plein_ecran.pressed.emit()
	_check(params.plein_ecran, "Plein écran, cliqué : le plein écran")
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s4.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s4.log" | head -5
```

Expected : `smoke 1`, `SCRIPT ERROR: Invalid access to property or key 'croix' on a base object of type 'Dictionary'.` (`_tester_salon`), `SCRIPT ERROR: Invalid access to property or key 'consigne' on a base object of type 'Control (Salon.gd)'.` (`_tester_tactile_mobile`), puis « ❌ Revanche : la manche se relance … » et « ❌ les scènes de jeu fermées et le salon ne laissent aucune connexion aux autoloads » (les salons jamais libérés par les tests interrompus).

- [ ] **Step 3 : la croix et la consigne**

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
## sur le desktop de développement, l'adresse `ip:port` de l'hôte ENet, sans lien. Une salle qui
## n'accueille plus personne (`Reseau.raison_salle_fermee`) : son message à la place du code, sans lien
## (spec §4.3 : « Salle expirée : crée une nouvelle partie pour inviter »).
##
## Retour (ou Échap, B à la manette) quitte le réseau et ramène à l'écran En ligne ; un hôte perdu y
````

par :

````gdscript
## sur le desktop de développement, l'adresse `ip:port` de l'hôte ENet, sans lien. Une salle qui
## n'accueille plus personne (`Reseau.raison_salle_fermee`) : son message à la place du code, sans lien
## (spec §4.3 : « Salle expirée : crée une nouvelle partie pour inviter »). En haut, la consigne de l'hôte
## (spec §5) : « Garde cet onglet au premier plan pendant la partie. » (le navigateur fige un onglet caché,
## et le jeu de tous avec lui).
##
## Exclusion (phase 7 du jeu en ligne, spec §8.2) : chez l'hôte, la carte de chaque autre joueur arrivé a
## une croix, en haut à droite ; cliquée (`exclure`), elle exclut ce joueur (`Reseau.exclure_du_salon`), qui
## lit « L'hôte t'a exclu de la partie. » ; sa carte se libère à son départ. La croix se clique à la souris
## (l'hôte est un ordinateur) ou au doigt ; ni le clavier ni la manette ne l'atteignent : le salon n'a pas
## de curseur de carte.
##
## Retour (ou Échap, B à la manette) quitte le réseau et ramène à l'écran En ligne ; un hôte perdu y
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
const TAILLE_CARTE := Vector2(310, 470)
const POLICE_PSEUDO := 24
const COULEUR_BADGE := Color(1, 0.85, 0.2)
const COULEUR_PRET := Color(0.55, 1.0, 0.55)
````

par :

````gdscript
const TAILLE_CARTE := Vector2(310, 470)
const POLICE_PSEUDO := 24
## La croix d'exclusion, en haut à droite d'une carte : 64 px de l'écran (45 px CSS dans la fenêtre de
## 1400 px d'un ordinateur), la police du jeu (le « × » y est).
const TAILLE_CROIX := Vector2(64, 64)
const POLICE_CROIX := 40
const COULEUR_BADGE := Color(1, 0.85, 0.2)
const COULEUR_PRET := Color(0.55, 1.0, 0.55)
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
	&"vomir", &"demarrer"]
## Une carte par place, dans l'ordre des index : {"cadre": PanelContainer, "style": StyleBoxFlat,
## "badge": Label, "lion": TextureRect, "teinte": ShaderMaterial, "pseudo": Label, "etat": Label}.
var cartes: Array[Dictionary] = []

````

par :

````gdscript
	&"vomir", &"demarrer"]
## Une carte par place, dans l'ordre des index : {"cadre": PanelContainer, "style": StyleBoxFlat,
## "badge": Label, "lion": TextureRect, "teinte": ShaderMaterial, "pseudo": Label, "etat": Label,
## "croix": Button}.
var cartes: Array[Dictionary] = []

````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
@onready var bouton_retour: Button = $BoutonRetour
@onready var bouton_plein_ecran: Button = $BoutonPleinEcran
@onready var controles_tactiles: CanvasLayer = $ControlesTactiles

````

par :

````gdscript
@onready var bouton_retour: Button = $BoutonRetour
@onready var bouton_plein_ecran: Button = $BoutonPleinEcran
@onready var consigne: Label = $Consigne
@onready var controles_tactiles: CanvasLayer = $ControlesTactiles

````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
		aide.add_theme_font_size_override("font_size", 40)
	for i in range(EtatPartie.NB_JOUEURS_MAX):
		cartes.append(_creer_carte())
	Reseau.salon_change.connect(_sur_salon_change)
	Reseau.manche_lancee.connect(_sur_manche_lancee)
````

par :

````gdscript
		aide.add_theme_font_size_override("font_size", 40)
	for i in range(EtatPartie.NB_JOUEURS_MAX):
		cartes.append(_creer_carte(i))
	Reseau.salon_change.connect(_sur_salon_change)
	Reseau.manche_lancee.connect(_sur_manche_lancee)
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript


func _remettre_bouton_copier() -> void:
	bouton_copier.text = "SALON_COPIER_LIEN"
````

par :

````gdscript


## L'hôte : exclut le joueur de la carte d'index `index` (sa croix) ; vrai si l'exclusion part
## (`Reseau.exclure_du_salon` : jamais l'hôte, ni une place libre, ni pendant le lancement).
func exclure(index: int) -> bool:
	if _lance:
		return false
	for fiche in Reseau.table_salon:
		if fiche.index == index:
			return Reseau.exclure_du_salon(fiche.id)
	return false


func _remettre_bouton_copier() -> void:
	bouton_copier.text = "SALON_COPIER_LIEN"
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript

func _sur_langue_changee(_langue: String) -> void:
	_afficher()

````

par :

````gdscript

func _sur_langue_changee(_langue: String) -> void:
	for carte in cartes:
		(carte.croix as Button).tooltip_text = tr("SALON_EXCLURE")
	_afficher()

````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
		_afficher_carte(cartes[i], par_index.get(i, {}), id_local)
	var hote := multiplayer.is_server()
	titre_niveau.text = tr("SALON_NIVEAU") % tr(GameState.NIVEAUX[Reseau.niveau_salon].nom)
	aide.text = tr("SALON_AIDE_HOTE" if hote else ("SALON_AIDE_TACTILE" if Parametres.mobile else "SALON_AIDE"))
````

par :

````gdscript
		_afficher_carte(cartes[i], par_index.get(i, {}), id_local)
	var hote := multiplayer.is_server()
	consigne.visible = hote and not Parametres.mobile
	consigne.text = tr("SALON_PREMIER_PLAN")
	titre_niveau.text = tr("SALON_NIVEAU") % tr(GameState.NIVEAUX[Reseau.niveau_salon].nom)
	aide.text = tr("SALON_AIDE_HOTE" if hote else ("SALON_AIDE_TACTILE" if Parametres.mobile else "SALON_AIDE"))
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
## Une place libre : silhouette sombre, sans couleur ; une place prise : le lion teinté de la
## couleur du joueur (le même shader qu'en jeu), son pseudo dans sa couleur, Prêt ou non, le
## contour à sa couleur (plus épais pour ce poste).
func _afficher_carte(carte: Dictionary, fiche: Dictionary, id_local: int) -> void:
	var style: StyleBoxFlat = carte.style
````

par :

````gdscript
## Une place libre : silhouette sombre, sans couleur ; une place prise : le lion teinté de la
## couleur du joueur (le même shader qu'en jeu), son pseudo dans sa couleur, Prêt ou non, le
## contour à sa couleur (plus épais pour ce poste) ; chez l'hôte, la croix d'exclusion sur la carte de
## chaque autre joueur.
func _afficher_carte(carte: Dictionary, fiche: Dictionary, id_local: int) -> void:
	var style: StyleBoxFlat = carte.style
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
	var etat_carte: Label = carte.etat
	var badge: Label = carte.badge
	if fiche.is_empty():
		badge.text = " "
````

par :

````gdscript
	var etat_carte: Label = carte.etat
	var badge: Label = carte.badge
	var croix: Button = carte.croix
	croix.visible = multiplayer.is_server() and not _lance and not fiche.is_empty() and fiche.id != id_local
	if fiche.is_empty():
		badge.text = " "
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript


func _creer_carte() -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
````

par :

````gdscript


## La carte de la place d'index `index` (sa croix exclut le joueur qui l'occupe : `exclure`).
func _creer_carte(index: int) -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
````

Dans `Scripts/Salon.gd`, remplacer :

````gdscript
	for noeud: Control in [badge, lion, pseudo, etat_carte]:
		colonne.add_child(noeud)
	rangee_cartes.add_child(cadre)
	return {"cadre": cadre, "style": style, "badge": badge, "lion": lion, "teinte": teinte, "pseudo": pseudo, "etat": etat_carte}


````

par :

````gdscript
	for noeud: Control in [badge, lion, pseudo, etat_carte]:
		colonne.add_child(noeud)
	# Par-dessus la colonne, en haut à droite (le conteneur respecte ses drapeaux de taille) : au-dessus du
	# lion, à côté des badges (un autre joueur n'en a pas chez l'hôte)
	var croix := Button.new()
	croix.text = "×"
	croix.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	croix.tooltip_text = tr("SALON_EXCLURE")
	croix.custom_minimum_size = TAILLE_CROIX
	croix.size_flags_horizontal = Control.SIZE_SHRINK_END
	croix.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	croix.focus_mode = Control.FOCUS_NONE
	croix.add_theme_font_size_override("font_size", POLICE_CROIX)
	croix.visible = false
	croix.pressed.connect(exclure.bind(index))
	cadre.add_child(croix)
	rangee_cartes.add_child(cadre)
	return {"cadre": cadre, "style": style, "badge": badge, "lion": lion, "teinte": teinte, "pseudo": pseudo, "etat": etat_carte,
		"croix": croix}


````

Dans `Scenes/Salon.tscn`, remplacer :

````ini
text = "SALON_PLEIN_ECRAN"

[node name="ControlesTactiles" parent="." instance=ExtResource("2_tactile")]
disposition = 1
````

par :

````ini
text = "SALON_PLEIN_ECRAN"

[node name="Consigne" type="Label" parent="."]
visible = false
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -560.0
offset_top = 30.0
offset_right = 560.0
offset_bottom = 70.0
grow_horizontal = 2
auto_translate_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.8)
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.12, 0.85)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 26
horizontal_alignment = 1
vertical_alignment = 1

[node name="ControlesTactiles" parent="." instance=ExtResource("2_tactile")]
disposition = 1
````

Dans `Assets/Traductions/traductions.csv`, remplacer :

````csv
SALON_AIDE_TACTILE,"Flèches : ta couleur   ·   PRÊT : prêt ou pas","Arrows: your color   ·   READY: ready or not"
SALON_PLEIN_ECRAN,Plein écran,Full screen
TACTILE_PRET,PRÊT,READY
VOILE_PORTRAIT,Tourne ton téléphone,Turn your phone sideways
````

par :

````csv
SALON_AIDE_TACTILE,"Flèches : ta couleur   ·   PRÊT : prêt ou pas","Arrows: your color   ·   READY: ready or not"
SALON_PLEIN_ECRAN,Plein écran,Full screen
SALON_PREMIER_PLAN,Garde cet onglet au premier plan pendant la partie.,Keep this tab in front during the game.
SALON_EXCLURE,Exclure ce joueur,Remove this player
TACTILE_PRET,PRÊT,READY
VOILE_PORTRAIT,Tourne ton téléphone,Turn your phone sideways
````

- [ ] **Step 4 : l'import, puis le test passe**

```bash
timeout 300 godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s4.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s4.log"; grep -c "✅" "$TMPDIR/s4.log"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u4.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u4.log"; grep -c "✅" "$TMPDIR/u4.log"
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c4.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c4.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c4.log"
```

Expected : rien à l'import ; smoke `0`, `== 0 échec(s) ==`, 466 ✅ (dont « chez l'hôte, la carte de Bob a la croix d'exclusion en haut à droite ([P: (586.0, 315.0), S: (64.0, 64.0)] dans [P: (350.0, 305.0), S: (310.0, 470.0)]) … » et « … « Garde cet onglet au premier plan pendant la partie. » en haut ([P: (677.5, 30.0), S: (645.0, 40.0)]) … ») ; unitaires `0`, `== 0 échec(s) ==`, 563 ✅ ; `captures 0 : 46 📸` (headless, rien d'écrit), sans erreur.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Salon.gd Scenes/Salon.tscn Assets/Traductions/traductions.csv Assets/Traductions/traductions.fr.translation Assets/Traductions/traductions.en.translation tests/smoke_test.gd
git commit -m "Salon : chez l'hôte, la croix d'exclusion sur la carte de chaque autre joueur ; « Garde cet onglet au premier plan pendant la partie. » en haut du salon de l'hôte, sur ordinateur

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 5 : les pseudos (la mise en forme d'Unicode, jamais interprétés)

**Files:**
- Modify: `Scripts/Reseau.gd` (`_code_point_interdit`)
- Modify: `tests/unitaires.gd` (`_tester_reseau` : les caractères de mise en forme ; `_tester_pseudos_affiches`)
- Modify: `tests/smoke_test.gd` (`_tester_salon`, `_tester_manche_reseau` : les étiquettes de pseudo)

**Interfaces:** aucune neuve (`Reseau._code_point_interdit` élargi ; unitaires : `func _tester_pseudos_affiches() -> void`).

- [ ] **Step 1 : les tests qui échouent**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	_tester_mobile()
	_tester_limites()
	await _tester_demandes_salon()
	await _tester_exclusion()
````

par :

````gdscript
	_tester_mobile()
	_tester_limites()
	_tester_pseudos_affiches()
	await _tester_demandes_salon()
	await _tester_exclusion()
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	_check(reseau.pseudo_valide(brut) == "abcdefg",
		"le pseudo est aussi nettoyé du DEL, des contrôles C1, des forçages de sens et des caractères invisibles")
	_check(reseau.pseudo_valide("abcdefghijk lmn") == "abcdefghijk",
		"la coupe à %d caractères ne laisse pas d'espace finale (nettoyage après la coupe)" % reseau.PSEUDO_MAX)
````

par :

````gdscript
	_check(reseau.pseudo_valide(brut) == "abcdefg",
		"le pseudo est aussi nettoyé du DEL, des contrôles C1, des forçages de sens et des caractères invisibles")
	# Phase 7 du jeu en ligne (spec §8.2) : tous les caractères de mise en forme (catégorie Cf), et ce qui fait
	# un pseudo invisible ; le nettoyage passe avant la coupe à 12 caractères
	var formats := ""
	for c: int in [0x00AD, 0x034F, 0x0600, 0x061C, 0x06DD, 0x070F, 0x0891, 0x08E2, 0x115F, 0x1160, 0x17B4, 0x180B, 0x180E, 0x2066,
			0x2069, 0x3164, 0xFFA0, 0xFFF9, 0xFFFB, 0x110BD, 0x13430, 0x1BCA0, 0x1D173, 0xE0001, 0xE0041, 0xE007F, 0xE0100]:
		formats += char(c) + "x"
	var masques := (char(0x200B) + "W" + char(0x2066)).repeat(20)
	_check(reseau.pseudo_valide(formats) == "xxxxxxxxxxxx" and reseau.pseudo_valide(masques) == "WWWWWWWWWWWW"
		and reseau.pseudo_valide("Zoé" + char(0x2003) + "Léa " + char(0x1F600)) == "Zoé" + char(0x2003) + "Léa " + char(0x1F600),
		"phase 7 : nettoyé aussi des caractères de mise en forme d'Unicode (trait d'union conditionnel, marque arabe, étiquettes…) et des lettres vides, avant la coupe à 12 ; espaces, accents et emoji restent")
	_check(reseau.pseudo_ou_defaut(char(0x3164).repeat(5) + char(0xE0041), 2) == "Joueur 3",
		"un pseudo fait seulement de lettres vides et d'étiquettes retombe sur « Joueur N »")
	_check(reseau.pseudo_valide("abcdefghijk lmn") == "abcdefghijk",
		"la coupe à %d caractères ne laisse pas d'espace finale (nettoyage après la coupe)" % reseau.PSEUDO_MAX)
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript


## Phase 7 du jeu en ligne (spec §8.2) : entre l'autoload, hôte, et un second poste client dans ce même
## processus (comme `_tester_battement`), les demandes de salon d'un client qui inonde l'hôte : au-delà de 10
````

par :

````gdscript


## Phase 7 du jeu en ligne (spec §8.2) : un pseudo n'est jamais interprété (BBCode, traduction) : aucun
## `RichTextLabel` dans le jeu, et l'étiquette du lion ne se traduit pas d'elle-même (un pseudo « PAUSE » n'est
## pas une clé) ; les cartes du salon, le HUD et l'écran Résultats sont vérifiés par le smoke test.
func _tester_pseudos_affiches() -> void:
	print("-- Pseudos affichés (phase 7)")
	var interpretes: Array[String] = []
	for dossier: String in ["res://Scripts", "res://Scenes"]:
		for fichier in _fichiers_du_dossier(dossier, ".gd" if dossier.ends_with("Scripts") else ".tscn"):
			var texte := FileAccess.get_file_as_string(dossier.path_join(fichier))
			if texte.contains("RichTextLabel") or texte.contains("bbcode"):
				interpretes.append(fichier)
	_check(interpretes.is_empty(), "aucun RichTextLabel ni BBCode dans les scripts et les scènes du jeu : un pseudo s'affiche en texte brut (%s)" % [interpretes])
	var etat := (load("res://Scenes/Lion.tscn") as PackedScene).get_state()
	var etiquette := {}
	for i in range(etat.get_node_count()):
		if etat.get_node_name(i) == &"Pseudo":
			etiquette["type"] = etat.get_node_type(i)
			for p in range(etat.get_node_property_count(i)):
				etiquette[etat.get_node_property_name(i, p)] = etat.get_node_property_value(i, p)
	_check(etiquette.get("type") == &"Label" and etiquette.get("auto_translate_mode") == Node.AUTO_TRANSLATE_MODE_DISABLED,
		"l'étiquette du pseudo d'un lion est un Label qui ne se traduit pas de lui-même (%s, %s)" % [etiquette.get("type"), etiquette.get("auto_translate_mode")])


## Phase 7 du jeu en ligne (spec §8.2) : entre l'autoload, hôte, et un second poste client dans ce même
## processus (comme `_tester_battement`), les demandes de salon d'un client qui inonde l'hôte : au-delà de 10
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
	_check(root.content_scale_size == Vector2i(2000, 1125) and salon.cartes.size() == 6
		and salon.cartes.all(func(c: Dictionary) -> bool: return c.cadre.visible), "le salon est en 16:9, une carte par place (6)")
	_check(c0.pseudo.text == "MMMMMMMMMMMM" and c0.badge.text == "HÔTE · TOI" and c0.etat.text == tr("SALON_PAS_PRET")
		and c0.lion.material == c0.teinte and c0.teinte.get_shader_parameter("couleur_joueur") == palette[0] and c0.style.border_color == palette[0],
````

par :

````gdscript
	_check(root.content_scale_size == Vector2i(2000, 1125) and salon.cartes.size() == 6
		and salon.cartes.all(func(c: Dictionary) -> bool: return c.cadre.visible), "le salon est en 16:9, une carte par place (6)")
	_check(salon.cartes.all(func(c: Dictionary) -> bool: return c.pseudo is Label and c.pseudo.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED),
		"phase 7 (spec §8.2) : le pseudo de chaque carte, un Label jamais traduit de lui-même (un pseudo n'est pas une clé)")
	_check(c0.pseudo.text == "MMMMMMMMMMMM" and c0.badge.text == "HÔTE · TOI" and c0.etat.text == tr("SALON_PAS_PRET")
		and c0.lion.material == c0.teinte and c0.teinte.get_shader_parameter("couleur_joueur") == palette[0] and c0.style.border_color == palette[0],
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
			and hud.vignettes[0].badge.text == "TOI",
			"(%s) le HUD de la bataille : une vignette par joueur de la table, « TOI » sur celle de l'hôte" % essai)
		if essai == "absent":
			_check(not reseau.inscrits.has(7) and main.lions.size() == 1, "(absent) un joueur exclu n'a pas de lion")
````

par :

````gdscript
			and hud.vignettes[0].badge.text == "TOI",
			"(%s) le HUD de la bataille : une vignette par joueur de la table, « TOI » sur celle de l'hôte" % essai)
		_check(hud.vignettes.all(func(v: Dictionary) -> bool: return v.pseudo is Label and v.pseudo.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED),
			"(%s) phase 7 (spec §8.2) : les pseudos du HUD, des Label jamais traduits d'eux-mêmes (un pseudo n'est pas une clé)" % essai)
		if essai == "absent":
			_check(not reseau.inscrits.has(7) and main.lions.size() == 1, "(absent) un joueur exclu n'a pas de lion")
````

Dans `tests/smoke_test.gd`, remplacer :

````gdscript
			and resultats.etat.text == tr("SALON_ATTENTE_JOUEURS"),
			"l'écran Résultats de l'hôte en réseau : Retour au salon ; Bob parti, Revanche et Niveau suivant attendent deux joueurs")
		# Un hôte perdu (chez un client) : message, tout se fige ; M5 (revue finale phase 17) : la boucle du
		# vomi d'un joueur qui tenait Espace s'arrête
````

par :

````gdscript
			and resultats.etat.text == tr("SALON_ATTENTE_JOUEURS"),
			"l'écran Résultats de l'hôte en réseau : Retour au salon ; Bob parti, Revanche et Niveau suivant attendent deux joueurs")
		_check(resultats != null and resultats.lignes.size() == 2
			and resultats.lignes.all(func(l: Dictionary) -> bool: return l.pseudo is Label and l.pseudo.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED),
			"phase 7 (spec §8.2) : les pseudos de l'écran Résultats, des Label jamais traduits d'eux-mêmes")
		# Un hôte perdu (chez un client) : message, tout se fige ; M5 (revue finale phase 17) : la boucle du
		# vomi d'un joueur qui tenait Espace s'arrête
````

- [ ] **Step 2 : ils échouent (et les étiquettes sont déjà justes)**

```bash
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u5.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u5.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s5.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s5.log"; grep -c "✅" "$TMPDIR/s5.log"
```

Expected : `unitaires 1`, `❌ phase 7 : nettoyé aussi des caractères de mise en forme d'Unicode …`, `❌ un pseudo fait seulement de lettres vides et d'étiquettes retombe sur « Joueur N »`, `== 2 échec(s) ==` (« aucun RichTextLabel ni BBCode … » et l'étiquette du lion passent déjà : rien n'interprète un pseudo aujourd'hui, ces tests le gardent) ; smoke `0`, `== 0 échec(s) ==`, 470 ✅ (les étiquettes des cartes, du HUD et des Résultats sont déjà sans traduction automatique).

- [ ] **Step 3 : les caractères interdits**

Dans `Scripts/Reseau.gd`, remplacer :

````gdscript
## (`strip_escapes` ne va que jusqu'à U+001F) et C1, les caractères invisibles (espaces et joints de
## largeur nulle, U+FEFF) et les forçages de sens (RLO/LRO, isolats) qui casseraient la lecture ou
## la mise en page d'un pseudo hostile.
static func _code_point_interdit(c: int) -> bool:
	return c <= 0x1F or (c >= 0x7F and c <= 0x9F) \
		or (c >= 0x200B and c <= 0x200F) or c == 0x2028 or c == 0x2029 \
		or (c >= 0x202A and c <= 0x202E) or (c >= 0x2060 and c <= 0x206F) or c == 0xFEFF


````

par :

````gdscript
## (`strip_escapes` ne va que jusqu'à U+001F) et C1, les caractères invisibles (espaces et joints de
## largeur nulle, U+FEFF) et les forçages de sens (RLO/LRO, isolats) qui casseraient la lecture ou
## la mise en page d'un pseudo hostile. Phase 7 du jeu en ligne (spec §8.2) : aussi tous les autres
## caractères de mise en forme d'Unicode (catégorie Cf : trait d'union conditionnel U+00AD, marque de lettre
## arabe U+061C, séparateur mongol U+180E, ancres d'annotation U+FFF9 à U+FFFB, étiquettes U+E0000 à
## U+E007F…), le joint de graphèmes U+034F, les sélecteurs de variante mongols et ceux du plan 14, et les
## lettres vides du coréen (U+115F, U+1160, U+3164, U+FFA0) : de quoi faire un pseudo invisible.
static func _code_point_interdit(c: int) -> bool:
	return c <= 0x1F or (c >= 0x7F and c <= 0x9F) or c == 0xAD or c == 0x34F \
		or (c >= 0x600 and c <= 0x605) or c == 0x61C or c == 0x6DD or c == 0x70F or c == 0x890 or c == 0x891 or c == 0x8E2 \
		or c == 0x115F or c == 0x1160 or c == 0x17B4 or c == 0x17B5 or (c >= 0x180B and c <= 0x180F) \
		or (c >= 0x200B and c <= 0x200F) or (c >= 0x2028 and c <= 0x202E) or (c >= 0x2060 and c <= 0x206F) \
		or c == 0x3164 or c == 0xFEFF or c == 0xFFA0 or (c >= 0xFFF9 and c <= 0xFFFB) \
		or c == 0x110BD or c == 0x110CD or (c >= 0x13430 and c <= 0x1343F) or (c >= 0x1BCA0 and c <= 0x1BCA3) \
		or (c >= 0x1D173 and c <= 0x1D17A) or (c >= 0xE0000 and c <= 0xE0FFF)


````

- [ ] **Step 4 : les tests passent**

```bash
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u5.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u5.log"; grep -c "✅" "$TMPDIR/u5.log"
```

Expected : unitaires `0`, `PROTOCOLE 0.21 1188810746 (67 lignes)`, `== 0 échec(s) ==`, 567 ✅ ; le smoke, inchangé depuis le Step 2 (470 ✅).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Reseau.gd tests/unitaires.gd tests/smoke_test.gd
git commit -m "Pseudos : nettoyés aussi des caractères de mise en forme d'Unicode et des lettres vides ; jamais interprétés (aucun RichTextLabel, aucune étiquette de pseudo traduite d'elle-même), vérifié partout où un pseudo s'affiche

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 6 : les canaux non fiables du navigateur (`CORRECTIF_CANAUX`)

**Files:**
- Modify: `Scripts/TransportWebRTC.gd` (`CORRECTIF_CANAUX`, `_init`)
- Modify: `tests/unitaires.gd` (`_tester_transport_webrtc`)

**Interfaces:** `TransportWebRTC.CORRECTIF_CANAUX` (le texte JavaScript posé par `_init` sur le Web : `RTCPeerConnection.prototype.createDataChannel` lit `maxPacketLifetime` sous le nom `maxPacketLifeTime`, une fois par page).

- [ ] **Step 1 : le test qui échoue**

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	var pilote: Node = root.get_node("PiloteWeb")  # autoload : jamais nommé
	_check(not pilote.actif and not pilote.is_processing(), "le pilote du test de bout en bout est inerte hors de l'export Web pilote")
	# Vague finale (T4) : une commande mal formée (nom, nombre ou types d'arguments) est rejetée, retirée de
	# la file, sans bloquer celles qui suivent ; une commande bien formée qui ne peut pas encore s'exécuter
````

par :

````gdscript
	var pilote: Node = root.get_node("PiloteWeb")  # autoload : jamais nommé
	_check(not pilote.actif and not pilote.is_processing(), "le pilote du test de bout en bout est inerte hors de l'export Web pilote")
	# Phase 7 (spec §5) : les canaux non fiables du navigateur gardent un paquet DUREE_NON_FIABLE ms au plus. Le
	# navigateur ignore l'option `maxPacketLifetime` que leur donne Godot : le correctif la lui passe sous son nom
	# du standard, une fois par page, à la création du transport (vérifié dans le navigateur par le bout en bout)
	var correctif := TransportWebRTC.CORRECTIF_CANAUX
	_check(TransportWebRTC.DUREE_NON_FIABLE == 100 and correctif.contains("maxPacketLifeTime: options.maxPacketLifetime")
		and correctif.contains("delete options.maxPacketLifetime") and correctif.contains("if (p.lelionCanaux) return")
		and FileAccess.get_file_as_string("res://Scripts/TransportWebRTC.gd").contains("		JavaScriptBridge.eval(CORRECTIF_CANAUX, true)"),
		"les canaux non fiables du navigateur : un paquet perdu renvoyé 100 ms au plus (le correctif de l'option maxPacketLifetime de Godot, posé une fois par page)")
	# Vague finale (T4) : une commande mal formée (nom, nombre ou types d'arguments) est rejetée, retirée de
	# la file, sans bloquer celles qui suivent ; une commande bien formée qui ne peut pas encore s'exécuter
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd > "$TMPDIR/u6.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|Parse Error|== " "$TMPDIR/u6.log" | head -5
```

Expected : `unitaires 0` mais aucun ✅ : `SCRIPT ERROR: Parse Error: Cannot find member "CORRECTIF_CANAUX" in base "TransportWebRTC".` (la suite ne se compile pas).

- [ ] **Step 3 : le correctif**

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
## Canaux (spec §5) : les trois par défaut de `WebRTCMultiplayerPeer` (le fiable porte la poignée de
## main et la table du salon ; les non fiables, `unreliable_lifetime` DUREE_NON_FIABLE), plus un canal
## fiable ordonné, le canal 1 de `SceneMultiplayer` (`Reseau.CANAL_ORDONNE`, `Manche.CANAL_PEINTURE`).
## `?relais=1` dans l'adresse de la page : le relais TURN seulement (`iceTransportPolicy: "relay"`,
## spec §10, diagnostic de l'essai réel).
````

par :

````gdscript
## Canaux (spec §5) : les trois par défaut de `WebRTCMultiplayerPeer` (le fiable porte la poignée de
## main et la table du salon ; les non fiables, `unreliable_lifetime` DUREE_NON_FIABLE), plus un canal
## fiable ordonné, le canal 1 de `SceneMultiplayer` (`Reseau.CANAL_ORDONNE`, `Manche.CANAL_PEINTURE`). Les
## canaux non fiables ne le sont dans le navigateur que par CORRECTIF_CANAUX (posé à la création, une fois par
## page) : un paquet perdu s'y renvoie DUREE_NON_FIABLE ms au plus, puis il est abandonné.
## `?relais=1` dans l'adresse de la page : le relais TURN seulement (`iceTransportPolicy: "relay"`,
## spec §10, diagnostic de l'essai réel).
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
## Durée de vie d'un paquet non fiable (`unreliable_lifetime`), en ms (spec §5 : environ 100 ms).
const DUREE_NON_FIABLE := 100
## Les canaux en plus des trois par défaut : le canal 1 de `SceneMultiplayer`, fiable et ordonné.
const CANAUX := [MultiplayerPeer.TRANSFER_MODE_RELIABLE]
````

par :

````gdscript
## Durée de vie d'un paquet non fiable (`unreliable_lifetime`), en ms (spec §5 : environ 100 ms).
const DUREE_NON_FIABLE := 100
## Le correctif des canaux non fiables de l'export Web (Godot 4.7.2, phase 7) : `WebRTCMultiplayerPeer.add_peer`
## crée ses deux canaux non fiables avec l'option `maxPacketLifetime`, que les navigateurs ignorent (le nom
## du standard, dans `RTCDataChannelInit`, est `maxPacketLifeTime` : vérifié sous Chromium et Firefox, où ces
## canaux restaient fiables, chaque paquet perdu renvoyé jusqu'à son arrivée). `createDataChannel` lit
## désormais aussi l'option sous le nom de Godot ; posé une fois par page, avant toute connexion, sans effet
## là où WebRTC manque.
const CORRECTIF_CANAUX := "(() => { if (typeof RTCPeerConnection === 'undefined') return; const p = RTCPeerConnection.prototype; if (p.lelionCanaux) return; const creer = p.createDataChannel; p.createDataChannel = function (nom, options) { if (options && options.maxPacketLifetime !== undefined && options.maxPacketLifeTime === undefined) { options = Object.assign({}, options, { maxPacketLifeTime: options.maxPacketLifetime }); delete options.maxPacketLifetime; } return creer.call(this, nom, options); }; p.lelionCanaux = true; })();"
## Les canaux en plus des trois par défaut : le canal 1 de `SceneMultiplayer`, fiable et ordonné.
const CANAUX := [MultiplayerPeer.TRANSFER_MODE_RELIABLE]
````

Dans `Scripts/TransportWebRTC.gd`, remplacer :

````gdscript
func _init() -> void:
	if OS.has_feature("web"):
		relais = lire_relais(str(JavaScriptBridge.eval("window.location.search", true)))

````

par :

````gdscript
func _init() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(CORRECTIF_CANAUX, true)
		relais = lire_relais(str(JavaScriptBridge.eval("window.location.search", true)))

````

- [ ] **Step 4 : le test passe**

```bash
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u6.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u6.log"; grep -c "✅" "$TMPDIR/u6.log"
```

Expected : unitaires `0`, `PROTOCOLE 0.21 1188810746 (67 lignes)`, `== 0 échec(s) ==`, 568 ✅. Le navigateur le vérifie à la Task 7.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/TransportWebRTC.gd tests/unitaires.gd
git commit -m "WebRTC : les canaux non fiables le sont aussi dans le navigateur (un paquet perdu renvoyé 100 ms au plus) : l'option maxPacketLifetime que Godot leur donne, ignorée du navigateur, lui est passée sous son nom du standard

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 7 : le bout en bout élargi (l'exclusion, la rencontre, le gel du mobile, les canaux, `pageerror`)

**Files:**
- Modify: `Scripts/PiloteWeb.gd` (`rencontrer`, `TICKS_RENCONTRE`, `ZONE_MILIEU`, `HAUTEUR_RENCONTRE`, `ZONE_HAUTEUR`, `_en_passe`, `_rencontrer`, `_tenir`, `_durees_canaux` ; l'état : `canaux`, les croix du salon, le bilan de la manche)
- Modify: `tests/web/bout_en_bout.spec.js` (`ecouter`, `erreurs`, `EXCLU`, `DECONNECTE` ; `@manche` : canaux, exclusion, rencontre, 14 s ; `@mobile` : le gel)
- Modify: `tests/unitaires.gd` (`_tester_transport_webrtc` : `rencontrer` dans les commandes du pilote)

**Interfaces:**
- `PiloteWeb` : commande `["rencontrer"]` ; état : `canaux: [ms, ms]` (vide hors d'une session WebRTC), `salon.table[i].croix: [x, y]` (px CSS, vide sans croix), `manche.bilan: {etourdissements: [...], chocs: [...]}` (vide avant la fin).
- `bout_en_bout.spec.js` : `function ecouter(page, lignes)` (console et `pageerror`).

- [ ] **Step 1 : le test qui échoue**

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
// (Scripts/PiloteWeb.gd) : des commandes poussées dans window.lelionPilote.commandes, son état relu
// dans window.lelionPilote.etat, par les vrais écrans du jeu (titre, En ligne, salon, manche). Le mobile,
// lui, joue au doigt : de vrais touchers de la page, aux places que l'état du pilote donne.
import { devices, expect, test } from "@playwright/test";

const ALPHABET = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;
const HOTE_PARTI = "L'hôte a quitté la partie";

/**
 * Le bruit connu des consoles des pages : des lignes d'erreur qui ne disent rien du jeu (aucune pour
 * l'instant). Toute autre ligne qui contient « SCRIPT ERROR » ou « ERROR: » (une erreur de script, un
 * push_error, une erreur du moteur) fait échouer le test.
 */
const BRUIT_CONNU = [];
````

par :

````js
// (Scripts/PiloteWeb.gd) : des commandes poussées dans window.lelionPilote.commandes, son état relu
// dans window.lelionPilote.etat, par les vrais écrans du jeu (titre, En ligne, salon, manche). Le mobile,
// lui, joue au doigt : de vrais touchers de la page, aux places que l'état du pilote donne ; l'hôte exclut un
// joueur d'un vrai clic sur la croix de sa carte (phase 7).
import { devices, expect, test } from "@playwright/test";

const ALPHABET = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;
const HOTE_PARTI = "L'hôte a quitté la partie";
const EXCLU = "L'hôte t'a exclu de la partie.";
const DECONNECTE = "Tu as été déconnecté";

/**
 * Le bruit connu des consoles des pages : des lignes d'erreur qui ne disent rien du jeu (aucune pour
 * l'instant). Toute autre ligne qui contient « SCRIPT ERROR » ou « ERROR: » (une erreur de script, un
 * push_error, une erreur du moteur), une exception JavaScript de la page (« PAGEERROR », phase 7) ou un client
 * que l'hôte limite (« l'excédent est jeté » : un joueur ne doit jamais l'être) fait échouer le test.
 */
const BRUIT_CONNU = [];
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
function erreurs(consoles) {
	return consoles.map((lignes) =>
		lignes.filter((ligne) => /SCRIPT ERROR|ERROR:/.test(ligne) && !BRUIT_CONNU.some((bruit) => bruit.test(ligne))),
	);
}

````

par :

````js
function erreurs(consoles) {
	return consoles.map((lignes) =>
		lignes.filter((ligne) => /SCRIPT ERROR|ERROR:|PAGEERROR|l'excédent est jeté/.test(ligne) && !BRUIT_CONNU.some((bruit) => bruit.test(ligne))),
	);
}

/** Note dans `lignes` la console de `page` et ses exceptions JavaScript (une erreur que la console ne dit pas). */
function ecouter(page, lignes) {
	page.on("console", (message) => lignes.push(message.text()));
	page.on("pageerror", (erreur) => lignes.push(`PAGEERROR ${erreur.message}`));
}

````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
	const lignes = [];
	consoles?.push(lignes);
	page.on("console", (message) => lignes.push(message.text()));
	await page.goto(chemin);
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
````

par :

````js
	const lignes = [];
	consoles?.push(lignes);
	ecouter(page, lignes);
	await page.goto(chemin);
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
}

test("une manche à trois pages par le lien d'invitation : même empreinte partout, départ de l'hôte vu @manche", async ({ browser }) => {
	const consoles = [];
	const hote = await ouvrir(browser, "/", consoles);
	await commander(hote, "duree", 10);
	await commander(hote, "creer", "Hote");
	const salle = await attendre(hote, (e) => e.scene === "Salon" && ALPHABET.test(e.code), "l'hôte a sa salle");
````

par :

````js
}

test("une manche à trois pages par le lien d'invitation, un joueur exclu qui revient, les lions qui se croisent : même empreinte partout, départ de l'hôte vu @manche", async ({ browser }) => {
	const consoles = [];
	const hote = await ouvrir(browser, "/", consoles);
	await commander(hote, "duree", 14);
	await commander(hote, "creer", "Hote");
	const salle = await attendre(hote, (e) => e.scene === "Salon" && ALPHABET.test(e.code), "l'hôte a sa salle");
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
		expect(accueil.ecran.code).toBe(`${code.slice(0, 3)}-${code.slice(3)}`);
		expect(accueil.en_ligne).toBe(false);
		await commander(page, "duree", 10);
		await commander(page, "rejoindre", pseudo);
		await attendre(page, (e) => e.scene === "Salon", `${pseudo} arrive au salon (canal WebRTC ouvert, poignée de main faite)`);
````

par :

````js
		expect(accueil.ecran.code).toBe(`${code.slice(0, 3)}-${code.slice(3)}`);
		expect(accueil.en_ligne).toBe(false);
		await commander(page, "duree", 14);
		await commander(page, "rejoindre", pseudo);
		await attendre(page, (e) => e.scene === "Salon", `${pseudo} arrive au salon (canal WebRTC ouvert, poignée de main faite)`);
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
	for (const page of pages) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna,Bruno", "la même table du salon partout");
	}

````

par :

````js
	for (const page of pages) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna,Bruno", "la même table du salon partout");
	}
	// Spec §5 : les canaux non fiables gardent un paquet 100 ms au plus (le correctif de TransportWebRTC : sans lui,
	// le navigateur ignore l'option de Godot et ces canaux sont fiables)
	for (const page of pages) expect((await etat(page)).canaux, "les canaux non fiables, 100 ms").toEqual([100, 100]);

	// L'exclusion (spec §8.2), d'un vrai clic de l'hôte sur la croix de la carte de Bruno : Bruno lit « L'hôte t'a
	// exclu de la partie. » sur l'écran En ligne, sa carte se libère partout ; il revient avec le code, en nouvel
	// arrivant (rien ne l'identifie)
	const bruno = invites[1];
	const salon = (await etat(hote)).salon;
	expect(salon.table[0].croix, "pas de croix sur la carte de l'hôte").toEqual([]);
	expect(salon.table[2].croix.length, "la croix de la carte de Bruno, chez l'hôte").toBe(2);
	expect((await etat(invites[0])).salon.table.every((f) => f.croix.length === 0), "aucune croix chez un client").toBe(true);
	await hote.mouse.click(salon.table[2].croix[0], salon.table[2].croix[1]);
	// Sous Xvfb, sans gestionnaire de fenêtres, le clic monte la fenêtre de l'hôte au-dessus des autres : Firefox
	// ne dessine plus celle d'Anna, entièrement couverte, et son jeu s'y fige (mesuré : 2 images en 3 s). Les
	// fenêtres des invités remontent, dans leur ordre.
	for (const page of invites) await page.bringToFront();
	const exclu = await attendre(bruno, (e) => e.scene === "EcranEnLigne" && e.pertes.includes(EXCLU), "Bruno, exclu, revient à l'écran En ligne");
	expect(exclu.ecran.message).toBe(EXCLU);
	for (const page of [hote, invites[0]]) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna", "la carte de Bruno se libère partout");
	}
	await commander(bruno, "rejoindre", "Bruno", code);
	await attendre(bruno, (e) => e.scene === "Salon", "Bruno revient avec le code");
	for (const page of pages) {
		await attendre(page, (e) => e.salon?.table.map((f) => f.pseudo).join(",") === "Hote,Anna,Bruno", "de nouveau la même table partout");
	}

````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
	// mesuré, 1 à 7 cellules sans retour), peint au retour.
	for (const page of pages) await commander(page, "peindre", 1);
	for (const page of pages) await attendre(page, (e) => e.manche?.en_cours === true, "la manche commence partout", 60_000);

	const fins = [];
	for (const page of pages) fins.push(await attendre(page, (e) => e.empreinte !== "", "la manche de 10 s finit partout", 60_000));
	const empreintes = consoles.map((lignes) => lignes.find((l) => l.startsWith("EMPREINTE ")));
	expect(empreintes[0]).toBeTruthy();
````

par :

````js
	// mesuré, 1 à 7 cellules sans retour), peint au retour.
	for (const page of pages) await commander(page, "peindre", 1);
	// Puis la rencontre (phase 7, la note de la revue de la phase 4) : chaque lion va au milieu de l'écran en
	// vomissant ; ils s'y heurtent et leurs gerbes les étourdissent, ce que l'hôte décide et que chaque page suit
	for (const page of pages) await commander(page, "rencontrer");
	for (const page of pages) await attendre(page, (e) => e.manche?.en_cours === true, "la manche commence partout", 60_000);

	const fins = [];
	for (const page of pages) fins.push(await attendre(page, (e) => e.empreinte !== "", "la manche de 14 s finit partout", 60_000));
	const empreintes = consoles.map((lignes) => lignes.find((l) => l.startsWith("EMPREINTE ")));
	expect(empreintes[0]).toBeTruthy();
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
	// Les scores du territoire : à l'index 0 les cellules de personne, puis un par joueur (l'hôte, Anna, Bruno).
	for (const fin of fins) expect(fin.scores.slice(1, 4).every((cellules) => cellules > 0), `chacun a peint : ${fin.scores} (${cadences})`).toBe(true);

	const depart = Date.now();
````

par :

````js
	// Les scores du territoire : à l'index 0 les cellules de personne, puis un par joueur (l'hôte, Anna, Bruno).
	for (const fin of fins) expect(fin.scores.slice(1, 4).every((cellules) => cellules > 0), `chacun a peint : ${fin.scores} (${cadences})`).toBe(true);
	// La rencontre : des chocs (et des étourdissements, comptés), le bilan de l'hôte le même sur chaque page
	const bilans = fins.map((fin) => fin.manche.bilan);
	const somme = (valeurs) => valeurs.reduce((a, b) => a + b, 0);
	console.log(`Rencontre : étourdissements ${bilans[0].etourdissements}, chocs ${bilans[0].chocs}`);
	expect(bilans[1]).toEqual(bilans[0]);
	expect(bilans[2]).toEqual(bilans[0]);
	expect(somme(bilans[0].chocs), `les lions se sont heurtés : ${JSON.stringify(bilans[0])}`).toBeGreaterThan(0);

	const depart = Date.now();
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
	const page = await contexte.newPage();
	const lignes = [];
	page.on("console", (message) => lignes.push(message.text()));
	await page.goto("/");
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
````

par :

````js
	const page = await contexte.newPage();
	const lignes = [];
	ecouter(page, lignes);
	await page.goto("/");
	await page.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
	const lignes = [];
	consoles.push(lignes);
	mobile.on("console", (message) => lignes.push(message.text()));
	await mobile.goto(`/?salle=${salle.code}`);
	await mobile.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
````

par :

````js
	const lignes = [];
	consoles.push(lignes);
	ecouter(mobile, lignes);
	await mobile.goto(`/?salle=${salle.code}`);
	await mobile.waitForFunction(() => window.lelionPilote !== undefined, null, { timeout: 60_000 });
````

Dans `tests/web/bout_en_bout.spec.js`, remplacer :

````js
	// Les scores du territoire : à l'index 0 les cellules de personne, puis l'hôte, puis le mobile
	expect(fins[1].scores[2], `le mobile a peint au doigt : ${fins[1].scores}`).toBeGreaterThan(0);
	expect(erreurs(consoles), "aucune erreur dans les consoles des deux pages").toEqual([[], []]);
});
````

par :

````js
	// Les scores du territoire : à l'index 0 les cellules de personne, puis l'hôte, puis le mobile
	expect(fins[1].scores[2], `le mobile a peint au doigt : ${fins[1].scores}`).toBeGreaterThan(0);

	// Un téléphone verrouillé (ou un onglet caché, spec §5) : la page ne rend plus la main, plus aucune image ; 10 s
	// plus tard, l'hôte déclare le mobile parti. À son retour, « Tu as été déconnecté », puis l'écran En ligne
	await mobile.evaluate(() => {
		const fin = Date.now() + 12_000;
		while (Date.now() < fin);
	});
	await attendre(mobile, (e) => e.pertes.includes(DECONNECTE), "au retour, « Tu as été déconnecté »", 15_000);
	const retour = await attendre(mobile, (e) => e.scene === "EcranEnLigne", "puis l'écran En ligne", 15_000);
	expect(retour.ecran.message).toBe(DECONNECTE);
	expect(retour.pertes, "pas « L'hôte a quitté la partie »").not.toContain(HOTE_PARTI);
	expect(erreurs(consoles), "aucune erreur dans les consoles des deux pages").toEqual([[], []]);
});
````

Dans `tests/unitaires.gd`, remplacer :

````gdscript
	var duree_avant: float = ReglesBataille.duree_manche
	pilote._commandes = [["duree", "dix"], ["duree"], ["peindre"], ["peindre", 1, 2], ["peindre", 0], ["peindre", 0.0], ["duree", -3.0], ["creer", 7],
		["rejoindre"], ["pret", true], 5, [], ["voler"], ["pret"], ["quitter"]]
	pilote._vider_commandes()
	_check(pilote._commandes == [["pret"], ["quitter"]] and ReglesBataille.duree_manche == duree_avant,
````

par :

````gdscript
	var duree_avant: float = ReglesBataille.duree_manche
	pilote._commandes = [["duree", "dix"], ["duree"], ["peindre"], ["peindre", 1, 2], ["peindre", 0], ["peindre", 0.0], ["duree", -3.0], ["creer", 7],
		["rejoindre"], ["pret", true], ["rencontrer", 1.0], 5, [], ["voler"], ["pret"], ["quitter"]]
	pilote._vider_commandes()
	_check(pilote._commandes == [["pret"], ["quitter"]] and ReglesBataille.duree_manche == duree_avant,
````

- [ ] **Step 2 : il échoue**

```bash
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u7.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/u7.log"
mkdir -p export/web-pilote
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep7.log" 2>&1; echo "export pilote $?"
timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion7-modules-signalisation:/depot/signalisation/node_modules -v lelion7-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test --project=chromium' > "$TMPDIR/e2e7.log" 2>&1; echo "bout en bout $?"; grep -E "✓|✘|Error:|passed|failed" "$TMPDIR/e2e7.log" | head -8
```

Expected : `unitaires 0`, `== 0 échec(s) ==`, 568 ✅ (une commande `rencontrer` avec un argument est rejetée, connue ou non) ; `export pilote 0` ; `bout en bout 1`, `✘ … [chromium] … @manche`, `Error: les canaux non fiables, 100 ms` (`Received: undefined` : le pilote ne les donne pas encore).

- [ ] **Step 3 : le pilote**

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
##   ticks physiques (comptés en temps de jeu), un aller dans le sens `sens` (1 : à droite, -1 : à gauche)
##   puis le retour ;
## - `["quitter"]` : retour au titre (qui quitte le réseau : l'adieu, spec §5).
## Une commande mal formée (nom inconnu, nombre ou types d'arguments, `erreur_commande`) est rejetée
````

par :

````gdscript
##   ticks physiques (comptés en temps de jeu), un aller dans le sens `sens` (1 : à droite, -1 : à gauche)
##   puis le retour ;
## - `["rencontrer"]` : en manche, une fois la passe de ce poste finie, son lion va au milieu de l'écran en
##   vomissant, TICKS_RENCONTRE ticks : les lions des pages s'y croisent (chocs, gerbes qui étourdissent) ;
## - `["quitter"]` : retour au titre (qui quitte le réseau : l'adieu, spec §5).
## Une commande mal formée (nom inconnu, nombre ou types d'arguments, `erreur_commande`) est rejetée
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
## Pour un client mobile (phase 6), qui joue au doigt (de vrais touchers de la page, jamais des commandes),
## l'état donne aussi, en px CSS de la page, ce qu'un toucher vise : Rejoindre, les boutons tactiles du
## salon et de la manche, le stick ; et la hauteur où peindre.
##
## Autoload : les tests `--script` ne le nomment pas.
````

par :

````gdscript
## Pour un client mobile (phase 6), qui joue au doigt (de vrais touchers de la page, jamais des commandes),
## l'état donne aussi, en px CSS de la page, ce qu'un toucher vise : Rejoindre, les boutons tactiles du
## salon et de la manche, le stick ; et la hauteur où peindre. Phase 7 : chez l'hôte, la croix d'exclusion de
## chaque carte (ce qu'un clic vise) ; sur chaque poste en session, la durée de vie (ms) des deux canaux non
## fiables de sa première connexion WebRTC ; une manche finie, les étourdissements et les chocs de son bilan.
##
## Autoload : les tests `--script` ne le nomment pas.
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
const TICKS_PASSE := 150
const TICKS_ALLER := 75
## Les arguments de chaque commande, leurs types dans l'ordre (les nombres arrivent du JSON en flottants),
## et combien sont facultatifs à la fin (le code de `rejoindre`).
const ARGUMENTS := {"duree": [TYPE_FLOAT], "creer": [TYPE_STRING], "rejoindre": [TYPE_STRING, TYPE_STRING],
	"pret": [], "demarrer": [], "peindre": [TYPE_FLOAT], "quitter": []}
const FACULTATIFS := {"rejoindre": 1}

````

par :

````gdscript
const TICKS_PASSE := 150
const TICKS_ALLER := 75
## La rencontre, en ticks physiques (2,5 s de jeu), et la demi-largeur du milieu de l'écran où le lion
## s'arrête, en px : partis espacés d'un tiers de l'écran, les lions des côtés y arrivent en 90 ticks environ.
## Elle se fait HAUTEUR_RENCONTRE px au-dessus de la hauteur de peinture : la gerbe, qui tombe de 190 px, n'y
## atteint plus les toits, et la rencontre ne repeint rien (les cellules de la passe de chacun restent à
## chacun) ; la tolérance de cette hauteur, en px.
const TICKS_RENCONTRE := 150
const ZONE_MILIEU := 20.0
const HAUTEUR_RENCONTRE := 200.0
const ZONE_HAUTEUR := 10.0
## Les arguments de chaque commande, leurs types dans l'ordre (les nombres arrivent du JSON en flottants),
## et combien sont facultatifs à la fin (le code de `rejoindre`).
const ARGUMENTS := {"duree": [TYPE_FLOAT], "creer": [TYPE_STRING], "rejoindre": [TYPE_STRING, TYPE_STRING],
	"pret": [], "demarrer": [], "peindre": [TYPE_FLOAT], "rencontrer": [], "quitter": []}
const FACULTATIFS := {"rejoindre": 1}

````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
var _scores: Array = []
## La passe de ce poste (`_peindre`), pour la page et ses messages d'échec : ticks physiques de la
## descente, puis de la peinture, comptés pendant qu'elle se fait ; vide avant.
var _passe := {}


````

par :

````gdscript
var _scores: Array = []
## La passe de ce poste (`_peindre`), pour la page et ses messages d'échec : ticks physiques de la
## descente, puis de la peinture, puis de la rencontre (`_rencontrer`), comptés pendant qu'elles se font ;
## vide avant.
var _passe := {}
## Vrai pendant une passe ou une rencontre : la suivante attend.
var _en_passe := false


````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
		"code": Reseau.code_partie, "pertes": _pertes, "echecs": _echecs, "empreinte": _empreinte, "scores": _scores,
		"fps": Engine.get_frames_per_second(), "passe": _passe, "mobile": Parametres.mobile, "voile": Parametres.voile.visible,
		"images": Engine.get_process_frames()}
	if nom == "EcranEnLigne":
		var rejoindre: Rect2 = scene.bouton_rejoindre.get_global_rect()
````

par :

````gdscript
		"code": Reseau.code_partie, "pertes": _pertes, "echecs": _echecs, "empreinte": _empreinte, "scores": _scores,
		"fps": Engine.get_frames_per_second(), "passe": _passe, "mobile": Parametres.mobile, "voile": Parametres.voile.visible,
		"images": Engine.get_process_frames(), "canaux": _durees_canaux()}
	if nom == "EcranEnLigne":
		var rejoindre: Rect2 = scene.bouton_rejoindre.get_global_rect()
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
	elif nom == "Salon":
		var table: Array = Reseau.table_salon.map(func(f: Dictionary) -> Dictionary:
			return {"pseudo": f.pseudo, "pret": f.pret, "couleur": f.couleur.to_html(false)})
		var bouton: Button = scene.bouton_copier
		var tactile: CanvasLayer = scene.controles_tactiles
````

par :

````gdscript
	elif nom == "Salon":
		var table: Array = Reseau.table_salon.map(func(f: Dictionary) -> Dictionary:
			var croix: Button = scene.cartes[f.index].croix
			return {"pseudo": f.pseudo, "pret": f.pret, "couleur": f.couleur.to_html(false),
				"croix": _css(croix.get_global_rect().get_center()) if croix.is_visible_in_tree() else []})
		var bouton: Button = scene.bouton_copier
		var tactile: CanvasLayer = scene.controles_tactiles
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
		var tactile: CanvasLayer = scene.get_node("ControlesTactiles")
		var stick: Control = tactile.joystick
		e["manche"] = {"barriere": manche.barriere, "en_cours": GameState.pret and GameState.partie_en_cours, "finie": manche.finie,
			"temps": GameState.temps_ecoule, "lion": [] if scene.lion == null else [scene.lion.position.x, scene.lion.position.y],
			"cible": _hauteur_peinture(scene),
````

par :

````gdscript
		var tactile: CanvasLayer = scene.get_node("ControlesTactiles")
		var stick: Control = tactile.joystick
		var bilan: BilanManche = manche.bilan
		e["manche"] = {"barriere": manche.barriere, "en_cours": GameState.pret and GameState.partie_en_cours, "finie": manche.finie,
			"bilan": {} if bilan == null else {"etourdissements": Array(bilan.etourdissements), "chocs": Array(bilan.chocs)},
			"temps": GameState.temps_ecoule, "lion": [] if scene.lion == null else [scene.lion.position.x, scene.lion.position.y],
			"cible": _hauteur_peinture(scene),
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
				"rayon": _css(Vector2(stick.rayon, 0))[0] - _css(Vector2.ZERO)[0]}}
	return e


````

par :

````gdscript
				"rayon": _css(Vector2(stick.rayon, 0))[0] - _css(Vector2.ZERO)[0]}}
	return e


## La durée de vie (ms) des deux canaux non fiables (le 2 et le 3 de `WebRTCMultiplayerPeer`) de la première
## connexion WebRTC de ce poste en session, telle que le navigateur la donne (`maxPacketLifeTime` : 0 quand il
## n'en a pas, le canal fiable) ; vide hors d'une session WebRTC.
func _durees_canaux() -> Array:
	var pair := multiplayer.multiplayer_peer as WebRTCMultiplayerPeer
	if pair == null:
		return []
	for id in multiplayer.get_peers():
		if pair.has_peer(id):
			var canaux: Array = pair.get_peer(id).get("channels", [])
			if canaux.size() >= 3:
				return [(canaux[1] as WebRTCDataChannel).get_max_packet_life_time(), (canaux[2] as WebRTCDataChannel).get_max_packet_life_time()]
	return []


````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
				return false
			scene.demarrer()
		"peindre":
			if nom != "Main" or not GameState.pret or scene.lion == null:
				return false
			_peindre(scene, int(commande[1]))
		"quitter":
			get_tree().change_scene_to_file(SCENE_TITRE)
````

par :

````gdscript
				return false
			scene.demarrer()
		"peindre", "rencontrer":
			if nom != "Main" or not GameState.pret or scene.lion == null or _en_passe:
				return false
			if commande[0] == "peindre":
				_peindre(scene, int(commande[1]))
			else:
				_rencontrer(scene)
		"quitter":
			get_tree().change_scene_to_file(SCENE_TITRE)
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
## bord arrête (sa gerbe, qui tombe devant lui, y sort de la ville) peint au retour.
func _peindre(main: Node, sens: int) -> void:
	var cible := _hauteur_peinture(main)
	_passe = {"descente": 0}
````

par :

````gdscript
## bord arrête (sa gerbe, qui tombe devant lui, y sort de la ville) peint au retour.
func _peindre(main: Node, sens: int) -> void:
	_en_passe = true
	var cible := _hauteur_peinture(main)
	_passe = {"descente": 0}
````

Dans `Scripts/PiloteWeb.gd`, remplacer :

````gdscript
	Input.action_release("deplacer_bas")
	Input.action_release("vomir")


````

par :

````gdscript
	Input.action_release("deplacer_bas")
	Input.action_release("vomir")
	_en_passe = false


## La rencontre du lion de ce poste dans la scène de jeu `main`, en ticks physiques (phase 7) : il va au milieu
## de l'écran (à ZONE_MILIEU px près), HAUTEUR_RENCONTRE px au-dessus de la hauteur de peinture (à ZONE_HAUTEUR
## px près), en vomissant, TICKS_RENCONTRE ticks ; la fin de la manche l'arrête. Les lions des autres pages y
## vont aussi : ils s'y heurtent, et leurs gerbes, face à face, les étourdissent.
func _rencontrer(main: Node) -> void:
	_en_passe = true
	var cible := _hauteur_peinture(main) - HAUTEUR_RENCONTRE
	var milieu: float = main.get_viewport().get_visible_rect().size.x / 2.0 - Lion.CENTRE.x
	_passe["rencontre"] = 0
	Input.action_press("vomir")
	while _en_manche(main) and _passe["rencontre"] < TICKS_RENCONTRE:
		var ici: Vector2 = main.lion.position
		_tenir("deplacer_droite", ici.x < milieu - ZONE_MILIEU)
		_tenir("deplacer_gauche", ici.x > milieu + ZONE_MILIEU)
		_tenir("deplacer_haut", ici.y > cible + ZONE_HAUTEUR)
		_tenir("deplacer_bas", ici.y < cible - ZONE_HAUTEUR)
		await get_tree().physics_frame
		_passe["rencontre"] += 1
	for action: String in ["deplacer_droite", "deplacer_gauche", "deplacer_haut", "deplacer_bas", "vomir"]:
		Input.action_release(action)
	_en_passe = false


## L'action `action` tenue (`tenue`) ou relâchée, comme une touche.
static func _tenir(action: String, tenue: bool) -> void:
	if tenue:
		Input.action_press(action)
	else:
		Input.action_release(action)


````

- [ ] **Step 4 : les tests passent**

```bash
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u7.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u7.log"; grep -c "✅" "$TMPDIR/u7.log"
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep7.log" 2>&1; echo "export pilote $?"
SECONDS=0; timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion7-modules-signalisation:/depot/signalisation/node_modules -v lelion7-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test' > "$TMPDIR/e2e7.log" 2>&1; echo "bout en bout $? en ${SECONDS} s"; grep -E "✓|✘|passed|failed|Fin de manche|Rencontre|Départ" "$TMPDIR/e2e7.log"
```

Expected : unitaires `0`, `== 0 échec(s) ==`, 568 ✅ ; `export pilote 0` ; `bout en bout 0`, `4 passed` (mesuré 132 à 141 s : la manche à trois pages 42 s sous Chromium, 31 s sous Firefox, le mobile 43 s) ; une ligne `Rencontre : étourdissements …, chocs …` par navigateur (mesuré : 1 à 2 étourdissements, 6 à 14 chocs), `Départ de l'hôte vu par les deux autres en … ms` (275 à 667 ms mesurés). Un `✘` : son message dit l'étape (l'exclusion, la rencontre, le gel) ; sous Firefox, un invité figé après le clic de l'exclusion est l'occlusion de Xvfb (écart 9).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/PiloteWeb.gd tests/web/bout_en_bout.spec.js tests/unitaires.gd
git commit -m "Bout en bout : l'exclusion d'un vrai clic sur la croix (l'exclu revient avec le code), les lions qui se croisent (chocs, étourdissements, le même bilan partout), le mobile revenu d'un gel (« Tu as été déconnecté »), les canaux non fiables à 100 ms, les exceptions JavaScript des pages

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 8 : le README « Jouer en ligne », la fiche de l'essai réel, la spec telle que construite

**Files:**
- Modify: `README.md` (la section « Jouer en ligne », en français ; le renvoi depuis « Multiplayer » ; `LimiteDebit` dans la disposition du projet ; le bout en bout)
- Create: `docs/essai-en-ligne.md`
- Modify: `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§5 Canaux et Onglet caché, §8.2, §10)

**Interfaces:** aucune.

- [ ] **Step 1 : le README**

Dans `README.md`, remplacer :

````markdown
In the lobby, the arrows pick a color and **READY** gets ready; in the round, the stick and **PUKE**; the
Results screen and the online pause menu have finger-sized buttons. Held upright, a phone shows « Turn
your phone sideways » over the game, which keeps running.
From the editor (`godot .`), desktop builds play over ENet instead: **Multiplayer** opens the Online
screen, where one player creates a game and the others join it with the host's address as the code: the host's local IP
````

par :

````markdown
In the lobby, the arrows pick a color and **READY** gets ready; in the round, the stick and **PUKE**; the
Results screen and the online pause menu have finger-sized buttons. Held upright, a phone shows « Turn
your phone sideways » over the game, which keeps running. The host can remove a player from the lobby (the
cross on their card). How to host, invite and join, what to keep in mind (the host's tab, privacy) and what
each message means: [Jouer en ligne](#jouer-en-ligne), below, in French.
From the editor (`godot .`), desktop builds play over ENet instead: **Multiplayer** opens the Online
screen, where one player creates a game and the others join it with the host's address as the code: the host's local IP
````

Dans `README.md`, remplacer :

````markdown
Ready-made Windows, macOS and Linux builds of the LAN version are on
[LeLion-multi's releases](https://github.com/w3cdotorg/LeLion-multi/releases/latest) (version 0.19).

## Running the game
````

par :

````markdown
Ready-made Windows, macOS and Linux builds of the LAN version are on
[LeLion-multi's releases](https://github.com/w3cdotorg/LeLion-multi/releases/latest) (version 0.19).

## Jouer en ligne

Le jeu en ligne se joue dans le navigateur, sans rien installer, de 2 à 6 joueurs, chacun chez soi. Il
sera publié sur <https://w3cdotorg.github.io/LeLion-web/> avec sa signalisation (le déploiement est la
prochaine étape) ; d'ici là, il se joue en local, comme le décrit la section précédente.

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

**Vie privée** : aucun compte, aucun serveur de jeu ; seuls ton pseudo et tes réglages sont gardés, dans
ton navigateur. Cloudflare, qui fait tourner le service de connexion (un Worker), voit l'adresse IP de
chaque joueur le temps d'entrer dans la partie : le service s'en sert pour limiter les créations et les
arrivées par minute, sans l'écrire dans ses journaux. Ensuite les navigateurs se parlent directement
(WebRTC) : l'hôte et chaque joueur voient l'adresse IP l'un de l'autre, sauf quand la
connexion passe par le relais de Cloudflare (TURN : les réseaux trop fermés, ou `?relais=1` ajouté au
lien, un réglage de diagnostic qui l'impose). Le pseudo des autres ne s'affiche que comme du texte : ni
mise en forme, ni caractères invisibles.

**Dépannage**, message par message :

| Message | Ce qui se passe | Que faire |
|---|---|---|
| « Un code fait 6 caractères (ex. K7Q-2XM). » | Le code tapé n'a pas 6 caractères de l'alphabet du jeu. | Recopie-le, ou ouvre le lien. |
| « Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM). » | Un caractère qu'on confond s'est glissé dans le code. | Relis-le : ce sont sans doute un Q, un D, un 7 ou un 2. |
| « Aucune partie avec ce code. » | La partie n'existe pas, ou plus (l'hôte est parti, la salle a fermé). | Demande un nouveau lien à l'hôte. |
| « Service de connexion indisponible, réessaie dans un instant. » | Le service de connexion ne répond pas, ou refuse pour un moment (trop de tentatives depuis la même adresse IP). | Réessaie dans une minute. |
| « Trop de parties en ce moment, réessaie plus tard. » | Le quota gratuit du service de connexion est atteint pour aujourd'hui. | Réessaie plus tard (le lendemain au pire). |
| « Connexion impossible avec l'hôte (réseau trop restrictif ?) » | Les deux navigateurs n'ont pas pu se relier en 15 s. | Réessaie ; sinon change de réseau (la 4G plutôt qu'un Wi-Fi d'entreprise ou d'école), ou ajoute `&relais=1` au lien. |
| « Version différente de l'hôte (…) » | L'hôte et toi n'avez pas la même version du jeu. | Recharge la page (l'un des deux a une ancienne version en cache). |
| « La partie est complète. » | Six joueurs au plus (ou les places que l'hôte a choisies). | Attends qu'une place se libère. |
| « Une manche est en cours : réessaie à la fin. » | On n'arrive pas en pleine manche. | Rejoins quand l'hôte revient au salon. |
| « L'hôte t'a exclu de la partie. » | L'hôte t'a retiré du salon. | Vois avec lui. |
| « Exclu : ta partie a mis trop de temps à charger. » | Ta manche n'a pas fini de charger à temps (20 s) : la partie est partie sans toi. | Rejoins au salon suivant ; ferme les autres onglets sur un appareil lent. |
| « L'hôte a quitté la partie » | L'hôte est parti, ou son onglet est caché depuis 10 s. | Attends son nouveau lien. |
| « Tu as été déconnecté » | Ton onglet était caché (ou ton téléphone verrouillé) plus de 10 s : l'hôte t'a déclaré parti. | Rouvre le lien. |
| « Salle expirée : crée une nouvelle partie pour inviter » (hôte) | Une salle vit 4 h : la partie continue, mais plus personne ne peut arriver. | Crée une nouvelle partie pour inviter. |
| « Invitations coupées : crée une nouvelle partie pour inviter » (hôte) | Le lien avec le service de connexion s'est coupé : la partie continue, sans nouvelles arrivées. | Crée une nouvelle partie pour inviter. |

Pour l'essai réel, à plusieurs foyers et sur téléphone : [docs/essai-en-ligne.md](docs/essai-en-ligne.md).

## Running the game
````

Dans `README.md`, remplacer :

````markdown
            pure logic: Joueur (a player), Commandes (inputs), Regles / ReglesSolo / ReglesBataille (rules of each
            mode), Territoire (cell ownership), Peinture (deterministic stamps), EtatLion, InterpolationLion and
            PredictionLocale (lions over the network), BilanManche (end of a round), PlacementPseudos; the lion's
            parts DeplacementLion, PareChocs, GerbeLion; Pilote (attract-mode autopilot)
Shaders/    Ville.gdshader (paint mask on the skyline), Lion.gdshader (mane tint), Crt.gdshader (optional CRT filter)
````

par :

````markdown
            pure logic: Joueur (a player), Commandes (inputs), Regles / ReglesSolo / ReglesBataille (rules of each
            mode), Territoire (cell ownership), Peinture (deterministic stamps), EtatLion, InterpolationLion and
            PredictionLocale (lions over the network), BilanManche (end of a round), PlacementPseudos, LimiteDebit
            (the host's rate limit on each client); the lion's
            parts DeplacementLion, PareChocs, GerbeLion; Pilote (attract-mode autopilot)
Shaders/    Ville.gdshader (paint mask on the skyline), Lion.gdshader (mane tint), Crt.gdshader (optional CRT filter)
````

Dans `README.md`, remplacer :

````markdown
a time (they share local ports).

The end-to-end test plays a real online round in three browser pages (Chromium and Firefox; WebKit
checks **Copy link**; an emulated Android phone, in Chromium, joins a desktop host and plays by touch),
on the "Web pilote" export and a local Worker that it starts itself (`python3` serves the export on
port 8060, `wrangler dev` listens on 8787):
````

par :

````markdown
a time (they share local ports).

The end-to-end test plays a real online round in three browser pages (Chromium and Firefox: the host removes a
player, who comes back with the code, and the lions bump into each other; WebKit checks **Copy link**; an
emulated Android phone, in Chromium, joins a desktop host, plays by touch, then freezes for 12 s and is told
it was disconnected),
on the "Web pilote" export and a local Worker that it starts itself (`python3` serves the export on
port 8060, `wrangler dev` listens on 8787):
````

- [ ] **Step 2 : la fiche de l'essai réel**

Créer `docs/essai-en-ligne.md` :

````markdown
# Essai réel du jeu en ligne (phase 7)

Cette fiche sert une soirée de jeu en ligne, chacun chez soi : ce qu'il faut essayer, ce qu'il faut
regarder et, pour chaque réponse, ce que la phase 7 bis changera. Rien n'y est décidé d'avance : la
prédiction a été réglée au banc (profil mobile : 150 ms, 60 ms de gigue, 8 % de pertes), les mobiles en
émulation, le TURN jamais (il ne se teste pas en local). Le critère de réussite (spec §1) : **une manche
complète à au moins 3 joueurs, dont un mobile en 4G et un joueur dans un autre foyer, sans installation
ni réglage réseau.**

Comment la remplir : cocher ce qui a été essayé, entourer ou écrire la réponse, noter sur quel appareil.
Une réponse « ça va » est une vraie réponse : elle clôt la question. Renvoyer ensuite la fiche remplie,
avec les journaux de la dernière section.

Pour créer, inviter et rejoindre, suivre la section « Jouer en ligne » du `README.md`.

## Avant la soirée

- [ ] La page est publiée (phase 5) : <https://w3cdotorg.github.io/LeLion-web/> s'ouvre, déployée depuis
  le tag de la version 0.21 ou d'une suivante (deux versions différentes ne jouent pas ensemble : chacun
  recharge la page avant de commencer) : oui / non
- [ ] Les captures de la phase 7 (le salon de l'hôte avec les croix d'exclusion et la consigne de
  l'onglet ; celles de la phase 6 pour un téléphone) ne sont pas dans le dépôt : la personne qui pilote
  cette phase te les montrera avant de commencer. Elles correspondent à cette fiche et au README :
  oui / non
- [ ] Il faut au moins : l'hôte sur un **ordinateur** ; un **téléphone en 4G** (Wi-Fi coupé) ; un
  joueur dans un **autre foyer**. Un iPhone et un Android si possible, et un téléphone ancien ou lent.

Les appareils de la soirée :

| N° | Rôle (hôte ou joueur) | Appareil, système | Navigateur et version | Réseau (fibre, ADSL, Wi-Fi, 4G, 5G) | Foyer (A, B…) |
|---|---|---|---|---|---|
| 1 | hôte | | | | A |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |
| 6 | | | | | |

## 1. Créer, inviter, rejoindre

- [ ] L'hôte crée la partie : le salon montre le code et *Copier le lien* en moins de 5 s : oui / non
  (sinon, le message : _______________)
- [ ] *Copier le lien* met le lien dans le presse-papiers (le coller dans une messagerie) : oui / non,
  navigateur de l'hôte : _______________
- [ ] Chaque joueur ouvre le lien reçu : l'écran *En ligne* s'ouvre, le code rempli, et *Rejoindre*
  mène au salon. Appareils où ça échoue, et leur message : _______________
- [ ] Le temps entre *Rejoindre* et l'arrivée au salon : moins de 3 s / 3 à 10 s / plus (appareil :
  ______)
- [ ] Un joueur tape le code à la main au lieu du lien : ça marche : oui / non

| Réponse | Ce que fera la phase 7 bis |
|---|---|
| Tout arrive vite | Rien. |
| « Connexion impossible avec l'hôte (réseau trop restrictif ?) » | Noter les deux réseaux ; refaire avec `&relais=1` ajouté au lien (section 2) : si le relais passe, le TURN fait son travail ; sinon, le journal de la console des deux navigateurs (`TransportWebRTC`, `DELAI_CANAL` 15 s). |
| « Service de connexion indisponible » | La console du navigateur : la raison exacte (`origine`, `debit`, Worker injoignable) ; les limites de 5 créations et 30 arrivées par minute et par IP (`signalisation/`) touchent un réseau partagé (école, entreprise). |
| L'arrivée prend plus de 10 s | Noter le réseau : les candidats ICE et le délai de 15 s (`TransportWebRTC.DELAI_CANAL`). |

## 2. Une manche normale, puis une manche par le relais

Manche 1 : au moins 3 joueurs (le téléphone en 4G et le joueur de l'autre foyer compris), niveau au choix.

- [ ] La manche va jusqu'au bout, avec l'écran Résultats chez tous : oui / non
- [ ] Son propre lion répond tout de suite : oui / non, appareil : ______
- [ ] Son propre lion paraît élastique (il glisse après l'arrêt, revient en arrière) : jamais / parfois /
  souvent, appareil : ______
- [ ] Son propre lion saute d'un coup (téléportation) : jamais / parfois / souvent
- [ ] Les autres lions bougent de façon fluide : oui / saccadés / par à-coups
- [ ] Les chocs entre lions et les étourdissements (une gerbe reçue) paraissent justes : oui / non

Manche 2 : tous les joueurs rouvrent le lien avec `&relais=1` à la fin (le relais TURN imposé), et
l'hôte crée une nouvelle partie avec `?relais=1` dans l'adresse de la page.

- [ ] Tout le monde arrive au salon : oui / non (appareils qui échouent : ______)
- [ ] La manche paraît : pareille / plus lente / saccadée, qu'en manche 1

| Réponse | Ce que fera la phase 7 bis |
|---|---|
| Tout est fluide, y compris en 4G | Rien : `InterpolationLion.RETARD` (6 ticks) et `PredictionLocale` restent. |
| Élastique | `PredictionLocale.DUREE_CORRECTION` (0,04 s). |
| Des sauts | `PredictionLocale.SEUIL_RECALAGE` (200 px), et la console de l'appareil (un recalage est une désynchronisation). |
| Autres lions saccadés (en 4G surtout) | `InterpolationLion.RETARD` (6 ticks, 100 ms : 8 à 10 absorbent un réseau plus mauvais, au prix d'un peu de retard) ; par à-coups pendant une coupure : `InterpolationLion.EXTRAPOLATION_MAX` (3 ticks). |
| Le relais échoue | Le TURN de Cloudflare (identifiants, ports bloqués) : la console (`iceServers`, l'état ICE). |
| Le relais est bien plus lent | Noter la ville des joueurs : le point de présence du TURN ; aucun réglage du jeu n'y peut rien. |

## 3. L'hôte et ses onglets

- [ ] Le salon de l'hôte affiche en haut « Garde cet onglet au premier plan pendant la partie. » : oui /
  non ; lisible : oui / non
- [ ] Au salon, l'hôte passe 15 s sur un autre onglet, puis revient : les joueurs ont vu « L'hôte a quitté
  la partie » au bout d'environ 10 s : oui / non ; l'hôte retrouve son salon vide : oui / non
- [ ] Un hôte sur un ordinateur à écran tactile voit les flèches et PRÊT du tactile en bas du salon :
  oui / non ; elles gênent : oui / non
- [ ] Le bouton *Plein écran* du salon de l'hôte (sur ordinateur) marche, et Échap en sort : oui / non

| Réponse | Ce que fera la phase 7 bis |
|---|---|
| Consigne vue, départ vu en 10 s | Rien. |
| La consigne passe inaperçue | Plus grande, ou au-dessus des cartes (`Scenes/Salon.tscn`, `Consigne`). |
| Les flèches tactiles gênent un hôte tactile | Les cacher chez l'hôte (`ControlesTactiles.affiches`, sur un ordinateur tactile). |

## 4. Les téléphones

Sur chaque téléphone, noter Android ou iPhone, et le navigateur.

- [ ] Plein écran : sur Android, demandé au premier doigt levé, et obtenu : oui / non ; sur iPhone, rien
  ne se passe (Safari n'a pas de plein écran pour le jeu) : comme attendu / autre : ______
- [ ] Premier toucher sur le champ du pseudo : le clavier s'ouvre **et** le plein écran se demande en même
  temps ; ça se passe bien : oui / non (le clavier se ferme, le champ disparaît…) : ______
- [ ] Clavier ouvert : la rangée du champ remonte en haut de l'écran ; une tranche de la rangée du pseudo
  reste au bord haut : gênant / pas gênant
- [ ] Le voile « Tourne ton téléphone » en portrait, et le jeu qui reprend en paysage : oui / non
- [ ] Retour (en haut à gauche, à 24 px du coin) se touche facilement : oui / non (coin arrondi, encoche)
- [ ] Sans lien (la page ouverte sur le titre, puis *Multijoueur*), les boutons de l'écran titre (environ
  35 px CSS) se touchent : oui / non
- [ ] Le libellé PRÊT / VOMIR (rose sur un anneau rose) se lit : oui / non
- [ ] Le stick : apparaît sous le pouce sur toute la moitié gauche : oui / non ; le lion avance à mi-course
  du stick (la zone morte des actions est 0,5) : trop tard / bien
- [ ] L'écran Résultats : ses textes (environ 10 px CSS sur un téléphone) se lisent : oui / non
- [ ] Le réglage *Plein écran* (menu pause, Réglages) reflète-t-il le mode du téléphone : oui / non
  (attendu : non, le réglage ne suit pas le plein écran pris au doigt)
- [ ] Le son en `Stream` grésille sur un téléphone lent : non / oui, appareil : ______
- [ ] Un téléphone ancien ou lent : la manche paraît au ralenti pour lui seul / pour tout le monde
  (un hôte lent ralentit tous les joueurs) ; images par seconde, si l'on peut : ______
- [ ] iPhone : il rejoint (WebRTC) : oui / non ; il a le son : oui / non ; le clavier fait défiler la
  page : non / oui

| Réponse | Ce que fera la phase 7 bis |
|---|---|
| Plein écran Android pas obtenu | `Parametres` (au relâchement d'un toucher, `TENTATIVES_PLEIN_ECRAN` : 3). |
| Clavier et plein écran se gênent | Ne pas demander le plein écran sur le toucher d'un champ (`Parametres._input`). |
| Tranche du pseudo gênante | `EcranEnLigne.MARGE_CLAVIER` (40 px). |
| Retour mal placé | Sa marge (24 px, `Scenes/Salon.tscn`, `Scenes/EcranEnLigne.tscn`) ; la zone sûre (`viewport-fit=cover`, alors revoir les marges). |
| Les boutons du titre trop petits | Les agrandir sur un mobile, comme ceux de l'écran En ligne (`Titre`, `Parametres.agrandir`). |
| PRÊT / VOMIR illisible | La couleur ou le contour du libellé (`Scenes/ControlesTactiles.tscn`). |
| Le stick réagit trop tard | La zone morte des actions `deplacer_*` (0,5, `project.godot`) pour le tactile, sans toucher au clavier (le stick a la sienne, 0,15). |
| Résultats illisibles | Agrandir encore les textes de l'écran Résultats sur un mobile (`Resultats`). |
| Le son grésille | `audio/general/default_playback_type.web` (`Stream`) : pas de retour à `Sample` (le plantage de Safari) ; un tampon plus grand. |
| iPhone ne rejoint pas | La console de Safari (le ticket Godot de WebRTC bloqué en « connecting ») ; spec §13. |

## 5. Départs, exclusion, veille

- [ ] Un joueur quitte le salon par Retour : sa carte se libère tout de suite chez tous : oui / non
- [ ] L'hôte exclut un joueur (la croix sur sa carte) : l'exclu lit « L'hôte t'a exclu de la partie. » en
  moins d'une seconde : oui / non ; sa carte se libère chez tous : oui / non
- [ ] L'exclu rouvre le lien : il revient au salon (attendu : oui, rien ne l'identifie), et l'hôte peut
  l'exclure de nouveau : oui / non
- [ ] Un joueur verrouille son téléphone (ou cache l'onglet) 15 s pendant une manche, puis revient : il lit
  « Tu as été déconnecté », puis l'écran *En ligne* ; son lion a disparu chez les autres, ses cellules sont
  restées : oui / non
- [ ] Le même, 5 s seulement : il reprend la manche sans rien voir : oui / non
- [ ] Un joueur coupe son réseau (mode avion) 15 s : les autres le voient partir au bout d'environ 10 s :
  oui / non ; à son retour, il lit : _______________

| Réponse | Ce que fera la phase 7 bis |
|---|---|
| Tout comme attendu | Rien. |
| L'exclu lit « L'hôte a quitté la partie » | L'annonce n'est pas arrivée avant la fermeture : `Reseau.DELAI_EXCLUSION_SALON` (2 s). |
| « L'hôte a quitté la partie » au retour d'un téléphone verrouillé | `Reseau.RETOUR_DE_GEL` (2 s), ou un téléphone qui garde des images en veille : noter le modèle. |
| Déclaré parti après 5 s de veille | `Reseau.SILENCE_SESSION` (10 s). |

## 6. Ce qu'il faut renvoyer

- Cette fiche remplie.
- Pour chaque problème : l'heure, l'appareil, et la console du navigateur (sur ordinateur : F12, onglet
  Console, clic droit, « Enregistrer sous » ; sur Android : `chrome://inspect` depuis un ordinateur ; sur
  iPhone : Safari de macOS, menu Développement). Les lignes `WARNING:` et `ERROR:` suffisent, avec celles
  de `Signalisation :`.
- Note pour l'essai : le test de bout en bout vise le stick à une place fixe (`PiloteWeb`, trois rayons du
  bord) ; s'il ne paraît pas sous le pouce ailleurs dans la moitié gauche, le dire (section 4).
````

- [ ] **Step 3 : la spec**

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
## 5. En jeu

- **Canaux** : canal 0 en non fiable (commandes, états, battement : `unreliable_lifetime` d'environ
  100 ms, 1 seul envoi), canal 1 fiable et ordonné (tampons, territoire, fin, lancement, table de
  relance : `CANAL_ORDONNE`, inchangé), configuré à la création du pair (`create_server` /
  `create_client` avec un canal fiable en plus des canaux par défaut). Le fiable du canal 0 (poignée
  de main, table du salon) reste sur le canal fiable par défaut.
- **Redondance des commandes**, prédiction du lion local, interpolation des lions distants : inchangées.
  Le banc de la prédiction gagne un **profil mobile** (150 ms de latence, 60 ms de gigue, 8 % de
````

par :

````markdown
## 5. En jeu

- **Canaux** : canal 0 en non fiable (commandes, états, battement : partiellement fiable, un paquet
  perdu renvoyé pendant 100 ms au plus, `unreliable_lifetime`, puis abandonné), canal 1 fiable et
  ordonné (tampons, territoire, fin, lancement, table de relance : `CANAL_ORDONNE`, inchangé),
  configuré à la création du pair (`create_server` / `create_client` avec un canal fiable en plus des
  canaux par défaut). Le fiable du canal 0 (poignée de main, table du salon) reste sur le canal fiable
  par défaut. Phase 7 : Godot 4.7.2 passe la durée de vie au navigateur sous le nom `maxPacketLifetime`,
  que Chromium et Firefox ignorent (le standard dit `maxPacketLifeTime`) : ses canaux non fiables y
  étaient fiables, chaque paquet perdu renvoyé jusqu'à son arrivée ; `TransportWebRTC` corrige le nom
  (une fois par page), le test de bout en bout lit 100 ms sur chaque canal non fiable.
- **Redondance des commandes**, prédiction du lion local, interpolation des lions distants : inchangées.
  Le banc de la prédiction gagne un **profil mobile** (150 ms de latence, 60 ms de gigue, 8 % de
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
    pendant la partie. » ; 10 s de silence de l'hôte donnent aux clients « L'hôte a quitté la
    partie » (retour à l'écran En ligne depuis le salon, au titre depuis une manche, comme au LAN).
- **Départ volontaire** : un message fiable « je pars » puis fermeture du pair après son envoi (au
  plus 1 s) ; l'autre côté le voit parti tout de suite, sans attendre les 10 s.
````

par :

````markdown
    pendant la partie. » ; 10 s de silence de l'hôte donnent aux clients « L'hôte a quitté la
    partie » (retour à l'écran En ligne depuis le salon, au titre depuis une manche, comme au LAN).
  - Tel que construit (phase 7) : un poste sait qu'il a gelé (plus aucune image depuis plus que le
    silence toléré, 10 s, 30 s au chargement) ; une perte de l'hôte constatée avant sa première image
    (la fermeture de son pair, relevée avec les paquets) ou dans les 2 s qui la suivent (le silence de
    l'hôte) est la sienne : « Tu as été déconnecté », puis l'écran En ligne, depuis le salon comme depuis
    une manche. La consigne de l'hôte est en haut de son salon, sur ordinateur.
- **Départ volontaire** : un message fiable « je pars » puis fermeture du pair après son envoi (au
  plus 1 s) ; l'autre côté le voit parti tout de suite, sans attendre les 10 s.
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
- Vie privée : aucun compte, rien de stocké. Cloudflare voit les IP le temps de la signalisation ;
  hôte et client voient l'IP l'un de l'autre, sauf connexion par le TURN. Le README le dit.

## 9. Gestion des erreurs
````

par :

````markdown
- Vie privée : aucun compte, rien de stocké. Cloudflare voit les IP le temps de la signalisation ;
  hôte et client voient l'IP l'un de l'autre, sauf connexion par le TURN. Le README le dit.
- Tel que construit (phase 7) : un seau de jetons par client chez l'hôte (`LimiteDebit`), à l'horloge
  de l'hôte (pas à ses ticks physiques : un hôte lent jetterait les paquets d'un client qui joue, vu
  sous Firefox en CI) : 2 paquets de commandes par tick (120 par seconde), 120 d'un coup (deux secondes
  d'un client : un hôte figé ne jette rien) ; 10 demandes de salon par seconde, 10 d'un coup.
  L'excédent est jeté sans réponse et compté, un avertissement au premier rejet ; personne n'est
  déconnecté pour autant. Pseudos : aussi les autres caractères de mise en forme (catégorie Cf
  d'Unicode : U+00AD, U+061C, U+180E, U+FFF9 à U+FFFB, les étiquettes…) et les lettres vides du coréen,
  nettoyés avant la coupe à 12 ; aucun `RichTextLabel` dans le jeu, et chaque étiquette de pseudo (cartes
  du salon, HUD, Résultats, lion) ne se traduit jamais d'elle-même. Exclusion : la croix se clique à la
  souris (ou au doigt), ni le clavier ni la manette ne l'atteignent ; au salon seulement ; l'annonce
  fiable porte sa raison (`_recevoir_exclusion(par_l_hote)`, version 0.21), l'exclu part de lui-même et
  l'hôte le libère au plus tard 2 s après (une annonce retardée par une 4G arrive avant la fermeture).

## 9. Gestion des erreurs
````

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

````markdown
  sous un vrai clic ; un mobile émulé par Chromium (Android en paysage) rejoint un hôte de bureau par le
  lien et joue au doigt (Rejoindre, la couleur, PRÊT, le stick et VOMIR : de vrais touchers), voit le
  voile en portrait (phase 6). L'exclusion d'un joueur s'y ajoute avec elle (phase 7). Le TURN ne se teste pas en
  local.
- **Essai réel** : `docs/essai-en-ligne.md` (hôte sur ordinateur, au moins un mobile en 4G, un joueur
  dans un autre foyer ; une manche avec le relais TURN forcé par `?relais=1`, paramètre de
  diagnostic qui pose `iceTransportPolicy: "relay"`). Ses réponses font la phase 6 bis.

## 11. Build, déploiement et prérequis
````

par :

````markdown
  sous un vrai clic ; un mobile émulé par Chromium (Android en paysage) rejoint un hôte de bureau par le
  lien et joue au doigt (Rejoindre, la couleur, PRÊT, le stick et VOMIR : de vrais touchers), voit le
  voile en portrait (phase 6). Phase 7 : l'hôte exclut un joueur d'un vrai clic sur sa croix, l'exclu lit
  son message puis revient avec le code ; les lions se croisent (chocs, étourdissements, le même bilan
  partout) ; le mobile gèle 12 s (la page ne rend plus la main) et lit « Tu as été déconnecté » ; chaque
  canal non fiable a sa durée de vie de 100 ms ; une exception JavaScript d'une page (`pageerror`), ou un
  client limité par l'hôte, fait échouer le test. Le TURN ne se teste pas en
  local.
- **Essai réel** : `docs/essai-en-ligne.md` (hôte sur ordinateur, au moins un mobile en 4G, un joueur
  dans un autre foyer ; une manche avec le relais TURN forcé par `?relais=1`, paramètre de
  diagnostic qui pose `iceTransportPolicy: "relay"`). Ses réponses font la phase 7 bis (feuille de
  route).

## 11. Build, déploiement et prérequis
````

- [ ] **Step 4 : relecture**

```bash
grep -c "^| « " README.md
grep -n "Jouer en ligne\|jouer-en-ligne" README.md
grep -c "^- \[ \]" docs/essai-en-ligne.md
grep -n "1 seul envoi\|phase 6 bis" docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
```

Expected : `15` (une ligne du dépannage par message) ; le titre « ## Jouer en ligne » et le lien `#jouer-en-ligne` de la section « Multiplayer » ; ``39`` ; rien pour la dernière commande.

- [ ] **Step 5 : Commit**

```bash
git add README.md docs/essai-en-ligne.md docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
git commit -m "README « Jouer en ligne » (créer, inviter, rejoindre, l'onglet de l'hôte, les téléphones, l'exclusion, la vie privée, le dépannage message par message) ; la fiche de l'essai réel (docs/essai-en-ligne.md) ; la spec telle que construite

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 9 : vérification commune, captures ◉, feuille de route, PR et fusion de la phase 7

**Files:**
- Modify: `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 7 : fichiers réels, « Faite (PR #N) »)

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
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "banc $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/p.log"
SECONDS=0; timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r.log"
(cd signalisation && npm ci --silent && npm test 2>&1 | tail -4)
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/dc.log" 2>&1 &
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/dh.log" 2>&1; echo "deux fenêtres hôte $?"; wait; grep -c "📸" "$TMPDIR/dh.log" "$TMPDIR/dc.log"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/dh.log" "$TMPDIR/dc.log"
mkdir -p export/web export/web-pilote
timeout 600 godot --headless --export-release Web export/web/index.html > "$TMPDIR/e.log" 2>&1; echo "export $?"
timeout 600 godot --headless --export-release "Web pilote" export/web-pilote/index.html > "$TMPDIR/ep.log" 2>&1; echo "export pilote $?"
for n in 1 2; do SECONDS=0; timeout 900 docker run --rm --init -v "$PWD":/depot -v lelion7-modules-signalisation:/depot/signalisation/node_modules -v lelion7-modules-web:/depot/tests/web/node_modules -w /depot/tests/web mcr.microsoft.com/playwright:v1.63.0-noble bash -c '(cd ../../signalisation && npm ci --silent) && npm ci --silent && xvfb-run -a npx playwright test' > "$TMPDIR/e2e$n.log" 2>&1; echo "bout en bout $n : $? en ${SECONDS} s"; grep -E "✓|✘|passed|failed|Fin de manche|Rencontre|Départ" "$TMPDIR/e2e$n.log"; done
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/web/*.js
git status --short
```

Expected : « aucun autre godot » ; pas de « ÉCHEC COMPILATION » ; chaque suite Godot sort en 0 sur `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR` ; `PROTOCOLE 0.21 1188810746 (67 lignes)`, 568 ✅ unitaires, 470 ✅ smoke, 78 ✅ au banc ; réseau en 155 à 170 s (mesuré 162 s), ses trois mesures (départs en moins d'une seconde, I1 environ 500 ms, départ arraché vu vers 9,8 s) ; les tests du Worker verts (`70 passed`) ; 46 📸 pour les captures, 5 et 6 pour les deux fenêtres ; `export 0`, `export pilote 0` ; les deux passages du bout en bout `0`, `4 passed` (mesurés 139 et 141 s), chacun avec ses deux lignes `Rencontre` (mesuré : étourdissements 1 à 2, chocs 6 à 8 par manche) ; rien au `perl` ; `git status` propre. Un échec : le corriger dans la tâche qu'il concerne (commit à part), puis tout relancer.

- [ ] **Step 2 : les captures avec le vrai rendu ◉ (contrôle visuel)**

```bash
D="$TMPDIR/captures-phase7"; mkdir -p "$D"
timeout 300 godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier="$D" --parties=salon,mobile > "$TMPDIR/cv.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/cv.log") 📸"; ls "$D"
```

Expected : `captures 0 : 16 📸` (une fenêtre s'ouvre, change de taille, se ferme). À regarder (le contrôleur, `Read` sur chaque PNG) :
- `salon_00_hote_seul.png` (2000×1125) : « Garde cet onglet au premier plan pendant la partie. » en haut, entre Retour et Plein écran, au-dessus de « Salon », sans le toucher ; aucune croix (l'hôte seul) ;
- `salon_01_a_3.png`, `salon_03_a_6.png` : une croix « × » en haut à droite de chaque carte d'un autre joueur, au-dessus de son lion, aucune sur celle de l'hôte ni sur les places libres ;
- `salon_04_anglais.png` : « Keep this tab in front during the game. » ;
- `salon_05_client.png` à `salon_07_client_joueur_qui_arrive.png` : ni croix ni consigne (un client) ;
- `mobile_02_salon.png` : ni croix ni consigne (un client sur un téléphone).

Noter ce qui ne va pas (texte coupé, chevauchement, contraste) pour la PR ; ne rien retoucher sans accord.

- [ ] **Step 3 : la branche poussée, la PR ouverte** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
git push -u origin phase-07-securite
cat > "$TMPDIR/pr.md" <<'EOF'
Phase 7 de la feuille de route du jeu en ligne : la sécurité du jeu et la documentation (spec §8.2, §5, §9, §11).

- Débit des clients chez l'hôte (`LimiteDebit`, un seau de jetons par client, à l'horloge de l'hôte) : 2 paquets de commandes par tick (120 par seconde, 120 d'un coup : un hôte figé 2 s ne jette rien), 10 demandes de salon (couleur, Prêt) par seconde ; l'excédent est jeté et compté, un avertissement au premier rejet. Compter en ticks physiques de l'hôte jetait les paquets d'un client qui joue sous un hôte lent (vu sous Firefox, en bout en bout).
- Exclusion : chez l'hôte, la croix sur la carte de chaque autre joueur ; l'exclu lit « L'hôte t'a exclu de la partie. » et part de lui-même, l'hôte le libère au plus tard 2 s plus tard ; il peut revenir avec le code. L'annonce porte sa raison : **version 0.21**, `PROTOCOLE 0.21 1188810746`.
- Un poste revenu d'un gel plus long que le silence toléré (onglet caché, téléphone verrouillé) lit « Tu as été déconnecté », puis l'écran En ligne ; le salon de l'hôte dit « Garde cet onglet au premier plan pendant la partie. ».
- Pseudos : aussi la catégorie Cf d'Unicode et les lettres vides du coréen ; aucun `RichTextLabel`, aucune étiquette de pseudo traduite d'elle-même (vérifié partout où un pseudo s'affiche).
- WebRTC : Godot 4.7.2 passe aux canaux non fiables l'option `maxPacketLifetime`, que Chromium et Firefox ignorent (le standard dit `maxPacketLifeTime`) : ces canaux étaient fiables. `TransportWebRTC` corrige le nom ; le bout en bout lit 100 ms (0 sans le correctif). À signaler en amont.
- Bout en bout : l'exclusion d'un vrai clic (l'exclu revient), les lions qui se croisent (chocs, le même bilan partout), le mobile qui gèle 12 s (« Tu as été déconnecté »), les exceptions JavaScript (`pageerror`) et tout client limité font échouer le test.
- README « Jouer en ligne » (en français : créer, inviter, rejoindre, l'onglet de l'hôte, les téléphones, l'exclusion, la vie privée, le dépannage message par message) ; la fiche de l'essai réel `docs/essai-en-ligne.md` (ses réponses font la phase 7 bis).

Mesures (ce Mac, Step 1) : MESURES

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
gh pr create --repo w3cdotorg/LeLion-web --base main --head phase-07-securite --title "Phase 7 : sécurité du jeu et documentation" --body-file "$TMPDIR/pr.md"
N=$(gh pr view --repo w3cdotorg/LeLion-web phase-07-securite --json number -q .number); echo "PR #$N"
```

Entre l'écriture de `$TMPDIR/pr.md` et `gh pr create`, y remplacer `MESURES` (outil Edit) par les mesures du Step 1 : la durée du test réseau, celles des deux passages du bout en bout, leurs lignes « Rencontre », et ce que le Step 2 a relevé.

- [ ] **Step 4 : la feuille de route**

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

````markdown
| ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Salon.gd` ✏️ `tests/unitaires.gd` ✏️ `README.md` ➕ `docs/essai-en-ligne.md` | Unitaires des limites et de l'exclusion ; fiche prête pour l'essai. |
````

par (`NUMERO` est le numéro de la PR, `$N` du Step 3) :

````markdown
| ✏️ `Scripts/Reseau.gd` (débit du salon, exclusion, retour d'un gel, pseudos) ➕ `Scripts/LimiteDebit.gd` ✏️ `Scripts/Manche.gd` (débit des commandes) ✏️ `Scripts/Salon.gd` ✏️ `Scenes/Salon.tscn` (croix, consigne) ✏️ `Scripts/Main.gd` ✏️ `Scripts/TransportWebRTC.gd` (canaux non fiables) ✏️ `Scripts/PiloteWeb.gd` ✏️ `project.godot` (0.21) ✏️ `Assets/Traductions/traductions.csv` ✏️ tests (`unitaires`, `smoke_test`, `web/`) ✏️ spec ✏️ `README.md` ➕ `docs/essai-en-ligne.md` | Unitaires des limites et de l'exclusion ; fiche prête pour l'essai ; l'exclusion, la rencontre des lions et le retour d'un gel de bout en bout. Faite (PR #NUMERO). |
````

puis :

```bash
perl -pi -e "s/PR #NUMERO/PR #$N/" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
grep -c "Faite (PR #$N)" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git add docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git commit -m "Feuille de route : phase 7 faite (PR #$N)

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

Expected : les trois jobs verts (le bout en bout de la CI est plus lent que celui de ce Mac : une page Chromium en rendu logiciel y tourne à 0,4× ; un client que l'hôte limite y ferait échouer le test, à diagnostiquer avec l'artefact `rapport-playwright` avant toute retouche, jamais en relâchant la garde) ; la fusion faite, `main` à jour. La CI rouge : ne pas fusionner, diagnostiquer.
