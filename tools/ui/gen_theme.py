"""Writes scenes/ui/theme/ui_theme.tres from the pixel-art skin (assets/ui/skin/skin.json, tools/ui/gen_skin.py).

Every style of the theme is a StyleBoxTexture (nine-patch) on one of the skin images, wrapped in a CanvasTexture so
UiSkin can switch the filter (NEAREST at whole UI scales, LINEAR otherwise). Edit STYLES / ENTRIES here, not the
.tres (it is written again by this script).

  python tools/ui/gen_skin.py && python tools/ui/gen_theme.py      then: Godot --headless --path . --import
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SKIN = os.path.join(ROOT, "assets", "ui", "skin", "skin.json")
THEME = os.path.join(ROOT, "scenes", "ui", "theme", "ui_theme.tres")
AXIS = {"stretch": 0, "tile": 1, "tile_fit": 2}

# theme style id -> (skin image, content margins [l, t, r, b], modulate or None)
STYLES = {
    "box": ("box", [3, 3, 3, 3], None),
    "button_disabled": ("button_disabled", [10, 6, 10, 6], None),
    "button_focus": ("focus", [10, 6, 10, 6], None),
    "button_hover": ("button_hover", [10, 6, 10, 6], None),
    "button_normal": ("button", [10, 6, 10, 6], None),
    "button_pressed": ("button_pressed", [10, 6, 10, 6], None),
    "choice": ("choice", [10, 6, 10, 6], None),
    "fight": ("fight", [10, 6, 10, 6], None),
    "fight_hover": ("fight_hover", [10, 6, 10, 6], None),
    "fight_pressed": ("fight_pressed", [10, 6, 10, 6], None),
    "hpbar_bg": ("bar_bg_18", [0, 0, 0, 0], None),
    "hpbar_fill": ("bar_hp_18", [0, 0, 0, 0], None),
    "panel": ("panel", [10, 6, 10, 6], None),
    "item_slot": ("item_slot", [4, 4, 4, 4], None),
    "item_slot_empty": ("item_slot_empty", [4, 4, 4, 4], None),
    "portrait_cell": ("portrait_cell", [0, 0, 0, 0], (0.55, 0.55, 0.55, 1)),
    "ppbar_bg": ("bar_bg_16", [0, 0, 0, 0], None),
    "ppbar_fill": ("bar_pp_16", [0, 0, 0, 0], None),
    "bar_bg": ("bar_bg_8", [0, 0, 0, 0], None),
    "bar_fill": ("bar_blue_8", [0, 0, 0, 0], None),
    "timerbar_fill": ("bar_orange_8", [0, 0, 0, 0], None),
    "sell": ("sell", [10, 6, 10, 6], None),
    "card_empty": ("card_empty", [10, 6, 10, 6], None),
    "card": ("card", [10, 6, 10, 6], (0.6, 0.6, 0.6, 1)),
    "shop": ("panel_shop", [10, 6, 10, 6], None),
    "synergy_badge": ("synergy_badge", [3, 3, 3, 3], (0.3, 0.32, 0.36, 1)),
    "synergy_row": ("synergy_row", [10, 6, 10, 6], None),
    "synergy_row_off": ("synergy_row_off", [10, 6, 10, 6], None),
    "tip": ("tip", [12, 10, 12, 10], None),
    "tip_pinned": ("tip_pinned", [12, 10, 12, 10], None),
    "unit_banner": ("banner", [0, 0, 0, 0], None),
    "unit_item_slot": ("unit_item_slot", [4, 4, 4, 4], None),
    "unit": ("panel_tint", [10, 6, 10, 6], (0.62, 0.68, 0.86, 1)),
    "xpbar_bg": ("bar_bg_16", [0, 0, 0, 0], None),
    "xpbar_fill": ("bar_xp_16", [0, 0, 0, 0], None),
}

# the [resource] part: type entries (colours, font sizes, which style)
ENTRIES = """default_font_size = 18
BannerLabel/base_type = &"Label"
BannerLabel/colors/font_color = Color(1, 0.82, 0.3, 1)
BannerLabel/colors/font_outline_color = Color(0, 0, 0, 0.9)
BannerLabel/constants/outline_size = 10
BannerLabel/font_sizes/font_size = 56
BoxPanel/base_type = &"PanelContainer"
BoxPanel/styles/panel = SubResource("box")
Button/colors/font_color = Color(0.94, 0.95, 0.97, 1)
Button/colors/font_disabled_color = Color(0.42, 0.45, 0.5, 1)
Button/colors/font_hover_color = Color(1, 1, 1, 1)
Button/colors/font_pressed_color = Color(1, 0.8, 0.42, 1)
Button/font_sizes/font_size = 18
Button/styles/disabled = SubResource("button_disabled")
Button/styles/focus = SubResource("button_focus")
Button/styles/hover = SubResource("button_hover")
Button/styles/normal = SubResource("button_normal")
Button/styles/pressed = SubResource("button_pressed")
ChoicePanel/base_type = &"PanelContainer"
ChoicePanel/styles/panel = SubResource("choice")
DimLabel/base_type = &"Label"
DimLabel/colors/font_color = Color(0.6, 0.64, 0.73, 1)
DimLabel/font_sizes/font_size = 14
FightButton/base_type = &"Button"
FightButton/font_sizes/font_size = 24
FightButton/styles/hover = SubResource("fight_hover")
FightButton/styles/normal = SubResource("fight")
FightButton/styles/pressed = SubResource("fight_pressed")
GoldLabel/base_type = &"Label"
GoldLabel/colors/font_color = Color(1, 0.82, 0.3, 1)
GoldLabel/font_sizes/font_size = 24
HintLabel/base_type = &"Label"
HintLabel/colors/font_color = Color(0.6, 0.64, 0.73, 1)
HintLabel/font_sizes/font_size = 13
HpBar/base_type = &"ProgressBar"
HpBar/styles/background = SubResource("hpbar_bg")
HpBar/styles/fill = SubResource("hpbar_fill")
HudPanel/base_type = &"PanelContainer"
HudPanel/styles/panel = SubResource("panel")
ItemSlot/base_type = &"PanelContainer"
ItemSlot/styles/panel = SubResource("item_slot")
ItemSlotEmpty/base_type = &"PanelContainer"
ItemSlotEmpty/styles/panel = SubResource("item_slot_empty")
Label/colors/font_color = Color(0.94, 0.95, 0.97, 1)
OutlinedLabel/base_type = &"Label"
OutlinedLabel/colors/font_color = Color(1, 1, 1, 1)
OutlinedLabel/colors/font_outline_color = Color(0, 0, 0, 0.9)
OutlinedLabel/constants/outline_size = 4
OutlinedLabel/font_sizes/font_size = 14
Panel/styles/panel = SubResource("panel")
PanelContainer/styles/panel = SubResource("panel")
PortraitCell/base_type = &"PanelContainer"
PortraitCell/styles/panel = SubResource("portrait_cell")
PpBar/base_type = &"ProgressBar"
PpBar/styles/background = SubResource("ppbar_bg")
PpBar/styles/fill = SubResource("ppbar_fill")
ProgressBar/font_sizes/font_size = 12
ProgressBar/styles/background = SubResource("bar_bg")
ProgressBar/styles/fill = SubResource("bar_fill")
RichTextLabel/colors/default_color = Color(0.94, 0.95, 0.97, 1)
RichTextLabel/fonts/bold_font = ExtResource("font_bold")
RichTextLabel/fonts/bold_italics_font = ExtResource("font_bold_italic")
RichTextLabel/fonts/italics_font = ExtResource("font_italic")
SellPanel/base_type = &"PanelContainer"
SellPanel/styles/panel = SubResource("sell")
ShopCard/base_type = &"Button"
ShopCard/styles/disabled = SubResource("card_empty")
ShopCard/styles/normal = SubResource("card")
ShopPanel/base_type = &"PanelContainer"
ShopPanel/styles/panel = SubResource("shop")
SynergyBadge/base_type = &"PanelContainer"
SynergyBadge/styles/panel = SubResource("synergy_badge")
SynergyRow/base_type = &"PanelContainer"
SynergyRow/styles/panel = SubResource("synergy_row")
SynergyRowInactive/base_type = &"PanelContainer"
SynergyRowInactive/styles/panel = SubResource("synergy_row_off")
TimerBar/base_type = &"ProgressBar"
TimerBar/styles/background = SubResource("bar_bg")
TimerBar/styles/fill = SubResource("timerbar_fill")
TipPanel/base_type = &"PanelContainer"
TipPanel/styles/panel = SubResource("tip")
TipPanelPinned/base_type = &"PanelContainer"
TipPanelPinned/styles/panel = SubResource("tip_pinned")
TitleLabel/base_type = &"Label"
TitleLabel/colors/font_color = Color(1, 0.82, 0.3, 1)
TitleLabel/font_sizes/font_size = 19
UnitBanner/base_type = &"PanelContainer"
UnitBanner/styles/panel = SubResource("unit_banner")
UnitItemSlot/base_type = &"PanelContainer"
UnitItemSlot/styles/panel = SubResource("unit_item_slot")
UnitPanel/base_type = &"PanelContainer"
UnitPanel/styles/panel = SubResource("unit")
XpBar/base_type = &"ProgressBar"
XpBar/styles/background = SubResource("xpbar_bg")
XpBar/styles/fill = SubResource("xpbar_fill")
"""


def num(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def main():
    images = json.load(open(SKIN, encoding="utf-8"))["images"]
    used = sorted({skin for skin, _, _ in STYLES.values()})
    out = ['[gd_resource type="Theme" format=3 uid="uid://bmjtkrgtpa8yq"]', ""]
    out.append('[ext_resource type="FontFile" uid="uid://bvy8xy03qihyy" path="res://assets/fonts/BeVietnamPro-Bold.ttf" id="font_bold"]')
    out.append('[ext_resource type="FontFile" uid="uid://bfwahqjl0hbxq" path="res://assets/fonts/BeVietnamPro-BoldItalic.ttf" id="font_bold_italic"]')
    out.append('[ext_resource type="FontFile" uid="uid://dkndfb173ndmf" path="res://assets/fonts/BeVietnamPro-Italic.ttf" id="font_italic"]')
    for skin in used:
        out.append('[ext_resource type="Texture2D" path="res://assets/ui/skin/%s.png" id="png_%s"]' % (skin, skin))
    out.append("")
    for skin in used:
        out.append('[sub_resource type="CanvasTexture" id="tex_%s"]' % skin)
        out.append('diffuse_texture = ExtResource("png_%s")' % skin)
        out.append("")
    for style_id in sorted(STYLES):
        skin, content, modulate = STYLES[style_id]
        spec = images[skin]
        l, t, r, b = spec["margin"]
        out.append('[sub_resource type="StyleBoxTexture" id="%s"]' % style_id)
        for side, v in zip(("left", "top", "right", "bottom"), content):
            out.append("content_margin_%s = %s.0" % (side, v))
        out.append('texture = SubResource("tex_%s")' % skin)
        for side, v in zip(("left", "top", "right", "bottom"), (l, t, r, b)):
            out.append("texture_margin_%s = %s.0" % (side, v))
        if spec["expand"]:
            for side in ("left", "top", "right", "bottom"):
                out.append("expand_margin_%s = %s.0" % (side, spec["expand"]))
        h, v = spec["axis"]
        if AXIS[h]:
            out.append("axis_stretch_horizontal = %d" % AXIS[h])
        if AXIS[v]:
            out.append("axis_stretch_vertical = %d" % AXIS[v])
        if modulate:
            out.append("modulate_color = Color(%s)" % ", ".join(num(float(x)) for x in modulate))
        out.append("")
    out.append("[resource]")
    out.append(ENTRIES.rstrip("\n"))
    with open(THEME, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("theme: %d styles on %d skin images -> %s" % (len(STYLES), len(used), THEME))


if __name__ == "__main__":
    main()
