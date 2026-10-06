# Forever Map Notes

`Forever Map Notes` is a standalone map notes addon for World of Warcraft Forever.

It adds manual map notes, edit/delete dialogs, map coordinates, and automatic node notes for mining, herbalism, and treasure chests.

## Install

Copy the `Forged_ForeverMapNotes` folder into the Forever client's `Interface\AddOns` folder
and enable it on the character select screen.

## Usage

- **Ctrl+Right-click** the world map: add a note.
- **Right-click** a note: edit or delete it.
- Note button in the map's bottom-left corner: show/hide categories, toggle auto-logging.
- Mining, herb and treasure gathers are logged automatically.

Slash commands: `/fmn add <text>`, `/fmn show|hide <notes|mining|herb|treasure>`,
`/fmn auto on|off`, `/fmn debug`, `/fmn count`.

## Known unknowns (beta)

- `## Interface: 16001` is taken from third-party reports. Check with
  `/dump select(4, GetBuildInfo())` and update the `.toc` if it differs.
- Saved variables reportedly don't persist in some beta builds, so notes may be lost
  on logout until Blizzard fixes that.
- Gathering detection matches English spell names in `Gathering.lua`. If a gather
  isn't logged, run `/fmn debug`, gather once, and add the printed spell name.
