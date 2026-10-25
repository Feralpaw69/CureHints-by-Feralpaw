# CureHints

A small add-on for **World of Warcraft 3.3.5a** (Wrath of the Lich King) that works together with **Decursive**.

It puts a letter on every Decursive square that shows a debuff you can cure, telling you **which mouse button cures it**:
<img width="127" height="104" alt="image" src="https://github.com/user-attachments/assets/22a6e8fd-7f48-44d5-bac5-46464adf73db" />

| Letter | Click |
|---|---|
| **L** | left click |
| **R** | right click |
| **M** | middle click |
| **cL**, **sR**, **aL** … | with Ctrl / Shift / Alt held |

The letters always follow your own mouse-button setup in Decursive's options.

> **Why not just make both buttons cure everything?** During combat WoW locks what a click casts, and secure code can't read debuff types, so no add-on on 3.3.5a can pick the right cure for you mid-fight. CureHints shows you which button to press instead.

## Test mode

Type `/curehints test` to give every Decursive square a fake debuff. The type changes every 3 seconds and walks through every cure your class has, so you can see all colours and letters without waiting for a real debuff. Nothing happens to your real party members. Type the command again to stop — it also turns itself off when combat starts.

## Commands

| Command | What it does |
|---|---|
| `/curehints` | help |
| `/curehints test` | toggle test mode |
| `/curehints on` / `off` | show / hide the letters |

## Installation

1. Install **Decursive** (required) — any 3.3.x version.
2. Download the latest zip from [Releases](../../releases).
3. Extract it into `World of Warcraft\Interface\AddOns\` so you get `Interface\AddOns\CureHints\CureHints.toc`.
4. Restart the game.

## Compatibility

Checked against the official Decursive source for the versions used on 3.3.x clients:

| Decursive | Status |
|---|---|
| 2.4.5.1 | supported (default button order) |
| 2.5.0 | supported |
| 2.5.1 | supported |
| 2.5.2.x | supported |

## Disclaimer

CureHints is an **unofficial** add-on. It is not made by, endorsed by or affiliated with John Wellesz (Archarodim), the author of Decursive, and it contains no Decursive code. Decursive must be installed separately from its official sources.

## License

[MIT](LICENSE) © feralpaw
