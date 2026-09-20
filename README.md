# mqvhdl

A lightweight VHDL project workflow tool built around [GHDL](https://github.com/ghdl/ghdl) and [GTKWave](https://gtkwave.sourceforge.net/).

`mqvhdl` provides a simple project structure and command-line workflow for discovering, building, simulating, and viewing VHDL designs.

Builds are **dependency-ordered** and **cached**: only the files a testbench actually needs are analyzed, and only when something changed.

## Status

Early development.

Current release: **v0.3.0**

## Requirements

* Bash 4.2 or newer
* GHDL
* GTKWave (needed for `mqvhdl run` waveform viewing)
* `sha256sum` or `shasum` (used by the build cache)

## Installation

`mqvhdl` is a single Bash script with no compilation step: installing it means putting one executable file named `mqvhdl` into a directory on your `PATH`.

### 1. Install the dependencies

`mqvhdl` wraps GHDL and GTKWave, so they must be present on the system:

| Platform | Command |
| --- | --- |
| Debian / Ubuntu | `sudo apt install ghdl gtkwave` |
| Fedora | `sudo dnf install ghdl gtkwave` |
| Arch Linux | `sudo pacman -S ghdl gtkwave` |
| openSUSE | `sudo zypper install ghdl gtkwave` |
| Alpine | `apk add ghdl gtkwave bash` |
| macOS (Homebrew) | `brew install ghdl gtkwave bash` |

Notes:

* **macOS** ships `/bin/bash` 3.2, but `mqvhdl` requires Bash ≥ 4.2 — install `bash` with Homebrew (included above) and make sure Homebrew's `bin` directory precedes `/bin` in `PATH`.
* `sha256sum` or `shasum` is required by the build cache; both are present on virtually every system.
* GTKWave is only needed for the automatic waveform viewer in `mqvhdl run` — `mqvhdl run --no-wave` works without it.

### 2. Install mqvhdl

**Quick install (recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/install.sh | bash
```

The installer downloads the latest release, sanity-checks it (shebang + Bash syntax) before installing anything, installs `mqvhdl` to `~/.local/bin/mqvhdl` (user install, no root required), checks that GHDL, GTKWave and a recent enough Bash are available, and warns you if the install directory is not on `PATH`.

Pin a specific release:

```bash
curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/install.sh | bash -s -- --ref v0.3.0
```

**From a local clone**

```bash
git clone https://github.com/mquency/mqvhdl
cd mqvhdl
./install.sh                  # user install → ~/.local/bin
sudo ./install.sh --system    # system-wide  → /usr/local/bin
```

**Manual install**

Because `mqvhdl` is one file, the manual route is equally valid:

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/mqvhdl -o ~/.local/bin/mqvhdl
chmod +x ~/.local/bin/mqvhdl
```

or, from a clone (also the line packagers use):

```bash
install -Dm755 mqvhdl ~/.local/bin/mqvhdl
```

**Installer options**

| Option | Description |
| --- | --- |
| `--prefix <dir>` | Install to `<dir>/bin/mqvhdl` (default: `~/.local`) |
| `--system` | Install to `/usr/local/bin` (uses `sudo` when needed) |
| `--ref <ref>` | Install a specific tag or branch instead of the latest release |
| `--add-path` | Add the install directory to your shell rc file when it is missing from `PATH` |
| `--no-check-deps` | Skip the advisory dependency checks |
| `--uninstall` | Remove the installed `mqvhdl` |

**Package managers**

Ready-to-use packaging files ship in the repository under `packaging/`:

* **Arch Linux** — `packaging/PKGBUILD`: build and install with `makepkg -si`, or publish it to the AUR.
* **macOS (Homebrew)** — `packaging/mqvhdl.rb`: install directly with `brew install ./packaging/mqvhdl.rb`, or host it in your own tap.

### 3. Make sure the install directory is on `PATH`

`~/.local/bin` is on `PATH` by default on most modern distributions. If `mqvhdl --version` is "command not found" after installing, add it:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

zsh users: append the same line to `~/.zshrc` instead. The installer detects this situation and can fix it for you with `--add-path`.

### 4. Verify

```bash
mqvhdl --version      # → mqvhdl 0.3.0
mqvhdl help
ghdl --version        # GHDL itself, as mqvhdl will use it
```

Then, in a scratch directory, `mqvhdl init` should create a project (see [Project Structure](#project-structure)).

### Upgrade

Re-running the installer replaces the previous installation in place:

```bash
curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/install.sh | bash
```

or, from a clone:

```bash
git pull && ./install.sh
```

Existing projects need no migration; caches and lock files are versioned and invalidate automatically when the tool or GHDL changes. Run `mqvhdl clean` inside a project if you ever want to force a full rebuild.

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/mquency/mqvhdl/HEAD/install.sh | bash -s -- --uninstall
```

or simply delete the file:

```bash
rm ~/.local/bin/mqvhdl
```

Per-project caches and outputs (`.mqvhdl_modules/`, `build/`, `mqvhdl.lock`) are not touched by the uninstaller — remove them from each project with `mqvhdl clean` if desired.

## Project Structure

A project initialized with `mqvhdl init` uses the following structure by default:

```text
project/
├── .mqvhdl
├── src/
│   └── *.vhd
└── tb/
    └── *.vhd
```

After the first build, two generated trees and a lock file are added:

```text
project/
├── .mqvhdl
├── mqvhdl.lock
├── src/
│   └── *.vhd
├── tb/
│   └── *.vhd
├── .mqvhdl_modules/
│   ├── meta/        cache index, elaboration records, GHDL version
│   └── ghdl/        GHDL working library
└── build/
    ├── bin/         elaborated testbench binaries (compiled backends)
    └── wave/        *.ghw waveforms
```

* `.mqvhdl_modules/` — the build cache (safe to delete; it is rebuilt on demand)
* `build/` — generated outputs
* `mqvhdl.lock` — lock file describing the last successful build

## Configuration

The `.mqvhdl` file contains the project configuration. Blank lines and `#` comments are allowed:

```ini
# Directories (relative to the project root)
source_dir=src
testbench_dir=tb

# VHDL standard
std=93

# IEEE library implementation
ieee=standard

# Relax LRM rules
relaxed=no

# Give priority to explicit component binding
fexplicit=no
```

| Key | Values | Default | GHDL flag |
| --- | --- | --- | --- |
| `source_dir` | any path | `src` | — |
| `testbench_dir` | any path | `tb` | — |
| `std` | `87` `93` `00` `02` `08` `19` | `93` | `--std=...` |
| `ieee` | `standard` `synopsys` `none` | `standard` | `--ieee=...` |
| `relaxed` | `yes` / `no` | `no` | `--relaxed-rules` |
| `fexplicit` | `yes` / `no` | `no` | `-fexplicit` |

Unknown keys produce a warning; invalid values are an error. Changing any of `std`, `ieee`, `relaxed`, or `fexplicit` — or upgrading GHDL — invalidates the build cache and triggers a rebuild.

All commands locate the project root by searching for `.mqvhdl` in the current directory and its parents, so they can be run from anywhere inside the project.

## Commands

Run `mqvhdl help` or `mqvhdl <command> --help` for the complete option list of each command.

### Initialize a project

```bash
mqvhdl init
```

Use custom directories:

```bash
mqvhdl init -s rtl -t verification
```

Choose the VHDL standard at creation time:

```bash
mqvhdl init -s rtl -t verification --std 08
```

### List project entities

```bash
mqvhdl list
```

Shows the configuration, the cache status, every discovered entity, package, configuration and context, and — for each testbench — the set of files its build depends on.

### Build

`mqvhdl build` resolves the dependency graph of the selected testbenches, then analyzes **only those files, in dependency order**, reusing everything that is still valid in the cache.

Build what all testbenches need:

```bash
mqvhdl build
```

Build what a single testbench needs:

```bash
mqvhdl build --tb and_gate_tb
```

Analyze every VHDL file in both directories:

```bash
mqvhdl build --all
```

Also elaborate a testbench:

```bash
mqvhdl build --elaborate --tb and_gate_tb
```

With `--elaborate` and a single testbench, the testbench is selected automatically.

| Option | Description |
| --- | --- |
| `-t`, `--tb <entity>` | Build only the dependency closure of this testbench |
| `-e`, `--elaborate` | Also elaborate the selected testbench |
| `-a`, `--analyze` | Analyze only (default) |
| `--all` | Analyze every VHDL file in both directories |

By default, files that no testbench depends on are not built at all. Use `--all` when you want a full analysis (e.g. while developing a library package).

A typical build run:

```text
  [1/3] analyze     src/and_gate.vhd
  [2/3] cached      src/mid_level.vhd
  [3/3] analyze     tb/and_gate_tb.vhd

✓ Analyzed 2, reused 1 (3 files).
```

### Run

Run a specific testbench:

```bash
mqvhdl run --tb and_gate_tb
```

Generate a named waveform:

```bash
mqvhdl run --tb and_gate_tb --output and_gate
```

Waveforms are written to `build/wave/<name>.ghw`, and GTKWave is opened automatically when a display is available.

Run without waveform or GTKWave:

```bash
mqvhdl run --tb and_gate_tb --no-wave
```

**Testbench selection**

* With exactly one testbench, `mqvhdl run` selects it automatically.
* With several testbenches and no `--tb`, an interactive menu is shown. The menu also reminds you that `--tb` skips it:

```text
! Multiple testbenches found — pick one:

   1)  and_gate_tb    (tb/and_gate_tb.vhd)
   2)  or_gate_tb     (tb/or_gate_tb.vhd)

→ Tip: 'mqvhdl run --tb <entity>' (or 'build --tb') skips this menu.

Select testbench [1-2]:
```

* In non-interactive shells, `--tb` is required.

`mqvhdl run` builds first (with the same dependency ordering and caching as `mqvhdl build`), elaborates, and only then simulates. Nothing that is already cached is repeated.

| Option | Description |
| --- | --- |
| `-t`, `--tb <entity>` | Testbench entity to run |
| `-o`, `--output <name>` | Waveform name (default: testbench name) |
| `--no-wave` | No waveform, no GTKWave |
| `-g`, `--ghw` | Generate a GHW waveform (default) |

### Clean

Remove the cache, build outputs, the lock file, and any stray GHDL artifacts (`*.cf`, `*.o`) or waveforms (`*.ghw`, `*.vcd`, `*.fst`, `*.gtkw`) left in the project:

```bash
mqvhdl clean
```

## Output

Every command ends with a summary line:

```text
✓ build completed in 1.87s
```

Output is colored when attached to a terminal; set `NO_COLOR` to disable it.

## How builds work

### Dependency resolution

`mqvhdl` parses the VHDL sources (comments stripped, matched case-insensitively) to build a dependency graph. It recognizes:

* `entity`, `architecture`, `package`, `package body`, `configuration` and `context` declarations
* `use work.<pkg>`, `context work.<ctx>` and package instantiation (`is new work.<pkg>`)
* direct entity instantiation (`entity work.<ent>`) and configurations
* component/entity instantiations (`label : unit`) — using VHDL's default binding rule, where component `foo` binds to `entity work.foo`

From this graph:

* Files are analyzed in dependency order, so chained dependencies (`and_gate_tb → top_level → mid_level → and_gate`) always work.
* Architectures and package bodies that live in separate files from their entity/package are pulled into the build automatically.
* Circular dependencies are detected and reported as a path.
* Only the `work` library is resolved; references to other libraries are left to GHDL.

The resolution deliberately over-approximates: a spurious dependency only costs an extra analysis, never a wrong build.

### Build cache

The cache lives in `.mqvhdl_modules/`. For every analyzed file, `meta/index` stores:

* the file's content hash,
* a signature of all analysis options (`std`, `ieee`, `relaxed`, `fexplicit`, GHDL version, mqvhdl version),
* its resolved dependency list,
* the content hashes those dependencies had at build time.

A file is **reused** only when all four still match. It is rebuilt when its own content changes, when any dependency changes (transitively up the whole chain), when the analysis options or the GHDL version change — or because the configured VHDL standard changed. Otherwise GHDL is not even invoked.

* GHDL's own library files are kept in `.mqvhdl_modules/ghdl` (`--workdir`) and are wiped automatically when the GHDL version changes.
* Elaborations are cached per testbench; with compiled GHDL backends the binary is copied to `build/bin/`. (The mcode backend produces no binary; `mqvhdl run` falls back to `ghdl -r`.)
* Progress is saved after every file, so a failed build keeps the analysis work already done.

### Lock file

After each successful analysis, `mqvhdl.lock` is regenerated. It records the tool and GHDL versions, the effective configuration, and every file's hash, declarations and dependency list. It is intended for inspection and reproducibility checks — do not edit it.

### One instance at a time

`mqvhdl` holds a PID lock in `.mqvhdl_modules/` while it works, so two concurrent invocations cannot corrupt the shared GHDL library.

## Example

Given:

```text
project/
├── .mqvhdl
├── src/
│   └── and_gate.vhd
└── tb/
    └── and_gate_tb.vhd
```

A typical workflow is:

```bash
mqvhdl list
mqvhdl build
mqvhdl run --tb and_gate_tb
```

The waveform is written to `build/wave/and_gate_tb.ghw` and opened with GTKWave (it can also be opened manually with `gtkwave build/wave/and_gate_tb.ghw`).

Even if the testbench sits on top of a chain of design units — `and_gate_tb → top_level → mid_level → and_gate` — `mqvhdl build` analyzes them in the correct order, and a second run rebuilds only the files that actually changed.

## Versioning

`mqvhdl` uses Git tags for releases.

Current releases:

* `v0.1.0` — Initial GHDL/GTKWave workflow
* `v0.2.0` — Project initialization, configuration, entity discovery, and project-aware build/run workflow
* `v0.3.0` — Dependency-ordered minimal builds, content-hash build cache, `build/` output tree, `mqvhdl.lock`, extended configuration, interactive testbench selection, colored output, and command timing

## License

`mqvhdl` is licensed under the [MIT License](LICENSE).
