"""Generates docs/WORLD.md: weather and region reference, from the exported data.

    python tools/port/gen_world_doc.py

Reads data/pac/config.json (maps, regional, regionalVariants, weatherThreshold),
data/pac/pokemon.json, data/pac/pool.json, data/pac/text.json and data/i18n/vi.json.
Run it again after tools/export_pac.bat when regions or regional Pokémon changed.
The rules written around the tables mirror src/core/weather.gd, src/core/town.gd and
PlayerState.change_map / update_regional_pool: update the text here when they change.
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load(path):
    with io.open(os.path.join(ROOT, path), encoding='utf-8') as f:
        return json.load(f)


config = load('data/pac/config.json')
pokemon = load('data/pac/pokemon.json')
pool = load('data/pac/pool.json')
text = load('data/pac/text.json')
vi = load('data/i18n/vi.json')

# src/core/weather.gd
BY_SYNERGY = {
    'GRASS': 'ZENITH', 'FIRE': 'DROUGHT', 'WATER': 'RAIN', 'GROUND': 'SANDSTORM', 'FAIRY': 'MISTY', 'ICE': 'SNOW',
    'ELECTRIC': 'STORM', 'DARK': 'NIGHT', 'FLYING': 'WINDY', 'WILD': 'BLOODMOON', 'POISON': 'SMOG', 'GHOST': 'MURKY',
    'NORMAL': 'NEUTRAL',
}
WEATHER_ORDER = ['ZENITH', 'DROUGHT', 'RAIN', 'SANDSTORM', 'MISTY', 'SNOW', 'STORM', 'NIGHT', 'WINDY', 'BLOODMOON', 'SMOG',
                 'MURKY', 'NEUTRAL']
PASSIVES = [
    ('RAIN / DROUGHT / ZENITH / SANDSTORM / MISTY / SNOW / STORM / NIGHT / WINDY', '+100 cho thời tiết cùng tên'),
    ('AIRLOCK (Rayquaza)', '+100 cho trời quang: xoá thời tiết'),
    ('CASTFORM', '+100 cho thời tiết trội nhất của sàn mình trong Drought / Zenith / Rain / Snow (hoà thì không)'),
    ('TORNADUS / THUNDURUS / LANDORUS / ENAMORUS', '+100 cho Windy hoặc Snow / Storm / Sandstorm / Misty, cái nào trội hơn trên sàn mình'),
    ('RAIN_OR_STORM, DROUGHT_OR_SANDSTORM (Kyogre, Groudon nguyên thuỷ)', '+100 cho cái trội hơn trên sàn mình (mặc định Rain / Drought)'),
    ('DROUGHT_OR_ZENITH', '+100 cho Zenith nếu sàn có số Light ≥ số Fire, không thì Drought'),
    ('SAND_STREAM, DRIZZLE, WIND_POWER', '+2 thêm cho Sandstorm / Rain / Storm khi chính nó có hệ tương ứng'),
]


def t(section, key, default=None):
    value = vi.get(section, {}).get(key)
    if isinstance(value, str) and value:
        return value
    return text.get(section, {}).get(key, default if default is not None else key)


def type_name(type_id):
    return t('synergy', type_id, type_id.capitalize())


def pkm_name(pkm):
    name = text.get('pkm', {}).get(pkm)
    return name if name else pkm.replace('_', ' ').title()


available = set()
for key in ('pool', 'additional', 'regional', 'unique', 'legendary', 'hatch', 'extras'):
    available.update(pool.get(key, []))

lines = []
out = lines.append
out('# Vùng và thời tiết — tài liệu tham chiếu')
out('')
out('> File này **sinh tự động** bằng `python tools/port/gen_world_doc.py` từ `data/pac/*.json` — đừng sửa tay, sửa script rồi')
out('> chạy lại (sau `tools\\export_pac.bat` nếu vùng / Pokémon vùng thay đổi). Tóm tắt luật cho người chơi: `docs/GAME_DESIGN.md`')
out('> mục 8 và 9.3; chi tiết port: `docs/PORTING.md` mục “Weather” và “Vùng và Pokémon regional”.')
out('')
out('## 1. Thời tiết')
out('')
out('Code: `src/core/weather.gd` (port `app/utils/weather.ts`), gọi từ `FightSetup.weather_for()`.')
out('')
out('- Tính **trước mỗi trận** từ hai sàn: đội người chơi (không tính bench) **và wave địch**. Lúc chuẩn bị, thanh stage hiện')
out('  dự báo theo sàn hiện tại; đổi đội hình là dự báo đổi.')
out('- Mỗi Pokémon **+1 điểm** cho thời tiết của từng hệ nó có (bảng dưới). Hệ do item cho (đá hệ...) cũng tính với đội người chơi.')
out('- Một số passive cộng **+100** (bảng “Passive thời tiết”).')
threshold = config.get('weatherThreshold', {})
values = sorted(set(int(v) for v in threshold.values()))
out('- Thời tiết nhiều điểm nhất thắng nếu đạt **≥ %s điểm** (`config.weatherThreshold`) và **không hoà** với thời tiết khác;' %
    ' / '.join(str(v) for v in values))
out('  không thì trời quang. Hệ Normal bỏ phiếu cho trời quang (kéo về không thời tiết).')
out('- Thời tiết áp dụng cho **cả hai đội**. Pokémon đổi dạng theo thời tiết (Lycanroc, Ursaluna) đổi trước khi trận bắt đầu.')
out('')
out('| Thời tiết | Id | Hệ bỏ phiếu | Hiệu ứng |')
out('|---|---|---|---|')
voters = {}
for type_id, weather in BY_SYNERGY.items():
    voters.setdefault(weather, []).append(type_name(type_id))
for weather in WEATHER_ORDER:
    desc = t('weather_description', weather, '').replace('\n', '; ')
    out('| %s | `%s` | %s | %s |' % (t('weather', weather), weather, ', '.join(voters.get(weather, ['—'])), desc))
out('')
out('Từ khoá VIẾT HOA trong cột hiệu ứng là từ khoá của game (chỉ số, trạng thái), hiển thị thành icon / tên trong tooltip.')
out('')
out('**Passive thời tiết**')
out('')
out('| Passive | Tác dụng lên phiếu |')
out('|---|---|')
for passive, effect in PASSIVES:
    out('| %s | %s |' % (passive, effect))
out('')
out('**Chi tiết trong trận** (`BattleSim`, `Weather`): Windy +10 SPEED (Flying +20); Snow −10 SPEED trừ Ice; Smog +15% né đòn;')
out('Night +10% chí mạng; Murky −30 LUCK trừ Ghost; Rain 13 PP/giây, Drought 7 PP/giây (bình thường 10); Misty ×1.2 sát thương phép;')
out('Bloodmoon ×1.2 sát thương vật lý; Sandstorm 5 sát thương phép mỗi giây trừ Ground; Storm sét đánh ngẫu nhiên 100 sát thương phép')
out('mỗi 4–8 giây (Electric được sạc); thời lượng trạng thái ×1.3 / ×0.7 theo bảng.')
out('')
out('**Muốn chỉnh**: ngưỡng điểm nằm ở bản web (`config.weatherThreshold`, export lại); hệ → thời tiết và hệ số ở đầu')
out('`src/core/weather.gd`; sát thương Sandstorm / Storm là hằng số đầu `src/core/battle_sim.gd`.')
out('')

maps = {k: v for k, v in config['maps'].items() if k != 'town' and v.get('synergies')}
regional = config.get('regional', {})
variants = config.get('regionalVariants', {})
variant_forms = set(v for forms in variants.values() for v in forms)


def first_forms(map_id):
    """Ported regional Pokémon of a region, one per family (its lowest star form)."""
    by_family = {}
    for pkm, info in regional.items():
        if pkm not in available or map_id not in info.get('maps', []):
            continue
        data = pokemon.get(pkm, {})
        family = data.get('family', pkm)
        if family not in by_family or data.get('stars', 1) < pokemon[by_family[family]].get('stars', 1):
            by_family[family] = pkm
    return sorted(by_family.values(), key=lambda p: (config['rarityCost'].get(pokemon[p].get('rarity'), 0), p))


out('## 2. Vùng')
out('')
out('Code: `src/core/town.gd` (`portals`), `PlayerState.change_map()` / `update_regional_pool()`, `GameData.in_region()`.')
out('Dữ liệu: `config.maps` (hệ + nhạc), `config.regional` (Pokémon → các vùng), `config.regionalVariants`.')
out('')
out('- Có **%d vùng**, mỗi vùng **3 hệ** và một bản nhạc. Người chơi bắt đầu ở Thị trấn (`town`, không có hệ).' % len(maps))
out('- **Đổi vùng** ở portal stage 0 / 10 / 20 (và Lapras Passport): mỗi portal có các biểu tượng hệ (stage 0: ngẫu nhiên; sau đó:')
out('  4 hệ mạnh nhất của đội) và dẫn tới vùng có nhiều hệ chung nhất với biểu tượng của nó, không lặp vùng.')
out('- Vào vùng mới: nhạc đổi, **cây quả mọng (Grass) trồng lại**, pool vùng cũ bị xoá và pool vùng mới được nạp.')
out('- **Pokémon vùng** chỉ vào shop khi vùng có ít nhất một hệ của nó (với biến thể: một hệ mà dạng gốc không có).')
out('  **Biến thể vùng** thay cho dạng gốc trong shop và trong đề xuất starter / Unique / Legendary.')
out('- Unique / Legendary vùng chỉ được đề xuất ở portal khi đang ở vùng của chúng.')
out('- Bán Pokémon vùng ở vùng khác: không trở về pool.')
out('')
out('### 2.1 Danh sách vùng')
out('')
out('Cột “Pokémon vùng” liệt kê dạng đầu của mỗi họ đã port, rẻ trước; *nghiêng* = biến thể thay cho dạng gốc; **đậm** = Unique / Legendary.')
out('')
out('| Vùng | Id | Hệ | Số họ | Pokémon vùng |')
out('|---|---|---|---|---|')


def fmt(pkm):
    name = pkm_name(pkm)
    if pokemon[pkm].get('rarity') in ('UNIQUE', 'LEGENDARY'):
        return '**%s**' % name
    if pkm in variant_forms:
        return '*%s*' % name
    return name


by_type = {}
counts = []
for map_id in sorted(maps, key=lambda m: t('map', m)):
    info = maps[map_id]
    forms = first_forms(map_id)
    counts.append((len(forms), t('map', map_id)))
    for type_id in info['synergies']:
        by_type.setdefault(type_id, []).append(t('map', map_id))
    out('| %s | `%s` | %s | %d | %s |' % (t('map', map_id), map_id, ', '.join(type_name(s) for s in info['synergies']), len(forms),
                                      ', '.join(fmt(p) for p in forms) or '—'))
out('')
counts.sort(reverse=True)
out('Nhiều Pokémon vùng nhất: %s. Ít nhất: %s.' % (
    ', '.join('%s (%d)' % (name, n) for n, name in counts[:3]), ', '.join('%s (%d)' % (name, n) for n, name in counts[-3:])))
out('')
out('### 2.2 Vùng theo hệ')
out('')
out('| Hệ | Số vùng | Vùng |')
out('|---|---|---|')
for type_id in config['synergyThresholds']:
    names = by_type.get(type_id, [])
    out('| %s | %d | %s |' % (type_name(type_id), len(names), ', '.join(names) or '—'))
out('')
out('### 2.3 Biến thể vùng')
out('')
out('| Dạng gốc | Biến thể | Hệ của biến thể | Cần mở khoá | Số vùng |')
out('|---|---|---|---|---|')
for base, forms in variants.items():
    for form in forms:
        if form not in available:
            continue
        info = regional.get(form, {})
        out('| %s | %s | %s | %s | %d |' % (pkm_name(base), pkm_name(form), ', '.join(type_name(s) for s in pokemon[form].get('types', [])),
                                        pkm_name(info['requires']) if info.get('requires') else '—', len(info.get('maps', []))))
out('')
out('“Cần mở khoá”: họ additional phải vào shop trước (additional pick stage 5 / 8 / 11) thì biến thể mới xuất hiện.')
out('')
families = set(pokemon[p].get('family', p) for p in regional if p in available)
out('Tổng: %d dạng regional đã port (%d họ), trong %d dạng bản web có luật vùng.' % (
    len([p for p in regional if p in available]), len(families), len(regional)))
out('')

path = os.path.join(ROOT, 'docs', 'WORLD.md')
with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(lines))
print('wrote %s: %d regions, %d lines' % (path, len(maps), len(lines)))
