extends RefCounted

const LACQUER = preload("res://assets/art/command_lacquer.webp")
const SILK = preload("res://assets/art/campaign_silk.webp")
const PAPER = preload("res://assets/art/order_paper.webp")
const WALNUT = preload("res://assets/art/table_walnut.webp")

# Nine-slicing keeps the bronze corner inlays the same size on a card or a long rail.
static func plaque(tint: Color = Color.WHITE, paper: bool = false) -> StyleBoxTexture:
    var box := StyleBoxTexture.new()
    box.texture = PAPER if paper else LACQUER
    box.modulate_color = tint
    for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
        box.set_texture_margin(edge,12)
        box.set_content_margin(edge,0)
    return box
