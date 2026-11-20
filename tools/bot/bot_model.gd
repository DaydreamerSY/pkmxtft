class_name BotModel
extends RefCounted

## The pro bot's win model (tools/bot/train_model.py): a logistic regression of "this board wins this fight" learned
## from the bots' fights. Features (same names as the trainer): st:<stage, 60 max>, lv:<level>, wv:<wave code>,
## sy:<TYPE>:<k> for every tier k reached, pr:<A>+<B> for two active synergies (A < B), u:<form> per Pokémon on the
## board, it:<item> per item held, pw (power: rarity cost x 3^(stars-1) / 10), n3 (3-star Pokémon), ni (items / 3).
## BotPro judges boards, purchases, items and danger with it.

const DEFAULT_PATH := "res://tools/bot/model.json"

var bias := 0.0
var w := {}


## The model of `path`, null when there is none (the pro bot then uses BotKnowledge's tables).
static func load_from(path: String) -> BotModel:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("w") is Dictionary:
		return null
	var m := BotModel.new()
	m.bias = float(parsed.get("bias", 0.0))
	m.w = parsed.w
	return m


func weight(name: String) -> float:
	return float(w.get(name, 0.0))


## Log-odds that `units` (OwnedUnits) win against `wave_code` at `stage` / `level`; `counts`: their synergy counts.
func logit(stage: int, level: int, wave_code: String, units: Array, counts: Dictionary) -> float:
	var z := bias + weight("st:%d" % mini(stage, 60)) + weight("lv:%d" % level) + weight("wv:" + wave_code)
	z += synergy_logit(counts)
	var power := 0.0
	var threes := 0.0
	var held := 0.0
	for u in units:
		z += weight("u:" + String(u.pkm))
		var stars: int = u.stars()
		power += float(maxi(GameData.rarity_cost(String(u.data().get("rarity", "COMMON"))), 1)) * pow(3.0, stars - 1)
		threes += 1.0 if stars >= 3 else 0.0
		for item in u.items:
			z += weight("it:" + String(item))
			held += 1.0
	return z + weight("pw") * power / 10.0 + weight("n3") * threes + weight("ni") * held / 3.0


## The part of the synergies: every tier reached, every pair of active synergies.
func synergy_logit(counts: Dictionary) -> float:
	var z := 0.0
	var active: Array[String] = []
	for type in counts:
		var tier := Synergies.tier(type, int(counts[type]))
		for k in range(1, tier + 1):
			z += weight("sy:%s:%d" % [type, k])
		if tier > 0:
			active.append(type)
	active.sort()
	for i in active.size():
		for j in range(i + 1, active.size()):
			z += weight("pr:%s+%s" % [active[i], active[j]])
	return z


static func prob(z: float) -> float:
	return 1.0 / (1.0 + exp(-z))
