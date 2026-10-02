class_name SaisieWeb
extends Node
## La saisie au doigt d'un mobile, dans l'export Web (spec §6) : un vrai champ `<input>` de la page, posé
## par-dessus un LineEdit du jeu quand on le touche. Le clavier du téléphone ne s'ouvre que pour un champ
## activé pendant le geste lui-même (Safari sur iPhone surtout) ; Godot traite ses touchers à l'image
## suivante, trop tard : le clavier virtuel de Godot (`html/experimental_virtual_keyboard`) ne s'y ouvre pas.
##
## Le partage du travail : ce nœud publie à la page, à chaque changement, la place de chaque champ branché
## (`brancher`) visible et permis (`actif`), en px du canevas : celle où le toucher le trouve, et celle où
## il sera en édition (sa rangée remontée au-dessus du clavier, `deplacement`). La page, au `touchend` d'un
## toucher sur un champ, montre et active son `<input>` à la place d'édition, dans le geste ; elle lui rend
## ce qui s'y passe (`ouvert`, `texte`, `valide` à Entrée, `ferme` quand le champ perd la main : un toucher
## ailleurs, que Godot prend pour lui), relevé à chaque image. Le LineEdit suit le texte à chaque frappe,
## et Entrée émet son `text_submitted`, comme au clavier. Les LineEdit branchés ne s'éditent jamais
## eux-mêmes (`editable` faux, à l'écran qui les tient : sinon leur édition rendrait la main au canevas et
## fermerait le clavier) ; ils en gardent l'apparence.
##
## Rien hors de l'écran qui le tient : à sa sortie, la page n'a plus de champ, un toucher n'y fait rien (la
## manche et ses contrôles tactiles ne passent jamais par ici).

## Un champ branché entre en édition (`actif` vrai, son `<input>` ouvert) ou en sort.
signal edition(champ: LineEdit, actif: bool)

## Le code de la page : un seul `<input>`, la table des champs publiée par Godot, les événements à relever.
## `zones()` donne aux tests la place des champs en px CSS.
const SCRIPT_PAGE := """
(() => {
	if (window.lelionSaisie) return;
	const canevas = document.querySelector("#canvas") || document.querySelector("canvas");
	const entree = document.createElement("input");
	entree.type = "text";
	entree.autocomplete = "off";
	entree.spellcheck = false;
	entree.setAttribute("autocorrect", "off");
	Object.assign(entree.style, {
		position: "fixed", display: "none", zIndex: "10", boxSizing: "border-box", margin: "0",
		padding: "0 0.4em", border: "2px solid rgba(255, 255, 255, 0.9)", borderRadius: "6px", outline: "none",
		background: "#1b1420", color: "#ffffff", caretColor: "#ffffff", fontFamily: "sans-serif",
	});
	document.body.appendChild(entree);
	let champs = [];
	let ouvert = "";
	let evenements = [];
	const css = (z) => {
		const r = canevas.getBoundingClientRect();
		const k = r.width / canevas.width;
		return { x: r.left + z[0] * k, y: r.top + z[1] * k, l: z[2] * k, h: z[3] * k, k };
	};
	const placer = (c) => {
		const p = css(c.edition);
		Object.assign(entree.style, {
			left: p.x + "px", top: p.y + "px", width: p.l + "px", height: p.h + "px", textAlign: c.alignement,
			// Sous 16 px, Safari agrandit la page pour le champ actif.
			fontSize: Math.max(16, c.police * p.k) + "px",
		});
	};
	const fermer = (valide) => {
		if (!ouvert) return;
		const id = ouvert;
		ouvert = "";
		entree.style.display = "none";
		evenements.push([valide ? "valide" : "ferme", id, entree.value]);
		if (document.activeElement === entree) entree.blur();
		window.scrollTo(0, 0);
	};
	const ouvrir = (c) => {
		ouvert = c.id;
		entree.value = c.texte;
		entree.maxLength = c.max;
		entree.setAttribute("autocapitalize", c.majuscules ? "characters" : "none");
		entree.enterKeyHint = c.touche_entree;
		placer(c);
		entree.style.display = "block";
		entree.focus();
		const fin = entree.value.length;
		entree.setSelectionRange(fin, fin);
		evenements.push(["ouvert", c.id, entree.value]);
	};
	entree.addEventListener("input", () => evenements.push(["texte", ouvert, entree.value]));
	entree.addEventListener("keydown", (e) => {
		if (e.key === "Enter") {
			e.preventDefault();
			fermer(true);
		} else if (e.key === "Escape") {
			fermer(false);
		}
	});
	// Un toucher ailleurs : le `touchstart` de Godot rend la main au canevas.
	entree.addEventListener("blur", () => fermer(false));
	canevas.addEventListener("touchend", (e) => {
		const t = e.changedTouches[0];
		if (!t || ouvert) return;
		for (const c of champs) {
			const p = css(c.zone);
			if (t.clientX >= p.x && t.clientX <= p.x + p.l && t.clientY >= p.y && t.clientY <= p.y + p.h) {
				ouvrir(c);
				return;
			}
		}
	});
	window.lelionSaisie = {
		publier(json) {
			champs = JSON.parse(json);
			const c = champs.find((c) => c.id === ouvert);
			if (c) placer(c);
			else fermer(false);
		},
		relever() {
			const e = evenements;
			evenements = [];
			return JSON.stringify(e);
		},
		zones() {
			return champs.map((c) => ({ id: c.id, ...css(c.zone), ouvert: c.id === ouvert }));
		},
		entree,
	};
})();
"""
const ALIGNEMENTS := {
	HORIZONTAL_ALIGNMENT_LEFT: "left", HORIZONTAL_ALIGNMENT_CENTER: "center",
	HORIZONTAL_ALIGNMENT_RIGHT: "right", HORIZONTAL_ALIGNMENT_FILL: "left",
}

## Faux : aucun champ publié (l'écran hors de son accueil : une connexion en cours).
var actif := true

## id (le nom du LineEdit) -> {champ, deplacement, majuscules, touche_entree}.
var _champs := {}
var _page: JavaScriptObject
## La dernière table publiée : republiée seulement si elle change.
var _publie := ""


## Vrai sur un mobile (`mobile` : `Parametres.mobile`), dans l'export Web : ailleurs, les LineEdit gardent
## leur saisie de Godot.
static func disponible(mobile: bool) -> bool:
	return mobile and OS.has_feature("web")


func _ready() -> void:
	JavaScriptBridge.eval(SCRIPT_PAGE, true)
	_page = JavaScriptBridge.get_interface("lelionSaisie")


## Branche `champ` : son `<input>` s'ouvre au toucher. `deplacement` donne de combien de px (de l'écran du
## jeu, vers le haut si négatif) sa rangée remontera en édition, depuis sa place du moment ; `majuscules`
## demande un clavier en capitales ; `touche_entree`, la touche Entrée du clavier (`enterkeyhint` : « go »,
## « done »…).
func brancher(champ: LineEdit, deplacement: Callable, majuscules := false, touche_entree := "done") -> void:
	champ.virtual_keyboard_enabled = false
	# Non éditable, il garde l'apparence d'un champ qui l'est.
	champ.add_theme_stylebox_override("read_only", champ.get_theme_stylebox("normal"))
	champ.add_theme_color_override("font_uneditable_color", champ.get_theme_color("font_color"))
	_champs[str(champ.name)] = {"champ": champ, "deplacement": deplacement, "majuscules": majuscules,
		"touche_entree": touche_entree}


func _process(_delta: float) -> void:
	if _page == null:
		return
	var table := JSON.stringify(_table())
	if table != _publie:
		_publie = table
		_page.publier(table)
	var evenements: Variant = JSON.parse_string(str(_page.relever()))
	if evenements is Array:
		for evenement: Array in evenements:
			_traiter(str(evenement[0]), str(evenement[1]), str(evenement[2]))


## Plus de champ pour la page : un `<input>` ouvert se ferme, un toucher n'en ouvre plus.
func _exit_tree() -> void:
	if _page != null:
		_page.publier("[]")
		_page.relever()


## Les champs visibles et permis, leur place en px du canevas : `zone` (où le toucher les trouve) et
## `edition` (leur place en édition).
func _table() -> Array:
	var table := []
	if not actif:
		return table
	for id: String in _champs:
		var fiche: Dictionary = _champs[id]
		var champ: LineEdit = fiche.champ
		if not champ.is_visible_in_tree():
			continue
		var ecran := champ.get_viewport().get_screen_transform() * champ.get_global_transform_with_canvas()
		var deplacement: float = fiche.deplacement.call(champ)
		var zone := ecran * Rect2(Vector2.ZERO, champ.size)
		var edition := ecran * Rect2(Vector2(0.0, deplacement), champ.size)
		table.append({
			"id": id, "zone": _px(zone), "edition": _px(edition), "texte": champ.text,
			"max": champ.max_length if champ.max_length > 0 else 524288,
			"police": champ.get_theme_font_size("font_size") * ecran.get_scale().y,
			"alignement": ALIGNEMENTS.get(champ.alignment, "left"),
			"majuscules": fiche.majuscules, "touche_entree": fiche.touche_entree,
		})
	return table


static func _px(rect: Rect2) -> Array:
	return [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1), snappedf(rect.size.x, 0.1),
		snappedf(rect.size.y, 0.1)]


func _traiter(genre: String, id: String, texte: String) -> void:
	if not _champs.has(id):
		return
	var champ: LineEdit = _champs[id].champ
	if genre == "ouvert":
		edition.emit(champ, true)
		return
	champ.text = texte
	if genre == "texte":
		return
	edition.emit(champ, false)
	if genre == "valide":
		champ.text_submitted.emit(champ.text)
