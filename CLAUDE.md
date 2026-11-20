# pkmxtft — bản port Godot của pokemonAutoChess (chế độ Endless offline)

File này để bắt đầu session mới nhanh. Người dùng viết tiếng Việt → trả lời tiếng Việt, code / tên định danh / lệnh để tiếng Anh.
**Làm tiếp: đọc `docs/HANDOFF.md`** (trạng thái, việc còn lại, quy trình thêm skill, công cụ `tools/port/`).
Tài liệu chi tiết: `docs/PORTING.md` (từng phase, luật, bảng synergy), `docs/ABILITIES.md` (định dạng skill JSON),
`docs/TODO_PORT.md` (checklist port item / skill / town), `docs/GAME_DESIGN.md` (game design document: luật, hệ thống,
nội dung, UI — cập nhật số liệu ở đó khi luật / cân bằng đổi), `docs/DIFFICULTY.md` (độ khó, hệ + item của wave địch,
template wave, tool `tools\wave_editor.bat`), `docs/WORLD.md` (tham chiếu thời tiết + 143 vùng, sinh bằng
`python tools/port/gen_world_doc.py`), `docs/PROGRESSION.md` (Battle Pass: mở khoá hệ qua nhiều run),
`docs/SEASONS.md` (mùa: danh sách Pokémon cố định của từng run; sinh bằng `python tools/port/gen_seasons.py`),
`docs/THEMES.md` (điểm chung của 508 họ Pokémon — nguyên liệu dựng hệ mới theo mùa; sinh bằng
`python tools/port/gen_themes.py` từ `tools/port/themes/`, bản xem có ảnh + lọc: `docs/themes.html`), `docs/BOT.md` (bot tự
chơi hàng loạt → TSV để cân độ khó / cân bằng).

## Dự án

- Port chế độ **Endless solo** của bản web `D:\Python\PKM Autobattle\pokemonAutoChess` (fork offline của
  keldaanCommunity/pokemonAutoChess, xem `D:\Python\PKM Autobattle\CLAUDE.md`) sang **Godot 4.7** (Mobile renderer, d3d12).
  Không multiplayer. Luồng: Main Menu → Game (planning ↔ fight, stage nối stage) → Game Over → Main Menu.
- Sàn **lưới lục giác 7×8** kiểu TFT (khác web: PAC dùng lưới vuông 8×6; đổi 2026-11-20, `docs/PORTING.md` mục "Lưới lục giác"),
  trình bày kiểu TFT: camera 3D thật, sàn vẽ phẳng (sân Pokémon có quả Poké Ball ở giữa), Pokémon là sprite PMD 2D billboard.
- **Nguyên tắc port**: đọc code web (`app/core/*.ts`, `app/models/...`, `app/rooms/commands/game-commands.ts`) rồi viết lại
  trung thành, ghi tên file web trong comment đầu hàm; chỗ đơn giản hoá thì ghi rõ (`approx` trong skill, "khác bản web" trong docs).
- Không phải git repo. Không sửa tay `data/pac/*.json`, `assets/pokemons|portraits|items|types|icons` (sinh tự động).

## Lệnh

```
set G=C:\Users\nqloc\godot-android\Godot_v4.7-stable_win64_console.exe
%G% --headless --path . --import                               # sau khi export hoặc thêm class_name mới (không thì "not declared in the current scope")
%G% --headless --path . res://tests/sim_test.tscn               # logic (exit 0 = OK); grep "FAIL|SCRIPT ERROR"
%G% --headless --path . res://tests/flow_test.tscn              # MM -> game -> game over -> MM
%G% --headless --path . res://tests/soak_test.tscn              # bot chơi nhanh ~20 stage, bắt lỗi runtime của view/event
%G% --headless --path . res://tests/layout_test.tscn             # đo kích thước màn pass / menu / Game Over (không cần cửa sổ)
tools\screenshot_hidden.bat <dir> [menu|synergy|board|vfx [SKILL...]] [lang=vi] [pass=5]   # ảnh từng màn UI (xem bằng Read), chạy trên desktop ẩn
set SHOT_ENGINE_ARGS=--fixed-fps 50 & tools\screenshot_hidden.bat <dir> motion seed=4242 [speed=2] [full=1] [pixels=nearest]   # quay từng frame một trận + motion.tsv
python -I tools/motion_gif.py out.gif "<dir1>=Trước" "<dir2>=Sau" [--crop x,y,w,h]   # GIF so 2 bản view (cùng seed = cùng trận)
%G% --path . res://tests/screenshot.tscn -- <dir> [...]          # như trên nhưng MỞ CỬA SỔ thật: chỉ dùng khi người dùng đồng ý
tools\export_pac.bat [--data-only] [--no-music]                  # sinh lại data/pac + sprite/icon/VFX/âm thanh từ bản web (offline/godot-export.ts, Node portable)
tools\wave_editor.bat                                            # tool sửa template wave + độ khó (cần cửa sổ); `-- shot <dir>` chụp 2 tab rồi thoát
%G% --headless --path . --export-debug "Android" build/pkmxtft.apk   # APK debug (~2 phút, preset trong export_presets.cfg; còn preset "Windows")
tools\bot_run.bat -Runs 500 -Workers 6 -Out build/bot/b1 -Passes journey -Report   # bot tự chơi song song -> TSV + report (docs/BOT.md)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/autobalance.ps1 -Iterations 3 -Runs 100 -Workers 12   # tự cân bằng -> data/balance.json
```
Mọi test / scene nhận `-- difficulty=<classic|normal|hard>`, `-- pass=<cấp>|all` (Battle Pass), `-- season=<id>|all` (mùa;
`all` = không mùa) và `-- ui_scale=<hệ số> touch`
(UI mobile; thêm `insets=<trái>,<phải> cutout=<x>,<y>,<w>,<h>` để giả lỗ camera) — đều không lưu; screenshot có thêm chế độ
`difficulty`. Xem bố cục **đúng như máy thử** (Oppo Reno 15 Pro: ×2,0, canvas 1171×540, lỗ camera bên trái):
`SHOT_RESOLUTION=1600x738` + `tools/screenshot_hidden.ps1 <dir> lang=vi ui_scale=2 touch insets=60,0 cutout=0,246,60,48`.
**Test không được chiếm chuột / focus / loa của người dùng**: mặc định chỉ chạy bản `--headless`; cần ảnh thì dùng
`tools\screenshot_hidden.bat` (Bash tool: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/screenshot_hidden.ps1 <dir> ...`).
Bash tool: gọi `cmd //c "tools\\export_pac.bat"`; Godot console exe chạy được cả khi không `--headless` (mở cửa sổ).

## Cấu trúc

| Đường dẫn | Nội dung |
|---|---|
| `src/autoload/game_data.gd` | autoload `GameData`: đọc `data/pac/*.json`, `data/abilities.json`, `data/item_effects.json`; pool (`pool`, `additional`, `regional`, `unique`, `legendary`, `extras`), vùng (`in_region`, `regional_in`, `variants_in_region`), tier1 theo độ hiếm, `evolutions_of`, `prevolution`, text theo ngôn ngữ (`set_language`, `ability_desc`, `item_desc`, `status_name`), icon |
| `src/autoload/settings.gd` / `audio.gd` | `Settings` (ngôn ngữ, âm lượng, `changed`), `Audio` (`play_music` cross-fade, `play_sfx`, tiếng nút) |
| `src/autoload/touch_input.gd` | `TouchInput` (chỉ bật trên máy cảm ứng): chạm giữ 0,45 s = chuột phải (tooltip ghim, tooltip của nút), huỷ nút / kéo thả đang dở |
| `src/ui/ui_scale.gd` | `UiScale`: phóng to canvas trên màn nhỏ (`content_scale_factor`, tự động theo inch hoặc `Settings.ui_scale`), `fit()` co panel cho vừa, lề an toàn + lỗ camera (`band_insets`), cờ `touch`; canvas thấp → HUD **compact** (`Hud._layout_compact`, `TftCamera.frame`) |
| `data/i18n/` | `ui.json` chữ giao diện (`L.t`), `vi.json` chữ game tiếng Việt (giữ từ khoá VIẾT HOA) |
| `data/ability_vfx.json` | spec hiệu ứng hình ảnh của skill (xem `_doc`) |
| `src/core/` | logic thuần, **không node** (test headless được) |
| `  battle_board.gd` | lưới lục giác 7×8 (ô offset ↔ axial, `step` / `offset` / `turn` / `fan`, `center` / `cell_at`), khoảng cách hex (cả tầm đánh lẫn tìm địch), 6 hướng, hình dạng vùng ô |
| `  battle_unit.gd` | Pokémon trong trận: chỉ số, BASE, item, `statuses` (tên → ms), poison tầng, curse, `synergy` (hệ → mốc), `counters`, `transform()` |
| `  battle_sim.gd` | một trận: vòng lặp ms, nhắm/đi/đánh, `attack_hit`, `deal_damage`, `heal`, `add_status`, enraged 35 s, weather Storm, **events** cho view (danh sách ở đầu file) |
| `  ability_runner.gd` | chạy skill data-driven; `step_cells()` dùng chung cho trận, nháy ô và sơ đồ trong panel |
| `  ability_scripts.gd` | skill viết bằng code (`"script"` trong abilities.json; 456 skill, helper `hit/status/show/by_stars...` ở đầu file) |
| `  synergy_items.gd` / `dish_effects.gd` | item của hệ giữa stage (mũ đầu bếp, cần câu, cây quả mọng, chậu hoa, trứng, TM, khăn, công cụ) + món ăn |
| `  evolution_rules.gd` | `EvolutionRules`: tiến hoá theo stack / state / map / money / placement / item (`evolution-logic/*`), `on_acquired` (Shedinja, Cosmoem...), `check_board`, `add_stack` |
| `  item_effects.gd` / `synergy_effects.gd` / `passive_effects.gd` | hook hiệu ứng item / synergy / passive (on_spawn, on_fight_start, on_tick, on_attack, on_hit, on_damage_*, on_kill, on_death, on_cast) |
| `  synergies.gd` | đếm synergy (họ, Dragon đôi, gem), mốc, dominant, tỉ lệ Wild, `context_text` cho tooltip |
| `  weather.gd` | tính weather từ 2 sàn + hệ số thời tiết |
| `  fight_setup.gd` | dựng trận của một stage: weather → đổi dạng → synergy + bối cảnh sàn → unit hai đội |
| `  player_state.gd` | người chơi: vàng/level/máu, bench+board, shop (Wild, Flabébé, additional, **pool vùng + biến thể**: `change_map`, `update_regional_pool`, `pool_entries`), gộp 3 con (tiến hoá rẽ nhánh), item (kể cả item đổi dạng: `_sync_form_items`), Pillar, hố Ground + đồ chôn, ô sáng, wand, `start_stage/before_fight/after_fight` |
| `  endless_waves.gd` | wave Endless (seed + stage), port `endless-stages.ts`; `display_name(wave)`; áp độ khó lên wave (`_apply_difficulty`), hệ của wave (`team_units`, `synergy_counts`) |
| `  difficulty.gd` / `wave_templates.gd` | **không có ở web**: mức độ khó (`data/difficulty.json`: ghi đè `config.endless`, hệ + item của địch, nhân chỉ số, **luật mana `mana`**) và template wave (`data/wave_templates.json`: slot Pokémon theo hệ / độ hiếm / sao / item) — `docs/DIFFICULTY.md` |
| `  town.gd` | sự kiện thị trấn: portal, propositions starter/unique/legendary, carousel, additional pick, town encounter |
| `  progression.gd` | **không có ở web**: `Progression` = Battle Pass (`data/progression.json`, lưu `user://progress.cfg`): XP mỗi run chơi tới hết (`run_xp`), cấp, hệ mở theo cấp; `GameData.apply_progression()` gỡ hệ còn khoá khỏi Pokémon / vùng / pool / item — `docs/PROGRESSION.md` |
| `  seasons.gd` | **không có ở web**: `Seasons` = mùa (`data/seasons.json`): danh sách họ shop / Unique / Legendary / trứng cố định cho run, mốc riêng của hệ ít Pokémon; chọn ở menu (`Settings.season`), `GameData.apply_progression()` áp vào các danh sách — `docs/SEASONS.md` |
| `  unit_roles.gd` | vai trò suy ra (tank, caster...) + item gợi ý |
| `src/view/` | `TftCamera` (@tool), `Arena` (@tool, sàn lục giác vẽ bằng shader `board.gdshader`: sân Poké Ball, viền ô mảnh, + lớp highlight theo ô; toạ độ ô ↔ thế giới), `UnitView` (AnimatedSprite3D billboard, icon trạng thái, chuyển động vẽ thêm `_animate_body`, shader `sprite_pixel_aa`), `SpriteLibrary` (cả shiny), `VfxLibrary` + `VfxPlayer` (hiệu ứng skill / đòn đánh / hit / tiến hoá), `Wanderers` (Pokémon lang thang bấm để bắt) |
| `src/ui/` | HUD kiểu TFT (scene trong `scenes/ui/`, theme `scenes/ui/theme/ui_theme.tres`), tooltip nhiều tầng `HoverTip` + `Tooltips`, `GameText` (keyword web → BBCode), `L.t` (dịch UI), `OptionsPanel`, `TownChoice`, `DpsMeter`, `CheatPanel` (F1), `PassPanel` (màn Battle Pass ở menu chính), `SeasonPanel` (danh sách Pokémon của mùa theo từng hệ) |
| `src/game/records.gd` | `Records`: kỷ lục theo độ khó (`user://records.cfg`; test đổi `Records.path`, screenshot `records=<file>`) |
| `src/game/run_stats.gd` | `RunStats`: thống kê cả run (cộng `fight_stats` từng trận theo họ Pokémon) → `RunSummary` (`src/ui/run_summary.gd`) trên bảng Game Over |
| `src/game/game.gd` | điều phối: pha, kéo thả, dựng trận qua `FightSetup`, hàng chờ lựa chọn (`choices`), nhạc, đổi event sim → hình ảnh / VFX / `fight_stats` |
| `src/core/run_rules.gd` | `RunRules`: luật run dùng chung Game + bot (máu mất, thưởng wave, áp lựa chọn thị trấn, tự chọn khi vào trận) |
| `tools/bot/` | bot tự chơi không view: `BotRun` (vòng stage chép từ Game + ghi TSV), `BotBrain` (quyết định, hồ sơ ngẫu nhiên), `BotPro` (bot pro: kế hoạch hệ theo quân + shop của run, rút softmax; đội hình / mua / item / kinh tế theo mô hình thắng; style `design` = kế hoạch cố định cho design test), `BotModel` + `model.json` + `train_model.py` (hồi quy logistic thắng / thua trên mọi trận), `BotKnowledge` + `knowledge.json` + `learn.py` (bảng kinh nghiệm), `autobalance.py` (một bước tự cân bằng → `data/balance.json`), `bot_runner.tscn` (worker), `report.py` / `balance.py` — `docs/BOT.md` |
| `tools/wave_editor/` | tool (scene Godot, chữ tiếng Việt) sửa `data/wave_templates.json` + `data/difficulty.json`, có xem trước wave |
| `tests/` | `sim_test` (logic), `flow_test`, `soak_test`, `layout_test` (kích thước UI, headless), `screenshot` |

Toạ độ: ô (x, y), x = 0..6, y = 0..3 phía người chơi (y = 3 hàng đầu), 4..7 phía địch; ô lục giác đỉnh nhọn, hàng lẻ lệch
nửa ô sang phải; bench = `Vector2i(i, Arena.BENCH_ROW)`. Wave địch: y 3 = hàng đầu … 0 = hàng thứ 4 (`EndlessWaves.to_sim_cell`).
Board của `PlayerState` dùng đúng toạ độ ô của trận (web: board y = positionY − 1).

## Quy ước / bẫy đã gặp

- Logic trong `src/core` không đụng node; view đọc `BattleUnit` và `sim.drain_events()`.
- **Lưới lục giác**: hướng là offset axial (`BattleBoard.DIRECTIONS`, 6 hướng) → dời ô bằng `BattleBoard.step(cell, dir)`,
  đừng `cell + dir` (chỉ hàng xóm cùng hàng `cell ± Vector2i(1, 0)` là cộng được); "sau lưng" = `step(t, offset(c, t))`,
  hướng ± 60° = `fan(dir)` / `turn(dir, k)`; khoảng cách / góc thật qua `center()` (đừng `Vector2(a - b)`). Số hàng một phía:
  `BattleBoard.SIDE_ROWS` (4) / `PlayerState.PLAYER_ROWS`, đừng viết số 3. Shader sàn chỉ dùng phép toán float (bản số
  nguyên làm hỏng pipeline D3D12). `sim_test._check_hex_board` kiểm hình học.
- Skill mới = thêm vào `data/abilities.json` rồi chạy `export_pac.bat` (Pokémon có đủ skill tự vào pool) + `sim_test`.
- Số trong JSON là float (`find(float(x))`); `Array.filter()` trả Array không kiểu → đừng gán vào `Array[T]`.
- `continue` trong `match` là continue vòng lặp (Godot 4).
- Test UI: sự kiện chuột giả phải dùng toạ độ cửa sổ (`get_viewport().get_final_transform() * pos`) và tự `emit mouse_entered`.
- Tham chiếu vòng (`counters`, lambda trong `schedule`) được phá ở `BattleSim.dispose()` — gọi khi xong trận.
- Wave PvE có synergy / item / hệ số chỉ số **tuỳ mức độ khó** (`Difficulty`; mức `classic` = như web: không synergy, boss không
  item). `sim_test` chạy ở `classic` rồi kiểm riêng độ khó trong `_check_difficulty`. Đọc số Endless qua `Difficulty.endless()`,
  đừng đọc thẳng `GameData.config.endless`.
- Hàm static tên `reload` trên class có `class_name` đụng `Script.reload(bool)` khi gọi từ ngoài → đặt tên khác (`load_data`).
- Chuỗi hiển thị cho người chơi: bọc `L.t("English")` + thêm bản dịch vào `data/i18n/ui.json` (giữ `%d`/`%s`, sim_test kiểm tra).
  Chữ game (synergy, item, trạng thái...) lấy qua `GameData` / `GameText.format`, không `L.t`.
- Test đọc chữ tiếng Anh: sim_test / screenshot tự đặt `en` (screenshot `lang=vi` để chụp tiếng Việt).
- Bash tool: heredoc có nháy/backslash dễ hỏng (`\` + xuống dòng bị nuốt; `tools\bot_run.bat`, `\a`, `\t` trong chuỗi Python gõ qua Bash thành ký tự điều khiển backspace / bell / tab) → viết script Python bằng Write rồi chạy, soát file docs bằng `ord(c) < 32`.
- GDScript: `match` bên trong lambda không parse được → tách ra hàm static.
- `export_pac.bat --data-only` KHÔNG cập nhật pool.json (Pokémon mới cần sprite) → sau khi thêm skill chạy `--no-music`.
- Lambda bắt biến cục bộ theo giá trị lúc tạo (gán lại sau đó không thấy) → truyền qua `bind()`.
- `data/i18n/vi.json`, `ui.json`, `data/ability_vfx.json` định dạng tay: chèn dòng, đừng ghi lại cả file bằng `json.dumps`.
- Chữ: UI co giãn theo cửa sổ (`canvas_items`, 1600×900 = 0.83 lần) nên glyph raster rơi vào toạ độ lẻ → Nearest thì bể nét,
  Linear thì mờ. Vì vậy font mặc định bật **MSDF** (`gui/theme/default_font_multichannel_signed_distance_field`) và filter
  mặc định của canvas là **Linear** → node 2D hiện pixel art (portrait) phải tự đặt `texture_filter = NEAREST`; sprite 3D đặt
  filter riêng trong `UnitView` / `VfxPlayer`. Thêm font riêng thì bật MSDF trong phần import của font đó.
- Đổi vùng luôn qua `PlayerState.change_map()` (pool vùng, cây quả mọng), đừng gán `player.map` trực tiếp.
- Font: **Be Vietnam Pro** (`assets/fonts/`), `gui/theme/custom_font` + bold/italic trong `ui_theme.tres`. Setting
  `default_font_multichannel_signed_distance_field` KHÔNG áp cho font riêng → MSDF bật trong `.ttf.import`
  (`multichannel_signed_distance_field=true`, sửa xong chạy `--import`).
- PP/mana: đọc luật của một unit qua `sim.mana_of(u)` (= `Difficulty.role_mana(u.role, sim.mana)`: `perSecond`, `perAttack`,
  `perHit`, `perDamage`, ghi đè theo vai trò `mana.roles`); đừng viết số cứng. Mặc định (`base`, mọi mức kể cả `classic`;
  người dùng chỉnh): Tank +15 mỗi đòn trúng, +5 mỗi lần bị đòn đánh trúng; Fighter +10 / +10; vai trò khác +10 / +5; `perHit`
  chỉ cộng trong `attack_hit` (skill không cho PP khi trúng); luật web ghi trong `Difficulty.WEB_MANA`. Chỉnh trong tab Độ khó
  của wave editor. **PP cần để cast không theo vai trò** (2026-11-19): maxPP riêng của dạng trong `GameData` (web × hệ số `pp`
  của tự cân bằng, hàng chục) qua `Difficulty.max_pp_of(own)` (0 → 100). Vai trò (`UnitRoles`) suy từ chỉ số **web**
  (`GameData.web_stat`), để cân bằng không đổi vai trò. **PP của hiệu ứng theo thanh 100 PP của web**: `u.add_pp(x)` = x ×
  maxPP / 100 (item, hệ, passive, skill, thời tiết, chỉ số PP), `u.add_pp(x, true)` = đúng x (luật `mana` và lượng đã tính theo
  `max_pp`); hút / cướp PP qua `u.drain_pp(x)` (trả lượng mất theo thang web), ngưỡng `u.web_pp(x)` — hiệu ứng mới viết theo
  số của web như vậy. Sát thương / hồi / khiên trong lúc skill chạy (và đòn trễ nó `schedule`) được gắn `ability` qua
  `sim.ability_source` (đặt trong `AbilityRunner.cast`) — skill gây sát thương ngoài cách đó thì bot không tính là của skill.
- Bench: `player.bench_slots` ô (difficulty `benchSize`, 8), mỗi ô chứa tới `player.bench_stack` con **giống nhau**
  (`benchStack`, 2; web 1). Mảng `bench` có `bench_size` = ô × stack chỗ: chỗ `i` thuộc ô `i / bench_stack`, lớp
  `i % bench_stack` (lớp 0 = con hiện ra). Vị trí bench là `{"bench": ô, "layer": lớp}` (`find`, `bench_loc`); arena / view
  chỉ dùng số ô. `first_free_bench_slot()` trả **chỗ** (index) đầu của ô trống; Pokémon mới vào bench thì dùng
  `put_on_bench()` / `bench_index_for()` (tự xếp chung với con giống nó), kiểm còn chỗ bằng `has_bench_room(pkm)`. Kéo thả:
  `can_place` / `move_unit` qua `_plan_move` (đổi chỗ, tách khỏi cặp); `_normalize_bench()` (trong `_board_changed`) dồn
  mỗi ô về trước. Ô bench `s` nằm ở hàng `s / 8` (`Arena.bench_rows`, shader `bench_rows`, texture highlight cao `6 + bench_rows`).
- Đổi vòng stage của `Game` (`_start_planning / _start_fight / _end_fight / _next_stage`) thì sửa `tools/bot/bot_run.gd` theo;
  luật chung (thưởng, máu mất, lựa chọn) đặt ở `RunRules`, không viết lại trong Game.
- Cheat (F1, difficulty `cheats`): `src/ui/cheat_panel.gd` gọi `Game.cheat_*`; thêm cheat mới = thêm hàm `cheat_*` trả chuỗi báo.
- Battle Pass: `GameData.pokemon[pkm].types` và các danh sách pool đã bỏ hệ / họ còn khoá (`all_types`,
  `GameData.full_list()` = bản gốc). Liệt kê hệ cho người chơi bằng `GameData.synergies()`, đừng dùng
  `config.synergyThresholds.keys()`. `GameData.apply_progression()` chỉ gọi ngoài run (`GameData.begin_run()` ở đầu run / menu
  xoá hệ mở tạm); trong run chỉ qua `GameData.unlock_for_run(map)` (vào vùng → hệ còn khoá của vùng mở tạm tới hết run, chỉ
  thêm hệ; `PlayerState.change_map` gọi, họ mới vào `pool_counts`). Test cần đủ nội dung: đặt
  `Progression.override_level = 9999` rồi gọi nó; test chơi thật đổi `Progression.path` (kẻo ghi vào pass thật).
- Mùa (`Seasons`): trong một mùa `GameData.additional` / `regional` / `regional_info` / `regional_variants` / `regional_base` đều
  **rỗng** — mọi họ shop của mùa nằm trong `pool` từ stage đầu, `in_region()` luôn đúng, `config.synergyThresholds` mang mốc của
  mùa (bản gốc: `GameData.full_thresholds()`). Đổi mùa chỉ qua `Settings.set_season()` (nó gọi `apply_progression()`), không đổi
  giữa run. `sim_test` chạy không mùa (`Seasons.FULL`) rồi kiểm riêng trong `_check_seasons`; flow / soak / layout / screenshot
  dùng mùa mặc định của file (`Seasons.use_default_unless_asked()`), không phải mùa người chơi đã lưu. Sửa `data/seasons.json`
  xong chạy `python tools/port/gen_seasons.py` (kiểm + ghi lại `docs/SEASONS.md`); `--generate` tính lại và **ghi đè** chỉnh tay.
- UI mobile: mọi kích thước HUD là đơn vị canvas (1920×1080 khi hệ số 1); trên máy thử canvas chỉ còn **1171×540**, nên
  thêm phần tử HUD mới thì phải cho nó chỗ trong `Hud._layout_compact()` và chạy `layout_test`. Panel có thể cao
  hơn canvas → `UiScale.fit()` (panel trong `CenterContainer`: co container, vì container đặt lại `scale` của con).
  Tooltip: gắn bằng `HoverTip.add` là đủ cho cả chuột lẫn chạm (chạm = mở, nút = giữ mới mở).
- UI mobile bản 4 (sàn to): shop **bật / tắt** (`Hud.set_shop_open`: mở đầu pha chuẩn bị, đóng khi vào trận) — đóng thì
  `board_rect` = từ mép phải cột trái tới nút Chiến!, từ thanh stage tới đáy màn (`Hud.board_room_full`), `_dock` (vàng trên
  nút Shop) thay shop làm vùng bán; hệ là chip hẹp (`SynergyRow.chip`, rộng 64). Góc camera gọn: `Game._pick_pitch()` =
  `Settings.board_pitch` (Tuỳ chọn → Góc nhìn sàn) hoặc tự chọn 36–60° cho sàn to nhất trong `board_room_full`. Thêm
  phần tử HUD: tính chỗ cho **cả hai** trạng thái shop và đừng lấn vào khoảng của sàn.
- Màn dựng bằng code đặt trong `CenterContainer` tạo bằng code (`open_over`): đặt `grow_horizontal/vertical = BOTH` cho
  container, kẻo panel cao hơn canvas lệch xuống dưới; trên canvas thấp thì dựng dạng gọn (`PassPanel._fill_compact`)
  thay vì để `UiScale.fit` co chữ. Popup chọn item: mỗi ô có nút **i** xem chi tiết (`ItemChoiceButton.show_details`).
- Thanh máu / item trên Pokémon (`UnitOverlay`) vẽ **phía trên** `UnitView.head_position()` và co theo cỡ ô trên màn hình;
  điểm trên sprite phải tính theo `UnitView.sprite_up()` (trục dọc của camera vì sprite là billboard), đừng dùng `Vector3.UP`.
- Sprite Pokémon (`UnitView`, `docs/HANDOFF.md` mục 12):
  - Đòn đánh thường gọi `v.attack(anim, u.attack_cooldown(), hit_delay, đích, ranged)` (animation kéo dài bằng cooldown
    như web), đừng gọi `play(anim, true)`. Tốc độ tua đi qua `UnitView.time_scale` (Game đặt mỗi frame).
  - `_animate_body` ghi `sprite.position / scale` mỗi frame (node = ô của sim): hiệu ứng mới thêm vào đó hoặc đẩy lò xo
    bằng `_kick()`, đừng tween hai thuộc tính này ở chỗ khác.
  - Shader `sprite_pixel_aa` là `material_override`: đổi `sprite_frames` thì gọi `_sync_sheet()`, đổi `render_priority`
    thì đặt cả cho `_sprite_mat`.
- **Bản export khác bản chạy trong editor**: lúc export scene bị đóng gói lại và mất mọi thuộc tính bằng mặc định → một
  setter chạy trước đó có tác dụng phụ sẽ thắng (`anchors_preset = 6` tự đặt `grow_vertical = BOTH`; dòng `grow_vertical = 1`
  viết tay trong `.tscn` biến mất trong APK). Node neo tuỳ biến: `anchors_preset = -1`; đặt lại vị trí bằng code thì đặt cả
  hướng mọc (`Hud._place`). `layout_test` (`_export_fidelity`) bắt lỗi loại này; thấy bản máy thật lệch bản test thì soát
  scene trong APK trước (`docs/HANDOFF.md` mục 9).
- **Tự cân bằng** (`data/balance.json`, không có ở web): **mỗi Pokémon có chỉ số riêng** — `GameData.pokemon` đã nhân hệ số
  của từng chỉ số (`hp`, `atk`, `skill` = `ap` gốc 100 (m − 1), `def` / `speDef` / `speed`, `pp` = maxPP; HP và PP làm tròn
  hàng chục; `GameData.balance_form`); không có hệ số theo hệ (người dùng: cân theo chỉ số từng con). Tiêu chí + mục tiêu
  (số lần cast theo vai trò, hồ sơ công / thủ của vai trò, độ hiếm, có / không item): `tools/bot/balance_targets.json`,
  `docs/BOT.md`. Đọc chỉ số từ `GameData`, đừng đọc thẳng `data/pac/pokemon.json`;
  test cần số web thì `GameData.use_balance(false)` (sim_test làm vậy); về web hẳn: `python tools/bot/autobalance.py --reset`.
  Lô bot dùng cho một bước phải chơi với đúng `version` hiện tại (`meta_W.tsv` → `balance`).
- Ô shop: gán qua `PlayerState.set_shop_slot(i, pkm)` (bản sao rời pool lúc hiện trong shop, như `shop.ts`), đừng gán `shop[i]`.
- Pokémon vào pool shop: gọi `PlayerState.record_pool_news()` / `unlock_additional()` (nút `!` cạnh ổ khoá + `PoolTip`);
  đừng thêm một dòng banner cho mỗi con (banner giới hạn 7 dòng phụ, tối đa 4,5 s).

## Trạng thái (2026-10-04)

Đã xong: Phase 1–7 (camera, sàn, sprite, UI kiểu TFT, item, 31 synergy, trạng thái, 12 weather, passive, thị trấn,
Options 14 ngôn ngữ, nhạc / âm thanh / VFX / DPS meter), item của mọi hệ, shop vùng + Pokémon regional, độ khó + template
wave (`docs/DIFFICULTY.md`), **551 skill, không còn skill `approx`**, và đợt **port nốt 2026-10-04**: luật trạng thái
theo `status.ts`, hồi sinh, passive viết lại theo `passives.ts`, tiến hoá đặc biệt (`EvolutionRules`), shop Ditto / Meltan /
Falinks + giá mua bán theo web, Pokémon lang thang (Magnet Pull, truy nã), trận shiny (Celebi), duo, town encounter 23/23,
VFX 473 skill (78 còn lại web cũng không có). Thêm riêng: kỷ lục theo độ khó, Android (preset + chạm giữ, APK debug).
Chi tiết: `docs/HANDOFF.md`, `docs/PORTING.md` mục "Port nốt phần còn thiếu", `docs/TODO_PORT.md`.

2026-11-11: VFX cho 78 skill còn thiếu (mọi skill đều có spec), màn thống kê sau run, sửa lệch web ở shop pool + táo Applin.

2026-11-14: **Battle Pass** (mở khoá hệ qua nhiều run: bắt đầu 10 hệ, 22 cấp, `docs/PROGRESSION.md`), `layout_test`,
tool chụp ảnh trên desktop ẩn.

2026-11-14 (sau khi thử trên Oppo Reno 15 Pro): **UI mobile** — `UiScale` (×2,0 trên máy đó), HUD compact, camera tự
căn sàn, chạm = xem chi tiết Pokémon / item / tooltip. Sau ảnh chụp thứ hai (chữ vừa, UI tràn): **bố cục gọn bản 2** (shop
cân giữa, thanh stage hai dòng, bảng Pokémon 300×300 không che nút Chiến!) + sửa lỗi chỉ có ở bản export. Kiểm bằng giả lập
đúng cấu hình máy thật (`layout_test`, ảnh trên desktop ẩn).

2026-11-15: **Mùa** (kiểu TFT set) — mỗi run chơi với danh sách cố định của một mùa chọn ở menu chính: 3 mùa × 96 họ shop
(hệ đại trà 8–10 họ, hệ đặc biệt 3–5 họ + mốc riêng, mỗi mùa 4 hệ đặc trưng), Unique / Legendary / trứng theo mùa, không
còn additional gia nhập giữa run hay Pokémon vùng; màn *Pokémon của mùa*, kỷ lục theo mùa + độ khó (`docs/SEASONS.md`).

2026-11-15 (sau ảnh tham chiếu TFT mobile): **bố cục gọn bản 3 — sàn to**: shop bật / tắt, hệ dạng chip, thanh máu + item
nằm trên đầu Pokémon và co theo cỡ ô (không còn che sprite). Sau ảnh khoanh vùng đỏ của người dùng: **bản 4** — sàn lấp
gần hết khoảng trống (787×455 trên máy thử), góc nhìn tự khớp (+ tuỳ chọn Góc nhìn sàn), chip hệ hẹp hơn, **bench 8 ô ×
2 con giống nhau** (một hàng).

2026-11-16: soát mọi màn ở cấu hình máy thử — **màn Battle Pass dạng gọn** cho điện thoại (không co), nút **i** xem chi
tiết item trong popup chọn item, sửa căn giữa các màn dựng bằng code, danh sách `!` không đè shop.

2026-11-16 (sau): **Battle Pass theo ván** — bắt đầu 3 hệ (Fire, Water, Grass), +100 XP mỗi run chơi tới hết (Game Over),
1 run → cấp 2 (+Normal), rồi 3 run một cấp (+2 hệ), 16 cấp; người dùng ghi "không cần test" nên chưa chạy test (kỳ vọng
`sim_test` đã sửa theo). **Điểm chung Pokémon** (`docs/THEMES.md`, `docs/themes.html`): 55 điểm chung (con vật, nghề,
truyền thuyết, đồ vật) cho 508 họ, category Pokédex từ PokéAPI, tham chiếu cách TFT Set 19 xếp hệ — để người dùng chọn hệ mới.

2026-11-18: **mana theo vai trò** (`mana.roles` trong `data/difficulty.json`: PP tối đa / mỗi đòn trúng / mỗi lần bị đòn đánh
trúng; trúng skill không cho PP) và **hệ mở tạm theo vùng** (tới vùng nào thì hệ còn khoá của vùng đó mở tới hết run).
**Bot tự chơi** (`docs/BOT.md`): chơi Endless không view với hồ sơ ngẫu nhiên, ghi TSV (run / stage / unit) cho Claude phân
tích, `report.py` ra bảng gọn + `boards.tsv`; ~2 s / run / worker.

2026-11-18 (sau): **bot pro bản 2** (kế hoạch hệ theo quân + shop của run, rút softmax; mọi quyết định theo mô hình thắng
học từ data `tools/bot/model.json`), **design test** (`-Design`: mọi cặp hệ của mùa, 4 116 run: Poison và Rock + Sound ở
s3 phá meta), **tự cân bằng** (`data/balance.json` = chỉ số riêng của từng dạng Pokémon: HP / ATK / skill, học từ bot,
`tools/autobalance.bat`; người dùng: chỉ số chưa cân, mục tiêu cân tự động từ data bot, mỗi Pokémon chỉ số riêng) —
version 3: 792 dạng (`build/bot/balance_stats.tsv`, `docs/BOT.md`).

2026-11-19: **tự cân bằng phương pháp 4** theo tiêu chí của người dùng (vai trò / khác vai trò, có / không item, độ hiếm,
số lần cast mỗi trận; mục tiêu cuối: nhiều chiến thuật carry + item + hệ, không chiến thuật nào áp đảo) — mọi chỉ số (HP /
ATK / DEF / SPE_DEF / SPEED / skill / **PP**), mục tiêu ở `tools/bot/balance_targets.json`, báo cáo `balance_report.txt` mỗi
lô. **PP tối đa riêng từng Pokémon** (không theo vai trò; vai trò chỉ còn PP mỗi đòn / mỗi lần bị đánh), HP / PP hàng chục;
**PP của hiệu ứng theo thanh 100 PP** (`BattleUnit.add_pp`); vai trò suy từ chỉ số web. Tracking: `units` TSV thêm PP nhận,
số đòn, sát thương nhận theo loại, giáp chặn, chỉ số vào trận, **sát thương / hồi + khiên của skill** (event `ability`:
`BattleSim.ability_source`, cả đòn trễ), sát thương tính **không phần thừa** (đòn kết liễu 9 999 = HP còn lại). Cân sức
mạnh skill qua **đúng chỉ số skill scale** (AP / ATK, tool đọc `abilities.json` + `ability_scripts.gd`) và tỉ lệ skill / đòn
tay theo vai trò (`skillShare`); số lần cast nhắm theo trận 16 s (`refFight`). Phát hiện: cast quá ít (TB < 1 lần / trận →
nay ~1,4–2,2), tank gây sát thương nhiều nhất, đội xếp tank áp đảo, độ hiếm đảo ở vài nhóm — `docs/BOT.md`. Vòng lặp
v6 → v9 (3 × 3 000 run): độ lệch giá trị các dạng 0,099 → **0,050**, tank gây 0,87 phần đều (trước 1,19), cast sát mục tiêu;
còn: đội nhiều tank vẫn thắng nhất, support yếu. Balance **version 9** (1 178 dạng, chưa có lô nào chơi).

2026-11-20: **làm mượt chuyển động sprite** (`docs/HANDOFF.md` mục 12):
- Animation đòn đánh theo tốc độ đánh như web và theo tốc độ tua; không còn chớp Idle giữa hai đòn / hai bước đi.
- Chuyển động vẽ thêm mỗi khung hình: thở, nảy khi đi, lao tới / lùi khi đánh, bị đẩy + bẹp khi trúng, pop khi xuất hiện,
  lún khi ngất.
- Sprite lọc "sharp bilinear" (`src/view/shaders/sprite_pixel_aa.gdshader`).
- Chế độ chụp `motion` + `tools/motion_gif.py` để so chuyển động.

2026-11-20 (sau): **sàn lục giác 7×8** (kiểu TFT, đỉnh nhọn, hàng so le; mỗi phía 4 hàng) thay lưới vuông 8×6 của web —
logic trận (khoảng cách / 6 hướng / đường đi / tìm ô trống), skill theo hướng và hình dạng, wave (hàng thứ 4, boss web ép
về 7 cột), bot, sơ đồ skill; sàn vẽ lại như sân Pokémon (Poké Ball giữa sân, viền ô mảnh nhạt), camera desktop lùi cho vừa
sàn sâu hơn (`docs/HANDOFF.md` mục 13, `docs/PORTING.md` "Lưới lục giác"). Cân bằng / mô hình bot còn học trên sàn vuông.

Hướng tiếp: người dùng chọn điểm chung → hệ mới cho từng mùa (`docs/THEMES.md`), duyệt / chỉnh 3 mùa, cân mốc riêng của
hệ đặc biệt; xác nhận bố cục gọn bản 4 trên máy thật, ký release; chạy bot lô lớn (hàng chục nghìn run) rồi cân độ khó
từng wave / `normal` / `hard` theo dữ liệu, lấy đội hình bot (`boards.tsv`) làm wave Endless (`docs/BOT.md`).
