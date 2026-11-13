class_name IconFactory
extends Node
## Fabrique des icônes procédurales (sans asset tiers).
##
## - Items : texture 64x64 générée (forme = icon_shape, couleur = icon_color,
##   liseré = rareté) via Image + pixels. Mise en cache par item_id.
## - Buildables : vignette procédurale (forme = dérivée du kind, couleur = palier).
##   Mise en cache par buildable_id.
## Aucune icône n'est générée à chaque frame : tout est mis en cache au premier
## appel.

const ICON_SIZE := 64

var _item_icons: Dictionary = {}
var _buildable_icons: Dictionary = {}

## Forme de base par kind de constructible.
const _KINDS_SHAPES := {
	"foundation": "carre",
	"wall": "cercle",
	"half_wall": "cercle",
	"campfire": "feuille",
	"chest": "carre",
	"door": "carre",
	"roof": "carre",
	"roof_slope": "losange",
	"roof_ridge": "carre",
	"roof_corner_out": "losange",
	"roof_corner_in": "losange",
	"window": "carre",
	"furnace": "cercle",
	"tent": "carre",
	"bed": "carre",
	"generator": "cercle",
	"stairs": "losange",
	"house": "carre",
	"torch": "feuille",
	"gate": "losange",
	"fence": "carre",
	"bridge": "losange",
}

## Couleur de base par palier de construction (bois -> pierre -> brique -> métal).
const _TIER_COLORS := {
	1: Color(0.45, 0.28, 0.12),
	2: Color(0.35, 0.35, 0.38),
	3: Color(0.55, 0.42, 0.20),
	4: Color(0.60, 0.60, 0.65),
}


func get_item_icon(item: ItemData) -> Texture2D:
	if item == null or item.id == "":
		return null
	if _item_icons.has(item.id):
		return _item_icons[item.id]
	var icon := _build_item_icon(item)
	_item_icons[item.id] = icon
	return icon


func get_buildable_icon(buildable: BuildableData) -> Texture2D:
	if buildable == null or buildable.id == "":
		return null
	if _buildable_icons.has(buildable.id):
		return _buildable_icons[buildable.id]
	var icon := _build_buildable_icon(buildable)
	if icon != null:
		_buildable_icons[buildable.id] = icon
	return icon


func _build_item_icon(item: ItemData) -> Texture2D:
	var image := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_shape(image, item.icon_shape, item.icon_color, false)
	if item.rarity == "rare" or item.rarity == "epique":
		_draw_shape(image, item.icon_shape, Color(0.05, 0.05, 0.05, 1.0), true)
	return ImageTexture.create_from_image(image)


func _build_buildable_icon(buildable: BuildableData) -> Texture2D:
	var shape: String = _KINDS_SHAPES.get(buildable.kind, "carre")
	var color: Color = _TIER_COLORS.get(buildable.tier, _TIER_COLORS[1])
	var image := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_shape(image, shape, color, false)
	if buildable.tier > 1:
		_draw_shape(image, shape, Color(0.05, 0.05, 0.05, 1.0), true)
	return ImageTexture.create_from_image(image)


## Dessine une forme (cercle / carre / losange / goutte / feuille / lingot / bûche / outil),
## optionnel : contour liseré.
func _draw_shape(image: Image, shape: String, color: Color, outline: bool) -> void:
	var base_radius: float = min(ICON_SIZE, ICON_SIZE) * 0.38
	var radius: float = base_radius
	var half_width: float = base_radius
	var half_height: float = base_radius
	match shape:
		"lingot":
			half_height = base_radius * 0.35
		"buche":
			half_height = base_radius * 0.5
		"outil":
			half_width = base_radius * 0.5
			half_height = base_radius * 0.5
	if outline:
		radius += 1.5
		half_width += 1.5
		half_height += 1.5
	for y in range(ICON_SIZE):
		for x in range(ICON_SIZE):
			var px := x + 0.5
			var py := y + 0.5
			var dx: float = px - ICON_SIZE * 0.5
			var dy: float = py - ICON_SIZE * 0.5
			var inside := true
			if shape == "cercle" or shape == "goutte" or shape == "feuille":
				inside = dx * dx + dy * dy <= radius * radius
			elif shape == "losange":
				inside = abs(dx) / half_width + abs(dy) / half_height <= 1.0
			else:
				inside = abs(dx) <= half_width and abs(dy) <= half_height
			if inside:
				image.set_pixel(x, y, color)
