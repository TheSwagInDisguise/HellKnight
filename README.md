# HellKnight

An isometric action roguelike for iOS, written in Swift with SpriteKit. Fight your way out of a burning underworld, one chamber at a time.

The game is drawn in a dark gothic ink-engraving style: bone-white and black linework with hatched shading, and blood-red accents. Each area adds its own glow color. Menus use ornate gilded frames, and boons are offered on tarot-style cards. All art and sound effects are generated in code, so the project has no external assets.

## Features

- **Fast top-down combat.** Attack combos, a weapon special, a ranged cast, and a dash with invincibility frames that also cancels attacks. Hits use hit-stop, screen shake and haptics.
- **3 weapons:** *Cinderblade* (sweeping slashes and a spin attack), *Hellpike* (long thrusts and a thrown spear that pierces), *Doomfists* (fast punches and a ground slam).
- **5 infernal patrons offer boons.** Each patron applies its element to your Attack, Special, Cast or Dash, and also has its own passive blessings:
  - Ignar: Burn
  - Sereth: Chill
  - Kharos: Shock (chain lightning)
  - Mother Vey: Leech (healing)
  - Ombrae: Crits

  Boons come in four rarities: Common, Rare, Epic and Legendary.
- **Hand-designed arenas.** Room layouts include crosses, L-shaped halls, chasm bridges, block mazes and courtyards, and are randomly mirrored. Arenas are filled with:
  - stone blocks and pillars to fight around
  - chasms you can knock enemies into
  - burning pools that hurt anyone standing in them
  - timed spike traps
  - breakable urns full of gold
- **Branching path.** You choose your next chamber by the reward shown on its door. There are 2 or 3 doors to pick from:
  - boon, gold, Infernal Heart, Soul Shards, or the Hellforge Anvil
  - **Elite Chambers:** a harder fight that rewards a **Relic**
  - **Rest Shrines:** a fountain that heals you
  - **Cursed Altars:** a power-for-a-price bargain
  - an Ash Merchant shop on every depth
- **Relics:** run-long items such as Phoenix Feather (extra life), Gambler's Die (4 boon choices), Bloodstone (heal on kill) and more.
- **3 depths, each ending in a guardian boss.** Every boss has several attack patterns and an enraged second phase:
  - Cinder Halls
  - Ossuary Wastes
  - Abyssal Throne
- **Enemies:** imps (lunge at you), bone archers (shoot), brutes (charge), wisps (explode) and hex priests (fire bullet rings). Elite versions appear in deeper levels.
- **Vows.** Before a run you can take optional curses in the Sanctum, such as foes dealing more damage, extra foes, tougher bosses or pricier shops. Each one adds Heat, and every point of Heat earns +15% Soul Shards. Your highest Heat escape is recorded.
- **Meta-progression.** Soul Shards are kept when you die. Spend them at the *Altar of Embers* in the Sanctum hub on max health, damage, speed, extra dashes, revives and more.

## Controls (landscape)

| Input | Action |
|---|---|
| Left side of screen | Floating joystick to move |
| Big sword button | Attack (hold to keep the combo going) |
| Wind button | Dash |
| Hurricane button | Special |
| Flame button | Cast |
| `II` button | Pause / see your boons / abandon run |

Attacks and casts auto-aim at nearby enemies in the direction you're holding. With the joystick released, they aim at the nearest enemy.

## Getting the IPA

Every push also runs the game in the iOS Simulator and saves screenshots as a workflow artifact (Actions → the run → Artifacts → `screenshots`).

Every push triggers the **Build IPA** GitHub Action, which runs on a macOS runner. It:

1. generates the Xcode project with XcodeGen,
2. builds an **unsigned** `HellKnight.ipa`,
3. uploads the IPA as a workflow artifact,
4. publishes it to the rolling **`latest`** release.

Download `HellKnight.ipa` from the repo's **Releases → latest** page, then sideload it. Any of these tools will sign it with your own Apple ID:

- AltStore / SideStore
- Sideloadly
- TrollStore (on supported iOS versions, no re-signing needed)

Requires iOS 15 or later.

## Character art

Characters are 2D skeletal rigs drawn in an ink style. They are rendered to animated sprite sheets in `HellKnight/Sprites/` by the generator in `tools/spritegen/`. To regenerate the sheets after changing a rig:

```sh
pip install skia-python numpy pillow
cd tools/spritegen && python build.py ../..
```

## Building locally (macOS)

```sh
brew install xcodegen
xcodegen generate
open HellKnight.xcodeproj
```
