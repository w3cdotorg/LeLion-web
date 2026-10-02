# Essai réel du jeu en ligne (phase 7)

Cette fiche sert une soirée de jeu en ligne, chacun chez soi : ce qu'il faut essayer, ce qu'il faut
regarder et, pour chaque réponse, ce que la phase 7 bis changera. Rien n'y est décidé d'avance : la
prédiction a été réglée au banc (profil mobile : 150 ms, 60 ms de gigue, 8 % de pertes), les mobiles en
émulation. Cette version n'a **pas de relais TURN** (STUN seul, phase 5) : deux réseaux trop fermés ne se
relient pas, et c'est l'une des questions de la soirée (section 2). Le critère de réussite (spec §1) :
**une manche complète à au moins 3 joueurs, dont un mobile en 4G et un joueur dans un autre foyer, sans
installation ni réglage réseau.**

Comment la remplir : cocher ce qui a été essayé, entourer ou écrire la réponse, noter sur quel appareil.
Une réponse « ça va » est une vraie réponse : elle clôt la question. Renvoyer ensuite la fiche remplie,
avec les journaux de la dernière section.

Pour créer, inviter et rejoindre, suivre la section « Jouer en ligne » du `README.md`.

## Avant la soirée

- [ ] La page est publiée (phase 5) : <https://w3cdotorg.github.io/LeLion-web/> s'ouvre, déployée depuis
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
| « Connexion impossible avec l'hôte (réseau trop restrictif ?) » | Noter les deux réseaux (section 2) : sans TURN, c'est attendu sur certains réseaux ; s'ils sont nombreux, un TURN (spec §13) ; sinon, le journal de la console des deux navigateurs (`TransportWebRTC`, `DELAI_CANAL` 15 s). |
| « Service de connexion indisponible » | La console du navigateur : la raison exacte (`origine`, `debit`, Worker injoignable) ; les limites de 5 créations et 30 arrivées par minute et par IP (`signalisation/`) touchent un réseau partagé (école, entreprise). |
| L'arrivée prend plus de 10 s | Noter le réseau : les candidats ICE et le délai de 15 s (`TransportWebRTC.DELAI_CANAL`). |

## 2. Une manche, et les réseaux qui ne se relient pas

Manche 1 : au moins 3 joueurs (le téléphone en 4G et le joueur de l'autre foyer compris), niveau au choix.

- [ ] La manche va jusqu'au bout, avec l'écran Résultats chez tous : oui / non
- [ ] Son propre lion répond tout de suite : oui / non, appareil : ______
- [ ] Son propre lion paraît élastique (il glisse après l'arrêt, revient en arrière) : jamais / parfois /
  souvent, appareil : ______
- [ ] Son propre lion saute d'un coup (téléportation) : jamais / parfois / souvent
- [ ] Les autres lions bougent de façon fluide : oui / saccadés / par à-coups
- [ ] Les chocs entre lions et les étourdissements (une gerbe reçue) paraissent justes : oui / non

Pas de manche par le relais : cette version n'a pas de TURN, et `?relais=1` (qui impose le relais)
empêche alors toute connexion. À la place, pour chaque joueur qui lit « Connexion impossible avec
l'hôte » :

- [ ] Son réseau et celui de l'hôte (Wi-Fi d'une box, Wi-Fi d'entreprise ou d'école, 4G, 5G,
  opérateur) : _______________
- [ ] Il réessaie depuis un autre réseau (la 4G au lieu du Wi-Fi, ou l'inverse) : ça passe : oui / non

| Réponse | Ce que fera la phase 7 bis |
|---|---|
| Tout est fluide, y compris en 4G | Rien : `InterpolationLion.RETARD` (6 ticks) et `PredictionLocale` restent. |
| Élastique | `PredictionLocale.DUREE_CORRECTION` (0,04 s). |
| Des sauts | `PredictionLocale.SEUIL_RECALAGE` (200 px), et la console de l'appareil (un recalage est une désynchronisation). |
| Autres lions saccadés (en 4G surtout) | `InterpolationLion.RETARD` (6 ticks, 100 ms : 8 à 10 absorbent un réseau plus mauvais, au prix d'un peu de retard) ; par à-coups pendant une coupure : `InterpolationLion.EXTRAPOLATION_MAX` (3 ticks). |
| Des joueurs ne se relient pas (« Connexion impossible avec l'hôte ») | Un TURN (spec §13) : des identifiants fabriqués par le Worker (`fabriquerIce`), chez Cloudflare (TURN Cloudflare, une carte bancaire) ou un fournisseur à offre gratuite ; puis rejouer cette section avec `?relais=1`. |
| Tout le monde se relie, même en 4G | Rien : le TURN reste à faire le jour où un réseau l'exige. |

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
| La page s'est rechargée au retour (iPhone surtout) | Rien : iOS recharge parfois une page passée en arrière-plan au lieu de la rendre ; c'est une issue normale, pas un bug (le joueur rejoint de nouveau, au salon suivant). |
| Déclaré parti après 5 s de veille | `Reseau.SILENCE_SESSION` (10 s). |

## 6. Ce qu'il faut renvoyer

- Cette fiche remplie.
- Pour chaque problème : l'heure, l'appareil, et la console du navigateur (sur ordinateur : F12, onglet
  Console, clic droit, « Enregistrer sous » ; sur Android : `chrome://inspect` depuis un ordinateur ; sur
  iPhone : Safari de macOS, menu Développement). Les lignes `WARNING:` et `ERROR:` suffisent, avec celles
  de `Signalisation :`.
- Note pour l'essai : le test de bout en bout vise le stick à une place fixe (`PiloteWeb`, trois rayons du
  bord) ; s'il ne paraît pas sous le pouce ailleurs dans la moitié gauche, le dire (section 4).
