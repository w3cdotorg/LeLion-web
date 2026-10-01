# Phase 3 et 3 bis : écran En ligne, puis retrait de la découverte

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** remplacer l'écran Réseau du LAN par l'écran En ligne (spec §3.1) : pseudo mémorisé, *Créer une partie*, *Rejoindre* avec un code de salle (alphabet sans 0/O ni 1/I/L, affiché `K7Q-2XM`, refusé à la saisie s'il est mal formé), rempli d'avance par le lien `?salle=` ; le salon de l'hôte affiche le code et *Copier le lien* ; les messages d'erreur du §9. Sur le desktop de développement, le code est l'adresse `ip:port` d'un hôte `TransportENet` ; dans l'export Web, tant que `TransportWebRTC` n'existe pas (phase 4), *Créer* et *Rejoindre* le disent sans rien ouvrir. Puis (3 bis) retirer la découverte LAN : `Decouverte.gd` et son autoload, l'écran Réseau, les scénarios 6 et 7 du test réseau, `DIFFUSION=1`. Sortie de la phase 3 : **le parcours Titre → En ligne → Salon en ENet** (smoke test, scénarios 8 à 13 du test réseau, deux fenêtres), les unitaires du code de salle. Sortie de la 3 bis : **plus aucune référence à `Decouverte`**, les captures à jour, le compte de la CI ajusté.

**Architecture:**
- **`CodeSalle`** (`Scripts/CodeSalle.gd`, `class_name`, logique pure, aucun autoload) : `normaliser` (sans espaces, tabulations ni tirets, lettres ASCII en majuscules), `valide`, `erreur` (clé de traduction : `ENLIGNE_CODE_CONFUSION` pour un 0/O/1/I/L, `ENLIGNE_CODE_FORMAT` pour le reste), `formater` (« K7Q-2XM »), `lien` (l'adresse de la page, puis `?salle=`), `url_page` (sur le Web, `location.origin + location.pathname` ; ailleurs le réglage `lelion/page/url`), `lire_recherche` (`?salle=` d'une `location.search`), `prendre_code_de_la_page` (une seule fois par lancement, `JavaScriptBridge` sur le Web, `recherche_forcee` dans les tests).
- **`Reseau`** gagne les entrées de l'écran En ligne, qui choisiront le transport en phase 4 : `creer_partie(port)` et `rejoindre_partie(code)` (ERR_UNAVAILABLE sans rien ouvrir si `transport_disponible` est faux : l'export Web avant la phase 4) ; `rejoindre(adresse, port)` y délègue, `heberger(port)` reste tel quel (les tests forcent ENet). `raison_echec` : la raison du transport (`Transport.ECHEC_*`) posée juste avant `connexion_echouee`, vide sinon. `Transport` déclare les raisons que `TransportWebRTC` rendra (celles de la signalisation de la phase 2, plus `injoignable`).
- **`EcranEnLigne`** (`Scenes/EcranEnLigne.tscn` + `Scripts/EcranEnLigne.gd`, sans `class_name` : il nomme des autoloads) : trois états comme l'écran Réseau (ACCUEIL, CONNEXION, SALON) ; `codes_de_salle` (vrai sur le Web) choisit la validation ; `cle_echec(raison)` donne le message du §9 ; `code_a_l_arrivee` (posé par le titre, depuis le lien) et `message_a_l_arrivee` (posé par le salon). `Titre` ouvre cet écran (Multijoueur, ou d'emblée sur un lien `?salle=`).
- **`Salon`** : la ligne des adresses LAN de l'hôte (`Decouverte.adresses_hote`) devient « Code de la partie : K7Q-2XM » et *Copier le lien* (`DisplayServer.clipboard_set` dans le gestionnaire du clic) ; l'hôte seul, relue à chaque affichage ; il revient à l'écran En ligne.
- **Tests** : unitaires (code de salle, alphabet recoupé avec `signalisation/src/code.js` ; entrées de `Reseau`, `raison_echec`), smoke (écran En ligne, lien `?salle=`, salon), test réseau et deux fenêtres par l'écran En ligne, captures (38). 3 bis : suppressions seulement, l'empreinte du protocole renotée (la ligne de la balise part).

**Tech Stack:** Godot 4.7.2, GDScript typé (`class_name`, `static var`), `JavaScriptBridge` (Web), `DisplayServer.clipboard_set`, `ProjectSettings` (réglage `lelion/page/url`), CSV de traductions, tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/prediction_test.gd`, `tests/reseau/lancer.sh` + `joueur.gd`, `tests/screenshots.gd`, `tests/deux_fenetres.gd`), `vitest` du Worker (inchangé, vérification commune).

**Spec:** `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§1, §2 « Rejoindre », §3.1 `EcranEnLigne`, §3.2, §4.4, §6, §9, §10) · feuille de route : `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (lignes 3 et 3 bis, « Vérification commune », « Points de vigilance ») · plan de la phase 1 (écarts 5 et 6 : signatures de `heberger` / `rejoindre`, `code_partie`, délais partagés) · prérequis : **phase 2 fusionnée** (PR #3) ; branche `phase-03-ecran-en-ligne` depuis `main`, puis `phase-03bis-retrait-decouverte` depuis `main` une fois la PR de la phase 3 fusionnée.

## Global Constraints

- Rejoindre (spec §2) : « Code de salle de 6 caractères (alphabet sans 0/O, 1/I/L), affiché `K7Q-2XM`, et lien `https://w3cdotorg.github.io/LeLion-web/?salle=K7Q2XM`. Privé : pas de liste. »
- `EcranEnLigne` (spec §3.1) : « Pseudo (mémorisé dans `Scores`), *Créer une partie* (absent sur mobile), *Rejoindre* avec un champ de code (pré-rempli par `?salle=`), messages d'erreur (§9). Le salon affiche le code et *Copier le lien*. »
- Choix du transport (spec §3.1) : « `TransportWebRTC` quand `OS.has_feature("web")`, `TransportENet` sinon (ou forcé par les tests). » ; `TransportENet` : « Le « code » y est `ip:port`. »
- Lien (spec §4.4) : « `?salle=K7Q2XM` est lu au démarrage par `JavaScriptBridge` (`location.search`). S'il est présent et valide, le jeu ouvre l'écran En ligne sur *Rejoindre*, code rempli ; il ne rejoint qu'après le pseudo validé. *Copier le lien* passe par `DisplayServer.clipboard_set` (sur le Web, l'API du presse-papiers, qui exige le geste du clic : le bouton le fournit). »
- Code de salle (plan de la phase 2, écarts 13 et 7) : alphabet `23456789ABCDEFGHJKMNPQRSTUVWXYZ`, 6 caractères ; « Le Worker accepte un code en minuscules, pas le tiret (400) : le jeu (phase 3, `CodeSalle`) retire tiret et espaces avant de rejoindre ». Raisons du message `erreur` : `inconnue`, `pleine`, `debit`, `quota`, `origine`, `expiree`, `delai`.
- Messages (spec §9), mot pour mot : « Un code fait 6 caractères (ex. K7Q-2XM). » · « Aucune partie avec ce code. » · « Service de connexion indisponible, réessaie dans un instant. » (Worker injoignable 5 s, origine refusée, débit dépassé) · « Trop de parties en ce moment, réessaie plus tard. » · « Connexion impossible avec l'hôte (réseau trop restrictif ?) » · refus du LAN inchangés (`Reseau.REFUS_*`) · « L'hôte a quitté la partie ».
- Mobiles (spec §6, feuille de route : phase 6) : *Créer une partie* absent sur `web_android` / `web_ios` et contrôles tactiles : **pas dans cette phase**, mais rien ici ne doit l'empêcher (le bouton est un nœud à part, `bouton_creer`).
- Ce qui disparaît (spec §3.2) : « `Scripts/Decouverte.gd` (balises UDP 7778), la saisie d'IP, l'écran Réseau du LAN […]. Les tests de découverte (scénarios et `DIFFUSION=1`) partent avec elle. »
- Tests (spec §10) : « `screenshots.gd` (écran En ligne, salon avec code, […]) » ; « Unitaires nouveaux : format et alphabet du code, lecture de `?salle=` […] ».
- Le délai d'échec d'un client est celui du canal du transport, puis celui de la poignée de main (plan de la phase 1, écart 6) : aucun texte ne promet « 5 s ».
- Version et protocole (feuille de route) : `config/version` reste **0.20** ; l'empreinte ne bouge pas en phase 3 (`PROTOCOLE 0.20 815376087 (68 lignes)`), elle est renotée en 3 bis : `PROTOCOLE 0.20 2553814265 (67 lignes)`, mesurée sur ce plan appliqué à une copie du dépôt. Une autre valeur trahit un écart avec le code du plan : le retrouver avant de noter quoi que ce soit.
- Commandes : `export PATH="/opt/homebrew/bin:$PATH"` puis `cd ~/Sites/LeLion-web` ; chaque commande godot sous `timeout`, options écrites en clair (zsh ne découpe pas une variable non quotée : `--fixed-fps` sauterait en silence). Un test qui doit échouer sur une erreur de script peut se bloquer : `timeout -k 5 120`.
- Un test `--script` est compilé **avant** les autoloads : il récupère `Reseau`, `Scores`, `GameState`, `Parametres` par `root.get_node(...)`, ne les nomme jamais ; il peut nommer `CodeSalle`, `Transport`, `TransportENet`, `EtatPartie` (aucun ne nomme d'autoload). `EcranEnLigne.gd` nomme des autoloads : pas de `class_name`, les tests le chargent (`load`) à l'exécution, `Titre` et `Salon` le préchargent. Les tests qui lisent des textes posent la langue française (`definir_langue("fr")` ou `TranslationServer.set_locale("fr")`, déjà le cas des quatre suites touchées).
- Après la création d'un script à `class_name` (`CodeSalle`) : `godot --headless --import .` avant les tests (il génère le `.uid`, à committer avec le script). Après une modification de `traductions.csv`, l'import régénère `traductions.fr.translation` et `traductions.en.translation`, suivis par git : les committer avec le CSV.
- Les blocs « Dans X, remplacer … par … » citent le texte exact laissé par la tâche précédente (vérifié en appliquant ce plan, tâche après tâche, à une copie de `main` où la phase 2 était fusionnée) ; chacun se fait avec l'outil Edit (texte exact, une seule occurrence), dans l'ordre donné. Les blocs « Exécuter (modification mécanique) » (suppressions de fonctions et de scénarios entiers, en 3 bis) sont des commandes à lancer telles quelles depuis la racine du dépôt : chacune vérifie elle-même ses ancres (`assert`) et ne touche à rien si l'une manque.
- Identifiants, commentaires et messages en français, docstrings `##`, tabulations. Aucune séquence `\u…` tapée dans un fichier ; après chaque écriture, `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh` ne sort rien. Aucun message de test ne contient `SCRIPT ERROR` ni `SHADER ERROR`.
- Bruit connu des sorties : « ObjectDB instances were leaked », « resources still in use at exit », les `ERROR` voulues des plans précédents, `ERROR: Couldn't create an ENet host.` et `ERROR: The local port number must be between 0 and 65535` (le port occupé et le port 70000 des tests d'hébergement, désormais aussi dans `_tester_ecran_en_ligne`).
- Commits en français, terminés par :
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT
  ```

## Review Focus

1. **Un code mal lu qui mène chez un autre** (un O pris pour un 0, un tiret envoyé au Worker, une lettre non ASCII qui ressemble à une lettre du code) : refusé avec son message, jamais remplacé ; le tiret et les espaces retirés avant `rejoindre_partie`. → unitaires `_tester_code_salle` (confusions en minuscules et dans un code trop court, « ſ », tiret long, `?salle=K7Q%2D2XM`) et l'alphabet recoupé avec `signalisation/src/code.js` (Task 1) ; smoke, refus à la saisie et affichage « K7Q-2XM » (Task 3).
2. **Un lien `?salle=` qui rejoint trop tôt, ou à chaque retour au titre** : l'écran s'ouvre sur Rejoindre, le code rempli, sans rien tenter ; il ne part qu'au Rejoindre du joueur (ou Entrée sur son pseudo) ; le lien ne sert qu'une fois par lancement. → unitaire « le lien de la page ne sert qu'une fois » (Task 1) ; smoke « une page ouverte sur un lien ?salle= », « rien de tenté », « un titre suivant reste le titre » (Task 3).
3. **L'export Web sans transport qui plante ou se tait** (avant `TransportWebRTC`) : `transport_disponible` faux, `creer_partie` / `rejoindre_partie` renvoient ERR_UNAVAILABLE sans rien ouvrir, l'écran dit « Pas encore de jeu en ligne dans cette version : il arrive bientôt. ». → unitaire « sans transport sur ce poste » (Task 2) ; smoke « sans transport, Rejoindre le dit sans rien ouvrir », « … et Créer une partie aussi » (Task 3).
4. **Un échec de connexion au mauvais message** (une raison du transport perdue en route, ou celle d'un échec précédent restée) : `raison_echec` vient du transport de la session (génération comprise) et repart vide à chaque échec sans raison ; chaque raison a son texte du §9. → unitaires « le transport échoue … sa raison dans raison_echec » et « un échec sans raison … rien de l'échec précédent » (Task 2) ; smoke, la table des raisons et « un vrai échec du transport, sa raison passée par Reseau » (Task 3).
5. **Une navigation qui mène à un écran disparu, ou une découverte qui survit** : le salon revient à l'écran En ligne (Retour, hôte perdu, salon orphelin), les écrans fermés ne laissent aucune connexion aux autoloads, et en 3 bis plus aucune référence à `Decouverte`, `EcranReseau`, `DIFFUSION` ni au port 7778. → smoke `_tester_salon` (Task 4) et « l'écran retiré de l'arbre ne laisse aucune connexion » (Task 3) ; scénarios 8 et 13 du test réseau, qui reviennent à l'écran En ligne (Task 4) ; le `grep` de la Task 12, sans résultat.

## Écarts assumés

1. **Un seul plan pour les lignes 3 et 3 bis, deux PR** (`phase-03-ecran-en-ligne`, puis `phase-03bis-retrait-decouverte`) : la frontière la plus nette est « la phase 3 fait passer tout le jeu et tous les tests par l'écran En ligne, la 3 bis ne fait que supprimer ». La feuille de route mettait l'adaptation des tests en 3 bis ; mais dès que le salon revient à l'écran En ligne (phase 3), le test réseau, les deux fenêtres et les captures doivent le suivre, sans quoi la phase 3 finirait rouge. L'écran Réseau reste donc compilé et testé seul (smoke, captures retirées) pendant la phase 3, injoignable depuis le titre.
2. **Fichiers au-delà des lignes 3 et 3 bis de la feuille de route.** Phase 3 : aussi `Scripts/Reseau.gd` et `Scripts/Transport.gd` (les entrées et les raisons d'échec), `Scripts/Titre.gd` (Multijoueur, le lien), `Scenes/Salon.tscn`, `project.godot` (le réglage `lelion/page/url`), `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh` (un commentaire), `tests/deux_fenetres.gd`, `tests/screenshots.gd`, `.github/workflows/ci.yml` (38 captures), la spec et le README (Task 6). Phase 3 bis : aussi `Scripts/EcranReseau.gd`, `Scripts/Regles.gd`, `Scripts/Salon.gd`, `Scripts/Titre.gd`, `Scripts/Reseau.gd` (des commentaires), les traductions, `.github/workflows/ci.yml` (`DIFFUSION=1`), la spec et le README. Chaque tâche touche 5 fichiers de code au plus (le plafond du §12 de la spec est levé par l'utilisateur depuis la phase 1).
3. **Les caractères qu'on confond sont refusés, pas remplacés** : 0, O, 1, I, L (en minuscules aussi) donnent « Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM). », un message de plus que le §9 (« Code mal formé ») ; remplacer O par 0 en silence enverrait un joueur qui a mal recopié dans la salle d'un autre. La saisie n'ignore que l'espace, la tabulation et le tiret ASCII, et ne met en majuscules que les lettres ASCII (un tiret long ou « ſ » sont refusés, comme au Worker). La spec §9 est mise à jour (Task 6).
4. **Le lien part de la page ouverte** : sur le Web, `location.origin + location.pathname` (la page publiée donne exactement le lien du §2 ; une préversion ou la page locale du test Playwright de la phase 4 donnent le leur) ; hors du Web, le réglage de projet `lelion/page/url` (`https://w3cdotorg.github.io/LeLion-web/`), à côté de `lelion/signalisation/url` qui viendra en phase 5. Le lien `?salle=` est lu au premier écran titre et ne sert qu'une fois par lancement (`CodeSalle.prendre_code_de_la_page`) : un retour au titre ne rouvre pas l'écran En ligne. Spec §4.4 mise à jour (Task 6).
5. **Les entrées de l'écran dans `Reseau`, pour la phase 4** : `creer_partie(port := PORT)` et `rejoindre_partie(code)` passent par `_nouveau_transport` (ENet aujourd'hui ; la phase 4 y choisira `TransportWebRTC` quand `OS.has_feature("web")`). `transport_disponible` (faux dans l'export Web jusqu'à la phase 4, modifiable par les tests) fait renvoyer ERR_UNAVAILABLE aux deux, sans rien ouvrir : l'écran dit « Pas encore de jeu en ligne dans cette version : il arrive bientôt. » plutôt que de tenter un ENet que le navigateur n'a pas. `heberger(port)` et `rejoindre(adresse, port)` gardent leur signature (écart 5 de la phase 1) ; `rejoindre` délègue à `rejoindre_partie` et répond donc aussi ERR_UNAVAILABLE sans transport. Le code de la partie reste `code_partie`, relu par le salon à chaque affichage : quand `pret` arrivera après coup (WebRTC), la phase 4 n'aura qu'à émettre `salon_change`.
6. **Sur le desktop de développement, le champ du code prend `ip:port`** (ou `ip`, port 7777 : `TransportENet.lire_code`), « Adresse invalide (ex. 192.168.1.20:7777) » sinon ; la saisie d'IP de l'écran Réseau disparaît bien (spec §3.2), c'est le « code » du transport ENet (spec §3.1, feuille de route ligne 3). L'écran choisit la validation par `codes_de_salle` (`OS.has_feature("web")`, modifiable par les tests pour vérifier le chemin du Web sur le desktop).
7. **Les raisons d'échec d'un transport sont déclarées dès maintenant** dans `Transport` (`ECHEC_INCONNUE`, `ECHEC_PLEINE`, `ECHEC_DEBIT`, `ECHEC_QUOTA`, `ECHEC_ORIGINE`, `ECHEC_EXPIREE`, `ECHEC_INJOIGNABLE` ; `delai` de la signalisation est le même mot que `ECHEC_DELAI`), et `Reseau.raison_echec` les transmet à l'écran, qui a la table des messages du §9 (`EcranEnLigne.cle_echec`). Seul ENet les produit aujourd'hui (`delai`) ; les tests les émettent sur le transport réel (`_transport.echec`). « Journal : raison exacte » (§9) revient à `TransportWebRTC`, qui a le message brut. `pleine` (la 8e socket de la salle) prend le refus du LAN « La partie est complète. » ; `expiree` vue par un arrivant, « Aucune partie avec ce code. ». Le salon de l'hôte (« Salle expirée … », « Garde cet onglet au premier plan ») et « Tu as été déconnecté » restent aux phases 4 et 7.
8. **Le salon : le code pour l'hôte seul, le lien seulement pour un code de salle.** La spec ne dit pas qui voit le code : l'hôte, qui invite (un client l'a déjà). Sur le desktop, l'hôte voit « Code de la partie : 127.0.0.1:port » (le code de `TransportENet`, écart 7 de la phase 1), sans *Copier le lien*. La ligne des adresses LAN de l'hôte (`Decouverte.adresses_hote`, `SALON_ADRESSES`) part dès la phase 3 (le code la remplace) : `adresses_hote` n'a plus d'appelant que ses unitaires jusqu'à sa suppression en 3 bis.
9. **Copier le lien** : `DisplayServer.clipboard_set` seulement si `DisplayServer.has_feature(FEATURE_CLIPBOARD)` (pas en headless) ; le bouton dit « Lien copié ! » 2 s ; `copier_lien()` renvoie le lien copié (ce que vérifie le smoke test). Les captures ne cliquent pas le bouton : le presse-papiers du développeur reste à lui.
10. **Sur un hôte perdu, l'écran En ligne affiche `Reseau.raison_perte`** (comme la scène de jeu et le salon), au lieu de la constante de l'écran Réseau.
11. **Test réseau : les scénarios 6 et 7 (découverte) partent, les autres gardent leur numéro et leurs ports** (1 à 5, 8 à 13 : onze scénarios ; renuméroter aurait réécrit tous les renvois au « scénario 11 » des plans, de la spec et des tests). Spec §3.1 et §10 mises à jour (Task 13).
12. **L'empreinte du protocole est renotée sans hausse de version** (Task 11) : la ligne retirée est celle de la balise de découverte, qui n'existe plus ; ce que deux postes 0.20 se disent (RPC, réplication, formats, poignée de main) ne change pas, et aucune 0.20 n'a été publiée.
13. **Entre les Tasks 10 et 12, l'autoload `Decouverte` vit encore sans que les tests le redirigent** : un hôte de test émet alors sa balise vers le port 7778 de ce poste (comme le jeu 0.19), le temps de deux commits ; la Task 12 le supprime. Faire tout en une tâche aurait touché dix fichiers de code.
14. **Captures** : la partie `reseau` passe de 10 à 11 captures (l'écran En ligne comme sur le Web : accueil, code trop court, confusion, partie inconnue, pas de transport, anglais, lien d'invitation ; puis le desktop : connexion, refus de version), `salon_00_hote_seul` montre « Code de la partie : K7Q-2XM » et *Copier le lien* (un code de salle posé à la main) : 38 captures (CI ajustée en Task 5), 5 et 6 pour les deux fenêtres (inchangé).
15. **Les deux fenêtres gardent leurs captures** : `_nettoyer_mes_fichiers` effaçait tout fichier `hote_*` / `client_*` du dossier, ses PNG compris (le contrôle visuel n'en trouvait aucun) ; il n'efface plus que les rendez-vous, sans extension (Task 5).
16. **Repris de la phase 1** : la docstring de `Reseau.hote_perdu` disait que personne ne l'écoutait côté hôte (`Main.gd` et `Salon.gd` l'écoutent) : corrigée en Task 2.
17. **Step 0** (règle du projet, `Reseau.gd` 1105 lignes, `Salon.gd` 324 lignes) : rien à retirer (vérifié, Task 0) ; la phase n'y fait pas de refonte structurelle.

---

### Task 0 : préparation, Step 0 et référence

Ce plan est commité par le commit de planification : ne pas le recommiter, ne jamais le modifier.

- [ ] **Step 1 : la branche**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
git switch main && git pull --ff-only
git log --oneline main | grep -m1 "phase-02-signalisation" || echo "PHASE 2 ABSENTE"
git switch -c phase-03-ecran-en-ligne
wc -l Scripts/Reseau.gd Scripts/Salon.gd; grep -n 'config/version' project.godot; ls signalisation/src/code.js
```

Expected : la fusion de la PR de la phase 2 (`Merge pull request #3 from w3cdotorg/phase-02-signalisation`) ; `1105 Scripts/Reseau.gd`, `324 Scripts/Salon.gd` ; `config/version="0.20"` ; `signalisation/src/code.js` existe. « PHASE 2 ABSENTE » ou d'autres longueurs : s'arrêter et le signaler.

- [ ] **Step 2 : Step 0 (règle du projet, `Reseau.gd` et `Salon.gd` font plus de 300 lignes)**

```bash
for f in Scripts/Reseau.gd Scripts/Salon.gd; do
	for n in $(grep -oE "^(const|var|func|static func|signal|enum) [A-Za-z_]+" $f | awk '{print $NF}'); do
		[ "$(grep -rwo "$n" Scripts tests Scenes | wc -l | tr -d ' ')" -lt 2 ] && echo "seul : $f $n"
	done
	grep -nE "^[[:space:]]*(print|prints|printt|print_debug|breakpoint)\b" $f
done
```

Expected (mesuré) : rien. **Pas de commit de nettoyage.** Une ligne `seul :` ou un `print` (le code a bougé depuis ce plan) : le retirer dans un commit à part (`Step 0 : code mort retiré`) avant la Task 1.

- [ ] **Step 3 : la référence**

```bash
timeout 300 godot --headless --import . > /dev/null 2>&1
timeout -k 5 300 godot --headless --script tests/unitaires.gd 2>&1 | grep -E "PROTOCOLE|== "
SECONDS=0; DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r0.log" 2>&1; echo "code $? en ${SECONDS} s"
grep -E "❌|== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r0.log"
(cd signalisation && npm ci --silent && npm test 2>&1 | tail -3)
```

Expected : `PROTOCOLE 0.20 815376087 (68 lignes)`, `== 0 échec(s) ==` ; réseau `code 0`, `== 0 échec(s) ==`, 160 à 180 s ; les tests du Worker verts. Noter les mesures pour la PR (jamais commitées).

---

### Task 1 : le code de salle (`CodeSalle`)

**Files:**
- Create: `Scripts/CodeSalle.gd` (+ `.uid` généré par l'import)
- Modify: `project.godot` (section `[lelion]`, avant `[rendering]`)
- Test: `tests/unitaires.gd` (`_run`, nouvelle `_tester_code_salle` avant `_tester_transport_enet`)

**Interfaces:**
- Consumes : `ProjectSettings`, `OS.has_feature("web")`, `JavaScriptBridge.eval` (Godot 4.7.2) ; `signalisation/src/code.js` (lu par le test seulement).
- Produces (Tasks 3, 4, 5) : `class_name CodeSalle extends RefCounted` ; `const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"`, `LONGUEUR := 6`, `CONFUSIONS := "01ILO"`, `SEPARATEURS := " \t-"`, `PARAMETRE := "salle"`, `URL_PAGE := "https://w3cdotorg.github.io/LeLion-web/"`, `ERREUR_FORMAT := "ENLIGNE_CODE_FORMAT"`, `ERREUR_CONFUSION := "ENLIGNE_CODE_CONFUSION"` ; `static var recherche_forcee := ""`, `static var _page_lue := false` ; `static func normaliser(texte: String) -> String`, `static func valide(code: String) -> bool`, `static func erreur(texte: String) -> String`, `static func formater(code: String) -> String`, `static func lien(code: String) -> String`, `static func url_page() -> String`, `static func lire_recherche(recherche: String) -> String`, `static func prendre_code_de_la_page() -> String`. Réglage de projet `lelion/page/url`.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_placement_pseudos()
	_tester_bilan_manche()
	_tester_manches_enchainees()
	_tester_transport_enet()
	await _tester_battement()
	_tester_protocole()
```

par :

```gdscript
	_tester_placement_pseudos()
	_tester_bilan_manche()
	_tester_manches_enchainees()
	_tester_code_salle()
	_tester_transport_enet()
	await _tester_battement()
	_tester_protocole()
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	return lignes


## Phase 1 du jeu en ligne : le transport ENet, seul (sans `Reseau` ni `SceneMultiplayer`) : son code,
## l'ouverture du canal, le délai d'un client sans hôte, la libération d'un pair figé (I1), le départ
## (DISCONNECT après la file, servi par `servir()`), la fermeture immédiate.
```

par :

```gdscript
	return lignes


## Phase 3 du jeu en ligne : le code de salle (alphabet, celui du Worker ; saisie, format, lien
## d'invitation, lecture de `?salle=`).
func _tester_code_salle() -> void:
	print("-- Code de salle (phase 3)")
	var lettres := PackedStringArray()
	for c in CodeSalle.ALPHABET:
		lettres.append(c)
	var distinctes := lettres.size() == 31
	for c in lettres:
		distinctes = distinctes and lettres.count(c) == 1 and not CodeSalle.CONFUSIONS.contains(c)
	_check(distinctes and CodeSalle.LONGUEUR == 6 and CodeSalle.CONFUSIONS == "01ILO",
		"31 caractères distincts, sans 0, O, 1, I ni L ; 6 par code")
	var source := FileAccess.get_file_as_string("res://signalisation/src/code.js")
	var alphabet_worker := RegEx.create_from_string("export const ALPHABET = \"([0-9A-Z]+)\";").search(source)
	var longueur_worker := RegEx.create_from_string("export const LONGUEUR_CODE = ([0-9]+);").search(source)
	_check(alphabet_worker != null and alphabet_worker.get_string(1) == CodeSalle.ALPHABET
		and longueur_worker != null and longueur_worker.get_string(1).to_int() == CodeSalle.LONGUEUR,
		"le même alphabet et la même longueur que le Worker (signalisation/src/code.js)")

	# La saisie : sans casse, sans espaces ni tirets ; un caractère qu'on confond a son propre message
	_check(CodeSalle.normaliser(" k7q-2xm ") == "K7Q2XM" and CodeSalle.normaliser("k7q 2\txm") == "K7Q2XM",
		"la saisie se lit sans casse, sans espaces, tabulations ni tirets (%s)" % CodeSalle.normaliser(" k7q-2xm "))
	var bons := ["K7Q2XM", "K7Q-2XM", "k7q-2xm", " K7Q 2XM ", "2345-67", "zzz-zzz"]
	_check(bons.all(func(t: String) -> bool: return CodeSalle.erreur(t).is_empty()), "des codes bien formés (%s)" % [bons])
	var format := ["", "K7Q2X", "K7Q-2XM9", "K7Q_2XM", "K7Q.2XM", "K7Q#2XM", "ſ7Q2XM", "K7Q–2XM", "ÉÀÇ2XM"]
	_check(format.all(func(t: String) -> bool: return CodeSalle.erreur(t) == CodeSalle.ERREUR_FORMAT),
		"mal formés : trop court, trop long, un autre séparateur (« _ », « . », tiret long), un caractère hors de l'alphabet, une lettre non ASCII qui ressemble à une lettre du code (« ſ »)")
	var confusions := ["K0Q2XM", "KOQ2XM", "K1Q2XM", "KIQ2XM", "KLQ2XM", "ko q2xm", "kl", "l7q2x"]
	_check(confusions.all(func(t: String) -> bool: return CodeSalle.erreur(t) == CodeSalle.ERREUR_CONFUSION),
		"un 0, un O, un 1, un I ou un L (minuscule comprise, même dans un code trop court) : refusé avec son message, jamais remplacé")
	_check(not CodeSalle.valide("k7q2xm") and CodeSalle.valide("K7Q2XM"), "valide() attend un code déjà normalisé")

	# L'affichage et le lien d'invitation
	_check(CodeSalle.formater("K7Q2XM") == "K7Q-2XM" and CodeSalle.formater("127.0.0.1:7777") == "127.0.0.1:7777",
		"un code s'affiche « K7Q-2XM » ; un autre texte (l'adresse d'un hôte ENet) tel quel")
	_check(ProjectSettings.get_setting("lelion/page/url", "") == CodeSalle.URL_PAGE
		and CodeSalle.lien("K7Q2XM") == "https://w3cdotorg.github.io/LeLion-web/?salle=K7Q2XM",
		"hors du Web, le lien d'invitation part du réglage lelion/page/url (%s)" % CodeSalle.lien("K7Q2XM"))

	# `?salle=` : le premier paramètre salle, décodé et normalisé, s'il est un code
	var recherches := {"?salle=K7Q2XM": "K7Q2XM", "?relais=1&salle=k7q-2xm": "K7Q2XM", "?salle=K7Q%2D2XM": "K7Q2XM",
		"salle=K7Q2XM": "K7Q2XM", "?salle=K7Q2XM&salle=ABCDEF": "K7Q2XM", "?salle=K0Q2XM": "", "?salle=": "", "?salle": "",
		"": "", "?": "", "?sallex=K7Q2XM": "", "?relais=1": ""}
	var lues: Array[String] = []
	for recherche: String in recherches:
		if CodeSalle.lire_recherche(recherche) != recherches[recherche]:
			lues.append("%s → %s" % [recherche, CodeSalle.lire_recherche(recherche)])
	_check(lues.is_empty(), "?salle= lu sans casse ni tiret, décodé, parmi d'autres paramètres ; vide, absent ou mal formé : aucun code (%s)" % [lues])
	CodeSalle.recherche_forcee = "?salle=k7q-2xm"
	CodeSalle._page_lue = false
	var premier := CodeSalle.prendre_code_de_la_page()
	var second := CodeSalle.prendre_code_de_la_page()
	CodeSalle.recherche_forcee = ""
	_check(premier == "K7Q2XM" and second.is_empty(), "le lien de la page ne sert qu'une fois par lancement (%s, puis « %s »)" % [premier, second])


## Phase 1 du jeu en ligne : le transport ENet, seul (sans `Reseau` ni `SceneMultiplayer`) : son code,
## l'ouverture du canal, le délai d'un client sans hôte, la libération d'un pair figé (I1), le départ
## (DISCONNECT après la file, servi par `servir()`), la fermeture immédiate.
```

- [ ] **Step 2 : ils échouent**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
timeout -k 5 120 godot --headless --script tests/unitaires.gd 2>&1 | grep -E "SCRIPT ERROR|== " | sort | uniq -c
```

Expected : `SCRIPT ERROR: Parse Error: Identifier "CodeSalle" not declared in the current scope.` (28 fois) et deux `Cannot infer the type of "premier"` / `"second"`, aucune ligne `== n échec(s) ==` (le script ne compile pas : le code de sortie peut être 0).

- [ ] **Step 3 : le code**

Créer `Scripts/CodeSalle.gd` :

```gdscript
class_name CodeSalle
extends RefCounted
## Le code d'une salle de la signalisation (spec §2, §4.4 du jeu en ligne) : 6 caractères d'un alphabet
## sans 0/O ni 1/I/L, affiché « K7Q-2XM », et le lien d'invitation qui le porte (`?salle=K7Q2XM`).
## Logique pure, sans autoload : la saisie d'un joueur se lit sans casse, sans espaces ni tirets (le
## Worker refuse le tiret : le jeu l'enlève) ; un caractère qu'on confond (0, O, 1, I, L) est refusé
## avec son propre message plutôt que remplacé en silence (un O lu comme un 0 mènerait chez un autre).

## Les 31 caractères d'un code : ceux du Worker (`signalisation/src/code.js`, ALPHABET).
const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const LONGUEUR := 6
## Les caractères qu'on prend pour d'autres, absents de l'alphabet.
const CONFUSIONS := "01ILO"
## Ce que la saisie ignore : espaces et tirets (« K7Q-2XM », « k7q 2xm »).
const SEPARATEURS := " \t-"
## Le paramètre de l'adresse de la page qui porte le code (`?salle=K7Q2XM`).
const PARAMETRE := "salle"
## L'adresse de la page du jeu en ligne (spec §2), si le réglage `lelion/page/url` manque.
const URL_PAGE := "https://w3cdotorg.github.io/LeLion-web/"
## Pourquoi une saisie n'est pas un code (`erreur`), en clés de traduction (spec §9).
const ERREUR_FORMAT := "ENLIGNE_CODE_FORMAT"
const ERREUR_CONFUSION := "ENLIGNE_CODE_CONFUSION"

## Si non vide, tient lieu de `location.search` (les tests, hors du Web).
static var recherche_forcee := ""
## Vrai une fois le lien de la page lu (`prendre_code_de_la_page`) : il ne sert qu'une fois par lancement.
static var _page_lue := false


## `texte` sans espaces ni tirets, ses lettres ASCII en majuscules ; rien d'autre ne change (un caractère
## hors ASCII reste tel quel, et le code est alors refusé : aucune lettre accentuée ni « ſ » n'y devient
## une lettre de l'alphabet).
static func normaliser(texte: String) -> String:
	var sortie := ""
	for c in texte:
		if SEPARATEURS.contains(c):
			continue
		sortie += c.to_upper() if c >= "a" and c <= "z" else c
	return sortie


## Vrai si `code`, déjà normalisé, est un code de salle : LONGUEUR caractères de l'ALPHABET.
static func valide(code: String) -> bool:
	if code.length() != LONGUEUR:
		return false
	for c in code:
		if not ALPHABET.contains(c):
			return false
	return true


## Pourquoi la saisie `texte` n'est pas un code : ERREUR_CONFUSION si elle a un 0, un O, un 1, un I ou un
## L (en minuscules aussi), ERREUR_FORMAT pour tout le reste ; vide si c'en est un.
static func erreur(texte: String) -> String:
	var code := normaliser(texte)
	if valide(code):
		return ""
	for c in code:
		if CONFUSIONS.contains(c):
			return ERREUR_CONFUSION
	return ERREUR_FORMAT


## Le code tel qu'il s'affiche, « K7Q-2XM » ; un texte qui n'est pas un code reste tel quel (l'adresse
## `ip:port` d'un hôte ENet, sur le desktop de développement).
static func formater(code: String) -> String:
	return "%s-%s" % [code.substr(0, 3), code.substr(3)] if valide(code) else code


## Le lien d'invitation à la salle `code` : l'adresse de la page (`url_page`), puis `?salle=<code>`.
static func lien(code: String) -> String:
	return "%s?%s=%s" % [url_page(), PARAMETRE, code]


## L'adresse de la page du jeu : sur le Web, celle de la page ouverte (son origine et son chemin, sans ses
## paramètres : un lien copié d'une préversion ou d'un test local y ramène) ; ailleurs, le réglage
## `lelion/page/url` (URL_PAGE par défaut).
static func url_page() -> String:
	if OS.has_feature("web"):
		var page: Variant = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
		if page is String and not (page as String).is_empty():
			return page
	return str(ProjectSettings.get_setting("lelion/page/url", URL_PAGE))


## Le code que porte la partie recherche d'une adresse (`location.search` : « ?salle=K7Q2XM&… ») : le
## premier paramètre `salle`, décodé et normalisé, s'il est un code ; vide sinon.
static func lire_recherche(recherche: String) -> String:
	for paire in recherche.trim_prefix("?").split("&", false):
		var morceaux := paire.split("=", true, 1)
		if morceaux[0] == PARAMETRE and morceaux.size() == 2:
			var code := normaliser(morceaux[1].uri_decode())
			return code if valide(code) else ""
	return ""


## Le code du lien qui a ouvert la page (`?salle=`, spec §4.4), une seule fois par lancement : le premier
## écran titre emmène le joueur à l'écran En ligne ; vide ensuite, hors du Web, ou sans code valide.
static func prendre_code_de_la_page() -> String:
	if _page_lue:
		return ""
	_page_lue = true
	var recherche := recherche_forcee
	if recherche.is_empty() and OS.has_feature("web"):
		recherche = str(JavaScriptBridge.eval("window.location.search", true))
	return lire_recherche(recherche)
```

Dans `project.godot`, remplacer :

```
]
}

[rendering]

renderer/rendering_method="mobile"
```

par :

```
]
}

[lelion]

page/url="https://w3cdotorg.github.io/LeLion-web/"

[rendering]

renderer/rendering_method="mobile"
```

- [ ] **Step 4 : ils passent**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; ls Scripts/CodeSalle.gd.uid
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"
sed -n '/Code de salle/,/Transport ENet/p' "$TMPDIR/u.log"; grep -E "❌|PROTOCOLE|== " "$TMPDIR/u.log"
```

Expected : rien à l'import, le `.uid` existe ; `code 0`, les 11 vérifications du code de salle en ✅ (dont « le même alphabet et la même longueur que le Worker »), `PROTOCOLE 0.20 815376087 (68 lignes)`, `== 0 échec(s) ==`.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/CodeSalle.gd Scripts/CodeSalle.gd.uid project.godot tests/unitaires.gd
git commit -m "CodeSalle : le code de salle (alphabet du Worker sans 0/O ni 1/I/L, saisie sans casse ni espaces ni tirets, un caractère qu'on confond refusé avec son message, format K7Q-2XM, lien d'invitation depuis la page ou le réglage lelion/page/url, ?salle= lu une fois par lancement) ; unitaires, alphabet recoupé avec signalisation/src/code.js

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 2 : les entrées de l'écran dans `Reseau`, les raisons d'échec du transport

**Files:**
- Modify: `Scripts/Transport.gd` (constantes ECHEC_*)
- Modify: `Scripts/Reseau.gd` (docstrings de `connexion_echouee` et `hote_perdu`, `raison_echec`, `transport_disponible`, `_raison_transport`, `rejoindre` → `rejoindre_partie`, `creer_partie`, `quitter`, `_sur_transport_echec`, `_fermer_puis_emettre`)
- Test: `tests/unitaires.gd` (`_run`, nouvelle `_tester_parties_en_ligne` avant `_attendre`)

**Interfaces:**
- Consumes : `Transport.echec`, `TransportENet.lire_code` (via `rejoindre`), `_nouveau_transport`.
- Produces (Tasks 3 à 5, phase 4) : `Transport.ECHEC_INJOIGNABLE := "injoignable"`, `ECHEC_INCONNUE := "inconnue"`, `ECHEC_PLEINE := "pleine"`, `ECHEC_DEBIT := "debit"`, `ECHEC_QUOTA := "quota"`, `ECHEC_ORIGINE := "origine"`, `ECHEC_EXPIREE := "expiree"` ; `Reseau.raison_echec: String`, `Reseau.transport_disponible: bool` ; `func creer_partie(port := PORT) -> Error`, `func rejoindre_partie(code: String) -> Error` ; `rejoindre(adresse, port := PORT)` et `heberger(port := PORT)` inchangés pour leurs appelants.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_code_salle()
	_tester_transport_enet()
	await _tester_battement()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

par :

```gdscript
	_tester_code_salle()
	_tester_transport_enet()
	await _tester_battement()
	await _tester_parties_en_ligne()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	hote.pseudo = ""


## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
## valeur.
func _attendre(condition: Callable, delai: float) -> bool:
```

par :

```gdscript
	hote.pseudo = ""


## Phase 3 du jeu en ligne : les entrées de l'écran En ligne dans `Reseau` (créer une partie, en rejoindre
## une par son code, une plateforme sans transport) et la raison d'un échec de connexion, donnée par le
## transport (`raison_echec`).
func _tester_parties_en_ligne() -> void:
	print("-- Parties en ligne (phase 3)")
	var reseau: Node = root.get_node("Reseau")  # autoload : jamais nommé (compilé avant lui)
	var port := 17787
	_check(reseau.transport_disponible, "hors du Web, ce poste a un transport pour jouer en réseau (ENet)")
	_check(reseau.creer_partie(port) == OK and reseau.en_ligne() and root.multiplayer.is_server() and reseau.code_partie == "127.0.0.1:%d" % port,
		"créer une partie : ce poste héberge, le code de la partie vient du transport (%s)" % reseau.code_partie)
	_check(reseau.rejoindre_partie("K7Q2XM") == ERR_INVALID_PARAMETER and reseau.en_ligne() and root.multiplayer.is_server(),
		"en ENet, un code de salle n'est pas une adresse : refusé sans toucher à la session en cours")
	reseau.quitter()

	var raisons: Array[String] = []
	var sur_echec := func() -> void: raisons.append(reseau.raison_echec)
	reseau.connexion_echouee.connect(sur_echec)
	_check(reseau.rejoindre_partie(" 127.0.0.1:%d " % (port + 1)) == OK and reseau.en_ligne() and not root.multiplayer.is_server(),
		"rejoindre une partie par son code : ce poste se connecte (« ip:port », espaces autour)")
	reseau._transport.echec.emit(Transport.ECHEC_INCONNUE)  # ce que dira TransportWebRTC d'un code sans salle (phase 4)
	_check(await _attendre(func() -> bool: return not raisons.is_empty(), 1.0) and raisons == [Transport.ECHEC_INCONNUE] and not reseau.en_ligne(),
		"le transport échoue : connexion échouée, ce poste hors réseau, sa raison dans raison_echec (%s)" % [raisons])
	_check(reseau.rejoindre_partie("127.0.0.1:%d" % (port + 1)) == OK, "(pré-condition) ce poste se connecte de nouveau")
	reseau._sur_delai_depasse()  # la poignée de main sans réponse dans son délai
	_check(await _attendre(func() -> bool: return raisons.size() == 2, 1.0) and raisons[1].is_empty(),
		"un échec sans raison du transport (la poignée de main) : raison_echec vide, rien de l'échec précédent (%s)" % [raisons])
	reseau.connexion_echouee.disconnect(sur_echec)

	reseau.transport_disponible = false
	_check(reseau.creer_partie(port) == ERR_UNAVAILABLE and reseau.rejoindre_partie("127.0.0.1:%d" % port) == ERR_UNAVAILABLE
		and not reseau.en_ligne() and reseau._transport == null,
		"sans transport sur ce poste (l'export Web avant la phase 4) : ni créer ni rejoindre, rien d'ouvert")
	reseau.transport_disponible = true
	await _attendre(func() -> bool: return reseau._partants.is_empty(), 2.0)


## Attend, image après image, que `condition` soit vraie, `delai` secondes au plus ; renvoie sa dernière
## valeur.
func _attendre(condition: Callable, delai: float) -> bool:
```

- [ ] **Step 2 : ils échouent**

```bash
timeout -k 5 120 godot --headless --script tests/unitaires.gd 2>&1 | grep -E "SCRIPT ERROR|== "
```

Expected : `SCRIPT ERROR: Parse Error: Cannot find member "ECHEC_INCONNUE" in base "Transport".` (deux fois), aucune ligne `== n échec(s) ==`.

- [ ] **Step 3 : le code**

Dans `Scripts/Transport.gd`, remplacer :

```gdscript
## se ferme pas seul : l'appelant le quitte ensuite (`quitter()`).
signal echec(raison: String)

## Le canal vers l'hôte ne s'est pas ouvert dans le délai du transport.
const ECHEC_DELAI := "delai"


## Ouvre une session hébergée ; `pret` part quand elle existe (pendant l'appel ou plus tard, selon le
```

par :

```gdscript
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
const ECHEC_PLEINE := "pleine"
const ECHEC_DEBIT := "debit"
const ECHEC_QUOTA := "quota"
const ECHEC_ORIGINE := "origine"
const ECHEC_EXPIREE := "expiree"


## Ouvre une session hébergée ; `pret` part quand elle existe (pendant l'appel ou plus tard, selon le
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## pour l'écran Réseau de la phase 12), `version_hote` la version de l'hôte. Le poste est déjà
## revenu hors réseau quand le signal part.
signal refuse(raison: String, version_hote: String)
## Chez le client : pas d'inscription dans le délai (IP qui ne répond pas, port fermé). Le poste
## est déjà revenu hors réseau quand le signal part.
signal connexion_echouee()
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
## réseau quand le signal part ; `raison_perte` dit pourquoi (phase 18 : un joueur exclu par la barrière
## de chargement le sait). N4 : si le pair de l'hôte tombe lui-même en erreur, ou si son transport se
## ferme de lui-même (`Transport.servir` faux), ce même signal part aussi chez l'hôte (server_disconnected
## n'y distingue pas les deux cas) ; personne ne l'écoute encore côté hôte à cette phase, mais un futur
## appelant ne doit pas supposer « jamais chez l'hôte ».
signal hote_perdu()
## Sur chaque poste en session : la table du salon (`table_salon`), son niveau ou ses places ont
## changé ; chez l'hôte, aussi quand une place se réserve ou se libère (le bouton Démarrer en
```

par :

```gdscript
## pour l'écran Réseau de la phase 12), `version_hote` la version de l'hôte. Le poste est déjà
## revenu hors réseau quand le signal part.
signal refuse(raison: String, version_hote: String)
## Chez le client : pas d'inscription (le transport n'a pas ouvert son canal, ou la poignée de main n'a
## pas fini dans son délai). Le poste est déjà revenu hors réseau quand le signal part ; `raison_echec`
## dit pourquoi.
signal connexion_echouee()
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
## réseau quand le signal part ; `raison_perte` dit pourquoi (phase 18 : un joueur exclu par la barrière
## de chargement le sait). N4 : si le pair de l'hôte tombe lui-même en erreur, ou si son transport se
## ferme de lui-même (`Transport.servir` faux), ce même signal part aussi chez l'hôte (server_disconnected
## n'y distingue pas les deux cas) : le salon et la scène de jeu l'écoutent des deux côtés (l'hôte qui
## perd sa session revient à l'écran En ligne, ou au titre depuis une manche, comme un client).
signal hote_perdu()
## Sur chaque poste en session : la table du salon (`table_salon`), son niveau ou ses places ont
## changé ; chez l'hôte, aussi quand une place se réserve ou se libère (le bouton Démarrer en
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE ou PERTE_EXCLU), posé juste
## avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
var index_local := -1
var couleur_locale := Color.TRANSPARENT
```

par :

```gdscript
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE ou PERTE_EXCLU), posé juste
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
var couleur_locale := Color.TRANSPARENT
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
var _exclu := false
## Les pairs dont ce poste écoute le silence : par identifiant, l'instant (ms) où il a reçu d'eux pour
## la dernière fois. Chez l'hôte, chaque client arrivé (sa poignée de main finie) ; chez un client,
## l'hôte, une fois inscrit. Vide hors réseau.
```

par :

```gdscript
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
var _exclu := false
## Chez un client : la raison de l'échec du transport de la session (`Transport.echec`), jusqu'à l'échec
## de connexion qui suit (`raison_echec`).
var _raison_transport := ""
## Les pairs dont ce poste écoute le silence : par identifiant, l'instant (ms) où il a reçu d'eux pour
## la dernière fois. Chez l'hôte, chaque client arrivé (sa poignée de main finie) ; chez un client,
## l'hôte, une fois inscrit. Vide hors réseau.
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
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
```

par :

```gdscript
	return OK


## Rejoint l'hôte ENet à `adresse` (une IPv4) et `port` : `rejoindre_partie` avec le code `adresse:port`
## (les tests et le desktop de développement).
func rejoindre(adresse: String, port := PORT) -> Error:
	return rejoindre_partie("%s:%d" % [adresse.strip_edges(), port])


## Crée une partie (l'écran En ligne) : `heberger(port)` si ce poste a un transport pour jouer en réseau
## (`transport_disponible`), sinon ERR_UNAVAILABLE sans rien changer. Son code (`code_partie`) vient du
## transport : `ip:port` en ENet, un code de salle en WebRTC (phase 4).
func creer_partie(port := PORT) -> Error:
	if not transport_disponible:
		return ERR_UNAVAILABLE
	return heberger(port)


## Rejoint la partie `code` avec le transport de ce poste (l'écran En ligne) : un code de salle en WebRTC
## (phase 4), le code `ip:port` (ou `ip`) d'un hôte en ENet. Un code que le transport refuse
## (ERR_INVALID_PARAMETER, M8 : aucun nom d'hôte, dont la résolution bloquerait le jeu), ou aucun transport
## (`transport_disponible` faux : ERR_UNAVAILABLE), ne change rien, pas même la session en cours. La
## réponse arrive par `inscrit`, `refuse` ou `connexion_echouee` (au plus tard après le délai du canal du
## transport, puis DELAI_CONNEXION). Renvoie l'erreur du transport si le client ne peut même pas être créé.
func rejoindre_partie(code: String) -> Error:
	if not transport_disponible:
		return ERR_UNAVAILABLE
	var transport := _nouveau_transport(PORT)
	var erreur := transport.rejoindre(code)
	if erreur != OK:
		return erreur
	quitter()
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	silence = SILENCE_SESSION
	_entendus.clear()
	code_partie = ""
	_connexion_en_cours = false
	niveau_salon = 0
	places_salon = EtatPartie.NB_JOUEURS_MAX
```

par :

```gdscript
	silence = SILENCE_SESSION
	_entendus.clear()
	code_partie = ""
	_raison_transport = ""
	_connexion_en_cours = false
	niveau_salon = 0
	places_salon = EtatPartie.NB_JOUEURS_MAX
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
		_delai.start(DELAI_CONNEXION)


## Chez un client : le canal vers l'hôte ne s'ouvrira pas (`raison`, Transport.ECHEC_* : l'écran En
## ligne, phase 3, en fera un message ; ici, un échec de connexion).
func _sur_transport_echec(_raison: String, generation: int) -> void:
	if generation == _generation and _connexion_en_cours:
		_decider("connexion_echouee")


```

par :

```gdscript
		_delai.start(DELAI_CONNEXION)


## Chez un client : le canal vers l'hôte ne s'ouvrira pas : un échec de connexion, dont `raison`
## (Transport.ECHEC_*) devient `raison_echec`.
func _sur_transport_echec(raison: String, generation: int) -> void:
	if generation == _generation and _connexion_en_cours and not _issue_decidee:
		_raison_transport = raison
		_decider("connexion_echouee")


```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	if generation != _generation:
		return
	var exclu := _exclu
	quitter()
	if nom == &"hote_perdu":
		raison_perte = PERTE_EXCLU if exclu else PERTE_HOTE
	callv("emit_signal", [nom] + arguments)
```

par :

```gdscript
	if generation != _generation:
		return
	var exclu := _exclu
	var raison_transport := _raison_transport
	quitter()
	if nom == &"hote_perdu":
		raison_perte = PERTE_EXCLU if exclu else PERTE_HOTE
	elif nom == &"connexion_echouee":
		raison_echec = raison_transport
	callv("emit_signal", [nom] + arguments)
```

- [ ] **Step 4 : ils passent, rien d'autre ne bouge**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"
sed -n '/Parties en ligne/,/Version du protocole/p' "$TMPDIR/u.log"; grep -E "❌|PROTOCOLE|== " "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"
grep -c "personne ne l'écoute" Scripts/Reseau.gd
```

Expected : unitaires `0`, les 8 vérifications « Parties en ligne » en ✅ (`raison_echec` : `["inconnue"]`, puis `["inconnue", ""]`), `PROTOCOLE 0.20 815376087 (68 lignes)` (aucune RPC ne change), `== 0 échec(s) ==` ; smoke `0`, `== 0 échec(s) ==` ; `0`.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Transport.gd Scripts/Reseau.gd tests/unitaires.gd
git commit -m "Reseau : creer_partie et rejoindre_partie(code), les entrées de l'écran En ligne (ERR_UNAVAILABLE sans transport : l'export Web avant la phase 4) ; raison_echec, la raison du transport posée avant connexion_echouee ; Transport : les raisons de la signalisation (inconnue, pleine, debit, quota, origine, expiree, injoignable) ; docstring de hote_perdu corrigée (le salon et la scène de jeu l'écoutent chez l'hôte)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 3 : l'écran En ligne, et le titre qui l'ouvre

**Files:**
- Create: `Scripts/EcranEnLigne.gd` (+ `.uid` généré par l'import), `Scenes/EcranEnLigne.tscn`
- Modify: `Assets/Traductions/traductions.csv` (13 clés après `RESEAU_HEBERGER_IMPOSSIBLE`) (+ les deux `.translation` régénérés)
- Modify: `Scripts/Titre.gd` (en-tête, `SCENE_EN_LIGNE`, `_EcranEnLigne`, fin de `_ready`, `ouvrir_reseau` → `ouvrir_en_ligne`)
- Test: `tests/smoke_test.gd` (`_run`, nouvelle `_tester_ecran_en_ligne`, `_tester_titre_reseau`)

**Interfaces:**
- Consumes : `CodeSalle` (Task 1) ; `Reseau.creer_partie`, `rejoindre_partie`, `raison_echec`, `transport_disponible`, `raison_perte`, `REFUS_*`, `PSEUDO_MAX`, `pseudo_valide`, signaux `inscrit`, `refuse`, `connexion_echouee`, `hote_perdu` (Task 2) ; `TransportENet.lire_code` ; `Scores`, `Parametres.langue_changee`, `Regles.appliquer_ecran`, `ReglesBataille.TAILLE_ECRAN`.
- Produces (Tasks 4, 5) : `Scenes/EcranEnLigne.tscn` (`Centre/Colonne/RangeePseudo/Pseudo`, `Centre/Colonne/Creer`, `Centre/Colonne/RangeeCode/Code`, `Centre/Colonne/RangeeCode/Rejoindre`, `Centre/Colonne/Message`, `BoutonRetour`) ; `EcranEnLigne.gd` : `enum Etat { ACCUEIL, CONNEXION, SALON }`, `const MESSAGES_ECHEC`, `ECHEC_PAR_DEFAUT := "ENLIGNE_ECHEC_CANAL"`, `var port_jeu: int`, `var codes_de_salle: bool`, `var etat`, `static var message_a_l_arrivee := ""`, `static var code_a_l_arrivee := ""`, `champ_pseudo`, `bouton_creer`, `champ_code`, `bouton_rejoindre`, `message`, `bouton_retour` ; `func creer_partie() -> void`, `func rejoindre() -> void`, `func retour(changer_scene := true) -> void`, `static func cle_echec(raison: String) -> String`. `Titre.ouvrir_en_ligne()`.

- [ ] **Step 1 : les tests**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	GS.niveau_courant = 0

	await _tester_ecran_reseau(scores, params)
	await _tester_titre_reseau(scores)
	await _tester_salon(params)

```

par :

```gdscript
	GS.niveau_courant = 0

	await _tester_ecran_reseau(scores, params)
	await _tester_ecran_en_ligne(scores, params)
	await _tester_titre_reseau(scores)
	await _tester_salon(params)

```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	scores.effacer()


## Phase 12 bis : le bouton Multijoueur du titre, l'aller et retour avec l'écran Réseau, et le titre
## qui remet toujours ce poste hors réseau avant le solo.
func _tester_titre_reseau(scores: Node) -> void:
	print("-- Titre et réseau")
	var reseau: Node = root.get_node("Reseau")
```

par :

```gdscript
	scores.effacer()


## Phase 3 du jeu en ligne : l'écran En ligne (pseudo, Créer une partie, Rejoindre avec un code de salle
## ou, sur le desktop, l'adresse d'un hôte ENet ; les refus, les échecs et leur message, spec §9 ; un poste
## sans transport). Les signaux de `Reseau` sont émis comme il le fait (après être revenu hors réseau pour
## les échecs) : le transport lui-même est couvert par tests/reseau/lancer.sh.
func _tester_ecran_en_ligne(scores: Node, params: Node) -> void:
	print("-- Écran En ligne")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	scores.definir_preference("pseudo", "Léa")
	var ecran: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran.port_jeu = 17797
	ecran.codes_de_salle = true  # comme sur le Web
	root.add_child(ecran)
	await _frames(1)

	# Accueil : 16:9, Créer une partie au focus, pseudo mémorisé et borné, un exemple de code
	_check(root.content_scale_size == Vector2i(2000, 1125) and ecran.etat == ecran.Etat.ACCUEIL and ecran.bouton_creer.has_focus()
		and ecran.message.text.is_empty(), "l'écran En ligne passe en 16:9 ; à l'accueil, Créer une partie a le focus")
	_check(ecran.champ_pseudo.text == "Léa" and ecran.champ_pseudo.max_length == reseau.PSEUDO_MAX and ecran.champ_code.placeholder_text == "K7Q-2XM",
		"le pseudo mémorisé est repris, la saisie bornée à %d caractères ; le champ du code montre « K7Q-2XM »" % reseau.PSEUDO_MAX)

	# Un code mal formé est refusé à la saisie (spec §9), sans rien tenter, le focus sur le code
	var refus := {"K7Q2X": "ENLIGNE_CODE_FORMAT", "K7Q-2XM9": "ENLIGNE_CODE_FORMAT", "": "ENLIGNE_CODE_FORMAT", "k7q-2o1": "ENLIGNE_CODE_CONFUSION"}
	var faux: Array[String] = []
	for saisie: String in refus:
		ecran.champ_code.text = saisie
		ecran.bouton_creer.grab_focus()
		ecran.rejoindre()
		if ecran.etat != ecran.Etat.ACCUEIL or reseau.en_ligne() or ecran.message.text != tr(refus[saisie]) or not ecran.champ_code.has_focus():
			faux.append("%s → %s" % [saisie, ecran.message.text])
	_check(faux.is_empty() and tr("ENLIGNE_CODE_FORMAT") == "Un code fait 6 caractères (ex. K7Q-2XM)."
		and tr("ENLIGNE_CODE_CONFUSION") == "Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM).",
		"un code mal formé est refusé à la saisie : « Un code fait 6 caractères (ex. K7Q-2XM). », un 0, O, 1, I ou L a son message (%s)" % [faux])

	# Un code bien formé, sans transport sur ce poste (l'export Web avant la phase 4)
	reseau.transport_disponible = false
	ecran.champ_code.text = " k7q 2xm"
	ecran.rejoindre()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.champ_code.text == "K7Q-2XM"
		and ecran.message.text == tr("ENLIGNE_INDISPONIBLE"),
		"un code bien formé s'affiche « K7Q-2XM » ; sans transport, Rejoindre le dit sans rien ouvrir (%s)" % ecran.message.text)
	ecran.message.text = ""
	ecran.creer_partie()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == tr("ENLIGNE_INDISPONIBLE"),
		"... et Créer une partie aussi")
	reseau.transport_disponible = true

	# Le desktop de développement : l'adresse ENet d'un hôte ; la connexion, le pseudo nettoyé
	ecran.codes_de_salle = false
	ecran.champ_code.text = "lelion.local"
	ecran.rejoindre()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == tr("ENLIGNE_ADRESSE_INVALIDE")
		and ecran.champ_code.has_focus(), "sur le desktop, un nom d'hôte est refusé sans rien tenter (%s)" % ecran.message.text)
	ecran.champ_pseudo.text = " Zoé la grande dompteuse"
	ecran.champ_code.text = " 127.000.0.1:17796 "  # personne n'y écoute
	ecran.rejoindre()
	_check(ecran.etat == ecran.Etat.CONNEXION and reseau.en_ligne() and not root.multiplayer.is_server()
		and ecran.champ_code.text == "127.0.0.1:17796" and ecran.message.text == tr("RESEAU_CONNEXION") % "127.0.0.1:17796",
		"une adresse ENet lance la connexion, normalisée (%s)" % ecran.message.text)
	_check(reseau.pseudo == "Zoé la gran" and ecran.champ_pseudo.text == "Zoé la gran" and scores.preference("pseudo", "") == "Zoé la gran",
		"le pseudo nettoyé (sans l'espace de tête) est donné à Reseau et mémorisé (%s)" % reseau.pseudo)
	_check(ecran.bouton_creer.disabled and ecran.bouton_rejoindre.disabled and not ecran.champ_code.editable and not ecran.champ_pseudo.editable
		and ecran.bouton_retour.has_focus(), "pendant la connexion, tout est grisé sauf Retour, qui a le focus")
	reseau.inscrit.emit(2, palette[2])
	_check(ecran.etat == ecran.Etat.SALON and ecran.bouton_creer.disabled, "inscrit par l'hôte : en route vers le salon, tout reste grisé")
	var salon_client: Node = await _attendre_scene("res://Scenes/Salon.tscn")
	_check(salon_client != null and salon_client.scene_file_path == "res://Scenes/Salon.tscn" and reseau.en_ligne(),
		"puis le salon prend la suite, toujours en ligne")
	if salon_client != null:
		salon_client.free()
	reseau.quitter()
	reseau.hote_perdu.emit()
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.message.text == tr("RESEAU_HOTE_PERDU") and ecran.bouton_creer.has_focus(),
		"hôte perdu : « L'hôte a quitté la partie », retour à l'accueil, Créer une partie au focus")

	# Chaque échec de connexion a son message (spec §9), le focus rendu au code
	var service := "Service de connexion indisponible, réessaie dans un instant."
	var canal := "Connexion impossible avec l'hôte (réseau trop restrictif ?)"
	var attendus := {Transport.ECHEC_INCONNUE: "Aucune partie avec ce code.", Transport.ECHEC_EXPIREE: "Aucune partie avec ce code.",
		Transport.ECHEC_QUOTA: "Trop de parties en ce moment, réessaie plus tard.", Transport.ECHEC_PLEINE: tr("RESEAU_REFUS_PLEIN"),
		Transport.ECHEC_ORIGINE: service, Transport.ECHEC_DEBIT: service, Transport.ECHEC_INJOIGNABLE: service,
		Transport.ECHEC_DELAI: canal, "": canal, "raison_inconnue": canal}
	faux.clear()
	for raison: String in attendus:
		ecran.rejoindre()
		reseau.quitter()
		reseau.raison_echec = raison
		reseau.connexion_echouee.emit()
		if ecran.etat != ecran.Etat.ACCUEIL or ecran.message.text != attendus[raison] or not ecran.champ_code.has_focus():
			faux.append("%s → %s" % [raison, ecran.message.text])
	_check(faux.is_empty(), "chaque raison d'échec du transport a son message, le focus rendu au code (%s)" % [faux])
	reseau.raison_echec = ""
	ecran.rejoindre()
	reseau._transport.echec.emit(Transport.ECHEC_INCONNUE)  # ce que dira TransportWebRTC d'un code sans salle (phase 4)
	var fin := Time.get_ticks_msec() + 1000
	while ecran.etat != ecran.Etat.ACCUEIL and Time.get_ticks_msec() < fin:
		await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == "Aucune partie avec ce code.",
		"un vrai échec du transport, sa raison passée par Reseau : « Aucune partie avec ce code. » (%s)" % ecran.message.text)
	var refus_attendus := {reseau.REFUS_VERSION: tr("RESEAU_REFUS_VERSION") % "0.9", reseau.REFUS_PLEIN: tr("RESEAU_REFUS_PLEIN"),
		reseau.REFUS_MANCHE: tr("RESEAU_REFUS_MANCHE"), reseau.REFUS_DEMANDE: tr("RESEAU_REFUS_DEMANDE"), "RAISON_INCONNUE": tr("RESEAU_REFUS_DEMANDE")}
	faux.clear()
	for raison: String in refus_attendus:
		ecran.rejoindre()
		reseau.quitter()
		reseau.refuse.emit(raison, "0.9")
		if ecran.etat != ecran.Etat.ACCUEIL or ecran.message.text != refus_attendus[raison] or ecran.message.text.begins_with("RESEAU_"):
			faux.append("%s → %s" % [raison, ecran.message.text])
	_check(faux.is_empty(), "chaque refus de l'hôte a son texte traduit, une raison inconnue lue comme demande incomprise (%s)" % [faux])

	# Créer une partie : en ligne, hôte, puis le salon ; Échap arrête
	ecran.creer_partie()
	_check(ecran.etat == ecran.Etat.SALON and reseau.en_ligne() and root.multiplayer.is_server() and reseau.inscrits[1].pseudo == "Zoé la gran"
		and reseau.code_partie == "127.0.0.1:17797" and ecran.bouton_retour.has_focus(),
		"Créer une partie : ce poste héberge avec son pseudo, le code de la partie est celui du transport (%s)" % reseau.code_partie)
	ecran.creer_partie()
	_check(reseau.en_ligne() and reseau.inscrits.size() == 1 and ecran.etat == ecran.Etat.SALON, "un second Créer avant le changement de scène ne relance rien")
	var salon_hote: Node = await _attendre_scene("res://Scenes/Salon.tscn")
	_check(salon_hote != null and salon_hote.scene_file_path == "res://Scenes/Salon.tscn" and reseau.en_ligne() and root.multiplayer.is_server(),
		"puis le salon prend la suite, toujours hôte")
	if salon_hote != null:
		salon_hote.free()
	var echap := InputEventAction.new()
	echap.action = "ui_cancel"
	echap.pressed = true
	root.push_input(echap)
	await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text.is_empty(), "Échap (ou B) arrête d'héberger et revient à l'accueil")

	# Port occupé, autre erreur ; changer de langue retraduit le message
	var occupant := ENetMultiplayerPeer.new()
	_check(occupant.create_server(17798) == OK, "(pré-condition) un autre programme occupe le port 17798")
	ecran.port_jeu = 17798
	ecran.creer_partie()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == "Impossible d'héberger : port 17798 occupé",
		"port occupé : « Impossible d'héberger : port 17798 occupé » (%s)" % ecran.message.text)
	params.definir_langue("en")
	await _frames(1)
	_check(ecran.message.text == "Can't host: port 17798 in use" and ecran.bouton_creer.text == "ENLIGNE_CREER" and tr(ecran.bouton_creer.text) == "Create a game",
		"changer de langue retraduit le message (%s)" % ecran.message.text)
	params.definir_langue("fr")
	occupant.close()
	var erreur_attendue := ENetMultiplayerPeer.new().create_server(70000)
	ecran.port_jeu = 70000
	ecran.creer_partie()
	_check(not reseau.en_ligne() and ecran.message.text == tr("RESEAU_HEBERGER_IMPOSSIBLE") % erreur_attendue,
		"une autre erreur d'hébergement donne son code (%s)" % ecran.message.text)
	ecran.port_jeu = 17797

	# Entrée dans le champ du pseudo : sans code, Créer une partie prend le focus ; avec un code, Rejoindre
	ecran.champ_code.text = ""
	ecran.champ_pseudo.text_submitted.emit("Zoé la gran")
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.bouton_creer.has_focus(), "Entrée sur le pseudo, sans code : Créer une partie au focus")
	ecran.champ_code.text = "127.0.0.1:17796"
	ecran.champ_pseudo.text_submitted.emit("Zoé la gran")
	_check(ecran.etat == ecran.Etat.CONNEXION and reseau.en_ligne(), "Entrée sur le pseudo, un code saisi : Rejoindre")

	# Retour (sans changer de scène : la navigation vers le titre est vérifiée avec le bouton Multijoueur) ;
	# l'écran retiré de l'arbre (pas encore détruit) ne laisse aucune connexion aux autoloads
	ecran.retour(false)
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne(), "Retour pendant une connexion l'annule : l'accueil, hors réseau")
	ecran.retour(false)
	_check(not reseau.en_ligne() and scores.preference("pseudo", "") == "Zoé la gran", "Retour à l'accueil quitte le réseau et garde le pseudo mémorisé")
	root.remove_child(ecran)
	_check(reseau.inscrit.get_connections().is_empty() and reseau.refuse.get_connections().is_empty()
		and reseau.connexion_echouee.get_connections().is_empty() and reseau.hote_perdu.get_connections().is_empty(),
		"l'écran retiré de l'arbre ne laisse aucune connexion aux autoloads")
	ecran.free()
	reseau.pseudo = ""
	scores.effacer()


## Phase 12 bis : le bouton Multijoueur du titre, l'aller et retour avec l'écran En ligne (phase 3 du jeu en
## ligne), la page ouverte sur un lien d'invitation, et le titre qui remet toujours ce poste hors réseau
## avant le solo.
func _tester_titre_reseau(scores: Node) -> void:
	print("-- Titre et réseau")
	var reseau: Node = root.get_node("Reseau")
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		and multi.get_node(multi.focus_neighbor_left) == titre.bouton_jouer,
		"clavier et manette : droite depuis Jouer mène à Multijoueur, gauche en revient")
	multi.pressed.emit()
	var ecran: Control = (await _attendre_scene("res://Scenes/EcranReseau.tscn")) as Control
	titre.free()
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn", "Multijoueur ouvre l'écran Réseau")
	# Ne sauter que les vérifications qui dépendent de `ecran` : la remise à zéro de fin de fonction
	# doit tourner même si cette précondition échoue (sinon un seul échec ici laisse decouverte et
	# reseau dans un état anormal pour la suite de la fonction et pour `_tester_salon`).
	if ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn":
		ecran.bouton_retour.pressed.emit()
		var titre_retour: Control = (await _attendre_scene("res://Scenes/Titre.tscn")) as Control
		_check(titre_retour != null and titre_retour.scene_file_path == "res://Scenes/Titre.tscn" and not is_instance_valid(ecran)
```

par :

```gdscript
		and multi.get_node(multi.focus_neighbor_left) == titre.bouton_jouer,
		"clavier et manette : droite depuis Jouer mène à Multijoueur, gauche en revient")
	multi.pressed.emit()
	var ecran: Control = (await _attendre_scene("res://Scenes/EcranEnLigne.tscn")) as Control
	titre.free()
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn", "Multijoueur ouvre l'écran En ligne")
	# Ne sauter que les vérifications qui dépendent de `ecran` : la remise à zéro de fin de fonction
	# doit tourner même si cette précondition échoue (sinon un seul échec ici laisse decouverte et
	# reseau dans un état anormal pour la suite de la fonction et pour `_tester_salon`).
	if ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn":
		ecran.bouton_retour.pressed.emit()
		var titre_retour: Control = (await _attendre_scene("res://Scenes/Titre.tscn")) as Control
		_check(titre_retour != null and titre_retour.scene_file_path == "res://Scenes/Titre.tscn" and not is_instance_valid(ecran)
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		if titre_retour != null:
			titre_retour.free()

	# Retour au titre depuis une session : hors réseau AVANT le solo (point de vigilance de la phase 12)
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	titre = load("res://Scenes/Titre.tscn").instantiate()
```

par :

```gdscript
		if titre_retour != null:
			titre_retour.free()

	# Une page ouverte sur un lien d'invitation (`?salle=`, spec §4.4) : l'écran En ligne, le code rempli,
	# Rejoindre au focus (le pseudo est mémorisé) ; ce poste ne rejoint qu'au Rejoindre du joueur
	scores.definir_preference("pseudo", "Léa")
	CodeSalle.recherche_forcee = "?relais=1&salle=k7q2xm"
	CodeSalle._page_lue = false
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	var invite: Control = (await _attendre_scene("res://Scenes/EcranEnLigne.tscn")) as Control
	titre.free()
	CodeSalle.recherche_forcee = ""
	_check(invite != null and invite.scene_file_path == "res://Scenes/EcranEnLigne.tscn",
		"une page ouverte sur un lien ?salle= passe du titre à l'écran En ligne")
	if invite != null and invite.scene_file_path == "res://Scenes/EcranEnLigne.tscn":
		_check(invite.champ_code.text == "K7Q-2XM" and invite.etat == invite.Etat.ACCUEIL and not reseau.en_ligne()
			and invite.message.text == tr("ENLIGNE_INVITATION") and invite.bouton_rejoindre.has_focus(),
			"le code du lien rempli (« K7Q-2XM »), Rejoindre au focus, rien de tenté : « %s »" % invite.message.text)
		invite.codes_de_salle = true  # comme sur le Web
		reseau.transport_disponible = false
		invite.champ_pseudo.text_submitted.emit("Léa")
		_check(invite.message.text == tr("ENLIGNE_INDISPONIBLE") and not reseau.en_ligne(),
			"le pseudo validé (Entrée), Rejoindre part avec le code du lien (ici sans transport : « %s »)" % invite.message.text)
		reseau.transport_disponible = true
		var second_titre: Control = load("res://Scenes/Titre.tscn").instantiate()
		second_titre.demo_autorisee = false
		root.add_child(second_titre)
		await _frames(3)
		_check(current_scene == invite and CodeSalle.prendre_code_de_la_page().is_empty(),
			"le lien ne sert qu'une fois : un titre suivant reste le titre")
		second_titre.free()
		invite.free()
	scores.effacer()

	# Retour au titre depuis une session : hors réseau AVANT le solo (point de vigilance de la phase 12)
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	titre = load("res://Scenes/Titre.tscn").instantiate()
```

- [ ] **Step 2 : ils échouent**

```bash
timeout -k 5 120 godot --headless --script tests/smoke_test.gd 2>&1 | grep -E "SCRIPT ERROR|❌|== "
```

Expected : `SCRIPT ERROR: Attempt to call function 'instantiate' in base 'null instance' on a null instance.`, puis `❌ Multijoueur ouvre l'écran En ligne`, `❌ une page ouverte sur un lien ?salle= passe du titre à l'écran En ligne`, `❌ le salon fermé ne laisse aucune connexion aux autoloads` (la fonction interrompue a laissé ses connexions), `== 3 échec(s) ==`.

- [ ] **Step 3 : l'écran**

Créer `Scripts/EcranEnLigne.gd` :

```gdscript
extends Control
## Écran En ligne (spec §3.1, §4.4 et §9 du jeu en ligne) : pseudo mémorisé, Créer une partie, Rejoindre
## avec un code (rempli d'avance par le lien `?salle=`), messages des refus et des échecs. En 16:9, comme
## le salon ; le titre remet l'écran du solo au retour.
##
## Le code : sur le Web, un code de salle (`CodeSalle`, « K7Q-2XM »), refusé à la saisie s'il est mal
## formé ; sur le desktop de développement, l'adresse `ip:port` (ou `ip`) d'un hôte `TransportENet`
## (`codes_de_salle` faux). Sans transport pour jouer en réseau (`Reseau.transport_disponible` : l'export
## Web avant la phase 4), Créer et Rejoindre le disent sans rien ouvrir.
##
## Trois états : ACCUEIL (tout est permis), CONNEXION (en attente de l'hôte) et SALON (partie créée, ou
## inscription reçue : en route vers le salon, tout reste grisé le temps du changement de scène). Retour
## (ou Échap, B à la manette) annule l'état en cours, puis ramène au titre. Le salon revient ici avec un
## message (`message_a_l_arrivee`) si l'hôte est perdu ; le titre y vient avec le code du lien de la page
## (`code_a_l_arrivee`).

enum Etat { ACCUEIL, CONNEXION, SALON }

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCENE_SALON := "res://Scenes/Salon.tscn"
const COULEUR_INFO := Color(1, 1, 1, 0.85)
## Le remplissage blanc porte le contraste ; le contour distingue un refus ou un échec (saumon) d'une
## simple information (sombre).
const COULEUR_ERREUR := Color(1, 1, 1, 0.95)
const COULEUR_CONTOUR_INFO := Color(0.1, 0.05, 0.12, 0.85)
const COULEUR_CONTOUR_ERREUR := Color(0.85, 0.22, 0.14, 0.9)
## Le message de chaque raison d'échec d'un transport (`Reseau.raison_echec`, spec §9).
const MESSAGES_ECHEC := {
	Transport.ECHEC_INCONNUE: "ENLIGNE_SALLE_INCONNUE",
	Transport.ECHEC_EXPIREE: "ENLIGNE_SALLE_INCONNUE",
	Transport.ECHEC_PLEINE: "RESEAU_REFUS_PLEIN",
	Transport.ECHEC_QUOTA: "ENLIGNE_QUOTA",
	Transport.ECHEC_DEBIT: "ENLIGNE_SERVICE_INDISPONIBLE",
	Transport.ECHEC_ORIGINE: "ENLIGNE_SERVICE_INDISPONIBLE",
	Transport.ECHEC_INJOIGNABLE: "ENLIGNE_SERVICE_INDISPONIBLE",
	Transport.ECHEC_DELAI: "ENLIGNE_ECHEC_CANAL",
}
## Un échec sans raison du transport (la poignée de main sans réponse) ou d'une raison inconnue.
const ECHEC_PAR_DEFAUT := "ENLIGNE_ECHEC_CANAL"

## Port de jeu de Créer une partie hors du Web (ENet ; modifiable par les tests).
var port_jeu: int = Reseau.PORT
## Vrai si le code se saisit en code de salle (le Web) ; faux sur le desktop de développement, où c'est
## l'adresse `ip:port` (ou `ip`) d'un hôte ENet. Modifiable par les tests.
var codes_de_salle := OS.has_feature("web")
var etat := Etat.ACCUEIL
## Clé d'un message d'erreur à afficher à la prochaine ouverture de l'écran, puis oubliée : le salon la
## pose avant d'y revenir (« L'hôte a quitté la partie »).
static var message_a_l_arrivee := ""
## Le code d'une salle à rejoindre, posé par le titre quand la page s'ouvre sur un lien `?salle=` (spec
## §4.4), puis oublié : l'écran s'ouvre ce code rempli, sur Rejoindre ; ce poste ne rejoint qu'au
## Rejoindre du joueur, son pseudo choisi.
static var code_a_l_arrivee := ""

@onready var champ_pseudo: LineEdit = $Centre/Colonne/RangeePseudo/Pseudo
@onready var bouton_creer: Button = $Centre/Colonne/Creer
@onready var champ_code: LineEdit = $Centre/Colonne/RangeeCode/Code
@onready var bouton_rejoindre: Button = $Centre/Colonne/RangeeCode/Rejoindre
@onready var message: Label = $Centre/Colonne/Message
@onready var bouton_retour: Button = $BoutonRetour

## Le message affiché, gardé en clé et arguments pour être retraduit au changement de langue.
var _message := {"cle": "", "arguments": [], "erreur": false}
## Vrai pendant une tentative lancée par Rejoindre : un refus ou un échec rend le focus au code (sinon à
## Créer une partie).
var _par_le_code := false


func _ready() -> void:
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
	champ_pseudo.max_length = Reseau.PSEUDO_MAX
	champ_pseudo.text = Reseau.pseudo_valide(str(Scores.preference("pseudo", "")))
	champ_code.placeholder_text = "K7Q-2XM" if codes_de_salle else "192.168.1.20:%d" % Reseau.PORT
	Reseau.inscrit.connect(_sur_inscription)
	Reseau.refuse.connect(_sur_refus)
	Reseau.connexion_echouee.connect(_sur_connexion_echouee)
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	Parametres.langue_changee.connect(_sur_langue_changee)
	_changer_etat(Etat.ACCUEIL)
	if not code_a_l_arrivee.is_empty():
		champ_code.text = CodeSalle.formater(code_a_l_arrivee)
		code_a_l_arrivee = ""
		_afficher_message("ENLIGNE_INVITATION", [], false)
		if champ_pseudo.text.is_empty():
			champ_pseudo.grab_focus()
		else:
			bouton_rejoindre.grab_focus()
	if not message_a_l_arrivee.is_empty():
		_afficher_message(message_a_l_arrivee, [], true)
		message_a_l_arrivee = ""


## Les autoloads survivent à l'écran : ne rien leur laisser. Ne quitte pas le réseau : le salon prend la
## suite d'une partie créée ou rejointe.
func _exit_tree() -> void:
	Reseau.inscrit.disconnect(_sur_inscription)
	Reseau.refuse.disconnect(_sur_refus)
	Reseau.connexion_echouee.disconnect(_sur_connexion_echouee)
	Reseau.hote_perdu.disconnect(_sur_hote_perdu)
	Parametres.langue_changee.disconnect(_sur_langue_changee)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Échap dans un champ en édition n'en sort pas de lui-même : on en sort d'abord, un second Échap
	# ramène à l'accueil ou au titre.
	var proprietaire := get_viewport().gui_get_focus_owner()
	if proprietaire is LineEdit and (proprietaire as LineEdit).is_editing():
		(proprietaire as LineEdit).unedit()
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	retour()


## Crée une partie avec le pseudo saisi (hors du Web, ENet sur `port_jeu`).
func creer_partie() -> void:
	if etat != Etat.ACCUEIL:
		return
	_appliquer_pseudo()
	_par_le_code = false
	var erreur: Error = Reseau.creer_partie(port_jeu)
	if erreur == ERR_UNAVAILABLE:
		_afficher_message("ENLIGNE_INDISPONIBLE", [], true)
	elif erreur == ERR_CANT_CREATE:
		_afficher_message("RESEAU_PORT_OCCUPE", [port_jeu], true)
	elif erreur != OK:
		_afficher_message("RESEAU_HEBERGER_IMPOSSIBLE", [erreur], true)
	else:
		_ouvrir_salon()


## Rejoint la partie du code saisi, avec le pseudo saisi ; un code mal formé est refusé d'emblée (spec
## §9), sans rien tenter. Le code s'affiche alors sous sa forme normale (« K7Q-2XM », ou l'adresse de
## l'hôte ENet).
func rejoindre() -> void:
	if etat != Etat.ACCUEIL:
		return
	var code := _lire_code()
	if code.is_empty():
		champ_code.grab_focus()
		return
	champ_code.text = CodeSalle.formater(code)
	_appliquer_pseudo()
	_par_le_code = true
	var erreur: Error = Reseau.rejoindre_partie(code)
	if erreur != OK:
		_afficher_message("ENLIGNE_INDISPONIBLE" if erreur == ERR_UNAVAILABLE else ECHEC_PAR_DEFAUT, [], true)
		return
	_changer_etat(Etat.CONNEXION)
	_afficher_message("RESEAU_CONNEXION", [champ_code.text], false)


## Hors de l'accueil : annule (quitte le réseau, revient à l'accueil). À l'accueil : retour au titre (qui
## quitte aussi le réseau). `changer_scene` à faux pour les tests.
func retour(changer_scene := true) -> void:
	Reseau.quitter()
	if etat != Etat.ACCUEIL:
		_changer_etat(Etat.ACCUEIL)
		_afficher_message("", [], false)
		return
	_appliquer_pseudo()
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_TITRE)


## Le message de l'échec de connexion `raison` (`Reseau.raison_echec`, Transport.ECHEC_*, spec §9) ;
## ECHEC_PAR_DEFAUT sans raison ou pour une raison inconnue.
static func cle_echec(raison: String) -> String:
	return MESSAGES_ECHEC.get(raison, ECHEC_PAR_DEFAUT)


## Le code saisi, tel que `Reseau.rejoindre_partie` l'attend (un code de salle normalisé, ou l'adresse
## `ip:port` de l'hôte ENet sous sa forme normale) ; vide s'il est mal formé, son message affiché.
func _lire_code() -> String:
	if codes_de_salle:
		var erreur := CodeSalle.erreur(champ_code.text)
		if not erreur.is_empty():
			_afficher_message(erreur, [], true)
			return ""
		return CodeSalle.normaliser(champ_code.text)
	var cible := TransportENet.lire_code(champ_code.text)
	if cible.is_empty():
		_afficher_message("ENLIGNE_ADRESSE_INVALIDE", [], true)
		return ""
	return "%s:%d" % [cible.ip, cible.port]


## Entrée dans le champ du pseudo : Rejoindre si un code attend (celui d'un lien), sinon Créer une partie
## prend le focus.
func _sur_pseudo_valide(_texte: String) -> void:
	if champ_code.text.strip_edges().is_empty():
		bouton_creer.grab_focus()
	else:
		rejoindre()


## Le pseudo saisi, nettoyé comme l'hôte le nettoiera, devient celui de ce poste et est mémorisé.
func _appliquer_pseudo() -> void:
	var pseudo := Reseau.pseudo_valide(champ_pseudo.text)
	champ_pseudo.text = pseudo
	Reseau.pseudo = pseudo
	Scores.definir_preference("pseudo", pseudo)


func _changer_etat(nouvel_etat: Etat) -> void:
	etat = nouvel_etat
	var accueil := etat == Etat.ACCUEIL
	champ_pseudo.editable = accueil
	champ_code.editable = accueil
	bouton_creer.disabled = not accueil
	bouton_rejoindre.disabled = not accueil
	if accueil:
		bouton_creer.grab_focus()
	else:
		bouton_retour.grab_focus()


func _afficher_message(cle: String, arguments: Array, erreur: bool) -> void:
	_message = {"cle": cle, "arguments": arguments, "erreur": erreur}
	_rendre_message()


func _rendre_message() -> void:
	var cle: String = _message.cle
	var arguments: Array = _message.arguments
	message.text = "" if cle.is_empty() else (tr(cle) % arguments if not arguments.is_empty() else tr(cle))
	message.add_theme_color_override("font_color", COULEUR_ERREUR if _message.erreur else COULEUR_INFO)
	message.add_theme_color_override("font_outline_color", COULEUR_CONTOUR_ERREUR if _message.erreur else COULEUR_CONTOUR_INFO)


## Après un refus ou un échec (déjà revenu à l'accueil, Créer une partie au focus) : le focus au code si
## la tentative venait de Rejoindre.
func _reprendre_focus_echec() -> void:
	if _par_le_code:
		champ_code.grab_focus()


func _sur_inscription(_index: int, _couleur: Color) -> void:
	if etat == Etat.CONNEXION:
		# La tentative a réussi : un « hôte perdu » bien plus tard rend le focus à Créer, comme d'habitude.
		_par_le_code = false
		_ouvrir_salon()


## Une partie créée ou rejointe continue au salon ; tout est grisé d'ici au changement de scène (un second
## Créer dans la même image ne relance rien).
func _ouvrir_salon() -> void:
	_changer_etat(Etat.SALON)
	get_tree().change_scene_to_file(SCENE_SALON)


## `Reseau` a déjà remis ce poste hors réseau quand ses signaux d'échec partent.
func _sur_refus(raison: String, version_hote: String) -> void:
	var connues := [Reseau.REFUS_VERSION, Reseau.REFUS_PLEIN, Reseau.REFUS_MANCHE, Reseau.REFUS_DEMANDE]
	var cle := raison if connues.has(raison) else Reseau.REFUS_DEMANDE
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message(cle, [version_hote] if cle == Reseau.REFUS_VERSION else [], true)


func _sur_connexion_echouee() -> void:
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message(cle_echec(Reseau.raison_echec), [], true)


func _sur_hote_perdu() -> void:
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message(Reseau.raison_perte, [], true)


func _sur_langue_changee(_langue: String) -> void:
	_rendre_message()
```

Créer `Scenes/EcranEnLigne.tscn` :

```
[gd_scene load_steps=4 format=3 uid="uid://dlelionenligne"]

[ext_resource type="Script" path="res://Scripts/EcranEnLigne.gd" id="1_enligne"]

[sub_resource type="Gradient" id="Gradient_ciel"]
offsets = PackedFloat32Array(0, 0.55, 1)
colors = PackedColorArray(0.09, 0.1, 0.24, 1, 0.42, 0.25, 0.43, 1, 0.9, 0.5, 0.32, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_ciel"]
gradient = SubResource("Gradient_ciel")
fill_to = Vector2(0, 1)

[node name="EcranEnLigne" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_enligne")

[node name="Ciel" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = SubResource("GradientTexture2D_ciel")

[node name="Centre" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Colonne" type="VBoxContainer" parent="Centre"]
layout_mode = 2
theme_override_constants/separation = 28
alignment = 1

[node name="Titre" type="Label" parent="Centre/Colonne"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.2, 1)
theme_override_font_sizes/font_size = 110
text = "EN_LIGNE"
horizontal_alignment = 1

[node name="RangeePseudo" type="HBoxContainer" parent="Centre/Colonne"]
layout_mode = 2
theme_override_constants/separation = 16
alignment = 1

[node name="Etiquette" type="Label" parent="Centre/Colonne/RangeePseudo"]
custom_minimum_size = Vector2(300, 0)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.75)
theme_override_font_sizes/font_size = 30
text = "RESEAU_PSEUDO"
horizontal_alignment = 2
vertical_alignment = 1

[node name="Pseudo" type="LineEdit" parent="Centre/Colonne/RangeePseudo"]
custom_minimum_size = Vector2(520, 72)
layout_mode = 2
theme_override_font_sizes/font_size = 34
max_length = 12

[node name="Creer" type="Button" parent="Centre/Colonne"]
custom_minimum_size = Vector2(520, 80)
layout_mode = 2
size_flags_horizontal = 4
theme_override_font_sizes/font_size = 38
text = "ENLIGNE_CREER"

[node name="Ou" type="Label" parent="Centre/Colonne"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.75)
theme_override_font_sizes/font_size = 30
text = "ENLIGNE_OU"
horizontal_alignment = 1

[node name="RangeeCode" type="HBoxContainer" parent="Centre/Colonne"]
layout_mode = 2
theme_override_constants/separation = 16
alignment = 1

[node name="Etiquette" type="Label" parent="Centre/Colonne/RangeeCode"]
custom_minimum_size = Vector2(300, 0)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.75)
theme_override_font_sizes/font_size = 30
text = "ENLIGNE_CODE"
horizontal_alignment = 2
vertical_alignment = 1

[node name="Code" type="LineEdit" parent="Centre/Colonne/RangeeCode"]
custom_minimum_size = Vector2(420, 72)
layout_mode = 2
theme_override_font_sizes/font_size = 34
max_length = 21

[node name="Rejoindre" type="Button" parent="Centre/Colonne/RangeeCode"]
custom_minimum_size = Vector2(260, 72)
layout_mode = 2
theme_override_font_sizes/font_size = 32
text = "RESEAU_REJOINDRE"

[node name="Message" type="Label" parent="Centre/Colonne"]
custom_minimum_size = Vector2(1400, 90)
layout_mode = 2
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.12, 0.85)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 30
horizontal_alignment = 1
autowrap_mode = 3

[node name="BoutonRetour" type="Button" parent="."]
layout_mode = 1
offset_left = 24.0
offset_top = 24.0
offset_right = 284.0
offset_bottom = 100.0
theme_override_font_sizes/font_size = 26
text = "RETOUR"

[connection signal="pressed" from="BoutonRetour" to="." method="retour"]
[connection signal="pressed" from="Centre/Colonne/Creer" to="." method="creer_partie"]
[connection signal="text_submitted" from="Centre/Colonne/RangeePseudo/Pseudo" to="." method="_sur_pseudo_valide"]
[connection signal="pressed" from="Centre/Colonne/RangeeCode/Rejoindre" to="." method="rejoindre"]
[connection signal="text_submitted" from="Centre/Colonne/RangeeCode/Code" to="." method="rejoindre" unbinds=1]
```

Dans `Assets/Traductions/traductions.csv`, remplacer :

```
RESEAU_EXCLU,"Exclu : ta partie a mis trop de temps à charger.","Removed: your game took too long to load."
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
RESEAU_HEBERGER_IMPOSSIBLE,Impossible d'héberger (erreur %d),Can't host (error %d)
SALON,Salon,Lobby
SALON_NIVEAU,Niveau : %s,Level: %s
SALON_HOTE,HÔTE,HOST
```

par :

```
RESEAU_EXCLU,"Exclu : ta partie a mis trop de temps à charger.","Removed: your game took too long to load."
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
RESEAU_HEBERGER_IMPOSSIBLE,Impossible d'héberger (erreur %d),Can't host (error %d)
EN_LIGNE,En ligne,Online
ENLIGNE_CREER,Créer une partie,Create a game
ENLIGNE_OU,ou rejoins une partie avec son code,or join a game with its code
ENLIGNE_CODE,Code,Code
ENLIGNE_CODE_FORMAT,"Un code fait 6 caractères (ex. K7Q-2XM).","A code has 6 characters (e.g. K7Q-2XM)."
ENLIGNE_CODE_CONFUSION,"Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM).","A code has no 0, O, 1, I or L (e.g. K7Q-2XM)."
ENLIGNE_ADRESSE_INVALIDE,"Adresse invalide (ex. 192.168.1.20:7777)","Invalid address (e.g. 192.168.1.20:7777)"
ENLIGNE_INVITATION,"Invitation reçue : choisis ton pseudo, puis Rejoindre.","You're invited: pick your name, then Join."
ENLIGNE_SALLE_INCONNUE,Aucune partie avec ce code.,No game with this code.
ENLIGNE_SERVICE_INDISPONIBLE,"Service de connexion indisponible, réessaie dans un instant.","Connection service unavailable, try again in a moment."
ENLIGNE_QUOTA,"Trop de parties en ce moment, réessaie plus tard.","Too many games right now, try again later."
ENLIGNE_ECHEC_CANAL,Connexion impossible avec l'hôte (réseau trop restrictif ?),Can't connect to the host (network too restrictive?)
ENLIGNE_INDISPONIBLE,"Pas encore de jeu en ligne dans cette version : il arrive bientôt.","No online play in this version yet: coming soon."
SALON,Salon,Lobby
SALON_NIVEAU,Niveau : %s,Level: %s
SALON_HOTE,HÔTE,HOST
```

- [ ] **Step 4 : le titre l'ouvre (Multijoueur, ou d'emblée sur un lien)**

Dans `Scripts/Titre.gd`, remplacer :

```gdscript
extends Control
## Écran titre : difficulté et niveau se choisissent (mémorisés), Jouer lance la partie,
## Multijoueur ouvre l'écran Réseau. Les niveaux affichent le record pour la difficulté choisie.
## `_ready` remet aussi ce poste hors réseau et le solo (`GameState.configurer_solo()` et l'écran
## 2000×648), même au retour d'une bataille ou de l'écran Réseau.

const SCENE_JEU := "res://Scenes/Main.tscn"
const SCENE_RESEAU := "res://Scenes/EcranReseau.tscn"
const DELAI_DEMO := 15.0
const SCENE_REGLAGES := preload("res://Scenes/Reglages.tscn")

```

par :

```gdscript
extends Control
## Écran titre : difficulté et niveau se choisissent (mémorisés), Jouer lance la partie,
## Multijoueur ouvre l'écran En ligne. Les niveaux affichent le record pour la difficulté choisie.
## `_ready` remet aussi ce poste hors réseau et le solo (`GameState.configurer_solo()` et l'écran
## 2000×648), même au retour d'une bataille ou de l'écran En ligne. Une page ouverte sur un lien
## d'invitation (`?salle=`, spec §4.4 du jeu en ligne) passe tout de suite à l'écran En ligne, le code
## rempli, une seule fois par lancement.

const SCENE_JEU := "res://Scenes/Main.tscn"
const SCENE_EN_LIGNE := "res://Scenes/EcranEnLigne.tscn"
const _EcranEnLigne := preload("res://Scripts/EcranEnLigne.gd")
const DELAI_DEMO := 15.0
const SCENE_REGLAGES := preload("res://Scenes/Reglages.tscn")

```

Dans `Scripts/Titre.gd`, remplacer :

```gdscript

func _ready() -> void:
	get_tree().paused = false
	# Retour depuis l'écran Réseau, le salon ou une manche quittée par le menu local, sans signal de
	# `Reseau` : ce poste revient hors réseau AVANT de remettre le solo. Sinon un ancien client
	# relancerait un solo où `multiplayer.is_server()` est faux (ennemis, pastilles, gerbe et chocs
	# inertes), et un ancien hôte émettrait encore sa balise et accepterait des joueurs.
```

par :

```gdscript

func _ready() -> void:
	get_tree().paused = false
	# Retour depuis l'écran En ligne, le salon ou une manche quittée par le menu local, sans signal de
	# `Reseau` : ce poste revient hors réseau AVANT de remettre le solo. Sinon un ancien client
	# relancerait un solo où `multiplayer.is_server()` est faux (ennemis, pastilles, gerbe et chocs
	# inertes), et un ancien hôte émettrait encore sa balise et accepterait des joueurs.
```

Dans `Scripts/Titre.gd`, remplacer :

```gdscript
	choisir_difficulte(GameState.difficulte_courante)
	choisir_niveau(GameState.niveau_courant)
	bouton_jouer.grab_focus()


## Attract mode : sans action pendant DELAI_DEMO secondes, le jeu se lance en démo.
```

par :

```gdscript
	choisir_difficulte(GameState.difficulte_courante)
	choisir_niveau(GameState.niveau_courant)
	bouton_jouer.grab_focus()
	var code := CodeSalle.prendre_code_de_la_page()
	if not code.is_empty():
		_EcranEnLigne.code_a_l_arrivee = code
		ouvrir_en_ligne.call_deferred()


## Attract mode : sans action pendant DELAI_DEMO secondes, le jeu se lance en démo.
```

Dans `Scripts/Titre.gd`, remplacer :

```gdscript
	bouton.offset_bottom = -24.0
	bouton.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bouton.pressed.connect(ouvrir_reseau)
	add_child(bouton)
	bouton_jouer.focus_neighbor_right = bouton_jouer.get_path_to(bouton)
	bouton.focus_neighbor_left = bouton.get_path_to(bouton_jouer)
	return bouton


func ouvrir_reseau() -> void:
	get_tree().change_scene_to_file(SCENE_RESEAU)


func lancer_demo(changer_scene := true) -> void:
```

par :

```gdscript
	bouton.offset_bottom = -24.0
	bouton.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bouton.pressed.connect(ouvrir_en_ligne)
	add_child(bouton)
	bouton_jouer.focus_neighbor_right = bouton_jouer.get_path_to(bouton)
	bouton.focus_neighbor_left = bouton.get_path_to(bouton_jouer)
	return bouton


func ouvrir_en_ligne() -> void:
	get_tree().change_scene_to_file(SCENE_EN_LIGNE)


func lancer_demo(changer_scene := true) -> void:
```

- [ ] **Step 5 : ils passent**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; ls Scripts/EcranEnLigne.gd.uid
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"
sed -n '/^-- Écran En ligne/,/^-- Salon/p' "$TMPDIR/s.log" | grep -E "✅|❌" | wc -l; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --script tests/unitaires.gd 2>&1 | grep -E "❌|== "
```

Expected : rien à l'import, le `.uid` existe ; smoke `0`, 41 lignes ✅ entre « Écran En ligne » et « Salon » (l'écran En ligne, puis le titre) (dont « chaque raison d'échec du transport a son message », « le code du lien rempli (« K7Q-2XM »), Rejoindre au focus, rien de tenté », « le lien ne sert qu'une fois »), `== 0 échec(s) ==` ; unitaires `== 0 échec(s) ==`.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/EcranEnLigne.gd Scripts/EcranEnLigne.gd.uid Scenes/EcranEnLigne.tscn Scripts/Titre.gd Assets/Traductions/ tests/smoke_test.gd
git commit -m "Écran En ligne : pseudo, Créer une partie, Rejoindre avec un code de salle (refusé à la saisie s'il est mal formé, affiché K7Q-2XM) ou, sur le desktop, l'adresse ip:port d'un hôte ENet ; les messages du §9 par raison d'échec ; sans transport (le Web avant la phase 4), il le dit sans rien ouvrir. Le titre l'ouvre (Multijoueur, ou d'emblée sur un lien ?salle=, une fois)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 4 : le salon (code, *Copier le lien*) et le test réseau par l'écran En ligne

**Files:**
- Modify: `Scripts/Salon.gd` (en-tête, constantes, `@onready`, `_tenues`, `_ready`, `retour`, nouvelles `copier_lien` et `_remettre_bouton_copier`, `_sur_hote_perdu`, `_revenir_au_reseau` → `_revenir_a_l_ecran_en_ligne`, `_afficher`)
- Modify: `Scenes/Salon.tscn` (`Adresses` → `Invitation/Code` + `Invitation/CopierLien`, la connexion du bouton)
- Modify: `Assets/Traductions/traductions.csv` (`SALON_ADRESSES` → `SALON_CODE`, `SALON_COPIER_LIEN`, `SALON_LIEN_COPIE`) (+ `.translation`)
- Test: `tests/smoke_test.gd` (`_tester_salon`), `tests/reseau/joueur.gd` (`_jouer_salon`, `_animer_salon_client`, nouvelle `_ouvrir_la_partie`, `_rejoindre_la_manche`, `_enchainer`, en-tête)

**Interfaces:**
- Consumes : `CodeSalle.valide`, `formater`, `lien` (Task 1) ; `Reseau.code_partie` ; `EcranEnLigne.message_a_l_arrivee`, `creer_partie`, `rejoindre`, `champ_code`, `port_jeu` (Task 3).
- Produces (Task 5) : `Salon.DUREE_LIEN_COPIE := 2.0`, `rangee_invitation: HBoxContainer`, `etiquette_code: Label`, `bouton_copier: Button`, `func copier_lien() -> String` ; `SCENE_EN_LIGNE`. `joueur.gd` : `func _ouvrir_la_partie(hote: bool) -> void`.

- [ ] **Step 1 : les tests**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	await _appuyer(&"deplacer_droite", false)
	Input.action_release("deplacer_droite")

	# L'hôte seul : sa carte, les places libres, le niveau du titre, ses adresses ; aucun focus
	var c0: Dictionary = salon.cartes[0]
	_check(root.content_scale_size == Vector2i(2000, 1125) and salon.cartes.size() == 6
		and salon.cartes.all(func(c: Dictionary) -> bool: return c.cadre.visible), "le salon est en 16:9, une carte par place (6)")
```

par :

```gdscript
	await _appuyer(&"deplacer_droite", false)
	Input.action_release("deplacer_droite")

	# L'hôte seul : sa carte, les places libres, le niveau du titre, le code de la partie ; aucun focus
	var c0: Dictionary = salon.cartes[0]
	_check(root.content_scale_size == Vector2i(2000, 1125) and salon.cartes.size() == 6
		and salon.cartes.all(func(c: Dictionary) -> bool: return c.cadre.visible), "le salon est en 16:9, une carte par place (6)")
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	_check(salon.cartes.slice(1).all(func(c: Dictionary) -> bool: return c.pseudo.text == tr("SALON_LIBRE") and c.lion.material == null),
		"les autres places sont libres : une silhouette sans couleur")
	_check(salon.titre_niveau.text == "Niveau : Métropole" and reseau.niveau_salon == 1 and salon.aide.text == tr("SALON_AIDE_HOTE")
		and salon.adresses.visible and salon.etat.text == tr("SALON_ATTENTE_JOUEURS") and salon.bouton_demarrer.visible and salon.bouton_demarrer.disabled,
		"le niveau choisi au titre, l'aide de l'hôte, ses adresses, Démarrer grisé : « Il faut au moins 2 joueurs pour démarrer. »")
	_check(root.gui_get_focus_owner() == null and salon.bouton_retour.focus_mode == Control.FOCUS_NONE,
		"aucun contrôle ne prend le focus : flèches, croix, stick, vomir et démarrer vont au salon")
	var adresses_lues: PackedStringArray = salon._adresses_hote
	salon._adresses_hote = PackedStringArray(["10.9.9.9"])
	reseau.salon_change.emit()
	_check(salon.adresses.text.contains("10.9.9.9"), "M4 : les adresses de l'hôte sont relevées une fois, à l'ouverture, pas à chaque changement du salon")
	salon._adresses_hote = adresses_lues

	# Une place réservée (poignée de main en cours) n'a pas de carte ; un joueur arrivé a la sienne
	reseau.inscrits[7] = {"index": 2, "couleur": palette[2], "pseudo": "Rita", "arrive": false, "pret": false}
```

par :

```gdscript
	_check(salon.cartes.slice(1).all(func(c: Dictionary) -> bool: return c.pseudo.text == tr("SALON_LIBRE") and c.lion.material == null),
		"les autres places sont libres : une silhouette sans couleur")
	_check(salon.titre_niveau.text == "Niveau : Métropole" and reseau.niveau_salon == 1 and salon.aide.text == tr("SALON_AIDE_HOTE")
		and salon.etat.text == tr("SALON_ATTENTE_JOUEURS") and salon.bouton_demarrer.visible and salon.bouton_demarrer.disabled,
		"le niveau choisi au titre, l'aide de l'hôte, Démarrer grisé : « Il faut au moins 2 joueurs pour démarrer. »")
	_check(salon.rangee_invitation.visible and salon.etiquette_code.text == "Code de la partie : 127.0.0.1:17797" and not salon.bouton_copier.visible
		and salon.copier_lien().is_empty(), "sur le desktop, le code de la partie ENet (son adresse), sans lien à copier (%s)" % salon.etiquette_code.text)
	_check(root.gui_get_focus_owner() == null and salon.bouton_retour.focus_mode == Control.FOCUS_NONE and salon.bouton_copier.focus_mode == Control.FOCUS_NONE,
		"aucun contrôle ne prend le focus : flèches, croix, stick, vomir et démarrer vont au salon")
	# Une salle de la signalisation (le Web, phase 4) : son code, et « Copier le lien »
	var code_enet: String = reseau.code_partie
	reseau.code_partie = "K7Q2XM"
	reseau.salon_change.emit()
	_check(salon.etiquette_code.text == "Code de la partie : K7Q-2XM" and salon.bouton_copier.visible and salon.bouton_copier.text == "SALON_COPIER_LIEN",
		"un code de salle : « Code de la partie : K7Q-2XM » et « Copier le lien », relus à chaque changement du salon (%s)" % salon.etiquette_code.text)
	_check(salon.copier_lien() == "https://w3cdotorg.github.io/LeLion-web/?salle=K7Q2XM" and salon.bouton_copier.text == "SALON_LIEN_COPIE"
		and tr(salon.bouton_copier.text) == "Lien copié !", "Copier le lien : le lien d'invitation, et « Lien copié ! »")
	await create_timer(salon.DUREE_LIEN_COPIE + 0.2).timeout
	_check(salon.bouton_copier.text == "SALON_COPIER_LIEN", "%.0f s plus tard, le bouton redit « Copier le lien »" % salon.DUREE_LIEN_COPIE)
	reseau.code_partie = code_enet
	reseau.salon_change.emit()

	# Une place réservée (poignée de main en cours) n'a pas de carte ; un joueur arrivé a la sienne
	reseau.inscrits[7] = {"index": 2, "couleur": palette[2], "pseudo": "Rita", "arrive": false, "pret": false}
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		and reseau.manche_lancee.get_connections().is_empty() and reseau.hote_perdu.get_connections().is_empty(),
		"le salon fermé ne laisse aucune connexion aux autoloads")

	# Un client : ni niveau ni adresses ; l'hôte perdu ramène à l'écran Réseau, avec son message
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est un client")
	var salon_client: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon_client)
	await process_frame
	_check(salon_client.aide.text == tr("SALON_AIDE") and not salon_client.adresses.visible and not salon_client.bouton_demarrer.visible,
		"un client : l'aide sans le niveau ni Démarrer, pas d'adresses, pas de bouton")
	salon_client.changer_niveau(1)
	salon_client.demarrer()
	_check(reseau.niveau_salon == 0 and not reseau.manche_en_cours, "un client ne change pas le niveau et ne démarre pas la partie")
```

par :

```gdscript
		and reseau.manche_lancee.get_connections().is_empty() and reseau.hote_perdu.get_connections().is_empty(),
		"le salon fermé ne laisse aucune connexion aux autoloads")

	# Un client : ni niveau ni code ; l'hôte perdu ramène à l'écran En ligne, avec son message
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est un client")
	var salon_client: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon_client)
	await process_frame
	_check(salon_client.aide.text == tr("SALON_AIDE") and not salon_client.rangee_invitation.visible and not salon_client.bouton_demarrer.visible,
		"un client : l'aide sans le niveau ni Démarrer, pas de code, pas de bouton")
	salon_client.changer_niveau(1)
	salon_client.demarrer()
	_check(reseau.niveau_salon == 0 and not reseau.manche_en_cours, "un client ne change pas le niveau et ne démarre pas la partie")
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
			% [attente_client, attente_arrivee, salon_client.etat.text])
	reseau.quitter()
	reseau.hote_perdu.emit()
	var ecran: Node = await _attendre_scene("res://Scenes/EcranReseau.tscn")
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn" and ecran.etat == ecran.Etat.ACCUEIL
		and ecran.message.text == tr("RESEAU_HOTE_PERDU"), "hôte perdu : retour à l'écran Réseau, « L'hôte a quitté la partie »")
	salon_client.free()
	if ecran != null:
		ecran.free()

	# Échap (ou B) : quitte le réseau, écran Réseau sans message (celui de l'hôte perdu ne s'affiche
	# qu'une fois)
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est de nouveau un client")
	salon_client = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon_client)
	await process_frame
	await _appuyer(&"ui_cancel", true)
	ecran = await _attendre_scene("res://Scenes/EcranReseau.tscn")
	_check(not reseau.en_ligne() and ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn" and ecran.message.text.is_empty(),
		"Échap (ou B) quitte le réseau et revient à l'écran Réseau, sans message")
	salon_client.free()
	if ecran != null:
		ecran.free()
```

par :

```gdscript
			% [attente_client, attente_arrivee, salon_client.etat.text])
	reseau.quitter()
	reseau.hote_perdu.emit()
	var ecran: Node = await _attendre_scene("res://Scenes/EcranEnLigne.tscn")
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn" and ecran.etat == ecran.Etat.ACCUEIL
		and ecran.message.text == tr("RESEAU_HOTE_PERDU"), "hôte perdu : retour à l'écran En ligne, « L'hôte a quitté la partie »")
	salon_client.free()
	if ecran != null:
		ecran.free()

	# Échap (ou B) : quitte le réseau, écran En ligne sans message (celui de l'hôte perdu ne s'affiche
	# qu'une fois)
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est de nouveau un client")
	salon_client = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon_client)
	await process_frame
	await _appuyer(&"ui_cancel", true)
	ecran = await _attendre_scene("res://Scenes/EcranEnLigne.tscn")
	_check(not reseau.en_ligne() and ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn" and ecran.message.text.is_empty(),
		"Échap (ou B) quitte le réseau et revient à l'écran En ligne, sans message")
	salon_client.free()
	if ecran != null:
		ecran.free()
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	# trouvé personne)
	var orphelin: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(orphelin)
	ecran = await _attendre_scene("res://Scenes/EcranReseau.tscn")
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn" and ecran.message.text == tr("RESEAU_HOTE_PERDU"),
		"un salon ouvert hors réseau revient à l'écran Réseau avec « L'hôte a quitté la partie »")
	orphelin.free()
	if ecran != null:
		ecran.free()
```

par :

```gdscript
	# trouvé personne)
	var orphelin: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(orphelin)
	ecran = await _attendre_scene("res://Scenes/EcranEnLigne.tscn")
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranEnLigne.tscn" and ecran.message.text == tr("RESEAU_HOTE_PERDU"),
		"un salon ouvert hors réseau revient à l'écran En ligne avec « L'hôte a quitté la partie »")
	orphelin.free()
	if ecran != null:
		ecran.free()
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   plus PERIODE_BALISE + DELAI_EXPIRATION (plus une marge) après le départ de l'hôte. Avec
##   --occupe : un second écouteur sur un port de balises déjà pris ; `ecouter()` doit renvoyer une
##   erreur sans planter (deux LeLion sur un même PC).
## Salon (phase 13), par les vraies scènes : l'écran Réseau (Héberger, ou Rejoindre par IP vers
##   127.0.0.1), qui passe la main au salon, puis la scène de jeu. Chaque poste écrit
##   « SALON OUVERT » à l'ouverture de son salon, note la ligne d'état du salon après chaque
##   `salon_change` (vérifiée à la fin), et écrit « MANCHE <empreinte> » une fois la scène de jeu
##   chargée (identifiant, pseudo et couleur de chaque index de `GameState.joueurs`, puis le
```

par :

```gdscript
##   plus PERIODE_BALISE + DELAI_EXPIRATION (plus une marge) après le départ de l'hôte. Avec
##   --occupe : un second écouteur sur un port de balises déjà pris ; `ecouter()` doit renvoyer une
##   erreur sans planter (deux LeLion sur un même PC).
## Salon (phase 13), par les vraies scènes : l'écran En ligne (Créer une partie, ou Rejoindre avec le
##   code « 127.0.0.1:--port »), qui passe la main au salon, puis la scène de jeu. Chaque poste écrit
##   « SALON OUVERT » à l'ouverture de son salon, note la ligne d'état du salon après chaque
##   `salon_change` (vérifiée à la fin), et écrit « MANCHE <empreinte> » une fois la scène de jeu
##   chargée (identifiant, pseudo et couleur de chaque index de `GameState.joueurs`, puis le
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   fois, il attend qu'un client repasse non prêt (le bouton se regrise), essaie quand même de
##   démarrer (« DEMARRAGE REFUSE » : la manche ne part pas) ; la seconde, il démarre.
##   Salon-client : --voir=N (attend d'avoir vu la table compter N joueurs : « SALON VU N »), puis
##   --partir (quitte le salon par Retour : l'écran Réseau revient) ou --reste=M (attend que la
##   table compte M joueurs ; défaut 2), --couleur=S et --feu=chemin (« ATTEND LE FEU », puis
##   demande la couleur voisine dans le sens S au feu : « COULEUR <html> »), prêt ensuite ;
##   --annuler=chemin (une fois ce fichier créé, repasse non prêt : « PLUS PRET » ; puis se
```

par :

```gdscript
##   fois, il attend qu'un client repasse non prêt (le bouton se regrise), essaie quand même de
##   démarrer (« DEMARRAGE REFUSE » : la manche ne part pas) ; la seconde, il démarre.
##   Salon-client : --voir=N (attend d'avoir vu la table compter N joueurs : « SALON VU N »), puis
##   --partir (quitte le salon par Retour : l'écran En ligne revient) ou --reste=M (attend que la
##   table compte M joueurs ; défaut 2), --couleur=S et --feu=chemin (« ATTEND LE FEU », puis
##   demande la couleur voisine dans le sens S au feu : « COULEUR <html> »), prêt ensuite ;
##   --annuler=chemin (une fois ce fichier créé, repasse non prêt : « PLUS PRET » ; puis se
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   --quitte quitte l'écran Résultats par Échap (« QUITTE », le titre) ; les autres le voient partir
##   (« DEPART VU ») ; l'hôte choisit Retour au salon : chacun y revient, la même table sans le partant,
##   personne prêt (« SALON <table> », la même ligne) ; puis l'hôte quitte le salon et l'autre client
##   revient à l'écran Réseau, « L'hôte a quitté la partie ».
##   Chrono-hôte : --clients=N, --niveau=L, --duree-manche=S, --duree-revanche=S, --revanche=chemin
##   (choisit Revanche une fois ce fichier créé par lancer.sh), --salon=chemin (Retour au salon, de même),
##   --rester=chemin (quitte le salon, de même).
```

par :

```gdscript
##   --quitte quitte l'écran Résultats par Échap (« QUITTE », le titre) ; les autres le voient partir
##   (« DEPART VU ») ; l'hôte choisit Retour au salon : chacun y revient, la même table sans le partant,
##   personne prêt (« SALON <table> », la même ligne) ; puis l'hôte quitte le salon et l'autre client
##   revient à l'écran En ligne, « L'hôte a quitté la partie ».
##   Chrono-hôte : --clients=N, --niveau=L, --duree-manche=S, --duree-revanche=S, --revanche=chemin
##   (choisit Revanche une fois ce fichier créé par lancer.sh), --salon=chemin (Retour au salon, de même),
##   --rester=chemin (quitte le salon, de même).
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript


## Rôles « salon-hote » et « salon-client » (phase 13, voir l'en-tête) : un poste passe par l'écran
## Réseau et le salon comme un joueur, jusqu'à la scène de jeu.
func _jouer_salon(hote: bool) -> void:
	var scores: Node = root.get_node("Scores")
	var gs: Node = root.get_node("GameState")
```

par :

```gdscript


## Rôles « salon-hote » et « salon-client » (phase 13, voir l'en-tête) : un poste passe par l'écran
## En ligne et le salon comme un joueur, jusqu'à la scène de jeu.
func _jouer_salon(hote: bool) -> void:
	var scores: Node = root.get_node("Scores")
	var gs: Node = root.get_node("GameState")
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	reseau.salon_change.connect(func() -> void: _tailles_vues.append(reseau.table_salon.size()))
	reseau.manche_lancee.connect(func(fiches: Array[Dictionary]) -> void: _fiches_manche.assign(fiches))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")), "l'écran Réseau s'ouvre")
	var ecran: Node = current_scene
	ecran.port_jeu = int(_option("port", "17777"))
	ecran.champ_pseudo.text = reseau.pseudo
	if hote:
		ecran.heberger()
	else:
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran Réseau passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return
```

par :

```gdscript
	reseau.salon_change.connect(func() -> void: _tailles_vues.append(reseau.table_salon.size()))
	reseau.manche_lancee.connect(func(fiches: Array[Dictionary]) -> void: _fiches_manche.assign(fiches))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	await _ouvrir_la_partie(hote)
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran En ligne passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
		print("SALON VU %d" % voir)
	if _options.has("partir"):
		salon.retour()
		_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")) and not reseau.en_ligne(),
			"Retour quitte le réseau et ramène à l'écran Réseau")
		if current_scene != null:
			current_scene.free()  # son écoute des balises se ferme avec lui
		return false
	var reste := int(_option("reste", "2"))
	_check(await _attendre(func() -> bool: return reseau.table_salon.size() == reste), "la table compte %d joueurs (%s)" % [reste, _tailles_vues])
```

par :

```gdscript
		print("SALON VU %d" % voir)
	if _options.has("partir"):
		salon.retour()
		_check(await _attendre(func() -> bool: return _scene_est("EcranEnLigne")) and not reseau.en_ligne(),
			"Retour quitte le réseau et ramène à l'écran En ligne")
		return false
	var reste := int(_option("reste", "2"))
	_check(await _attendre(func() -> bool: return reseau.table_salon.size() == reste), "la table compte %d joueurs (%s)" % [reste, _tailles_vues])
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	return true


func _scene_est(nom: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://Scenes/%s.tscn" % nom and current_scene.is_node_ready()

```

par :

```gdscript
	return true


## L'écran En ligne, puis Créer une partie (l'hôte, ENet sur --port) ou Rejoindre avec le code
## « 127.0.0.1:--port » (un client), comme un joueur.
func _ouvrir_la_partie(hote: bool) -> void:
	change_scene_to_file("res://Scenes/EcranEnLigne.tscn")
	_check(await _attendre(func() -> bool: return _scene_est("EcranEnLigne")), "l'écran En ligne s'ouvre")
	if not _scene_est("EcranEnLigne"):
		return
	var ecran: Node = current_scene
	ecran.port_jeu = int(_option("port", "17777"))
	ecran.champ_pseudo.text = reseau.pseudo
	if hote:
		ecran.creer_partie()
	else:
		ecran.champ_code.text = "127.0.0.1:%d" % ecran.port_jeu
		ecran.rejoindre()


func _scene_est(nom: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://Scenes/%s.tscn" % nom and current_scene.is_node_ready()

```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript


## Du salon à la scène de jeu d'une manche (rôles « manche-… » et « bout-… »), par les vraies scènes :
## l'écran Réseau (Héberger, ou Rejoindre par IP vers 127.0.0.1), le salon (l'hôte y choisit
## --niveau, attend 1 + --clients joueurs et démarre quand tous sont prêts), puis la scène de jeu.
## Renvoie la scène de jeu, ou null si ce poste n'y arrive pas (il a alors quitté le réseau).
func _rejoindre_la_manche(hote: bool) -> Node:
```

par :

```gdscript


## Du salon à la scène de jeu d'une manche (rôles « manche-… » et « bout-… »), par les vraies scènes :
## l'écran En ligne (`_ouvrir_la_partie`), le salon (l'hôte y choisit
## --niveau, attend 1 + --clients joueurs et démarre quand tous sont prêts), puis la scène de jeu.
## Renvoie la scène de jeu, ou null si ce poste n'y arrive pas (il a alors quitté le réseau).
func _rejoindre_la_manche(hote: bool) -> Node:
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	script_manche.delai_chargement = float(_option("delai-chargement", str(script_manche.DELAI_CHARGEMENT)))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	reseau.joueur_parti.connect(_sur_depart)
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")), "l'écran Réseau s'ouvre")
	var ecran: Node = current_scene
	ecran.port_jeu = int(_option("port", "17777"))
	ecran.champ_pseudo.text = reseau.pseudo
	if hote:
		ecran.heberger()
	else:
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran Réseau passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return null
```

par :

```gdscript
	script_manche.delai_chargement = float(_option("delai-chargement", str(script_manche.DELAI_CHARGEMENT)))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	reseau.joueur_parti.connect(_sur_depart)
	await _ouvrir_la_partie(hote)
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran En ligne passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return null
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	if hote:
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("rester", ""))), "lancer.sh laisse partir l'hôte")
		salon.retour()
		_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")) and not reseau.en_ligne(), "l'hôte quitte le salon : l'écran Réseau, hors réseau")
	else:
		_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")) and not reseau.en_ligne()
			and current_scene.message.text == tr("RESEAU_HOTE_PERDU"),
			"l'hôte parti du salon : l'écran Réseau, « L'hôte a quitté la partie »")
	change_scene_to_file("res://Scenes/Titre.tscn")  # l'écran Réseau écoute les balises : le titre, non
	_check(await _attendre(func() -> bool: return _scene_est("Titre")), "puis le titre")


```

par :

```gdscript
	if hote:
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("rester", ""))), "lancer.sh laisse partir l'hôte")
		salon.retour()
		_check(await _attendre(func() -> bool: return _scene_est("EcranEnLigne")) and not reseau.en_ligne(), "l'hôte quitte le salon : l'écran En ligne, hors réseau")
	else:
		_check(await _attendre(func() -> bool: return _scene_est("EcranEnLigne")) and not reseau.en_ligne()
			and current_scene.message.text == tr("RESEAU_HOTE_PERDU"),
			"l'hôte parti du salon : l'écran En ligne, « L'hôte a quitté la partie »")
	change_scene_to_file("res://Scenes/Titre.tscn")  # le joueur en a fini : le titre
	_check(await _attendre(func() -> bool: return _scene_est("Titre")), "puis le titre")


```

- [ ] **Step 2 : ils échouent**

```bash
timeout -k 5 120 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "code $?"; grep -E "SCRIPT ERROR|❌|== " "$TMPDIR/s.log" | head -5
```

Expected : `SCRIPT ERROR: Invalid access to property or key 'rangee_invitation' on a base object of type 'Control (Salon.gd)'.`, d'autres `SCRIPT ERROR` en cascade, puis le processus reste bloqué : `timeout` l'arrête (`code 124`). (Le test réseau échouerait aussi, aux scénarios 8 et 13 qui attendent l'écran En ligne au retour du salon : on ne le lance qu'au Step 4.)

- [ ] **Step 3 : le salon**

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
## Vomissez ! ») : chaque poste branche les règles de bataille et la table des joueurs
## (`GameState.configurer_bataille_reseau`), puis charge la scène de jeu. En 16:9 (spec §7).
##
## Retour (ou Échap, B à la manette) quitte le réseau et ramène à l'écran Réseau ; un hôte perdu y
## ramène avec « L'hôte a quitté la partie ». Aucun contrôle ne prend le focus (les boutons se
## cliquent à la souris) : les flèches, la croix, le stick, vomir et démarrer arrivent tous à
## `_unhandled_input`.

const SCENE_JEU := "res://Scenes/Main.tscn"
const SCENE_RESEAU := "res://Scenes/EcranReseau.tscn"
const _EcranReseau := preload("res://Scripts/EcranReseau.gd")
const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
## Six cartes et leurs écarts tiennent dans les 2000 px ; un pseudo de 12 caractères larges
```

par :

```gdscript
## Vomissez ! ») : chaque poste branche les règles de bataille et la table des joueurs
## (`GameState.configurer_bataille_reseau`), puis charge la scène de jeu. En 16:9 (spec §7).
##
## L'hôte voit le code de la partie (`Reseau.code_partie`, relu à chaque affichage) : un code de salle
## (« K7Q-2XM ») et « Copier le lien », qui met le lien d'invitation dans le presse-papiers (spec §4.4) ;
## sur le desktop de développement, l'adresse `ip:port` de l'hôte ENet, sans lien.
##
## Retour (ou Échap, B à la manette) quitte le réseau et ramène à l'écran En ligne ; un hôte perdu y
## ramène avec « L'hôte a quitté la partie ». Aucun contrôle ne prend le focus (les boutons se
## cliquent à la souris) : les flèches, la croix, le stick, vomir et démarrer arrivent tous à
## `_unhandled_input`.

const SCENE_JEU := "res://Scenes/Main.tscn"
const SCENE_EN_LIGNE := "res://Scenes/EcranEnLigne.tscn"
const _EcranEnLigne := preload("res://Scripts/EcranEnLigne.gd")
const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
## Six cartes et leurs écarts tiennent dans les 2000 px ; un pseudo de 12 caractères larges
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
const COULEUR_PRET := Color(0.55, 1.0, 0.55)
const COULEUR_ATTENTE := Color(1, 1, 1, 0.55)
const COULEUR_CONTOUR := Color(0.1, 0.05, 0.15, 1)
## Actions du salon, prises à l'appui (voir `_unhandled_input`).
const ACTIONS: Array[StringName] = [&"deplacer_gauche", &"deplacer_droite", &"deplacer_haut", &"deplacer_bas",
	&"vomir", &"demarrer"]
```

par :

```gdscript
const COULEUR_PRET := Color(0.55, 1.0, 0.55)
const COULEUR_ATTENTE := Color(1, 1, 1, 0.55)
const COULEUR_CONTOUR := Color(0.1, 0.05, 0.15, 1)
## Secondes pendant lesquelles « Copier le lien » dit « Lien copié ! ».
const DUREE_LIEN_COPIE := 2.0
## Actions du salon, prises à l'appui (voir `_unhandled_input`).
const ACTIONS: Array[StringName] = [&"deplacer_gauche", &"deplacer_droite", &"deplacer_haut", &"deplacer_bas",
	&"vomir", &"demarrer"]
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
@onready var rangee_cartes: HBoxContainer = $Centre/Colonne/Cartes
@onready var etat: Label = $Centre/Colonne/Etat
@onready var aide: Label = $Centre/Colonne/Aide
@onready var adresses: Label = $Centre/Colonne/Adresses
@onready var bouton_demarrer: Button = $Centre/Colonne/Demarrer
@onready var bouton_retour: Button = $BoutonRetour

```

par :

```gdscript
@onready var rangee_cartes: HBoxContainer = $Centre/Colonne/Cartes
@onready var etat: Label = $Centre/Colonne/Etat
@onready var aide: Label = $Centre/Colonne/Aide
@onready var rangee_invitation: HBoxContainer = $Centre/Colonne/Invitation
@onready var etiquette_code: Label = $Centre/Colonne/Invitation/Code
@onready var bouton_copier: Button = $Centre/Colonne/Invitation/CopierLien
@onready var bouton_demarrer: Button = $Centre/Colonne/Demarrer
@onready var bouton_retour: Button = $BoutonRetour

```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
## relevées à l'ouverture (phase 18, M3 de la revue finale 13 : un stick déjà penché en arrivant, d'une
## manche ou de l'écran Résultats, n'agit pas une fois de lui-même).
var _tenues: Dictionary[StringName, bool] = {}
## Chez l'hôte, ses adresses (`Decouverte.adresses_hote`), relevées une fois à l'ouverture (phase 18, M4
## de la revue finale 13 : pas à chaque changement du salon).
var _adresses_hote := PackedStringArray()


func _ready() -> void:
```

par :

```gdscript
## relevées à l'ouverture (phase 18, M3 de la revue finale 13 : un stick déjà penché en arrivant, d'une
## manche ou de l'écran Résultats, n'agit pas une fois de lui-même).
var _tenues: Dictionary[StringName, bool] = {}


func _ready() -> void:
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
	Parametres.langue_changee.connect(_sur_langue_changee)
	if not Reseau.en_ligne():
		# L'hôte est parti entre l'inscription et l'arrivée ici : son signal n'a trouvé personne.
		_revenir_au_reseau.call_deferred(Reseau.raison_perte)
		return
	if multiplayer.is_server():
		_adresses_hote = Decouverte.adresses_hote(IP.get_local_interfaces())
		Reseau.ouvrir_salon(GameState.niveau_courant)
	_sur_salon_change()

```

par :

```gdscript
	Parametres.langue_changee.connect(_sur_langue_changee)
	if not Reseau.en_ligne():
		# L'hôte est parti entre l'inscription et l'arrivée ici : son signal n'a trouvé personne.
		_revenir_a_l_ecran_en_ligne.call_deferred(Reseau.raison_perte)
		return
	if multiplayer.is_server():
		Reseau.ouvrir_salon(GameState.niveau_courant)
	_sur_salon_change()

```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
		_afficher()


## Quitte le réseau (l'hôte : ses clients le voient partir) et revient à l'écran Réseau.
## `changer_scene` à faux pour les tests.
func retour(changer_scene := true) -> void:
	Reseau.quitter()
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_RESEAU)


func _agir(action: StringName) -> void:
```

par :

```gdscript
		_afficher()


## Quitte le réseau (l'hôte : ses clients le voient partir) et revient à l'écran En ligne.
## `changer_scene` à faux pour les tests.
func retour(changer_scene := true) -> void:
	Reseau.quitter()
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_EN_LIGNE)


## L'hôte : met le lien d'invitation de sa salle dans le presse-papiers (spec §4.4). Sur le Web, l'API du
## presse-papiers exige le geste d'un clic : c'est le clic sur le bouton qui appelle ceci. Le bouton dit
## « Lien copié ! » DUREE_LIEN_COPIE secondes. Renvoie le lien copié (vide sans code de salle).
func copier_lien() -> String:
	if not CodeSalle.valide(Reseau.code_partie):
		return ""
	var lien := CodeSalle.lien(Reseau.code_partie)
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(lien)
	bouton_copier.text = "SALON_LIEN_COPIE"
	get_tree().create_timer(DUREE_LIEN_COPIE).timeout.connect(_remettre_bouton_copier)
	return lien


func _remettre_bouton_copier() -> void:
	bouton_copier.text = "SALON_COPIER_LIEN"


func _agir(action: StringName) -> void:
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript


func _sur_hote_perdu() -> void:
	_revenir_au_reseau(Reseau.raison_perte)


func _sur_langue_changee(_langue: String) -> void:
	_afficher()


## Retour à l'écran Réseau, qui affiche le message `cle` en arrivant.
func _revenir_au_reseau(cle: String) -> void:
	_EcranReseau.message_a_l_arrivee = cle
	get_tree().change_scene_to_file(SCENE_RESEAU)


func _afficher() -> void:
```

par :

```gdscript


func _sur_hote_perdu() -> void:
	_revenir_a_l_ecran_en_ligne(Reseau.raison_perte)


func _sur_langue_changee(_langue: String) -> void:
	_afficher()


## Retour à l'écran En ligne, qui affiche le message `cle` en arrivant.
func _revenir_a_l_ecran_en_ligne(cle: String) -> void:
	_EcranEnLigne.message_a_l_arrivee = cle
	get_tree().change_scene_to_file(SCENE_EN_LIGNE)


func _afficher() -> void:
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
	var hote := multiplayer.is_server()
	titre_niveau.text = tr("SALON_NIVEAU") % tr(GameState.NIVEAUX[Reseau.niveau_salon].nom)
	aide.text = tr("SALON_AIDE_HOTE" if hote else "SALON_AIDE")
	adresses.visible = hote
	if hote:
		# I1 (revue finale 12 bis) : triées par interface (physique d'abord), pas seulement par plage
		# IPv4, sans quoi une carte virtuelle (bridge, vEthernet, VMware…) pouvait passer devant le
		# Wi-Fi ; l'écran Réseau utilisait la même liste pour l'hébergement, le salon la reprend ici.
		var liste := ", ".join(_adresses_hote)
		adresses.text = tr("SALON_ADRESSES") % (liste if not liste.is_empty() else "?")
	_afficher_etat()


```

par :

```gdscript
	var hote := multiplayer.is_server()
	titre_niveau.text = tr("SALON_NIVEAU") % tr(GameState.NIVEAUX[Reseau.niveau_salon].nom)
	aide.text = tr("SALON_AIDE_HOTE" if hote else "SALON_AIDE")
	rangee_invitation.visible = hote and not Reseau.code_partie.is_empty()
	etiquette_code.text = tr("SALON_CODE") % CodeSalle.formater(Reseau.code_partie)
	bouton_copier.visible = CodeSalle.valide(Reseau.code_partie)
	_afficher_etat()


```

Dans `Scenes/Salon.tscn`, remplacer :

```
theme_override_font_sizes/font_size = 26
horizontal_alignment = 1

[node name="Adresses" type="Label" parent="Centre/Colonne"]
custom_minimum_size = Vector2(1600, 0)
layout_mode = 2
auto_translate_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.75)
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.12, 0.85)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 26
horizontal_alignment = 1
autowrap_mode = 3

[node name="BoutonRetour" type="Button" parent="."]
layout_mode = 1
```

par :

```
theme_override_font_sizes/font_size = 26
horizontal_alignment = 1

[node name="Invitation" type="HBoxContainer" parent="Centre/Colonne"]
layout_mode = 2
theme_override_constants/separation = 32
alignment = 1

[node name="Code" type="Label" parent="Centre/Colonne/Invitation"]
layout_mode = 2
auto_translate_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.2, 1)
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.12, 0.85)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 40
vertical_alignment = 1

[node name="CopierLien" type="Button" parent="Centre/Colonne/Invitation"]
custom_minimum_size = Vector2(320, 64)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 28
text = "SALON_COPIER_LIEN"

[node name="BoutonRetour" type="Button" parent="."]
layout_mode = 1
```

Dans `Scenes/Salon.tscn`, remplacer :

```

[connection signal="pressed" from="BoutonRetour" to="." method="retour"]
[connection signal="pressed" from="Centre/Colonne/Demarrer" to="." method="demarrer"]
```

par :

```

[connection signal="pressed" from="BoutonRetour" to="." method="retour"]
[connection signal="pressed" from="Centre/Colonne/Demarrer" to="." method="demarrer"]
[connection signal="pressed" from="Centre/Colonne/Invitation/CopierLien" to="." method="copier_lien"]
```

Dans `Assets/Traductions/traductions.csv`, remplacer :

```
SALON_DEMARRER,Démarrer la partie,Start the game
SALON_AIDE,"Gauche/Droite : couleur   ·   Espace : prêt   ·   Échap : quitter","Left/Right: color   ·   Space: ready   ·   Esc: leave"
SALON_AIDE_HOTE,"Gauche/Droite : couleur   ·   Haut/Bas : niveau   ·   Espace : prêt   ·   Tab : démarrer   ·   Échap : quitter","Left/Right: color   ·   Up/Down: level   ·   Space: ready   ·   Tab: start   ·   Esc: leave"
SALON_ADRESSES,"Les autres te voient dans leur liste, ou tapent ton adresse : %s","Others see you in their list, or type your address: %s"
PAUSE_RESEAU,La partie continue,The game goes on
QUITTER_PARTIE,Quitter la partie,Leave the game
BATAILLE_JOUEUR,Joueur %d,Player %d
```

par :

```
SALON_DEMARRER,Démarrer la partie,Start the game
SALON_AIDE,"Gauche/Droite : couleur   ·   Espace : prêt   ·   Échap : quitter","Left/Right: color   ·   Space: ready   ·   Esc: leave"
SALON_AIDE_HOTE,"Gauche/Droite : couleur   ·   Haut/Bas : niveau   ·   Espace : prêt   ·   Tab : démarrer   ·   Échap : quitter","Left/Right: color   ·   Up/Down: level   ·   Space: ready   ·   Tab: start   ·   Esc: leave"
SALON_CODE,Code de la partie : %s,Game code: %s
SALON_COPIER_LIEN,Copier le lien,Copy link
SALON_LIEN_COPIE,Lien copié !,Link copied!
PAUSE_RESEAU,La partie continue,The game goes on
QUITTER_PARTIE,Quitter la partie,Leave the game
BATAILLE_JOUEUR,Joueur %d,Player %d
```

- [ ] **Step 4 : ils passent**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== |Copier|code de la partie" "$TMPDIR/s.log"
SECONDS=0; DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r.log"
grep -rn "Decouverte.adresses_hote\|SALON_ADRESSES\|EcranReseau" Scripts/Salon.gd Scenes/Salon.tscn Assets/Traductions/traductions.csv tests/reseau/joueur.gd
```

Expected : smoke `0`, `== 0 échec(s) ==`, dont « sur le desktop, le code de la partie ENet (son adresse), sans lien à copier (Code de la partie : 127.0.0.1:17797) », « Copier le lien : le lien d'invitation, et « Lien copié ! » », « 2 s plus tard, le bouton redit « Copier le lien » » ; réseau `code 0`, `== 0 échec(s) ==`, environ 170 s (mesuré 168 s sans `DIFFUSION`), écart exclusion ≈ 500 ms, départ arraché de 8 500 à 11 000 ms, départs volontaires sous 1 000 ms ; rien au `grep`.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Salon.gd Scenes/Salon.tscn Assets/Traductions/ tests/smoke_test.gd tests/reseau/joueur.gd
git commit -m "Salon : l'hôte voit le code de la partie (K7Q-2XM, ou l'adresse ENet sur le desktop) et Copier le lien (presse-papiers dans le clic, Lien copié ! 2 s) à la place de ses adresses LAN ; Retour et hôte perdu ramènent à l'écran En ligne ; test réseau : chaque poste passe par l'écran En ligne (Créer une partie, Rejoindre avec 127.0.0.1:port)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 5 : les captures et les deux fenêtres par l'écran En ligne

**Files:**
- Modify: `tests/screenshots.gd` (en-tête, `_reseau`, `_salon`)
- Modify: `tests/deux_fenetres.gd` (en-tête, l'écran En ligne dans `_run`, `_nettoyer_mes_fichiers` qui garde les captures)
- Modify: `tests/reseau/lancer.sh` (le commentaire du scénario 8)
- Modify: `.github/workflows/ci.yml:84` (37 → 38 captures)

**Interfaces:**
- Consumes : `EcranEnLigne` (`codes_de_salle`, `code_a_l_arrivee`, `creer_partie`, `rejoindre`, `champ_code`, `port_jeu`), `Reseau.raison_echec`, `transport_disponible`, `code_partie`, `Transport.ECHEC_INCONNUE`.
- Produces : 38 captures (`reseau_00` à `reseau_10`, `salon_00` à `salon_07`, puis bataille et résultats inchangés).

- [ ] **Step 1 : les captures et les deux fenêtres**

Dans `tests/screenshots.gd`, remplacer :

```gdscript
## Écrit ses PNG dans <dossier> (défaut : user://), par partie (toutes par défaut) :
##   solo       le titre, une partie solo (gerbe à 3 puis 7 couleurs, ennemis, pause, défaite), une
##              victoire avec record, le peintre du Village ;
##   reseau     le titre et son bouton Multijoueur, l'écran Réseau (vide, liste, IP invalide, connexion,
##              refus de version, anglais, port des balises occupé ; phase 12 bis) ;
##   salon      l'hôte seul, le salon à 3 (bouton grisé puis actif), à 6 aux pseudos larges, en anglais,
##              vu d'un client (tous prêts, un joueur qui arrive ; phase 13) ;
##   bataille   la manche à 6 couleurs (départ, en jeu : parts, rangs, couronnes, crans, gerbe XXL,
##              étourdi, parti ; les dix dernières secondes), une égalité à 2 en anglais (phase 17) ;
##   resultats  l'écran Résultats d'une bataille à 6 (animation, hôte local, client, hôte en réseau,
```

par :

```gdscript
## Écrit ses PNG dans <dossier> (défaut : user://), par partie (toutes par défaut) :
##   solo       le titre, une partie solo (gerbe à 3 puis 7 couleurs, ennemis, pause, défaite), une
##              victoire avec record, le peintre du Village ;
##   reseau     le titre et son bouton Multijoueur, l'écran En ligne (phase 3 du jeu en ligne) : comme sur
##              le Web (accueil, code trop court, code à confusion, partie inconnue, pas de transport,
##              anglais, une page ouverte sur un lien d'invitation), puis sur le desktop de développement
##              (connexion à l'adresse d'un hôte ENet, refus de version) ;
##   salon      l'hôte seul (le code de sa salle et « Copier le lien »), le salon à 3 (bouton grisé puis
##              actif), à 6 aux pseudos larges, en anglais, vu d'un client (tous prêts, un joueur qui
##              arrive ; phase 13) ;
##   bataille   la manche à 6 couleurs (départ, en jeu : parts, rangs, couronnes, crans, gerbe XXL,
##              étourdi, parti ; les dix dernières secondes), une égalité à 2 en anglais (phase 17) ;
##   resultats  l'écran Résultats d'une bataille à 6 (animation, hôte local, client, hôte en réseau,
```

Dans `tests/screenshots.gd`, remplacer :

```gdscript
	current_scene = null


# --- Écran Réseau (phase 12 bis) --------------------------------------------------------------------


func _reseau() -> void:
	var scores: Node = root.get_node("Scores")
	var params: Node = root.get_node("Parametres")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	scores.definir_preference("pseudo", "MMMMMMMMMMMM")  # 12 caractères larges : le champ doit les tenir
	decouverte.port_balise = PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])

	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
```

par :

```gdscript
	current_scene = null


# --- Écran En ligne (phase 3 du jeu en ligne) --------------------------------------------------------


func _reseau() -> void:
	var scores: Node = root.get_node("Scores")
	var params: Node = root.get_node("Parametres")
	var reseau: Node = root.get_node("Reseau")
	scores.definir_preference("pseudo", "MMMMMMMMMMMM")  # 12 caractères larges : le champ doit les tenir

	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
```

Dans `tests/screenshots.gd`, remplacer :

```gdscript
	await _shot("reseau_01_titre_focus_multijoueur")
	titre.free()

	var ecran: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	ecran.port_jeu = PORT_JEU
	root.add_child(ecran)
	await _attendre(0.3)
	await _shot("reseau_02_vide")

	var futur := Time.get_ticks_msec() + 600000  # ces parties n'expirent pas pendant les captures
	var zoe := {"version": reseau.version, "port": 7777, "nb_joueurs": 2, "places": 6, "manche_en_cours": false, "niveau": 1, "pseudo": "Zoé"}
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.20", zoe, futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.21", zoe.merged({"pseudo": "Anna", "nb_joueurs": 6}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.22", zoe.merged({"pseudo": "Bob", "version": "0.10"}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.23", zoe.merged({"pseudo": "Chloé", "manche_en_cours": true, "niveau": 2}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.24", zoe.merged({"pseudo": "MMMMMMMMMMMM", "nb_joueurs": 5, "niveau": 0}, true), futur)
	decouverte.parties_changees.emit()
	await _attendre(0.2)
	await _shot("reseau_03_liste")
	ecran.boutons_parties["192.168.1.20:7777"].grab_focus()
	await _attendre(0.1)
	await _shot("reseau_04_focus_partie")

	ecran.champ_ip.text = "lelion.local"
	ecran.rejoindre_par_ip()
	await _attendre(0.1)
	await _shot("reseau_05_ip_invalide")

	ecran.champ_ip.text = "127.0.0.1"
	ecran.port_jeu = PORT_SANS_HOTE
	ecran.rejoindre_par_ip()
	await _attendre(0.1)
	await _shot("reseau_06_connexion")
	reseau.quitter()
	reseau.refuse.emit(reseau.REFUS_VERSION, "0.10")
	await _attendre(0.1)
	await _shot("reseau_07_refus_version")

	params.definir_langue("en")
	decouverte.parties.clear()
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.20", zoe, futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.21", zoe.merged({"pseudo": "Anna", "nb_joueurs": 6}, true), futur)
	decouverte.parties_changees.emit()
	await _attendre(0.2)
	await _shot("reseau_08_anglais")
	params.definir_langue("fr")
	ecran.free()
	decouverte.parties.clear()

	var intrus := PacketPeerUDP.new()
	intrus.bind(decouverte.port_balise, "0.0.0.0")
	var ecran2: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	root.add_child(ecran2)
	await _attendre(0.3)
	await _shot("reseau_09_ecoute_impossible")
	ecran2.free()
	intrus.close()


# --- Salon (phase 13) ------------------------------------------------------------------------------
```

par :

```gdscript
	await _shot("reseau_01_titre_focus_multijoueur")
	titre.free()

	# Comme sur le Web : un code de salle
	var ecran: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran.port_jeu = PORT_JEU
	ecran.codes_de_salle = true
	root.add_child(ecran)
	await _attendre(0.3)
	await _shot("reseau_02_accueil")
	ecran.champ_code.text = "K7Q2X"
	ecran.rejoindre()
	await _attendre(0.1)
	await _shot("reseau_03_code_trop_court")
	ecran.champ_code.text = "K0Q-2XM"
	ecran.rejoindre()
	await _attendre(0.1)
	await _shot("reseau_04_code_confusion")
	ecran.champ_code.text = "K7Q-2XM"
	reseau.raison_echec = Transport.ECHEC_INCONNUE  # ce que dira TransportWebRTC d'un code sans salle (phase 4)
	reseau.connexion_echouee.emit()
	reseau.raison_echec = ""
	await _attendre(0.1)
	await _shot("reseau_05_partie_inconnue")
	reseau.transport_disponible = false
	ecran.creer_partie()
	reseau.transport_disponible = true
	await _attendre(0.1)
	await _shot("reseau_06_pas_de_transport")
	params.definir_langue("en")
	ecran.champ_code.text = "K7Q2X"
	ecran.rejoindre()
	await _attendre(0.2)
	await _shot("reseau_07_anglais")
	params.definir_langue("fr")
	ecran.free()

	# Une page ouverte sur un lien d'invitation (`?salle=K7Q2XM`) : le code rempli, Rejoindre au focus
	var ecran_lien: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran_lien.codes_de_salle = true
	ecran_lien.code_a_l_arrivee = "K7Q2XM"
	root.add_child(ecran_lien)
	await _attendre(0.3)
	await _shot("reseau_08_lien")
	ecran_lien.free()

	# Le desktop de développement : l'adresse d'un hôte ENet
	var ecran_dev: Control = load("res://Scenes/EcranEnLigne.tscn").instantiate()
	ecran_dev.port_jeu = PORT_JEU
	root.add_child(ecran_dev)
	ecran_dev.champ_code.text = "127.0.0.1:%d" % PORT_SANS_HOTE
	ecran_dev.rejoindre()
	await _attendre(0.3)
	await _shot("reseau_09_connexion_desktop")
	reseau.quitter()
	reseau.refuse.emit(reseau.REFUS_VERSION, "0.10")
	await _attendre(0.1)
	await _shot("reseau_10_refus_version")
	ecran_dev.free()


# --- Salon (phase 13) ------------------------------------------------------------------------------
```

Dans `tests/screenshots.gd`, remplacer :

```gdscript
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	GS.niveau_courant = 1

	# L'hôte seul, pseudo de 12 caractères larges : Démarrer grisé, « Il faut au moins 2 joueurs »
	reseau.pseudo = "MMMMMMMMMMMM"
	reseau.heberger(PORT_JEU)
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await _attendre(0.4)
```

par :

```gdscript
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	GS.niveau_courant = 1

	# L'hôte seul, pseudo de 12 caractères larges : Démarrer grisé, « Il faut au moins 2 joueurs » ; le code
	# d'une salle de la signalisation (le Web, phase 4) et « Copier le lien »
	reseau.pseudo = "MMMMMMMMMMMM"
	reseau.heberger(PORT_JEU)
	reseau.code_partie = "K7Q2XM"
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await _attendre(0.4)
```

Dans `tests/deux_fenetres.gd`, remplacer :

```gdscript
extends SceneTree
## Une partie à deux vraies fenêtres sur ce poste (◉, phases 14 et 19 ; la CI la déroule sans rendu (pas « Captures »)) : un hôte
## et un client passent par l'écran Réseau et le salon, jouent une manche courte au clavier simulé,
## voient le même écran Résultats, puis l'hôte quitte et le client le voit partir. Deux processus :
##   godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=<dossier>
##   godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier=<dossier>
```

par :

```gdscript
extends SceneTree
## Une partie à deux vraies fenêtres sur ce poste (◉, phases 14 et 19 ; la CI la déroule sans rendu (pas « Captures »)) : un hôte
## et un client passent par l'écran En ligne et le salon, jouent une manche courte au clavier simulé,
## voient le même écran Résultats, puis l'hôte quitte et le client le voit partir. Deux processus :
##   godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=<dossier>
##   godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier=<dossier>
```

Dans `tests/deux_fenetres.gd`, remplacer :

```gdscript
	DisplayServer.window_set_position(Vector2i(20, 40) if role == "hote" else Vector2i(740, 440))
	DisplayServer.window_set_size(Vector2i(700, 227))  # la fenêtre du solo, en plus petit : deux tiennent à l'écran

	# L'écran Réseau, puis le salon
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	await _attendre(func() -> bool: return _scene_est("EcranReseau"))
	var ecran: Node = current_scene
	ecran.port_jeu = PORT
	ecran.champ_pseudo.text = "Hôte" if role == "hote" else "Invitée"
	if role == "hote":
		ecran.heberger()
		_signaler("heberge")
	else:
		await _attendre_l_autre("heberge")
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	await _attendre(func() -> bool: return _scene_est("Salon"))
	var salon: Node = current_scene
	if role == "hote":
```

par :

```gdscript
	DisplayServer.window_set_position(Vector2i(20, 40) if role == "hote" else Vector2i(740, 440))
	DisplayServer.window_set_size(Vector2i(700, 227))  # la fenêtre du solo, en plus petit : deux tiennent à l'écran

	# L'écran En ligne, puis le salon
	change_scene_to_file("res://Scenes/EcranEnLigne.tscn")
	await _attendre(func() -> bool: return _scene_est("EcranEnLigne"))
	var ecran: Node = current_scene
	ecran.port_jeu = PORT
	ecran.champ_pseudo.text = "Hôte" if role == "hote" else "Invitée"
	if role == "hote":
		ecran.creer_partie()
		_signaler("heberge")
	else:
		await _attendre_l_autre("heberge")
		ecran.champ_code.text = "127.0.0.1:%d" % PORT
		ecran.rejoindre()
	await _attendre(func() -> bool: return _scene_est("Salon"))
	var salon: Node = current_scene
	if role == "hote":
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
	echo "  (scénario 7, découverte en vraie diffusion : DIFFUSION=1 pour le lancer)"
fi

# 8. Salon (phase 13), par les vraies scènes : un hôte et trois clients passent par l'écran Réseau
#    et le salon, arrivés dans l'ordre (index 1, 2, 3). B repart du salon par Retour : sa carte se
#    libère chez tous, un trou reste à l'index 2. A et C demandent au même feu la couleur voisine
#    (A la suivante, C la précédente : toutes deux visent celle de B) ; l'hôte arbitre, chacun garde
```

par :

```bash
	echo "  (scénario 7, découverte en vraie diffusion : DIFFUSION=1 pour le lancer)"
fi

# 8. Salon (phase 13), par les vraies scènes : un hôte et trois clients passent par l'écran En ligne
#    et le salon, arrivés dans l'ordre (index 1, 2, 3). B repart du salon par Retour : sa carte se
#    libère chez tous, un trou reste à l'index 2. A et C demandent au même feu la couleur voisine
#    (A la suivante, C la précédente : toutes deux visent celle de B) ; l'hôte arbitre, chacun garde
```

Dans `.github/workflows/ci.yml`, remplacer :

```yaml
            echo "::error::tests/deux_fenetres.gd a échoué (hôte $statut_hote, client $statut_client)"; exit 1
          fi
          if grep -nE "SCRIPT ERROR|SHADER ERROR|❌" captures.log deux_fenetres_hote.log deux_fenetres_client.log; then echo "::error::erreur dans un script de captures"; exit 1; fi
          [ "$(grep -c "📸" captures.log)" -eq 37 ] || { echo "::error::tests/screenshots.gd n'a pas déroulé ses 37 captures"; exit 1; }
          [ "$(grep -c "📸" deux_fenetres_hote.log)" -eq 5 ] && [ "$(grep -c "📸" deux_fenetres_client.log)" -eq 6 ] \
            || { echo "::error::tests/deux_fenetres.gd n'a pas déroulé ses captures (5 pour l'hôte, 6 pour le client)"; exit 1; }

```

par :

```yaml
            echo "::error::tests/deux_fenetres.gd a échoué (hôte $statut_hote, client $statut_client)"; exit 1
          fi
          if grep -nE "SCRIPT ERROR|SHADER ERROR|❌" captures.log deux_fenetres_hote.log deux_fenetres_client.log; then echo "::error::erreur dans un script de captures"; exit 1; fi
          [ "$(grep -c "📸" captures.log)" -eq 38 ] || { echo "::error::tests/screenshots.gd n'a pas déroulé ses 38 captures"; exit 1; }
          [ "$(grep -c "📸" deux_fenetres_hote.log)" -eq 5 ] && [ "$(grep -c "📸" deux_fenetres_client.log)" -eq 6 ] \
            || { echo "::error::tests/deux_fenetres.gd n'a pas déroulé ses captures (5 pour l'hôte, 6 pour le client)"; exit 1; }

```

Les deux fenêtres effaçaient aussi leurs propres captures en finissant (tout fichier `hote_*` ou `client_*` du dossier) : le contrôle visuel de la Task 7 n'en trouvait aucune. Dans `tests/deux_fenetres.gd`, remplacer :

```gdscript
## Supprime les fichiers de rendez-vous que CE poste a lui-même écrits (jamais ceux de
## l'autre) : appelé au tout début (un tour précédent dans le même dossier) et après `fin`.
```

par :

```gdscript
## Supprime les fichiers de rendez-vous que CE poste a lui-même écrits (jamais ceux de
## l'autre, ni ses captures : un rendez-vous n'a pas d'extension) : appelé au tout début (un tour
## précédent dans le même dossier) et après `fin`.
```

Dans `tests/deux_fenetres.gd`, remplacer :

```gdscript
		if not dir.current_is_dir() and f.begins_with(role + "_"):
```

par :

```gdscript
		if not dir.current_is_dir() and f.begins_with(role + "_") and f.get_extension().is_empty():
```

- [ ] **Step 2 : le déroulé sans rendu, comme la CI**

```bash
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"; grep "📸 reseau" "$TMPDIR/c.log" | cut -c1-40
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/dc.log" 2>&1 &
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/dh.log" 2>&1; echo "deux fenêtres hôte $?"; wait; grep -c "📸" "$TMPDIR/dh.log" "$TMPDIR/dc.log"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/dh.log" "$TMPDIR/dc.log"
grep -rn "EcranReseau\|rejoindre_par_ip\|champ_ip" tests/screenshots.gd tests/deux_fenetres.gd tests/reseau/
```

Expected : `captures 0 : 38 📸`, les onze `📸 reseau_00_titre_multijoueur` à `📸 reseau_10_refus_version` ; `deux fenêtres hôte 0`, 5 et 6 📸 ; rien d'autre (ni ❌, ni `SCRIPT ERROR`, ni `grep`).

- [ ] **Step 3 : Commit**

```bash
git add tests/screenshots.gd tests/deux_fenetres.gd tests/reseau/lancer.sh .github/workflows/ci.yml
git commit -m "Captures : l'écran En ligne comme sur le Web (accueil, code trop court, confusion, partie inconnue, pas de transport, anglais, lien d'invitation) puis sur le desktop (connexion à un hôte ENet, refus de version), le code de la salle et Copier le lien au salon de l'hôte (38 captures, CI ajustée) ; deux fenêtres par l'écran En ligne

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 6 : la spec et le README

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§3.1 ligne `EcranEnLigne`, §4.4, §9 ligne « Code mal formé »)
- Modify: `README.md` (le paragraphe « Until online play lands », `Scenes/`, la ligne du smoke test)

**Interfaces:** aucune.

- [ ] **Step 1 : la spec**

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

```
| `Transport` (interface `@abstract`, `RefCounted`) | `heberger() -> Error`, `rejoindre(code: String) -> Error`, `quitter()` (ferme une fois envoyé ce qui est en file, en arrière-plan), `clore()` (tout de suite), `pair() -> MultiplayerPeer`, `liberer(id)` (chez l'hôte : ferme sur-le-champ le canal d'un pair parti, muet ou exclu, sans attendre de réponse ; son `peer_disconnected` part pendant l'appel), `servir() -> bool` (à chaque image ; faux une fois fermé) ; signaux `pret(code)` (chez l'hôte : la salle existe), `connecte()` (chez le client : canal ouvert, la poignée de main peut partir), `echec(raison)`. Ne sait rien du salon ni du jeu. | rien |
| `TransportWebRTC` | Le transport livré : la signalisation (§4), un `WebRTCPeerConnection` par client chez l'hôte, la configuration ICE reçue du Worker, les canaux (§5). | `Transport`, `WebSocketPeer` |
| `TransportENet` | Le transport ENet de LeLion-multi, extrait de `Reseau.gd`, gardé pour la **version desktop de développement et les tests headless** (les 13 scénarios réseau, le relais de latence). Jamais choisi dans l'export Web. Le « code » y est `ip:port`. | `Transport` |
| `EcranEnLigne` (remplace `EcranReseau`) | Pseudo (mémorisé dans `Scores`), *Créer une partie* (absent sur mobile), *Rejoindre* avec un champ de code (pré-rempli par `?salle=`), messages d'erreur (§9). Le salon affiche le code et *Copier le lien*. | `Reseau` |
| `signalisation/` (Worker + Durable Object `Salle`, JavaScript) | Crée les salles, relaie offres, réponses et candidats entre l'hôte et chaque arrivant, fournit les identifiants TURN, applique les plafonds (§8). Ne lit pas le contenu WebRTC. Six modules (`index`, `origine`, `code`, `protocole`, `ice`, `salle`, environ 440 lignes), avec ses tests `vitest` dans l'environnement local de Cloudflare (`@cloudflare/vitest-plugin`). | API TURN de Cloudflare |

Le choix du transport : `TransportWebRTC` quand `OS.has_feature("web")`, `TransportENet` sinon (ou
```

par :

```
| `Transport` (interface `@abstract`, `RefCounted`) | `heberger() -> Error`, `rejoindre(code: String) -> Error`, `quitter()` (ferme une fois envoyé ce qui est en file, en arrière-plan), `clore()` (tout de suite), `pair() -> MultiplayerPeer`, `liberer(id)` (chez l'hôte : ferme sur-le-champ le canal d'un pair parti, muet ou exclu, sans attendre de réponse ; son `peer_disconnected` part pendant l'appel), `servir() -> bool` (à chaque image ; faux une fois fermé) ; signaux `pret(code)` (chez l'hôte : la salle existe), `connecte()` (chez le client : canal ouvert, la poignée de main peut partir), `echec(raison)`. Ne sait rien du salon ni du jeu. | rien |
| `TransportWebRTC` | Le transport livré : la signalisation (§4), un `WebRTCPeerConnection` par client chez l'hôte, la configuration ICE reçue du Worker, les canaux (§5). | `Transport`, `WebSocketPeer` |
| `TransportENet` | Le transport ENet de LeLion-multi, extrait de `Reseau.gd`, gardé pour la **version desktop de développement et les tests headless** (les 13 scénarios réseau, le relais de latence). Jamais choisi dans l'export Web. Le « code » y est `ip:port`. | `Transport` |
| `EcranEnLigne` (remplace `EcranReseau`) | Pseudo (mémorisé dans `Scores`), *Créer une partie* (absent sur mobile), *Rejoindre* avec un champ de code (pré-rempli par `?salle=`), messages d'erreur (§9). Le salon de l'hôte affiche le code et *Copier le lien*. Le code (`CodeSalle`) : un code de salle sur le Web ; l'adresse `ip:port` d'un hôte `TransportENet` sur le desktop de développement. Passe par `Reseau.creer_partie()` et `Reseau.rejoindre_partie(code)`, qui choisissent le transport. | `Reseau`, `CodeSalle` |
| `signalisation/` (Worker + Durable Object `Salle`, JavaScript) | Crée les salles, relaie offres, réponses et candidats entre l'hôte et chaque arrivant, fournit les identifiants TURN, applique les plafonds (§8). Ne lit pas le contenu WebRTC. Six modules (`index`, `origine`, `code`, `protocole`, `ice`, `salle`, environ 440 lignes), avec ses tests `vitest` dans l'environnement local de Cloudflare (`@cloudflare/vitest-plugin`). | API TURN de Cloudflare |

Le choix du transport : `TransportWebRTC` quand `OS.has_feature("web")`, `TransportENet` sinon (ou
```

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

```
`?salle=K7Q2XM` est lu au démarrage par `JavaScriptBridge` (`location.search`). S'il est présent et
valide, le jeu ouvre l'écran En ligne sur *Rejoindre*, code rempli ; il ne rejoint qu'après le pseudo
validé. *Copier le lien* passe par `DisplayServer.clipboard_set` (sur le Web, l'API du presse-papiers,
qui exige le geste du clic : le bouton le fournit).

## 5. En jeu

```

par :

```
`?salle=K7Q2XM` est lu au démarrage par `JavaScriptBridge` (`location.search`). S'il est présent et
valide, le jeu ouvre l'écran En ligne sur *Rejoindre*, code rempli ; il ne rejoint qu'après le pseudo
validé. *Copier le lien* passe par `DisplayServer.clipboard_set` (sur le Web, l'API du presse-papiers,
qui exige le geste du clic : le bouton le fournit). Le lien part de l'adresse de la page ouverte
(origine et chemin, sans paramètres : `https://w3cdotorg.github.io/LeLion-web/` une fois publiée), ou,
hors du Web, du réglage de projet `lelion/page/url`. Le lien ne sert qu'une fois par lancement (un
retour au titre ne rouvre pas l'écran En ligne).

## 5. En jeu

```

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

```

| Situation | Comportement |
|---|---|
| Code mal formé | Refusé à la saisie : « Un code fait 6 caractères (ex. K7Q-2XM). » |
| Code inconnu, salle fermée | « Aucune partie avec ce code. » |
| Worker injoignable (5 s) | « Service de connexion indisponible, réessaie dans un instant. » |
| Origine refusée, débit dépassé | « Service de connexion indisponible, réessaie dans un instant. » (journal : raison exacte) |
```

par :

```

| Situation | Comportement |
|---|---|
| Code mal formé | Refusé à la saisie : « Un code fait 6 caractères (ex. K7Q-2XM). » ; un 0, O, 1, I ou L, jamais remplacé en silence : « Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM). » |
| Code inconnu, salle fermée | « Aucune partie avec ce code. » |
| Worker injoignable (5 s) | « Service de connexion indisponible, réessaie dans un instant. » |
| Origine refusée, débit dépassé | « Service de connexion indisponible, réessaie dans un instant. » (journal : raison exacte) |
```

- [ ] **Step 2 : le README**

Dans `README.md`, remplacer :

```
Until online play lands, run the game from the editor (`godot .`) on each computer of the same
local network: games are found automatically (UDP broadcast) or joined by the host's IP address.
```

par :

```
Until online play lands (in the browser, by room code or invitation link), run the game from the
editor (`godot .`) on each computer: **Multiplayer** opens the Online screen, where one player
creates a game and the others join it with the host's address as the code (`192.168.1.20:7777`).
```

Dans `README.md`, remplacer :

```
            Resultats (battle results), EcranReseau (network screen), Salon (lobby), PauseMenu, Reglages (settings),
```

par :

```
            Resultats (battle results), EcranEnLigne (online screen), Salon (lobby), PauseMenu, Reglages (settings),
```

Dans `README.md`, remplacer :

```
godot --headless --script tests/smoke_test.gd                      # solo game, title, network screen, lobby, a networked round
```

par :

```
godot --headless --script tests/smoke_test.gd                      # solo game, title, online screen, lobby, a networked round
```

- [ ] **Step 3 : la vérification passe**

```bash
S=docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
grep -c "Reseau.rejoindre_partie(code)" $S; grep -c "lelion/page/url" $S; grep -c "ni 0, ni O, ni 1" $S; grep -c "EcranEnLigne (online screen)" README.md; grep -c "UDP broadcast" README.md
```

Expected : `1`, `1`, `1`, `1`, `0`.

- [ ] **Step 4 : Commit**

```bash
git add docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md README.md
git commit -m "Spec : l'écran En ligne tel que la phase 3 l'a fait (CodeSalle, creer_partie et rejoindre_partie, ip:port sur le desktop, le code au salon de l'hôte), le lien depuis la page ou lelion/page/url et lu une fois, le message des caractères qu'on confond ; README : l'écran En ligne

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 7 : vérification commune, contrôle visuel ◉, feuille de route, PR et fusion de la phase 3

**Files:**
- Modify: `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md:49` (ligne 3 : fichiers réels, « Faite (PR #N) »)

**Interfaces:** aucune.

- [ ] **Step 1 : la vérification commune (feuille de route), sans relance**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|PROTOCOLE|== " "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd > "$TMPDIR/b.log" 2>&1; echo "bataille $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/b.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "banc $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/p.log"
SECONDS=0; DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== |\(I1\)|départ arraché|\(départs\)" "$TMPDIR/r.log"
(cd signalisation && npm test 2>&1 | tail -4)
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/dc.log" 2>&1 &
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/dh.log" 2>&1; echo "deux fenêtres hôte $?"; wait; grep -c "📸" "$TMPDIR/dh.log" "$TMPDIR/dc.log"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/dh.log" "$TMPDIR/dc.log"
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh
git status --short
```

Expected : pas de « ÉCHEC COMPILATION » ; chaque suite Godot sort en 0 sur `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR` ; `PROTOCOLE 0.20 815376087 (68 lignes)` ; (vu une fois sur cinq en appliquant ce plan : l'unitaire de la phase 1 « un battement par seconde » à 1 504 ms pour une borne de 1 500, vert aux quatre autres passages ; s'il revient, le relancer une fois et le signaler dans la PR, sans toucher à sa borne ici) ; réseau en 170 à 185 s (moins de 300 s) avec ses trois mesures ; les tests du Worker verts ; 38 📸 pour les captures, 5 et 6 pour les deux fenêtres ; rien au `perl` ; `git status` propre. Un échec : le corriger dans la tâche qu'il concerne (commit à part), puis tout relancer.

- [ ] **Step 2 : le contrôle visuel ◉ (vrai rendu, sur ce Mac)**

```bash
V="$TMPDIR/captures-phase3"; rm -rf "$V"; mkdir -p "$V"
timeout 180 godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier="$V" --parties=reseau,salon 2>&1 | grep -c "📸"
timeout 120 godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier="$V" > /dev/null 2>&1 &
timeout 120 godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier="$V" 2>&1 | grep -c "📸"; wait
ls "$V"/*.png
```

Expected : `19` (11 `reseau_*`, 8 `salon_*`), puis `5` ; 30 PNG. Les regarder (outil Read) et les lister au contrôleur, au moins `reseau_02_accueil.png` (titre « En ligne », pseudo, *Créer une partie*, « ou rejoins une partie avec son code », le champ du code avec « K7Q-2XM » en exemple, *Rejoindre*), `reseau_04_code_confusion.png` (le message saumon « Un code n'a ni 0, ni O, ni 1, ni I, ni L (ex. K7Q-2XM). », le focus sur le code), `reseau_08_lien.png` (« K7Q-2XM » rempli, *Rejoindre* au focus, « Invitation reçue : choisis ton pseudo, puis Rejoindre. »), `reseau_09_connexion_desktop.png` (tout grisé sauf Retour, « Connexion à 127.0.0.1:17891… »), `salon_00_hote_seul.png` (« Code de la partie : K7Q-2XM » en jaune et *Copier le lien* sous l'aide, dans l'écran, sans chevaucher) et `hote_0_salon.png` (« Code de la partie : 127.0.0.1:17990 », sans bouton). Un défaut visuel : le corriger dans la tâche concernée, puis tout relancer.

- [ ] **Step 3 : la branche poussée, la PR ouverte** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
git push -u origin phase-03-ecran-en-ligne
cat > "$TMPDIR/pr.md" <<'EOF'
Phase 3 de la feuille de route du jeu en ligne : l'écran En ligne remplace l'écran Réseau.

- `Scripts/CodeSalle.gd` : le code de salle (alphabet du Worker sans 0/O ni 1/I/L, saisie sans casse ni espaces ni tirets, un caractère qu'on confond refusé avec son message, `K7Q-2XM`, lien d'invitation, `?salle=` lu une fois par lancement).
- `Scenes/EcranEnLigne.tscn` + `Scripts/EcranEnLigne.gd` : pseudo, *Créer une partie*, *Rejoindre* avec un code (sur le desktop de développement : l'adresse `ip:port` d'un hôte ENet), les messages du §9 par raison d'échec ; dans l'export Web, jusqu'au WebRTC de la phase 4, il dit « Pas encore de jeu en ligne dans cette version » sans rien ouvrir.
- `Reseau` : `creer_partie()` et `rejoindre_partie(code)` (où la phase 4 branchera `TransportWebRTC`), `raison_echec` ; `Transport` : les raisons de la signalisation.
- Salon : le code de la partie et *Copier le lien* chez l'hôte, à la place de ses adresses LAN ; retour à l'écran En ligne.
- Le titre, le test réseau, les deux fenêtres et les captures passent par l'écran En ligne (38 captures). L'écran Réseau et la découverte partent en phase 3 bis (PR suivante).

Tests : unitaires (code de salle, alphabet recoupé avec le Worker ; entrées de `Reseau`), smoke (écran En ligne, lien `?salle=`, salon), les scénarios réseau verts.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
gh pr create --repo w3cdotorg/LeLion-web --base main --head phase-03-ecran-en-ligne --title "Phase 3 : écran En ligne" --body-file "$TMPDIR/pr.md"
N=$(gh pr view --repo w3cdotorg/LeLion-web phase-03-ecran-en-ligne --json number -q .number); echo "PR #$N"
```

Ajouter au corps de la PR, avant la dernière ligne, les mesures de la Task 0 et du Step 1, et la liste des captures du Step 2 (`gh pr edit --repo w3cdotorg/LeLion-web "$N" --body-file "$TMPDIR/pr.md"` après les avoir écrites dans le fichier).

- [ ] **Step 4 : la feuille de route**

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

```
| ➕ `Scripts/CodeSalle.gd` ➕ `Scenes/EcranEnLigne.tscn` ➕ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `Assets/Traductions/traductions.csv` | Parcours Titre → En ligne → Salon en ENet ; unitaires du code de salle. |
```

par (`NUMERO` est le numéro de la PR, `$N` du Step 3) :

```
| ➕ `Scripts/CodeSalle.gd` ➕ `Scenes/EcranEnLigne.tscn` ➕ `Scripts/EcranEnLigne.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scenes/Salon.tscn` ✏️ `Scripts/Titre.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Transport.gd` ✏️ `project.godot` ✏️ `Assets/Traductions/traductions.csv` ✏️ tests (`unitaires`, `smoke_test`, `screenshots`, `deux_fenetres`, `reseau/`) ✏️ `.github/workflows/ci.yml` ✏️ spec ✏️ `README.md` | Parcours Titre → En ligne → Salon en ENet ; unitaires du code de salle. Faite (PR #NUMERO). |
```

puis :

```bash
perl -pi -e "s/PR #NUMERO/PR #$N/" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
grep -c "Faite (PR #$N)" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git add docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git commit -m "Feuille de route : phase 3 faite (PR #$N)

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

Expected : la CI verte (le pas « Captures » compte 38 📸 ; le pas « Test réseau » sous ses 300 s) ; la fusion faite, `main` à jour. La CI rouge : ne pas fusionner, diagnostiquer. **Fin de la phase 3 : attendre la validation de l'utilisateur avant la 3 bis** (`CLAUDE.md`), sauf accord contraire.

---

### Task 8 : préparation de la 3 bis

**Files:** aucun (vérifications seulement).

**Interfaces:** aucune.

- [ ] **Step 1 : la branche**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
git switch main && git pull --ff-only
git log --oneline main | grep -m1 "phase-03-ecran-en-ligne" || echo "PHASE 3 ABSENTE"
git switch -c phase-03bis-retrait-decouverte
grep -rln "Decouverte\|EcranReseau\|DIFFUSION" Scripts Scenes tests project.godot .github README.md | sort
```

Expected : la fusion de la PR de la phase 3 ; les fichiers qui nomment encore la découverte ou l'écran Réseau : `.github/workflows/ci.yml`, `README.md`, `Scenes/EcranReseau.tscn`, `Scripts/Decouverte.gd`, `Scripts/EcranReseau.gd`, `Scripts/Salon.gd`, `project.godot`, `tests/deux_fenetres.gd`, `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`, `tests/screenshots.gd`, `tests/smoke_test.gd`, `tests/unitaires.gd`. Une autre liste : s'arrêter et le signaler.

---

### Task 9 : l'écran Réseau part

**Files:**
- Delete: `Scripts/EcranReseau.gd` (+ `.uid`), `Scenes/EcranReseau.tscn`
- Modify: `tests/smoke_test.gd` (l'appel et la fonction `_tester_ecran_reseau`)
- Modify: `Assets/Traductions/traductions.csv` (les 11 clés de l'écran Réseau seul) (+ `.translation`)
- Modify: `Scripts/Regles.gd:47` (un commentaire)

**Interfaces:** aucune (rien ne nommait plus l'écran Réseau depuis la phase 3, hors son test).

- [ ] **Step 1 : les suppressions**

Exécuter (modification mécanique) :

```bash
git rm -q Scripts/EcranReseau.gd Scripts/EcranReseau.gd.uid Scenes/EcranReseau.tscn
python3 - <<'EOF'
p = "tests/smoke_test.gd"
s = open(p).read()
appel = "\tawait _tester_ecran_reseau(scores, params)\n"
assert s.count(appel) == 1
s = s.replace(appel, "")
debut = s.index("## Phase 12 bis : l'écran Réseau (liste, IP, refus, échecs, hébergement, port occupé, clavier). Les\n")
fin = s.index("## Phase 3 du jeu en ligne : l'écran En ligne (pseudo, Créer une partie, Rejoindre avec un code de salle\n")
s = s[:debut] + s[fin:]
open(p, "w").write(s)
p = "Assets/Traductions/traductions.csv"
lignes = open(p).read().split("\n")
retirees = ["RESEAU_HEBERGER", "RESEAU_PARTIES", "RESEAU_AUCUNE_PARTIE", "RESEAU_ECOUTE_IMPOSSIBLE", "RESEAU_PARTIE",
	"RESEAU_PARTIE_PLEINE", "RESEAU_PARTIE_MANCHE", "RESEAU_PARTIE_VERSION", "RESEAU_ADRESSE_IP", "RESEAU_IP_INVALIDE",
	"RESEAU_ECHEC_CONNEXION"]
gardees = [l for l in lignes if l.split(",", 1)[0] not in retirees]
assert len(lignes) - len(gardees) == len(retirees)
open(p, "w").write("\n".join(gardees))
EOF
```

Dans `Scripts/Regles.gd`, remplacer :

```gdscript

## Met l'écran à `taille` (`content_scale_size`, spec §7) et, dans une fenêtre (ni plein écran, ni
## maximisée, ni headless) : quand l'écran change de format, règle la hauteur de la fenêtre sur le
## nouveau format en gardant sa largeur (hors du solo, écran Réseau, salon, bataille en 16:9, l'écran ne
## s'affiche plus avec des bandes dans la fenêtre du solo : 1400×454 devient 1400×788, et le titre la
## rend au solo) ; puis, toujours, la garde dans la zone utile de son écran (M7 de la revue finale 14 :
## sans la barre des tâches, barre de titre comprise), réduite au même format et recentrée au besoin (une
```

par :

```gdscript

## Met l'écran à `taille` (`content_scale_size`, spec §7) et, dans une fenêtre (ni plein écran, ni
## maximisée, ni headless) : quand l'écran change de format, règle la hauteur de la fenêtre sur le
## nouveau format en gardant sa largeur (hors du solo, écran En ligne, salon, bataille en 16:9, l'écran ne
## s'affiche plus avec des bandes dans la fenêtre du solo : 1400×454 devient 1400×788, et le titre la
## rend au solo) ; puis, toujours, la garde dans la zone utile de son écran (M7 de la revue finale 14 :
## sans la barre des tâches, barre de titre comprise), réduite au même format et recentrée au besoin (une
```

- [ ] **Step 2 : la vérification passe**

```bash
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
grep -rn "EcranReseau\|_tester_ecran_reseau\|RESEAU_HEBERGER\b\|RESEAU_PARTIE\|RESEAU_AUCUNE\|RESEAU_ECOUTE\|RESEAU_ADRESSE_IP\|RESEAU_IP_INVALIDE\|RESEAU_ECHEC_CONNEXION" Scripts Scenes tests Assets/Traductions/traductions.csv
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"
```

Expected : rien à l'import ; au `grep`, seulement les commentaires qu'enlèvent les Tasks 10 à 12 (`Scripts/Reseau.gd:69`, `Scripts/Decouverte.gd`, `tests/reseau/joueur.gd`, `tests/smoke_test.gd` « l'écran Réseau ouvert ici écoute ») : aucune ligne `EcranReseau`, aucune clé ; smoke `0`, `== 0 échec(s) ==`.

- [ ] **Step 3 : Commit**

```bash
git add -A Scripts/EcranReseau.gd Scripts/EcranReseau.gd.uid Scenes/EcranReseau.tscn tests/smoke_test.gd Assets/Traductions/ Scripts/Regles.gd
git commit -m "Retrait de l'écran Réseau du LAN (liste des parties, saisie d'IP), de son smoke test et de ses 11 clés de traduction : l'écran En ligne l'a remplacé en phase 3

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 10 : le test réseau sans la découverte

**Files:**
- Modify: `tests/reseau/joueur.gd` (en-tête, le rôle `ecouteur` et `_jouer_ecouteur`, `_cle_partie`, `decouverte`, `--port-balise`, `--diffusion`, `--apres-depart`)
- Modify: `tests/reseau/lancer.sh` (en-tête, scénarios 6 et 7, `B=` et `--port-balise=$B`)
- Modify: `.github/workflows/ci.yml` (le pas « Test réseau » sans `DIFFUSION=1`)

**Interfaces:** `joueur.gd` n'a plus de rôle `ecouteur` ni d'option `--port-balise`, `--diffusion`, `--apres-depart` ; les autres scénarios gardent leur numéro et leurs ports.

- [ ] **Step 1 : les suppressions**

Exécuter (modification mécanique) :

```bash
python3 - <<'EOF'
p = "tests/reseau/joueur.gd"
s = open(p).read()
def remplacer(avant, apres):
	global s
	assert s.count(avant) == 1, avant[:80]
	s = s.replace(avant, apres)
remplacer("""## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet, bout-hote, bout-client, latence-hote, latence-client, chrono-hote, chrono-client.
## Communes : --port=N (défaut 17777), --pseudo=texte, --port-balise=N (port des balises de
##   découverte, émises par un hôte et écoutées par un écouteur ; défaut : --port + 1000),
##   --diffusion (balises en vraie diffusion, comme en jeu ; sans elle, vers 127.0.0.1 seulement).
""", """## Rôles : hote, client, lent, salon-hote, salon-client, manche-hote, manche-client, manche-muet,
## bout-hote, bout-client, latence-hote, latence-client, chrono-hote, chrono-client.
## Communes : --port=N (défaut 17777), --pseudo=texte.
""")
remplacer("""##   plus), --apres-depart=S (le processus vit encore S secondes après avoir quitté le réseau : sa
##   balise doit s'arrêter d'elle-même, pas avec le processus). Écrit « HOTE PRET » quand il écoute
""", """##   plus). Écrit « HOTE PRET » quand il écoute
""")
debut = s.index("## Écouteur (phase 12) : écoute les balises (`Decouverte`)")
fin = s.index("## Salon (phase 13), par les vraies scènes : l'écran En ligne")
s = s[:debut] + s[fin:]
remplacer("""## `Reseau`, `Decouverte`, `GameState` et `Scores` par `root.get_node`, ne nomme ni `Reseau`, ni
## `Decouverte`, ni `GameState`, ni le salon (il peut nommer `EtatPartie`, dont le script ne nomme
""", """## `Reseau`, `GameState` et `Scores` par `root.get_node`, ne nomme ni `Reseau`, ni `GameState`, ni le
## salon (il peut nommer `EtatPartie`, dont le script ne nomme
""")
remplacer("var reseau: Node\nvar decouverte: Node\n", "var reseau: Node\n")
remplacer("""	reseau = root.get_node("Reseau")
	decouverte = root.get_node("Decouverte")
	reseau.pseudo = _option("pseudo", "Poste")
	# Chaque hôte émet sa balise (elle suit l'état de Reseau) : vers un port de test propre au
	# scénario, et vers localhost seulement, sauf --diffusion (jamais le 7778 d'une vraie partie).
	decouverte.port_balise = int(_option("port-balise", str(int(_option("port", "17777")) + 1000)))
	if not _options.has("diffusion"):
		decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
""", """	reseau = root.get_node("Reseau")
	reseau.pseudo = _option("pseudo", "Poste")
""")
remplacer("""	elif role == "ecouteur":
		await _jouer_ecouteur()
""", "")
remplacer("""		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client, manche-muet, bout-hote, bout-client, latence-hote, latence-client, chrono-hote ou chrono-client")""",
	"""		_check(false, "rôle inconnu : --role=hote, client, lent, salon-hote, salon-client, manche-hote, manche-client, manche-muet, bout-hote, bout-client, latence-hote, latence-client, chrono-hote ou chrono-client")""")
remplacer("""		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1
		and not decouverte.ecoute_active(),
		"à la fin, le poste est revenu hors réseau (pair hors ligne, hôte de lui-même, plus d'inscrits ni d'écoute)")""",
	"""		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1,
		"à la fin, le poste est revenu hors réseau (pair hors ligne, hôte de lui-même, plus d'inscrits)")""")
remplacer("""	reseau.quitter()  # son départ s'achève en arrière-plan : `_run` l'attend avant de sortir
	if _options.has("apres-depart"):
		# Le processus vit encore : si la balise ne suivait pas l'état de Reseau, elle continuerait.
		await _pause(float(_option("apres-depart", "0")))
""", """	reseau.quitter()  # son départ s'achève en arrière-plan : `_run` l'attend avant de sortir
""")
debut = s.index("## Rôle de test « écouteur » (phase 12)")
fin = s.index("## Rôles « salon-hote » et « salon-client » (phase 13, voir l'en-tête)")
s = s[:debut] + s[fin:]
remplacer("""	_check(gs.niveau_courant == niveau, "le niveau choisi au salon devient celui de la partie (%d), que la balise annonce" % niveau)""",
	"""	_check(gs.niveau_courant == niveau, "le niveau choisi au salon devient celui de la partie (%d)" % niveau)""")
debut = s.index("## La clé (« ip:port ») d'une partie de la liste dont l'hôte a ce pseudo")
fin = s.index("func _sur_arrivee(id: int) -> void:")
s = s[:debut] + s[fin:]
open(p, "w").write(s)

p = "tests/reseau/lancer.sh"
s = open(p).read()
remplacer("""# Test réseau du transport (phase 11), de la découverte (phase 12), du salon (phase 13), de la
""", """# Test réseau du transport (phase 11), du salon (phase 13), de la
""")
remplacer("""# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie)
# et, pour les balises de découverte, port_de_base + 1000 + n (jamais le 7778) ; le relais du
# scénario n (12, 13) écoute sur port_de_base + 2000 + n.
""", """# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie) ;
# le relais du scénario n (12, 13) écoute sur port_de_base + 2000 + n. Les scénarios 6 et 7 (la
# découverte des parties sur le réseau local) sont partis avec elle (phase 3 bis du jeu en ligne) :
# les autres gardent leur numéro, et leurs ports.
""")
remplacer("""# DUREE13B + 60),
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion ; le pas « Test réseau » de la CI le
# pose depuis la phase 19 ; le scénario 6 couvre le même chemin en envoi direct vers 127.0.0.1).
""", """# DUREE13B + 60).
""")
debut = s.index("# 6. Découverte (balises vers 127.0.0.1) : l'hôte émet sa balise ; un écouteur voit sa partie,\n")
fin = s.index("# 8. Salon (phase 13), par les vraies scènes : un hôte et trois clients passent par l'écran En ligne\n")
s = s[:debut] + s[fin:]
import re
avant = len(s)
s, n_options = re.subn(r" --port-balise=\$B", "", s)
s, n_ports = re.subn(r"\nB=\$\(\(PORT_BASE \+ 10[0-9][0-9]\)\)", "", s)
assert (n_options, n_ports) == (20, 6), (n_options, n_ports)
open(p, "w").write(s)

p = ".github/workflows/ci.yml"
s = open(p).read()
remplacer("""      - name: Test réseau (plusieurs processus sur localhost, dont une manche sous latence simulée et la découverte en vraie diffusion)
        shell: bash
        run: |
          set -o pipefail
          DIFFUSION=1 timeout 300 bash tests/reseau/lancer.sh 2>&1 | tee reseau.log""", """      - name: Test réseau (plusieurs processus sur localhost, dont une manche sous latence simulée)
        shell: bash
        run: |
          set -o pipefail
          timeout 300 bash tests/reseau/lancer.sh 2>&1 | tee reseau.log""")
open(p, "w").write(s)
EOF
```

- [ ] **Step 2 : le test réseau passe**

```bash
grep -n "balise\|decouverte\|Decouverte\|diffusion\|DIFFUSION\|ecouteur\|apres-depart\|\$B\b" tests/reseau/joueur.gd tests/reseau/lancer.sh .github/workflows/ci.yml
SECONDS=0; timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|== |\(I1\)|départ arraché|\(départs\)|découverte" "$TMPDIR/r.log"
```

Expected : rien au `grep` ; réseau `code 0`, `== 0 échec(s) ==`, environ 160 s (mesuré 159 s), les trois mesures, aucune ligne « découverte ».

- [ ] **Step 3 : Commit**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh .github/workflows/ci.yml
git commit -m "Test réseau : les scénarios 6 et 7 de la découverte partent (rôle ecouteur, balises, --port-balise, --diffusion, --apres-depart), les autres gardent leur numéro et leurs ports ; CI : plus de DIFFUSION=1

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 11 : les autres tests sans la découverte, l'empreinte du protocole renotée

**Files:**
- Modify: `tests/smoke_test.gd` (`_tester_titre_reseau`, `_tester_salon`, `manche_avant`)
- Modify: `tests/unitaires.gd` (`_tester_decouverte`, `_datagrammes_recus`, la ligne de la balise, `PROTOCOLE_EMPREINTE`)
- Modify: `tests/screenshots.gd` (`PORT_BALISE`, `_salon`), `tests/deux_fenetres.gd` (`PORT_BALISE`, `_run`)

**Interfaces:** `PROTOCOLE_EMPREINTE := 2553814265` (67 lignes, version 0.20 inchangée : écart 12).

- [ ] **Step 1 : les suppressions**

Exécuter (modification mécanique) :

```bash
python3 - <<'EOF'
s = ""
def remplacer(avant, apres):
	global s
	assert s.count(avant) == 1, avant[:80]
	s = s.replace(avant, apres)

p = "tests/smoke_test.gd"
s = open(p).read()
remplacer("""	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	decouverte.port_balise = 17895  # l'écran Réseau ouvert ici écoute : jamais le 7778 d'une vraie partie
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
""", """	var reseau: Node = root.get_node("Reseau")
""")
remplacer("""	# doit tourner même si cette précondition échoue (sinon un seul échec ici laisse decouverte et
	# reseau dans un état anormal pour la suite de la fonction et pour `_tester_salon`).""", """	# doit tourner même si cette précondition échoue (sinon un seul échec ici laisse reseau dans un
	# état anormal pour la suite de la fonction et pour `_tester_salon`).""")
remplacer("""			and root.content_scale_size == Vector2i(2000, 648) and not decouverte.ecoute_active() and not reseau.en_ligne(),
			"Retour ramène au titre, en 2000×648, hors réseau et sans écoute")""", """			and root.content_scale_size == Vector2i(2000, 648) and not reseau.en_ligne(),
			"Retour ramène au titre, en 2000×648, hors réseau")""")
remplacer("""		"après un hébergement, le titre remet ce poste hors réseau (plus de balise ni d'arrivée)")""", """		"après un hébergement, le titre remet ce poste hors réseau (plus d'arrivée)")""")
remplacer("""	titre.free()
	decouverte.port_balise = decouverte.PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray()
	reseau.pseudo = ""
	scores.effacer()
""", """	titre.free()
	reseau.pseudo = ""
	scores.effacer()
""")
remplacer("""	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var port_balise := 17896  # la balise de l'hôte : jamais le 7778 d'une vraie partie
	decouverte.port_balise = port_balise
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	reseau.pseudo = "MMMMMMMMMMMM"  # 12 caractères larges : ils doivent tenir dans la carte
""", """	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	reseau.pseudo = "MMMMMMMMMMMM"  # 12 caractères larges : ils doivent tenir dans la carte
""")
remplacer("""	# Niveau (l'hôte, haut/bas, en boucle) : la partie et la balise le suivent""", """	# Niveau (l'hôte, haut/bas, en boucle) : la partie le suit""")
remplacer("""	salon.changer_niveau(-1)
	var recepteur := PacketPeerUDP.new()
	_check(recepteur.bind(port_balise, "0.0.0.0") == OK, "(pré-condition) un récepteur écoute la balise de l'hôte")
	decouverte._emettre_balise()
	var balise := {}
	var fin := Time.get_ticks_msec() + 500
	while balise.is_empty() and Time.get_ticks_msec() < fin:
		if recepteur.get_available_packet_count() > 0:
			balise = decouverte.decoder_balise(recepteur.get_packet())
		else:
			OS.delay_msec(5)
	recepteur.close()
	_check(balise.get("niveau") == 2 and balise.get("nb_joueurs") == 1 and balise.get("manche_en_cours") == false,
		"la balise de l'hôte annonce le niveau choisi au salon (%s)" % [balise])
""", """	salon.changer_niveau(-1)
""")
remplacer("""	decouverte.port_balise = decouverte.PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray()
	reseau.pseudo = ""
	GS.niveau_courant = 0
""", """	reseau.pseudo = ""
	GS.niveau_courant = 0
""")
import re
s, n = re.subn(r"\bbalise_manche\b", "manche_avant", s)
assert n == 2, n
open(p, "w").write(s)

p = "tests/unitaires.gd"
s = open(p).read()
remplacer("\t_tester_decouverte()\n", "")
debut = s.index("func _tester_decouverte() -> void:\n")
fin = s.index("## Phase 13 : la bataille configurée par les fiches du salon")
s = s[:debut] + s[fin:]
remplacer("""## protocole, présentée à la poignée de main et dans la balise ; deux postes de versions différentes se""",
	"""## protocole, présentée à la poignée de main ; deux postes de versions différentes se""")
remplacer("""			"le protocole (RPC, réplication, formats réseau, balise) est celui de la version %s ; s'il a changé, augmenter application/config/version, puis noter ici la version et l'empreinte de la ligne PROTOCOLE" % version)""",
	"""			"le protocole (RPC, réplication, formats réseau) est celui de la version %s ; s'il a changé, augmenter application/config/version, puis noter ici la version et l'empreinte de la ligne PROTOCOLE" % version)""")
remplacer("""## revue finale : renommer un tel nœud ou changer son `spawn_path` doit faire échouer ce test), les
## tailles des formats réseau, et une balise de découverte.""", """## revue finale : renommer un tel nœud ou changer son `spawn_path` doit faire échouer ce test), et les
## tailles des formats réseau.""")
remplacer("""	lignes.append("balise " + load("res://Scripts/Decouverte.gd").encoder_balise("V", 1, 2, 3, true, 0, "P").get_string_from_utf8())
""", "")
remplacer("const PROTOCOLE_EMPREINTE := 815376087\n", "const PROTOCOLE_EMPREINTE := 2553814265\n")
open(p, "w").write(s)

p = "tests/screenshots.gd"
s = open(p).read()
remplacer("""## N'utilise ni le port 7777 ni le 7778 d'une vraie partie, ni les records et réglages du joueur""", """## N'utilise ni le port 7777 d'une vraie partie, ni les records et réglages du joueur""")
remplacer("const PORT_SANS_HOTE := 17891\nconst PORT_BALISE := 17899\n", "const PORT_SANS_HOTE := 17891\n")
remplacer("""	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	decouverte.port_balise = PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	GS.niveau_courant = 1
""", """	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	GS.niveau_courant = 1
""")
open(p, "w").write(s)

p = "tests/deux_fenetres.gd"
s = open(p).read()
remplacer("""## se vérifie, rien n'est écrit. N'utilise ni le port 7777 ni le 7778 d'une vraie partie, ni les records""", """## se vérifie, rien n'est écrit. N'utilise ni le port 7777 d'une vraie partie, ni les records""")
remplacer("const PORT := 17990\nconst PORT_BALISE := 18990\n", "const PORT := 17990\n")
remplacer("""	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var scores: Node = root.get_node("Scores")""", """	var reseau: Node = root.get_node("Reseau")
	var scores: Node = root.get_node("Scores")""")
remplacer("""	root.get_node("Parametres").definir_langue("fr")
	decouverte.port_balise = PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	ReglesBataille.duree_manche = DUREE_MANCHE""", """	root.get_node("Parametres").definir_langue("fr")
	ReglesBataille.duree_manche = DUREE_MANCHE""")
open(p, "w").write(s)
EOF
```

- [ ] **Step 2 : les suites passent**

```bash
grep -rn "decouverte\|Decouverte\|balise\|7778\|PORT_BALISE" tests/*.gd
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|PROTOCOLE|== " "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/s.log"
D="$(mktemp -d)"; timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c.log" 2>&1; echo "captures $? : $(grep -c '📸' "$TMPDIR/c.log") 📸"; grep -E "❌|SCRIPT ERROR" "$TMPDIR/c.log"
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/dc.log" 2>&1 &
timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/dh.log" 2>&1; echo "deux fenêtres hôte $?"; wait; grep -c "📸" "$TMPDIR/dh.log" "$TMPDIR/dc.log"
```

Expected : rien au `grep` ; unitaires `0`, `PROTOCOLE 0.20 2553814265 (67 lignes)`, `== 0 échec(s) ==` ; smoke `0`, `== 0 échec(s) ==` ; `captures 0 : 38 📸` ; `deux fenêtres hôte 0`, 5 et 6 📸. Une autre empreinte : un écart avec le code du plan (le retrouver avant de la noter).

- [ ] **Step 3 : Commit**

```bash
git add tests/smoke_test.gd tests/unitaires.gd tests/screenshots.gd tests/deux_fenetres.gd
git commit -m "Tests : plus rien de la découverte (balise du salon, ports de balises, unitaires de Decouverte) ; l'empreinte du protocole renotée sans la ligne de la balise (version 0.20 inchangée : ce que deux postes se disent ne change pas)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 12 : `Decouverte` part

**Files:**
- Delete: `Scripts/Decouverte.gd` (+ `.uid`)
- Modify: `project.godot` (l'autoload)
- Modify: `Scripts/Salon.gd`, `Scripts/Titre.gd`, `Scripts/Reseau.gd` (des commentaires)
- Modify: `README.md` (`Scripts/`, la ligne du test réseau)

**Interfaces:** plus d'autoload `Decouverte`.

- [ ] **Step 1 : les suppressions**

Exécuter (modification mécanique) :

```bash
git rm -q Scripts/Decouverte.gd Scripts/Decouverte.gd.uid
python3 - <<'EOF'
s = ""
def remplacer(avant, apres):
	global s
	assert s.count(avant) == 1, avant[:80]
	s = s.replace(avant, apres)

p = "project.godot"
s = open(p).read()
remplacer('Reseau="*res://Scripts/Reseau.gd"\nDecouverte="*res://Scripts/Decouverte.gd"\n', 'Reseau="*res://Scripts/Reseau.gd"\n')
open(p, "w").write(s)

p = "Scripts/Salon.gd"
s = open(p).read()
remplacer("""## Le niveau du salon devient celui de la partie : la balise de l'hôte l'annonce (`Decouverte` lit
## `GameState.niveau_courant`), et chaque poste chargera ce niveau. Pas pendant un lancement déjà""", """## Le niveau du salon devient celui de la partie : chaque poste chargera ce niveau. Pas pendant un
## lancement déjà""")
open(p, "w").write(s)

p = "Scripts/Titre.gd"
s = open(p).read()
remplacer("""	# inertes), et un ancien hôte émettrait encore sa balise et accepterait des joueurs.""", """	# inertes), et un ancien hôte accepterait encore des joueurs.""")
open(p, "w").write(s)

p = "Scripts/Reseau.gd"
s = open(p).read()
remplacer("""## Chez le client : l'hôte a refusé ; `raison` est une des constantes REFUS_* (clé de traduction
## pour l'écran Réseau de la phase 12), `version_hote` la version de l'hôte. Le poste est déjà""", """## Chez le client : l'hôte a refusé ; `raison` est une des constantes REFUS_* (clé de traduction
## pour l'écran En ligne), `version_hote` la version de l'hôte. Le poste est déjà""")
remplacer("""## cours (les arrivées sont de nouveau acceptées, la balise l'annonce), personne n'est prêt, le""", """## cours (les arrivées sont de nouveau acceptées), personne n'est prêt, le""")
remplacer("""## (`manche_en_cours`, que la balise annonce), index compactés sur 0..n-1 (des départs ont pu""", """## (`manche_en_cours`), index compactés sur 0..n-1 (des départs ont pu""")
remplacer("""## arrivées de nouveau acceptées et annoncées par la balise, personne prêt, la table diffusée), puis""", """## arrivées de nouveau acceptées, personne prêt, la table diffusée), puis""")
open(p, "w").write(s)

p = "README.md"
s = open(p).read()
remplacer("""            (records, preferences), Parametres (settings, CRT layer), Audio (sounds, layered music), Reseau (ENet
            transport, handshake, lobby table) and Decouverte (UDP game announcements); Manche (a networked round);""",
	"""            (records, preferences), Parametres (settings, CRT layer), Audio (sounds, layered music) and Reseau
            (handshake, lobby table, heartbeat); Transport and TransportENet (the network channels); CodeSalle
            (room codes, invitation link); Manche (a networked round);""")
remplacer("""bash tests/reseau/lancer.sh                                        # headless Godot processes on localhost; DIFFUSION=1 adds real broadcast""",
	"""bash tests/reseau/lancer.sh                                        # headless Godot processes on localhost (ENet)""")
open(p, "w").write(s)
EOF
```

- [ ] **Step 2 : plus aucune référence**

```bash
rm -f .godot/global_script_class_cache.cfg
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
grep -rn "Decouverte\|decouverte\|DIFFUSION\|EcranReseau\|port_balise\|PORT_BALISE\|écran Réseau" Scripts tests Scenes project.godot .github README.md; echo "grep $?"
grep -rn "balise\|7778" Scripts tests Scenes README.md .github; echo "grep $?"
```

Expected : rien à l'import ; `grep 1` deux fois (aucune ligne).

- [ ] **Step 3 : Commit**

```bash
git add -A Scripts/Decouverte.gd Scripts/Decouverte.gd.uid project.godot Scripts/Salon.gd Scripts/Titre.gd Scripts/Reseau.gd README.md
git commit -m "Retrait de Decouverte (balises UDP 7778) et de son autoload ; commentaires et README sans la découverte

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 13 : spec, vérification commune, feuille de route, PR et fusion de la 3 bis

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§3.1 ligne `TransportENet`, §10 « Conservés »)
- Modify: `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md:50` (ligne 3 bis)

**Interfaces:** aucune.

- [ ] **Step 1 : la spec**

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

```
(les 13 scénarios réseau, le relais de latence)
```

par :

```
(le test réseau, le relais de latence)
```

Dans `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md`, remplacer :

```
  (profil mobile en plus), le test réseau (13 scénarios, sur `TransportENet`, relais de latence
  compris, découverte retirée), `trace_lions.gd`, `screenshots.gd` (écran En ligne, salon avec code,
```

par :

```
  (profil mobile en plus), le test réseau (11 scénarios, numérotés 1 à 5 et 8 à 13 : les 6 et 7 de
  la découverte retirés en phase 3 bis ; sur `TransportENet`, relais de latence compris),
  `trace_lions.gd`, `screenshots.gd` (écran En ligne, salon avec code,
```

```bash
git add docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
git commit -m "Spec : le test réseau sans les scénarios de la découverte (11 scénarios, numéros gardés)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

- [ ] **Step 2 : la vérification commune, sans relance**

Les commandes du Step 1 de la Task 7, avec `timeout -k 5 300 bash tests/reseau/lancer.sh` **sans** `DIFFUSION=1`, puis :

```bash
grep -rn "Decouverte\|DIFFUSION\|EcranReseau" Scripts tests Scenes project.godot .github README.md; echo "grep $?"
```

Expected : comme à la Task 7, sauf `PROTOCOLE 0.20 2553814265 (67 lignes)` et le réseau en 155 à 170 s (deux scénarios de moins) ; 38 📸, 5 et 6 ; `grep 1`.

- [ ] **Step 3 : le contrôle visuel**

Le Step 2 de la Task 7 (même commande, `V="$TMPDIR/captures-phase3bis"`) : les mêmes 19 et 5 captures, identiques à l'œil à celles de la phase 3 (la 3 bis ne touche aucun écran) ; regarder `salon_00_hote_seul.png` et `hote_0_salon.png`.

- [ ] **Step 4 : la branche poussée, la PR ouverte** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
git push -u origin phase-03bis-retrait-decouverte
cat > "$TMPDIR/pr.md" <<'EOF'
Phase 3 bis de la feuille de route du jeu en ligne : la découverte LAN part.

- `Scripts/Decouverte.gd` (balises UDP 7778) et son autoload, `Scripts/EcranReseau.gd` et `Scenes/EcranReseau.tscn` (liste des parties, saisie d'IP), leurs tests et leurs clés de traduction.
- Test réseau : les scénarios 6 et 7 partent, les autres gardent leur numéro et leurs ports ; la CI ne pose plus `DIFFUSION=1`.
- L'empreinte du protocole renotée sans la ligne de la balise (version 0.20 inchangée : ce que deux postes se disent ne change pas).

Plus aucune référence à `Decouverte`, `EcranReseau` ni `DIFFUSION` (`grep` vide) ; captures inchangées (38).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
gh pr create --repo w3cdotorg/LeLion-web --base main --head phase-03bis-retrait-decouverte --title "Phase 3 bis : retrait de la découverte" --body-file "$TMPDIR/pr.md"
N=$(gh pr view --repo w3cdotorg/LeLion-web phase-03bis-retrait-decouverte --json number -q .number); echo "PR #$N"
```

- [ ] **Step 5 : la feuille de route**

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

```
| ➖ `Scripts/Decouverte.gd` ➖ `Scenes/EcranReseau.tscn` ✏️ `project.godot` ✏️ tests (`smoke_test`, `screenshots`, `deux_fenetres`, `unitaires`, `reseau/`) | Plus aucune référence à `Decouverte` ; captures à jour (compte de la CI ajusté). |
```

par (`NUMERO` est le numéro de la PR, `$N` du Step 4) :

```
| ➖ `Scripts/Decouverte.gd` ➖ `Scripts/EcranReseau.gd` ➖ `Scenes/EcranReseau.tscn` ✏️ `project.godot` ✏️ `Assets/Traductions/traductions.csv` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/Titre.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Regles.gd` ✏️ tests (`smoke_test`, `screenshots`, `deux_fenetres`, `unitaires`, `reseau/`) ✏️ `.github/workflows/ci.yml` ✏️ spec ✏️ `README.md` | Plus aucune référence à `Decouverte` ; captures à jour (compte de la CI ajusté en phase 3 : 38). Faite (PR #NUMERO). |
```

puis :

```bash
perl -pi -e "s/PR #NUMERO/PR #$N/" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
grep -c "Faite (PR #$N)" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git add docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git commit -m "Feuille de route : phase 3 bis faite (PR #$N)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
git push
```

Expected : `1`.

- [ ] **Step 6 : la CI, puis la fusion** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
gh pr checks --repo w3cdotorg/LeLion-web "$N" --watch
gh pr merge --repo w3cdotorg/LeLion-web "$N" --merge
git switch main && git pull --ff-only && git log --oneline -3
```

Expected : la CI verte ; la fusion faite, `main` à jour. La CI rouge : ne pas fusionner, diagnostiquer.
