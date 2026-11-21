# Bot tự chơi — dữ liệu để cân độ khó / cân bằng (2026-11-18)

Bot chơi Endless **không dựng view** (logic thuần, nhanh), mỗi run một kiểu chơi rút ngẫu nhiên, ghi chi tiết từng stage /
từng Pokémon ra **TSV gọn** — định dạng chọn để **Claude** đọc và phân tích (pandas), không để người đọc.

## Chạy

```
tools\bot_run.bat -Runs 500 -Workers 6 -Out build/bot/b1 -Diffs normal,hard -Seasons s1,s2,s3 -Passes journey -Report
```
(Bash tool: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/bot_run.ps1 ...`.) Mỗi worker là một Godot
`--headless` ưu tiên thấp (BelowNormal), không cửa sổ, không âm thanh, **không ghi** pass / kỷ lục của người chơi.

| Tham số | Ý nghĩa |
|---|---|
| `-Runs` | số run **mỗi worker** |
| `-Workers` | số tiến trình (0 = số nhân logic − 2) |
| `-Out` | thư mục kết quả (tương đối thư mục dự án) |
| `-Diffs`, `-Seasons`, `-Passes`, `-Styles` | danh sách, mỗi run rút một giá trị. `-Passes journey` = người chơi mới: cấp pass theo số run worker đã chơi (1 run → cấp 2, rồi 3 run một cấp); `all` = mở hết; số = cấp đó. `-Seasons all` = không mùa |
| `-NoUnits` | không ghi `units_*.tsv` (file to nhất) |
| `-Seed` | seed đầu (worker w dùng seed + w × 1 000 003; cùng seed + cùng code = cùng shop / wave / lựa chọn của bot) |
| `-Report` | chạy `tools/bot/report.py` sau khi xong |
| `-Styles pro` | bot pro (`BotPro`, xem dưới); trộn được: `-Styles pro,random,synergy` |
| `-Knowledge`, `-Model` | file kinh nghiệm / mô hình thắng (mặc định `tools/bot/knowledge.json`, `tools/bot/model.json`); `-NoLearn` = không gộp kinh nghiệm của lô, không train lại mô hình |
| `-Design`, `-Combo 2\|3` | design test: mọi cặp (bộ 3) hệ của pool, chia đều cho các run (xem dưới) |

Một worker trực tiếp: `%G% --headless --path . res://tools/bot/bot_runner.tscn -- runs=50 out=build/bot/x worker=0
diffs=normal passes=1,5,all` (tham số trong `tools/bot/bot_runner.gd`).

Tốc độ đo được: ~2 s / run / worker (run tới stage ~20–25); 4 worker × 10 run = 21 s. 10 000 run với 8 worker ≈ 45 phút.

## File (trong `-Out`)

`runs_W.tsv`, `stages_W.tsv`, `units_W.tsv`, `meta_W.tsv` (W = worker; dòng đầu là header), `log_W.txt` / `err_W.txt`,
`report.tsv`, `boards.tsv`. Cột (hằng `BotRun.*_COLUMNS`):

- **runs**: `run seed diff season pass bot aims stage wins losses draws level gold board wave fight_s real_ms unlocks` —
  `stage` = stage chết, `wave` = wave cuối (giết run), `bot` = hồ sơ `style:keep:pace:rolls:aims:items:noise`, `aims` = hệ
  nhắm lúc cuối, `unlocks` = hệ mở tạm theo vùng trong run.
- **stages** (một dòng mỗi trận): `run stage map life gold level income team bench itembench rolls bought sold xp syn board
  wave wkind wn wpkm wsyn res fight_s alive_b alive_r loss reward picks unlocks aims` — `life` / `gold` / `board` / `syn` = **lúc
  vào trận**; `income` = vàng nhận đầu stage; `rolls bought sold xp` = việc bot làm trong pha chuẩn bị; `res` W / L / D;
  `loss` = máu mất; `reward` = item nhận (`+choice` = được chọn); `picks` = lựa chọn đã trả lời; `unlocks` = số hệ mở tạm;
  `aims` = hệ bot đang nhắm ở stage đó (đo "dễ build").
- **units** (một dòng mỗi Pokémon mỗi trận, cả hai đội): `run stage team pkm stars rarity items role dealt phys spec true
  adealt taken heal shield casts first_cast maxpp alive t_dead y ppgain attacks tphys tspec ttrue mitig blocked hp0 atk0 def0
  spedef0 speed0 ap0 crit0` — `team` B (người chơi) / R (địch); `adealt` = phần sát thương từ đòn đánh thường (event damage
  có `attack: true`, phần còn lại là skill / item / hệ); `casts`, `first_cast` (giây) = số lần dùng skill và lần đầu; `maxpp`
  = PP cần; `t_dead` = giây gục (−1 = sống); `y` = hàng lúc vào trận (người chơi 2 = trước); `ppgain` = PP nhận được cả trận
  (`BattleUnit.pp_gained`: tool cân PP dựa vào nó); `attacks` = số đòn đánh thường; `tphys / tspec / ttrue` = `taken` theo
  loại; `mitig` = sát thương DEF / SPE_DEF (và giảm cố định) chặn; `blocked` = sát thương bị chặn hẳn (Protect, Reflect...);
  `hp0 ... crit0` = chỉ số lúc vào trận (sau item, hệ, hiệu ứng đầu trận; con vào giữa trận: lúc cuối); `sdealt` / `ssus` =
  sát thương / hồi + khiên **của skill** (event có `ability`: `BattleSim.ability_source` trong lúc `AbilityRunner.cast` chạy,
  cả đòn trễ qua `schedule`; phần `dealt − adealt − sdealt` còn lại là item / hệ / passive / trạng thái).
- **meta**: tham số, `mana` của độ khó, `errors` (run dừng vì lỗi script), `seconds`.

Mã hoá trong ô: board `PKM*sao[ITEM+ITEM]@x.y|...` (y 3 = hàng trước; lô trước 2026-11-20: sàn vuông, y 2); hệ `TYPE:số:mốc|...` (chỉ mốc ≥ 1); wave
`tpl:<template>` / `boss:<tên stage>` / `wild:<con đầu đàn>`; picks `p:<vùng>`, `s:/u:/l:/a:/f:<Pokémon>` (starter / Unique /
Legendary / additional / dạng), `i:/w:/c:<item>` (thưởng / đũa / carousel, `-` = bỏ qua).

## Báo cáo (`tools/bot/report.py <dir> [--min 20]`)

In ra (và ghi `report.tsv`) các khối TSV `#tên`: `by_setup` (theo độ khó × mùa × cấp pass), `by_style`, `curve` (theo stage: số
run còn sống, tỉ lệ thắng, máu, cấp, đội, vàng, máu mất khi thua), `death` (stage chết theo dải 5), `waves` (wave giết nhiều
run / tỉ lệ thắng thấp), `wkind` (thắng theo loại wave × dải 10 stage), `syn` (hệ đang kích → tỉ lệ thắng), `pkm best/worst`,
`items`, `roles`, `enemy carries` (Pokémon địch gánh sát thương). `boards.tsv`: đội hình thắng còn dư quân theo dải 5 stage —
nguyên liệu làm wave Endless từ đội hình bot (TODO bước sau).

**`tools/bot/balance.py <dir> [--min 30]`** (ghi `balance.tsv`): 5 câu hỏi cân bằng, mọi số `adj` đã trừ tỉ lệ thắng trung bình
của stage đó — `pkm_vs_cost` (Pokémon mạnh / yếu so với cùng độ hiếm + sao), `rarity_stars`, `syn_ease` (hệ: bot nhắm thì tới
mốc 1 / 2 bao nhiêu % (r1 / r2) so với độ mạnh khi kích (adj, adj2); `easy+strong` / `hard+weak`), `skill_pp` (lượng ra mỗi lần
dùng skill so với nhóm cùng độ hiếm / sao / vai trò, tần suất dùng, trận không dùng lần nào), `items` (cầm item vs cùng Pokémon,
cùng dải stage, cùng số item mà không cầm nó), `roles` / `role_fit` (vai trò có làm đúng việc: % sát thương, % đòn nhận,
sống sót, hồi + khiên, đứng hàng trước).

**`tools/bot/season_report.py <dir> [<dir>...] [--season s1] [--min 30]`** (ghi `<dir đầu>/season_<id>.tsv`): mùa có skill /
hệ riêng (`data/season_skills.json`, `data/season_synergies.json`) — `seasons` (mỗi lô × mùa: stage, tỉ lệ thắng, độ dài trận,
`ms_stage` = thời gian thật mỗi stage, so chi phí code giữa các mùa trong cùng lô), `synergy_spread` (độ lệch `adj` giữa các hệ
của từng mùa), `synergies <mùa>` (mỗi hệ: cơ chế, `adj` khi kích / mốc ≥ 2, `adj_foe` khi wave địch có hệ đó), `roles`, `skills
<mùa>` (mỗi skill mùa: mới / mượn, PP, số lần cast khi không item, % trận không cast, đầu ra mỗi lần cast, D / T / S = phần sát
thương gây / nhận / hồi + khiên so với phần đều của đội, `other_part` = sát thương qua hook không gắn `ability`, `dmg0` /
`dmgi` = sát thương so với cùng vai trò khi không item / có item (cách tính của tự cân bằng, bước 4b), so với **cùng dạng dùng
skill web ở mùa khác** `D_web` / `casts0_web` / `dmg0_web` / `dmgi_web` — cần lô có cả mùa khác, ví dụ `all`). Lỗi script của
worker ở đầu file.

Phân tích sâu hơn: đọc thẳng các TSV bằng pandas (`pd.read_csv(f, sep="\t", na_filter=False)`), nối `units` với `stages`
theo `(run, stage)`.

## Bot chơi thế nào (`tools/bot/bot_brain.gd`)

Mỗi run rút một hồ sơ: `style` random (mua theo hứng, không nhắm hệ, noise 0,5) / synergy (nhắm 2 hệ) / reroll (cấp thấp,
đổi shop nhiều để lên 3 sao) / fast (lên cấp sớm) / econ (giữ 40–50 vàng lấy lãi); `keep` (vàng giữ lại, tăng dần theo
stage, giảm khi máu ≤ 40), `pace` (số stage mỗi cấp sau cấp 3), `rolls`, `aims`, `items` carry / spread / role, `noise`.
Mỗi pha chuẩn bị: trả lời lựa chọn (cổng theo hệ nhắm + hệ "Mở tạm", Pokémon theo độ muốn, item theo vai trò hoặc ngẫu
nhiên, carousel nếu đủ vàng, đũa phép), bắt Pokémon lang thang (90%), hái quả mọng, chọn lại hệ nhắm, lên cấp theo đường
cong (dư ≥ 30 vàng thì lên tiếp), mua / đổi shop (ưu tiên đủ 3 con, hệ nhắm, độ hiếm, lấp sàn; dư vàng thì đổi shop thêm),
bán bớt bench khi cần chỗ, xếp sàn (con mạnh nhất thay con yếu nhất; cận chiến hàng trước, tầm 2 hàng giữa, xa hàng sau),
gắn mọi item qua `PlayerState.equip`.

**Chưa làm** (người thật có thể làm): dùng phân bón / vé đổi item, gỡ item, khoá shop, đặt con vào ô sáng (Light), xếp
theo hệ của địch, Dojo, chọn dạng Rotom có chủ đích. Bot không "giỏi" như người — số liệu là của người chơi trung bình
đến yếu; so sánh tương đối (wave này khó hơn wave kia, hệ này mạnh hơn) đáng tin hơn con số tuyệt đối.

## Bot pro (bản 2, 2026-11-18): thích ứng theo run, phán đoán học từ data

`tools/bot/bot_pro.gd` (`BotPro`, style `pro`) chơi như người giỏi **thích ứng với thứ run đưa tới**, không theo công thức
cố định; mọi phán đoán **học từ data** (giống AI chơi hơn là luật viết tay):
- **Mô hình thắng** `tools/bot/model.json` (`BotModel`; train: `python tools/bot/train_model.py --all`, launcher tự chạy sau
  mỗi lô trừ khi `-NoLearn`): hồi quy logistic "đội này thắng trận này" trên mọi trận của mọi lô. Đặc trưng: `st:` stage,
  `lv:` cấp, `wv:` wave, `sy:HỆ:k` mỗi mốc đã kích, `pr:A+B` cặp hệ cùng kích, `u:` mỗi Pokémon trên sàn, `it:` mỗi item,
  `pw` sức mạnh đội (Σ giá × 3^(sao−1) / 10), `n3` số con 3 sao, `ni` số item / 3. Holdout (52 nghìn trận): acc 0,805,
  AUC 0,892 (chỉ biết stage: 0,751 / 0,836).
- **Kế hoạch** = 2 hệ chọn từ **chính run này**: số con đang có + ½ số con shop đang bán + một chút pool (như nhau ở mọi run)
  → mốc với tới được → giá trị đã học của các mốc + của cặp (+ nhỏ cho hệ sát thương đi với hệ buff / đỡ đòn, nhóm
  `BotPro.DAMAGE`); rút **softmax** (`TEMPERATURE` 0,12) trong các hướng tốt, xét lại mỗi 3 stage (+0,15 cho hướng đang đi:
  chỉ đổi khi hướng khác rõ ràng hơn). Hệ thứ 3 từ cấp 6 khi đã có ≥ 2 con của nó và mô hình nói đáng.
- **Đội hình**: đổi chỗ tối đa log-odds của mô hình trước **đúng wave của stage** + tiến độ kế hoạch, ≥ 2 con đỡ đòn, 1 carry.
- **Mua**: con làm odds tăng nhiều nhất (thay con yếu nhất hoặc vào chỗ trống) + bản sao tới 3 sao + hệ kế hoạch; bán con
  bench ít giá trị nhất khi cần chỗ; khoá shop khi có con rất muốn mà thiếu tiền.
- **Kinh tế**: giữ vàng / nhịp lên cấp của run rút softmax trong các cặp `giữ ∈ {10..50} × nhịp ∈ {3..5}` đã học
  (`knowledge.json` → `econ`); giữ lãi khi an toàn (odds > 0,85 → giữ 50), **tiêu hết** khi odds < 0,35, gặp boss, máu ≤ 40
  hoặc vừa thua.
- **Item**: gắn chỗ mô hình định giá cao nhất (`it:`, carry ×1,5), mảnh ghép cho carry / tuyến trước, đá tiến hoá, TM, món ăn,
  đá hệ làm tăng mốc (hệ kế hoạch ưu tiên), Cell Battery. **Vị trí**: đỡ đòn hàng trước (trâu nhất ở giữa), carry góc sau,
  carry chính vào ô sáng (Light), Pokémon Ground giữ ô đã đào.
- **Kinh nghiệm** `tools/bot/knowledge.json` (`BotKnowledge`, mỗi mục `[n, tổng]`, gộp bằng cộng: `stage syn pair unit share
  item plan econ`): mọi bot góp trận; worker ghi `knowledge_W.json`, launcher gộp bằng `python tools/bot/learn.py <lô>`
  (`--decay 0.9`, `--reset`, `--from-tsv <lô>` học lại từ TSV). `plan` / `econ` chỉ lấy từ run của bot pro / design (bot yếu
  chơi hệ nào cũng chết sớm). Không có `model.json` thì bot pro dùng các bảng này.

| Lô (normal, pass all, 4 mùa) | Run | Stage TB | Kế hoạch khác nhau | Hệ hay chọn nhất |
|---|---|---|---|---|
| pro1 (bản 1: UCB + bảng) | 300 | 26,4 | hội tụ | Poison + Steel 52 / 300 (cả 6 run vô hạn) |
| pro2 (mô hình, kế hoạch theo pool) | 120 | 22,6 | 61 | Poison 73% |
| pro3 (kế hoạch theo quân + shop của run) | 120 | 23,8 | 90 | Bug 40%, Fire 38%, Poison 37% |

pro1 cao nhờ spam Poison + Steel (đội vô hạn ở s2 / s3); pro3 vừa đa dạng vừa mạnh hơn pro2: meta vẫn hiện ra (hệ mạnh được
chọn nhiều hơn) nhưng không độc quyền — đúng ý "người chơi giỏi thích ứng, không spam một chiến thuật".

## Design test (`-Design`)

```
tools\bot_run.bat -Design -Seasons s1 -Runs 109 -Workers 12 -Out build/bot/design_s1 -NoLearn -Report
```
Style `design` = bot pro với **kế hoạch cố định**: mọi cặp hệ (bộ 3: `-Combo 3`) có ≥ 3 họ trong pool shop của mùa
(`BotPro.design_combos`), chia đều cho các run (run i của worker w chơi tổ hợp i × workers + w); kinh tế = cặp tốt nhất đã
biết, phần còn lại thích ứng như bot pro. **Một mùa mỗi lô** (tổ hợp tuỳ pool của mùa): s1 30 hệ / 435 cặp / 4 060 bộ 3;
s2, s3 31 / 465 / 4 495; không mùa 30 / 435. Muốn mỗi cặp k run: `-Runs` = ⌈k × số cặp / workers⌉. `report.py`: `#combos`
(mỗi tổ hợp: n, stage TB, trung vị, p90, tỉ lệ thắng), `#combo_types` (mỗi hệ: stage TB các tổ hợp có nó, `se`, `vs_all`).
Data design cũng là data **không thiên lệch** cho mô hình (mọi cặp đều được chơi, kể cả cặp bot pro không bao giờ chọn).

Kết quả design test (2026-11-18: normal, pass all, 3 run mỗi cặp, **4 116 run**, 12 worker: s1 341 s / s2 387 s / s3 541 s;
`build/bot/design_s1..s3`, 0 lỗi). Stage TB mỗi mùa ~22,9. Hệ (stage hơn / kém TB của mùa, gộp các cặp có hệ đó, se ≈ 0,2):
- Mạnh: **Poison +1,5** (s2 +3,1: Ghost + Poison tới 64, Normal + Poison 48, Poison + Psychic 46), **Rock +1,1** (phần lớn
  nhờ **Rock + Sound ở s3**: 6 run TB +25 stage, một run 141 — đội vô hạn), Sound +0,8 (chỉ có ở s2 / s3), Electric +0,6,
  Fossil +0,5, Ice +0,5, Fire +0,3.
- Yếu: Flying −0,6, Gourmet −0,6, Human −0,6, Normal −0,5, Psychic −0,5, Flora / Fairy / Baby / Wild / Artificial ≈ −0,4.
  Cặp tệ nhất: Gourmet + Sound, Light + Wild, Artificial + Flying, Amorphous + Wild (−2 tới −3,3 stage).
- Hệ "cơ chế" (Light, Gourmet, Baby, Flora, Wild, Fairy) có thể yếu một phần vì bot chưa dùng hết cơ chế (phân bón, vé...).
- Sd stage của một cặp 2,6–4,6 → 3 run mỗi cặp đủ xếp hạng **hệ** (~87 run mỗi hệ mỗi mùa); xếp hạng **cặp** cần ≥ 10 run
  mỗi cặp (`-Runs` ≈ 10 × 435 / 12 ≈ 363 mỗi mùa, ~20 phút một mùa).

## Tự cân bằng (2026-11-18; phương pháp 4: 2026-11-19)

Mục tiêu (người dùng): cân bằng **tự động** từ data bot; **mỗi Pokémon có chỉ số riêng, cân theo chính chỉ số đó** — không
có hệ số theo hệ (hệ mạnh được cân qua chỉ số của các Pokémon của nó). Tiêu chí (2026-11-19):
- Pokémon có **làm tròn vai trò** chưa; có gây ra gì **khác vai trò** không (ví dụ tank gây quá nhiều sát thương);
- **có và không có item**: có mạnh hơn phần còn lại không;
- Pokémon **hiếm hơn thì mạnh hơn**;
- **số lần dùng skill mỗi trận** hợp lý (có / không item); HP / PP làm tròn hàng chục; chỉnh cả DEF, SPE_DEF, SPEED;
- **sát thương của skill, sát thương tay (đòn đánh thường), chỉ số skill scale**;
- mục tiêu cuối: mỗi carry có bộ item + hệ đi kèm khiến nó cực mạnh (chiến thuật), nhưng **không có chiến thuật duy nhất áp
  đảo** các chiến thuật khác.

**`data/balance.json`** (không đụng `data/pac`, một dòng mỗi dạng): `pokemon`: dạng → hệ số riêng từng chỉ số
`{"hp", "atk", "def", "speDef", "speed", "skill", "pp"}` (thiếu = 1; `pp` = PP cần để dùng skill × m; HP và PP làm tròn
**hàng chục**; một số = cùng hp / atk / skill — định dạng cũ). `skill` **không phải chỉ số**: sức mạnh skill riêng của dạng đó
(`skillScale`, `BattleUnit.skill_scale()`) = × sát thương / hồi / khiên mà skill đó gây ra lúc chạy (`BattleSim.ability_scale`,
cùng điều kiện với cờ `ability` của event; không nhân đòn đánh thường, hút máu / Shell Bell sau một đòn (`damage_hooks`), skill
không phải của nó (TM, Skill Swap)); AP luôn 0 như web; tooltip skill ghi "Hiệu lực kỹ năng: x%". **Không chỉ số nào được âm**
(người dùng 2026-11-20, trước đó `skill` < 1 thành AP âm, thấp nhất −47): skill quá mạnh → giảm `skill` hoặc tăng PP; mọi hệ
số > 0 (`BOUNDS`), `autobalance.py` dừng nếu một chỉ số sẽ dưới 0 (`negative_stats`), `sim_test._check_balance` kiểm mọi dạng.
Skill không gây sát thương / hồi / khiên (buff, trạng thái, triệu hồi: 186 dạng) không có cần `skill`, chỉ có PP. Áp lúc đọc data
(`GameData._apply_balance` → `balance_form`), nên tooltip / bảng chỉ số, địch và bot đều thấy số mới;
`GameData.use_balance(false)` = chỉ số web (`sim_test`). Vai trò (`UnitRoles`) suy từ chỉ số **web** (`GameData.web_stat`) nên
cân bằng không đổi vai trò. `version` = bước đã ghi, worker ghi vào `meta_W.tsv` (`balance`). Bảng đọc được:
**`build/bot/balance_stats.tsv`** (mỗi dạng: HP / ATK / DEF / SPE_DEF / SPEED / PP web → sau cân bằng, sức mạnh skill). Huỷ: xoá mục;
`python tools/bot/autobalance.py --reset` (về chỉ số web) / `--restore <version>` (bản cũ trong `build/bot/balance_v<n>.json`).

**Mục tiêu** (sửa tay): **`tools/bot/balance_targets.json`** — `casts` (số lần dùng skill TB mỗi trận khi không cầm item, theo
vai trò: caster 3, support 2,5, tank / fighter / assassin 2, marksman 1,5, cho một trận `refFight` = 16 s — lô có trận ngắn hơn thì
mục tiêu × độ dài TB / 16), `webPP` (giữ một phần khác biệt maxPP của web:
mục tiêu × (100 / maxPP web)^0,5, kẹp `castRange` [1, 4]), `castsWithItems` (tối đa khi cầm 2+ item: 6), `ppStep` / `ppFreeze`,
`roleProfile` (khoảng q = ln(D / T) của vai trò: tank ≤ −0,25, carry ≥ +0,15, fighter ±0,3), `supportSustain` (support:
ln(S / D) ≥ 0,4), `skillShare` (phần đầu ra từ skill: caster ≥ 55%, support ≥ 50%, marksman ≤ 50%), `castsP99` (1% trận nhiều nhất ≤ 10 lần), `roleStrength` / `roleStep`, `rarityGap` (0,03 log-odds mỗi bậc hiếm), `itemWeight` (1,5),
`damageRange` (khoảng ln của sát thương so với cùng vai trò, theo vai trò: fighter / assassin / marksman / caster ±0,2 ≈
×0,82..×1,22; tank / support chỉ phía trên — gây ít là đúng việc), `damageItemWeight` (phần của lệch khi có item: 0,5),
`damageStrength` / `damageStep` (0,5 phần vượt, tối đa 0,1 mỗi bước).

**Một bước**: `python tools/bot/autobalance.py <các lô chơi với balance hiện tại> [--rate 0.5] [--explore 0.03] [--min 60]
[--step 0.1] [--sens S] [--dry]` (~3 phút cho 60 nghìn trận; lô cần `units_*.tsv` có `ppgain`; `--dry` ghi
`balance_step.dry.tsv` / `balance_report.dry.txt`, không đè bản của bước thật):
1. **Sức mạnh có / không item**: mô hình thắng fit **chỉ trên các lô đó**, **bỏ đặc trưng hệ** (nên giá trị gồm cả phần hệ con
   đó mang lại) và có `ui:<dạng>` (số item dạng đó cầm): `u:` = giá trị khi không item, `ui:` = mỗi item thêm bao nhiêu trên
   nó. Lệch = lệch không item + `itemWeight` × lệch của phần item, so với TB nhóm cùng độ hiếm + sao + số dạng của họ. Nhiễu:
   fit lại trên hai nửa run → độ tin cậy (Spearman–Brown) → co độ lệch (riêng cho phần item).
2. **Độ hiếm**: giá trị tổng (`u` + `pw` × giá / 10 + `n3`) TB theo (độ hiếm, sao); trong mỗi mức sao, các độ hiếm shop phải
   tăng dần, mỗi bậc ít nhất `rarityGap` (hồi quy đẳng biến có trọng số) — nhóm vi phạm dịch cả nhóm.
3. **Độ mạnh cần đổi**: ln P −= rate × lệch / độ nhạy (đo trên một bước trước cùng phương pháp mà sức mạnh đổi còn PP gần như
   không, không thì max(proxy tiến hoá, 0,6)); chia phần công / thủ theo vai trò (tank 30% công ... carry 70%) và theo chỗ con
   đó hơn / kém nhóm.
4. **Vai trò** (`units` đội người chơi): D = sát thương gây ra, T = sát thương nhận, S = hồi + khiên, mỗi số so với phần chia đều
   của đội. q = ln(D / T) ngoài khoảng `roleProfile` → dịch một phần công sang thủ (tank gây quá nhiều) hoặc ngược lại (carry
   chịu đòn như tank), **không đổi sức mạnh**; support gây sát thương quá nhiều → ATK xuống, hồi / khiên quá ít → skill lên.
4b. **Sát thương so với cùng vai trò, không item / có item** (người dùng 2026-11-21): mỗi trận của một con (đội người chơi;
   wave địch có boss / hệ số chỉ số nên không dùng) so với TB sát thương của **các con khác** cùng vai trò, cùng sao, cùng số
   item và cùng dải 5 stage (bỏ chính nó ra: con dùng nhiều không tự kéo TB về mình) → chỉ số = Σ sát thương / Σ TB đó (×1 =
   như đồng vai trò), tính riêng trận **không item** và trận **có item**. Trừ trung vị của độ hiếm (×k / (k + 5) với k dạng:
   độ hiếm ít dạng gần như không trừ) để con hiếm hơn vẫn được gây nhiều hơn; co theo độ tin cậy hai nửa run (~0,98: sát
   thương đo rất ổn). Lệch dùng = (1 − `damageItemWeight`) × lệch không item + `damageItemWeight` × lệch có item; ngoài
   `damageRange` của vai trò → dịch `damageStrength` phần vượt (tối đa `damageStep`) giữa công và thủ, **không đổi sức mạnh**
   (sức mạnh là việc của bước 1). Báo cáo: mục `== Damage against the same role` (mỗi vai trò: số dạng ngoài khoảng, cao / thấp
   nhất, con có item gây hơn / kém hẳn khi không item, skill mùa); `balance_step.tsv` cột `dmg_none` / `dmg_items` (chỉ số),
   `n_dmg_*`, `dmg_dev`, `sigma_dmg`.
   **Skill mùa tách riêng** (cả bước 1–5): trong run của một mùa, dạng được mùa đó cho skill khác (`data/season_skills.json`)
   thành `<dạng>@<mùa>` (sàn của stages + units) — có giá trị / sát thương / số lần cast riêng trong báo cáo, **không bị cân**
   (chỉ số của nó là của dạng gốc); dạng gốc chỉ đo bằng skill web.
5. **Số lần cast → PP**: PP nhận mỗi trận (`ppgain`) của các trận không item (cả hai đội) → PP cho số lần mục tiêu (× độ
   dài trận / `refFight`, chia hệ số tự hiệu chỉnh `cast_calibration`: nhịp cast đo được / nhịp bước trước dự đoán; một lần
   cast thay một đòn đánh: mất `perAttack` PP của vai trò); cầm 2+ item thì tối đa `castsWithItems`; dạng ít data (hoặc chưa
   lô nào chơi) theo trung vị thay đổi PP của vai trò. PP thật (hàng chục) đổi quá `ppFreeze` → bước đó không đổi sức mạnh /
   vai trò của dạng đó (đo lại khi số lần cast đã đổi).
6. **Skill / đòn tay** (người dùng 2026-11-19: "xem xét thêm damage của skill, sát thương tay, chỉ số scale cho skill"):
   chỉ số mỗi skill scale theo đọc từ `data/abilities.json` (damage / heal / shield × AP trừ `no_ap`, × `stat` / `plus_stat`,
   buff × `scale_stat`) và code của skill trong `src/core/ability_scripts.gd` (`hit()` = AP; đọc `c.atk` / `c.def` /
   `c.spe_def` / `c.max_hp` / `c.speed`, cả hàm phụ nó gọi): 978 dạng skill theo AP, 94 theo AP + ATK, 6 chỉ ATK, 101 không theo
   AP / ATK (cột `scales` của `balance_step.tsv`, để đọc). Phần sức mạnh skill của bước đổ vào **sức mạnh skill** (`skill`:
   × sát thương / hồi / khiên của skill, theo chỉ số nào cũng vậy; từ 2026-11-20, trước đó là AP gốc nên âm khi < 1) nếu skill
   có gây sát thương / hồi / khiên (`skill_output`: 992 dạng), không thì cả phần công vào đòn đánh (186 dạng: skill chỉ buff /
   trạng thái / triệu hồi, chỉ cân qua PP). `skillShare` của vai trò (phần đầu ra từ skill so với skill + đòn tay: caster ≥
   55%, support ≥ 50%, marksman ≤ 50%) ngoài khoảng → dịch giữa ATK / tốc đánh và sức mạnh skill, cùng sức công. Báo cáo: tỉ lệ
   đòn tay / skill theo vai trò, đầu ra mỗi lần cast, dạng skill to nhất.
7. **Chia vào chỉ số**: thủ = HP, DEF, SPE_DEF (một hệ số; giáp tính theo tỉ lệ sát thương vật lý / phép mà nó nhận), công =
   ATK + tốc đánh (2 : 1, tốc đánh = 0,4 + 0,007 SPEED) và chỉ số skill scale, theo tỉ lệ đầu ra đến từ đòn đánh thường
   (`adealt` / (`adealt` + `sdealt` + `ssus`)). Mỗi chỉ số tối đa ±10% mỗi bước (PP: `ppStep`), hệ số trong [0,5; 2] (SPEED
   [0,6; 1,6], skill [0,3; 2,5], PP [0,2; 2,5]).
8. Ghi `balance_step.tsv` (mỗi dạng: nhóm, vai trò, giá trị, mục tiêu độ hiếm, lệch không item / item, D / T / S / q, số lần
   cast lúc này / có item / mục tiêu / dự đoán sau bước, PP trước → sau, `step_<chỉ số>`; thêm dòng `synergy` / `item` của mô
   hình đủ đặc trưng — **chỉ để xem**), **`balance_report.txt`** (bảng dưới), `build/bot/balance_stats.tsv`, một dòng
   `build/bot/balance_history.tsv`.

`balance_report.txt` của mỗi lô trả lời các câu hỏi của người dùng: **số lần cast** theo vai trò × 0 / 1 / 2+ item (TB, % trận
không cast, mỗi 10 giây còn sống) và mục tiêu; **vai trò** (D / T / S / q của mỗi vai trò, số dạng ngoài khoảng, dạng công /
thủ nhất); **item** (dạng hưởng nhiều / ít nhất mỗi item, mạnh hơn nhóm khi không item / khi 3 item); **thứ tự độ hiếm** (giá trị
TB → mục tiêu); **chiến thuật** (tỉ lệ thắng so với TB của stage: 2 hệ chính, carry = con cầm nhiều item nhất, carry + bộ item,
2 hệ + carry, độ lệch giữa các carry); **cấu trúc đội hình** (T tank / F fighter / C carry / S support: cân bằng, không tank,
không carry, 1 carry + ≥2 support, ≥3 support, các dạng hay gặp).

**Vòng lặp**: `tools\autobalance.bat -Iterations 3 -Runs 250 -Workers 12` (Bash tool: `powershell -NoProfile
-ExecutionPolicy Bypass -File tools/autobalance.ps1 ...`) — mỗi vòng: lô `build/bot/bal_v<version>` (styles `pro,synergy`,
4 mùa, normal, pass all, `-NoLearn`; 12 × 250 run ≈ 15 phút) → một bước (`-Rate 0.5 -Explore 0.03`) → train lại mô hình
của bot pro (`--all`). `-Dry`: một lô, in bước, không ghi.

Kết quả (`build/bot/balance_history.tsv`; `balance_step.tsv` + `balance_report.txt` trong lô của mỗi bước):

| Bước | Data | Cách | Kết quả |
|---|---|---|---|
| v0 → v1 | mọi lô cũ (b2000, pro1–3, design): 148 663 trận | bản đầu: một hệ số mỗi dạng + hệ số theo hệ | 608 thay đổi |
| v1 → v2 | `bal_v1`: 1 200 run (pro + synergy), 26 258 trận | như trên; bước rất nhỏ (lỗi tham số) | 186 thay đổi |
| v2 → v3 | `bal_v2`: 1 200 run, 26 288 trận | chỉ số riêng từng con (HP / ATK / skill; hệ số theo hệ gộp vào thành viên), rate 0,5 | tin cậy 0,38; 394 dạng đổi |
| v3 → v4 | `bal_v3`: 2 750 run, 60 940 trận; **maxPP riêng (web)** | phương pháp 4; bước **PP** (dạng có PP đổi nhiều thì chưa đổi sức mạnh) | PP TB 100 → 30–50 (1 166 dạng); 44 dạng đổi sức mạnh |
| v4 → v5 | `bal_v4`: 3 000 run, 66 589 trận; PP của hiệu ứng theo thanh 100 PP | đủ tiêu chí (dạng có PP thật đổi > 35% thì chưa đổi sức mạnh), rate 0,5 | tin cậy 0,70; PP 1 082 dạng (một nấc nữa), sức mạnh 296, công ↔ thủ 168 |
| v5 → v6 | `bal_v5`: 1 800 run, 39 951 trận; sát thương skill tách riêng (`sdealt`) | + skill / đòn tay, đúng chỉ số skill scale, mục tiêu cast theo trận 16 s, tự hiệu chỉnh dự đoán | tin cậy 0,63; PP 189 dạng, sức mạnh 437, công ↔ thủ 237 (tank → thủ 89, carry → công 92), skill ↔ đòn tay 38 |
| v6 → v7 | `bal_v6`: 3 000 run, 67 326 trận; sát thương không phần thừa | vòng lặp (`tools/autobalance.ps1 -Iterations 3 -Runs 250`), độ nhạy đo từ bước trước: 0,70 | lệch 0,092; tin cậy 0,66; 736 thay đổi |
| v7 → v8 | `bal_v7`: 3 000 run, 67 703 trận | độ nhạy 0,35 | lệch 0,067; tin cậy 0,58; 734 thay đổi |
| v8 → v9 | `bal_v8`: 3 000 run, 67 721 trận | độ nhạy 0,82 | lệch **0,050**; tin cậy 0,58; 715 thay đổi |

**Vòng lặp 2026-11-19 (v6 → v9, 3 bước × 3 000 run)**: độ lệch giá trị các dạng (lệch dùng để cân, TB theo số lần lên sàn)
0,099 → 0,092 → 0,067 → **0,050**; độ lệch giữa các hệ của bot `synergy` 0,033 → 0,030 → 0,028 → 0,028; giữa các carry (sd tỉ
lệ thắng) 0,095 → 0,091 → 0,098 → 0,087. Lô `bal_v8` (balance v8): trận 13,2 s; số lần cast khi không item tank 1,55, fighter
1,70, assassin 1,50, marksman 1,43, caster 2,12, support 2,14 (mục tiêu ở trận 13,2 s: 1,6 / 1,6 / 1,6 / 1,2 / 2,5 / 2,1);
**tank gây 0,87 / nhận 1,15 phần đều** (v5: gây 1,19), carry gây 1,15–1,22. Còn lại: đội nhiều tank vẫn thắng nhiều nhất (5
tank +9,6%, 0 tank −8%; tank giờ đáng giá vì sống dai, không phải vì sát thương), support vẫn yếu (1 support −7%, 2 support
−19%), 3★ hiếm hơn vẫn yếu hơn 3★ COMMON (nhóm nhỏ, chưa xếp); mạnh nhất: carry Spiritomb +21%, 2 hệ Normal + Sound +18%.

**Số lần dùng skill mỗi trận** (TB, cả hai đội, trận ~16 s; trong ngoặc: % trận không cast lần nào):

| Vai trò | v3 (maxPP web), 0 item | v3, 2+ item | v4, 0 item | v4, 2+ item | v5, 0 item | v5, 2+ item | mục tiêu (trận 16 s) |
|---|---|---|---|---|---|---|---|
| tank | 0,95 (31%) | 1,41 (17%) | 1,45 (17%) | 2,08 (8%) | 1,63 (20%) | 2,42 (7%) | 2 |
| fighter | 0,72 (39%) | 1,05 (26%) | 1,41 (13%) | 1,90 (8%) | 1,69 (10%) | 2,28 (6%) | 2 |
| assassin | 0,52 (55%) | 1,13 (25%) | 1,56 (13%) | 2,25 (5%) | 1,71 (11%) | 2,37 (5%) | 2 |
| marksman | 0,74 (43%) | 1,08 (26%) | 1,24 (17%) | 1,76 (9%) | 1,40 (14%) | 1,90 (8%) | 1,5 |
| caster | 0,48 (56%) | 0,80 (37%) | 1,77 (8%) | 2,17 (9%) | 2,14 (5%) | 2,68 (7%) | 3 |
| support | 0,68 (39%) | 1,18 (22%) | 2,14 (3%) | 3,11 (2%) | 2,15 (4%) | 2,66 (2%) | 2,5 |

Trước đó (maxPP theo vai trò 70 / 100 / 120, lô `bal_v2`): TB 0,63 lần mỗi trận khi không item, 128 / 356 dạng không cast lần
nào trong hơn nửa số trận — **không hợp lý** (bản web: ~2–3 lần mỗi trận nhờ +10 PP mỗi giây). Hạ maxPP thì các hiệu ứng PP
cố định (hệ Water +4 / 8 / 12 mỗi giây, Aqua Egg, Soul Dew...) mạnh gấp 2–3 lần (Swampert cầm Aqua Egg cast 53 lần một trận) →
từ 2026-11-19 PP của hiệu ứng tính theo thanh 100 PP của web (`BattleUnit.add_pp`, `docs/DIFFICULTY.md`).

Trận ngắn dần khi skill ra nhiều hơn (TB 16,4 s ở v3 → 14,2 s ở v4 → 13,2 s ở v5), nên mục tiêu là số lần trong một trận 16 s
(`refFight`: ở lô 13,2 s mục tiêu × 0,82) — đuổi theo số lần mỗi trận thì PP bị hạ mãi (bản v6 đầu tiên đã hạ tiếp xuống
~20 cho mọi vai trò; đã huỷ, tính lại). Dự đoán số lần cast từ `ppgain` lạc quan 5–20% (`casts_after` của bước trước so với lô
sau, theo nhịp: `cast_calibration` tự bù). Có item: một item thêm nhiều lần cast nhất Deep Sea Tooth +0,98, King's Rock +0,89,
Aqua Egg +0,88; Flame Orb −0,39. **Sát thương ghi trong TSV là sát thương thật mất** (không tính phần thừa) từ 2026-11-19
(meta `damage effective`): trước đó đòn kết liễu (Crabhammer, Sheer Cold: 9 999) thổi phồng sát thương của Crawdaunt /
Corphish / Poliwrath / Abomasnow lên 2 000–3 300 mỗi lần cast — với lô cũ tool bỏ qua tiêu chí vai trò của các skill kết liễu.

**Skill / đòn tay** (lô `bal_v5`, còn tính phần thừa của đòn kết liễu): phần đầu ra từ đòn đánh thường so với skill — tank 22% / 78%, fighter 32 / 68, caster 36 / 64,
assassin 39 / 61, support 48 / 52, marksman 62 / 38; đầu ra mỗi lần cast TB: tank 83, assassin 43, fighter 41, caster 32,
marksman 30, support 24. Skill theo AP: 978 dạng, AP + ATK 94, chỉ ATK 6, không theo AP / ATK 101.

Độ lệch giữa các hệ của bot `synergy` (`#syn_spread`): v3 0,031 → v4 0,030 → v5 0,033 (hai bước đầu chủ yếu là chỉnh PP;
tiêu chí sức mạnh / vai trò áp mạnh từ v6). Stage TB 22,2 ở cả ba lô (pro 23,3–23,7).

**Phát hiện** (lô `bal_v3`, balance v3; cùng xu hướng ở `bal_v2`):
- **Tank gây sát thương nhiều nhất** trong mọi vai trò: so với phần chia đều của đội, tank gây 1,20 / nhận 1,13; marksman
  1,03 / 0,91; caster 0,99 / 0,83 (caster hầu như không cast). 140 / 273 dạng tank ngoài khoảng `roleProfile` (Crawdaunt gây
  5,6 lần phần đều — nhãn tank do họ có giáp cao).
- **Đội xếp tank áp đảo** (stage ≥ 10, tỉ lệ thắng so với TB của stage): 0 tank −12%, 1 tank −4%, 4–5 tank +4%; 1 carry +4,6%
  → 5 carry −9%; 1 support −10%, 2 support −18%; không tank / fighter −33%; sát thương chia đều (con gây nhiều nhất ≤ 30%)
  +4,8%, một con gánh > 60% +2,4%. "1 carry + ≥ 2 support" chỉ 43 trận (−20%) — bot ít dựng, cần design test bản 2.
  Ở v5 (`bal_v5`) vẫn vậy: 5 tank +7,4%, 0 tank −7,3%, 5 carry −5,3%, 2 support −23% — tiêu chí vai trò dịch ±10% mỗi bước.
- **Độ hiếm đảo**: 1★ RARE yếu hơn 1★ COMMON, 2★ ULTRA yếu hơn 2★ RARE, 3★ RARE yếu hơn COMMON (giá trị tổng TB).
- **Item**: phần mỗi item thêm khác nhau ít giữa các dạng (±0,07 log-odds, tin cậy 0,14) — chưa có carry "ăn item" vượt hẳn.
- Hệ (mô hình đủ đặc trưng, chỉ để xem): Poison +1,38 (rất mạnh), Fighting +0,45, Fire +0,28; yếu Baby −0,72, Flying −0,71,
  Flora −0,68, Gourmet / Light −0,56.

Bài học / giới hạn:
- Giá trị **từng dạng** từ một lô vài nghìn run còn nhiều nhiễu (tin cậy 0,4–0,5) → co mạnh, giảm chấn 0,5; phần **item** của
  từng dạng còn nhiễu hơn (tin cậy ~0,1–0,3).
- **Độ nhạy**: proxy từ tiến hoá thấp hơn tác dụng thật; đo lại từ lịch sử chỉ dùng bước cùng phương pháp mà PP gần như không
  đổi (PP đổi thì số lần cast đổi giá trị).
- Chỉ có đòn bẩy chỉ số Pokémon: hệ mạnh vì **hiệu ứng** hệ thì các thành viên của nó bị giảm chỉ số (cả khi chơi lẻ không kích
  hệ) — muốn giữ chỉ số mà vẫn cân hệ thì phải sửa hiệu ứng hệ bằng tay (dòng `synergy` trong `balance_step.tsv` chỉ hướng).
- Hệ "cơ chế" (Light, Baby, Flying, Fairy, Flora, Gourmet) yếu một phần vì bot chưa khai thác hết cơ chế → các Pokémon của
  chúng có thể bị buff oan; xem lại bằng tay hoặc dạy bot dùng cơ chế rồi cân tiếp.
- Vai trò suy ra (`UnitRoles`) còn nhãn sai (một số "tank" thực ra là carry vật lý, Flabébé...) — tiêu chí vai trò sẽ kéo
  chúng về nhãn; sửa nhãn trước nếu thấy dạng nào bị đổi sai bản chất.
- Bot pro dùng mô hình train `--all` (cả data của balance cũ) → còn "nhớ" chỉ số cũ một thời gian.
- Item chưa có đòn bẩy riêng (dòng `item` trong `balance_step.tsv` chỉ để xem).

## Kiểm tra 2026-11-21: balance v9, sàn lục giác, mùa 1 có skill / hệ riêng

Lô `build/bot/design_s1_v9` (design test s1 ở **classic** — không truyền `-Diffs` thì bot dùng mức lưu trong cài đặt của
người chơi; 1 308 run, 3 run mỗi cặp) và `build/bot/bal_v9` (lô chuẩn của tự cân bằng: normal, pass all, pro + synergy, 4 mùa,
3 000 run, 28 phút) + bước thử `autobalance.py --dry` (`balance_report.dry.txt`, **chưa áp**); bảng mùa `season_s1.tsv`
(`season_report.py`) trong mỗi lô. 0 run dừng vì lỗi script (dòng "6 resources still in use at exit" có từ trước).
- Chung (normal): stage TB không mùa 21,2 / s1 22,3 / s2 22,3 / s3 22,9 (v8: 21,4 / 22,7 / 23,3 / 22,9); trận 14,2–15,1 s;
  thời gian thật mỗi stage như nhau ở mọi mùa (s1 269 ms = không mùa) → code mùa không tốn thêm (chậm hơn v8 157–188 ms là
  do sàn lục giác). Lệch giá trị các dạng 0,067 (bước v8 → v9: 0,050); số lần cast gần mục tiêu, s1 cast nhiều hơn các mùa khác
  (caster 2,78 / 2,3–2,4, fighter 2,02 / 1,7).
- **Hệ mùa 1 lệch hơn hệ web**: sd `adj` giữa các hệ 0,052 (bỏ trận có dòng Bulbasaur, hệ ≥ 300 trận) so với 0,033–0,036 ở
  không mùa / s2 / s3. Bỏ trận có dòng Bulbasaur / Moltres, TB normal + classic: mạnh Electric +0,08 (mốc 2: +0,13–0,15),
  Sound +0,06, Dragon +0,05; yếu Grass −0,08 (`seed_drain`), Water −0,06, Fighting −0,05, Artificial / Aquatic −0,05, Monster /
  Psychic / Human / Flying / Steel / Ground / Ice −0,03 … −0,04. Flora / Baby / Gourmet ít trận (Flora s1 gần như chỉ có dòng
  Bulbasaur).
- **Giga Drain** (dòng Bulbasaur, 10 PP): cast 4,2–4,8 lần mỗi trận, D 2,8–3,0 (caster 1,3), adj +0,21 (cùng dạng dùng Magical
  Leaf ở mùa khác: 0,00); có mặt ở 9,7% trận s1 và trong **cả 9 run s1 tới stage ≥ 40** (normal). Flora / Grass / Poison mạnh
  chỉ nhờ nó.
- Nguyên nhân chung: PP của skill mùa = `pp` của luật × tỉ lệ PP mà tự cân bằng đã chỉnh cho **skill web** của dạng đó →
  Bulbasaur (PP bị hạ xuống sàn vì Magical Leaf yếu) có Giga Drain 10 PP; skill mượn mang maxPP web của chủ cũ → PP cao hơn:
  Electro Web (Shinx 57 / web 39) không cast ở 35–66% trận, Pickup (Linoone 90) 20–41%, Fire Blast (Ponyta 40 / 25) 29%,
  Magnet Rise / Parry / Strength Sap 20–33%. Cast ≥ 4 lần mỗi trận: Shift Gear (8 PP, đầu ra thấp, adj −0,14), Helping Hand,
  Mirror Coat, Disguise Patch, Entrainment.
- So với skill web của cùng dạng (D): mạnh hơn Giga Drain, Tidal Push, Life Dew, Primal Chill; yếu hơn nhiều Sky Attack
  (1,6 / 3,2), Baton Pass (0,5 / 2,1), Anchor Shot, Mirror Coat, Mind Link, Supreme Overlord. Skill hỗ trợ / debuff (Will-O-Wisp,
  Electro Link, Guard Dog, Toxic Spikes, Spite) gây ít là đúng vai, adj gần 0.
- Bước tự cân bằng thử (bản đầu) sẽ hạ chỉ số Ivysaur (+0,76 so với nhóm) / Bulbasaur (+0,28) **ở mọi mùa** vì Giga Drain chỉ
  có ở s1. Đã sửa (cùng ngày): skill mùa tách thành `<dạng>@<mùa>` (bước 4b) → lệch giá trị 0,067 → **0,052**, Ivysaur /
  Bulbasaur không còn bị hạ; skill mùa vẫn **chưa có đòn bẩy riêng** (PP / sức mạnh theo (mùa, dạng)) nên chỉ được báo cáo.
- Sát thương so với cùng vai trò (bước 4b, `balance_report.dry.txt`): độ lệch giữa các dạng sd 0,23 (caster) … 0,35 (tank);
  ngoài khoảng: tank 57 / 228 (gây như carry: Girafarig ×3,1, Snover ×3,2, Munchlax ×2,9), fighter 56 / 120 (Carvanha ×2,3,
  Hisui Voltorb ×2,3; thấp: Goomy ×0,3), marksman 39 / 93 (Salandit ×1,6; Comfey ×0,08), caster 17 / 49; bước thử dịch 153
  dạng (92 về thủ, 62 về công; 66 / 67 dạng cũng bị tiêu chí vai trò dịch thì cùng chiều). Skill mùa cao nhất: Giga Drain
  (`BULBASAUR@s1` ×3,2 không item / ×3,7 có item; Magical Leaf của web ×1,1 / ×1,0), Smack Down (Dwebble ×3,0), Earthquake
  (Gible ×2,5); thấp nhất là skill hỗ trợ (Spite, Toxic Spikes, Electro Link, Guard Dog ×0,2–0,4).
- Có từ trước, không do mùa: Bonsley / Stonjourner / Sudowoodo không đánh đòn nào ở 40–60% trận (lô v8 cũng vậy).

## Việc tiếp (phiên sau)

- **Tự cân bằng**: chạy tiếp vòng lặp (`tools\autobalance.bat -Iterations 5 -Runs 250 -Workers 12`, ~1,5 giờ) cho tới khi
  số lần cast gần mục tiêu, hồ sơ vai trò vào khoảng (tank dịch ±10% mỗi bước) và độ lệch giữa các chiến thuật / carry nhỏ
  lại (`balance_report.txt` mỗi lô, `balance_history.tsv`, khối `#syn_spread` của `report.py`); thêm đòn bẩy cho **item**;
  dạy bot dùng cơ chế (phân bón, vé, xếp theo địch) để Pokémon của hệ cơ chế không bị buff oan.
- **Design test bản 2** (người dùng 2026-11-19): chơi thử mọi tổ hợp đội hình (carry × bộ item × hệ × cấu trúc vai trò:
  tank + xạ thủ + pháp sư, 1 carry + nhiều support buff, toàn support...) và **đánh giá đội hình với nhau** (đấu trực tiếp /
  xếp hạng) — bot hiện ít dựng "1 carry + ≥ 2 support" (59 trận ở `bal_v4`), nên chưa đo được tương quan đó.
- Mô tả skill / item vẫn ghi số PP của web (+50 PP...): trong trận là phần của thanh 100 PP (`BattleUnit.add_pp`) — cần ghi
  chú trong tooltip nếu người chơi thấy lệch. Nhãn vai trò suy ra còn sai vài dạng (Crawdaunt / Corphish, Abomasnow / Snover
  là "tank" nhưng gây 4–6 lần phần đều) — tiêu chí vai trò đang kéo chúng về tank; cần bảng ghi đè vai trò nếu muốn khác.
- **Tracking hiệu quả buff** (người dùng, 2026-11-18): sát thương tăng / giảm của Pokémon được buff sau khi buff, khiên, hiệu
  quả hồi máu / PP khi được buff... (hiện skill chỉ buff / gây trạng thái đo ra 0; cần gắn nguồn buff vào event `buff` /
  `shield` / `heal` và đo sát thương của người được buff trước / sau).
- ~~Sát thương skill tách khỏi passive / item~~ (xong 2026-11-19: cột `sdealt` / `ssus`); còn: sửa nhãn vai trò sai
  (Flabébé, Comfey, Pokémon chậu hoa, các "tank" gây sát thương lớn) — đo cho chuẩn rồi chạy lô 10 000 run.

## Luật dùng chung với game

`src/core/run_rules.gd` (`RunRules`): máu mất khi thua, phần thưởng wave, trả lời lựa chọn thị trấn, tự chọn khi vào trận —
`Game` và bot cùng gọi. Vòng stage (`Game._ready / _start_planning / _start_fight / _end_fight / _next_stage`) được
`tools/bot/bot_run.gd` (`BotRun`) chép lại: **đổi vòng stage của Game thì sửa BotRun theo**.

## Kết quả lô b2000 (2026-11-18: 2004 run, normal, pass all, s1 / s2 / s3 / all, 12 worker, 535 s)

Dữ liệu: `build/bot/b2000` (`report.tsv`, `balance.tsv`). Bot chết chủ yếu ở stage 15–24 (TB 19–21.5; không mùa 19).
- Wave giết nhiều: boss `tower_duo` (st 19, 240 run), `tpl:steel_wall` (st ~15, thắng 25%), `tpl:fire_raid` (st ~13),
  boss `legendary_birds` (st 24, thắng 8%), `legendary_beasts` (st 29, thắng 5%).
- 1 run (s2, econ) sống tới stage 87: từ ~40 thắng gọn (địch 0, ta 10–13 con) → Endless không tăng độ khó kịp một đội mạnh.
- Pokémon mạnh so với cùng giá (n ≥ 300): Frosmoth, Houndour, Sizzlipede, Spinarak, Sharpedo; Crabhammer (Corphish /
  Crawdaunt / Poliwrath) kết liễu < 30% máu → sát thương khổng lồ với boss. Yếu: Spearow, Doublade, Latias, Floette (mọi màu).
- Hệ: dễ + mạnh Fossil, Bug, Fire, Fighting, Rock, Ghost, Human; mạnh nhất Poison (+13 điểm, mốc 2 +21) / Dark / Electric;
  khó + yếu Baby (nhắm mà tới mốc 1 chỉ 24%), Gourmet; yếu Wild, Amorphous, Fairy, Light (dễ tới mốc 2 nhưng ~0) — các hệ
  cơ chế (Light, Gourmet, Baby, Flora, Wild, Fairy) có thể yếu vì bot chưa dùng cơ chế.
- Item: Shiny Charm / Max Revive / Smoke Ball +27–29 điểm thắng (+45% sống sót) — vượt xa phần còn lại (+4 là cao); yếu
  trong item chiến đấu: Safety Goggles, Choice Specs, Aqua Egg, Reaper Cloth, Gracidea, Wide Lens.
- Vai trò: tank nhận ít đòn hơn fighter (18% vs 24% sát thương đội nhận), sống sót thấp nhất (23%), hiếm khi dùng skill
  (100 PP); nhãn sai: Flabébé (Fairy Wind gây sát thương mà gắn support), Comfey, Pokémon chậu hoa.
- Hạn chế đo: `skill_out` gồm cả sát thương passive / item / kết liễu; skill chỉ buff / trạng thái đo ra 0.
