# Contributing to UDAV

Bug reports, fixes, readability improvements, and documentation updates are
welcome.

## Reporting a bug

Describe what happened, what you expected, and how to reproduce it. Include
the UDAV version and your environment: real DOS hardware, DOSBox version and
configuration, or another virtual machine. Screenshots and build logs help.

## Building and testing

1. Fork the repository and create a branch for your change.
2. From the repository root, start the DOSBox launcher:

   ```powershell
   .\DOSBOX\DOSBox.exe -conf dosbox_udav.conf
   ```

3. Choose **1** to build and run, or **2** to build only. Check the assembler
   and linker logs with **4** if the build fails.
4. For code changes, run the machine-code regression tests on the host after
   a successful build:

   ```powershell
   python -m pip install unicorn
   python -m unittest discover -s tests -v
   ```

5. Check gameplay changes interactively in DOSBox or real DOS. Include a
   regression test for a bug fix when practical.

See [README.md](README.md) for manual assembly/linking commands and game rules.

## Code conventions

- Keep the game compatible with real-mode DOS and the supplied TASM/TLINK
  tools. The current source uses 8086 instructions in a single `.COM` segment.
- Use descriptive labels, named constants, and small procedures. Document
  procedure inputs, outputs, and register usage.
- Preserve balanced stack operations, clear the direction flag after backward
  copies, and respect the documented board and snake-buffer bounds.
- Keep changes focused. Include generated binaries and build output only when
  intentionally updating release artifacts.
- Use short, descriptive, plain-language commit subjects, generally lowercase,
  matching the existing history; add a body when useful.

## Submitting a pull request

Explain the change and its motivation, link any related issue, and describe
the checks you ran. Update documentation when controls, game rules, or build
steps change.

Contributions to UDAV are provided under the project's [MIT license](LICENSE).
