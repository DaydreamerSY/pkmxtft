# Vùng và thời tiết — tài liệu tham chiếu

> File này **sinh tự động** bằng `python tools/port/gen_world_doc.py` từ `data/pac/*.json` — đừng sửa tay, sửa script rồi
> chạy lại (sau `tools\export_pac.bat` nếu vùng / Pokémon vùng thay đổi). Tóm tắt luật cho người chơi: `docs/GAME_DESIGN.md`
> mục 8 và 9.3; chi tiết port: `docs/PORTING.md` mục “Weather” và “Vùng và Pokémon regional”.

## 1. Thời tiết

Code: `src/core/weather.gd` (port `app/utils/weather.ts`), gọi từ `FightSetup.weather_for()`.

- Tính **trước mỗi trận** từ hai sàn: đội người chơi (không tính bench) **và wave địch**. Lúc chuẩn bị, thanh stage hiện
  dự báo theo sàn hiện tại; đổi đội hình là dự báo đổi.
- Mỗi Pokémon **+1 điểm** cho thời tiết của từng hệ nó có (bảng dưới). Hệ do item cho (đá hệ...) cũng tính với đội người chơi.
- Một số passive cộng **+100** (bảng “Passive thời tiết”).
- Thời tiết nhiều điểm nhất thắng nếu đạt **≥ 8 điểm** (`config.weatherThreshold`) và **không hoà** với thời tiết khác;
  không thì trời quang. Hệ Normal bỏ phiếu cho trời quang (kéo về không thời tiết).
- Thời tiết áp dụng cho **cả hai đội**. Pokémon đổi dạng theo thời tiết (Lycanroc, Ursaluna) đổi trước khi trận bắt đầu.

| Thời tiết | Id | Hệ bỏ phiếu | Hiệu ứng |
|---|---|---|---|
| Nắng gắt | `ZENITH` | Cỏ | +20% hồi máu từ mọi nguồn; -30% thời gian SLEEP |
| Hạn hán | `DROUGHT` | Lửa | +30% sát thương BURN; -30% thời gian FREEZE; -3 PP mỗi giây |
| Mưa | `RAIN` | Nước | +3 PP mỗi giây; -30% sát thương BURN và POISONED |
| Bão cát | `SANDSTORM` | Đất | 5 SPECIAL mỗi giây (GROUND miễn nhiễm); +30% thời gian CONFUSION |
| Sương mù | `MISTY` | Tiên | +20% SPECIAL; +30% thời gian CHARM |
| Tuyết | `SNOW` | Băng | -10 SPEED nếu không phải ICE; +30% thời gian FREEZE |
| Bão sét | `STORM` | Điện | Sét đánh ngẫu nhiên xuống sàn, gây 100 SPECIAL (Pokémon ELECTRIC được sạc thay vì trúng đòn); +30% thời gian PARALYSIS |
| Đêm tối | `NIGHT` | Bóng tối | +10% CRIT_CHANCE; +30% thời gian SLEEP |
| Gió lớn | `WINDY` | Bay | +10 SPEED (+20 nếu là FLYING) |
| Trăng máu | `BLOODMOON` | Hoang dã | +20% PHYSICAL; +30% thời gian WOUND |
| Khói độc | `SMOG` | Độc | -15% độ chính xác; +30% thời gian POISONED |
| U ám | `MURKY` | Ma | -30 LUCK (GHOST miễn nhiễm); +30% thời gian SILENCE |
| Trời quang | `NEUTRAL` | Thường | Thời tiết bình thường. Không có hiệu ứng. |

Từ khoá VIẾT HOA trong cột hiệu ứng là từ khoá của game (chỉ số, trạng thái), hiển thị thành icon / tên trong tooltip.

**Passive thời tiết**

| Passive | Tác dụng lên phiếu |
|---|---|
| RAIN / DROUGHT / ZENITH / SANDSTORM / MISTY / SNOW / STORM / NIGHT / WINDY | +100 cho thời tiết cùng tên |
| AIRLOCK (Rayquaza) | +100 cho trời quang: xoá thời tiết |
| CASTFORM | +100 cho thời tiết trội nhất của sàn mình trong Drought / Zenith / Rain / Snow (hoà thì không) |
| TORNADUS / THUNDURUS / LANDORUS / ENAMORUS | +100 cho Windy hoặc Snow / Storm / Sandstorm / Misty, cái nào trội hơn trên sàn mình |
| RAIN_OR_STORM, DROUGHT_OR_SANDSTORM (Kyogre, Groudon nguyên thuỷ) | +100 cho cái trội hơn trên sàn mình (mặc định Rain / Drought) |
| DROUGHT_OR_ZENITH | +100 cho Zenith nếu sàn có số Light ≥ số Fire, không thì Drought |
| SAND_STREAM, DRIZZLE, WIND_POWER | +2 thêm cho Sandstorm / Rain / Storm khi chính nó có hệ tương ứng |

**Chi tiết trong trận** (`BattleSim`, `Weather`): Windy +10 SPEED (Flying +20); Snow −10 SPEED trừ Ice; Smog +15% né đòn;
Night +10% chí mạng; Murky −30 LUCK trừ Ghost; Rain 13 PP/giây, Drought 7 PP/giây (bình thường 10); Misty ×1.2 sát thương phép;
Bloodmoon ×1.2 sát thương vật lý; Sandstorm 5 sát thương phép mỗi giây trừ Ground; Storm sét đánh ngẫu nhiên 100 sát thương phép
mỗi 4–8 giây (Electric được sạc); thời lượng trạng thái ×1.3 / ×0.7 theo bảng.

**Muốn chỉnh**: ngưỡng điểm nằm ở bản web (`config.weatherThreshold`, export lại); hệ → thời tiết và hệ số ở đầu
`src/core/weather.gd`; sát thương Sandstorm / Storm là hằng số đầu `src/core/battle_sim.gd`.

## 2. Vùng

Code: `src/core/town.gd` (`portals`), `PlayerState.change_map()` / `update_regional_pool()`, `GameData.in_region()`.
Dữ liệu: `config.maps` (hệ + nhạc), `config.regional` (Pokémon → các vùng), `config.regionalVariants`.

- Có **143 vùng**, mỗi vùng **3 hệ** và một bản nhạc. Người chơi bắt đầu ở Thị trấn (`town`, không có hệ).
- **Đổi vùng** ở portal stage 0 / 10 / 20 (và Lapras Passport): mỗi portal có các biểu tượng hệ (stage 0: ngẫu nhiên; sau đó:
  4 hệ mạnh nhất của đội) và dẫn tới vùng có nhiều hệ chung nhất với biểu tượng của nó, không lặp vùng.
- Vào vùng mới: nhạc đổi, **cây quả mọng (Grass) trồng lại**, pool vùng cũ bị xoá và pool vùng mới được nạp.
- **Pokémon vùng** chỉ vào shop khi vùng có ít nhất một hệ của nó (với biến thể: một hệ mà dạng gốc không có).
  **Biến thể vùng** thay cho dạng gốc trong shop và trong đề xuất starter / Unique / Legendary.
- Unique / Legendary vùng chỉ được đề xuất ở portal khi đang ở vùng của chúng.
- Bán Pokémon vùng ở vùng khác: không trở về pool.

### 2.1 Danh sách vùng

Cột “Pokémon vùng” liệt kê dạng đầu của mỗi họ đã port, rẻ trước; *nghiêng* = biến thể thay cho dạng gốc; **đậm** = Unique / Legendary.

| Vùng | Id | Hệ | Số họ | Pokémon vùng |
|---|---|---|---|---|
| Amp Plains | `AmpPlains` | Điện, Thảo nguyên, Âm thanh | 15 | *Alolan Geodude*, Pidgey, Cetoddle, Gossifleur, Tynamo, Lotad, Obstagoon, Spoink, Toxel, Jangmo-o, Numel, Slakoth, **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Apple Woods | `AppleWoods` | Côn trùng, Ẩm thực, Sơ sinh | 8 | Blipbug, Starly, Cleffa, Sizzlipede, Cutiefly, Toxel, Cherubi, Larvesta |
| Barren Valley | `BarrenValley` | Đá, Giác đấu, Ma | 15 | Chimchar, Pidove, Hisuian Lilligant, Hisuian Typhlosion, *Hisuian Growlithe*, *Hisuian Zorua*, Buneary, Hisuian Avalugg, Corsola, *Hisuian Sneasel*, Jangmo-o, Shellos (East Sea), **Galarian Farfetch'd**, **Oricorio (Sensu Style)**, **Ogerpon Cornerstone** |
| Beach Cave | `BeachCave` | Thủy sinh, Đất, Hóa thạch | 10 | Mudkip, Pidgey, *Hisuian Voltorb*, Tynamo, Burmy (Sandy), Lotad, Corsola, Numel, Shellos (West Sea), **Ogerpon Wellspring** |
| Brine Cave | `BrineCave` | Độc, Hóa thạch, Bóng tối | 16 | *Alolan Rattata*, Seedot, Starly, *Alolan Grimer*, *Galarian Slowpoke*, *Hisuian Voltorb*, *Nidoran ♀*, Varoom, *Alolan Meowth*, *Galarian Zigzagoon*, *Paldean Wooper*, Toxel, Hisuian Samurott, *Hisuian Sneasel*, **Galarian Farfetch'd**, **Hisuian Qwilfish** |
| Brine Cave 2 | `UnusedBrineCave` | Ẩm thực, Đất, Rồng | 9 | Mudkip, Starly, Bagon, Burmy (Sandy), Alolan Exeggutor, Cherubi, Jangmo-o, Numel, Shellos (West Sea) |
| Buried Relic 1 | `BuriedRelic1` | Ánh sáng, Nhân tạo, Nhân hình | 10 | Chimchar, Pidove, Cleffa, Impidimp, Varoom, Burmy (Trash), Cherubi, Drowzee, *Galarian Ponyta*, **Rotom** |
| Buried Relic 2 | `BuriedRelic2` | Đất, Nhân tạo, Ánh sáng | 10 | Mudkip, Pidgey, Cleffa, Varoom, Burmy (Sandy), Cherubi, *Galarian Ponyta*, Numel, Shellos (West Sea), **Rotom** |
| Buried Relic 3 | `BuriedRelic3` | Đất, Nhân tạo, Nhân hình | 10 | Chimchar, Mudkip, Starly, Impidimp, Varoom, Burmy (Sandy), Drowzee, Numel, Shellos (West Sea), **Rotom** |
| Concealed Ruins | `ConcealedRuins` | Độc, Hoang dã, Ma | 13 | Pidove, *Galarian Slowpoke*, Hisuian Typhlosion, *Hisuian Zorua*, *Nidoran ♀*, Rufflet, Varoom, *Galarian Meowth*, *Paldean Wooper*, Toxel, Doduo, *Hisuian Sneasel*, **Oricorio (Sensu Style)** |
| Craggy Coast | `CraggyCoast` | Nước, Giác đấu, Quái vật | 13 | Chimchar, Mudkip, Pidgey, Bagon, Hisuian Lilligant, Buneary, *Galarian Yamask*, Drowzee, *Hisuian Sneasel*, Jangmo-o, Shellos (West Sea), Snover, **Galarian Farfetch'd** |
| Crystal Cave 1 | `CrystalCave1` | Siêu linh, Âm thanh, Tiên | 18 | Alolan Raichu, Blipbug, Starly, Cetoddle, *Galarian Weezing*, Gossifleur, *Alolan Vulpix*, Cutiefly, Lotad, Obstagoon, Spoink, Toxtricity, Drowzee, *Galarian Ponyta*, Jangmo-o, **Oricorio (Pa’u Style)**, **Tapu Fini**, **Tapu Lele** |
| Crystal Cave 2 | `CrystalCave2` | Siêu linh, Âm thanh, Ánh sáng | 16 | Alolan Raichu, Blipbug, Pidove, Cetoddle, Cleffa, Gossifleur, Lotad, Obstagoon, Spoink, Toxtricity, Cherubi, Drowzee, *Galarian Ponyta*, Jangmo-o, **Oricorio (Pa’u Style)**, **Tapu Lele** |
| Crystal Crossing | `CrystalCrossing` | Siêu linh, Thủy sinh, Độc | 19 | Alolan Raichu, Blipbug, Pidgey, *Galarian Slowpoke*, *Nidoran ♀*, Tynamo, Varoom, Lotad, *Paldean Wooper*, Spoink, Toxel, Corsola, Drowzee, *Galarian Ponyta*, *Hisuian Sneasel*, Shellos (East Sea), **Oricorio (Pa’u Style)**, **Tapu Lele**, **Ogerpon Wellspring** |
| Dark Crater | `DarkCrater` | Bóng tối, Lửa, Đất | 19 | *Alolan Rattata*, Chimchar, Mudkip, Seedot, Starly, *Alolan Grimer*, Sizzlipede, *Alolan Meowth*, Burmy (Sandy), *Galarian Zigzagoon*, Alolan Marowak, Hisuian Samurott, Larvesta, Numel, Shellos (West Sea), **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Dark Hill 1 | `DarkHill1` | Ma, Bóng tối, Bay | 17 | *Alolan Rattata*, Orbeetle, Pidove, Seedot, *Alolan Grimer*, Hisuian Typhlosion, *Hisuian Zorua*, Rufflet, Salamence, *Alolan Meowth*, *Galarian Zigzagoon*, Rookidee, Doduo, Hisuian Samurott, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Oricorio (Sensu Style)** |
| Dark Hill 2 | `DarkHill2` | Ma, Bóng tối, Vô định hình | 13 | *Alolan Rattata*, Pidgey, Seedot, *Alolan Grimer*, Hisuian Typhlosion, *Hisuian Zorua*, Tynamo, *Alolan Meowth*, *Galarian Zigzagoon*, Hisuian Samurott, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Oricorio (Sensu Style)** |
| Dark Ice Mountain | `DarkIceMountain` | Bóng tối, Băng, Thường | 16 | *Alolan Rattata*, Seedot, Starly, *Alolan Grimer*, *Alolan Sandshrew*, Cetoddle, *Alolan Vulpix*, Buneary, *Galarian Zigzagoon*, Doduo, *Galarian Darumaka*, Hisuian Samurott, Slakoth, Snover, **Galarian Farfetch'd**, **Hisuian Qwilfish** |
| Dark Ice Mountain Peak | `DarkIceMountainPeak` | Bóng tối, Băng, Bay | 19 | *Alolan Rattata*, Orbeetle, Pidove, Seedot, *Alolan Grimer*, *Alolan Sandshrew*, Cetoddle, Rufflet, Salamence, *Alolan Meowth*, *Alolan Vulpix*, *Galarian Zigzagoon*, Rookidee, Doduo, *Galarian Darumaka*, Hisuian Samurott, Snover, **Galarian Farfetch'd**, **Hisuian Qwilfish** |
| Dark Wasteland | `DarkWasteland` | Bóng tối, Độc, Quái vật | 19 | *Alolan Rattata*, Seedot, Starly, *Alolan Grimer*, Bagon, *Galarian Slowpoke*, *Nidoran ♀*, Varoom, *Alolan Meowth*, *Galarian Yamask*, *Galarian Zigzagoon*, *Paldean Wooper*, Toxel, Drowzee, Hisuian Samurott, *Hisuian Sneasel*, Snover, **Galarian Farfetch'd**, **Hisuian Qwilfish** |
| Darknight Relic | `DarknightRelic` | Hóa thạch, Thủy sinh, Nhân hình | 10 | Chimchar, Pidgey, *Hisuian Voltorb*, Impidimp, Tynamo, Lotad, Corsola, Drowzee, Shellos (East Sea), **Ogerpon Wellspring** |
| Deep Boulder Quarry | `DeepBoulderQuarry` | Đá, Thép, Hóa thạch | 13 | Hisuian Sliggoo, Pidove, *Alolan Diglett*, *Alolan Sandshrew*, *Hisuian Growlithe*, *Hisuian Voltorb*, Varoom, *Galarian Meowth*, Hisuian Avalugg, Rookidee, Corsola, Shellos (East Sea), **Ogerpon Cornerstone** |
| Deep Dark Crater | `DeepDarkCrater` | Bóng tối, Lửa, Quái vật | 20 | *Alolan Rattata*, Chimchar, Pidgey, Seedot, *Alolan Grimer*, Bagon, Sizzlipede, *Alolan Meowth*, *Galarian Yamask*, *Galarian Zigzagoon*, Alolan Marowak, Drowzee, Hisuian Samurott, Larvesta, Numel, Snover, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Deep Dusk Forest 1 | `DeepDuskForest1` | Bóng tối, Cỏ, Ẩm thực | 15 | *Alolan Rattata*, Seedot, Starly, *Alolan Grimer*, *Hisuian Voltorb*, *Alolan Meowth*, Burmy (Plant), *Galarian Zigzagoon*, Lotad, Cherubi, Hisuian Samurott, Snover, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Tapu Bulu** |
| Deep Dusk Forest 2 | `DeepDuskForest2` | Ma, Cỏ, Ánh sáng | 12 | Pidove, Cleffa, Hisuian Typhlosion, *Hisuian Voltorb*, *Hisuian Zorua*, Burmy (Plant), Lotad, Cherubi, *Galarian Ponyta*, Snover, **Oricorio (Sensu Style)**, **Tapu Bulu** |
| Deep Limestone Cavern | `DeepLimestoneCavern` | Nước, Côn trùng, Đá | 11 | Blipbug, Mudkip, Pidgey, *Hisuian Growlithe*, Sizzlipede, Cutiefly, Hisuian Avalugg, Corsola, Larvesta, Shellos (West Sea), **Ogerpon Cornerstone** |
| Deep Sealed Ruin | `DeepSealedRuin` | Vô định hình, Ma, Hóa thạch | 6 | Starly, Hisuian Typhlosion, *Hisuian Voltorb*, *Hisuian Zorua*, Tynamo, **Oricorio (Sensu Style)** |
| Desert Region | `DesertRegion` | Lửa, Thảo nguyên, Ánh sáng | 14 | Chimchar, Pidove, Cetoddle, Cleffa, Sizzlipede, Spoink, Alolan Marowak, Cherubi, *Galarian Ponyta*, Larvesta, Numel, Slakoth, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Drenched Bluff | `DrenchedBluff` | Thủy sinh, Hóa thạch, Quái vật | 11 | Pidgey, Bagon, *Hisuian Voltorb*, Tynamo, *Galarian Yamask*, Lotad, Corsola, Drowzee, Shellos (East Sea), Snover, **Ogerpon Wellspring** |
| Dusk Forest 1 | `DuskForest1` | Quái vật, Cỏ, Bóng tối | 17 | *Alolan Rattata*, Seedot, Starly, *Alolan Grimer*, Bagon, *Hisuian Voltorb*, *Alolan Meowth*, Burmy (Plant), *Galarian Yamask*, *Galarian Zigzagoon*, Lotad, Drowzee, Hisuian Samurott, Snover, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Tapu Bulu** |
| Dusk Forest 2 | `DuskForest2` | Ma, Cỏ, Hoa | 13 | Pidove, Gossifleur, Hisuian Typhlosion, *Hisuian Voltorb*, *Hisuian Zorua*, Burmy (Plant), Cutiefly, Lotad, Cherubi, Snover, **Oricorio (Sensu Style)**, **Tapu Bulu**, **Ogerpon Teal** |
| Electric Maze | `ElectricMaze` | Điện, Ánh sáng, Ẩm thực | 10 | *Alolan Geodude*, Pidgey, Cleffa, Tynamo, Toxel, Cherubi, *Galarian Ponyta*, **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Far Amp Plains | `FarAmpPlains` | Điện, Thảo nguyên, Hóa thạch | 12 | *Alolan Geodude*, Starly, Cetoddle, *Hisuian Voltorb*, Tynamo, Spoink, Toxel, Numel, Slakoth, **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Final Maze 2 | `FinalMaze2` | Thường, Hoa, Côn trùng | 11 | Blipbug, Pidove, Gossifleur, Sizzlipede, Buneary, Cutiefly, Cherubi, Doduo, Larvesta, Slakoth, **Ogerpon Teal** |
| Foggy Forest | `FoggyForest` | Tiên, Hoang dã, Hoa | 12 | Pidgey, *Galarian Weezing*, Gossifleur, Rufflet, *Alolan Vulpix*, Cutiefly, *Galarian Meowth*, Cherubi, Doduo, *Galarian Ponyta*, **Tapu Fini**, **Ogerpon Teal** |
| Forest Path | `ForestPath` | Cỏ, Côn trùng, Sơ sinh | 12 | Blipbug, Starly, Cleffa, *Hisuian Voltorb*, Sizzlipede, Burmy (Plant), Cutiefly, Lotad, Toxel, Larvesta, Snover, **Tapu Bulu** |
| Frosty Forest | `FrostyForest` | Ánh sáng, Băng, Giác đấu | 15 | Chimchar, Pidove, *Alolan Sandshrew*, Cetoddle, Cleffa, Hisuian Lilligant, *Alolan Vulpix*, Buneary, Cherubi, *Galarian Darumaka*, *Galarian Ponyta*, *Hisuian Sneasel*, Jangmo-o, Snover, **Galarian Farfetch'd** |
| Future Temporal Spire | `FutureTemporalSpire` | Nhân hình, Nhân tạo, Siêu linh | 13 | Alolan Raichu, Blipbug, Chimchar, Pidgey, Impidimp, Varoom, Burmy (Trash), Spoink, Drowzee, *Galarian Ponyta*, **Oricorio (Pa’u Style)**, **Rotom**, **Tapu Lele** |
| Future Temporal Tower | `FutureTemporalTower` | Quái vật, Nhân tạo, Siêu linh | 14 | Alolan Raichu, Blipbug, Starly, Bagon, Varoom, Burmy (Trash), *Galarian Yamask*, Spoink, Drowzee, *Galarian Ponyta*, Snover, **Oricorio (Pa’u Style)**, **Rotom**, **Tapu Lele** |
| Golden Chamber | `GoldenChamber` | Rồng, Thép, Vô định hình | 11 | Hisuian Sliggoo, Pidove, *Alolan Diglett*, *Alolan Sandshrew*, Bagon, Tynamo, Varoom, *Galarian Meowth*, Rookidee, Alolan Exeggutor, Jangmo-o |
| Grass Maze | `GrassMaze` | Cỏ, Thảo nguyên, Thường | 12 | Pidgey, Cetoddle, *Hisuian Voltorb*, Buneary, Burmy (Plant), Lotad, Spoink, Doduo, Numel, Slakoth, Snover, **Tapu Bulu** |
| Great Canyon | `GreatCanyon` | Thường, Hoang dã, Lửa | 13 | Chimchar, Starly, Rufflet, Sizzlipede, Buneary, *Galarian Meowth*, Alolan Marowak, Doduo, Larvesta, Numel, Slakoth, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Hidden Highland | `HiddenHighland` | Hoa, Cỏ, Rồng | 13 | Pidove, Bagon, Gossifleur, *Hisuian Voltorb*, Burmy (Plant), Cutiefly, Lotad, Alolan Exeggutor, Cherubi, Jangmo-o, Snover, **Tapu Bulu**, **Ogerpon Teal** |
| Hidden Land | `HiddenLand` | Hoa, Côn trùng, Nước | 10 | Blipbug, Mudkip, Pidgey, Gossifleur, Sizzlipede, Cutiefly, Cherubi, Larvesta, Shellos (West Sea), **Ogerpon Teal** |
| Howling Forest 1 | `HowlingForest1` | Âm thanh, Thảo nguyên, Côn trùng | 14 | Blipbug, Starly, Cetoddle, Gossifleur, Sizzlipede, Cutiefly, Lotad, Obstagoon, Spoink, Toxtricity, Jangmo-o, Larvesta, Numel, Slakoth |
| Howling Forest 2 | `HowlingForest2` | Âm thanh, Độc, Ẩm thực | 13 | Pidove, Cetoddle, *Galarian Slowpoke*, Gossifleur, *Nidoran ♀*, Varoom, Lotad, Obstagoon, *Paldean Wooper*, Toxel, Cherubi, *Hisuian Sneasel*, Jangmo-o |
| Ice Aegis Cave | `IceAegisCave` | Băng, Giác đấu, Đất | 16 | Chimchar, Mudkip, Pidgey, *Alolan Sandshrew*, Cetoddle, Hisuian Lilligant, *Alolan Vulpix*, Buneary, Burmy (Sandy), *Galarian Darumaka*, *Hisuian Sneasel*, Jangmo-o, Numel, Shellos (West Sea), Snover, **Galarian Farfetch'd** |
| Ice Maze | `IceMaze` | Băng, Thép, Giác đấu | 17 | Chimchar, Hisuian Sliggoo, Starly, *Alolan Diglett*, *Alolan Sandshrew*, Cetoddle, Hisuian Lilligant, Varoom, *Alolan Vulpix*, Buneary, *Galarian Meowth*, Rookidee, *Galarian Darumaka*, *Hisuian Sneasel*, Jangmo-o, Snover, **Galarian Farfetch'd** |
| Icicle Forest | `IcicleForest` | Băng, Thảo nguyên, Giác đấu | 15 | Chimchar, Pidove, *Alolan Sandshrew*, Cetoddle, Hisuian Lilligant, *Alolan Vulpix*, Buneary, Spoink, *Galarian Darumaka*, *Hisuian Sneasel*, Jangmo-o, Numel, Slakoth, Snover, **Galarian Farfetch'd** |
| Joyous Tower | `JoyousTower` | Ánh sáng, Tiên, Sơ sinh | 9 | Pidgey, Cleffa, *Galarian Weezing*, *Alolan Vulpix*, Cutiefly, Toxel, Cherubi, *Galarian Ponyta*, **Tapu Fini** |
| Lapis Cave | `LapisCave` | Nước, Thủy sinh, Hóa thạch | 8 | Mudkip, Starly, *Hisuian Voltorb*, Tynamo, Lotad, Corsola, Shellos (West Sea), **Ogerpon Wellspring** |
| Lightning Field | `LightningField` | Điện, Thảo nguyên, Ánh sáng | 14 | *Alolan Geodude*, Pidove, Cetoddle, Cleffa, Tynamo, Spoink, Toxel, Cherubi, *Galarian Ponyta*, Numel, Slakoth, **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Limestone Cavern | `LimestoneCavern` | Đá, Côn trùng, Thủy sinh | 12 | Blipbug, Pidgey, *Hisuian Growlithe*, Sizzlipede, Tynamo, Cutiefly, Hisuian Avalugg, Lotad, Corsola, Larvesta, Shellos (East Sea), **Ogerpon Cornerstone** |
| Lost Quicksand | `QuicksandUnused` | Đất, Thường, Độc | 14 | Mudkip, Starly, *Galarian Slowpoke*, *Nidoran ♀*, Varoom, Buneary, Burmy (Sandy), *Paldean Wooper*, Toxel, Doduo, *Hisuian Sneasel*, Numel, Shellos (West Sea), Slakoth |
| Lower Brine Cave | `LowerBrineCave` | Thủy sinh, Hóa thạch, Rồng | 10 | Starly, Bagon, *Hisuian Voltorb*, Tynamo, Lotad, Alolan Exeggutor, Corsola, Jangmo-o, Shellos (East Sea), **Ogerpon Wellspring** |
| Lush Prairie | `LushPrairie` | Ẩm thực, Ánh sáng, Hoa | 7 | Pidove, Cleffa, Gossifleur, Cutiefly, Cherubi, *Galarian Ponyta*, **Ogerpon Teal** |
| Magma Cavern 2 | `MagmaCavern2` | Lửa, Đất, Giác đấu | 16 | Chimchar, Mudkip, Pidgey, Hisuian Lilligant, Sizzlipede, Buneary, Burmy (Sandy), Alolan Marowak, *Hisuian Sneasel*, Jangmo-o, Larvesta, Numel, Shellos (West Sea), **Galarian Farfetch'd**, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Magma Cavern 3 | `MagmaCavern3` | Lửa, Rồng, Quái vật | 14 | Chimchar, Starly, Bagon, Sizzlipede, *Galarian Yamask*, Alolan Exeggutor, Alolan Marowak, Drowzee, Jangmo-o, Larvesta, Numel, Snover, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Meteor Cave | `MeteorCave` | Siêu linh, Tiên, Nhân hình | 14 | Alolan Raichu, Blipbug, Chimchar, Pidove, *Galarian Weezing*, Impidimp, *Alolan Vulpix*, Cutiefly, Spoink, Drowzee, *Galarian Ponyta*, **Oricorio (Pa’u Style)**, **Tapu Fini**, **Tapu Lele** |
| Miracle Sea | `MiracleSea` | Nước, Thủy sinh, Tiên | 12 | Mudkip, Pidgey, *Galarian Weezing*, Tynamo, *Alolan Vulpix*, Cutiefly, Lotad, Corsola, *Galarian Ponyta*, Shellos (West Sea), **Tapu Fini**, **Ogerpon Wellspring** |
| Moonlit Courtyard | `MoonlitCourtyard` | Tiên, Hoa, Bóng tối | 17 | *Alolan Rattata*, Seedot, Starly, *Alolan Grimer*, *Galarian Weezing*, Gossifleur, *Alolan Meowth*, *Alolan Vulpix*, Cutiefly, *Galarian Zigzagoon*, Cherubi, *Galarian Ponyta*, Hisuian Samurott, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Tapu Fini**, **Ogerpon Teal** |
| Mt Blaze | `MtBlaze` | Lửa, Bay, Hoang dã | 14 | Chimchar, Orbeetle, Pidove, Rufflet, Salamence, Sizzlipede, *Galarian Meowth*, Rookidee, Alolan Marowak, Doduo, Larvesta, Numel, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Mt Bristle | `MtBristle` | Điện, Bay, Quái vật | 15 | *Alolan Geodude*, Orbeetle, Pidgey, Bagon, Rufflet, Tynamo, *Galarian Yamask*, Rookidee, Toxel, Doduo, Drowzee, Snover, **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Mt Faraway 2 | `MtFaraway2` | Băng, Vô định hình, Rồng | 10 | Starly, *Alolan Sandshrew*, Bagon, Cetoddle, Tynamo, *Alolan Vulpix*, Alolan Exeggutor, *Galarian Darumaka*, Jangmo-o, Snover |
| Mt Faraway 4 | `MtFaraway4` | Băng, Bay, Âm thanh | 16 | Orbeetle, Pidove, *Alolan Sandshrew*, Cetoddle, Gossifleur, Rufflet, Salamence, *Alolan Vulpix*, Lotad, Obstagoon, Rookidee, Toxtricity, Doduo, *Galarian Darumaka*, Jangmo-o, Snover |
| Mt Freeze | `MtFreeze` | Băng, Bay, Thường | 13 | Orbeetle, Pidgey, *Alolan Sandshrew*, Cetoddle, Rufflet, Salamence, *Alolan Vulpix*, Buneary, Rookidee, Doduo, *Galarian Darumaka*, Slakoth, Snover |
| Mt Horn | `MtHorn` | Đá, Bay, Âm thanh | 17 | Orbeetle, Starly, Cetoddle, Gossifleur, *Hisuian Growlithe*, Rufflet, Salamence, Hisuian Avalugg, Lotad, Obstagoon, Rookidee, Toxtricity, Corsola, Doduo, Jangmo-o, Shellos (East Sea), **Ogerpon Cornerstone** |
| Mt Steel 1 | `MtSteel1` | Thép, Bay, Hóa thạch | 12 | Hisuian Sliggoo, Orbeetle, Pidove, *Alolan Diglett*, *Alolan Sandshrew*, *Hisuian Voltorb*, Rufflet, Salamence, Varoom, *Galarian Meowth*, Rookidee, Doduo |
| Mt Steel 2 | `MtSteel2` | Thép, Bay, Vô định hình | 12 | Hisuian Sliggoo, Orbeetle, Pidgey, *Alolan Diglett*, *Alolan Sandshrew*, Rufflet, Salamence, Tynamo, Varoom, *Galarian Meowth*, Rookidee, Doduo |
| Mt Thunder | `MtThunder` | Điện, Đá, Thép | 18 | *Alolan Geodude*, Hisuian Sliggoo, Starly, *Alolan Diglett*, *Alolan Sandshrew*, *Hisuian Growlithe*, Tynamo, Varoom, *Galarian Meowth*, Hisuian Avalugg, Rookidee, Toxel, Corsola, Shellos (East Sea), **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko**, **Ogerpon Cornerstone** |
| Mt Thunder Peak | `MtThunderPeak` | Điện, Bay, Hoang dã | 13 | *Alolan Geodude*, Orbeetle, Pidove, Rufflet, Salamence, Tynamo, *Galarian Meowth*, Rookidee, Toxel, Doduo, **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Mt Travail | `MtTravail` | Giác đấu, Nhân hình, Hóa thạch | 10 | Chimchar, Pidgey, Hisuian Lilligant, *Hisuian Voltorb*, Impidimp, Buneary, Drowzee, *Hisuian Sneasel*, Jangmo-o, **Galarian Farfetch'd** |
| Murky Cave | `MurkyCave` | Ma, Đất, Nhân hình | 11 | Chimchar, Mudkip, Starly, Hisuian Typhlosion, *Hisuian Zorua*, Impidimp, Burmy (Sandy), Drowzee, Numel, Shellos (West Sea), **Oricorio (Sensu Style)** |
| Murky Forest | `MurkyForest` | Ma, Cỏ, Bóng tối | 17 | *Alolan Rattata*, Pidove, Seedot, *Alolan Grimer*, Hisuian Typhlosion, *Hisuian Voltorb*, *Hisuian Zorua*, *Alolan Meowth*, Burmy (Plant), *Galarian Zigzagoon*, Lotad, Hisuian Samurott, Snover, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Oricorio (Sensu Style)**, **Tapu Bulu** |
| Mystery Jungle 1 | `MysteryJungle1` | Hoang dã, Hoa, Độc | 14 | Pidgey, *Galarian Slowpoke*, Gossifleur, *Nidoran ♀*, Rufflet, Varoom, Cutiefly, *Galarian Meowth*, *Paldean Wooper*, Toxel, Cherubi, Doduo, *Hisuian Sneasel*, **Ogerpon Teal** |
| Mystery Jungle 2 | `MysteryJungle2` | Hoang dã, Tiên, Độc | 15 | Starly, *Galarian Slowpoke*, *Galarian Weezing*, *Nidoran ♀*, Rufflet, Varoom, *Alolan Vulpix*, Cutiefly, *Galarian Meowth*, *Paldean Wooper*, Toxel, Doduo, *Galarian Ponyta*, *Hisuian Sneasel*, **Tapu Fini** |
| Mystifying Forest | `MystifyingForest` | Rồng, Tiên, Hoa | 12 | Pidove, Bagon, *Galarian Weezing*, Gossifleur, *Alolan Vulpix*, Cutiefly, Alolan Exeggutor, Cherubi, *Galarian Ponyta*, Jangmo-o, **Tapu Fini**, **Ogerpon Teal** |
| Northern Desert 1 | `NorthernDesert1` | Rồng, Lửa, Ánh sáng | 14 | Chimchar, Pidgey, Bagon, Cleffa, Sizzlipede, Alolan Exeggutor, Alolan Marowak, Cherubi, *Galarian Ponyta*, Jangmo-o, Larvesta, Numel, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Northern Desert 2 | `NorthernDesert2` | Rồng, Lửa, Hoang dã | 14 | Chimchar, Starly, Bagon, Rufflet, Sizzlipede, *Galarian Meowth*, Alolan Exeggutor, Alolan Marowak, Doduo, Jangmo-o, Larvesta, Numel, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Northern Range 1 | `NorthernRange1` | Độc, Hoang dã, Thép | 14 | Hisuian Sliggoo, Pidove, *Alolan Diglett*, *Alolan Sandshrew*, *Galarian Slowpoke*, *Nidoran ♀*, Rufflet, Varoom, *Galarian Meowth*, *Paldean Wooper*, Rookidee, Toxel, Doduo, *Hisuian Sneasel* |
| Northern Range 2 | `NorthernRange2` | Quái vật, Giác đấu, Thép | 17 | Chimchar, Hisuian Sliggoo, Pidgey, *Alolan Diglett*, *Alolan Sandshrew*, Bagon, Hisuian Lilligant, Varoom, Buneary, *Galarian Yamask*, *Galarian Meowth*, Rookidee, Drowzee, *Hisuian Sneasel*, Jangmo-o, Snover, **Galarian Farfetch'd** |
| Northwind Field | `NorthwindField` | Nước, Thảo nguyên, Âm thanh | 12 | Mudkip, Starly, Cetoddle, Gossifleur, Lotad, Obstagoon, Spoink, Toxtricity, Jangmo-o, Numel, Shellos (West Sea), Slakoth |
| Pitfall Valley 1 | `PitfallValley1` | Thảo nguyên, Nhân hình, Sơ sinh | 10 | Chimchar, Pidove, Cetoddle, Cleffa, Impidimp, Spoink, Toxel, Drowzee, Numel, Slakoth |
| Poison Maze | `PoisonMaze` | Độc, Siêu linh, Côn trùng | 17 | Alolan Raichu, Blipbug, Pidgey, *Galarian Slowpoke*, *Nidoran ♀*, Sizzlipede, Varoom, Cutiefly, *Paldean Wooper*, Spoink, Toxel, Drowzee, *Galarian Ponyta*, *Hisuian Sneasel*, Larvesta, **Oricorio (Pa’u Style)**, **Tapu Lele** |
| Purity Forest 2 | `PurityForest2` | Sơ sinh, Ẩm thực, Vô định hình | 5 | Starly, Cleffa, Tynamo, Toxel, Cherubi |
| Purity Forest 4 | `PurityForest4` | Thường, Sơ sinh, Tiên | 11 | Pidove, Cleffa, *Galarian Weezing*, *Alolan Vulpix*, Buneary, Cutiefly, Toxel, Doduo, *Galarian Ponyta*, Slakoth, **Tapu Fini** |
| Purity Forest 6 | `PurityForest6` | Thường, Cỏ, Sơ sinh | 11 | Pidgey, Cleffa, *Hisuian Voltorb*, Buneary, Burmy (Plant), Lotad, Toxel, Doduo, Slakoth, Snover, **Tapu Bulu** |
| Purity Forest 7 | `PurityForest7` | Cỏ, Sơ sinh, Âm thanh | 12 | Starly, Cetoddle, Cleffa, Gossifleur, *Hisuian Voltorb*, Burmy (Plant), Lotad, Obstagoon, Toxel, Jangmo-o, Snover, **Tapu Bulu** |
| Quicksand Cave | `QuicksandCave` | Đất, Hóa thạch, Thường | 9 | Mudkip, Pidove, *Hisuian Voltorb*, Buneary, Burmy (Sandy), Doduo, Numel, Shellos (West Sea), Slakoth |
| Quicksand Pit | `QuicksandPit` | Đất, Hóa thạch, Quái vật | 10 | Mudkip, Pidgey, Bagon, *Hisuian Voltorb*, Burmy (Sandy), *Galarian Yamask*, Drowzee, Numel, Shellos (West Sea), Snover |
| Rescue Team Maze | `RescueTeamMaze` | Giác đấu, Nhân hình, Nhân tạo | 12 | Chimchar, Pidove, Hisuian Lilligant, Impidimp, Varoom, Buneary, Burmy (Trash), Drowzee, *Hisuian Sneasel*, Jangmo-o, **Galarian Farfetch'd**, **Rotom** |
| Rock Aegis Cave | `RockAegisCave` | Đá, Ma, Vô định hình | 10 | Pidgey, Hisuian Typhlosion, *Hisuian Growlithe*, *Hisuian Zorua*, Tynamo, Hisuian Avalugg, Corsola, Shellos (East Sea), **Oricorio (Sensu Style)**, **Ogerpon Cornerstone** |
| Rock Maze | `RockMaze` | Đá, Thép, Giác đấu | 18 | Chimchar, Hisuian Sliggoo, Starly, *Alolan Diglett*, *Alolan Sandshrew*, Hisuian Lilligant, *Hisuian Growlithe*, Varoom, Buneary, *Galarian Meowth*, Hisuian Avalugg, Rookidee, Corsola, *Hisuian Sneasel*, Jangmo-o, Shellos (East Sea), **Galarian Farfetch'd**, **Ogerpon Cornerstone** |
| Rock Path 1 | `RockPathRB` | Đá, Thảo nguyên, Lửa | 15 | Chimchar, Pidove, Cetoddle, *Hisuian Growlithe*, Sizzlipede, Hisuian Avalugg, Spoink, Alolan Marowak, Corsola, Larvesta, Numel, Shellos (East Sea), Slakoth, **Oricorio (Baile Style)**, **Ogerpon Cornerstone** |
| Rock Path 2 | `RockPathTDS` | Đá, Thảo nguyên, Quái vật | 14 | Pidgey, Bagon, Cetoddle, *Hisuian Growlithe*, *Galarian Yamask*, Hisuian Avalugg, Spoink, Corsola, Drowzee, Numel, Shellos (East Sea), Slakoth, Snover, **Ogerpon Cornerstone** |
| Sealed Ruin | `SealedRuin` | Nhân hình, Rồng, Ma | 10 | Chimchar, Starly, Bagon, Hisuian Typhlosion, *Hisuian Zorua*, Impidimp, Alolan Exeggutor, Drowzee, Jangmo-o, **Oricorio (Sensu Style)** |
| Side Path | `SidePath` | Thường, Thảo nguyên, Thép | 13 | Hisuian Sliggoo, Pidove, *Alolan Diglett*, *Alolan Sandshrew*, Cetoddle, Varoom, Buneary, *Galarian Meowth*, Rookidee, Spoink, Doduo, Numel, Slakoth |
| Silent Chasm | `SilentChasm` | Lửa, Ánh sáng, Hoang dã | 14 | Chimchar, Pidgey, Cleffa, Rufflet, Sizzlipede, *Galarian Meowth*, Alolan Marowak, Cherubi, Doduo, *Galarian Ponyta*, Larvesta, Numel, **Oricorio (Baile Style)**, **Ogerpon Hearthflame** |
| Sky Peak 4th Pass | `SkyPeak4thPass` | Cỏ, Hoa, Nước | 12 | Mudkip, Starly, Gossifleur, *Hisuian Voltorb*, Burmy (Plant), Cutiefly, Lotad, Cherubi, Shellos (West Sea), Snover, **Tapu Bulu**, **Ogerpon Teal** |
| Sky Peak 7th Pass | `SkyPeak7thPass` | Băng, Rồng, Tiên | 13 | Pidove, *Alolan Sandshrew*, Bagon, Cetoddle, *Galarian Weezing*, *Alolan Vulpix*, Cutiefly, Alolan Exeggutor, *Galarian Darumaka*, *Galarian Ponyta*, Jangmo-o, Snover, **Tapu Fini** |
| Sky Peak Summit Pass | `SkyPeakSummitPass` | Bay, Đá, Giác đấu | 17 | Chimchar, Orbeetle, Pidgey, Hisuian Lilligant, *Hisuian Growlithe*, Rufflet, Salamence, Buneary, Hisuian Avalugg, Rookidee, Corsola, Doduo, *Hisuian Sneasel*, Jangmo-o, Shellos (East Sea), **Galarian Farfetch'd**, **Ogerpon Cornerstone** |
| Sky Tower | `SkyTower` | Bay, Ánh sáng, Tiên | 13 | Orbeetle, Starly, Cleffa, *Galarian Weezing*, Rufflet, Salamence, *Alolan Vulpix*, Cutiefly, Rookidee, Cherubi, Doduo, *Galarian Ponyta*, **Tapu Fini** |
| Snow Path | `SnowPath` | Băng, Thảo nguyên, Thường | 11 | Pidove, *Alolan Sandshrew*, Cetoddle, *Alolan Vulpix*, Buneary, Spoink, Doduo, *Galarian Darumaka*, Numel, Slakoth, Snover |
| Solar Cave 1 | `SolarCave1` | Siêu linh, Lửa, Âm thanh | 20 | Alolan Raichu, Blipbug, Chimchar, Pidgey, Cetoddle, Gossifleur, Sizzlipede, Lotad, Obstagoon, Spoink, Toxtricity, Alolan Marowak, Drowzee, *Galarian Ponyta*, Jangmo-o, Larvesta, Numel, **Oricorio (Baile Style)**, **Tapu Lele**, **Ogerpon Hearthflame** |
| Southern Cavern 1 | `SouthernCavern1` | Thép, Độc, Nhân tạo | 14 | Hisuian Sliggoo, Starly, *Alolan Diglett*, *Alolan Sandshrew*, *Galarian Slowpoke*, *Nidoran ♀*, Varoom, Burmy (Trash), *Galarian Meowth*, *Paldean Wooper*, Rookidee, Toxel, *Hisuian Sneasel*, **Rotom** |
| Southern Cavern 2 | `SouthernCavern2` | Tiên, Thủy sinh, Độc | 17 | Pidove, *Galarian Slowpoke*, *Galarian Weezing*, *Nidoran ♀*, Tynamo, Varoom, *Alolan Vulpix*, Cutiefly, Lotad, *Paldean Wooper*, Toxel, Corsola, *Galarian Ponyta*, *Hisuian Sneasel*, Shellos (East Sea), **Tapu Fini**, **Ogerpon Wellspring** |
| Southern Jungle | `SouthernJungle` | Hoang dã, Hoa, Cỏ | 13 | Pidgey, Gossifleur, *Hisuian Voltorb*, Rufflet, Burmy (Plant), Cutiefly, *Galarian Meowth*, Lotad, Cherubi, Doduo, Snover, **Tapu Bulu**, **Ogerpon Teal** |
| Spacial Cliffs | `SpacialCliffs` | Ma, Vô định hình, Điện | 9 | *Alolan Geodude*, Starly, Hisuian Typhlosion, *Hisuian Zorua*, Tynamo, Toxel, **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Spacial Rift 1 | `SpacialRift1` | Vô định hình, Nhân tạo, Quái vật | 9 | Pidove, Bagon, Tynamo, Varoom, Burmy (Trash), *Galarian Yamask*, Drowzee, Snover, **Rotom** |
| Spacial Rift 2 | `SpacialRift2` | Vô định hình, Nhân tạo, Siêu linh | 12 | Alolan Raichu, Blipbug, Pidgey, Tynamo, Varoom, Burmy (Trash), Spoink, Drowzee, *Galarian Ponyta*, **Oricorio (Pa’u Style)**, **Rotom**, **Tapu Lele** |
| Steam Cave | `SteamCave` | Lửa, Ẩm thực, Điện | 14 | *Alolan Geodude*, Chimchar, Starly, Sizzlipede, Tynamo, Toxel, Alolan Marowak, Cherubi, Larvesta, Numel, **Oricorio (Baile Style)**, **Rotom**, **Tapu Koko**, **Ogerpon Hearthflame** |
| Steam Cave 2 | `UnusedSteamCave` | Lửa, Nước, Điện | 15 | *Alolan Geodude*, Chimchar, Mudkip, Pidove, Sizzlipede, Tynamo, Toxel, Alolan Marowak, Larvesta, Numel, Shellos (West Sea), **Oricorio (Baile Style)**, **Rotom**, **Tapu Koko**, **Ogerpon Hearthflame** |
| Steel Aegis Cave | `SteelAegisCave` | Thép, Thường, Giác đấu | 15 | Chimchar, Hisuian Sliggoo, Pidove, *Alolan Diglett*, *Alolan Sandshrew*, Hisuian Lilligant, Varoom, Buneary, *Galarian Meowth*, Rookidee, Doduo, *Hisuian Sneasel*, Jangmo-o, Slakoth, **Galarian Farfetch'd** |
| Stormy Sea 1 | `StormySea1` | Nước, Thủy sinh, Điện | 12 | *Alolan Geodude*, Mudkip, Pidgey, Tynamo, Lotad, Toxel, Corsola, Shellos (West Sea), **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko**, **Ogerpon Wellspring** |
| Stormy Sea 2 | `StormySea2` | Nước, Thủy sinh, Âm thanh | 12 | Mudkip, Starly, Cetoddle, Gossifleur, Tynamo, Lotad, Obstagoon, Toxtricity, Corsola, Jangmo-o, Shellos (West Sea), **Ogerpon Wellspring** |
| Surrounded Sea | `SurroundedSea` | Nước, Băng, Hoang dã | 11 | Mudkip, Pidove, *Alolan Sandshrew*, Cetoddle, Rufflet, *Alolan Vulpix*, *Galarian Meowth*, Doduo, *Galarian Darumaka*, Shellos (West Sea), Snover |
| Temporal Spire | `TemporalSpire` | Nhân hình, Siêu linh, Vô định hình | 11 | Alolan Raichu, Blipbug, Chimchar, Pidgey, Impidimp, Tynamo, Spoink, Drowzee, *Galarian Ponyta*, **Oricorio (Pa’u Style)**, **Tapu Lele** |
| Temporal Tower | `TemporalTower` | Nhân hình, Thép, Nhân tạo | 12 | Chimchar, Hisuian Sliggoo, Starly, *Alolan Diglett*, *Alolan Sandshrew*, Impidimp, Varoom, Burmy (Trash), *Galarian Meowth*, Rookidee, Drowzee, **Rotom** |
| Temporal Tower 2 | `TemporalUnused` | Thường, Hóa thạch, Nhân tạo | 8 | Pidove, *Hisuian Voltorb*, Varoom, Buneary, Burmy (Trash), Doduo, Slakoth, **Rotom** |
| Test Dungeon | `TestDungeon` | Nhân tạo, Điện, Siêu linh | 15 | *Alolan Geodude*, Alolan Raichu, Blipbug, Pidgey, Tynamo, Varoom, Burmy (Trash), Spoink, Toxel, Drowzee, *Galarian Ponyta*, **Oricorio (Pa’u Style)**, **Rotom**, **Tapu Koko**, **Tapu Lele** |
| The Nightmare | `TheNightmare` | Ma, Bóng tối, Siêu linh | 18 | Alolan Raichu, *Alolan Rattata*, Blipbug, Seedot, Starly, *Alolan Grimer*, Hisuian Typhlosion, *Hisuian Zorua*, *Alolan Meowth*, *Galarian Zigzagoon*, Spoink, Drowzee, *Galarian Ponyta*, Hisuian Samurott, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Oricorio (Pa’u Style)**, **Tapu Lele** |
| Thunderwave Cave | `ThunderwaveCave` | Điện, Đất, Ánh sáng | 14 | *Alolan Geodude*, Mudkip, Pidove, Cleffa, Tynamo, Burmy (Sandy), Toxel, Cherubi, *Galarian Ponyta*, Numel, Shellos (West Sea), **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Tiny Meadow | `TinyMeadow` | Côn trùng, Sơ sinh, Vô định hình | 8 | Blipbug, Pidgey, Cleffa, Sizzlipede, Tynamo, Cutiefly, Toxel, Larvesta |
| Tiny Woods | `TinyWoods` | Côn trùng, Sơ sinh, Thường | 10 | Blipbug, Starly, Cleffa, Sizzlipede, Buneary, Cutiefly, Toxel, Doduo, Larvesta, Slakoth |
| Treeshroud Forest 1 | `TreeshroudForest1` | Ẩm thực, Hoa, Côn trùng | 8 | Blipbug, Pidove, Gossifleur, Sizzlipede, Cutiefly, Cherubi, Larvesta, **Ogerpon Teal** |
| Treeshroud Forest 2 | `TreeshroudForest2` | Cỏ, Độc, Sơ sinh | 13 | Pidgey, Cleffa, *Galarian Slowpoke*, *Hisuian Voltorb*, *Nidoran ♀*, Varoom, Burmy (Plant), Lotad, *Paldean Wooper*, Toxel, *Hisuian Sneasel*, Snover, **Tapu Bulu** |
| Uproar Forest | `UproarForest` | Hoang dã, Thảo nguyên, Âm thanh | 12 | Starly, Cetoddle, Gossifleur, Rufflet, *Galarian Meowth*, Lotad, Spoink, Toxtricity, Doduo, Jangmo-o, Numel, Slakoth |
| Vast Ice Mountain | `VastIceMountain` | Hoang dã, Băng, Đá | 14 | Pidove, *Alolan Sandshrew*, Cetoddle, *Hisuian Growlithe*, Rufflet, *Alolan Vulpix*, *Galarian Meowth*, Hisuian Avalugg, Corsola, Doduo, *Galarian Darumaka*, Shellos (East Sea), Snover, **Ogerpon Cornerstone** |
| Vast Ice Mountain Peak | `VastIceMountainPeak` | Rồng, Băng, Bay | 13 | Orbeetle, Pidgey, *Alolan Sandshrew*, Bagon, Cetoddle, Rufflet, *Alolan Vulpix*, Rookidee, Alolan Exeggutor, Doduo, *Galarian Darumaka*, Jangmo-o, Snover |
| Water Maze | `WaterMaze` | Nước, Thủy sinh, Cỏ | 11 | Mudkip, Pidgey, *Hisuian Voltorb*, Tynamo, Burmy (Plant), Lotad, Corsola, Shellos (West Sea), Snover, **Tapu Bulu**, **Ogerpon Wellspring** |
| Waterfall Cave | `WaterfallCave` | Nước, Đất, Âm thanh | 11 | Mudkip, Starly, Cetoddle, Gossifleur, Burmy (Sandy), Lotad, Obstagoon, Toxtricity, Jangmo-o, Numel, Shellos (West Sea) |
| Waterfall Pond | `WaterfallPond` | Nước, Vô định hình, Âm thanh | 10 | Mudkip, Pidove, Cetoddle, Gossifleur, Tynamo, Lotad, Obstagoon, Toxtricity, Jangmo-o, Shellos (West Sea) |
| Waterfall Pond 2 | `UnusedWaterfallPond` | Thủy sinh, Côn trùng, Sơ sinh | 12 | Blipbug, Pidgey, Cleffa, Sizzlipede, Tynamo, Cutiefly, Lotad, Toxel, Corsola, Larvesta, Shellos (East Sea), **Ogerpon Wellspring** |
| Western Cave 1 | `WesternCave1` | Nhân hình, Hoa, Nhân tạo | 11 | Chimchar, Starly, Gossifleur, Impidimp, Varoom, Burmy (Trash), Cutiefly, Cherubi, Drowzee, **Rotom**, **Ogerpon Teal** |
| Western Cave 2 | `WesternCave2` | Nhân hình, Hoa, Đá | 12 | Chimchar, Pidove, Gossifleur, *Hisuian Growlithe*, Impidimp, Cutiefly, Hisuian Avalugg, Cherubi, Corsola, Drowzee, Shellos (East Sea), **Ogerpon Cornerstone** |
| Wish Cave 1 | `WishCave1` | Tiên, Thủy sinh, Sơ sinh | 13 | Pidgey, Cleffa, *Galarian Weezing*, Tynamo, *Alolan Vulpix*, Cutiefly, Lotad, Toxel, Corsola, *Galarian Ponyta*, Shellos (East Sea), **Tapu Fini**, **Ogerpon Wellspring** |
| Wish Cave 2 | `WishCave2` | Tiên, Rồng, Côn trùng | 12 | Blipbug, Starly, Bagon, *Galarian Weezing*, Sizzlipede, *Alolan Vulpix*, Cutiefly, Alolan Exeggutor, *Galarian Ponyta*, Jangmo-o, Larvesta, **Tapu Fini** |
| World Abyss | `WorldAbyss2` | Bóng tối, Ma, Điện | 17 | *Alolan Geodude*, *Alolan Rattata*, Pidove, Seedot, *Alolan Grimer*, Hisuian Typhlosion, *Hisuian Zorua*, Tynamo, *Alolan Meowth*, *Galarian Zigzagoon*, Toxel, Hisuian Samurott, **Galarian Farfetch'd**, **Hisuian Qwilfish**, **Oricorio (Pom-Pom Style)**, **Rotom**, **Tapu Koko** |
| Wyvern Hill | `WyvernHill` | Rồng, Bay, Ẩm thực | 9 | Orbeetle, Pidgey, Bagon, Rufflet, Rookidee, Alolan Exeggutor, Cherubi, Doduo, Jangmo-o |
| Zero Isle East 3 | `ZeroIsleEast3` | Vô định hình, Siêu linh, Thép | 15 | Alolan Raichu, Blipbug, Hisuian Sliggoo, Starly, *Alolan Diglett*, *Alolan Sandshrew*, Tynamo, Varoom, *Galarian Meowth*, Rookidee, Spoink, Drowzee, *Galarian Ponyta*, **Oricorio (Pa’u Style)**, **Tapu Lele** |
| Zero Isle East 4 | `ZeroIsleEast4` | Độc, Quái vật, Siêu linh | 17 | Alolan Raichu, Blipbug, Pidove, Bagon, *Galarian Slowpoke*, *Nidoran ♀*, Varoom, *Galarian Yamask*, *Paldean Wooper*, Spoink, Toxel, Drowzee, *Galarian Ponyta*, *Hisuian Sneasel*, Snover, **Oricorio (Pa’u Style)**, **Tapu Lele** |
| Zero Isle South 1 | `ZeroIsleSouth1` | Quái vật, Côn trùng, Ẩm thực | 10 | Blipbug, Pidgey, Bagon, Sizzlipede, Cutiefly, *Galarian Yamask*, Cherubi, Drowzee, Larvesta, Snover |
| Zero Isle South 2 | `ZeroIsleSouth2` | Đá, Đất, Giác đấu | 15 | Chimchar, Mudkip, Starly, Hisuian Lilligant, *Hisuian Growlithe*, Buneary, Burmy (Sandy), Hisuian Avalugg, Corsola, *Hisuian Sneasel*, Jangmo-o, Numel, Shellos (West Sea), **Galarian Farfetch'd**, **Ogerpon Cornerstone** |

Nhiều Pokémon vùng nhất: Solar Cave 1 (20), Deep Dark Crater (20), Dark Wasteland (19). Ít nhất: Lush Prairie (7), Deep Sealed Ruin (6), Purity Forest 2 (5).

### 2.2 Vùng theo hệ

| Hệ | Số vùng | Vùng |
|---|---|---|
| Thường | 14 | Dark Ice Mountain, Final Maze 2, Grass Maze, Great Canyon, Lost Quicksand, Mt Freeze, Purity Forest 4, Purity Forest 6, Quicksand Cave, Side Path, Snow Path, Steel Aegis Cave, Temporal Tower 2, Tiny Woods |
| Cỏ | 14 | Deep Dusk Forest 1, Deep Dusk Forest 2, Dusk Forest 1, Dusk Forest 2, Forest Path, Grass Maze, Hidden Highland, Murky Forest, Purity Forest 6, Purity Forest 7, Sky Peak 4th Pass, Southern Jungle, Treeshroud Forest 2, Water Maze |
| Lửa | 14 | Dark Crater, Deep Dark Crater, Desert Region, Great Canyon, Magma Cavern 2, Magma Cavern 3, Mt Blaze, Northern Desert 1, Northern Desert 2, Rock Path 1, Silent Chasm, Solar Cave 1, Steam Cave, Steam Cave 2 |
| Nước | 14 | Craggy Coast, Deep Limestone Cavern, Hidden Land, Lapis Cave, Miracle Sea, Northwind Field, Sky Peak 4th Pass, Steam Cave 2, Stormy Sea 1, Stormy Sea 2, Surrounded Sea, Water Maze, Waterfall Cave, Waterfall Pond |
| Điện | 14 | Amp Plains, Electric Maze, Far Amp Plains, Lightning Field, Mt Bristle, Mt Thunder, Mt Thunder Peak, Spacial Cliffs, Steam Cave, Steam Cave 2, Stormy Sea 1, Test Dungeon, Thunderwave Cave, World Abyss |
| Giác đấu | 14 | Barren Valley, Craggy Coast, Frosty Forest, Ice Aegis Cave, Ice Maze, Icicle Forest, Magma Cavern 2, Mt Travail, Northern Range 2, Rescue Team Maze, Rock Maze, Sky Peak Summit Pass, Steel Aegis Cave, Zero Isle South 2 |
| Siêu linh | 14 | Crystal Cave 1, Crystal Cave 2, Crystal Crossing, Future Temporal Spire, Future Temporal Tower, Meteor Cave, Poison Maze, Solar Cave 1, Spacial Rift 2, Temporal Spire, Test Dungeon, The Nightmare, Zero Isle East 3, Zero Isle East 4 |
| Bóng tối | 14 | Brine Cave, Dark Crater, Dark Hill 1, Dark Hill 2, Dark Ice Mountain, Dark Ice Mountain Peak, Dark Wasteland, Deep Dark Crater, Deep Dusk Forest 1, Dusk Forest 1, Moonlit Courtyard, Murky Forest, The Nightmare, World Abyss |
| Thép | 14 | Deep Boulder Quarry, Golden Chamber, Ice Maze, Mt Steel 1, Mt Steel 2, Mt Thunder, Northern Range 1, Northern Range 2, Rock Maze, Side Path, Southern Cavern 1, Steel Aegis Cave, Temporal Tower, Zero Isle East 3 |
| Đất | 14 | Beach Cave, Brine Cave 2, Buried Relic 2, Buried Relic 3, Dark Crater, Ice Aegis Cave, Lost Quicksand, Magma Cavern 2, Murky Cave, Quicksand Cave, Quicksand Pit, Thunderwave Cave, Waterfall Cave, Zero Isle South 2 |
| Độc | 14 | Brine Cave, Concealed Ruins, Crystal Crossing, Dark Wasteland, Howling Forest 2, Lost Quicksand, Mystery Jungle 1, Mystery Jungle 2, Northern Range 1, Poison Maze, Southern Cavern 1, Southern Cavern 2, Treeshroud Forest 2, Zero Isle East 4 |
| Rồng | 14 | Brine Cave 2, Golden Chamber, Hidden Highland, Lower Brine Cave, Magma Cavern 3, Mt Faraway 2, Mystifying Forest, Northern Desert 1, Northern Desert 2, Sealed Ruin, Sky Peak 7th Pass, Vast Ice Mountain Peak, Wish Cave 2, Wyvern Hill |
| Thảo nguyên | 14 | Amp Plains, Desert Region, Far Amp Plains, Grass Maze, Howling Forest 1, Icicle Forest, Lightning Field, Northwind Field, Pitfall Valley 1, Rock Path 1, Rock Path 2, Side Path, Snow Path, Uproar Forest |
| Quái vật | 14 | Craggy Coast, Dark Wasteland, Deep Dark Crater, Drenched Bluff, Dusk Forest 1, Future Temporal Tower, Magma Cavern 3, Mt Bristle, Northern Range 2, Quicksand Pit, Rock Path 2, Spacial Rift 1, Zero Isle East 4, Zero Isle South 1 |
| Nhân hình | 14 | Buried Relic 1, Buried Relic 3, Darknight Relic, Future Temporal Spire, Meteor Cave, Mt Travail, Murky Cave, Pitfall Valley 1, Rescue Team Maze, Sealed Ruin, Temporal Spire, Temporal Tower, Western Cave 1, Western Cave 2 |
| Thủy sinh | 14 | Beach Cave, Crystal Crossing, Darknight Relic, Drenched Bluff, Lapis Cave, Limestone Cavern, Lower Brine Cave, Miracle Sea, Southern Cavern 2, Stormy Sea 1, Stormy Sea 2, Water Maze, Waterfall Pond 2, Wish Cave 1 |
| Côn trùng | 14 | Apple Woods, Deep Limestone Cavern, Final Maze 2, Forest Path, Hidden Land, Howling Forest 1, Limestone Cavern, Poison Maze, Tiny Meadow, Tiny Woods, Treeshroud Forest 1, Waterfall Pond 2, Wish Cave 2, Zero Isle South 1 |
| Bay | 14 | Dark Hill 1, Dark Ice Mountain Peak, Mt Blaze, Mt Bristle, Mt Faraway 4, Mt Freeze, Mt Horn, Mt Steel 1, Mt Steel 2, Mt Thunder Peak, Sky Peak Summit Pass, Sky Tower, Vast Ice Mountain Peak, Wyvern Hill |
| Hoa | 14 | Dusk Forest 2, Final Maze 2, Foggy Forest, Hidden Highland, Hidden Land, Lush Prairie, Moonlit Courtyard, Mystery Jungle 1, Mystifying Forest, Sky Peak 4th Pass, Southern Jungle, Treeshroud Forest 1, Western Cave 1, Western Cave 2 |
| Đá | 14 | Barren Valley, Deep Boulder Quarry, Deep Limestone Cavern, Limestone Cavern, Mt Horn, Mt Thunder, Rock Aegis Cave, Rock Maze, Rock Path 1, Rock Path 2, Sky Peak Summit Pass, Vast Ice Mountain, Western Cave 2, Zero Isle South 2 |
| Ma | 14 | Barren Valley, Concealed Ruins, Dark Hill 1, Dark Hill 2, Deep Dusk Forest 2, Deep Sealed Ruin, Dusk Forest 2, Murky Cave, Murky Forest, Rock Aegis Cave, Sealed Ruin, Spacial Cliffs, The Nightmare, World Abyss |
| Tiên | 14 | Crystal Cave 1, Foggy Forest, Joyous Tower, Meteor Cave, Miracle Sea, Moonlit Courtyard, Mystery Jungle 2, Mystifying Forest, Purity Forest 4, Sky Peak 7th Pass, Sky Tower, Southern Cavern 2, Wish Cave 1, Wish Cave 2 |
| Băng | 14 | Dark Ice Mountain, Dark Ice Mountain Peak, Frosty Forest, Ice Aegis Cave, Ice Maze, Icicle Forest, Mt Faraway 2, Mt Faraway 4, Mt Freeze, Sky Peak 7th Pass, Snow Path, Surrounded Sea, Vast Ice Mountain, Vast Ice Mountain Peak |
| Hóa thạch | 14 | Beach Cave, Brine Cave, Darknight Relic, Deep Boulder Quarry, Deep Sealed Ruin, Drenched Bluff, Far Amp Plains, Lapis Cave, Lower Brine Cave, Mt Steel 1, Mt Travail, Quicksand Cave, Quicksand Pit, Temporal Tower 2 |
| Âm thanh | 14 | Amp Plains, Crystal Cave 1, Crystal Cave 2, Howling Forest 1, Howling Forest 2, Mt Faraway 4, Mt Horn, Northwind Field, Purity Forest 7, Solar Cave 1, Stormy Sea 2, Uproar Forest, Waterfall Cave, Waterfall Pond |
| Nhân tạo | 13 | Buried Relic 1, Buried Relic 2, Buried Relic 3, Future Temporal Spire, Future Temporal Tower, Rescue Team Maze, Southern Cavern 1, Spacial Rift 1, Spacial Rift 2, Temporal Tower, Temporal Tower 2, Test Dungeon, Western Cave 1 |
| Sơ sinh | 13 | Apple Woods, Forest Path, Joyous Tower, Pitfall Valley 1, Purity Forest 2, Purity Forest 4, Purity Forest 6, Purity Forest 7, Tiny Meadow, Tiny Woods, Treeshroud Forest 2, Waterfall Pond 2, Wish Cave 1 |
| Ánh sáng | 14 | Buried Relic 1, Buried Relic 2, Crystal Cave 2, Deep Dusk Forest 2, Desert Region, Electric Maze, Frosty Forest, Joyous Tower, Lightning Field, Lush Prairie, Northern Desert 1, Silent Chasm, Sky Tower, Thunderwave Cave |
| Hoang dã | 14 | Concealed Ruins, Foggy Forest, Great Canyon, Mt Blaze, Mt Thunder Peak, Mystery Jungle 1, Mystery Jungle 2, Northern Desert 2, Northern Range 1, Silent Chasm, Southern Jungle, Surrounded Sea, Uproar Forest, Vast Ice Mountain |
| Vô định hình | 14 | Dark Hill 2, Deep Sealed Ruin, Golden Chamber, Mt Faraway 2, Mt Steel 2, Purity Forest 2, Rock Aegis Cave, Spacial Cliffs, Spacial Rift 1, Spacial Rift 2, Temporal Spire, Tiny Meadow, Waterfall Pond, Zero Isle East 3 |
| Ẩm thực | 11 | Apple Woods, Brine Cave 2, Deep Dusk Forest 1, Electric Maze, Howling Forest 2, Lush Prairie, Purity Forest 2, Steam Cave, Treeshroud Forest 1, Wyvern Hill, Zero Isle South 1 |

### 2.3 Biến thể vùng

| Dạng gốc | Biến thể | Hệ của biến thể | Cần mở khoá | Số vùng |
|---|---|---|---|---|
| Rattata | Alolan Rattata | Hoang dã, Bóng tối | — | 14 |
| Growlithe | Hisuian Growlithe | Lửa, Đá, Thảo nguyên | Growlithe | 14 |
| Vulpix | Alolan Vulpix | Băng, Tiên | Vulpix | 27 |
| Geodude | Alolan Geodude | Điện, Đá | — | 14 |
| Diglett | Alolan Diglett | Đất, Thép | Diglett | 14 |
| Zorua | Hisuian Zorua | Thường, Ma | Zorua | 14 |
| Grimer | Alolan Grimer | Độc, Bóng tối, Vô định hình | Grimer | 14 |
| Nidoran ♂ | Nidoran ♀ | Độc, Thảo nguyên, Đất | — | 14 |
| Sneasel | Hisuian Sneasel | Độc, Giác đấu, Quái vật | Sneasel | 28 |
| Meowth | Alolan Meowth | Thường, Bóng tối | Meowth | 13 |
| Meowth | Galarian Meowth | Thép, Hoang dã | Meowth | 27 |
| Ponyta | Galarian Ponyta | Tiên, Siêu linh, Ánh sáng | Ponyta | 37 |
| Voltorb | Hisuian Voltorb | Điện, Cỏ, Hóa thạch | Voltorb | 28 |
| Sandshrew | Alolan Sandshrew | Băng, Thép | Sandshrew | 27 |
| Wooper | Paldean Wooper | Độc, Đất, Thủy sinh | — | 14 |
| Farfetch'd | Galarian Farfetch'd | Bay, Ẩm thực, Giác đấu | — | 28 |
| Zigzagoon | Galarian Zigzagoon | Hoang dã, Bóng tối | — | 14 |
| Qwilfish | Hisuian Qwilfish | Bóng tối, Độc, Thủy sinh | — | 14 |
| Yamask | Galarian Yamask | Ma, Quái vật | Yamask | 14 |
| Slowpoke | Galarian Slowpoke | Siêu linh, Độc | Slowpoke | 14 |
| Weezing | Galarian Weezing | Độc, Nhân tạo, Tiên | — | 14 |
| Darumaka | Galarian Darumaka | Hoang dã, Băng, Lửa | — | 14 |

“Cần mở khoá”: họ additional phải vào shop trước (additional pick stage 5 / 8 / 11) thì biến thể mới xuất hiện.

Tổng: 163 dạng regional đã port (73 họ), trong 175 dạng bản web có luật vùng.
