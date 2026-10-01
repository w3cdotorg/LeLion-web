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
