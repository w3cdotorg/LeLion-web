# Phase 2 : signalisation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le Worker Cloudflare de signalisation, dans `signalisation/` à la racine du dépôt : `GET /v1/creer` et `GET /v1/rejoindre/<code>` en WebSocket, un Durable Object `Salle` par code (SQLite, hibernation), les messages du §4.2 de la spec (`salle`, `bienvenue`, `arrivee`, relais `offre` / `reponse` / `candidat` entre l'hôte et un client seulement, `depart`, `ouvert`, `ping` / `pong`, `erreur`), les plafonds du §8.1 (origine, 7 sockets, 16 Ko, 20 messages par seconde, 5 créations par minute et par IP), l'expiration à 4 h et les identifiants TURN de 2 h (API de Cloudflare simulée dans les tests, STUN seul sans secrets). Sortie : **`npm test` vert en local et en CI, sans compte Cloudflare** (49 tests en 7 suites, `vitest` dans l'environnement local de Cloudflare), `wrangler dev` qui sert une vraie partie de signalisation en local (pour la phase 4), la spec à jour des faits vérifiés. Rien n'est déployé (phase 5).

**Architecture:**
- **`src/index.js`** (le module principal, qui n'exporte que `default` et `Salle`) : routes `/v1`, 400 pour un code mal formé, 404 / 405 / 426 pour le reste ; origine (`src/origine.js`, variable `ORIGINES`) ; limite de création par IP (binding `ratelimits` `LIMITE_CREATION`, clé `cf-connecting-ip`) ; tirage d'un code libre (`src/code.js`, 5 essais si le code a déjà un hôte) ; la socket passe à la salle `env.SALLES.get(env.SALLES.idFromName(code))` par `fetch`. Un appel de salle qui échoue (quota gratuit des Durable Objects épuisé) donne `erreur quota`.
- **`src/protocole.js`** : plafonds (`LIMITES`), `PING` / `PONG` (texte exact), `envoyer`, `fermer` (code 1000, la raison en motif), `refuser(raison)` (une socket acceptée le temps d'un message `erreur`, puis fermée : la réponse 101 qui la porte ; un navigateur ne montre pas au jeu le statut HTTP d'une WebSocket refusée), `journal` (JSON, jamais de SDP ni d'IP).
- **`src/ice.js`** : `fabriquerIce(env)` : STUN (Cloudflare, Google) toujours ; avec les secrets `TURN_KEY_ID` et `TURN_KEY_API_TOKEN`, un `POST` à l'API TURN de Cloudflare (`ttl` 7200, 3 s au plus), ses serveurs TURN sans le port 53 ; sans secrets ou API en échec : STUN seul.
- **`src/salle.js`** (`Salle extends DurableObject`) : l'hôte (étiquette `hote`, id 1) et les arrivants (étiquettes `client` et leur id) acceptés par `ctx.acceptWebSocket` ; une fiche par socket (`serializeAttachment` : rôle, id, seau de jetons, fin) ; les ids donnés dans une table SQLite `pairs` (uniques toute la vie de la salle) ; `setWebSocketAutoResponse` pour `{"t":"ping"}` ; une alarme à 4 h. Rien en mémoire : tout survit à l'hibernation. L'hôte parti ou l'alarme : `erreur` à tous, fermeture, `deleteAll()` (alarme comprise).
- **Tests** (`test/`) : une suite par souci (`code`, `ice`, `entree`, `salle`, `relais`, `plafonds`, `vie`), des outils communs (`aide.js` : sockets vers `exports.default.fetch`, file des messages, salles prêtes), l'API TURN simulée avant chaque test (`preparation.js`, `turn.js`) ; les ids et le hasard pilotés par un espion de `crypto.getRandomValues`, l'alarme par `runDurableObjectAlarm`, l'hibernation par `evictDurableObject`.

**Tech Stack:** Cloudflare Workers et Durable Objects (JavaScript, modules ES, `compatibility_date` 2026-10-01, stockage SQLite, WebSocket Hibernation API, alarmes, binding `ratelimits`), `wrangler` 4.146.0 (workerd 1.20261001.1), `vitest` 4.1.11 et `@cloudflare/vitest-plugin` 1.3.5 (Miniflare 5.20261001.0-alpha), Node 26.10.0 sur ce Mac et 24.21.0 en CI, GitHub Actions (`actions/setup-node@v6`).

**Spec:** `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§3.1 unité `signalisation/`, §4 salles et signalisation, §8.1 sécurité du Worker, §9, §10 tests du Worker, §13) · feuille de route : `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (ligne 2, « Vérification commune », « Points de vigilance ») · prérequis : **phase 1 fusionnée** (PR #2, `806959c Merge pull request #2 from w3cdotorg/phase-01-transport`) ; nouvelle branche `phase-02-signalisation` depuis `main`.

## Global Constraints

- Points d'entrée (spec §4.1) : « Tous sous `wss://<worker>/v1/…` : la version du protocole de signalisation est dans le chemin » ; « `GET /v1/creer` (upgrade WebSocket) : l'hôte. Le Worker tire un code libre (nouvel essai si la salle de ce code a déjà un hôte), crée le Durable Object `Salle` de ce code (`idFromName`) et lui passe la socket. » ; « `GET /v1/rejoindre/<code>` (upgrade WebSocket) : un arrivant. Code mal formé : 400 ; salle sans hôte : message `erreur` `inconnue` puis fermeture. »
- Code (spec §2) : « Code de salle de 6 caractères (alphabet sans 0/O, 1/I/L), affiché `K7Q-2XM` ». Alphabet retenu : `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (31 caractères).
- Messages (spec §4.2) : `{t:"salle", code, id:1, ice}` ; `{t:"bienvenue", id, ice}` (« `id` : identifiant de pair tiré au hasard dans 2..2³¹-1, unique dans la salle ») ; `{t:"arrivee", id, ice}` (« `ice` neuf ») ; `{t:"offre"|"reponse"|"candidat", vers, …}` (« La salle vérifie que `vers` est membre, remplace l'émetteur par `de` et relaie. Seulement entre l'hôte et un client, jamais entre deux clients. ») ; `{t:"depart", id}` (« La socket d'un client s'est fermée avant que l'hôte ait dit `ouvert`. ») ; `{t:"ouvert", id}` (« la salle oublie ce client ») ; `{t:"ping"}` (« réponse automatique `{t:"pong"}` (hibernation du Durable Object) ») ; `{t:"erreur", raison}` puis fermeture : « `inconnue`, `pleine`, `debit`, `quota`, `origine` ».
- Déroulé (spec §4.3) : « Socket fermée (onglet fermé, retour au titre) : la salle est supprimée. » ; « Une salle vit **4 h au plus**, puis la salle ferme toutes ses sockets ».
- Worker (spec §8.1) : « **Origine** : WebSocket acceptée seulement depuis `https://w3cdotorg.github.io` et `http://localhost:*` (variable du Worker). » ; « **Plafonds par salle** : 7 sockets (l'hôte et 6 arrivants en cours) ; messages de 16 Ko au plus ; 20 messages par seconde et par socket ; au-delà, `erreur` puis fermeture. » ; « **Limite par IP** : quelques salles créées par minute et par IP (`cf-connecting-ip`), par la limitation de débit des Workers (`ratelimit`) si elle est disponible sur l'offre gratuite, sinon par un Durable Object compteur. À vérifier en phase 2. » ; « **Validation** : type de message connu, `vers` membre de la salle, champs attendus seulement ; le contenu SDP n'est ni lu ni journalisé. » ; « **TURN** : la clé TURN et le jeton d'API restent dans les secrets du Worker ; identifiants à 2 h, donnés seulement par `salle`, `bienvenue` et `arrivee`. » ; « **Coût** : Durable Object en hibernation de WebSocket […] ; quota gratuit dépassé : `erreur quota` ».
- Tests du Worker (spec §10) : « `signalisation/`, `vitest` dans l'environnement local de Cloudflare, sans compte : création, code unique, arrivée, relais limité à hôte ↔ client, `depart`, `ouvert`, plafonds (7 sockets, 16 Ko, 20 msg/s), limite par IP, origine refusée, expiration à 4 h, identifiants TURN (API Cloudflare simulée), réponses automatiques `ping`. »
- Offre gratuite (spec §13, vérifié le 01/10/2026 dans la documentation des Durable Objects) : « Workers Free plan: Only Durable Objects with SQLite storage backend are available » : migration `new_sqlite_classes`.
- Déploiement : aucun (`wrangler deploy` sans `--dry-run`, `wrangler login`, `wrangler secret put` interdits : phase 5, avec l'utilisateur). Aucun secret dans le dépôt : les faux secrets TURN des tests vivent dans `vitest.config.js` et ne valent rien.
- Versions épinglées (vérifiées le 01/10/2026 sur npm, plan rejoué avec elles) : `wrangler` **4.146.0**, `vitest` **4.1.11** (`@cloudflare/vitest-plugin` exige `vitest` `^4.1.0` : la 5.0.3 publiée est refusée), `@cloudflare/vitest-plugin` **1.3.5** (il dépend lui-même de `wrangler` 4.146.0 et de Miniflare 5.20261001.0-alpha). `package-lock.json` commité ; CI en `npm ci`.
- Commandes : `export PATH="/opt/homebrew/bin:$PATH"` puis `cd ~/Sites/LeLion-web/signalisation` (branche `phase-02-signalisation`) ; `npm test` (= `vitest run`). Après la Task 1, `npm ci` réinstalle depuis le verrou.
- Code : JavaScript en modules ES, sans TypeScript ni dépendance d'exécution ; identifiants, commentaires et messages en français ; tabulations ; docstrings `/** … */`. Après chaque écriture, `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' src/*.js test/*.js` (depuis `signalisation/`) ne sort rien.
- Les fichiers neufs s'écrivent tels quels (outil Write) ; les blocs « remplacer … par … » citent le texte exact laissé par la tâche précédente et se font avec l'outil Edit (texte exact, une seule occurrence), dans l'ordre donné. Le plan a été appliqué tâche après tâche à un clone de `main` (`806959c`) : chaque « Expected » est la sortie mesurée.
- Bruit connu des sorties : `npm warn install-scripts … workerd@1.20261001.1 (postinstall: node install.js)` (npm 11 : sans effet, le binaire de workerd vient de son paquet `@cloudflare/workerd-<plateforme>`) ; en `wrangler dev`, une ligne `✘ [ERROR] Uncaught Error: Network connection lost.` par socket refusée qui se ferme (socket acceptée hors hibernation : vu même quand le client ferme proprement, jamais sous `vitest`).
- Commits en français, terminés par :
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT
  ```

## Review Focus

1. **Un relais qui fuit ou qu'on usurpe** : un client qui écrit à un autre client, un `de` forgé par l'émetteur, un `vers` hors de la salle (ou l'hôte lui-même), un champ en plus qui passerait tel quel, un type hérité d'`Object` (`constructor`, `__proto__`) pris pour un type connu (vu en préparant ce plan : `RELAYES[m.t]` seul relayait `{t:"constructor"}`). La salle reconstruit le message relayé (`de` posé par elle, `vers` retiré) et n'admet que les champs exacts de chaque type. → `test/relais.test.js` : « jamais d'un client à un autre », « vers inconnu, vers l'hôte lui-même », « champs attendus seulement » (`de: 42`, `constructor`, `__proto__`, `toString` ignorés), avec un message témoin qui prouve que les refusés ont été lus avant (Task 4).
2. **Un état perdu à l'hibernation** : la salle est évincée de la mémoire entre deux messages (le runtime le fait dès qu'elle se tait) ; un rôle, un id ou un seau de jetons gardé dans un champ de la classe disparaîtrait. Tout vit dans les étiquettes, les fiches attachées et SQLite ; le constructeur ne pose que la réponse automatique. → `test/vie.test.js` « évincée de la mémoire, la salle garde ses membres, leurs ids et le relais » (`evictDurableObject`, Task 6).
3. **Deux pairs au même id** : l'hôte garde dans son `WebRTCMultiplayerPeer` des clients que la salle a oubliés (`ouvert`) ; un id redonné casserait la partie. Les ids donnés restent dans la table `pairs` toute la vie de la salle ; 0 et 1 ne sortent jamais. → `test/salle.test.js` « ni 0, ni 1, ni un id déjà donné dans la salle (même à un client parti) » (tirages imposés par un espion de `crypto.getRandomValues`, Task 3).
4. **Les plafonds à leur bord** : 16 384 octets passent et 16 385 non, comptés en UTF-8 ; 20 messages d'affilée passent, au-delà `debit` ; le battement ne compte pas ; la 8e socket reçoit `pleine`, une place rendue (`ouvert`, départ) resert ; un hôte au-delà ferme sa salle ; la 6e création d'une IP dans la minute reçoit `debit`, une autre IP non. → `test/plafonds.test.js` (Task 5).
5. **Ce que `vitest` ne voit pas** : un module principal qui exporte autre chose que des gestionnaires (workerd refuse alors de démarrer en `wrangler dev` et au déploiement, alors que `vitest` passe : vu en préparant ce plan) ; Godot qui importe `signalisation/node_modules` (il y a écrit un `favicon.svg.import` de Miniflare et l'aurait mis dans l'export Web) ; une configuration que `wrangler` refuserait. → `test/entree.test.js` « n'exporte que des gestionnaires » (Task 3) ; `.gdignore` vérifié à l'import Godot (Task 1, Step 2) ; essai `wrangler dev` et `wrangler deploy --dry-run` (Task 8, Step 2 ; le second aussi en CI).

## Écarts assumés

1. **`@cloudflare/vitest-plugin` au lieu de `@cloudflare/vitest-pool-workers`** : le paquet a été renommé (premier `@cloudflare/vitest-plugin` le 20/08/2026 ; dernier `vitest-pool-workers` 0.22.0 le 18/08/2026, lié à `wrangler` 4.124.0). Le guide « Migrate to Vitest plugin » de Cloudflare : « The package API and Vitest configuration are unchanged » (seuls le nom du paquet et l'import de `cloudflareTest` changent). Le `fetchMock` d'autrefois n'y est plus : l'API TURN se simule par `vi.spyOn(globalThis, "fetch")` (la salle tourne dans l'isolat des tests ; la réponse se fabrique à l'appel, une `Response` créée par le test ne se lit pas depuis un Durable Object : « Cannot perform I/O on behalf of a different Durable Object »).
2. **25 fichiers au lieu des 5 de la feuille de route** : 22 neufs sous `signalisation/` (un module par souci, `index`, `origine`, `code`, `protocole`, `ice`, `salle` : 440 lignes, commentaires compris, au lieu des « environ 150 » de la spec ; sept suites de tests, une par souci, et trois fichiers d'outils ; `package.json`, `package-lock.json`, `.gitignore`, `.gdignore`, `wrangler.jsonc`, `vitest.config.js`), plus la CI, la spec (Task 7) et la feuille de route (Task 8). La Task 1 crée les 9 fichiers du paquet ; les autres tâches en touchent 7 au plus, tous sous `signalisation/` jusqu'à la Task 6.
3. **`origineAdmise` dans `src/origine.js`, `ESSAIS_CODE` dans `src/code.js`** : workerd refuse un module principal qui exporte autre chose que des gestionnaires (« Incorrect type for map entry 'ESSAIS_CODE': the provided value is not of type 'function or ExportedHandler' », vu en `wrangler dev`), ce que `vitest` laisse passer ; un test le garde.
4. **Une raison de plus, `expiree`** : le salon de l'hôte doit afficher « Salle expirée » (§4.3, §9) et distinguer l'expiration d'une panne. Spec §4.2 mise à jour (Task 7).
5. **Un message invalide est ignoré, sans fermer la socket** (§8.1 « Validation » ne dit pas quoi en faire) : un relais vers un client parti à l'instant est une course normale, pas une faute ; le débit (20 par seconde) borne déjà l'abus. Seuls les plafonds ferment.
6. **`ouvert` : la salle ferme elle-même la socket du client** (code 1000, motif `ouvert`, sans `erreur`) au lieu d'attendre que le client la ferme : un client qui ne la fermerait pas garderait une des 7 places. La phase 4 (`TransportWebRTC`) ne prend pas une fermeture sans `erreur` après `bienvenue` pour un échec (le délai de 15 s du §4.3 tranche).
7. **Les refus passent par une socket d'un message** (`refuser`) : `origine`, `debit`, `quota` (Worker), `inconnue`, `pleine` (salle) ; le 400 du code mal formé reste en HTTP (spec), et 404, 405, 426 hors des deux routes ou sans upgrade.
8. **Un seul jeu d'identifiants TURN par arrivée**, donné à l'arrivant (`bienvenue`) et à l'hôte (`arrivee`) : neuf pour les deux comme le veut la spec, un appel d'API au lieu de deux ; `salle` a le sien.
9. **Taille dépassée : raison `debit`** (pas de raison dédiée dans la spec) ; **un hôte au-delà d'un plafond ferme sa salle** (ses arrivants reçoivent `inconnue`), puisque sans lui elle ne sert plus.
10. **`Origin` absent : refusé, sans interrupteur de développement** : le jeu livré est l'export Web (le navigateur envoie toujours `Origin`), le desktop de développement joue en ENet (`TransportENet`), le test Playwright de la phase 4 passe par des navigateurs. Un `WebSocketPeer` natif de Godot sans `Origin` n'a rien à faire ici.
11. **`erreur quota` = un appel de salle qui échoue** : sur l'offre gratuite, « If you exceed any one of the free tier limits, further operations of that type will fail with an error » (tarifs des Durable Objects) ; c'est le seul échec attendu en régime établi, et le jeu donne le même conseil (réessayer plus tard). Cinq codes tirés déjà pris donnent aussi `quota` (« Trop de parties en ce moment »). Le quota du Worker lui-même ne se détecte pas de l'intérieur (Cloudflare répond à sa place).
12. **Limite par IP : le binding `ratelimits` (5 par minute), pas un Durable Object compteur.** Vérifié : générale depuis le 19/09/2025 (« The ratelimit binding is now stable and recommended for all production workloads ») ; ni la page *Rate Limiting*, ni les tarifs, ni les limites des Workers ne la réservent à une offre (aucune mention d'offre ; seuls des tiers écrivent qu'elle existe sur l'offre gratuite) ; simulée par Miniflare (fenêtres calées sur la minute de l'horloge) et testée. Le premier `wrangler deploy` (phase 5) le tranche ; s'il la refusait, un Durable Object compteur la remplacerait sans changer le protocole. Sans `cf-connecting-ip` (local), la clé est `local`.
13. **Le Worker accepte un code en minuscules, pas le tiret** (400) : le jeu (phase 3, `CodeSalle`) retire tiret et espaces avant de rejoindre ; `lireCode` n'apparie aucune lettre non ASCII (« ſ », signe kelvin) à une lettre de l'alphabet.
14. **Observabilité** : logs (tous) et traces (5 %) activés, comme le veulent les bonnes pratiques de Cloudflare ; depuis le 01/10/2026 les traces se décomptent du même quota gratuit que les logs (200 000 événements par jour). Journal sans IP ni SDP.

---

### Task 0 : branche et prérequis

Ce plan est commité par le commit de planification : ne pas le recommiter, ne jamais le modifier.

- [ ] **Step 1 : la branche**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
git switch main && git pull --ff-only && git switch -c phase-02-signalisation
git log --oneline -1 --grep "Merge pull request #2 from w3cdotorg/phase-01-transport" main
ls signalisation 2>&1 | head -1; node --version; npm --version
```

Expected : la fusion de la PR #2 (`806959c`) ; `ls: signalisation: No such file or directory` ; Node 22 ou plus (mesuré : `v26.10.0`, `11.19.1`). Sans la fusion de la phase 1 : s'arrêter et attendre.

---

### Task 1 : le paquet du Worker et les codes de salle

**Files:**
- Create: `signalisation/package.json`, `signalisation/package-lock.json` (généré par `npm install`), `signalisation/.gitignore`, `signalisation/.gdignore` (vide)
- Create: `signalisation/wrangler.jsonc`, `signalisation/vitest.config.js`
- Create: `signalisation/src/index.js` (provisoire : 404 partout, réécrit en Task 3), `signalisation/src/code.js`
- Test: `signalisation/test/code.test.js`

**Interfaces:**
- Consumes : rien.
- Produces (Tasks 3 et 5) : `src/code.js` : `ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"`, `LONGUEUR_CODE = 6`, `ESSAIS_CODE = 5`, `lireCode(texte) -> string | null` (le code en majuscules, `null` s'il n'a pas 6 caractères de l'alphabet, casse indifférente, tiret refusé), `tirerCode() -> string` (`crypto.getRandomValues`, rejet des octets ≥ 248 : chaque caractère équiprobable). Scripts `npm test` (`vitest run`) et `npm run dev` (`wrangler dev`). Variable `ORIGINES` = `https://w3cdotorg.github.io,http://localhost:*`.

- [ ] **Step 1 : le paquet**

Créer `signalisation/package.json` :

```json
{
	"name": "lelion-signalisation",
	"version": "0.0.0",
	"private": true,
	"description": "Signalisation WebRTC de LeLion web : Worker Cloudflare et Durable Object Salle.",
	"type": "module",
	"engines": {
		"node": ">=22"
	},
	"scripts": {
		"test": "vitest run",
		"dev": "wrangler dev"
	},
	"devDependencies": {
		"@cloudflare/vitest-plugin": "1.3.5",
		"vitest": "4.1.11",
		"wrangler": "4.146.0"
	}
}
```

Créer `signalisation/.gitignore` :

```gitignore
node_modules/
.wrangler/
.dev.vars*
```

Créer `signalisation/wrangler.jsonc` :

```jsonc
{
	"$schema": "./node_modules/wrangler/config-schema.json",
	"name": "lelion-signalisation",
	"main": "src/index.js",
	"compatibility_date": "2026-10-01",
	// Origines admises, séparées par des virgules ; « :* » = tout port (spec §8.1).
	"vars": {
		"ORIGINES": "https://w3cdotorg.github.io,http://localhost:*"
	},
	// Secrets (phase 5, jamais dans le dépôt) : TURN_KEY_ID, TURN_KEY_API_TOKEN. Absents : STUN seul.
	"observability": {
		"enabled": true,
		"logs": { "enabled": true, "head_sampling_rate": 1 },
		"traces": { "enabled": true, "head_sampling_rate": 0.05 }
	}
}
```

Créer `signalisation/vitest.config.js` :

```js
import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
	plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" } })],
});
```

Créer `signalisation/src/index.js` (le plugin de test charge le module principal ; il ne sert encore à rien) :

```js
// Le point d'entrée du Worker de signalisation (spec §4.1) : ses routes viennent avec la Task 3.
export default {
	async fetch() {
		return new Response("introuvable\n", { status: 404 });
	},
};
```

puis :

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web/signalisation
touch .gdignore
npm install
npm ls --depth=0
```

Expected : `added 79 packages` (à quelques paquets près si une dépendance indirecte a bougé), le bruit connu `npm warn install-scripts`, puis `@cloudflare/vitest-plugin@1.3.5`, `vitest@4.1.11`, `wrangler@4.146.0`. `package-lock.json` est créé (`lockfileVersion: 3`, avec `@cloudflare/workerd-linux-64` pour la CI : `grep -c '"node_modules/@cloudflare/workerd-linux-64"' package-lock.json` donne `1`).

- [ ] **Step 2 : `.gdignore` tient Godot hors du Worker**

Sans lui, Godot parcourt `node_modules` (387 dossiers dans son cache) et importe `node_modules/miniflare/dist/local-explorer-ui/favicon.svg` (mesuré sur une copie du dépôt), que l'export Web (`all_resources`) emporterait.

```bash
cd ~/Sites/LeLion-web
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
find signalisation -name "*.import" | wc -l; grep -c "signalisation" .godot/editor/filesystem_cache10
git status --short
```

Expected : pas de « ÉCHEC COMPILATION » ; `0` et `0` ; `git status` ne montre que `?? signalisation/` (ni `node_modules` ni `.wrangler` : `.gitignore`).

- [ ] **Step 3 : les tests**

Créer `signalisation/test/code.test.js` :

```js
import { describe, expect, it } from "vitest";
import { ALPHABET, LONGUEUR_CODE, lireCode, tirerCode } from "../src/code.js";

describe("alphabet des codes", () => {
	it("31 caractères distincts, sans 0, O, 1, I ni L", () => {
		expect(ALPHABET).toHaveLength(31);
		expect(new Set(ALPHABET).size).toBe(31);
		for (const interdit of "0O1IL") expect(ALPHABET).not.toContain(interdit);
		expect(LONGUEUR_CODE).toBe(6);
	});
});

describe("tirerCode", () => {
	it("tire des codes de 6 caractères de l'alphabet, tous les caractères sortent", () => {
		const vus = new Set();
		for (let i = 0; i < 1000; i++) {
			const code = tirerCode();
			expect(code).toMatch(/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/);
			for (const caractere of code) vus.add(caractere);
		}
		expect(vus.size).toBe(31);
	});

	it("ne tire pas deux fois le même code en 1000 tirages", () => {
		const codes = new Set(Array.from({ length: 1000 }, tirerCode));
		expect(codes.size).toBe(1000);
	});
});

describe("lireCode", () => {
	it("rend le code canonique, en majuscules", () => {
		expect(lireCode("K7Q2XM")).toBe("K7Q2XM");
		expect(lireCode("k7q2xm")).toBe("K7Q2XM");
	});

	it("refuse un code mal formé", () => {
		for (const texte of ["", "K7Q2X", "K7Q2XMM", "K7Q-2XM", "K7Q2X0", "K7Q2XO", "K7Q2X1", "K7Q2XI", "K7Q2XL", "k7q2xl", "K7Q2X ", "K7Q2XM\n"]) {
			expect(lireCode(texte), JSON.stringify(texte)).toBeNull();
		}
	});

	it("refuse les lettres non ASCII que toUpperCase changerait en lettres de l'alphabet", () => {
		expect(lireCode("K7Q2Xſ")).toBeNull(); // s long → S
		expect(lireCode("K7Q2XM")).toBeNull(); // signe kelvin → K
	});

	it("refuse ce qui n'est pas un texte", () => {
		for (const valeur of [null, undefined, 123456, ["K7Q2XM"]]) expect(lireCode(valeur)).toBeNull();
	});
});
```

- [ ] **Step 4 : ils échouent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "Error:|Test Files|Tests "
```

Expected : `Error: Cannot find module '../src/code.js' imported from …/test/code.test.js`, `Test Files  1 failed (1)`, `Tests  no tests`.

- [ ] **Step 5 : les codes**

Créer `signalisation/src/code.js` :

```js
// Les codes de salle : 6 caractères tirés d'un alphabet sans 0/O ni 1/I/L (spec §2).

/** Les 31 caractères d'un code : chiffres 2 à 9, majuscules sans I, L ni O. */
export const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
export const LONGUEUR_CODE = 6;
/** Tirages d'un code avant d'abandonner (erreur quota), quand chaque code tiré a déjà un hôte. */
export const ESSAIS_CODE = 5;

// Sans le drapeau `u`, `i` n'apparie aucun caractère non ASCII à une lettre ASCII (ni « ſ » à S).
const FORME = new RegExp(`^[${ALPHABET}]{${LONGUEUR_CODE}}$`, "i");
// Le plus grand multiple de 31 sous 256 : un octet au-delà est rejeté (tirage sans biais).
const PLAFOND_OCTET = 256 - (256 % ALPHABET.length);

/** Le code canonique (majuscules) de `texte`, ou `null` s'il est mal formé (tiret compris). */
export function lireCode(texte) {
	if (typeof texte !== "string" || !FORME.test(texte)) return null;
	return texte.toUpperCase();
}

/** Un code tiré au hasard (`crypto.getRandomValues`), chaque caractère équiprobable. */
export function tirerCode() {
	const octets = new Uint8Array(LONGUEUR_CODE * 2);
	let code = "";
	while (code.length < LONGUEUR_CODE) {
		crypto.getRandomValues(octets);
		for (const octet of octets) {
			if (octet < PLAFOND_OCTET && code.length < LONGUEUR_CODE) code += ALPHABET[octet % ALPHABET.length];
		}
	}
	return code;
}
```

- [ ] **Step 6 : ils passent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "FAIL|Test Files|Tests "
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' src/*.js test/*.js
```

Expected : `Test Files  1 passed (1)`, `Tests  7 passed (7)` ; rien au `perl`.

- [ ] **Step 7 : Commit**

```bash
cd ~/Sites/LeLion-web
git add signalisation
git status --short
git commit -m "Signalisation : le paquet du Worker (wrangler 4.146.0, vitest 4.1.11, @cloudflare/vitest-plugin 1.3.5, verrou commité), codes de salle (alphabet sans 0/O ni 1/I/L, tirage sans biais, lecture sans casse ni tiret) ; .gdignore : Godot n'importe pas node_modules

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

Expected (`git status`) : 9 fichiers ajoutés (`A`), dont `package-lock.json` et `.gdignore`, aucun sous `node_modules/` ni `.wrangler/`.

---

### Task 2 : le protocole et les serveurs ICE

**Files:**
- Modify: `signalisation/vitest.config.js` (faux secrets TURN, fichier de préparation)
- Create: `signalisation/test/turn.js` (réponse simulée de l'API TURN), `signalisation/test/preparation.js` (l'espion de `fetch`)
- Create: `signalisation/src/protocole.js`, `signalisation/src/ice.js`
- Test: `signalisation/test/ice.test.js`

**Interfaces:**
- Consumes : secrets facultatifs `env.TURN_KEY_ID`, `env.TURN_KEY_API_TOKEN` (absents en local et en CI ; de faux en test).
- Produces (Tasks 3 à 6) :
  - `src/protocole.js` : `ID_HOTE = 1` ; `LIMITES = { SOCKETS: 7, OCTETS: 16384, MESSAGES_PAR_SECONDE: 20, DUREE_SALLE_MS: 14400000 }` ; `PING = '{"t":"ping"}'`, `PONG = '{"t":"pong"}'` (texte exact : le jeu doit envoyer ce texte-là) ; `envoyer(ws, message) -> boolean` ; `fermer(ws, raison)` (code 1000) ; `refuser(raison) -> Response` (101, socket qui dit `{"t":"erreur","raison":…}` puis se ferme) ; `journal(message, details)`. `refuser`, `envoyer` et `fermer` se testent à travers le Worker dès la Task 3.
  - `src/ice.js` : `STUN = ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"]`, `API_TURN = "https://rtc.live.cloudflare.com/v1/turn/keys"`, `DUREE_TURN_S = 7200`, `DELAI_TURN_MS = 3000`, `fabriquerIce(env) -> Promise<Array<{ urls: string[], username?: string, credential?: string }>>` : `[{ urls: STUN }]`, plus les serveurs TURN de l'API (`urls` sans port 53, `username`, `credential`) quand elle répond.
  - `test/turn.js` : `REPONSE_TURN` (la réponse 201 de la documentation, port 53 compris), `ICE_ATTENDU` (ce qu'en reçoit un membre).
  - En test, avant chaque cas : `fetch` est un espion (`vi.mocked(fetch)`) qui sert `REPONSE_TURN` pour `https://rtc.live.cloudflare.com/…` et lève une erreur pour tout autre appel.

- [ ] **Step 1 : les tests**

Remplacer tout `signalisation/vitest.config.js` par :

```js
import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
	plugins: [
		cloudflareTest({
			wrangler: { configPath: "./wrangler.jsonc" },
			// De faux secrets TURN : l'API est simulée par test/preparation.js, jamais appelée pour de vrai.
			miniflare: { bindings: { TURN_KEY_ID: "cle-turn-de-test", TURN_KEY_API_TOKEN: "jeton-turn-de-test" } },
		}),
	],
	test: { setupFiles: ["./test/preparation.js"] },
});
```

Créer `signalisation/test/turn.js` :

```js
// L'API TURN de Cloudflare simulée : sa réponse (celle de sa documentation, port 53 compris) et
// les `iceServers` qu'un membre doit en recevoir.

export const REPONSE_TURN = {
	iceServers: [
		{ urls: ["stun:stun.cloudflare.com:3478", "stun:stun.cloudflare.com:53"] },
		{
			urls: [
				"turn:turn.cloudflare.com:3478?transport=udp",
				"turn:turn.cloudflare.com:53?transport=udp",
				"turn:turn.cloudflare.com:3478?transport=tcp",
				"turns:turn.cloudflare.com:5349?transport=tcp",
				"turns:turn.cloudflare.com:443?transport=tcp",
			],
			username: "nom-turn",
			credential: "secret-turn",
		},
	],
};

export const ICE_ATTENDU = [
	{ urls: ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"] },
	{
		urls: [
			"turn:turn.cloudflare.com:3478?transport=udp",
			"turn:turn.cloudflare.com:3478?transport=tcp",
			"turns:turn.cloudflare.com:5349?transport=tcp",
			"turns:turn.cloudflare.com:443?transport=tcp",
		],
		username: "nom-turn",
		credential: "secret-turn",
	},
];
```

Créer `signalisation/test/preparation.js` :

```js
// Avant chaque test : l'API TURN de Cloudflare simulée par un espion de fetch (aucun appel réseau).
// La salle tourne dans le même isolat que les tests : l'espion la sert aussi. La réponse se fabrique
// à l'appel (une Response créée par le test ne se lit pas depuis un Durable Object).
import { afterEach, beforeEach, vi } from "vitest";
import { REPONSE_TURN } from "./turn.js";

beforeEach(() => {
	vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
		if (String(url).startsWith("https://rtc.live.cloudflare.com/")) return Response.json(REPONSE_TURN, { status: 201 });
		throw new Error(`appel réseau inattendu : ${url}`);
	});
});

afterEach(() => {
	vi.restoreAllMocks();
});
```

Créer `signalisation/test/ice.test.js` :

```js
import { describe, expect, it, vi } from "vitest";
import { API_TURN, DUREE_TURN_S, STUN, fabriquerIce } from "../src/ice.js";
import { ICE_ATTENDU } from "./turn.js";

const SECRETS = { TURN_KEY_ID: "cle/42", TURN_KEY_API_TOKEN: "jeton" };

describe("fabriquerIce", () => {
	it("sans secrets TURN (développement local) : STUN seul, aucun appel", async () => {
		expect(await fabriquerIce({})).toEqual([{ urls: STUN }]);
		expect(await fabriquerIce({ TURN_KEY_ID: "cle" })).toEqual([{ urls: STUN }]);
		expect(fetch).not.toHaveBeenCalled();
	});

	it("avec les secrets : un POST à l'API TURN, identifiants de 2 h, port 53 retiré", async () => {
		expect(await fabriquerIce(SECRETS)).toEqual(ICE_ATTENDU);
		expect(fetch).toHaveBeenCalledTimes(1);
		const [url, init] = vi.mocked(fetch).mock.calls[0];
		expect(url).toBe(`${API_TURN}/cle%2F42/credentials/generate-ice-servers`);
		expect(init.method).toBe("POST");
		expect(init.headers).toEqual({ Authorization: "Bearer jeton", "Content-Type": "application/json" });
		expect(JSON.parse(init.body)).toEqual({ ttl: DUREE_TURN_S });
		expect(DUREE_TURN_S).toBe(7200);
		expect(init.signal).toBeInstanceOf(AbortSignal);
	});

	it("API en erreur, injoignable ou réponse étrange : STUN seul", async () => {
		const reponses = [
			async () => new Response("non", { status: 401 }),
			async () => {
				throw new Error("réseau coupé");
			},
			async () => Response.json({ rien: true }, { status: 201 }),
			async () => Response.json({ iceServers: [{ urls: ["turn:turn.cloudflare.com:53"], username: "u", credential: "c" }] }, { status: 201 }),
			async () => Response.json({ iceServers: [{ urls: ["turn:x"], username: 1, credential: "c" }] }, { status: 201 }),
		];
		for (const reponse of reponses) {
			vi.mocked(fetch).mockImplementationOnce(reponse);
			expect(await fabriquerIce(SECRETS)).toEqual([{ urls: STUN }]);
		}
	});

	it("ne garde que urls, username et credential d'un serveur TURN", async () => {
		vi.mocked(fetch).mockImplementationOnce(async () =>
			Response.json({ iceServers: [{ urls: ["turn:a:3478"], username: "u", credential: "c", autre: "x" }] }, { status: 201 }),
		);
		expect(await fabriquerIce(SECRETS)).toEqual([{ urls: STUN }, { urls: ["turn:a:3478"], username: "u", credential: "c" }]);
	});
});
```

- [ ] **Step 2 : ils échouent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "Error:|Test Files|Tests "
```

Expected : `Error: Cannot find module '../src/ice.js' imported from …/test/ice.test.js`, `Test Files  1 failed | 1 passed (2)`, `Tests  7 passed (7)`.

- [ ] **Step 3 : le protocole**

Créer `signalisation/src/protocole.js` :

```js
// Le protocole de signalisation v1 (spec §4.2, §8.1) : plafonds, messages fixes, envois et refus.

/** L'identifiant de pair de l'hôte (celui de `create_server` dans Godot). */
export const ID_HOTE = 1;

export const LIMITES = Object.freeze({
	/** L'hôte et 6 arrivants en cours. */
	SOCKETS: 7,
	/** Taille d'un message reçu, en octets UTF-8. */
	OCTETS: 16 * 1024,
	/** Messages reçus par seconde et par socket (seau de jetons, 20 d'avance au plus). */
	MESSAGES_PAR_SECONDE: 20,
	/** Durée de vie d'une salle. */
	DUREE_SALLE_MS: 4 * 60 * 60 * 1000,
});

/** Le battement de l'hôte et sa réponse, servis par le runtime sans réveiller la salle (texte exact). */
export const PING = '{"t":"ping"}';
export const PONG = '{"t":"pong"}';

/** Envoie `message` en JSON ; faux si la socket est déjà fermée. */
export function envoyer(ws, message) {
	try {
		ws.send(JSON.stringify(message));
		return true;
	} catch {
		return false;
	}
}

/** Ferme `ws` (code 1000, `raison` en motif) ; sans effet sur une socket déjà fermée. */
export function fermer(ws, raison) {
	try {
		ws.close(1000, raison);
	} catch {
		// déjà fermée
	}
}

/** Une socket acceptée le temps de dire `{t:"erreur", raison}`, puis fermée : la réponse 101 qui la porte. */
export function refuser(raison) {
	const [client, serveur] = Object.values(new WebSocketPair());
	serveur.accept();
	envoyer(serveur, { t: "erreur", raison });
	fermer(serveur, raison);
	return new Response(null, { status: 101, webSocket: client });
}

/** Une ligne de journal structurée (Workers Logs) ; jamais de SDP, de candidat ni d'IP. */
export function journal(message, details = {}) {
	console.log(JSON.stringify({ message, ...details }));
}
```

- [ ] **Step 4 : les serveurs ICE**

Créer `signalisation/src/ice.js` :

```js
// Les serveurs ICE donnés aux membres d'une salle (spec §2, §8.1) : STUN toujours, TURN Cloudflare
// quand les secrets TURN_KEY_ID et TURN_KEY_API_TOKEN existent (absents en local : STUN seul).
import { journal } from "./protocole.js";

export const STUN = ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"];
export const API_TURN = "https://rtc.live.cloudflare.com/v1/turn/keys";
/** Durée de validité des identifiants TURN, en secondes (2 h). */
export const DUREE_TURN_S = 7200;
/** Au-delà, la salle se passe du TURN pour cette fois. */
export const DELAI_TURN_MS = 3000;

// Le port 53 de rechange est bloqué par les navigateurs (documentation TURN de Cloudflare).
const PORT_53 = /:53(\?|$)/;

/** La liste `iceServers` d'un membre : STUN, puis le TURN s'il a pu être fabriqué. */
export async function fabriquerIce(env) {
	const ice = [{ urls: [...STUN] }];
	if (!env.TURN_KEY_ID || !env.TURN_KEY_API_TOKEN) return ice;
	try {
		const reponse = await fetch(`${API_TURN}/${encodeURIComponent(env.TURN_KEY_ID)}/credentials/generate-ice-servers`, {
			method: "POST",
			headers: { Authorization: `Bearer ${env.TURN_KEY_API_TOKEN}`, "Content-Type": "application/json" },
			body: JSON.stringify({ ttl: DUREE_TURN_S }),
			signal: AbortSignal.timeout(DELAI_TURN_MS),
		});
		if (!reponse.ok) {
			await reponse.body?.cancel();
			journal("TURN refusé", { statut: reponse.status });
			return ice;
		}
		const { iceServers } = await reponse.json();
		const turn = Array.isArray(iceServers) ? iceServers.flatMap(serveurTurn) : [];
		if (turn.length === 0) journal("TURN sans identifiants");
		return [...ice, ...turn];
	} catch (erreur) {
		journal("TURN injoignable", { erreur: String(erreur) });
		return ice;
	}
}

/** Un serveur TURN de la réponse de l'API, réduit à ses champs utiles et sans le port 53 ; [] sinon. */
function serveurTurn(serveur) {
	if (typeof serveur?.username !== "string" || typeof serveur.credential !== "string" || !Array.isArray(serveur.urls)) return [];
	const urls = serveur.urls.filter((url) => typeof url === "string" && !PORT_53.test(url));
	return urls.length ? [{ urls, username: serveur.username, credential: serveur.credential }] : [];
}
```

- [ ] **Step 5 : ils passent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "FAIL|Test Files|Tests "
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' src/*.js test/*.js
```

Expected : `Test Files  2 passed (2)`, `Tests  11 passed (11)` ; rien au `perl`.

- [ ] **Step 6 : Commit**

```bash
cd ~/Sites/LeLion-web
git add signalisation
git commit -m "Signalisation : le protocole (plafonds, ping/pong, refus par une socket d'un message, journal sans SDP ni IP) et les serveurs ICE (STUN Cloudflare et Google, TURN Cloudflare à 2 h sans le port 53, STUN seul sans secrets ou si l'API échoue) ; API TURN simulée avant chaque test

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 3 : le Worker et la salle (création, arrivée, départs, battement)

**Files:**
- Create: `signalisation/src/origine.js`, `signalisation/src/salle.js`
- Modify: `signalisation/src/index.js` (réécrit), `signalisation/wrangler.jsonc` (Durable Object `SALLES`, migration SQLite)
- Test: `signalisation/test/aide.js` (outils), `signalisation/test/entree.test.js`, `signalisation/test/salle.test.js`

**Interfaces:**
- Consumes : `src/code.js` (Task 1), `src/protocole.js`, `src/ice.js` (Task 2) ; bindings `SALLES` (Durable Object `Salle`), `ORIGINES` (variable).
- Produces :
  - HTTP du Worker : `GET /v1/creer` et `GET /v1/rejoindre/<code>` (upgrade WebSocket) → 101 ; code mal formé → 400 ; autre chemin → 404 ; autre méthode → 405 (`Allow: GET`) ; sans `Upgrade: websocket` → 426. Origine refusée (absente comprise) → 101 puis `{"t":"erreur","raison":"origine"}` et fermeture ; un appel de salle qui lève, ou 5 codes tirés déjà pris → `erreur` `quota`.
  - Messages (salle → hôte) : `{"t":"salle","code":"K7Q2XM","id":1,"ice":[…]}` puis, à chaque arrivée, `{"t":"arrivee","id":<id>,"ice":[…]}` et, quand un client suivi se ferme, `{"t":"depart","id":<id>}`. (Salle → client) : `{"t":"bienvenue","id":<id>,"ice":[…]}` (même `id`, même `ice` que l'`arrivee`) ; salle sans hôte → `erreur` `inconnue` ; l'hôte parti → `erreur` `inconnue` aux arrivants en cours, puis fermeture, stockage effacé. `{"t":"ping"}` (texte exact) → `{"t":"pong"}` sans réveiller la salle. Fermetures : code 1000, motif = la raison.
  - Interne (Worker → salle) : `GET https://salle/creer?code=<code>` → 101 (hôte accepté) ou 409 (ce code a déjà un hôte) ; `GET https://salle/rejoindre` → 101.
  - `src/origine.js` : `origineAdmise(origine, liste) -> boolean`.
  - `test/aide.js` : `ORIGINE`, `ipAuHasard()`, `requete(chemin, { origine, ip, upgrade, methode })`, `ouvrir(chemin, options) -> { reponse, ws?, fermeture?, envoyer?, fermer?, suivant?(delai), enAttente? }`, `brancher(ws)`, `creerSalle(options) -> { hote, salle, code }`, `arriver(hote, code, options) -> { client, bienvenue, arrivee, id }`, `salleDe(code)`.

- [ ] **Step 1 : les tests**

Créer `signalisation/test/aide.js` :

```js
// Outils des tests : sockets vers le Worker, file des messages reçus, salles prêtes.
import { env, exports } from "cloudflare:workers";

export const ORIGINE = "https://w3cdotorg.github.io";

/** Une IP de test tirée au hasard (10.x.y.z), pour que la limite par IP ne lie pas les tests entre eux. */
export function ipAuHasard() {
	const [a, b, c] = crypto.getRandomValues(new Uint8Array(3));
	return `10.${a}.${b}.${c}`;
}

/** Une requête vers le Worker (WebSocket demandée, origine admise et IP au hasard par défaut). */
export function requete(chemin, { origine = ORIGINE, ip = ipAuHasard(), upgrade = "websocket", methode = "GET" } = {}) {
	const entetes = new Headers({ "cf-connecting-ip": ip });
	if (upgrade) entetes.set("Upgrade", upgrade);
	if (origine) entetes.set("Origin", origine);
	return new Request(`https://signalisation.test${chemin}`, { method: methode, headers: entetes });
}

/** Ouvre une socket : `{ reponse }` seul si le Worker n'a pas répondu 101, sinon la socket branchée. */
export async function ouvrir(chemin, options) {
	const reponse = await exports.default.fetch(requete(chemin, options));
	if (reponse.status !== 101) return { reponse };
	return { reponse, ...brancher(reponse.webSocket) };
}

/** Accepte la socket `ws` côté test et range ses messages (JSON) dans une file. */
export function brancher(ws) {
	const recus = [];
	let reveil = null;
	const fermeture = new Promise((resoudre) => {
		ws.addEventListener("close", (evenement) => resoudre({ code: evenement.code, raison: evenement.reason }));
	});
	ws.addEventListener("message", (evenement) => {
		recus.push(JSON.parse(evenement.data));
		reveil?.();
	});
	ws.accept();
	return {
		ws,
		fermeture,
		envoyer(message) {
			ws.send(typeof message === "string" ? message : JSON.stringify(message));
		},
		fermer() {
			ws.close(1000, "fin du test");
		},
		/** Le prochain message reçu ; rejette au bout de `delai` ms sans message. */
		async suivant(delai = 2000) {
			if (recus.length === 0) {
				await new Promise((resoudre, rejeter) => {
					const minuterie = setTimeout(() => rejeter(new Error(`aucun message en ${delai} ms`)), delai);
					reveil = () => {
						clearTimeout(minuterie);
						reveil = null;
						resoudre();
					};
				});
			}
			return recus.shift();
		},
		/** Les messages déjà reçus et pas encore lus. */
		enAttente() {
			return recus.length;
		},
	};
}

/** Une salle créée : la socket de l'hôte, le message `salle`, le code. */
export async function creerSalle(options) {
	const hote = await ouvrir("/v1/creer", options);
	const salle = await hote.suivant();
	return { hote, salle, code: salle.code };
}

/** Un arrivant dans la salle `code` : sa socket, son `bienvenue`, l'`arrivee` lue chez l'hôte. */
export async function arriver(hote, code, options) {
	const client = await ouvrir(`/v1/rejoindre/${code}`, options);
	const bienvenue = await client.suivant();
	const arrivee = await hote.suivant();
	return { client, bienvenue, arrivee, id: bienvenue.id };
}

/** Le Durable Object de la salle `code`. */
export function salleDe(code) {
	return env.SALLES.get(env.SALLES.idFromName(code));
}
```

Créer `signalisation/test/entree.test.js` :

```js
import { describe, expect, it } from "vitest";
import { ESSAIS_CODE } from "../src/code.js";
import * as principal from "../src/index.js";
import { origineAdmise } from "../src/origine.js";
import { brancher, ouvrir, requete } from "./aide.js";

const ORIGINES = "https://w3cdotorg.github.io,http://localhost:*";

describe("origineAdmise", () => {
	it("admet les origines de la variable ORIGINES, localhost sur tout port", () => {
		for (const origine of ["https://w3cdotorg.github.io", "http://localhost", "http://localhost:8060", "http://localhost:65535"]) {
			expect(origineAdmise(origine, ORIGINES), origine).toBe(true);
		}
	});

	it("refuse le reste, l'origine absente comprise", () => {
		for (const origine of [
			null,
			"",
			"null",
			"https://w3cdotorg.github.io.exemple.net",
			"http://w3cdotorg.github.io",
			"https://w3cdotorg.github.io:443",
			"https://localhost:8060",
			"http://localhost.exemple.net",
			"http://localhost:8060.exemple.net",
			"http://localhost:",
			"http://localhost:abc",
			"http://localhost:123456",
		]) {
			expect(origineAdmise(origine, ORIGINES), String(origine)).toBe(false);
		}
		expect(origineAdmise("https://w3cdotorg.github.io", undefined)).toBe(false);
	});
});

const worker = principal.default;

describe("module principal", () => {
	it("n'exporte que des gestionnaires (workerd refuse de démarrer sinon)", () => {
		expect(Object.keys(principal).sort()).toEqual(["Salle", "default"]);
	});
});

describe("routes du Worker", () => {
	it("404 hors de /v1/creer et /v1/rejoindre/<code>", async () => {
		for (const chemin of ["/", "/v1", "/v1/creer/", "/v2/creer", "/v1/rejoindre"]) {
			const { reponse } = await ouvrir(chemin);
			expect(reponse.status, chemin).toBe(404);
		}
	});

	it("400 pour un code mal formé", async () => {
		for (const code of ["", "K7Q-2XM", "K7Q2X", "K7Q2XO", "K7Q2XM/plus"]) {
			const { reponse } = await ouvrir(`/v1/rejoindre/${code}`);
			expect(reponse.status, code).toBe(400);
		}
	});

	it("405 hors GET, 426 sans demande de WebSocket", async () => {
		// Sans Upgrade : workerd change en GET toute requête qui demande une WebSocket.
		expect((await ouvrir("/v1/creer", { methode: "POST", upgrade: null })).reponse.status).toBe(405);
		const { reponse } = await ouvrir("/v1/creer", { upgrade: null });
		expect(reponse.status).toBe(426);
		expect(reponse.headers.get("Upgrade")).toBe("websocket");
	});

	it("origine refusée : erreur origine puis fermeture, à la création comme à l'arrivée", async () => {
		for (const chemin of ["/v1/creer", "/v1/rejoindre/K7Q2XM"]) {
			for (const origine of [null, "https://exemple.net"]) {
				const socket = await ouvrir(chemin, { origine });
				expect(socket.reponse.status).toBe(101);
				expect(await socket.suivant()).toEqual({ t: "erreur", raison: "origine" });
				expect(await socket.fermeture).toMatchObject({ code: 1000 });
			}
		}
	});
});

describe("quota", () => {
	const envFactice = (salle) => ({
		ORIGINES,
		LIMITE_CREATION: { limit: async () => ({ success: true }) },
		SALLES: { idFromName: (code) => code, get: () => salle },
	});

	async function lireRefus(reponse) {
		expect(reponse.status).toBe(101);
		const socket = brancher(reponse.webSocket);
		return socket.suivant();
	}

	it("une salle qui ne répond pas (quota gratuit épuisé) : erreur quota", async () => {
		const env = envFactice({
			fetch: async () => {
				throw new Error("Exceeded allowed volume of requests in Durable Objects free tier.");
			},
		});
		expect(await lireRefus(await worker.fetch(requete("/v1/creer"), env))).toEqual({ t: "erreur", raison: "quota" });
		expect(await lireRefus(await worker.fetch(requete("/v1/rejoindre/K7Q2XM"), env))).toEqual({ t: "erreur", raison: "quota" });
	});

	it("un nouveau code tant que le code tiré a déjà un hôte, erreur quota au bout des essais", async () => {
		let appels = 0;
		const env = envFactice({
			fetch: async () => {
				appels++;
				return new Response(null, { status: 409 });
			},
		});
		expect(await lireRefus(await worker.fetch(requete("/v1/creer"), env))).toEqual({ t: "erreur", raison: "quota" });
		expect(appels).toBe(ESSAIS_CODE);
	});
});
```

Créer `signalisation/test/salle.test.js` :

```js
import { describe, expect, it, vi } from "vitest";
import { arriver, creerSalle, ouvrir } from "./aide.js";
import { ICE_ATTENDU } from "./turn.js";

const FORME_CODE = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;

describe("création", () => {
	it("l'hôte reçoit salle : un code, l'id 1 et ses serveurs ICE (TURN compris)", async () => {
		const { salle } = await creerSalle();
		expect(salle).toEqual({ t: "salle", code: expect.stringMatching(FORME_CODE), id: 1, ice: ICE_ATTENDU });
	});

	it("deux salles n'ont pas le même code", async () => {
		const a = await creerSalle();
		const b = await creerSalle();
		expect(a.code).not.toBe(b.code);
	});
});

describe("arrivée", () => {
	it("le client reçoit bienvenue, l'hôte arrivee : même id, mêmes identifiants neufs, un appel TURN", async () => {
		const { hote, code } = await creerSalle();
		const appelsAvant = fetch.mock.calls.length;
		const { bienvenue, arrivee } = await arriver(hote, code);
		expect(bienvenue).toEqual({ t: "bienvenue", id: expect.any(Number), ice: ICE_ATTENDU });
		expect(arrivee).toEqual({ t: "arrivee", id: bienvenue.id, ice: ICE_ATTENDU });
		expect(fetch.mock.calls.length - appelsAvant).toBe(1);
	});

	it("des identifiants de pair entiers dans 2..2³¹-1, distincts dans la salle", async () => {
		const { hote, code } = await creerSalle();
		const ids = new Set();
		for (let i = 0; i < 6; i++) {
			const { id, client } = await arriver(hote, code);
			expect(Number.isInteger(id) && id >= 2 && id <= 2 ** 31 - 1, String(id)).toBe(true);
			ids.add(id);
			client.fermer();
			expect(await hote.suivant()).toEqual({ t: "depart", id });
		}
		expect(ids.size).toBe(6);
	});

	it("ni 0, ni 1, ni un id déjà donné dans la salle (même à un client parti)", async () => {
		const { hote, code } = await creerSalle();
		const hasard = crypto.getRandomValues.bind(crypto);
		const tirages = [0, 1, 5, 5, 0x80000005, 7];
		vi.spyOn(crypto, "getRandomValues").mockImplementation((tableau) => {
			if (!(tableau instanceof Uint32Array) || tirages.length === 0) return hasard(tableau);
			tableau[0] = tirages.shift();
			return tableau;
		});
		const premier = await arriver(hote, code);
		expect(premier.id).toBe(5);
		premier.client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id: 5 });
		expect((await arriver(hote, code)).id).toBe(7);
		expect(tirages).toEqual([]);
	});

	it("le code s'accepte en minuscules", async () => {
		const { hote, code } = await creerSalle();
		const { bienvenue } = await arriver(hote, code.toLowerCase());
		expect(bienvenue.t).toBe("bienvenue");
	});

	it("code inconnu : erreur inconnue puis fermeture", async () => {
		const client = await ouvrir("/v1/rejoindre/ZZZZZZ");
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
		expect(await client.fermeture).toMatchObject({ code: 1000 });
	});
});

describe("départs", () => {
	it("un client parti avant ouvert : depart chez l'hôte", async () => {
		const { hote, code } = await creerSalle();
		const { client, id } = await arriver(hote, code);
		client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id });
	});

	it("l'hôte parti : la salle est supprimée, les arrivants en cours reçoivent erreur inconnue", async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		hote.fermer();
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
		expect(await client.fermeture).toMatchObject({ code: 1000 });
		const tard = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await tard.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
	});
});

describe("battement", () => {
	it('{"t":"ping"} reçoit {"t":"pong"}, chez l\'hôte comme chez un client', async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		hote.envoyer('{"t":"ping"}');
		expect(await hote.suivant()).toEqual({ t: "pong" });
		client.envoyer('{"t":"ping"}');
		expect(await client.suivant()).toEqual({ t: "pong" });
	});
});
```

- [ ] **Step 2 : ils échouent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "Error:|Test Files|Tests " | sort | uniq -c
```

Expected : `Error: Cannot find module '../src/origine.js' imported from …/test/entree.test.js` ; neuf `TypeError: hote.suivant is not a function` et un `TypeError: client.suivant is not a function` (le Worker provisoire répond 404 : aucune socket) ; `Failed Tests 10`, `Test Files  2 failed | 2 passed (4)`, `Tests  10 failed | 11 passed (21)`.

- [ ] **Step 3 : l'origine**

Créer `signalisation/src/origine.js` :

```js
// Les origines admises (spec §8.1) : la variable ORIGINES du Worker.

/**
 * Vrai si `origine` (l'en-tête Origin) est dans `liste` (variable ORIGINES : origines séparées par des
 * virgules). Un motif `schéma://hôte:*` admet cet hôte sur tout port, ou sans port. Origine absente :
 * refusée (le jeu livré est l'export Web, dont le navigateur envoie toujours Origin).
 */
export function origineAdmise(origine, liste) {
	if (!origine) return false;
	return (liste ?? "")
		.split(",")
		.map((motif) => motif.trim())
		.filter(Boolean)
		.some((motif) => {
			if (!motif.endsWith(":*")) return origine === motif;
			const base = motif.slice(0, -2);
			return origine === base || (origine.startsWith(`${base}:`) && /^\d{1,5}$/.test(origine.slice(base.length + 1)));
		});
}
```

- [ ] **Step 4 : le Worker**

Remplacer tout `signalisation/src/index.js` par :

```js
// Le point d'entrée du Worker (spec §4.1, §8.1) : les routes /v1 et l'origine, puis la salle
// (Durable Object `Salle`, un par code) qui garde la socket.
// Le module principal n'exporte que des gestionnaires (`default`, `Salle`) : workerd refuse d'en
// démarrer un qui exporte autre chose (constante, fonction).
import { ESSAIS_CODE, lireCode, tirerCode } from "./code.js";
import { origineAdmise } from "./origine.js";
import { journal, refuser } from "./protocole.js";

export { Salle } from "./salle.js";

const CREER = "/v1/creer";
const REJOINDRE = "/v1/rejoindre/";

export default {
	async fetch(requete, env) {
		const { pathname } = new URL(requete.url);
		let code = null;
		if (pathname.startsWith(REJOINDRE)) {
			code = lireCode(pathname.slice(REJOINDRE.length));
			if (code === null) return new Response("code mal formé\n", { status: 400 });
		} else if (pathname !== CREER) {
			return new Response("introuvable\n", { status: 404 });
		}
		if (requete.method !== "GET") return new Response("GET seulement\n", { status: 405, headers: { Allow: "GET" } });
		if (requete.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
			return new Response("WebSocket attendue\n", { status: 426, headers: { Upgrade: "websocket" } });
		}
		const origine = requete.headers.get("Origin");
		if (!origineAdmise(origine, env.ORIGINES)) {
			journal("origine refusée", { origine });
			return refuser("origine");
		}
		return code === null ? creer(requete, env) : rejoindre(requete, env, code);
	},
};

function salle(env, code) {
	return env.SALLES.get(env.SALLES.idFromName(code));
}

/** Un code libre (la salle répond 409 si le sien a déjà un hôte), sa salle crée l'hôte. */
async function creer(requete, env) {
	try {
		for (let essai = 0; essai < ESSAIS_CODE; essai++) {
			const code = tirerCode();
			const reponse = await salle(env, code).fetch(new Request(`https://salle/creer?code=${code}`, requete));
			if (reponse.status !== 409) return reponse;
		}
	} catch (erreur) {
		journal("salle injoignable", { erreur: String(erreur) });
		return refuser("quota");
	}
	journal("aucun code libre", { essais: ESSAIS_CODE });
	return refuser("quota");
}

/** Un Durable Object qui échoue est, sur l'offre gratuite, un quota épuisé (spec §8.1). */
async function rejoindre(requete, env, code) {
	try {
		return await salle(env, code).fetch(new Request("https://salle/rejoindre", requete));
	} catch (erreur) {
		journal("salle injoignable", { erreur: String(erreur) });
		return refuser("quota");
	}
}
```

- [ ] **Step 5 : la salle**

Créer `signalisation/src/salle.js` :

```js
// Une salle (Durable Object, une par code) : l'hôte, les arrivants en cours, le relais entre eux
// (spec §4.2, §4.3, §8.1). Tout son état vit dans les sockets (étiquettes, fiches attachées) et dans
// son stockage SQLite : il survit à l'hibernation, qui ne garde rien en mémoire.
import { DurableObject } from "cloudflare:workers";
import { fabriquerIce } from "./ice.js";
import { ID_HOTE, PING, PONG, envoyer, fermer, refuser } from "./protocole.js";

/** La fiche attachée à une socket (`serializeAttachment`) : rôle, identifiant, fin. */
function nouvelleFiche(role, id) {
	return { role, id, fin: null };
}

export class Salle extends DurableObject {
	constructor(ctx, env) {
		super(ctx, env);
		ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair(PING, PONG));
	}

	async fetch(requete) {
		const url = new URL(requete.url);
		if (url.pathname === "/creer") return this.accueillirHote(url.searchParams.get("code"));
		if (url.pathname === "/rejoindre") return this.accueillirClient();
		return new Response("introuvable\n", { status: 404 });
	}

	/** Les sockets ouvertes que la salle n'a pas oubliées (toutes, ou celles de l'étiquette `tag`). */
	vivantes(tag) {
		return this.ctx.getWebSockets(tag).filter((ws) => ws.readyState === WebSocket.OPEN && !ws.deserializeAttachment()?.fin);
	}

	hote() {
		return this.vivantes("hote")[0] ?? null;
	}

	async accueillirHote(code) {
		if (this.hote()) return new Response("salle occupée\n", { status: 409 });
		const [client, serveur] = Object.values(new WebSocketPair());
		this.ctx.acceptWebSocket(serveur, ["hote"]);
		serveur.serializeAttachment(nouvelleFiche("hote", ID_HOTE));
		this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS pairs (id INTEGER PRIMARY KEY)");
		envoyer(serveur, { t: "salle", code, id: ID_HOTE, ice: await fabriquerIce(this.env) });
		return new Response(null, { status: 101, webSocket: client });
	}

	async accueillirClient() {
		const hote = this.hote();
		if (!hote) return refuser("inconnue");
		const id = this.tirerId();
		const [client, serveur] = Object.values(new WebSocketPair());
		this.ctx.acceptWebSocket(serveur, ["client", String(id)]);
		serveur.serializeAttachment(nouvelleFiche("client", id));
		// Un seul jeu d'identifiants par arrivée, neuf pour l'arrivant comme pour l'hôte (spec §4.2).
		const ice = await fabriquerIce(this.env);
		envoyer(serveur, { t: "bienvenue", id, ice });
		envoyer(hote, { t: "arrivee", id, ice });
		return new Response(null, { status: 101, webSocket: client });
	}

	/** Un identifiant de pair dans 2..2³¹-1, jamais donné dans cette salle (table `pairs`). */
	tirerId() {
		const sql = this.ctx.storage.sql;
		const tirage = new Uint32Array(1);
		for (;;) {
			crypto.getRandomValues(tirage);
			const id = tirage[0] & 0x7fffffff;
			if (id < 2 || sql.exec("SELECT id FROM pairs WHERE id = ?", id).toArray().length > 0) continue;
			sql.exec("INSERT INTO pairs (id) VALUES (?)", id);
			return id;
		}
	}

	async webSocketClose(ws) {
		await this.perdre(ws);
	}

	async webSocketError(ws) {
		await this.perdre(ws);
	}

	/** Une socket fermée de l'autre côté : l'hôte parti ferme la salle, un client suivi part (`depart`). */
	async perdre(ws) {
		const fiche = ws.deserializeAttachment();
		if (!fiche || fiche.fin) return;
		fiche.fin = "parti";
		ws.serializeAttachment(fiche);
		if (fiche.role === "hote") return this.fermerSalle("inconnue");
		const hote = this.hote();
		if (hote) envoyer(hote, { t: "depart", id: fiche.id });
	}

	/** Fin de la salle (hôte parti) : `erreur` puis fermeture pour tous, stockage effacé. */
	async fermerSalle(raison) {
		for (const ws of this.vivantes()) {
			const fiche = ws.deserializeAttachment();
			fiche.fin = raison;
			ws.serializeAttachment(fiche);
			envoyer(ws, { t: "erreur", raison });
			fermer(ws, raison);
		}
		await this.ctx.storage.deleteAll();
	}
}
```

Remplacer tout `signalisation/wrangler.jsonc` par :

```jsonc
{
	"$schema": "./node_modules/wrangler/config-schema.json",
	"name": "lelion-signalisation",
	"main": "src/index.js",
	"compatibility_date": "2026-10-01",
	// Origines admises, séparées par des virgules ; « :* » = tout port (spec §8.1).
	"vars": {
		"ORIGINES": "https://w3cdotorg.github.io,http://localhost:*"
	},
	// Secrets (phase 5, jamais dans le dépôt) : TURN_KEY_ID, TURN_KEY_API_TOKEN. Absents : STUN seul.
	// Une salle par code (idFromName) ; SQLite obligatoire sur l'offre gratuite.
	"durable_objects": {
		"bindings": [{ "name": "SALLES", "class_name": "Salle" }]
	},
	"migrations": [{ "tag": "v1", "new_sqlite_classes": ["Salle"] }],
	"observability": {
		"enabled": true,
		"logs": { "enabled": true, "head_sampling_rate": 1 },
		"traces": { "enabled": true, "head_sampling_rate": 0.05 }
	}
}
```

- [ ] **Step 6 : ils passent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "FAIL|Test Files|Tests "
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' src/*.js test/*.js
```

Expected : `Test Files  4 passed (4)`, `Tests  30 passed (30)` ; rien au `perl`.

- [ ] **Step 7 : Commit**

```bash
cd ~/Sites/LeLion-web
git add signalisation
git commit -m "Signalisation : routes /v1/creer et /v1/rejoindre/<code> (400, 404, 405, 426), origine (ORIGINES, localhost sur tout port, Origin absent refusé), erreur quota quand la salle échoue ; Durable Object Salle (SQLite) : salle, bienvenue, arrivee (un jeu TURN par arrivée), ids uniques dans 2..2³¹-1, depart, salle supprimée au départ de l'hôte, ping/pong automatique ; le module principal n'exporte que ses gestionnaires

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 4 : le relais et `ouvert`

**Files:**
- Modify: `signalisation/src/salle.js` (règles des messages relayés après `nouvelleFiche`, `client(id)` après `hote()`, `webSocketMessage`, `deLHote`, `duClient`, `oublier` avant `webSocketClose`)
- Test: `signalisation/test/relais.test.js`

**Interfaces:**
- Consumes : la salle de la Task 3.
- Produces (phase 4 : `TransportWebRTC`) :
  - Hôte → salle : `{"t":"offre","vers":<id>,"sdp":"…"}`, `{"t":"reponse","vers":<id>,"sdp":"…"}`, `{"t":"candidat","vers":<id>,"media":"…","index":<entier ≥ 0>,"nom":"…"}` → au client `<id>` : le même sans `vers`, avec `"de":1`. Client → salle : les mêmes avec `"vers":1` → à l'hôte, avec `"de":<id du client>`. Les champs sont ceux des signaux `session_description_created(type, sdp)` et `ice_candidate_created(media, index, name)` de `WebRTCPeerConnection`.
  - Hôte → salle : `{"t":"ouvert","id":<id>}` → la salle ferme la socket du client (1000, `ouvert`, sans `erreur`) et ne relaie plus vers lui ; pas de `depart` chez l'hôte.
  - Tout autre message (JSON invalide, binaire, type inconnu, champ en plus ou en moins, mauvais type, `vers` absent, client → client, `ouvert` d'un client) : ignoré, socket ouverte.

- [ ] **Step 1 : les tests**

Créer `signalisation/test/relais.test.js` :

```js
import { describe, expect, it } from "vitest";
import { arriver, creerSalle } from "./aide.js";

const OFFRE = { t: "offre", sdp: "v=0 offre" };
const REPONSE = { t: "reponse", sdp: "v=0 réponse" };
const CANDIDAT = { t: "candidat", media: "0", index: 0, nom: "candidate:1 1 UDP 1 192.0.2.1 9 typ host" };

/** Une salle, son hôte et deux arrivants. */
async function salleADeux() {
	const { hote, code } = await creerSalle();
	const a = await arriver(hote, code);
	const b = await arriver(hote, code);
	return { hote, code, a, b };
}

describe("relais hôte ↔ client", () => {
	it("offre et candidat de l'hôte vers un client : vers devient de", async () => {
		const { hote, a } = await salleADeux();
		hote.envoyer({ ...OFFRE, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...OFFRE, de: 1 });
		hote.envoyer({ ...CANDIDAT, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...CANDIDAT, de: 1 });
	});

	it("réponse et candidat d'un client vers l'hôte : de est l'id du client", async () => {
		const { hote, a } = await salleADeux();
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		a.client.envoyer({ ...CANDIDAT, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...CANDIDAT, de: a.id });
	});

	it("jamais d'un client à un autre", async () => {
		const { hote, a, b } = await salleADeux();
		a.client.envoyer({ ...OFFRE, vers: b.id });
		a.client.envoyer({ ...CANDIDAT, vers: b.id });
		// Le témoin passe après les deux messages refusés (une socket est servie dans l'ordre).
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		hote.envoyer({ ...OFFRE, vers: b.id });
		expect(await b.client.suivant()).toEqual({ ...OFFRE, de: 1 });
	});

	it("vers inconnu, vers l'hôte lui-même : rien n'est relayé", async () => {
		const { hote, a } = await salleADeux();
		hote.envoyer({ ...OFFRE, vers: 1 });
		hote.envoyer({ ...OFFRE, vers: 999 });
		hote.envoyer({ ...OFFRE, vers: String(a.id) });
		hote.envoyer({ ...OFFRE, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...OFFRE, de: 1 });
		expect(hote.enAttente()).toBe(0);
	});
});

describe("validation", () => {
	it("champs attendus seulement, bien typés, types connus : le reste est ignoré sans fermer", async () => {
		const { hote, a } = await salleADeux();
		const refuses = [
			"pas du JSON",
			"[1,2]",
			"null",
			'"offre"',
			{ t: "inconnu", vers: 1 },
			{ t: "constructor", vers: 1 },
			{ t: "__proto__", vers: 1 },
			{ t: "toString", vers: 1 },
			{ t: "offre", vers: 1 },
			{ ...REPONSE, vers: 1, de: 42 },
			{ ...REPONSE, vers: 1, sdp: 12 },
			{ ...CANDIDAT, vers: 1, index: -1 },
			{ ...CANDIDAT, vers: 1, index: 1.5 },
			{ ...CANDIDAT, vers: 1, nom: undefined },
			{ t: "ouvert", id: 1 },
			{ t: "pong" },
		];
		for (const message of refuses) a.client.envoyer(message);
		a.client.ws.send(new Uint8Array([123, 125]));
		a.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: a.id });
		expect(hote.enAttente()).toBe(0);
	});
});

describe("ouvert", () => {
	it("la salle oublie le client et ferme sa socket, sans depart chez l'hôte", async () => {
		const { hote, a, b } = await salleADeux();
		hote.envoyer({ t: "ouvert", id: a.id });
		expect(await a.client.fermeture).toEqual({ code: 1000, raison: "ouvert" });
		expect(a.client.enAttente()).toBe(0);
		hote.envoyer({ ...OFFRE, vers: a.id });
		b.client.envoyer({ ...REPONSE, vers: 1 });
		expect(await hote.suivant()).toEqual({ ...REPONSE, de: b.id });
	});

	it("ouvert mal formé ou d'un client : ignoré", async () => {
		const { hote, a } = await salleADeux();
		hote.envoyer({ t: "ouvert", id: String(a.id) });
		hote.envoyer({ t: "ouvert", id: a.id, en_plus: true });
		a.client.envoyer({ t: "ouvert", id: a.id });
		hote.envoyer({ ...OFFRE, vers: a.id });
		expect(await a.client.suivant()).toEqual({ ...OFFRE, de: 1 });
	});
});
```

- [ ] **Step 2 : ils échouent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "Error:|Test Files|Tests " | sort | uniq -c
```

Expected : `Error: aucun message en 2000 ms` (vitest regroupe sous un seul message les six échecs identiques : rien n'est relayé) et `Error: Test timed out in 5000ms.` (`ouvert` ne ferme rien) ; `Failed Tests 7`, `Test Files  1 failed | 4 passed (5)`, `Tests  7 failed | 30 passed (37)`.

- [ ] **Step 3 : le relais**

Dans `signalisation/src/salle.js`, remplacer :

```js
/** La fiche attachée à une socket (`serializeAttachment`) : rôle, identifiant, fin. */
function nouvelleFiche(role, id) {
	return { role, id, fin: null };
}
```

par :

```js
/** La fiche attachée à une socket (`serializeAttachment`) : rôle, identifiant, fin. */
function nouvelleFiche(role, id) {
	return { role, id, fin: null };
}

const estTexte = (valeur) => typeof valeur === "string";
const estIndex = (valeur) => Number.isInteger(valeur) && valeur >= 0;

/** Les champs de chaque message relayé, en plus de `t` et `vers` : aucun autre n'est admis. */
const RELAYES = {
	offre: { sdp: estTexte },
	reponse: { sdp: estTexte },
	candidat: { media: estTexte, index: estIndex, nom: estTexte },
};

/** Le message décodé s'il est un objet JSON à champ `t` texte, sinon `null`. */
function lire(message) {
	if (typeof message !== "string") return null;
	try {
		const objet = JSON.parse(message);
		return objet !== null && typeof objet === "object" && !Array.isArray(objet) && estTexte(objet.t) ? objet : null;
	} catch {
		return null;
	}
}

/** Vrai si `m` a exactement les champs `t`, `vers` (entier) et ceux de son type, bien typés. */
function relayable(m) {
	const champs = Object.hasOwn(RELAYES, m.t) ? RELAYES[m.t] : null; // ni « constructor » ni « __proto__ »
	if (!champs || !Number.isInteger(m.vers)) return false;
	const noms = Object.keys(m);
	if (noms.length !== Object.keys(champs).length + 2) return false;
	return noms.every((nom) => nom === "t" || nom === "vers" || (Object.hasOwn(champs, nom) && champs[nom](m[nom])));
}
```

Dans `signalisation/src/salle.js`, remplacer :

```js
	hote() {
		return this.vivantes("hote")[0] ?? null;
	}
```

par :

```js
	hote() {
		return this.vivantes("hote")[0] ?? null;
	}

	/** Le client `id` encore suivi par la salle, ou `null`. */
	client(id) {
		return this.vivantes(String(id)).find((ws) => ws.deserializeAttachment().role === "client") ?? null;
	}
```

Dans `signalisation/src/salle.js`, remplacer :

```js
	async webSocketClose(ws) {
```

par :

```js
	async webSocketMessage(ws, message) {
		const fiche = ws.deserializeAttachment();
		if (!fiche || fiche.fin) return;
		const m = lire(message);
		if (m === null) return;
		if (fiche.role === "hote") this.deLHote(m);
		else this.duClient(fiche, m);
	}

	/** `ouvert` (la salle oublie ce client), ou un relais vers un client suivi ; le reste est ignoré. */
	deLHote(m) {
		if (m.t === "ouvert") {
			if (Object.keys(m).length !== 2 || !Number.isInteger(m.id)) return;
			const client = this.client(m.id);
			if (client) this.oublier(client, "ouvert");
			return;
		}
		if (!relayable(m)) return;
		const client = this.client(m.vers);
		const { vers, ...contenu } = m;
		if (client) envoyer(client, { ...contenu, de: ID_HOTE });
	}

	/** Un relais vers l'hôte seulement, jamais vers un autre client ; le reste est ignoré. */
	duClient(fiche, m) {
		if (!relayable(m) || m.vers !== ID_HOTE) return;
		const hote = this.hote();
		const { vers, ...contenu } = m;
		if (hote) envoyer(hote, { ...contenu, de: fiche.id });
	}

	/** La salle ne suit plus le client `ws` (`ouvert`, ou chassé) et le ferme ; `depart` à l'hôte sauf après `ouvert`. */
	oublier(ws, raison) {
		const fiche = ws.deserializeAttachment();
		fiche.fin = raison;
		ws.serializeAttachment(fiche);
		if (raison !== "ouvert") {
			envoyer(ws, { t: "erreur", raison });
			const hote = this.hote();
			if (hote) envoyer(hote, { t: "depart", id: fiche.id });
		}
		fermer(ws, raison);
	}

	async webSocketClose(ws) {
```

- [ ] **Step 4 : ils passent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "FAIL|Test Files|Tests "
```

Expected : `Test Files  5 passed (5)`, `Tests  37 passed (37)`.

- [ ] **Step 5 : Commit**

```bash
cd ~/Sites/LeLion-web
git add signalisation
git commit -m "Signalisation : relais offre/reponse/candidat entre l'hôte et un client seulement (vers devient de, posé par la salle ; champs attendus seulement ; le reste ignoré sans fermer) ; ouvert : la salle oublie le client et ferme sa socket, sans depart

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 5 : les plafonds et la limite par IP

**Files:**
- Modify: `signalisation/src/salle.js` (import, seau de jetons et taille après `nouvelleFiche`, `pleine` dans `accueillirClient`, plafonds dans `webSocketMessage`, `chasser`)
- Modify: `signalisation/src/index.js` (en-tête, limite de création dans `creer`)
- Modify: `signalisation/wrangler.jsonc` (binding `ratelimits` `LIMITE_CREATION`, 5 par 60 s)
- Test: `signalisation/test/plafonds.test.js`

**Interfaces:**
- Consumes : `LIMITES`, `journal` (Task 2) ; binding `env.LIMITE_CREATION.limit({ key }) -> Promise<{ success: boolean }>` (`ratelimits`, période de 10 ou 60 s seulement).
- Produces :
  - 8e socket d'une salle (l'hôte et 6 arrivants en cours, `ouvert` et départs rendent la place) → `erreur` `pleine` puis fermeture.
  - Message de plus de 16 384 octets UTF-8, ou au-delà de 20 messages par seconde (seau de 20 jetons, 20 rendus par seconde, dans la fiche) → `erreur` `debit` puis fermeture ; pour un client, `depart` chez l'hôte ; pour l'hôte, la salle se ferme (`erreur` `inconnue` aux arrivants). `{"t":"ping"}` ne compte pas (servi par le runtime).
  - 6e `GET /v1/creer` d'une même IP (`cf-connecting-ip`) dans la minute → `erreur` `debit` (journal : « trop de salles créées par cette IP »).
  - Pour la phase 4 : la socket de l'hôte porte offres et candidats de tous les arrivants ; plusieurs arrivées simultanées (une dizaine de candidats chacune avec STUN et TURN) dépasseraient 20 messages par seconde et fermeraient la salle. `TransportWebRTC` espace donc ses envois de signalisation (file, 15 par seconde au plus), et le test Playwright à 3 pages le vérifie.

- [ ] **Step 1 : les tests**

Créer `signalisation/test/plafonds.test.js` :

```js
import { describe, expect, it } from "vitest";
import { arriver, creerSalle, ouvrir } from "./aide.js";

const REPONSE = { t: "reponse", vers: 1, sdp: "v=0" };

/** Un message `reponse` dont le JSON fait exactement `octets` octets UTF-8, en `motif` répété. */
function reponseDe(octets, motif = "a") {
	const vide = JSON.stringify({ ...REPONSE, sdp: "" });
	const largeur = new TextEncoder().encode(motif).length;
	return JSON.stringify({ ...REPONSE, sdp: motif.repeat(Math.floor((octets - vide.length) / largeur)) });
}

describe("7 sockets par salle", () => {
	it("l'hôte et 6 arrivants ; le 7e arrivant reçoit erreur pleine, une place libérée resert", async () => {
		const { hote, code } = await creerSalle();
		const arrivants = [];
		for (let i = 0; i < 6; i++) arrivants.push(await arriver(hote, code));
		const refuse = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await refuse.suivant()).toEqual({ t: "erreur", raison: "pleine" });
		expect(await refuse.fermeture).toMatchObject({ code: 1000 });
		hote.envoyer({ t: "ouvert", id: arrivants[0].id });
		await arrivants[0].client.fermeture;
		expect((await arriver(hote, code)).bienvenue.t).toBe("bienvenue");
		arrivants[1].client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id: arrivants[1].id });
		expect((await arriver(hote, code)).bienvenue.t).toBe("bienvenue");
	});
});

describe("16 Ko par message", () => {
	it("16 384 octets passent, un de plus : erreur debit, fermeture, depart chez l'hôte", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		const juste = reponseDe(16384);
		expect(new TextEncoder().encode(juste).length).toBe(16384);
		a.client.envoyer(juste);
		expect((await hote.suivant()).t).toBe("reponse");
		a.client.envoyer(reponseDe(16385));
		expect(await a.client.suivant()).toEqual({ t: "erreur", raison: "debit" });
		expect(await a.client.fermeture).toEqual({ code: 1000, raison: "debit" });
		expect(await hote.suivant()).toEqual({ t: "depart", id: a.id });
	});

	it("la taille se compte en octets UTF-8, pas en caractères", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		const lourd = reponseDe(16386, "é");
		expect(lourd.length).toBeLessThan(16384);
		a.client.envoyer(lourd);
		expect(await a.client.suivant()).toEqual({ t: "erreur", raison: "debit" });
	});
});

describe("20 messages par seconde et par socket", () => {
	it("20 d'affilée passent ; une seconde plus tard, 20 de plus", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		for (let tour = 0; tour < 2; tour++) {
			for (let i = 0; i < 20; i++) a.client.envoyer(REPONSE);
			for (let i = 0; i < 20; i++) expect((await hote.suivant()).t).toBe("reponse");
			await new Promise((resoudre) => setTimeout(resoudre, 1050));
		}
		expect(a.client.enAttente()).toBe(0);
	});

	it("au-delà : erreur debit, fermeture, depart chez l'hôte", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		for (let i = 0; i < 30; i++) a.client.envoyer(REPONSE);
		expect(await a.client.suivant()).toEqual({ t: "erreur", raison: "debit" });
		expect(await a.client.fermeture).toEqual({ code: 1000, raison: "debit" });
		let relayes = 0;
		for (let m = await hote.suivant(); m.t !== "depart"; m = await hote.suivant()) relayes++;
		expect(relayes).toBeGreaterThanOrEqual(20);
		expect(relayes).toBeLessThan(30);
	});

	it("un hôte au-delà : erreur debit chez lui, la salle se ferme (erreur inconnue aux arrivants)", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		for (let i = 0; i < 30; i++) hote.envoyer({ t: "offre", vers: a.id, sdp: "v=0" });
		let m = await hote.suivant();
		expect(m).toEqual({ t: "erreur", raison: "debit" });
		for (m = await a.client.suivant(); m.t === "offre"; m = await a.client.suivant());
		expect(m).toEqual({ t: "erreur", raison: "inconnue" });
		const tard = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await tard.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
	});

	it("le battement ne compte pas : 50 ping de suite reçoivent 50 pong", async () => {
		const { hote } = await creerSalle();
		for (let i = 0; i < 50; i++) hote.envoyer('{"t":"ping"}');
		for (let i = 0; i < 50; i++) expect(await hote.suivant()).toEqual({ t: "pong" });
	});
});

describe("limite de création par IP", () => {
	it("5 salles par minute et par IP, la 6e reçoit erreur debit ; une autre IP crée encore", async () => {
		// Les fenêtres de la limitation locale sont calées sur la minute de l'horloge : ne pas en chevaucher deux.
		const reste = 60000 - (Date.now() % 60000);
		if (reste < 10000) await new Promise((resoudre) => setTimeout(resoudre, reste + 100));
		const ip = "203.0.113.7";
		for (let i = 0; i < 5; i++) expect((await creerSalle({ ip })).salle.t).toBe("salle");
		const sixieme = await ouvrir("/v1/creer", { ip });
		expect(await sixieme.suivant()).toEqual({ t: "erreur", raison: "debit" });
		expect((await creerSalle({ ip: "203.0.113.8" })).salle.t).toBe("salle");
	}, 20000);
});
```

- [ ] **Step 2 : ils échouent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "FAIL|Test Files|Tests "
```

Expected : six `FAIL  test/plafonds.test.js` (7 sockets, les deux de 16 Ko, « au-delà », « un hôte au-delà », la limite par IP) ; « 20 d'affilée passent » et « le battement ne compte pas » passent déjà (gardes) ; `Test Files  1 failed | 5 passed (6)`, `Tests  6 failed | 39 passed (45)`.

- [ ] **Step 3 : les plafonds de la salle**

Dans `signalisation/src/salle.js`, remplacer :

```js
import { ID_HOTE, PING, PONG, envoyer, fermer, refuser } from "./protocole.js";
```

par :

```js
import { ID_HOTE, LIMITES, PING, PONG, envoyer, fermer, journal, refuser } from "./protocole.js";
```

Dans `signalisation/src/salle.js`, remplacer :

```js
/** La fiche attachée à une socket (`serializeAttachment`) : rôle, identifiant, fin. */
function nouvelleFiche(role, id) {
	return { role, id, fin: null };
}
```

par :

```js
/** La fiche attachée à une socket (`serializeAttachment`) : rôle, identifiant, seau de jetons, fin. */
function nouvelleFiche(role, id) {
	return { role, id, jetons: LIMITES.MESSAGES_PAR_SECONDE, instant: Date.now(), fin: null };
}

/** Prend un jeton du seau de `fiche` (rempli de 20 par seconde, 20 au plus) ; faux s'il est vide. */
function prendreJeton(fiche, maintenant) {
	const debit = LIMITES.MESSAGES_PAR_SECONDE;
	fiche.jetons = Math.min(debit, fiche.jetons + ((maintenant - fiche.instant) * debit) / 1000);
	fiche.instant = maintenant;
	if (fiche.jetons < 1) return false;
	fiche.jetons -= 1;
	return true;
}

/** Taille de `message` en octets (UTF-8 pour un texte). */
function taille(message) {
	if (typeof message !== "string") return message.byteLength;
	if (message.length > LIMITES.OCTETS) return message.length; // au moins un octet par unité UTF-16
	return new TextEncoder().encode(message).length;
}
```

Dans `signalisation/src/salle.js`, remplacer :

```js
		if (!hote) return refuser("inconnue");
		const id = this.tirerId();
```

par :

```js
		if (!hote) return refuser("inconnue");
		if (this.vivantes().length >= LIMITES.SOCKETS) return refuser("pleine");
		const id = this.tirerId();
```

Dans `signalisation/src/salle.js`, remplacer :

```js
		if (!fiche || fiche.fin) return;
		const m = lire(message);
```

par :

```js
		if (!fiche || fiche.fin) return;
		if (!prendreJeton(fiche, Date.now()) || taille(message) > LIMITES.OCTETS) return this.chasser(ws, fiche, "debit");
		ws.serializeAttachment(fiche);
		const m = lire(message);
```

Dans `signalisation/src/salle.js`, remplacer :

```js
	async webSocketClose(ws) {
```

par :

```js
	/** Une socket au-delà d'un plafond : un client est oublié, un hôte ferme la salle. */
	async chasser(ws, fiche, raison) {
		journal("plafond dépassé", { role: fiche.role, raison });
		if (fiche.role === "client") return this.oublier(ws, raison);
		fiche.fin = raison;
		ws.serializeAttachment(fiche);
		envoyer(ws, { t: "erreur", raison });
		fermer(ws, raison);
		await this.fermerSalle("inconnue");
	}

	async webSocketClose(ws) {
```

- [ ] **Step 4 : la limite par IP**

Dans `signalisation/src/index.js`, remplacer :

```js
// Le point d'entrée du Worker (spec §4.1, §8.1) : les routes /v1 et l'origine, puis la salle
// (Durable Object `Salle`, un par code) qui garde la socket.
```

par :

```js
// Le point d'entrée du Worker (spec §4.1, §8.1) : les routes /v1, l'origine, la limite de création
// par IP, puis la salle (Durable Object `Salle`, un par code) qui garde la socket.
```

Dans `signalisation/src/index.js`, remplacer :

```js
async function creer(requete, env) {
	try {
```

par :

```js
async function creer(requete, env) {
	const { success } = await env.LIMITE_CREATION.limit({ key: requete.headers.get("cf-connecting-ip") ?? "local" });
	if (!success) {
		journal("trop de salles créées par cette IP");
		return refuser("debit");
	}
	try {
```

Dans `signalisation/wrangler.jsonc`, remplacer :

```jsonc
	"migrations": [{ "tag": "v1", "new_sqlite_classes": ["Salle"] }],
```

par :

```jsonc
	"migrations": [{ "tag": "v1", "new_sqlite_classes": ["Salle"] }],
	// Limitation de débit des Workers : 5 créations par minute et par IP, par point de présence.
	// namespace_id : entier propre au compte (phase 5 : le changer s'il est déjà pris).
	"ratelimits": [
		{
			"name": "LIMITE_CREATION",
			"namespace_id": "1001",
			"simple": { "limit": 5, "period": 60 }
		}
	],
```

- [ ] **Step 5 : ils passent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "FAIL|Test Files|Tests "
```

Expected : `Test Files  6 passed (6)`, `Tests  45 passed (45)` (de 4 à 15 s : le test de la limite par IP attend jusqu'à 10 s s'il tombe à la fin d'une minute de l'horloge).

- [ ] **Step 6 : Commit**

```bash
cd ~/Sites/LeLion-web
git add signalisation
git commit -m "Signalisation : plafonds (7 sockets, 16 Ko en octets UTF-8, 20 messages par seconde en seau de jetons, ping exempté ; un hôte au-delà ferme sa salle) et 5 créations par minute et par IP (binding ratelimits)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 6 : l'expiration à 4 h et l'hibernation

**Files:**
- Modify: `signalisation/src/salle.js` (alarme dans `accueillirHote`, commentaire de `fermerSalle`, `alarm()`)
- Test: `signalisation/test/vie.test.js`

**Interfaces:**
- Consumes : `LIMITES.DUREE_SALLE_MS`, `journal`.
- Produces : 4 h après sa création, la salle envoie `{"t":"erreur","raison":"expiree"}` à tous, ferme leurs sockets (1000, `expiree`) et efface son stockage ; ensuite, `rejoindre` ce code → `erreur` `inconnue`. L'hôte parti efface l'alarme avec le reste (`deleteAll`). La phase 3 affiche « Salle expirée : crée une nouvelle partie pour inviter » sur `expiree`.

- [ ] **Step 1 : les tests**

Créer `signalisation/test/vie.test.js` :

```js
import { evictDurableObject, runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { arriver, creerSalle, ouvrir, salleDe } from "./aide.js";

const QUATRE_HEURES = 4 * 60 * 60 * 1000;

/** L'alarme de la salle `code` et le nombre de ses tables SQLite à nous (`pairs`). */
async function etat(code) {
	return runInDurableObject(salleDe(code), async (_salle, ctx) => ({
		alarme: await ctx.storage.getAlarm(),
		tables: ctx.storage.sql.exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pairs'").toArray().length,
	}));
}

describe("expiration à 4 h", () => {
	it("la création pose l'alarme à 4 h", async () => {
		const avant = Date.now();
		const { code } = await creerSalle();
		const { alarme } = await etat(code);
		expect(alarme).toBeGreaterThanOrEqual(avant + QUATRE_HEURES);
		expect(alarme).toBeLessThanOrEqual(Date.now() + QUATRE_HEURES);
	});

	it("l'alarme ferme la salle : erreur expiree à tous, stockage effacé, plus d'arrivée", async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		expect(await runDurableObjectAlarm(salleDe(code))).toBe(true);
		expect(await hote.suivant()).toEqual({ t: "erreur", raison: "expiree" });
		expect(await hote.fermeture).toEqual({ code: 1000, raison: "expiree" });
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "expiree" });
		expect(await etat(code)).toEqual({ alarme: null, tables: 0 });
		const tard = await ouvrir(`/v1/rejoindre/${code}`);
		expect(await tard.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
	});

	it("l'hôte parti efface l'alarme et le stockage", async () => {
		const { hote, code } = await creerSalle();
		const { client } = await arriver(hote, code);
		hote.fermer();
		expect(await client.suivant()).toEqual({ t: "erreur", raison: "inconnue" });
		await expect.poll(() => etat(code)).toEqual({ alarme: null, tables: 0 });
	});
});

describe("hibernation", () => {
	it("évincée de la mémoire, la salle garde ses membres, leurs ids et le relais", async () => {
		const { hote, code } = await creerSalle();
		const a = await arriver(hote, code);
		await evictDurableObject(salleDe(code));
		hote.envoyer({ t: "offre", vers: a.id, sdp: "v=0" });
		expect(await a.client.suivant()).toEqual({ t: "offre", de: 1, sdp: "v=0" });
		a.client.envoyer({ t: "reponse", vers: 1, sdp: "v=0" });
		expect(await hote.suivant()).toEqual({ t: "reponse", de: a.id, sdp: "v=0" });
		hote.envoyer('{"t":"ping"}');
		expect(await hote.suivant()).toEqual({ t: "pong" });
		const b = await arriver(hote, code);
		expect(b.id).not.toBe(a.id);
		a.client.fermer();
		expect(await hote.suivant()).toEqual({ t: "depart", id: a.id });
	});
});
```

- [ ] **Step 2 : ils échouent**

```bash
cd ~/Sites/LeLion-web/signalisation && npm test 2>&1 | grep -E "FAIL|Error:|Test Files|Tests "
```

Expected : `FAIL … la création pose l'alarme à 4 h` (`TypeError: actual value must be number or bigint, received "object"` : pas d'alarme), `FAIL … l'alarme ferme la salle …` (`expected false to be true`) ; « l'hôte parti efface l'alarme et le stockage » et le test d'hibernation passent déjà (gardes) ; `Test Files  1 failed | 6 passed (7)`, `Tests  2 failed | 47 passed (49)`.

- [ ] **Step 3 : l'alarme**

Dans `signalisation/src/salle.js`, remplacer :

```js
		this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS pairs (id INTEGER PRIMARY KEY)");
		envoyer(serveur, { t: "salle", code, id: ID_HOTE, ice: await fabriquerIce(this.env) });
```

par :

```js
		this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS pairs (id INTEGER PRIMARY KEY)");
		await this.ctx.storage.setAlarm(Date.now() + LIMITES.DUREE_SALLE_MS);
		envoyer(serveur, { t: "salle", code, id: ID_HOTE, ice: await fabriquerIce(this.env) });
```

Dans `signalisation/src/salle.js`, remplacer :

```js
	/** Fin de la salle (hôte parti) : `erreur` puis fermeture pour tous, stockage effacé. */
```

par :

```js
	/**
	 * Fin de la salle (hôte parti, expiration) : `erreur` puis fermeture pour tous, stockage effacé,
	 * alarme comprise (deleteAll l'efface depuis la date de compatibilité 2026-02-24).
	 */
```

Dans `signalisation/src/salle.js`, remplacer :

```js
		await this.ctx.storage.deleteAll();
	}
}
```

par :

```js
		await this.ctx.storage.deleteAll();
	}

	/** 4 h après la création : la salle ferme (la partie continue en WebRTC, plus personne n'arrive). */
	async alarm() {
		journal("salle expirée");
		await this.fermerSalle("expiree");
	}
}
```

- [ ] **Step 4 : ils passent, trois fois**

```bash
cd ~/Sites/LeLion-web/signalisation
for i in 1 2 3; do npm test 2>&1 | grep -E "FAIL|Test Files|Tests "; done
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' src/*.js test/*.js
wc -l src/*.js | tail -1
```

Expected : trois fois `Test Files  7 passed (7)`, `Tests  49 passed (49)` ; rien au `perl` ; `440 total`.

- [ ] **Step 5 : Commit**

```bash
cd ~/Sites/LeLion-web
git add signalisation
git commit -m "Signalisation : la salle expire à 4 h (alarme, erreur expiree à tous, stockage effacé) ; tests de la vie de la salle (alarme posée et effacée, hibernation : membres, ids et relais gardés après éviction)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 7 : la spec (le protocole tel qu'il est, les faits vérifiés)

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md` (§3.1 ligne `signalisation/`, §4.1, §4.2 lignes du relais, d'`ouvert` et d'`erreur`, §4.3 point 4, §8.1, §13)

**Interfaces:** aucune (documentation).

- [ ] **Step 1 : la vérification d'abord (elle échoue)**

```bash
cd ~/Sites/LeLion-web
f=docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
grep -c "expiree" $f; grep -c "generate-ice-servers" $f; grep -c "À vérifier en phase 2" $f
```

Expected : `0`, `0`, `1`.

- [ ] **Step 2 : §3.1 et §4**

Dans la spec, remplacer :

```markdown
| `signalisation/` (Worker + Durable Object `Salle`, JavaScript) | Crée les salles, relaie offres, réponses et candidats entre l'hôte et chaque arrivant, fournit les identifiants TURN, applique les plafonds (§8). Ne lit pas le contenu WebRTC. Environ 150 lignes, avec ses tests `vitest`. | API TURN de Cloudflare |
```

par :

```markdown
| `signalisation/` (Worker + Durable Object `Salle`, JavaScript) | Crée les salles, relaie offres, réponses et candidats entre l'hôte et chaque arrivant, fournit les identifiants TURN, applique les plafonds (§8). Ne lit pas le contenu WebRTC. Six modules (`index`, `origine`, `code`, `protocole`, `ice`, `salle`, environ 440 lignes), avec ses tests `vitest` dans l'environnement local de Cloudflare (`@cloudflare/vitest-plugin`). | API TURN de Cloudflare |
```

Dans la spec, remplacer :

```markdown
- `GET /v1/rejoindre/<code>` (upgrade WebSocket) : un arrivant. Code mal formé : 400 ; salle sans
  hôte : message `erreur` `inconnue` puis fermeture.
```

par :

```markdown
- `GET /v1/rejoindre/<code>` (upgrade WebSocket) : un arrivant. Code mal formé : 400 (le code s'y
  écrit sans tiret, en majuscules ou en minuscules) ; salle sans hôte : message `erreur` `inconnue`
  puis fermeture.
- Les autres refus (origine, débit, quota, salle pleine) passent eux aussi par une socket acceptée
  le temps d'un message `erreur` : un navigateur ne montre pas au jeu le statut HTTP d'une WebSocket
  refusée. Hors de ces deux chemins : 404 ; autre méthode que GET : 405 ; sans upgrade : 426.
```

Dans la spec, remplacer :

```markdown
| Hôte ↔ client (relayé) | `{t:"offre"\|"reponse"\|"candidat", vers, …}` | La salle vérifie que `vers` est membre, remplace l'émetteur par `de` et relaie. Seulement entre l'hôte et un client, jamais entre deux clients. |
```

par :

```markdown
| Hôte ↔ client (relayé) | `{t:"offre"\|"reponse", vers, sdp}`, `{t:"candidat", vers, media, index, nom}` | La salle vérifie que `vers` est membre, remplace l'émetteur par `de` et relaie (`{t, de, sdp}`, `{t, de, media, index, nom}` : les champs des signaux de `WebRTCPeerConnection`). Seulement entre l'hôte et un client, jamais entre deux clients. Un message invalide (type inconnu, champ en plus ou en moins, mauvais type, `vers` absent de la salle) est ignoré, sans fermer la socket. |
```

Dans la spec, remplacer :

```markdown
| Hôte → salle | `{t:"ouvert", id}` | Le canal WebRTC avec `id` est ouvert : la salle oublie ce client (il ferme sa socket de son côté). |
```

par :

```markdown
| Hôte → salle | `{t:"ouvert", id}` | Le canal WebRTC avec `id` est ouvert : la salle oublie ce client et ferme sa socket (code 1000, motif `ouvert`, sans `erreur` : le client ne la prend pas pour un échec). |
```

Dans la spec, remplacer :

```markdown
| Salle → tous | `{t:"erreur", raison}` puis fermeture | `inconnue`, `pleine`, `debit`, `quota`, `origine`. |
```

par :

```markdown
| Salle → tous | `{t:"erreur", raison}` puis fermeture | `inconnue`, `pleine`, `debit`, `quota`, `origine`, `expiree` (§4.3, point 4). Fermeture : code 1000, la raison en motif. |
```

Dans la spec, remplacer :

```markdown
4. Une salle vit **4 h au plus**, puis la salle ferme toutes ses sockets (la partie en cours continue
```

par :

```markdown
4. Une salle vit **4 h au plus** (alarme du Durable Object), puis elle envoie `erreur` `expiree` et
   ferme toutes ses sockets (la partie en cours continue
```

- [ ] **Step 3 : §8.1 et §13**

Dans la spec, remplacer :

```markdown
- **Origine** : WebSocket acceptée seulement depuis `https://w3cdotorg.github.io` et
  `http://localhost:*` (variable du Worker). Ça freine le pillage, ça ne protège pas seul.
- **Plafonds par salle** : 7 sockets (l'hôte et 6 arrivants en cours) ; messages de 16 Ko au plus ;
  20 messages par seconde et par socket ; au-delà, `erreur` puis fermeture.
- **Limite par IP** : quelques salles créées par minute et par IP (`cf-connecting-ip`), par la
  limitation de débit des Workers (`ratelimit`) si elle est disponible sur l'offre gratuite, sinon
  par un Durable Object compteur. À vérifier en phase 2.
- **Validation** : type de message connu, `vers` membre de la salle, champs attendus seulement ; le
  contenu SDP n'est ni lu ni journalisé.
- **TURN** : la clé TURN et le jeton d'API restent dans les secrets du Worker ; identifiants à 2 h,
  donnés seulement par `salle`, `bienvenue` et `arrivee`.
- **Coût** : Durable Object en hibernation de WebSocket (pas de durée facturée pour une socket
  inactive) ; quota gratuit dépassé : `erreur quota`, le jeu dit « Trop de parties en ce moment,
  réessaie plus tard. ».
```

par :

```markdown
- **Origine** : WebSocket acceptée seulement depuis `https://w3cdotorg.github.io` et
  `http://localhost:*` (variable du Worker `ORIGINES` ; `:*` = tout port ou aucun). Ça freine le
  pillage, ça ne protège pas seul. Sans en-tête `Origin` : refusée (le jeu livré est l'export Web,
  dont le navigateur l'envoie toujours ; le desktop de développement joue en ENet).
- **Plafonds par salle** : 7 sockets (l'hôte et 6 arrivants en cours) ; messages de 16 Ko au plus
  (16 384 octets UTF-8) ; 20 messages par seconde et par socket (seau de jetons de 20, rempli de 20
  par seconde, gardé dans la fiche de la socket) ; au-delà, `erreur` puis fermeture (`pleine` pour
  la 8e socket, `debit` pour la taille et le débit ; un hôte au-delà ferme sa salle). Le `ping`, servi
  par le runtime, ne compte pas.
- **Limite par IP** : 5 salles créées par minute et par IP (`cf-connecting-ip`), par la limitation de
  débit des Workers (binding `ratelimits`, générale depuis le 19/09/2025, simulée par Miniflare en
  local et testée) ; au-delà, `erreur` `debit`. Compteurs par point de présence et cohérents à terme :
  un frein, pas un compte exact. Vérifié en phase 2 (documentation du 01/10/2026) : ni la page
  *Rate Limiting* ni les tarifs et limites des Workers ne la réservent à une offre, sans dire en
  toutes lettres qu'elle existe sur l'offre gratuite ; le premier `wrangler deploy` (phase 5) le
  tranche, et sinon un Durable Object compteur la remplace.
- **Validation** : type de message connu, `vers` membre de la salle, champs attendus seulement ; un
  message invalide est ignoré, sans fermer la socket (un relais vers un client parti à l'instant est
  une course normale) ; le contenu SDP n'est ni lu ni journalisé.
- **TURN** : la clé TURN et le jeton d'API restent dans les secrets du Worker ; identifiants à 2 h,
  donnés seulement par `salle`, `bienvenue` et `arrivee`. Fabriqués par
  `POST https://rtc.live.cloudflare.com/v1/turn/keys/<TURN_KEY_ID>/credentials/generate-ice-servers`
  (`Authorization: Bearer <TURN_KEY_API_TOKEN>`, corps `{"ttl": 7200}`, réponse 201 `iceServers` ;
  vérifié dans la documentation TURN de Cloudflare le 01/10/2026), URL du port 53 retirées (bloqué
  par les navigateurs) ; un seul jeu par arrivée, donné à l'arrivant et à l'hôte. Sans secrets
  (développement local), API en erreur ou muette 3 s : STUN seul (Cloudflare et Google).
- **Coût** : Durable Object en hibernation de WebSocket (pas de durée facturée pour une socket
  inactive) ; quota gratuit dépassé : `erreur quota`, le jeu dit « Trop de parties en ce moment,
  réessaie plus tard. ». Sur l'offre gratuite, une opération au-delà du quota quotidien des Durable
  Objects échoue (tarifs des Durable Objects) : le Worker répond `erreur quota` à tout appel de salle
  qui échoue. Le quota du Worker lui-même (requêtes par jour) ne se détecte pas de l'intérieur :
  Cloudflare répond à sa place, le jeu y voit un service injoignable.
```

Dans la spec, remplacer :

```markdown
- **Offre gratuite de Cloudflare** : Durable Objects gratuits avec le stockage SQLite seulement ; à
  vérifier en phase 2 si le TURN exige une carte bancaire pour être activé, et si la limitation de
  débit existe sur l'offre gratuite.
```

par :

```markdown
- **Offre gratuite de Cloudflare** : Durable Objects gratuits avec le stockage SQLite seulement
  (`new_sqlite_classes`, phase 2) ; limitation de débit : aucune restriction d'offre dans la
  documentation (phase 2, §8.1), le premier déploiement le confirme (phase 5) ; TURN : 1 000 Go
  gratuits, reste à vérifier en phase 5 s'il exige une carte bancaire pour être activé.
```

- [ ] **Step 4 : la vérification passe**

```bash
cd ~/Sites/LeLion-web
f=docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
grep -c "expiree" $f; grep -c "generate-ice-servers" $f; grep -c "À vérifier en phase 2" $f
git diff --stat
```

Expected : `2`, `1`, `0` ; `1 file changed, 44 insertions(+), 20 deletions(-)`.

- [ ] **Step 5 : Commit**

```bash
git add docs/superpowers/specs/2026-10-01-multijoueur-en-ligne-design.md
git commit -m "Spec : la signalisation telle que la phase 2 l'a faite (champs relayés, message invalide ignoré, ouvert ferme la socket du client, erreur expiree, refus par une socket d'un message) ; faits vérifiés le 01/10/2026 : limitation de débit (binding ratelimits, aucune restriction d'offre documentée), API TURN (generate-ice-servers, ttl 7200, port 53 retiré), quota des Durable Objects

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

---

### Task 8 : CI, vérification commune, feuille de route, PR et fusion

**Files:**
- Modify: `.github/workflows/ci.yml` (job `signalisation` après `test-et-export`, intact)
- Modify: `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md` (« Vérification commune » : `npm ci` ; ligne 2 : fichiers réels, « Faite (PR #N) »)

**Interfaces:** job CI `signalisation` (« Tests du Worker de signalisation ») : Node 24.21.0, `npm ci`, `npm test`, `wrangler deploy --dry-run` (aucun compte, aucun secret).

- [ ] **Step 1 : le job CI**

Dans `.github/workflows/ci.yml`, remplacer :

```yaml
      - name: Publier l'export Web (artefact)
        uses: actions/upload-artifact@v4
        with:
          name: LeLion-web
          path: export/web
          if-no-files-found: error
          retention-days: 30
```

par :

```yaml
      - name: Publier l'export Web (artefact)
        uses: actions/upload-artifact@v4
        with:
          name: LeLion-web
          path: export/web
          if-no-files-found: error
          retention-days: 30

  signalisation:
    name: Tests du Worker de signalisation
    runs-on: ubuntu-latest
    timeout-minutes: 10
    defaults:
      run:
        working-directory: signalisation
    steps:
      - uses: actions/checkout@v4

      - name: Installer Node
        uses: actions/setup-node@v6
        with:
          node-version: 24.21.0
          cache: npm
          cache-dependency-path: signalisation/package-lock.json

      - name: Installer les dépendances (package-lock.json)
        run: npm ci

      - name: Tests vitest (Worker et salle dans l'environnement local de Cloudflare, sans compte)
        run: npm test

      - name: Configuration de déploiement valide (sans compte)
        run: npx wrangler deploy --dry-run --outdir "$RUNNER_TEMP/signalisation"
```

puis :

```bash
cd ~/Sites/LeLion-web
python3 -c "import yaml; d = yaml.safe_load(open('.github/workflows/ci.yml')); print(list(d['jobs']))"
git add .github/workflows/ci.yml
git commit -m "CI : job des tests du Worker de signalisation (Node 24.21.0, npm ci, npm test, wrangler deploy --dry-run sans compte), à côté du job Godot inchangé

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RktizzPvgk3uEWX3kLbQwT"
```

Expected : `['test-et-export', 'signalisation']`.

- [ ] **Step 2 : la vérification commune (feuille de route), sans relance**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-web
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
find signalisation -name "*.import" | wc -l
timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "unitaires $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/u.log"
timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "smoke $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/s.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd > "$TMPDIR/b.log" 2>&1; echo "bataille $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/b.log"
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "banc $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/p.log"
SECONDS=0; DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "réseau $? en ${SECONDS} s"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/r.log"
cd signalisation
rm -rf node_modules && npm ci > "$TMPDIR/ci.log" 2>&1; echo "npm ci $?"
for i in 1 2 3; do npm test 2>&1 | grep -E "FAIL|Test Files|Tests "; done
npx wrangler deploy --dry-run --outdir "$TMPDIR/signalisation-dry" 2>&1 | grep -E "Total Upload|env\.|dry-run|✘"
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' src/*.js test/*.js
```

Expected : pas de « ÉCHEC COMPILATION », `0` fichier `.import` sous `signalisation/` ; chaque suite Godot sort en 0 sur `== 0 échec(s) ==` (réseau sous 300 s, environ 180 s), sans `SCRIPT ERROR` ni `SHADER ERROR` (aucun fichier du jeu n'a changé) ; `npm ci 0` ; trois fois `Test Files  7 passed (7)` et `Tests  49 passed (49)` ; `Total Upload: 13.96 KiB / gzip: 4.82 KiB`, les bindings `env.SALLES (Salle)`, `env.LIMITE_CREATION (5 requests/60s)`, `env.ORIGINES`, puis `--dry-run: exiting now.` ; rien au `perl`.

Puis l'essai de `wrangler dev` (ce que la phase 4 servira à Playwright). Créer `$TMPDIR/essai_dev.mjs` :

```js
// Essai de `wrangler dev` (Node 22 ou plus : WebSocket globale, en-têtes permis) : création, arrivée,
// battement, origine refusée.
const BASE = "ws://127.0.0.1:8799";
const ORIGINE = "http://localhost:8060";
const pause = (ms) => new Promise((resoudre) => setTimeout(resoudre, ms));

function ouvrir(chemin, origine) {
	return new Promise((resoudre, rejeter) => {
		const ws = new WebSocket(BASE + chemin, origine ? { headers: { Origin: origine } } : undefined);
		const recus = [];
		ws.onmessage = (evenement) => recus.push(JSON.parse(evenement.data));
		ws.onopen = () => resoudre({ ws, recus });
		ws.onerror = () => rejeter(new Error(`échec de ${chemin}`));
	});
}

const hote = await ouvrir("/v1/creer", ORIGINE);
await pause(300);
const salle = hote.recus.shift();
console.log("salle :", salle.t, salle.code, JSON.stringify(salle.ice));
const client = await ouvrir(`/v1/rejoindre/${salle.code}`, ORIGINE);
await pause(300);
console.log("bienvenue :", client.recus[0]?.t, "/ arrivee :", hote.recus.shift()?.t);
hote.ws.send('{"t":"ping"}');
await pause(200);
console.log("ping →", JSON.stringify(hote.recus.shift()));
const sans = await ouvrir("/v1/creer", null);
await pause(300);
console.log("sans origine →", JSON.stringify(sans.recus[0]));
for (const socket of [client, hote, sans]) socket.ws.close();
await pause(300);
```

```bash
cd ~/Sites/LeLion-web/signalisation
npx wrangler dev --port 8799 --ip 127.0.0.1 > "$TMPDIR/dev.log" 2>&1 &
DEV=$!
for i in $(seq 30); do grep -q "Ready on" "$TMPDIR/dev.log" && break; sleep 1; done
node "$TMPDIR/essai_dev.mjs"
kill $DEV; wait $DEV 2>/dev/null
grep -E "✘|ERROR" "$TMPDIR/dev.log"
cd .. && git status --short
```

Expected (mesuré) :

```
salle : salle <code> [{"urls":["stun:stun.cloudflare.com:3478","stun:stun.l.google.com:19302"]}]
bienvenue : bienvenue / arrivee : arrivee
ping → {"t":"pong"}
sans origine → {"t":"erreur","raison":"origine"}
✘ [ERROR] Uncaught Error: Network connection lost.
```

(STUN seul : pas de secrets TURN en local ; la ligne `✘` est le bruit connu de la socket refusée, une seule.) Un `Incorrect type for map entry` ou `The Workers runtime failed to start` : le module principal exporte autre chose que ses gestionnaires (voir l'écart 3). `git status` propre. Un échec : le corriger dans la tâche qu'il concerne (commit à part), puis tout relancer.

- [ ] **Step 3 : la branche poussée, la PR ouverte** (effet externe : exécuté par le contrôleur, avec l'accord de l'utilisateur)

```bash
git push -u origin phase-02-signalisation
cat > "$TMPDIR/pr.md" <<'EOF'
Phase 2 de la feuille de route du jeu en ligne : le Worker de signalisation, dans `signalisation/`.

- `GET /v1/creer` et `GET /v1/rejoindre/<code>` en WebSocket ; un Durable Object `Salle` par code (SQLite, hibernation des WebSocket, alarme à 4 h).
- Messages du §4.2 : `salle`, `bienvenue`, `arrivee`, relais `offre` / `reponse` / `candidat` entre l'hôte et un client seulement (`vers` devient `de`, champs attendus seulement), `depart`, `ouvert` (la salle ferme la socket du client), `ping` / `pong` automatiques, `erreur` (`inconnue`, `pleine`, `debit`, `quota`, `origine`, et `expiree` en plus).
- Plafonds du §8.1 : origine (`ORIGINES`), 7 sockets, 16 Ko, 20 messages par seconde (seau de jetons), 5 créations par minute et par IP (binding `ratelimits`).
- Identifiants TURN de 2 h par l'API de Cloudflare (`generate-ice-servers`, port 53 retiré) ; sans secrets, STUN seul. Rien n'est déployé (phase 5).
- Tests : 49 tests `vitest` en 7 suites, dans l'environnement local de Cloudflare (`@cloudflare/vitest-plugin`), API TURN simulée ; job CI `signalisation` (`npm ci`, `npm test`, `wrangler deploy --dry-run`).
- Vérifié : la limitation de débit des Workers n'est réservée à aucune offre dans la documentation (le premier déploiement le confirmera) ; spec §4, §8.1 et §13 à jour.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
gh pr create --repo w3cdotorg/LeLion-web --base main --head phase-02-signalisation --title "Phase 2 : signalisation" --body-file "$TMPDIR/pr.md"
N=$(gh pr view --repo w3cdotorg/LeLion-web phase-02-signalisation --json number -q .number); echo "PR #$N"
```

- [ ] **Step 4 : la feuille de route**

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

```text
(cd signalisation && npm test)                                     # à partir de la phase 2
```

par :

```text
(cd signalisation && npm ci && npm test)                           # à partir de la phase 2
```

Dans `docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md`, remplacer :

```markdown
| ➕ `signalisation/package.json` ➕ `signalisation/wrangler.jsonc` ➕ `signalisation/src/index.js` ➕ `signalisation/test/salle.test.js` ✏️ `.github/workflows/ci.yml` | `npm test` vert en local et en CI, sans compte Cloudflare. |
```

par :

```markdown
| ➕ `signalisation/package.json` (+ `package-lock.json`, `.gitignore`, `.gdignore`) ➕ `signalisation/wrangler.jsonc` ➕ `signalisation/vitest.config.js` ➕ `signalisation/src/` (`index`, `origine`, `code`, `protocole`, `ice`, `salle`) ➕ `signalisation/test/` (7 suites, `aide`, `turn`, `preparation`) ✏️ `.github/workflows/ci.yml` ✏️ spec | `npm test` vert en local et en CI, sans compte Cloudflare ; limitation de débit par le binding `ratelimits` (aucune restriction d'offre documentée, le déploiement de la phase 5 le confirme). Faite (PR #NUMERO). |
```

puis (`$N` du Step 3) :

```bash
perl -pi -e "s/PR #NUMERO/PR #$N/" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
grep -c "Faite (PR #$N)" docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git add docs/superpowers/plans/2026-10-01-en-ligne-feuille-de-route.md
git commit -m "Feuille de route : phase 2 faite (PR #$N)

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

Expected : les deux jobs verts (« Tests + export Web » comme avant ; « Tests du Worker de signalisation » en une à deux minutes : `gh run view --repo w3cdotorg/LeLion-web --json jobs`) ; la fusion faite, `main` à jour. La CI rouge : ne pas fusionner, diagnostiquer (un `npm ci` qui échoue sur Linux : le verrou doit contenir `@cloudflare/workerd-linux-64`, Task 1 Step 1).
