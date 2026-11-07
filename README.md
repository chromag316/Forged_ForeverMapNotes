# Forever Map Notes

`Forever Map Notes` is a standalone map notes addon for World of Warcraft Forever.

It adds manual map notes, edit/delete dialogs, map coordinates, and automatic node notes for mining, herbalism, and treasure chests, plus vendors that sell recipes.

## Install

Copy the `Forged_ForeverMapNotes` folder into the Forever client's `Interface\AddOns` folder
and enable it on the character select screen.

## Usage

- **Ctrl+Right-click** the world map: add a note.
- **Right-click** a note: edit or delete it.
- Note button in the map's bottom-left corner: show/hide categories, toggle auto-logging.
- Mining, herb and treasure gathers are logged automatically.
- Vendors that sell recipes are logged when you open their window. The note's
  tooltip lists every recipe seen there. Recipe vendor notes are saved per
  character; all other notes are shared across the account.
- The addon ships with known mining and herb nodes (`Data/KnownNodes.lua`).
  They're added to your notes once; deleting one keeps it deleted.

Slash commands: `/fmn add <text>`, `/fmn show|hide <notes|mining|herb|treasure|recipes>`,
`/fmn auto on|off`, `/fmn debug`, `/fmn count`.

## Sharing gathering nodes

Players send their account's SavedVariables file:

    WTF\Account\<ACCOUNT>\SavedVariables\Forged_ForeverMapNotes.lua

Merge one or more of those files into the shipped data, then release a new
addon version:

    python tools/merge_known_nodes.py <file> [<file> ...]

Only mining and herb notes are taken. Nodes already known (same name within
0.5% of the map) are skipped, and new ones are added as a new batch that each
account imports once. `--dry-run` reports counts without writing.

## Known unknowns (beta)

- `## Interface: 16001` is taken from third-party reports. Check with
  `/dump select(4, GetBuildInfo())` and update the `.toc` if it differs.
- Saved variables reportedly don't persist in some beta builds, so notes may be lost
  on logout until Blizzard fixes that.
- Gathering detection matches English spell names in `Gathering.lua`. If a gather
  isn't logged, run `/fmn debug`, gather once, and add the printed spell name.
