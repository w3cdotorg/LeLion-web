// La clé d'une IP pour les limites par IP (spec §8.1) : un abonné IPv6 reçoit en général tout un /64,
// d'où il tire autant d'adresses qu'il veut ; une limite par adresse ne le freinerait pas.
// Module à part : le module principal n'exporte que des gestionnaires (workerd refuse le reste).

/**
 * La clé de limite de `texte` (l'en-tête cf-connecting-ip) : une IPv4 telle quelle ; une IPv4 mappée
 * (`::ffff:a.b.c.d`) rendue à son IPv4 ; une IPv6 réduite à son /64 (ses 4 premiers groupes, `::`
 * développé, en minuscules sans zéros de tête : `2001:db8::1` → `2001:db8:0:0`) ; absente : `local`.
 * Un texte qui n'est pas une IPv6 valide reste tel quel, en minuscules.
 */
export function cleIp(texte) {
	if (!texte) return "local";
	const ip = texte.trim().toLowerCase();
	if (!ip.includes(":")) return ip;
	const groupes = groupesIpv6(ip);
	if (groupes === null) return ip;
	if (groupes.slice(0, 5).every((groupe) => groupe === 0) && groupes[5] === 0xffff) {
		return [groupes[6] >> 8, groupes[6] & 0xff, groupes[7] >> 8, groupes[7] & 0xff].join(".");
	}
	return groupes
		.slice(0, 4)
		.map((groupe) => groupe.toString(16))
		.join(":");
}

const GROUPE = /^[0-9a-f]{1,4}$/;
const IPV4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;

/** Les 8 groupes de 16 bits de l'IPv6 `ip` (`::` développé, IPv4 finale comprise), ou `null`. */
function groupesIpv6(ip) {
	const moities = ip.split("::");
	if (moities.length > 2) return null;
	const parties = moities.map((moitie) => (moitie === "" ? [] : moitie.split(":")));
	const derniere = parties.at(-1);
	const ipv4 = IPV4.exec(derniere.at(-1) ?? "");
	if (ipv4) {
		const octets = ipv4.slice(1).map(Number);
		if (octets.some((octet) => octet > 255)) return null;
		derniere.splice(-1, 1, ((octets[0] << 8) | octets[1]).toString(16), ((octets[2] << 8) | octets[3]).toString(16));
	}
	if (!parties.flat().every((groupe) => GROUPE.test(groupe))) return null;
	const nombre = parties.flat().length;
	if (moities.length === 1 ? nombre !== 8 : nombre > 7) return null;
	const [tete, queue = []] = parties;
	return [...tete, ...Array(8 - nombre).fill("0"), ...queue].map((groupe) => parseInt(groupe, 16));
}
