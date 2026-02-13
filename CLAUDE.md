# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Ukiryu Tool Register (v1)** - a collection of YAML tool profiles for the Ukiryu platform-adaptive command execution framework. Each profile defines how to execute command-line tools across different platforms (macOS, Linux, Windows), shells (bash, zsh, PowerShell, etc.), and versions.

## Commands

### Validation

```bash
# Validate a specific profile
bundle exec ukiryu validate --definition tools/imagemagick/7.1.yaml

# Validate with schema (schemas repo must be checked out at ../schemas)
bundle exec ukiryu validate --definition tools/imagemagick/7.1.yaml \
  --schema ../schemas/v1/tool.schema.yaml

# Validate all profiles with executable testing
bundle exec ukiryu validate all --register . --schema ../schemas/v1/tool.schema.yaml --all --executable --verbose

# Lint a specific profile
bundle exec ukiryu lint file tools/imagemagick/7.1.yaml

# Lint all profiles
bundle exec ukiryu lint all
```

### Utility Scripts

```bash
# Add smoke tests to all profiles that don't have them
ruby add_smoke_tests.rb

# Migrate shell enumeration to platform groups (e.g., [bash, zsh] → [unix])
ruby scripts/migrate_shells.rb --dry-run tools/
ruby scripts/migrate_shells.rb tools/
```

## Architecture

### Directory Structure

```
register/
├── interfaces/           # Interface contracts (what a tool should do)
│   ├── tar.yaml         # Defines tar interface with actions
│   └── imagemagick.yaml # Defines imagemagick interface
├── tools/               # Tool implementations (how to do it)
│   ├── imagemagick/
│   │   ├── index.yaml   # Version routing
│   │   ├── 7.1.yaml     # Version-specific profile
│   │   └── 6.9.yaml     # Older version
│   └── cat/
│       └── generic.yaml # Generic tool (stable interface)
└── .github/
    └── workflows/
        └── validate-profiles.yml  # CI validation
```

### Interface vs Tool

- **Interface** (`interfaces/`): Defines the contract - what commands and options a tool should support. Used for tools with multiple implementations (GNU, BusyBox, BSD).
- **Tool** (`tools/`): Concrete implementation - how to execute commands on specific platforms/shells.

### Version Routing (index.yaml)

Tools with version-specific behavior use `index.yaml` for routing:

```yaml
implementations:
  - name: default
    detection:
      executables: ["convert", "magick"]
      command: ["-version"]
      pattern: 'Version: ImageMagick ([\d.]+)'
    version_scheme: semantic
    versions:
      - equals: '6.9'
        file: 6.9.yaml
      - equals: '7.1'
        file: 7.1.yaml
    default: 7.1.yaml
```

### Versioned vs Generic Tools

- **Versioned** (`tools/<tool>/<version>.yaml`): Tools with version-specific interfaces (imagemagick/7.1.yaml, ffmpeg/8.0.yaml)
- **Generic** (`tools/<tool>/generic.yaml`): Stable system utilities (cat/generic.yaml, sort/generic.yaml)

### Profile Structure

Key fields in tool profiles:

| Field | Description |
|-------|-------------|
| `ukiryu_schema` | Schema version ('1.0') |
| `name` | Tool identifier |
| `version` | Version number or 'generic' |
| `version_detection` | How to detect installed version |
| `search_paths` | Platform-specific executable locations |
| `profiles` | Array of platform/shell-specific configurations |
| `commands` | Command definitions with arguments, options, flags |
| `smoke_tests` | Basic tests to verify tool works |

### Version Detection Methods

Use `detection_methods` array with fallback:

```yaml
version_detection:
  detection_methods:
    - type: command
      command: "--version"
      pattern: tool ([\d.]+)
    - type: man_page
      paths:
        macos: /usr/share/man/man1/tool.1
        linux: /usr/share/man/man1/tool.1
  system_tool: true  # Fallback if detection fails
```

### Shell Platform Groups

Use platform groups instead of listing individual shells:

- `unix` - bash, zsh, fish, sh, dash, tcsh, ash, csh, ksh
- `windows` - cmd
- `powershell` - powershell, pwsh

Example:
```yaml
profiles:
  - name: unix
    platforms: [macos, linux]
    shells: [unix]  # NOT [bash, zsh, fish, ...]
```

## Adding a New Tool

1. Determine version naming: versioned (`<version>.yaml`) or generic (`generic.yaml`)
2. Create `tools/<tool-name>/` directory
3. Create profile YAML following v1 schema
4. Add version detection using `detection_methods` array
5. Add `smoke_tests` for basic validation
6. Validate: `bundle exec ukiryu validate --definition tools/<tool>/<file>.yaml`
7. If multiple implementations exist (GNU/BusyBox), create interface in `interfaces/`

## BusyBox Support

See `BUSYBOX_SUPPORT.md` for guidance on when to create GNU vs BusyBox implementations. Key points:

- Only create BusyBox interfaces when significant differences exist
- Many operations should use Ruby built-ins instead of CLI wrappers
- Tools like tar, grep, sed, find, wget, awk have separate GNU/BusyBox implementations

## CI/CD

The GitHub Actions workflow (`validate-profiles.yml`) runs on:
- Pull requests modifying YAML files
- Pushes to v1 branch
- Manual dispatch

It validates across multiple platforms: Ubuntu (x64/arm), macOS (arm/intel), Windows (x64/arm).

## Schema Reference

This register follows the v1 schema from https://github.com/ukiryu/schemas/tree/v1
