# Port nốt item / skill / item của hệ (yêu cầu 2026-09-28)

Người dùng: "port nốt tất cả item, skill, fraction's item như mũ đầu bếp, món ăn, cây...".
Khối lượng lúc bắt đầu: 541 skill trên web (đã port 118; Pokémon shop còn thiếu 197 skill / 431 Pokémon),
358 item (có hiệu ứng ~44). Làm theo thứ tự dưới, đánh dấu [x] khi xong + test.

## A. Item của hệ (giữa các stage + trong trận)

- [x] Gourmet: mũ đầu bếp (1/1/2 theo mốc), nấu món (`DishByPkm`) cho đồng minh kề mạnh nhất, ăn đầu trận
      (`app/core/effects/dishes.ts`, `chefCookEffect` trong `items.ts`, `updateChefsHats` trong `player.ts`)
- [x] Grass: cây quả mọng (1/2/3 cây, vàng ở mốc 4), thu hoạch quả, quả mọng cầm được (ăn khi < 50% HP)
- [x] Water: cần câu Old/Good/Super → câu Pokémon ra bench mỗi stage (`FishingRodEffect`, `shop.pickFish`)
- [x] Normal: Silk Scarf + 10 khăn ghép (Scarves) (+ Fur Coat cho Silk Scarf)
- [x] Artificial: 3 công cụ ngẫu nhiên mỗi run theo mốc + hiệu ứng mọi Tool (cả đồ chôn: Explorer Kit, Air Balloon...)
- [x] Human: TM đồng / bạc / vàng dạy skill (12 skill TM đã port), trả về kho khi về bench / bán
- [x] Baby: trứng sau trận thua → nở 13 dòng HATCH (12 skill mới), trứng vàng
- [x] Flora: 5 chậu hoa nở trong trận, phân bón nuôi chậu / cây (5 skill mới), UI chậu ở góc trên trái
- [x] Psychic: shop Unown (mốc 1/2/3) + 28 Hidden Power
- [x] Fire 4: Fire Shard; Electric 3: Cell Battery (siêu nạp)
- [x] Aquatic 4: Pikachu lướt sóng (skill SURF)
- [x] Rock: đá thời tiết — web KHÔNG cho ở trận PvE (Endless toàn PvE) → giữ nguyên, không có

## B. Item còn lại dùng được trong Endless

- [x] Item vàng của trứng vàng (ShinyItems): Dynamax Band, Star Piece, Sacred Ash (hồi sinh 3 đồng minh),
      Absorb Bulb, Gold Mask (gọi 3–4 Pokémon cùng hệ), Gold Bottle Cap, Repeat Ball, Rare Candy (tiến hoá ngay),
      Eviolite (không ghép), Shiny Stone (Necrozma / Cherrim), Gold Bow (không tính sĩ số)
- [x] Amulet Coin (+1 vàng mỗi hạ gục, -1 lãi tối đa), Incense / Honey (shop 5% ra Pokémon cùng hệ),
      Fossil Stone (nguyên liệu, đá tiến hoá), Leftovers (món không hiệu ứng như web)
- [x] Eevee: 1/20 trong 3 starter kèm Fossil Stone, tiến hoá theo đá (`evolutionByItem` do exporter xuất)
- [x] Town encounter (web `mini-game.ts`, `Town.PORTED_ENCOUNTERS`): Meowth (4 Amulet Coin), Cinccino (4 Silk Scarf),
      Electivire (shop công cụ, 10 vàng), Kecleon (item hệ của 3 tộc mạnh nhất, 10 vàng), Ludicolo (7 nhạc cụ báu:
      shop 5% ra hệ tương ứng), Chansey (trứng 7 vàng), Wobbuffet (Recycle Ticket), Croagunk (Exchange Ticket),
      Munchlax (Picnic Set → Sandwich), Chimecho (Soothe Bell → đổi shop theo hệ), Lapras (Passport → đổi vùng),
      Makuhita (vé Võ đường: đi 3 stage, về +HP/ATK/AP, Thế Thân giữ chỗ), Magnezone (Wanted Notice: +10 vàng ở stage 5–15),
      Wigglytuff (chọn 1 trong 3 Mission Order, +30 vàng), Spinda (chỉ trang trí).
      Vé đổi/tái chế còn thả được lên một item khác trong kho đồ (`PlayerState.use_ticket`).
- [x] Celebi (trận PvE kế tiếp shiny + thưởng shiny), Kingambit (Leaders Crest, chỉ tác dụng khi đấu người) — 2026-10-04.
- [ ] Không port (chỉ có tác dụng PvP): Mission Order đỏ, đá thời tiết (Rock).

## Hạ tầng đã thêm

- `src/core/synergy_items.gd` (item hệ giữa stage + quả mọng trong trận), `src/core/dish_effects.gd`,
  `src/core/ability_scripts.gd` (skill viết bằng code: `"script": "<tên>"` trong abilities.json),
  `src/ui/garden_panel.gd` (cây quả mọng góc trên trái), `BattleUnit.owned` (OwnedUnit: thay đổi vĩnh viễn trong trận),
  `BattleSim.rewards` (vàng / lượt đổi shop / item nhận trong trận), trạng thái `spike_armor`, `magic_bounce`,
  `PlayerState.merge_count()` (8 Magikarp, 6 Feebas...), exporter: `dishByPkm`, `fishRarity`, `evolutionCount`.

## C. Skill (theo đợt, ưu tiên Pokémon shop, rồi Unique / Legendary / Hatch)

- [x] ATTRACT, OCTAZOOKA, SCHOOLING (cá câu được)
- [x] TM: RAGE, RETURN, COUNTER, DISABLE, BULK_UP, CHARGE, PAYDAY, HYPER_BEAM, FOCUS_PUNCH, SUBSTITUTE, SKILL_SWAP
- [x] HATCH: DRAGON_DARTS, FAKE_TEARS, FOUL_PLAY, HEAT_CRASH, OUTRAGE, POWDER, PYRO_BALL, SLUDGE_WAVE, SPARKLING_ARIA,
      SPIRIT_SHACKLE, WATER_SHURIKEN, ZAP_CANNON
- [x] Chậu hoa: ACROBATICS, INGRAIN, SWEET_SCENT, STUN_SPORE, PETAL_BLIZZARD; SURF; 28 HIDDEN_POWER_*
- [x] Đợt 1–14 (~140 skill): mọi skill của các họ Pokémon shop (COMMON → ULTRA, không regional) đã port
      → pool 275 Pokémon shop. Ô sàn mới: POISON_GAS, SMOKE, SPIKES, STICKY_WEB (`BattleSim._each_second`),
      Wonder Room (`wonder_room_until`), đòn kế tiếp +special (`next_attack_special`), Silk Trap.
- [x] Đợt 15–32: mọi skill UNIQUE (103), LEGENDARY (56), SPECIAL (8) → pool 100 unique, 74 legendary.
      Cơ chế mới kèm theo: POSSESSED đổi phe (`BattleSim._possess`), Bide (`bide_damage`, `no_pp_gain`),
      Lock-On, Volt Surge, Ball (Fling), COTTON_BALL, thưởng sau trận `rewards.exp/life/pokemon`.
      Tổng: 481 skill trong data/abilities.json, 473 được cast thử trong sim_test.
- [x] Regional (đợt 33–37, 67 skill) + shop vùng (2026-09-30): `PlayerState.change_map / update_regional_pool`,
      biến thể Alola / Galar / Hisui, đề xuất theo vùng, ~20 passive regional, item đổi dạng (Rotom Catalog, Nectar,
      Mask Ogerpon), sàn STRANGE_STEAM / STEALTH_ROCKS. Chi tiết: `docs/PORTING.md` mục "Vùng và Pokémon regional".
      Tổng: 548 skill, 540 được cast thử; pool 279 shop + 316 additional + 130 regional + 110 unique + 78 legendary.
      Công cụ trong `tools/port/`: `show_abilities.py`, `add_batch.py`, `check_texts.py`, `gen_vfx.py`.
- [x] VFX: `tools/port/gen_vfx.py` dịch tự động entry đơn giản của `abilities-animations.ts` → 409 skill có spec
      (104 viết tay + 305 sinh tự động). Còn ~140 skill không có spec: xem `python tools/port/gen_vfx.py`.

## Luật mới đã port kèm theo

- Về bench: Chef Hat, Trash, công cụ, khăn, TM tự về kho (`PlayerState._unequip_on_bench`, web RemovableItems).
- Món ăn: kéo món trong kho lên Pokémon = ăn (1 món/lần, Big Eater Belt 2); ăn trước trận, hiệu ứng ở trận kế.
- Quả mọng cầm: ăn khi < 50% HP (hết vĩnh viễn); quả vàng cho vàng / lượt đổi shop / kẹo sau trận.
- Repeat Ball: đổi shop bằng vàng được thêm lượt miễn phí; từ 80 / 120 lượt (đổi shop + stage), cứ 10 lượt một ô shop
  ra Unique / Legendary.
- Tiếng Việt: tên 183 skill mới (`data/i18n/vi.json` mục `ability`), 268 mô tả skill (`ability_port`), ~40 item mới;
  mô tả còn lại dùng bản dịch web (`data/pac/lang/vi.json`).

## D. Port nốt (yêu cầu 2026-10-04: "đọc handoff và port toàn bộ những gì còn thiếu")

- [x] 24 skill `approx` viết lại đúng web + Magnet Pull, Dream Eater, Hail; Attack / Heal / Defend Order (Vespiquen theo
      hàng, gọi Combee) → 551 skill, không còn `approx`.
- [x] Luật trạng thái `status.ts` (CONFUSION nhắm cả đồng minh, CHARM, không gia hạn CC + miễn 1,5 s, RAGE, SILENCE với cây,
      CURSE lần hai, LOCKED tầm 1, quả mọng giải trạng thái), hồi sinh 2 s về chỉ số lúc vào trận, Reflect, Wonder Guard.
- [x] Passive viết lại theo `passives.ts` (Illusion trên sàn, Falinks, Comfey, Commander, Conversion, Manaphy, Finizen,
      Eiscue, Mimikyu, Primeape, Basculin, Minior, Kubfu, Guzzlord, Poipole...).
- [x] Tiến hoá đặc biệt `EvolutionRules` (stack / state / map / money / placement / item, Shedinja, Cosmog, Vivillon, Meltan,
      Deoxys, Zygarde, giáp Charcadet, cuộn Kubfu, hương vị Milcery, đĩa Silvally).
- [x] Shop: Ditto / Meltan / lính Falinks, bỏ dạng đầu của họ đã tiến hoá hết, giá mua / bán theo web.
- [x] Pokémon lang thang bấm để bắt (Magnet Pull, kẻ truy nã), trận shiny, duo trong đề xuất, thưởng stage theo web,
      Treasure Box đủ loại, Deerling theo mùa, thanh máu POSSESSED đổi màu, panel địch hiện chỉ số đã nhân của wave.
- [x] VFX: +64 spec (Hidden Power: Unown xoắn ốc, Water Shuriken, Prismatic Laser...) → 473 skill; 78 còn lại web không có.
- [x] Thêm riêng: kỷ lục theo độ khó (`Records`), Android (preset + `TouchInput` chạm giữ), APK debug export được.
- [x] (2026-11-11) VFX cho 78 skill web không có animation, màn thống kê sau run (`RunStats` / `RunSummary`), soát
  `shop.ts` (bản sao rời pool lúc hiện trong shop, bán trả tối đa 9) + Applin / Dipplin / Hydrapple ăn táo.
- [x] (2026-11-14) Battle Pass: mở khoá hệ qua nhiều run (`docs/PROGRESSION.md`), `layout_test`, tool chụp ảnh trên
  desktop ẩn (`tools\screenshot_hidden.bat`).
- [x] (2026-11-14) UI mobile: phóng to theo màn hình (`UiScale`), HUD bố cục gọn + camera tự căn, chạm = xem chi tiết.
- [x] (2026-11-14) Bố cục gọn bản 2 theo ảnh máy thật (canvas 1171×540): không tràn, bảng Pokémon dạng gọn, thanh stage
      hai dòng; sửa lỗi chỉ có ở bản export (`grow_vertical` bị bỏ khi đóng gói scene) + test `_export_fidelity`.
- [ ] Xác nhận bố cục gọn bản 2 trên máy thật, ký release.
