# data/abilities.json — định dạng skill

Mỗi khoá là id skill của bản web (`Ability` enum, ví dụ `HYDRO_PUMP`). Code chạy: `src/core/ability_runner.gd`.
Mọi mảng giá trị là theo số sao `[1★, 2★, 3★, (4)]`; nếu ngắn hơn thì lấy phần tử cuối.

```jsonc
"HYDRO_PUMP": {
  "name": "Hydro Pump",                  // tên hiển thị
  "desc": "Fires a jet ...",             // mô tả trong panel
  "approx": "…" | true,                  // (tuỳ chọn) đánh dấu bản đơn giản hoá
  "no_target": false,                    // true = cast được khi chưa có địch trong tầm (requiresTarget = false)
  "focus": "target",                     // target | farthest | lowest_ally | self  — "mục tiêu" của skill
  "dash": "",                            // di chuyển trước khi đánh, xem bên dưới
  "cycle": false,                        // true = mỗi lần cast dùng 1 bước kế tiếp (Drum Beating)
  "special": "",                         // (tuỳ chọn) hiệu ứng viết bằng code: "transe" = Darmanitan Zen trở lại dạng thường
  "steps": [ { ...bước... } ]
}
```

## Bước (`steps[]`)

| khoá | giá trị | ý nghĩa |
|---|---|---|
| `area` | xem bảng trong PORTING.md | vùng ô |
| `origin` | `caster` (mặc định) / `focus` | tâm của `adjacent` / `radius` / `square` |
| `size` | số, mảng theo sao, `"range"`, `"range+1"` | bán kính / độ dài / số mục tiêu |
| `center` | bool | tính cả ô tâm |
| `affects` | `enemies` (mặc định) / `allies` / `allies_others` / `all` | ai bị ảnh hưởng trong vùng |
| `first_only` | bool | chỉ địch đầu tiên trên đường (Whirlpool) |
| `guarantee_focus` | bool | vùng không trúng ai thì vẫn trúng mục tiêu (`ray` luôn bật) |
| `delay`, `repeat`, `interval` | ms, số lần (`"fallen+1"`, `"speed3"`), ms | trễ và đánh nhiều lần; `delay ≥ 500` → nháy báo trước |
| `scatter`, `cycle_targets` | bool | `random`: rơi vào 3×3 quanh địch; `closest`: bắn lần lượt nhiều phát |
| `effects` | mảng | hiệu ứng, áp dụng lần lượt lên từng Pokémon trong vùng |

## Hiệu ứng (`effects[]`)

`"to": "self"` = áp lên chính người cast (1 lần mỗi bước), không có = lên từng mục tiêu trong vùng.

| type | khoá | |
|---|---|---|
| `damage` | `values`, `kind` (special/physical/true), `stat` (nhân với chỉ số người cast: atk, def, speDef, speed, maxHP, hp), `plus_stat`+`plus_values`, `if`+`if_mult`, `falloff`, `splash`, `crit_bonus`, `always_crit`, `per_fallen`, `target_hp_bonus`, `execute_chance`, `execute_below` (mục tiêu dưới tỉ lệ HP này bị hạ ngay, Crabhammer), `stored_power` (nhân với tổng chỉ số được buff), `on_kill_pp`, `no_ap` | sát thương (mặc định nhân `1 + AP/100`) |
| `drain` | `ratio` | hồi máu người cast theo sát thương vừa gây lên mục tiêu đó |
| `heal` | `values`, `stat` / `target_stat` | hồi máu |
| `shield` | `values`, `stat` | khiên |
| `status` | `status`, `duration` / `durations`, `chance`, `options` (ngẫu nhiên), `ap_scale`, `if` | paralysis, burn, freeze, sleep, silence, flinch, armor_reduction, confusion, charm, locked, fatigue, poison (cộng tầng), wound, blinded, protect, reflect, safeguard; người cast là "nguồn" (Poison 3 → tối đa 5 tầng, Synchro) |
| `buff` | `stat` (atk, def, speDef, speed, ap, pp, critChance), `values` (âm = giảm), `scale_stat`, `no_ap` | cộng chỉ số |
| `cleanse` | | xoá hiệu ứng xấu |
| `knockback` | `distance` / `distances` | đẩy lùi theo hướng từ người cast |

Điều kiện `if`: `{"target_type": "FLYING"}`, `{"target_types_any": [...]}`, `{"target_status": "burn"}`,
`{"target_negative": true}`, `{"target_shield": true}`.

## Dash

| dash | |
|---|---|
| `farthest_spot` | lướt tới ô trống cạnh địch xa nhất (mục tiêu đổi thành địch đó) |
| `behind_focus` | ra sau lưng mục tiêu |
| `toward_focus` | tiến 1 ô về phía mục tiêu |
| `fly_away` | bay tới ô an toàn (ít địch với tới, vẫn còn địch trong tầm) |
| `most_surrounded` | tới ô trống có nhiều địch xung quanh nhất |
| `far_row` | lao tới hàng cuối sàn phía bên kia |
| `swap_farthest` | đổi chỗ với địch xa nhất |

## Thêm skill

1. Đọc `pokemonAutoChess/app/core/abilities/<ten-skill>.ts`, chuyển sang một mục JSON như trên.
2. Chạy `tools/export_pac.bat` → Pokémon dùng skill đó (nếu cả họ tiến hoá đều đã có skill) vào pool.
3. Chạy `tests/sim_test.tscn` (cast thử mọi skill).
