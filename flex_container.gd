@tool

extends Container

## Container custom regroupant des propriétés de layout, de marge, d'espacement et de panel
class_name FlexContainer

#region Export
@export_group("Layout")
## Organise les enfants les uns sur les autres plutôt que les uns à côté des autres
@export var vertical : bool = false :
	set(value):
		vertical = value
		_update_axis()
		queue_sort() 

## Alignement horizontal des enfants Control par rapport au Container
@export var align_horizontal : Align = Align.BEGIN :
	set(value):
		align_horizontal = value
		_update_axis()
		queue_sort() 

## Alignement vertical des enfants Control par rapport au Container
@export var align_vertical : Align = Align.BEGIN :
	set(value):
		align_vertical = value
		_update_axis()
		queue_sort() 

## Arrange les enfants sur de nouvelles rangées si nécessaire
@export var wrapping : bool = false :
	set(value):
		wrapping = value
		queue_sort() 

## Défini comment les enfants sont triés
@export var sort : Sort = Sort.NORMAL :
	set(value):
		sort = value
		queue_sort() 

## Place les rangées d'enfants de la dernière à la première (seulement important quand plusierus rangées sont crées par le wrapping)
@export var reverse_fill : bool = false :
	set(value):
		reverse_fill = value
		queue_sort()

@export_group("Items")
## Défini si tous les enfants doivent prendre un espace minimum semblable à celui de l'enfant le plus grand
@export var match_largest : bool = false :
	set(value):
		match_largest = value
		queue_sort() 

## Défini comment les enfants ont le droit de s'étendre
@export var allow_expand : Expand = Expand.NONE :
	set(value):
		allow_expand = value
		queue_sort() 

@export_group("Margin")
## Marge générale
@export var margin : float = 0 :
	set(value):
		margin = value
		margin_top = value
		margin_bottom = value
		margin_left = value
		margin_right = value
		queue_sort() 

@export_subgroup("Detailed margins")
## Marge supérieure du contenu
@export var margin_top : float = 0 :
	set(value):
		margin_top = value
		queue_sort() 

## Marge inférieure du contenu
@export var margin_bottom : float = 0 :
	set(value):
		margin_bottom = value
		queue_sort() 

## Marge gauche du contenu
@export var margin_left : float = 0 :
	set(value):
		margin_left = value
		queue_sort() 

## Marge droite du contenu
@export var margin_right : float = 0 :
	set(value):
		margin_right = value
		queue_sort() 

@export_group("Gap")
## Espacement vertical entre les enfants
@export var gap_vertical : float = 0 :
	set(value):
		gap_vertical = value
		_update_axis()
		queue_sort() 

## Espacement horizontal entre les enfants
@export var gap_horizontal : float = 0 :
	set(value):
		gap_horizontal = value
		_update_axis()
		queue_sort() 

@export_group("Panel")
## Style du panel appliqué au Container
@export var panel : StyleBox :
	set(value):
		panel = value
		queue_redraw()
		queue_sort()

#endregion

#region Enums
## Alignements possibles des enfants
enum Align {
	BEGIN, ## Enfants disposés au début du Container
	CENTER, ## Enfants disposés au milieu du Container
	END ## Enfants disposés à la fin du Container
}

## Remplissage de l'espace possibles
enum Expand {
	NONE, ## Garde la taille minimale
	VERTICAL, ## Rempli l'espace vertical
	HORIZONTAL, ## Rempli l'espace horizontal
	BOTH ## Rempli l'espace vertical et horizontal
}

## Tris possibles pour les enfants
enum Sort {
	NORMAL, ## Reprend l'ordre de l'arbre
	REVERSE, ## Inverse l'ordre de l'arbre
	RANDOM ## Ordonne au hasard
}

#endregion

#region Var
var main := 0
var cross := 1

var gap_main := 0.0
var gap_cross := 0.0

var align_main := Align.BEGIN
var align_cross := Align.BEGIN

## Dernière taille calculée dans le sens de travers
var _cached_wrap_size: float = 0.0

#endregion

#region Main func
func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_children()
	elif what == NOTIFICATION_DRAW:
		_draw_panel()

func _draw_panel() -> void:
	if panel:
		panel.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

## Renvoie la taille minimum possible du Container
func _get_minimum_size() -> Vector2:
	var children := _get_layout_children()
	if children.is_empty():
		return _get_total_insets()

	var children_sizes: Array[Vector2] = []
	for child in children:
		children_sizes.append(child.get_combined_minimum_size())

	var minimum_size := Vector2.ZERO
	
	var largest_minimim_size := _get_largest_children_minimum_size(children_sizes)

	if wrapping:
		minimum_size = largest_minimim_size
		if _cached_wrap_size > 0.0:
			minimum_size[cross] = _cached_wrap_size
	else:
		var max_cross := 0.0
		var total_main := 0.0
		for index in children_sizes.size():
			var child_size := children_sizes[index]
			total_main += largest_minimim_size[main] if match_largest else child_size[main]
			if index > 0:
				total_main += gap_main
			max_cross = maxf(max_cross, child_size[cross])
		minimum_size[main] = total_main
		minimum_size[cross] = max_cross
	
	return minimum_size + _get_total_insets()

## Positionne les enfants
func _sort_children() -> void:
	var children := _get_layout_children()
	if children.is_empty():
		_cached_wrap_size = 0.0
		return

	var inner := _get_inner_rect()
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		_cached_wrap_size = 0.0
		return

	var lines := _build_lines(children, inner.size)
	_place_lines(lines, inner)
	update_minimum_size()

## Renvoie une liste de rangées d'enfants respectant les paramètres du Container
func _build_lines(children: Array[Control], available_size: Vector2) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var line := _make_line()

	var max_main := available_size[main]

	var children_sizes: Array[Vector2] = []
	for child in children:
		children_sizes.append(child.get_combined_minimum_size())

	var largest_size = _get_largest_children_minimum_size(children_sizes)

	for child in children:
		var item := _make_item(child)
		
		item["size"][cross] = largest_size[cross]
		
		if match_largest:
			item["size"][main] = largest_size[main]
	
		var projected : float = line["size"][main]

		if not line["items"].is_empty():
			projected += gap_main
		projected += item["size"][main]

		var should_wrap : bool = wrapping and not line["items"].is_empty() and projected > max_main

		if should_wrap:
			lines.append(line)
			line = _make_line()

		if not line["items"].is_empty():
			line["size"][main] += gap_main

		line["items"].append(item)
		line["size"][main] += item["size"][main]
		line["size"][cross] = maxf(line["size"][cross], item["size"][cross])

	if not line["items"].is_empty():
		lines.append(line)

	_update_cached_wrap_size(lines)

	_expand_items(lines, available_size)

	return lines

## Place rangées d'enfants
func _place_lines(lines: Array[Dictionary], inner: Rect2) -> void:
	var content_cross := 0.0
	for i in lines.size():
		content_cross += lines[i]["size"][cross]
		if i > 0:
			content_cross += gap_cross

	var cross_start := _aligned_offset(
		inner.size[cross],
		content_cross,
		align_cross
	)

	var cursor_cross := cross_start

	if reverse_fill:
		lines.reverse()

	for line in lines:
		var main_space := inner.size[main]
		var main_start := _aligned_offset(main_space, line["size"][main], align_main)

		var cursor_main := main_start

		for item in line["items"]:
			var child: Control = item["child"]
			var child_size: Vector2 = item["size"]

			var rect := Rect2()

			rect.position = inner.position
			rect.position[main] += cursor_main
			rect.position[cross] += cursor_cross
			rect.size[main] = child_size[main]
			rect.size[cross] = child_size[cross]
			cursor_main += item["size"][main] + gap_main

			fit_child_in_rect(child, rect)

		cursor_cross += line["size"][cross] + gap_cross

#endregion

#region Expand logic
## Adapte la taille des enfants en fonction du mode d'expand
func _expand_items(lines : Array[Dictionary], available_size : Vector2) -> void:
	if allow_expand == Expand.NONE:
		return

	if allow_expand == Expand.HORIZONTAL or allow_expand == Expand.BOTH:
		if _direction_matches_main_axis(Expand.HORIZONTAL):
			_expand_on_main_axis(lines, available_size[main], Expand.HORIZONTAL)
		else:
			_expand_on_cross_axis(lines, available_size[cross], Expand.HORIZONTAL)

	if allow_expand == Expand.VERTICAL or allow_expand == Expand.BOTH:
		if _direction_matches_main_axis(Expand.VERTICAL):
			_expand_on_main_axis(lines, available_size[main], Expand.VERTICAL)
		else:
			_expand_on_cross_axis(lines, available_size[cross], Expand.VERTICAL)

func _expand_on_main_axis(lines: Array[Dictionary], available_main: float, expand_direction: Expand) -> void:
	for line in lines:
		var remaining := maxf(0.0, available_main - line["size"][main])
		var stretch_shares := 0.0

		for item in line["items"]:
			if _has_expand_flag(item["child"], expand_direction):
				stretch_shares += item["child"].size_flags_stretch_ratio

		if stretch_shares <= 0.0:
			continue

		for item in line["items"]:
			var child: Control = item["child"]
			if not _has_expand_flag(child, expand_direction):
				continue

			var stretch := child.size_flags_stretch_ratio / stretch_shares * remaining
			item["size"][main] += stretch

		line["size"][main] = available_main

func _expand_on_cross_axis(lines: Array[Dictionary], available_cross: float, expand_direction: Expand) -> void:
	var used := 0.0
	var stretch_shares := 0.0
	var line_ratios: Array[float] = []

	for i in lines.size():
		used += lines[i]["size"][cross]
		if i > 0:
			used += gap_cross

		var ratio := _get_max_ratio(lines[i]["items"], expand_direction)
		line_ratios.append(ratio)
		stretch_shares += ratio

	var remaining := maxf(0.0, available_cross - used)

	if stretch_shares <= 0.0:
		return

	for i in lines.size():
		var line := lines[i]
		var stretch := line_ratios[i] / stretch_shares * remaining
		line["size"][cross] += stretch

		for item in line["items"]:
			item["size"][cross] = line["size"][cross]

func _direction_matches_main_axis(expand_direction: Expand) -> bool:
	if vertical:
		return expand_direction == Expand.VERTICAL
	return expand_direction == Expand.HORIZONTAL

func _has_expand_flag(control : Control, expand_direction : Expand) -> bool:
	match expand_direction:
		Expand.VERTICAL:
			return (control.size_flags_vertical & Control.SIZE_EXPAND) != 0
		Expand.HORIZONTAL:
			return (control.size_flags_horizontal & Control.SIZE_EXPAND) != 0
		_:
			return false
#endregion

#region Get helpers
## Récupère les enfants Control visibles dans l'ordre souhaité
func _get_layout_children() -> Array[Control]: 
	var result: Array[Control] = []
	for child in get_children():
		if child is Control:
			if child.visible and not child.top_level:
				result.append(child)
	if sort == Sort.REVERSE:
		result.reverse()
	elif sort == Sort.RANDOM:
		result.shuffle()
	return result

## Renvoie la somme des marges horizontales et verticales
func _get_total_insets() -> Vector2:
	return Vector2(margin_left + margin_right, margin_top + margin_bottom)

## Renvoie le rectangle dans lequel les enfants peuvent être placés
func _get_inner_rect() -> Rect2:
	var pos := Vector2(margin_left, margin_top)
	var rect_size := size - _get_total_insets()
	rect_size.x = maxf(0.0, rect_size.x)
	rect_size.y = maxf(0.0, rect_size.y)
	return Rect2(pos, rect_size)

func _get_max_ratio(items: Array, expand_direction: Expand) -> float:
	return items.reduce(func(max_value: float, item: Dictionary) -> float:
		var child: Control = item["child"]
		return max(
			max_value,
			child.size_flags_stretch_ratio if _has_expand_flag(child, expand_direction) else 0.0
		)
	, 0.0)

## Renvoie la taille minimum la plus grande parmis les enfants
func _get_largest_children_minimum_size(children_sizes: Array[Vector2]) -> Vector2:
	var max_height := 0.0
	var max_width := 0.0
	for index in children_sizes.size():
		var child_size: Vector2 = children_sizes[index]
		max_height = maxf(max_height, child_size.y)
		max_width = maxf(max_width, child_size.x)
	var minimum_size := Vector2(max_width, max_height)
	return minimum_size

#endregion

#region Update helpers
## Mets à jour quels axe et espacement sont principales ou secondaire
func _update_axis():
	main = int(vertical)
	cross = int(!vertical)
	gap_main = gap_vertical if vertical else gap_horizontal
	gap_cross = gap_horizontal if vertical else gap_vertical
	align_main = align_vertical if vertical else align_horizontal
	align_cross = align_horizontal if vertical else align_vertical

## Enregistre la taille dans le sens de travers
func _update_cached_wrap_size(lines: Array[Dictionary]) -> void:
	var total_cross := 0.0

	for index in lines.size():
		total_cross += lines[index]["size"][cross]
		if index > 0:
			total_cross += gap_cross

	_cached_wrap_size = total_cross

#endregion

#region Object makers
## Renvoie un template de dictionnaire décrivant une rangée d'enfant
func _make_line() -> Dictionary:
	return {
		"items": [],
		"size": Vector2(0,0)
	}

## Renvoie un dictionnaire décrivant la taille d'un enfant
func _make_item(child: Control) -> Dictionary:
	return {
		"child": child,
		"size": child.get_combined_minimum_size(),
	}

#endregion

#region Other small helpers
## Renvoie un offset à appliquer à la position des enfants en fonction du mode d'alignement
func _aligned_offset(available: float, used: float, align_mode: Align) -> float:
	match align_mode:
		Align.CENTER:
			return (available - used) * 0.5
		Align.END:
			return available - used
		_:
			return 0.0

#endregion
