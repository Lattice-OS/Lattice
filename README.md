# LATTICE

> A grid‑first operating system for ComputerCraft: Tweaked  
> Designed for the AllTheMods 10 modpack

Lattice is a lightweight, modular operating system built for
**ComputerCraft: Tweaked**, running inside the **AllTheMods 10** modpack.

It treats every computer as a node in a grid — structured, predictable,
and extensible.  
Bootstrapped cleanly. Expanded deliberately.

---

## What is Lattice?

Lattice is not a single program.

It is a **system**:
- A minimal bootloader
- A shared library grid
- A manifest‑driven installer
- A foundation for automation, monitoring, and orchestration

Think *blocks*, not blobs.

---

## Requirements

- **Advanced Computer** (required)
- **HTTP enabled** (`http.enable=true`)
- AllTheMods 10 modpack
- A willingness to rebuild the grid if something breaks

Optional but encouraged:
- Monitor (for status output)
- Speaker (for boot chimes)

---

## Installation

Installing Lattice is intentionally simple.

From a **ComputerCraft Computer**, run:

```sh
wget run https://raw.githubusercontent.com/AltriusRS/CCT/main/Lattice/install.lua
```

The installer will:
- Clear existing Lattice files (clean grid)
- Fetch required system libraries
- Initialise the boot environment
- Verify core components

You’ll know it’s working when the screen starts talking back.

---

## Usage

Once installed, Lattice will:
- Manage its own libraries under `/lib`
- Maintain system state under `/os`
- Handle updates via manifest files
- Log all actions to both terminal and monitor (if attached)

From here, you build *on* the grid.

---

## Philosophy

- **Explicit over implicit**
- **Structure over sprawl**
- **Modules over monoliths**
- **Automation is a feature, not an afterthought**

If something fails, it should fail *loudly* and *clearly*.

---

## Status

Lattice is currently in **active development**.

APIs may change.  
The grid may shift.  
That’s the point.

---

## License

MIT — build freely, break responsibly.

---

> Lattice OS  
> *Constructing the grid.*
