# Kiểm tra vai trò Pokémon

*Sinh bằng `tools\role_audit.bat` (probe: `tools/roles/role_probe.gd`, luật: `tools/roles/role_rules.json`, báo cáo: `tools/roles/role_audit.py`); đừng sửa tay. Bảng đủ số: `build/roles/roles.tsv`.*

Probe đặt từng dạng lên một sàn thử (chỉ số web, không item / AP / hệ), cho nó dùng skill một lần rồi đo: tầm với thật (một địch đứng cách 1..7 ô), sát thương khi đứng hàng đầu / hàng cuối lên 7 địch, burn / poison nó gây, hồi / khiên / buff cho đồng đội và cho chính nó, trạng thái / debuff lên địch, lao tới / triệu hồi. Luật (sửa được ở `role_rules.json`) ước lượng một trận 16 s: phần sát thương từ skill so với đòn đánh, rồi xếp vai trò. Vai trò hiện tại là `UnitRoles._guess` (chỉ đọc skill dạng data: 806 dạng có skill viết bằng code bị coi như skill không gây sát thương).

## Tóm tắt

1106 dạng có trong game (shop / unique / legendary / trứng của mọi mùa), 517 dạng đổi vai trò (255 họ).

| Vai trò | Hiện tại | Gợi ý |
|---|---|---|
| Đỡ đòn | 522 | 313 |
| Đấu sĩ | 167 | 286 |
| Sát thủ | 34 | 98 |
| Xạ thủ | 267 | 198 |
| Pháp sư | 92 | 138 |
| Hỗ trợ | 24 | 73 |

Đổi nhiều nhất: Đỡ đòn → Đấu sĩ 180, Xạ thủ → Pháp sư 83, Đỡ đòn → Sát thủ 56, Đấu sĩ → Đỡ đòn 53, Pháp sư → Xạ thủ 38, Xạ thủ → Hỗ trợ 34, Đỡ đòn → Hỗ trợ 29, Hỗ trợ → Xạ thủ 15.

## Hệ và vai trò

Mỗi hệ có một *focus* (hiệu ứng của nó có lợi cho ai: đòn đánh, skill, đứng trước, gây sát thương); vai trò hưởng: Đỡ đòn: front; Đấu sĩ: attack, front, damage; Sát thủ: attack, damage; Xạ thủ: attack, damage; Pháp sư: ability, damage; Đấu sĩ phép: ability, front, damage; Hỗ trợ: ability. **Hợp** = phần thành viên (theo dạng cuối của họ) có vai trò hưởng hiệu ứng của hệ. Hệ dưới 50% bị đánh dấu ⚠.

### Season 1: Genesis

| Hệ | Focus | Họ | Vai trò hiện tại | Hợp | Vai trò gợi ý | Hợp | Không hưởng (gợi ý) |
|---|---|---|---|---|---|---|---|
| ⚠ Nước | ability | 20 | Đỡ đòn 8, Đấu sĩ 2, Sát thủ 1, Xạ thủ 5, Pháp sư 4 | 20% | Đỡ đòn 4, Đấu sĩ 6, Sát thủ 2, Xạ thủ 5, Pháp sư 3 | 15% | AZUMARILL, BRUXISH, EMPOLEON, FERALIGATR, GOLISOPOD, HISUI_SAMUROTT … |
| ⚠ Âm thanh | ability | 10 | Đỡ đòn 4, Xạ thủ 4, Pháp sư 2 | 20% | Đỡ đòn 1, Đấu sĩ 2, Xạ thủ 4, Pháp sư 2, Hỗ trợ 1 | 30% | CROBAT, MARACTUS, POLITOED, SCREAM_TAIL, TOXTRICITY, VIVILLON … |
| ⚠ Siêu linh | ability | 26 | Đỡ đòn 10, Đấu sĩ 1, Sát thủ 1, Xạ thủ 11, Pháp sư 3 | 12% | Đỡ đòn 6, Đấu sĩ 5, Sát thủ 1, Xạ thủ 5, Pháp sư 7, Hỗ trợ 2 | 35% | ALOLAN_EXEGGUTOR, ALOLAN_RAICHU, BRUXISH, DARMANITAN, DEOXYS, EXEGGUTOR … |
| ⚠ Lửa | attack | 18 | Đỡ đòn 4, Đấu sĩ 3, Sát thủ 1, Xạ thủ 5, Pháp sư 5 | 50% | Đỡ đòn 2, Đấu sĩ 5, Sát thủ 1, Xạ thủ 2, Pháp sư 8 | 44% | ARCANINE, ARMAROUGE, DELPHOX, HEATRAN, HISUIAN_TYPHLOSION, MAGMORTAR … |
| ⚠ Cỏ | front | 15 | Đỡ đòn 6, Đấu sĩ 2, Xạ thủ 4, Pháp sư 3 | 53% | Đỡ đòn 3, Đấu sĩ 4, Xạ thủ 2, Pháp sư 3, Hỗ trợ 3 | 47% | ARBOLIVA, CARNIVINE, CELEBI, MEOWSCARADA, RILLABOOM, ROSERADE … |
| ⚠ Bóng tối | attack | 15 | Đỡ đòn 7, Đấu sĩ 3, Xạ thủ 2, Pháp sư 3 | 33% | Đỡ đòn 4, Đấu sĩ 5, Sát thủ 1, Xạ thủ 1, Pháp sư 3, Hỗ trợ 1 | 47% | HYDREIGON, KINGAMBIT, KROOKODILE, LUNATONE, MEOWSCARADA, MIGHTYENA … |
| Thường | front | 14 | Đỡ đòn 3, Đấu sĩ 4, Sát thủ 1, Xạ thủ 4, Pháp sư 1, Hỗ trợ 1 | 50% | Đỡ đòn 4, Đấu sĩ 3, Sát thủ 1, Xạ thủ 2, Pháp sư 2, Hỗ trợ 2 | 50% | ARBOLIVA, BLISSEY, HELIOLISK, PACHIRISU, PORYGON_Z, VIVILLON_ICY_SNOW … |
| ↑ Băng | attack | 12 | Đỡ đòn 5, Đấu sĩ 1, Sát thủ 1, Xạ thủ 2, Pháp sư 3 | 33% | Đỡ đòn 4, Đấu sĩ 2, Sát thủ 1, Xạ thủ 3, Pháp sư 2 | 50% | ARTICUNO, AURORUS, EMPOLEON, FROSLASS, MAMOSWINE, WALREIN |
| Hóa thạch | front | 10 | Đỡ đòn 6, Xạ thủ 4 | 60% | Đỡ đòn 4, Đấu sĩ 1, Sát thủ 1, Xạ thủ 3, Pháp sư 1 | 50% | ARCHEOPS, OMASTAR, ROARING_MOON, SLITHER_WING, VIVILLON_CONTINENTAL |
| Bay | front | 21 | Đỡ đòn 7, Đấu sĩ 3, Sát thủ 1, Xạ thủ 6, Pháp sư 4 | 48% | Đỡ đòn 4, Đấu sĩ 7, Sát thủ 1, Xạ thủ 4, Pháp sư 5 | 52% | ARCHEOPS, ARTICUNO, CHATOT, CROBAT, EMOLGA, ENAMORUS … |
| ↑ Thép | damage | 18 | Đỡ đòn 10, Đấu sĩ 2, Xạ thủ 5, Pháp sư 1 | 44% | Đỡ đòn 8, Đấu sĩ 2, Sát thủ 2, Xạ thủ 2, Pháp sư 4 | 56% | EMPOLEON, GHOLDENGO, HISUI_GOODRA, KINGAMBIT, MELMETAL, METAGROSS … |
| Điện | attack | 17 | Đỡ đòn 4, Đấu sĩ 1, Sát thủ 4, Xạ thủ 7, Pháp sư 1 | 71% | Đỡ đòn 1, Đấu sĩ 3, Sát thủ 5, Xạ thủ 2, Pháp sư 6 | 59% | AMPHAROS, ARCHALUDON, HELIOLISK, MAGNEZONE, ZAPDOS, ZEKROM … |
| ↑ Quái vật | attack | 13 | Đỡ đòn 9, Đấu sĩ 3, Xạ thủ 1 | 31% | Đỡ đòn 5, Đấu sĩ 6, Sát thủ 1, Xạ thủ 1 | 62% | KROOKODILE, PRIMAL_GROUDON, RHYPERIOR, SUDOWOODO, TORTERRA |
| ↑ Ma | attack | 13 | Đỡ đòn 7, Xạ thủ 4, Pháp sư 2 | 31% | Đỡ đòn 2, Đấu sĩ 2, Sát thủ 3, Xạ thủ 4, Pháp sư 2 | 69% | FROSLASS, GHOLDENGO, HISUIAN_TYPHLOSION, MIMIKYU |
| Giác đấu | front | 21 | Đỡ đòn 17, Đấu sĩ 2, Sát thủ 1, Xạ thủ 1 | 90% | Đỡ đòn 5, Đấu sĩ 10, Sát thủ 5, Xạ thủ 1 | 71% | HAWLUCHA, IRON_VALIANT, MARSHADOW, PHEROMOSA, SLITHER_WING, VIVILLON_ARCHIPELAGO |
| ↑ Độc | attack | 15 | Đỡ đòn 5, Đấu sĩ 2, Sát thủ 1, Xạ thủ 3, Pháp sư 4 | 40% | Đỡ đòn 1, Đấu sĩ 5, Sát thủ 2, Xạ thủ 4, Pháp sư 3 | 73% | DRAGALGE, NIDOKING, ROSERADE, VENUSAUR |
| ↑ Đá | front | 15 | Đỡ đòn 7, Đấu sĩ 3, Sát thủ 1, Xạ thủ 3, Hỗ trợ 1 | 67% | Đỡ đòn 8, Đấu sĩ 3, Sát thủ 1, Xạ thủ 2, Hỗ trợ 1 | 73% | ARCHEOPS, LUNATONE, LYCANROC_DAY, VIVILLON_SANDSTORM |
| ↑ Hoang dã | attack | 15 | Đỡ đòn 8, Đấu sĩ 4, Sát thủ 2, Pháp sư 1 | 40% | Đỡ đòn 4, Đấu sĩ 8, Sát thủ 2, Xạ thủ 1 | 73% | DONPHAN, LINOONE, MIGHTYENA, ZERAORA |
| ↑ Tiên | attack | 35 | Đỡ đòn 5, Đấu sĩ 1, Sát thủ 2, Xạ thủ 19, Pháp sư 2, Hỗ trợ 6 | 63% | Đỡ đòn 4, Đấu sĩ 1, Sát thủ 3, Xạ thủ 22, Pháp sư 4, Hỗ trợ 1 | 74% | BLISSEY, ENAMORUS, GARDEVOIR, HATTERENE, KLEFKI, MIMIKYU … |
| ↑ Nhân hình | damage | 15 | Đỡ đòn 8, Đấu sĩ 1, Xạ thủ 3, Pháp sư 3 | 47% | Đỡ đòn 3, Đấu sĩ 5, Sát thủ 1, Xạ thủ 2, Pháp sư 4 | 80% | REGIGIGAS, REGIROCK, REGISTEEL |

### Season 2: Ancient Ruins

| Hệ | Focus | Họ | Vai trò hiện tại | Hợp | Vai trò gợi ý | Hợp | Không hưởng (gợi ý) |
|---|---|---|---|---|---|---|---|
| ⚠ Siêu linh | ability | 19 | Đỡ đòn 5, Đấu sĩ 3, Sát thủ 1, Xạ thủ 9, Pháp sư 1 | 5% | Đỡ đòn 3, Đấu sĩ 4, Sát thủ 2, Xạ thủ 6, Pháp sư 2, Hỗ trợ 2 | 21% | ALOLAN_RAICHU, AZELF, BRONZONG, GALARIAN_SLOWBRO, GOLDUCK, HOOPA … |
| ⚠ Nước | ability | 16 | Đỡ đòn 8, Đấu sĩ 2, Xạ thủ 3, Pháp sư 3 | 19% | Đỡ đòn 6, Đấu sĩ 3, Sát thủ 1, Xạ thủ 2, Pháp sư 4 | 25% | AZUMARILL, GASTRODON_WEST_SEA, GOLDUCK, IRON_BUNDLE, KABUTOPS, MANAPHY … |
| ⚠ Âm thanh | ability | 14 | Đỡ đòn 7, Đấu sĩ 1, Xạ thủ 5, Pháp sư 1 | 7% | Đỡ đòn 4, Đấu sĩ 2, Sát thủ 1, Xạ thủ 3, Pháp sư 3, Hỗ trợ 1 | 29% | AUDINO, BRONZONG, CETITAN, FEZANDIPITI, KOMALA, KRICKETUNE … |
| ⚠ Thép | damage | 17 | Đỡ đòn 11, Đấu sĩ 2, Xạ thủ 3, Pháp sư 1 | 35% | Đỡ đòn 9, Đấu sĩ 3, Xạ thủ 2, Pháp sư 2, Hỗ trợ 1 | 41% | BASTIODON, BRONZONG, CELESTEELA, COBALION, DHELMISE, ESCAVALIER … |
| ⚠ Bay | front | 19 | Đỡ đòn 6, Đấu sĩ 3, Xạ thủ 8, Pháp sư 2 | 47% | Đỡ đòn 2, Đấu sĩ 6, Sát thủ 1, Xạ thủ 5, Pháp sư 5 | 42% | DECIDUEYE, KILOWATTREL, MINIOR, NOIVERN, PIDGEOT, SHAYMIN_SKY … |
| ⚠ Điện | attack | 18 | Đỡ đòn 6, Đấu sĩ 3, Sát thủ 3, Xạ thủ 5, Pháp sư 1 | 61% | Đỡ đòn 6, Đấu sĩ 3, Sát thủ 3, Xạ thủ 2, Pháp sư 4 | 44% | ALOLAN_GOLEM, AMPHAROS, DEDENNE, EELEKTROSS, IRON_HANDS, KILOWATTREL … |
| ⚠ Bóng tối | attack | 13 | Đỡ đòn 8, Đấu sĩ 3, Xạ thủ 1, Pháp sư 1 | 31% | Đỡ đòn 5, Đấu sĩ 6, Pháp sư 2 | 46% | ALOLAN_RATICATE, CHI_YU, CRAWDAUNT, KINGAMBIT, MEOWSCARADA, MORPEKO … |
| ↑ Lửa | attack | 18 | Đỡ đòn 7, Đấu sĩ 2, Sát thủ 1, Xạ thủ 5, Pháp sư 3 | 44% | Đỡ đòn 3, Đấu sĩ 4, Sát thủ 2, Xạ thủ 3, Pháp sư 5, Hỗ trợ 1 | 50% | ALOLAN_MAROWAK, BLACEPHALON, CHI_YU, DELPHOX, HISUI_ARCANINE, MAGCARGO … |
| ↑ Độc | attack | 16 | Đỡ đòn 9, Đấu sĩ 2, Xạ thủ 4, Pháp sư 1 | 38% | Đỡ đòn 6, Đấu sĩ 5, Xạ thủ 3, Pháp sư 1, Hỗ trợ 1 | 50% | ETERNATUS, GALARIAN_SLOWBRO, GALARIAN_SLOWKING, GLIMMORA, PECHARUNT, SKUNTANK … |
| ↑ Băng | attack | 12 | Đỡ đòn 7, Đấu sĩ 2, Sát thủ 1, Xạ thủ 2 | 42% | Đỡ đòn 5, Đấu sĩ 3, Sát thủ 2, Xạ thủ 1, Pháp sư 1 | 50% | AURORUS, AVALUGG, CETITAN, KYUREM, MAMOSWINE, REGICE |
| Cỏ | front | 17 | Đỡ đòn 10, Đấu sĩ 2, Xạ thủ 3, Pháp sư 2 | 71% | Đỡ đòn 6, Đấu sĩ 3, Sát thủ 1, Xạ thủ 1, Pháp sư 3, Hỗ trợ 3 | 53% | ARBOLIVA, DECIDUEYE, GOGOAT, LILIGANT, MEOWSCARADA, RILLABOOM … |
| ↑ Ma | attack | 15 | Đỡ đòn 7, Đấu sĩ 2, Xạ thủ 5, Pháp sư 1 | 47% | Đỡ đòn 4, Đấu sĩ 4, Sát thủ 1, Xạ thủ 3, Pháp sư 3 | 53% | ALOLAN_MAROWAK, BLACEPHALON, DECIDUEYE, DHELMISE, MAROWAK, PECHARUNT … |
| ↑ Tiên | attack | 15 | Đỡ đòn 6, Sát thủ 2, Xạ thủ 5, Pháp sư 1, Hỗ trợ 1 | 47% | Đỡ đòn 4, Đấu sĩ 2, Sát thủ 2, Xạ thủ 4, Pháp sư 1, Hỗ trợ 2 | 53% | ALTARIA, BLISSEY, CRESSELIA, DEDENNE, DIANCIE, MAUSHOLD_FOUR … |
| ↑ Quái vật | attack | 13 | Đỡ đòn 7, Đấu sĩ 2, Xạ thủ 4 | 46% | Đỡ đòn 5, Đấu sĩ 4, Xạ thủ 3, Pháp sư 1 | 54% | AVALUGG, HARIYAMA, KANGASKHAN, PRIMAL_KYOGRE, RHYPERIOR, TANGROWTH |
| Thường | front | 20 | Đỡ đòn 10, Đấu sĩ 3, Xạ thủ 4, Pháp sư 2, Hỗ trợ 1 | 65% | Đỡ đòn 7, Đấu sĩ 5, Sát thủ 1, Xạ thủ 1, Pháp sư 3, Hỗ trợ 3 | 60% | ARBOLIVA, AUDINO, BLISSEY, CYCLIZAR, EXPLOUD, PIDGEOT … |
| ↑ Nhân hình | damage | 15 | Đỡ đòn 8, Đấu sĩ 1, Xạ thủ 5, Pháp sư 1 | 47% | Đỡ đòn 5, Đấu sĩ 4, Xạ thủ 3, Pháp sư 2, Hỗ trợ 1 | 60% | HISUIAN_LILLIGANT, HITMONCHAN, HITMONTOP, LILIGANT, MACHAMP, REGICE |
| ↑ Hoang dã | attack | 8 | Đỡ đòn 4, Đấu sĩ 3, Sát thủ 1 | 50% | Đỡ đòn 3, Đấu sĩ 3, Sát thủ 2 | 62% | ALOLAN_RATICATE, PERRSERKER, URSALUNA |
| Đá | front | 14 | Đỡ đòn 10, Đấu sĩ 2, Xạ thủ 1, Pháp sư 1 | 86% | Đỡ đòn 7, Đấu sĩ 3, Xạ thủ 1, Pháp sư 1, Hỗ trợ 2 | 71% | BASTIODON, GIGALITH, MAGCARGO, MINIOR |
| Giác đấu | front | 19 | Đỡ đòn 12, Đấu sĩ 4, Xạ thủ 3 | 84% | Đỡ đòn 11, Đấu sĩ 5, Xạ thủ 2, Pháp sư 1 | 84% | LUCARIO, MEDICHAM, PASSIMIAN |
| Hóa thạch | front | 13 | Đỡ đòn 10, Đấu sĩ 3 | 100% | Đỡ đòn 7, Đấu sĩ 5, Hỗ trợ 1 | 92% | BASTIODON |

### Season 3: Festival of Lights

| Hệ | Focus | Họ | Vai trò hiện tại | Hợp | Vai trò gợi ý | Hợp | Không hưởng (gợi ý) |
|---|---|---|---|---|---|---|---|
| ⚠ Nước | ability | 22 | Đỡ đòn 11, Đấu sĩ 2, Xạ thủ 7, Pháp sư 2 | 9% | Đỡ đòn 6, Đấu sĩ 6, Sát thủ 1, Xạ thủ 7, Hỗ trợ 2 | 9% | AZUMARILL, BARBARACLE, BASCULEGION_FEMALE, BASCULEGION_MALE, BASCULIN_BLUE, BASCULIN_RED … |
| ⚠ Siêu linh | ability | 20 | Đỡ đòn 6, Đấu sĩ 1, Sát thủ 1, Xạ thủ 11, Pháp sư 1 | 5% | Đỡ đòn 1, Đấu sĩ 2, Sát thủ 4, Xạ thủ 7, Pháp sư 4, Hỗ trợ 2 | 30% | ALAKAZAM, ALOLAN_RAICHU, BEHEEYEM, CHIMECHO, GRUMPIG, INDEEDEE_FEMALE … |
| ⚠ Thường | front | 17 | Đỡ đòn 6, Đấu sĩ 2, Xạ thủ 7, Pháp sư 1, Hỗ trợ 1 | 47% | Đỡ đòn 5, Đấu sĩ 1, Sát thủ 1, Xạ thủ 4, Pháp sư 2, Hỗ trợ 4 | 35% | ARBOLIVA, BLISSEY, DRAMPA, FURFROU, INDEEDEE_FEMALE, INDEEDEE_MALE … |
| ⚠ Băng | attack | 14 | Đỡ đòn 8, Đấu sĩ 2, Sát thủ 1, Xạ thủ 3 | 43% | Đỡ đòn 7, Đấu sĩ 3, Sát thủ 1, Xạ thủ 1, Pháp sư 1, Hỗ trợ 1 | 36% | ALOLAN_NINETALES, ALOLAN_SANDSLASH, CLOYSTER, CRABOMINABLE, DELIBIRD, DEWGONG … |
| ⚠ Bay | front | 20 | Đỡ đòn 6, Đấu sĩ 5, Xạ thủ 7, Pháp sư 2 | 55% | Đỡ đòn 3, Đấu sĩ 5, Sát thủ 3, Xạ thủ 3, Pháp sư 5, Hỗ trợ 1 | 40% | BUTTERFREE, CRAMORANT, DRIFBLIM, GLISCOR, HO_OH, LANDORUS … |
| ⚠ Hoang dã | attack | 12 | Đỡ đòn 8, Đấu sĩ 3, Sát thủ 1 | 33% | Đỡ đòn 7, Đấu sĩ 3, Sát thủ 2 | 42% | ABSOL, ANNIHILAPE, BRAVIARY, EMBOAR, OBSTAGOON, URSALUNA … |
| ⚠ Độc | attack | 13 | Đỡ đòn 9, Đấu sĩ 2, Sát thủ 1, Xạ thủ 1 | 31% | Đỡ đòn 4, Đấu sĩ 4, Sát thủ 2, Pháp sư 1, Hỗ trợ 2 | 46% | CLODSIRE, GALARIAN_WEEZING, GARBODOR, MUK, NIHILEGO, SWALOT … |
| ⚠ Quái vật | attack | 13 | Đỡ đòn 11, Đấu sĩ 1, Xạ thủ 1 | 15% | Đỡ đòn 7, Đấu sĩ 5, Xạ thủ 1 | 46% | CRABOMINABLE, DONDOZO, MAWILE, MUK, REGIDRAGO, RHYPERIOR … |
| ⚠ Ma | attack | 13 | Đỡ đòn 5, Xạ thủ 7, Pháp sư 1 | 54% | Đỡ đòn 2, Đấu sĩ 3, Xạ thủ 3, Pháp sư 3, Hỗ trợ 2 | 46% | ANNIHILAPE, DARKRAI, DRIFBLIM, LUNALA, POLTEAGEIST, ROTOM … |
| Cỏ | front | 16 | Đỡ đòn 8, Đấu sĩ 1, Xạ thủ 6, Pháp sư 1 | 56% | Đỡ đòn 1, Đấu sĩ 7, Xạ thủ 2, Pháp sư 3, Hỗ trợ 3 | 50% | ARBOLIVA, CRADILY, FLAPPLE, HYDRAPPLE, MEOWSCARADA, RILLABOOM … |
| ↑ Bóng tối | attack | 16 | Đỡ đòn 10, Đấu sĩ 4, Xạ thủ 1, Pháp sư 1 | 31% | Đỡ đòn 6, Đấu sĩ 7, Sát thủ 1, Pháp sư 2 | 50% | ABSOL, DARKRAI, GRENINJA, KINGAMBIT, MALAMAR, MEOWSCARADA … |
| Hóa thạch | front | 10 | Đỡ đòn 6, Xạ thủ 4 | 60% | Đỡ đòn 1, Đấu sĩ 4, Sát thủ 1, Xạ thủ 1, Pháp sư 2, Hỗ trợ 1 | 50% | CRADILY, FLUTTER_MANE, GOREBYSS, GREAT_TUSK, SIGILYPH |
| ↑ Âm thanh | ability | 8 | Đỡ đòn 4, Xạ thủ 3, Pháp sư 1 | 12% | Đỡ đòn 1, Sát thủ 1, Xạ thủ 2, Pháp sư 1, Hỗ trợ 3 | 50% | CHIMECHO, OBSTAGOON, POLITOED, WAILORD |
| ↑ Thép | damage | 17 | Đỡ đòn 11, Đấu sĩ 4, Xạ thủ 1, Pháp sư 1 | 35% | Đỡ đòn 6, Đấu sĩ 5, Sát thủ 3, Xạ thủ 1, Hỗ trợ 2 | 53% | ALOLAN_SANDSLASH, HISUI_GOODRA, KINGAMBIT, MAGEARNA, MAWILE, PROBOPASS … |
| Lửa | attack | 13 | Đấu sĩ 5, Xạ thủ 6, Pháp sư 2 | 85% | Đỡ đòn 1, Đấu sĩ 4, Xạ thủ 3, Pháp sư 3, Hỗ trợ 2 | 54% | CINDERACE, EMBOAR, HO_OH, ORICORIO_BAILE, SCOVILLAIN, SOLROCK |
| ↑ Tiên | attack | 16 | Đỡ đòn 7, Sát thủ 2, Xạ thủ 5, Pháp sư 1, Hỗ trợ 1 | 44% | Đỡ đòn 3, Đấu sĩ 1, Sát thủ 3, Xạ thủ 5, Hỗ trợ 4 | 56% | ALOLAN_NINETALES, BLISSEY, GALARIAN_RAPIDASH, GALARIAN_WEEZING, GRANBULL, MAGEARNA … |
| ↑ Điện | attack | 19 | Đỡ đòn 7, Đấu sĩ 2, Sát thủ 4, Xạ thủ 4, Pháp sư 2 | 53% | Đỡ đòn 2, Đấu sĩ 3, Sát thủ 7, Xạ thủ 1, Pháp sư 4, Hỗ trợ 2 | 58% | ALOLAN_GOLEM, AMPHAROS, BOLTUND, ELECTIVIRE, PROBOPASS, REGIELEKI … |
| Đá | front | 14 | Đỡ đòn 9, Đấu sĩ 2, Xạ thủ 3 | 79% | Đỡ đòn 6, Đấu sĩ 4, Pháp sư 1, Hỗ trợ 3 | 71% | NIHILEGO, PROBOPASS, SOLROCK, STAKATAKA |
| ↑ Nhân hình | damage | 10 | Đỡ đòn 3, Đấu sĩ 1, Xạ thủ 5, Pháp sư 1 | 70% | Đỡ đòn 1, Đấu sĩ 3, Xạ thủ 3, Pháp sư 3 | 90% | ELECTIVIRE |
| Giác đấu | front | 13 | Đỡ đòn 7, Đấu sĩ 6 | 100% | Đỡ đòn 6, Đấu sĩ 6, Sát thủ 1 | 92% | GREAT_TUSK |

### Không mùa (mọi Pokémon)

| Hệ | Focus | Họ | Vai trò hiện tại | Hợp | Vai trò gợi ý | Hợp | Không hưởng (gợi ý) |
|---|---|---|---|---|---|---|---|
| ⚠ Nước | ability | 62 | Đỡ đòn 31, Đấu sĩ 6, Sát thủ 2, Xạ thủ 18, Pháp sư 5 | 8% | Đỡ đòn 18, Đấu sĩ 16, Sát thủ 5, Xạ thủ 13, Pháp sư 7, Hỗ trợ 3 | 16% | AZUMARILL, BARBARACLE, BASCULEGION_FEMALE, BASCULEGION_MALE, BASCULIN_BLUE, BASCULIN_RED … |
| ⚠ Siêu linh | ability | 69 | Đỡ đòn 25, Đấu sĩ 5, Sát thủ 1, Xạ thủ 35, Pháp sư 3 | 4% | Đỡ đòn 13, Đấu sĩ 12, Sát thủ 5, Xạ thủ 22, Pháp sư 11, Hỗ trợ 6 | 25% | ALAKAZAM, ALOLAN_EXEGGUTOR, ALOLAN_RAICHU, AZELF, BEHEEYEM, BRONZONG … |
| ⚠ Âm thanh | ability | 35 | Đỡ đòn 14, Đấu sĩ 2, Xạ thủ 15, Pháp sư 4 | 11% | Đỡ đòn 6, Đấu sĩ 5, Sát thủ 2, Xạ thủ 9, Pháp sư 8, Hỗ trợ 5 | 37% | AUDINO, BRONZONG, CETITAN, CHIMECHO, CINCCINO, CROBAT … |
| ⚠ Bay | front | 69 | Đỡ đòn 24, Đấu sĩ 8, Sát thủ 3, Xạ thủ 26, Pháp sư 7, Hỗ trợ 1 | 46% | Đỡ đòn 11, Đấu sĩ 15, Sát thủ 10, Xạ thủ 15, Pháp sư 15, Hỗ trợ 3 | 38% | ARCHEOPS, ARTICUNO, BEAUTIFLY, BUTTERFREE, CHATOT, CORVIKNIGHT … |
| ⚠ Lửa | attack | 45 | Đỡ đòn 12, Đấu sĩ 7, Sát thủ 3, Xạ thủ 16, Pháp sư 7 | 58% | Đỡ đòn 7, Đấu sĩ 10, Sát thủ 4, Xạ thủ 5, Pháp sư 16, Hỗ trợ 3 | 42% | ALOLAN_MAROWAK, ARCANINE, ARMAROUGE, BLACEPHALON, CAMERUPT, CHI_YU … |
| ⚠ Băng | attack | 34 | Đỡ đòn 20, Đấu sĩ 3, Sát thủ 1, Xạ thủ 7, Pháp sư 3 | 32% | Đỡ đòn 13, Đấu sĩ 9, Sát thủ 2, Xạ thủ 5, Pháp sư 4, Hỗ trợ 1 | 47% | ALOLAN_NINETALES, ALOLAN_SANDSLASH, ARTICUNO, AURORUS, AVALUGG, CETITAN … |
| ⚠ Thép | damage | 47 | Đỡ đòn 32, Đấu sĩ 5, Xạ thủ 9, Pháp sư 1 | 32% | Đỡ đòn 21, Đấu sĩ 8, Sát thủ 6, Xạ thủ 3, Pháp sư 6, Hỗ trợ 3 | 49% | ALOLAN_SANDSLASH, BASTIODON, BRONZONG, CELESTEELA, COBALION, DHELMISE … |
| Điện | attack | 45 | Đỡ đòn 17, Đấu sĩ 5, Sát thủ 5, Xạ thủ 16, Pháp sư 2 | 58% | Đỡ đòn 8, Đấu sĩ 9, Sát thủ 9, Xạ thủ 5, Pháp sư 12, Hỗ trợ 2 | 51% | ALOLAN_GOLEM, AMPHAROS, ARCHALUDON, BOLTUND, DEDENNE, EELEKTROSS … |
| ↑ Ma | attack | 45 | Đỡ đòn 22, Đấu sĩ 3, Xạ thủ 16, Pháp sư 4 | 42% | Đỡ đòn 9, Đấu sĩ 12, Sát thủ 4, Xạ thủ 8, Pháp sư 10, Hỗ trợ 2 | 53% | ALOLAN_MAROWAK, ANNIHILAPE, BLACEPHALON, DARKRAI, DECIDUEYE, DHELMISE … |
| ↑ Quái vật | attack | 37 | Đỡ đòn 27, Đấu sĩ 4, Xạ thủ 6 | 27% | Đỡ đòn 16, Đấu sĩ 14, Sát thủ 1, Xạ thủ 5, Pháp sư 1 | 54% | AVALUGG, CRABOMINABLE, DONDOZO, HARIYAMA, KANGASKHAN, KROOKODILE … |
| ↑ Bóng tối | attack | 47 | Đỡ đòn 26, Đấu sĩ 12, Sát thủ 1, Xạ thủ 5, Pháp sư 3 | 38% | Đỡ đòn 15, Đấu sĩ 20, Sát thủ 4, Xạ thủ 2, Pháp sư 5, Hỗ trợ 1 | 55% | ABSOL, ALOLAN_MUK, ALOLAN_RATICATE, CHI_YU, CRAWDAUNT, DARKRAI … |
| ↑ Độc | attack | 46 | Đỡ đòn 25, Đấu sĩ 7, Sát thủ 2, Xạ thủ 7, Pháp sư 5 | 35% | Đỡ đòn 12, Đấu sĩ 16, Sát thủ 4, Xạ thủ 6, Pháp sư 5, Hỗ trợ 3 | 57% | ALOLAN_MUK, CLODSIRE, DRAGALGE, ETERNATUS, GALARIAN_SLOWBRO, GALARIAN_SLOWKING … |
| Cỏ | front | 51 | Đỡ đòn 28, Đấu sĩ 5, Xạ thủ 14, Pháp sư 4 | 65% | Đỡ đòn 12, Đấu sĩ 18, Sát thủ 1, Xạ thủ 7, Pháp sư 8, Hỗ trợ 5 | 59% | ARBOLIVA, CARNIVINE, CELEBI, CRADILY, DECIDUEYE, FLAPPLE … |
| Thường | front | 67 | Đỡ đòn 34, Đấu sĩ 14, Sát thủ 2, Xạ thủ 13, Pháp sư 2, Hỗ trợ 2 | 72% | Đỡ đòn 21, Đấu sĩ 21, Sát thủ 6, Xạ thủ 7, Pháp sư 5, Hỗ trợ 7 | 63% | ARBOLIVA, AUDINO, BEAUTIFLY, BLISSEY, CYCLIZAR, DODRIO … |
| ↑ Tiên | attack | 62 | Đỡ đòn 18, Đấu sĩ 3, Sát thủ 2, Xạ thủ 30, Pháp sư 2, Hỗ trợ 7 | 56% | Đỡ đòn 11, Đấu sĩ 6, Sát thủ 4, Xạ thủ 29, Pháp sư 6, Hỗ trợ 6 | 63% | ALOLAN_NINETALES, ALTARIA, BLISSEY, CRESSELIA, DEDENNE, DIANCIE … |
| Hóa thạch | front | 33 | Đỡ đòn 21, Đấu sĩ 3, Xạ thủ 9 | 73% | Đỡ đòn 11, Đấu sĩ 10, Sát thủ 2, Xạ thủ 5, Pháp sư 3, Hỗ trợ 2 | 64% | ARCHEOPS, BASTIODON, CRADILY, FLUTTER_MANE, GOREBYSS, GREAT_TUSK … |
| ↑ Hoang dã | attack | 37 | Đỡ đòn 21, Đấu sĩ 11, Sát thủ 4, Pháp sư 1 | 41% | Đỡ đòn 13, Đấu sĩ 16, Sát thủ 7, Xạ thủ 1 | 65% | ABSOL, ALOLAN_RATICATE, ANNIHILAPE, BRAVIARY, DONPHAN, EMBOAR … |
| Đá | front | 39 | Đỡ đòn 25, Đấu sĩ 4, Sát thủ 1, Xạ thủ 7, Pháp sư 1, Hỗ trợ 1 | 74% | Đỡ đòn 18, Đấu sĩ 9, Sát thủ 1, Xạ thủ 3, Pháp sư 2, Hỗ trợ 6 | 69% | ARCHEOPS, BASTIODON, GIGALITH, LUNATONE, LYCANROC_DAY, MAGCARGO … |
| ↑ Nhân hình | damage | 38 | Đỡ đòn 19, Đấu sĩ 2, Xạ thủ 13, Pháp sư 4 | 50% | Đỡ đòn 9, Đấu sĩ 11, Sát thủ 1, Xạ thủ 8, Pháp sư 8, Hỗ trợ 1 | 74% | ELECTIVIRE, HISUIAN_LILLIGANT, HITMONCHAN, HITMONTOP, LILIGANT, MACHAMP … |
| Giác đấu | front | 54 | Đỡ đòn 39, Đấu sĩ 10, Sát thủ 1, Xạ thủ 4 | 91% | Đỡ đòn 21, Đấu sĩ 22, Sát thủ 6, Xạ thủ 3, Pháp sư 1, Hỗ trợ 1 | 80% | GREAT_TUSK, HAWLUCHA, IRON_VALIANT, KOMMO_O, LUCARIO, MARSHADOW … |

## Đổi vai trò (theo họ, dạng cuối)

Số: skill = phần sát thương từ skill trong trận 16 s ước lượng; tầm = ô xa nhất skill còn trúng; cuối = sát thương skill khi đứng hàng cuối so với hàng đầu; trúng = số địch trúng (hàng đầu / hàng cuối); bulk = xếp hạng độ trâu trong cùng độ hiếm × sao.

| Dạng cuối (họ) | Độ hiếm | Hiện tại | Gợi ý | Skill | Tầm | Cuối | Trúng | Tầm web | Bulk | Lý do |
|---|---|---|---|---|---|---|---|---|---|---|
| STARAPTOR (STARLY) | COMMON | Đấu sĩ | **Sát thủ** | 38% | 7 | 100% | 1 / 1 | 1 | 56% | đòn đánh = 62% sát thương, skill lao vào địch 3 ô |
| UNFEZANT (PIDOVE) | COMMON | Đấu sĩ | **Sát thủ** | 0% | 0 | 0% | 0 / 0 | 1 | 26% | đòn đánh = 100% sát thương, skill lao vào địch 3 ô |
| DODRIO (DODUO) | EPIC | Đỡ đòn | **Sát thủ** | 28% | 7 | 100% | 1 / 1 | 1 | 31% | đòn đánh = 72% sát thương, skill lao vào địch 3 ô |
| GLISCOR (GLIGAR) | EPIC | Đỡ đòn | **Sát thủ** | 48% | 7 | 100% | 1 / 1 | 1 | 29% | đòn đánh = 52% sát thương, skill lao vào địch 3 ô |
| GOGOAT (SKIDDO) | EPIC | Đỡ đòn | **Sát thủ** | 22% | 6 | 100% | 2 / 2 | 1 | 96% | đòn đánh = 78% sát thương, skill lao vào địch 3 ô |
| GOLISOPOD (WIMPOD) | EPIC | Đỡ đòn | **Sát thủ** | 38% | 7 | 100% | 1 / 1 | 1 | 43% | đòn đánh = 62% sát thương, skill lao vào địch 3 ô |
| MUDSDALE (MUDBRAY) | EPIC | Đỡ đòn | **Sát thủ** | 46% | 6 | 100% | 2 / 1 | 1 | 77% | đòn đánh = 54% sát thương, skill lao vào địch 3 ô |
| WAILORD (WAILMER) | EPIC | Đỡ đòn | **Sát thủ** | 49% | 7 | 100% | 4 / 4 | 1 | 99% | đòn đánh = 51% sát thương, skill lao vào địch 3 ô |
| GIRATINA | LEGENDARY | Đỡ đòn | **Sát thủ** | 60% | 7 | 100% | 4 / 4 | 1 | 44% | đòn đánh = 40% sát thương, skill lao vào địch 3 ô |
| IRON_VALIANT | LEGENDARY | Đỡ đòn | **Sát thủ** | 53% | 1 | 25% | 4 / 1 | 1 | 24% | đòn đánh = 47% sát thương, skill lao vào địch 3 ô |
| LUGIA | LEGENDARY | Đỡ đòn | **Sát thủ** | 43% | 7 | 100% | 1 / 1 | 1 | 76% | đòn đánh = 57% sát thương, skill lao vào địch 3 ô |
| MARSHADOW | LEGENDARY | Đỡ đòn | **Sát thủ** | 18% | 7 | 100% | 1 / 1 | 1 | 12% | đòn đánh = 82% sát thương, skill lao vào địch 3 ô |
| PHEROMOSA | LEGENDARY | Đỡ đòn | **Sát thủ** | 22% | 7 | 100% | 1 / 1 | 1 | 12% | đòn đánh = 78% sát thương, skill lao vào địch 3 ô |
| PIROUETTE_MELOETTA (MELOETTA) | LEGENDARY | Đỡ đòn | **Sát thủ** | 0% | 7 | 0% | 0 / 0 | 1 | 32% | đòn đánh = 100% sát thương, skill lao vào địch 3 ô |
| SHADOW_LUGIA (LUGIA) | LEGENDARY | Đỡ đòn | **Sát thủ** | 43% | 7 | 100% | 1 / 1 | 1 | 76% | đòn đánh = 57% sát thương, skill lao vào địch 3 ô |
| SOLGALEO (COSMOG) | LEGENDARY | Đỡ đòn | **Sát thủ** | 60% | 7 | 100% | 4 / 4 | 1 | 62% | đòn đánh = 40% sát thương, skill lao vào địch 3 ô |
| ZACIAN_CROWNED (ZACIAN) | LEGENDARY | Đỡ đòn | **Sát thủ** | 45% | 7 | 100% | 1 / 1 | 1 | 29% | đòn đánh = 55% sát thương, skill lao vào địch 3 ô |
| AEGISLASH (HONEDGE) | RARE | Đỡ đòn | **Sát thủ** | 0% | 0 | 0% | 0 / 0 | 1 | 44% | đòn đánh = 100% sát thương, skill lao vào địch 3 ô |
| AEGISLASH_BLADE (HONEDGE) | RARE | Đỡ đòn | **Sát thủ** | 0% | 0 | 0% | 0 / 0 | 1 | 6% | đòn đánh = 100% sát thương, skill lao vào địch 3 ô |
| BELLIBOLT (TADBULB) | RARE | Đỡ đòn | **Sát thủ** | 52% | 7 | 100% | 4 / 4 | 1 | 79% | đòn đánh = 48% sát thương, skill lao vào địch 3 ô |
| CORVIKNIGHT (ROOKIDEE) | RARE | Đỡ đòn | **Sát thủ** | 45% | 7 | 100% | 2 / 2 | 1 | 94% | đòn đánh = 55% sát thương, skill lao vào địch 3 ô |
| GOLURK (GOLETT) | RARE | Đỡ đòn | **Sát thủ** | 0% | 0 | 0% | 0 / 0 | 1 | 53% | đòn đánh = 100% sát thương, skill lao vào địch 3 ô |
| GRUMPIG (SPOINK) | RARE | Đỡ đòn | **Sát thủ** | 37% | 7 | 100% | 2 / 2 | 1 | 100% | đòn đánh = 63% sát thương, skill lao vào địch 3 ô |
| LOKIX (NYMBLE) | RARE | Đấu sĩ | **Sát thủ** | 26% | 7 | 100% | 1 / 1 | 1 | 35% | đòn đánh = 74% sát thương, skill lao vào địch 3 ô |
| MANDIBUZZ (VULLABY) | RARE | Đỡ đòn | **Sát thủ** | 21% | 7 | 100% | 1 / 1 | 1 | 92% | đòn đánh = 79% sát thương, skill lao vào địch 3 ô |
| PIKACHU_SURFER (PICHU) | SPECIAL | Đấu sĩ | **Sát thủ** | 79% | 7 | 67% | 2 / 2 | 1 | 18% | đòn đánh = 21% sát thương, skill lao vào địch 3 ô |
| ALOLAN_DUGTRIO (ALOLAN_DIGLETT) | UNCOMMON | Đấu sĩ | **Sát thủ** | 43% | 7 | 100% | 2 / 2 | 1 | 41% | đòn đánh = 57% sát thương, skill lao vào địch 3 ô |
| DUGTRIO (DIGLETT) | UNCOMMON | Đỡ đòn | **Sát thủ** | 50% | 7 | 100% | 2 / 2 | 1 | 89% | đòn đánh = 50% sát thương, skill lao vào địch 3 ô |
| WUGTRIO (WIGLETT) | UNCOMMON | Đỡ đòn | **Sát thủ** | 49% | 7 | 100% | 3 / 3 | 1 | 88% | đòn đánh = 51% sát thương, skill lao vào địch 3 ô |
| GREAT_TUSK | UNIQUE | Đỡ đòn | **Sát thủ** | 41% | 7 | 100% | 2 / 2 | 1 | 32% | đòn đánh = 59% sát thương, skill lao vào địch 3 ô |
| HAWLUCHA | UNIQUE | Đỡ đòn | **Sát thủ** | 40% | 7 | 100% | 1 / 1 | 1 | 33% | đòn đánh = 60% sát thương, skill lao vào địch 3 ô |
| LAPRAS | UNIQUE | Đỡ đòn | **Sát thủ** | 59% | 7 | 100% | 4 / 4 | 1 | 89% | đòn đánh = 41% sát thương, skill lao vào địch 3 ô |
| MINUN | UNIQUE | Đỡ đòn | **Sát thủ** | 39% | 7 | 100% | 1 / 1 | 1 | 4% | đòn đánh = 61% sát thương, skill lao vào địch 3 ô |
| OVERQWIL (HISUIAN_QWILFISH) | UNIQUE | Đỡ đòn | **Sát thủ** | 82% | 7 | 50% | 4 / 2 | 1 | 90% | đòn đánh = 18% sát thương, skill lao vào địch 3 ô |
| PLUSLE | UNIQUE | Đỡ đòn | **Sát thủ** | 39% | 7 | 100% | 1 / 1 | 1 | 4% | đòn đánh = 61% sát thương, skill lao vào địch 3 ô |
| SLITHER_WING | UNIQUE | Đỡ đòn | **Sát thủ** | 28% | 7 | 100% | 1 / 1 | 1 | 30% | đòn đánh = 72% sát thương, skill lao vào địch 3 ô |
| TOGEDEMARU | UNIQUE | Đỡ đòn | **Sát thủ** | 44% | 7 | 100% | 1 / 1 | 1 | 82% | đòn đánh = 56% sát thương, skill lao vào địch 3 ô |
| TORKOAL | UNIQUE | Đỡ đòn | **Sát thủ** | 54% | 7 | 100% | 4 / 4 | 1 | 82% | đòn đánh = 46% sát thương, skill lao vào địch 3 ô |
| WYRDEER (STANTLER) | UNIQUE | Đỡ đòn | **Sát thủ** | 43% | 7 | 100% | 2 / 2 | 1 | 60% | đòn đánh = 57% sát thương, skill lao vào địch 3 ô |
| PIDGEOT (PIDGEY) | COMMON | Xạ thủ | **Pháp sư** | 62% | 7 | 50% | 2 / 1 | 2 | 47% | skill = 62% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| ALTARIA (SWABLU) | EPIC | Xạ thủ | **Pháp sư** | 68% | 7 | 100% | 5 / 5 | 2 | 17% | skill = 68% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| HELIOLISK (HELIOPTILE) | EPIC | Xạ thủ | **Pháp sư** | 49% | 7 | 100% | 1 / 1 | 3 | 11% | skill = 49% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| KILOWATTREL (WATTREL) | EPIC | Xạ thủ | **Pháp sư** | 52% | 7 | 100% | 3 / 2 | 2 | 37% | skill = 52% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| MISMAGIUS (MISDREAVUS) | EPIC | Xạ thủ | **Pháp sư** | 70% | 7 | 100% | 1 / 1 | 3 | 6% | skill = 70% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| CINDERACE (SCORBUNNY) | HATCH | Xạ thủ | **Pháp sư** | 76% | 7 | 100% | 2 / 2 | 2 | 81% | skill = 76% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| DECIDUEYE (ROWLET) | HATCH | Xạ thủ | **Pháp sư** | 52% | 7 | 50% | 2 / 1 | 3 | 69% | skill = 52% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| GOTHITELLE (GOTHITA) | HATCH | Xạ thủ | **Pháp sư** | 47% | 7 | 100% | 7 / 7 | 3 | 78% | skill = 47% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| PRIMARINA (POPPLIO) | HATCH | Xạ thủ | **Pháp sư** | 63% | 7 | 50% | 4 / 2 | 3 | 69% | skill = 63% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| BLACEPHALON | LEGENDARY | Xạ thủ | **Pháp sư** | 52% | 7 | 100% | 7 / 7 | 3 | 3% | skill = 52% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| CHI_YU | LEGENDARY | Xạ thủ | **Pháp sư** | 59% | 7 | 50% | 4 / 2 | 2 | 5% | skill = 59% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| DARKRAI | LEGENDARY | Xạ thủ | **Pháp sư** | 50% | 7 | 100% | 7 / 7 | 2 | 12% | skill = 50% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| DEOXYS_SPEED (DEOXYS) | LEGENDARY | Xạ thủ | **Pháp sư** | 54% | 7 | 100% | 2 / 2 | 2 | 18% | skill = 54% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| ENAMORUS | LEGENDARY | Xạ thủ | **Pháp sư** | 52% | 7 | 50% | 2 / 1 | 3 | 18% | skill = 52% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| HEATRAN | LEGENDARY | Xạ thủ | **Pháp sư** | 67% | 7 | 100% | 5 / 5 | 2 | 49% | skill = 67% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| HO_OH | LEGENDARY | Xạ thủ | **Pháp sư** | 66% | 7 | 50% | 4 / 2 | 2 | 40% | skill = 66% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| JIRACHI | LEGENDARY | Xạ thủ | **Pháp sư** | 48% | 7 | 100% | 1 / 1 | 3 | 20% | skill = 48% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| KYUREM | LEGENDARY | Xạ thủ | **Pháp sư** | 49% | 7 | 50% | 4 / 2 | 3 | 7% | skill = 49% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| LANDORUS | LEGENDARY | Xạ thủ | **Pháp sư** | 61% | 7 | 50% | 2 / 1 | 3 | 18% | skill = 61% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| LUNALA (COSMOG) | LEGENDARY | Xạ thủ | **Pháp sư** | 49% | 7 | 50% | 2 / 1 | 4 | 40% | skill = 49% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| MEGA_RAYQUAZA (RAYQUAZA) | LEGENDARY | Xạ thủ | **Pháp sư** | 70% | 7 | 50% | 4 / 2 | 2 | 100% | skill = 70% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| NIHILEGO | LEGENDARY | Xạ thủ | **Pháp sư** | 55% | 7 | 167% | 3 / 5 | 3 | 2% | skill = 55% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 167%) |
| PECHARUNT | LEGENDARY | Xạ thủ | **Pháp sư** | 56% | 7 | 100% | 0 / 0 | 3 | 29% | skill = 56% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| PRIMAL_KYOGRE (KYOGRE) | LEGENDARY | Xạ thủ | **Pháp sư** | 81% | 7 | 100% | 5 / 5 | 3 | 57% | skill = 81% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| RESHIRAM | LEGENDARY | Xạ thủ | **Pháp sư** | 48% | 7 | 50% | 4 / 2 | 3 | 7% | skill = 48% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| ROARING_MOON | LEGENDARY | Xạ thủ | **Pháp sư** | 52% | 7 | 41% | 4 / 3 | 3 | 4% | skill = 52% sát thương, nhưng skill TẠI CHỖ (tầm 7 ô, từ hàng cuối còn 41%): nên sửa thành skill tung |
| SHAYMIN_SKY (SHAYMIN) | LEGENDARY | Xạ thủ | **Pháp sư** | 52% | 5 | 100% | 7 / 7 | 3 | 14% | skill = 52% sát thương, tung được từ hàng cuối (tầm 5 ô, từ hàng cuối còn 100%) |
| THUNDURUS | LEGENDARY | Xạ thủ | **Pháp sư** | 49% | 7 | 50% | 2 / 1 | 3 | 18% | skill = 49% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| TORNADUS | LEGENDARY | Xạ thủ | **Pháp sư** | 49% | 7 | 50% | 2 / 1 | 3 | 18% | skill = 49% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| ULTRA_NECROZMA (NECROZMA) | LEGENDARY | Xạ thủ | **Pháp sư** | 57% | 7 | 60% | 5 / 3 | 3 | 43% | skill = 57% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 60%) |
| VOLCANION | LEGENDARY | Xạ thủ | **Pháp sư** | 82% | 7 | 50% | 4 / 2 | 2 | 47% | skill = 82% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| XURKITREE | LEGENDARY | Xạ thủ | **Pháp sư** | 61% | 7 | 100% | 3 / 3 | 2 | 2% | skill = 61% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| ZAPDOS | LEGENDARY | Xạ thủ | **Pháp sư** | 56% | 7 | 100% | 3 / 3 | 2 | 40% | skill = 56% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| ZEKROM | LEGENDARY | Xạ thủ | **Pháp sư** | 48% | 7 | 50% | 4 / 2 | 3 | 7% | skill = 48% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| ZYGARDE_50 (ZYGARDE_10) | LEGENDARY | Xạ thủ | **Pháp sư** | 63% | 0 | 100% | 4 / 4 | 3 | 4% | skill = 63% sát thương, nhưng skill TẠI CHỖ (tầm 0 ô, từ hàng cuối còn 100%): nên sửa thành skill tung |
| CLAWITZER (CLAUNCHER) | RARE | Xạ thủ | **Pháp sư** | 67% | 7 | 50% | 4 / 2 | 4 | 15% | skill = 67% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| CRADILY (LILEEP) | RARE | Xạ thủ | **Pháp sư** | 60% | 7 | 100% | 0 / 0 | 2 | 19% | skill = 60% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| LUCARIO (RIOLU) | RARE | Xạ thủ | **Pháp sư** | 48% | 7 | 50% | 2 / 1 | 2 | 41% | skill = 48% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| NINETALES (VULPIX) | RARE | Xạ thủ | **Pháp sư** | 83% | 7 | 50% | 4 / 2 | 2 | 41% | skill = 83% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| SUNFLORA (SUNKERN) | RARE | Xạ thủ | **Pháp sư** | 72% | 7 | 50% | 2 / 1 | 2 | 44% | skill = 72% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| DRAGALGE (SKRELP) | UNCOMMON | Xạ thủ | **Pháp sư** | 81% | 7 | 50% | 4 / 2 | 3 | 11% | skill = 81% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| HISUIAN_TYPHLOSION (CYNDAQUIL) | UNCOMMON | Xạ thủ | **Pháp sư** | 58% | 7 | 100% | 2 / 2 | 2 | 22% | skill = 58% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| MAGNEZONE (MAGNEMITE) | UNCOMMON | Xạ thủ | **Pháp sư** | 57% | 7 | 60% | 4 / 2 | 2 | 30% | skill = 57% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 60%) |
| ARCHALUDON (DURALUDON) | UNIQUE | Xạ thủ | **Pháp sư** | 68% | 7 | 50% | 2 / 1 | 2 | 73% | skill = 68% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| ARMAROUGE (CHARCADET) | UNIQUE | Xạ thủ | **Pháp sư** | 62% | 7 | 100% | 3 / 3 | 2 | 60% | skill = 62% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| CHATOT | UNIQUE | Xạ thủ | **Pháp sư** | 66% | 3 | 0% | 7 / 0 | 2 | 28% | skill = 66% sát thương, nhưng skill TẠI CHỖ (tầm 3 ô, từ hàng cuối còn 0%): nên sửa thành skill tung |
| DRAMPA | UNIQUE | Xạ thủ | **Pháp sư** | 82% | 7 | 36% | 7 / 4 | 3 | 94% | skill = 82% sát thương, nhưng skill TẠI CHỖ (tầm 7 ô, từ hàng cuối còn 36%): nên sửa thành skill tung |
| FLAPPLE (APPLIN) | UNIQUE | Xạ thủ | **Pháp sư** | 59% | 7 | 100% | 1 / 1 | 3 | 11% | skill = 59% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| KLEFKI | UNIQUE | Xạ thủ | **Pháp sư** | 47% | 7 | 98% | 4 / 2 | 3 | 7% | skill = 47% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 98%) |
| LATIAS | UNIQUE | Xạ thủ | **Pháp sư** | 63% | 7 | 50% | 2 / 1 | 3 | 1% | skill = 63% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| LATIOS | UNIQUE | Xạ thủ | **Pháp sư** | 63% | 7 | 50% | 2 / 1 | 3 | 1% | skill = 63% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 50%) |
| ORICORIO_BAILE | UNIQUE | Xạ thủ | **Pháp sư** | 46% | 1 | 0% | 2 / 0 | 2 | 22% | skill = 46% sát thương, nhưng skill TẠI CHỖ (tầm 1 ô, từ hàng cuối còn 0%): nên sửa thành skill tung |
| ROTOM | UNIQUE | Xạ thủ | **Pháp sư** | 74% | 7 | 67% | 3 / 2 | 3 | 43% | skill = 74% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 67%) |
| ROTOM_DRONE (ROTOM) | UNIQUE | Xạ thủ | **Pháp sư** | 55% | 7 | 100% | 1 / 1 | 2 | 26% | skill = 55% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| ROTOM_FAN (ROTOM) | UNIQUE | Xạ thủ | **Pháp sư** | 69% | 7 | 100% | 5 / 4 | 3 | 43% | skill = 69% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| ROTOM_FROST (ROTOM) | UNIQUE | Xạ thủ | **Pháp sư** | 49% | 7 | 100% | 1 / 1 | 2 | 35% | skill = 49% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| ROTOM_WASH (ROTOM) | UNIQUE | Xạ thủ | **Pháp sư** | 63% | 7 | 100% | 5 / 5 | 2 | 26% | skill = 63% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| SIGILYPH | UNIQUE | Xạ thủ | **Pháp sư** | 52% | 7 | 100% | 2 / 2 | 3 | 43% | skill = 52% sát thương, tung được từ hàng cuối (tầm 7 ô, từ hàng cuối còn 100%) |
| ABOMASNOW (SNOVER) | EPIC | Đỡ đòn | **Đấu sĩ** | 35% | 7 | 100% | 1 / 1 | 1 | 39% | đòn đánh = 65% sát thương, cận chiến |
| BANETTE (SHUPPET) | EPIC | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 23% | đòn đánh = 100% sát thương, cận chiến |
| BEARTIC (CUBCHOO) | EPIC | Đỡ đòn | **Đấu sĩ** | 52% | 2 | 0% | 3 / 0 | 1 | 46% | đòn đánh = 48% sát thương, cận chiến |
| CURSOLA (CORSOLA) | EPIC | Đỡ đòn | **Đấu sĩ** | 0% | 7 | 0% | 0 / 0 | 1 | 55% | đòn đánh = 100% sát thương, cận chiến |
| DRAPION (SKORUPI) | EPIC | Đỡ đòn | **Đấu sĩ** | 78% | 7 | 100% | 0 / 0 | 1 | 25% | đòn đánh = 22% sát thương, cận chiến |
| FARIGIRAF (GIRAFARIG) | EPIC | Đỡ đòn | **Đấu sĩ** | 57% | 7 | 75% | 4 / 3 | 1 | 42% | đòn đánh = 43% sát thương, cận chiến |
| GALLADE (RALTS) | EPIC | Đỡ đòn | **Đấu sĩ** | 46% | 7 | 50% | 2 / 1 | 1 | 38% | đòn đánh = 54% sát thương, cận chiến |
| GARCHOMP (GIBLE) | EPIC | Đỡ đòn | **Đấu sĩ** | 48% | 7 | 50% | 2 / 1 | 1 | 19% | đòn đánh = 52% sát thương, cận chiến |
| GOURGEIST (PUMPKABOO) | EPIC | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 57% | đòn đánh = 100% sát thương, cận chiến |
| HISUI_SAMUROTT (OSHAWOTT) | EPIC | Đỡ đòn | **Đấu sĩ** | 37% | 1 | 0% | 2 / 0 | 1 | 48% | đòn đánh = 63% sát thương, cận chiến |
| HOUNDOOM (HOUNDOUR) | EPIC | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 46% | đòn đánh = 100% sát thương, cận chiến |
| HUNTAIL (CLAMPERL) | EPIC | Đỡ đòn | **Đấu sĩ** | 32% | 7 | 100% | 1 / 1 | 1 | 5% | đòn đánh = 68% sát thương, cận chiến |
| NINJASK (NINCADA) | EPIC | Đỡ đòn | **Đấu sĩ** | 31% | 7 | 100% | 1 / 1 | 1 | 9% | đòn đánh = 69% sát thương, cận chiến |
| SNEASLER (HISUI_SNEASEL) | EPIC | Đỡ đòn | **Đấu sĩ** | 32% | 7 | 100% | 1 / 1 | 1 | 27% | đòn đánh = 68% sát thương, cận chiến |
| TSAREENA (BOUNSWEET) | EPIC | Đỡ đòn | **Đấu sĩ** | 47% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 53% sát thương, cận chiến |
| WEAVILE (SNEASEL) | EPIC | Đỡ đòn | **Đấu sĩ** | 35% | 7 | 100% | 1 / 1 | 1 | 27% | đòn đánh = 65% sát thương, cận chiến |
| ARCEUS | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_BUG (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_DARK (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_DRAGON (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_ELECTRIC (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_FAIRY (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_FIGHTING (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_FIRE (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_FLYING (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_GHOST (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_GRASS (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_GROUND (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_ICE (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_POISON (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_PSYCHIC (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_ROCK (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_STEEL (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| ARCEUS_WATER (ARCEUS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 1% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 99% sát thương, cận chiến |
| BUZZWOLE | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 35% | đòn đánh = 100% sát thương, cận chiến |
| DEOXYS | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 72% | 7 | 70% | 3 / 2 | 1 | 32% | đòn đánh = 28% sát thương, cận chiến |
| DEOXYS_DEFENSE (DEOXYS) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 62% | đòn đánh = 100% sát thương, cận chiến |
| DIALGA | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 62% | đòn đánh = 100% sát thương, cận chiến |
| FEZANDIPITI | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 0% | 3 | 0% | 0 / 0 | 1 | 44% | đòn đánh = 100% sát thương, cận chiến |
| GUZZLORD | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 46% | 7 | 100% | 1 / 1 | 1 | 62% | đòn đánh = 54% sát thương, cận chiến |
| KARTANA | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 37% | 7 | 100% | 1 / 1 | 1 | 15% | đòn đánh = 63% sát thương, cận chiến |
| KELDEO | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 49% | 7 | 100% | 1 / 1 | 1 | 49% | đòn đánh = 51% sát thương, cận chiến |
| MUNKIDORI | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 0% | 7 | 0% | 0 / 0 | 1 | 36% | đòn đánh = 100% sát thương, cận chiến |
| NAGANADEL (POIPOLE) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 41% | 7 | 100% | 1 / 1 | 1 | 29% | đòn đánh = 59% sát thương, cận chiến |
| NECROZMA | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 53% | 7 | 60% | 5 / 3 | 1 | 62% | đòn đánh = 47% sát thương, cận chiến |
| OGERPON_CORNERSTONE (OGERPON_TEAL) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 32% | 7 | 100% | 1 / 1 | 1 | 24% | đòn đánh = 68% sát thương, cận chiến |
| OGERPON_CORNERSTONE_MASK (OGERPON_TEAL) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 32% | 7 | 100% | 1 / 1 | 1 | 24% | đòn đánh = 68% sát thương, cận chiến |
| OGERPON_HEARTHFLAME (OGERPON_TEAL) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 72% | 7 | 18% | 2 / 1 | 1 | 24% | đòn đánh = 28% sát thương, cận chiến |
| OGERPON_HEARTHFLAME_MASK (OGERPON_TEAL) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 72% | 7 | 18% | 2 / 1 | 1 | 24% | đòn đánh = 28% sát thương, cận chiến |
| OGERPON_TEAL | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 32% | 7 | 100% | 1 / 1 | 1 | 24% | đòn đánh = 68% sát thương, cận chiến |
| OGERPON_TEAL_MASK (OGERPON_TEAL) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 32% | 7 | 100% | 1 / 1 | 1 | 24% | đòn đánh = 68% sát thương, cận chiến |
| OKIDOGI | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 32% | đòn đánh = 100% sát thương, cận chiến |
| ORIGIN_GIRATINA (GIRATINA) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 42% | 1 | 0% | 2 / 0 | 1 | 44% | đòn đánh = 58% sát thương, cận chiến |
| PALKIA | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 70% | 7 | 100% | 5 / 5 | 1 | 62% | đòn đánh = 30% sát thương, cận chiến |
| TERRAKION | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 22% | 7 | 100% | 1 / 1 | 1 | 49% | đòn đánh = 78% sát thương, cận chiến |
| URSHIFU_RAPID (KUBFU) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 44% | 7 | 100% | 1 / 1 | 1 | 36% | đòn đánh = 56% sát thương, cận chiến |
| URSHIFU_SINGLE (KUBFU) | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 38% | 7 | 100% | 1 / 1 | 1 | 36% | đòn đánh = 62% sát thương, cận chiến |
| VICTINI | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 81% | 2 | 0% | 6 / 0 | 1 | 62% | đòn đánh = 19% sát thương, cận chiến |
| ZYGARDE_10 | LEGENDARY | Đỡ đòn | **Đấu sĩ** | 56% | 7 | 50% | 4 / 2 | 1 | 24% | đòn đánh = 44% sát thương, cận chiến |
| ALOLAN_PERSIAN (ALOLAN_MEOWTH) | RARE | Đỡ đòn | **Đấu sĩ** | 34% | 7 | 100% | 1 / 1 | 1 | 63% | đòn đánh = 66% sát thương, cận chiến |
| BLAZIKEN (TORCHIC) | RARE | Đỡ đòn | **Đấu sĩ** | 49% | 7 | 100% | 1 / 1 | 1 | 56% | đòn đánh = 51% sát thương, cận chiến |
| CACTURNE (CACNEA) | RARE | Đỡ đòn | **Đấu sĩ** | 43% | 1 | 0% | 2 / 0 | 1 | 53% | đòn đánh = 57% sát thương, cận chiến |
| COFAGRIGUS (YAMASK) | RARE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 44% | đòn đánh = 100% sát thương, cận chiến |
| DACHSBUN (FIDOUGH) | RARE | Đỡ đòn | **Đấu sĩ** | 0% | 1 | 0% | 0 / 0 | 1 | 64% | đòn đánh = 100% sát thương, cận chiến |
| DREDNAW (CHEWTLE) | RARE | Đỡ đòn | **Đấu sĩ** | 38% | 7 | 100% | 1 / 1 | 1 | 53% | đòn đánh = 62% sát thương, cận chiến |
| EXCADRILL (DRILBUR) | RARE | Đỡ đòn | **Đấu sĩ** | 17% | 7 | 100% | 1 / 1 | 1 | 53% | đòn đánh = 83% sát thương, cận chiến |
| GALVANTULA (JOLTIK) | RARE | Đỡ đòn | **Đấu sĩ** | 31% | 1 | 0% | 2 / 0 | 1 | 53% | đòn đánh = 69% sát thương, cận chiến |
| LOPUNNY (BUNEARY) | RARE | Đỡ đòn | **Đấu sĩ** | 25% | 7 | 100% | 1 / 1 | 1 | 11% | đòn đánh = 75% sát thương, cận chiến |
| LURANTIS (FOMANTIS) | RARE | Đỡ đòn | **Đấu sĩ** | 47% | 1 | 0% | 2 / 0 | 1 | 47% | đòn đánh = 53% sát thương, cận chiến |
| MANECTRIC (ELECTRIKE) | RARE | Đỡ đòn | **Đấu sĩ** | 35% | 7 | 100% | 1 / 1 | 1 | 34% | đòn đánh = 65% sát thương, cận chiến |
| MIENSHAO (MIENFOO) | RARE | Đỡ đòn | **Đấu sĩ** | 32% | 7 | 100% | 1 / 1 | 1 | 46% | đòn đánh = 68% sát thương, cận chiến |
| PARASECT (PARAS) | RARE | Đỡ đòn | **Đấu sĩ** | 29% | 7 | 100% | 1 / 1 | 1 | 38% | đòn đánh = 71% sát thương, cận chiến |
| PAWMOT (PAWMI) | RARE | Đỡ đòn | **Đấu sĩ** | 45% | 7 | 100% | 1 / 1 | 1 | 56% | đòn đánh = 55% sát thương, cận chiến |
| PERSIAN (MEOWTH) | RARE | Đỡ đòn | **Đấu sĩ** | 37% | 7 | 100% | 1 / 1 | 1 | 63% | đòn đánh = 63% sát thương, cận chiến |
| SAWSBUCK_AUTUMN (DEERLING_AUTUMN) | RARE | Đỡ đòn | **Đấu sĩ** | 20% | 7 | 100% | 1 / 1 | 1 | 53% | đòn đánh = 80% sát thương, cận chiến |
| SAWSBUCK_SPRING (DEERLING_SPRING) | RARE | Đỡ đòn | **Đấu sĩ** | 20% | 7 | 100% | 1 / 1 | 1 | 53% | đòn đánh = 80% sát thương, cận chiến |
| SAWSBUCK_SUMMER (DEERLING_SUMMER) | RARE | Đỡ đòn | **Đấu sĩ** | 20% | 7 | 100% | 1 / 1 | 1 | 53% | đòn đánh = 80% sát thương, cận chiến |
| SAWSBUCK_WINTER (DEERLING_WINTER) | RARE | Đỡ đòn | **Đấu sĩ** | 20% | 7 | 100% | 1 / 1 | 1 | 53% | đòn đánh = 80% sát thương, cận chiến |
| SWELLOW (TAILLOW) | RARE | Đỡ đòn | **Đấu sĩ** | 33% | 7 | 100% | 1 / 1 | 1 | 60% | đòn đánh = 67% sát thương, cận chiến |
| TOXAPEX (MAREANIE) | RARE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 44% | đòn đánh = 100% sát thương, cận chiến |
| TOXTRICITY (TOXEL) | RARE | Đỡ đòn | **Đấu sĩ** | 47% | 0 | 37% | 6 / 4 | 1 | 26% | đòn đánh = 53% sát thương, cận chiến |
| TYRANTRUM (TYRUNT) | RARE | Đỡ đòn | **Đấu sĩ** | 28% | 7 | 100% | 1 / 1 | 1 | 41% | đòn đánh = 72% sát thương, cận chiến |
| CONKELDURR (TIMBURR) | ULTRA | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 53% | đòn đánh = 100% sát thương, cận chiến |
| HOUNDSTONE (GREAVARD) | UNCOMMON | Đỡ đòn | **Đấu sĩ** | 31% | 7 | 100% | 1 / 1 | 1 | 61% | đòn đánh = 69% sát thương, cận chiến |
| QUAQUAVAL (QUAXLY) | UNCOMMON | Sát thủ | **Đấu sĩ** | 35% | 7 | 100% | 1 / 1 | 1 | 12% | đòn đánh = 65% sát thương, cận chiến |
| SALAMENCE (BAGON) | UNCOMMON | Đỡ đòn | **Đấu sĩ** | 43% | 7 | 100% | 1 / 1 | 1 | 16% | đòn đánh = 57% sát thương, cận chiến |
| SCEPTILE (TREECKO) | UNCOMMON | Đỡ đòn | **Đấu sĩ** | 28% | 7 | 100% | 1 / 1 | 1 | 60% | đòn đánh = 72% sát thương, cận chiến |
| AERODACTYL | UNIQUE | Đỡ đòn | **Đấu sĩ** | 58% | 7 | 100% | 1 / 1 | 1 | 43% | đòn đánh = 42% sát thương, cận chiến |
| ARCTOVISH | UNIQUE | Đỡ đòn | **Đấu sĩ** | 42% | 7 | 100% | 1 / 1 | 1 | 17% | đòn đánh = 58% sát thương, cận chiến |
| ARCTOZOLT | UNIQUE | Đỡ đòn | **Đấu sĩ** | 42% | 7 | 100% | 1 / 1 | 1 | 17% | đòn đánh = 58% sát thương, cận chiến |
| BASCULEGION_MALE (BASCULIN_WHITE) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 38% | 7 | 100% | 1 / 1 | 1 | 30% | đòn đánh = 62% sát thương, cận chiến |
| BASCULIN_BLUE | UNIQUE | Đỡ đòn | **Đấu sĩ** | 21% | 7 | 100% | 1 / 1 | 1 | 8% | đòn đánh = 79% sát thương, cận chiến |
| BASCULIN_RED | UNIQUE | Đỡ đòn | **Đấu sĩ** | 21% | 7 | 100% | 1 / 1 | 1 | 8% | đòn đánh = 79% sát thương, cận chiến |
| CERULEDGE (CHARCADET) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 48% | 1 | 0% | 2 / 0 | 1 | 60% | đòn đánh = 52% sát thương, cận chiến |
| DRACOVISH | UNIQUE | Đỡ đòn | **Đấu sĩ** | 34% | 7 | 100% | 1 / 1 | 1 | 17% | đòn đánh = 66% sát thương, cận chiến |
| DRACOZOLT | UNIQUE | Đỡ đòn | **Đấu sĩ** | 34% | 7 | 100% | 1 / 1 | 1 | 17% | đòn đánh = 66% sát thương, cận chiến |
| DRUDDIGON | UNIQUE | Đỡ đòn | **Đấu sĩ** | 44% | 7 | 50% | 2 / 1 | 1 | 25% | đòn đánh = 56% sát thương, cận chiến |
| DURANT | UNIQUE | Đỡ đòn | **Đấu sĩ** | 7% | 7 | 100% | 1 / 1 | 1 | 56% | đòn đánh = 93% sát thương, cận chiến |
| EISCUE | UNIQUE | Đỡ đòn | **Đấu sĩ** | 48% | 7 | 100% | 1 / 1 | 1 | 64% | đòn đánh = 52% sát thương, cận chiến |
| EISCUE_NOICE (EISCUE) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 45% | 7 | 100% | 1 / 1 | 1 | 11% | đòn đánh = 55% sát thương, cận chiến |
| HEATMOR | UNIQUE | Đỡ đòn | **Đấu sĩ** | 42% | 7 | 100% | 1 / 1 | 1 | 60% | đòn đánh = 58% sát thương, cận chiến |
| HERACROSS | UNIQUE | Đỡ đòn | **Đấu sĩ** | 44% | 7 | 100% | 1 / 1 | 1 | 31% | đòn đánh = 56% sát thương, cận chiến |
| HITMONLEE (TYROGUE) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 39% | 7 | 100% | 1 / 1 | 1 | 43% | đòn đánh = 61% sát thương, cận chiến |
| HOOPA | UNIQUE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 50% | đòn đánh = 100% sát thương, cận chiến |
| ILLUMISE | UNIQUE | Đỡ đòn | **Đấu sĩ** | 42% | 1 | 0% | 2 / 0 | 1 | 2% | đòn đánh = 58% sát thương, cận chiến |
| IRON_BUNDLE | UNIQUE | Đỡ đòn | **Đấu sĩ** | 66% | 7 | 50% | 2 / 1 | 1 | 60% | đòn đánh = 34% sát thương, cận chiến |
| IRON_THORNS | UNIQUE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 60% | đòn đánh = 100% sát thương, cận chiến |
| KECLEON | UNIQUE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 43% | đòn đánh = 100% sát thương, cận chiến |
| KLEAVOR (SCYTHER) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 27% | 7 | 100% | 1 / 1 | 1 | 36% | đòn đánh = 73% sát thương, cận chiến |
| KOMALA | UNIQUE | Đỡ đòn | **Đấu sĩ** | 47% | 1 | 0% | 2 / 0 | 1 | 36% | đòn đánh = 53% sát thương, cận chiến |
| MANTINE (MANTYKE) | UNIQUE | Xạ thủ | **Đấu sĩ** | 45% | 7 | 100% | 2 / 3 | 2 | 97% | đòn đánh = 55% sát thương, tầm web 2 nhưng rất trâu (bulk 97%) |
| MARACTUS | UNIQUE | Đỡ đòn | **Đấu sĩ** | 8% | 7 | 100% | 1 / 1 | 1 | 30% | đòn đánh = 92% sát thương, cận chiến |
| MEGA_SABLEYE (SABLEYE) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 51% | 7 | 100% | 1 / 1 | 1 | 50% | đòn đánh = 49% sát thương, cận chiến |
| ORTHWORM | UNIQUE | Đỡ đòn | **Đấu sĩ** | 52% | 7 | 100% | 1 / 1 | 1 | 65% | đòn đánh = 48% sát thương, cận chiến |
| PALAFIN (FINIZEN) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 47% | 7 | 100% | 1 / 1 | 1 | 55% | đòn đánh = 53% sát thương, cận chiến |
| PALAFIN_HERO (FINIZEN) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 39% | 7 | 100% | 1 / 1 | 1 | 40% | đòn đánh = 61% sát thương, cận chiến |
| PINSIR | UNIQUE | Đỡ đòn | **Đấu sĩ** | 28% | 7 | 100% | 1 / 1 | 1 | 31% | đòn đánh = 72% sát thương, cận chiến |
| PYUKUMUKU | UNIQUE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 38% | đòn đánh = 100% sát thương, cận chiến |
| QWILFISH | UNIQUE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 13% | đòn đánh = 100% sát thương, cận chiến |
| SCIZOR (SCYTHER) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 24% | 7 | 100% | 1 / 1 | 1 | 64% | đòn đánh = 76% sát thương, cận chiến |
| SCYTHER | UNIQUE | Đỡ đòn | **Đấu sĩ** | 44% | 7 | 100% | 1 / 1 | 1 | 36% | đòn đánh = 56% sát thương, cận chiến |
| SEVIPER | UNIQUE | Đỡ đòn | **Đấu sĩ** | 52% | 7 | 100% | 1 / 1 | 1 | 17% | đòn đánh = 48% sát thương, cận chiến |
| SMEARGLE | UNIQUE | Xạ thủ | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 3 | 94% | đòn đánh = 100% sát thương, tầm web 3 nhưng rất trâu (bulk 94%) |
| TAPU_BULU | UNIQUE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 43% | đòn đánh = 100% sát thương, cận chiến |
| TAUROS | UNIQUE | Đỡ đòn | **Đấu sĩ** | 39% | 7 | 100% | 1 / 1 | 1 | 60% | đòn đánh = 61% sát thương, cận chiến |
| TAUROS_AQUA_BREED (TAUROS) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 39% | 7 | 100% | 1 / 1 | 1 | 60% | đòn đánh = 61% sát thương, cận chiến |
| TAUROS_BLAZE_BREED (TAUROS) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 39% | 7 | 100% | 1 / 1 | 1 | 60% | đòn đánh = 61% sát thương, cận chiến |
| TAUROS_COMBAT_BREED (TAUROS) | UNIQUE | Đỡ đòn | **Đấu sĩ** | 39% | 7 | 100% | 1 / 1 | 1 | 60% | đòn đánh = 61% sát thương, cận chiến |
| VELUZA | UNIQUE | Đỡ đòn | **Đấu sĩ** | 0% | 0 | 0% | 0 / 0 | 1 | 12% | đòn đánh = 100% sát thương, cận chiến |
| VOLBEAT | UNIQUE | Đỡ đòn | **Đấu sĩ** | 49% | 1 | 0% | 2 / 0 | 1 | 2% | đòn đánh = 51% sát thương, cận chiến |
| AZUMARILL (AZURILL) | COMMON | Pháp sư | **Xạ thủ** | 43% | 7 | 100% | 1 / 1 | 2 | 47% | đòn đánh = 57% sát thương, tầm web 2 |
| BUTTERFREE (CATERPIE) | COMMON | Pháp sư | **Xạ thủ** | 29% | 7 | 100% | 1 / 1 | 2 | 23% | đòn đánh = 71% sát thương, tầm web 2 |
| CHANDELURE (LITWICK) | COMMON | Pháp sư | **Xạ thủ** | 43% | 7 | 100% | 1 / 1 | 3 | 3% | đòn đánh = 57% sát thương, tầm web 3 |
| CROBAT (ZUBAT) | COMMON | Pháp sư | **Xạ thủ** | 40% | 7 | 100% | 1 / 1 | 2 | 19% | đòn đánh = 60% sát thương, tầm web 2 |
| KLINKLANG (KLINK) | COMMON | Pháp sư | **Xạ thủ** | 40% | 7 | 100% | 1 / 1 | 3 | 10% | đòn đánh = 60% sát thương, tầm web 3 |
| POLITOED (POLIWAG) | COMMON | Pháp sư | **Xạ thủ** | 41% | 7 | 100% | 1 / 1 | 2 | 37% | đòn đánh = 59% sát thương, tầm web 2 |
| SERPERIOR (SNIVY) | HATCH | Pháp sư | **Xạ thủ** | 42% | 7 | 100% | 2 / 2 | 3 | 84% | đòn đánh = 58% sát thương, tầm web 3 |
| MASQUERAIN (SURSKIT) | RARE | Pháp sư | **Xạ thủ** | 43% | 7 | 100% | 2 / 2 | 2 | 23% | đòn đánh = 57% sát thương, tầm web 2 |
| VANILLUXE (VANILLITE) | RARE | Pháp sư | **Xạ thủ** | 45% | 7 | 100% | 3 / 3 | 3 | 17% | đòn đánh = 55% sát thương, tầm web 3 |
| TALONFLAME (FLETCHLING) | ULTRA | Pháp sư | **Xạ thủ** | 40% | 7 | 200% | 1 / 2 | 2 | 47% | đòn đánh = 60% sát thương, tầm web 2 |
| ARIADOS (SPINARAK) | UNCOMMON | Pháp sư | **Xạ thủ** | 21% | 7 | 100% | 1 / 1 | 2 | 30% | đòn đánh = 79% sát thương, tầm web 2 |
| DUSKNOIR (DUSKULL) | UNCOMMON | Pháp sư | **Xạ thủ** | 34% | 7 | 100% | 1 / 1 | 2 | 80% | đòn đánh = 66% sát thương, tầm web 2 |
| FLORGES (FLABEBE) | UNCOMMON | Hỗ trợ | **Xạ thủ** | 0% | 0 | 0% | 0 / 0 | 3 | 44% | đòn đánh = 100% sát thương, tầm web 3 |
| FLORGES_BLUE (FLABEBE_BLUE) | UNCOMMON | Hỗ trợ | **Xạ thủ** | 0% | 0 | 0% | 0 / 0 | 3 | 44% | đòn đánh = 100% sát thương, tầm web 3 |
| FLORGES_ORANGE (FLABEBE_ORANGE) | UNCOMMON | Hỗ trợ | **Xạ thủ** | 0% | 0 | 0% | 0 / 0 | 3 | 44% | đòn đánh = 100% sát thương, tầm web 3 |
| FLORGES_WHITE (FLABEBE_WHITE) | UNCOMMON | Hỗ trợ | **Xạ thủ** | 0% | 0 | 0% | 0 / 0 | 3 | 44% | đòn đánh = 100% sát thương, tầm web 3 |
| FLORGES_YELLOW (FLABEBE_YELLOW) | UNCOMMON | Hỗ trợ | **Xạ thủ** | 0% | 0 | 0% | 0 / 0 | 3 | 44% | đòn đánh = 100% sát thương, tầm web 3 |
| KINGDRA (HORSEA) | UNCOMMON | Pháp sư | **Xạ thủ** | 34% | 7 | 100% | 1 / 1 | 2 | 30% | đòn đánh = 66% sát thương, tầm web 2 |
| VENOMOTH (VENONAT) | UNCOMMON | Pháp sư | **Xạ thủ** | 40% | 7 | 100% | 1 / 1 | 2 | 22% | đòn đánh = 60% sát thương, tầm web 2 |
| ARBOLIVA (SMOLIV) | COMMON | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 56% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| CHERRIM (CHERUBI) | EPIC | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 3 | 9% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| CHERRIM_SUNLIGHT (CHERUBI) | EPIC | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 3 | 10% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| GALARIAN_RAPIDASH (GALARIAN_PONYTA) | EPIC | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 63% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| GOREBYSS (CLAMPERL) | EPIC | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 46% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| KOMMO_O (JANGMO_O) | EPIC | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 57% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| SWANNA (DUCKLETT) | EPIC | Xạ thủ | **Hỗ trợ** | 11% | 6 | 100% | 0 / 1 | 2 | 52% | skill giúp đồng đội (hồi / khiên / buff) = 87% giá trị skill |
| CELEBI | LEGENDARY | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 3 | 32% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| CRESSELIA | LEGENDARY | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 3 | 62% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| MELOETTA | LEGENDARY | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 4 | 32% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| OGERPON_WELLSPRING (OGERPON_TEAL) | LEGENDARY | Đỡ đòn | **Hỗ trợ** | 32% | 7 | 100% | 1 / 1 | 1 | 24% | skill giúp đồng đội (hồi / khiên / buff) = 67% giá trị skill |
| OGERPON_WELLSPRING_MASK (OGERPON_TEAL) | LEGENDARY | Đỡ đòn | **Hỗ trợ** | 32% | 7 | 100% | 1 / 1 | 1 | 24% | skill giúp đồng đội (hồi / khiên / buff) = 67% giá trị skill |
| STAKATAKA | LEGENDARY | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 100% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| ALOLAN_NINETALES (ALOLAN_VULPIX) | RARE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 60% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| BASTIODON (SHIELDON) | RARE | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 98% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| DRIFBLIM (DRIFLOON) | RARE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 94% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| FURRET (SENTRET) | RARE | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 77% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| LUMINEON (FINNEON) | RARE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 53% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| MAGCARGO (SLUGMA) | RARE | Đỡ đòn | **Hỗ trợ** | 40% | 1 | 0% | 2 / 0 | 1 | 84% | skill giúp đồng đội (hồi / khiên / buff) = 60% giá trị skill |
| RILLABOOM (GROOKEY) | ULTRA | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 77% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| ARAQUANID (DEWPIDER) | UNCOMMON | Đấu sĩ | **Hỗ trợ** | 26% | 7 | 100% | 1 / 1 | 1 | 53% | skill giúp đồng đội (hồi / khiên / buff) = 77% giá trị skill |
| BOLTUND (YAMPER) | UNCOMMON | Đấu sĩ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 22% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| ELDEGOSS (GOSSIFLEUR) | UNCOMMON | Đỡ đòn | **Hỗ trợ** | 0% | 1 | 0% | 0 / 0 | 1 | 79% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| GALARIAN_SLOWKING (GALARIAN_SLOWPOKE) | UNCOMMON | Xạ thủ | **Hỗ trợ** | 18% | 7 | 100% | 1 / 1 | 3 | 70% | skill giúp đồng đội (hồi / khiên / buff) = 75% giá trị skill |
| GALARIAN_WEEZING (KOFFING) | UNCOMMON | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 86% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| LILIGANT (PETILIL) | UNCOMMON | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 96% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| POLTEAGEIST (SINISTEA) | UNCOMMON | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 65% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| PROBOPASS (NOSEPASS) | UNCOMMON | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 97% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| SCOVILLAIN (CAPSAKID) | UNCOMMON | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 17% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| WEEZING (KOFFING) | UNCOMMON | Đỡ đòn | **Hỗ trợ** | 49% | 1 | 0% | 2 / 0 | 1 | 86% | skill giúp đồng đội (hồi / khiên / buff) = 75% giá trị skill |
| CASTFORM | UNIQUE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 17% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| CASTFORM_HAIL (CASTFORM) | UNIQUE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 17% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| CASTFORM_RAIN (CASTFORM) | UNIQUE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 17% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| CASTFORM_SUN (CASTFORM) | UNIQUE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 17% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| CYCLIZAR | UNIQUE | Đỡ đòn | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 1 | 91% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| FURFROU | UNIQUE | Đỡ đòn | **Hỗ trợ** | 0% | 1 | 0% | 0 / 0 | 1 | 74% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| LUNATONE | UNIQUE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 28% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| ORICORIO_PA_U (ORICORIO_BAILE) | UNIQUE | Xạ thủ | **Hỗ trợ** | 46% | 1 | 0% | 2 / 0 | 2 | 22% | skill giúp đồng đội (hồi / khiên / buff) = 88% giá trị skill |
| ORICORIO_POMPOM (ORICORIO_BAILE) | UNIQUE | Xạ thủ | **Hỗ trợ** | 46% | 1 | 0% | 2 / 0 | 2 | 22% | skill giúp đồng đội (hồi / khiên / buff) = 88% giá trị skill |
| ORICORIO_SENSU (ORICORIO_BAILE) | UNIQUE | Xạ thủ | **Hỗ trợ** | 46% | 1 | 0% | 2 / 0 | 2 | 22% | skill giúp đồng đội (hồi / khiên / buff) = 67% giá trị skill |
| SOLROCK | UNIQUE | Xạ thủ | **Hỗ trợ** | 0% | 0 | 0% | 0 / 0 | 2 | 28% | skill giúp đồng đội (hồi / khiên / buff) = 100% giá trị skill |
| ALOLAN_GOLEM (ALOLAN_GEODUDE) | COMMON | Đấu sĩ | **Đỡ đòn** | 61% | 1 | 0% | 2 / 0 | 1 | 95% | đòn đánh = 39% sát thương, trâu (bulk 95% cùng nhóm) |
| ALOLAN_RATICATE (ALOLAN_RATTATA) | COMMON | Đấu sĩ | **Đỡ đòn** | 0% | 0 | 0% | 0 / 0 | 1 | 81% | đòn đánh = 100% sát thương, trâu (bulk 81% cùng nhóm) |
| CHESNAUGHT (CHESPIN) | COMMON | Đấu sĩ | **Đỡ đòn** | 8% | 7 | 100% | 1 / 1 | 1 | 87% | đòn đánh = 92% sát thương, trâu (bulk 87% cùng nhóm) |
| GOLEM (GEODUDE) | COMMON | Đấu sĩ | **Đỡ đòn** | 48% | 7 | 100% | 1 / 1 | 1 | 95% | đòn đánh = 52% sát thương, trâu (bulk 95% cùng nhóm) |
| GOODRA (GOOMY) | COMMON | Đấu sĩ | **Đỡ đòn** | 0% | 0 | 0% | 0 / 0 | 1 | 90% | đòn đánh = 100% sát thương, trâu (bulk 90% cùng nhóm) |
| HISUI_GOODRA (GOOMY) | COMMON | Đấu sĩ | **Đỡ đòn** | 0% | 7 | 0% | 0 / 0 | 1 | 73% | đòn đánh = 100% sát thương, trâu (bulk 73% cùng nhóm) |
| MAMOSWINE (SWINUB) | COMMON | Đấu sĩ | **Đỡ đòn** | 76% | 7 | 50% | 4 / 2 | 1 | 100% | đòn đánh = 24% sát thương, trâu (bulk 100% cùng nhóm) |
| POLIWRATH (POLIWAG) | COMMON | Đấu sĩ | **Đỡ đòn** | 55% | 7 | 100% | 1 / 1 | 1 | 68% | đòn đánh = 45% sát thương, trâu (bulk 68% cùng nhóm) |
| STOUTLAND (LILLIPUP) | COMMON | Đấu sĩ | **Đỡ đòn** | 16% | 7 | 100% | 1 / 1 | 1 | 77% | đòn đánh = 84% sát thương, trâu (bulk 77% cùng nhóm) |
| SWAMPERT (MUDKIP) | COMMON | Đấu sĩ | **Đỡ đòn** | 0% | 0 | 0% | 0 / 0 | 1 | 73% | đòn đánh = 100% sát thương, trâu (bulk 73% cùng nhóm) |
| EMBOAR (TEPIG) | HATCH | Đấu sĩ | **Đỡ đòn** | 44% | 7 | 100% | 1 / 1 | 1 | 100% | đòn đánh = 56% sát thương, trâu (bulk 100% cùng nhóm) |
| TOXICROAK (CROAGUNK) | RARE | Đấu sĩ | **Đỡ đòn** | 84% | 7 | 50% | 4 / 2 | 1 | 68% | đòn đánh = 16% sát thương, trâu (bulk 68% cùng nhóm) |
| ALOLAN_MUK (ALOLAN_GRIMER) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 85% | 1 | 0% | 0 / 0 | 1 | 83% | đòn đánh = 15% sát thương, trâu (bulk 83% cùng nhóm) |
| ARCANINE (GROWLITHE) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 58% | 7 | 100% | 1 / 1 | 1 | 67% | đòn đánh = 42% sát thương, trâu (bulk 67% cùng nhóm) |
| BRAVIARY (RUFFLET) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 25% | 7 | 100% | 1 / 1 | 1 | 79% | đòn đánh = 75% sát thương, trâu (bulk 79% cùng nhóm) |
| BRELOOM (SHROOMISH) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 69% | 7 | 100% | 0 / 0 | 1 | 75% | đòn đánh = 31% sát thương, trâu (bulk 75% cùng nhóm) |
| CETITAN (CETODDLE) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 47% | 1 | 0% | 2 / 0 | 1 | 74% | đòn đánh = 53% sát thương, trâu (bulk 74% cùng nhóm) |
| DUBWOOL (WOOLOO) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 27% | 7 | 100% | 1 / 1 | 1 | 69% | đòn đánh = 73% sát thương, trâu (bulk 69% cùng nhóm) |
| EELEKTROSS (TYNAMO) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 68% | 2 | 0% | 5 / 0 | 1 | 96% | đòn đánh = 32% sát thương, trâu (bulk 96% cùng nhóm) |
| GARGANACL (NACLI) | UNCOMMON | Hỗ trợ | **Đỡ đòn** | 90% | 2 | 0% | 0 / 0 | 1 | 100% | đòn đánh = 10% sát thương, trâu (bulk 100% cùng nhóm) |
| GOLDUCK (PSYDUCK) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 27% | 7 | 100% | 1 / 1 | 1 | 92% | đòn đánh = 73% sát thương, trâu (bulk 92% cùng nhóm) |
| GRAPPLOCT (CLOBBOPUS) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 50% | 7 | 100% | 1 / 1 | 1 | 79% | đòn đánh = 50% sát thương, trâu (bulk 79% cùng nhóm) |
| NIDOKING (NIDORANM) | UNCOMMON | Đấu sĩ | **Đỡ đòn** | 42% | 7 | 100% | 1 / 1 | 1 | 70% | đòn đánh = 58% sát thương, trâu (bulk 70% cùng nhóm) |

## Pháp sư có skill tại chỗ (nên sửa skill)

Pháp sư nên *tung* skill (vào mục tiêu / đường thẳng / ném xa) chứ không *thả skill tại chỗ* (quanh mình). Các dạng cuối dưới đây là carry skill tầm xa nhưng skill chỉ trúng khi đứng gần: tầm < 4 ô hoặc từ hàng cuối còn < 50% sát thương so với hàng đầu. Danh sách đủ skill để đọc / cân lại: `docs/SKILLS.md`, `docs/skills.html`.

| Dạng cuối | Độ hiếm | Skill | Vai trò hiện tại | Tầm | Cuối | Trúng | Skill |
|---|---|---|---|---|---|---|---|
| ROARING_MOON | LEGENDARY | SCALE_SHOT | Xạ thủ | 7 | 41% | 4 / 3 | 52% |
| ZYGARDE_50 | LEGENDARY | THOUSAND_ARROWS | Xạ thủ | 0 | 100% | 4 / 4 | 63% |
| CHATOT | UNIQUE | CHATTER | Xạ thủ | 3 | 0% | 7 / 0 | 66% |
| DRAMPA | UNIQUE | DRAGON_PULSE | Xạ thủ | 7 | 36% | 7 / 4 | 82% |
| ORICORIO_BAILE | UNIQUE | REVELATION_DANCE | Xạ thủ | 1 | 0% | 2 / 0 | 46% |

## Họ có dạng khác vai trò

Từng dạng xếp riêng ra vai trò khác nhau (skill / chỉ số đổi theo sao); gợi ý lấy vai trò của dạng cuối (`familyRole`).

| Họ | Vai trò từng dạng |
|---|---|
| ABRA | KADABRA Xạ thủ, ABRA Đấu sĩ, ALAKAZAM Xạ thủ |
| ALOLAN_GRIMER | ALOLAN_GRIMER Đấu sĩ, ALOLAN_MUK Đỡ đòn |
| ALOLAN_MEOWTH | ALOLAN_MEOWTH Đỡ đòn, ALOLAN_PERSIAN Đấu sĩ |
| ALOLAN_RATTATA | ALOLAN_RATICATE Đỡ đòn, ALOLAN_RATTATA Đấu sĩ |
| APPLIN | DIPPLIN Pháp sư, APPLETUN Đỡ đòn, APPLIN Hỗ trợ, HYDRAPPLE Xạ thủ, FLAPPLE Pháp sư |
| ARON | ARON Đỡ đòn, AGGRON Đấu sĩ, LAIRON Đấu sĩ |
| AZURILL | AZUMARILL Xạ thủ, AZURILL Xạ thủ, MARILL Pháp sư |
| BAGON | SALAMENCE Đấu sĩ, SHELGON Đấu sĩ, BAGON Đỡ đòn |
| BASCULIN_WHITE | BASCULEGION_FEMALE Xạ thủ, BASCULEGION_MALE Đấu sĩ, BASCULIN_WHITE Đấu sĩ |
| BLIPBUG | ORBEETLE Đấu sĩ, BLIPBUG Đỡ đòn, DOTTLER Đỡ đòn |
| BULBASAUR | IVYSAUR Pháp sư, BULBASAUR Xạ thủ, VENUSAUR Pháp sư |
| BUNNELBY | BUNNELBY Đấu sĩ, DIGGERSBY Đỡ đòn |
| CAPSAKID | CAPSAKID Xạ thủ, SCOVILLAIN Hỗ trợ |
| CHARCADET | CHARCADET Sát thủ, ARMAROUGE Pháp sư, CERULEDGE Đấu sĩ |
| CLAMPERL | CLAMPERL Hỗ trợ, GOREBYSS Hỗ trợ, HUNTAIL Đấu sĩ |
| CLOBBOPUS | CLOBBOPUS Đấu sĩ, GRAPPLOCT Đỡ đòn |
| COMBEE | COMBEE Đấu sĩ, VESPIQUEN Xạ thủ |
| CORSOLA | GALAR_CORSOLA Đỡ đòn, CORSOLA Đỡ đòn, CURSOLA Đấu sĩ |
| COSMOG | COSMOEM Đấu sĩ, COSMOG Đấu sĩ, LUNALA Pháp sư, SOLGALEO Sát thủ |
| CROAGUNK | CROAGUNK Đấu sĩ, TOXICROAK Đỡ đòn |
| CYNDAQUIL | CYNDAQUIL Xạ thủ, TYPHLOSION Pháp sư, QUILAVA Pháp sư, HISUIAN_TYPHLOSION Pháp sư |
| DARUMAKA | DARMANITAN Đấu sĩ, DARMANITAN_ZEN Xạ thủ, DARUMAKA Đấu sĩ |
| DEOXYS | DEOXYS_DEFENSE Đấu sĩ, DEOXYS_SPEED Pháp sư, DEOXYS Đấu sĩ, DEOXYS_ATTACK Xạ thủ |
| DRATINI | DRAGONAIR Đấu sĩ, DRAGONITE Đỡ đòn, DRATINI Đấu sĩ |
| DREEPY | DREEPY Đấu sĩ, DRAGAPULT Xạ thủ, DRAKLOAK Xạ thủ |
| DUCKLETT | SWANNA Hỗ trợ, DUCKLETT Xạ thủ |
| DUNSPARCE | DUNSPARCE Đấu sĩ, DUDUNSPARCE Đỡ đòn |
| DWEBBLE | CRUSTLE Đỡ đòn, DWEBBLE Đấu sĩ |
| ELECTRIKE | ELECTRIKE Đỡ đòn, MANECTRIC Đấu sĩ |
| ELEKID | ELEKID Đỡ đòn, ELECTABUZZ Đấu sĩ, ELECTIVIRE Đỡ đòn |
| ESPURR | ESPURR Đỡ đòn, MEOWSTIC_FEMALE Đấu sĩ, MEOWSTIC_MALE Đấu sĩ |
| EXEGGCUTE | ALOLAN_EXEGGUTOR Đỡ đòn, EXEGGCUTE Pháp sư, EXEGGUTOR Đỡ đòn |
| FERROSEED | FERROSEED Hỗ trợ, FERROTHORN Đỡ đòn |
| GALARIAN_SLOWPOKE | GALARIAN_SLOWBRO Đỡ đòn, GALARIAN_SLOWKING Hỗ trợ, GALARIAN_SLOWPOKE Hỗ trợ |
| GALARIAN_ZIGZAGOON | GALARIAN_LINOONE Đấu sĩ, GALARIAN_ZIGZAGOON Đỡ đòn, OBSTAGOON Đỡ đòn |
| GIRATINA | GIRATINA Sát thủ, ORIGIN_GIRATINA Đấu sĩ |
| GOOMY | GOODRA Đỡ đòn, GOOMY Đỡ đòn, HISUI_GOODRA Đỡ đòn, HISUI_SLIGGOO Đấu sĩ, SLIGOO Đỡ đòn |
| GROUDON | GROUDON Đấu sĩ, PRIMAL_GROUDON Đỡ đòn |
| HOOPA | HOOPA Đấu sĩ, HOOPA_UNBOUND Đỡ đòn |
| INKAY | MALAMAR Đỡ đòn, INKAY Đấu sĩ |
| KARRABLAST | KARRABLAST Đấu sĩ, ESCAVALIER Đỡ đòn |
| KRICKETOT | KRICKETOT Đấu sĩ, KRICKETUNE Đỡ đòn |
| LECHONK | LECHONK Đỡ đòn, OINKOLOGNE_MALE Đấu sĩ |
| MACHOP | MACHAMP Đỡ đòn, MACHOKE Đấu sĩ, MACHOP Đỡ đòn |
| MANTYKE | MANTYKE Pháp sư, MANTINE Đấu sĩ |
| MAREEP | MAREEP Xạ thủ, FLAFFY Pháp sư, AMPHAROS Pháp sư |
| MELOETTA | PIROUETTE_MELOETTA Sát thủ, MELOETTA Hỗ trợ |
| MEOWTH | PERSIAN Đấu sĩ, MEOWTH Đỡ đòn |
| MIENFOO | MIENFOO Đỡ đòn, MIENSHAO Đấu sĩ |
| NECROZMA | NECROZMA Đấu sĩ, ULTRA_NECROZMA Pháp sư |
| NIDORANM | NIDOKING Đỡ đòn, NIDORANM Đấu sĩ, NIDORINO Đấu sĩ |
| NINCADA | NINCADA Đỡ đòn, NINJASK Đấu sĩ |
| NOIBAT | NOIBAT Pháp sư, NOIVERN Xạ thủ |
| OGERPON_TEAL | OGERPON_CORNERSTONE Đấu sĩ, OGERPON_CORNERSTONE_MASK Đấu sĩ, OGERPON_HEARTHFLAME Đấu sĩ, OGERPON_HEARTHFLAME_MASK Đấu sĩ, OGERPON_TEAL Đấu sĩ, OGERPON_TEAL_MASK Đấu sĩ, OGERPON_WELLSPRING Hỗ trợ, OGERPON_WELLSPRING_MASK Hỗ trợ |
| ORICORIO_BAILE | ORICORIO_BAILE Pháp sư, ORICORIO_PA_U Hỗ trợ, ORICORIO_POMPOM Hỗ trợ, ORICORIO_SENSU Hỗ trợ |
| OSHAWOTT | OSHAWOTT Đỡ đòn, DEWOTT Đỡ đòn, HISUI_SAMUROTT Đấu sĩ, SAMUROTT Đỡ đòn |
| PANCHAM | PANGORO Đỡ đòn, PANCHAM Đấu sĩ |
| PARAS | PARAS Đỡ đòn, PARASECT Đấu sĩ |
| PAWMI | PAWMI Đỡ đòn, PAWMO Đấu sĩ, PAWMOT Đấu sĩ |
| PAWNIARD | BISHARP Đấu sĩ, PAWNIARD Đỡ đòn, KINGAMBIT Đỡ đòn |
| PETILIL | PETILIL Hỗ trợ, HISUIAN_LILLIGANT Đỡ đòn, LILIGANT Hỗ trợ |
| PICHU | ALOLAN_RAICHU Sát thủ, PIKACHU Sát thủ, PIKACHU_LIBRE Đấu sĩ, PIKACHU_SURFER Sát thủ, PICHU Sát thủ, RAICHU Sát thủ |
| POLIWAG | POLIWHIRL Xạ thủ, POLIWRATH Đỡ đòn, POLITOED Xạ thủ, POLIWAG Xạ thủ |
| POOCHYENA | MIGHTYENA Đỡ đòn, POOCHYENA Đấu sĩ |
| RALTS | RALTS Pháp sư, KIRLIA Pháp sư, GALLADE Đấu sĩ, GARDEVOIR Pháp sư |
| RAYQUAZA | MEGA_RAYQUAZA Pháp sư, RAYQUAZA Đấu sĩ |
| RHYHORN | RHYPERIOR Đỡ đòn, RHYDON Đấu sĩ, RHYHORN Đấu sĩ |
| ROTOM | ROTOM Pháp sư, ROTOM_DRONE Pháp sư, ROTOM_FAN Pháp sư, ROTOM_FROST Pháp sư, ROTOM_HEAT Đỡ đòn, ROTOM_MOW Đỡ đòn, ROTOM_WASH Pháp sư |
| RUFFLET | BRAVIARY Đỡ đòn, RUFFLET Đấu sĩ |
| SABLEYE | SABLEYE Đỡ đòn, MEGA_SABLEYE Đấu sĩ |
| SEEDOT | NUZLEAF Đỡ đòn, SHIFTRY Đấu sĩ, SEEDOT Đỡ đòn |
| SHROOMISH | BRELOOM Đỡ đòn, SHROOMISH Đấu sĩ |
| SILICOBRA | SILICOBRA Đấu sĩ, SANDACONDA Đỡ đòn |
| SIZZLIPEDE | SIZZLIPEDE Đỡ đòn, CENTISKORCH Đấu sĩ |
| SLAKOTH | SLAKING Đỡ đòn, SLAKOTH Đỡ đòn, VIGOROTH Đấu sĩ |
| SLOWPOKE | SLOWBRO Đỡ đòn, SLOWKING Xạ thủ, SLOWPOKE Đỡ đòn |
| SNIVY | SERPERIOR Xạ thủ, SERVINE Xạ thủ, SNIVY Pháp sư |
| SNOM | FROSMOTH Xạ thủ, SNOM Pháp sư |
| SNORUNT | SNORUNT Xạ thủ, FROSLASS Pháp sư, GLALIE Pháp sư |
| SPHEAL | SPHEAL Đỡ đòn, WALREIN Đỡ đòn, SEALEO Đấu sĩ |

