import { describe, expect, it, vi } from "vitest";
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

	it("1000 tirages : au plus un doublon (31⁶ codes ; deux doublons ou plus : ~1,6e-7)", () => {
		const codes = new Set(Array.from({ length: 1000 }, tirerCode));
		expect(codes.size).toBeGreaterThanOrEqual(999);
	});

	it("rejette les octets 248 à 255 (tirage sans biais) et garde 247", () => {
		// 248 = 8 × 31 : un octet au-delà donnerait plus souvent les 8 premiers caractères.
		const tirages = [
			new Uint8Array([255, 254, 253, 252, 251, 250, 249, 248, 255, 254, 253, 252]),
			new Uint8Array([247, 0, 1, 2, 3, 4, 248, 5, 6, 7, 8, 9]),
		];
		const espion = vi.spyOn(crypto, "getRandomValues").mockImplementation((tableau) => {
			tableau.set(tirages.shift());
			return tableau;
		});
		expect(tirerCode()).toBe("Z23456");
		expect(espion).toHaveBeenCalledTimes(2);
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
