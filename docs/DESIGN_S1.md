# Thiết kế Season 1: Genesis

*Sinh bằng `python tools/design/gen_design.py s1` từ `tools/design/s1_*.json`; đừng sửa tay. Người dùng đã duyệt (2026-11-20: mượn skill được, item giữa stage của hệ giữ nguyên, số liệu để tự cân bằng chỉnh); trong game: `data/season_skills.json` (`--write`), `data/season_synergies.json`, `docs/HANDOFF.md` mục 14.*

## Luật đã chốt (người dùng, 2026-11-20)

- **Hệ**: mỗi mùa mỗi hệ một hiệu ứng mới, không lặp ở hệ / mùa nào (hiệu ứng web chỉ còn khi chơi *Không mùa*). Giữ chủ đề của hệ, đổi cơ chế. Item giữa các stage của hệ (cần câu, quả mọng, đũa, mũ đầu bếp...) giữ nguyên.
- **Skill**: trong một mùa mỗi họ Pokémon một cơ chế riêng = *vùng trúng + cách hoạt động* (cột **Khoá**). Chỉ đổi số liệu, đổi trạng thái (BURN↔POISON) hay đổi chỉ số bị giảm vẫn tính là trùng.
- Họ có ở nhiều mùa: mỗi mùa một skill khác (mùa 1 giữ skill web nếu không trùng; mùa 2 / 3 sẽ đổi).
- Làm từng mùa: duyệt bảng này → code + test → chơi thử → mùa 2, mùa 3.

## Số liệu

- 165 họ (5 màu Flabébé tính 1). Skill: **85 giữ**, **33 mượn** (skill đã có của Pokémon không thuộc mùa này), **53 mới** (phải code).
- 31 hệ, mỗi hệ một cơ chế mới.
- Kiểm tra: **không lỗi** (mỗi họ một skill, khoá không trùng, id mới không đụng skill có sẵn).

## 1. Hiệu ứng hệ

| Hệ | Tên | Mốc | Hiệu ứng | Cơ chế (khoá) | Vì sao hợp mùa này | Cảm hứng TFT |
|---|---|---|---|---|---|---|
| NORMAL | **Chịu Đựng** | 3/5/7/9 | Lần đầu mỗi trận một Pokémon NORMAL nhận đòn chí tử: còn 1 HP, miễn sát thương {0.8/1/1.2/1.5} giây rồi nhận khiên {15/25/35/50}% HP tối đa. | `cheat_death` | Endure là chiêu hệ Thường; 14 họ đa số đỡ đòn / đấu sĩ | Set 9.5 Ghostly / Set 11 Fated (sống sót) |
| GRASS | **Hạt Ký Sinh** | 3/5/7/9 | Đòn đánh và skill của Pokémon GRASS gieo hạt lên kẻ địch (mỗi kẻ một hạt, 5 giây): mất {1/1.5/2/3}% HP tối đa mỗi giây, lượng đó hồi cho đồng minh ít % HP nhất. | `seed_drain` | Leech Seed của Bulbasaur; hút máu nuôi tuyến đầu | Set 4 Elderwood (theo thời gian) / Set 12 Honeymancy |
| FIRE | **Đất Cháy** | 2/4/6/8 | Ô bị skill của Pokémon FIRE đánh trúng bốc cháy {3/4/5/6} giây: kẻ địch đứng trên đó chịu {2/3/4/6}% HP tối đa thành sát thương phép mỗi giây và bị BURN. | `scorch_cells_on_cast` | Hệ Lửa mùa 1 chủ yếu pháp sư (Magby, Vulpix, Cyndaquil, Heatran, Moltres): thưởng skill thay vì đòn đánh | Set 2 Inferno |
| WATER | **Dòng Chảy** | 3/6/9 | Mỗi lần một Pokémon WATER dùng skill, Pokémon WATER khác có ít PP nhất nhận {15/25/40} PP (theo thanh 100 PP). | `cast_chain_pp` | Giữ chất 'hồi PP' của hệ Nước nhưng thành dây chuyền giữa các con | Set 3 Star Guardian (chia mana) |
| ELECTRIC | **Tĩnh Điện** | 3/5/7 | Pokémon ELECTRIC tích 1 điện mỗi lần đánh hoặc bị đánh trúng; đủ 8 điện thì phóng sét nảy qua {3/4/6} kẻ địch, mỗi kẻ {40/60/90} sát thương phép. | `charge_release_chain` | Tia chớp nảy, hợp cả đỡ đòn (bị đánh) lẫn xạ thủ (đánh) | Set 2 Electric / Set 5.5 Dragonslayer |
| FIGHTING | **Liên Hoàn** | 2/4/6/8 | Mỗi đòn đánh liên tiếp của Pokémon FIGHTING vào cùng một mục tiêu gây thêm {6/10/14/20}% sát thương (cộng dồn tối đa 5 lần, đổi mục tiêu thì mất). | `same_target_ramp` | Võ sĩ cận chiến đánh liên tục một mục tiêu | Set 6 Challenger / combo |
| PSYCHIC | **Dư Âm Tiên Tri** | 3/5/7 | 2 giây sau mỗi skill của Pokémon PSYCHIC, {20/35/55}% sát thương skill đó đánh lại đúng các mục tiêu (sát thương phép). | `ability_echo` | Future Sight; 24 họ, đa số pháp sư | Set 6 Mage (đánh hai lần) theo kiểu trễ |
| DARK | **Kẻ Cắp** | 3/5/7 | Mỗi lần trúng đòn (đánh hoặc skill, mỗi mục tiêu 1 lần / giây), Pokémon DARK cướp {1/2/3} ATK và {3/5/8} AP của mục tiêu (tối đa 10 lần mỗi trận). | `stat_steal_on_hit` | Thief / Knock Off là chiêu hệ Ác | Set 14 Cypher / Set 9 Noxus |
| STEEL | **Pháo Đài** | 2/4/6/8 | {5/6/8/10} giây đầu trận Pokémon STEEL nhận ít hơn {25/35/45/60}% sát thương và không bị đẩy / kéo; hết thời gian thì nhận DEF bằng 10% lượng sát thương đã chặn. | `opening_fortify` | 18 họ, phần lớn đỡ đòn | Set 9 Bastion |
| GROUND | **Địa Chấn** | 2/4/6/8 | Mỗi 4 giây mỗi Pokémon GROUND dậm đất: kẻ địch ADJACENT chịu {50/80/120/180}% DEF của nó thành sát thương phép và mất 10 SPEED. | `periodic_quake` | Đa số đỡ đòn / đấu sĩ cận chiến; hố đất giữa stage giữ nguyên | Set 9 Shurima (định kỳ) |
| POISON | **Lây Lan** | 3/5/7 | Skill của Pokémon POISON gây POISON 3 giây lên mọi kẻ trúng. Kẻ địch đang POISON gục thì số tầng độc lây sang {1/2/3} kẻ địch gần nhất (+1 tầng). | `poison_contagion` | Độc lan qua đội hình đứng sát | Set 19 Teemo (Lây Nhiễm) |
| DRAGON | **Vũ Điệu Rồng** | 3/5/7 | Mỗi lần một Pokémon DRAGON dùng skill, mọi Pokémon DRAGON nhận {2/3/5} ATK, {5/8/12} AP và 5 SPEED (tối đa 8 lần mỗi trận). | `cast_stacks_type_team` | Hệ đặc trưng mùa 1: cả bầy rồng mạnh lên cùng nhau | Set 7 Ragewing / Set 9.5 Dragonmancer |
| FIELD | **Săn Theo Bầy** | 3/6/9 | Pokémon FIELD gây thêm {8/14/22}% sát thương lên mục tiêu cho mỗi Pokémon FIELD khác cũng đang nhắm mục tiêu đó. | `focus_fire_bonus` | Thú thảo nguyên săn theo đàn | Set 4.5 Warlord / focus fire |
| MONSTER | **Cuồng Nộ** | 2/4/6/8 | Lần đầu xuống dưới 50% HP, Pokémon MONSTER gầm lên: kẻ địch ADJACENT bị FLINCH 2 giây; nó miễn khống chế {3/4/5/6} giây, +{20/30/45/60}% SPEED và hút máu {15/20/25/35}% tới hết trận. | `half_hp_rampage` | Quái vật cận chiến càng đau càng hung | Set 8 Brawler / Set 13 Pit Fighter |
| HUMAN | **Chiến Thuật** | 2/3/5 | Đầu trận: Pokémon HUMAN ở 2 hàng trước cho đồng minh đứng ngay sau nó khiên {80/140/240}; Pokémon HUMAN ở 2 hàng sau cho đồng minh đứng ngay trước nó {15/25/40} ATK% và {20/35/60} AP. | `row_strategy` | Hệ hiếm (mốc 2/3/5): con người bày trận | Set 9 Strategist |
| AQUATIC | **Trơn Trượt** | 2/4/6/8 | Pokémon AQUATIC có {10/16/22/30}% né đòn đánh; mỗi lần né nhận 8 PP và 5 SPEED (tối đa 10 lần). | `dodge_reward` | Thân trơn dưới nước | Set 5 Knight / Set 1 Yordle (né) |
| BUG | **Bầy Đàn** | 2/4/6/8 | Pokémon BUG nhận {8/12/16/22}% SPEED và {2/3/5/8} DEF cho mỗi Pokémon BUG khác ADJACENT (tính lại mỗi giây). | `adjacency_swarm` | Côn trùng đi theo đàn; bản sao Bug của web bỏ trong mùa này | Set 7 Jade / kề vai |
| FLYING | **Thuận Gió** | 2/4/6/8 | Đầu trận cả đội +{10/15/20/30}% SPEED trong 6 giây; mỗi lần một Pokémon FLYING dùng skill, gió được làm mới 6 giây. Pokémon FLYING giữ một nửa lượng đó tới hết trận. | `tailwind_team_haste` | Tailwind; 21 họ trộn đủ vai trò | Set 4 Spirit (đội nhận tốc đánh khi cast) |
| FLORA | **Nở Rộ** | 3/4/5/6 | Mỗi lần một Pokémon FLORA dùng skill, {2/3/3/4} đồng minh ít % HP nhất hồi {6/8/10/12}% HP tối đa; mốc 4: còn được giải hiệu ứng xấu. | `cast_heals_lowest_allies` | Hệ đặc trưng mùa 1; chậu hoa giữa stage giữ nguyên | Set 10 Disco / healer trait |
| ROCK | **Cứng Cáp** | 2/4/6 | Một đòn (đánh hoặc skill) không thể làm Pokémon ROCK mất quá {25/18/12}% HP tối đa. | `damage_cap_per_hit` | Sturdy; khắc chế đòn kết liễu / sát thương dồn | Set 6 Colossus (chống dồn sát thương) |
| GHOST | **Hồn Lưu Luyến** | 2/3/4/5 | Pokémon GHOST gục thì hồn ở lại {3/4/5/6} giây: không bị nhắm, vẫn đánh và dùng skill với {50/60/70/80}% sức mạnh. | `afterlife_spirit` | Hệ hiếm; ma không chết ngay | Set 9 Shadow Isles / Set 13 Revenant |
| FAIRY | **Sương Mù Tiên** | 2/4/6/8 | Đồng minh ADJACENT với một Pokémon FAIRY (kể cả nó) bỏ qua hiệu ứng xấu đầu tiên mỗi {8/6/5/4} giây và nhận ít hơn {10/15/20/30}% sát thương từ skill. | `aura_status_immunity` | Misty Terrain; Tiên mùa 1 nhiều hỗ trợ đứng giữa đội hình | Set 3 Mystic / Set 7 Mystic |
| ICE | **Giá Rét** | 2/4/6/8 | Đòn trúng của Pokémon ICE gây 1 tầng lạnh (3 giây, mỗi tầng -{4/6/8/10}% SPEED); tầng thứ 5 làm mục tiêu FREEZE 1 giây và xoá tầng. | `chill_stacks_freeze` | Băng làm chậm rồi đóng băng | Set 1 Glacial |
| FOSSIL | **Vỏ Đá Cổ** | 2/3/4 | Pokémon FOSSIL vào trận với vỏ đá = {20/30/45}% HP tối đa (khiên, miễn khống chế khi còn); vỏ vỡ thì gây {60/100/160} sát thương phép lên kẻ địch ADJACENT và nhận {20/30/45}% ATK. | `shell_burst` | Hệ hiếm; hoá thạch tỉnh dậy khỏi đá | Set 13 Sentinel / Set 4 Divine |
| SOUND | **Nhịp Điệu** | 2/3/5 | Mỗi đòn đánh thứ 3 của Pokémon SOUND phát sóng âm thẳng qua mục tiêu tới mép sàn: {40/70/120} sát thương phép lên mọi kẻ địch trên đường. | `nth_attack_wave` | Hệ hiếm; sóng âm xuyên hàng | Set 14 Rapidfire / Set 5 Cannoneer |
| ARTIFICIAL | **Ép Xung** | 2/3/5 | Mỗi lần Pokémon ARTIFICIAL dùng skill, PP cần cho lần sau giảm {8/12/18}% (tối đa còn 50%). | `cast_cost_down` | Máy chạy càng lâu càng nhanh; công cụ giữa stage giữ nguyên | Set 6 Clockwork / Set 14 Dynamo |
| BABY | **Lớn Nhanh** | 3/5/7 | Mỗi 3 giây trong trận, Pokémon BABY nhận {4/6/9}% ATK gốc và {4/6/9}% HP tối đa gốc (tối đa 8 lần). | `growth_over_time` | Hệ đặc trưng mùa 1: em bé lớn lên ngay trong trận; trứng sau trận thua giữ nguyên | Set 4 Elderwood |
| LIGHT | **Lóe Sáng** | 2/3/4/5 | Đầu trận và mỗi 8 giây, mỗi Pokémon LIGHT lóe sáng: kẻ địch trong 2 ô bị BLINDED {1.5/2/2.5/3} giây; nó nhận {5/8/10/15} AP cho mỗi kẻ bị chói. Ô sáng giữ nguyên. | `periodic_blind_flash` | Hệ hiếm (8 họ) | Set 2 Light / flash |
| WILD | **Cuộc Săn** | 2/4/6/9 | Pokémon WILD luôn nhắm kẻ địch ít HP nhất trong tầm và gây thêm {10/15/22/35}% sát thương lên nó; mỗi lần hạ gục +10% SPEED. | `hunt_lowest_hp` | Hệ đặc trưng mùa 1: thú hoang săn con yếu | Set 9 Slayer / Set 1 Assassin |
| AMORPHOUS | **Đàn Hồi** | 2/3/5 | {25/35/50}% sát thương Pokémon AMORPHOUS nhận được dồn lại, trừ dần trong 3 giây; mỗi lần nó dùng skill, phần còn dồn bị xoá. | `damage_stagger` | Hệ hiếm; thân mềm hấp thụ đòn | Set 19 Ekko (tua ngược sát thương) |
| GOURMET | **Bữa Tiệc** | 3/4/5 | Mỗi khi một kẻ địch gục, Pokémon GOURMET gần nó nhất ăn: hồi {10/14/20}% HP tối đa và nhận vĩnh viễn {20/30/45} HP tối đa trong trận. Mũ đầu bếp giữ nguyên. | `feast_on_enemy_death` | Hệ hiếm; ăn để mạnh lên | Set 18 / Set 12 Hunger |

## 2. Skill mới (phải code)

| Họ | Độ hiếm | Dạng | Skill | Khoá | Mô tả | Ghi chú |
|---|---|---|---|---|---|---|
| Azurill | Thường |  | **Bong Bóng** `BUBBLE` | `fan.first_hit` | Thổi 3/4/5 bong bóng xoè hình quạt về phía mục tiêu; mỗi bong bóng vỡ ở kẻ địch đầu tiên nó chạm: 15/30/60 sát thương phép và -10 SPEED 3 giây. | PP 80; cảm hứng: Set 13 Ezreal / đạn hình quạt |
| Fennekin | Thường |  | **Quỷ Hỏa** `WILL_O_WISP` | `target.vulnerability_mark` | Gắn ma trơi lên mục tiêu 5 giây: BURN, và nó chịu thêm 15/20/30% sát thương từ mọi nguồn. | PP 80; cảm hứng: Set 19 Akali (sơn: Dễ Tổn Thương) |
| Goomy | Thường |  | **Thân Nhầy Hồi Phục** `LIFE_DEW` | `self.rewind` | Hồi lại 40/60/90% sát thương đã nhận trong 3 giây qua, rồi bắn chất nhầy lên kẻ địch ADJACENT: 15/30/60 sát thương phép và -20% SPEED 3 giây. | PP 100; cảm hứng: Set 19 Ekko (tua ngược sát thương) |
| Klink | Thường |  | **Sang Số** `SHIFT_GEAR` | `self.rapid_attacks` | 3/4/5 đòn đánh kế tiếp nhanh gấp đôi và mỗi đòn bắn thêm một bánh răng nảy sang kẻ địch gần mục tiêu: 50% ATK thành sát thương phép. | PP 70; cảm hứng: Set 19 Ashe (loạt tên) |
| Mareep | Thường |  | **Dây Dẫn Điện** `ELECTRO_LINK` | `ally.tether_empower` | Nối dây điện với đồng minh có ATK cao nhất 6 giây: nó +15/25/40 SPEED, mỗi đòn đánh của nó phóng thêm 10/20/40 sát thương phép. | PP 90; cảm hứng: Set 11 Lillia / Karma (nối dây) |
| Rattata | Thường |  | **Nỗ Lực** `ENDEAVOR` | `target.equalize_hp` | Nếu mục tiêu còn nhiều HP hơn nó: kéo HP mục tiêu xuống bằng HP của nó (tối đa 80/160/320 sát thương chuẩn). Không thì gây 20/40/80 sát thương phép. | PP 100; cảm hứng: Endeavor (Pokémon) |
| Cyndaquil | Ít gặp |  | **Thề Ước Lửa** `FIRE_PLEDGE` | `row.zone` | Biển lửa phủ cả hàng của mục tiêu 4 giây: kẻ địch trên hàng bị BURN và chịu 10/20/40 sát thương phép mỗi giây. (Mọi dạng, cả Hisuian Typhlosion.) | PP 100; cảm hứng: Set 9 Brand / vùng cháy |
| Growlithe | Ít gặp |  | **Hộ Vệ Trung Thành** `GUARD_DOG` | `allies_adjacent.redirect_damage` | 4 giây: 30/40/50% sát thương mà đồng minh ADJACENT nhận được chuyển sang nó; nó nhận 20/40/80 SHIELD. | PP 90; cảm hứng: Set 6 Bodyguard / Set 12 Rakan |
| Nidoran♂ | Ít gặp |  | **Chông Độc** `TOXIC_SPIKES` | `ally_front.traps` | Rải 2/3/4 chông độc lên các ô trống ở hàng trước phía mình; kẻ địch bước vào: 30/60/120 sát thương phép và 2 tầng POISON (mỗi chông một lần). | PP 90; cảm hứng: Set 9 Teemo / bẫy |
| Omanyte | Ít gặp |  | **Xúc Tu Siết** `CONSTRICT` | `target.bind_mana_reave` | Quấn mục tiêu 3/3/4 giây: nó bị LOCKED, mất 10/20/40 HP mỗi giây và cần thêm 30% PP để dùng skill trong lúc bị quấn. | PP 90; cảm hứng: Mana Reave (TFT) |
| Piplup | Ít gặp |  | **Màn Sương** `MIST` | `allies_behind.shield_safeguard` | Phủ sương lên 2 đồng minh đứng ngay sau nó: mỗi con 25/50/100 SHIELD và SAFEGUARD 3 giây (miễn hiệu ứng xấu). | PP 90; cảm hứng: Set 7 Guardian (che người phía sau) |
| Sewaddle | Ít gặp |  | **Kéo May Chữ X** `CROSS_CUT` | `x_shape.execute` | Chém chữ X qua mục tiêu (mục tiêu + 4 ô chéo của nó): 20/40/80 sát thương vật lý; kẻ trúng dưới 12/15/18% HP bị hạ gục. | PP 90; cảm hứng: Set 19 Pyke (chữ X, kết liễu) |
| Spinarak | Ít gặp |  | **Mạng Nhện Nối** `SPIDER_WEB` | `two_enemies.damage_link` | Nối tơ 2 kẻ địch gần nhất với nhau 5 giây: mỗi khi một kẻ nhận sát thương, kẻ kia chịu 30/40/50% lượng đó (sát thương chuẩn) và cả hai -15 SPEED. | PP 80; cảm hứng: Set 11 Morgana / liên kết |
| Bulbasaur | Hiếm |  | **Siêu Hút Năng Lượng** `GIGA_DRAIN` | `closest_n.tether_drain` | Cắm dây hút vào 3 kẻ địch gần nhất 4 giây: mỗi giây mỗi kẻ 8/15/30 sát thương phép; nó hồi bằng tổng lượng hút. | PP 100; cảm hứng: Set 19 Thresh (hút máu kẻ địch ở gần) |
| Pancham | Hiếm |  | **Quật Vòng** `CIRCLE_THROW` | `target.throw_behind` | Túm mục tiêu quật ra ô trống sau lưng mình (giữa đội hình mình): 30/60/120 sát thương phép, FLINCH 2 giây. | PP 100; cảm hứng: Set 9.5 Sett |
| Pawmi | Hiếm |  | **Phước Lành Hồi Sinh** `REVIVAL_BLESSING` | `allies.revive_one` | Lần đầu mỗi trận có đồng minh đã gục: hồi sinh con gục gần nhất với 20/30/50% HP. Các lần sau (hoặc chưa ai gục): đấm mục tiêu 30/60/120 sát thương phép và PARALYSIS 1 giây. | PP 120; cảm hứng: Revival Blessing (Pawmot) |
| Trapinch | Hiếm |  | **Hố Cát Kiến Sư Tử** `SAND_PIT` | `pull_nearest.strike` | Kéo kẻ địch gần nhất trong 3 ô sát vào mình; nó bị LOCKED 2/3/4 giây và chịu 30/60/120 sát thương phép. | PP 90; cảm hứng: Set 19 Mordekaiser (kéo kẻ gần nhất) |
| Vanillite | Hiếm |  | **Áo Gương** `MIRROR_COAT` | `self.reflect_special` | 3 giây: 50/75/100% sát thương phép nhận vào dội ngược lên kẻ gây ra (vẫn nhận sát thương); nhận 15/30/60 SHIELD. | PP 90; cảm hứng: Set 3 Rakan / phản đòn phép |
| Vulpix | Hiếm |  | **Hồ Hỏa** `FOX_FIRE` | `marks.stack_detonate` | Đặt lửa hồ ly lên 3/3/4 kẻ địch gần nhất (mỗi kẻ 1 lửa, tối đa 3); kẻ có đủ 3 lửa nổ: 60/120/240 sát thương phép và BURN 3 giây. | PP 70; cảm hứng: Set 19 Mel (cộng dồn Blues) / Ahri |
| Corsola | Sử thi |  | **Hút Sức Mạnh** `STRENGTH_SAP` | `target.sap_heal` | Mục tiêu mất 3/5/8 ATK; Corsola hồi HP bằng 300% ATK của mục tiêu. (Dạng Corsola / Galarian Corsola; Cursola giữ CURSE.) | PP 90; cảm hứng: Strength Sap (Galarian Corsola) |
| Dratini | Sử thi |  | **Bay Tới Cứu** `ALLY_SWITCH` | `ally_lowest.swap_rescue` | Bay tới đổi chỗ với đồng minh ít % HP nhất: đồng minh nhận 30/60/120 SHIELD; Dratini đứng chắn, kẻ địch ADJACENT nơi đến bị FLINCH 2 giây. | PP 100; cảm hứng: Set 9 Shen / Set 17 Rakan (lao tới đồng minh) |
| Dwebble | Sử thi |  | **Quăng Tảng Đá** `SMACK_DOWN` | `backline_cluster.lob` | Ném tảng đá trên lưng vào ô hàng cuối của địch có nhiều kẻ địch quanh nhất: 30/60/120 sát thương phép lên kẻ ở đó và ADJACENT, LOCKED 1 giây. | PP 100; cảm hứng: Set 5 Ziggs / ném vào hậu tuyến |
| Gible | Sử thi |  | **Động Đất** `EARTHQUAKE` | `ring.expanding_wave` | Sóng chấn lan 3 vòng từ nó (1, 2, 3 ô), cách nhau 0,4 giây: mỗi vòng 20/40/80 sát thương phép lên kẻ địch trên vòng đó (trừ hệ FLYING). | PP 100; cảm hứng: Set 9 Sion / vòng lan |
| Rockruff | Sử thi |  | **Phục Kích Đá** `ROCK_AMBUSH` | `self.stealth_ambush` | Ẩn vào vách đá 1,5 giây (không bị nhắm); đòn đánh đầu tiên khi hiện ra chắc chắn chí mạng và gây 150/200/250% ATK. | PP 80; cảm hứng: Set 19 Evelynn (ẩn mình) / Set 6 Shaco |
| Snorunt | Sử thi |  | **Lời Nguyền Đồng Mệnh** `DESTINY_BOND` | `target.destiny_link` | Nối số phận với mục tiêu 5 giây: nếu Snorunt gục trong lúc đó, mục tiêu gục theo; nếu không, hết giờ mục tiêu chịu 40/80/160 sát thương phép và FREEZE 1 giây. | PP 100; cảm hứng: Destiny Bond (Pokémon) |
| Pawniard | Tối thượng |  | **Tổng Tư Lệnh** `SUPREME_OVERLORD` | `all_enemies.execute_low` | Ra lệnh chém: mọi kẻ địch dưới 12/16/22% HP trên sàn bị hạ gục; mỗi kẻ bị hạ cho Pawniard 3/5/8 ATK. Không ai dưới ngưỡng thì chém mục tiêu 100% ATK sát thương chuẩn. | PP 100; cảm hứng: Set 9 Nocturne / Kingambit |
| Venipede | Tối thượng |  | **Chuyền Gậy** `BATON_PASS` | `self.buff_then_pass` | Nhận 10/20/40 SPEED và 4/8/15 ATK 5 giây; khi hết (hoặc khi gục), trao lại chừng đó cho đồng minh ADJACENT có ATK cao nhất tới hết trận. | PP 80; cảm hứng: Baton Pass (Scolipede) |
| Arctovish | Độc nhất |  | **Hàn Khí Nguyên Thuỷ** `PRIMAL_CHILL` | `nova2.slow_stack_aura` | 4 giây toả hàn khí: mỗi giây kẻ địch trong 2 ô mất thêm 20% SPEED và chịu 20 sát thương phép; kẻ bị làm chậm 4 lần thì FREEZE 1,5 giây. | PP 100; cảm hứng: Set 1 Glacial / aura làm chậm |
| Charcadet | Độc nhất | Armarouge | **Pháo Giáp Đồng Loạt** `ARMOR_SALVO` | `all_enemies.split` | Dạng Armarouge: bắn 250 sát thương phép chia đều cho mọi kẻ địch trên sàn (ít kẻ địch thì mỗi kẻ đau hơn). | PP 100; cảm hứng: Set 19 Sona / Baron (chia đều toàn địch) |
| Eiscue (Ice Face) | Độc nhất |  | **Túm Tụm Tuyết** `SNOW_HUDDLE` | `nova.pull_in` | Hút mọi kẻ địch trong 2 ô sát vào quanh mình; những kẻ bị hút FREEZE 1 giây và chịu 40 sát thương phép. | PP 90; cảm hứng: Set 3 Lux / Orianna (kéo vào giữa) |
| Emolga | Độc nhất |  | **Ảnh Phân Thân** `DOUBLE_TEAM` | `self.decoy_dodge` | Tạo 3 ảo ảnh quanh mình: mỗi ảo ảnh hút trọn một đòn đánh hoặc skill đơn mục tiêu nhắm vào nó; còn ảo ảnh thì +20 SPEED. | PP 80; cảm hứng: Set 4 Shen / né đòn |
| Galarian Farfetch'd | Độc nhất |  | **Gạt Kiếm** `PARRY` | `self.counter_stance` | Thế thủ 3 giây: 3 đòn đánh đầu tiên nhắm vào nó bị gạt (không sát thương), mỗi lần gạt đâm trả 120% ATK sát thương vật lý. | PP 90; cảm hứng: Set 5 Riven / Set 8 Samira (phản đòn) |
| Hawlucha | Độc nhất |  | **Thả Từ Trời** `SKY_DROP` | `target.sky_drop` | Túm mục tiêu bay lên 1,5 giây (cả hai không bị nhắm, mục tiêu không làm gì), rồi quật xuống ô cũ: 150 sát thương vật lý, kẻ địch ADJACENT 60. | PP 100; cảm hứng: Set 9.5 Sett (quật) / banish |
| Heatmor | Độc nhất |  | **Thiêu Rụi** `INCINERATE` | `burst.shield_strip` | Phun lửa lên mục tiêu và kẻ địch ADJACENT nó: xoá khiên của chúng, gây 30 + 100% lượng khiên bị xoá thành sát thương phép và BURN 3 giây. | PP 90; cảm hứng: Set 8 Shred / Scalescorn |
| Latios | Độc nhất |  | **Thần Giao Cách Cảm** `MIND_LINK` | `ally.share_damage_link` | Nối tâm trí với đồng minh mạnh nhất 6 giây: sát thương hai bên nhận được chia đôi cho nhau; cả hai +40 AP. | PP 90; cảm hứng: Spirit Link / Set 9 Shen |
| Maractus | Độc nhất |  | **Vũ Điệu Maraca** `MARACA_DANCE` | `zone.ally_heal_haste` | Tạo sàn nhảy bán kính 2 quanh mình 5 giây: đồng minh trong vùng +25% SPEED và hồi 3% HP tối đa mỗi giây. | PP 100; cảm hứng: Set 10 Disco / Set 19 Pop Bãi Biển |
| Mesprit | Độc nhất |  | **Hút Cảm Xúc** `EMOTION_DRAIN` | `highest_ap.steal_silence` | Kẻ địch có AP cao nhất mất 40 AP (Mesprit nhận lượng đó) và bị SILENCE 2,5 giây. | PP 90; cảm hứng: Set 14 Cypher (cướp chỉ số) |
| Mimikyu | Độc nhất |  | **Vá Lốt** `DISGUISE_PATCH` | `allies_lowest.block_next` | Vá lốt cho bản thân và 2 đồng minh ít % HP nhất: lần trúng đòn kế tiếp của mỗi con bị chặn, kẻ tấn công chịu 40 sát thương phép. | PP 90; cảm hứng: Disguise (Mimikyu) |
| Orthworm | Độc nhất |  | **Đất Lún** `EARTH_EATER` | `burst.zone` | Biến các ô quanh mục tiêu (bán kính 1) thành cát lún 4 giây: kẻ địch trong đó -50% SPEED và mất 30 HP mỗi giây; Orthworm hồi bằng tổng. | PP 100; cảm hứng: Set 18 / vùng làm chậm |
| Scream Tail | Độc nhất |  | **Khúc Ca Diệt Vong** `PERISH_SONG` | `nova2.countdown_doom` | Mọi Pokémon khác trong 2 ô (cả đồng minh) nghe bài hát: 4 giây sau chịu 25% HP tối đa thành sát thương chuẩn (đồng minh chỉ 10%). | PP 100; cảm hứng: Perish Song (Pokémon) |
| Stonjourner | Độc nhất |  | **Điểm Năng Lượng** `POWER_SPOT` | `allies_adjacent.ability_power` | Vòng đá cổ: đồng minh ADJACENT +40 AP trong 6 giây và nhận 30 SHIELD. | PP 90; cảm hứng: Power Spot (Stonjourner) |
| Tropius | Độc nhất |  | **Chuyền Quả** `FRUIT_TOSS` | `chain.heal_allies` | Hái quả trên cổ ném chuyền qua 4 đồng minh ít % HP nhất: lần đầu hồi 80 HP, mỗi lần chuyền sau ít hơn 20%; đồng minh cuối +10 SPEED. | PP 90; cảm hứng: Set 2 Taliyah (nảy) / healer |
| Zeraora | Độc nhất |  | **Chớp Plasma Liên Hoàn** `PLASMA_BLITZ` | `dash_chain.n_enemies` | Lao lần lượt tới 3 kẻ địch gần nhau nhất, mỗi kẻ một cú đấm 40 + 60% ATK sát thương phép; mỗi cú +10 SPEED tới hết trận. | PP 90; cảm hứng: Set 6 Yone / Master Yi (lướt nhiều mục tiêu) |
| Celebi | Huyền thoại |  | **Ngược Dòng Thời Gian** `TIME_REWIND` | `team.rewind_hp` | Mọi đồng minh trở về lượng HP của 3 giây trước (nếu khi đó cao hơn) và được giải hiệu ứng xấu. | PP 100; cảm hứng: Set 19 Ekko (tua ngược) cho cả đội |
| Enamorus | Huyền thoại |  | **Tình Tay Ba** `LOVE_TANGLE` | `two_enemies.infatuate` | 2 kẻ địch gần nhất phải lòng nhau 3 giây: chúng đánh nhau (CHARM về phía nhau) và nhận 30% sát thương nhiều hơn. | PP 90; cảm hứng: Set 17 / charm |
| Melmetal | Huyền thoại |  | **Nện Thép** `IRON_SLAM` | `target.slam_into_cluster` | Nhấc mục tiêu lên rồi nện vào ô ADJACENT nó có nhiều kẻ địch nhất: mục tiêu 120% ATK, kẻ địch quanh chỗ nện 80% ATK sát thương vật lý, FLINCH 2 giây. | PP 100; cảm hứng: Set 9 Sion / Set 3 Gnar (ném vào nhau) |
| Okidogi | Huyền thoại |  | **Xích Kéo Độc** `CHAIN_DRAG` | `closest_n.chain_pull` | Quăng xích độc vào 3 kẻ địch gần nhất: kéo mỗi kẻ lại gần 1 ô, 2 tầng POISON; mỗi kẻ bị xích cho Okidogi 5 DEF và 5 SPE_DEF. | PP 90; cảm hứng: Set 9 Darius / Nautilus |
| Registeel | Huyền thoại |  | **Pháo Điện Khoá Mục Tiêu** `ZAP_LOCK` | `highest_atk.lock_on_delayed` | Khoá kẻ địch có ATK cao nhất; 1,5 giây sau pháo điện trúng chắc chắn: 150 sát thương phép, PARALYSIS 2 giây; trong lúc tê liệt, đòn đánh vào nó +30% tỉ lệ chí mạng. | PP 100; cảm hứng: Lock-On + Zap Cannon (Pokémon) |
| Suicune | Huyền thoại |  | **Sóng Đẩy Thanh Tẩy** `TIDAL_PUSH` | `all_enemies.push` | Một đợt sóng quét sàn: mọi kẻ địch bị đẩy lùi 1 ô, chịu 30 + 8% HP tối đa của chúng thành sát thương phép và mất mọi hiệu ứng tốt. | PP 100; cảm hứng: Set 2 Ocean / sóng đẩy |
| Axew | Trứng |  | **Long Nộ Tích Tụ** `DRAGON_FURY` | `target.consume_stacks` | Mỗi đòn đánh trúng tích 1 nộ (tối đa 20). Skill tiêu hết nộ: chém mục tiêu 30/60/120 sát thương phép, +6% mỗi nộ. | PP 80; cảm hứng: Set 19 Smeech (Nhịp) |
| Popplio | Trứng |  | **Bóng Nước Che Chở** `BUBBLE_STASIS` | `allies_lowest.bubble_stasis` | Bọc 2 đồng minh ít % HP nhất trong bong bóng 2 giây: không bị nhắm, không hành động, hồi 10/20/40 HP mỗi 0,5 giây. | PP 90; cảm hứng: Set 4 Zilean / stasis |
| Sandile | Trứng |  | **Rình Cướp** `SNATCH` | `enemy_buffs.redirect` | 4 giây: mọi buff chỉ số, khiên và hồi máu mà kẻ địch nhận được bị chuyển sang Sandile; nó đánh kèm 20/40/80 sát thương phép lên mục tiêu. | PP 90; cảm hứng: Snatch (Pokémon) |
| Scatterbug | Trứng |  | **Phấn Cánh Bướm** `WING_POWDER` | `closest_allies.random_buffs` | Rắc phấn lên 3 đồng minh gần nhất: mỗi con nhận ngẫu nhiên một trong +20/40/80 SHIELD, +10/20/40 AP, +10/15/25 SPEED (theo hoa văn Vivillon). | PP 80; cảm hứng: Set 19 Kết Hợp / buff ngẫu nhiên |

## 3. Skill mượn (đã có trong game)

| Họ | Độ hiếm | Dạng | Skill | Khoá | Mô tả | Ghi chú |
|---|---|---|---|---|---|---|
| Charmander | Thường |  | **Cơn Giận Rồng** `DRAGON_RAGE` | `nova.channel_shield` | Nhận 15/30/45 SHIELD. Mỗi giây trong 6 giây: +5/10/15 SHIELD và 5/10/15 sát thương phép lên kẻ địch kề bên. Sau đó phần SHIELD đã nhận còn lại đổi thành hồi máu bằng 40% của nó. | của Magikarp: Rồng lửa: khiên + đốt quanh mình 6 giây, hợp đấu sĩ hàng đầu |
| Poliwag | Thường |  | **Đồng Điệu** `ENTRAINMENT` | `target.replace_skill` | Nhận 10 PP; kỹ năng của mục tiêu trở thành Đồng Điệu. | của Audino: Vòng xoáy thôi miên: kỹ năng của mục tiêu bị thay bằng Đồng Điệu |
| Spearow | Thường |  | **Mổ Khoan** `DRILL_PECK` | `target.swap_chain` | Gây 30/60/120 sát thương phép và đổi chỗ với mục tiêu. Nếu ngay sau có kẻ địch, kẻ đó thành mục tiêu kế và hồi đầy PP. | của Doduo: Fearow học Drill Peck; mổ xuyên đội hình |
| Swinub | Thường |  | **Rãnh Nứt** `FISSURE` | `random_cells.burst` | Mở 2/3/4 khe nứt ở ô ngẫu nhiên: 25/50/75 sát thương phép lên kẻ địch trên ô và xung quanh. | của Barboach: Mamoswine: Đất + nứt băng |
| Weedle | Thường |  | **Kim Châm Kết Liễu** `FELL_STINGER` | `target.grow_on_kill` | Gây 400% ATK gốc sát thương phép; hạ gục thì nhận +30% ATK gốc. | của Poipole: Beedrill học Fell Stinger |
| Archen | Ít gặp |  | **Nhào Lộn** `ACROBATICS` | `target.hit_and_retreat` | Gây 20/40/80/160 Sát thương đặc biệt và di chuyển đến một ô cách xa mục tiêu. Di chuyển xa hơn nếu không cầm bất kỳ vật phẩm nào | của Hoppip: Archeops học Acrobatics; xạ thủ đánh rồi lùi |
| Impidimp | Ít gặp |  | **Hằn Học** `SPITE` | `target.pp_drain_to_allies` | Rút 20/40/60 PP của mục tiêu và chia cho các đồng minh kề bên. | của Yamask: Tiểu yêu chơi khăm: rút PP chia cho đồng đội |
| Nacli | Ít gặp |  | **Giáp Sắt** `IRON_DEFENSE` | `allies_row.shield` | Tăng 20/40/80/160 chỉ số Khiên cho đồng minh cùng hàng | của Shieldon: Tường muối che cả hàng |
| Quaxly | Ít gặp |  | **Vũ Điệu Lông Vũ** `FEATHER_DANCE` | `dash_farthest.feather_trail` | Bay tới kẻ địch xa nhất; 8/10/12 chiếc lông rơi trên đường bay: đồng minh được cộng, kẻ địch bị trừ HP, ATK, DEF, AP, SPE_DEF, SPEED hoặc LUCK. | của Ducklett: Quaquaval là vũ công |
| Skrelp | Ít gặp |  | **Kim Độc** `POISON_STING` | `target.stack_overflow` | Thêm 2/3/4 tầng POISON; mỗi tầng vượt giới hạn gây 25/50/100 sát thương phép. | của Skorupi: Tảo độc dồn tầng, tràn tầng thành sát thương |
| Phanpy | Hiếm |  | **Lao Đầu** `HEADLONG_RUSH` | `dash_farthest.sweep` | Lao tới kẻ địch xa nhất, gạt kẻ địch trên đường sang bên: 20/40/80 sát thương phép lên nó, 10/20/30 lên những kẻ khác. | của Great Tusk: Great Tusk là Donphan nghịch thời |
| Poochyena | Hiếm |  | **Đánh Hội Đồng** `BEAT_UP` | `summon.pack` | Triệu hồi 1/2/3/5 Houndour (100% Máu, không có trang bị) | của Houndour: Mightyena săn theo bầy |
| Taillow | Hiếm |  | **Anh Dũng Điểu** `BRAVE_BIRD` | `self.retreat_pull` | Bay tới chỗ an toàn, kéo mục tiêu tới sát bên và gây 30/60/90 sát thương phép. | của Starly: Swellow học Brave Bird |
| Totodile | Hiếm |  | **Khoá Hàm** `JAW_LOCK` | `target.lock_rebite` | LOCKED 3 giây và 125% ATK + 10/15/20 sát thương phép; cắn lại cùng mục tiêu thì hồi 25/50/100 HP. | của Chewtle: Feraligatr cắn giữ |
| Toxel | Hiếm |  | **Náo Loạn** `UPROAR` | `in_range.channel` | Trong 3 giây, gây 5/10/20 sát thương phép mỗi giây lên mọi kẻ địch trong tầm đánh. | của Whismur: Toxtricity chơi rock: náo loạn |
| Wooper | Hiếm |  | **Ngáp** `YAWN` | `targeters.punish_shield` | Kẻ địch đang nhắm vào nó bị FATIGUE 3 giây và mất 20 AP; nhận 15/30/60 SHIELD. | của Slowpoke: Quagsire học Yawn; đỡ đòn lười biếng |
| Zigzagoon | Hiếm |  | **Thu Nhặt** `PICKUP` | `target.disarm` | Lấy item đầu tiên của mục tiêu, rồi gây 30/60/120 sát thương phép. | của Alolan Meowth: Nội tại gốc của Zigzagoon là Pickup |
| Bonsly | Sử thi |  | **Bắt Chước** `MIMIC` | `target.copy_skill` | Sao chép chiêu thức của mục tiêu hiện tại | của Mime Jr.: Sudowoodo giả cây: bắt chước |
| Bounsweet | Sử thi |  | **Lên Gối** `HIGH_JUMP_KICK` | `target.pp_steal` | Gây 15/30/60/120 Sát thương đặc biệt và đánh cắp tới 40 Mana từ mục tiêu | của Buneary: Tsareena là nữ hoàng cú đá |
| Darumaka | Sử thi |  | **Va Chạm Nhiệt** `HEAT_CRASH` | `target.scale_atk_gap` | Lao vào mục tiêu: 40/60/80 sát thương phép cộng hai lần phần ATK vượt ATK mục tiêu, và hất lùi nó. | của Tepig: Darmanitan nặng và nóng |
| Exeggcute | Sử thi |  | **Bùa Chú Kỳ Quái** `EERIE_SPELL` | `chain.mixed_lowest` | Bùa chú nảy 4 lần tới các Pokémon ít HP nhất: đồng minh hồi 15/30/45 HP, kẻ địch chịu 10/20/40 sát thương phép. | của Galarian Slowpoke: Trứng siêu linh nảy giữa hai phe |
| Oshawott | Sử thi | Hisuian Samurott | **Kết Án** `ASSURANCE` | `target.bonus_when_self_low` | Gây 25/50/100 sát thương phép, gấp đôi nếu bản thân dưới 50% HP. | của Scraggy: Chỉ dạng Hisui (Ác): càng đau càng chém mạnh |
| Ponyta | Sử thi |  | **Lửa Chữ Đại** `FIRE_BLAST` | `star.plain` | Vụ nổ hình ngôi sao ở mục tiêu: 30/60/110 sát thương phép lên mọi kẻ địch trong đó. | của Ho-Oh: Rapidash học Fire Blast; vùng hình sao |
| Fletchling | Tối thượng |  | **Thiên Công Không Kích** `SKY_ATTACK` | `airborne.dive_farthest` | Bay lên ngoài tầm đánh, đáp xuống cạnh kẻ địch xa nhất và 1 giây sau bổ vào nó 30/60/120 sát thương phép. | của Lugia: Talonflame bổ nhào từ trời |
| Shinx | Tối thượng |  | **Lưới Điện** `ELECTRO_WEB` | `nova.speed_steal` | Đánh cắp 15/30/60/120 Tốc độ từ các Pokémon đối thủ ở gần và gây 15/30/60/120 Sát thương đặc biệt | của Joltik: Luxray hút tốc độ con mồi |
| Bruxish | Độc nhất |  | **Hoán Vị Tâm Linh** `PSYCHO_SHIFT` | `two_enemies.swap` | Kẻ địch xa nhất đổi chỗ với mục tiêu; cả hai chịu 20/40/60 sát thương phép. | của Sigilyph: Cá siêu linh làm loạn vị trí địch |
| Carnivine | Độc nhất |  | **Bắn Mỏ Neo** `ANCHOR_SHOT` | `hook_farthest.strike` | Kéo kẻ địch xa nhất tới cạnh mình và gây 20/40/80 sát thương phép. | của Dhelmise: Cây bắt mồi kéo con mồi về |
| Charcadet | Độc nhất |  | **Bẫy Vỏ Nhiệt** `SHELL_TRAP` | `self.shield_detonate` | Nếu có khiên: làm nổ khiên, kẻ địch xung quanh chịu 50 + lượng khiên thành sát thương phép. Nếu không thì nhận 25/50/75 SHIELD. | của Turtonator: Chỉ dạng Charcadet: giáp lửa nổ |
| Chatot | Độc nhất |  | **Diễn Lại** `ENCORE` | `team.repeat_last_cast` | Dùng lại kỹ năng cuối cùng mà đội mình đã dùng. | của Minccino: Vẹt nhại lại kỹ năng của đồng đội |
| Farfetch'd | Độc nhất |  | **Trợ Giúp** `HELPING_HAND` | `closest_allies.next_cast_double` | 2 đồng minh gần nhất nhận 30/60/100 SHIELD và kỹ năng kế tiếp của chúng gây gấp đôi sát thương. | của Sentret: Chia cọng hành cho đồng đội |
| Kubfu | Độc nhất | Urshifu | **Đấm Tập Trung** `FOCUS_PUNCH` | `target.delayed_ringout` | Sau 0,9 giây, đấm văng mục tiêu ra khỏi sàn nếu phía sau trống; nếu không thì gây 500% ATK sát thương phép và đẩy nó đi xa nhất có thể. | của (chưa Pokémon nào dùng): Hai dạng Urshifu: tụ lực rồi đấm văng khỏi sàn |
| Pachirisu | Độc nhất |  | **Theo Tôi** `FOLLOW_ME` | `self.retreat_charm_targeters` | Nhảy ra xa và nhận 10/20/40 SHIELD; kẻ địch từng nhắm vào nó bị CHARM 1/2/3 giây. | của Indeedee: Follow Me là chiêu nổi tiếng của Pachirisu |
| Togedemaru | Độc nhất |  | **Phản Trọng Trường** `MAGNET_RISE` | `allies_weakest_adjacent.protect` | Bản thân và 2/4/6 đồng minh yếu nhất kề bên nhận PROTECT 2 giây và 10% né tránh. | của Nosepass: Điện + Thép, nhấc đồng đội lên bằng từ trường |

## 4. Skill giữ nguyên (web)

| Họ | Độ hiếm | Dạng | Skill | Khoá | Mô tả | Ghi chú |
|---|---|---|---|---|---|---|
| Aron | Thường |  | **Thân Trọng Xung Kích** `HEAVY_SLAM` | `nova.scale_hp_gap` | Nện đất: 15/30/60 sát thương phép lên kẻ địch kề bên, tăng theo phần HP tối đa nhiều hơn mục tiêu (x 1 + nửa phần chênh lệch tính theo % HP tối đa của mục tiêu). |  |
| Chespin | Thường |  | **Giáp Gai** `SPIKY_SHIELD` | `self.thorns` | Gây 60/80/100% DEF thành sát thương phép lên mục tiêu và khoác giáp gai trong 3/5/10 giây. |  |
| Geodude | Thường |  | **Đá Lở** `ROCK_SLIDE` | `target.bonus_vs_type` | Gây 30/60/120 sát thương phép lên mục tiêu, gấp đôi nếu là hệ FLYING. |  |
| Lillipup | Thường |  | **Báo Thù** `RETALIATE` | `target.fallen_allies` | Đánh mục tiêu 150% ATK thành sát thương phép, thêm một lần cho mỗi đồng minh đã ngã. |  |
| Pichu | Thường |  | **Cọ Má** `NUZZLE` | `dash_farthest.strike` | Lao tới cạnh kẻ địch xa nhất, làm nó tê liệt 3 giây và gây 25/50/100 sát thương phép. |  |
| Smoliv | Thường |  | **Xung Địa Hình** `TERRAIN_PULSE` | `allies.terrain_spread` | Nếu chưa có thảm thì nhận Thảm Cỏ. Thảm của đội lan sang đồng minh kề bên chưa có thảm, rồi mỗi đồng minh có thảm: Cỏ hồi 5/7/10% HP tối đa, Điện +10/12/15 SPEED, Siêu Linh +10/12/15 PP, Tiên 5/7/10% HP tối đa thành SHIELD. |  |
| Sprigatito | Thường |  | **Mánh Hoa** `FLOWER_TRICK` | `burst.delayed` | Cắm một bông hoa lên mục tiêu, sau 3 giây phát nổ lên mục tiêu và 8 ô quanh nó, gây 15/40/85 sát thương phép. |  |
| Zubat | Thường |  | **Hút Máu** `LEECH_LIFE` | `target.lifesteal` | Gây 20/40/80 sát thương phép và hồi máu bằng lượng sát thương gây ra. |  |
| Aipom | Ít gặp |  | **Cù Lét** `TICKLE` | `closest_n.debuff_only` | 1/2/3 kẻ địch gần nhất mất 3 ATK và 3 DEF. |  |
| Duskull | Ít gặp |  | **Ám Cầu** `SHADOW_BALL` | `target.team_wide_debuff` | Gây 30/60/100 sát thương phép lên mục tiêu; mọi kẻ địch mất 2 SPE_DEF. |  |
| Flabébé | Ít gặp |  | **Gió Tiên** `FAIRY_WIND` | `allies.pp` | Mọi đồng minh khác nhận 5/10/20 PP. |  |
| Glameow | Ít gặp |  | **Vênh Váo** `SWAGGER` | `target.status_only` | CONFUSION và RAGE 1,5/2/3 giây lên mục tiêu. |  |
| Hatenna | Ít gặp |  | **Bột Ma Thuật** `MAGIC_POWDER` | `nova.status` | Nhận 15/30/60 khiên và làm câm lặng kẻ địch trên 8 ô quanh mình trong 2/3/4 giây. |  |
| Horsea | Ít gặp |  | **Xoáy Nước** `WHIRLPOOL` | `projectile.first_hit_multi` | Tung xoáy nước về phía kẻ địch xa nhất; kẻ địch đầu tiên trên đường chịu 4 đòn, mỗi đòn 100% ATK thành sát thương phép. |  |
| Igglybuff | Ít gặp |  | **Ca Hát** `SING` | `backline_n.status` | Ru ngủ 1/2/3 kẻ địch ở tuyến sau cùng trong 2 giây. |  |
| Magnemite | Ít gặp |  | **Bom Nam Châm** `MAGNET_BOMB` | `burst.pull` | 20/40/80 sát thương phép lên mục tiêu và 10/20/40 lên kẻ địch quanh nó; kẻ địch cách 2 ô bị hút lại sát nó. Mọi kẻ trúng đòn hoặc bị hút bị LOCKED 1.5 giây. |  |
| Smoochum | Ít gặp |  | **Nụ Hôn Đáng Yêu** `LOVELY_KISS` | `target.status_or_payoff` | Mục tiêu đang ngủ chịu 50/100/150 sát thương phép; nếu không thì bị SLEEP 2/4/6 giây. |  |
| Spheal | Ít gặp |  | **Bóng Băng** `ICE_BALL` | `target.scale_own_stat` | Nhận 10 SPE_DEF, rồi gây 10/20/30 + 50/100/150% SPE_DEF thành sát thương phép. |  |
| Treecko | Ít gặp |  | **Diệp Đao** `LEAF_BLADE` | `target.crit` | Một đòn chắc chắn chí mạng, gây 100/125/150% ATK thành sát thương chuẩn. |  |
| Voltorb | Ít gặp |  | **Vụ Nổ Lớn** `EXPLOSION` | `nova.self_damage` | Gây 50/100/200/400 Sát thương đặc biệt cho tất cả đối thủ gần nhất. Gây sát thương lên bản thân |  |
| Bunnelby | Hiếm |  | **Đào Tai** `EAR_DIG` | `target.ground_hole` | Gây 30/60/120 sát thương phép, +5/10/20 theo độ sâu của hố dưới mục tiêu; đào hố nếu chưa có. |  |
| Cutiefly | Hiếm |  | **Bánh Phấn Hoa** `POLLEN_PUFF` | `ally_lowest.heal` | Đồng minh ít HP nhất hồi 30/60/120 HP. |  |
| Deino | Hiếm |  | **Ám Vụ Thu Thập** `DARK_HARVEST` | `jump_cluster.dot_lifesteal` | Nhảy tới ô bị nhiều kẻ địch bao quanh nhất, rồi trong 3 giây 8 ô quanh nó chịu 5/10/20 sát thương phép mỗi giây; hồi máu bằng 30% lượng đó. |  |
| Fomantis | Hiếm |  | **Kiếm Mặt Trời** `SOLAR_BLADE` | `front.charge` | Nạp 2 giây (tức thì trên ô ánh sáng), rồi kẻ địch phía trước chịu 30/60/120 sát thương chuẩn. |  |
| Honedge | Hiếm |  | **Khiên Của Nhà Vưa** `KING_SHIELD` | `self.protect_swap` | Tự bảo vệ 1.5 giây, nhận 10/20/40 khiên và đổi chỗ với kẻ địch xa nhất. |  |
| Larvitar | Hiếm |  | **Truy Đuổi** `PURSUIT` | `target.mark_pursue` | Gây 35/70/140 sát thương phép lên mục tiêu và đánh dấu nó: nếu nó nhảy hoặc dịch chuyển, nhảy theo tới cạnh nó và dùng kỹ năng lần nữa. |  |
| Magby | Hiếm |  | **Phun Lửa** `FLAMETHROWER` | `cone.plain` | Phun lửa về hướng mục tiêu, tới 3 ô: 30/60/120 sát thương phép và bỏng 4 giây. |  |
| Torchic | Hiếm |  | **Cú Đá Lửa** `BLAZE_KICK` | `target.knockback` | Gây 30/60/120 sát thương phép (x1.3 nếu đang bỏng), gây bỏng 2 giây và đá văng mục tiêu ra xa nhất có thể. |  |
| Turtwig | Hiếm |  | **Ủi Đất** `BULLDOZE` | `nova.knockback` | Kẻ địch trên 8 ô quanh mình chịu 25/45/85 sát thương phép, mất 10 SPEED và bị đẩy lùi 1 ô. |  |
| Amaura | Sử thi |  | **Bão Tuyết** `HAIL` | `random_cells.zone` | 8/15/30 hạt mưa đá rơi xuống các ô ngẫu nhiên phía mục tiêu: 50 sát thương phép và FREEZE 1 giây lên kẻ địch ở đó; ô vẫn còn mưa đá (10 sát thương phép và FREEZE 1 giây lên kẻ bước vào). |  |
| Beldum | Sử thi |  | **Quyền Sao Chổi** `METEOR_MASH` | `target.multi_hit` | Đánh mục tiêu 3 lần, mỗi lần 100/120/140% ATK thành sát thương phép, nhận 2 ATK mỗi đòn. |  |
| Budew | Sử thi |  | **Vũ Điệu Cánh Hoa** `PETAL_DANCE` | `closest_n.projectiles` | Ném 3/4/5 cánh hoa vào các kẻ địch gần nhất, mỗi cánh 20/30/50 sát thương phép. |  |
| Corsola | Sử thi | Cursola | **Nguyền Rủa** `CURSE` | `highest_hp.doom` | Một kẻ địch ngẫu nhiên trong số kẻ có HP tối đa cao nhất bị CURSE: gục sau 8/5/3 giây, ngắn hơn nhờ AP. | dạng rẽ nhánh |
| Helioptile | Sử thi |  | **Điện Kích Parabol** `PARABOLIC_CHARGE` | `self.heal_then_strike` | Hồi 25/50/75 HP, rồi gây 25/50/100 sát thương phép cộng phần hồi dư. |  |
| Oshawott | Sử thi |  | **Đuôi Nước** `AQUA_TAIL` | `target.self_gain` | Gây 30/60/100 sát thương phép và nhận 30/60/100 khiên. |  |
| Ralts | Sử thi |  | **Tương Lai Thấu Thị** `FUTURE_SIGHT` | `closest_n.delayed` | Đánh dấu 3/4/5 kẻ địch gần nhất; 2 giây sau mỗi kẻ chịu 20/30/50 sát thương phép, 20% lượng đó lan ra 8 ô xung quanh. |  |
| Ralts | Sử thi | Gallade | **Nhát Chém Tâm Linh** `PSYCHO_CUT` | `line.multi_hit` | Chém theo đường thẳng về phía mục tiêu tới mép sàn: mọi kẻ địch trên đường chịu 10/20/40 sát thương phép 3 lần. | dạng rẽ nhánh |
| Tinkatink | Sử thi |  | **Búa Nặng Ngàn Tấn** `GIGATON_HAMMER` | `target.drawback` | Gây 100/200/400 sát thương phép, rồi bị mệt mỏi 6 giây. |  |
| Wimpod | Sử thi |  | **Ấn Tượng Đầu** `FIRST_IMPRESSION` | `target.first_cast_summon` | Gây 45/90/180 sát thương phép và FLINCH 5 giây. Lần dùng đầu tiên, nhảy tới chỗ an toàn và một Pokémon hệ Bọ xuất hiện ở chỗ cũ. |  |
| Frigibax | Tối thượng |  | **Lao Kiếm** `GLAIVE_RUSH` | `dash_path.plain` | Lao tới đầu kia của sàn: kẻ địch trên đường chịu 50/100/200 sát thương phép; mọi kẻ trúng đòn (và chính nó) bị phá giáp 6 giây. |  |
| Gastly | Tối thượng |  | **Ác Mộng** `NIGHTMARE` | `all_enemies.status` | Mọi kẻ địch bị FATIGUE (nhận PP giảm nửa) 2/4/6 giây; kẻ đang bị lời nguyền Ma còn chịu 25/50/100 sát thương phép. |  |
| Grookey | Tối thượng |  | **Gõ Trống** `DRUM_BEATING` | `team.cycle` | Luân phiên 3 nhịp trống: cả đội +10/20/40 SPEED, cả đội +10/20/40 khiên, mọi kẻ địch chịu 10/20/40 sát thương phép. |  |
| Happiny | Tối thượng |  | **Trứng Lòng Đào** `SOFT_BOILED` | `team.shield_cleanse` | Mọi đồng minh nhận 20/40/80 khiên và được giải trạng thái xấu. |  |
| Porygon | Tối thượng |  | **Tam Thể Kích** `TRI_ATTACK` | `target.plain` | Đóng băng 3 giây, gây bỏng 5 giây hoặc tê liệt 7 giây mục tiêu (ngẫu nhiên), và gây 60/120/250 sát thương phép. |  |
| Rhyhorn | Tối thượng |  | **Khoan Sừng** `HORN_DRILL` | `target.execute` | Gây 300/400/500% ATK thành sát thương phép, 30% hạ gục ngay mục tiêu (cao hơn nếu ATK của nó cao hơn). |  |
| Sobble | Tối thượng |  | **Xuyên Tâm Thủy Kích** `SNIPE_SHOT` | `line.plain` | Bắn kẻ địch xa nhất: mọi kẻ địch trên các ô ở giữa chịu 40/80/160 sát thương phép. |  |
| Solosis | Tối thượng |  | **Tâm Linh Xuất Thần** `PSYCHIC` | `burst.plain` | Mục tiêu và 8 ô quanh nó: 40/80/160 sát thương phép và -15 PP. |  |
| Charcadet | Độc nhất | Ceruledge | **Kiếm Cay Đắng** `BITTER_BLADE` | `nova.lifesteal_per_hit` | Kẻ địch kề bên chịu 50/60/70 sát thương phép; hồi 10% HP tối đa mỗi kẻ địch trúng đòn. | dạng rẽ nhánh |
| Comfey | Độc nhất |  | **Thảo Mộc Chữa Lành** `FLORAL_HEALING` | `self.heal` | Hồi lượng HP bằng PP tối đa. |  |
| Druddigon | Độc nhất |  | **Cơn Thịnh Nộ Của Rồng** `OUTRAGE` | `cleave.self_confusion` | Bị CONFUSION 2 giây và gây 300% ATK sát thương phép lên mục tiêu cùng đồng đội của nó kề bên bản thân. |  |
| Duraludon | Độc nhất |  | **Bắn Điện** `ELECTRO_SHOT` | `line.charge` | Nạp 2 giây (tức thì khi có STORM), nhận 40 AP và gây 80/100/120 sát thương phép trên một đường thẳng. |  |
| Gimmighoul | Độc nhất |  | **Cơn Sốt Vàng** `GOLD_RUSH` | `target.gold` | Gây 20 sát thương phép + 1 mỗi vàng của người chơi, và kiếm 2 vàng. |  |
| Hisuian Qwilfish | Độc nhất |  | **Ngàn Kim Cực Độc** `BARB_BARRAGE` | `jump_cluster.plain` | Nhảy tới chỗ kẻ địch đông nhất; mục tiêu và đồng đội ADJACENT của nó bị POISON 3 giây và chịu 15/30/45 sát thương phép. |  |
| Klefki | Độc nhất |  | **Xiềng Xích Tiên Linh** `FAIRY_LOCK` | `burst.split` | LOCKED 5 giây; 50/70/90 sát thương phép chia đều cho mục tiêu và kẻ địch xung quanh. |  |
| Kubfu | Độc nhất |  | **Âm Tốc Quyền** `MACH_PUNCH` | `target.instant_attack` | Gây 25/50/100/200 Sát thương đặc biệt và tấn công đối thủ sau đó ngay lập tức |  |
| Latias | Độc nhất |  | **Hà Sương Linh Cầu** `MIST_BALL` | `boomerang.plain` | Quả cầu đi rồi quay lại qua đường thẳng: mỗi lần 10/20/30 sát thương phép và -30 AP. |  |
| Lunatone | Độc nhất |  | **Năng Lượng Vũ Trụ (Moon)** `COSMIC_POWER_MOON` | `team.ap` | Tăng 25/25/25/50 Sức mạnh kĩ năng cho tất cả đồng minh |  |
| Mantyke | Độc nhất |  | **Nảy Bật** `BOUNCE` | `hop_n.nova` | Nảy 1/2/3 lần tới cạnh kẻ địch xa nhất: kẻ địch kề bên chịu 15/20/25 sát thương phép. |  |
| Milcery | Độc nhất |  | **Trang Trí** `DECORATE` | `ally_strongest.buff` | Đồng minh gần nhất mạnh nhất nhận 1/2/3 ATK, 10/20/30 AP và thưởng theo vị của Alcremie. |  |
| Pinsir | Độc nhất |  | **Máy Chém** `GUILLOTINE` | `target.refund_on_kill` | Gây 300% ATK thành sát thương phép. Hoàn lại một nửa PP nếu hạ gục. |  |
| Qwilfish | Độc nhất |  | **Tích Trữ** `STOCKPILE` | `self.stack_then_burst` | Nhận 30/40/50 HP tối đa nhưng mất 10 SPEED; mỗi lần dùng thứ 4 phun ra 50% HP tối đa thành sát thương phép. |  |
| Shuckle | Độc nhất |  | **Chịu Đựng** `BIDE` | `self.store_release` | Tích sát thương nhận vào trong 3 giây (không nhận PP), rồi kẻ địch kề bên chịu 100/150/200% lượng đó thành sát thương phép. |  |
| Slither Wing | Độc nhất |  | **Luồn Đánh** `SKITTER_SMACK` | `behind_target.strike` | Luồn ra sau mục tiêu: 15/30/60 sát thương phép và -20 AP. |  |
| Tapu Lele | Độc nhất |  | **Tâm Linh Trường Tạo** `PSYCHIC_SURGE` | `type_allies.shield` | Các đồng minh hệ PSYCHIC khác nhận 20/25/30 SHIELD. |  |
| Veluza | Độc nhất |  | **Lóc Thịt** `FILLET_AWAY` | `self.sacrifice_hide` | Mất 30% HP tối đa, nhận 5/8/10 ATK và 10/15/20 SPEED, PROTECT 1 giây và trốn vào góc. |  |
| Arceus | Huyền thoại |  | **Đại Phán Quyết** `JUDGEMENT` | `target.synergy_scaling` | Gây 10 sát thương phép lên mục tiêu, nhân với tổng mốc synergy của đội ở các hệ của mình. |  |
| Articuno | Huyền thoại |  | **Bão Tuyết** `BLIZZARD` | `big_nova.status` | Mọi kẻ địch trong vòng 4 ô chịu 10/20/40 sát thương phép (x1.3 nếu đang đóng băng) và bị đóng băng 1.5 giây. |  |
| Deoxys | Huyền thoại |  | **Siêu Linh Khuếch Đại** `PSYCHO_BOOST` | `row3.plain` | Mục tiêu và hai bên cạnh nó trong hàng chịu 90/120/150 sát thương phép; mất 10 AP mỗi lần trúng. |  |
| Giratina | Huyền thoại |  | **Lực Bóng Tối** `SHADOW_FORCE` | `jump_cluster.transform` | Chuyển sang dạng Origin, dịch chuyển vào giữa nhóm kẻ địch đông nhất và gây 30/45/60 sát thương phép lên kẻ kề bên, phá Protect, Reflect và Magic Bounce. Kỹ năng đổi thành Shadow Claw. |  |
| Groudon | Huyền thoại |  | **Lưỡi Vực Thẳm** `PRECIPICE_BLADES` | `cross.plain` | Gây 25/50/100 sát thương phép lên mọi kẻ địch cùng hàng hoặc cùng cột với mình. |  |
| Heatran | Huyền thoại |  | **Hoả Diệm Lốc** `MAGMA_STORM` | `chain.decay` | Bão lửa nhảy từ kẻ địch sang kẻ địch kề bên: 50/75/100 sát thương phép, yếu đi 20% sau mỗi lần nhảy. |  |
| Iron Valiant | Huyền thoại |  | **Kiếm Laser** `LASER_BLADE` | `self.alternate_stance` | Luân phiên xoay ra sau mục tiêu (SHIELD, 25 sát thương phép xung quanh) và chém đôi (25 + ATK sát thương phép). |  |
| Keldeo | Huyền thoại |  | **Bí Kiếm** `SECRET_SWORD` | `target.charged_condition` | Gây 50/100/150 sát thương phép, thành sát thương chuẩn khi đã chặn được 20 đòn. |  |
| Marshadow | Huyền thoại |  | **Linh Thể Cưỡng Đoạt** `SPECTRAL_THIEF` | `target.steal_buffs` | Gây 30/40/50 sát thương phép, lao đi và cướp mọi chỉ số được cộng của mục tiêu. |  |
| Mew | Huyền thoại |  | **Dịch Chuyển** `TELEPORT` | `self.teleport_empower` | Dịch chuyển tới một ô an toàn. Đòn đánh kế tiếp gây thêm 15/30/60 sát thương phép; tới lúc đó không dùng kỹ năng được. |  |
| Moltres | Huyền thoại |  | **Quá Nhiệt Bạo Tạc** `OVERHEAT` | `big_burst.plain` | Mọi kẻ địch trong vòng 4 ô quanh mục tiêu chịu 12/25/50 sát thương phép (x1.3 nếu đang bỏng). |  |
| Munkidori | Huyền thoại |  | **Bẻ Cong Tâm Trí** `MIND_BEND` | `target.possess` | Mục tiêu bị POSSESSED 2 giây; mục tiêu được bảo vệ hoặc đã bị chiếm hữu thì chịu 100 sát thương phép thay vào đó. |  |
| Pheromosa | Huyền thoại |  | **Trùng Mãnh Khốc** `LUNGE` | `jump_highest_atk.strike` | Nhảy vào kẻ địch có ATK cao nhất: -3/4/5 ATK và 30/40/50 sát thương phép. |  |
| Regigigas | Huyền thoại |  | **Nghiền Áp** `CRUSH_GRIP` | `target.scale_target_stat` | Gây 15/25/50 + tối đa 50/100/200 sát thương phép, mục tiêu càng nhiều máu càng đau. |  |
| Regirock | Huyền thoại |  | **Ẩn Thạch Trận** `STEALTH_ROCKS` | `cone.zone` | Rải đá ngầm trên vùng hình nón 1/2/3 ô về phía mục tiêu; kẻ địch ở đó chịu 30/40/50 sát thương phép. |  |
| Roaring Moon | Huyền thoại |  | **Bắn Vảy** `SCALE_SHOT` | `orbit_then_fire` | 8 chiếc vảy tụ quanh bản thân (40 sát thương phép lên kẻ địch kề bên), rồi bay vào kẻ địch xa nhất. |  |
| Xerneas | Huyền thoại |  | **Phong Thủy Linh Tạo** `GEOMANCY` | `self.buff` | Tăng 15/15/15/30 Công, 10/10/10/20 Thủ đặc biệt và 15 Tốc độ |  |
| Zapdos | Huyền thoại |  | **Sấm Sét** `THUNDER` | `random_n.strikes` | Sét đánh 3 kẻ địch ngẫu nhiên, cách nhau 0.5 giây: 25/50/100 sát thương phép, 30% cơ hội PARALYSIS 3 giây. |  |
| Zekrom | Huyền thoại |  | **Dung Lôi Sát Địa** `FUSION_BOLT` | `burst.synergy_scaling` | Gây 30/40/50/100 Sát thương đặc biệt + 10/10/10/20 cho từng cấp bậc hiệu ứng hệ Điện lên mục tiêu và đối thủ gần nó |  |
| Dreepy | Trứng |  | **Long Chi Tiễn** `DRAGON_DARTS` | `closest_n.refund_on_kill` | Ném ra 3 phi tiêu gây 10/20/40/80 Sát thương đặc biệt cho từng mục tiêu. Nếu mục tiêu bị hạ gục, hồi lập tức 40/40/40/80 Mana |  |

## 5. Người dùng đã trả lời (2026-11-20)

1. Skill **mượn**: được (một skill có thể ở hai mùa trên hai Pokémon khác nhau).
2. Item giữa stage của hệ giữ nguyên (bản sao Bug đầu trận của web là hiệu ứng trong trận nên mùa 1 không có).
3. Số liệu là bản đầu; tự cân bằng chỉnh sau khi chơi thử.

