# UDAV project memory

Last checked against the repository on 2026-10-23.

## Purpose and compatibility

- UDAV is a DOS snake game written in x86 assembly, originally tested by the
  author in VMware, DOSBox, and on a real 386 PC.
- The maintained source is `zmei.asm`: TASM/MASM syntax, tiny model, a single
  `.COM` segment with `org 100h`. The current source uses 8086 instructions.
- Keep changes compatible with real-mode DOS and the supplied Borland tools.
  The local executables identify themselves as TASM 2.5 and TLINK 4.0,
  although the original README referred to Turbo Assembler 5.0.
- Prefer descriptive labels, named constants/storage, small near procedures,
  and comments documenting procedure inputs, outputs, and register usage.

## Important paths

- `zmei.asm`: menu/level flow, bitmap I/O, rendering, movement, input, timing,
  game state, buffers, and private stack.
- `README.md`: user-facing build instructions, controls, and architecture notes.
- `CONTRIBUTING.md`: contribution guide (renamed from `contribution.md`);
  build/test steps, coding conventions, bug reports, and pull request guidance.
- `LICENSE`: standard MIT license, copyright 2026 Boriss Melikjan. Bundled
  third-party tools retain their respective licenses.
- `BUILD.BAT`: DOS build using `TASM/TASM.EXE` and `TASM/TLINK.EXE`.
- `LAUNCH.BAT`: interactive build/run/logs menu using DOSBox's built-in CHOICE.
- `dosbox_udav.conf`: windowed DOSBox configuration that starts the menu.
- `tests/test_game.py`: Python/Unicorn tests of the compiled machine code.
- Root BMPs: intro, four levels, defeat, and victory artwork.
- `old/` and existing archives: historical versions; preserve them.
- `DOSBOX/` and `TASM/`: bundled and tracked DOSBox/runtime and Borland tools.
- `BUILD/`: tracked generated outputs, logs, and DOSBox smoke-test helpers.
- `UDAV-1_2.zip`: version 1.2 release archive.

## Build and run

Run from the repository root on Windows:

```powershell
.\DOSBOX\DOSBox.exe -conf dosbox_udav.conf
```

The configuration mounts the working directory as DOS drive C: and calls
`LAUNCH.BAT`. Options: 1 build and run, 2 build only, 3 run the existing
build, 4 view build logs, 5 return to the DOS prompt. Build-and-run invokes
`BUILD.BAT` and launches only on success; quitting the game returns to the
menu. On real DOS the menu requires CHOICE; BUILD.BAT works independently.
The game opens BMP assets relative to the current DOS directory, so launch
it from the repository root, not from inside BUILD.

For a DOSBox prompt without the menu, add `-noautoexec -c "mount c ." -c "c:"`
to the launch command. README.md documents both BUILD.BAT and the individual
assembler/linker commands, including their output paths and options.

The build writes COM/OBJ/MAP/LST files and logs to `BUILD/`. This directory
is tracked, as are the bundled tools; it is no longer ignored. `.gitignore`
currently contains only `__pycache__/`. Builds and DOSBox runs can therefore
modify tracked outputs/logs: inspect their diffs before staging them.
TASM's output arguments use directories (`ZMEI.ASM,BUILD\,BUILD\`); this
worked reliably on repeated builds with the supplied toolchain. TLINK
options are case-sensitive: use `/t /m`, not `/T /M`.

Root-level `ZMEI.COM`, `ZMEI.OBJ`, `ZMEI.MAP`, and `ZMEI.LST` were updated
for the 1.2 release in commit `4ca4125`; they are tracked release artifacts,
not untouched 1.1 binaries. The normal build still targets BUILD. Update
root outputs/archive deliberately when preparing another release.

## Releases and tags

- UDAV 1.2 is based on the 2026-10-23 refactor, bug fixes, updated binaries,
  build tooling, tests, and launcher documentation.
- Use the `v` prefix for release tags. Current annotated tags:
  - `v1.0` -> `07e63ce` (original project snapshot).
  - `v1.1` -> `5f37a2d` (last commit before the 2026-10-23 changes).
  - `v1.2` -> `18455ed` (build/run documentation and bundled tools).
- Unprefixed tags `1.0`, `1.1`, and `1.2` were deleted locally and verified
  absent from origin at the user's request. Keep the prefixed naming style.
- Contribution/license additions and subsequent documentation changes are
  later than the `v1.2` tag. A release tag does not automatically follow HEAD.

README.md now identifies version 1.2, summarizes its changes, documents
prebuilt/release-archive play, and accurately describes tracked BUILD output
and root release artifacts. BUILD.BAT does not refresh root binaries or the
release archive. Keep these details synchronized when preparing a release.

## Game invariants and intentional behavior

- VGA mode 13h: 320x200 pixels, represented as 160x100 logical 2x2 cells.
- Packed cell positions use AL for column (0..159), AH for row (0..99).
  Do not revert to byte-sized pixel coordinates: x would wrap at pixel 256.
- The VGA framebuffer doubles as the collision/food map. Palette index 15
  is solid for both walls and snake cells.
- Palette index 2 grows by one; 4 grows by two. Double growth temporarily
  duplicates the tail position; erasure and shrinking must handle overlap.
- Index 3 is the original castor-oil mechanic: shrink by one and turn the
  discarded tail into a green apple. Food count stays unchanged because one
  item is consumed and another spawned. At length two it is simply eaten.
- Snake length is bounded to 2..1024. Growth beyond capacity consumes the
  food without extending the buffer.
- BMPs must be uncompressed 160x100, 8-bit, with a 1078-byte header/palette.
  Use the default VGA palette and draw rows in file order, intentionally
  preserving the existing artwork rather than reversing BMP scanlines.
- F1 selects two BIOS ticks/move; F2 selects one. Any key starts a level.
  Arrows steer, direct reversal is ignored, Escape/F10 quits. F1/F2 after
  defeat or victory restarts at level 1. Victory follows level 4.
- Keep the stack balanced and clear DF after backward string operations.
  Restore the saved video mode on normal exit and asset-loading failure.
- Timer waits compare successive BIOS ticks and select INT 1Ah/AH=0 on each
  call, handling both low-word rollover and the midnight clock reset.

## Verification

1. Build with the bundled tools in DOSBox. Inspect `BUILD/ASSEMBLE.LOG` and
   `BUILD/LINK.LOG`; a DOSBox process exit code alone does not prove success.
2. Install Python's `unicorn` package and run:
   `python -m unittest discover -s tests -v`.
3. Check interactive behavior in DOSBox or real DOS when changing gameplay.

The refactor passed 14 machine-code tests: exact rendering of all assets,
food counts/effects, movement/collision, full-width bounds, buffer capacity,
input, timer rollover, malformed/missing files, and menu/defeat/victory flow.
BIOS/DOS services are stubbed in these tests. Level-flow tests place the
final apple directly ahead of the snake to reach all screens quickly.
A separate DOSBox smoke check passed using BIOS-queued F2, Space, Escape.
`BUILD/DOSKEYS.ASM` queues those keys for the game smoke check.
The launcher was also checked in DOSBox with BIOS-queued keys through all
five menu actions, including build-and-run and run-existing game sessions.
The check confirmed all queued keys were consumed and UDAV_BUILT was 1.
`BUILD/MENUKEY.ASM` queues menu/game keys; `BUILD/MENUCHK.ASM` verifies the
keyboard queue was consumed. These helpers and their generated outputs/logs
are now tracked. These results refer to the refactor/launcher validation;
subsequent documentation-only changes have not changed the game code.

## Git convention and workflow

- Existing history uses short plain-language subjects, mostly lowercase,
  without Conventional Commit prefixes. Preserve this style with an
  imperative subject describing the change; add a body for significant work.
- Stage explicit task-related paths. Tracked generated outputs and bundled
  tool directories require deliberate consideration, not blanket staging.
- Keep this memory current when architecture, build steps, or rules change.
