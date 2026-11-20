# Battle Pass — tiến trình mở khoá hệ (chỉ có ở bản Godot)

Bản web cho người chơi cả 31 hệ ngay từ ván đầu. Bản Godot thêm một **Battle Pass** mà mục đích chính là
*unlock progression*: người mới bắt đầu với 3 hệ (Fire, Water, Grass) để học, chơi càng lâu càng mở thêm hệ (và các
Pokémon, item, hệ thống giữa stage đi kèm hệ đó).

Dữ liệu: `data/progression.json` • Code: `src/core/progression.gd` (`Progression`), `GameData.apply_progression()`,
`src/ui/pass_panel.gd` (`PassPanel`) • Lưu: `user://progress.cfg`.

## 1. Luật

(Đổi 2026-11-16 theo yêu cầu: trước đó bắt đầu 10 hệ, 22 cấp, XP theo từng trận.)

- **XP pass tính theo ván (run)**: mỗi run **chơi tới hết** (Game Over) +100 XP. Thoát giữa chừng bằng nút Menu không
  tính ván (chặn kiểu vào rồi thoát ngay để cày). Run đã dùng cheat (F1) không nhận XP. Hệ số độ khó vẫn có trong file
  nhưng đang để ×1 ở mọi mức, XP theo trận (`perStage` / `perWin`) đang tắt (0).
- **Cấp**: pass có 16 cấp. Cấp 1 có **3 hệ**; **1 run** là lên cấp 2 (+1 hệ); sau đó **cứ 3 run lên một cấp, mỗi cấp
  mở 2 hệ** (cấp cuối mở hệ còn lại). Mở hết 31 hệ sau 43 run.
- **Hệ mở ở cấp nào thì dùng được từ run kế tiếp** — trong một run, bộ hệ không đổi. Lên cấp lúc Game Over thì bảng
  Game Over báo "Lên cấp! Mở cho run kế tiếp: …".
- Hết cấp 16: mọi thứ như bản web.

### Bảng cấp (mặc định)

| Cấp | XP lên cấp | Tổng XP | Sau run thứ | Hệ mở | Ghi chú |
|---|---|---|---|---|---|
| 1 | — | 0 | — | Fire, Water, Grass | bộ ba quen thuộc; shop cấp 1 còn 28 / 94 họ (không mùa), ~27–30 / 96 họ trong một mùa |
| 2 | 100 | 100 | 1 | Normal | khiên |
| 3 | 300 | 400 | 4 | Electric, Flying | |
| 4 | 300 | 700 | 7 | Fighting, Rock | |
| 5 | 300 | 1 000 | 10 | Poison, Field | |
| 6 | 300 | 1 300 | 13 | Dark, Steel | chí mạng, nhảy vào hàng sau / giáp cả đội, sát thương chuẩn |
| 7 | 300 | 1 600 | 16 | Ice, Ghost | đóng băng / né, SILENCE, nguyền |
| 8 | 300 | 1 900 | 19 | Monster, Aquatic | lớn lên khi hạ địch / sóng thần, giải trạng thái |
| 9 | 300 | 2 200 | 22 | Bug, Sound | nhân bản đầu trận / buff khi dùng skill |
| 10 | 300 | 2 500 | 25 | Dragon, Wild | hệ thứ hai tính đôi / luật "Pokémon hoang dã" của shop |
| 11 | 300 | 2 800 | 28 | Fairy, Psychic | đũa phép / shop Unown |
| 12 | 300 | 3 100 | 31 | Fossil, Amorphous | khiên lớn lúc yếu máu / mạnh theo số hệ đang kích hoạt |
| 13 | 300 | 3 400 | 34 | Human, Ground | TM / đào hố, đồ chôn |
| 14 | 300 | 3 700 | 37 | Flora, Baby | chậu hoa / trứng |
| 15 | 300 | 4 000 | 40 | Artificial, Light | công cụ / ô sáng |
| 16 | 300 | 4 300 | 43 | Gourmet | đầu bếp, món ăn |

Thứ tự giữ như bản cũ: hệ hiệu ứng thuần trong trận trước, hệ có luật riêng sau, cuối cùng là các hệ có hệ thống giữa
stage. Lưu ý: hệ đặc trưng của mùa (vd. mùa 1: Wild, Baby, Flora, Dragon) mở khá muộn — xem lại khi cân pass theo mùa.

### Hệ mở tạm theo vùng (2026-11-18)

Yêu cầu người dùng (thay cho ý "tăng độ khó sau stage 50 ở 10 cấp đầu", đã bỏ): **tới một vùng thì các hệ của vùng đó mà pass
chưa mở được mở tạm cho tới hết run**.

- Cổng (`Town.portals`) ghi `unlocks` = hệ của vùng đích còn khoá (`GameData.region_unlocks`); nút cổng hiện dòng **"Mở tạm"** +
  biểu tượng, tooltip ghi tên. Vùng của cổng vẫn chọn theo hệ đã mở như trước.
- Vào vùng (`PlayerState.change_map`: cổng, Lapras Passport, cheat) → `GameData.unlock_for_run(map)` thêm vào
  `GameData.run_unlocked` rồi áp lại khoá (`apply_progression(true)`, giữ các wave đã dựng): Pokémon đang có **thêm** hệ (không
  bao giờ mất), họ của hệ mới vào shop ngay (thêm bản sao vào `pool_counts`, danh sách `!`), item của hệ đó vào các nguồn item,
  Pokémon vùng theo hệ đó xuất hiện. Báo trong popup chọn Pokémon kế tiếp (hoặc banner nếu không có popup).
- Run mới / menu chính (`GameData.begin_run`) xoá hết hệ mở tạm — chỉ còn hệ của pass.
- Ngay cổng đầu run (stage 0) đã mở tạm tới 2–3 hệ: run cấp 1 thực tế chơi với 3 hệ của pass + hệ của các vùng đi qua (bot của
  `soak_test` kết thúc run với 7 / 31 hệ).

## 2. Hệ chưa mở nghĩa là gì

> Từ 2026-11-15 game chia **mùa** (`docs/SEASONS.md`): mùa quyết định *họ nào* có mặt, pass quyết định *hệ nào* đã mở,
> pass áp sau mùa. Các con số "28 / 94 họ shop" bên dưới là khi chơi **không mùa**; trong một mùa (96 họ shop) cấp 1 còn
> khoảng 27–30 họ, và mỗi độ hiếm luôn còn ít nhất 2 họ (`sim_test::_check_seasons` kiểm cho từng mùa).

Hệ chưa mở **không tồn tại** trong game của người chơi đó:

- **Bị gỡ khỏi mọi Pokémon** (cả phía địch): không hiện trên thẻ / tooltip, không đếm, không kích hoạt. Ví dụ ở
  cấp 1, Charmander chỉ là Fire (Dragon ẩn), Azurill chỉ là Water (Fairy và Baby ẩn).
- **Họ Pokémon mà dạng đầu không còn hệ nào đã mở thì chưa xuất hiện** ở bất cứ đâu: shop, additional pick, đề xuất
  Unique / Legendary (kể cả duo), trứng, Pokémon vùng, bầy hoang dã của wave. Ở cấp 1 shop có 28 / 94 họ
  (Common 9, Uncommon 5, Rare 5, Epic 6, Ultra 3).
- **`gatedBy`** (mặc định `WILD`): họ có hệ này ở dạng đầu đứng ngoài cho tới khi hệ mở, dù còn hệ khác đã mở —
  Pokémon hoang dã có luật shop riêng (chỉ gặp với "tỉ lệ Wild"), để lẫn vào shop thường sẽ sai luật.
- Pokémon độ hiếm **SPECIAL** (Ditto, Meltan, Magikarp / Remoraid câu được, lính Falinks, vật triệu hồi) và Pokémon
  vốn không có hệ (Arceus, Kecleon, trứng, trụ) luôn có — chúng đến từ cơ chế chứ không từ pool.
- **Vùng**: biểu tượng hệ của cổng và hệ của vùng chỉ gồm hệ đã mở. Pokémon vùng "sống nhờ" một hệ của vùng
  (Alolan Vulpix ↔ vùng Ice) chỉ có khi hệ đó đã mở — suy ra từ dữ liệu export (`GameData._infer_regional_links`).
- **Item**: đá hệ, gem, công cụ, Memory Disc của hệ chưa mở không nằm trong các nguồn ngẫu nhiên (carousel,
  thưởng boss, đồ chôn, cửa hàng thị trấn). Nếu vẫn có (ghép từ Fossil Stone) thì item chỉ cộng chỉ số, tooltip có ghi.
- **Wave**: template cần một hệ chưa mở (Hang Rồng khi chưa có Dragon) tạm không dùng.
- Mọi hệ thống gắn với hệ (đũa phép, TM, chậu hoa, trứng, hố, ô sáng, Unown…) tự tắt vì hệ không bao giờ kích hoạt.

## 3. Giao diện

- **Menu chính**: dòng pass dưới kỷ lục — nút *Battle Pass*, cấp, thanh XP, rồi "Mới: …" (hệ vừa mở, tới khi mở
  màn pass) hoặc "Kế tiếp: …".
- **Màn Battle Pass** (`PassPanel`): cấp + XP, luật XP (theo độ khó đang chọn), 3 hệ khởi đầu, lưới 15 cấp (đã mở:
  viền vàng; cấp kế: viền xanh + tiến độ; còn khoá: mờ + ổ khoá + XP cần). Hover một hệ: tooltip hệ (mô tả, các mốc).
  Khi `cheats` bật trong `data/difficulty.json`: nút **−1 / +1 / Mở hết / Đặt lại** để chỉnh cấp.
- **Trong run**: cổng đầu tiên ghi "Mới trong run này: …" nếu run trước vừa mở hệ; lên cấp giữa run báo ở banner stage.
- **Game Over**: khối *Battle Pass* trong bảng thống kê — XP của run, thanh cấp, "Lên cấp! Mở cho run kế tiếp: …".

Ảnh chụp: `build/shots/battle_pass_*.png`.

## 4. Chỉnh (`data/progression.json`)

| Khoá | Ý nghĩa |
|---|---|
| `enabled` | `false` = tắt hẳn pass: mọi hệ mở sẵn, không XP, không hiện ở menu / Game Over |
| `xp.perRun` | XP khi một run chơi tới hết (Game Over), 100 |
| `xp.perStage`, `xp.perWin` | XP mỗi trận đã đấu / cộng thêm khi thắng (đang 0 = tắt) |
| `xp.difficulty` | hệ số theo id mức độ khó (mức không ghi = 1) |
| `gatedBy` | các hệ giữ cả họ ở ngoài khi còn khoá |
| `levels[i]` | cấp `i + 2`: `xp` = XP từ cấp trước, `synergies` = các hệ mở (có thể nhiều hệ, hoặc rỗng) |

- **Hệ khởi đầu = mọi hệ không nằm trong `levels`.** Muốn một hệ có sẵn từ đầu thì xoá nó khỏi `levels`.
- Cấp của người chơi tính lại từ tổng XP đã lưu mỗi lần đọc, nên đổi `xp` của các cấp sẽ đổi cấp hiện tại của họ.
- `sim_test` kiểm file (`Progression.problems()`: hệ lạ, hệ mở hai lần, XP ≤ 0) và kiểm ở cấp 1: mỗi độ hiếm còn
  ≥ 3 họ trong shop (trong mùa ≥ 2), mỗi hệ khởi đầu đủ họ để chạm mốc đầu; nhịp 1 run → cấp 2, 3 run một cấp.

## 5. Kỹ thuật

- `Progression` (static, không node): đọc file, `level()`, `progress()`, `rewards(level)`,
  `unlocked_synergies()`, `run_xp()`, `stage_xp(won)`, `xp_rule()` (chữ luật XP), `add_xp(n)` (lưu, trả `{gained, from, to, unlocked}`), `report()` cho
  Game Over, `unseen_synergies()` / `mark_seen()` (dấu "Mới" ở menu), `take_run_news()` (báo một lần đầu run),
  `set_level()` (cheat). File lưu: `[pass] xp, seen, run`.
- `GameData.apply_progression()` là **chỗ duy nhất** áp khoá:
  - `pokemon[pkm].types` = các hệ đã mở (bản gốc giữ ở `all_types`); `config.maps[m].synergies` tương tự
    (`all_synergies`);
  - các danh sách `pool`, `additional`, `unique`, `legendary`, `hatch`, `regional`, duo và `tier1_by_rarity…` chỉ còn
    họ đã mở → `is_available()` là false với Pokémon còn khoá; bản đầy đủ: `GameData.full_list(name)`;
  - `full_items`, `items_in()` bỏ item của hệ khoá; `item_synergy()` trả `""` cho hệ khoá.
  Gọi khi game khởi động, ở menu chính và **đầu mỗi run** (`Game._ready`) — không gọi giữa run.
- `GameData.synergies()` = danh sách hệ đã mở theo thứ tự web; `synergy_unlocked(type)`, `pokemon_unlocked(pkm)`,
  `item_locked(item)`, cờ `all_unlocked`. `Synergies.tier()` trả 0 và `Synergies.count()` bỏ điểm cộng của hệ khoá
  (lớp chắn thứ hai).
- `Game`: `run_xp()` cộng lúc Game Over (`_next_stage`), `_grant_pass_xp()` sau mỗi trận (XP theo trận, đang 0),
  `pass_xp`, `_pass_from`, `_run_news`.

### Thử / test

- `-- pass=<cấp>` hoặc `-- pass=all` sau lệnh chạy scene: ép cấp đó, **không lưu gì**. `-- pass_file=<file>`: dùng file lưu khác.
- `sim_test` chạy với mọi hệ mở (`Progression.override_level = 9999`) rồi kiểm riêng pass trong `_check_progression`.
- `flow_test` và `soak_test` dùng pass mới trong `user://test_progress.cfg` (cấp 1: chơi với hệ khởi đầu, nhận XP);
  `soak_test -- pass=all` chơi với mọi hệ.
- `layout_test` (headless): đo màn pass, dòng pass ở menu, bảng Game Over ở vài cấp — phải nằm gọn trong 1920×1080.
- Tool `wave_editor` và `screenshot` luôn mở hết (trừ khi có `pass=`).

## 6. Việc có thể làm tiếp

- Cân lại nhịp XP sau khi chơi thử thật (số hiện tại là ước lượng từ bot của `soak_test`).
- Thêm loại phần thưởng khác cho cấp (mức độ khó, vùng, item…): mỗi mục của `levels` hiện chỉ đọc `synergies`.
- Màn giới thiệu hệ mới (hiện là tooltip + dòng chữ).
