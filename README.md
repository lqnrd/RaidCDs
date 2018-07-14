# RaidCDs

Shows available Raid CDs and their remaining cooldown. Similar to [TankCDs](https://github.com/lqnrd/TankCDs), but shows raid-wide damage mitigation and utility CDs instead of personal.

Makes use of [LibGroupInSpecT](https://www.wowace.com/projects/libgroupinspect/) functions to scan group member's specs and talents.

![screenshot](https://q-nerd.de/src/q1430950560141lk.raidCDs.jpg)

`/raidcds` to show command options (e.g. `/raidcds move` to move the frame around).

Options are:
  * move: move the frame around

  * reset: reset position

  * toggle: show/hide the frame

  * hideself: show/hide the player's own CDs

  * showcr: show/hide combat rez timer

  * update: force a rescan of all raid members

Upon joining a group it may take a while for all CDs to show up.
