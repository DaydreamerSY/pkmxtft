# Port pokemonAutoChess (web) → Godot 4.7

Bản port tập trung vào **Endless offline, chơi một mình** (multiplayer không port, xem cuối file).
Item của chế độ Endless (Phase 3); hiệu ứng synergy, trạng thái, weather, passive (Phase 4); sự kiện thị trấn
giữa stage: portal, Pokémon khởi đầu / Unique / Legendary, carousel, additional pick, town encounter (Phase 5);
chọn ngôn ngữ (Phase 6); âm thanh, hiệu ứng hình ảnh, DPS meter, xem trước stage (Phase 7).

Luồng màn hình: `Main Menu (Play)` → `Game` (planning ↔ fight, stage nối stage) → hết máu →
popup `GAME OVER` → `Main Menu`.

## Chạy

- Mở project bằng Godot 4.7, F5 (main scene: `scenes/main_menu.tscn`).
- Khi export bản build: thêm `*.json` vào *Filters to export non-resource files* (dữ liệu và atlas được đọc bằng `FileAccess`), bỏ thư mục `tests/`.
- Phím trong game: kéo thả chuột trái (bench ↔ sàn, thả lên shop để bán, kéo item từ kho item lên Pokémon),
  chuột phải = xem chi tiết Pokémon / công thức ghép của item, `Space` = đánh ngay, `D` = refresh shop,
  `F` = mua XP, lăn chuột = zoom, `Esc` = đóng chi tiết và tooltip.

## Cấu trúc

```
data/abilities.json        skill đã port (dữ liệu, xem docs/ABILITIES.md)
data/ability_vfx.json      hiệu ứng hình ảnh của từng skill (viết tay, chuyển từ abilities-animations.ts)
data/i18n/ui.json          chữ giao diện: {"English": {"vi": "..."}} (viết tay)
data/i18n/<code>.json      chữ game viết cho bản port, đè lên bản dịch web (vi.json: tiếng Việt đầy đủ)
data/pac/*.json            SINH TỰ ĐỘNG từ bản web — đừng sửa tay (data/pac/lang/<code>.json = bản dịch web)
assets/pokemons/           atlas sprite PMD (png + json đã lọc) — sinh tự động
assets/portraits/          chân dung — sinh tự động
assets/items, types, icons icon item / hệ / chỉ số / UI — sinh tự động
assets/vfx/                sheet animation skill / đòn đánh / trạng thái + vfx.json — sinh tự động
assets/sounds, music       âm thanh (20) và nhạc vùng / thị trấn / menu (~280 MB) — sinh tự động
src/autoload/game_data.gd  autoload GameData: đọc toàn bộ dữ liệu, chữ theo ngôn ngữ
src/autoload/settings.gd   autoload Settings: ngôn ngữ, âm lượng (user://settings.cfg)
src/autoload/audio.gd      autoload Audio: nhạc (cross-fade), âm thanh, tiếng nút
src/core/                  logic thuần (không có node): board, unit, simulation, skill, wave, người chơi,
                           synergy (Synergies, SynergyEffects), passive (PassiveEffects), Weather, FightSetup
src/view/                  3D: camera TFT, sàn đấu, sprite Pokémon, shader, VFX (VfxLibrary, VfxPlayer)
src/ui/                    HUD, shop, kho item, synergy, panel chi tiết, tooltip, main menu
src/game/game.gd           điều phối: pha, kéo thả, nối simulation → hình ảnh
scenes/                    main_menu.tscn, game.tscn
tests/                     test headless (logic, luồng màn hình) + chụp màn hình
tools/export_pac.bat       export lại dữ liệu/sprite từ bản web
```

`src/core` là bản port của `app/core` (board.ts, simulation.ts, pokemon-state.ts,
moving/attacking-state.ts), `app/models/endless-stages.ts` và luật shop/level/income
của `app/config/game`. Công thức giữ nguyên: tốc đánh `1000/(0.4+0.007·speed)` ms,
bước đi `500/(0.5+speed/100)` ms, giáp `dmg/(1+0.05·def)`, +5 PP mỗi đòn, +10 PP/giây,
nhận `ceil(dmg/10)` PP khi bị đánh, trận tối đa 45 s, thua mất `ceil(stage/2) + số địch còn sống`.

## Pipeline dữ liệu

`tools/export_pac.bat` gọi `pokemonAutoChess/offline/godot-export.ts` (chạy bằng tsx + Node portable):

- `pokemon.json`: toàn bộ 1183 Pokémon (stats, hệ, passive, tiến hoá + `evolutions` của tiến hoá rẽ nhánh, skill, animation attack/ability).
- `pve_stages.json`, `config.json` (tỉ lệ shop, giá, pool, bảng XP, ngưỡng synergy, hiệu ứng từng mốc `synergyTiers`,
  các con số synergy `synergyValues`, wand của Fairy, ngưỡng weather, stage additional pick, tham số endless), `delays.json`.
- `pool.json`: các họ tiến hoá kiểu COUNT (3 con → 1) mà **mọi skill đều có trong `data/abilities.json`**
  (tiến hoá rẽ nhánh: giữ các nhánh có skill). `pool` = shop, `additional` = họ additional pick (vào shop ở
  stage 5 / 8 / 11), `bosses` = boss PvE, `extras` = dạng chỉ gặp trong trận / do passive (Pillar, Darmanitan Zen,
  Aegislash Blade, Lycanroc, Ursaluna Bloodmoon). Hiện 273 Pokémon shop + 18 additional / 118 skill.
- `items.json`: 8 mảnh ghép (không có Fossil Stone / Silk Scarf) + 36 item ghép từ chúng: tên, mô tả, chỉ số (`ItemStats`), công thức.
- `text.json`: chữ tiếng Anh của bản web cho tooltip (tên + mô tả synergy và từng mốc, chỉ số, trạng thái, thuật ngữ,
  mô tả passive, tên + mô tả weather...).
- `pve_stages.json` có thêm `items` (item boss cầm, chỉ giữ item đã port) và `reward` (`pool` component/full, `choice` = chọn 1 trong 3).
- Sprite: chỉ frame `Normal/*/Anim`, kèm thời lượng frame (tick 1/36 s) và **điểm chân** lấy từ layer
  Shadow của PMD (để chân Pokémon đặt đúng tâm ô).

Thêm Pokémon mới = thêm skill của nó vào `data/abilities.json` rồi chạy lại `tools/export_pac.bat`.

Thêm (Phase 5-7): `pool.json` có `unique`, `legendary` (họ đề xuất ở stage 10 / 20); `config.json` có stage portal / carousel,
town encounter theo stage, `maps` (synergy + nhạc của từng vùng); `pokemon.json` có `evolutionItems` (Primal Kyogre...) và
`anim.attackSprite` / `anim.hitSprite`; `text.json` có tên Pokémon, map, skill, lựa chọn; `lang/<code>.json` + `languages.json`
(bản dịch web, 14 ngôn ngữ); `assets/vfx` (animation dùng trong `data/ability_vfx.json` + mọi đòn đánh + mọi trạng thái,
mỗi animation một sheet lưới dựng lại từ frame gốc bằng pngjs); `assets/sounds`, `assets/music` (`--no-music` để bỏ qua nhạc).

---

## Phase 1

### Camera kiểu TFT — `scenes/game.tscn` › `TftCamera`

Script `@tool`: chỉnh trong Inspector là viewport editor cập nhật ngay (bấm *Preview* của camera để nhìn qua nó).
Camera quay quanh `focus_point` trên mặt đất.

| Export | Mặc định | Ý nghĩa |
|---|---|---|
| `focus_point` | (0, 0, 0.75) | điểm nhìn trên sàn; z dương = lệch về phía người chơi/bench |
| `pitch_degrees` | 55° | góc cúi; 90 = nhìn thẳng từ trên, TFT ≈ 50–60 |
| `yaw_degrees` | 0° | xoay quanh sàn |
| `distance` | 13.6 | khoảng cách tới `focus_point` (zoom = 1) |
| `field_of_view` | 38° | FOV dọc; nhỏ hơn = phối cảnh "dẹt" hơn (TFT dùng FOV hẹp) |
| `screen_offset` | (0, -0.95) | dịch khung hình mà không đổi góc (chừa chỗ cho shop) |
| `use_orthographic`, `orthographic_size` | tắt | so sánh với phép chiếu trực giao |
| Zoom: `zoom_enabled`, `zoom_min`, `zoom_max`, `zoom_step`, `zoom_smoothing`, `zoom_pitch_bonus` | 0.8 – 1.15 | lăn chuột; `zoom_pitch_bonus` > 0 để cúi thêm khi zoom gần |
| Pan: `pan_enabled`, `pan_limit`, `pan_speed` | tắt | kéo chuột giữa (TFT không pan) |
| Shake: `shake_strength`, `shake_duration` | 0.06 / 0.25 s | rung khi skill lớn / thua |

Tỉ lệ: **1 ô = 1 đơn vị** (bề ngang một ô lục giác), sàn 7 × 8 ô lục giác (7,5 × 7,2 đơn vị) đặt ở gốc toạ độ, phía người
chơi hướng +Z (dưới màn hình).

### Phong cách: asset 2D trên nền 2D giả 3D

Chọn cách của Don't Starve / Arknights: **thế giới là 3D thật nhưng mọi thứ đều là hình 2D**.

- **Sàn** (`Arena`, `src/view/shaders/board.gdshader`, `ground.gdshader`): các mặt phẳng phẳng tô bằng shader
  "vẽ tay" (sân đất sét có Poké Ball vẽ ở giữa, viền ô mảnh, cỏ/đất quanh sàn), nhìn qua camera phối cảnh nên ra cảm giác 3D.
  Khối đế sàn có độ dày (`platform_thickness`) và bóng tiếp đất quanh sàn.
- `pixel_density` (Arena, mặc định 27 px/ô ≈ 48 / `sprite_scale`) làm sàn "pixel-art" cùng mật độ điểm ảnh với sprite PMD.
  Đặt 0 để sàn mịn.
- Màu: `stone_light/dark`, `player_tint`, `enemy_tint`, `side_tint`, `bench_color`, `rim_color`, `grass_a/b`…
- Viền ô: `grid_strength` (độ đậm, 0,22), `grid_width` (ô, tối thiểu 1 pixel sàn). Poké Ball: `ball_radius` (ô), `ball_strength`,
  `ball_red/white/black`, vạch trắng `field_line_color/strength`. Có file `assets/arena/pokeball.png` (ảnh tròn nền trong
  suốt) thì sàn vẽ ảnh đó thay quả bóng tự vẽ (`Arena.BALL_IMAGE`, `ball_texture`).
- `ground_texture` + `ground_texture_rect`: thay nền cỏ bằng một bức vẽ bất kỳ (ví dụ ảnh arena).
- **Pokémon** (`UnitView`): `AnimatedSprite3D` billboard, 8 hướng PMD, không dùng depth test và sắp xếp
  xa→gần nên sprite không bao giờ bị sàn cắt chân và con đứng gần luôn che con đứng xa. Bóng tròn vẽ trên ô.
  - `Game.sprite_scale` (1.8): độ to sprite (1.0 = đúng tỉ lệ bản web: 48 px sprite / ô).
  - `Game.sprite_billboard`: `Enabled` = luôn quay mặt về camera (Don't Starve), `Y-Billboard` = đứng thẳng (kiểu Arknights).
  - **Animation** (`UnitView.play` / `attack`, 2026-11-20): đòn đánh thường kéo dài đúng thời gian hồi đòn
    (`getAttackAnimTimeScale` của `animation-manager.ts`: tốc độ = số tick của animation / 36 / cooldown; số tick bằng
    `t` của `delays.json`), nên frame đánh trúng khớp `hit_delay` của sim. Mọi animation nhân `UnitView.time_scale`
    (= tốc độ tua của trận, Game đặt mỗi frame). Animation một lần hoặc bước đi vừa hết thì giữ frame cuối `IDLE_GRACE`
    (0,1 s) rồi mới về Idle, để đòn / bước kế tiếp (tới theo frame vật lý) nối liền. Khác web: web cho animation đánh lặp
    lại theo trạng thái ATTACK của server; port bắt đầu lại ở mỗi đòn.
  - **Chuyển động vẽ thêm** (không có ở web, `UnitView._animate_body`): lò xo tắt dần tới hạn, tính chính xác nên ổn ở mọi
    fps và mọi tốc độ tua.
    - Đòn đánh: lunge của đòn cận chiến (xa nhất lúc trúng), lùi khi bắn (lúc đạn rời đi: `min(250 ms, hit_delay)` trước
      khi trúng, như `VfxPlayer.attack`).
    - Trúng đòn: bị đẩy khỏi kẻ đánh + bẹp. Event `damage` có cờ `attack` / `ability`; sát thương khác (bỏng, độc...) chỉ
      bẹp nhẹ, không đẩy.
    - Thở khi đứng, nảy mỗi nửa ô khi đi, giãn khi bay (dash / knockback) và bẹp khi đáp.
    - Phóng to khi xuất hiện (`pop_in`), lún khi ngất.

    Chỉ sprite (và bóng, theo chiều ngang) dịch chuyển: node vẫn ở ô của sim, thanh máu / VFX neo theo node.
  - **Lọc pixel** (`shaders/sprite_pixel_aa.gdshader`, `UnitView.smooth_pixels`): "sharp bilinear" thay NEAREST. Mỗi texel
    vẫn là ô vuông sắc, chỉ pixel màn hình nằm trên mép texel được trộn, nên sprite di chuyển / co giãn ở tỉ lệ lẻ không
    nhấp nháy.
    - Shader là `material_override` chép lại material 2D-trong-3D của `SpriteBase3D` (billboard giữ scale, modulate từ màu
      đỉnh đổi sRGB → linear).
    - `SpriteBase3D` không đưa texture cho override, nên `UnitView._sync_sheet()` đặt `texture_albedo` = sheet của Pokémon.
    - Các frame trong sheet luôn cách nhau ≥ 1 px trong suốt, nên lọc tuyến tính không lem sang frame bên cạnh.
- Thanh máu/PP, sao, số damage là UI 2D bám theo vị trí 3D (`UnitOverlay`).

### Bố cục sàn: lưới lục giác (2026-11-20)

```
          x:  0   1   2   3   4   5   6
 y=7       ⬡   ⬡   ⬡   ⬡   ⬡   ⬡   ⬡      địch — hàng sau (hàng thứ 4)
 y=6     ⬡   ⬡   ⬡   ⬡   ⬡   ⬡   ⬡
 y=5       ⬡   ⬡   ⬡   ⬡   ⬡   ⬡   ⬡
 y=4     ⬡   ⬡   ⬡   ⬡   ⬡   ⬡   ⬡        địch — hàng đầu
 y=3       ⬡   ⬡   ⬡   ⬡   ⬡   ⬡   ⬡  ← vạch giữa; bạn — hàng đầu
 y=2     ⬡   ⬡   ⬡   ⬡   ⬡   ⬡   ⬡
 y=1       ⬡   ⬡   ⬡   ⬡   ⬡   ⬡   ⬡
 y=0     ⬡   ⬡   ⬡   ⬡   ⬡   ⬡   ⬡        bạn — hàng sau
         ( khoảng trống bench_gap )
bench  [ 0   1   2   3   4   5   6   7 ]   8 ô vuông trải đúng bề ngang sàn
```

#### Lưới lục giác

Người chơi đổi sàn sang lục giác kiểu TFT (web: 8 × 6 ô vuông): **7 cột × 8 hàng**, ô đỉnh nhọn, hàng lẻ lệch nửa ô sang
phải ("odd-r"), mỗi phía 4 hàng (`BattleBoard.SIDE_ROWS`). Ô vẫn là `Vector2i(cột, hàng)` ở mọi nơi (sàn của người chơi,
wave, sự kiện); hình học đi qua toạ độ axial (`to_axial` / `from_axial`), nơi 6 hướng là offset cố định:

| Web (ô vuông) | Bản Godot (lục giác) |
|---|---|
| khoảng cách Chebyshev (tầm đánh), Manhattan (tìm gần / xa) | cùng một khoảng cách lục giác (`distance`; `distance_c` / `distance_m` giữ tên, trả số bước) |
| `getAdjacentCells`: 8 ô | 6 ô kề |
| `getCellsInRange(r)`: hình vuông | hình lục giác bán kính r (tầm 2 = 18 ô quanh) |
| `getCellsInRadius(r)`: đĩa dx² + dy² < (r + ½)² | như trên (lục giác đã tròn) |
| 8 hướng `Orientation` | 6 hướng (`DIRECTIONS`: phải, trước-phải, trước-trái, trái, sau-trái, sau-phải); `orientation(a, b)` = hướng gần góc thật nhất, hướng thẳng trước / sau (giữa hai hướng) lệch vào giữa sàn |
| "hướng và 2 hướng lệch 45°" (nón `getCellsInFront`, `getKnockBackPlace`, Water Shuriken, Frost Breath, Hydro Steam, Zing Zap...) | hướng và 2 hướng lệch 60° (`fan`) |
| `getCellsBetween` (đường thẳng phủ ô) | đường thẳng lục giác (`cells_between`: lerp toạ độ cube, mỗi bước một ô; dọc mép ô thì lấy một bên, bên kia nếu ra ngoài sàn) |
| `effectInLine` (góc thật tới mép) | góc thật qua `center()` / `cell_at()` |
| đường đi 8 hướng, chéo √2 | 6 ô kề, mỗi bước 1 |
| `getClosestFreeCellTo` (danh sách offset) | `BattleSim.near_order()`: theo khoảng cách, cùng hàng → về phía mình → phía trước, gần ngang trước, trái trước |

Skill có hình riêng: Fire Blast (ngôi sao 6 ô) → ô đích + 6 ô kề; Toxic Spikes (3 × 2 ô) → 2 hàng trước, ô lệch ngang
≤ 1 ô (2 + 3 ô); Magnet Bomb hút từ vòng 2 ô (mỗi ô kề nhận 1 trong 2 ô phía sau nó); Plasma Fission tách 2 tia vuông góc
theo góc thật; Smoke Screen lấy hàng sâu nhất trong 4 hàng; Hail / Sacred Sword Cavern / Skarmory dùng 4 hàng mỗi phía.

Wave địch (EndlessWaves): toạ độ wave `y` 3 = hàng đầu, 2 = giữa, 1 = sau (như 3 hàng web), 0 = hàng thứ 4 (chỉ dùng khi
3 hàng kia đầy), `to_sim_cell(x, y) = (x, 7 − y)`; cột từ giữa ra `[3, 2, 4, 1, 5, 0, 6]`, tối đa 28 con. Bàn boss của web
(x 0..7) được ép về 7 cột lúc nạp (`GameData.fit_wave_board`: x × 6 / 7, trùng ô thì sang ô trống gần nhất cùng hàng).
Người chơi tự xếp (`auto_place`, `run_rules`): cận chiến hàng 3 → 0, tầm 2 hàng 2, xa hàng 0. Bench 8 ô vuông trải đúng
bề ngang sàn (`Arena.BENCH_SLOT` = 0,9375 ô).

HUD theo layout TFT (xem `board-layout/tft-vs-pac.png` bên project web): thanh stage + đồng hồ (trên),
synergy (trái), máu/level/menu (phải), shop 6 ô + Refresh/Buy XP/Lock + vàng (dưới), panel chi tiết (phải giữa).
Bố cục chi tiết theo breakdown TFT: xem Phase 3.

---

## Phase 2

### Quan hệ Pokémon ↔ ô

1. **Một Pokémon luôn chiếm đúng một ô**, dù sprite to hay nhỏ. Kích thước sprite chỉ là hình ảnh; một sprite
   to có thể tràn sang ô bên cạnh nhưng không chiếm ô đó.
2. Gốc của Pokémon = **tâm ô**; chân (điểm bóng PMD) đặt đúng tâm ô, bóng tròn vẽ trên chính ô đó.
3. **Ô được giữ chỗ ngay khi bắt đầu đi**: khi di chuyển, ô đích thuộc về Pokémon ngay lập tức (giống bản web),
   sprite chỉ trượt tới trong thời gian bước đi. Vì vậy trong trận, ô tô màu (xanh = bạn, đỏ = địch) là ô *logic*
   mà Pokémon đang giữ — có thể đi trước sprite một chút.
4. Tầm đánh tính theo ô, khoảng cách lục giác: range 1 = 6 ô xung quanh, range 2 = 18 ô… (web: Chebyshev, hình vuông).
   Tìm địch gần nhất/xa nhất cũng theo khoảng cách lục giác (web: Manhattan), đường đi qua 6 ô kề, Pokémon khác là vật cản.
5. Bench: 8 ô, Pokémon trên bench không đánh. Người chơi chỉ đặt được ở 4 hàng y = 0..3, tối đa = level.

Hiển thị: `Game.show_occupied_cells` (tô ô đang chiếm), `show_team_rings` (vòng team dưới chân),
di chuột lên Pokémon → viền trắng ô của nó; chuột phải → tô tầm đánh trên sàn, ô `(x, y)` ghi trong tooltip của ô tầm đánh ở panel.

### Ô bị ảnh hưởng bởi skill

Mỗi skill là dữ liệu (`data/abilities.json`), gồm các bước; mỗi bước có một **vùng ô** (`area`):

| area | Các ô | Ví dụ |
|---|---|---|
| `single` | ô của mục tiêu | Thunder Shock, Bite |
| `adjacent` (origin caster) | 8 ô quanh mình | Blast Burn, Heavy Slam, Growl |
| `adjacent` (origin focus, center) | mục tiêu + 8 ô quanh | Icicle Crash, Psychic, Flower Trick |
| `radius` N | hình tròn bán kính N (`dx²+dy² < (N+0.5)²`) | Shockwave (2), Blizzard (4), Salt Cure |
| `square` N | hình vuông = tầm đánh | Uproar (caster: tầm 5) |
| `cone` N | hình nón N ô về phía mục tiêu | Stealth Rocks |
| `ray` N | đường thẳng 8 hướng về phía mục tiêu, tối đa N ô | Flamethrower (3), Dragon Breath (range+1) |
| `line` | đường thẳng qua mục tiêu tới mép sàn (góc thật) | Hydro Pump, Icy Wind |
| `between` | các ô giữa mình và mục tiêu/địch xa nhất | Snipe Shot, Magical Leaf, Whirlpool |
| `path` | các ô trên đường lướt | Volt Switch, Glaive Rush, Firestarter |
| `row` | cả hàng của mục tiêu | Spacial Rend |
| `board` | cả sàn | Soft-Boiled, Nightmare |
| `closest` / `backline` N | N địch gần nhất / xa phía sau nhất | Tickle, Future Sight / Sing |
| `random` N | N phát ngẫu nhiên (có `scatter` = rơi vào 3×3 quanh địch) | Rock Artillery, Hail |

Cùng một hàm `AbilityRunner.step_cells()` được dùng cho: trận đấu, hiệu ứng nháy ô, và sơ đồ trong panel chi tiết —
nên ô hiển thị luôn đúng là ô bị ảnh hưởng.

- **Trong trận**: ô bị đánh nháy **cam** (lên địch), **xanh lá** (lên đồng minh); skill có độ trễ (Flower Trick,
  Future Sight…) nháy **hồng** liên tục tới lúc nổ.
- **Tooltip skill** (hover ô skill của panel chi tiết hoặc thẻ shop): dòng "Cells: …" mô tả vùng bằng lời + sơ đồ lục giác 7×8 mô phỏng trên một đội hình mẫu
  (vòng xanh = Pokémon, chấm đỏ = địch, tâm ngắm = mục tiêu, cam = ô trúng, xanh lá = đồng minh, viền vàng = tầm đánh,
  vòng nét đứt = vị trí trước khi lướt).

### Kéo Pokémon: highlight tầm đánh

Khi kéo: các ô thả được sáng nhẹ, ô đang trỏ **xanh lá** (thả được) / **đỏ** (không được, ví dụ đủ quân),
và **các ô trong tầm đánh tính từ ô đang trỏ tô vàng** (kể cả ô bên địch) — `Game.show_drag_range`.
Kéo lên shop → shop đổi thành "Sell for Xg".

---

## Phase 3 — UI theo `screenshot example/TFT-UI-breakdown.drawio` + item

### Bố cục (TFT)

| Vị trí | Thành phần | File |
|---|---|---|
| Mép trái | kho item (10 ô) | `src/ui/item_bench.gd` |
| Trái | danh sách synergy của sàn: badge hệ (màu theo mốc), số lượng, tên, các mốc `2 > 4 > 6` | `src/ui/synergy_list.gd` |
| Phải giữa | panel chi tiết Pokémon (chuột phải) | `src/ui/unit_info_panel.gd` |
| Dưới | shop: dải trên (level + XP, tỉ lệ độ hiếm, vàng ở giữa, nút khoá), Buy XP / Refresh, 6 thẻ | `src/ui/shop_bar.gd` |
| Góc dưới phải | nút **Fight!** | `src/ui/hud.gd` |
| Trên giữa | popup "Choose an item" (phần thưởng chọn 1 trong 3) | `src/ui/item_choice.gd` |

Tooltip (`src/ui/hover_tip.gd`) mở **cạnh** phần tử được hover như TFT (không theo chuột), có nhiều tầng:
tooltip có thể chứa phần tử có tooltip riêng. Nội dung ở `src/ui/tooltips.gd`, chữ mô tả của bản web được
đổi sang BBCode có icon/màu bởi `src/ui/game_text.gd` (SPECIAL → "special damage", ATK → icon + "Attack", `[30,LK]` → 30...).

| Màn trong breakdown | Cách làm |
|---|---|
| mouse_hover: fraction | hover một synergy bên trái → mô tả, các mốc (mốc đạt được sáng), lưới Pokémon có hệ đó (đang sở hữu = sáng); hover một Pokémon trong lưới → tên, giá, hệ, vai trò |
| drag_drop: sell zone | kéo Pokémon lên shop → cả thanh shop thành "Sell for X gold" |
| right_click: on_character | panel phải: sao (còn tiến hoá = sao rỗng), chân dung + hệ, tên + giá bán, thanh HP / PP, ô skill / vị trí gợi ý / tầm đánh, 3 ô item, vai trò, 9 chỉ số. Trong trận số liệu chạy trực tiếp |
| mouse_hover: character's fraction information | hover hệ trong panel → tooltip synergy |
| mouse_hover: character's skill information | hover ô skill (icon = sơ đồ ô của skill) → tên, PP, mô tả, "Cells", sơ đồ lục giác của Phase 2 |
| mouse_hover: (item trong panel) | hover ô item → tooltip item; chuột phải → công thức |
| mouse_hover: character's stats information | hover chỉ số → ý nghĩa, giá trị hiện tại (gốc + cộng thêm) |
| mouse_hover: suggest_item | hover chip vai trò → mô tả, vị trí nên đặt, 8 item gợi ý kèm công thức (hover từng item) |
| mouse_hover: buy_character_info | hover thẻ shop → tooltip skill phía trên thẻ |
| mouse_hover: item_infomation | hover item trong kho → tên, chỉ số, mô tả, công thức |
| right_click: on_item | bảng công thức ghim lại: `+ mảnh > item` cho mọi mảnh còn lại (item ghép: "Made from A + B"); đóng khi click ra ngoài / Esc / chuột phải lần nữa |
| mouse_hover: upper tier item's information | hover một dòng trong bảng công thức → tooltip item ghép |
| mouse_hover: lock_shop | hover nút khoá → giải thích |

Item đang cầm hiện dưới thanh máu (như TFT), cả của địch.

### Vai trò ("type of character")

PAC không có vai trò kiểu TFT nên `src/core/unit_roles.gd` suy ra từ dữ liệu: support (skill chỉ giúp đồng minh),
caster / marksman (tầm ≥ 2, skill có / không gây damage), assassin (cận chiến có dash), tank (cận chiến,
DEF + SPE_DEF ≥ 10 hoặc HP ≥ 80 và ≥ 8, hoặc tự tạo khiên — tính trên dạng đầu của họ), còn lại fighter.
Vai trò quyết định vị trí gợi ý (tank / fighter / assassin: hàng trước) và 8 item gợi ý.
**Khác bản web** (2026-11-20, người dùng): caster / marksman có tầm đánh ít nhất 5 (`UnitRoles.ROLES` `"range"`), ghi vào
`GameData.pokemon` lúc nạp (`_apply_role_ranges`; tầm web: `GameData.web_stat(pkm, "range")`, vai trò suy từ tầm web).

### Item (port của `app/core/effects/items.ts` và các chỗ kiểm tra item trong pokemon-state / simulation)

- Kho item: phần thưởng + item của Pokémon bị bán. Kéo item lên Pokémon của mình (lúc planning: mọi con;
  trong trận: chỉ con trên bench). Luật như `OnDragDropItemCommand`: mảnh + mảnh = item ghép, tối đa 3 item,
  không cầm 2 item ghép giống nhau (item ghép trùng khi ghép sẽ rơi về kho). Khi kéo: ô xanh/đỏ + chữ "Equip" / "Combine: X" / lý do.
- 3 con gộp thành 1: con tiến hoá nhận item ghép trước, tối đa 1 mảnh, tối đa 3 item; phần dư về kho.
- Phần thưởng (thắng mới có): stage PvE gốc theo `reward` (1, 3, 9, 19: mảnh ngẫu nhiên; 2, 14: chọn 1 trong 3 mảnh;
  24, 28, 32, 36: chọn 1 trong 3 item ghép; 40: item ghép ngẫu nhiên); wave hoang dã: cứ 3 stage một item, mảnh trước stage 20, item ghép từ stage 20.
- Địch cầm item: boss PvE theo dữ liệu gốc; wave hoang dã từ stage 8 (mảnh), stage 14 (item ghép), thêm 1 item mỗi 2 stage, con nhiều sao nhất trước.
- Trong trận: `BattleUnit.equip()` cộng chỉ số, `src/core/item_effects.gd` chạy hiệu ứng (lúc bắt đầu, mỗi giây,
  sau đòn đánh, khi trúng, khi nhận / gây damage, khi dùng skill). Poke Doll, Protective Pads, Shiny Charm, Power Lens,
  Rocky Helmet, Red Orb, Punching Glove, X-Ray, Max Revive, Assault Vest nằm trong `BattleSim.deal_damage` / đòn đánh.
  Trạng thái mới: `wound` (không hồi máu), `blinded` (50% đánh trượt), `safeguard` (miễn trạng thái xấu).
- Wonder Box: đầu mỗi trận đổi thành 2 item ghép ngẫu nhiên (chỉ trong trận đó).
- Chưa port: Fossil Stone / Silk Scarf và các item đặc biệt (Red Scale, Rare Candy, Dynamax Band...); boss cầm
  item chưa port thì bỏ qua, phần thưởng item đặc biệt đổi thành item ghép.

---

## Phase 4 — synergy, trạng thái, weather, passive

Trận đấu được dựng bởi `src/core/fight_setup.gd` (`FightSetup.create`, dùng chung cho game và test):
tính weather của hai sàn → đổi dạng theo weather (Lycanroc, Ursaluna) → synergy + bối cảnh sàn của người chơi
(`PlayerState.fight_info()`: ô sáng, hố, wand, số sao Dragon) → tạo unit hai đội. Bản web: wave PvE không có synergy.
**Bản port**: wave có synergy / item / hệ số chỉ số tuỳ mức độ khó (`Difficulty`, `FightSetup.enemy_info`; mức `classic` giữ
đúng bản web) — xem `docs/DIFFICULTY.md`.

### Đếm synergy — `src/core/synergies.gd`

Mỗi họ trên sàn tính 1 lần cho mỗi hệ (bench và Pillar không tính), cộng synergy thưởng (gem đào được).
Khi DRAGON kích hoạt, hệ thứ hai của mỗi họ Dragon tính thêm 1 lần. Mốc = số ngưỡng đạt (`config.synergyThresholds`).
Danh sách synergy bên trái, tooltip và panel đều dùng `Synergies.count_player()`; tooltip có thêm dòng
`Synergies.context_text()` (wand đang dùng, ô sáng, số hố, số sao Dragon, tỉ lệ Wild, phần chưa port).

### Hiệu ứng trong trận — `src/core/synergy_effects.gd`

| Synergy | Đã port |
|---|---|
| Normal | đầu trận: khiên 15/20/25/30 cho mình + đồng minh kề bên |
| Grass | hồi 5/15/25 HP mỗi 2 s; 40% hồi thừa thành max HP |
| Fire | 30% gây BURN 3 s khi đánh trúng; +1/2/3 ATK mỗi đòn (mốc 2-4) |
| Water | +4/8/12 PP mỗi giây |
| Electric | đòn thứ 4 (mốc 1) / thứ 3 đánh 3 lần; mốc 3 đốt 10 PP |
| Fighting | chặn 3/6/9/12 sát thương mỗi đòn; mỗi 10 lần chặn ném kẻ cận chiến ra xa (mất khiên, nhận ATK) |
| Psychic | +50/100/150 AP |
| Dark | +30/40/50% crit, +40/60/100% crit power; Dark cận chiến **nhảy** tới cạnh địch xa nhất thay vì đi bộ (luôn, như web) |
| Steel | +3 DEF cả đội; Steel đánh ra 33/66/100/125% ATK thành sát thương thật |
| Ground | DEF/SPE_DEF theo độ sâu hố đang đứng (1/2/3 mỗi tầng), ATK khi hố sâu 5; mốc 4: +5 mỗi hàng đào hết |
| Poison | 30/60/100% gây POISONED 4 s; tối đa 3/4/5 tầng; mỗi tầng 5% max HP sát thương thật mỗi giây |
| Dragon | hệ thứ hai tính đôi; mốc 2: khiên 5 × tổng sao Dragon; mốc 3: + SPEED/AP bằng tổng sao |
| Field | Field ngã → các Field khác hồi 30/40/50 HP, +15/20/25 SPEED |
| Monster | 30% FLINCH; mỗi lần hạ địch +ATK/AP/max HP; mốc 4 luôn đánh con yếu nhất trong tầm (kể cả đồng minh ≤ 10 HP) |
| Human | hút máu 25/35/50% sát thương gây ra |
| Aquatic | cả đội: trạng thái xấu ngắn hơn 30/50/70%, BURN/POISON giảm như vậy; TIDAL WAVE ở giây 7 (mốc 3: thêm giây 14, mốc 4: mỗi 7 s) xoá hiệu ứng ô, giải trạng thái, hồi Aquatic, đánh và đẩy lùi địch |
| Bug | đầu trận nhân bản 1-4 con Bug mạnh nhất |
| Flying | bay đi khi dưới 20% HP (mốc 3+: dưới 50% rồi 20%), mốc 2+ PROTECT 2 s, mốc 4 bổ nhào 150% ATK |
| Rock | +10/25/50 DEF, crit nhận vào giảm 30/50/70% |
| Ghost | +15% né đòn, 15% SILENCE; đầu trận nguyền địch: Vulnerability (DEF+SPE_DEF cao nhất, FLINCH), Weakness (ATK cao nhất, PARALYSIS), Torment (AP cao nhất, FATIGUE), Fate (mạnh nhất, chết sau 8 s); con bị nguyền chết thì lời nguyền chuyển sang con khác |
| Fairy | wand (chọn 1 trong 3 mỗi mốc) cộng 20% ATK sát thương phép vào đòn đánh + hiệu ứng riêng của 16 wand; mốc 4 +5 LUCK |
| Ice | cả đội +4/12/25/50 SPE_DEF; Ice 20% FREEZE 2 s; mốc 4: địch bị đóng băng nhận +30% |
| Fossil | lần đầu xuống 30% HP: khiên 40/70/100% max HP (chịu tối đa nửa đòn đó) + cùng tỉ lệ BASE ATK |
| Sound | mỗi lần Sound dùng skill: đánh thức cả đội; có synergy thì +ATK/SPEED/PP |
| Artificial | mỗi item đang cầm +5/10% BASE ATK, +5/10 AP, +5/10% max HP khiên (mốc 2-3) |
| Light | con đứng trên ô sáng (random mỗi run, tô vàng trên sàn khi Light kích hoạt): +20% ATK, +20 AP; +8 PP/s; +50% BASE DEF/SPE_DEF + SAFEGUARD 8 s; +100 khiên + hồi sinh |
| Wild | +20/40 SPEED, mốc 3 +40% BASE ATK, mốc 4 dưới 30% HP bùng nổ 3 s + 30 khiên; 25% WOUND; shop: Wild chỉ xuất hiện với tỉ lệ 6% (+0.5%/sao Wild) ở stage PvE gốc hoặc khi Wild kích hoạt |
| Amorphous | cả đội +1/3/5 SPEED và +3/6/10 HP cho mỗi synergy đang kích hoạt |

### Trạng thái và luật chung mới

- `poison` cộng dồn tầng (sát thương thật mỗi giây), `curse` (Curse of Fate), `enraged`, 4 field (+20% sát thương),
  `skydiving`, né đòn (`dodge`, tối đa 90%, blinded +50%), `safeguard` giải trạng thái xấu khi nhận.
- **Enraged ở giây 35** (như web): mọi Pokémon +80 SPEED, gây gấp đôi sát thương, hồi máu/khiên nhận một nửa, mất PROTECT.
- Người gây BURN/POISON được tính sát thương (hút máu, hạ địch).

### Weather — `src/core/weather.gd`

Hai sàn bỏ phiếu: mỗi hệ +1 (GRASS→Zenith, FIRE→Drought, WATER→Rain, GROUND→Sandstorm, FAIRY→Misty, ICE→Snow,
ELECTRIC→Storm, DARK→Night, FLYING→Windy, WILD→Bloodmoon, POISON→Smog, GHOST→Murky, NORMAL→trung tính),
passive thời tiết +100 (Zapdos Storm, Moltres Drought, Articuno Snow, Rayquaza Airlock, Kyogre/Groudon nguyên thuỷ chọn theo synergy).
Cần ≥ 8 điểm và không hoà. Hiệu ứng: tốc độ (Windy/Snow), né (Smog), crit (Night), luck (Murky), PP mỗi giây (Rain/Drought),
BURN/POISON (Rain/Drought), hồi máu (Zenith), sát thương (Misty phép, Bloodmoon vật lý), Sandstorm 5 sát thương/giây,
Storm sét đánh ngẫu nhiên (100 phép, Electric được sạc), thời lượng trạng thái ±30%. Thanh stage hiện weather
(lúc planning là dự báo theo sàn hiện tại + wave), hover để xem hiệu ứng.

### Passive — `src/core/passive_effects.gd` + `PlayerState`

Panel chi tiết hiện dòng **Passive** (mô tả bản web). Đã port cho mọi Pokémon trong pool/boss:
Gears (Klink), Pickup (Zigzagoon), Slow Start (Regigigas), Aegislash (đổi Shield/Blade khi dùng King's Shield),
Darmanitan (Zen mode dưới 30% HP, Transe quay lại), Mitosis (Duosion/Reuniclus tách đôi), Synchro (Mew),
Well Baked (Fidough), Gale Wings (để lại EMBER trên đường bay), Drummer (Grookey đánh trống cho đồng minh kề bên),
Stoutland (sủa khi đứng trên ô có đồ chôn), Fur Coat (Wooloo: +2 DEF −5 SPEED mỗi stage trên sàn, về bench thì tỉa lông),
Pillar (Timburr xây 1/1/2 cột — không tính vào số quân, không bán được), weather passive, và **tiến hoá rẽ nhánh**:
Poliwhirl (hàng đầu → Poliwrath, không thì Politoed), Espurr (Psychic/Field → Meowstic Male/Female),
Kirlia (Fighting/Fairy → Gallade/Gardevoir), Wurmple (có Poison → Cascoon, không thì Silcoon), Flabébé (giữ màu; mỗi run
chỉ gặp 1 màu trong shop), Lycanroc/Ursaluna đổi dạng theo weather. Conversion (Porygon) lấy hệ đông nhất của đội địch (mức `classic`: địch không có synergy → như web, không tác dụng).
7 skill mới cho các nhánh/dạng: Crabhammer, Stored Power, Psycho Cut, Silver Wind, Poison Powder, Blood Moon, Transe.

### Giữa các stage — `PlayerState.start_stage()` / `before_fight()` / `after_fight()`

- Ground: Pokémon Ground trên sàn đào ô của mình sâu thêm 1 (tối đa 5, sàn tối dần); tới 5 thì lấy đồ chôn
  (8 món mỗi run: vàng, Treasure Box = 2 mảnh, gem = +1 synergy; đồ chưa port đổi thành 1 mảnh ngẫu nhiên).
- Bug 4: mỗi stage một bản sao dạng đầu của con Bug rẻ nhất chưa tiến hoá hết xuất hiện ở bench (nếu còn chỗ).
- Fighting 4: Fighting ở ô bench đầu tiên hoặc bên phải một Pillar tập luyện trong trận → +4 ATK, +10% BASE HP vĩnh viễn.
- Fairy: mỗi mốc mới mở popup chọn 1 trong 3 wand (dùng chung popup "Choose an item").
- Additional pick: stage 5 / 8 / 11 các họ additional (Uncommon / Rare / Epic) vào shop (bản web cho chọn 1 con, chưa port popup đó).

---

## Phase 5 — thị trấn giữa stage (`src/core/town.gd`, port `game-commands.ts` / `mini-game.ts`)

- Đầu stage 0 / 10 / 20 (`PortalCarouselStages`): chọn 1 trong 3 **portal**. Stage 0: 6 hệ ngẫu nhiên; sau đó: 4 hệ mạnh
  nhất của người chơi; mỗi portal nhận vùng (map) có nhiều hệ chung nhất (không lặp vùng, bỏ `town` và map Test).
  Chọn xong → vùng của người chơi (`PlayerState.map`, đổi nhạc) và đề xuất **Pokémon khởi đầu** (stage 0, ra sàn ngay) /
  **Unique** (10) / **Legendary** (20) có hệ của portal, kèm item của propositions.
- Stage carousel (`ItemCarouselStages`): chọn 1 item (mảnh; từ stage 20 là item ghép, không Scarf) — popup "Choose an item".
- Additional pick (5 / 8 / 11): popup chọn 1 họ additional → họ đó vào shop.
- **Town encounter** (web `TownEncountersByStage`, theo trọng số): chỉ port Regirock (+15 máu), Xatu (Treasure Box),
  Kangaskhan (carousel item ghép giá 10 vàng), Sableye (chọn gem synergy), Duskull (Gimmighoul Coin: lãi tối đa +1),
  Marowak (boss PvE tiếp theo cầm `marowakItems`). Encounter khác bị bỏ qua khi bốc.
- Treasure Box tự mở khi máu ≤ 40 (`treasureBoxLifeThreshold`); gem không cầm được; Protean (Arceus...) nhận hệ theo đội.
- Hàng chờ lựa chọn: `Game.choices`, một popup mỗi lúc; bắt đầu trận thì tự chọn ngẫu nhiên phần còn lại (web `autoPickChoices`),
  carousel có giá thì bỏ qua, wand chờ.

## Phase 6 — ngôn ngữ

- Options (main menu và nút Menu trong game): ngôn ngữ, nhạc, âm thanh — lưu `user://settings.cfg`; lần đầu theo ngôn ngữ hệ thống.
- Chữ game: `GameData.set_language(code)` = `text.json` (Anh) + `lang/<code>.json` (bản dịch web) + `data/i18n/<code>.json`
  (viết cho port: `ability_port` mô tả skill của port, `item_port` mẫu mô tả item với `{param}` của `data/item_effects.json`,
  `stage_name`...). Bản dịch web tiếng Việt gần như trống nên `data/i18n/vi.json` viết đầy đủ; các ngôn ngữ khác dùng bản web
  (de, es, fr, it, ko, pt, zh gần đủ), phần thiếu giữ tiếng Anh.
- **Giữ nguyên từ khoá VIẾT HOA** trong câu dịch (`BURN`, `SHIELD`, `ON_HIT`, `ADJACENT`, `[30,LK]`): `GameText.format` đổi chúng
  thành tên / icon / số theo ngôn ngữ. BBCode (`[b]`, `[color=...]`) được giữ.
- Chữ giao diện: `L.t("English")` (TranslationServer, nạp từ `data/i18n/ui.json`); text tĩnh trong scene tự dịch.
  Giữ đúng `%d` / `%s` (sim_test kiểm tra). Đổi ngôn ngữ trong trận: HUD làm mới ngay (`Settings.changed`).
- Font chính **Be Vietnam Pro** (`assets/fonts/`, OFL; Regular / Italic / Bold / BoldItalic, gắn qua `gui/theme/custom_font` và
  `RichTextLabel` bold / italics trong `ui_theme.tres`; MSDF bật ở file `.import` của từng font). CJK / Thái dùng font hệ thống
  (fallback của Godot).

## Phase 7 — âm thanh, VFX, DPS meter, xem trước stage

- **Nhạc** (`Game._update_music`, như `board-manager.ts`): menu = Top Menu Theme; khi đang chọn portal / Pokémon của
  portal = Treasure Town Stage 0 / 10 / 20; còn lại = nhạc vùng (`config.maps[map].music`), chưa chọn vùng = Treasure Town.
  Nhạc Marowak ("The Terrable Jungle") không có file trong bản web → bỏ qua.
- **Âm thanh**: mọi nút click / hover (Audio bắt `node_added`), refresh shop, tiến hoá (t2 / t3), portal & carousel
  (carouselunlock), bắt đầu run (startgame), game over (finish1/2/4 theo stage đạt được).
- **VFX** — `VfxLibrary` (nạp sheet → SpriteFrames, fps / lặp / yoyo của web) + `VfxPlayer` (node `Vfx` của Game):
  - Skill: `data/ability_vfx.json`, mỗi skill là danh sách spec chuyển từ `abilities-animations.ts`
    (`at`: caster / target / projectile / skyfall / orbit / row / row_sweep / cells / enemies / shake; scale, origin, xoay theo
    hướng, offset px web, thời gian bay, `hit`...; xem `_doc` trong file). Skill web không có animation thì không có hiệu ứng.
    Kích thước: 1 px web = ô / 96 × `VfxPlayer.size_scale` (1.3); scale × (1 + AP/200) như web.
  - Đòn đánh thường: `anim.attackSprite` "…/range" = đạn bay tới mục tiêu (≤ 250 ms, tới lúc trúng), "…/melee" = hiệu ứng trên
    mục tiêu; mỗi lần mất máu có nguồn → hit spark `anim.hitSprite` của kẻ đánh.
  - Trạng thái: icon animation trên đầu Pokémon (`VfxLibrary.STATUS`, offset/scale của `pokemon-sprite.ts`), `UnitView.sync_statuses`.
  - Tiến hoá khi mua: burst EVOLUTION + âm thanh.
  - Sprite hiệu ứng quay mặt về camera, xoay trong mặt phẳng màn hình; vẽ đè sàn như Pokémon (`below` vẽ dưới Pokémon).
- Event sim mới: `damage` có `source`, `reduced` (bị DEF/SPE_DEF... chặn), `shield_taken`; `heal` / `shield` có `source`
  (người hồi / cho khiên; skill và Ability Shield, Green Orb ghi đúng người, còn lại = chính unit).
- **DPS meter** (`src/ui/dps_meter.gd`, như `game-dps-meter.tsx`): dưới panel máu, 3 tab — sát thương gây ra
  (vật lý / phép / chuẩn), sát thương chặn được (giáp + khiên), hồi máu + khiên; đội mình / đối thủ; gập bằng tiêu đề;
  giữ số của trận trước tới trận sau; ẩn khi đang xem panel một Pokémon.
- **Xem trước stage**: hover "Stage N" / tên đối thủ → 6 stage tới (boss màu đỏ, portal, carousel, additional pick, thưởng).

### Shop card, kho item nhiều trang, Item Remover (yêu cầu của người dùng, 2026-09-28)

- **Shop card** theo khung web: chân dung lệch phải, nửa trái mờ dần về đen dưới danh sách hệ, tên + giá trên dải tối ở đáy.
  Khung rarity dày 4 px (hover 6). Pokémon có hệ **đang kích** trên sàn (mốc ≥ 1): viền 8 px màu hệ nhấp nháy nhanh
  (0.35 s) + đom đóm chạy quanh viền (`src/ui/firefly_frame.gd`) + nền sáng sau tên hệ (`TypeRow.highlighted`).
- **Hover một hệ** (hàng trong danh sách synergy, hoặc tên hệ trên card shop) → `Hud.synergy_hovered`: card shop có hệ đó
  sáng (viền + đom đóm), card khác mờ; ô dưới chân các Pokémon hệ đó trên sàn và bench nhấp nháy màu hệ
  (lớp `synergy` của Arena, `Game._update_synergy_focus`, tính cả hệ do item cho).
- **Kho item nhiều trang** (`ItemBench`): 10 ô / trang, dưới cùng là "trang/tổng" + ◀ ▶, lăn chuột trên các ô cũng chuyển
  trang; có item mới thì nhảy tới trang cuối (nơi nó nằm). `slot_at` / `drag_started` trả chỉ số trong `PlayerState.items`.
- **Item Remover** (chỉ có ở bản port, icon Toolbox của web): ô viền vàng cố định trên đầu kho item, không nằm trong
  `PlayerState.items`, dùng không giới hạn. Kéo lên một Pokémon (như gắn item, được cả lúc đang đánh nếu nó ở bench) → mọi
  item nó cầm về kho (`PlayerState.strip_items`), trừ item đã làm nó tiến hoá (Primal Kyogre giữ Blue Orb).

---

## Vùng và Pokémon regional (2026-09-30)

Port của `player.ts::updateRegionalPool`, `pokemon.ts::isInRegion`, `shop.ts` (pool vùng, biến thể) và phần regional của
`assignUniquePropositions`.

- **Dữ liệu** (exporter): `config.regional` = `{pkm: {maps, requires}}` (chạy `isInRegion` của từng class trên 144 vùng;
  `requires` = họ additional phải vào shop trước, vd Alolan Vulpix cần Vulpix), `config.regionalVariants` (dạng gốc → biến
  thể), `pool.json.regional` (các dòng regional có đủ skill, để có sprite). `GameData.in_region / regional_in /
  variants_in_region / is_regional_variant`, `regional_base` (biến thể → họ của dạng gốc).
- **Pool vùng** (`PlayerState`): `change_map()` (portal, Lapras Passport) → `update_regional_pool(true)`: xoá
  `regional_counts`, thêm bản copy (`pool_size`) của các dạng 1★ chỉ có ở vùng (không phải biến thể). `regional_pokemons`
  = danh sách dạng vùng (web `regionalPokemons`), làm mới cả khi họ additional mở khoá. `pool_entries(rarity)` gộp pool
  chung + pool vùng và đổi dạng gốc thành biến thể (`regional_form`); `_roll_one` và cần câu dùng nó.
- **Khác web (cố ý)**: biến thể dùng chung bản copy với dạng gốc (`take_copy` / `return_copies`); web thì mua biến thể
  không trừ bản nào và bán lại sinh bản biến thể trong pool vùng. Pokémon regional bán ngoài vùng thì mất (giống web).
- **Thị trấn**: starter / Unique / Legendary — Pokémon regional chỉ được đề xuất trong vùng của nó, dạng gốc đổi thành biến
  thể của vùng, không đề xuất dạng mà biến thể mất hệ đang cần (`Town._fits_proposition`); additional pick hiện biến thể.
- **Burmy**: từ stage 20, sang vùng không có hệ của áo choàng → Burmy đầu tiên trên sàn thành Mothim.
- **HUD**: tên vùng trên thanh stage (trước thời tiết); hover: hệ của vùng + Pokémon vùng đang có trong shop.
- **Passive của dòng regional** (`passive_effects.gd`): Illusion (giả dạng đồng minh bên trái, Bitter Malice phá), Acceleration,
  Water Spring, Surge Surfer, Vigoroth, Slaking, Steely Spirit, Hisuian Typhlosion, Galarian Darmanitan (Zen: `effects.tree`
  — không đi không đánh, chỉ cast — và status `untargetable`), Corsola (KO → Galar Corsola), Hisuian Qwilfish (20 lần cast →
  Overqwil, đếm ở `OwnedUnit.stacks`), Avalugg (Bergmite trên bench → thêm băng ở lần Mountain Gale đầu), 4 terrain của Tapu,
  Ogerpon (hết khiên rơi mask: `on_shield_depleted`). Galarian Slowpoke rẽ nhánh theo PSYCHIC / POISON.
- **Item đổi dạng** (`PlayerState._sync_form_items`, thay cho `onAcquired` / `afterSell` của web): Rotom Catalog (thả lên
  Rotom → popup chọn 1 trong 7 dạng, category `form`), Nectar (chậu hoa lớn hết cỡ → đổi điệu Oricorio), 4 Mask của Ogerpon
  (đeo = đổi dạng `_MASK`, mask cũ về kho). Catalog và nectar không bị tiêu hao (`keep`).
- **Sàn mới**: STRANGE_STEAM (+20% sát thương skill, `BattleSim.strange_steam_factor`), STEALTH_ROCKS (10 PHYSICAL + WOUND).
  Obstruct: `effects.obstruct` → kẻ đánh nó mất 2 DEF.

## Độ khó và template wave (2026-09-30, không có ở web)

Chi tiết: `docs/DIFFICULTY.md`. Tóm tắt:

- `data/difficulty.json` + `src/core/difficulty.gd`: 3 mức (classic / normal / hard), mỗi mức = `base` + ghi đè; ghi đè
  `config.endless`, bật hệ / item cho wave địch, nhân chỉ số gốc theo stage, máu / vàng đầu run, hệ số mất máu.
  Chọn ở menu chính (`Settings.difficulty`); dòng lệnh `-- difficulty=<id>` cho test.
- `data/wave_templates.json` + `src/core/wave_templates.gd`: wave dựng theo slot (số con, Pokémon cố định hoặc ngẫu nhiên theo
  hệ / độ hiếm, sao, item, hàng), bốc thăm theo trọng số với bầy hoang dã, có thể thay boss.
- `EndlessWaves.get_stage()` trả thêm `stage`, `kind`, `statScale`, `synergies`, `synergyBonus`, `bonusSynergies`;
  `FightSetup.create()` đưa `team_tiers` / `team_info` cho đội đỏ. `SynergyEffects` vốn đã viết theo team nên chỉ sửa ô sáng
  Light (unit của wave không có `owned_id`).
- Tool `tools/wave_editor/` (scene Godot): sửa hai file, xem trước wave theo stage + seed, lịch 60 stage, bảng hệ quả độ khó.
- HUD: chip hệ của wave trên thanh stage, tooltip stage có độ khó + chỉ số + item của wave.

## Port nốt phần còn thiếu (2026-10-04)

### Trạng thái (port `status.ts`, `attacking-state.ts`, `moving-state.ts`)
- CONFUSION: một nửa số lần chọn mục tiêu, nhắm ngẫu nhiên trong tầm, kể cả đồng minh và chính mình
  (`BattleSim._confused_target`, web `getTargetWhenConfused`). CHARM: không đánh / không dùng skill, đi về phía kẻ mê hoặc.
- Không gia hạn FREEZE / SLEEP / LOCKED / CONFUSION / CHARM / BLINDED khi đang dính; hết thì miễn 1,5 s (`CC_COOLDOWN`,
  `cc_cooldown` trong `BattleUnit.tick`). BURN làm FREEZE hết nhanh gấp đôi; RAGE +80 SPEED, chia đôi SLEEP / FREEZE.
- SILENCE không áp lên cây (Sudowoodo...), CURSE lần hai giết ngay, LOCKED tầm đánh 1 (trả lại khi hết, kể cả Wide Lens /
  Long Wand), quả mọng giải trạng thái được ăn ngay khi dính. PROTECT không còn chặn trạng thái (chỉ SAFEGUARD / inanimate).
- Hồi sinh (Max Revive, RESURRECTION, Sacred Ash...): 2 s trạng thái `resurrecting` (không bị nhắm, không hành động),
  rồi về chỉ số lúc vào trận (`spawn_stats`), đầy máu, 0 PP, mất trạng thái trừ cái của item (`BattleSim._try_resurrect`).
- Reflect chặn sát thương vật lý và phản lại; WONDER_GUARD; sát thương lên Pokémon ngủ (-300 ms) / bị mê hoặc (-500 ms).
- Di chuyển cưỡng bức đi qua `BattleSim.force_move / swap_cells / _on_displaced` (Pursuit, Stench, cục bông, mưa đá).

### Passive (`src/core/passive_effects.gd` viết lại theo `passives.ts`)
Illusion (Zorua: mượn hình con bên cạnh cả trên sàn), Falinks (đội hình + lính), Comfey (bám vào đồng minh thành item),
Commander (Tatsugiri), Conversion (lấy hệ đông nhất của địch — trong `classic` địch không có synergy nên như web không có
tác dụng), Manaphy → Phione, Stonjourner, Skarmory (gai), Bad / Good Luck, Tadbulb, Finizen → Palafin Hero, Eiscue
(Ice Face), Wall of Stone, Luvdisc, Victini, Mimikyu (Disguise), Primeape (Rage Fist), Basculin (đổi màu theo số lần gục),
Last Respects, Minior (lõi), Kubfu (cuộn giấy), Guzzlord, Poipole / Naganadel, Moxie, Durant, Shared Vision,
Illumise / Volbeat, Clear Wing, Zygarde (cell), Dry Skin, Water Bubble, Gholdengo... Hook mới: `on_second`,
`on_status`, `on_resurrecting`, `on_resurrect`, `on_shield_depleted`.

### Tiến hoá đặc biệt (`src/core/evolution_rules.gd`, port `core/evolution-logic/*`)
- Theo stack (`stacksRequired` do exporter xuất), theo trạng thái (Tandemaus từ stage 15, họ FAMILY khác từ stage 20;
  Stantler: ở vùng khác vùng bắt và từ stage 20), theo tiền (Gimmighoul: đủ vàng), theo vị trí (Mantyke cạnh Remoraid),
  theo item (Armarouge / Ceruledge, Urshifu, Alcremie), theo số lần gục (Basculin), dạng Vivillon theo vùng,
  Cosmog → Cosmoem → Solgaleo / Lunala.
- `on_acquired`: Ninjask sinh Shedinja, Cosmoem, Stantler ghi vùng gốc; Meltan đổ vào Melmetal (+50 HP).
- Shop: Ditto / Meltan / lính Falinks theo tỉ lệ web, không ra dạng đầu của họ đã tiến hoá hết; giá mua / bán theo
  `getSellPrice` (kẹo, trứng, unique, legendary); METEORITE (Deoxys), ZYGARDE_CUBE, giáp Charcadet, cuộn Kubfu,
  hương vị Milcery, đĩa Silvally, đá synergy.

### Pokémon lang thang (`src/view/wanderers.gd`, port `wanderers-manager.ts`)
Magnet Pull (Pokémon Thép) và kẻ truy nã (Wanted Notice, Drowzee) chạy qua màn hình; bấm vào để bắt (bench / +10 vàng).
Hàng chờ: `PlayerState.wanderers`, game tạo node `Wanderers` và gọi `_click_wanderer` khi bấm chuột trái.

### Shiny, duo, phần thưởng stage
- Celebi (town encounter) và `shinyChance` của wave: trận PvE kế tiếp shiny (sprite shiny do exporter xuất, phần thưởng
  `shinyRewards` của `pve-stages.ts`). `Game._give_reward` theo web: if_board, unique / remember / weighted / choice.
- Duo (Latios + Latias, Plusle + Minun...) trong đề xuất Unique / Legendary (`GameData.DUOS`, chọn được cả hai).
- Town encounter đủ 23 (thêm Celebi, Kingambit → Leaders Crest, chỉ có tác dụng khi đấu người); Treasure Box đủ loại.
- Deerling theo mùa (`GameData.current_season`).

### Skill
24 skill `approx` viết lại đúng web (Heavy Slam, Terrain Pulse, Magnet Bomb, Teleport, Pursuit, Nightmare, Column Crush,
Dragon Rage, Psystrike, Sky Attack, Fire Blast, Thunder, Origin Pulse, Draco Meteor, Precipice Blades, Stealth Rocks,
Iron Head, Dragon Energy, Roar of Time, Shadow Force, Spacial Rend, Judgement, Cotton Spore, No Retreat) + Magnet Pull,
Dream Eater, Hail, 3 lệnh Vespiquen (Attack / Heal / Defend Order theo hàng, gọi Combee). Không còn skill `approx`.
Công cụ: `python tools/port/replace_abilities.py <entries.json> [<code.gd> <region>]` (thay entry một dòng trong
`abilities.json`, nối code vào `ability_scripts.gd`).

### VFX
VfxPlayer thêm `spread`, `from_cell` / `to_cell` (ô ngoài sàn được), `jitter`, `at: everyone`, `at: unowns` (Hidden Power:
Unown bay xoắn ốc). 473 / 551 skill có spec; 78 còn lại bản web cũng không có animation (`python tools/port/gen_vfx.py`).

### Kỷ lục, Android (không có ở web)
- `src/game/records.gd` (`Records`): stage cao nhất + đội hình + ngày + số lượt chơi theo mức độ khó, lưu ở
  `user://records.cfg`; run có dùng cheat không tính. Hiện ở menu chính (dưới ô độ khó) và popup Game Over.
  Test trỏ `Records.path` sang file khác; `records=<file>` sau `--` để chụp màn.
- `src/autoload/touch_input.gd` (autoload `TouchInput`, chỉ bật trên máy cảm ứng): chạm = chuột trái (Godot giả lập),
  chạm giữ 0,45 s = chuột phải (tooltip ghim, xem Pokémon), nhả off-screen để huỷ nút / kéo thả đang dở.
- `export_presets.cfg`: preset **Android** (APK debug, arm64, ký bằng debug keystore của môi trường
  `C:\Users\nqloc\godot-android`) và **Windows**; ra `build/` (có `.gdignore`); bỏ `tests/ tools/ docs/ addons/`.
  `rendering/textures/vram_compression/import_etc2_astc=true` (bắt buộc cho Android). APK ~370 MB (nhạc ~270 MB).

## Chưa port / khác bản web

- Không port: multiplayer (và mọi thứ chỉ có tác dụng khi đấu người: đá thời tiết của Rock, Leaders Crest, Mission
  Order đỏ), animation boost / emote, quỹ đạo cong của vài đạn (Icicle Missile: làm gần đúng).
- Hết giờ planning mà sàn chưa đủ quân → tự đặt quân từ bench (như TFT; tắt bằng `Game.auto_place_on_fight`).
- Cờ `approx` trong abilities.json vẫn được panel hiểu ("(simplified port)") nhưng hiện không skill nào dùng.
- Hình dạng tạm (Trick-or-Treat → Magikarp, Camouflage, Transform): event `transform` có `pkm` = chỉ đổi hình.
- Kỷ lục, Item Remover, tua trận, xem trước stage, độ khó + template wave, chạm giữ trên Android: thêm riêng của bản port.

## Test

Sau khi export có file mới (icon, script có `class_name` mới), chạy `Godot_v4.7-stable_win64_console.exe --headless --path . --import`
một lần (hoặc mở editor) để Godot import asset và cập nhật danh sách class.

```
Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/sim_test.tscn    # logic (ở mức classic + _check_difficulty): script, wave 1-60, mọi skill, preview, shop, item (luật ghép, gộp, từng item trong trận), vai trò, đếm synergy + weather, mọi mốc của mọi synergy, passive, luật giữa stage, thị trấn, ngôn ngữ (mọi ngôn ngữ, ui.json), dữ liệu VFX / âm thanh, trận mẫu
Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/flow_test.tscn   # MM -> game -> game over -> MM
Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/soak_test.tscn   # bot chơi tới stage 22 (mua, kéo thả, gắn item, nhận thưởng)
Godot_v4.7-stable_win64.exe --path . res://tests/screenshot.tscn -- <thư mục>        # chụp màn hình từng màn của breakdown (cần cửa sổ)
Godot_v4.7-stable_win64.exe --path . res://tests/screenshot.tscn -- <thư mục> synergy  # ô sáng, hố, popup wand, tooltip synergy, passive, trận có clone
Godot_v4.7-stable_win64.exe --path . res://tests/screenshot.tscn -- <thư mục> vfx [SKILL...]  # hiệu ứng từng skill, icon trạng thái, đạn, tiến hoá
Godot_v4.7-stable_win64.exe --path . res://tests/screenshot.tscn -- <thư mục> menu lang=vi   # thêm lang=<code> để chụp theo ngôn ngữ
```
