# Free versions

Cut-down builds meant to be handed out. Each one is a **separate script**, not
the paid build with switches thrown — a flag-gated build still ships every line
of the paid code, and anyone reading the file can flip the flag. What is not in
these files cannot be turned on in these files.

| File | Full version | Lines |
|---|---|---|
| `PIHD-Free.lua` | `PIHD.lua` | ~900 vs ~6,500 |

## PIHD-Free.lua

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aparaanana-hue/DW/main/free%20versions/PIHD-Free.lua"))()
```

**Included** — live island scan (coins, items, vending modes, island code),
coin deposit/withdraw, item deposit/empty with a type filter, price scanning to
file or clipboard, crop auto-harvest, auto eat, walk speed, jump, infinite jump,
noclip, anti-AFK, theme, self test.

**Held back for the full build** — Run Coins and Run Items, Apply Prices, the
price webhook, the Restock and Bank-to-Vendings loops, the auto stocker, the
vending sniper, the chest manager, saved vending groups, openables, travel,
planting and plowing, flowers and trees, demolition, combat and auto farm, boss
auto spawn, the Sakura event, and undo history.

**No telemetry.** The full build posts a launch notice to a Discord webhook
carrying username, user id, account age, island code and executor. This build
does not phone home at all.

The price file this build writes is the same format the full build reads as a
source, so nothing saved here is wasted if someone upgrades.
