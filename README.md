# mqvhdl

A lightweight VHDL project workflow tool built around [GHDL](https://github.com/ghdl/ghdl) and [GTKWave](https://gtkwave.sourceforge.net/).

`mqvhdl` provides a simple project structure and command-line workflow for discovering, building, simulating, and viewing VHDL designs.

## Status

Early development.

Current release: **v0.2.0**

## Requirements

* Bash
* GHDL
* GTKWave

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

The `.mqvhdl` file contains the project configuration:

```ini
source_dir=src
testbench_dir=tb
```

Custom source and testbench directories can also be configured.

## Commands

### Initialize a project

```bash
mqvhdl init
```

Use custom directories:

```bash
mqvhdl init -s rtl -t verification
```

### List project entities

```bash
mqvhdl list
```

This discovers VHDL entities in the configured source and testbench directories.

### Build

Analyze the project:

```bash
mqvhdl build
```

Analyze only:

```bash
mqvhdl build --analyze
```

Elaborate a testbench:

```bash
mqvhdl build --elaborate --tb and_gate_tb
```

### Run

Run a specific testbench:

```bash
mqvhdl run --tb and_gate_tb
```

Generate a named GHW waveform:

```bash
mqvhdl run --tb and_gate_tb --output and_gate
```

When only one testbench exists, `mqvhdl run` can automatically select it.

### Clean

Remove generated GHDL and waveform artifacts:

```bash
mqvhdl clean
```

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

A GHW waveform can then be opened with GTKWave.

## Versioning

`mqvhdl` uses Git tags for releases.

Current releases:

* `v0.1.0` — Initial GHDL/GTKWave workflow
* `v0.2.0` — Project initialization, configuration, entity discovery, and project-aware build/run workflow

## License

`mqvhdl` is licensed under the [MIT License](LICENSE).
