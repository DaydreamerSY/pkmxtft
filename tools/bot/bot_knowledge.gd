class_name BotKnowledge
extends RefCounted

## What the bots learned from their fights - a pro player's experience - that the pro bot (BotPro) reads to judge
## synergies, pairs of synergies, Pokémon, items and whole strategies, and that every fight of every bot adds to.
## Kept in tools/bot/knowledge.json across batches: a worker starts from it and writes what it added
## (knowledge_W.json in the batch folder); tools/bot/learn.py adds those into it (or learns it from TSV batches).
## Every entry is [n, sum] (mean = sum / n); "adj" = won (1 / 0) - the win rate of that stage:
##   stage[stage]   wins of the stage (the baseline of adj)
##   syn[T:tier]    adj of the fights with synergy T at that tier       pair[A+B]  adj with both active (A < B)
##   unit[pkm]      adj with it on the board        share[pkm]  its share of the team's damage
##   item[I@role]   adj with item I held by a Pokémon of that role
##   plan[A+B]      final stage of the runs that aimed at A and B        econ[keep:pace]  same for the economy

const DEFAULT_PATH := "res://tools/bot/knowledge.json"
const KINDS: Array[String] = ["stage", "syn", "pair", "unit", "share", "item", "plan", "econ"]

var base := {}  ## the file read: {kind: {name: [n, sum]}}
var added := {} ## what this worker learned, written for learn.py


static func load_from(path: String) -> BotKnowledge:
	var k := BotKnowledge.new()
	for kind in KINDS:
		k.base[kind] = {}
		k.added[kind] = {}
	if path != "" and FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for kind in KINDS:
				if parsed.get(kind) is Dictionary:
					k.base[kind] = parsed[kind]
	return k


## Writes what this worker added (learn.py merges it into the knowledge file).
func save_added(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(added))


func add(kind: String, name: String, value: float) -> void:
	var table: Dictionary = added[kind]
	var entry: Array = table.get(name, [0.0, 0.0])
	table[name] = [float(entry[0]) + 1.0, float(entry[1]) + value]


## n of an entry (file + this worker).
func count(kind: String, name: String) -> float:
	var a: Array = base[kind].get(name, [0.0, 0.0])
	var b: Array = added[kind].get(name, [0.0, 0.0])
	return float(a[0]) + float(b[0])


## Mean pulled toward `prior` by `weight` pseudo-observations (few observations = mostly the prior).
func mean(kind: String, name: String, prior: float, weight: float) -> float:
	var a: Array = base[kind].get(name, [0.0, 0.0])
	var b: Array = added[kind].get(name, [0.0, 0.0])
	var n := float(a[0]) + float(b[0])
	return (float(a[1]) + float(b[1]) + prior * weight) / (n + weight)


## Total n of a kind (the N of the UCB exploration bonus).
func total(kind: String) -> float:
	var n := 0.0
	for table in [base[kind], added[kind]]:
		for name in table:
			n += float(table[name][0])
	return n


## Win rate expected at a stage (0.5 when nothing is known).
func baseline(stage: int) -> float:
	return mean("stage", str(stage), 0.5, 4.0)


## UCB1 score of an arm: its mean (pulled to `prior`) + exploration for the ones tried little.
func ucb(kind: String, name: String, prior: float, scale: float, explore: float) -> float:
	var n := count(kind, name)
	return mean(kind, name, prior, 1.0) / scale + explore * sqrt(log(total(kind) + 2.0) / (n + 1.0))


## A fight seen by any bot: {stage, win (0 / 1), counts {type: count}, units [{pkm, role, items, share}]}.
func observe(info: Dictionary) -> void:
	var stage := int(info.stage)
	var win := float(info.win)
	var adj := win - baseline(stage)
	add("stage", str(stage), win)
	var active: Array[String] = []
	var counts: Dictionary = info.counts
	for type in counts:
		var tier := Synergies.tier(type, int(counts[type]))
		if tier > 0:
			active.append(type)
			add("syn", "%s:%d" % [type, tier], adj)
	active.sort()
	for i in active.size():
		for j in range(i + 1, active.size()):
			add("pair", active[i] + "+" + active[j], adj)
	for u in info.units:
		add("unit", String(u.pkm), adj)
		add("share", String(u.pkm), float(u.share))
		for item in u.items:
			add("item", "%s@%s" % [item, u.role], adj)
