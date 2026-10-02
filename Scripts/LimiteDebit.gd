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
