# Mùa — danh sách Pokémon cố định cho từng run (chỉ có ở bản Godot)

> File này sinh bằng `python tools/port/gen_seasons.py` từ `data/seasons.json` — đừng sửa tay, sửa JSON rồi chạy lại.

Không có mùa, mọi Pokémon của game nằm chung một pool: shop bắt đầu với 94 họ, tới stage 11 bản port đã cho cả
155 họ *additional* vào shop (bản web 8 người chơi chỉ thêm 24 họ mỗi ván), cộng Pokémon vùng — một hệ có tới
13–37 họ, rất khó nhắm đội hình. Bản Godot vì vậy chia nội dung thành các **mùa** như TFT: mỗi run chơi với
danh sách Pokémon **cố định** của một mùa, chọn ở menu chính trước khi bắt đầu.

Dữ liệu: `data/seasons.json` • Code: `src/core/seasons.gd` (`Seasons`), `GameData.apply_progression()` •
Công cụ: `tools/port/gen_seasons.py`.

## 1. Luật

- **Shop của mùa** có sẵn toàn bộ từ stage đầu: không còn họ *additional* gia nhập ở stage 5 / 8 / 11, không còn
  Pokémon vùng theo từng vùng, không còn biến thể vùng thay dạng gốc. Họ nào không thuộc mùa thì không xuất hiện ở
  đâu cả (shop, đề xuất, trứng, bầy hoang dã của wave).
- **Hệ đại trà**: 8–10 họ trong shop (hệ có mốc cuối 9 thì ít nhất 9). **Hệ đặc biệt**: 3–5 họ, có **mốc kích
  hoạt riêng** của mùa (ít Pokémon hơn nên mốc thấp hơn; mốc cuối có thể cần thêm Unique / Legendary / đá hệ).
- Mỗi mùa có **4 hệ đặc trưng**: các hệ này đủ 8–10 họ ở mùa đó và là hệ đặc biệt ở các mùa khác.
- **Additional pick** (stage 5 / 8 / 11) vẫn còn: chọn 1 trong 3 Pokémon *của mùa* (Uncommon / Rare / Epic) kèm mảnh ghép.
- **Unique / Legendary** của cổng stage 10 / 20 và **dòng nở từ trứng** cũng theo mùa; mỗi con chỉ thuộc một mùa.
- Wave địch (bầy hoang dã, template) lấy Pokémon từ chính danh sách của mùa.
- **Battle Pass** vẫn áp lên trên: hệ chưa mở bị ẩn như cũ, mùa chỉ quyết định họ nào có mặt.
- Kỷ lục lưu riêng cho từng cặp mùa + độ khó.
- Lựa chọn **Tất cả Pokémon** (`allowFull`) = không mùa: pool như bản web.

## 2. Tổng quan các mùa

| Mùa | Hệ đặc trưng | Họ trong shop (C / U / R / E / Ultra) | Unique | Legendary | Trứng |
|---|---|---|---|---|---|
| **Mùa 1: Khởi Nguyên** (`s1`) | Wild, Baby, Flora, Dragon | 96 (19 / 24 / 22 / 19 / 12) | 39 | 25 | 5 |
| **Mùa 2: Tàn Tích Cổ** (`s2`) | Fossil, Human, Sound, Ghost | 96 (19 / 24 / 22 / 19 / 12) | 38 | 25 | 4 |
| **Mùa 3: Lễ Hội Ánh Sáng** (`s3`) | Artificial, Light, Gourmet, Amorphous | 96 (19 / 24 / 22 / 19 / 12) | 39 | 25 | 4 |

### Số họ của mỗi hệ trong shop

Chữ **đậm** = hệ đặc trưng của mùa, *nghiêng* = hệ đặc biệt (mốc riêng trong ngoặc). Cột "web" = số họ shop +
additional + vùng mà bản web có cho hệ đó.

| Hệ | Mốc gốc | web | s1 | s2 | s3 |
|---|---|---|---|---|---|
| Normal | 3/5/7/9 | 42 | 10 | 10 | 10 |
| Grass | 3/5/7/9 | 28 | 10 | 9 | 10 |
| Fire | 2/4/6/8 | 24 | 10 | 10 | 8 |
| Water | 3/6/9 | 34 | 10 | 10 | 10 |
| Electric | 3/5/7 | 19 | 8 | 8 | 10 |
| Fighting | 2/4/6/8 | 29 | 10 | 9 | 9 |
| Psychic | 3/5/7 | 33 | 10 | 10 | 10 |
| Dark | 3/5/7 | 33 | 10 | 10 | 10 |
| Steel | 2/4/6/8 | 23 | 9 | 10 | 9 |
| Ground | 2/4/6/8 | 32 | 10 | 10 | 10 |
| Poison | 3/5/7 | 32 | 10 | 10 | 10 |
| Dragon | 3/5/7 | 15 | **10** | *4 (2/3/4)* | *5 (2/3/5)* |
| Field | 3/6/9 | 40 | 10 | 10 | 10 |
| Monster | 2/4/6/8 | 25 | 9 | 9 | 9 |
| Human | 2/4/6 | 16 | *5 (2/3/5)* | **8** | *5 (2/3/5)* |
| Aquatic | 2/4/6/8 | 28 | 9 | 9 | 9 |
| Bug | 2/4/6/8 | 30 | 8 | 10 | 9 |
| Flying | 2/4/6/8 | 38 | 10 | 10 | 10 |
| Flora | 3/4/5/6 | 14 | **8** | *3 (2/3/4/5)* | *4 (2/3/4/5)* |
| Rock | 2/4/6 | 26 | 10 | 10 | 10 |
| Ghost | 2/4/6/8 | 20 | *5 (2/3/4/5)* | **8** | *4 (2/3/4/5)* |
| Fairy | 2/4/6/8 | 24 | 10 | 8 | 8 |
| Ice | 2/4/6/8 | 20 | 8 | 8 | 9 |
| Fossil | 2/4/6 | 14 | *3 (2/3/4)* | **8** | *3 (2/3/4)* |
| Sound | 2/4/6 | 21 | *5 (2/3/5)* | **8** | *5 (2/3/5)* |
| Artificial | 2/4/6 | 13 | *5 (2/3/5)* | *3 (2/3/4)* | **8** |
| Baby | 3/5/7 | 17 | **10** | *5 (2/3/5)* | *5 (2/3/5)* |
| Light | 2/3/4/5 | 17 | *5* | *5* | **10** |
| Wild | 2/4/6/9 | 20 | **10** | *4 (2/3/4/5)* | *5 (2/3/4/5)* |
| Amorphous | 3/5/7 | 22 | *5 (2/3/5)* | *5 (2/3/5)* | **10** |
| Gourmet | 3/4/5 | 15 | *5* | *4 (2/3/4)* | **9** |

### Trùng nhau giữa các mùa

| | s1 | s2 | s3 |
|---|---|---|---|
| s1 | 96 | 23 | 21 |
| s2 | 23 | 96 | 22 |
| s3 | 21 | 22 | 96 |

Số họ shop dùng trong ít nhất một mùa: **239 / 300**. Common và Ultra của game chỉ có 31 và 14 họ nên các mùa
buộc phải dùng chung phần lớn hai độ hiếm này.

Chưa mùa nào dùng (61): Alolan Grimer, Alolan Meowth, Baltoy, Barboach, Buizel, Buneary, Burmy (Plant), Burmy (Sandy), Burmy (Trash), Clauncher, Cleffa, Deerling (Autumn), Deerling (Spring), Deerling (Summer), Deerling (Winter), Dewpider, Diglett, Doduo, Ducklett, Ekans, Ferroseed, Fuecoco, Girafarig, Greavard, Hisuian Sneasel, Hoothoot, Jangmo-o, Krabby, Lickitung, Litten, Lotad, Mareanie, Meowth, Mienfoo, Minccino, Misdreavus, Mudbray, Munna, Murkrow, Natu, Nickit, Numel, Phantump, Rookidee, Sandshrew, Sentret, Shedinja, Shroomish, Skitty, Slakoth, Slowpoke, Sunkern, Surskit, Togepi, Vullaby, Wingull, Wooloo, Wurmple, Wynaut, Yamask, Yanma.

## 3. Mùa 1: Khởi Nguyên (`s1`)

Đội hình kinh điển của bản web: các starter và những dòng quen thuộc nhất.

- **Hệ đặc trưng**: Wild, Baby, Flora, Dragon
- **Hệ đặc biệt** (mốc của mùa): Human (2/3/5), Ghost (2/3/4/5), Fossil (2/3/4), Sound (2/3/5), Artificial (2/3/5), Light (2/3/4/5), Amorphous (2/3/5), Gourmet (3/4/5)
- **Trứng** nở ra: Axew, Dreepy, Popplio, Sandile, Scatterbug

### Shop theo độ hiếm

- **Common** (19): Aron, Azurill, Charmander, Chespin, Fennekin, Geodude, Goomy, Klink, Lillipup, Mareep, Pichu, Poliwag, Rattata, Smoliv, Spearow, Sprigatito, Swinub, Weedle, Zubat
- **Uncommon** (24): Aipom, Archen, Cyndaquil, Duskull, Flabébé (Pink), Glameow, Growlithe, Hatenna, Horsea, Igglybuff, Impidimp, Magnemite, Nacli, Nidoran ♂, Omanyte, Piplup, Quaxly, Sewaddle, Skrelp, Smoochum, Spheal, Spinarak, Treecko, Voltorb
- **Rare** (22): Bulbasaur, Bunnelby, Cutiefly, Deino, Fomantis, Honedge, Larvitar, Magby, Pancham, Pawmi, Phanpy, Poochyena, Taillow, Torchic, Totodile, Toxel, Trapinch, Turtwig, Vanillite, Vulpix, Wooper, Zigzagoon
- **Epic** (19): Amaura, Beldum, Bonsly, Bounsweet, Budew, Corsola, Darumaka, Dratini, Dwebble, Exeggcute, Gible, Helioptile, Oshawott, Ponyta, Ralts, Rockruff, Snorunt, Tinkatink, Wimpod
- **Ultra** (12): Fletchling, Frigibax, Gastly, Grookey, Happiny, Pawniard, Porygon, Rhyhorn, Shinx, Sobble, Solosis, Venipede

### Theo hệ

| Hệ | Mốc | Shop | Unique | Legendary |
|---|---|---|---|---|
| Normal | 3/5/7/9 | **10**: Lillipup (C), Rattata (C), Smoliv (C), Aipom (U), Glameow (U), Igglybuff (U), Bunnelby (R), Helioptile (E), Happiny (Ul), Porygon (Ul) | Farfetch'd, Pachirisu | Regigigas |
| Grass | 3/5/7/9 | **10**: Chespin (C), Smoliv (C), Sprigatito (C), Sewaddle (U), Treecko (U), Bulbasaur (R), Turtwig (R), Bounsweet (E), Budew (E), Grookey (Ul) | Carnivine, Maractus, Tropius | Celebi |
| Fire | 2/4/6/8 | **10**: Charmander (C), Fennekin (C), Cyndaquil (U), Growlithe (U), Magby (R), Torchic (R), Vulpix (R), Darumaka (E), Ponyta (E), Fletchling (Ul) | Charcadet, Heatmor | Heatran, Moltres |
| Water | 3/6/9 | **10**: Azurill (C), Poliwag (C), Horsea (U), Omanyte (U), Piplup (U), Skrelp (U), Totodile (R), Oshawott (E), Wimpod (E), Sobble (Ul) | Bruxish, Mantyke, Qwilfish, Veluza | Suicune |
| Electric | 3/5/7 | **8**: Mareep (C), Pichu (C), Magnemite (U), Voltorb (U), Pawmi (R), Toxel (R), Helioptile (E), Shinx (Ul) | Emolga, Pachirisu, Togedemaru, Zeraora | Zapdos, Zekrom |
| Fighting | 2/4/6/8 | **10**: Chespin (C), Poliwag (C), Quaxly (U), Fomantis (R), Pancham (R), Pawmi (R), Torchic (R), Bounsweet (E), Oshawott (E), Ralts (E) | Galarian Farfetch'd, Hawlucha, Kubfu, Slither Wing | Iron Valiant, Keldeo, Marshadow, Okidogi, Pheromosa |
| Psychic | 3/5/7 | **10**: Fennekin (C), Pichu (C), Hatenna (U), Smoochum (U), Vulpix (R), Beldum (E), Darumaka (E), Exeggcute (E), Ralts (E), Solosis (Ul) | Bruxish, Latias, Latios, Lunatone, Mesprit, Scream Tail, Tapu Lele, Veluza | Celebi, Deoxys, Mew, Munkidori |
| Dark | 3/5/7 | **10**: Sprigatito (C), Duskull (U), Glameow (U), Impidimp (U), Deino (R), Larvitar (R), Pancham (R), Poochyena (R), Oshawott (E), Pawniard (Ul) | Hisuian Qwilfish, Lunatone | Roaring Moon |
| Steel | 2/4/6/8 | **9**: Aron (C), Goomy (C), Klink (C), Magnemite (U), Piplup (U), Honedge (R), Beldum (E), Tinkatink (E), Pawniard (Ul) | Duraludon, Gimmighoul, Klefki, Orthworm, Togedemaru | Heatran, Melmetal, Registeel |
| Ground | 2/4/6/8 | **10**: Geodude (C), Swinub (C), Nidoran ♂ (U), Bunnelby (R), Phanpy (R), Trapinch (R), Turtwig (R), Wooper (R), Gible (E), Rhyhorn (Ul) | Orthworm, Stonjourner | Groudon |
| Poison | 3/5/7 | **10**: Weedle (C), Zubat (C), Nidoran ♂ (U), Skrelp (U), Spinarak (U), Bulbasaur (R), Toxel (R), Budew (E), Gastly (Ul), Venipede (Ul) | Hisuian Qwilfish, Qwilfish | Munkidori, Okidogi |
| **Dragon** ★ | 3/5/7 | **10**: Charmander (C), Goomy (C), Horsea (U), Skrelp (U), Deino (R), Trapinch (R), Dratini (E), Exeggcute (E), Gible (E), Frigibax (Ul) | Druddigon, Duraludon, Latias, Latios | Giratina, Roaring Moon, Zekrom |
| Field | 3/6/9 | **10**: Lillipup (C), Mareep (C), Cyndaquil (U), Growlithe (U), Nidoran ♂ (U), Zigzagoon (R), Oshawott (E), Ponyta (E), Shinx (Ul), Venipede (Ul) | Eiscue (Ice Face), Heatmor | Suicune |
| Monster | 2/4/6/8 | **9**: Aron (C), Treecko (U), Larvitar (R), Totodile (R), Turtwig (R), Bonsly (E), Gible (E), Wimpod (E), Rhyhorn (Ul) | Carnivine, Druddigon | Groudon |
| *Human* | 2/3/5 | **5**: Fennekin (C), Impidimp (U), Smoochum (U), Magby (R), Ralts (E) | Hawlucha | Deoxys, Munkidori, Regigigas, Regirock, Registeel |
| Aquatic | 2/4/6/8 | **9**: Goomy (C), Poliwag (C), Quaxly (U), Spheal (U), Totodile (R), Wooper (R), Corsola (E), Dratini (E), Sobble (Ul) | Arctovish, Eiscue (Ice Face), Hisuian Qwilfish, Qwilfish | Keldeo |
| Bug | 2/4/6/8 | **8**: Weedle (C), Sewaddle (U), Spinarak (U), Cutiefly (R), Trapinch (R), Dwebble (E), Wimpod (E), Venipede (Ul) | Pinsir, Shuckle, Slither Wing | Pheromosa |
| Flying | 2/4/6/8 | **10**: Charmander (C), Spearow (C), Weedle (C), Zubat (C), Archen (U), Quaxly (U), Taillow (R), Torchic (R), Dratini (E), Fletchling (Ul) | Chatot, Emolga, Farfetch'd, Galarian Farfetch'd, Hawlucha, Mantyke, Tropius | Articuno, Enamorus, Moltres, Zapdos |
| **Flora** ★ | 3/4/5/6 | **8**: Sprigatito (C), Flabébé (Pink) (U), Bulbasaur (R), Cutiefly (R), Fomantis (R), Bonsly (E), Budew (E), Exeggcute (E) | Carnivine, Comfey, Maractus | Celebi, Xerneas |
| Rock | 2/4/6 | **10**: Aron (C), Geodude (C), Archen (U), Nacli (U), Larvitar (R), Bonsly (E), Corsola (E), Dwebble (E), Rockruff (E), Rhyhorn (Ul) | Lunatone, Shuckle, Stonjourner | Regirock |
| *Ghost* | 2/3/4/5 | **5**: Cyndaquil (U), Duskull (U), Honedge (R), Snorunt (E), Gastly (Ul) | Gimmighoul, Mimikyu | Giratina, Marshadow |
| Fairy | 2/4/6/8 | **10**: Azurill (C), Pichu (C), Flabébé (Pink) (U), Hatenna (U), Igglybuff (U), Impidimp (U), Cutiefly (R), Ralts (E), Tinkatink (E), Happiny (Ul) | Comfey, Klefki, Mesprit, Milcery, Mimikyu, Scream Tail, Tapu Lele | Enamorus, Iron Valiant, Xerneas |
| Ice | 2/4/6/8 | **8**: Swinub (C), Piplup (U), Smoochum (U), Spheal (U), Vanillite (R), Amaura (E), Snorunt (E), Frigibax (Ul) | Arctovish, Eiscue (Ice Face) | Articuno |
| *Fossil* | 2/3/4 | **3**: Archen (U), Omanyte (U), Amaura (E) | Arctovish, Slither Wing | Regigigas, Regirock, Registeel, Roaring Moon |
| *Sound* | 2/3/5 | **5**: Poliwag (C), Zubat (C), Igglybuff (U), Toxel (R), Grookey (Ul) | Chatot, Maractus, Scream Tail | — |
| *Artificial* | 2/3/5 | **5**: Klink (C), Voltorb (U), Honedge (R), Beldum (E), Porygon (Ul) | Klefki | Iron Valiant |
| **Baby** ★ | 3/5/7 | **10**: Azurill (C), Pichu (C), Igglybuff (U), Smoochum (U), Magby (R), Phanpy (R), Toxel (R), Bonsly (E), Budew (E), Happiny (Ul) | Charcadet, Kubfu, Mantyke | — |
| *Light* | 2/3/4/5 | **5**: Mareep (C), Fomantis (R), Helioptile (E), Rockruff (E), Shinx (Ul) | Stonjourner | Xerneas |
| **Wild** ★ | 2/4/6/9 | **10**: Rattata (C), Spearow (C), Aipom (U), Spinarak (U), Phanpy (R), Poochyena (R), Taillow (R), Zigzagoon (R), Darumaka (E), Rockruff (E) | Druddigon, Pinsir, Zeraora | Okidogi, Suicune |
| *Amorphous* | 2/3/5 | **5**: Goomy (C), Omanyte (U), Vanillite (R), Gastly (Ul), Solosis (Ul) | Milcery, Mimikyu | Deoxys, Melmetal, Mew |
| *Gourmet* | 3/4/5 | **5**: Smoliv (C), Nacli (U), Vanillite (R), Bounsweet (E), Happiny (Ul) | Farfetch'd, Galarian Farfetch'd, Milcery, Shuckle, Tropius, Veluza | — |

Unique (39): Arctovish, Bruxish, Carnivine, Charcadet, Chatot, Comfey, Druddigon, Duraludon, Eiscue (Ice Face), Emolga, Farfetch'd, Galarian Farfetch'd, Gimmighoul, Hawlucha, Heatmor, Hisuian Qwilfish, Klefki, Kubfu, Latias, Latios, Lunatone, Mantyke, Maractus, Mesprit, Milcery, Mimikyu, Orthworm, Pachirisu, Pinsir, Qwilfish, Scream Tail, Shuckle, Slither Wing, Stonjourner, Tapu Lele, Togedemaru, Tropius, Veluza, Zeraora.

Legendary (25): Arceus, Articuno, Celebi, Deoxys, Enamorus, Giratina, Groudon, Heatran, Iron Valiant, Keldeo, Marshadow, Melmetal, Mew, Moltres, Munkidori, Okidogi, Pheromosa, Regigigas, Regirock, Registeel, Roaring Moon, Suicune, Xerneas, Zapdos, Zekrom.

## 4. Mùa 2: Tàn Tích Cổ (`s2`)

Hoá thạch thức giấc, hồn ma lang thang trong tàn tích và các nhà thám hiểm truyền dạy chiêu thức.

- **Hệ đặc trưng**: Fossil, Human, Sound, Ghost
- **Hệ đặc biệt** (mốc của mùa): Dragon (2/3/4), Flora (2/3/4/5), Artificial (2/3/4), Baby (2/3/5), Light (2/3/4/5), Wild (2/3/4/5), Amorphous (2/3/5), Gourmet (2/3/4)
- **Trứng** nở ra: Grubbin, Rowlet, Snivy, Tympole

### Shop theo độ hiếm

- **Common** (19): Alolan Geodude, Alolan Rattata, Aron, Azurill, Charmander, Chespin, Chimchar, Fennekin, Klink, Litwick, Mareep, Pichu, Pidgey, Smoliv, Sprigatito, Squirtle, Starly, Swinub, Weedle
- **Uncommon** (24): Anorith, Bidoof, Cetoddle, Corphish, Cranidos, Espurr, Galarian Slowpoke, Hisuian Growlithe, Hisuian Voltorb, Hisuian Zorua, Machop, Mime Jr., Noibat, Petilil, Pineco, Psyduck, Purrloin, Sandygast, Tangela, Tentacool, Tynamo, Venonat, Wiglett, Woobat
- **Rare** (22): Bergmite, Bronzor, Carvanha, Croagunk, Drilbur, Fidough, Galarian Yamask, Galarian Meowth, Glimmet, Goldeen, Golett, Joltik, Kabuto, Kricketot, Makuhita, Riolu, Salandit, Shieldon, Slugma, Snom, Swirlix, Whismur
- **Epic** (19): Amaura, Carbink, Cubchoo, Cubone, Drowzee, Hippopotas, Houndour, Karrablast, Meditite, Nincada, Pumpkaboo, Roggenrola, Shellos (West Sea), Skiddo, Skorupi, Sneasel, Stunky, Swablu, Wattrel
- **Ultra** (12): Fletchling, Frigibax, Gastly, Grookey, Happiny, Pawniard, Porygon, Rhyhorn, Shinx, Sobble, Teddiursa, Timburr

### Theo hệ

| Hệ | Mốc | Shop | Unique | Legendary |
|---|---|---|---|---|
| Normal | 3/5/7/9 | **10**: Pidgey (C), Smoliv (C), Starly (C), Bidoof (U), Hisuian Zorua (U), Goldeen (R), Whismur (R), Hippopotas (E), Happiny (Ul), Porygon (Ul) | Audino, Cyclizar, Dunsparce, Kangaskhan, Komala, Miltank, Smeargle, Tandemaus, Tauros | Type: Null |
| Grass | 3/5/7/9 | **9**: Chespin (C), Smoliv (C), Sprigatito (C), Hisuian Voltorb (U), Petilil (U), Tangela (U), Pumpkaboo (E), Skiddo (E), Grookey (Ul) | Dhelmise, Komala | Celesteela, Shaymin, Virizion |
| Fire | 2/4/6/8 | **10**: Charmander (C), Chimchar (C), Fennekin (C), Litwick (C), Hisuian Growlithe (U), Salandit (R), Slugma (R), Cubone (E), Houndour (E), Fletchling (Ul) | Torkoal, Turtonator | Blacephalon, Chi-Yu, Entei, Reshiram, Victini, Volcanion |
| Water | 3/6/9 | **10**: Azurill (C), Squirtle (C), Psyduck (U), Tentacool (U), Wiglett (U), Carvanha (R), Goldeen (R), Kabuto (R), Shellos (West Sea) (E), Sobble (Ul) | Finizen, Iron Bundle, Relicanth | Kyogre, Manaphy, Volcanion |
| Electric | 3/5/7 | **8**: Alolan Geodude (C), Mareep (C), Pichu (C), Hisuian Voltorb (U), Tynamo (U), Joltik (R), Wattrel (E), Shinx (Ul) | Dedenne, Dracozolt, Iron Hands, Morpeko, Pincurchin, Tapu Koko | Thundurus |
| Fighting | 2/4/6/8 | **9**: Chespin (C), Chimchar (C), Machop (U), Petilil (U), Croagunk (R), Makuhita (R), Riolu (R), Meditite (E), Timburr (Ul) | Falinks (Trooper), Iron Hands, Kangaskhan, Passimian, Tyrogue | Cobalion, Terrakion, Virizion |
| Psychic | 3/5/7 | **10**: Fennekin (C), Pichu (C), Espurr (U), Galarian Slowpoke (U), Mime Jr. (U), Psyduck (U), Woobat (U), Bronzor (R), Drowzee (E), Meditite (E) | Azelf, Hoopa, Stantler | Cresselia, Jirachi, Mewtwo, Victini |
| Dark | 3/5/7 | **10**: Alolan Rattata (C), Sprigatito (C), Corphish (U), Purrloin (U), Carvanha (R), Houndour (E), Skorupi (E), Sneasel (E), Stunky (E), Pawniard (Ul) | Hoopa, Morpeko | Chi-Yu |
| Steel | 2/4/6/8 | **10**: Aron (C), Klink (C), Pineco (U), Bronzor (R), Drilbur (R), Galarian Meowth (R), Riolu (R), Shieldon (R), Karrablast (E), Pawniard (Ul) | Dhelmise, Falinks (Trooper), Skarmory | Celesteela, Cobalion, Genesect, Jirachi |
| Ground | 2/4/6/8 | **10**: Swinub (C), Sandygast (U), Wiglett (U), Drilbur (R), Golett (R), Cubone (E), Hippopotas (E), Shellos (West Sea) (E), Rhyhorn (Ul), Teddiursa (Ul) | Dunsparce, Torkoal | Zygarde (10% Forme) |
| Poison | 3/5/7 | **10**: Weedle (C), Galarian Slowpoke (U), Tentacool (U), Venonat (U), Croagunk (R), Glimmet (R), Salandit (R), Skorupi (E), Stunky (E), Gastly (Ul) | Poipole, Seviper | Eternatus, Fezandipiti, Pecharunt |
| *Dragon* | 2/3/4 | **4**: Charmander (C), Noibat (U), Swablu (E), Frigibax (Ul) | Cyclizar, Dracozolt, Turtonator | Eternatus, Kyurem, Reshiram, Zygarde (10% Forme) |
| Field | 3/6/9 | **10**: Mareep (C), Squirtle (C), Cetoddle (U), Espurr (U), Hisuian Growlithe (U), Purrloin (U), Fidough (R), Cubchoo (E), Skiddo (E), Shinx (Ul) | Finizen, Miltank, Passimian, Stantler, Tauros | Entei |
| Monster | 2/4/6/8 | **9**: Aron (C), Cranidos (U), Tangela (U), Bergmite (R), Galarian Yamask (R), Makuhita (R), Drowzee (E), Sneasel (E), Rhyhorn (Ul) | Kangaskhan, Seviper | Kyogre, Mewtwo |
| **Human** ★ | 2/4/6 | **8**: Chimchar (C), Fennekin (C), Machop (U), Mime Jr. (U), Petilil (U), Drowzee (E), Meditite (E), Timburr (Ul) | Smeargle, Tyrogue | Blacephalon, Regice |
| Aquatic | 2/4/6/8 | **9**: Anorith (U), Bidoof (U), Corphish (U), Tentacool (U), Tynamo (U), Bergmite (R), Croagunk (R), Cubchoo (E), Sobble (Ul) | Lapras, Pincurchin | Manaphy, Volcanion |
| Bug | 2/4/6/8 | **10**: Weedle (C), Anorith (U), Pineco (U), Venonat (U), Joltik (R), Kricketot (R), Snom (R), Karrablast (E), Nincada (E), Skorupi (E) | Combee, Dunsparce, Illumise, Poipole, Volbeat | Genesect |
| Flying | 2/4/6/8 | **10**: Charmander (C), Pidgey (C), Starly (C), Weedle (C), Noibat (U), Venonat (U), Woobat (U), Nincada (E), Wattrel (E), Fletchling (Ul) | Aerodactyl, Illumise, Minior, Skarmory, Volbeat | Celesteela, Thundurus |
| *Flora* | 2/3/4/5 | **3**: Sprigatito (C), Petilil (U), Glimmet (R) | Combee | Shaymin |
| Rock | 2/4/6 | **10**: Alolan Geodude (C), Aron (C), Hisuian Growlithe (U), Bergmite (R), Glimmet (R), Shieldon (R), Slugma (R), Carbink (E), Roggenrola (E), Rhyhorn (Ul) | Aerodactyl, Minior, Relicanth, Spiritomb | Terrakion |
| **Ghost** ★ | 2/4/6/8 | **8**: Litwick (C), Hisuian Zorua (U), Sandygast (U), Galarian Yamask (R), Golett (R), Cubone (E), Pumpkaboo (E), Gastly (Ul) | Dhelmise, Hoopa, Spiritomb | Blacephalon, Pecharunt |
| Fairy | 2/4/6/8 | **8**: Azurill (C), Pichu (C), Mime Jr. (U), Fidough (R), Swirlix (R), Carbink (E), Swablu (E), Happiny (Ul) | Azelf, Dedenne, Tandemaus, Tapu Koko | Cresselia, Fezandipiti |
| Ice | 2/4/6/8 | **8**: Swinub (C), Cetoddle (U), Bergmite (R), Snom (R), Amaura (E), Cubchoo (E), Sneasel (E), Frigibax (Ul) | Iron Bundle, Lapras | Kyurem, Regice |
| **Fossil** ★ | 2/4/6 | **8**: Anorith (U), Cranidos (U), Hisuian Voltorb (U), Tangela (U), Kabuto (R), Shieldon (R), Amaura (E), Carbink (E) | Aerodactyl, Dracozolt, Relicanth | Eternatus, Regice |
| **Sound** ★ | 2/4/6 | **8**: Cetoddle (U), Noibat (U), Woobat (U), Bronzor (R), Kricketot (R), Whismur (R), Swablu (E), Grookey (Ul) | Audino, Komala, Lapras | Fezandipiti, Jirachi |
| *Artificial* | 2/3/4 | **3**: Klink (C), Golett (R), Porygon (Ul) | Iron Bundle, Iron Hands | Genesect, Mewtwo, Type: Null |
| *Baby* | 2/3/5 | **5**: Azurill (C), Pichu (C), Mime Jr. (U), Riolu (R), Happiny (Ul) | Tyrogue | — |
| *Light* | 2/3/4/5 | **5**: Litwick (C), Mareep (C), Pumpkaboo (E), Roggenrola (E), Shinx (Ul) | Illumise, Volbeat | Cresselia |
| *Wild* | 2/3/4/5 | **4**: Alolan Rattata (C), Espurr (U), Galarian Meowth (R), Teddiursa (Ul) | Stantler, Tauros | Entei |
| *Amorphous* | 2/3/5 | **5**: Sandygast (U), Tynamo (U), Slugma (R), Shellos (West Sea) (E), Gastly (Ul) | Pincurchin, Spiritomb | Manaphy |
| *Gourmet* | 2/3/4 | **4**: Smoliv (C), Fidough (R), Swirlix (R), Happiny (Ul) | Combee, Miltank | Pecharunt |

Unique (38): Aerodactyl, Audino, Azelf, Combee, Cyclizar, Dedenne, Dhelmise, Dracozolt, Dunsparce, Falinks (Trooper), Finizen, Hoopa, Illumise, Iron Bundle, Iron Hands, Kangaskhan, Kecleon, Komala, Lapras, Miltank, Minior, Morpeko, Passimian, Pincurchin, Poipole, Relicanth, Seviper, Skarmory, Smeargle, Spiritomb, Stantler, Tandemaus, Tapu Koko, Tauros, Torkoal, Turtonator, Tyrogue, Volbeat.

Legendary (25): Blacephalon, Celesteela, Chi-Yu, Cobalion, Cresselia, Entei, Eternatus, Fezandipiti, Genesect, Jirachi, Kyogre, Kyurem, Manaphy, Mewtwo, Pecharunt, Regice, Reshiram, Shaymin, Terrakion, Thundurus, Type: Null, Victini, Virizion, Volcanion, Zygarde (10% Forme).

## 5. Mùa 3: Lễ Hội Ánh Sáng (`s3`)

Máy móc, đèn lồng và yến tiệc: lễ hội nơi những hình thù kỳ lạ nhảy múa.

- **Hệ đặc trưng**: Artificial, Light, Gourmet, Amorphous
- **Hệ đặc biệt** (mốc của mùa): Dragon (2/3/5), Human (2/3/5), Flora (2/3/4/5), Ghost (2/3/4/5), Fossil (2/3/4), Sound (2/3/5), Baby (2/3/5), Wild (2/3/4/5)
- **Trứng** nở ra: Froakie, Gothita, Scorbunny, Tepig

### Shop theo độ hiếm

- **Common** (19): Alolan Geodude, Aron, Azurill, Blipbug, Caterpie, Charmander, Chimchar, Goomy, Klink, Litwick, Mareep, Mudkip, Pichu, Pidove, Poliwag, Seedot, Smoliv, Sprigatito, Swinub
- **Uncommon** (24): Alolan Diglett, Alolan Sandshrew, Bagon, Capsakid, Chinchou, Clobbopus, Cottonee, Gossifleur, Grimer, Koffing, Lechonk, Ledyba, Nidoran ♀, Nosepass, Rufflet, Scraggy, Seel, Shellder, Sinistea, Sizzlipede, Tarountula, Varoom, Yamper, Zorua
- **Rare** (22): Abra, Alolan Vulpix, Binacle, Cacnea, Chewtle, Crabrawler, Drifloon, Electrike, Elgyem, Finneon, Galarian Zigzagoon, Lileep, Nymble, Paldean Wooper, Paras, Patrat, Silicobra, Skwovet, Spoink, Staryu, Tadbulb, Tyrunt
- **Epic** (19): Cherubi, Clamperl, Elekid, Galarian Darumaka, Galarian Ponyta, Gligar, Gulpin, Inkay, Larvesta, Mankey, Munchlax, Onix, Shellos (East Sea), Shuppet, Snover, Snubbull, Stufful, Trubbish, Wailmer
- **Ultra** (12): Fletchling, Frigibax, Grookey, Happiny, Pawniard, Porygon, Rhyhorn, Shinx, Solosis, Teddiursa, Timburr, Venipede

### Theo hệ

| Hệ | Mốc | Shop | Unique | Legendary |
|---|---|---|---|---|
| Normal | 3/5/7/9 | **10**: Pidove (C), Smoliv (C), Lechonk (U), Tarountula (U), Patrat (R), Skwovet (R), Munchlax (E), Stufful (E), Happiny (Ul), Porygon (Ul) | Drampa, Furfrou, Indeedee ♀, Indeedee ♂, Spinda, Zangoose | Meloetta (Aria) |
| Grass | 3/5/7/9 | **10**: Seedot (C), Smoliv (C), Sprigatito (C), Capsakid (U), Cottonee (U), Cacnea (R), Lileep (R), Paras (R), Snover (E), Grookey (Ul) | Applin, Tapu Bulu | Kartana, Ogerpon Teal |
| Fire | 2/4/6/8 | **8**: Charmander (C), Chimchar (C), Litwick (C), Capsakid (U), Sizzlipede (U), Galarian Darumaka (E), Larvesta (E), Fletchling (Ul) | Oricorio (Baile Style), Solrock | Ho-Oh, Ogerpon Teal |
| Water | 3/6/9 | **10**: Azurill (C), Mudkip (C), Poliwag (C), Chinchou (U), Shellder (U), Binacle (R), Finneon (R), Staryu (R), Clamperl (E), Wailmer (E) | Basculin (Blue Stripes), Basculin (Red Stripes), Basculin (White Stripes), Dondozo, Luvdisc, Pyukumuku, Tapu Fini | Palkia |
| Electric | 3/5/7 | **10**: Alolan Geodude (C), Mareep (C), Pichu (C), Chinchou (U), Nosepass (U), Yamper (U), Electrike (R), Tadbulb (R), Elekid (E), Shinx (Ul) | Arctozolt, Iron Thorns, Minun, Oricorio (Baile Style), Plusle, Rotom | Raikou, Regieleki, Xurkitree |
| Fighting | 2/4/6/8 | **9**: Chimchar (C), Poliwag (C), Clobbopus (U), Ledyba (U), Scraggy (U), Crabrawler (R), Mankey (E), Stufful (E), Timburr (Ul) | Great Tusk, Heracross | Buzzwole |
| Psychic | 3/5/7 | **10**: Blipbug (C), Pichu (C), Abra (R), Elgyem (R), Spoink (R), Staryu (R), Clamperl (E), Galarian Ponyta (E), Inkay (E), Solosis (Ul) | Chingling, Cosmog, Indeedee ♀, Indeedee ♂, Oricorio (Baile Style), Sigilyph, Uxie | Lugia, Necrozma |
| Dark | 3/5/7 | **10**: Seedot (C), Sprigatito (C), Scraggy (U), Zorua (U), Cacnea (R), Galarian Zigzagoon (R), Nymble (R), Clamperl (E), Inkay (E), Pawniard (Ul) | Absol, Sableye | Darkrai, Guzzlord, Yveltal |
| Steel | 2/4/6/8 | **9**: Aron (C), Goomy (C), Klink (C), Alolan Diglett (U), Alolan Sandshrew (U), Nosepass (U), Varoom (U), Onix (E), Pawniard (Ul) | Durant, Mawile | Dialga, Kartana, Magearna, Stakataka |
| Ground | 2/4/6/8 | **10**: Mudkip (C), Swinub (C), Alolan Diglett (U), Nidoran ♀ (U), Paldean Wooper (R), Silicobra (R), Gligar (E), Onix (E), Rhyhorn (Ul), Teddiursa (Ul) | Great Tusk | Landorus |
| Poison | 3/5/7 | **10**: Grimer (U), Koffing (U), Nidoran ♀ (U), Varoom (U), Paldean Wooper (R), Paras (R), Gligar (E), Gulpin (E), Trubbish (E), Venipede (Ul) | Pyukumuku | Nihilego |
| *Dragon* | 2/3/5 | **5**: Charmander (C), Goomy (C), Bagon (U), Tyrunt (R), Frigibax (Ul) | Applin, Dracovish, Drampa | Dialga, Palkia, Rayquaza, Regidrago |
| Field | 3/6/9 | **10**: Mareep (C), Lechonk (U), Nidoran ♀ (U), Yamper (U), Zorua (U), Electrike (R), Spoink (R), Snubbull (E), Shinx (Ul), Venipede (Ul) | Furfrou, Minun, Plusle | Glastrier, Raikou, Spectrier |
| Monster | 2/4/6/8 | **9**: Aron (C), Bagon (U), Grimer (U), Chewtle (R), Crabrawler (R), Elgyem (R), Munchlax (E), Snover (E), Rhyhorn (Ul) | Dondozo, Mawile | Guzzlord, Regidrago |
| *Human* | 2/3/5 | **5**: Chimchar (C), Abra (R), Cacnea (R), Elekid (E), Timburr (Ul) | Indeedee ♀, Indeedee ♂ | Regieleki |
| Aquatic | 2/4/6/8 | **9**: Goomy (C), Poliwag (C), Clobbopus (U), Seel (U), Chewtle (R), Paldean Wooper (R), Tadbulb (R), Inkay (E), Shellos (East Sea) (E) | Cramorant, Dracovish, Luvdisc | Lugia, Ogerpon Teal |
| Bug | 2/4/6/8 | **9**: Blipbug (C), Caterpie (C), Ledyba (U), Sizzlipede (U), Tarountula (U), Nymble (R), Paras (R), Larvesta (E), Venipede (Ul) | Durant, Heracross, Scyther | Buzzwole |
| Flying | 2/4/6/8 | **10**: Blipbug (C), Caterpie (C), Charmander (C), Pidove (C), Bagon (U), Ledyba (U), Rufflet (U), Drifloon (R), Gligar (E), Fletchling (Ul) | Cramorant, Delibird, Scyther, Sigilyph | Ho-Oh, Landorus, Lugia, Rayquaza, Tornadus, Yveltal |
| *Flora* | 2/3/4/5 | **4**: Sprigatito (C), Gossifleur (U), Lileep (R), Cherubi (E) | Oricorio (Baile Style) | Ogerpon Teal |
| Rock | 2/4/6 | **10**: Alolan Geodude (C), Aron (C), Nosepass (U), Shellder (U), Binacle (R), Chewtle (R), Tyrunt (R), Onix (E), Shellos (East Sea) (E), Rhyhorn (Ul) | Iron Thorns, Solrock | Nihilego, Ogerpon Teal, Stakataka |
| *Ghost* | 2/3/4/5 | **4**: Litwick (C), Sinistea (U), Drifloon (R), Shuppet (E) | Basculin (White Stripes), Flutter Mane, Oricorio (Baile Style), Rotom, Sableye | Darkrai, Spectrier |
| Fairy | 2/4/6/8 | **8**: Azurill (C), Pichu (C), Cottonee (U), Koffing (U), Alolan Vulpix (R), Galarian Ponyta (E), Snubbull (E), Happiny (Ul) | Flutter Mane, Mawile, Tapu Bulu, Tapu Fini, Uxie | Magearna, Zacian |
| Ice | 2/4/6/8 | **9**: Swinub (C), Alolan Sandshrew (U), Seel (U), Shellder (U), Alolan Vulpix (R), Crabrawler (R), Galarian Darumaka (E), Snover (E), Frigibax (Ul) | Arctozolt, Cryogonal, Delibird | Glastrier, Tornadus |
| *Fossil* | 2/3/4 | **3**: Lileep (R), Tyrunt (R), Clamperl (E) | Arctozolt, Dracovish, Flutter Mane, Great Tusk, Sigilyph | Regidrago |
| *Sound* | 2/3/5 | **5**: Poliwag (C), Gossifleur (U), Galarian Zigzagoon (R), Wailmer (E), Grookey (Ul) | Chingling, Oricorio (Baile Style) | Meloetta (Aria) |
| **Artificial** ★ | 2/4/6 | **8**: Klink (C), Koffing (U), Sinistea (U), Varoom (U), Elekid (E), Shuppet (E), Trubbish (E), Porygon (Ul) | Castform, Iron Thorns, Rotom | Magearna, Xurkitree |
| *Baby* | 2/3/5 | **5**: Azurill (C), Pichu (C), Elekid (E), Munchlax (E), Happiny (Ul) | Chingling | — |
| **Light** ★ | 2/3/4/5 | **10**: Litwick (C), Mareep (C), Chinchou (U), Elgyem (R), Finneon (R), Patrat (R), Tadbulb (R), Cherubi (E), Galarian Ponyta (E), Shinx (Ul) | Cosmog, Solrock | Ho-Oh, Necrozma, Xurkitree |
| *Wild* | 2/3/4/5 | **5**: Rufflet (U), Galarian Zigzagoon (R), Galarian Darumaka (E), Mankey (E), Teddiursa (Ul) | Absol, Basculin (Blue Stripes), Basculin (Red Stripes), Zangoose | Raikou, Zacian |
| **Amorphous** ★ | 3/5/7 | **10**: Caterpie (C), Goomy (C), Clobbopus (U), Grimer (U), Koffing (U), Drifloon (R), Silicobra (R), Gulpin (E), Shellos (East Sea) (E), Solosis (Ul) | Castform, Cryogonal, Pyukumuku | Darkrai, Nihilego, Regieleki |
| **Gourmet** ★ | 3/4/5 | **9**: Smoliv (C), Capsakid (U), Lechonk (U), Sinistea (U), Skwovet (R), Cherubi (E), Gulpin (E), Munchlax (E), Happiny (Ul) | Applin, Delibird, Dondozo, Spinda | Guzzlord |

Unique (39): Absol, Applin, Arctozolt, Basculin (Blue Stripes), Basculin (Red Stripes), Basculin (White Stripes), Castform, Chingling, Cosmog, Cramorant, Cryogonal, Delibird, Dondozo, Dracovish, Drampa, Durant, Flutter Mane, Furfrou, Great Tusk, Heracross, Indeedee ♀, Indeedee ♂, Iron Thorns, Luvdisc, Mawile, Minun, Oricorio (Baile Style), Plusle, Pyukumuku, Rotom, Sableye, Scyther, Sigilyph, Solrock, Spinda, Tapu Bulu, Tapu Fini, Uxie, Zangoose.

Legendary (25): Buzzwole, Darkrai, Dialga, Glastrier, Guzzlord, Ho-Oh, Kartana, Landorus, Lugia, Magearna, Meloetta (Aria), Necrozma, Nihilego, Ogerpon Teal, Palkia, Raikou, Rayquaza, Regidrago, Regieleki, Spectrier, Stakataka, Tornadus, Xurkitree, Yveltal, Zacian.

## 6. Chỉnh sửa

| Khoá của `data/seasons.json` | Ý nghĩa |
|---|---|
| `enabled` | `false` = tắt hẳn mùa: pool như bản web, menu không hiện ô chọn mùa |
| `default` | mùa được chọn lần đầu (sau đó game nhớ lựa chọn của người chơi) |
| `allowFull` | menu có thêm lựa chọn *Tất cả Pokémon* (không mùa) |
| `seasons[i].id` | định danh, dùng trong file lưu kỷ lục và tham số test `season=<id>` |
| `seasons[i].name`, `description` | tiếng Anh; bản dịch thêm vào `data/i18n/ui.json` |
| `seasons[i].shop` | các **họ** (tên dạng đầu) theo độ hiếm; cũng nhận một mảng phẳng |
| `seasons[i].unique`, `legendary`, `hatch` | các họ Unique / Legendary được đề xuất, các dòng nở từ trứng |
| `seasons[i].thresholds` | mốc riêng của mùa cho một hệ — **phải cùng số mốc** với bản gốc |
| `seasons[i].featured`, `special` | chỉ để hiển thị ở menu và trong tài liệu này |

- Thêm / bớt Pokémon: sửa các mảng trong JSON rồi chạy `python tools/port/gen_seasons.py` (kiểm + ghi lại tài liệu
  này) và `sim_test` (`_check_seasons`).
- Thêm mùa: thêm một mục vào `seasons` (hoặc thêm vào bảng `SEASONS` trong tool rồi `--generate`).
- Flabébé: liệt kê cả 5 màu, tính là một họ (mỗi run một màu). Deerling không vào mùa (dạng theo ngày thật).
- Hai dạng của cùng một Pokémon (Vulpix và Alolan Vulpix) không nên ở chung một mùa — tool sẽ báo.
- `--generate` tính lại toàn bộ danh sách bằng thuật toán (tham số ở đầu file tool: số họ mỗi độ hiếm, khoảng
  8–10 / 3–5, hệ đặc trưng từng mùa) — **ghi đè** mọi chỉnh tay.

## 7. Kiểm tra

Tool không báo vấn đề nào: mọi họ hợp lệ, mỗi hệ đủ họ cho mốc đầu, mốc cuối với tới được, mỗi độ hiếm còn
ít nhất 5 họ ở Battle Pass cấp 1.
