# Handoff — port Godot của PAC Endless (cập nhật 2026-11-15)

File này để mở phiên mới làm tiếp. Đọc theo thứ tự: `CLAUDE.md` (cấu trúc code, quy ước, lệnh) →
file này (trạng thái, việc còn lại, cách làm) → `docs/TODO_PORT.md` (checklist chi tiết).
Người dùng viết tiếng Việt → trả lời tiếng Việt; code / tên định danh / lệnh để tiếng Anh.

## 1. Trạng thái hiện tại

| Mảng | Tình trạng |
|---|---|
| Skill | **551** trong `data/abilities.json` (456 viết bằng code trong `src/core/ability_scripts.gd`, còn lại data-driven). Đủ mọi Pokémon shop COMMON → ULTRA, UNIQUE, LEGENDARY, SPECIAL, regional. **Không còn skill `approx`** (2026-10-04: 24 skill viết lại đúng web + Magnet Pull, Dream Eater, Hail, 3 lệnh Vespiquen). |
| Pool (exporter) | 279 shop + 316 additional + 130 regional + 120 unique (kể cả duo) + 78 legendary + 58 hatch + 185 extras (dạng tạm / dạng tiến hoá đặc biệt); sprite + portrait shiny |
| Shop vùng | xong (2026-09-30): pool vùng theo map, biến thể Alola / Galar / Hisui, đề xuất theo vùng, nhãn vùng trên HUD. Chi tiết `docs/PORTING.md` mục "Vùng và Pokémon regional" |
| Passive regional | Illusion, Acceleration, Water Spring, Surge Surfer, Vigoroth, Slaking, Steely Spirit, Hisuian Typhlosion, Galarian Darmanitan (Zen), Corsola, Hisuian Qwilfish, Avalugg, 4 terrain Tapu, Ogerpon, Burmy, Galarian Slowpoke |
| Item của hệ | đủ: mũ đầu bếp / món ăn, cây quả mọng, cần câu, chậu hoa + phân bón, trứng Baby, TM Human, khăn Normal, công cụ Artificial, Unown Psychic, Fire Shard, Cell Battery, Pikachu lướt sóng |
| Item khác | item vàng của trứng vàng, Amulet Coin, Incense/Honey, Fossil Stone + đá tiến hoá (Eevee), vé / chuông / hộ chiếu / vé Võ đường / nhiệm vụ / lệnh truy nã / 7 nhạc cụ, Ball, Repeat Ball, **Rotom Catalog, 4 Nectar (Oricorio), 4 Mask (Ogerpon)** |
| Town encounter | **23/23** (Celebi → trận PvE kế tiếp shiny; Kingambit → Leaders Crest) |
| Luật trận (2026-10-04) | trạng thái theo `status.ts` (CONFUSION nhắm cả đồng minh, CHARM, không gia hạn CC + miễn 1,5 s, RAGE, SILENCE / CURSE / LOCKED...), hồi sinh 2 s, Reflect, Wonder Guard, di chuyển cưỡng bức (`force_move`, `swap_cells`, `_on_displaced`) |
| Passive / tiến hoá (2026-10-04) | `passive_effects.gd` viết lại theo `passives.ts` (nhiều passive mới, hook `on_second` / `on_status` / `on_resurrect`...); `evolution_rules.gd` (stack / state / map / money / placement / item, Shedinja, Cosmog, Basculin, Vivillon, Meltan...) |
| Shop / thưởng (2026-10-04) | Ditto / Meltan / lính Falinks, giá mua / bán theo web, duo trong đề xuất, Pokémon lang thang bấm để bắt (Magnet Pull, kẻ truy nã), trận shiny + thưởng stage theo `pve-stages.ts` |
| VFX | **mọi skill** có spec trong `data/ability_vfx.json`: 473 theo web (viết tay + `tools/port/gen_vfx.py`) + 78 skill web không có animation được gán hiệu ứng dùng lại sheet có sẵn (2026-11-11; `SKETCH`, `VESPIQUEN_ORDERS` để `[]` vì không làm gì) |
| Tiếng Việt | đủ chuỗi UI, tên + mô tả mọi skill, item và passive mới (`python tools/port/check_texts.py` → 0 thiếu) |
| Độ khó / wave | xong (2026-09-30): 3 mức (`data/difficulty.json`), wave địch kích hệ + cầm item, template wave (`data/wave_templates.json`), tool `tools\wave_editor.bat`. Chi tiết `docs/DIFFICULTY.md` |
| Font | **Be Vietnam Pro** (`assets/fonts/`, 2026-10-01), MSDF bật trong `.import` (xem CLAUDE.md) |
| Mana (PP) | luật cơ bản cấu hình trong `data/difficulty.json` → `mana` (2026-10-01; theo vai trò từ 2026-11-18): Tank 100 PP, +10 mỗi đòn trúng, +10 mỗi lần bị đòn đánh trúng; các vai trò khác 70 PP, +10 / +5; skill không cho PP khi trúng; không hồi theo giây (luật web: `Difficulty.WEB_MANA`). Fighter chưa được người dùng chốt (đang như Marksman). Chi tiết `docs/DIFFICULTY.md` |
| Pool shop | nút **!** cạnh ổ khoá → `PoolTip` (Pokémon đã vào shop theo stage, sắp vào, Pokémon vùng); banner đầu stage chỉ còn một dòng (2026-10-01) |
| Ground | hố vẽ thành hố đất trên sàn (shader `board.gdshader` `apply_hole`), chữ `độ sâu/5` (`Arena.set_cell_labels`), ô sắp đào viền cam |
| Tooltip hệ | lưới Pokémon theo nhóm như web (`Tooltips.synergy_groups`: shop, additional, regional, unique, legendary; Flabébé gộp một ô), viền theo giá, ✓ = có trong đội, khoá = shop chưa có; hover → thẻ nhỏ có điều kiện unlock (`Tooltips.unlock_info`) |
| Bench / kinh tế / cheat | `benchSize` 8 ô × `benchStack` 2 con giống nhau mỗi ô (2026-11-15; một hàng trên sàn), `goldPerWave`, `cheats` trong `data/difficulty.json`; bảng cheat F1 (`CheatPanel`, `Game.cheat_*`) — `docs/DIFFICULTY.md` |
| Tài liệu tra cứu | `docs/WORLD.md` (thời tiết + 143 vùng, sinh bằng `python tools/port/gen_world_doc.py`) |
| Kỷ lục | `src/game/records.gd`: stage cao nhất + đội + số lượt theo **mùa + độ khó** (`user://records.cfg`, khoá `<độ khó>@<mùa>`), hiện ở menu chính và Game Over; run có cheat không tính |
| Battle Pass | (2026-11-14) mở khoá hệ qua nhiều run: `data/progression.json`, `src/core/progression.gd` (`Progression`), `GameData.apply_progression()` (gỡ hệ khoá khỏi Pokémon / vùng / pool / item), `src/ui/pass_panel.gd`; lưu ở `user://progress.cfg`. Từ 2026-11-16: bắt đầu 3 hệ (Fire, Water, Grass), +100 XP mỗi run chơi tới hết, 1 run → cấp 2 (+1 hệ), rồi 3 run một cấp (+2 hệ), 16 cấp. Chi tiết `docs/PROGRESSION.md` |
| Mùa | (2026-11-15) danh sách Pokémon **cố định** cho mỗi run, chọn ở menu chính (kiểu TFT set): `data/seasons.json` — 3 mùa × 96 họ shop (hệ đại trà 8–10 họ, hệ đặc biệt 3–5 họ + mốc riêng, mỗi mùa 4 hệ đặc trưng), Unique / Legendary / trứng theo mùa; `src/core/seasons.gd` (`Seasons`), `GameData.apply_progression()` (áp mùa rồi tới pass), `src/ui/season_panel.gd`, tool `tools/port/gen_seasons.py`. Chi tiết `docs/SEASONS.md`, mục 10 |
| Thống kê sau run | (2026-11-11) `src/game/run_stats.gd` (`RunStats`: cộng `Game.fight_stats` từng trận theo họ Pokémon) + `src/ui/run_summary.gd` (`RunSummary`) trên bảng Game Over: số trận thắng / thua, thời gian, cấp, vàng, số lần đổi shop, đội cuối, top 5 sát thương, chặn / hồi nhiều nhất, trận hay nhất |
| Android | `export_presets.cfg` (Android + Windows), APK debug ở `build/`. Chạy trên Oppo Reno 15 Pro (2026-11-14): lần 1 chữ quá nhỏ → **UI mobile** (`UiScale` phóng to canvas, bố cục gọn, chạm = xem chi tiết); lần 2 chữ vừa nhưng UI tràn → **bố cục gọn bản 2** + sửa lỗi chỉ có ở bản export (bảng Pokémon lệch lên trên). Xem mục 9 |
| Test | `sim_test` (có `_check_every_ability`, `_check_regions`, `_check_difficulty`, `_check_ported_rules`, `_check_records`...), `flow_test`, `soak_test` đều OK (2026-10-04); 2026-11-15: thêm `_check_seasons`, soak ở cả 3 mùa và không mùa |

## 2. Việc còn lại (ưu tiên từ trên xuống)

Đợt 2026-10-04 đã port nốt mọi thứ của Endless solo (xem `docs/PORTING.md` mục "Port nốt phần còn thiếu").
Còn lại là việc riêng của bản port:

- **Mùa** (2026-11-15): danh sách 3 mùa do `tools/port/gen_seasons.py --generate` tính (đúng ràng buộc số họ / độ hiếm /
  Battle Pass cấp 1) — chờ người dùng xem `docs/SEASONS.md` rồi chỉnh tay hoặc đổi tham số (chủ đề, hệ đặc trưng, số
  họ). Mốc riêng của hệ đặc biệt là công thức (từ 2 tới số họ của hệ), chưa cân qua chơi thật — vd Rồng 2/3/4 ở mùa 2
  kích "hệ thứ hai tính đôi" chỉ với 2 con. Ý tưởng tiếp: mùa bỏ hẳn vài hệ, mùa mở dần theo Battle Pass.
  **Hệ mới theo chủ đề** (2026-11-16): người dùng muốn thêm hệ kiểu Y tế, Vận chuyển, Trâu bò, Ngựa… — đã gom
  `docs/THEMES.md` + `docs/themes.html` (55 điểm chung cho 508 họ, mỗi họ có thể nhiều điểm chung, gợi ý ghép mùa, cách
  TFT Set 19 xếp hệ). Chờ người dùng chọn; dữ liệu nguồn ở `tools/port/themes/` (sửa tag rồi chạy
  `python tools/port/gen_themes.py`). Một hệ mới trong game cần: id trong `config.synergyThresholds`, hiệu ứng
  (`synergy_effects.gd`), icon `assets/types`, chữ 14 ngôn ngữ, gắn vào `types` của Pokémon (data export) — chưa làm.
- **Battle Pass**: từ 2026-11-16 tính theo ván — bắt đầu 3 hệ (Fire, Water, Grass), +100 XP mỗi run chơi tới hết,
  1 run → cấp 2 (+Normal), rồi 3 run một cấp (+2 hệ), 16 cấp (`docs/PROGRESSION.md`). Từ 2026-11-18: tới vùng nào thì hệ còn khoá của vùng đó **mở tạm tới hết run** (`GameData.unlock_for_run`, `PlayerState.change_map`; cổng ghi "Mở tạm"); ý tăng độ khó sau stage 50 ở 10 cấp đầu người dùng đã bỏ. Người dùng ghi "không cần test"
  nên **chưa chạy test nào** sau đợt đổi này; kỳ vọng trong `sim_test` đã sửa theo (shop cấp 1 ≥ 3 họ mỗi độ hiếm,
  trong mùa ≥ 2; nhịp 1 run / 3 run) — lần chạy `sim_test` tới sẽ xác nhận. Pass của máy dev bắt đầu ở cấp 1: mở màn
  Battle Pass ở menu chính → **Mở hết** (nút cheat, có khi `cheats` bật) nếu cần test đủ hệ, hoặc chạy với `-- pass=all`.
- **Bot tự chơi — đã làm 2026-11-18** (`docs/BOT.md`: `tools/bot_run.bat`, `tools/bot/`, `src/core/run_rules.gd`), có **bot pro**
  bản 2 (thích ứng theo run, phán đoán bằng mô hình thắng học từ data: `tools/bot/model.json`, `train_model.py`), **design
  test** (`-Design`: mọi cặp hệ của mùa) và **tự cân bằng** (`data/balance.json` + `tools/bot/autobalance.py` /
  `tools/autobalance.ps1`: chỉ số riêng của từng Pokémon — HP / ATK / DEF / SPE_DEF / SPEED / skill / **PP tối đa** (2026-11-19:
  không còn theo vai trò), học từ lô bot theo tiêu chí của người dùng: vai trò, có / không item, độ hiếm, số lần cast mỗi trận
  — mục tiêu trong `tools/bot/balance_targets.json`; người dùng 2026-11-18: chỉ số chưa cân, mục tiêu là cân tự động từ data
  bot, mỗi Pokémon chỉ số riêng — không có hệ số theo hệ; mục tiêu cuối: nhiều chiến thuật carry + item + hệ, không chiến
  thuật nào áp đảo). **Phiên sau: design test bản 2** (mọi tổ hợp đội hình carry × item × hệ × cấu trúc vai trò, đánh giá
  đội hình với nhau) và **tracking hiệu quả buff** (sát thương của Pokémon được buff trước / sau, khiên, hồi
  máu / PP — `docs/BOT.md` mục Việc tiếp). Còn lại:
  chạy lô lớn, phân tích (Claude), chỉnh `data/difficulty.json` / `data/wave_templates.json` theo số liệu, dựng wave từ
  `boards.tsv`; bot chưa dùng phân bón / vé / ô sáng / Dojo. Ý ban đầu:
- **TODO (người dùng, 2026-11-16) — bot chơi hàng loạt để cân độ khó + làm phong phú wave Endless**: cho bot chơi liên
  tục vài chục nghìn run (headless, nhanh như `soak_test` nhưng không dựng view), **ghi lại quá trình** mỗi run (stage,
  đội hình + item + sao, vàng / level, thắng / thua từng wave, máu mất, wave nào giết run). Từ data đó: (1) cân độ khó
  **từng wave** theo tỉ lệ thắng mong muốn của người chơi ở mỗi stage (chỉnh `data/difficulty.json` /
  `data/wave_templates.json`, có thể sinh tự động); (2) lấy **đội hình của bot** ở từng stage làm nguồn wave Endless mới
  (đa dạng hơn template tay). Cần: bot có vài kiểu chơi (theo hệ, theo độ hiếm, ngẫu nhiên) để data không lệch một lối;
  chạy song song nhiều tiến trình Godot `--headless`; định dạng log gọn (JSON lines) + script Python tổng hợp.
- **UI mobile**: bố cục gọn **bản 4** (2026-11-15: sau ảnh TFT mobile thì bản 3 — shop bật / tắt, hệ dạng chip, thanh
  máu + item phía trên đầu; sau ảnh người dùng khoanh vùng đỏ thì bản 4 — sàn lấp vùng đó, góc nhìn tự khớp + tuỳ chọn,
  chip hẹp hơn, bench 8 ô × 2) mới kiểm bằng giả lập đúng cấu hình máy thử
  (`layout_test`, ảnh trên desktop ẩn) — chờ người dùng cài APK và báo lại. Câu hỏi còn mở: shop có nên tự mở đầu mỗi
  pha chuẩn bị không (đang tự mở; mở thì sàn nhỏ lại). 2026-11-16 (người dùng: "test qua tất cả screen"): soát 60+ ảnh
  mọi màn ở cấu hình máy thử → màn Battle Pass dạng gọn (`PassPanel._fill_compact`, không co), nút **i** xem chi tiết item
  trong popup chọn item (`ItemChoiceButton`), sửa căn giữa của các màn dựng bằng code (Options / Battle Pass / mùa), danh
  sách `!` không đè shop, dịch chuỗi gợi ý ghép item. Ý tưởng tiếp: zoom hai ngón, chạm ra ngoài để đóng shop, menu chính
  dựng riêng cho màn nhỏ (hiện co ×0,84, vẫn vừa).
- **Android**: APK debug (`build/pkmxtft.apk`, ~365 MB, preset trong `export_presets.cfg`). Việc tiếp: keystore release
  để ký bản phát hành, cân nhắc nén nhạc (`assets/music` ~270 MB).

## 3. Chỗ port lệch web (cố ý, để biết khi gặp)
- Hình dạng tạm (Trick-or-Treat → Magikarp, Camouflage, Transform): event `transform` có `pkm` = chỉ đổi hình.
- Mission Order đỏ (gây sát thương người chơi khác), Leaders Crest (Kingambit), đá thời tiết (Rock) chỉ có tác dụng khi
  đấu người → trong Endless solo không làm gì (đúng web ở PvE).
- Leftovers: món ăn không hiệu ứng (đúng web).
- Thêm riêng: kỷ lục (`Records`), chạm giữ = chuột phải (`TouchInput`), Item Remover, tua trận, xem trước stage, độ khó.

## 4. Quy trình thêm skill (đã dùng cho 37 đợt)
1. `python tools/port/show_abilities.py SKILL1 SKILL2 ...` — in code web gọn.
2. Viết `batchN.gd` (các `static func <skill_lower>(ctx: Dictionary) -> void`) và `batchN.json`
   (`{"SKILL": {"name", "desc", "no_target"?, "inimitable"?, "approx"?}}`) bằng trình soạn file (không heredoc).
   Helper ở đầu `ability_scripts.gd`: `hit(ctx, t, amount, kind, ap, crit)`, `by_stars(c, [1★,2★,3★,4★])`,
   `status(ctx, t, name, ms, ap_boost)`, `show(ctx, cells, affects)`, `enemies_on`, `line_through`, `ray_from`,
   `knock_back`, `board_effect`, `_summon`, `swap_units`, `take_item`, `run_other`, `closest_unit_of`,
   `strongest_nearest_ally`, `_jump_behind`. Quy đổi API web → port:

   | Web | Port |
   |---|---|
   | `target.handleSpecialDamage(d, board, SPECIAL, pokemon, crit, apBoost=true)` | `hit(ctx, t, d)` (`kind`, `ap=false`, `crit` tuỳ chọn) |
   | `[a, b, c, d][pokemon.stars - 1]` | `by_stars(c, [a, b, c, d])` |
   | `status.triggerX(ms, …)` | `status(ctx, t, "x", ms, ap_boost)` / `sim.add_status(t, "x", ms, c)` |
   | `pokemon.broadcastAbility(…)` | `show(ctx, cells, "enemies" \| "allies" \| "all")` |
   | `effectInLine` / `effectInOrientation` | `line_through(c, t)` / `ray_from(from, dir)` |
   | `getCellsInFront(pokemon, target, r)` / `getCellsInRadius` | `BattleBoard.cells_in_front(c.cell, t.cell, r)` / `cells_in_radius` |
   | `getKnockBackPlace` / `moveTo(…, forced)` | `knock_back(sim, t, dir)` / `sim.move_unit` hoặc `swap_units` |
   | `getFarthestTargetCoordinateAvailablePlace` | `sim.farthest_spot(c)` → `{cell, target}` |
   | `getSafePlaceAwayFrom` / `getTeleportationCell` | `AbilityRunner.fly_away_cell(sim, c)` / `sim.teleport_cell(cell, team)` |
   | `getClosestFreeCellTo…` / `simulation.addPokemon` | `sim.closest_free_cell_near(cell, team)` / `_summon(sim, pkm, team, cell)` |
   | `addBoardEffect(x, y, EffectEnum.X)` | `board_effect(sim, cells, "X")` (tick ở `BattleSim._each_second`) |
   | `addAttack(-x, pokemon, 1, crit)` lên địch | `t.add_stat("atk", AbilityRunner.adjust_buff(c, t, -x * (1 + ap/100)))` |
   | `addShield(x, pokemon, 1, crit)` | `sim.add_shield(u, x * (1 + c.ap / 100.0), c)` (add_shield không tự nhân AP) |
   | `DelayedCommand(fn, ms)` | `sim.schedule(ms, c, fn)` |
   | `pokemon.count.ult` | `c.cast_count` (đã +1 trước khi script chạy) |
3. `python tools/port/add_batch.py <thư mục>/batchN` → chèn code + JSON.
4. Chạy `sim_test` (cast thử mọi skill có Pokémon). Lỗi parse: chạy
   `Godot_console.exe --headless --path . --check-only --script res://src/core/ability_scripts.gd`.
5. Sau vài đợt: `tools\export_pac.bat --no-music` (Pokémon có đủ skill mới vào pool) → `--import` → 3 test.
6. Dịch: thêm tên/mô tả vào `data/i18n/vi.json` (`ability`, `ability_port`), kiểm tra `tools/port/check_texts.py`.
   `vi.json` / `ui.json` định dạng tay (mỗi mục một dòng): chèn dòng vào cuối section, đừng `json.dumps` cả file.
7. VFX: `python tools/port/gen_vfx.py --write` (spec tự động cho skill mới) rồi export lại.

## 5. Lệnh
```
set G=C:\Users\nqloc\godot-android\Godot_v4.7-stable_win64_console.exe
tools\export_pac.bat --no-music        (đầy đủ trừ nhạc; --data-only KHÔNG cập nhật pool.json)
%G% --headless --path . --import
%G% --headless --path . res://tests/sim_test.tscn     (flow_test / soak_test tương tự)
%G% --path . res://tests/screenshot.tscn -- <thư mục> [menu|synergy|vfx] [lang=vi]
python tools/port/show_abilities.py --next 10 | --rest | SKILL...
python tools/port/check_texts.py
python tools/port/gen_vfx.py [--write | --check | SKILL...]   (spec VFX từ abilities-animations.ts)
python tools/port/fix_continuations.py   (sửa dòng `\` bị nuốt khi sửa .gd qua shell)
python tools/port/replace_abilities.py <entries.json> [<code.gd> <region>]   (thay entry skill đã có + nối code)
%G% --headless --path . --export-debug "Android" build/pkmxtft.apk   (~2 phút; preset Windows: "Windows")
python tools/port/gen_world_doc.py       (sinh lại docs/WORLD.md sau khi export)
tools\wave_editor.bat                    (template wave + độ khó; thêm `-- shot <dir>` để chụp 2 tab)
%G% ... -- difficulty=hard               (mọi scene / test: chạy ở mức đó, không lưu)
%G% ... -- pass=<cấp> | pass=all         (ép cấp Battle Pass, không lưu; pass_file=<file>: file lưu khác)
%G% --headless --path . res://tests/layout_test.tscn   (đo kích thước màn pass / menu / Game Over, không cần cửa sổ)
tools\screenshot_hidden.bat <thư mục> [menu|synergy|vfx ...] [lang=vi] [pass=5]
                                         (chụp ảnh trên desktop ẩn: không hiện cửa sổ, không lấy chuột / focus, tắt tiếng)
```

## 6. Bẫy đã gặp (bổ sung cho CLAUDE.md)
- Bash heredoc nuốt `\` + xuống dòng → dòng GDScript bị dính (vẫn chạy nhưng xấu); dùng file script / `fix_continuations.py`.
- `match` trong lambda GDScript không parse được → tách hàm static (vd `_firework`).
- Lambda trong `sim.schedule(ms, owner, fn)` không chạy nếu `owner` đã gục; dùng `null` nếu cần chạy dù chết.
- Skill đổi `c.pkm` (Aura Wheel, Shields Down, Unbound) cần sprite: thêm dạng đó vào `extras` của exporter.
- `GameData.item_in(item, "Category")` dùng danh mục web xuất trong `data/pac/items.json` `categories`.
- Lambda GDScript bắt biến cục bộ **theo giá trị lúc tạo**: gán lại biến sau đó lambda không thấy → truyền qua `bind()`
  (lỗi cũ ở `Town.propositions`).
- `--check-only --script ability_scripts.gd` báo "Identifier not found: GameData" (không nạp autoload): không phải lỗi
  thật, kiểm bằng `sim_test`.
- Item đổi dạng / item theo Pokémon (Rotom Catalog, Mask, Nectar): đồng bộ ở `PlayerState._sync_form_items` (gọi từ
  `_board_changed`); hook khi nhận Pokémon (onAcquired của web) ở `EvolutionRules.on_acquired`.
- Thưởng từ trong trận đi qua `sim.rewards` (`gold`, `free_rolls`, `items`, `cell_battery`, `mulch`, `exp`, `life`,
  `pokemon`) và được nhận ở `PlayerState.collect_fight_rewards`.
- `var x := <biểu thức Variant>` (vd `dict.get(...)`, phần tử Array không kiểu) → lỗi parse "Cannot infer the type";
  test headless khi đó treo và log phình hàng trăm MB → luôn chạy test với `timeout`, ghi kiểu rõ (`var x: int = ...`).
- Bản export release không cho chạy scene tuỳ ý ("compiled without support for path overrides"); kiểm một pack đã
  export bằng `%G% --main-pack build/<file>.pck --headless --quit-after 1500 res://scenes/game.tscn`.
- Kỷ lục: test đặt `Records.path = "user://test_records.cfg"`; mọi `Game.cheat_*` đặt `cheated = true` (run không tính).
- Thêm skill thay cho skill đã có: `tools/port/replace_abilities.py` (add_batch.py chỉ thêm mới).

## 7. File chính của đợt 2026-10-04 (port nốt)
- `src/core/battle_sim.gd` — luật trạng thái (`add_status`, `_status_ended`, `_confused_target`, charm), hồi sinh
  (`_try_resurrect`, `_resurrect`, `spawn_stats`), `force_move` / `swap_cells` / `_on_displaced` / `_pursue`,
  `remove_unit`, `nearest_free_cell`, `farthest_enemy` / `farthest_spot` theo web, ô TOXIC_SPIKES / HAIL / COTTON_BALL.
- `src/core/battle_unit.gd` — `can_be_moved`, `cleanse` (curse_left), `tick` trả `expired`, Melmetal, Rusted Sword.
- `src/core/passive_effects.gd` — viết lại toàn bộ (hook `on_second`, `on_status`, `on_resurrecting`, `on_resurrect`).
- `src/core/evolution_rules.gd` (mới) — `EvolutionRules`; `src/core/player_state.gd` — shop đặc biệt, giá, item đặc
  biệt khi `equip`, `wanderers`, `catch_wanderer`, `magnet_pull_pick`, `shiny_encounter`, `_update_position_forms`.
- `src/core/ability_scripts.gd` — regions `faithful rewrites of the approx ones`, `Vespiquen orders`, `hail`.
- `src/view/wanderers.gd` (mới), `src/view/vfx_player.gd` (spread, from_cell / to_cell, jitter, everyone, unowns),
  `src/view/sprite_library.gd` + `unit_view.gd` (shiny).
- `src/game/game.gd` — `_give_reward`, shiny, wanderers, `_looks` (Illusion), preview chỉ số địch, `cheated`;
  `src/game/records.gd` (mới); `src/autoload/touch_input.gd` (mới); `src/ui/main_menu.gd` / `hud.gd` (kỷ lục).
- `src/core/town.gd` — Celebi, Kingambit, Treasure Box đủ loại, duo; `src/autoload/game_data.gd` — `DUOS`, mùa.
- Exporter `offline/godot-export.ts` — `stacksRequired`, duo, extras dạng đặc biệt + closure tiến hoá, frame / portrait shiny.
- `tests/sim_test.gd::_check_ported_rules` (+ `_check_status_rules`, `_check_new_passives`, `_check_evolution_rules`,
  `_check_shop_rules`, `_check_stage_rewards`), `_check_records`.

## 8. Battle Pass (2026-11-14) — file và bẫy
- `data/progression.json`, `src/core/progression.gd`, `src/autoload/game_data.gd` (region "Battle Pass"),
  `src/ui/pass_panel.gd`, `src/ui/main_menu.gd` (`_show_pass`), `src/ui/run_summary.gd` (`_pass_block`),
  `src/game/game.gd` (`_grant_pass_xp`, `_run_news`), `tests/layout_test.gd`, `tools/screenshot_hidden.ps1`.
- `GameData.pokemon[pkm].types` đã bị gỡ hệ khoá; cần hệ gốc thì đọc `all_types`. Liệt kê "mọi hệ" cho người chơi:
  `GameData.synergies()`, không phải `config.synergyThresholds` (cái đó là toàn bộ 31 hệ, dùng cho tool / kiểm tra).
- `GameData.apply_progression()` chỉ gọi ngoài run (menu, đầu run, test). Test nào cần đủ nội dung thì đặt
  `Progression.override_level = 9999` rồi gọi nó; test chơi thật phải đổi `Progression.path` kẻo ghi vào pass của người chơi.
- `is_available(pkm)` giờ là "đã port **và** pass cho xuất hiện"; danh sách đầy đủ: `GameData.full_list("pool")`.
- Đừng đặt tên hàm static là `reload` (xem CLAUDE.md) — `Progression.forget()` là hàm quên dữ liệu đã đọc.
- Test cần cửa sổ (`screenshot`): chạy qua `tools\screenshot_hidden.bat` để không chiếm chuột / focus của người đang
  dùng máy; `_hover` của tool không còn `warp_mouse` (chỉ dùng sự kiện chuột giả).

## 9. UI mobile (2026-11-14) — file và bẫy

**Máy thử: Oppo Reno 15 Pro.** Hệ số tự động ra **×2,0** (người dùng thấy cỡ chữ này vừa mắt) → canvas **1171×540**;
lỗ camera ở mép trái, giữa chiều cao: `get_display_safe_area()` trả lề trái ≈ 60 đơn vị canvas. Giả lập đúng máy đó:
`-- ui_scale=2 touch insets=60,0 cutout=0,246,60,48` (ảnh: `SHOT_RESOLUTION=1600x738`; ảnh mẫu của bố cục gọn bản 2:
`build/shots/mobile2_*.png`, còn `mobile_*.png` là bản 1 ở ×1,65).

- `src/ui/ui_scale.gd` (`UiScale`): hệ số = 4,67 / chiều cao màn hình (inch), kẹp 1–2; `Settings.ui_scale` (0 = tự động);
  `fit()` co panel cho vừa canvas; cờ `touch`. `safe_insets()` = dải có lỗ camera, `cutouts()` = vị trí lỗ,
  `band_insets(canvas, y0, y1)` = lề trái / phải của một dải ngang (chỉ né dải camera ở chỗ lỗ chạm tới; máy không báo
  vị trí lỗ → né cả dải). Tham số thử (không lưu): `ui_scale=`, `touch`, `insets=<trái>,<phải>`, `cutout=<x>,<y>,<w>,<h>`.
- Canvas thấp hơn `UiScale.COMPACT_HEIGHT` (840) → `Hud.compact`. `Hud._layout_compact()` đặt mọi phần (đơn vị canvas):
  shop một hàng ở đáy, cách hai mép `COMPACT_CORNER` (22: góc bo của màn hình); cột trái (vườn, kho item, **chip hệ** rộng
  `SYNERGY_WIDTH` 100); thanh stage hai dòng cân giữa; góc phải: player panel, thống kê trận (`DPS_WIDTH` 240), bảng
  Pokémon (`UNIT_PANEL_WIDTH` 300), nút Chiến!. Sàn = `board_rect`: đối xứng quanh giữa màn hình, từ mép phải cột trái
  tới phần đối xứng bên kia, từ thanh stage xuống `_board_bottom`.
- **Bản 3 — shop bật / tắt** (`Hud.shop_open`, `set_shop_open()`): `Game._start_planning` mở, `_start_fight` đóng; nút ▼
  trong shop (`ShopBar.close_pressed`) và nút *Shop ▲* của dock. Shop đóng → `_board_bottom` = đáy canvas, `board_rect`
  cao lên → `layout_changed` → `Game._frame_board()` căn lại camera (tween 0,2 s; **không tween khi headless** vì test đo
  sàn ngay sau layout). `_dock` (góc dưới trái, rộng bằng cột trái) = vàng + nút mở shop, và là **vùng bán** khi shop đóng:
  `is_over_shop()` nhận dock, `show_sell(price, dragging)` đổi dock thành "Thả vào đây để bán" / giá. Bố cục desktop không
  có khái niệm này (shop luôn hiện).
- **Bản 4 — sàn lấp khoảng trống** (sau ảnh người dùng khoanh vùng đỏ: từ sau cột hệ tới nút Chiến!, từ thanh stage tới
  đáy màn): `board_rect` = [mép phải cột trái / dock + 8, mép trái nút Chiến! − 8] × [đáy thanh stage + 4, đáy shop hoặc đáy
  màn]; `board_room_full` = khoảng đó khi shop đóng. Cột trái hẹp lại (chip hệ 64, dock xếp vàng **trên** nút Shop), nút
  Chiến! 140×60. Thống kê trận gập lại lần đầu vào bố cục gọn (`DpsMeter.set_folded`) — mở ra thì che mép phải của sàn.
- Góc camera gọn: `Game._pick_pitch()` — `Settings.board_pitch` (Tuỳ chọn → *Góc nhìn sàn*, chỉ hiện khi canvas thấp;
  0 = tự động; tham số thử `board_pitch=<độ>`) hoặc góc 36–60° (`AUTO_PITCH_MIN/MAX`) cho diện tích ô lớn nhất khi
  `frame()` vào `board_room_full` (máy thử: 39°, máy không lỗ camera: 37°, ×1,65: 36°, máy 16:9 nhỏ: 52°); cache theo
  khoảng trống. Góc giữ nguyên khi mở / đóng shop. `_scene_camera` nhớ cả pitch của scene để trả lại khi về bố cục desktop.
  `layout_test` in góc đã chọn cho từng cấu hình (`camera angle`).
- `UnitOverlay` (thanh máu / PP / item / sao): xếp chồng **phía trên** điểm neo, co theo `scale_at()` = bề rộng ô trên màn
  hình / `FULL_CELL` (80), kẹp 0,55–1. Điểm neo `UnitView.head_position()` dùng `sprite_up()` = trục dọc của **camera**
  (sprite là billboard): dùng `Vector3.UP` thì điểm chiếu chỉ ở ~57% chiều cao sprite (lỗi cũ: thanh máu cắt ngang thân
  Pokémon lớn). `entry.height` cao hơn đỉnh đầu thật vài pixel → trừ 3. Các phần tự đổi sang dạng gọn: `ShopBar.set_compact`, `ShopCard.set_compact` (tên tự thu cỡ
  chữ), `UnitInfoPanel.set_compact` (bảng 300×300, reparent node), `ItemBench.set_compact`, `GardenPanel.set_compact`,
  `Hud._compact_stage_bar`, `Hud._compact_player_panel`. Bố cục của scene (desktop) nhớ trong `_scene_layout`.
- **Lưới an toàn**: shop và thanh stage rộng hơn chỗ dành cho chúng thì co lại (`scale`); bảng Pokémon cao hơn khoảng
  trên shop thì co lại (`_fit_panels`). Vị trí đo bằng `Hud.shown_rect()` (có tính `scale`), đừng dùng `get_global_rect()`.
- Tooltip cao hơn canvas bị `HoverTip._place` co lại (chữ nhỏ đi) → cái nào hay dùng thì dựng dạng rộng khi canvas thấp:
  `SynergyTip._two_columns()` (`UiScale.is_compact(self)` trong `_ready`). `ItemChoice` cho tiêu đề xuống dòng.
- **BẪY EXPORT (đã dính)**: khi export, Godot đóng gói lại scene và **bỏ mọi thuộc tính bằng giá trị mặc định**. Trong
  `.tscn` viết tay, `anchors_preset = 6` kèm `grow_vertical = 1` chạy đúng trong editor (dòng `grow_vertical` ghi đè), nhưng
  trong APK dòng đó mất, `anchors_preset` tự đặt `grow_vertical = BOTH` → bảng Pokémon mọc ra cả hai phía và lệch khỏi mép
  trên. Test desktop không thể thấy. Cách phòng: (1) `layout_test._export_fidelity()` đóng gói lại mọi scene
  (`PackedScene.pack`) rồi so từng thuộc tính; (2) `Hud._place()` luôn đặt cả hướng mọc; (3) node có neo tuỳ biến dùng
  `anchors_preset = -1`. Soát APK: giải nén `assets/.godot/exported/*/export-*-<tên>.scn` rồi `load()` + so `get_state()`.
- **Container đặt lại `scale` của con**: muốn co một panel nằm trong `CenterContainer` thì co chính container đó
  (`UiScale.fit(panel, max, pivot, container)`), đừng co panel.
- Chạm: chạm phát ra chuột trái giả (emulate_mouse_from_touch) **không có sự kiện di chuyển trước đó** → `_hover_slot` cũ;
  `Game._point_at(pos)` cập nhật ô dưới ngón tay trước khi chọn Pokémon. Nhấn ngắn không xê dịch = tap (`_is_tap`):
  Pokémon → `_inspect`, item → `ItemBench.show_item_info`. `HoverTip` ở chế độ chạm bỏ qua `mouse_entered`, mở tooltip
  trong `_touch()` (nút chỉ khi giữ).
- Chữ thay đổi kích thước một phần (cấp 10, tên vùng dài, số hệ của địch) → `minimum_size_changed` → `Hud._layout_later()`;
  `layout_changed` chỉ phát khi `board_rect` đổi (camera căn lại sàn thì mất zoom).
- Test: `tests/layout_test.tscn` (headless): `_export_fidelity`, rồi `_phone()` dựng HUD với chữ dài nhất (tên vùng, tên
  wave, 5 hệ địch, tên Pokémon) ở ×1,65 / ×2,0 / ×2,0 + lỗ camera trái / phải / không báo lỗ / có vườn / máy 16:9 nhỏ, kiểm
  từng phần nằm trong canvas, không đè nhau, bảng Pokémon giữ nguyên cỡ và không che nút Chiến!; rồi **đóng shop**: dock /
  nút Chiến! trong canvas, sàn cao ≥ 70% canvas và rộng ≥ 1,2 lần lúc shop mở, dock là vùng bán, thống kê trận không đè
  sàn (so với cạnh phải hình thang của sàn), mở lại thì sàn về cỡ cũ; `_rescale` (đổi cỡ giữa trận rồi đổi lại: node về
  đúng chỗ của scene); `_touch`. Ảnh: `tools/screenshot_hidden.ps1 <dir> board ...` (shop mở / đóng / kéo vào dock / trận);
  ảnh mẫu bản 3: `build/shots/mobile3_*.png`.

## 10b. Bench 8 ô × 2 con giống nhau (2026-11-15) — file và bẫy

Người dùng muốn hàng chờ 8 ô thay 16, mỗi ô chứa 1–2 con giống nhau (3 con thì gộp). `data/difficulty.json`: `benchSize` 8,
`benchStack` 2 (cả 3 mức; wave editor có ô chỉnh).

- `PlayerState` (region "bench slots"): `bench` vẫn là mảng phẳng `bench_slots × bench_stack` chỗ để mọi vòng lặp
  `bench + board.values()` (gộp, nội tại, hệ thống giữa stage...) thấy đủ con. Chỗ `i` → ô `i / bench_stack`, lớp
  `i % bench_stack`. `find()` trả `{"bench": ô, "layer": lớp}`; `unit_at({"bench": ô})` = con đầu của ô.
- Luật chung ô: `stackable(front, back)` = cùng `pkm`, không phải trứng / trụ, con sau **không cầm item / TM**;
  `stack_order()` đưa con cầm item lên đầu. `_normalize_bench()` (đầu `_board_changed`, cuối `check_merges`, `after_fight`)
  dồn ô, tách con không hợp lệ ra ô trống (không có chỗ thì để tạm sau con đầu).
- Thêm Pokémon: `bench_index_for(unit)` / `put_on_bench(unit)` (ưu tiên ô có con giống nó), kiểm chỗ: `has_bench_room(pkm)`
  (mua: `can_buy`). `first_free_bench_slot()` vẫn trả **index chỗ** đầu của ô trống — code cũ `p.bench[...] = X` (trứng, cá,
  Unown...) vẫn đúng, chỉ không xếp chung.
- Kéo thả: `_plan_move(unit, to)` trả danh sách `[unit, vị trí]` phải đổi: thả lên con giống nó → chung ô; lên con khác → đổi
  chỗ (những con ở đó về chỗ con kéo vừa rời nếu hợp, không thì sang ô trống; không có thì từ chối); từ sàn lên ô có 2 con
  → từ chối (2 con không về được 1 ô sàn). `can_place` dùng chung nên ô xanh khi kéo = ô thả được.
- Nơi theo "ô" chứ không theo chỗ: Illusion (con bên trái = con đầu của ô trước), luyện tập Fighting (ô đầu và ô sau trụ:
  mọi con trong ô), `SynergyItems._adjacent` (khác ô 1 đơn vị), highlight `occupied` / `valid`, `_slot_world`.
- View: mỗi con một `UnitView` như cũ; `Game._update_stack_views()` ẩn con sau, con đầu có `stack_count` → `UnitOverlay`
  vẽ nhãn "x2" ở góc trước bên phải của ô; lúc kéo con đầu thì con sau hiện ra. `_pick_view` bỏ qua view ẩn.
- Test: `sim_test::_check_bench_stacks` (mua xếp chung, con thứ ba gộp, bench đầy, kéo thả đổi chỗ / tách cặp, item, bán
  con đầu, trứng không xếp chung); `_check_player_config` đếm ô × lớp. Ảnh: `screenshot ... board` có một cặp trên bench.

## 10. Mùa (2026-11-15) — file và bẫy

Vì sao có: không mùa thì tới stage 11 shop có 249 họ (94 gốc + cả 155 họ additional, bản port cho vào hết) cộng Pokémon
vùng — một hệ 13–37 họ, người dùng thấy khó nhắm đội hình. Mùa = danh sách cố định, chọn ở menu trước khi chơi.

- File: `data/seasons.json`, `src/core/seasons.gd`, `src/autoload/game_data.gd` (region "season", `apply_progression`,
  `pokemon_unlocked`, `in_region`), `src/autoload/settings.gd` (`season`, `set_season`), `src/ui/main_menu.gd`
  (`_show_season`, ô chọn mùa cạnh độ khó), `src/ui/season_panel.gd`, `src/ui/tooltips/pool_tip.gd` (`_fill_season`: nút
  **!** của shop hiện cả danh sách mùa), `src/core/town.gd` (`additional_pick`), `tools/port/gen_seasons.py`,
  `docs/SEASONS.md` (sinh tự động), `tests/sim_test.gd::_check_seasons`.
- Trong một mùa: `GameData.pool` chứa mọi họ shop của mùa (kể cả họ vốn là additional / regional), `additional` và
  `regional` **rỗng**, `regional_info` / `regional_variants` / `regional_base` rỗng (biến thể vùng là một họ độc lập, có
  pool riêng), `in_region()` luôn đúng, `unlocked_additional` và `pool_news` của `PlayerState` luôn rỗng. Code mới đừng
  giả định có additional (flow_test từng kiểm `unlocked_additional ≥ 50`).
- `config.synergyThresholds[hệ]` bị thay bằng mốc của mùa cho các hệ có `thresholds`; bản gốc: `GameData.full_thresholds()`.
  Mốc riêng **phải cùng số mốc** với bản gốc (hiệu ứng tra theo số thứ tự mốc) — `Seasons.problems()` và tool đều kiểm.
- Thứ tự autoload: `GameData` sẵn sàng trước `Settings`, nên `Settings._ready` đặt `Seasons.current` rồi gọi lại
  `GameData.apply_progression()`. Đổi mùa luôn qua `Settings.set_season()`; không đổi giữa run.
- Test: `sim_test` đặt `Seasons.FULL` (đủ nội dung như trước) rồi `_check_seasons` duyệt từng mùa; flow / soak / layout /
  screenshot gọi `Seasons.use_default_unless_asked()` (mùa mặc định của file, không phải mùa người chơi đã lưu); thêm
  `-- season=<id>` hoặc `season=all` để đổi. **Đừng phát `item_selected` của ô chọn mùa trong test** — nó ghi vào
  `user://settings.cfg` thật.
- Họ đặc biệt (xử lý trong tool): Flabébé liệt kê cả 5 màu, tính một họ; Deerling (dạng theo ngày thật), Burmy Sandy /
  Trash (Mothim thuộc họ Burmy Plant), Shedinja (đi kèm Ninjask, không phải dòng shop) không vào mùa nào; hai dạng của
  cùng một Pokémon (Vulpix / Alolan Vulpix) không ở chung một mùa.
- Pokémon đến từ cơ chế (độ hiếm SPECIAL: Ditto, Eevee starter, cá câu, hoa trong chậu, Unown...) không thuộc danh sách
  nào và luôn có, như với Battle Pass.
- Sửa `data/seasons.json` → `python tools/port/gen_seasons.py` (kiểm + ghi lại `docs/SEASONS.md`) → `sim_test`.
  `--generate` tính lại cả 3 mùa bằng simulated annealing (seed cố định, ~15 s) và **ghi đè** mọi chỉnh tay.
- Kỷ lục: khoá `"<độ khó>@<mùa>"` (`Seasons.record_key`); run không mùa giữ khoá cũ (`"normal"`...).
- `tools\wave_editor.bat` luôn chạy không mùa (xem trước wave với mọi Pokémon).
- Ảnh mẫu: `build/shots/season_*.png` (menu, màn Pokémon của mùa, danh sách trong trận).

## 11. Soát mọi màn trên điện thoại (2026-11-16) — file và bẫy

- **Màn dựng bằng code + `CenterContainer` tạo bằng code**: container cao hơn canvas mọc **xuống dưới** (hướng mọc mặc định
  END) chứ không ra hai phía, nên panel bị `UiScale.fit` co lại vẫn lệch xuống, tràn mép dưới (màn Battle Pass trên máy
  thử). `OptionsPanel` / `PassPanel` / `SeasonPanel.open_over` đặt `grow_horizontal / grow_vertical = BOTH`. Kiểm vị trí
  bằng `Hud.shown_rect()` (có `scale` của container), đừng dùng `get_global_rect()`.
- `PassPanel` dạng gọn (`_compact` khi canvas thấp hơn `UiScale.COMPACT_HEIGHT`): `_fill_compact()` — rộng = canvas − 16 −
  2 × lề lỗ camera, thẻ cấp `COMPACT_CARD_SIZE` 120×88 giãn theo cột. `layout_test` kiểm: nằm trong canvas, **không co**
  (`scale` ≈ 1), đủ thẻ cấp; Options cũng phải nằm trong canvas.
- `ItemChoiceButton`: nút con `Info` ("i", góc trên phải) → `show_details()` = `HoverTip.current.toggle(...)` (tooltip ghim
  dưới ô, bấm lần nữa đóng). Nút con của một `Button` nhận chạm trước nút cha, nên chạm "i" không chọn item. `layout_test`
  bấm nút này ở popup đũa phép (tooltip nằm trong canvas, popup vẫn mở, bấm lần hai đóng); ảnh: `18a_item_choice_details`.
- `PoolTip._fit()`: trên canvas thấp, danh sách cao tối đa `0,78 × canvas − 140` để nằm trên hàng shop.

## 12. Chuyển động sprite (2026-11-20) — file và bẫy

Người dùng hỏi "làm mượt animation sprite như 60 fps". Game vốn render theo tần số màn hình; giật là do sprite PMD ít
frame và do animation đòn đánh không theo tốc độ đánh / tốc độ tua (bị cắt về frame đầu liên tục). Đã làm (chi tiết
`docs/PORTING.md`, mục Phong cách):

1. **Đồng bộ tốc độ** — `UnitView.attack(anim, cooldown, hit_delay, đích, ranged)` (Game gọi ở event `attack`):
   - animation đánh kéo dài bằng cooldown, như web;
   - `UnitView.time_scale` = tốc độ tua;
   - `IDLE_GRACE`: đòn / bước kế tiếp nối liền, không chớp Idle.
2. **Chuyển động vẽ thêm** — `UnitView._animate_body`: lò xo cho lunge / trúng đòn / bẹp, cùng thở, nảy, pop, lún.
   `Game._ground_of(u)` cho hướng đánh. Sửa kèm: `move_to(..., "dash")` tới đúng chỗ đang đứng không còn nhảy (trước đó
   mọi Pokémon của người chơi nhảy lên mỗi khi `_sync_owned_views(true)` chạy: mua, đổi shop...).
3. **Shader** — `src/view/shaders/sprite_pixel_aa.gdshader`.

Bẫy:
- Đổi `sprite.sprite_frames` thì gọi `_sync_sheet()`. Đổi `sprite.render_priority` thì đặt cả `_sprite_mat.render_priority`:
  priority là thuộc tính của material, override không lấy của sprite.
- Đừng tween `sprite.position` / `sprite.scale` ở chỗ khác: `_animate_body` ghi đè mỗi frame. Muốn hiệu ứng mới thì thêm
  vào đó, hoặc đẩy lò xo bằng `_kick()`.
- Dữ liệu ngẫu nhiên của view (pha thở) lấy từ instance id, không dùng `randf()`: để một run có seed vẫn giống hệt nhau.

Công cụ so sánh chuyển động:
- Lệnh:
  ```
  SHOT_ENGINE_ARGS="--fixed-fps 50" tools/screenshot_hidden.ps1 <dir> motion seed=4242 difficulty=classic [speed=2] [full=1] [pixels=nearest]
  ```
- Kết quả: `motion_NNN.png` (khung sàn; `full=1` cả khung hình — bố cục gọn căn lại camera khi shop đóng) và `motion.tsv`
  (mỗi frame mỗi Pokémon: vị trí node, độ lệch sprite, scale, frame animation).
- Cùng seed thì cùng trận, nên hai bản view so được từng frame: `python -I tools/motion_gif.py out.gif "<dir1>=Trước"
  "<dir2>=Sau" --crop x,y,w,h [--strip ảnh.png]`.
- Ảnh mẫu: `build/shots/motion_*`.
- Ảnh soát: chạy `tools/screenshot_hidden.ps1` với các chế độ `menu`, (mặc định), `synergy`, `pool`, `difficulty`, `board`,
  `cheat`, mỗi chế độ hai lần (có `touch` và không — không `touch` thì tooltip hover hiện trong ảnh); ghép bảng ảnh bằng
  PIL để xem nhanh. Ảnh chế độ `difficulty` có shop trống (công cụ nhảy stage không đổi shop) — không phải lỗi game.

## 13. Sàn lục giác 7×8 + sân Poké Ball (2026-11-20) — file và bẫy

Người dùng: viền ô mảnh và nhạt hơn, vẽ sân theo phong cách Pokémon (thêm Poké Ball), sàn 8×6 ô vuông → 7×8 ô lục giác
đỉnh nhọn, hai hàng so le. Khác bản web (lưới vuông): xem `docs/PORTING.md` mục "Lưới lục giác" (bảng web ↔ lục giác).

- `src/core/battle_board.gd`: viết lại. Ô vẫn là `Vector2i(cột, hàng)`, hình học qua axial: `step`, `offset`, `turn`, `fan`,
  `center` / `cell_at` (toạ độ phẳng, đơn vị = bề ngang ô), `distance` (= `distance_c` = `distance_m`), `orientation`
  (6 hướng, hướng thẳng trước / sau lệch vào giữa sàn), `direction_index` / `sprite_direction_between` (8 hướng sprite PMD
  theo góc thật). `place()` báo lỗi khi ô ra ngoài sàn.
- Đã sửa: `battle_sim.gd` (đường đi 6 ô kề, `near_order()` cho `closest_free_cell_near`, hướng ngẫu nhiên % 6),
  `ability_runner.gd` (dash, knockback, preview, chữ "6 ô"), `ability_scripts.gd` (~20 skill theo hướng / hình dạng, xem
  bảng ở PORTING), `passive_effects.gd` (Toxic Spikes, Skarmory), `player_state.gd` (`PLAYER_ROWS` = 4, `CENTER_OUT`),
  `run_rules.gd`, `endless_waves.gd` (`to_sim_cell`, hàng 0 = hàng thứ 4, 7 cột, 28 con), `wave_templates.gd`,
  `game_data.gd` (`fit_wave_board`: boss web 8 cột → 7), bot (`bot_brain.gd`, `bot_pro.gd` hàng / cột, `bot_run.gd` chú thích,
  `balance.py` front = y 3), wave editor (xem trước 4 hàng).
- View: `arena.gd` (toạ độ ô ↔ thế giới, `HALF_W` / `HALF_D` / `BENCH_SLOT`, `board_half_width()` / `board_far_z()` /
  `bench_near_z()` cho camera, texture highlight 8 × (8 + hàng bench)), `shaders/board.gdshader` (sân lục giác + Poké Ball,
  **chỉ toán float**: bản dùng `int` / `&` / `ivec2` làm một pipeline D3D12 lỗi `0x8007000e` lúc khởi động), `unit_view.gd`
  (`face_toward`), `vfx_player.gd`, `ui/ability_shape_view.gd` (sơ đồ skill vẽ lục giác), `tft_camera.gd` + `game.tscn`
  (camera desktop: distance 14,6, focus z 1,45, v_offset −0,5 — sàn sâu hơn), `game.gd` (khung camera theo Arena).
- Poké Ball tự vẽ trong shader (`Arena.ball_*`). Link ảnh người dùng gửi (models.spriters-resource.com) bị Cloudflare chặn
  bot nên không tải được: muốn dùng ảnh thì đặt file vào `assets/arena/pokeball.png` (ảnh tròn, nền trong suốt), chạy
  `--import`, Arena tự dùng (`BALL_IMAGE`).
- Test: `sim_test._check_hex_board` (vòng ô 1/6/12/18, đối xứng, đường thẳng liền, step/orientation, thứ tự tìm ô trống,
  wave, boss trong sàn); các test cũ đổi ô (7, 5) → (6, 7), hàng đầu người chơi 2 → 3; `layout_test` chờ Pokémon mới nhảy
  vào ô xong mới chạm.
- Bẫy: đừng cộng `cell + dir` (trừ `± Vector2i(1, 0)` cùng hàng); "cột" `(x, y ± 1)` là đường zigzag (vẫn là ô kề).
  **Cân bằng (`data/balance.json`) và mô hình bot (`tools/bot/model.json`) được học trên sàn vuông**: cần chạy lại lô bot /
  tự cân bằng trên sàn lục giác.

