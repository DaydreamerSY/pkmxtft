# Điểm chung của Pokémon — nguyên liệu dựng hệ mới theo mùa

> Sinh bằng `python tools/port/gen_themes.py` từ `tools/port/themes/` — **đừng sửa tay file này**. Bản xem có ảnh,
> lọc theo điểm chung / độ hiếm / mùa / hệ và nút chép danh sách: [`docs/themes.html`](themes.html) (mở bằng trình duyệt).

Mục đích (yêu cầu 2026-11-16): thêm các hệ *khác đại trà* — kiểu Human, Gourmet — như Y tế, Vận chuyển, Trâu bò,
Ngựa…, rồi đưa vào từng mùa (`docs/SEASONS.md`). File này gom **điểm chung** của **508 họ** Pokémon đang có trong
game (shop, Unique, Legendary, trứng): mỗi họ có thể có nhiều điểm chung; danh sách xếp theo số họ.

**Nguồn:**

- Cột *Pokédex*: category chính thức (tiếng Anh) từ dữ liệu PokéAPI (`pokemon_species_names.csv`), lưu ở
  `tools/port/themes/genus_en.txt` — vd Lapras là *Transport*, Miltank *Milk Cow*, Mudsdale *Draft Horse*.
- *Ghi chú* và *điểm chung*: Claude tóm tắt từ lore Pokédex / thiết kế của từng loài (viết lại, không chép nguyên
  văn; Bulbapedia chặn bot nên không đọc được từng trang). Tag có dấu `?` = **gần đúng** / tuỳ cách hiểu. Trước khi
  chốt một hệ, nên xem lại các họ trong đó (ảnh và ghi chú ở viewer).
- Sửa / thêm: chỉnh `tools/port/themes/themes.txt` (điểm chung) hoặc `pokemon_*.txt` (tag của họ) rồi chạy lại script.

## 1. Tham khảo: cách TFT Set 19 xếp hệ (op.gg)

Set 19 *Prismatic Tour* (chủ đề âm nhạc) có khoảng 94 tướng (tính cả biến thể), **14 Tộc (origin) + 15 Hệ (class)**.
Mỗi tướng thường có **1 Tộc + 1 Hệ** (vd Draven: Illbeats + Trickshot, Ashe: Beach Pop + Swiftstriker, Elise: Ionic
Spark + Frontman); nhiều tướng đắt có **hệ độc nhất** (1 tướng, cơ chế riêng). Các cỡ hệ hay gặp:

| Loại | Số tướng | Mốc | Ví dụ |
|---|---|---|---|
| Hệ lớn (vai trò) | 7–10 | 2/4/6 | Arcanist, Bodyguard, Frontman, Juggernaut, Slayer |
| Tộc vừa (nhóm nhạc) | 6–8 | 3/5/7 | Beach Pop, Pentakill, Heartsteel, Rock |
| Hệ nhỏ | 3–6 | 2/3/4 (đến 5) | Jazz, Gu Feng, Manager, Prodigy, Renegade |
| Độc nhất | 1 | 1 | Country, Disco, Emo, Goth, Mariachi… (khoảng 15 hệ) |
| Siêu hệ | ~8 | nhiều mốc (3/5/7/10…) | K/DA, Ionic Spark |

Áp vào game này: các hệ có sẵn (Fire, Water…) đóng vai **Tộc**; điểm chung ở đây hợp làm **Hệ theo chủ đề** — mỗi
mùa thêm vài hệ mới, Pokémon của mùa mang hệ gốc + một hệ mới. Luật mùa hiện tại (hệ đại trà 8–10 họ, hệ đặc biệt
3–5 họ + mốc riêng) khớp với *Hệ lớn* và *Hệ nhỏ*; điểm chung chỉ có 1–2 họ có thể làm **hệ độc nhất** cho một
Unique / Legendary. Lưu ý: game chưa có hệ nào trong số này — mỗi hệ mới cần hiệu ứng, icon, mốc, chữ 14 ngôn ngữ.

## 2. Gợi ý ghép mùa (số = số họ khớp, `+n?` = thêm n họ gần đúng)

- **Nông trại & thảo nguyên**: Nông trại `farm` 13 (+11?), Ngựa `horse` 6 (+2?), Trâu bò `bovine` 2 (+1?), Dê & cừu `goat` 3, Lợn `pig` 4 (+1?), Vận chuyển `transport` 23 (+7?).
- **Thành phố & nghề nghiệp**: Y tế & cứu hộ `medic` 14 (+5?), Vận chuyển `transport` 23 (+7?), Lao động & xây dựng `worker` 6, Hộ vệ & canh gác `guardian` 21 (+3?), Thành phố & ô nhiễm `urban` 12 (+4?), Món ăn `food` 18 (+5?).
- **12 con giáp**: Chuột & gặm nhấm `rodent` 17 (+1?), Trâu bò `bovine` 2 (+1?), Hổ, báo, sư tử `tiger` 4 (+2?), Mèo `cat` 9, Rắn & mãng xà `snake` 7 (+2?), Ngựa `horse` 6 (+2?), Dê & cừu `goat` 3, Khỉ & vượn `monkey` 6 (+1?), Gà, vịt & gà lôi `fowl` 7 (+1?), Chó & sói `dog` 16, Lợn `pig` 4 (+1?).
- **Truyện cổ phương Đông**: Truyện cổ & yêu quái `folklore` 26 (+7?), Thần thoại & thần linh `myth` 48 (+4?), Ninja & điệp viên `ninja` 7 (+2?), Hiệp sĩ & kiếm sĩ `knight` 19 (+4?), Hoàng gia & thủ lĩnh `royal` 15 (+3?).
- **Kho báu & cổ vật**: Kho báu & đá quý `treasure` 11 (+2?), Cổ vật & di tích `relic` 17 (+4?), Sa mạc & Ai Cập cổ `desert` 12 (+1?), Kẻ gian & lưu manh `rogue` 14 (+4?), Đào mỏ `miner` 9 (+2?).
- **Vũ trụ & giấc mơ**: Vũ trụ & ngoài hành tinh `space` 21 (+1?), Giấc ngủ & giấc mơ `dream` 9 (+3?), Pháp sư & phù thuỷ `magic` 11 (+1?), Thời tiết & thiên tai `weather` 19 (+3?).
- **Biển cả**: Thú biển `sea_mammal` 8, Cua, tôm & giáp xác `crab` 8 (+1?), Chim biển & cánh cụt `waterbird` 6, Bạch tuộc & mực `octopus` 3, Rùa `turtle` 5, Vận chuyển `transport` 23 (+7?).
- **Rạp xiếc & sân đấu**: Nghệ sĩ biểu diễn `artist` 15 (+7?), Thể thao & võ thuật `sport` 21, Pháp sư & phù thuỷ `magic` 11 (+1?), Món ăn `food` 18 (+5?).

12 con giáp: Thìn (rồng) dùng hệ Dragon có sẵn; trâu bò và gà ít họ — gộp cả mười hai thành một hệ "Con giáp"
lớn, hoặc mỗi con một hệ nhỏ 2/3/4 và bỏ các con thiếu họ.

## 3. Bảng tổng (xếp theo số họ)

| Điểm chung | id | Nhóm | Số họ | Theo độ hiếm | Hệ có sẵn hay gặp | Hay đi cùng | Trong mùa s1/s2/s3 |
|---|---|---|---|---|---|---|---|
| Thần thoại & thần linh | `myth` | Truyền thuyết & văn hoá | 48 (+4?) | E1 Unq11 Leg36 | Psychic 13, Flying 12, Fairy 11 | weather 10, guardian 6, medic 4 | 17/14/17 |
| Truyện cổ & yêu quái | `folklore` | Truyền thuyết & văn hoá | 26 (+7?) | C1 U3 R6 E5 Unq2 Leg9 | Psychic 7, Ghost 6, Fire 5 | fox 4, disguise 3, myth 3 | 6/9/7 |
| Vận chuyển | `transport` | Hệ | 23 (+7?) | C2 U2 R3 E5 UL2 Unq7 Leg2 | Field 7, Flying 7, Water 5 | farm 3, horse 3, medic 2 | 5/10/9 |
| Đồ vật sống | `object` | Đồ vật & thế giới | 22 (+1?) | C2 U5 R4 E4 Unq5 Leg2 | Artificial 11, Ghost 10, Steel 9 | relic 3, urban 3, folklore 2 | 6/7/11 |
| Hộ vệ & canh gác | `guardian` | Hệ | 21 (+3?) | C1 U2 R4 E1 Unq8 Leg5 | Fairy 6, Fighting 5, Field 4 | myth 6, knight 4, dog 3 | 5/9/7 |
| Vũ trụ & ngoài hành tinh | `space` | Truyền thuyết & văn hoá | 21 (+1?) | U1 R2 Unq5 Leg13 | Psychic 7, Light 6, Rock 5 | treasure 2, festival 1, folklore 1 | 3/6/11 |
| Thể thao & võ thuật | `sport` | Hệ | 21 | C1 U2 R7 E2 Unq5 Leg2 Trứng2 | Fighting 19, Human 6, Fire 5 | monkey 2, bear 1, cat 1 | 5/9/6 |
| Hiệp sĩ & kiếm sĩ | `knight` | Hệ | 19 (+4?) | R2 E5 UL1 Unq3 Leg7 Sp1 | Fighting 10, Steel 9, Bug 3 | guardian 4, royal 2, crab 1 | 9/6/4 |
| Thời tiết & thiên tai | `weather` | Đồ vật & thế giới | 19 (+3?) | R1 E4 Unq4 Leg10 | Flying 8, Electric 5, Ground 5 | myth 10, folklore 3, guardian 2 | 4/5/9 |
| Món ăn | `food` | Đồ vật & thế giới | 18 (+5?) | C1 U4 R3 E2 UL1 Unq6 Sp1 | Gourmet 16, Grass 5, Normal 5 | farm 4, royal 3, medic 2 | 9/6/6 |
| Cổ vật & di tích | `relic` | Truyền thuyết & văn hoá | 17 (+4?) | U1 R4 E1 Unq4 Leg7 | Fossil 7, Human 6, Rock 5 | object 3, desert 2, folklore 2 | 4/6/5 |
| Chuột & gặm nhấm | `rodent` | Tộc | 17 (+1?) | C4 U2 R3 Unq8 | Electric 9, Normal 7, Fairy 4 | glutton 2, urban 2, family 1 | 7/7/6 |
| Chó & sói | `dog` | Tộc | 16 | C1 U4 R4 E3 Unq2 Leg2 | Field 9, Fire 4, Wild 4 | guardian 3, artist 1, farm 1 | 5/5/5 |
| Nghệ sĩ biểu diễn | `artist` | Hệ | 15 (+7?) | C1 U4 R2 UL1 Unq5 Leg1 Trứng1 | Sound 8, Grass 5, Flora 4 | bear 1, cat 1, desert 1 | 8/5/5 |
| Hoàng gia & thủ lĩnh | `royal` | Hệ | 15 (+3?) | C1 U5 R4 E1 UL1 Leg1 Trứng1 Sp1 | Water 5, Field 3, Poison 3 | food 3, knight 2, cat 1 | 7/5/4 |
| Y tế & cứu hộ | `medic` | Hệ | 14 (+5?) | C1 U1 R1 E3 UL1 Unq5 Leg2 | Fairy 6, Normal 4, Field 3 | myth 4, family 2, food 2 | 7/3/5 |
| Kẻ gian & lưu manh | `rogue` | Hệ | 14 (+4?) | U4 R4 E2 UL1 Unq3 | Dark 11, Field 3, Ghost 3 | treasure 3, cat 2, bear 1 | 3/5/4 |
| Nguỵ trang & ảo ảnh | `disguise` | Đồ vật & thế giới | 13 (+3?) | U4 R4 E1 Unq3 Leg1 | Bug 3, Flora 3, Fairy 2 | folklore 3, fox 2, reptile 1 | 4/3/3 |
| Nông trại | `farm` | Hệ | 13 (+11?) | C2 U4 R1 E2 Unq2 Leg1 Sp1 | Field 8, Normal 6, Gourmet 4 | food 4, goat 3, transport 3 | 2/6/5 |
| Sa mạc & Ai Cập cổ | `desert` | Truyền thuyết & văn hoá | 12 (+1?) | U1 R4 E4 Unq2 Trứng1 | Ground 6, Dark 3, Normal 3 | relic 2, reptile 2, artist 1 | 4/2/3 |
| Lễ hội & mùa | `festival` | Truyền thuyết & văn hoá | 12 (+6?) | R4 E3 Unq4 Leg1 | Grass 6, Light 4, Normal 4 | deer 4, object 1, space 1 | 0/4/4 |
| Xạ thủ & pháo thủ | `gunner` | Hệ | 12 (+2?) | C1 R2 UL1 Unq2 Leg3 Trứng3 | Fire 4, Ghost 4, Water 4 | ninja 2, crab 1, family 1 | 4/7/1 |
| Thành phố & ô nhiễm | `urban` | Đồ vật & thế giới | 12 (+4?) | C3 U4 R1 E1 Unq3 | Poison 5, Artificial 4, Amorphous 3 | object 3, rodent 2, dog 1 | 2/1/8 |
| Pháp sư & phù thuỷ | `magic` | Hệ | 11 (+1?) | C2 U2 R1 E5 Trứng1 | Psychic 8, Human 5, Dark 3 | cat 2, artist 1, dream 1 | 4/4/4 |
| Thằn lằn & cá sấu | `reptile` | Tộc | 11 | C1 U2 R2 E2 UL1 Unq2 Trứng1 | Fire 3, Monster 3, Aquatic 2 | desert 2, transport 2, disguise 1 | 6/5/2 |
| Kho báu & đá quý | `treasure` | Đồ vật & thế giới | 11 (+2?) | R4 E2 Unq5 | Psychic 4, Dark 3, Ghost 3 | rogue 3, object 2, space 2 | 2/4/4 |
| Gia đình & bảo mẫu | `family` | Hệ | 10 (+3?) | U1 E1 UL1 Unq6 Trứng1 | Normal 7, Dragon 2, Fairy 2 | medic 2, food 1, gunner 1 | 3/5/4 |
| Chim săn mồi & quạ | `raptor` | Tộc | 10 (+2?) | C2 U2 R2 E1 UL1 Unq1 Trứng1 | Flying 10, Dark 2, Normal 2 | gunner 1, knight 1, magic 1 | 2/4/2 |
| Mèo | `cat` | Tộc | 9 | C1 U4 R3 E1 | Dark 5, Field 5, Normal 4 | magic 2, rogue 2, tiger 2 | 2/4/1 |
| Giấc ngủ & giấc mơ | `dream` | Truyền thuyết & văn hoá | 9 (+3?) | U2 R1 E3 Unq1 Leg2 | Normal 4, Psychic 4, Amorphous 2 | folklore 2, myth 2, bear 1 | 1/3/2 |
| Ham ăn | `glutton` | Đồ vật & thế giới | 9 (+1?) | U2 R1 E2 Unq3 Leg1 | Gourmet 6, Dark 3, Monster 3 | rodent 2, dream 1, gunner 1 | 0/1/6 |
| Đào mỏ | `miner` | Hệ | 9 (+2?) | U3 R3 E2 Unq1 | Ground 6, Rock 4, Steel 4 | worker 2, farm 1, medic 1 | 3/3/2 |
| Cua, tôm & giáp xác | `crab` | Tộc | 8 (+1?) | U3 R3 E2 | Water 4, Bug 3, Aquatic 2 | gunner 1, knight 1, rogue 1 | 2/2/2 |
| Thú biển | `sea_mammal` | Tộc | 8 | U3 E3 Unq1 Trứng1 | Water 5, Field 4, Aquatic 3 | artist 1, knight 1, medic 1 | 3/2/2 |
| Gấu & gấu trúc | `bear` | Tộc | 7 | R1 E2 UL1 Unq3 | Fighting 3, Normal 3, Dark 2 | artist 1, dream 1, rogue 1 | 2/3/3 |
| Hươu nai | `deer` | Tộc | 7 | R4 Unq1 Leg2 | Grass 5, Normal 4, Flora 2 | festival 4, guardian 1, knight 1 | 1/2/0 |
| Gà, vịt & gà lôi | `fowl` | Tộc | 7 (+1?) | U2 R1 E1 Unq2 Leg1 | Flying 5, Fighting 3, Aquatic 2 | artist 1, folklore 1, food 1 | 4/2/0 |
| Ninja & điệp viên | `ninja` | Hệ | 7 (+2?) | E2 UL1 Unq1 Leg1 Trứng2 | Flying 3, Aquatic 2, Bug 2 | gunner 2, frog 1, knight 1 | 2/3/2 |
| Rắn & mãng xà | `snake` | Tộc | 7 (+2?) | U1 R1 E1 Unq2 Leg1 Trứng1 | Ground 3, Poison 2, Amorphous 1 | desert 1, miner 1, myth 1 | 0/3/3 |
| Cáo | `fox` | Tộc | 6 | C1 U2 R3 | Dark 2, Field 2, Fire 2 | folklore 4, disguise 2, magic 1 | 2/2/2 |
| Ngựa | `horse` | Tộc | 6 (+2?) | E3 Leg3 | Field 4, Aquatic 1, Fairy 1 | transport 3, farm 1, knight 1 | 2/0/3 |
| Khỉ & vượn | `monkey` | Tộc | 6 (+1?) | C1 U1 E1 UL1 Unq1 Leg1 | Fighting 3, Human 2, Wild 2 | sport 2, artist 1, folklore 1 | 3/3/3 |
| Nhện & bọ cạp | `spider` | Tộc | 6 | U3 R1 E2 | Bug 5, Poison 3, Amorphous 1 | desert 1 | 1/2/2 |
| Chim biển & cánh cụt | `waterbird` | Tộc | 6 | U1 E3 Unq2 | Flying 4, Aquatic 3, Ice 2 | fowl 1, glutton 1, gunner 1 | 2/1/1 |
| Lao động & xây dựng | `worker` | Hệ | 6 | U2 R2 E1 UL1 | Fighting 2, Ground 2, Human 2 | miner 2, rabbit 1, rodent 1 | 2/4/1 |
| Voi & thú khổng lồ | `elephant` | Tộc | 5 | C1 R1 E1 UL1 Unq1 | Ground 5, Baby 1, Fighting 1 | desert 1, pig 1, transport 1 | 3/3/3 |
| Ếch & nòng nọc | `frog` | Tộc | 5 (+1?) | C1 R2 Trứng2 | Aquatic 5, Fighting 2, Sound 2 | ninja 1, royal 1, sport 1 | 1/2/3 |
| Rùa | `turtle` | Tộc | 5 | C1 R2 Unq2 | Fire 2, Ground 2, Monster 2 | gunner 1, weather 1 | 1/3/1 |
| Lợn | `pig` | Tộc | 4 (+1?) | C1 U1 R1 Trứng1 | Field 2, Fighting 1, Fire 1 | elephant 1, farm 1, food 1 | 1/1/4 |
| Thỏ | `rabbit` | Tộc | 4 (+2?) | C1 R2 Trứng1 | Normal 2, Baby 1, Fairy 1 | miner 1, rodent 1, sport 1 | 2/1/2 |
| Hổ, báo, sư tử | `tiger` | Tộc | 4 (+2?) | U1 E1 UL1 Leg1 | Field 4, Dark 2, Electric 2 | cat 2, myth 1, rogue 1 | 1/2/2 |
| Dơi | `bat` | Tộc | 3 (+1?) | C1 U2 | Flying 3, Sound 3, Dragon 1 |  | 1/2/0 |
| Dê & cừu | `goat` | Tộc | 3 | C1 U1 E1 | Field 3, Electric 1, Grass 1 | farm 3, transport 1 | 1/2/1 |
| Bạch tuộc & mực | `octopus` | Tộc | 3 | U2 E1 | Amorphous 2, Aquatic 2, Dark 1 | magic 1, sport 1 | 1/0/2 |
| Trâu bò | `bovine` | Tộc | 2 (+1?) | Unq2 | Field 2, Normal 2, Fighting 1 | farm 2, food 1, medic 1 | 0/2/0 |

## 4. Từng điểm chung

### Tộc — con vật gốc

#### Chuột & gặm nhấm — `rodent` (17 (+1?))

*Rodents* — Tý — chuột, sóc, hamster, hải ly, sinsila

- Common: Alolan Rattata (Wild/Dark), Azurill (Water/Fairy/Baby), Pichu (Electric/Fairy/Baby/Psychic/Fighting/Aquatic), Rattata (Wild/Normal)
- Uncommon: Bidoof (Normal/Aquatic), Minccino (Normal/Field/Sound)
- Rare: Patrat (Normal/Light), Pawmi (Electric/Fighting), Skwovet (Normal/Gourmet)
- Unique: Dedenne (Electric/Fairy), Emolga (Electric/Flying), Minun (Electric/Field), Morpeko (Dark/Electric), Pachirisu (Electric/Normal), Plusle (Electric/Field), Tandemaus (Normal/Fairy), Togedemaru (Electric/Steel)
- *Gần đúng*: Cyndaquil

#### Chó & sói — `dog` (16)

*Dogs & wolves* — Tuất — chó, sói, linh cẩu, chó rừng

- Common: Lillipup (Normal/Field)
- Uncommon: Greavard (Ghost/Rock/Field), Growlithe (Fire/Field), Hisuian Growlithe (Fire/Rock/Field), Yamper (Electric/Field)
- Rare: Electrike (Electric/Field), Fidough (Gourmet/Fairy/Field), Poochyena (Wild/Dark), Riolu (Fighting/Steel/Baby)
- Epic: Houndour (Fire/Dark), Rockruff (Wild/Rock/Light/Fire/Dark), Snubbull (Fairy/Field)
- Unique: Furfrou (Normal/Field), Smeargle (Normal/Human)
- Legendary: Okidogi (Wild/Fighting/Poison), Zacian (Wild/Fairy/Steel)

#### Thằn lằn & cá sấu — `reptile` (11)

*Lizards & crocodiles* — thằn lằn, tắc kè, cá sấu, kỳ nhông

- Common: Charmander (Dragon/Fire/Flying)
- Uncommon: Scraggy (Dark/Fighting), Treecko (Grass/Monster)
- Rare: Salandit (Fire/Poison), Totodile (Water/Monster/Aquatic)
- Epic: Fuecoco (Fire/Sound/Ghost), Helioptile (Normal/Electric/Light)
- Ultra: Sobble (Water/Aquatic)
- Unique: Cyclizar (Dragon/Normal), Kecleon ()
- Hatch: Sandile (Dark/Ground/Monster)

#### Chim săn mồi & quạ — `raptor` (10 (+2?))

*Birds of prey* — ưng, đại bàng, cú, quạ, kền kền, chim cắt

- Common: Spearow (Wild/Flying), Starly (Normal/Flying)
- Uncommon: Hoothoot (Normal/Flying/Psychic), Rufflet (Wild/Flying)
- Rare: Rookidee (Steel/Flying), Vullaby (Dark/Flying)
- Epic: Murkrow (Dark/Flying)
- Ultra: Fletchling (Flying/Fire)
- Unique: Skarmory (Steel/Flying)
- Hatch: Rowlet (Grass/Flying/Ghost)
- *Gần đúng*: Pidgey, Taillow

#### Mèo — `cat` (9)

*Cats* — Mão (12 con giáp Việt dùng mèo thay thỏ)

- Common: Sprigatito (Grass/Flora/Dark)
- Uncommon: Espurr (Wild/Psychic/Field), Glameow (Normal/Dark), Purrloin (Dark/Field), Skitty (Normal/Fairy/Field)
- Rare: Alolan Meowth (Normal/Dark), Galarian Meowth (Steel/Wild), Meowth (Normal/Field)
- Epic: Litten (Fire/Dark/Field)

#### Cua, tôm & giáp xác — `crab` (8 (+1?))

*Crustaceans* — cua, tôm, tôm hùm, hà, bọ biển

- Uncommon: Anorith (Fossil/Bug/Aquatic), Corphish (Aquatic/Dark), Krabby (Water/Normal)
- Rare: Binacle (Rock/Water), Clauncher (Water/Sound), Crabrawler (Ice/Fighting/Monster)
- Epic: Dwebble (Bug/Rock), Wimpod (Bug/Water/Monster)
- *Gần đúng*: Kabuto

#### Thú biển — `sea_mammal` (8)

*Sea mammals* — cá voi, cá heo, hải cẩu, sư tử biển, rái cá

- Uncommon: Cetoddle (Ice/Sound/Field), Seel (Ice/Aquatic), Spheal (Aquatic/Ice)
- Epic: Buizel (Water/Aquatic/Field), Oshawott (Water/Field/Fighting/Dark), Wailmer (Water/Sound)
- Unique: Finizen (Water/Field)
- Hatch: Popplio (Water/Fairy/Sound)

#### Gấu & gấu trúc — `bear` (7)

*Bears & pandas* — gấu, gấu trúc, koala

- Rare: Pancham (Fighting/Dark)
- Epic: Cubchoo (Ice/Field/Aquatic), Stufful (Normal/Fighting)
- Ultra: Teddiursa (Wild/Ground)
- Unique: Komala (Normal/Sound/Grass), Kubfu (Fighting/Baby/Water/Dark), Spinda (Normal/Gourmet)

#### Hươu nai — `deer` (7)

*Deer* — hươu, nai, tuần lộc

- Rare: Deerling (Autumn) (Normal/Grass/Wild), Deerling (Spring) (Normal/Grass/Flora), Deerling (Summer) (Normal/Grass/Gourmet), Deerling (Winter) (Normal/Grass/Ice)
- Unique: Stantler (Wild/Psychic/Field)
- Legendary: Virizion (Grass/Fighting), Xerneas (Fairy/Light/Flora)

#### Gà, vịt & gà lôi — `fowl` (7 (+1?))

*Poultry* — Dậu — gia cầm

- Uncommon: Psyduck (Water/Psychic), Quaxly (Aquatic/Fighting/Flying)
- Rare: Torchic (Fire/Fighting/Flying)
- Epic: Ducklett (Aquatic/Flying/Sound)
- Unique: Farfetch'd (Flying/Gourmet/Normal), Galarian Farfetch'd (Flying/Gourmet/Fighting)
- Legendary: Fezandipiti (Poison/Fairy/Sound)
- *Gần đúng*: Pidove

#### Rắn & mãng xà — `snake` (7 (+2?))

*Snakes & serpents* — Tỵ — cả lươn, rồng thân rắn

- Uncommon: Ekans (Poison/Dark)
- Rare: Silicobra (Ground/Amorphous)
- Epic: Onix (Rock/Ground/Steel)
- Unique: Dunsparce (Normal/Ground/Bug), Seviper (Poison/Monster)
- Legendary: Rayquaza (Dragon/Flying)
- Hatch: Snivy (Grass/Field)
- *Gần đúng*: Tynamo, Wiglett

#### Cáo — `fox` (6)

*Foxes* — cáo (kitsune)

- Common: Fennekin (Fire/Psychic/Human)
- Uncommon: Hisuian Zorua (Normal/Ghost), Zorua (Dark/Field)
- Rare: Alolan Vulpix (Ice/Fairy), Nickit (Field/Dark), Vulpix (Fire/Psychic)

#### Ngựa — `horse` (6 (+2?))

*Horses* — Ngọ — ngựa, lừa, kỳ lân, ngựa con; gần đúng: cá ngựa

- Epic: Galarian Ponyta (Fairy/Psychic/Light), Mudbray (Ground/Field), Ponyta (Fire/Field)
- Legendary: Glastrier (Ice/Field), Keldeo (Aquatic/Fighting), Spectrier (Ghost/Field)
- *Gần đúng*: Cobalion, Horsea

#### Khỉ & vượn — `monkey` (6 (+1?))

*Monkeys & apes* — Thân

- Common: Chimchar (Fire/Fighting/Human)
- Uncommon: Aipom (Wild/Normal)
- Epic: Mankey (Wild/Fighting/Ghost)
- Ultra: Grookey (Sound/Grass)
- Unique: Passimian (Field/Fighting)
- Legendary: Munkidori (Poison/Psychic/Human)
- *Gần đúng*: Slakoth

#### Nhện & bọ cạp — `spider` (6)

*Arachnids* — nhện, bọ cạp

- Uncommon: Dewpider (Water/Bug/Amorphous), Spinarak (Wild/Bug/Poison), Tarountula (Bug/Normal)
- Rare: Joltik (Bug/Electric)
- Epic: Gligar (Ground/Poison/Flying), Skorupi (Dark/Bug/Poison)

#### Chim biển & cánh cụt — `waterbird` (6)

*Seabirds* — mòng biển, bồ nông, chim cốc, cánh cụt, thiên nga

- Uncommon: Piplup (Water/Ice/Steel)
- Epic: Ducklett (Aquatic/Flying/Sound), Wattrel (Flying/Electric), Wingull (Water/Flying)
- Unique: Cramorant (Flying/Aquatic), Eiscue (Ice Face) (Ice/Field/Aquatic)

#### Voi & thú khổng lồ — `elephant` (5)

*Giant mammals* — voi, ma mút, tê giác, hà mã, lạc đà

- Common: Swinub (Ground/Ice)
- Rare: Phanpy (Wild/Ground/Baby)
- Epic: Hippopotas (Ground/Normal)
- Ultra: Rhyhorn (Ground/Monster/Rock)
- Unique: Great Tusk (Ground/Fighting/Fossil)

#### Ếch & nòng nọc — `frog` (5 (+1?))

*Frogs* — ếch, cóc, nòng nọc

- Common: Poliwag (Water/Aquatic/Fighting/Sound)
- Rare: Croagunk (Poison/Fighting/Aquatic), Tadbulb (Electric/Light/Aquatic)
- Hatch: Froakie (Water/Aquatic/Dark), Tympole (Aquatic/Ground/Sound)
- *Gần đúng*: Bulbasaur

#### Rùa — `turtle` (5)

*Turtles* — rùa cạn, rùa biển

- Common: Squirtle (Water/Field)
- Rare: Chewtle (Aquatic/Rock/Monster), Turtwig (Grass/Ground/Monster)
- Unique: Torkoal (Fire/Ground), Turtonator (Dragon/Fire)

#### Lợn — `pig` (4 (+1?))

*Pigs* — Hợi — lợn, lợn rừng

- Common: Swinub (Ground/Ice)
- Uncommon: Lechonk (Normal/Field/Gourmet)
- Rare: Spoink (Psychic/Field)
- Hatch: Tepig (Wild/Fire/Fighting)
- *Gần đúng*: Mankey

#### Thỏ — `rabbit` (4 (+2?))

*Rabbits* — thỏ và Pokémon tai thỏ

- Common: Azurill (Water/Fairy/Baby)
- Rare: Buneary (Normal/Fighting), Bunnelby (Normal/Ground)
- Hatch: Scorbunny (Fire/Field/Human)
- *Gần đúng*: Nidoran ♀, Nidoran ♂

#### Hổ, báo, sư tử — `tiger` (4 (+2?))

*Big cats* — Dần — mèo lớn

- Uncommon: Purrloin (Dark/Field)
- Epic: Litten (Fire/Dark/Field)
- Ultra: Shinx (Electric/Field/Light)
- Legendary: Raikou (Wild/Electric/Field)
- *Gần đúng*: Entei, Zeraora

#### Dơi — `bat` (3 (+1?))

*Bats* — dơi

- Common: Zubat (Poison/Flying/Sound)
- Uncommon: Noibat (Dragon/Sound/Flying), Woobat (Flying/Sound/Psychic)
- *Gần đúng*: Gligar

#### Dê & cừu — `goat` (3)

*Goats & sheep* — Mùi

- Common: Mareep (Electric/Field/Light)
- Uncommon: Wooloo (Normal/Field)
- Epic: Skiddo (Grass/Field)

#### Bạch tuộc & mực — `octopus` (3)

*Cephalopods* — bạch tuộc, mực, ốc anh vũ

- Uncommon: Clobbopus (Aquatic/Amorphous/Fighting), Omanyte (Fossil/Water/Amorphous)
- Epic: Inkay (Dark/Psychic/Aquatic)

#### Trâu bò — `bovine` (2 (+1?))

*Cattle* — Sửu — bò, bò tót, trâu; ít họ, nên gộp vào "Nông trại" nếu muốn hệ to

- Unique: Miltank (Normal/Gourmet/Field), Tauros (Wild/Normal/Field/Water/Fighting/Fire)
- *Gần đúng*: Terrakion

### Hệ — vai trò / nghề

#### Vận chuyển — `transport` (23 (+7?))

*Transport* — chở người / hàng, Pokémon để cưỡi (Poké Ride), đưa thư, xe cộ

- Common: Charmander (Dragon/Fire/Flying), Lillipup (Normal/Field)
- Uncommon: Machop (Fighting/Human), Varoom (Steel/Artificial/Poison)
- Rare: Carvanha (Water/Dark), Drifloon (Ghost/Flying/Amorphous), Rookidee (Steel/Flying)
- Epic: Dratini (Dragon/Flying/Aquatic), Hisuian Sneasel (Poison/Fighting/Monster), Mudbray (Ground/Field), Skiddo (Grass/Field), Wingull (Water/Flying)
- Ultra: Rhyhorn (Ground/Monster/Rock), Teddiursa (Wild/Ground)
- Unique: Cyclizar (Dragon/Normal), Delibird (Ice/Flying/Gourmet), Dondozo (Water/Gourmet/Monster), Lapras (Aquatic/Ice/Sound), Mantyke (Baby/Water/Flying), Stantler (Wild/Psychic/Field), Tauros (Wild/Normal/Field/Water/Fighting/Fire)
- Legendary: Glastrier (Ice/Field), Spectrier (Ghost/Field)
- *Gần đúng*: Basculin (Blue Stripes), Basculin (Red Stripes), Basculin (White Stripes), Bergmite, Pidove, Ponyta, Rufflet

#### Hộ vệ & canh gác — `guardian` (21 (+3?))

*Guardians* — bảo vệ người khác, canh cổng, cảnh giới, thần hộ mệnh

- Common: Chespin (Grass/Fighting)
- Uncommon: Growlithe (Fire/Field), Hisuian Growlithe (Fire/Rock/Field)
- Rare: Golett (Ground/Artificial/Ghost), Patrat (Normal/Light), Sentret (Ground/Normal/Field), Shieldon (Rock/Fossil/Steel)
- Epic: Ralts (Psychic/Fairy/Human/Fighting)
- Unique: Absol (Wild/Dark), Furfrou (Normal/Field), Klefki (Steel/Fairy/Artificial), Sigilyph (Psychic/Flying/Fossil), Tapu Bulu (Grass/Fairy), Tapu Fini (Fairy/Water), Tapu Koko (Electric/Fairy), Tapu Lele (Psychic/Fairy)
- Legendary: Cobalion (Steel/Fighting), Lugia (Aquatic/Flying/Psychic/Dark), Terrakion (Rock/Fighting), Virizion (Grass/Fighting), Zygarde (10% Forme) (Dragon/Ground)
- *Gần đúng*: Aron, Finizen, Mime Jr.

#### Thể thao & võ thuật — `sport` (21)

*Athletes* — bóng đá, đấu vật, quyền anh, sumo, kung fu, yoga

- Common: Chimchar (Fire/Fighting/Human)
- Uncommon: Clobbopus (Aquatic/Amorphous/Fighting), Machop (Fighting/Human)
- Rare: Crabrawler (Ice/Fighting/Monster), Croagunk (Poison/Fighting/Aquatic), Makuhita (Fighting/Monster), Mienfoo (Fighting/Field), Pawmi (Electric/Fighting), Riolu (Fighting/Steel/Baby), Torchic (Fire/Fighting/Flying)
- Epic: Litten (Fire/Dark/Field), Meditite (Psychic/Human/Fighting)
- Unique: Hawlucha (Fighting/Flying/Human), Iron Hands (Fighting/Artificial/Electric), Kubfu (Fighting/Baby/Water/Dark), Passimian (Field/Fighting), Tyrogue (Fighting/Human/Baby)
- Legendary: Buzzwole (Bug/Fighting), Marshadow (Ghost/Fighting)
- Hatch: Scorbunny (Fire/Field/Human), Tepig (Wild/Fire/Fighting)

#### Hiệp sĩ & kiếm sĩ — `knight` (19 (+4?))

*Knights* — kiếm, giáo, giáp, samurai, lính

- Rare: Honedge (Ghost/Steel/Artificial), Rookidee (Steel/Flying)
- Epic: Jangmo-o (Dragon/Fighting/Sound), Karrablast (Bug/Steel), Oshawott (Water/Field/Fighting/Dark), Ralts (Psychic/Fairy/Human/Fighting), Wimpod (Bug/Water/Monster)
- Ultra: Pawniard (Dark/Steel)
- Unique: Charcadet (Fire/Baby/Psychic/Human/Ghost), Galarian Farfetch'd (Flying/Gourmet/Fighting), Scyther (Bug/Rock/Steel/Flying)
- Legendary: Cobalion (Steel/Fighting), Iron Valiant (Fighting/Fairy/Artificial), Kartana (Steel/Grass), Keldeo (Aquatic/Fighting), Terrakion (Rock/Fighting), Virizion (Grass/Fighting), Zacian (Wild/Fairy/Steel)
- Special: Falinks (Trooper) (Fighting/Steel)
- *Gần đúng*: Chespin, Frigibax, Galarian Meowth, Skarmory

#### Nghệ sĩ biểu diễn — `artist` (15 (+7?))

*Performers* — múa, kịch câm, vẽ, ca sĩ (âm nhạc thuần đã có hệ Sound)

- Common: Sprigatito (Grass/Flora/Dark)
- Uncommon: Mime Jr. (Fairy/Psychic/Baby/Human), Petilil (Grass/Flora/Human/Fighting), Quaxly (Aquatic/Fighting/Flying), Smoochum (Ice/Psychic/Baby/Human)
- Rare: Lotad (Grass/Aquatic/Sound), Toxel (Baby/Electric/Poison/Sound)
- Ultra: Grookey (Sound/Grass)
- Unique: Chatot (Flying/Sound), Maractus (Grass/Sound/Flora), Oricorio (Baile Style) (Flora/Sound/Fire/Psychic/Electric/Ghost), Smeargle (Normal/Human), Spinda (Normal/Gourmet)
- Legendary: Meloetta (Aria) (Normal/Sound/Fighting)
- Hatch: Popplio (Water/Fairy/Sound)
- *Gần đúng*: Comfey, Fuecoco, Galarian Zigzagoon, Kricketot, Sewaddle, Swablu, Tyrogue

#### Hoàng gia & thủ lĩnh — `royal` (15 (+3?))

*Royalty & bosses* — vua, hoàng hậu, hoàng đế, trùm

- Common: Poliwag (Water/Aquatic/Fighting/Sound)
- Uncommon: Horsea (Dragon/Water), Nidoran ♀ (Poison/Field/Ground), Nidoran ♂ (Poison/Field/Ground), Piplup (Water/Ice/Steel), Slowpoke (Psychic/Water)
- Rare: Alolan Meowth (Normal/Dark), Honedge (Ghost/Steel/Artificial), Salandit (Fire/Poison), Tyrunt (Dragon/Rock/Fossil)
- Epic: Bounsweet (Grass/Fighting/Gourmet)
- Ultra: Pawniard (Dark/Steel)
- Legendary: Manaphy (Water/Aquatic/Amorphous)
- Hatch: Snivy (Grass/Field)
- Special: Combee (Bug/Flora/Gourmet)
- *Gần đúng*: Furfrou, Goldeen, Krabby

#### Y tế & cứu hộ — `medic` (14 (+5?))

*Medic & rescue* — chữa lành, y tá, thuốc, cứu người gặp nạn

- Common: Lillipup (Normal/Field)
- Uncommon: Nacli (Rock/Gourmet)
- Rare: Paras (Bug/Poison/Grass)
- Epic: Buizel (Water/Aquatic/Field), Dratini (Dragon/Flying/Aquatic), Galarian Ponyta (Fairy/Psychic/Light)
- Ultra: Happiny (Normal/Fairy/Baby/Gourmet)
- Unique: Audino (Normal/Sound), Comfey (Flora/Fairy), Miltank (Normal/Gourmet/Field), Tapu Fini (Fairy/Water), Tapu Lele (Psychic/Fairy)
- Legendary: Ho-Oh (Fire/Flying/Light), Xerneas (Fairy/Light/Flora)
- *Gần đúng*: Cresselia, Delibird, Pawmi, Shuckle, Smoliv

#### Kẻ gian & lưu manh — `rogue` (14 (+4?))

*Rogues* — trộm, lừa đảo, côn đồ, chơi khăm

- Uncommon: Corphish (Aquatic/Dark), Impidimp (Dark/Fairy/Human), Purrloin (Dark/Field), Scraggy (Dark/Fighting)
- Rare: Galarian Zigzagoon (Wild/Dark/Sound), Meowth (Normal/Field), Nickit (Field/Dark), Pancham (Fighting/Dark)
- Epic: Murkrow (Dark/Flying), Sneasel (Ice/Dark/Monster)
- Ultra: Gastly (Ghost/Poison/Amorphous)
- Unique: Hoopa (Psychic/Dark/Ghost), Mawile (Steel/Fairy/Monster), Sableye (Dark/Ghost)
- *Gần đúng*: Basculin (Blue Stripes), Basculin (Red Stripes), Basculin (White Stripes), Carvanha

#### Nông trại — `farm` (13 (+11?))

*Farm* — gia súc, cây trồng, làm vườn, chăn nuôi

- Common: Mareep (Electric/Field/Light), Smoliv (Grass/Normal/Gourmet)
- Uncommon: Diglett (Ground/Normal), Lechonk (Normal/Field/Gourmet), Wooloo (Normal/Field), Yamper (Electric/Field)
- Rare: Sunkern (Grass/Light/Flora)
- Epic: Mudbray (Ground/Field), Skiddo (Grass/Field)
- Unique: Miltank (Normal/Gourmet/Field), Tauros (Wild/Normal/Field/Water/Fighting/Fire)
- Legendary: Landorus (Flying/Ground)
- Special: Combee (Bug/Flora/Gourmet)
- *Gần đúng*: Applin, Cacnea, Flabébé (Pink), Flabébé (Blue), Flabébé (Orange), Flabébé (White), Flabébé (Yellow), Gossifleur, Shaymin, Swinub, Tropius

#### Xạ thủ & pháo thủ — `gunner` (12 (+2?))

*Marksmen* — cung tên, súng nước, pháo, bắn từ xa

- Common: Squirtle (Water/Field)
- Rare: Clauncher (Water/Sound), Magby (Fire/Human/Baby)
- Ultra: Sobble (Water/Aquatic)
- Unique: Charcadet (Fire/Baby/Psychic/Human/Ghost), Cramorant (Flying/Aquatic)
- Legendary: Blacephalon (Fire/Ghost/Human), Genesect (Bug/Steel/Artificial), Volcanion (Fire/Water/Aquatic)
- Hatch: Dreepy (Dragon/Ghost), Grubbin (Bug/Electric), Rowlet (Grass/Flying/Ghost)
- *Gần đúng*: Alolan Geodude, Galarian Slowpoke

#### Pháp sư & phù thuỷ — `magic` (11 (+1?))

*Mages & witches* — phép thuật, thôi miên, bói toán, ảo thuật

- Common: Fennekin (Fire/Psychic/Human), Sprigatito (Grass/Flora/Dark)
- Uncommon: Espurr (Wild/Psychic/Field), Hatenna (Fairy/Psychic)
- Rare: Abra (Psychic/Human)
- Epic: Drowzee (Psychic/Human/Monster), Inkay (Dark/Psychic/Aquatic), Misdreavus (Ghost/Fairy/Amorphous), Murkrow (Dark/Flying), Ralts (Psychic/Fairy/Human/Fighting)
- Hatch: Gothita (Psychic/Human)
- *Gần đúng*: Natu

#### Gia đình & bảo mẫu — `family` (10 (+3?))

*Family & caretakers* — chăm con, nuôi trẻ, quản gia

- Uncommon: Sewaddle (Grass/Bug)
- Epic: Cubone (Ground/Ghost/Fire)
- Ultra: Happiny (Normal/Fairy/Baby/Gourmet)
- Unique: Audino (Normal/Sound), Drampa (Dragon/Normal), Indeedee ♀ (Normal/Psychic/Human), Indeedee ♂ (Normal/Psychic/Human), Kangaskhan (Fighting/Normal/Monster), Tandemaus (Normal/Fairy)
- Hatch: Dreepy (Dragon/Ghost)
- *Gần đúng*: Lillipup, Mime Jr., Togepi

#### Đào mỏ — `miner` (9 (+2?))

*Miners* — đào đường hầm, quặng, than, đá quý dưới đất

- Uncommon: Alolan Diglett (Ground/Steel), Diglett (Ground/Normal), Nacli (Rock/Gourmet)
- Rare: Bunnelby (Normal/Ground), Drilbur (Ground/Steel), Glimmet (Poison/Rock/Flora)
- Epic: Onix (Rock/Ground/Steel), Roggenrola (Rock/Light)
- Unique: Orthworm (Steel/Ground)
- *Gần đúng*: Aron, Sableye

#### Ninja & điệp viên — `ninja` (7 (+2?))

*Ninjas & spies* — ninja, sát thủ, điệp viên, ẩn mình

- Epic: Hisuian Sneasel (Poison/Fighting/Monster), Nincada (Bug/Flying)
- Ultra: Sobble (Water/Aquatic)
- Unique: Scyther (Bug/Rock/Steel/Flying)
- Legendary: Marshadow (Ghost/Fighting)
- Hatch: Froakie (Water/Aquatic/Dark), Rowlet (Grass/Flying/Ghost)
- *Gần đúng*: Shedinja, Sneasel

#### Lao động & xây dựng — `worker` (6)

*Workers* — khuân vác, xây dựng, thợ rèn

- Uncommon: Bidoof (Normal/Aquatic), Machop (Fighting/Human)
- Rare: Bunnelby (Normal/Ground), Drilbur (Ground/Steel)
- Epic: Tinkatink (Steel/Fairy)
- Ultra: Timburr (Fighting/Human)

### Truyền thuyết & văn hoá

#### Thần thoại & thần linh — `myth` (48 (+4?))

*Myths & deities* — thần sáng thế, thần thời tiết, thần hộ mệnh (phần lớn là Legendary)

- Epic: Larvesta (Fire/Bug)
- Unique: Azelf (Psychic/Fairy), Cosmog (Psychic/Light/Ghost/Steel), Hoopa (Psychic/Dark/Ghost), Latias (Dragon/Psychic), Latios (Dragon/Psychic), Mesprit (Psychic/Fairy), Tapu Bulu (Grass/Fairy), Tapu Fini (Fairy/Water), Tapu Koko (Electric/Fairy), Tapu Lele (Psychic/Fairy), Uxie (Psychic/Fairy)
- Legendary: Arceus (), Articuno (Ice/Flying), Celebi (Grass/Psychic/Flora), Chi-Yu (Fire/Dark), Cresselia (Psychic/Fairy/Light), Darkrai (Dark/Ghost/Amorphous), Dialga (Dragon/Steel), Enamorus (Flying/Fairy), Entei (Wild/Fire/Field), Giratina (Dragon/Ghost), Groudon (Ground/Monster/Fire), Ho-Oh (Fire/Flying/Light), Kyogre (Water/Monster/Electric), Kyurem (Dragon/Ice), Landorus (Flying/Ground), Lugia (Aquatic/Flying/Psychic/Dark), Manaphy (Water/Aquatic/Amorphous), Meloetta (Aria) (Normal/Sound/Fighting), Mew (Psychic/Amorphous), Moltres (Fire/Flying), Palkia (Dragon/Water), Raikou (Wild/Electric/Field), Rayquaza (Dragon/Flying), Regigigas (Normal/Human/Fossil), Reshiram (Dragon/Fire), Shaymin (Grass/Flora/Flying), Suicune (Wild/Water/Field), Thundurus (Flying/Electric), Tornadus (Flying/Ice), Victini (Fire/Psychic), Xerneas (Fairy/Light/Flora), Yveltal (Dark/Flying), Zacian (Wild/Fairy/Steel), Zapdos (Electric/Flying), Zekrom (Dragon/Electric), Zygarde (10% Forme) (Dragon/Ground)
- *Gần đúng*: Deino, Houndour, Turtwig, Zeraora

#### Truyện cổ & yêu quái — `folklore` (26 (+7?))

*Folklore* — yêu quái Nhật, truyện cổ châu Á (kitsune, tengu, kappa, Momotarō...)

- Common: Seedot (Grass/Dark)
- Uncommon: Duskull (Dark/Ghost), Hisuian Zorua (Normal/Ghost), Zorua (Dark/Field)
- Rare: Alolan Vulpix (Ice/Fairy), Bronzor (Steel/Psychic/Sound), Lotad (Grass/Aquatic/Sound), Munna (Psychic/Field/Amorphous), Phantump (Ghost/Grass/Monster), Vulpix (Fire/Psychic)
- Epic: Barboach (Water/Ground), Darumaka (Wild/Fire/Psychic), Drowzee (Psychic/Human/Monster), Galarian Darumaka (Wild/Ice/Fire), Snorunt (Ghost/Ice)
- Unique: Chingling (Sound/Psychic/Baby), Spiritomb (Rock/Ghost/Amorphous)
- Legendary: Celesteela (Steel/Flying/Grass), Chi-Yu (Fire/Dark), Fezandipiti (Poison/Fairy/Sound), Munkidori (Poison/Psychic/Human), Ogerpon Teal (Grass/Rock/Fire/Flora/Aquatic), Okidogi (Wild/Fighting/Poison), Pecharunt (Poison/Ghost/Gourmet), Thundurus (Flying/Electric), Tornadus (Flying/Ice)
- *Gần đúng*: Castform, Chimchar, Elekid, Growlithe, Hisuian Growlithe, Shedinja, Shuppet

#### Vũ trụ & ngoài hành tinh — `space` (21 (+1?))

*Space & aliens* — thiên thạch, sao, người ngoài hành tinh, Ultra Beast

- Uncommon: Cleffa (Fairy/Normal/Baby/Light)
- Rare: Elgyem (Psychic/Monster/Light), Staryu (Water/Psychic)
- Unique: Cosmog (Psychic/Light/Ghost/Steel), Lunatone (Rock/Psychic/Dark), Minior (Flying/Rock), Poipole (Poison/Bug/Dragon), Solrock (Rock/Fire/Light)
- Legendary: Blacephalon (Fire/Ghost/Human), Buzzwole (Bug/Fighting), Celesteela (Steel/Flying/Grass), Deoxys (Psychic/Amorphous/Human), Eternatus (Dragon/Poison/Fossil), Guzzlord (Gourmet/Dark/Monster), Jirachi (Steel/Psychic/Sound), Kartana (Steel/Grass), Necrozma (Light/Psychic/Dragon), Nihilego (Poison/Rock/Amorphous), Pheromosa (Bug/Fighting), Stakataka (Rock/Steel), Xurkitree (Electric/Artificial/Light)
- *Gần đúng*: Porygon

#### Cổ vật & di tích — `relic` (17 (+4?))

*Relics & ruins* — tượng cổ, đồ đồng, phế tích, hoá thạch sống

- Uncommon: Nosepass (Rock/Steel/Electric)
- Rare: Bronzor (Steel/Psychic/Sound), Galarian Yamask (Ghost/Monster), Golett (Ground/Artificial/Ghost), Yamask (Ghost/Human)
- Epic: Baltoy (Ground/Psychic/Artificial)
- Unique: Relicanth (Rock/Water/Fossil), Sigilyph (Psychic/Flying/Fossil), Spiritomb (Rock/Ghost/Amorphous), Stonjourner (Rock/Ground/Light)
- Legendary: Magearna (Steel/Fairy/Artificial), Regice (Ice/Human/Fossil), Regidrago (Dragon/Fossil/Monster), Regieleki (Electric/Human/Amorphous), Regigigas (Normal/Human/Fossil), Regirock (Rock/Human/Fossil), Registeel (Steel/Human/Fossil)
- *Gần đúng*: Dhelmise, Hisuian Voltorb, Natu, Sinistea

#### Sa mạc & Ai Cập cổ — `desert` (12 (+1?))

*Desert & ancient Egypt* — sa mạc, xương rồng, quan tài, kim tự tháp

- Uncommon: Sandshrew (Ground/Normal)
- Rare: Cacnea (Grass/Dark/Human), Silicobra (Ground/Amorphous), Trapinch (Bug/Ground/Dragon), Yamask (Ghost/Human)
- Epic: Helioptile (Normal/Electric/Light), Hippopotas (Ground/Normal), Numel (Fire/Field/Ground), Skorupi (Dark/Bug/Poison)
- Unique: Maractus (Grass/Sound/Flora), Sigilyph (Psychic/Flying/Fossil)
- Hatch: Sandile (Dark/Ground/Monster)
- *Gần đúng*: Larvesta

#### Lễ hội & mùa — `festival` (12 (+6?))

*Festivals & seasons* — Giáng sinh, Halloween, hoa anh đào, đom đóm, bốn mùa

- Rare: Deerling (Autumn) (Normal/Grass/Wild), Deerling (Spring) (Normal/Grass/Flora), Deerling (Summer) (Normal/Grass/Gourmet), Deerling (Winter) (Normal/Grass/Ice)
- Epic: Cherubi (Flora/Light/Gourmet), Pumpkaboo (Ghost/Grass/Light), Snover (Grass/Ice/Monster)
- Unique: Delibird (Ice/Flying/Gourmet), Illumise (Bug/Light/Flying), Luvdisc (Water/Aquatic), Volbeat (Bug/Light/Flying)
- Legendary: Jirachi (Steel/Psychic/Sound)
- *Gần đúng*: Chingling, Cleffa, Enamorus, Litwick, Scatterbug, Stantler

#### Giấc ngủ & giấc mơ — `dream` (9 (+3?))

*Sleep & dreams* — ngủ, lười, ăn giấc mơ, ác mộng

- Uncommon: Igglybuff (Normal/Fairy/Baby/Sound), Slowpoke (Psychic/Water)
- Rare: Munna (Psychic/Field/Amorphous)
- Epic: Drowzee (Psychic/Human/Monster), Munchlax (Normal/Gourmet/Baby/Monster), Slakoth (Normal/Field)
- Unique: Komala (Normal/Sound/Grass)
- Legendary: Cresselia (Psychic/Fairy/Light), Darkrai (Dark/Ghost/Amorphous)
- *Gần đúng*: Bagon, Galarian Slowpoke, Shroomish

### Đồ vật & thế giới

#### Đồ vật sống — `object` (22 (+1?))

*Living objects* — đồ vật có hồn: nến, ấm trà, chìa khoá, búp bê, gương...

- Common: Klink (Steel/Artificial), Litwick (Ghost/Fire/Light)
- Uncommon: Hisuian Voltorb (Electric/Grass/Fossil), Sandygast (Ghost/Ground/Amorphous), Sinistea (Ghost/Artificial/Gourmet), Varoom (Steel/Artificial/Poison), Voltorb (Electric/Artificial)
- Rare: Bronzor (Steel/Psychic/Sound), Drifloon (Ghost/Flying/Amorphous), Honedge (Ghost/Steel/Artificial), Vanillite (Ice/Amorphous/Gourmet)
- Epic: Baltoy (Ground/Psychic/Artificial), Pumpkaboo (Ghost/Grass/Light), Shuppet (Ghost/Artificial), Trubbish (Poison/Artificial)
- Unique: Chingling (Sound/Psychic/Baby), Dhelmise (Grass/Ghost/Steel), Gimmighoul (Ghost/Steel), Klefki (Steel/Fairy/Artificial), Rotom (Electric/Artificial/Ghost/Light/Flying/Ice/Fire/Grass/Water)
- Legendary: Magearna (Steel/Fairy/Artificial), Stakataka (Rock/Steel)
- *Gần đúng*: Magnemite

#### Thời tiết & thiên tai — `weather` (19 (+3?))

*Weather & disasters* — gọi mưa / nắng / bão, báo thiên tai

- Rare: Larvitar (Dark/Monster/Rock)
- Epic: Barboach (Water/Ground), Hippopotas (Ground/Normal), Snover (Grass/Ice/Monster), Wattrel (Flying/Electric)
- Unique: Absol (Wild/Dark), Castform (Artificial/Amorphous/Ice/Water/Fire), Cryogonal (Ice/Amorphous), Torkoal (Fire/Ground)
- Legendary: Articuno (Ice/Flying), Groudon (Ground/Monster/Fire), Kyogre (Water/Monster/Electric), Landorus (Flying/Ground), Lugia (Aquatic/Flying/Psychic/Dark), Raikou (Wild/Electric/Field), Rayquaza (Dragon/Flying), Thundurus (Flying/Electric), Tornadus (Flying/Ice), Zapdos (Electric/Flying)
- *Gần đúng*: Alolan Vulpix, Tapu Koko, Wingull

#### Món ăn — `food` (18 (+5?))

*Food* — Pokémon trông như món ăn / nguyên liệu (khác hệ Gourmet = đầu bếp)

- Common: Smoliv (Grass/Normal/Gourmet)
- Uncommon: Capsakid (Grass/Fire/Gourmet), Lechonk (Normal/Field/Gourmet), Sinistea (Ghost/Artificial/Gourmet), Slowpoke (Psychic/Water)
- Rare: Fidough (Gourmet/Fairy/Field), Swirlix (Fairy/Gourmet), Vanillite (Ice/Amorphous/Gourmet)
- Epic: Bounsweet (Grass/Fighting/Gourmet), Exeggcute (Flora/Psychic/Dragon)
- Ultra: Happiny (Normal/Fairy/Baby/Gourmet)
- Unique: Applin (Dragon/Gourmet/Grass), Farfetch'd (Flying/Gourmet/Normal), Milcery (Fairy/Amorphous/Gourmet), Miltank (Normal/Gourmet/Field), Shuckle (Bug/Rock/Gourmet), Tropius (Grass/Gourmet/Flying)
- Special: Combee (Bug/Flora/Gourmet)
- *Gần đúng*: Cherubi, Cutiefly, Nacli, Paras, Sunkern

#### Nguỵ trang & ảo ảnh — `disguise` (13 (+3?))

*Disguise & illusion* — giả dạng, đổi màu, ảo ảnh

- Uncommon: Hisuian Zorua (Normal/Ghost), Skrelp (Poison/Water/Dragon), Wiglett (Ground/Water), Zorua (Dark/Field)
- Rare: Burmy (Plant) (Bug/Grass/Flying), Burmy (Sandy) (Bug/Ground), Burmy (Trash) (Bug/Artificial), Fomantis (Flora/Light/Fighting)
- Epic: Bonsly (Rock/Flora/Baby/Monster)
- Unique: Kecleon (), Mawile (Steel/Fairy/Monster), Mimikyu (Ghost/Fairy/Amorphous)
- Legendary: Ogerpon Teal (Grass/Rock/Fire/Flora/Aquatic)
- *Gần đúng*: Chatot, Dhelmise, Latias

#### Thành phố & ô nhiễm — `urban` (12 (+4?))

*City & pollution* — sống quanh người, rác, khí thải, nhà máy

- Common: Alolan Rattata (Wild/Dark), Pidove (Normal/Flying), Rattata (Wild/Normal)
- Uncommon: Alolan Grimer (Poison/Dark/Amorphous), Grimer (Poison/Monster/Amorphous), Koffing (Poison/Artificial/Amorphous/Fairy), Varoom (Steel/Artificial/Poison)
- Rare: Galarian Zigzagoon (Wild/Dark/Sound)
- Epic: Trubbish (Poison/Artificial)
- Unique: Duraludon (Dragon/Steel/Electric), Furfrou (Normal/Field), Rotom (Electric/Artificial/Ghost/Light/Flying/Ice/Fire/Grass/Water)
- *Gần đúng*: Dedenne, Magnemite, Nickit, Voltorb

#### Kho báu & đá quý — `treasure` (11 (+2?))

*Treasure & gems* — vàng, tiền xu, ngọc trai, đá quý

- Rare: Glimmet (Poison/Rock/Flora), Meowth (Normal/Field), Spoink (Psychic/Field), Staryu (Water/Psychic)
- Epic: Carbink (Fossil/Rock/Fairy), Clamperl (Fossil/Water/Psychic/Dark)
- Unique: Gimmighoul (Ghost/Steel), Hoopa (Psychic/Dark/Ghost), Klefki (Steel/Fairy/Artificial), Minior (Flying/Rock), Sableye (Dark/Ghost)
- *Gần đúng*: Alolan Diglett, Zigzagoon

#### Ham ăn — `glutton` (9 (+1?))

*Big eaters* — ăn không ngừng, nuốt mọi thứ

- Uncommon: Alolan Grimer (Poison/Dark/Amorphous), Lickitung (Wild/Normal/Gourmet)
- Rare: Skwovet (Normal/Gourmet)
- Epic: Gulpin (Poison/Gourmet/Amorphous), Munchlax (Normal/Gourmet/Baby/Monster)
- Unique: Cramorant (Flying/Aquatic), Dondozo (Water/Gourmet/Monster), Morpeko (Dark/Electric)
- Legendary: Guzzlord (Gourmet/Dark/Monster)
- *Gần đúng*: Alolan Rattata

## 5. Từng họ Pokémon (thông tin nền)

Hệ = hệ trong game (gộp mọi dạng). Mùa = mùa có họ đó (`data/seasons.json`). Điểm chung in nghiêng là gần đúng.

### Common (31 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Alolan Geodude → Alolan Graveler → Alolan Golem** | Rock / Megaton | Electric, Rock | s2, s3 | *Xạ thủ & pháo thủ* | Geodude vùng Alola: đá nhiễm từ, có "râu" bằng cát sắt; Golem Alola bắn đá tích điện như súng ray. |
| **Alolan Rattata → Alolan Raticate** | Mouse | Wild, Dark | s2 | Chuột & gặm nhấm, Thành phố & ô nhiễm, *Ham ăn* | Chuột cống Alola sống về đêm theo đàn; Raticate Alola béo vì chỉ ăn đồ ngon lấy của người. |
| **Aron → Lairon → Aggron** | Iron Armor | Steel, Monster, Rock | s1, s2, s3 | *Đào mỏ*, *Hộ vệ & canh gác* | Ấu trùng giáp sắt, gặm quặng sắt (có khi cả đường ray); Aggron coi cả ngọn núi là lãnh thổ và giữ gìn nó. |
| **Azurill → Marill → Azumarill** | Polka Dot / Aqua Mouse / Aqua Rabbit | Water, Fairy, Baby | s1, s2, s3 | Chuột & gặm nhấm, Thỏ | Chuột - thỏ nước: đuôi như quả bóng nảy; Marill, Azumarill (Aqua Rabbit) tai dài như thỏ. |
| **Blipbug → Dottler → Orbeetle** | Larva / Radome / Seven Spot | Bug, Psychic, Flying | s3 |  | Ấu trùng bọ cánh cứng; Dottler như vòm radar, Orbeetle là bọ rùa 7 chấm có siêu năng lực rất mạnh. |
| **Caterpie → Metapod → Butterfree** | Worm / Cocoon / Butterfly | Bug, Amorphous, Flying | s3 |  | Sâu xanh → nhộng → bướm trắng Butterfree, rắc phấn gây ngủ / tê liệt. |
| **Charmander → Charmeleon → Charizard** | Lizard / Flame | Dragon, Fire, Flying | s1, s2, s3 | Thằn lằn & cá sấu, Vận chuyển | Thằn lằn lửa, ngọn lửa đuôi là sinh mệnh; Charizard bay chở người (Poké Ride Charizard Glide ở Alola). |
| **Chespin → Quilladin → Chesnaught** | Spiny Nut / Spiny Armor | Grass, Fighting | s1, s2 | Hộ vệ & canh gác, *Hiệp sĩ & kiếm sĩ* | Nhím / sóc gai (Spiny Nut); Chesnaught có giáp gai như khiên, đứng chắn đòn cho đồng đội. |
| **Chimchar → Monferno → Infernape** | Chimp / Playful / Flame | Fire, Fighting, Human | s2, s3 | Khỉ & vượn, Thể thao & võ thuật, *Truyện cổ & yêu quái* | Khỉ lửa; Infernape đánh võ, lấy cảm hứng Tôn Ngộ Không (Tây Du Ký). |
| **Fennekin → Braixen → Delphox** | Fox | Fire, Psychic, Human | s1, s2 | Cáo, Pháp sư & phù thuỷ | Cáo lửa; Braixen cầm cành cây như đũa phép, Delphox là phù thuỷ / pháp sư lửa. |
| **Geodude → Graveler → Golem** | Rock / Megaton | Ground, Rock | s1 |  | Tảng đá có tay sống ở núi; Golem (Megaton) như mai rùa đá, lăn xuống dốc. |
| **Goomy → Hisuian Sliggoo / Sliggoo → Goodra / Hisuian Goodra** | Soft Tissue / Dragon | Dragon, Aquatic, Amorphous, Steel | s1, s3 |  | Rồng nhầy (Soft Tissue) giống ốc sên trần; Goodra rất hiền, hay ôm người. Có dạng Hisui (vỏ kim loại). |
| **Klink → Klang → Klinklang** | Gear | Steel, Artificial | s1, s2, s3 | Đồ vật sống | Bánh răng sống (Gear): hai bánh ăn khớp, Klinklang thêm bánh thứ ba. |
| **Lillipup → Herdier → Stoutland** | Puppy / Loyal Dog / Big-Hearted | Normal, Field | s1 | Chó & sói, Y tế & cứu hộ, Vận chuyển, *Gia đình & bảo mẫu* | Chó con → Herdier (Loyal Dog) → Stoutland: chó cứu hộ trên núi / biển, giỏi trông trẻ; Poké Ride đánh hơi đồ (Alola). |
| **Litwick → Lampent → Chandelure** | Candle / Lamp / Luring | Ghost, Fire, Light | s2, s3 | Đồ vật sống, *Lễ hội & mùa* | Nến (Candle) → đèn lồng (Lamp) → đèn chùm Chandelure: ngọn lửa hút linh hồn. |
| **Mareep → Flaaffy → Ampharos** | Wool / Light | Electric, Field, Light | s1, s2, s3 | Dê & cừu, Nông trại | Cừu điện (Wool): lông tích điện; Ampharos có đuôi sáng như đèn hải đăng dẫn tàu. |
| **Mudkip → Marshtomp → Swampert** | Mud Fish | Water, Ground | s3 |  | Kỳ nhông axolotl / cá thòi lòi (Mud Fish); Swampert khoẻ kéo được tảng đá, báo bão. |
| **Pichu → Pikachu → Alolan Raichu / Libre Pikachu / Surfing Pikachu / Raichu** | Tiny Mouse / Mouse | Electric, Fairy, Baby, Psychic, Fighting, Aquatic | s1, s2, s3 | Chuột & gặm nhấm | Chuột điện: Pichu → Pikachu (linh vật Pokémon) → Raichu; Raichu Alola lướt sóng trên đuôi. |
| **Pidgey → Pidgeotto → Pidgeot** | Tiny Bird / Bird | Normal, Flying | s2 | *Chim săn mồi & quạ* | Chim nhỏ đồng quê (Tiny Bird); Pidgeot như chim ưng bay rất nhanh. |
| **Pidove → Tranquill → Unfezant** | Tiny Pigeon / Wild Pigeon / Proud | Normal, Flying | s3 | Thành phố & ô nhiễm, *Gà, vịt & gà lôi*, *Vận chuyển* | Bồ câu thành phố; Tranquill nhớ đường về tổ như bồ câu đưa thư; Unfezant (Proud) như gà lôi. |
| **Poliwag → Poliwhirl → Politoed / Poliwrath** | Tadpole / Frog | Water, Aquatic, Fighting, Sound | s1, s3 | Ếch & nòng nọc, Hoàng gia & thủ lĩnh | Nòng nọc có bụng xoắn; Politoed là vua ếch (tóc xoăn), Poliwrath là võ sĩ bơi lội. |
| **Rattata → Raticate** | Mouse | Wild, Normal | s1 | Chuột & gặm nhấm, Thành phố & ô nhiễm | Chuột (Mouse) sống khắp nơi, gặm mọi thứ, sinh sôi nhanh. |
| **Seedot → Nuzleaf → Shiftry** | Acorn / Wily / Wicked | Grass, Dark | s3 | Truyện cổ & yêu quái | Hạt sồi (Acorn) → Nuzleaf → Shiftry: tengu (yêu quái núi Nhật), quạt lá tạo gió lốc. |
| **Smoliv → Dolliv → Arboliva** | Olive | Grass, Normal, Gourmet | s1, s2, s3 | Nông trại, Món ăn, *Y tế & cứu hộ* | Quả ô liu → Dolliv → Arboliva (cây ô liu): dầu quả bổ, chia cho Pokémon yếu. |
| **Spearow → Fearow** | Tiny Bird / Beak | Wild, Flying | s1 | Chim săn mồi & quạ | Chim sẻ dữ → Fearow (Beak) mỏ dài, bay xa. |
| **Sprigatito → Floragato → Meowscarada** | Grass Cat / Magician | Grass, Flora, Dark | s1, s2, s3 | Mèo, Pháp sư & phù thuỷ, Nghệ sĩ biểu diễn | Mèo cỏ (Grass Cat); Meowscarada là ảo thuật gia (Magician) biến hoá như diễn trò. |
| **Squirtle → Wartortle → Blastoise** | Tiny Turtle / Turtle / Shellfish | Water, Field | s2 | Rùa, Xạ thủ & pháo thủ | Rùa con (Tiny Turtle) → Wartortle → Blastoise có pháo nước trên mai. |
| **Starly → Staravia → Staraptor** | Starling / Predator | Normal, Flying | s2 | Chim săn mồi & quạ | Chim sáo đá (Starling) → Staraptor (Predator) dữ tợn. |
| **Swinub → Piloswine → Mamoswine** | Pig / Swine / Twin Tusk | Ground, Ice | s1, s2, s3 | Lợn, Voi & thú khổng lồ, *Nông trại* | Lợn rừng con → Piloswine → Mamoswine (ma mút, Twin Tusk); Swinub đào tìm nấm như lợn tìm nấm truffle. |
| **Weedle → Kakuna → Beedrill** | Hairy Bug / Cocoon / Poison Bee | Bug, Poison, Flying | s1, s2 |  | Sâu kim độc (Hairy Bug) → kén → ong bắp cày Beedrill. |
| **Zubat → Golbat → Crobat** | Bat | Poison, Flying, Sound | s1 | Dơi | Dơi hang (Bat) → Golbat → Crobat bốn cánh bay êm. |

### Uncommon (91 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Aipom → Ambipom** | Long Tail | Wild, Normal | s1 | Khỉ & vượn | Khỉ có đuôi như bàn tay (Long Tail); Ambipom hai đuôi. |
| **Alolan Diglett → Alolan Dugtrio** | Mole | Ground, Steel | s3 | Đào mỏ, *Kho báu & đá quý* | Diglett Alola có ba sợi "tóc" kim loại vàng, đào đất núi lửa. |
| **Alolan Grimer → Alolan Muk** | Sludge | Poison, Dark, Amorphous |  | Thành phố & ô nhiễm, Ham ăn | Bùn độc Alola được đưa tới để ăn rác; nhiều màu do chất độc kết tinh. |
| **Alolan Sandshrew → Alolan Sandslash** | Mouse | Ice, Steel | s3 |  | Tê tê băng (Sandshrew Alola) sống trên núi tuyết; Sandslash gai băng. |
| **Anorith → Armaldo** | Old Shrimp / Plate | Fossil, Bug, Aquatic | s2 | Cua, tôm & giáp xác | Tôm cổ đại (Old Shrimp, giống anomalocaris) → Armaldo giáp đá. |
| **Archen → Archeops** | First Bird | Rock, Flying, Fossil | s1 |  | Chim thuỷ tổ (First Bird, archaeopteryx) chưa bay giỏi; Archeops. |
| **Bagon → Shelgon → Salamence** | Rock Head / Endurance / Dragon | Dragon, Monster, Flying | s3 | *Giấc ngủ & giấc mơ* | Rồng con đầu cứng mơ được bay (Rock Head) → Shelgon → Salamence. |
| **Bidoof → Bibarel** | Plump Mouse / Beaver | Normal, Aquatic | s2 | Chuột & gặm nhấm, Lao động & xây dựng | Chuột béo / hải ly (Beaver): Bibarel xây đập trên sông. |
| **Capsakid → Scovillain** | Spicy Pepper | Grass, Fire, Gourmet | s3 | Món ăn | Quả ớt cay (Spicy Pepper) → Scovillain hai đầu. |
| **Cetoddle → Cetitan** | Terra Whale | Ice, Sound, Field | s2 | Thú biển | Cá voi sống trên cạn (Terra Whale) ở núi tuyết → Cetitan. |
| **Chinchou → Lanturn** | Angler / Light | Water, Electric, Light | s3 |  | Cá đèn lồng biển sâu (Angler) → Lanturn (Light) soi đáy biển. |
| **Cleffa → Clefairy → Clefable** | Star Shape / Fairy | Fairy, Normal, Baby, Light |  | Vũ trụ & ngoài hành tinh, *Lễ hội & mùa* | Ngôi sao nhỏ (Star Shape) → Clefairy → Clefable: tương truyền đến từ Mặt Trăng, nhảy múa dưới trăng tròn. |
| **Clobbopus → Grapploct** | Tantrum / Jujitsu | Aquatic, Amorphous, Fighting | s3 | Bạch tuộc & mực, Thể thao & võ thuật | Bạch tuộc tập võ (Tantrum) → Grapploct (Jujitsu). |
| **Corphish → Crawdaunt** | Ruffian / Rogue | Aquatic, Dark | s2 | Cua, tôm & giáp xác, Kẻ gian & lưu manh | Tôm hùm đất hung hăng (Ruffian) → Crawdaunt (Rogue), loài xâm lấn. |
| **Cottonee → Whimsicott** | Cotton Puff / Windveiled | Grass, Fairy | s3 |  | Bông gòn (Cotton Puff) → Whimsicott tinh nghịch, theo gió đi khắp nơi. |
| **Cranidos → Rampardos** | Head Butt | Fossil, Monster | s2 |  | Khủng long đầu đá (Head Butt, pachycephalosaurus) → Rampardos. |
| **Cyndaquil → Quilava → Hisuian Typhlosion / Typhlosion** | Fire Mouse / Volcano | Fire, Field, Ghost | s1 | *Chuột & gặm nhấm* | Chuột lửa (Fire Mouse, như chuột chù / nhím); Typhlosion (Volcano); Typhlosion Hisui mang lửa linh hồn. |
| **Dewpider → Araquanid** | Water Bubble | Water, Bug, Amorphous |  | Nhện & bọ cạp | Nhện nước mang bong bóng trên đầu (Water Bubble) → Araquanid. |
| **Diglett → Dugtrio** | Mole | Ground, Normal |  | Nông trại, Đào mỏ | Chuột chũi (Mole): nông dân quý vì nó đào làm đất tơi xốp cho trồng trọt. |
| **Duskull → Dusclops → Dusknoir** | Requiem / Beckon / Gripper | Dark, Ghost | s1 | Truyện cổ & yêu quái | Hồn ma đầu lâu (Requiem) → Dusclops → Dusknoir: dẫn linh hồn về thế giới bên kia, như thần chết. |
| **Ekans → Arbok** | Snake / Cobra | Poison, Dark |  | Rắn & mãng xà | Rắn (Snake) → rắn hổ mang Arbok (Cobra). |
| **Espurr → Meowstic ♀ / Meowstic ♂** | Restraint / Constraint | Wild, Psychic, Field | s2 | Mèo, Pháp sư & phù thuỷ | Mèo giữ siêu năng lực trong tai (Restraint) → Meowstic, đực / cái khác nhau. |
| **Flabébé (Pink) → Floette (Pink) → Florges (Pink)** | Single Bloom / Garden | Fairy, Flora | s1 | *Nông trại* | Tiên hoa sống cùng một bông hoa (Single Bloom); Florges chăm sóc cả khu vườn; 5 màu hoa. |
| **Flabébé (Blue) → Floette (Blue) → Florges (Blue)** | Single Bloom / Garden | Fairy, Flora | s1 | *Nông trại* | Tiên hoa sống cùng một bông hoa (Single Bloom); Florges chăm sóc cả khu vườn; 5 màu hoa. |
| **Flabébé (Orange) → Floette (Orange) → Florges (Orange)** | Single Bloom / Garden | Fairy, Flora | s1 | *Nông trại* | Tiên hoa sống cùng một bông hoa (Single Bloom); Florges chăm sóc cả khu vườn; 5 màu hoa. |
| **Flabébé (White) → Floette (White) → Florges (White)** | Single Bloom / Garden | Fairy, Flora | s1 | *Nông trại* | Tiên hoa sống cùng một bông hoa (Single Bloom); Florges chăm sóc cả khu vườn; 5 màu hoa. |
| **Flabébé (Yellow) → Floette (Yellow) → Florges (Yellow)** | Single Bloom / Garden | Fairy, Flora | s1 | *Nông trại* | Tiên hoa sống cùng một bông hoa (Single Bloom); Florges chăm sóc cả khu vườn; 5 màu hoa. |
| **Galarian Slowpoke → Galarian Slowbro / Galarian Slowking** | Dopey / Hermit Crab / Royal | Psychic, Poison | s2 | *Giấc ngủ & giấc mơ*, *Xạ thủ & pháo thủ* | Slowpoke Galar ăn hạt Galarica; Slowbro Galar bóp Shellder trên tay bắn chất độc như súng; Slowking Galar. |
| **Glameow → Purugly** | Catty / Tiger Cat | Normal, Dark | s1 | Mèo | Mèo kiêu kỳ (Catty) → Purugly (Tiger Cat) béo, hay chiếm tổ của Pokémon khác. |
| **Gossifleur → Eldegoss** | Flowering / Cotton Bloom | Flora, Sound | s3 | *Nông trại* | Hoa (Flowering) → Eldegoss (Cotton Bloom): bông có hạt bổ dưỡng, gió đưa đi cho cây cỏ. |
| **Greavard → Houndstone** | Ghost Dog | Ghost, Rock, Field |  | Chó & sói | Chó ma ở nghĩa địa (Ghost Dog) → Houndstone, rất trung thành. |
| **Grimer → Muk** | Sludge | Poison, Monster, Amorphous | s3 | Thành phố & ô nhiễm | Bùn độc (Sludge) sinh ra từ chất thải nhà máy → Muk. |
| **Growlithe → Arcanine** | Puppy / Legendary | Fire, Field | s1 | Chó & sói, Hộ vệ & canh gác, *Truyện cổ & yêu quái* | Chó con (Puppy) → Arcanine (Legendary): chó thần canh gác như sư tử đá phương Đông; chó cảnh sát trong anime. |
| **Hatenna → Hattrem → Hatterene** | Calm / Serene / Silent | Fairy, Psychic | s1 | Pháp sư & phù thuỷ | Hatenna (Calm) cảm nhận cảm xúc → Hattrem → Hatterene (Silent): phù thuỷ rừng, ghét tiếng ồn. |
| **Hisuian Growlithe → Hisuian Arcanine** | Puppy / Legendary | Fire, Rock, Field | s2 | Chó & sói, Hộ vệ & canh gác, *Truyện cổ & yêu quái* | Growlithe vùng Hisui: lông có đá, canh giữ lâu đài lãnh chúa; Arcanine Hisui. |
| **Hisuian Voltorb → Hisuian Electrode** | Ball | Electric, Grass, Fossil | s2 | Đồ vật sống, *Cổ vật & di tích* | Voltorb Hisui: quả cầu gỗ như Poké Ball thời xưa. |
| **Hisuian Zorua → Hisuian Zoroark** | Tricky Fox / Illusion Fox | Normal, Ghost | s2 | Cáo, Nguỵ trang & ảo ảnh, Truyện cổ & yêu quái | Zorua Hisui: hồn cáo hờn oán, tạo ảo ảnh; Zoroark Hisui. |
| **Hoothoot → Noctowl** | Owl | Normal, Flying, Psychic |  | Chim săn mồi & quạ | Cú (Owl) đứng một chân, đếm nhịp thời gian rất đều; Noctowl nhìn trong đêm. |
| **Horsea → Seadra → Kingdra** | Dragon | Dragon, Water | s1 | Hoàng gia & thủ lĩnh, *Ngựa* | Cá ngựa phun mực (Dragon) → Seadra → Kingdra (vua rồng biển). |
| **Igglybuff → Jigglypuff → Wigglytuff** | Balloon | Normal, Fairy, Baby, Sound | s1 | Giấc ngủ & giấc mơ | Bóng bay hát (Balloon): Jigglypuff hát ru làm người nghe ngủ; Wigglytuff. |
| **Impidimp → Morgrem → Grimmsnarl** | Wily / Devious / Bulk Up | Dark, Fairy, Human | s1 | Kẻ gian & lưu manh | Yêu tinh lẻn vào nhà trộm đồ, chơi khăm (Wily) → Morgrem → Grimmsnarl như quỷ troll. |
| **Koffing → Galarian Weezing / Weezing** | Poison Gas | Poison, Artificial, Amorphous, Fairy | s3 | Thành phố & ô nhiễm | Khí độc nhà máy (Poison Gas) → Weezing; Weezing Galar hút ô nhiễm và nhả khí sạch. |
| **Krabby → Kingler** | River Crab / Pincer | Water, Normal |  | Cua, tôm & giáp xác, *Hoàng gia & thủ lĩnh* | Cua sông (River Crab) → Kingler càng khổng lồ, tên có chữ "king". |
| **Lechonk → Oinkologne ♂** | Hog | Normal, Field, Gourmet | s3 | Lợn, Món ăn, Nông trại | Lợn con (Hog) → Oinkologne: tên ghép từ lechón (lợn quay) và cologne (nước hoa). |
| **Ledyba → Ledian** | Five Star | Bug, Fighting, Flying | s3 |  | Bọ rùa (Five Star) → Ledian đánh tay dưới ánh sao. |
| **Lickitung → Lickilicky** | Licking | Wild, Normal, Gourmet |  | Ham ăn | Lưỡi dài liếm mọi thứ (Licking) → Lickilicky. |
| **Machop → Machoke → Machamp** | Superpower | Fighting, Human | s2 | Lao động & xây dựng, Thể thao & võ thuật, Vận chuyển | Võ sĩ cơ bắp (Superpower): Machoke giúp khuân vác nặng, Machamp đẩy đá (Poké Ride Machamp Shove). |
| **Magnemite → Magneton → Magnezone** | Magnet / Magnet Area | Electric, Steel | s1 | *Thành phố & ô nhiễm*, *Đồ vật sống* | Nam châm bay (Magnet), tụ quanh nhà máy điện → Magneton → Magnezone. |
| **Mime Jr. → Mr. Mime** | Mime / Barrier | Fairy, Psychic, Baby, Human | s2 | Nghệ sĩ biểu diễn, *Hộ vệ & canh gác*, *Gia đình & bảo mẫu* | Kịch câm (Mime): Mr. Mime dựng bức tường vô hình; trong anime làm việc nhà. |
| **Minccino → Cinccino** | Chinchilla / Scarf | Normal, Field, Sound |  | Chuột & gặm nhấm | Sinsila (Chinchilla) mê sạch sẽ, lấy đuôi lau bụi → Cinccino. |
| **Nacli → Naclstack → Garganacl** | Rock Salt | Rock, Gourmet | s1 | Đào mỏ, Y tế & cứu hộ, *Món ăn* | Muối mỏ (Rock Salt) → Naclstack → Garganacl: rắc muối lên vết thương của Pokémon bị thương để chữa. |
| **Nidoran ♀ → Nidorina → Nidoqueen** | Poison Pin / Drill | Poison, Field, Ground | s3 | Hoàng gia & thủ lĩnh, *Thỏ* | Nidoran cái (Poison Pin, giống thỏ có gai) → Nidorina → Nidoqueen (hoàng hậu). |
| **Nidoran ♂ → Nidorino → Nidoking** | Poison Pin / Drill | Poison, Field, Ground | s1 | Hoàng gia & thủ lĩnh, *Thỏ* | Nidoran đực → Nidorino → Nidoking (vua). |
| **Noibat → Noivern** | Sound Wave | Dragon, Sound, Flying | s2 | Dơi | Dơi phát sóng âm (Sound Wave) → Noivern (rồng dơi). |
| **Nosepass → Probopass** | Compass | Rock, Steel, Electric | s3 | Cổ vật & di tích | Tượng đá mũi nam châm (Compass, giống tượng Moai đảo Phục Sinh) → Probopass ba "mũi" con. |
| **Omanyte → Omastar** | Spiral | Fossil, Water, Amorphous | s1 | Bạch tuộc & mực | Ốc anh vũ cổ đại (Spiral, ammonite) → Omastar. |
| **Petilil → Hisuian Lilligant / Lilligant** | Bulb / Flowering | Grass, Flora, Human, Fighting | s2 | Nghệ sĩ biểu diễn | Củ hành hoa (Bulb) → Lilligant (Flowering) múa như vũ công; Lilligant Hisui là vũ công chiến binh. |
| **Pineco → Forretress** | Bagworm | Bug, Steel | s2 |  | Quả thông (Bagworm) → Forretress vỏ thép. |
| **Piplup → Prinplup → Empoleon** | Penguin / Emperor | Water, Ice, Steel | s1 | Chim biển & cánh cụt, Hoàng gia & thủ lĩnh | Chim cánh cụt (Penguin) → Prinplup → Empoleon (Emperor), hoàng đế cánh cụt. |
| **Psyduck → Golduck** | Duck | Water, Psychic | s2 | Gà, vịt & gà lôi | Vịt (Duck) hay đau đầu, đau quá thì bộc phát siêu năng lực → Golduck. |
| **Purrloin → Liepard** | Devious / Cruel | Dark, Field | s2 | Mèo, Hổ, báo, sư tử, Kẻ gian & lưu manh | Mèo lừa (Devious) → Liepard (Cruel, báo hoa) trộm đồ của người. |
| **Quaxly → Quaxwell → Quaquaval** | Duckling / Practicing / Dancer | Aquatic, Fighting, Flying | s1 | Gà, vịt & gà lôi, Nghệ sĩ biểu diễn | Vịt con (Duckling) → Quaxwell (Practicing) → Quaquaval (Dancer) múa samba. |
| **Rufflet → Braviary** | Eaglet / Valiant | Wild, Flying | s3 | Chim săn mồi & quạ, *Vận chuyển* | Đại bàng non (Eaglet) → Braviary (Valiant), như biểu tượng đại bàng của Mỹ; Braviary Hisui chở người bay. |
| **Sandshrew → Sandslash** | Mouse | Ground, Normal |  | Sa mạc & Ai Cập cổ | Tê tê / chuột cát (Mouse) sống ở sa mạc → Sandslash. |
| **Sandygast → Palossand** | Sand Heap / Sand Castle | Ghost, Ground, Amorphous | s2 | Đồ vật sống | Đụn cát có hồn (Sand Heap) → Palossand (Sand Castle), hút sinh lực người chơi ở bãi biển. |
| **Scraggy → Scrafty** | Shedding / Hoodlum | Dark, Fighting | s3 | Kẻ gian & lưu manh, Thằn lằn & cá sấu | Thằn lằn kéo quần như dân anh chị (Shedding) → Scrafty (Hoodlum). |
| **Seel → Dewgong** | Sea Lion | Ice, Aquatic | s3 | Thú biển | Hải cẩu (Sea Lion) → Dewgong. |
| **Sewaddle → Swadloon → Leavanny** | Sewing / Leaf-Wrapped / Nurturing | Grass, Bug | s1 | Gia đình & bảo mẫu, *Nghệ sĩ biểu diễn* | Sâu may áo (Sewing) → Swadloon → Leavanny (Nurturing) may áo bằng lá cho Pokémon sơ sinh. |
| **Shellder → Cloyster** | Bivalve | Water, Ice, Rock | s3 |  | Sò hai mảnh (Bivalve) → Cloyster; cắn đuôi Slowpoke thì thành Slowbro. |
| **Shroomish → Breloom** | Mushroom | Grass, Fighting |  | *Giấc ngủ & giấc mơ* | Nấm (Mushroom) → Breloom: bào tử gây ngủ. |
| **Sinistea → Polteageist** | Black Tea | Ghost, Artificial, Gourmet | s3 | Đồ vật sống, Món ăn, *Cổ vật & di tích* | Hồn ma trong ấm / tách trà (Black Tea) → Polteageist; bản "thật" là đồ cổ hiếm. |
| **Sizzlipede → Centiskorch** | Radiator | Fire, Bug | s3 |  | Rết lửa (Radiator) → Centiskorch. |
| **Skitty → Delcatty** | Kitten / Prim | Normal, Fairy, Field |  | Mèo | Mèo con (Kitten) đuổi theo đuôi mình → Delcatty (Prim). |
| **Skrelp → Dragalge** | Mock Kelp | Poison, Water, Dragon | s1 | Nguỵ trang & ảo ảnh | Rồng biển lá giả làm rong biển (Mock Kelp) → Dragalge. |
| **Slowpoke → Slowbro / Slowking** | Dopey / Hermit Crab / Royal | Psychic, Water |  | Giấc ngủ & giấc mơ, Món ăn, Hoàng gia & thủ lĩnh | Lười, đần (Dopey); đuôi Slowpoke là đặc sản; Slowking (Royal) thông thái như vua. |
| **Smoochum → Jynx** | Kiss / Human Shape | Ice, Psychic, Baby, Human | s1 | Nghệ sĩ biểu diễn | Smoochum (Kiss) → Jynx (Human Shape) hay nhảy múa theo nhịp. |
| **Spheal → Sealeo → Walrein** | Clap / Ball Roll / Ice Break | Aquatic, Ice | s1 | Thú biển | Hải cẩu tròn lăn (Clap) → Sealeo → Walrein (hải mã). |
| **Spinarak → Ariados** | String Spit / Long Leg | Wild, Bug, Poison | s1 | Nhện & bọ cạp | Nhện giăng tơ (String Spit) → Ariados. |
| **Tangela → Tangrowth** | Vine | Grass, Monster, Fossil | s2 |  | Mớ dây leo che kín thân (Vine) → Tangrowth. |
| **Tarountula → Spidops** | String Ball / Trap | Bug, Normal | s3 | Nhện & bọ cạp | Nhện cuộn chỉ như cuộn len (String Ball) → Spidops (Trap). |
| **Tentacool → Tentacruel** | Jellyfish | Water, Aquatic, Poison | s2 |  | Sứa (Jellyfish) → Tentacruel. |
| **Treecko → Grovyle → Sceptile** | Wood Gecko / Forest | Grass, Monster | s1 | Thằn lằn & cá sấu | Tắc kè rừng (Wood Gecko) → Grovyle → Sceptile (Forest). |
| **Tynamo → Eelektrik → Eelektross** | EleFish | Electric, Aquatic, Amorphous | s2 | *Rắn & mãng xà* | Lươn điện (EleFish) → Eelektrik → Eelektross. |
| **Varoom → Revavroom** | Single-Cyl / Multi-Cyl | Steel, Artificial, Poison | s3 | Vận chuyển, Thành phố & ô nhiễm, Đồ vật sống | Động cơ sống trong xe hỏng (Single-Cyl) → Revavroom như chiếc xe máy nhiều xi lanh. |
| **Venonat → Venomoth** | Insect / Poison Moth | Bug, Flying, Poison | s2 |  | Côn trùng mắt to (Insect) → Venomoth (Poison Moth). |
| **Voltorb → Electrode** | Ball | Electric, Artificial | s1 | Đồ vật sống, *Thành phố & ô nhiễm* | Quả cầu giống Poké Ball (Ball), hay ở nhà máy điện, dễ tự nổ → Electrode. |
| **Wiglett → Wugtrio** | Garden Eel | Ground, Water | s2 | Nguỵ trang & ảo ảnh, *Rắn & mãng xà* | Lươn vườn (Garden Eel) trông giống Diglett → Wugtrio. |
| **Woobat → Swoobat** | Bat / Courting | Flying, Sound, Psychic | s2 | Dơi | Dơi mũi hình trái tim (Bat) → Swoobat (Courting). |
| **Wooloo → Dubwool** | Sheep | Normal, Field |  | Dê & cừu, Nông trại | Cừu (Sheep), lông dùng dệt vải ở Galar → Dubwool. |
| **Yamper → Boltund** | Puppy / Dog | Electric, Field | s3 | Chó & sói, Nông trại | Chó corgi (Puppy) giúp chăn cừu → Boltund (Dog) chạy như chó săn greyhound. |
| **Zorua → Zoroark** | Tricky Fox / Illusion Fox | Dark, Field | s3 | Cáo, Nguỵ trang & ảo ảnh, Truyện cổ & yêu quái | Cáo tinh ranh (Tricky Fox) → Zoroark (Illusion Fox) tạo ảo ảnh — kiểu cáo kitsune. |

### Rare (93 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Abra → Kadabra → Alakazam** | Psi | Psychic, Human | s3 | Pháp sư & phù thuỷ | Siêu năng lực (Psi): Abra ngủ gần cả ngày, Kadabra bẻ cong thìa, Alakazam có trí nhớ cực lớn. |
| **Alolan Meowth → Alolan Persian** | Scratch Cat / Classy Cat | Normal, Dark |  | Mèo, Hoàng gia & thủ lĩnh | Meowth Alola kiêu hãnh — từng là thú cưng của hoàng tộc Alola; Persian Alola mặt tròn. |
| **Alolan Vulpix → Alolan Ninetales** | Fox | Ice, Fairy | s3 | Cáo, Truyện cổ & yêu quái, *Thời tiết & thiên tai* | Vulpix băng của Alola; Ninetales Alola như nữ thần núi tuyết, gọi tuyết rơi. |
| **Bergmite → Avalugg / Hisuian Avalugg** | Ice Chunk / Iceberg | Ice, Monster, Aquatic, Rock | s2 | *Vận chuyển* | Tảng băng nhỏ (Ice Chunk) → Avalugg (Iceberg) cõng cả đàn Bergmite trên lưng như tàu sân bay. |
| **Binacle → Barbaracle** | Two-Handed / Collective | Rock, Water | s3 | Cua, tôm & giáp xác | Hà biển hai đầu (Two-Handed) → Barbaracle: bảy con Binacle sống chung một tảng đá. |
| **Bronzor → Bronzong** | Bronze / Bronze Bell | Steel, Psychic, Sound | s2 | Cổ vật & di tích, Đồ vật sống, Truyện cổ & yêu quái | Gương đồng cổ (Bronze) → Bronzong (Bronze Bell) giống chuông đồng thời cổ, từng được thờ để cầu mưa. |
| **Bulbasaur → Ivysaur → Venusaur** | Seed | Grass, Poison, Flora | s1 | *Ếch & nòng nọc* | Hạt giống trên lưng (Seed): con vật giống ếch / khủng long; củ nở thành hoa lớn ở Venusaur. |
| **Buneary → Lopunny** | Rabbit | Normal, Fighting |  | Thỏ | Thỏ (Rabbit) → Lopunny tai dài, lông mềm. |
| **Bunnelby → Diggersby** | Digging | Normal, Ground | s1 | Thỏ, Lao động & xây dựng, Đào mỏ | Thỏ đào hang (Digging) → Diggersby khoẻ như máy xúc, rất có ích ở công trường. |
| **Burmy (Plant) → Mothim / Wormadam (Plant)** | Bagworm / Moth | Bug, Grass, Flying |  | Nguỵ trang & ảo ảnh | Sâu bọc tổ (Bagworm) khoác áo lá / cát / rác tuỳ nơi ở; cái thành Wormadam, đực thành Mothim. |
| **Burmy (Sandy) → Wormadam (Sandy)** | Bagworm | Bug, Ground |  | Nguỵ trang & ảo ảnh | Sâu bọc tổ (Bagworm) khoác áo lá / cát / rác tuỳ nơi ở; cái thành Wormadam, đực thành Mothim. |
| **Burmy (Trash) → Wormadam (Trash)** | Bagworm | Bug, Artificial |  | Nguỵ trang & ảo ảnh | Sâu bọc tổ (Bagworm) khoác áo lá / cát / rác tuỳ nơi ở; cái thành Wormadam, đực thành Mothim. |
| **Cacnea → Cacturne** | Cactus / Scarecrow | Grass, Dark, Human | s3 | Sa mạc & Ai Cập cổ, *Nông trại* | Xương rồng (Cactus) → Cacturne (Scarecrow) như bù nhìn đứng yên giữa sa mạc. |
| **Carvanha → Sharpedo** | Savage / Brutal | Water, Dark | s2 | Vận chuyển, *Kẻ gian & lưu manh* | Cá piranha (Savage) → Sharpedo (Brutal), "côn đồ của biển"; Poké Ride Sharpedo Jet ở Alola. |
| **Chewtle → Drednaw** | Snapping / Bite | Aquatic, Rock, Monster | s3 | Rùa | Rùa cá sấu (Snapping) → Drednaw (Bite) cắn gãy cả đá. |
| **Clauncher → Clawitzer** | Water Gun / Howitzer | Water, Sound |  | Cua, tôm & giáp xác, Xạ thủ & pháo thủ | Tôm súng (Water Gun) → Clawitzer (Howitzer) bắn nước từ càng như khẩu pháo. |
| **Crabrawler → Crabominable** | Boxing / Woolly Crab | Ice, Fighting, Monster | s3 | Cua, tôm & giáp xác, Thể thao & võ thuật | Cua đấm bốc (Boxing) → Crabominable (Woolly Crab) leo lên núi tuyết. |
| **Croagunk → Toxicroak** | Toxic Mouth | Poison, Fighting, Aquatic | s2 | Ếch & nòng nọc, Thể thao & võ thuật | Ếch độc (Toxic Mouth) → Toxicroak đấm móc như võ sĩ. |
| **Cutiefly → Ribombee** | Bee Fly | Bug, Fairy, Flora | s1 | *Món ăn* | Ruồi ong (Bee Fly) → Ribombee vo phấn hoa thành viên bánh. |
| **Deerling (Autumn) → Sawsbuck (Autumn)** | Season | Normal, Grass, Wild |  | Hươu nai, Lễ hội & mùa | Hươu con (Season) đổi màu lông theo bốn mùa → Sawsbuck có gạc theo mùa. |
| **Deerling (Spring) → Sawsbuck (Spring)** | Season | Normal, Grass, Flora |  | Hươu nai, Lễ hội & mùa | Hươu con (Season) đổi màu lông theo bốn mùa → Sawsbuck có gạc theo mùa. |
| **Deerling (Summer) → Sawsbuck (Summer)** | Season | Normal, Grass, Gourmet |  | Hươu nai, Lễ hội & mùa | Hươu con (Season) đổi màu lông theo bốn mùa → Sawsbuck có gạc theo mùa. |
| **Deerling (Winter) → Sawsbuck (Winter)** | Season | Normal, Grass, Ice |  | Hươu nai, Lễ hội & mùa | Hươu con (Season) đổi màu lông theo bốn mùa → Sawsbuck có gạc theo mùa. |
| **Deino → Zweilous → Hydreigon** | Irate / Hostile / Brutal | Dragon, Dark | s1 | *Thần thoại & thần linh* | Rồng con mù (Irate) → Zweilous → Hydreigon ba đầu như rồng Hydra. |
| **Drifloon → Drifblim** | Balloon / Blimp | Ghost, Flying, Amorphous | s3 | Đồ vật sống, Vận chuyển | Bóng bay ma (Balloon) → Drifblim (Blimp) như khinh khí cầu, đôi khi chở người và Pokémon bay đi. |
| **Drilbur → Excadrill** | Mole / Subterrene | Ground, Steel | s2 | Đào mỏ, Lao động & xây dựng | Chuột chũi khoan (Mole) → Excadrill (Subterrene) đào đường hầm, có khi phá hỏng đường hầm tàu điện. |
| **Electrike → Manectric** | Lightning / Discharge | Electric, Field | s3 | Chó & sói | Chó / sói điện (Lightning) → Manectric (Discharge). |
| **Elgyem → Beheeyem** | Cerebral | Psychic, Monster, Light | s3 | Vũ trụ & ngoài hành tinh | Người ngoài hành tinh xám (Cerebral) gắn với chuyện UFO rơi → Beheeyem. |
| **Fidough → Dachsbun** | Puppy / Dog | Gourmet, Fairy, Field | s2 | Chó & sói, Món ăn | Chó bột bánh (Puppy) → Dachsbun (Dog): chó lạp xưởng thơm mùi bánh mới nướng. |
| **Finneon → Lumineon** | Wing Fish / Neon | Water, Light | s3 |  | Cá cánh bướm (Wing Fish) → Lumineon (Neon) phát sáng. |
| **Fomantis → Lurantis** | Sickle Grass / Bloom Sickle | Flora, Light, Fighting | s1 | Nguỵ trang & ảo ảnh | Bọ ngựa giả làm hoa (Sickle Grass) → Lurantis (Bloom Sickle). |
| **Galarian Yamask → Runerigus** | Spirit / Grudge | Ghost, Monster | s2 | Cổ vật & di tích | Yamask Galar: hồn đất bám vào phiến đá khắc cổ → Runerigus như bức bích hoạ cổ. |
| **Galarian Zigzagoon → Galarian Linoone → Obstagoon** | Tiny Raccoon / Rushing / Blocking | Wild, Dark, Sound | s3 | Kẻ gian & lưu manh, Thành phố & ô nhiễm, *Nghệ sĩ biểu diễn* | Gấu mèo Galar (Tiny Raccoon) → Linoone → Obstagoon (Blocking) như dân punk rock. |
| **Galarian Meowth → Perrserker** | Scratch Cat / Viking | Steel, Wild | s2 | Mèo, *Hiệp sĩ & kiếm sĩ* | Meowth Galar lông sắt → Perrserker (Viking), chiến binh Viking. |
| **Glimmet → Glimmora** | Ore | Poison, Rock, Flora | s2 | Đào mỏ, Kho báu & đá quý | Quặng (Ore) → Glimmora như bông hoa pha lê độc. |
| **Goldeen → Seaking** | Goldfish | Water, Normal | s2 | *Hoàng gia & thủ lĩnh* | Cá vàng (Goldfish) → Seaking, "vua" của cá vàng. |
| **Golett → Golurk** | Automaton | Ground, Artificial, Ghost | s2 | Cổ vật & di tích, Hộ vệ & canh gác | Người đất (Automaton) do người cổ đại nặn để bảo vệ / phục vụ → Golurk, như golem. |
| **Honedge → Doublade → Aegislash (Shield) / Aegislash (Blade)** | Sword / Royal Sword | Ghost, Steel, Artificial | s1 | Hiệp sĩ & kiếm sĩ, Đồ vật sống, Hoàng gia & thủ lĩnh | Kiếm ma (Sword) → Doublade → Aegislash (Royal Sword): kiếm và khiên từng theo các vị vua. |
| **Joltik → Galvantula** | Attaching / EleSpider | Bug, Electric | s2 | Nhện & bọ cạp | Nhện điện bé xíu (Attaching) → Galvantula (EleSpider). |
| **Kabuto → Kabutops** | Shellfish | Fossil, Water | s2 | *Cua, tôm & giáp xác* | Sam biển cổ đại (Shellfish) → Kabutops lưỡi hái. |
| **Kricketot → Kricketune** | Cricket | Bug, Sound | s2 | *Nghệ sĩ biểu diễn* | Dế (Cricket) → Kricketune kéo "vĩ cầm" bằng chân (âm nhạc: hệ Sound). |
| **Larvitar → Pupitar → Tyranitar** | Rock Skin / Hard Shell / Armor | Dark, Monster, Rock | s1 | Thời tiết & thiên tai | Ấu trùng núi (Rock Skin) → Pupitar → Tyranitar (Armor) gây bão cát. |
| **Lileep → Cradily** | Sea Lily / Barnacle | Fossil, Grass, Flora | s3 |  | Huệ biển cổ đại (Sea Lily) → Cradily. |
| **Lotad → Lombre → Ludicolo** | Water Weed / Jolly / Carefree | Grass, Aquatic, Sound |  | Truyện cổ & yêu quái, Nghệ sĩ biểu diễn | Lá sen (Water Weed) → Lombre → Ludicolo: dựa trên kappa (thuỷ quái Nhật), nghe nhạc là nhảy múa. |
| **Magby → Magmar → Magmortar** | Live Coal / Spitfire / Blast | Fire, Human, Baby | s1 | Xạ thủ & pháo thủ | Lửa con (Live Coal) → Magmar (Spitfire) → Magmortar (Blast) tay như súng phun lửa. |
| **Makuhita → Hariyama** | Guts / Arm Thrust | Fighting, Monster | s2 | Thể thao & võ thuật | Võ sĩ sumo con (Guts) → Hariyama (Arm Thrust). |
| **Mareanie → Toxapex** | Brutal Star | Water, Poison |  |  | Sao biển gai (Brutal Star) → Toxapex. |
| **Meowth → Persian** | Scratch Cat / Classy Cat | Normal, Field |  | Mèo, Kho báu & đá quý, Kẻ gian & lưu manh | Mèo mê đồng xu (Scratch Cat) → Persian (Classy Cat); Meowth biết nói của Team Rocket. |
| **Mienfoo → Mienshao** | Martial Arts | Fighting, Field |  | Thể thao & võ thuật | Chồn võ (Martial Arts) → Mienshao, kiểu kung fu Lý Tiểu Long. |
| **Munna → Musharna** | Dream Eater / Drowsing | Psychic, Field, Amorphous |  | Giấc ngủ & giấc mơ, Truyện cổ & yêu quái | Heo vòi ăn giấc mơ (Dream Eater) → Musharna nhả khói mộng — dựa trên baku. |
| **Natu → Xatu** | Tiny Bird / Mystic | Psychic, Flying |  | *Pháp sư & phù thuỷ*, *Cổ vật & di tích* | Chim nhỏ (Tiny Bird) → Xatu (Mystic) đứng nhìn mặt trời cả ngày, thấy được tương lai; giống cột totem. |
| **Nickit → Thievul** | Fox | Field, Dark |  | Cáo, Kẻ gian & lưu manh, *Thành phố & ô nhiễm* | Cáo con (Fox) → Thievul: lén trộm thức ăn, trứng của người và Pokémon khác. |
| **Nymble → Lokix** | Grasshopper | Bug, Dark | s3 |  | Châu chấu (Grasshopper) → Lokix, dáng như hiệp sĩ đeo mặt nạ (Kamen Rider). |
| **Paldean Wooper → Clodsire** | Water Fish / Spiny Fish | Poison, Ground, Aquatic | s3 |  | Wooper Paldea (độc, sống ở đầm lầy) → Clodsire. |
| **Pancham → Pangoro** | Playful / Daunting | Fighting, Dark | s1 | Gấu & gấu trúc, Kẻ gian & lưu manh | Gấu trúc con (Playful) → Pangoro (Daunting) như đại ca băng đảng, ngậm lá tre. |
| **Paras → Parasect** | Mushroom | Bug, Poison, Grass | s3 | Y tế & cứu hộ, *Món ăn* | Bọ mang nấm (Mushroom) → Parasect: nấm trên lưng được dùng làm thuốc, như đông trùng hạ thảo. |
| **Patrat → Watchog** | Scout / Lookout | Normal, Light | s3 | Chuột & gặm nhấm, Hộ vệ & canh gác | Sóc canh gác (Scout) → Watchog (Lookout) luôn cảnh giới. |
| **Pawmi → Pawmo → Pawmot** | Mouse / Hands-On | Electric, Fighting | s1 | Chuột & gặm nhấm, Thể thao & võ thuật, *Y tế & cứu hộ* | Chuột điện (Mouse) → Pawmo → Pawmot (Hands-On) đấm điện, có chiêu hồi sinh đồng đội. |
| **Phanpy → Donphan** | Long Nose / Armor | Wild, Ground, Baby | s1 | Voi & thú khổng lồ | Voi con (Long Nose) → Donphan (Armor) cuộn tròn lăn như bánh xe. |
| **Phantump → Trevenant** | Stump / Elder Tree | Ghost, Grass, Monster |  | Truyện cổ & yêu quái | Gốc cây có hồn (Stump) → Trevenant (Elder Tree) — như tinh linh cây (kodama). |
| **Poochyena → Mightyena** | Bite | Wild, Dark | s1 | Chó & sói | Linh cẩu / sói con (Bite) → Mightyena săn theo bầy. |
| **Riolu → Lucario** | Emanation / Aura | Fighting, Steel, Baby | s2 | Chó & sói, Thể thao & võ thuật | Chó rừng con (Emanation) → Lucario (Aura) cảm nhận "aura"; dáng giống thần Anubis. |
| **Rookidee → Corvisquire → Corviknight** | Tiny Bird / Raven | Steel, Flying |  | Chim săn mồi & quạ, Vận chuyển, Hiệp sĩ & kiếm sĩ | Chim nhỏ (Tiny Bird) → Corvisquire → Corviknight (Raven): taxi bay của Galar, như hiệp sĩ giáp đen. |
| **Salandit → Salazzle** | Toxic Lizard | Fire, Poison | s2 | Thằn lằn & cá sấu, Hoàng gia & thủ lĩnh | Thằn lằn độc (Toxic Lizard); Salazzle chỉ có con cái, như nữ hoàng có đàn đực theo hầu. |
| **Sentret → Furret** | Scout / Long Body | Ground, Normal, Field |  | Hộ vệ & canh gác | Chồn sóc (Scout) đứng trên đuôi để canh gác → Furret (Long Body). |
| **Shieldon → Bastiodon** | Shield | Rock, Fossil, Steel | s2 | Hộ vệ & canh gác | Khủng long mặt khiên (Shield) → Bastiodon mặt như bức thành. |
| **Silicobra → Sandaconda** | Sand Snake | Ground, Amorphous | s3 | Rắn & mãng xà, Sa mạc & Ai Cập cổ | Rắn cát (Sand Snake) → Sandaconda. |
| **Skwovet → Greedent** | Cheeky / Greedy | Normal, Gourmet | s3 | Chuột & gặm nhấm, Ham ăn | Sóc (Cheeky) → Greedent (Greedy) nhồi đầy quả mọng trong má. |
| **Slugma → Magcargo** | Lava | Fire, Rock, Amorphous | s2 |  | Ốc dung nham (Lava) → Magcargo. |
| **Snom → Frosmoth** | Worm / Frost Moth | Bug, Ice | s2 |  | Sâu băng (Worm) → Frosmoth (Frost Moth). |
| **Spoink → Grumpig** | Bounce / Manipulate | Psychic, Field | s3 | Lợn, Kho báu & đá quý | Lợn lò xo (Bounce) đội viên ngọc trai trên đầu → Grumpig (Manipulate). |
| **Staryu → Starmie** | Star Shape / Mysterious | Water, Psychic | s3 | Vũ trụ & ngoài hành tinh, Kho báu & đá quý | Sao biển (Star Shape) → Starmie (Mysterious): lõi đỏ như ngọc quý, nhiều chuyện kể nó đến từ vũ trụ. |
| **Sunkern → Sunflora** | Seed / Sun | Grass, Light, Flora |  | Nông trại, *Món ăn* | Hạt hướng dương (Seed) → Sunflora (Sun). |
| **Surskit → Masquerain** | Pond Skater / Eyeball | Bug, Aquatic, Flying |  |  | Gọng vó trượt nước (Pond Skater) → Masquerain (Eyeball). |
| **Swirlix → Slurpuff** | Cotton Candy / Meringue | Fairy, Gourmet | s2 | Món ăn | Kẹo bông (Cotton Candy) → Slurpuff (Meringue) mũi thính, giúp thợ làm bánh. |
| **Tadbulb → Bellibolt** | EleTadpole / EleFrog | Electric, Light, Aquatic | s3 | Ếch & nòng nọc | Nòng nọc điện (EleTadpole) → Bellibolt (EleFrog). |
| **Taillow → Swellow** | Tiny Swallow / Swallow | Wild, Flying | s1 | *Chim săn mồi & quạ* | Chim én (Tiny Swallow) → Swellow. |
| **Togepi → Togetic → Togekiss** | Spike Ball / Happiness / Jubilee | Fairy, Normal, Baby, Flying |  | *Gia đình & bảo mẫu* | Quả trứng (Spike Ball) → Togetic (Happiness) → Togekiss (Jubilee) mang may mắn, hoà bình. |
| **Torchic → Combusken → Blaziken** | Chick / Young Fowl / Blaze | Fire, Fighting, Flying | s1 | Gà, vịt & gà lôi, Thể thao & võ thuật | Gà con (Chick) → Combusken (Young Fowl) → Blaziken (Blaze) đá võ — như gà chọi. |
| **Totodile → Croconaw → Feraligatr** | Big Jaw | Water, Monster, Aquatic | s1 | Thằn lằn & cá sấu | Cá sấu con (Big Jaw) → Croconaw → Feraligatr. |
| **Toxel → Toxtricity** | Baby / Punk | Baby, Electric, Poison, Sound | s1 | Nghệ sĩ biểu diễn | Ấu trùng (Baby) → Toxtricity (Punk): rocker punk, ngực như cây đàn guitar. |
| **Trapinch → Vibrava → Flygon** | Ant Pit / Vibration / Mystic | Bug, Ground, Dragon | s1 | Sa mạc & Ai Cập cổ | Kiến sư tử (Ant Pit) → Vibrava → Flygon, "linh hồn sa mạc". |
| **Turtwig → Grotle → Torterra** | Tiny Leaf / Grove / Continent | Grass, Ground, Monster | s1 | Rùa, *Thần thoại & thần linh* | Rùa cây (Tiny Leaf) → Grotle → Torterra (Continent) mang cả khu rừng trên lưng, như rùa đội thế giới. |
| **Tyrunt → Tyrantrum** | Royal Heir / Despot | Dragon, Rock, Fossil | s3 | Hoàng gia & thủ lĩnh | Khủng long bạo chúa con (Royal Heir) → Tyrantrum (Despot). |
| **Vanillite → Vanillish → Vanilluxe** | Fresh Snow / Icy Snow / Snowstorm | Ice, Amorphous, Gourmet | s1 | Món ăn, Đồ vật sống | Kem (Fresh Snow) → Vanillish → Vanilluxe hai đầu kem ốc quế. |
| **Vullaby → Mandibuzz** | Diapered / Bone Vulture | Dark, Flying |  | Chim săn mồi & quạ | Kền kền con đội vỏ xương (Diapered) → Mandibuzz (Bone Vulture). |
| **Vulpix → Ninetales** | Fox | Fire, Psychic | s1 | Cáo, Truyện cổ & yêu quái | Cáo lửa (Fox) → Ninetales chín đuôi sống ngàn năm (kitsune). |
| **Whismur → Loudred → Exploud** | Whisper / Big Voice / Loud Noise | Normal, Sound | s2 |  | Loa phóng thanh (Whisper) → Loudred → Exploud (âm thanh: hệ Sound). |
| **Wooper → Quagsire** | Water Fish | Aquatic, Ground | s1 |  | Kỳ nhông axolotl (Water Fish) → Quagsire. |
| **Wynaut → Wobbuffet** | Bright / Patient | Psychic, Baby, Amorphous |  |  | Wobbuffet con (Bright) → Wobbuffet (Patient) chỉ phản đòn. |
| **Yamask → Cofagrigus** | Spirit / Coffin | Ghost, Human |  | Sa mạc & Ai Cập cổ, Cổ vật & di tích | Hồn ma cầm mặt nạ (Spirit) → Cofagrigus (Coffin) như quan tài vàng Ai Cập. |
| **Yanma → Yanmega** | Clear Wing / Ogre Darner | Bug, Fossil, Flying |  |  | Chuồn chuồn (Clear Wing) → Yanmega (Ogre Darner). |
| **Zigzagoon → Linoone** | Tiny Raccoon / Rushing | Wild, Field | s1 | *Kho báu & đá quý* | Gấu mèo (Tiny Raccoon) chạy zíc zắc, hay nhặt đồ → Linoone (Rushing). |

### Epic (75 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Amaura → Aurorus** | Tundra | Fossil, Ice | s1, s2 |  | Khủng long cổ dài vùng băng (Tundra) → Aurorus phát cực quang. |
| **Baltoy → Claydol** | Clay Doll | Ground, Psychic, Artificial |  | Cổ vật & di tích, Đồ vật sống | Búp bê đất sét cổ (Clay Doll), giống tượng dogū của Nhật → Claydol. |
| **Barboach → Whiscash** | Whiskers | Water, Ground |  | Truyện cổ & yêu quái, Thời tiết & thiên tai | Cá chạch (Whiskers) → Whiscash: như cá trê Namazu trong truyện Nhật, cựa mình là động đất. |
| **Beldum → Metang → Metagross** | Iron Ball / Iron Claw / Iron Leg | Psychic, Steel, Artificial | s1 |  | Quả cầu sắt một mắt (Iron Ball) → Metang → Metagross bốn bộ não, tính nhanh hơn siêu máy tính. |
| **Bonsly → Sudowoodo** | Bonsai / Imitation | Rock, Flora, Baby, Monster | s1 | Nguỵ trang & ảo ảnh | Cây bonsai (Bonsai) → Sudowoodo (Imitation) giả làm cái cây chắn đường. |
| **Bounsweet → Steenee → Tsareena** | Fruit | Grass, Fighting, Gourmet | s1 | Món ăn, Hoàng gia & thủ lĩnh | Trái cây thơm (Fruit) → Steenee → Tsareena: nữ hoàng, đá rất cao. |
| **Budew → Roselia → Roserade** | Bud / Thorn / Bouquet | Grass, Poison, Baby, Flora | s1 |  | Nụ hoa (Bud) → Roselia → Roserade (Bouquet) cầm hai bó hoa độc. |
| **Buizel → Floatzel** | Sea Weasel | Water, Aquatic, Field |  | Thú biển, Y tế & cứu hộ | Chồn biển (Sea Weasel) → Floatzel có phao ở cổ, hay cứu người đuối nước. |
| **Carbink → Diancie** | Jewel | Fossil, Rock, Fairy | s2 | Kho báu & đá quý | Viên đá quý sống dưới lòng đất (Jewel). |
| **Cherubi → Cherrim → Cherrim Sunlight** | Cherry / Blossom | Flora, Light, Gourmet | s3 | Lễ hội & mùa, *Món ăn* | Quả anh đào (Cherry) → Cherrim (Blossom) nở khi trời nắng — như mùa ngắm hoa hanami. |
| **Clamperl → Gorebyss / Huntail** | Bivalve / South Sea / Deep Sea | Fossil, Water, Psychic, Dark | s3 | Kho báu & đá quý | Ngọc trai trong vỏ sò (Bivalve) → Huntail (Deep Sea) / Gorebyss (South Sea). |
| **Corsola / Galarian Corsola → Cursola** | Coral | Rock, Aquatic, Ghost | s1 |  | San hô (Coral), sừng mọc lại khi gãy; Corsola Galar là hồn san hô chết. |
| **Cubchoo → Beartic** | Chill / Freezing | Ice, Field, Aquatic | s2 | Gấu & gấu trúc | Gấu con thò lò mũi (Chill) → Beartic (Freezing). |
| **Cubone → Alolan Marowak / Marowak** | Lonely / Bone Keeper | Ground, Ghost, Fire | s2 | Gia đình & bảo mẫu | Đội sọ của mẹ đã mất (Lonely) → Marowak (Bone Keeper); Marowak Alola múa lửa. |
| **Darumaka → Darmanitan / Darmanitan (Zen)** | Zen Charm / Blazing | Wild, Fire, Psychic | s1 | Truyện cổ & yêu quái | Búp bê daruma (Zen Charm) → Darmanitan (Blazing), chế độ Zen ngồi thiền như tượng. |
| **Doduo → Dodrio** | Twin Bird / Triple Bird | Wild, Flying, Normal |  |  | Chim hai đầu chạy rất nhanh (Twin Bird) → Dodrio ba đầu (Triple Bird), như đà điểu. |
| **Dratini → Dragonair → Dragonite** | Dragon | Dragon, Flying, Aquatic | s1 | Vận chuyển, Y tế & cứu hộ | Rồng biển (Dragon) → Dragonair → Dragonite: hiền lành, dẫn tàu gặp nạn và người trôi dạt vào bờ. |
| **Drowzee → Hypno** | Hypnosis | Psychic, Human, Monster | s2 | Giấc ngủ & giấc mơ, Truyện cổ & yêu quái, Pháp sư & phù thuỷ | Heo vòi ăn giấc mơ (Hypnosis), dựa trên baku → Hypno đung đưa con lắc thôi miên. |
| **Ducklett → Swanna** | Water Bird / White Bird | Aquatic, Flying, Sound |  | Chim biển & cánh cụt, Gà, vịt & gà lôi | Vịt con (Water Bird) → Swanna (White Bird), thiên nga. |
| **Dwebble → Crustle** | Rock Inn / Stone Home | Bug, Rock | s1 | Cua, tôm & giáp xác | Cua ẩn sĩ mang đá làm nhà (Rock Inn) → Crustle (Stone Home). |
| **Elekid → Electabuzz → Electivire** | Electric / Thunderbolt | Electric, Artificial, Baby, Human | s3 | *Truyện cổ & yêu quái* | Điện (Electric) → Electabuzz → Electivire (Thunderbolt): dáng như quỷ sấm (oni / lôi thần). |
| **Exeggcute → Alolan Exeggutor / Exeggutor** | Egg / Coconut | Flora, Psychic, Dragon | s1 | Món ăn | Chùm trứng / hạt (Egg) → Exeggutor (Coconut) như cây dừa biết đi; Exeggutor Alola cao vút. |
| **Ferroseed → Ferrothorn** | Thorn Seed / Thorn Pod | Grass, Steel |  |  | Hạt gai sắt bám trần hang (Thorn Seed) → Ferrothorn. |
| **Fuecoco → Crocalor → Skeledirge** | Fire Croc / Singer | Fire, Sound, Ghost |  | Thằn lằn & cá sấu, *Nghệ sĩ biểu diễn* | Cá sấu lửa (Fire Croc) → Crocalor → Skeledirge (Singer) hát bằng chú chim lửa trên đầu. |
| **Galarian Darumaka → Galarian Darmanitan / Galarian Darmanitan (Zen)** | Zen Charm / Blazing | Wild, Ice, Fire | s3 | Truyện cổ & yêu quái | Darumaka Galar sống ở xứ tuyết, như búp bê daruma tuyết → Darmanitan Galar. |
| **Galarian Ponyta → Galarian Rapidash** | Fire Horse | Fairy, Psychic, Light | s3 | Ngựa, Y tế & cứu hộ | Ponyta Galar (Unique Horn) → Rapidash Galar: kỳ lân bờm cầu vồng, sừng có sức chữa vết thương. |
| **Gible → Gabite → Garchomp** | Land Shark / Cave / Mach | Dragon, Ground, Monster | s1 |  | Cá mập đất (Land Shark) → Gabite → Garchomp (Mach) bay như máy bay phản lực. |
| **Girafarig → Farigiraf** | Long Neck | Normal, Psychic, Field |  |  | Hươu cao cổ hai đầu (Long Neck), đuôi cũng có não → Farigiraf. |
| **Gligar → Gliscor** | Fly Scorpion / Fang Scorpion | Ground, Poison, Flying | s3 | Nhện & bọ cạp, *Dơi* | Bọ cạp bay (Fly Scorpion) → Gliscor (Fang Scorpion) như dơi. |
| **Gulpin → Swalot** | Stomach / Poison Bag | Poison, Gourmet, Amorphous | s3 | Ham ăn | Cái dạ dày biết đi (Stomach) → Swalot (Poison Bag) nuốt chửng mọi thứ. |
| **Helioptile → Heliolisk** | Generator | Normal, Electric, Light | s1 | Thằn lằn & cá sấu, Sa mạc & Ai Cập cổ | Thằn lằn diềm (Generator) phơi nắng sa mạc để lấy điện → Heliolisk. |
| **Hippopotas → Hippowdon** | Hippo / Heavyweight | Ground, Normal | s2 | Voi & thú khổng lồ, Sa mạc & Ai Cập cổ, Thời tiết & thiên tai | Hà mã cát (Hippo) → Hippowdon (Heavyweight) thổi bão cát. |
| **Hisuian Sneasel → Sneasler** | Sharp Claw / Free Climb | Poison, Fighting, Monster |  | Ninja & điệp viên, Vận chuyển | Sneasel Hisui (độc) → Sneasler (Free Climb) leo vách đá — Poké Ride ở Hisui. |
| **Houndour → Houndoom** | Dark | Fire, Dark | s2 | Chó & sói, *Thần thoại & thần linh* | Chó săn bóng tối (Dark) → Houndoom: lửa thiêu da, như chó săn địa ngục, săn theo bầy. |
| **Inkay → Malamar** | Revolving / Overturning | Dark, Psychic, Aquatic | s3 | Bạch tuộc & mực, Pháp sư & phù thuỷ | Mực con (Revolving) → Malamar (Overturning) thôi miên, có thể lộn ngược. |
| **Jangmo-o → Hakamo-o → Kommo-o** | Scaly | Dragon, Fighting, Sound |  | Hiệp sĩ & kiếm sĩ | Rồng giáp vảy (Scaly) → Hakamo-o → Kommo-o, đập vảy như chiến binh gõ khiên. |
| **Karrablast → Escavalier** | Clamping / Cavalry | Bug, Steel | s2 | Hiệp sĩ & kiếm sĩ | Bọ (Clamping) → Escavalier (Cavalry): hiệp sĩ giáp, hai cây thương. |
| **Larvesta → Volcarona** | Torch / Sun | Fire, Bug | s3 | Thần thoại & thần linh, *Sa mạc & Ai Cập cổ* | Sâu lửa (Torch) → Volcarona (Sun): tương truyền thay mặt trời sưởi ấm khi trời tối vì tro núi lửa. |
| **Litten → Torracat → Incineroar** | Fire Cat / Heel | Fire, Dark, Field |  | Mèo, Hổ, báo, sư tử, Thể thao & võ thuật | Mèo lửa (Fire Cat) → Torracat → Incineroar (Heel): đô vật vai phản diện, dáng hổ. |
| **Mankey → Primeape → Annihilape** | Pig Monkey / Rage Monkey | Wild, Fighting, Ghost | s3 | Khỉ & vượn, *Lợn* | Khỉ lợn (Pig Monkey) hay nổi giận → Primeape → Annihilape (Rage Monkey) giận tới mức thành ma. |
| **Meditite → Medicham** | Meditate | Psychic, Human, Fighting | s2 | Thể thao & võ thuật | Tập thiền (Meditate) → Medicham — yoga. |
| **Misdreavus → Mismagius** | Screech / Magical | Ghost, Fairy, Amorphous |  | Pháp sư & phù thuỷ | Hồn ma tinh nghịch (Screech) → Mismagius (Magical) như phù thuỷ đội mũ. |
| **Mudbray → Mudsdale** | Donkey / Draft Horse | Ground, Field |  | Ngựa, Nông trại, Vận chuyển | Lừa (Donkey) → Mudsdale (Draft Horse), ngựa kéo; Poké Ride chở người qua đá (Alola). |
| **Munchlax → Snorlax** | Big Eater / Sleeping | Normal, Gourmet, Baby, Monster | s3 | Ham ăn, Giấc ngủ & giấc mơ | Ăn tạp (Big Eater) → Snorlax (Sleeping): ăn xong lăn ra ngủ chắn đường. |
| **Murkrow → Honchkrow** | Darkness / Big Boss | Dark, Flying |  | Chim săn mồi & quạ, Pháp sư & phù thuỷ, Kẻ gian & lưu manh | Quạ (Darkness) đội "mũ phù thuỷ", điềm xấu, nhặt đồ sáng → Honchkrow (Big Boss) như trùm mafia. |
| **Nincada → Ninjask** | Trainee / Ninja | Bug, Flying | s2 | Ninja & điệp viên | Ve sầu (Trainee) → Ninjask (Ninja) bay cực nhanh; xác lột hoá Shedinja. |
| **Numel → Camerupt** | Numb / Eruption | Fire, Field, Ground |  | Sa mạc & Ai Cập cổ | Lạc đà lửa (Numb) → Camerupt (Eruption) mang núi lửa trên lưng. |
| **Onix → Steelix** | Rock Snake / Iron Snake | Rock, Ground, Steel | s3 | Rắn & mãng xà, Đào mỏ | Rắn đá (Rock Snake) đào hầm dưới đất → Steelix (Iron Snake) thân thép. |
| **Oshawott → Dewott → Hisuian Samurott / Samurott** | Sea Otter / Discipline / Formidable | Water, Field, Fighting, Dark | s1 | Thú biển, Hiệp sĩ & kiếm sĩ | Rái cá biển (Sea Otter) → Dewott (Discipline) → Samurott (Formidable): samurai với kiếm vỏ sò. |
| **Ponyta → Rapidash** | Fire Horse | Fire, Field | s1 | Ngựa, *Vận chuyển* | Ngựa lửa (Fire Horse): bờm và đuôi là lửa → Rapidash chạy cực nhanh. |
| **Pumpkaboo → Gourgeist** | Pumpkin | Ghost, Grass, Light | s2 | Lễ hội & mùa, Đồ vật sống | Quả bí ngô có hồn (Pumpkin) → Gourgeist — Halloween, dẫn linh hồn lạc đường. |
| **Ralts → Kirlia → Gallade / Gardevoir** | Feeling / Emotion / Blade / Embrace | Psychic, Fairy, Human, Fighting | s1 | Hộ vệ & canh gác, Pháp sư & phù thuỷ, Hiệp sĩ & kiếm sĩ | Cảm xúc (Feeling) → Kirlia → Gardevoir (Embrace) liều mình bảo vệ chủ / Gallade (Blade) hiệp sĩ kiếm tay. |
| **Rockruff → Lycanroc (Day) / Lycanroc (Dusk) / Lycanroc (Night)** | Puppy / Wolf | Wild, Rock, Light, Fire, Dark | s1 | Chó & sói | Chó sói đá (Puppy) → Lycanroc (Wolf): dạng ngày, đêm, hoàng hôn. |
| **Roggenrola → Boldore → Gigalith** | Mantle / Ore / Compressed | Rock, Light | s2 | Đào mỏ | Đá khoáng (Mantle) → Boldore (Ore) → Gigalith (Compressed) hấp thụ nắng. |
| **Shedinja** | Shed | Bug, Ghost |  | *Ninja & điệp viên*, *Truyện cổ & yêu quái* | Vỏ ve lột rỗng có hồn (Shed) — sinh ra khi Nincada tiến hoá. |
| **Shellos (East Sea) → Gastrodon (East Sea)** | Sea Slug | Aquatic, Rock, Amorphous | s3 |  | Sên biển (Sea Slug) → Gastrodon; màu khác nhau ở bờ biển phía Đông / Tây. |
| **Shellos (West Sea) → Gastrodon (West Sea)** | Sea Slug | Water, Ground, Amorphous | s2 |  | Sên biển (Sea Slug) → Gastrodon; màu khác nhau ở bờ biển phía Đông / Tây. |
| **Shuppet → Banette** | Puppet / Marionette | Ghost, Artificial | s3 | Đồ vật sống, *Truyện cổ & yêu quái* | Hồn ma ăn cảm xúc oán hận (Puppet) → Banette (Marionette): búp bê bị vứt bỏ. |
| **Skiddo → Gogoat** | Mount | Grass, Field | s2 | Dê & cừu, Nông trại, Vận chuyển | Dê (Mount) → Gogoat (Mount): người cưỡi đi lại trong thành phố Lumiose. |
| **Skorupi → Drapion** | Scorpion / Ogre Scorpion | Dark, Bug, Poison | s2 | Nhện & bọ cạp, Sa mạc & Ai Cập cổ | Bọ cạp sa mạc (Scorpion) → Drapion (Ogre Scorpion). |
| **Slakoth → Vigoroth → Slaking** | Slacker / Wild Monkey / Lazy | Normal, Field |  | Giấc ngủ & giấc mơ, *Khỉ & vượn* | Con lười (Slacker) → Vigoroth (Wild Monkey) → Slaking (Lazy) nằm cả ngày. |
| **Sneasel → Weavile** | Sharp Claw | Ice, Dark, Monster | s2 | Kẻ gian & lưu manh, *Ninja & điệp viên* | Chồn vuốt sắc (Sharp Claw) trộm trứng → Weavile săn theo bầy. |
| **Snorunt → Glalie → Froslass** | Snow Hat / Face / Snow Land | Ghost, Ice | s1 | Truyện cổ & yêu quái | Mũ tuyết (Snow Hat) → Glalie (Face) / Froslass (Snow Land) — yuki-onna (tuyết nữ Nhật). |
| **Snover → Abomasnow** | Frost Tree | Grass, Ice, Monster | s3 | Lễ hội & mùa, Thời tiết & thiên tai | Cây tuyết (Frost Tree) → Abomasnow: như cây thông Noel, gọi mưa tuyết. |
| **Snubbull → Granbull** | Fairy | Fairy, Field | s3 | Chó & sói | Chó bulldog (Fairy) → Granbull. |
| **Stufful → Bewear** | Flailing / Strong Arm | Normal, Fighting | s3 | Gấu & gấu trúc | Gấu bông (Flailing) → Bewear (Strong Arm) ôm thân thiện nhưng gãy xương. |
| **Stunky → Skuntank** | Skunk | Dark, Poison | s2 |  | Chồn hôi (Skunk) → Skuntank. |
| **Swablu → Altaria** | Cotton Bird / Humming | Fairy, Sound, Dragon | s2 | *Nghệ sĩ biểu diễn* | Chim bông (Cotton Bird) → Altaria (Humming) hát hay như ca sĩ soprano. |
| **Tinkatink → Tinkatuff → Tinkaton** | Metalsmith / Hammer | Steel, Fairy | s1 | Lao động & xây dựng | Thợ rèn (Metalsmith) → Tinkatuff → Tinkaton (Hammer): tự rèn búa, có khi từ thép của Corviknight. |
| **Trubbish → Garbodor** | Trash Bag / Trash Heap | Poison, Artificial | s3 | Thành phố & ô nhiễm, Đồ vật sống | Túi rác (Trash Bag) → Garbodor (Trash Heap). |
| **Wailmer → Wailord** | Ball Whale / Float Whale | Water, Sound | s3 | Thú biển | Cá voi bóng (Ball Whale) → Wailord (Float Whale), Pokémon to nhất. |
| **Wattrel → Kilowattrel** | Storm Petrel / Frigatebird | Flying, Electric | s2 | Chim biển & cánh cụt, Thời tiết & thiên tai | Hải âu bão (Storm Petrel) → Kilowattrel (Frigatebird) cưỡi gió bão. |
| **Wimpod → Golisopod** | Turn Tail / Hard Scale | Bug, Water, Monster | s1 | Cua, tôm & giáp xác, Hiệp sĩ & kiếm sĩ | Bọ biển nhút nhát (Turn Tail) → Golisopod (Hard Scale) như hiệp sĩ giáp. |
| **Wingull → Pelipper** | Seagull / Water Bird | Water, Flying |  | Chim biển & cánh cụt, Vận chuyển, *Thời tiết & thiên tai* | Mòng biển (Seagull) → Pelipper (Water Bird) chở Pokémon nhỏ trong mỏ, đưa thư; gọi mưa. |
| **Wurmple → Cascoon / Silcoon → Beautifly / Dustox** | Worm / Cocoon / Butterfly / Poison Moth | Bug, Poison, Normal, Flying |  |  | Sâu (Worm) → Beautifly (bướm) hoặc Dustox (ngài). |

### Ultra (14 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Fletchling → Fletchinder → Talonflame** | Tiny Robin / Ember / Scorching | Flying, Fire | s1, s2, s3 | Chim săn mồi & quạ | Chim cổ đỏ (Tiny Robin) → Fletchinder → Talonflame (Scorching), chim cắt lửa. |
| **Frigibax → Arctibax → Baxcalibur** | Ice Fin / Ice Dragon | Dragon, Ice | s1, s2, s3 | *Hiệp sĩ & kiếm sĩ* | Rồng băng (Ice Fin) → Arctibax → Baxcalibur (Ice Dragon) có vây lưng như thanh kiếm Excalibur. |
| **Gastly → Haunter → Gengar** | Gas / Shadow | Ghost, Poison, Amorphous | s1, s2 | Kẻ gian & lưu manh | Khí ma (Gas) → Haunter → Gengar (Shadow) trốn trong bóng tối, chơi khăm. |
| **Grookey → Thwackey → Rillaboom** | Chimp / Beat / Drummer | Sound, Grass | s1, s2, s3 | Khỉ & vượn, Nghệ sĩ biểu diễn | Khỉ cỏ (Chimp) → Thwackey (Beat) → Rillaboom (Drummer) đánh trống làm từ gốc cây. |
| **Happiny → Chansey → Blissey** | Playhouse / Egg / Happiness | Normal, Fairy, Baby, Gourmet | s1, s2, s3 | Y tế & cứu hộ, Gia đình & bảo mẫu, Món ăn | Búp bê trứng (Playhouse) → Chansey (Egg) → Blissey (Happiness): y tá ở Trung tâm Pokémon, trứng rất bổ. |
| **Pawniard → Bisharp → Kingambit** | Sharp Blade / Sword Blade / Big Blade | Dark, Steel | s1, s2, s3 | Hiệp sĩ & kiếm sĩ, Hoàng gia & thủ lĩnh | Lưỡi dao (Sharp Blade) → Bisharp (Sword Blade) → Kingambit (Big Blade): tướng samurai đứng đầu cả đàn. |
| **Porygon → Porygon2 → Porygon-Z** | Virtual | Normal, Artificial | s1, s2, s3 | *Vũ trụ & ngoài hành tinh* | Pokémon nhân tạo bằng dữ liệu (Virtual) → Porygon2 → Porygon-Z, nâng cấp để đi tới chiều không gian khác. |
| **Rhyhorn → Rhydon → Rhyperior** | Spikes / Drill | Ground, Monster, Rock | s1, s2, s3 | Voi & thú khổng lồ, Vận chuyển | Tê giác (Spikes) → Rhydon (Drill) → Rhyperior; ở Kalos có lớp dạy cưỡi Rhyhorn. |
| **Shinx → Luxio → Luxray** | Flash / Spark / Gleam Eyes | Electric, Field, Light | s1, s2, s3 | Hổ, báo, sư tử | Sư tử / linh miêu con (Flash) → Luxio (Spark) → Luxray (Gleam Eyes) nhìn xuyên vật. |
| **Sobble → Drizzile → Inteleon** | Water Lizard / Secret Agent | Water, Aquatic | s1, s2 | Thằn lằn & cá sấu, Ninja & điệp viên, Xạ thủ & pháo thủ | Tắc kè nước hay khóc (Water Lizard) → Drizzile → Inteleon (Secret Agent), điệp viên bắn nước từ ngón tay. |
| **Solosis → Duosion → Reuniclus** | Cell / Mitosis / Multiplying | Psychic, Amorphous | s1, s3 |  | Tế bào (Cell) → Duosion (Mitosis) → Reuniclus (Multiplying). |
| **Teddiursa → Ursaring → Ursaluna / Blood moon Ursaluna** | Little Bear / Hibernator / Peat | Wild, Ground | s2, s3 | Gấu & gấu trúc, Vận chuyển | Gấu con (Little Bear) → Ursaring (Hibernator) → Ursaluna (Peat): Poké Ride ở Hisui, đánh hơi tìm đồ. |
| **Timburr → Gurdurr → Conkeldurr** | Muscular | Fighting, Human | s2, s3 | Lao động & xây dựng | Thợ xây (Muscular): Timburr vác gỗ, Gurdurr vác dầm thép, Conkeldurr chống trụ bê tông. |
| **Venipede → Whirlipede → Scolipede** | Centipede / Curlipede / Megapede | Bug, Poison, Field | s1, s3 |  | Rết (Centipede) → Whirlipede → Scolipede. |

### Unique (114 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Absol** | Disaster | Wild, Dark | s3 | Thời tiết & thiên tai, Hộ vệ & canh gác | Báo thiên tai (Disaster): xuất hiện để cảnh báo thảm hoạ nhưng bị người hiểu lầm là thủ phạm. |
| **Aerodactyl** | Fossil | Rock, Flying, Fossil | s2 |  | Thằn lằn bay cổ đại hồi sinh từ hổ phách (Fossil). |
| **Applin → Appletun / Dipplin / Flapple → Hydrapple** | Apple Core / Apple Nectar / Candy Apple / Apple Wing / Apple Hydra | Dragon, Gourmet, Grass | s3 | Món ăn, *Nông trại* | Sâu sống trong quả táo (Apple Core) → Flapple (Apple Wing) / Appletun (Apple Nectar, như bánh táo) / Dipplin (Candy Apple) → Hydrapple. |
| **Arctovish** | Fossil | Ice, Aquatic, Fossil | s1 |  | Hoá thạch bị ghép sai (Fossil): đầu cá + thân băng — nhà khảo cổ ghép bừa hai mảnh. |
| **Arctozolt** | Fossil | Electric, Ice, Fossil | s3 |  | Hoá thạch ghép sai (Fossil): thân trên điện + thân dưới băng. |
| **Audino** | Hearing | Normal, Sound | s2 | Y tế & cứu hộ, Gia đình & bảo mẫu | Thính giác (Hearing): nghe nhịp tim để biết sức khoẻ, làm trợ lý ở Trung tâm Pokémon (Unova). |
| **Azelf** | Willpower | Psychic, Fairy | s2 | Thần thoại & thần linh | Thần ý chí (Willpower), một trong ba thần hồ của Sinnoh. |
| **Basculin (Blue Stripes)** | Hostile | Water, Wild | s3 | *Vận chuyển*, *Kẻ gian & lưu manh* | Cá vược hung dữ (Hostile); chỉ sọc trắng tiến hoá → Basculegion (Big Fish), hồn cá chở người ở Hisui. |
| **Basculin (Red Stripes)** | Hostile | Water, Wild | s3 | *Vận chuyển*, *Kẻ gian & lưu manh* | Cá vược hung dữ (Hostile); chỉ sọc trắng tiến hoá → Basculegion (Big Fish), hồn cá chở người ở Hisui. |
| **Basculin (White Stripes) → Basculegion ♀ / Basculegion ♂** | Hostile / Big Fish | Water, Ghost | s3 | *Vận chuyển*, *Kẻ gian & lưu manh* | Cá vược hung dữ (Hostile); chỉ sọc trắng tiến hoá → Basculegion (Big Fish), hồn cá chở người ở Hisui. |
| **Bruxish** | Gnash Teeth | Water, Psychic | s1 |  | Cá nghiến răng phát sóng siêu linh (Gnash Teeth). |
| **Carnivine** | Bug Catcher | Monster, Grass, Flora | s1 |  | Cây bẫy ruồi treo mình trên cây (Bug Catcher). |
| **Castform / Castform (Snowy) / Castform (Rainy) / Castform (Sunny)** | Weather | Artificial, Amorphous, Ice, Water, Fire | s3 | Thời tiết & thiên tai, *Truyện cổ & yêu quái* | Thời tiết (Weather): đổi dạng theo nắng / mưa / tuyết, giống búp bê cầu nắng teru teru bōzu. |
| **Charcadet → Armarouge / Ceruledge** | Fire Child / Fire Warrior / Fire Blades | Fire, Baby, Psychic, Human, Ghost | s1 | Hiệp sĩ & kiếm sĩ, Xạ thủ & pháo thủ | Lửa con (Fire Child) → Armarouge (Fire Warrior, giáp + pháo tay) hoặc Ceruledge (Fire Blades, kiếm sĩ). |
| **Chatot** | Music Note | Flying, Sound | s1 | Nghệ sĩ biểu diễn, *Nguỵ trang & ảo ảnh* | Vẹt bắt chước tiếng người và giai điệu (Music Note). |
| **Chingling → Chimecho** | Bell / Wind Chime | Sound, Psychic, Baby | s3 | Truyện cổ & yêu quái, Đồ vật sống, *Lễ hội & mùa* | Chuông nhỏ (Bell) → Chimecho (Wind Chime) như chuông gió fūrin mùa hè Nhật. |
| **Comfey** | Posy Picker | Flora, Fairy | s1 | Y tế & cứu hộ, *Nghệ sĩ biểu diễn* | Kết vòng hoa (Posy Picker) và tặng Pokémon khác; hương hoa làm dịu, chữa lành. |
| **Cosmog → Cosmoem → Lunala / Solgaleo** | Nebula / Protostar / Moone / Sunne | Psychic, Light, Ghost, Steel | s3 | Vũ trụ & ngoài hành tinh, Thần thoại & thần linh | Tinh vân (Nebula) → Cosmoem (Protostar) → Solgaleo (Sunne) / Lunala (Moone), sứ giả của mặt trời / mặt trăng. |
| **Cramorant** | Gulp | Flying, Aquatic | s3 | Chim biển & cánh cụt, Ham ăn, Xạ thủ & pháo thủ | Chim cốc (Gulp) nuốt cá Arrokuda (cả Pikachu!) rồi phun ra như tên lửa. |
| **Cryogonal** | Crystallizing | Ice, Amorphous | s3 | Thời tiết & thiên tai | Bông tuyết pha lê (Crystallizing) sinh ra trong mây tuyết. |
| **Cyclizar** | Mount | Dragon, Normal | s2 | Vận chuyển, Thằn lằn & cá sấu | Thằn lằn chạy nhanh (Mount): người Paldea cưỡi như xe máy. |
| **Dedenne** | Antenna | Electric, Fairy | s2 | Chuột & gặm nhấm, *Thành phố & ô nhiễm* | Chuột ăng-ten (Antenna) hút điện từ ổ cắm. |
| **Delibird** | Delivery | Ice, Flying, Gourmet | s3 | Vận chuyển, Lễ hội & mùa, *Y tế & cứu hộ* | Chim đưa quà (Delivery) như ông già Noel: chia thức ăn cho người lạc trên núi. |
| **Dhelmise** | Sea Creeper | Grass, Ghost, Steel | s2 | Đồ vật sống, *Cổ vật & di tích*, *Nguỵ trang & ảo ảnh* | Hồn ma nhập vào mỏ neo + rong biển (Sea Creeper), như xác tàu đắm. |
| **Dondozo** | Big Catfish | Water, Gourmet, Monster | s3 | Ham ăn, Vận chuyển | Cá trê khổng lồ (Big Catfish) ăn không ngừng; làm "xe" cho Tatsugiri cưỡi. |
| **Dracovish** | Fossil | Dragon, Aquatic, Fossil | s3 |  | Hoá thạch ghép sai (Fossil): đầu cá + đuôi rồng. |
| **Dracozolt** | Fossil | Dragon, Electric, Fossil | s2 |  | Hoá thạch ghép sai (Fossil): thân điện + đuôi rồng. |
| **Drampa** | Placid | Dragon, Normal | s3 | Gia đình & bảo mẫu | Rồng già hiền (Placid) sống trên núi, thích chơi với trẻ con. |
| **Druddigon** | Cave | Dragon, Wild, Monster | s1 |  | Rồng hang (Cave), sưởi nắng lấy nhiệt. |
| **Dunsparce → Dudunsparce** | Land Snake | Normal, Ground, Bug | s2 | Rắn & mãng xà | Rắn đất có cánh nhỏ (Land Snake) → Dudunsparce đào hang dài. |
| **Duraludon → Archaludon** | Alloy | Dragon, Steel, Electric | s1 | Thành phố & ô nhiễm | Hợp kim (Alloy): thân như toà nhà chọc trời → Archaludon. |
| **Durant** | Iron Ant | Steel, Bug | s3 |  | Kiến sắt (Iron Ant) sống theo đàn, kình địch của Heatmor. |
| **Eiscue (Ice Face) / Eiscue** | Penguin | Ice, Field, Aquatic | s1 | Chim biển & cánh cụt | Chim cánh cụt (Penguin) đội khối băng trên đầu. |
| **Emolga** | Sky Squirrel | Electric, Flying | s1 | Chuột & gặm nhấm | Sóc bay điện (Sky Squirrel). |
| **Farfetch'd** | Wild Duck | Flying, Gourmet, Normal | s1 | Gà, vịt & gà lôi, Món ăn | Vịt cầm cọng hành (Wild Duck) — thành ngữ Nhật "vịt mang hành tới" = may quá; từng bị săn làm món ăn. |
| **Finizen / Palafin → Palafin (Hero)** | Dolphin | Water, Field | s2 | Thú biển, *Hộ vệ & canh gác* | Cá heo (Dolphin) → Palafin hoá thân anh hùng khi đồng đội gặp nguy. |
| **Flutter Mane** | Paradox | Ghost, Fairy, Fossil | s3 |  | Pokémon Nghịch lý (Paradox) cổ đại giống Misdreavus. |
| **Furfrou** | Poodle | Normal, Field | s3 | Chó & sói, Thành phố & ô nhiễm, Hộ vệ & canh gác, *Hoàng gia & thủ lĩnh* | Chó poodle (Poodle) được cắt tỉa nhiều kiểu ở Kalos; ngày xưa là vệ binh của vua. |
| **Galarian Farfetch'd** | Wild Duck | Flying, Gourmet, Fighting | s1 | Hiệp sĩ & kiếm sĩ, Gà, vịt & gà lôi | Farfetch'd Galar → Sirfetch'd (Wild Duck): hiệp sĩ cầm cọng hành như cây giáo, lá làm khiên. |
| **Gimmighoul → Gholdengo** | Coin Chest / Coin Entity | Ghost, Steel | s1 | Kho báu & đá quý, Đồ vật sống | Rương báu có hồn (Coin Chest) → Gholdengo (Coin Entity) thân làm bằng tiền vàng. |
| **Great Tusk** | Paradox | Ground, Fighting, Fossil | s3 | Voi & thú khổng lồ | Pokémon Nghịch lý cổ đại giống Donphan (Paradox). |
| **Hawlucha** | Wrestling | Fighting, Flying, Human | s1 | Thể thao & võ thuật | Đô vật (Wrestling) — luchador Mexico. |
| **Heatmor** | Anteater | Fire, Field | s1 |  | Thú ăn kiến lửa (Anteater), kình địch của Durant. |
| **Heracross** | Single Horn | Bug, Fighting | s3 |  | Bọ hung tê giác (Single Horn) mê nhựa cây. |
| **Hisuian Qwilfish → Overqwil** | Balloon / Pin Cluster | Dark, Poison, Aquatic | s1 |  | Cá nóc Hisui (Balloon) → Overqwil. |
| **Hoopa → Hoopa (Unbound)** | Mischief | Psychic, Dark, Ghost | s2 | Thần thoại & thần linh, Kẻ gian & lưu manh, Kho báu & đá quý | Thần đèn tinh nghịch (Mischief): vòng không gian trộm kho báu, như djinn Nghìn lẻ một đêm. |
| **Illumise** | Firefly | Bug, Light, Flying | s2 | Lễ hội & mùa | Đom đóm cái (Firefly) dẫn Volbeat vẽ hình bằng ánh sáng trên bầu trời đêm. |
| **Indeedee ♀** | Emotion | Normal, Psychic, Human | s3 | Gia đình & bảo mẫu | Cảm xúc (Emotion): dùng sừng cảm nhận cảm xúc; con đực làm quản gia, con cái chăm sóc người. |
| **Indeedee ♂** | Emotion | Normal, Psychic, Human | s3 | Gia đình & bảo mẫu | Cảm xúc (Emotion): dùng sừng cảm nhận cảm xúc; con đực làm quản gia, con cái chăm sóc người. |
| **Iron Bundle** | Paradox | Ice, Water, Artificial | s2 |  | Pokémon Nghịch lý tương lai giống Delibird, như robot. |
| **Iron Hands** | Paradox | Fighting, Artificial, Electric | s2 | Thể thao & võ thuật | Pokémon Nghịch lý tương lai giống Hariyama — sumo robot. |
| **Iron Thorns** | Paradox | Rock, Electric, Artificial | s3 |  | Pokémon Nghịch lý tương lai giống Tyranitar. |
| **Kangaskhan** | Parent | Fighting, Normal, Monster | s2 | Gia đình & bảo mẫu | Mẹ (Parent): mang con trong túi, bảo vệ con dữ dội. |
| **Kecleon** | Color Swap |  | s2 | Nguỵ trang & ảo ảnh, Thằn lằn & cá sấu | Tắc kè hoa (Color Swap) đổi màu để tàng hình; chủ tiệm trong Mystery Dungeon. |
| **Klefki** | Key Ring | Steel, Fairy, Artificial | s1 | Hộ vệ & canh gác, Kho báu & đá quý, Đồ vật sống | Chùm chìa khoá (Key Ring): người ta nhờ nó giữ chìa khoá két sắt vì nó không bao giờ đánh rơi. |
| **Komala** | Drowsing | Normal, Sound, Grass | s2 | Gấu & gấu trúc, Giấc ngủ & giấc mơ | Gấu koala ngủ suốt đời (Drowsing), ôm khúc gỗ. |
| **Kubfu → Urshifu (Rapid Strike) / Urshifu (Single Strike)** | Wushu | Fighting, Baby, Water, Dark | s1 | Gấu & gấu trúc, Thể thao & võ thuật | Gấu con võ thuật (Wushu) → Urshifu hai trường phái (Single / Rapid Strike). |
| **Lapras** | Transport | Aquatic, Ice, Sound | s2 | Vận chuyển | Vận tải (Transport): chở người qua biển; Poké Ride Lapras Paddle. |
| **Latias** | Eon | Dragon, Psychic | s1 | Thần thoại & thần linh, *Nguỵ trang & ảo ảnh* | Rồng vô hạn (Eon) cái: tàng hình, có thể giả dạng người; cặp với Latios. |
| **Latios** | Eon | Dragon, Psychic | s1 | Thần thoại & thần linh | Rồng vô hạn (Eon) đực: hiểu tiếng người; cặp với Latias. |
| **Lunatone** | Meteorite | Rock, Psychic, Dark | s1 | Vũ trụ & ngoài hành tinh | Thiên thạch hình trăng khuyết (Meteorite). |
| **Luvdisc** | Rendezvous | Water, Aquatic | s3 | Lễ hội & mùa | Cá trái tim (Rendezvous) mang lại tình yêu, gắn với ngày Valentine. |
| **Mantyke → Mantine** | Kite | Baby, Water, Flying | s1 | Vận chuyển | Cá đuối con (Kite) → Mantine: Poké Ride lướt sóng (Mantine Surf). |
| **Maractus** | Cactus | Grass, Sound, Flora | s1 | Sa mạc & Ai Cập cổ, Nghệ sĩ biểu diễn | Xương rồng nhảy múa (Cactus), tay như đôi maracas. |
| **Mawile** | Deceiver | Steel, Fairy, Monster | s3 | Nguỵ trang & ảo ảnh, Kẻ gian & lưu manh | Kẻ lừa đảo (Deceiver): mặt dễ thương, hàm to phía sau đầu. |
| **Mesprit** | Emotion | Psychic, Fairy | s1 | Thần thoại & thần linh | Thần cảm xúc (Emotion), một trong ba thần hồ. |
| **Milcery → Alcremie (Caramel Swirl) / Alcremie (Lemon) / Alcremie (Matcha) / Alcremie (Mint) / Alcremie (Rainbow Swirl) / Alcremie (Ruby) / Alcremie (Ruby Swirl) / Alcremie (Salted) / Alcremie (Vanilla)** | Cream | Fairy, Amorphous, Gourmet | s1 | Món ăn | Kem tươi (Cream) → Alcremie được "trang trí" như bánh ngọt. |
| **Miltank** | Milk Cow | Normal, Gourmet, Field | s2 | Trâu bò, Nông trại, Món ăn, Y tế & cứu hộ | Bò sữa (Milk Cow): sữa rất bổ, uống vào là khoẻ lại. |
| **Mimikyu / Mimikyu (Busted)** | Disguise | Ghost, Fairy, Amorphous | s1 | Nguỵ trang & ảo ảnh | Nguỵ trang (Disguise): đội bộ đồ giả Pikachu để được yêu thương. |
| **Minior / Minior Blue Core / Minior Green Core / Minior Orange Core / Minior Red Core** | Meteor | Flying, Rock | s2 | Vũ trụ & ngoài hành tinh, Kho báu & đá quý | Thiên thạch (Meteor): vỏ đá, vỡ ra là lõi nhiều màu. |
| **Minun** | Cheering | Electric, Field | s3 | Chuột & gặm nhấm | Cổ vũ (Cheering) — cặp với Plusle. |
| **Morpeko / Morpeko (Hangry)** | Two-Sided | Dark, Electric | s2 | Chuột & gặm nhấm, Ham ăn | Hai mặt (Two-Sided): đói là hoá dạng "hangry". |
| **Oricorio (Baile Style) / Oricorio (Pa’u Style) / Oricorio (Pom-Pom Style) / Oricorio (Sensu Style)** | Dancing | Flora, Sound, Fire, Psychic, Electric, Ghost | s3 | Nghệ sĩ biểu diễn | Vũ công (Dancing): bốn kiểu múa theo mật hoa (flamenco, cổ vũ, hula, buyō). |
| **Orthworm** | Earthworm | Steel, Ground | s1 | Đào mỏ | Giun đất thép (Earthworm) đào đường hầm. |
| **Pachirisu** | EleSquirrel | Electric, Normal | s1 | Chuột & gặm nhấm | Sóc điện (EleSquirrel). |
| **Passimian** | Teamwork | Field, Fighting | s2 | Khỉ & vượn, Thể thao & võ thuật | Đồng đội (Teamwork): chơi theo đội với "quả bóng", như rugby. |
| **Pincurchin** | Sea Urchin | Electric, Aquatic, Amorphous | s2 |  | Nhím biển (Sea Urchin). |
| **Pinsir** | Stag Beetle | Wild, Bug | s1 |  | Bọ kìm (Stag Beetle). |
| **Plusle** | Cheering | Electric, Field | s3 | Chuột & gặm nhấm | Cổ vũ (Cheering) — cặp với Minun. |
| **Poipole → Naganadel** | Poison Pin | Poison, Bug, Dragon | s2 | Vũ trụ & ngoài hành tinh | Ultra Beast (Poison Pin) → Naganadel. |
| **Pyukumuku** | Sea Cucumber | Water, Poison, Amorphous | s3 |  | Hải sâm (Sea Cucumber). |
| **Qwilfish** | Balloon | Water, Poison, Aquatic | s1 |  | Cá nóc (Balloon). |
| **Relicanth** | Longevity | Rock, Water, Fossil | s2 | Cổ vật & di tích | Cá vây tay (Longevity), "hoá thạch sống". |
| **Rotom / Rotom (Drone) / Rotom (Fan) / Rotom (Frost) / Rotom (Heat) / Rotom (Mow) / Rotom (Wash)** | Plasma | Electric, Artificial, Ghost, Light, Flying, Ice, Fire, Grass, Water | s3 | Đồ vật sống, Thành phố & ô nhiễm | Plasma: nhập vào đồ điện (máy giặt, tủ lạnh, quạt, lò vi sóng, máy cắt cỏ). |
| **Sableye → Mega Sableye** | Darkness | Dark, Ghost | s3 | Kho báu & đá quý, Kẻ gian & lưu manh, *Đào mỏ* | Bóng tối (Darkness): sống trong hang, ăn đá quý, mắt là kim cương. |
| **Scream Tail** | Paradox | Psychic, Fairy, Sound | s1 |  | Pokémon Nghịch lý cổ đại giống Jigglypuff. |
| **Kleavor / Scizor / Scyther** | Axe / Pincer / Mantis | Bug, Rock, Steel, Flying | s3 | Hiệp sĩ & kiếm sĩ, Ninja & điệp viên | Bọ ngựa lưỡi hái (Mantis) → Scizor (giáp thép) / Kleavor (Axe, rìu đá). |
| **Seviper** | Fang Snake | Poison, Monster | s2 | Rắn & mãng xà | Rắn nanh (Fang Snake), kình địch của Zangoose. |
| **Shuckle** | Mold | Bug, Rock, Gourmet | s1 | Món ăn, *Y tế & cứu hộ* | Mốc (Mold): ủ quả mọng trong vỏ thành nước ép. |
| **Sigilyph** | Avianoid | Psychic, Flying, Fossil | s3 | Cổ vật & di tích, Sa mạc & Ai Cập cổ, Hộ vệ & canh gác | Chim cổ (Avianoid) giống hình vẽ sa mạc / tượng chim Ai Cập, canh giữ thành cổ. |
| **Skarmory** | Armor Bird | Steel, Flying | s2 | Chim săn mồi & quạ, *Hiệp sĩ & kiếm sĩ* | Chim giáp thép (Armor Bird), lông cánh sắc như kiếm. |
| **Slither Wing** | Paradox | Bug, Fighting, Fossil | s1 |  | Pokémon Nghịch lý cổ đại giống Volcarona. |
| **Smeargle** | Painter | Normal, Human | s2 | Chó & sói, Nghệ sĩ biểu diễn | Hoạ sĩ (Painter): chó beagle vẽ bằng đuôi. |
| **Solrock** | Meteorite | Rock, Fire, Light | s3 | Vũ trụ & ngoài hành tinh | Thiên thạch hình mặt trời (Meteorite). |
| **Spinda** | Spot Panda | Normal, Gourmet | s3 | Gấu & gấu trúc, Nghệ sĩ biểu diễn | Gấu trúc chóng mặt (Spot Panda): đốm không con nào giống con nào, đi loạng choạng như nhảy. |
| **Spiritomb** | Forbidden | Rock, Ghost, Amorphous | s2 | Truyện cổ & yêu quái, Cổ vật & di tích | Bị cấm (Forbidden): 108 linh hồn bị phong ấn trong một hòn đá. |
| **Stantler → Wyrdeer** | Big Horn | Wild, Psychic, Field | s2 | Hươu nai, Vận chuyển, *Lễ hội & mùa* | Tuần lộc (Big Horn) gạc gây ảo giác → Wyrdeer cõng người ở Hisui. |
| **Stonjourner** | Big Rock | Rock, Ground, Light | s1 | Cổ vật & di tích | Đá lớn (Big Rock) — như vòng đá Stonehenge. |
| **Tandemaus → Maushold (3) → Maushold (4)** | Couple / Family | Normal, Fairy | s2 | Chuột & gặm nhấm, Gia đình & bảo mẫu | Cặp chuột (Couple) → Maushold (Family): cả gia đình đi cùng nhau. |
| **Tapu Bulu** | Land Spirit | Grass, Fairy | s3 | Thần thoại & thần linh, Hộ vệ & canh gác | Thần hộ mệnh (Land Spirit) đảo Ula'ula. |
| **Tapu Fini** | Land Spirit | Fairy, Water | s3 | Thần thoại & thần linh, Hộ vệ & canh gác, Y tế & cứu hộ | Thần hộ mệnh đảo Poni: sương mù thanh tẩy, chữa lành. |
| **Tapu Koko** | Land Spirit | Electric, Fairy | s2 | Thần thoại & thần linh, Hộ vệ & canh gác, *Thời tiết & thiên tai* | Thần hộ mệnh đảo Melemele, sấm sét. |
| **Tapu Lele** | Land Spirit | Psychic, Fairy | s1 | Thần thoại & thần linh, Hộ vệ & canh gác, Y tế & cứu hộ | Thần hộ mệnh đảo Akala: vảy phấn chữa bệnh (nhiều quá lại hại). |
| **Tauros / Tauros (Aqua Breed) / Tauros (Blaze Breed) / Tauros (Combat Breed)** | Wild Bull | Wild, Normal, Field, Water, Fighting, Fire | s2 | Trâu bò, Vận chuyển, Nông trại | Bò tót (Wild Bull): Poké Ride húc đá (Alola); Tauros Paldea. |
| **Togedemaru** | Roly-Poly | Electric, Steel | s1 | Chuột & gặm nhấm | Lăn tròn (Roly-Poly), lông gai thu sét. |
| **Torkoal** | Coal | Fire, Ground | s2 | Rùa, Thời tiết & thiên tai | Rùa than (Coal) phả khói, làm nắng gắt. |
| **Tropius** | Fruit | Grass, Gourmet, Flying | s1 | Món ăn, *Nông trại* | Khủng long chuối (Fruit): chùm chuối ở cổ, trẻ con rất thích ăn. |
| **Turtonator** | Blast Turtle | Dragon, Fire | s2 | Rùa | Rùa nổ (Blast Turtle): mai chứa chất nổ. |
| **Tyrogue → Hitmonchan / Hitmonlee / Hitmontop** | Scuffle / Punching / Kicking / Handstand | Fighting, Human, Baby | s2 | Thể thao & võ thuật, *Nghệ sĩ biểu diễn* | Võ sinh (Scuffle) → Hitmonlee (Kicking) / Hitmonchan (Punching) / Hitmontop (Handstand, xoay như breakdance). |
| **Uxie** | Knowledge | Psychic, Fairy | s3 | Thần thoại & thần linh | Thần tri thức (Knowledge), một trong ba thần hồ. |
| **Veluza** | Jettison | Water, Psychic, Gourmet | s1 |  | Cá chó (Jettison) bỏ bớt thịt để nhẹ người. |
| **Volbeat** | Firefly | Bug, Light, Flying | s2 | Lễ hội & mùa | Đom đóm đực (Firefly) vẽ hình bằng ánh sáng trên trời đêm. |
| **Zangoose** | Cat Ferret | Wild, Normal | s3 |  | Chồn mangut (Cat Ferret), kình địch của Seviper. |
| **Zeraora** | Thunderclap | Wild, Electric | s1 | *Hổ, báo, sư tử*, *Thần thoại & thần linh* | Sấm (Thunderclap): mèo / hổ điện thần thoại (Mythical). |

### Legendary (75 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus / Arceus** | Alpha |  | s1 | Thần thoại & thần linh | Thần sáng thế (Alpha): tương truyền nở ra từ quả trứng và tạo nên vũ trụ. |
| **Articuno** | Freeze | Ice, Flying | s1 | Thần thoại & thần linh, Thời tiết & thiên tai | Chim băng huyền thoại (Freeze), gọi bão tuyết. |
| **Blacephalon** | Fireworks | Fire, Ghost, Human | s2 | Vũ trụ & ngoài hành tinh, Xạ thủ & pháo thủ | Ultra Beast pháo hoa (Fireworks): ném cái đầu nổ tung như diễn hề. |
| **Buzzwole** | Swollen | Bug, Fighting | s3 | Vũ trụ & ngoài hành tinh, Thể thao & võ thuật | Ultra Beast cơ bắp (Swollen), như con muỗi khoe cơ. |
| **Celebi** | Time Travel | Grass, Psychic, Flora | s1 | Thần thoại & thần linh | Thần rừng du hành thời gian (Time Travel). |
| **Celesteela** | Launch | Steel, Flying, Grass | s2 | Vũ trụ & ngoài hành tinh, Truyện cổ & yêu quái | Ultra Beast tên lửa (Launch), dáng ống tre — gợi chuyện công chúa Kaguya. |
| **Chi-Yu** | Ruinous | Fire, Dark | s2 | Thần thoại & thần linh, Truyện cổ & yêu quái | Bảo vật tai ương (Ruinous): con cá lửa sinh từ ngọc bội; gợi tên Xi Vưu, thần chiến tranh Trung Hoa. |
| **Cobalion** | Iron Will | Steel, Fighting | s2 | Hiệp sĩ & kiếm sĩ, Hộ vệ & canh gác, *Ngựa* | Thanh kiếm công lý (Iron Will), như Athos (Ba chàng lính ngự lâm): bảo vệ Pokémon khỏi con người. |
| **Cresselia** | Lunar | Psychic, Fairy, Light | s2 | Giấc ngủ & giấc mơ, Thần thoại & thần linh, *Y tế & cứu hộ* | Thiên nga trăng (Lunar): mang giấc mơ đẹp, giải ác mộng của Darkrai. |
| **Darkrai** | Pitch-Black | Dark, Ghost, Amorphous | s3 | Giấc ngủ & giấc mơ, Thần thoại & thần linh | Bóng tối (Pitch-Black): gây ác mộng. |
| **Deoxys / Deoxys Attack / Deoxys Defense / Deoxys Speed** | DNA | Psychic, Amorphous, Human | s1 | Vũ trụ & ngoài hành tinh | DNA: virus ngoài vũ trụ đột biến sau khi va vào tia laser. |
| **Dialga** | Temporal | Dragon, Steel | s3 | Thần thoại & thần linh | Thần thời gian (Temporal). |
| **Enamorus** | Love-Hate | Flying, Fairy | s1 | Thần thoại & thần linh, *Lễ hội & mùa* | Nữ thần mùa xuân và tình yêu (Love-Hate) trong bộ ba thần mây. |
| **Entei** | Volcano | Wild, Fire, Field | s2 | Thần thoại & thần linh, *Hổ, báo, sư tử* | Núi lửa (Volcano): một trong ba thú huyền thoại tái sinh nhờ Ho-Oh. |
| **Eternatus** | Gigantic | Dragon, Poison, Fossil | s2 | Vũ trụ & ngoài hành tinh | Khổng lồ (Gigantic): đến từ thiên thạch rơi xuống Galar 20.000 năm trước. |
| **Fezandipiti** | Retainer | Poison, Fairy, Sound | s2 | Truyện cổ & yêu quái, Gà, vịt & gà lôi | Gà lôi độc (Retainer), một trong ba "trung thần" — dựa trên truyện Momotarō (chó, khỉ, gà lôi). |
| **Genesect** | Paleozoic | Bug, Steel, Artificial | s2 | Xạ thủ & pháo thủ | Bọ cổ đại 300 triệu năm bị cải tạo (Paleozoic), đeo pháo trên lưng. |
| **Giratina / Giratina (Origin)** | Renegade | Dragon, Ghost | s1 | Thần thoại & thần linh | Thần phản vật chất (Renegade) của Thế giới Méo. |
| **Glastrier** | Wild Horse | Ice, Field | s3 | Ngựa, Vận chuyển | Ngựa băng (Wild Horse), chiến mã của vua Calyrex. |
| **Groudon → Primal Groudon** | Continent | Ground, Monster, Fire | s1 | Thần thoại & thần linh, Thời tiết & thiên tai | Lục địa (Continent): nâng đất liền, gây hạn hán. |
| **Guzzlord** | Junkivore | Gourmet, Dark, Monster | s3 | Vũ trụ & ngoài hành tinh, Ham ăn | Ultra Beast ăn tạp (Junkivore) nuốt mọi thứ. |
| **Heatran** | Lava Dome | Fire, Steel | s1 |  | Hang dung nham (Lava Dome) sống trong núi lửa, chân bám vách hang. |
| **Ho-Oh** | Rainbow | Fire, Flying, Light | s3 | Thần thoại & thần linh, Y tế & cứu hộ | Phượng hoàng (Rainbow): hồi sinh ba thú huyền thoại sau vụ cháy tháp. |
| **Iron Valiant** | Paradox | Fighting, Fairy, Artificial | s1 | Hiệp sĩ & kiếm sĩ | Pokémon Nghịch lý tương lai (Gardevoir + Gallade), như hiệp sĩ robot. |
| **Jirachi** | Wish | Steel, Psychic, Sound | s2 | Vũ trụ & ngoài hành tinh, Lễ hội & mùa | Điều ước (Wish): thức dậy 7 ngày mỗi 1000 năm — gợi lễ Tanabata, sao chổi. |
| **Kartana** | Drawn Sword | Steel, Grass | s3 | Vũ trụ & ngoài hành tinh, Hiệp sĩ & kiếm sĩ | Ultra Beast (Drawn Sword) như con hạc giấy gấp origami, sắc như kiếm. |
| **Keldeo** | Colt | Aquatic, Fighting | s1 | Ngựa, Hiệp sĩ & kiếm sĩ | Ngựa con (Colt): thanh kiếm công lý trẻ tuổi, như d'Artagnan. |
| **Kyogre → Primal Kyogre** | Sea Basin | Water, Monster, Electric | s2 | Thần thoại & thần linh, Thời tiết & thiên tai | Biển (Sea Basin): mưa lớn mở rộng đại dương. |
| **Kyurem** | Boundary | Dragon, Ice | s2 | Thần thoại & thần linh | Ranh giới (Boundary): rồng băng thiếu năng lượng, nhập với Reshiram / Zekrom. |
| **Landorus** | Abundance | Flying, Ground | s3 | Thần thoại & thần linh, Nông trại, Thời tiết & thiên tai | Thần đất (Abundance): vùng nó đi qua được mùa. |
| **Lugia / XD001** | Diving | Aquatic, Flying, Psychic, Dark | s3 | Thần thoại & thần linh, Hộ vệ & canh gác, Thời tiết & thiên tai | Lặn (Diving): thần bảo hộ biển cả, vỗ cánh gây bão. |
| **Magearna** | Artificial | Steel, Fairy, Artificial | s3 | Cổ vật & di tích, Đồ vật sống | Nhân tạo (Artificial): búp bê máy chế tạo 500 năm trước. |
| **Manaphy** | Seafaring | Water, Aquatic, Amorphous | s2 | Thần thoại & thần linh, Hoàng gia & thủ lĩnh | Đi biển (Seafaring): "hoàng tử biển", hoán đổi tâm hồn (Heart Swap). |
| **Marshadow** | Gloomdweller | Ghost, Fighting | s1 | Ninja & điệp viên, Thể thao & võ thuật | Ẩn trong bóng (Gloomdweller), bắt chước võ của người nó nấp theo. |
| **Melmetal** | Hex Nut | Steel, Amorphous | s1 |  | Đai ốc (Hex Nut): Meltan → Melmetal, thân kim loại lỏng. |
| **Meloetta (Aria) / Meloetta (Pirouette)** | Melody | Normal, Sound, Fighting | s3 | Nghệ sĩ biểu diễn, Thần thoại & thần linh | Giai điệu (Melody): hát và nhảy, hai dạng Aria / Pirouette. |
| **Mew** | New Species | Psychic, Amorphous | s1 | Thần thoại & thần linh | Loài mới (New Species): mang DNA của mọi Pokémon. |
| **Mewtwo** | Genetic | Psychic, Monster, Artificial | s2 |  | Gen (Genetic): tạo ra trong phòng thí nghiệm từ DNA của Mew. |
| **Moltres** | Flame | Fire, Flying | s1 | Thần thoại & thần linh | Chim lửa huyền thoại (Flame), như phượng hoàng. |
| **Munkidori** | Retainer | Poison, Psychic, Human | s1 | Truyện cổ & yêu quái, Khỉ & vượn | Khỉ độc (Retainer), một trong ba "trung thần" (Momotarō). |
| **Necrozma → Ultra Necrozma** | Prism | Light, Psychic, Dragon | s3 | Vũ trụ & ngoài hành tinh | Lăng kính (Prism): đến từ Ultra Space, hấp thụ ánh sáng. |
| **Nihilego** | Parasite | Poison, Rock, Amorphous | s3 | Vũ trụ & ngoài hành tinh | Ultra Beast ký sinh (Parasite) như con sứa. |
| **Ogerpon Cornerstone / Ogerpon Cornerstone Mask / Ogerpon Hearthflame / Ogerpon Hearthflame Mask / Ogerpon Teal / Ogerpon Teal Mask / Ogerpon Wellspring / Ogerpon Wellspring Mask** | Mask | Grass, Rock, Fire, Flora, Aquatic | s3 | Truyện cổ & yêu quái, Nguỵ trang & ảo ảnh | Mặt nạ (Mask): quỷ oni nhỏ ở Kitakami, đeo 4 loại mặt nạ. |
| **Okidogi** | Retainer | Wild, Fighting, Poison | s1 | Truyện cổ & yêu quái, Chó & sói | Chó độc (Retainer), một trong ba "trung thần" (Momotarō). |
| **Palkia** | Spatial | Dragon, Water | s3 | Thần thoại & thần linh | Thần không gian (Spatial). |
| **Pecharunt** | Subjugation | Poison, Ghost, Gourmet | s2 | Truyện cổ & yêu quái | Khuất phục (Subjugation): quả đào độc, chủ của ba "trung thần" (Momotarō = cậu bé quả đào). |
| **Pheromosa** | Lissome | Bug, Fighting | s1 | Vũ trụ & ngoài hành tinh | Ultra Beast duyên dáng (Lissome). |
| **Raikou** | Thunder | Wild, Electric, Field | s3 | Thần thoại & thần linh, Hổ, báo, sư tử, Thời tiết & thiên tai | Sấm (Thunder): hổ sấm, một trong ba thú huyền thoại. |
| **Rayquaza → Mega Rayquaza** | Sky High | Dragon, Flying | s3 | Thần thoại & thần linh, Thời tiết & thiên tai, Rắn & mãng xà | Trời cao (Sky High): rồng thân rắn sống ở tầng ôzôn, dàn xếp Groudon và Kyogre. |
| **Regice** | Iceberg | Ice, Human, Fossil | s2 | Cổ vật & di tích | Núi băng (Iceberg): người khổng lồ băng bị phong ấn. |
| **Regidrago** | Dragon Orb | Dragon, Fossil, Monster | s3 | Cổ vật & di tích | Ngọc rồng (Dragon Orb). |
| **Regieleki** | Electron | Electric, Human, Amorphous | s3 | Cổ vật & di tích | Điện tử (Electron). |
| **Regigigas** | Colossal | Normal, Human, Fossil | s1 | Cổ vật & di tích, Thần thoại & thần linh | Khổng lồ (Colossal): tương truyền đã kéo các lục địa. |
| **Regirock** | Rock Peak | Rock, Human, Fossil | s1 | Cổ vật & di tích | Đỉnh đá (Rock Peak). |
| **Registeel** | Iron | Steel, Human, Fossil | s1 | Cổ vật & di tích | Sắt (Iron). |
| **Reshiram** | Vast White | Dragon, Fire | s2 | Thần thoại & thần linh | Trắng mênh mông (Vast White): chân lý (cặp âm dương với Zekrom). |
| **Roaring Moon** | Paradox | Dragon, Dark, Fossil | s1 |  | Pokémon Nghịch lý cổ đại giống Salamence. |
| **Shaymin → Shaymin (Sky)** | Gratitude | Grass, Flora, Flying | s2 | Thần thoại & thần linh, *Nông trại* | Biết ơn (Gratitude): hoa nở nơi nó đi, biến đất bẩn thành cánh đồng hoa. |
| **Spectrier** | Swift Horse | Ghost, Field | s3 | Ngựa, Vận chuyển | Ngựa ma (Swift Horse), chiến mã của vua Calyrex. |
| **Stakataka** | Rampart | Rock, Steel | s3 | Vũ trụ & ngoài hành tinh, Đồ vật sống | Ultra Beast tường thành (Rampart) ghép từ nhiều viên đá. |
| **Suicune** | Aurora | Wild, Water, Field | s1 | Thần thoại & thần linh | Cực quang (Aurora): làm sạch nước bẩn, một trong ba thú huyền thoại. |
| **Terrakion** | Cavern | Rock, Fighting | s2 | Hiệp sĩ & kiếm sĩ, Hộ vệ & canh gác, *Trâu bò* | Hang động (Cavern): thanh kiếm công lý (như Porthos), dáng như bò rừng. |
| **Thundurus** | Bolt Strike | Flying, Electric | s2 | Thần thoại & thần linh, Thời tiết & thiên tai, Truyện cổ & yêu quái | Sấm (Bolt Strike), như Lôi thần Raijin. |
| **Tornadus** | Cyclone | Flying, Ice | s3 | Thần thoại & thần linh, Thời tiết & thiên tai, Truyện cổ & yêu quái | Gió lốc (Cyclone), như Phong thần Fūjin. |
| **Type: Null → Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally / Silvally** | Synthetic | Normal, Artificial | s2 |  | Tổng hợp (Synthetic) → Silvally: vũ khí sinh học chế ra để chống Ultra Beast. |
| **Victini** | Victory | Fire, Psychic | s2 | Thần thoại & thần linh | Chiến thắng (Victory): mang thắng lợi cho người nó chọn. |
| **Virizion** | Grassland | Grass, Fighting | s2 | Hiệp sĩ & kiếm sĩ, Hộ vệ & canh gác, Hươu nai | Đồng cỏ (Grassland): thanh kiếm công lý (như Aramis), dáng hươu. |
| **Volcanion** | Steam | Fire, Water, Aquatic | s2 | Xạ thủ & pháo thủ | Hơi nước (Steam): bắn hơi nước từ vòng tay trên lưng. |
| **Xerneas** | Life | Fairy, Light, Flora | s1 | Hươu nai, Thần thoại & thần linh, Y tế & cứu hộ | Sự sống (Life): ban sự sống vĩnh cửu, gạc như cây đời. |
| **Xurkitree** | Glowing | Electric, Artificial, Light | s3 | Vũ trụ & ngoài hành tinh | Ultra Beast phát sáng (Glowing) như mớ dây điện. |
| **Yveltal** | Destruction | Dark, Flying | s3 | Thần thoại & thần linh | Huỷ diệt (Destruction): hút sinh lực khi chết đi. |
| **Zacian → Zacian (Crowned)** | Warrior | Wild, Fairy, Steel | s3 | Hiệp sĩ & kiếm sĩ, Chó & sói, Thần thoại & thần linh | Chiến binh (Warrior): sói anh hùng ngậm kiếm cứu Galar. |
| **Zapdos** | Electric | Electric, Flying | s1 | Thần thoại & thần linh, Thời tiết & thiên tai | Chim sấm huyền thoại (Electric) sống trong mây giông. |
| **Zekrom** | Deep Black | Dragon, Electric | s1 | Thần thoại & thần linh | Đen sâu thẳm (Deep Black): lý tưởng (cặp âm dương với Reshiram). |
| **Zygarde (10% Forme) / Zygarde (50% Forme) → Zygarde (100% Forme)** | Order | Dragon, Ground | s2 | Thần thoại & thần linh, Hộ vệ & canh gác | Trật tự (Order): canh giữ hệ sinh thái; dạng 10% như con chó. |

### Hatch (13 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Axew → Fraxure → Haxorus** | Tusk / Axe Jaw | Dragon | s1 |  | Rồng ngà (Tusk) → Fraxure → Haxorus (Axe Jaw), ngà sắc như rìu. |
| **Dreepy → Drakloak → Dragapult** | Lingering / Caretaker / Stealth | Dragon, Ghost | s1 | Gia đình & bảo mẫu, Xạ thủ & pháo thủ | Rồng ma (Lingering) → Drakloak (Caretaker) chăm Dreepy → Dragapult phóng Dreepy như tên lửa. |
| **Froakie → Frogadier → Greninja** | Bubble Frog / Ninja | Water, Aquatic, Dark | s3 | Ếch & nòng nọc, Ninja & điệp viên | Ếch bọt (Bubble Frog) → Frogadier → Greninja (Ninja) phóng phi tiêu nước. |
| **Gothita → Gothorita → Gothitelle** | Fixation / Manipulate / Astral Body | Psychic, Human | s3 | Pháp sư & phù thuỷ | Gothita (Fixation) → Gothorita (Manipulate) → Gothitelle (Astral Body) nhìn sao đoán tương lai. |
| **Grubbin → Charjabug → Vikavolt** | Larva / Battery / Stag Beetle | Bug, Electric | s2 | Xạ thủ & pháo thủ | Ấu trùng (Larva) → Charjabug (Battery, làm pin cho người cắm trại) → Vikavolt bắn điện từ hàm. |
| **Popplio → Brionne → Primarina** | Sea Lion / Pop Star / Soloist | Water, Fairy, Sound | s1 | Thú biển, Nghệ sĩ biểu diễn | Sư tử biển (Sea Lion) → Brionne (Pop Star) → Primarina (Soloist), ca sĩ / nghệ sĩ xiếc. |
| **Rowlet → Dartrix → Decidueye** | Grass Quill / Blade Quill / Arrow Quill | Grass, Flying, Ghost | s2 | Chim săn mồi & quạ, Xạ thủ & pháo thủ, Ninja & điệp viên | Cú (Grass Quill) → Dartrix → Decidueye (Arrow Quill), cung thủ áo choàng như ninja. |
| **Sandile → Krokorok → Krookodile** | Desert Croc / Intimidation | Dark, Ground, Monster | s1 | Thằn lằn & cá sấu, Sa mạc & Ai Cập cổ | Cá sấu sa mạc (Desert Croc) → Krokorok → Krookodile (Intimidation). |
| **Scatterbug → Spewpa → Vivillon (Meadow) / Vivillon (Archipelago) / Vivillon (Continental) / Vivillon (Elegant) / Vivillon (Fancy) / Vivillon (Garden) / Vivillon (High Plains) / Vivillon (Icy Snow) / Vivillon (Jungle) / Vivillon (Marine) / Vivillon (Modern) / Vivillon (Monsoon) / Vivillon (Ocean) / Vivillon (Poké Ball) / Vivillon (Polar) / Vivillon (River) / Vivillon (Sandstorm) / Vivillon (Savanna) / Vivillon (Sun) / Vivillon (Tundra)** | Scatterdust / Scale | Bug, Amorphous, Sound, Fighting, Fossil, Psychic, Fairy, Grass, Human, Normal, Poison, Water, Field, Steel, Light, Artificial, Ghost, Aquatic, Rock, Electric, Fire, Ice | s1 | *Lễ hội & mùa* | Sâu (Scatterdust) → Spewpa → Vivillon (Scale): hoa văn cánh khác nhau theo vùng trên thế giới. |
| **Scorbunny → Raboot → Cinderace** | Rabbit / Striker | Fire, Field, Human | s3 | Thỏ, Thể thao & võ thuật | Thỏ lửa (Rabbit) → Raboot → Cinderace (Striker), cầu thủ bóng đá. |
| **Snivy → Servine → Serperior** | Grass Snake / Regal | Grass, Field | s2 | Rắn & mãng xà, Hoàng gia & thủ lĩnh | Rắn cỏ (Grass Snake) → Servine → Serperior (Regal), quý tộc kiêu hãnh. |
| **Tepig → Pignite → Emboar** | Fire Pig / Mega Fire Pig | Wild, Fire, Fighting | s3 | Lợn, Thể thao & võ thuật | Lợn lửa (Fire Pig) → Pignite → Emboar (Mega Fire Pig), đô vật. |
| **Tympole → Palpitoad → Seismitoad** | Tadpole / Vibration | Aquatic, Ground, Sound | s2 | Ếch & nòng nọc | Nòng nọc (Tadpole) → Palpitoad → Seismitoad rung u trên da (Vibration). |

### Special (2 họ)

| Họ | Pokédex | Hệ | Mùa | Điểm chung | Ghi chú |
|---|---|---|---|---|---|
| **Combee → Vespiquen** | Tiny Bee / Beehive | Bug, Flora, Gourmet | s2 | Hoàng gia & thủ lĩnh, Món ăn, Nông trại | Ong con (Tiny Bee) → Vespiquen (Beehive), ong chúa; mật ong. |
| **Falinks (Trooper) → Falinks (Brass)** | Formation | Fighting, Steel | s2 | Hiệp sĩ & kiếm sĩ | Đội hình (Formation): sáu "lính" hành quân theo hàng. |
