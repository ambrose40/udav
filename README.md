# Snake UDAV 1.2

DOS snake game written in x86 assembly using Turbo Assembler and Turbo Link.
The source uses 8086 instructions and fits in one `.COM` segment.
Guide the snake through four bitmap-based levels, collecting food and avoiding
walls and its own body. The game uses VGA mode 13h (320x200) and BIOS keyboard
and timer services; the original was tested on a real 386, VMware, and DOSBox.

## Table of contents

- [Project structure](#project-structure)
- [What's new in 1.2](#whats-new-in-12)
- [Build and run with the DOSBox menu](#build-and-run-with-the-dosbox-menu)
  - [Run the release on DOS](#run-the-release-on-dos)
- [Compile and link manually](#compile-and-link-manually)
  - [Option A: use the build script](#option-a-use-the-build-script)
  - [Option B: invoke the assembler and linker directly](#option-b-invoke-the-assembler-and-linker-directly)
  - [Build output and troubleshooting](#build-output-and-troubleshooting)
- [Controls and rules](#controls-and-rules)
- [Source layout](#source-layout)
- [Machine-code regression checks](#machine-code-regression-checks-optional-on-the-host)
- [Contributing](#contributing)
- [License](#license)

## Project structure

```text
zmei.asm           Game source: rendering, movement, input, and level flow
*.bmp              Level maps and intro/defeat/victory screens
BUILD.BAT          Assemble and link with the bundled Borland tools
LAUNCH.BAT         Interactive build/run/logs menu
dosbox_udav.conf   DOSBox settings and launcher startup
DOSBOX/            Bundled Windows DOSBox runtime and its documentation
TASM/              Bundled assembler, linker, and supporting files
BUILD/             Build outputs, logs, and DOSBox smoke-test helpers
tests/             Python/Unicorn machine-code regression tests
ZMEI.COM           Prebuilt release executable (OBJ/MAP/LST alongside it)
UDAV-*.zip         Packaged releases
old/               Earlier game version and artwork
CONTRIBUTING.md    Contribution and testing guidelines
LICENSE            MIT license for UDAV
.agents/           Project memory and working notes
```

## What's new in 1.2

- Clearer assembly with named state, documented procedures, and shared
  movement/rendering routines.
- Fixes for coordinate wrapping, snake growth/shrink limits, overlapping
  tails, bitmap-loading errors, timer rollover, and victory/exit behavior.
- An interactive DOSBox launcher with build, run, and build-log options.
- Bundled DOSBox and TASM/TLINK tools, updated game binaries, and the
  [UDAV-1_2.zip](UDAV-1_2.zip) release archive.
- 14 machine-code regression tests covering rendering, gameplay, error
  handling, and level flow; the build and launcher were also checked in DOSBox.

## Build and run with the DOSBox menu

From **the repository root**, run this in Windows PowerShell:

```powershell
.\DOSBOX\DOSBox.exe -conf dosbox_udav.conf
```

`dosbox_udav.conf` mounts the current directory as DOS drive `C:` and starts
`LAUNCH.BAT`, which provides this menu:

| Key | Action |
| --- | --- |
| 1 | Assemble, link, and run the game if the build succeeds |
| 2 | Assemble and link only |
| 3 | Run the existing `BUILD\ZMEI.COM` |
| 4 | Display assembler and linker logs |
| 5 | Leave the menu at the DOS prompt |

Choose **3** to play the included `BUILD\ZMEI.COM` without compiling, or **1**
to rebuild from source and play. The repository includes the tools needed
for the Windows/DOSBox workflow; Python is needed only for the optional tests.

Quitting the game returns to the launcher. From the DOS prompt, run
`LAUNCH.BAT` to reopen it or `exit` to close DOSBox.
The menu uses `CHOICE`, which is built into the bundled DOSBox.

### Run the release on DOS

Extract `UDAV-1_2.zip` into a directory on your DOS machine and run `ZMEI.COM`
from that directory. Keep the BMP files alongside the game. The repository
also contains a root-level `ZMEI.COM` updated for version 1.2, which can be
run directly from the project directory in DOS or DOSBox.

## Compile and link manually

The tools in `TASM/` are DOS executables; run them inside DOSBox or real DOS.
The supplied executables identify themselves as **TASM 2.5** and **TLINK 4.0**.

To open DOSBox at a prompt without starting the menu:

```powershell
.\DOSBOX\DOSBox.exe -conf dosbox_udav.conf -noautoexec -c "mount c ." -c "c:"
```

Then, at the DOS `C:\>` prompt:

### Option A: use the build script

```bat
BUILD.BAT
```

After it reports `Build succeeded`, run:

```bat
BUILD\ZMEI.COM
```

### Option B: invoke the assembler and linker directly

1. Create the output directory if it does not exist:

   ```bat
   if not exist BUILD\NUL mkdir BUILD
   ```

2. Assemble `zmei.asm` into an object file and generate a listing:

   ```bat
   TASM\TASM.EXE /l ZMEI.ASM,BUILD\,BUILD\
   ```

   `/l` enables the listing. The two directory arguments put `ZMEI.OBJ` and
   `ZMEI.LST` into `BUILD`. Continue only if assembly succeeds.

3. Link the object file into a DOS `.COM` executable:

   ```bat
   TASM\TLINK.EXE /t /m BUILD\ZMEI.OBJ,BUILD\ZMEI.COM,BUILD\ZMEI.MAP
   ```

   `/t` creates a `.COM` file; `/m` generates the map. These TLINK switches
   are **case-sensitive**: use lowercase `/t /m`. Continue only if linking
   succeeds.

4. Run the result from the repository root:

   ```bat
   BUILD\ZMEI.COM
   ```

Keep the current DOS directory at `C:\`, where the BMP assets are mounted.
The game opens artwork relative to the current directory, so do not change
into `BUILD` before running it. On a real DOS machine, use the same commands
from the project directory. `BUILD.BAT` works without the menu; `LAUNCH.BAT`
also requires a DOS `CHOICE` command.

### Build output and troubleshooting

| Path | Contents |
| --- | --- |
| `BUILD/ZMEI.COM` | Newly linked game |
| `BUILD/ZMEI.OBJ` | Assembled object code |
| `BUILD/ZMEI.LST` | Assembly listing and symbols |
| `BUILD/ZMEI.MAP` | Linker map |
| `BUILD/ASSEMBLE.LOG` | Assembler output from `BUILD.BAT` |
| `BUILD/LINK.LOG` | Linker output from `BUILD.BAT` |

For a failed scripted build, choose menu option **4** or inspect the logs:

```bat
type BUILD\ASSEMBLE.LOG
type BUILD\LINK.LOG
```

The build-and-run menu option launches the game only after a successful
build. Option **3** explicitly runs the existing executable, which may be
from an earlier build.

`BUILD/` is tracked in this repository, including generated binaries,
listings, logs, and smoke-test helpers. Rebuilding may therefore change
tracked files. The root-level `ZMEI.COM`, `ZMEI.OBJ`, `ZMEI.MAP`, and `ZMEI.LST`
are the artifacts updated for release 1.2; `BUILD.BAT` writes new output to
`BUILD/` and does not refresh the root files or `UDAV-1_2.zip`. The `old/`
directory and older archives preserve historical versions.

## Controls and rules

F1: slow (two BIOS timer ticks per move, about 9 moves/second).
F2: fast (one BIOS timer tick per move, about 18 moves/second).
Press a key to begin each level. Arrow keys steer; direct reversal is ignored.
Escape or F10 quits and restores the video mode active before launch.
F1/F2 on the defeat or victory screen starts a new game at level 1.

Green (palette index 2) grows the snake by one cell; red (4) grows it by two.
Cyan (3) shortens it by one and turns its discarded tail into green food.
At the minimum length of two cells, cyan is simply consumed. White (15)
is solid: both walls and the snake itself. Eat all food to advance through
the four levels, followed by the victory screen.

## Source layout

`zmei.asm` contains the main menu/level loop followed by small near procedures:
bitmap loading/rendering, cell drawing, snake initialization/movement,
keyboard input, and BIOS-tick pacing. Procedure comments document inputs,
outputs, and register usage. Variables and buffers have named storage;
there are no fixed scratch-memory addresses or stack resets during play.

Positions pack a logical cell column into AL and a row into AH. Each cell
is 2x2 pixels in VGA mode 13h, giving a 160x100-cell board. This permits the
whole 320-pixel screen width without wrapping a byte-sized pixel coordinate.
The snake has a bounded 1024-cell buffer. Extra growth at capacity consumes
the food without writing beyond that buffer.

Assets are the supplied uncompressed 160x100 8-bit BMPs with a 1078-byte
header/palette. The game validates this format and reports missing, short,
or incompatible files in text mode. As in the original, it uses the default
VGA palette and displays pixel rows in file order; this is intentional for
the existing artwork, rather than a general-purpose BMP decoder.

The refactor also fixes unchecked file reads, coordinate wrapping, shrinking
to zero length, timer rollover waits, and treating victory as another level.

## Machine-code regression checks (optional, on the host)

After a successful build, run on the host with Python 3:

```powershell
python -m pip install unicorn
python -m unittest discover -s tests -v
```

These checks execute BUILD/ZMEI.COM in a 16-bit x86 CPU emulator with small
BIOS/DOS service stubs, using symbols from BUILD/ZMEI.LST. They cover asset
rendering, food counts/effects, movement/collision, buffer bounds, keyboard
rules, timer rollover, file errors, and the menu/defeat/victory flow. The
level-flow checks place the final apple ahead of the snake to reach each
screen quickly. Use DOSBox or real DOS for interactive gameplay checks.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for bug reports, development conventions,
and pull request guidance.

## License

UDAV is licensed under the [MIT License](LICENSE). Bundled third-party tools,
including DOSBox and TASM/TLINK, retain their respective licenses.
