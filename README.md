# JudgementRun

A Balatro mod that replaces every Joker in the game with a Judgement card. Anything that would hand you a Joker hands you a Judgement instead, and Judgement creates a random Joker, so Jokers still fill your slots. You just never choose a single one of them.

---

## What it does

| Where a Joker would appear | What appears instead |
|---|---|
| Shop slots | Judgement |
| Buffoon Packs | Judgement |
| Tags that grant a Joker | Judgement |
| The Soul | Judgement |
| Wraith | Judgement |
| Judgement itself | A random Joker, as normal |

Judgement is the one exemption. It has to keep creating Jokers or nothing in the run ever does.

A Judgement with nowhere to go is simply not created. If your consumable slots are full when something tries to give you one, no card appears.

Wraith is worth calling out. It still costs you the money it normally costs, and it still empties your hand of the thing it normally takes, but what you get back is a Judgement. It becomes a trap rather than a shortcut.

Joker slots are untouched. You still have five.

---

## Why Riff-raff is removed

Riff-raff creates its Jokers directly rather than offering them to you, and under this mod it does not convert them reliably. Rather than leave a Joker in the pool that behaves inconsistently with the rule the mod exists to enforce, it is removed from the pool by default. The toggle is there if you want it back.

---

## Installation

Requires [Steamodded](https://github.com/Steamodded/smods) `1.0.0~BETA-0400a` or newer.

Drop the `JudgementRun` folder into your Balatro `Mods/` directory:

```
Mods/
  JudgementRun/
    JudgementRun.json
    JudgementRun.lua
```

No `lovely.toml` is required. This mod patches no vanilla files.

Four toggles live on the mod's config tab:

- **Enable JudgementRun**
- **Price Judgement at what it grants** (off by default, see below)
- **The Soul also gives a Judgement**
- **Ban Riff-raff**

**Price Judgement at what it grants** raises Judgement above its normal $3, on the logic that a card handing you a Joker should cost about what a Joker costs. It ships off. The higher stakes already apply enough money pressure on their own, and the raised price made runs tedious rather than harder.

---

## Compatibility

Single-player Balatro with Steamodded. Nothing outside Joker creation is changed.

---

## Credits

Built by NickTG for a Balatro challenge run series.

Concept suggested by a viewer on the [NickTG](http://www.youtube.com/@NickTGaming) channel.

## License

MIT. See LICENSE.
