# UDAV project memory

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
- `README`: user-facing build instructions, controls, and architecture notes.
- `BUILD.BAT`: DOS build using `TASM/TASM.EXE` and `TASM/TLINK.EXE`.
- `dosbox_udav.conf`: windowed DOSBox configuration that builds and runs UDAV.
- `tests/test_game.py`: Python/Unicorn tests of the compiled machine code.
- Root BMPs: intro, four levels, defeat, and victory artwork.
- `old/` and existing archives: historical versions; preserve them.
- `DOSBOX/`, `TASM/`, and the Al-Qadim example configurations were supplied
  locally and were untracked when this refactor began.

## Build and run

Run from the repository root on Windows:

```powershell
.\DOSBOX\DOSBox.exe -conf dosbox_udav.conf
```

The configuration mounts the working directory as DOS drive C:, calls
`BUILD.BAT`, and runs `BUILD\ZMEI.COM` only if the build succeeded. The game
opens its BMP assets relative to the current DOS directory, so launch it
from the repository root, not from inside BUILD.

The build writes COM/OBJ/MAP/LST files and logs to ignored `BUILD/`.
TASM's output arguments use directories (`ZMEI.ASM,BUILD\,BUILD\`); this
worked reliably on repeated builds with the supplied toolchain. TLINK
options are case-sensitive: use `/t /m`, not `/T /M`.

Root-level `ZMEI.COM`, `ZMEI.OBJ`, and `ZMEI.MAP` are already tracked legacy
artifacts. They may also be rebuilt manually by the user. Inspect their
changes before staging or replacing them; the normal build targets BUILD.

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

## Git convention and workflow

- Existing history uses short plain-language subjects, mostly lowercase,
  without Conventional Commit prefixes. Preserve this style with an
  imperative subject describing the change; add a body for significant work.
- Stage explicit task-related paths. Generated outputs and locally supplied
  tool directories require deliberate consideration, not blanket staging.
- Keep this memory current when architecture, build steps, or rules change.
