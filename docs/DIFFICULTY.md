# Độ khó, wave địch và template wave

Cập nhật: 2026-09-30. Phần này **không có ở bản web** — là lớp cấu hình riêng của bản Godot đặt lên trên luật Endless đã port.

| Muốn chỉnh | Ở đâu |
|---|---|
| Độ khó chung: số con, sao, item, hệ, hệ số chỉ số của địch, máu / vàng người chơi | `data/difficulty.json` — tab **Độ khó** của tool |
| Đội hình của từng loại wave: bao nhiêu con, hệ gì, độ hiếm, bậc sao, item, hàng đứng | `data/wave_templates.json` — tab **Template wave** của tool |
| Công thức (cách áp các số trên) | `src/core/difficulty.gd`, `src/core/endless_waves.gd`, `src/core/wave_templates.gd`, `src/core/fight_setup.gd` |
| Số gốc của bản web (mặc định khi không ghi đè) | `data/pac/config.json` → `endless` (sinh tự động, không sửa tay) |

Tool: chạy **`tools\wave_editor.bat`** (mở một cửa sổ Godot riêng). Bấm **Lưu** (Ctrl+S) ghi cả hai file; game đọc file lúc khởi động,
nên đang mở game thì chơi lại từ menu sau khi khởi động lại.

---

## 1. Mức độ khó

Chọn ở **menu chính** (ô “Độ khó” dưới nút Chơi), lưu trong `user://settings.cfg`. Mức áp dụng cho run bắt đầu sau đó.
Trong trận, hover “Stage N” trên thanh stage để xem mức đang chơi.

| Mức | Khác gì |
|---|---|
| `classic` — Cổ điển | đúng bản web: wave **không** kích hệ, boss không cầm item, không template (luật mana là chung cho mọi mức, xem `mana`) |
| `normal` — Thường (mặc định) | wave kích hệ từ stage 5, boss cầm item, có template wave |
| `hard` — Khó | kích hệ từ stage 1 và +1 điểm mỗi hệ, 2★ / 3★ và item đến sớm hơn, HP ×1.15 / ATK ×1.1 rồi +1% / +0.5% mỗi stage, cộng dồn chỉ số từ stage 15, mất máu ×1.5 |

Thêm mức mới: nút “＋ Mức mới” trong tool (hoặc thêm khoá vào `levels`); nó tự hiện ở menu chính. Tên mức dịch được bằng cách
thêm dòng vào `data/i18n/ui.json`.

### 1.1 Cấu trúc `data/difficulty.json`

```
active   mức mặc định khi người chơi chưa chọn
base     giá trị chung của mọi mức
levels   { id: { label, desc, ...các khoá ghi đè base } }
```

Một mức = `base` + phần ghi đè của nó. Dictionary lồng nhau (`endless`, `statScale`...) được gộp **theo từng khoá**, nên mức
`hard` chỉ cần ghi `"statScale": {"HP": 1.15}` là các chỉ số khác vẫn lấy của `base`.

### 1.2 Các tham số

**Đội hình bầy hoang dã** — nhóm `endless` (ghi đè `config.endless` của web; khoá không ghi thì lấy số web):

| Khoá | Mặc định | Ý nghĩa |
|---|---|---|
| `unitsBase`, `unitsPerStage`, `minUnits`, `maxUnits` | 2, 0.3, 3, 9 | số con = `round(unitsBase + stage × unitsPerStage)`, kẹp trong [min, max] |
| `twoStarsStages` | [4, 16] | xác suất 2★ mỗi con tăng đều từ 0% (stage 4) tới 100% (stage 16) |
| `threeStarsStages` | [14, 30] | tương tự cho 3★ (xét trước 2★) |
| `bossInterval` | 5 | sau boss gốc cuối (stage 40), cứ 5 stage một boss quay lại |
| `firstItemStage`, `stagesPerItem`, `fullItemsStage` | 8, 2, 14 | bầy hoang dã cầm 1 item từ stage 8, thêm 1 mỗi 2 stage; từ stage 14 là item ghép. Con nhiều sao cầm trước |
| `scalingStartStage`, `statBoostsPerStage` | 25, HP 15 / ATK 2 / AP 5 / DEF 0.5 / SPE_DEF 0.5 | từ stage 25, mỗi stage cộng thẳng chừng đó cho mọi con (kể cả boss quay lại) |
| `rewardInterval`, `fullItemRewardsStage` | 3, 20 | bầy hoang dã thưởng 1 item mỗi 3 stage; từ stage 20 là item ghép |
| `componentPool`, `fullItemPool` | (của web) | item mà wave cầm / thưởng; chỉ sửa tay trong JSON |

Độ hiếm của bầy hoang dã dùng tỉ lệ shop của level = số con trong bầy (từ stage 30: level 10), nên tăng số con cũng là tăng độ hiếm.

**Hệ của địch**

| Khoá | `base` | Ý nghĩa |
|---|---|---|
| `enemySynergies` | true | wave địch đếm hệ và nhận hiệu ứng hệ như đội người chơi (`classic`: false) |
| `enemySynergiesFromStage` | 5 | chỉ từ stage này |
| `bossSynergies` | true | boss (gốc và quay lại) cũng kích hệ |
| `synergyBonus` | 0 | cộng N điểm vào **mỗi hệ mà wave có** — để wave ít con vẫn đạt mốc |

**Item của địch**

| Khoá | `base` | Ý nghĩa |
|---|---|---|
| `bossItems` | true | boss gốc cầm `marowakItems` của bản web mà không cần gặp Marowak (`classic`: false) |
| `itemsPerUnit` | 3 | trần item mỗi con (0 = địch không cầm item) |

**Chỉ số của địch** — thứ tự áp lên một con: chỉ số gốc × `statScale` → + cộng thẳng → + item → + hệ / thời tiết.

| Khoá | `base` | Ý nghĩa |
|---|---|---|
| `statScale` | mọi chỉ số 1 | nhân chỉ số gốc (HP, ATK, DEF, SPE_DEF, SPEED). Chỉ số “gốc” (BASE) mà item / hệ dùng cũng được nhân |
| `statScalePerStage`, `statScaleStartStage` | 0, 1 | hệ số = `statScale + perStage × max(stage − start, 0)`; 0.01 = +1% mỗi stage |
| `statBoosts` | 0 | cộng thẳng cho mọi con ở mọi stage (HP, ATK, DEF, SPE_DEF, AP, SPEED, PP, CRIT_CHANCE) |

**Mana (PP) cơ bản** — nhóm `mana`, áp cho **mọi** Pokémon trong trận (cả hai đội) ở **mọi mức** (đặt ở `base`). PP của item /
hệ / passive và ±3 của thời tiết (RAIN +3, DROUGHT −3) không đổi; DROUGHT trừ vào `perSecond` nên khi `perSecond` = 0 nó bào mòn
PP kiếm được từ đòn đánh.

**Theo vai trò** (2026-11-18, yêu cầu người dùng; vai trò suy ra ở `src/core/unit_roles.gd` từ tầm đánh / skill / chỉ số
**web** — tự cân bằng không đổi được vai trò): `mana.roles.<vai trò>` ghi đè các khoá trên cho Pokémon có vai trò đó
(`Difficulty.role_mana`, trong trận `BattleSim.mana_of(u)`; vai trò giữ nguyên khi đổi dạng).

| Vai trò | `perAttack` (mỗi đòn trúng) | `perHit` (mỗi lần bị đòn đánh trúng) |
|---|---|---|
| Tank (Đỡ đòn) | 15 | 5 |
| Fighter (Đấu sĩ) | 10 | 10 |
| Marksman (Xạ thủ), Caster (Pháp sư), Support (Hỗ trợ), Assassin (Sát thủ) | 10 | 5 |

**PP cần để dùng skill không theo vai trò** (2026-11-19, người dùng: "max pp bây giờ không theo cả hệ, chỉ có pp gain per
hit và be hit thôi"): mỗi Pokémon có **maxPP riêng** = maxPP web × hệ số `pp` của `data/balance.json`, làm tròn hàng chục
(`GameData.balance_form`; `Difficulty.max_pp_of(own)`; 0 = không có skill → 100). Tự cân bằng chỉnh hệ số đó cho số lần dùng
skill mỗi trận hợp lý (`tools/bot/balance_targets.json` `casts`, `docs/BOT.md`). Skill TM: 100 (web). Trước đó (2026-11-18):
tank 100, fighter 120, vai trò khác 70. **PP của item / hệ / passive / skill / thời tiết / chỉ số PP** (khác bản web) tính theo
thanh 100 PP của web: một Pokémon có maxPP 40 nhận 40% số ghi trong mô tả (hệ Water +4 / 8 / 12 mỗi giây → +1,6 / 3,2 / 4,8;
Shiny Charm +50 → +20), hút / cướp PP cũng vậy (`BattleUnit.add_pp` / `drain_pp` / `web_pp`) — giữ đúng phần thanh mà web cho
hiệu ứng; nếu không, khi maxPP giảm các hiệu ứng PP cố định mạnh gấp 2–3 lần (Pokémon Water cầm Aqua Egg cast 50 lần một
trận). Các số của bảng trên (luật) thì giữ nguyên.

| Khoá | `base` | Web | Ý nghĩa |
|---|---|---|---|
| `mana.perSecond` | 0 | 10 | PP hồi mỗi giây |
| `mana.perAttack` | 10 | 5 | PP mỗi đòn đánh thường **trúng** (đòn bị né / bị Protect chặn không có; web: cả đòn trượt) |
| `mana.perHit` | 5 | 0 | PP cộng cố định **một lần** mỗi đòn đánh thường trúng mình, kể cả khi khiên đỡ hết. **Sát thương của skill không tính**; skill cường hoá đòn đánh (Shadow Punch, Teleport, Lock-On, Charge…) và đòn ba của hệ Electric đi qua `attack_hit` nên vẫn tính. Không tính đòn bị chặn hoàn toàn (Protect, Reflect với đòn vật lý…), độc, bỏng, bão cát, sét, phản đòn |
| `mana.perDamage` | 0 | 10 | 1 PP mỗi N sát thương thủng khiên, mọi nguồn (0 = tắt) |

Khoá thiếu → lấy số của web (`Difficulty.WEB_MANA`). Muốn luật web ở một mức (vd `classic`): thêm
`"mana": {"perSecond": 10, "perAttack": 5, "perHit": 0, "perDamage": 10, "roles": {}}` vào mức đó.
Tooltip chỉ số PP đổi theo các số này (`Tooltips.stat_info`: theo vai trò của Pokémon đang xem; không có Pokémon thì gộp các vai
trò cùng luật). Sửa trong tab Độ khó của wave editor: mỗi vai trò một dòng (đòn trúng / bị đánh).

**Người chơi**

| Khoá | `base` | Ý nghĩa |
|---|---|---|
| `startLife`, `startGold` | 100, 5 | máu và vàng đầu run |
| `lifeLossScale` | 1 | máu mất khi thua / hoà = `ceil((ceil(stage / 2) + số địch còn sống) × lifeLossScale)` |
| `goldPerWave` | 5 | vàng cơ bản nhận đầu mỗi stage, chưa tính lãi `min(vàng / 10, 5)` (web: 5) |
| `benchSize` | 8 | số ô hàng chờ, 1–24 (web: 8). Mỗi 8 ô là một hàng trên sàn; từ 9 ô camera lùi ra cho vừa |
| `benchStack` | 2 | số con **giống nhau** một ô chứa được, 1–3 (web: 1). Chỉ hiện con đầu kèm "x2"; con sau không cầm item; đủ 3 bản thì gộp tiến hoá như thường |
| `cheats` | true | bảng cheat trong trận (phím **F1**), xem mục dưới |

**Bảng cheat** (`src/ui/cheat_panel.gd`, hành động là các hàm `Game.cheat_*`): F1 mở / đóng khi `cheats` bật.

| Nhóm | Có gì |
|---|---|
| Người chơi | +10 / +100 vàng, +1 cấp, cấp max, ±20 máu, *Không mất máu* (thua không trừ máu), *Đổi shop miễn phí* |
| Trận / stage | *Thắng trận này* (lúc chuẩn bị thì bắt đầu trận rồi hạ hết địch), *Tới stage N* (như vừa xong stage N−1: thu nhập, sự kiện đầu stage, thị trấn của stage đó, wave mới; chỉ lúc chuẩn bị), *Mở hết additional*, đổi vùng |
| Pokémon | ô tìm (tên, id, hoặc tên hệ gõ đủ: `fire` / `lửa`) → danh sách mọi Pokémon port; nhấp đúp hoặc nút để thêm vào bench (chọn dạng tiến hoá = nhiều sao); *Xoá bench* |
| Item | ô tìm (tên hoặc id) → nhấp đúp / nút để thêm vào kho item |

Cheat không ghi lại gì: tắt `cheats` khi muốn chơi thật.

Tab **Độ khó** của tool có bảng “Wave theo stage” cho mức đang chọn: số con, tỉ lệ 2★ / 3★, số item, hệ số và phần cộng
thẳng HP / ATK ở stage 1 → 100, để thấy ngay hệ quả của một thay đổi.

---

## 2. Wave địch kích hệ và cầm item

- **Đếm hệ** như đội người chơi (`Synergies.count`): mỗi **họ** trong wave tính một lần cho mỗi hệ; Dragon kích thì hệ thứ hai của
  họ Dragon tính đôi; hệ do item cho (đá hệ) cũng tính; Protean (Arceus) nhận hệ mạnh nhất của wave. Sau đó cộng
  `bonusSynergies` của template và `synergyBonus` của độ khó. Code: `EndlessWaves.team_units()` / `synergy_counts()`.
- **Hiệu ứng trong trận** dùng chung code với người chơi (`SynergyEffects`, `BattleSim.team_tiers[RED]`): buff chỉ số, Bug nhân
  bản, Ghost nguyền đội người chơi, sóng thần Aquatic, Fossil, Flying bay đi...
- Phần phụ thuộc bối cảnh sàn của người chơi được thay bằng quy ước cho wave (`FightSetup.enemy_info`):
  - **Light**: ô sáng là ô của con đầu tiên trong wave (con đầu đàn).
  - **Ground**: mọi con Ground của wave đứng trong hố sâu `1 + stage / 6` (tối đa 5); không có thưởng “đào hết hàng”.
  - **Fairy**: mỗi mốc một đũa phép, cố định theo stage (`EndlessWaves.wands`).
  - **Dragon**: tổng sao Dragon của wave.
- Hệ chỉ có tác dụng **giữa các stage** (trứng Baby, cần câu Water, TM Human, món ăn Gourmet, chậu hoa Flora, công cụ
  Artificial, quả mọng Grass...) không làm gì cho wave; phần hiệu ứng trong trận của chúng vẫn chạy (Grass hồi máu, Water +PP...).
- **Thời tiết**: wave vẫn bỏ phiếu như trước (việc này có từ bản web).
- **Item**: bầy hoang dã cầm item theo `firstItemStage` / `stagesPerItem` / `fullItemsStage`; boss cầm `marowakItems` khi
  `bossItems` bật (khi đó gặp Marowak không thay đổi gì thêm); template tự quy định item từng slot.
- **Giao diện**: thanh stage hiện icon + số điểm (đỏ) của các hệ wave đang kích, hover từng icon để xem mốc; hover “Stage N” /
  tên wave để xem mức độ khó, hệ của địch, số item đang cầm và mọi thay đổi chỉ số của wave sắp gặp.

---

## 3. Template wave

Một template là công thức dựng wave thay cho bầy hoang dã ngẫu nhiên. File `data/wave_templates.json`:

```
wildWeight   trọng số của bầy hoang dã mặc định khi bốc thăm (0 = hễ có template hợp là dùng template)
templates    danh sách template
```

### 3.1 Khi nào một template được dùng

Với mỗi stage (theo seed của run, nên cùng seed + stage luôn ra cùng wave):

1. Lọc template **hợp**: `enabled`, có slot, stage trong `stages [đầu, cuối]` (cuối 0 = không giới hạn), nếu `every` > 0 thì
   `(stage − đầu)` chia hết cho `every`, và `levels` rỗng hoặc chứa mức độ khó đang chơi.
2. Stage **boss** (1, 2, 3, 9, 14, 19, 24, 28, 32, 36, 40 và boss quay lại): chỉ template có `replaceBoss` được xét, và nó thay boss.
3. Có template `always` → chỉ bốc trong số đó. Không thì bốc thăm theo `weight` giữa các template hợp và bầy hoang dã
   (`wildWeight`). Ví dụ `wildWeight` 10 và hai template hợp cùng `weight` 2 → mỗi template 2/14, bầy hoang dã 10/14.
4. Template không dựng được con nào (không Pokémon nào hợp slot) → dùng wave mặc định.

Muốn một wave cố định ở đúng một stage: `stages [N, N]` + `always` (+ `replaceBoss` nếu N là stage boss).

### 3.2 Trường của template

| Trường | Mặc định | Ý nghĩa |
|---|---|---|
| `id` | | định danh, không trùng |
| `name` | "" | tên hiện trên thanh stage; trống = “Bầy <con đầu> hoang dã”. Dịch được qua `data/i18n/ui.json` |
| `enabled` | true | tắt tạm mà không xoá |
| `stages`, `every` | [1, 0], 0 | xem 3.1 |
| `weight`, `always`, `replaceBoss`, `levels` | 10, false, false, [] | xem 3.1 |
| `slots` | | các nhóm Pokémon, xem 3.3 |
| `stageItems` | false | cộng thêm số item mà bầy hoang dã ở stage đó cầm (ngoài item của slot) |
| `statScale` | {} | nhân chỉ số gốc của cả wave (nhân thêm với `statScale` của độ khó) |
| `statBoosts` | {} | cộng thẳng (cộng thêm vào phần cộng dồn theo stage) |
| `synergies` | auto | `auto` = theo độ khó, `on` = luôn kích hệ, `off` = không bao giờ |
| `bonusSynergies` | {} | `{"FIRE": 2}` = +2 điểm Lửa cho wave |
| `reward` | default | `default` (luật stage), `none`, `component`, `full`, `choice_component`, `choice_full` |

### 3.3 Slot

Mỗi slot sinh `count` con. Tổng tối đa 28 con (7 × 4 ô lục giác phía địch).

| Trường | Mặc định | Ý nghĩa |
|---|---|---|
| `count` | 1 | số con |
| `pkm` | "" | tên Pokémon cố định (vd `CHARIZARD`); trống = ngẫu nhiên theo `types` + `rarity` |
| `types` | [] | con ngẫu nhiên phải có **một trong** các hệ này ([] = hệ nào cũng được) |
| `rarity` | [] | `COMMON`, `UNCOMMON`, `RARE`, `EPIC`, `ULTRA` (dạng đầu của shop + additional), `UNIQUE`, `LEGENDARY` (danh sách đề xuất của portal). [] = bốc độ hiếm theo tỉ lệ shop của stage như bầy hoang dã |
| `stars` | 0 | bậc 1–3★ (tiến hoá dạng đầu lên bậc đó); 0 = theo tỉ lệ 2★ / 3★ của độ khó. Pokémon cố định đã ở bậc cao hơn thì giữ nguyên |
| `items` | [] | item cố định, mỗi con của slot đều cầm |
| `randomItems`, `itemPool` | 0, auto | thêm N item ngẫu nhiên từ `component` / `full`; `auto` = mảnh trước `fullItemsStage`, item ghép sau đó |
| `row` | 0 | 3 = hàng trước (sát người chơi), 2 = giữa, 1 = sau, 0 = theo tầm đánh (cận chiến đứng trước). Hàng đầy thì tràn sang hàng khác, cuối cùng là hàng thứ 4 sau cùng của sàn lục giác |

Con ngẫu nhiên ưu tiên **họ chưa có trong wave**; hết họ mới lặp lại.

### 3.4 Tool (tab Template wave)

- **Trái**: danh sách template (tên, khoảng stage, trọng số) — thêm, nhân bản, xoá, đổi thứ tự; “Trọng số bầy hoang dã”.
- **Giữa**: mọi trường ở 3.2 và các slot ở 3.3. Pokémon và item chọn bằng popup có ô lọc (gõ tên, hệ, độ hiếm). Mỗi slot ngẫu
  nhiên hiện “N Pokémon phù hợp ở stage X” — 0 (đỏ) nghĩa là slot sẽ không sinh con nào ở stage đó.
- **Phải — xem trước**: chọn stage, seed (nút xúc xắc = lần tung khác), độ khó. Lưới 8 × 3 là sàn địch (hàng dưới sát người
  chơi) với chân dung, số sao, item; bên dưới là hệ đang kích / chưa đủ mốc, chỉ số, item, thưởng.
  “Luôn xem template đang chọn” bật: dựng đúng template đang sửa; tắt: xem wave mà game thật sự chọn cho stage + seed đó.
- **Lịch 60 stage**: mỗi stage của seed dùng wave nào (đỏ = boss, vàng = template); bấm một dòng để xem wave đó.
- Góc trên phải báo lỗi dữ liệu (id trùng, Pokémon / item / hệ không tồn tại, slot không có Pokémon hợp) — cùng hàm
  `WaveTemplates.problems()` mà `sim_test` kiểm.

Các template mẫu có sẵn (chỉ dùng ở `normal` / `hard`): Fire raid (stage 6+), Steel wall (10+), Dragon den (15+),
Elite trio (18+), Legend hunt (30+, chỉ `hard`). Xoá hoặc bỏ tích “Bật” nếu không muốn.

---

## 4. Code và test

| File | Vai trò |
|---|---|
| `src/core/difficulty.gd` | `Difficulty`: đọc file, `set_level`, `params()` / `value()`, `endless()` (config web + ghi đè), `enemy_scale(stage)`, `enemy_synergies(stage, boss)` |
| `src/core/wave_templates.gd` | `WaveTemplates`: `pick(stage, seed, boss)`, `build(template, stage, rng)`, `candidates(slot, stage)`, `problems()` |
| `src/core/endless_waves.gd` | `get_stage()` chọn template / boss / bầy hoang dã rồi `_apply_difficulty()` (thêm `stage`, `kind`, `statScale`, `synergies`, `synergyBonus`, item boss); `team_units()`, `synergy_counts()`, `wands()` |
| `src/core/fight_setup.gd` | cho đội đỏ `team_tiers` + `enemy_info()`, `apply_stat_scale()` rồi `apply_stat_boosts()` |
| `src/core/battle_unit.gd` | `apply_stat_scale()` |
| `src/game/game.gd`, `src/ui/hud.gd`, `src/ui/main_menu.gd`, `src/autoload/settings.gd` | máu / vàng đầu run, máu mất, `enemy_text()`, chip hệ của địch, ô chọn độ khó, lưu lựa chọn |
| `tools/wave_editor/` | tool |

- Wave được cache theo (seed, stage); cache tự xoá khi đổi mức (`Difficulty.revision`) hoặc nạp lại template.
- `sim_test` chạy các kiểm tra luật port ở mức `classic` (giống web), rồi `_check_difficulty` kiểm: `classic` không hệ / không
  template, `normal` boss cầm item + đội đỏ có `team_tiers` đúng, hệ số chỉ số, `synergyBonus`, ghi đè `endless`, template (slot cố
  định / ngẫu nhiên, item, hàng, stage, `replaceBoss`), file template không lỗi, tool ghi JSON không đổi nội dung.
- Chạy test / game ở một mức mà không đổi cài đặt: thêm `-- difficulty=hard` vào dòng lệnh.
  Ảnh kiểm tra: `screenshot.tscn -- <dir> difficulty difficulty=hard`, `wave_editor.tscn -- shot <dir>`.
- Bot của `soak_test` (mua bừa): chết quanh stage 18–19 ở `classic`, 16 ở `normal`, 11–13 ở `hard` (2026-09-30) — chỉ để so
  tương đối giữa các mức, không phải thước đo cho người chơi.
