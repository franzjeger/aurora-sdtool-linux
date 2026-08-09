# Native Linux memory tools

Aurora is not the only way to cheat in a game on Linux, and for some problems
it is not the best one. This is the alternative, and when to reach for it.

## They are not substitutes

| | Aurora | Native tools |
| --- | --- | --- |
| What you get | Curated trainers, maintained per game version | A scanner. You find the values yourself |
| Cost | CheatHappens account, some features paid | Free |
| Effort per game | One click | Minutes to hours, and again after each patch |
| Hotkeys while fullscreen | The known weak spot | Not affected |

Aurora's value is the reverse-engineering CheatHappens already did. Switching to
a scanner does not port those trainers across — it means doing that work
yourself. Keep both, and pick per situation.

## Why the native route wins on Wayland

Aurora runs *inside* the game's Wine prefix, so its hotkeys live in the game's
own X11 input context. A fullscreen game that grabs the keyboard swallows them,
and under gamescope it is worse — upstream removed its window-focus workarounds
in 3.2.0 because they never worked there.

A native tool runs outside the game entirely. It is an ordinary Linux window you
alt-tab to, driven by your compositor's real global shortcuts. The focus problem
that Aurora cannot solve does not arise.

Hooking itself is unaffected either way: a Proton game is a normal Linux process
and its memory is readable with `ptrace`, whatever the display server.

## What is installed

| Tool | Command | Notes |
| --- | --- | --- |
| scanmem | `scanmem` | CLI scanner |
| GameConqueror | `gameconqueror` | GTK front-end for scanmem; escalates via polkit |
| PINCE | `PINCE` | Qt front-end over GDB, closest thing to Cheat Engine |

`scanmem` and `gameconqueror` come from the `extra` repository; `pince-bin`
comes from the AUR.

## The ptrace permission problem

This system runs `kernel.yama.ptrace_scope = 1`, which allows a process to
attach only to its own descendants. A game launched by Steam is not a descendant
of your scanner, so attaching as your normal user fails:

```
$ gdb --batch -p <plasmashell pid> -ex detach
ptrace: Operation not permitted.
```

As root the same attach succeeds. Three ways to deal with it, best first:

1. **Let the tool escalate.** GameConqueror ships a polkit action and asks for
   authentication when it needs it. Nothing to configure — just launch it from
   your menu. PINCE prompts for `sudo` the same way.

2. **Run the CLI under sudo** when you want `scanmem` directly:

   ```bash
   sudo scanmem -p <pid>
   ```

3. **Loosen it globally** — only if the above get in your way. This lets any
   process of yours read any other, which is a real reduction in isolation:

   ```bash
   echo 'kernel.yama.ptrace_scope = 0' | sudo tee /etc/sysctl.d/10-ptrace.conf
   sudo sysctl --system
   ```

Option 1 is enough for almost everything. Do not reach for option 3 by reflex.

## Attaching to a Proton game

The game runs as a Windows executable inside a Wine process, so look for the
`.exe`:

```bash
pgrep -af '\.exe' | grep -iv -e proton -e steam -e wine -e services -e explorer
```

GameConqueror and PINCE both have a process picker that shows the same list.
Attach to the `.exe` matching your game — not to `wineserver`, and not to the
Proton wrapper scripts.

From there it is an ordinary scan: search for a value, change it in game,
narrow the results, then edit or freeze what remains.

## Cheat Engine tables

Community `.CT` tables from sites like FearLessRevolution are Cheat Engine's own
format. PINCE cannot read them, and neither can scanmem.

To use one you need Cheat Engine itself, run under Wine **in the same prefix as
the game** so it can see the game's memory. That works, but it puts you back
inside the game's input context — the fullscreen hotkey problem returns, because
CE is then in exactly the position Aurora is in.

## Anti-cheat

None of this is safe in a game with EAC or BattlEye. Attaching a debugger is
precisely what they detect. Single-player only.
