class_name BattleBoard
extends RefCounted

## The battle grid, port of app/core/board.ts on hexagons (not like the web game, which has an
## 8 x 6 grid of squares, see docs/PORTING.md "Lưới lục giác").
##
## WIDTH x HEIGHT pointy-top hexagons in rows; every odd row is shifted half a cell to the right
## ("odd-r" offset coordinates). One Pokémon = exactly one cell.
##   y = 0..3 : player side (blue), y = 3 is the player's front row
##   y = 4..7 : enemy side (red),   y = 4 is the enemy front row
## +x goes right, +y goes away from the camera (toward the enemy).
## A cell is Vector2i(column, row). The geometry works in axial coordinates (to_axial: q, r = row),
## where the 6 neighbours are constant offsets (DIRECTIONS): move a cell with step(), never with
## cell + direction (only the row neighbours cell +- Vector2i(1, 0) can be added).
## Distances: the hex distance (steps between the cells) both for ranges (web: Chebyshev) and for
## the "nearest / farthest" searches (web: Manhattan).
##
## The static shape helpers only do geometry and are shared by the simulation, the ability previews
## and the drag highlight, so what the player sees is exactly what the simulation uses.

const WIDTH := 7
const HEIGHT := 8
## Rows of one side: the player has rows 0..SIDE_ROWS - 1.
const SIDE_ROWS := 4
## Distance between the centres of two rows, in cell widths (sqrt(3) / 2).
const ROW_STEP := 0.8660254

## The 6 directions (axial offsets), counter-clockwise from the right, 60° apart:
## 0 RIGHT, 1 FORWARD_RIGHT (toward the enemy), 2 FORWARD_LEFT, 3 LEFT, 4 BACK_LEFT, 5 BACK_RIGHT.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]

var cells: Array = [] # BattleUnit or null, index = y * WIDTH + x


func _init() -> void:
	cells.resize(WIDTH * HEIGHT)


#region occupancy
func get_unit(cell: Vector2i) -> BattleUnit:
	if not in_bounds(cell):
		return null
	return cells[cell.y * WIDTH + cell.x]


func is_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and cells[cell.y * WIDTH + cell.x] == null


func place(unit: BattleUnit, cell: Vector2i) -> void:
	if not in_bounds(cell):
		push_error("BattleBoard.place: %s is off the board" % cell)
		return
	cells[cell.y * WIDTH + cell.x] = unit
	unit.cell = cell


func clear(cell: Vector2i) -> void:
	if in_bounds(cell):
		cells[cell.y * WIDTH + cell.x] = null


## Moves a unit to a free cell (the cell is reserved immediately).
func move(unit: BattleUnit, to: Vector2i) -> void:
	clear(unit.cell)
	place(unit, to)


func swap(a: Vector2i, b: Vector2i) -> void:
	var ua := get_unit(a)
	var ub := get_unit(b)
	cells[a.y * WIDTH + a.x] = ub
	cells[b.y * WIDTH + b.x] = ua
	if ua:
		ua.cell = b
	if ub:
		ub.cell = a


func units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in cells:
		if u != null:
			out.append(u)
	return out


func free_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in all_cells():
		if is_free(c):
			out.append(c)
	return out


## Closest free cell to `cell` (the first one of the board on a tie), used for dashes and knockbacks.
func closest_free_cell(cell: Vector2i) -> Variant:
	var best: Variant = null
	var best_distance := 999
	for c in all_cells():
		if is_free(c):
			var d := distance(c, cell)
			if d < best_distance:
				best_distance = d
				best = c
	return best
#endregion


#region coordinates and distances
static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


## Offset cell (column, row) -> axial (q, r). Exact for negative rows too (cells off the board).
static func to_axial(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - (cell.y - (cell.y & 1)) / 2, cell.y)


static func from_axial(a: Vector2i) -> Vector2i:
	return Vector2i(a.x + (a.y - (a.y & 1)) / 2, a.y)


## The cell `n` steps from `cell` going `dir` (one of DIRECTIONS, or any axial offset).
static func step(cell: Vector2i, dir: Vector2i, n := 1) -> Vector2i:
	return from_axial(to_axial(cell) + dir * n)


## Axial offset from `a` to `b`: step(a, offset(a, b)) == b.
static func offset(a: Vector2i, b: Vector2i) -> Vector2i:
	return to_axial(b) - to_axial(a)


## Centre of a cell in cell widths: x to the right, y toward the enemy (rows are ROW_STEP apart).
static func center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5 * float(cell.y & 1), cell.y * ROW_STEP)


## The cell containing a point given like center() (it may be off the board).
static func cell_at(p: Vector2) -> Vector2i:
	var r := p.y / ROW_STEP
	var q := p.x - r * 0.5
	return from_axial(_cube_round(Vector3(q, r, -q - r)))


## Number of steps between two cells.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := offset(a, b)
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


## Attack ranges (web: Chebyshev distance): the hex distance.
static func distance_c(a: Vector2i, b: Vector2i) -> int:
	return distance(a, b)


## Nearest / farthest searches (web: Manhattan distance): the hex distance.
static func distance_m(a: Vector2i, b: Vector2i) -> int:
	return distance(a, b)


## The direction (one of DIRECTIONS) closest to the line from `from` to `to`, ZERO on the same cell.
## A line exactly between two directions (straight ahead, for one) takes the one leading toward the
## middle of the board.
static func orientation(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	var d := center(to) - center(from)
	var k := atan2(d.y, d.x) / (PI / 3.0)
	var low := floori(k)
	if absf(k - low - 0.5) > 1e-4:
		return DIRECTIONS[posmod(roundi(k), 6)]
	var a: Vector2i = DIRECTIONS[posmod(low, 6)]
	var b: Vector2i = DIRECTIONS[posmod(low + 1, 6)]
	var mid := Vector2((WIDTH - 0.5) * 0.5, (HEIGHT - 1) * 0.5 * ROW_STEP)
	var da := center(step(from, a)).distance_squared_to(mid)
	var db := center(step(from, b)).distance_squared_to(mid)
	return b if db < da - 1e-6 else a


## `dir` turned by `k` sixths of a turn (60°), counter-clockwise for k > 0.
static func turn(dir: Vector2i, k: int) -> Vector2i:
	var i := DIRECTIONS.find(dir)
	return DIRECTIONS[posmod(i + k, 6)] if i >= 0 else dir


## `dir` and its two neighbours 60° aside (the web game: the direction and the two 45° aside).
static func fan(dir: Vector2i) -> Array[Vector2i]:
	return [dir, turn(dir, 1), turn(dir, -1)]


## PMD sprite direction (0 DOWN, 1 DOWNRIGHT, 2 RIGHT, 3 UPRIGHT, 4 UP, 5 UPLEFT, 6 LEFT,
## 7 DOWNLEFT) of a board direction or offset (DOWN = toward the camera).
static func direction_index(dir: Vector2i) -> int:
	if dir == Vector2i.ZERO:
		return 0
	return sprite_direction(center(step(Vector2i.ZERO, dir)))


## PMD sprite direction looking from cell `a` at cell `b` (at the real angle, 8 directions).
static func sprite_direction_between(a: Vector2i, b: Vector2i) -> int:
	return sprite_direction(center(b) - center(a))


static func sprite_direction(v: Vector2) -> int:
	if v.is_zero_approx():
		return 0
	return posmod(roundi((rad_to_deg(atan2(v.y, v.x)) - 270.0) / 45.0), 8)


static func _cube_round(v: Vector3) -> Vector2i:
	var q := roundf(v.x)
	var r := roundf(v.y)
	var s := roundf(v.z)
	var dq := absf(q - v.x)
	var dr := absf(r - v.y)
	var ds := absf(s - v.z)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))
#endregion


#region shapes (pure geometry, clipped to the board)
static func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in HEIGHT:
		for x in WIDTH:
			out.append(Vector2i(x, y))
	return out


## The 6 cells around `center` (board.getAdjacentCells, 8 squares on the web).
static func adjacent_cells(center: Vector2i, include_center := false) -> Array[Vector2i]:
	return cells_in_range(center, 1, include_center)


## Hexagon of radius `r` (board.getCellsInRange, a Chebyshev square on the web) = attack range.
static func cells_in_range(center: Vector2i, r: int, include_center := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(maxi(center.y - r, 0), mini(center.y + r, HEIGHT - 1) + 1):
		for x in range(maxi(center.x - r - 1, 0), mini(center.x + r + 1, WIDTH - 1) + 1):
			var c := Vector2i(x, y)
			if c == center and not include_center:
				continue
			if distance(c, center) <= r:
				out.append(c)
	return out


## Disc of radius `r` (board.getCellsInRadius: dx² + dy² < (r + 0.5)² on the web): on hexagons
## the hexagon of radius `r`, like cells_in_range.
static func cells_in_radius(center: Vector2i, r: int, include_center := false) -> Array[Vector2i]:
	return cells_in_range(center, r, include_center)


static func cells_in_row(y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in WIDTH:
		if in_bounds(Vector2i(x, y)):
			out.append(Vector2i(x, y))
	return out


## Straight line from a to b, both included (board.getCellsBetween): the cells under the segment
## joining their centres, one per step. A line along cell edges keeps to one side, the other one
## where that side is off the board (the line stays in one piece along the board edges).
static func cells_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := distance(a, b)
	var qa := Vector3(to_axial(a).x, to_axial(a).y, -to_axial(a).x - to_axial(a).y)
	var qb := Vector3(to_axial(b).x, to_axial(b).y, -to_axial(b).x - to_axial(b).y)
	var nudge := Vector3(1e-6, 2e-6, -3e-6)
	for i in n + 1:
		var t := float(i) / float(maxi(n, 1))
		var c := from_axial(_cube_round((qa + nudge).lerp(qb + nudge, t)))
		if not in_bounds(c):
			var other := from_axial(_cube_round((qa - nudge).lerp(qb - nudge, t)))
			if in_bounds(other):
				c = other
		if in_bounds(c) and (out.is_empty() or out.back() != c):
			out.append(c)
	return out


## Cone toward the target: the facing direction and its two neighbours 60° aside, expanded `r`
## times (board.getCellsInFront: 45° aside on the web).
static func cells_in_front(caster: Vector2i, target: Vector2i, r: int) -> Array[Vector2i]:
	var facing := orientation(caster, target)
	if facing == Vector2i.ZERO:
		facing = DIRECTIONS[0]
	var dirs := fan(facing)
	var seen := {caster: true}
	var out: Array[Vector2i] = []
	var previous: Array[Vector2i] = [caster]
	for _i in r:
		var next: Array[Vector2i] = []
		for dir in dirs:
			for c in previous:
				var n := step(c, dir)
				if not seen.has(n):
					seen[n] = true
					next.append(n)
					if in_bounds(n):
						out.append(n)
		previous = next
	return out


## Straight ray from the caster toward the target in one of the 6 directions, up to max_range
## cells (0 = board edge). effectInOrientation.
static func ray_cells(caster: Vector2i, target: Vector2i, max_range := 0) -> Array[Vector2i]:
	var dir := orientation(caster, target)
	var out: Array[Vector2i] = []
	if dir == Vector2i.ZERO:
		return out
	var p := step(caster, dir)
	while in_bounds(p):
		if max_range > 0 and distance(p, caster) > max_range:
			break
		out.append(p)
		p = step(p, dir)
	return out


## Line from the caster through the target, to the board edge, at the real angle
## (effectInLine). Starts with the caster cell.
static func line_cells(caster: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var d := center(target) - center(caster)
	if d.is_zero_approx():
		return cells_between(caster, caster)
	return cells_between(caster, cell_at(center(caster) + d.normalized() * 12.0))
#endregion
