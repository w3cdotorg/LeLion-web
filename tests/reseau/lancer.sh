#!/usr/bin/env bash
# Test réseau du transport (phase 11), de la découverte (phase 12), du salon (phase 13), de la
# manche synchronisée (phase 14), de bout en bout (phase 15), de la prédiction sous latence
# simulée (phase 16), de la fin de manche au chrono (phase 17) et des manches enchaînées depuis l'écran
# Résultats (phase 18) : des postes headless sur localhost,
# un processus Godot par poste (tests/reseau/joueur.gd), et pour les scénarios 12 et 13 le simulateur de
# latence (tests/reseau/relais.gd), scénario après scénario.
#   tests/reseau/lancer.sh [port_de_base]
# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie)
# et, pour les balises de découverte, port_de_base + 1000 + n (jamais le 7778) ; le relais du
# scénario n (12, 13) écoute sur port_de_base + 2000 + n.
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40 ; les
# scénarios 11, 12 et 13, des manches jouées, ont le leur : DUREE11 + 60, DUREE12 + 50, DUREE13 +
# DUREE13B + 60),
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion ; le pas « Test réseau » de la CI le
# pose depuis la phase 19 ; le scénario 6 couvre le même chemin en envoi direct vers 127.0.0.1).
# Chaque étape s'enchaîne sur un événement observé (une ligne d'un journal, un compte de l'hôte),
# 15 s au plus (DELAI_ETAPE de joueur.gd, 150 × 0,1 s ici ; plus pour les étapes de la manche
# entière du scénario 11, qui durent ce que dure le jeu) ; seules restent, côté client
# (joueur.gd), de courtes fenêtres de vérification d'absence (1 s après un refus, 0,5 s avant un
# départ volontaire) : elles ne peuvent pas donner de faux rouge.
# Sortie 0 si chaque poste sort en 0, sans ❌ ni SCRIPT ERROR ni SHADER ERROR dans son journal, et
# si les comptes croisés entre postes tombent juste. Tous les processus lancés sont tués en sortie.
set -u
cd "$(dirname "$0")/../.." || exit 2

# N6 : sur un Mac sans coreutils dans le PATH, chaque poste sortirait en 127 (« timeout » introuvable)
# sans indice. `export PATH="/opt/homebrew/bin:$PATH"` avant de lancer ce script s'il manque.
command -v timeout >/dev/null || { echo "il faut la commande GNU 'timeout' (coreutils) dans le PATH" >&2; exit 2; }

GODOT="${GODOT:-godot}"
PORT_BASE="${1:-17777}"
DELAI="${DELAI:-40}"
JOURNAUX="$(mktemp -d "${TMPDIR:-/tmp}/lelion-reseau.XXXXXX")" || { echo "mktemp impossible (TMPDIR plein ou non inscriptible ?)" >&2; exit 2; }
# Délai de poignée de main de l'hôte du scénario 5, en secondes (Reseau.DELAI_POIGNEE_DE_MAIN, 3 s,
# reste celui du jeu). Deux marges en dépendent. Le rival doit être refusé avant qu'il expire :
# démarré d'avance, il part au feu, donné dans les 0,1 s qui suivent « ACCEPTE » (refus mesuré
# 0,07 à 0,16 s après), soit plus de 7,8 s de marge, sans démarrage de Godot dedans. L'hôte doit
# voir la coupure du lent dans son attente des poignées échouées (15 s depuis « HOTE PRET ») :
# 15 - 8 = 7 s pour démarrer le lent (mesuré 0,3 à 0,6 s). Plus long mange la seconde marge, plus
# court la première.
DELAI_POIGNEE_LENT=8
PIDS=()
NOMS=()
ECHECS=0

nettoyer() {
	local pid
	for pid in ${PIDS[@]+"${PIDS[@]}"}; do
		kill "$pid" 2>/dev/null
	done
	wait 2>/dev/null
}
trap nettoyer EXIT
# Deux pièges séparés (plutôt qu'un INT TERM commun) : TERM sort en 143, la convention, sans changer
# le 130 attendu sur INT. Les deux recopient les journaux (recopier_journaux, définie plus bas) :
# c'est le timeout 300 de la CI qui envoie TERM, et sans ça les journaux restaient dans le mktemp du
# runner, perdus.
trap 'echo "interrompu"; recopier_journaux; exit 130' INT
trap 'echo "interrompu"; recopier_journaux; exit 143' TERM

echec() {
	echo "  ❌ $1"
	ECHECS=$((ECHECS + 1))
}

# recopier_journaux : recopie chaque journal de poste dans la sortie du lanceur (JOURNAUX est gardé,
# pas supprimé). En CI, c'est tout ce qui reste d'un échec, y compris d'une interruption (INT/TERM,
# par exemple le timeout 300 du pas de CI) : appelée à la fois en sortie normale et depuis les pièges.
recopier_journaux() {
	echo "journaux gardés dans $JOURNAUX"
	for f in "$JOURNAUX"/*.log; do
		[ -e "$f" ] || continue
		echo "----- $(basename "$f")"
		cat "$f"
	done
}

# lancer <nom> <arguments de joueur.gd…> : un poste en arrière-plan, borné par timeout (TERM au
# bout de DELAI secondes, KILL 5 s plus tard s'il résiste).
lancer() {
	local nom="$1"
	shift
	timeout -k 5 "$DELAI" "$GODOT" --headless --script tests/reseau/joueur.gd -- "$@" >"$JOURNAUX/$nom.log" 2>&1 &
	PIDS+=("$!")
	NOMS+=("$nom")
}

# lancer_relais <nom> <arguments de relais.gd…> : le simulateur de latence en arrière-plan, borné
# comme un poste.
lancer_relais() {
	local nom="$1"
	shift
	timeout -k 5 "$DELAI" "$GODOT" --headless --script tests/reseau/relais.gd -- "$@" >"$JOURNAUX/$nom.log" 2>&1 &
	PIDS+=("$!")
	NOMS+=("$nom")
}

# attendre_hote <nom> : attend que l'hôte écoute (ligne « HOTE PRET »), 15 s au plus.
attendre_hote() {
	local i
	for i in $(seq 1 150); do
		grep -q "HOTE PRET" "$JOURNAUX/$1.log" 2>/dev/null && return 0
		sleep 0.1
	done
	echec "l'hôte $1 n'écoute pas"
	return 1
}

# attendre_ligne <nom> <motif> [secondes] : attend qu'une ligne contenant <motif> apparaisse dans le
# journal de <nom>, 15 s au plus par défaut (par exemple « ACCEPTE » du rôle lent, I2).
attendre_ligne() {
	local i
	for i in $(seq 1 $((${3:-15} * 10))); do
		grep -q -- "$2" "$JOURNAUX/$1.log" 2>/dev/null && return 0
		sleep 0.1
	done
	echec "« $2 » n'apparaît jamais dans le journal de $1"
	return 1
}

# attendre_fin <nom> : attend la fin d'UN poste déjà lancé, vérifie son code et son journal, et le
# retire des postes suivis (terminer() ne le revérifie donc pas). Pour choréographier un scénario où
# certains postes doivent finir avant que d'autres soient lancés (I2, scénario 5).
attendre_fin() {
	local nom="$1" i code
	for i in "${!NOMS[@]}"; do
		if [ "${NOMS[$i]}" = "$nom" ]; then
			wait "${PIDS[$i]}"
			code=$?
			if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
				echec "$nom n'a pas fini dans les $DELAI s (tué par timeout)"
			elif [ "$code" -ne 0 ]; then
				echec "$nom sort en $code"
			fi
			grep -HnE "❌|SCRIPT ERROR|SHADER ERROR|Parse Error" "$JOURNAUX/$nom.log" && echec "erreurs dans le journal de $nom"
			unset "PIDS[$i]" "NOMS[$i]"
			PIDS=(${PIDS[@]+"${PIDS[@]}"})
			NOMS=(${NOMS[@]+"${NOMS[@]}"})
			return
		fi
	done
	echec "attendre_fin : $nom introuvable parmi les postes suivis"
}

# terminer <titre> : attend chaque poste lancé, vérifie son code de sortie et son journal.
terminer() {
	local titre="$1" i code avant=$ECHECS
	for i in "${!PIDS[@]}"; do
		wait "${PIDS[$i]}"
		code=$?
		if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
			echec "$titre : ${NOMS[$i]} n'a pas fini dans les $DELAI s (tué par timeout)"
		elif [ "$code" -ne 0 ]; then
			echec "$titre : ${NOMS[$i]} sort en $code"
		fi
		if grep -HnE "❌|SCRIPT ERROR|SHADER ERROR|Parse Error" "$JOURNAUX/${NOMS[$i]}.log"; then
			echec "$titre : erreurs dans le journal de ${NOMS[$i]}"
		fi
	done
	PIDS=()
	NOMS=()
	[ "$ECHECS" -eq "$avant" ] && echo "  ✅ $titre"
}

# tuer <nom…> : arrête tout de suite les postes nommés (scénario 10, I1) au lieu d'attendre leur
# fin : on ne vérifie ni leur code de sortie ni leur journal, seulement le repère déjà mesuré avant
# l'arrêt (aucune manche n'y est jouée jusqu'au bout). SIGTERM (défaut de `kill`, comme `nettoyer`),
# puis KILL passé 0,3 s pour un muet qui dormirait encore dans son délai --figer.
tuer() {
	local nom i cibles=()
	for nom in "$@"; do
		for i in "${!NOMS[@]}"; do
			if [ "${NOMS[$i]}" = "$nom" ]; then
				cibles+=("${PIDS[$i]}")
				kill "${PIDS[$i]}" 2>/dev/null
				unset "PIDS[$i]" "NOMS[$i]"
			fi
		done
	done
	PIDS=(${PIDS[@]+"${PIDS[@]}"})
	NOMS=(${NOMS[@]+"${NOMS[@]}"})
	sleep 0.3
	for i in ${cibles[@]+"${cibles[@]}"}; do
		kill -9 "$i" 2>/dev/null
	done
	wait 2>/dev/null
}

# arracher <nom> : tue sur-le-champ (KILL) le processus Godot du poste nommé, enfant de son timeout,
# puis ce timeout : le poste n'envoie plus rien, pas même un DISCONNECT, comme un PC planté ou un
# Wi-Fi coupé (scénario 11). Comme tuer(), ni son code de sortie ni son journal ne sont vérifiés ici.
arracher() {
	local nom="$1" i
	for i in "${!NOMS[@]}"; do
		if [ "${NOMS[$i]}" = "$nom" ]; then
			pkill -KILL -P "${PIDS[$i]}" 2>/dev/null
			kill -KILL "${PIDS[$i]}" 2>/dev/null
			wait "${PIDS[$i]}" 2>/dev/null
			unset "PIDS[$i]" "NOMS[$i]"
		fi
	done
	PIDS=(${PIDS[@]+"${PIDS[@]}"})
	NOMS=(${NOMS[@]+"${NOMS[@]}"})
}

# compter <motif> <nom…> : nombre de lignes qui contiennent le motif dans les journaux nommés.
compter() {
	local motif="$1" nom total=0 n
	shift
	for nom in "$@"; do
		n=$(grep -c -- "$motif" "$JOURNAUX/$nom.log" 2>/dev/null)
		total=$((total + ${n:-0}))
	done
	echo "$total"
}

echo "== test réseau LeLion (journaux : $JOURNAUX) =="

# 1. Hôte + 2 clients ; un troisième se présente avec une autre version. L'un des deux clients
#    repart de lui-même, puis l'hôte quitte : l'autre le voit partir.
P=$((PORT_BASE + 1))
lancer hote1 --role=hote --port=$P --pseudo=Hote --clients=2 --partants=1 --refus=1
if attendre_hote hote1; then
	lancer reste1 --role=client --port=$P --pseudo=Reste --attendu=inscrit
	lancer partant1 --role=client --port=$P --pseudo=Partant --attendu=inscrit --partir
	lancer ancien1 --role=client --port=$P --pseudo=Ancien --attendu=refus_version --version=0.0-ancienne
fi
terminer "hôte + 2 clients, départ d'un client et de l'hôte, version différente refusée"

# 2. Partie à 2 places, deux demandes simultanées : exactement une acceptée, l'autre refusée. Les
#    deux rivaux démarrent, puis partent au même feu : la course ne dépend pas de leurs démarrages.
P=$((PORT_BASE + 2))
lancer hote2 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=1
if attendre_hote hote2; then
	lancer rival2a --role=client --port=$P --pseudo=RivalA --attendu=inscrit_ou_plein --feu="$JOURNAUX/feu2"
	lancer rival2b --role=client --port=$P --pseudo=RivalB --attendu=inscrit_ou_plein --feu="$JOURNAUX/feu2"
	attendre_ligne rival2a "ATTEND LE FEU" && attendre_ligne rival2b "ATTEND LE FEU" && touch "$JOURNAUX/feu2"
fi
terminer "deux demandes pour la dernière place"
[ "$(compter "RESULTAT inscrit" rival2a rival2b)" -eq 1 ] || echec "dernière place : il fallait exactement un client inscrit"
[ "$(compter "RESULTAT refus RESEAU_REFUS_PLEIN" rival2a rival2b)" -eq 1 ] || echec "dernière place : il fallait exactement un refus « plein »"

# 3. Manche en cours : tout nouveau venu est refusé.
P=$((PORT_BASE + 3))
lancer hote3 --role=hote --port=$P --pseudo=Hote --manche --refus=1
if attendre_hote hote3; then
	lancer tard3 --role=client --port=$P --pseudo=Tard --attendu=refus_manche
fi
terminer "manche en cours : arrivée refusée"

# 4. Aucun hôte sur le port : la connexion échoue après le délai.
P=$((PORT_BASE + 4))
lancer seul4 --role=client --port=$P --pseudo=Seul --attendu=echec
terminer "sans hôte : échec de connexion après le délai"

# 5. Réservation à la réponse, vrai auth_timeout (I2, Focus 2 et 5) : un client lent est accepté
#    mais ne finit jamais sa poignée de main. Pendant sa réservation (place prise dès la réponse de
#    l'hôte, avant toute arrivée), un rival est refusé « plein » sans course possible : démarré en
#    même temps que le lent, il ne part qu'au feu, donné après l'acceptation du lent (vue dans son
#    journal), bien avant la fin du délai de poignée de main de l'hôte (DELAI_POIGNEE_LENT). Ce
#    délai passé, l'hôte coupe le lent et libère sa place (vrai peer_authentication_failed, la
#    deuxième de l'hôte après le refus du rival) : un troisième client, lancé seulement alors,
#    obtient la place, à l'index 1.
P=$((PORT_BASE + 5))
lancer hote5 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=2 --delai-poignee=$DELAI_POIGNEE_LENT
if attendre_hote hote5; then
	lancer lent5 --role=lent --port=$P --pseudo=Lent --delai-poignee=$DELAI_POIGNEE_LENT
	lancer rival5 --role=client --port=$P --pseudo=Rival --attendu=refus_plein --feu="$JOURNAUX/feu5"
	if attendre_ligne lent5 "ACCEPTE" && attendre_ligne rival5 "ATTEND LE FEU"; then
		touch "$JOURNAUX/feu5"
		attendre_fin rival5
		if attendre_ligne hote5 "POIGNEE ECHOUEE 2"; then
			lancer tard5 --role=client --port=$P --pseudo=Tard --attendu=inscrit
		fi
	fi
fi
terminer "poignée de main jamais finie : réservation à la réponse, puis libération par le vrai délai"

# 6. Découverte (balises vers 127.0.0.1) : l'hôte émet sa balise ; un écouteur voit sa partie,
#    la rejoint à l'adresse et au port de la balise, voit la balise suivante compter 2 joueurs.
#    Un second écouteur sur le même port de balises (deux LeLion sur un PC) reçoit une erreur,
#    sans planter. Puis l'hôte quitte le réseau mais son processus vit encore 6 s : la partie doit
#    quitter la liste 3 s après sa dernière balise, pas à la fin du processus.
P=$((PORT_BASE + 6))
B=$((PORT_BASE + 1006))
lancer hote6 --role=hote --port=$P --port-balise=$B --pseudo=Hote6 --places=4 --clients=1 --rester="$JOURNAUX/rester6" --apres-depart=6
if attendre_hote hote6; then
	lancer ecouteur6 --role=ecouteur --port=$P --port-balise=$B --hote=Hote6 --places=4 --rejoindre
	if attendre_ligne ecouteur6 "ECOUTE PRETE"; then
		lancer occupe6 --role=ecouteur --port-balise=$B --occupe
		# occupe6 doit tenter son bind() pendant qu'ecouteur6 tient encore le port (le second bind
		# doit échouer, pas juste arriver après coup) : on attend sa vérification avant de laisser
		# partir ecouteur6 (constat 4 de la revue finale de la phase 12).
		attendre_ligne occupe6 "RESULTAT occupe" && attendre_ligne ecouteur6 "PARTIE A 2" && touch "$JOURNAUX/rester6"
	fi
fi
terminer "découverte : partie vue et rejointe par sa balise, comptée à 2, expirée après le départ de l'hôte ; port des balises occupé sans plantage"
[ "$(compter "PARTIE EXPIREE" ecouteur6)" -eq 1 ] || echec "découverte : la partie n'a pas expiré dans la liste"

# 7. (DIFFUSION=1) La même découverte en vraie diffusion (255.255.255.255 et réseaux privés), sans
#    rejoindre : l'adresse vue est l'une de celles de ce PC.
if [ "${DIFFUSION:-0}" = "1" ]; then
	P=$((PORT_BASE + 7))
	B=$((PORT_BASE + 1007))
	lancer hote7 --role=hote --port=$P --port-balise=$B --pseudo=Hote7 --diffusion --rester="$JOURNAUX/rester7"
	if attendre_hote hote7; then
		lancer ecouteur7 --role=ecouteur --port=$P --port-balise=$B --hote=Hote7 --diffusion
		attendre_ligne ecouteur7 "PARTIE VUE" && touch "$JOURNAUX/rester7"
	fi
	terminer "découverte en vraie diffusion"
	[ "$(compter "PARTIE EXPIREE" ecouteur7)" -eq 1 ] || echec "diffusion : la partie n'a pas expiré dans la liste"
else
	echo "  (scénario 7, découverte en vraie diffusion : DIFFUSION=1 pour le lancer)"
fi

# 8. Salon (phase 13), par les vraies scènes : un hôte et trois clients passent par l'écran Réseau
#    et le salon, arrivés dans l'ordre (index 1, 2, 3). B repart du salon par Retour : sa carte se
#    libère chez tous, un trou reste à l'index 2. A et C demandent au même feu la couleur voisine
#    (A la suivante, C la précédente : toutes deux visent celle de B) ; l'hôte arbitre, chacun garde
#    une couleur à lui. Tous prêts : le bouton « Démarrer la partie » de l'hôte s'active ; A repasse
#    non prêt, le bouton se regrise et un démarrage tenté quand même est refusé ; A de nouveau prêt,
#    l'hôte démarre : chaque poste charge la scène de jeu avec les mêmes fiches, index compactés (C
#    passe de 3 à 2). Un retardataire est alors refusé « manche en cours » : c'est le salon qui l'a
#    posée.
P=$((PORT_BASE + 8))
B=$((PORT_BASE + 1008))
lancer hote8 --role=salon-hote --port=$P --port-balise=$B --pseudo=Hote8 --clients=3 --partants=1 --niveau=2 --rester="$JOURNAUX/rester8"
if attendre_hote hote8; then
	lancer a8 --role=salon-client --port=$P --port-balise=$B --pseudo=Anna --voir=4 --reste=3 --couleur=1 --feu="$JOURNAUX/feu8" \
		--annuler="$JOURNAUX/annule8" --relance="$JOURNAUX/relance8" --index=1 --niveau=2
	if attendre_ligne a8 "SALON OUVERT"; then
		lancer b8 --role=salon-client --port=$P --port-balise=$B --pseudo=Bruno --voir=4 --partir
		if attendre_ligne b8 "SALON OUVERT"; then
			lancer c8 --role=salon-client --port=$P --port-balise=$B --pseudo=Chloe --reste=3 --couleur=-1 --feu="$JOURNAUX/feu8" \
				--index=2 --niveau=2
			if attendre_ligne a8 "ATTEND LE FEU" && attendre_ligne c8 "ATTEND LE FEU"; then
				touch "$JOURNAUX/feu8"
				if attendre_ligne hote8 "BOUTON ACTIF"; then
					touch "$JOURNAUX/annule8"
					if attendre_ligne hote8 "DEMARRAGE REFUSE"; then
						touch "$JOURNAUX/relance8"
						if attendre_ligne hote8 "MANCHE" && attendre_ligne a8 "MANCHE" && attendre_ligne c8 "MANCHE"; then
							lancer tard8 --role=client --port=$P --pseudo=Tard --attendu=refus_manche
							attendre_fin tard8
						fi
					fi
				fi
			fi
		fi
	fi
	touch "$JOURNAUX/rester8"
fi
terminer "salon : arrivées, départ (carte libérée), couleurs arbitrées, démarrage refusé tant qu'un joueur n'est pas prêt, manche lancée par l'hôte chez tous, retardataire refusé"
[ "$(grep -h "^MANCHE " "$JOURNAUX/hote8.log" "$JOURNAUX/a8.log" "$JOURNAUX/c8.log" 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^MANCHE " hote8 a8 c8)" -eq 3 ] || echec "salon : les trois postes doivent charger la manche avec la même empreinte"
[ "$(compter "BOUTON ACTIF" hote8)" -eq 2 ] && [ "$(compter "DEMARRAGE REFUSE" hote8)" -eq 1 ] && [ "$(compter "PLUS PRET" a8)" -eq 1 ] \
	|| echec "salon : le bouton de l'hôte doit s'activer deux fois, et le démarrage être refusé une fois entre les deux"

# 9. Manche synchronisée (phase 14), par les vraies scènes : un hôte, deux clients qui jouent, un
#    muet (prêt au salon, mais qui ne charge jamais sa scène de jeu). L'hôte se fige GEL9 s dès sa
#    scène chargée (ses clients chargent pendant ce temps : ils ne doivent pas le croire parti) ;
#    la barrière de chargement exclut le muet après son délai ; l'intro part chez tous. Chaque poste
#    descend vers la ville et la peint au clavier ; Bruno quitte alors la manche par le menu local :
#    son lion disparaît, ses cellules restent. L'hôte donne à Anna un cran, la gerbe XXL et un
#    étourdissement ; lions arrêtés et coulures finies, il fige la
#    manche et écrit son empreinte (territoire, scores, tampons et leur suite, lions et réactions,
#    apparitions) ; Anna écrit la sienne, qui doit être la même. L'hôte part : Anna voit « L'hôte a
#    quitté la partie », puis le titre.
GEL9=6.5
DELAI_CHARGEMENT9=3
P=$((PORT_BASE + 9))
B=$((PORT_BASE + 1009))
lancer hote9 --role=manche-hote --port=$P --port-balise=$B --pseudo=Hote9 --clients=3 --gel=$GEL9 \
	--delai-chargement=$DELAI_CHARGEMENT9 --sens=1 --rester="$JOURNAUX/rester9"
if attendre_hote hote9; then
	lancer a9 --role=manche-client --port=$P --port-balise=$B --pseudo=Anna --sens=1 --fige="$JOURNAUX/fige9"
	lancer b9 --role=manche-client --port=$P --port-balise=$B --pseudo=Bruno --sens=-1 --partir
	lancer c9 --role=manche-muet --port=$P --port-balise=$B --pseudo=Muet --gel=$GEL9 --delai-chargement=$DELAI_CHARGEMENT9
	# Chaque étape de l'hôte dans ses 15 s : la manche entière en prend plus (le gel, l'intro, les
	# passes). M6 (revue finale) : « BARRIERE » d'abord, pour que la fenêtre de 15 s d'« INTRO »
	# ne couvre plus, à elle seule, le plancher fixe du scénario (gel + délai de barrière + intro).
	if attendre_ligne hote9 "BARRIERE" && attendre_ligne hote9 "INTRO" && attendre_ligne hote9 "DEPART VU" && attendre_ligne hote9 "FIGE"; then
		touch "$JOURNAUX/fige9"
		attendre_ligne a9 "EMPREINTE" && touch "$JOURNAUX/rester9"
	fi
	touch "$JOURNAUX/fige9" "$JOURNAUX/rester9"
fi
terminer "manche : barrière de chargement (hôte figé, muet exclu), commandes au clavier de chaque poste, tampons, territoire et apparitions répliqués, départ d'un client en pleine manche, hôte perdu"
[ "$(grep -h "^EMPREINTE " "$JOURNAUX/hote9.log" "$JOURNAUX/a9.log" 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^EMPREINTE " hote9 a9)" -eq 2 ] || echec "manche : l'hôte et Anna doivent finir avec la même empreinte"
[ "$(compter "^PARTI" b9)" -eq 1 ] && [ "$(compter "^EXCLU" c9)" -eq 1 ] || echec "manche : Bruno doit partir, le muet être exclu"

# 10. I1 (revue finale phase 14) : un muet dont le fil principal se fige tout entier (ENet muet,
#     comme un poste qui compile ses shaders) après le lancement de la manche. Sa libération
#     (`Reseau._liberer` : fermé sur-le-champ, sans attendre d'accusé de réception) doit faire passer
#     la barrière bien avant le silence de chargement (30 s) : l'hôte chronomètre lui-même l'écart
#     entre l'exclusion et la barrière (--mesurer-exclusion, ECART_EXCLUSION en ms). Aucune manche
#     n'est jouée ici : les deux postes sont arrêtés dès la mesure prise.
DELAI_CHARGEMENT10=3
P=$((PORT_BASE + 10))
B=$((PORT_BASE + 1010))
avant10=$ECHECS
lancer hote10 --role=manche-hote --port=$P --port-balise=$B --pseudo=Hote10 --clients=1 \
	--delai-chargement=$DELAI_CHARGEMENT10 --mesurer-exclusion
if attendre_hote hote10; then
	lancer muet10 --role=manche-muet --port=$P --port-balise=$B --pseudo=Muet10 \
		--delai-chargement=$DELAI_CHARGEMENT10 --figer=10
	if attendre_ligne hote10 "ECART_EXCLUSION"; then
		ecart=$(grep -o "ECART_EXCLUSION [0-9]*" "$JOURNAUX/hote10.log" | head -1 | awk '{print $2}')
		echo "  (I1) écart exclusion -> barrière : ${ecart} ms"
		[ -n "$ecart" ] && [ "$ecart" -lt 2000 ] 2>/dev/null \
			|| echec "I1 : écart exclusion -> barrière de ${ecart:-?} ms (attendu bien sous 2000 ms : la libération ne doit pas attendre l'accusé de réception du pair figé)"
	fi
fi
tuer hote10 muet10
[ "$ECHECS" -eq "$avant10" ] && echo "  ✅ I1 : un poste figé (ENet muet) est exclu, la barrière passe sans attendre le silence par défaut de la barrière"

# 11. De bout en bout (phase 15), par les vraies scènes : un hôte et trois clients jouent une manche
#     entière (DUREE11 s) sur le Village (son peintre), chacun au clavier selon son programme (des
#     commandes au hasard, tirées de sa graine). Après 20 s de jeu, l'hôte orchestre les rencontres
#     (pastilles ramassées au vol, étoile, soucoupe, sa gerbe sur un client, celle d'un client sur lui,
#     un choc) ; puis le client qui tient le plus de territoire est arraché (KILL, sans un paquet de
#     plus) : l'hôte doit le voir partir au bout du silence de son battement (Reseau.SILENCE_SESSION,
#     10 s depuis le dernier battement reçu, 0 à 1 s avant l'arrachement ; ECART_DEPART), pas avant
#     (ENet ne décide plus), son lion disparaître chez tous, ses cellules rester. Le jeu reprend jusqu'au
#     calme, 4 s avant la fin ; la manche arrivée à son terme, l'hôte la fige : l'hôte et les deux
#     clients restés écrivent la même empreinte (territoire, scores, suite des tampons, lions,
#     apparitions, niveau, réactions de chaque joueur).
DUREE11=45
P=$((PORT_BASE + 11))
B=$((PORT_BASE + 1011))
DELAI_AVANT11=$DELAI
DELAI=$((DUREE11 + 60))
lancer hote11 --role=bout-hote --port=$P --port-balise=$B --pseudo=Hote11 --clients=3 --niveau=2 --duree=$DUREE11 \
	--graine=1 --tue="$JOURNAUX/tue11" --rester="$JOURNAUX/rester11"
partant11=""
restes11="a11 b11 c11"
if attendre_hote hote11; then
	lancer a11 --role=bout-client --port=$P --port-balise=$B --pseudo=Anna --graine=2 --calme="$JOURNAUX/calme11" --fige="$JOURNAUX/fige11"
	lancer b11 --role=bout-client --port=$P --port-balise=$B --pseudo=Bruno --graine=3 --calme="$JOURNAUX/calme11" --fige="$JOURNAUX/fige11"
	lancer c11 --role=bout-client --port=$P --port-balise=$B --pseudo=Chloe --graine=4 --calme="$JOURNAUX/calme11" --fige="$JOURNAUX/fige11"
	if attendre_ligne hote11 "INTRO" 30 && attendre_ligne a11 "INTRO" && attendre_ligne b11 "INTRO" && attendre_ligne c11 "INTRO" \
		&& attendre_ligne hote11 "A TUER" 60; then
		# L'hôte désigne le client à arracher (celui qui tient le plus de territoire) : « A TUER <pseudo> ».
		case "$(sed -n 's/^A TUER //p' "$JOURNAUX/hote11.log" | head -1)" in
			Anna) partant11=a11 ;;
			Bruno) partant11=b11 ;;
			Chloe) partant11=c11 ;;
			*) partant11="" ;;
		esac
		restes11=""
		for nom in a11 b11 c11; do
			[ "$nom" = "$partant11" ] || restes11="$restes11 $nom"
		done
		if [ -n "$partant11" ]; then
			arracher "$partant11"
			touch "$JOURNAUX/tue11"
			# Le client arraché n'aura pas de bilan, mais ses vérifications jusque-là comptent.
			grep -HnE "❌|SCRIPT ERROR|SHADER ERROR|Parse Error" "$JOURNAUX/$partant11.log" \
				&& echec "de bout en bout : erreurs dans le journal de $partant11 avant son arrachement"
			if attendre_ligne hote11 "DEPART VU" 30 && attendre_ligne hote11 "CALME" $DUREE11; then
				touch "$JOURNAUX/calme11"
				if attendre_ligne hote11 "FIGE" 30; then
					touch "$JOURNAUX/fige11"
					ok11=1
					for nom in $restes11; do
						attendre_ligne "$nom" "EMPREINTE" || ok11=0
					done
					[ "$ok11" -eq 1 ] && touch "$JOURNAUX/rester11"
				fi
			fi
		else
			echec "de bout en bout : l'hôte ne désigne aucun client connu à arracher"
		fi
	fi
	touch "$JOURNAUX/tue11" "$JOURNAUX/calme11" "$JOURNAUX/fige11" "$JOURNAUX/rester11"
	if [ -z "$partant11" ]; then
		# Aucun client désigné (échec plus tôt) : b11 est arraché quand même, les autres finissent.
		partant11=b11
		restes11="a11 c11"
		arracher b11
	fi
fi
terminer "de bout en bout : manche entière à 1 hôte et 3 clients au clavier, rencontres (pastilles au vol, étoile, soucoupe, gerbes croisées, choc), un client arraché en pleine manche, mêmes empreintes chez l'hôte et les clients restés"
DELAI=$DELAI_AVANT11
[ "$(for nom in hote11 $restes11; do grep -h "^EMPREINTE " "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^EMPREINTE " hote11 $restes11)" -eq 3 ] || echec "de bout en bout : l'hôte et les deux clients restés doivent finir avec la même empreinte"
for nom in $restes11; do
	grep -h "^PREDICTION " "$JOURNAUX/$nom.log" 2>/dev/null | sed 's/^/  (bout en bout) /'
done
ecart11=$(grep -o "ECART_DEPART [0-9]*" "$JOURNAUX/hote11.log" 2>/dev/null | head -1 | awk '{print $2}')
echo "  (bout en bout) départ arraché vu par l'hôte au bout de ${ecart11:-?} ms"
[ -n "$ecart11" ] && [ "$ecart11" -ge 8500 ] && [ "$ecart11" -le 11000 ] 2>/dev/null \
	|| echec "de bout en bout : départ arraché vu au bout de ${ecart11:-?} ms (attendu de 8500 à 11000 : les 10 s du battement depuis son dernier, reçu 0 à 1 s avant l'arrachement, et la marge d'une image sous la charge de la CI)"

# 12. Prédiction sous latence simulée (phase 16), par les vraies scènes : un hôte et deux clients, les
#     clients derrière le relais (80 ms d'aller-retour, 40 ms de gigue, 5 % de pertes dans chaque
#     sens). Chaque client joue au clavier son programme au hasard (graine), dans sa moitié de la bande
#     de peinture : l'hôte reste immobile et écarte les ennemis. Au calme, chaque client vérifie sa
#     prédiction (aucun recalage, l'erreur rarement au-delà de 16 px, sous 4 px 150 ms après l'arrêt de
#     ses commandes), l'hôte les commandes reçues (aucune appliquée deux fois, presque aucune sautée) ;
#     puis la même empreinte chez l'hôte et les deux clients. L'hôte part (ses clients le voient partir
#     à travers le relais), puis le relais s'arrête.
DUREE12=20
P=$((PORT_BASE + 12))
B=$((PORT_BASE + 1012))
R=$((PORT_BASE + 2012))
DELAI_AVANT12=$DELAI
DELAI=$((DUREE12 + 50))
lancer_relais relais12 --ecoute=$R --vers=$P --latence=80 --gigue=40 --pertes=5 --graine=12 --fin="$JOURNAUX/fin12"
lancer hote12 --role=latence-hote --port=$P --port-balise=$B --pseudo=Hote12 --clients=2 --niveau=0 --duree=$DUREE12 \
	--rester="$JOURNAUX/rester12"
if attendre_ligne relais12 "RELAIS PRET" && attendre_hote hote12; then
	lancer a12 --role=latence-client --port=$R --port-balise=$B --pseudo=Anna --graine=5 --moitie=0 --calme="$JOURNAUX/calme12" --fige="$JOURNAUX/fige12"
	lancer b12 --role=latence-client --port=$R --port-balise=$B --pseudo=Bruno --graine=6 --moitie=1 --calme="$JOURNAUX/calme12" --fige="$JOURNAUX/fige12"
	if attendre_ligne hote12 "INTRO" 30 && attendre_ligne hote12 "CALME" $((DUREE12 + 10)); then
		touch "$JOURNAUX/calme12"
		if attendre_ligne a12 "PREDICTION" && attendre_ligne b12 "PREDICTION" && attendre_ligne hote12 "FIGE" 30; then
			touch "$JOURNAUX/fige12"
			attendre_ligne a12 "EMPREINTE" && attendre_ligne b12 "EMPREINTE" && touch "$JOURNAUX/rester12"
		fi
	fi
	touch "$JOURNAUX/calme12" "$JOURNAUX/fige12" "$JOURNAUX/rester12"
	attendre_fin hote12
	attendre_fin a12
	attendre_fin b12
fi
touch "$JOURNAUX/fin12"
terminer "prédiction sous latence simulée (80 ms, 40 ms de gigue, 5 % de pertes) : lion local prédit et recalé, commandes redondantes appliquées une fois, mêmes empreintes chez l'hôte et les clients"
DELAI=$DELAI_AVANT12
[ "$(for nom in hote12 a12 b12; do grep -h "^EMPREINTE " "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^EMPREINTE " hote12 a12 b12)" -eq 3 ] || echec "prédiction sous latence : l'hôte et les deux clients doivent finir avec la même empreinte"
grep -hE "^PREDICTION |^COMMANDES |^RELAIS datagrammes" "$JOURNAUX/a12.log" "$JOURNAUX/b12.log" "$JOURNAUX/hote12.log" "$JOURNAUX/relais12.log" 2>/dev/null | sed 's/^/  (latence) /'

# 13. Fin de manche au chrono (phase 17), résultats, revanche et retour au salon (phase 18), par les
#     vraies scènes : un hôte et deux clients, les clients derrière le relais (80 ms d'aller-retour, 40 ms
#     de gigue, 5 % de pertes), jouent une manche courte (DUREE13 s, `ReglesBataille.duree_manche` sur
#     chaque poste) que seul le chrono de l'hôte termine, chacun peignant sans lâcher ses touches jusqu'au
#     gong : chaque client reçoit sa fin (son chrono pris sur celui de l'hôte, « ECART_CHRONO »), tout se
#     fige chez tous sur le même HUD, le même bilan et les mêmes lions (posés sur l'état final de l'hôte :
#     les lignes « FIN » identiques), puis le même écran Résultats (« RESULTATS FIN »). L'hôte choisit
#     Revanche : chaque poste recharge la scène de jeu, une manche neuve de DUREE13B s, qui finit de même
#     (« FIN2 », « RESULTATS FIN2 »). Bruno quitte alors l'écran Résultats (le titre) ; l'hôte et Anna le
#     voient partir ; l'hôte choisit Retour au salon : tous deux y reviennent, la même table sans Bruno,
#     personne prêt (« SALON », la même ligne) ; l'hôte quitte le salon, Anna le voit partir, puis le
#     relais s'arrête.
DUREE13=10
DUREE13B=6
P=$((PORT_BASE + 13))
B=$((PORT_BASE + 1013))
R=$((PORT_BASE + 2013))
DELAI_AVANT13=$DELAI
DELAI=$((DUREE13 + DUREE13B + 60))
lancer_relais relais13 --ecoute=$R --vers=$P --latence=80 --gigue=40 --pertes=5 --graine=13 --fin="$JOURNAUX/fin13"
lancer hote13 --role=chrono-hote --port=$P --port-balise=$B --pseudo=Hote13 --clients=2 --niveau=0 --duree-manche=$DUREE13 \
	--duree-revanche=$DUREE13B --revanche="$JOURNAUX/revanche13" --salon="$JOURNAUX/salon13" --rester="$JOURNAUX/rester13"
if attendre_ligne relais13 "RELAIS PRET" && attendre_hote hote13; then
	lancer a13 --role=chrono-client --port=$R --port-balise=$B --pseudo=Anna --sens=1 --duree-manche=$DUREE13 --duree-revanche=$DUREE13B
	lancer b13 --role=chrono-client --port=$R --port-balise=$B --pseudo=Bruno --sens=-1 --duree-manche=$DUREE13 --duree-revanche=$DUREE13B \
		--quitte="$JOURNAUX/quitte13"
	if attendre_ligne hote13 "^RESULTATS FIN " $((DUREE13 + 40)) && attendre_ligne a13 "^RESULTATS FIN " && attendre_ligne b13 "^RESULTATS FIN "; then
		touch "$JOURNAUX/revanche13"
		if attendre_ligne hote13 "^RESULTATS FIN2 " $((DUREE13B + 30)) && attendre_ligne a13 "^RESULTATS FIN2 " && attendre_ligne b13 "^RESULTATS FIN2 "; then
			touch "$JOURNAUX/quitte13"
			if attendre_ligne hote13 "DEPART VU" && attendre_ligne a13 "DEPART VU"; then
				touch "$JOURNAUX/salon13"
				attendre_ligne hote13 "^SALON " && attendre_ligne a13 "^SALON "
			fi
		fi
	fi
	touch "$JOURNAUX/revanche13" "$JOURNAUX/quitte13" "$JOURNAUX/salon13" "$JOURNAUX/rester13"
	attendre_fin hote13
	attendre_fin a13
	attendre_fin b13
fi
touch "$JOURNAUX/revanche13" "$JOURNAUX/quitte13" "$JOURNAUX/salon13" "$JOURNAUX/rester13" "$JOURNAUX/fin13"
terminer "fin de manche au chrono sous latence simulée, résultats, revanche et retour au salon : chaque client reçoit la fin et le bilan de l'hôte, le même écran Résultats partout, une revanche relancée par l'hôte, un client qui quitte l'écran Résultats vu parti, le retour au salon sur la même table"
DELAI=$DELAI_AVANT13
for ligne in "^FIN " "^RESULTATS FIN " "^FIN2 " "^RESULTATS FIN2 "; do
	[ "$(for nom in hote13 a13 b13; do grep -h "$ligne" "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
		&& [ "$(compter "$ligne" hote13 a13 b13)" -eq 3 ] || echec "fin au chrono : l'hôte et les deux clients doivent avoir la même ligne « $ligne» (HUD, bilan, lions, écran Résultats)"
done
[ "$(for nom in hote13 a13; do grep -h "^SALON " "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^SALON " hote13 a13)" -eq 2 ] && [ "$(compter "^QUITTE" b13)" -eq 1 ] \
	|| echec "retour au salon : l'hôte et Anna doivent revenir au salon sur la même table, Bruno être parti"
grep -hE "^FIN |^FIN2 |^RESULTATS |^ECART_CHRONO|^SALON " "$JOURNAUX/hote13.log" "$JOURNAUX/a13.log" "$JOURNAUX/b13.log" 2>/dev/null | sed 's/^/  (chrono) /'

echo "== $ECHECS échec(s) =="
if [ "$ECHECS" -eq 0 ]; then
	rm -rf "$JOURNAUX"
	exit 0
fi
recopier_journaux
exit 1
