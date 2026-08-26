================================================================================
ROBLOX ISLANDS - ELECTRICITY SYSTEM
Reference pack + build plans
================================================================================
Source: https://robloxislands.fandom.com/wiki/Category:Electricity
Compiled: 2026-08-25

--------------------------------------------------------------------------------
FILES IN THIS FOLDER
--------------------------------------------------------------------------------
README.txt                 <- you are here. Read this first.
01-blocks-reference.txt    Every electricity block: recipe, bench level, behavior.
02-power-rules.txt         How power actually flows. The rules that break builds.
03-logic-cookbook.txt      Gate truth tables + the circuits you can/can't make.
04-project-adder.txt       Full build plan: 4-bit binary calculator (adder).
05-projects-other.txt      6 smaller projects, wiring included.
06-bom.txt                 Bill of materials / block counts for every project.

--------------------------------------------------------------------------------
THE 30-SECOND VERSION
--------------------------------------------------------------------------------
Every gate, LED, switch and splitter is ONE BLOCK. A working calculator is
roughly 40-50 blocks placed in a flat field, wired with the Wire Tool. That is
the real cost of these projects: not materials, FLOOR SPACE and WIRING TIME.

Power in this game is a NUMBER (an amount), not just on/off. Gates pass power
through from their inputs - they never create it. There is NO NOT gate, and no
NAND/NOR/XNOR either. The devs left them out on purpose: a gate that outputs
power with no input would be free infinite energy.

That single fact decides what is possible:

  CAN BUILD  - adders (XOR = sum, AND = carry, no inversion needed)
             - combination locks, AND-chains
             - timers/flashers, item sorters, auto-farm shutoffs
             - analog power meters (bar graphs)

  CANNOT BUILD - subtraction (needs two's complement, needs NOT)
               - memory: latches, flip-flops, registers (needs a feedback loop,
                 and a loop has no power source of its own)
               - anything multi-step/sequenced
               - "output ON when input OFF" of any kind

So "calculator" in Islands means: a binary ADDER with LED output. That is
genuinely buildable and it is the flagship project here (see 04).

--------------------------------------------------------------------------------
BEFORE YOU START BUILDING
--------------------------------------------------------------------------------
1. Upgrade the Electrical Workbench to LEVEL 3. Half the useful blocks are
   locked behind L2/L3 and you do not want to discover that mid-build.
2. Get a Steam Generator (60 power, coal-fed, can be auto-fed by a coal totem
   on a conveyor). It is the only clean infinite power source. Coal Generators
   (~20-30) are fine for small stuff.
3. Stock Electrite. Every project here is electrite-limited, not iron-limited.
   The 4-bit adder alone wants ~980 electrite.
4. Plan the FOOTPRINT on paper first. 17 gate blocks + 14 splitters + 8 switches
   + 5 LEDs does not fit in a corner of your base.

--------------------------------------------------------------------------------
KNOWN QUIRKS / GOTCHAS
--------------------------------------------------------------------------------
* Switch visually snaps to "off" when you rejoin the game, but power KEEPS
  flowing. Your circuit is still live. Toggle it twice to resync.
* Timers cannot be stacked or chained. You get exactly ONE 2-second clock
  domain per circuit. Plan around it.
* Splitters DIVIDE power. Long chains of splitters starve the far end. This is
  the #1 reason builds fail. See 02-power-rules.txt.
* Wiki lists the Combiner recipe two different ways (3 iron in the infobox,
  8 iron in the crafting table). Assume 8 and you won't be short.
* There is a cap on how many power sources you can place before the workbench
  needs upgrading. Exact number not documented on the wiki.
