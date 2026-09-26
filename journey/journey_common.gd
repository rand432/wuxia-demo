extends RefCounted
# ============================================================
# journey_common.gd —— 游历公共小件 v1（拆件批）
# 拆分自 journey_stage v20，逐字搬运、零逻辑改：
#  · POPUP_TOP：7 个弹窗统一顶线——全游历唯一源（原住在 journey_stage）
#  · make_card_button()：事件三选一／货郎货架共用的卡牌按钮工厂
# 不引 journey_stage（防循环——老铁律）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const UiKit := preload("res://shared/ui_kit.gd")

# 弹窗统一顶线（7 个弹窗全用它）：想让弹窗整体上/下挪，只改这一个数。
# 384 = 包裹板底（60 + 306 = 366）再往下 18 像素。可用范围约 367 ~ 558。
const POPUP_TOP := 384.0

# 事件三选一 / 商店货架的卡牌按钮（原 journey_stage._make_card_button，逐字搬）
# v54（玩家反馈："游历的商店和选卡字体还是太小了"）：字号原来全按 h 的比例算，
#   小卡（商店那排 140×190）拿到的是"标签 11 / 名 13 / 加成 11"——**根本看不清**。
#   现在给每一行加了**下限**（标签 ≥14、名 ≥17、加成 ≥14），大卡按比例反而更大一点：
#     140×190 的小卡 → 14 / 41 / 17 / 14（原来是 11 / 38 / 13 / 11）
#     216×270 的事件卡 → 14 / 59 / 20 / 16（原来是 13 / 54 / 18 / 14）
#   框高也跟着放宽（22→26 / 26→30 / 24→28），免得放大之后被裁掉。
static func make_card_button(card: Dictionary, w := 216.0, h := 270.0) -> Button:
	var sid := str(card.get("set_id", ""))
	var part := int(card.get("part", 0))
	var b := Button.new()
	b.size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86, 1.0)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.45)
	sb.set_border_width_all(2)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color(1.0, 0.97, 0.88, 1.0)
	hov.border_color = UiKit.SEAL
	var pre: StyleBoxFlat = sb.duplicate()
	pre.bg_color = UiKit.PAPER_DARK
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", pre)

	# v54：标签 11→14 起
	var tag := UiKit.make_label(b, Vector2(0, h * 0.03), Vector2(w, 26), maxi(14, int(h * 0.052)), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.65))
	# R2：品级可见——高品残卡在卡面标出来（凡品不标）
	var kind_cn := "武学残页" if Cards.is_arts(sid) else "残缺兵器"
	var qn := Cards.quality_of(sid)
	if qn != "凡品":
		kind_cn += " · " + qn
	UiKit.set_text(tag, kind_cn)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var parts: Array = Cards.parts_of(sid)
	var pc := "?"
	if part >= 0 and part < parts.size():
		pc = str(parts[part])
	var big := UiKit.make_label(b, Vector2(0, h * 0.235), Vector2(w, h * 0.36), int(h * 0.215), UiKit.INK)
	UiKit.set_text(big, pc.right(1))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# v54：名字 13→17 起
	var nm := UiKit.make_label(b, Vector2(0, h * 0.66), Vector2(w, 30), maxi(17, int(h * 0.072)), UiKit.INK)
	UiKit.set_text(nm, str(Cards.card_name(sid, part)))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# v54：加成那一行 11→14 起
	var bl := UiKit.make_label(b, Vector2(0, h * 0.79), Vector2(w, 28), maxi(14, int(h * 0.058)), UiKit.SEAL)
	UiKit.set_text(bl, str(Cards.bonus_text(Cards.card_bonus(sid))))
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b
