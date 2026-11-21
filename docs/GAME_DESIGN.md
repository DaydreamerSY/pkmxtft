# Game Design Document — pkmxtft (PAC Endless trên Godot)

Cập nhật: 2026-09-30 • Phiên bản tài liệu: 1.1 • Engine: Godot 4.7 (Mobile renderer)

Tài liệu này mô tả **trò chơi** (luật, hệ thống, nội dung, giao diện) ở trạng thái hiện tại của project.
Chi tiết triển khai từng phần nằm ở `docs/PORTING.md`; việc đang làm dở ở `docs/HANDOFF.md`;
định dạng dữ liệu skill ở `docs/ABILITIES.md`; **độ khó, wave địch và template wave ở `docs/DIFFICULTY.md`**;
**bảng tra thời tiết và từng vùng ở `docs/WORLD.md`**. Mọi con số dưới đây lấy từ `data/pac/config.json`
và code trong `src/core` — khi cân bằng thay đổi ở bản web rồi export lại, số trong file này cần cập nhật theo.

---

## 1. Tổng quan

| | |
|---|---|
| Tên làm việc | **pkmxtft** |
| Thể loại | Auto-battler một người chơi, roguelike theo run (chế độ *Endless*) |
| Nền tảng | PC (Windows) và Android (preset `export_presets.cfg`, APK debug; chạm = chuột trái, chạm giữ = chuột phải) |
| Thời lượng một run | tới khi hết 100 máu (ước tính 20–40 phút, chưa đo) |
| Nguồn gốc | Port chế độ Endless offline của *pokemonAutoChess* (bản web mã nguồn mở, fork offline ở `D:\Python\PKM Autobattle\pokemonAutoChess`) |
| Ngôn ngữ | 14 ngôn ngữ, tiếng Việt viết đầy đủ |

**Câu mô tả**: xây đội Pokémon trên lưới lục giác 7×8, mua – gộp – gắn item giữa các trận, rồi xem đội tự đánh với các
bầy Pokémon hoang dã và boss mạnh dần, đi được càng xa càng tốt.

### Trụ cột thiết kế

1. **Luật của PAC, dáng vẻ của TFT.** Giữ nguyên luật, công thức và lưới ô vuông của pokemonAutoChess; trình bày
   theo Teamfight Tactics: camera 3D nghiêng, HUD bố cục TFT, tooltip mở cạnh phần tử.
2. **Một người, không chờ đợi.** Không có đối thủ người, không đồng hồ ép buộc: pha chuẩn bị kết thúc khi người chơi
   bấm *Fight!*; trận có thể tua x2 / x4.
3. **Chiều sâu từ tổ hợp.** 31 hệ (synergy), 548 skill, hơn 350 item, 13 thời tiết, 144 vùng — mỗi run ghép một bài khác.
4. **Đọc được mọi thứ.** Mọi con số, vùng ô của skill, công thức item đều xem được bằng hover / chuột phải.
5. **Dữ liệu sinh từ nguồn.** Nội dung (Pokémon, item, chữ, sprite, âm thanh) export tự động từ bản web; bản Godot chỉ
   viết lại luật.

### Phạm vi

- Có: chế độ Endless solo với 3 mức độ khó, menu chính, tuỳ chọn (ngôn ngữ, âm lượng), màn game over, **Battle Pass**
  mở khoá hệ dần qua nhiều run (mục 9.4).
- Không có: nhiều người chơi, bot đối thủ, lobby, tài khoản, bảng xếp hạng, lưu một run đang chơi dở.
- Ghi chú bản quyền: đây là dự án fan phi thương mại dựa trên dữ liệu và hình ảnh của bản web; nhân vật thuộc thương hiệu
  Pokémon. Muốn phát hành thương mại phải thay toàn bộ nội dung có bản quyền.

---

## 2. Vòng lặp chơi

```
Main Menu ──Play──► Game ──hết máu──► GAME OVER ──► Main Menu

Một stage:
  [Thị trấn]  portal / carousel / additional pick / encounter (chỉ ở một số stage)
       │
  [Chuẩn bị]  thu nhập → shop mới → mua, bán, gộp, xếp sàn, gắn item        (không giới hạn thời gian)
       │  Fight! / Space
  [Trận đấu]  hai đội tự đánh, tối đa 45 s, tua x1 / x2 / x4
       │
  [Kết quả]   thắng: phần thưởng của wave  •  thua / hoà: mất máu
       └──► stage kế tiếp
```

- Run bắt đầu ở **stage 0** trong thị trấn: chọn 1 trong 3 portal, rồi chọn Pokémon khởi đầu.
- Mỗi stage người chơi đấu một **wave PvE** (bầy hoang dã hoặc boss). Wave chỉ phụ thuộc hạt giống của run và số stage.
- Thua hoặc hoà: mất `ceil(stage / 2) + số địch còn sống` máu (nhân hệ số của mức độ khó). Hết 100 máu là kết thúc run;
  kết quả = stage đạt được.
- Không có điều kiện thắng: mục tiêu là đi xa nhất có thể.

---

## 3. Sàn đấu và Pokémon

### 3.1 Sàn

- Lưới **7 cột × 8 hàng ô lục giác** đỉnh nhọn, hai hàng liền nhau so le nửa ô (kiểu TFT; web: 8 × 6 ô vuông). 4 hàng
  dưới của người chơi (`y = 0..3`, `y = 3` là hàng đầu), 4 hàng trên của địch. Mỗi ô có 6 ô kề.
- Sàn vẽ như sân đấu Pokémon: nền đất sét sáng, một quả **Poké Ball** lớn vẽ ở giữa sân (nửa đỏ phía địch, nửa trắng
  phía mình, vạch đen giữa sân, vòng trắng quanh), vạch trắng dọc mép hai hàng đầu, đường viền ô mảnh và nhạt.
- **Bench** (hàng chờ): **8 ô, mỗi ô chứa 1–2 con giống nhau** (`benchSize` 8, `benchStack` 2 trong `data/difficulty.json`;
  web: 8 ô × 1 con). Hai bản sao cùng một Pokémon dùng chung một ô (mua / nhận thì tự xếp vào ô đang có một con giống nó);
  bản thứ ba thì gộp tiến hoá như thường. Ô có 2 con chỉ hiện con đầu kèm nhãn **x2** ở góc trước của ô; kéo ra thì lấy một
  con, con còn lại ở yên. Chỉ con đầu được cầm item (con thứ hai không cầm gì); Pokémon khác loại không chung ô — thả lên
  ô của con khác thì hai bên đổi chỗ. Pokémon ở bench không đánh.
- Số Pokémon trên sàn tối đa = **level** người chơi (2 → 9).
- Một Pokémon luôn chiếm đúng một ô, dù sprite to hay nhỏ. Ô đích được giữ ngay khi bắt đầu bước đi.
- Tầm đánh và tìm mục tiêu tính theo khoảng cách lục giác (số bước; tầm 1 = 6 ô xung quanh, tầm 2 = 18 ô; marksman /
  caster tầm 5, mục 3.4). Đường đi qua
  6 ô kề, Pokémon khác là vật cản. Skill theo hướng (tia, nón, đẩy lùi, nhảy ra sau) dùng 6 hướng, lệch ± 60° (web: 8
  hướng, ± 45°).

### 3.2 Chỉ số

| Chỉ số | Ý nghĩa |
|---|---|
| HP | máu; gục khi về 0 |
| ATK | sát thương vật lý mỗi đòn đánh thường |
| DEF / SPE_DEF | giảm sát thương vật lý / phép: `damage / (1 + 0.05 × giáp)` |
| SPEED | tốc đánh: một đòn mỗi `1000 / (0.4 + 0.007 × SPEED)` ms; bước đi `500 / (0.5 + SPEED/100)` ms |
| AP | sức mạnh kỹ năng: +1% sát thương, hồi máu, khiên của skill mỗi điểm |
| PP | năng lượng: đầy thì dùng skill. **PP tối đa riêng từng Pokémon** (2026-11-19: maxPP web × hệ số `pp` của tự cân bằng, làm tròn hàng chục — không theo vai trò nữa). PP nhận được nằm ở `mana` của `data/difficulty.json`, **theo vai trò** (người dùng chỉnh trong wave editor): **Tank +15 mỗi đòn đánh trúng, +5 mỗi lần bị đòn đánh trúng; Đấu sĩ +10 / +10; Xạ thủ / Pháp sư / Hỗ trợ / Sát thủ +10 / +5**; không hồi theo giây; sát thương của skill không cho PP (skill cường hoá đòn đánh thì vẫn tính); mọi Pokémon, cả hai đội, mọi mức độ khó; item / hệ / passive / thời tiết vẫn có PP riêng, **tính theo thanh 100 PP của web** (maxPP 40 → nhận 40% số trong mô tả; hút PP cũng vậy). Bản web: maxPP riêng từng Pokémon, +5 mỗi đòn, +10 mỗi giây, +`ceil(sát thương / 10)` khi bị đánh |
| CRIT_CHANCE / CRIT_POWER | tỉ lệ và hệ số chí mạng (mặc định 10% / x2) |
| SHIELD | khiên, chịu sát thương trước HP |
| LUCK | tăng xác suất các hiệu ứng ngẫu nhiên |
| RANGE | tầm đánh tính bằng ô |

Ba loại sát thương: **vật lý** (giảm bởi DEF), **phép** (giảm bởi SPE_DEF), **chuẩn** (không giảm).

**Tự cân bằng** (chỉ có ở bản này, `data/balance.json`, `docs/BOT.md`): **mỗi Pokémon có chỉ số riêng** — hệ số của từng
chỉ số (HP, ATK, DEF, SPE_DEF, SPEED, **PP tối đa**; HP / PP làm tròn hàng chục) và **sức mạnh skill** (× sát thương / hồi /
khiên của skill riêng của nó, không phải chỉ số: AP vẫn 0; tooltip skill ghi "Hiệu lực kỹ năng: x%") học từ bot, áp lên chỉ số
web; **không chỉ số nào âm** (skill quá mạnh → giảm sức mạnh skill hoặc tăng PP); không có hệ số theo hệ (hệ mạnh được cân qua
chỉ số các Pokémon của nó). Tiêu chí (người dùng 2026-11-19):
làm tròn vai trò / không làm việc khác vai trò, có và không có item không mạnh hơn phần còn lại, hiếm hơn thì mạnh hơn, số
lần dùng skill mỗi trận hợp lý, sát thương skill / đòn tay theo vai trò và đúng chỉ số skill scale; mục tiêu cuối: nhiều
chiến thuật carry + item + hệ, không chiến thuật nào áp đảo. Mục tiêu ở `tools/bot/balance_targets.json`; bảng đủ:
`build/bot/balance_stats.tsv`. Về chỉ số web: `python tools/bot/autobalance.py --reset`.

### 3.3 Độ hiếm, sao và tiến hoá

| Độ hiếm | Giá | Nguồn |
|---|---|---|
| Common / Uncommon / Rare / Epic / Ultra | 1 / 2 / 3 / 4 / 5 vàng | shop |
| Unique | 10 | portal stage 10, Repeat Ball |
| Legendary | 20 | portal stage 20, Repeat Ball |
| Hatch | — | trứng của hệ Baby |
| Special | — | câu cá, Unown, chậu hoa, dạng triệu hồi |

- **3 bản giống nhau gộp thành dạng tiến hoá** (1★ → 2★ → 3★). Ngoại lệ: Magikarp cần 8, Feebas cần 6.
- Con tiến hoá giữ item ghép trước, tối đa 1 mảnh, tối đa 3 item; phần dư về kho.
- **Tiến hoá rẽ nhánh** theo điều kiện: Poliwhirl (đứng hàng đầu → Poliwrath, không thì Politoed), Kirlia (Fighting trội →
  Gallade, không thì Gardevoir), Espurr, Wurmple, Galarian Slowpoke, Flabébé (giữ màu)...
- Tiến hoá đặc biệt: bằng item (Eevee + đá, Kyogre + Blue Orb), theo thời gian (dòng Hatch: 5 stage), theo trạng thái
  (Corsola bị hạ gục → Galarian Corsola), theo số lần dùng skill (Hisuian Qwilfish, 20 lần → Overqwil), theo thời tiết
  (Lycanroc, Ursaluna).
- Bán: nhận lại `giá × số sao` vàng; các bản copy trở về pool.

### 3.4 Vai trò (gợi ý cho người chơi)

Game suy ra vai trò từ dữ liệu để gợi ý vị trí và item: **tank**, **fighter**, **assassin** (cận chiến có lướt),
**marksman**, **caster**, **support**. Vai trò chỉ đổi một luật: **marksman và caster có tầm đánh ít nhất 5** (đứng hàng
sau cùng vẫn bắn tới hai hàng đầu của địch; bản web: tầm của từng Pokémon, phần lớn 2–4). Support và Pokémon cận chiến giữ
tầm của bản web.

---

## 4. Kinh tế

| Luật | Giá trị |
|---|---|
| Vàng / level / máu ban đầu | 5 / 2 / 100 |
| Thu nhập mỗi stage | `goldPerWave` vàng (`data/difficulty.json`, mặc định 5 như web) + lãi `min(vàng / 10, 5)`; +2 XP |
| Lãi tối đa | 5 (+1 mỗi Gimmighoul Coin đang giữ, −1 mỗi Amulet Coin) |
| Đổi shop (Refresh) | 1 vàng • phím `D` |
| Mua XP | 4 vàng = 4 XP • phím `F` |
| Khoá shop | giữ nguyên shop sang stage sau |
| Shop | 6 ô, làm mới miễn phí đầu mỗi stage |

**XP cần để lên level**: 2→3: 2 • 3→4: 6 • 4→5: 10 • 5→6: 22 • 6→7: 34 • 7→8: 52 • 8→9: 72. Level tối đa 9.

**Tỉ lệ độ hiếm trong shop theo level** (Common / Uncommon / Rare / Epic / Ultra, %):

| Level | C | U | R | E | Ultra |
|---|---|---|---|---|---|
| 2 | 100 | 0 | 0 | 0 | 0 |
| 3 | 70 | 30 | 0 | 0 | 0 |
| 4 | 50 | 40 | 10 | 0 | 0 |
| 5 | 36 | 42 | 20 | 2 | 0 |
| 6 | 25 | 40 | 30 | 5 | 0 |
| 7 | 15 | 35 | 35 | 15 | 0 |
| 8 | 11 | 27 | 35 | 22 | 5 |
| 9 | 5 | 20 | 35 | 30 | 10 |

**Pool dùng chung**: mỗi họ có số bản giới hạn theo độ hiếm và số bậc tiến hoá (họ 3 bậc: Common 27, Uncommon 22,
Rare 18, Epic 14, Ultra 10; họ 2 bậc: 18 / 13 / 9 / 7 / 5; không tiến hoá: 1). Mua thì rút khỏi pool, bán thì trả lại.
Trong pool, xác suất ra một họ tỉ lệ với số bản còn lại.

**Nguồn Pokémon trong shop**

- Pool thường: 94 họ (279 dạng).
- **Additional**: 154 họ (Uncommon / Rare / Epic) vào shop lần lượt ở stage 5 / 8 / 11. Banner đầu stage chỉ báo một dòng
  (“51 Pokémon Uncommon đã vào shop”); danh sách đầy đủ (theo stage, kể cả con chọn ở thị trấn, các stage sắp tới và
  Pokémon vùng) ở nút **!** cạnh ổ khoá — nút sáng nhấp nháy tới khi mở xem.
- **Pool vùng**: Pokémon chỉ có ở vùng hiện tại, và biến thể vùng thay cho dạng gốc (mục 9.3).
- Hệ **Wild** chỉ xuất hiện với tỉ lệ nhỏ (6%, +0,5% mỗi sao Wild đang có) ở các stage boss gốc hoặc khi Wild kích hoạt.
- Hệ **Psychic** mở shop Unown; item Incense / Honey / nhạc cụ báu kéo Pokémon cùng hệ vào shop (5% mỗi ô).

---

## 5. Trận đấu

- Mô phỏng thuần logic (`src/core/battle_sim.gd`), chạy theo mili giây, tách khỏi phần hiển thị.
- Mỗi Pokémon lặp: chọn mục tiêu trong tầm → đánh thường, hoặc dùng skill nếu PP đầy → không có mục tiêu thì đi tới.
- Trận tối đa **45 giây**. Ở **giây 35** mọi Pokémon vào trạng thái RAGE: +80 SPEED, gây gấp đôi sát thương, hồi máu và
  khiên nhận một nửa.
- Thắng khi đội địch gục hết. Hết giờ = hoà (tính như thua).
- **Wave địch cũng kích hệ** (mức Thường: từ stage 5; mức Cổ điển: không, như bản web). Hệ của wave hiện trên thanh stage.

### 5.1 Skill

- 548 skill, mỗi Pokémon một skill (dòng tiến hoá dùng chung, mạnh theo sao).
- Skill nhắm theo **vùng ô**: một mục tiêu, 8 ô quanh, bán kính N, hình nón, tia 8 hướng, đường thẳng tới mép sàn,
  các ô giữa hai điểm, cả hàng, cả sàn, N địch gần / xa nhất, ngẫu nhiên...
- Cùng một hàm tính ô dùng cho trận, hiệu ứng nháy ô và sơ đồ trong tooltip — ô hiển thị luôn là ô bị ảnh hưởng.
- Màu nháy: cam = đánh địch, xanh lá = tác động đồng minh, hồng = skill có độ trễ sắp nổ.
- Hiệu ứng sàn (board effect) do skill để lại: EMBER, POISON_GAS, SMOKE, SPIKES, STEALTH_ROCKS, STICKY_WEB,
  COTTON_BALL, STRANGE_STEAM.

### 5.2 Trạng thái

| Trạng thái | Hiệu ứng |
|---|---|
| BURN | 5% HP tối đa sát thương chuẩn mỗi giây; hồi máu giảm một nửa |
| POISONED | 5% HP tối đa mỗi tầng mỗi giây (3 tầng, tới 5 với hệ Poison) |
| FREEZE / SLEEP | không di chuyển, không đánh |
| PARALYSIS | SPEED chỉ còn 50% hiệu lực, không né được |
| SILENCE | không dùng được skill |
| FATIGUE | PP nhận vào giảm 50% |
| ARMOR_BREAK | DEF và SPE_DEF chỉ còn 50% hiệu lực |
| WOUND | không hồi máu |
| FLINCH | 50% sát thương xuyên khiên |
| BLINDED | đòn đánh trượt 50% |
| CONFUSION | một nửa số lần chọn mục tiêu ngẫu nhiên trong tầm, kể cả đồng minh và chính mình |
| CHARM | không đánh, không dùng skill, đi về phía kẻ mê hoặc |
| LOCKED | không di chuyển, tầm đánh còn 1 |
| CURSE | gục sau một thời gian |
| POSSESSED | tạm thời chiến đấu cho phe kia |
| PROTECT | miễn mọi sát thương |
| SAFEGUARD (Rune Protect) | miễn trạng thái xấu |
| RESURRECTION | hồi sinh một lần: 2 giây hồi sinh (không bị nhắm), rồi về chỉ số lúc vào trận, đầy máu, 0 PP |
| RAGE | gấp đôi sát thương, +80 SPEED |
| 4 FIELD (Electric / Psychic / Grass / Fairy) | +20% sát thương gây ra |

FREEZE, SLEEP, LOCKED, CONFUSION, CHARM, BLINDED không gia hạn khi đang dính; hết FREEZE / SLEEP / CHARM... thì miễn lại 1,5 giây. BURN làm FREEZE hết nhanh gấp đôi; RAGE chia đôi thời gian SLEEP / FREEZE. Như web (`status.ts`).

---

## 6. Hệ (synergy)

Mỗi Pokémon có một hoặc nhiều hệ. Mỗi **họ** trên sàn tính một lần cho mỗi hệ (bench không tính). Đạt ngưỡng thì kích hoạt mốc.
Khi Dragon kích hoạt, hệ thứ hai của mỗi họ Dragon được tính đôi. Gem đào được và một số item cộng thêm điểm hệ.

| Hệ | Ngưỡng | Hiệu ứng chính |
|---|---|---|
| Normal | 3/5/7/9 | đầu trận cho khiên mình và đồng minh kề bên; khăn Silk Scarf để ghép item khăn |
| Grass | 3/5/7/9 | hồi máu mỗi 2 s; **cây quả mọng** cho quả mỗi vài stage |
| Fire | 2/4/6/8 | đốt BURN khi đánh trúng, +ATK mỗi đòn; mốc 4: Fire Shard |
| Water | 3/6/9 | +PP mỗi giây; **cần câu** câu Pokémon ra bench mỗi stage |
| Electric | 3/5/7 | đòn thứ 4 / 3 đánh ba lần; mốc 3: Cell Battery siêu nạp |
| Fighting | 2/4/6/8 | chặn sát thương mỗi đòn, ném kẻ cận chiến; mốc 4: tập luyện tăng chỉ số vĩnh viễn |
| Psychic | 3/5/7 | +AP; shop **Unown** với 28 Hidden Power |
| Dark | 3/5/7 | +chí mạng; Dark cận chiến nhảy tới kẻ địch xa nhất |
| Steel | 2/4/6/8 | +DEF cả đội; một phần ATK thành sát thương chuẩn |
| Ground | 2/4/6/8 | đào hố dưới chân mỗi stage: +DEF/SPE_DEF theo độ sâu, tìm **đồ chôn**. Trên sàn: hố vẽ thành hố đất (càng sâu càng rộng / tối) với chữ `độ sâu/5` dưới chân; ô có Pokémon Ground sắp đào ở stage sau viền cam, đủ 5/5 chữ vàng |
| Poison | 3/5/7 | gây POISONED, tăng số tầng tối đa |
| Dragon | 3/5/7 | hệ thứ hai tính đôi; khiên và SPEED/AP theo tổng sao Dragon |
| Field | 3/6/9 | một Field ngã: các Field khác hồi máu và tăng SPEED |
| Monster | 2/4/6/8 | FLINCH; lớn lên mỗi lần hạ địch |
| Human | 2/4/6 | hút máu; **TM** dạy skill khác |
| Aquatic | 2/4/6/8 | rút ngắn trạng thái xấu; sóng thần định kỳ |
| Bug | 2/4/6/8 | nhân bản các con Bug mạnh nhất đầu trận; mốc 4: tổ sinh thêm Bug |
| Flying | 2/4/6/8 | bay ra chỗ an toàn khi máu thấp |
| Flora | 3/4/5/6 | **chậu hoa** nở Pokémon khi một Flora gục; phân bón nuôi chậu |
| Rock | 2/4/6 | +DEF, giảm chí mạng nhận vào |
| Ghost | 2/4/6/8 | né đòn, SILENCE, nguyền địch đầu trận |
| Fairy | 2/4/6/8 | chọn **đũa phép** (1 trong 3 mỗi mốc) thêm hiệu ứng cho đòn đánh |
| Ice | 2/4/6/8 | +SPE_DEF cả đội, đóng băng |
| Fossil | 2/4/6 | khiên lớn khi xuống 30% máu |
| Sound | 2/4/6 | mỗi lần dùng skill: tăng ATK / SPEED / PP cho đội |
| Artificial | 2/4/6 | mạnh theo số item cầm; tặng **công cụ** mỗi mốc |
| Baby | 3/5/7 | thua trận có thể được **trứng**, nở ra dòng Hatch; trứng vàng cho item vàng |
| Light | 2/3/4/5 | con đứng trên **ô sáng** của run được buff lớn |
| Wild | 2/4/6/9 | +SPEED, +ATK; mở Pokémon Wild trong shop |
| Amorphous | 3/5/7 | cả đội +SPEED và +HP theo số hệ đang kích hoạt |
| Gourmet | 3/4/5 | **mũ đầu bếp** nấu món ăn cho đồng minh; món ăn cho hiệu ứng ở trận kế |

Nhiều hệ có **hệ thống giữa stage** riêng (chữ đậm ở bảng) — đây là lớp chiến lược dài hạn của một run, không chỉ là
chỉ số trong trận.

---

## 7. Item

- **Mảnh ghép** (8 loại dùng trong Endless + Fossil Stone, Silk Scarf): cho chỉ số nhỏ. **Hai mảnh ghép thành một item
  hoàn chỉnh** (55 công thức) có hiệu ứng riêng.
- Mỗi Pokémon cầm tối đa **3 item**, tối đa 1 mảnh lẻ, không cầm hai item ghép giống nhau.
- Kéo item từ kho (mép trái) lên Pokémon. Trong trận chỉ gắn được cho con ở bench.
- **Item Remover** (chỉ có ở bản này): công cụ cố định đầu kho, kéo lên Pokémon để tháo hết item về kho, dùng không giới hạn.
- Bán Pokémon thì item về kho.

| Nhóm | Ví dụ | Nguồn |
|---|---|---|
| Mảnh ghép, item ghép | Charcoal, Magnet, Choice Specs, Soul Dew | thưởng sau trận, carousel, starter |
| Đá hệ, khăn | Fire Stone, các Scarf | ghép từ Fossil Stone / Silk Scarf |
| Quả mọng (24) | ăn khi dưới 50% máu | cây của hệ Grass |
| Món ăn (46) | Sandwich, Curry | đầu bếp hệ Gourmet |
| TM (12) | dạy skill cho Pokémon Human | hệ Human |
| Công cụ (21) | Explorer Kit, Air Balloon | hệ Artificial, đồ chôn, Electivire |
| Gem hệ (30) | +1 điểm hệ khi giữ | đồ chôn, Sableye |
| Item vàng (12) | Dynamax Band, Rare Candy, Gold Bow | trứng vàng |
| Item thị trấn | vé, chuông, hộ chiếu, nhạc cụ báu | town encounter |
| Item đổi dạng | Rotom Catalog, Nectar (Oricorio), Mask (Ogerpon) | có khi sở hữu Pokémon tương ứng |

Tổng cộng 358 item trong dữ liệu.

---

## 8. Thời tiết

Trước mỗi trận, hệ của hai đội "bỏ phiếu": mỗi Pokémon +1 cho thời tiết của hệ mình; một số passive huyền thoại +100.
Thời tiết thắng cần **≥ 8 điểm** và không hoà; nếu không thì trời quang.

| Thời tiết | Hệ bỏ phiếu | Hiệu ứng chính |
|---|---|---|
| Zenith | Grass | hồi máu +20%; SLEEP ngắn hơn 30% |
| Drought | Fire | −3 PP mỗi giây, BURN +30%; FREEZE ngắn hơn 30% |
| Rain | Water | +3 PP mỗi giây, BURN −30% |
| Sandstorm | Ground | 5 sát thương phép mỗi giây (trừ Ground); CONFUSION dài hơn 30% |
| Misty | Fairy | sát thương phép +20%; CHARM dài hơn 30% |
| Snow | Ice | −10 SPEED (trừ Ice); FREEZE dài hơn 30% |
| Storm | Electric | sét đánh ngẫu nhiên (100 phép); PARALYSIS dài hơn 30% |
| Night | Dark | +10% chí mạng; SLEEP dài hơn 30% |
| Windy | Flying | +10 SPEED (Flying +20) |
| Bloodmoon | Wild | sát thương vật lý +20%; WOUND dài hơn 30% |
| Smog | Poison | +15% né đòn |
| Murky | Ghost | −30 LUCK (trừ Ghost); SILENCE dài hơn 30% |

Thời tiết áp dụng cho **cả hai đội**. Thanh stage hiển thị dự báo trong lúc chuẩn bị (theo sàn hiện tại và wave sắp gặp).
Bảng đầy đủ (passive bỏ phiếu, số liệu trong trận): `docs/WORLD.md` mục 1.

---

## 9. Tiến trình của một run

### 9.1 Wave (Endless)

- **Stage boss gốc**: 1 Magikarp • 2 Rattata • 3 Spearow • 9 Gyarados • 14 Mewtwo • 19 Tower Duo • 24 ba chim huyền thoại •
  28 ba thú huyền thoại • 32 Super Ancients • 36 các người khổng lồ • 40 Arceus.
- **Sau stage 40**: cứ 5 stage một boss quay lại (các boss từ stage 19 trở đi, xoay vòng), kèm hệ số tăng theo stage.
- **Các stage còn lại — bầy hoang dã**: một con đầu đàn ngẫu nhiên và các Pokémon chung ít nhất một hệ với nó.
  - Số con: `round(2 + stage × 0,3)`, từ 3 tới 9.
  - Độ hiếm: dùng tỉ lệ shop của level = số con trong bầy (từ stage 30: tỉ lệ level 10).
  - Sao: 2★ xuất hiện dần từ stage 4 tới 16, 3★ từ stage 14 tới 30.
  - Item cầm: từ stage 8 (mảnh), từ stage 14 (item ghép), thêm 1 item mỗi 2 stage.
  - Từ stage 25, mỗi stage cộng thêm cho cả wave: +15 HP, +2 ATK, +5 AP, +0,5 DEF / SPE_DEF.
- **Phần thưởng** (chỉ khi thắng): boss gốc theo bảng (mảnh ngẫu nhiên, chọn 1 trong 3 mảnh, chọn 1 trong 3 item ghép...);
  bầy hoang dã cứ 3 stage một item (mảnh trước stage 20, item ghép từ stage 20).
- **Template wave** (mức Thường / Khó): một số stage dùng wave dựng theo công thức thay cho bầy hoang dã — Đột kích Lửa
  (stage 6+), Bức tường Thép (10+), Hang Rồng (15+), Bộ ba tinh nhuệ (18+), Săn huyền thoại (30+, mức Khó).

Các con số trên là của mức **Thường** và đều chỉnh được trong `data/difficulty.json`; template trong `data/wave_templates.json`
(tool `tools\wave_editor.bat`). Xem `docs/DIFFICULTY.md`.

### 9.1b Độ khó

| Mức | Wave địch |
|---|---|
| Cổ điển | như bản web: không kích hệ, boss không cầm item, không template |
| Thường (mặc định) | kích hệ từ stage 5, boss cầm item, có template wave |
| Khó | kích hệ từ stage 1 với +1 điểm mỗi hệ; 2★ từ stage 3–12, 3★ từ 10–24; item từ stage 5, item ghép từ stage 10; HP ×1.15 và ATK ×1.1, thêm +1% / +0.5% mỗi stage; cộng dồn chỉ số từ stage 15; mất máu ×1.5 |

Chọn ở menu chính. Khi wave kích hệ, nó đếm hệ và nhận hiệu ứng đúng như đội người chơi (mỗi họ một điểm mỗi hệ).

### 9.2 Thị trấn

| Sự kiện | Stage | Nội dung |
|---|---|---|
| **Portal** | 0, 10, 20 | chọn 1 trong 3 cổng (mỗi cổng có các biểu tượng hệ và dẫn tới một vùng), rồi chọn Pokémon: khởi đầu (3 con Common kèm mảnh ghép), Unique (6), Legendary (6) |
| **Carousel** | 4, 12, 17, 22, 27, 34 | chọn 1 item (mảnh; từ stage 20 là item ghép) |
| **Additional pick** | 5, 8, 11 | chọn 1 trong 3 Pokémon additional kèm mảnh ghép; các họ additional của độ hiếm đó vào shop |
| **Town encounter** | cùng stage carousel / portal | mỗi nhân vật ~5%: Regirock (+15 máu), Xatu (Treasure Box), Kangaskhan, Kecleon, Electivire (cửa hàng), Sableye (gem), Duskull, Meowth, Cinccino, Ludicolo, Chansey, Wobbuffet, Croagunk, Munchlax, Chimecho, Lapras (đổi vùng), Makuhita (Võ đường), Magnezone (truy nã), Wigglytuff (nhiệm vụ), Marowak (boss cầm item), Spinda, Celebi (trận PvE kế tiếp shiny), Kingambit (Leaders Crest) — đủ 23 / 23 |

Các lựa chọn xếp hàng, mỗi lúc một popup; bấm *Fight!* khi chưa chọn thì game chọn ngẫu nhiên (trừ cửa hàng có giá).

Khi chơi theo **mùa** (9.5): additional pick chọn 1 trong 3 Pokémon của shop mùa đó (không họ nào gia nhập thêm);
Unique / Legendary được đề xuất là của mùa.

### 9.3 Vùng

- Mỗi portal dẫn tới một trong **144 vùng**. Vùng quyết định nhạc nền, ảnh hưởng cây quả mọng và **Pokémon vùng**.
- Mỗi vùng có vài hệ đặc trưng. Pokémon **regional** (55 họ) chỉ vào shop khi vùng có hệ của chúng.
- **Biến thể vùng** (Alola, Galar, Hisui, Paldea) thay cho dạng gốc trong shop và trong đề xuất khi ở đúng vùng
  (Vulpix → Alolan Vulpix...).
- Unique / Legendary regional (Tapu, Rotom, Oricorio, Ogerpon, chim Galar...) chỉ được đề xuất trong vùng của chúng.
- Rời vùng: pool vùng cũ mất; Pokémon vùng bán ở vùng khác không trở về pool.
- HUD hiện tên vùng; hover để xem hệ của vùng và Pokémon vùng đang có trong shop.
- Bảng 143 vùng (hệ, Pokémon vùng), vùng theo hệ và các biến thể: `docs/WORLD.md` mục 2.
- Khi chơi theo **mùa** (9.5) không có Pokémon vùng và biến thể vùng: shop giống nhau ở mọi vùng; vùng chỉ còn quyết
  định nhạc nền, cây quả mọng và biểu tượng hệ của cổng (tức Unique / Legendary được đề xuất).

### 9.4 Battle Pass — mở khoá hệ qua nhiều run (chỉ có ở bản này)

Mục tiêu: người mới học game với ít hệ đơn giản, chơi lâu thì có thêm hệ để chơi. Chi tiết: `docs/PROGRESSION.md`.

- **Bắt đầu với 3 hệ**: Fire, Water, Grass. **1 run** là lên cấp 2 (+Normal), sau đó **cứ 3 run một cấp, mỗi cấp 2 hệ**:
  Electric + Flying, Fighting + Rock, Poison + Field, rồi hệ thuần trong trận (Dark, Steel, Ice, Ghost, Monster, Aquatic,
  Bug, Sound), hệ có luật riêng (Dragon, Wild, Fairy, Psychic, Fossil, Amorphous, Human) và cuối cùng hệ có hệ thống giữa
  stage (Ground, Flora, Baby, Artificial, Light, Gourmet). 16 cấp, mở hết sau 43 run.
- **XP pass**: +100 cho mỗi run chơi tới hết (Game Over); thoát giữa chừng bằng nút Menu không tính. Cấp 2 cần 100, các
  cấp sau 300. Run có cheat không nhận XP. (Trước 2026-11-16: XP theo từng trận, 10 hệ khởi đầu, 22 cấp.)
- **Hệ chưa mở không tồn tại**: bị gỡ khỏi mọi Pokémon (cả địch) và vùng; họ Pokémon không còn hệ nào đã mở thì chưa xuất
  hiện (shop, đề xuất, trứng, wave); họ Wild đứng ngoài tới khi mở Wild; đá hệ / gem / công cụ của hệ đó không được phát.
  Ở cấp 1 shop có 28 / 94 họ (không mùa), khoảng 27–30 / 96 trong một mùa.
- Hệ mở ở run này dùng được **từ run kế tiếp**.
- **Hệ mở tạm theo vùng** (2026-11-18): tới vùng nào thì các hệ của vùng đó còn khoá được mở **cho tới hết run** (Pokémon có thêm
  hệ, họ của hệ đó vào shop ngay, item của hệ được phát). Cổng ghi "Mở tạm" + biểu tượng các hệ sẽ mở. Run mới chỉ còn hệ của pass.
- Số liệu và thứ tự nằm trong `data/progression.json` (`enabled: false` để tắt hẳn).

### 9.5 Mùa — danh sách Pokémon cố định (chỉ có ở bản này)

Vấn đề: không chia mùa thì tới stage 11 shop có 249 họ cộng Pokémon vùng, một hệ có 13–37 họ — rất khó nhắm đội hình.
Giải pháp theo kiểu các *set* của TFT: mỗi run chơi với **danh sách cố định của một mùa**, chọn ở menu chính cạnh độ
khó. Chi tiết và danh sách từng mùa: `docs/SEASONS.md`.

- **Shop của mùa: 96 họ** (19 Common, 24 Uncommon, 22 Rare, 19 Epic, 12 Ultra), có đủ **từ stage đầu** — không họ nào
  gia nhập giữa run, không Pokémon vùng. Họ ngoài mùa không xuất hiện ở đâu (shop, đề xuất, trứng, wave địch).
- **Hệ đại trà: 8–10 họ** mỗi hệ (hệ có mốc cuối 9 thì 9–10). **Hệ đặc biệt: 3–5 họ**, với **mốc kích hoạt riêng**
  của mùa (vd Fossil 2/3/4 thay cho 2/4/6); mốc cuối có thể cần thêm một Unique / Legendary / đá hệ.
- Mỗi mùa có **4 hệ đặc trưng**: đủ 8–10 họ ở mùa đó, là hệ đặc biệt ở hai mùa kia. 19 hệ còn lại mùa nào cũng đại trà.
- **Unique** (38–39 mỗi mùa), **Legendary** (25) và **dòng nở từ trứng** (4–5) cũng chia theo mùa, mỗi con một mùa.
- Battle Pass áp lên trên mùa (hệ chưa mở vẫn ẩn). Kỷ lục lưu riêng cho từng cặp mùa + độ khó.
- Lựa chọn **Tất cả Pokémon** = không mùa, pool như trước.

| Mùa | Hệ đặc trưng | Ghi chú |
|---|---|---|
| 1 — Khởi Nguyên | Wild, Baby, Flora, Dragon | gần shop gốc của bản web nhất (≈ 3/4 số họ), mùa mặc định |
| 2 — Tàn Tích Cổ | Fossil, Human, Sound, Ghost | phần lớn là họ additional / vùng |
| 3 — Lễ Hội Ánh Sáng | Artificial, Light, Gourmet, Amorphous | phần lớn là họ additional / vùng |

Ba mùa dùng 239 / 300 họ shop của game; Common (31 họ) và Ultra (14 họ) quá ít nên các mùa dùng chung phần lớn.
Trong trận, nút **!** cạnh shop mở danh sách cả mùa; ở menu, nút *Pokémon của mùa* mở bảng theo từng hệ.
Danh sách do `tools/port/gen_seasons.py` tính rồi lưu ở `data/seasons.json` (sửa tay được).

---

## 10. Nội dung hiện có

| Loại | Số lượng |
|---|---|
| Pokémon trong dữ liệu | 1183 dạng |
| Shop thường | 94 họ / 279 dạng (22 Common, 23 Uncommon, 18 Rare, 17 Epic, 14 Ultra) |
| Additional | 154 họ / 316 dạng |
| Regional | 55 họ / 130 dạng |
| Unique / Legendary | 110 / 78 dạng |
| Hatch | 58 dạng |
| Skill | 548 (25 là bản đơn giản hoá, ghi `approx`) |
| Skill có hiệu ứng hình ảnh | 409 |
| Hệ | 31 |
| Mùa | 3 (mỗi mùa 96 họ shop, 38–39 Unique, 25 Legendary) + lựa chọn không mùa |
| Item | 358 |
| Thời tiết | 12 + trời quang |
| Vùng | 144 (mỗi vùng một bản nhạc) |
| Ngôn ngữ | 14 |

---

## 11. Giao diện và điều khiển

### 11.1 Bố cục HUD (kiểu TFT)

| Vị trí | Thành phần |
|---|---|
| Trên giữa | thanh stage: số stage, tên wave, **hệ wave địch đang kích**, **vùng**, thời tiết, pha, tốc độ trận; hover = độ khó, chỉ số / item của wave, 6 stage sắp tới |
| Trên phải | máu, level và sĩ số, nút Menu; bên dưới là **DPS meter** (sát thương gây ra / chặn được / hồi máu) |
| Trên trái | vườn: cây quả mọng, chậu hoa |
| Mép trái | kho item nhiều trang (10 ô / trang) và Item Remover |
| Trái | danh sách hệ của sàn với các mốc |
| Phải giữa | panel chi tiết Pokémon (chuột phải): sao, hệ, máu / PP, skill, passive, item, vai trò, 9 chỉ số |
| Dưới | shop: level + XP, tỉ lệ độ hiếm, vàng, nút **!** (pool của shop) và khoá; nút Mua XP / Đổi shop; 6 thẻ |
| Góc dưới phải | nút **Fight!** |
| Giữa trên | popup lựa chọn (portal, Pokémon, item, đũa phép) |

### 11.2 Tooltip

Tooltip mở **cạnh** phần tử được hover, nhiều tầng (tooltip chứa phần tử có tooltip riêng). Chữ mô tả tự đổi từ khoá
thành icon và màu (loại sát thương, chỉ số, trạng thái, hệ, item). Có tooltip cho: hệ (kèm lưới Pokémon của hệ), skill
(kèm sơ đồ lục giác 7×8 các ô bị ảnh hưởng), item (kèm công thức), chỉ số, vai trò (vị trí + item gợi ý), thẻ shop, thời tiết,
vùng, các stage sắp tới.

Tooltip chứa phần tử hover được (hệ, vai trò, công thức item) giữ mở khi đưa chuột sang nó: khoảng hở giữa phần tử và
tooltip tính là bên trong, ra ngoài thì 0,35 s sau mới đóng, và chuột đi ngang qua một phần tử khác (vd hệ bên dưới) chỉ đổi
tooltip nếu dừng ở đó 0,18 s (`HoverTip.CLOSE_DELAY`, `SWITCH_DELAY`).

Lưới Pokémon của tooltip hệ chia nhóm như bản web: **trong shop**, **additional** (vào shop ở stage 5 / 8 / 11), **vùng**,
**Unique** (portal stage 10), **Legendary** (portal stage 20); mỗi họ một ô (các màu Flabébé gộp một ô). Viền ô theo **giá**:
xám 1, xanh lá 2, xanh dương 3, tím 4, đỏ 5, vàng Unique / Legendary. Dấu ✓ xanh = họ đó đang có trên sàn / bench; ô tối + ổ
khoá = shop của bạn chưa thể ra con đó lúc này (additional chưa tới stage, Pokémon vùng không thuộc vùng hiện tại, WILD khi
tỉ lệ WILD = 0). Hover một ô: thẻ nhỏ (tên, giá, hệ, vai trò) kèm **điều kiện unlock** và trạng thái (đang có trong đội /
có thể ra trong shop / chưa có / chọn qua portal).

### 11.3 Điều khiển

| Thao tác | Tác dụng |
|---|---|
| Kéo thả chuột trái | bench ↔ sàn; thả lên shop để bán; kéo item lên Pokémon |
| Chuột phải lên Pokémon | mở panel chi tiết, tô tầm đánh |
| Chuột phải lên item | ghim bảng công thức |
| `Space` | bắt đầu trận |
| `D` / `F` | đổi shop / mua XP |
| Lăn chuột | zoom camera; trên kho item: chuyển trang |
| `Esc` | đóng panel và tooltip |

Khi kéo Pokémon: ô thả được sáng nhẹ, ô đang trỏ xanh (được) hoặc đỏ (không được), các ô trong tầm đánh tô vàng.

---

## 12. Hình ảnh và âm thanh

- **Phong cách**: thế giới 3D thật nhưng mọi thứ là hình 2D (hướng Don't Starve / Arknights). Sàn là mặt phẳng tô bằng
  shader "vẽ tay" pixel-art; Pokémon là sprite PMD 2D billboard, 8 hướng, có bóng tròn dưới chân.
- **Chuyển động Pokémon** (2026-11-20): giữ nguyên frame PMD (Idle ~3 hình / giây, đi 4 hình / giây). Animation đòn
  đánh kéo dài đúng bằng thời gian hồi đòn như bản web, nên frame đánh trúng khớp lúc gây sát thương; mọi animation chạy
  theo tốc độ tua x2 / x4; đòn / bước đi kế tiếp nối liền, không chớp về Idle. Phủ lên đó là chuyển động vẽ lại mỗi khung
  hình (không có ở web):
  - thở khi đứng, nảy mỗi nửa ô khi đi;
  - lao tới mục tiêu khi đánh cận chiến (xa nhất đúng lúc trúng), lùi nhẹ khi bắn;
  - bị đẩy lùi + bẹp khi trúng đòn (chí mạng mạnh hơn, sát thương theo thời gian chỉ bẹp nhẹ);
  - giãn khi bay (dash / bị hất) rồi bẹp khi đáp, phóng to khi xuất hiện (mua, tiến hoá, triệu hồi), lún xuống khi ngất.

  Chỉ hình sprite dịch chuyển; vị trí ô, thanh máu và VFX vẫn theo ô của trận. Sprite lọc "sharp bilinear": pixel vẫn sắc
  nhưng không nhấp nháy khi di chuyển hay co giãn ở tỉ lệ màn hình lẻ.
- **Camera** kiểu TFT: nghiêng 55°, FOV hẹp 38°, zoom bằng lăn chuột, rung khi skill lớn hoặc thua.
- Thanh máu / PP, sao, item đang cầm, số sát thương là UI 2D bám theo vị trí 3D.
- **VFX**: animation skill của bản web (chiếu, đạn bay, rơi từ trên xuống, quay quanh, theo ô), đạn và tia lửa của đòn
  đánh thường, icon trạng thái trên đầu, burst khi tiến hoá.
- **Âm thanh**: nhạc menu, nhạc thị trấn theo stage portal, nhạc riêng từng vùng (cross-fade); tiếng nút, đổi shop,
  tiến hoá, portal, carousel, bắt đầu run, game over theo stage đạt được.
- Độ phân giải thiết kế 1920×1080, co giãn theo `canvas_items` / `expand`.

---

## 13. Kỹ thuật (tóm tắt)

```
src/core/      luật thuần, không node (test headless được): board, unit, simulation, skill, synergy,
               passive, item, weather, wave Endless, người chơi, thị trấn
src/view/      camera, sàn, sprite Pokémon, VFX
src/ui/        HUD, shop, kho item, tooltip, options
src/game/      điều phối pha, kéo thả, đổi event của simulation thành hình ảnh
src/autoload/  GameData (dữ liệu + chữ), Settings, Audio
data/pac/      SINH TỰ ĐỘNG từ bản web (không sửa tay)
data/          abilities.json, ability_vfx.json, item_effects.json, i18n/ (viết cho bản port)
tests/         sim_test (logic), flow_test (luồng màn hình), soak_test (bot chơi), screenshot
data/          difficulty.json (mức độ khó), wave_templates.json (template wave)
tools/         export_pac.bat, wave_editor.bat (+ wave_editor/), port/*.py
```

- **Tách logic và hiển thị**: simulation phát danh sách event (đánh, sát thương, di chuyển, trạng thái, vùng ô...);
  view chỉ đọc event và trạng thái unit.
- **Pipeline**: `tools\export_pac.bat` chạy `godot-export.ts` của bản web → JSON dữ liệu, sprite, chân dung, icon,
  sheet VFX, âm thanh, bản dịch. Thêm một Pokémon = port skill của nó rồi export lại.
- **Skill**: dạng dữ liệu (các bước + vùng ô) hoặc viết bằng code (`ability_scripts.gd`, khoảng 430 skill).
- **Test**: mọi skill được cast thử, mọi mốc synergy, luật shop / item / thị trấn / vùng; bot chơi tự động ~20 stage để bắt
  lỗi runtime.
- **Ngôn ngữ**: chữ game = tiếng Anh của web + bản dịch web + bản viết riêng (`data/i18n/<code>.json`); chữ giao diện
  qua `L.t()` và `data/i18n/ui.json`.

---

## 14. Khác biệt với bản web và hạn chế

Cố ý khác:

- Pha chuẩn bị không có đồng hồ (tuỳ chọn bật 30 s); hết giờ mà sàn thiếu quân thì tự xếp từ bench.
- Có Item Remover, tua trận x2 / x4, xem trước 6 stage, nhãn vùng trên HUD.
- Có mức độ khó: wave địch kích hệ, boss cầm item, hệ số chỉ số, template wave (mức Cổ điển tắt hết, giống web).
- Lưu kỷ lục theo mức độ khó (stage cao nhất, đội hình, số lượt chơi) ở `user://records.cfg`; run có dùng cheat
  không được tính. Bản web lưu hồ sơ online (ELO, lịch sử).
- Battle Pass mở khoá hệ dần (mục 9.4); bản web có đủ 31 hệ từ đầu.
- Bench 8 ô, mỗi ô chứa 1–2 con giống nhau (web: 8 ô × 1 con).
- Chia **mùa** (mục 9.5): danh sách Pokémon cố định cho mỗi run, hệ ít Pokémon có mốc riêng; bản web dùng một pool
  chung lớn dần theo additional pick và theo vùng. Kỷ lục lưu theo mùa + độ khó.
- Bảng Game Over có thống kê của run: số trận thắng / thua, thời gian, cấp, vàng kiếm được, số lần đổi shop, đội hình
  cuối, 5 Pokémon gây sát thương nhiều nhất (chia vật lý / phép / chuẩn), Pokémon chặn và hồi nhiều nhất, trận hay nhất.
- Mọi skill đều có hiệu ứng hình ảnh: 78 skill bản web không có animation được gán hiệu ứng dùng lại sheet có sẵn.
- Android / màn nhỏ: cả giao diện được phóng to theo kích thước thật của màn hình (×2,0 trên Oppo Reno 15 Pro → canvas
  chỉ còn 1171×540; chỉnh được ở Tuỳ chọn → Cỡ giao diện), HUD chuyển sang **bố cục gọn** và camera tự căn sàn vào phần
  còn trống. Bố cục gọn (bản 4, 2026-11-15: **sàn to kiểu TFT mobile**; không phần nào tràn / đè nhau / nằm dưới lỗ camera):
  - **shop bật / tắt**: shop một hàng ở đáy (vàng + cấp + thanh XP + nút ▼ ẩn shop, Mua XP / Đổi shop cạnh nhau, 6 thẻ,
    nút `!` và khoá) tự mở khi vào pha chuẩn bị và tự đóng khi vào trận. Shop đóng: **sàn lấp gần hết màn hình** — từ mép
    phải cột trái tới nút Chiến!, từ dưới thanh stage xuống đáy màn hình (trên máy thử: 787×455 đơn vị canvas, gấp ~1,3 lần
    bản 3 và ~1,7 lần bản 2); góc dưới trái còn **ô vàng (số vàng trên nút Shop ▲)**, nút Chiến! (140×60) ở góc dưới phải;
    camera lướt giữa hai cỡ trong 0,2 s. Thẻ shop hẹp: tên Pokémon tự thu cỡ chữ; tỉ lệ độ hiếm: chạm vào cấp;
  - bán khi shop đóng: kéo Pokémon vào ô vàng ở góc dưới trái (ô hiện "Thả vào đây để bán" trong lúc kéo);
  - cột trái: kho item (nút lật trang chỉ hiện khi có hơn một trang) và **hệ dạng chip hẹp** (rộng 64) — biểu tượng, số
    đang có, bên dưới là mốc kế tiếp ("/4"); tên hệ và các mốc khác nằm trong tooltip (chạm). Vườn (cây quả mọng, chậu
    hoa) thu nhỏ nằm trên cùng khi có;
  - **góc nhìn sàn tự khớp**: camera chọn góc (36–60°) cho sàn to nhất trong khoảng trống lúc shop đóng — vừa rộng bằng
    khoảng trống vừa cao bằng nó (trên máy thử: 39°); giữ nguyên góc khi mở shop. Tuỳ chọn → **Góc nhìn sàn**: Tự động
    hoặc cố định 40 / 45 / 50 / 55 / 60° (chỉ hiện trên màn nhỏ);
  - bench một hàng 8 ô (mỗi ô 1–2 con giống nhau) nên sàn nông hơn bản cũ (2 hàng bench) → to hơn;
  - giữa: thanh stage **hai dòng** (dòng 1: stage, tên wave, pha, tốc độ; dòng 2: hệ của địch, tên vùng, thời tiết, thanh
    thời gian) — tên wave / tên vùng quá dài thì cắt bằng "…", chạm để xem đủ;
  - góc phải: máu + cấp + nút Menu trên một khối thấp, thống kê trận (rộng 240, **gập lại lúc đầu** — chạm tiêu đề để
    mở; mở ra thì che mép phải của sàn) bên dưới, nút Chiến! ngay trên đầu phải của shop (hoặc ở góc dưới phải khi shop
    đóng);
  - **bảng Pokémon dạng gọn** (300×300, bằng nửa bản PC) mở ở cột phải, không che nút Chiến! và shop: ảnh vuông (sao
    nằm trên ảnh) + tên (tự thu cỡ chữ) + giá + hệ, HP | PP cạnh nhau, sơ đồ kỹ năng | 3 ô item + vị trí + tầm đánh +
    vai trò, 9 chỉ số. Chú giải của sơ đồ và chữ nội tại chuyển vào tooltip (chạm sơ đồ / nhãn "Nội tại");
  - tooltip của hệ xếp **hai cột** (mô tả + mốc bên trái, Pokémon bên phải) để giữ nguyên cỡ chữ thay vì bị co lại;
    tiêu đề dài của popup chọn item (đũa phép) xuống dòng thay vì kéo popup rộng ra hai cột bên;
  - **popup chọn item** (thưởng cuối round, carousel, đũa phép, cửa hàng thị trấn): mỗi ô có nút tròn **i** ở góc trên
    phải — chạm để xem item làm gì (tooltip ghim dưới ô, chạm lần nữa để đóng) mà không chọn nó; ô quá giá vẫn xem được;
  - **màn Battle Pass dạng gọn** (2026-11-16): rộng hết màn, một dòng đầu (tiêu đề, cấp + thanh XP, nút cheat, Đóng), luật
    XP, hệ khởi đầu trên một dòng, rồi các thẻ cấp (7 cột, thẻ thấp hơn) — vừa khít màn, **không co chữ** (trước
    co ×0,85 và lệch xuống dưới màn hình);
  - danh sách shop của mùa (nút `!`) không cao quá khoảng phía trên shop;
  - màn quá nhỏ (ví dụ 960×540): shop, thanh stage, bảng Pokémon, popup tự co lại cho vừa — không gì rời màn hình.
- Cảm ứng: **chạm** Pokémon → bảng thông tin (chạm chỗ trống để đóng); **chạm** item → tooltip của item; chạm một phần tử
  có tooltip (hệ, chỉ số, thời tiết...) → tooltip đó; chạm nút / thẻ shop = bấm; **giữ** = tooltip của nút / thẻ shop,
  công thức của item; kéo vẫn là di chuyển / gắn item / bán.
- **Thanh máu và item trên đầu Pokémon** (mọi cỡ màn hình): thanh PP, thanh máu, hàng item đang cầm rồi tới sao xếp chồng
  **phía trên đầu** — không còn đè lên sprite; kích thước co theo bề rộng của ô trên màn hình (đủ cỡ trên PC, nhỏ dần ở
  hàng xa và trên điện thoại). Điểm neo là đỉnh sprite như nó được vẽ (sprite là billboard, đứng theo trục dọc của camera).
- Biến thể vùng dùng chung số bản copy với dạng gốc.

Hạn chế hiện tại:

- Đá thời tiết của Rock không có (bản web chỉ dùng khi đấu người); Leaders Crest (Kingambit) và Mission Order đỏ chỉ
  có tác dụng khi đấu người → trong Endless solo chỉ là item giữ chỗ.
- Bản Android: bố cục gọn đã chỉnh theo ảnh chụp trên máy thật (2026-11-14) rồi kiểm lại bằng giả lập đúng cấu hình máy
  đó; chưa có zoom bằng hai ngón; shop mở thì sàn nhỏ hơn (phải đóng shop để sàn to nhất); menu chính co ×0,84 (vẫn
  vừa màn). Bố cục bản 4 (sàn lấp khoảng trống, góc nhìn tự khớp, bench 8 ô × 2) chưa chạy trên máy thật. Bảng cheat
  (F1, công cụ dev, chỉ mở được bằng bàn phím) tràn khỏi màn ở cỡ điện thoại.

---

## 15. Hướng phát triển

1. Bản Android: xác nhận bố cục gọn bản 4 (sàn lấp khoảng trống, góc nhìn tự khớp) trên máy thật; zoom hai ngón, menu chính và
   Battle Pass dựng riêng cho màn nhỏ thay vì co lại; ký bản release.
2. Battle Pass: cân nhịp XP sau khi chơi thử thật, thêm loại phần thưởng khác cho cấp, màn giới thiệu hệ mới.
2b. Lưu thống kê của run vào kỷ lục để xem lại từ menu chính.
3. Portrait cảm xúc và động tác Faint từ PMD SpriteCollab; màn credit tác giả sprite (bắt buộc khi phát hành).
4. Tooltip hệ liệt kê cả Pokémon vùng hiện tại.
4b. Mùa: duyệt lại danh sách 3 mùa bằng tay, cân mốc riêng của hệ đặc biệt, thêm mùa / mùa bỏ hẳn vài hệ, mở mùa theo pass.
5. Cân bằng riêng cho Endless: chỉnh số của 3 mức độ khó và thêm template wave (đã có công cụ), phần thưởng boss lặp lại.
6. Nếu hướng tới phát hành: thay toàn bộ nội dung có bản quyền bằng nội dung gốc, giữ nguyên hệ thống.
