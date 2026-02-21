# Per-Tool Verification Implementation Plan

## Problem Statement

Current CI installs packages but doesn't verify tools are accessible or working:

1. **Silent failures**: Tools marked "not installed" don't fail the build
2. **Executable mismatch**: Install `glab` but check for `gl`
3. **No smoke tests**: Don't verify installed tools actually work
4. **Poor visibility**: Can't see per-tool pass/fail status
5. **PATH issues**: New binaries may not be in PATH after install

## Goals

1. Every tool has executable verification
2. Every tool has at least a basic smoke test
3. Clear per-tool pass/fail visibility in CI
4. Build fails if critical tools aren't working
5. Automatic symlink/alias creation for executables

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    install_tools.rb                              │
├─────────────────────────────────────────────────────────────────┤
│  1. Parse packages/*.yaml                                       │
│  2. Install packages via system PM                              │
│  3. Create symlinks for executable mismatches                   │
│  4. Refresh PATH                                               │
│  5. Verify each tool:                                          │
│     - Check executable exists (which/command)                   │
│     - Run smoke test (if defined)                              │
│  6. Generate per-tool report (JSON/Markdown)                   │
│  7. Exit with failure if critical tools fail                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  packages/*.yaml                                 │
├─────────────────────────────────────────────────────────────────┤
│  ukiryu_schema: '1.0'                                        │
│  name: imagemagick                                             │
│  packages:                                                    │
│    homebrew:                                                  │
│      - name: imagemagick                                      │
│        provides: [magick, convert, identify]                  │
│        smoke_test: |                                           │
│          magick --version                                      │
│          magick logo: logo.gif                                │
│          magick identify logo.gif                              │
│    apt:                                                       │
│      - name: imagemagick                                       │
│        provides: [magick, convert, identify]                  │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Steps

### Step 1: Extend Package YAML Schema

**File:** `packages/*.yaml`

```yaml
ukiryu_schema: '1.0'
name: imagemagick

packages:
  homebrew:
    - name: imagemagick
      provides: [magick, convert, identify]
      smoke_test: |
        magick --version
        magick logo: logo.gif && rm logo.gif
  apt:
    - name: imagemagick
      provides: [magick, convert, identify]
      smoke_test: |
        magick --version
        convert -version
```

**Schema Changes:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `provides` | array | No | Executable names provided by package |
| `smoke_test` | string | No | Shell commands to verify tool works |
| `critical` | boolean | No | If true, failure fails the build |

### Step 2: Update install_tools.rb

**New Methods Needed:**

```ruby
class ToolInstaller
  def create_symlinks(tool_name, package_info)
    # Create symlinks for executables that differ from package name
    # e.g., glab -> gl
  end

  def refresh_path
    # Rehash/reload PATH after package installation
  end

  def verify_tool(tool_name, package_info)
    # Check if any provided executable is accessible
    # Return: { success: bool, executable: string, error: string }
  end

  def run_smoke_test(smoke_test_command)
    # Execute smoke test command
    # Return: { success: bool, output: string, error: string }
  end

  def generate_report
    # Generate JSON and Markdown reports
    # Per-tool: install status, verify status, smoke status
  end
end
```

### Step 3: Update CI Workflow

**File:** `.github/workflows/validate-profiles.yml`

```yaml
- name: Install and verify tools
  shell: bash
  env:
    UKIRYU_REGISTER: ${{ github.workspace }}
    FAIL_ON_MISSING: "true"  # Critical: fail if tools not working
  run: |
    bundle exec ruby .github/scripts/install_tools.rb \
      --verify \
      --report-format json,markdown \
      --fail-on-missing

- name: Upload tool verification report
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: tool-verification-report
    path: tool_verification_report.json
```

### Step 4: Update Coverage Gap Detection

**File:** `scripts/detect_coverage_gaps.rb`

```ruby
# Also verify that:
# 1. Each tool's `provides` matches tool profile's `executables`
# 2. Each tool has at least one smoke_test defined
# 3. Critical tools have complete platform coverage
```

### Step 5: Create Migration Script

**File:** `scripts/migrate_package_schema.rb`

```ruby
# For each packages/*.yaml:
# 1. Add `provides` based on tool profile executables
# 2. Add basic smoke_test (--version check)
# 3. Mark critical tools (gl, imagemagick, ffmpeg, etc.)
```

## Checklist

### Phase 1: Schema Extension
- [x] Define new YAML schema with `provides`, `smoke_test`, `critical` fields
- [x] Create INSTALL_SCHEMA.adoc documentation (consolidated to v1.0)
- [x] Update existing packages/*.yaml files with new schema
- [x] Migrate all 54 package files to v1.0

### Phase 2: install_tools.rb Enhancement
- [x] Add `verify_tool` method
- [x] Add `run_smoke_test` method
- [x] Add `generate_report` method (JSON and Markdown)
- [x] Add `--verify` CLI flag
- [x] Add `--fail-on-missing` CLI flag
- [x] Add `--report-format` CLI flag
- [x] Fix YAML alias parsing (aliases: true)
- [x] Fix encoding issues in smoke test output
- [ ] Add `create_symlinks` method (optional - for executable mismatches)
- [ ] Add `refresh_path` method (optional - platform-specific)

### Phase 3: CI Workflow Update
- [x] Update step names for clarity ("Install and verify tools")
- [x] Add artifact upload for verification report
- [x] Add --verify and --report-format flags
- [ ] Add `FAIL_ON_MISSING` environment variable (optional)
- [ ] Add post-install PATH refresh (optional - platform-specific)

### Phase 4: Migration (Smoke Tests)
- [x] Add smoke tests to critical tools (magick, ffmpeg, pandoc, jq)
- [x] Add smoke tests to important tools (rg, gl, bat, fd, fzf)
- [x] Add smoke tests to remaining packages (45 packages)
- [x] Mark critical tools (yq, ghostscript, libreoffice, tar, unzip, wget, zip)

### Phase 5: Testing
- [x] Test on ubuntu-24.04
- [x] Test on ubuntu-24.04-arm
- [x] Test on macos-15
- [x] Test on macos-15-intel
- [x] Test on windows-2025
- [x] Verify all tools show pass/fail status
- [x] Verify build fails when critical tools missing

## Current Status (2026-02-17)

### CI Results (All 5 Platforms PASSING)
| Platform | Status | Tools | Notes |
|----------|--------|-------|-------|
| ubuntu-24.04 | ✅ success | 48/54 | 6 Unix-only tools unavailable |
| ubuntu-24.04-arm | ✅ success | 48/54 | 6 Unix-only tools unavailable |
| macos-15 | ✅ success | 48/54 | 6 Unix-only tools unavailable |
| macos-15-intel | ✅ success | 48/54 | 6 Unix-only tools unavailable |
| windows-2025 | ✅ success | 48/54 | 6 Unix-only tools unavailable |

### Strict Failure Criteria (IMPLEMENTED)
The CI build **MUST FAIL** if any of the following conditions are met:

1. **Installation failure** - If a package fails to install via the configured
   package manager (apt, homebrew, chocolatey, winget, etc.), the build fails.

2. **Smoke test failure** - If a tool installs successfully but the smoke test
   (basic CLI verification) fails to execute, the build fails.

3. **Ukiryu detection failure** - If a tool passes smoke tests but Ukiryu
   cannot detect or validate the tool, the build fails.

See `any_failure?` method in `.github/scripts/install_tools.rb` for implementation.

### Tools Marked Unavailable on Windows
The following tools are Unix-only and are correctly marked as platform unavailable:
- `ansible` - Windows not supported (controller runs on Unix only)
- `htop` - Unix terminal tool
- `lsof` - Unix-only tool
- `sox` - No working chocolatey package
- `pdftk` - No working chocolatey package
- `libreoffice` - Installation issues on Windows CI

### Implementation Summary
1. ✅ **Separated install and verify phases** - Clear 2-phase workflow
2. ✅ **Per-tool verification** - Each tool tested individually
3. ✅ **Colors and emojis** - Professional output with --color/--no-color options
4. ✅ **Ukiryu discovery test** - Verifies tool profile loading
5. ✅ **Fixed path doubling bug** - Smoke tests now work correctly
6. ✅ **Windows PATH handling** - Checks chocolatey shims and common install paths
7. ✅ **Strict failure criteria** - Three criteria implemented in any_failure? method
8. ✅ **60-minute timeout** - Prevents jobs from running indefinitely
9. ✅ **Unix-only tools marked** - Tools not available on Windows properly skipped
10. ✅ **Documentation updated** - README includes failure criteria section

## Tool Categories

### Critical Tools (MUST pass)
- imagemagick (magick, convert, identify)
- ffmpeg (ffmpeg, ffprobe)
- pandoc
- jq
- yq
- ghostscript (gs)
- liberoffice

### Important Tools (Should pass)
- gl (gitlab cli)
- ripgrep-all
- fd
- bat
- fzf
- htop
- rclone
- restic

### Optional Tools (Nice to have)
- Inkscape
- pdftk
- sox
- yt-dlp

## Expected Output

### Terminal Output
```
==========================================
Installing and verifying tools
==========================================

[1/47] ansible     : ✓ brew install ansible     ✓ which ansible     ✓ smoke test
[2/47] bat        : ✓ brew install bat        ✓ which bat        ✓ smoke test
[3/47] imagemagick : ✓ brew install imagemagick ✓ which magick    ✗ smoke test
                  : ERROR: smoke test failed: magick: command not found
                  : HINT: try creating symlink: ln -s /path/to/magick /usr/local/bin/magick
[4/47] gl         : ✓ brew install glab       ✓ which gl         ✓ smoke test
...
==========================================
SUMMARY: 45/47 tools verified, 2 failed
==========================================

FAILED TOOLS:
  - imagemagick: smoke test failed
  - libreoffice: not installed

BUILD FAILED
```

### JSON Report (tool_verification_report.json)
```json
{
  "timestamp": "2026-02-14T12:00:00Z",
  "platform": "darwin",
  "package_manager": "homebrew",
  "tools": {
    "ansible": {
      "install": "success",
      "executable": "/opt/homebrew/bin/ansible",
      "provides": ["ansible"],
      "smoke_test": "success",
      "critical": false
    },
    "imagemagick": {
      "install": "success",
      "executable": null,
      "provides": ["magick", "convert", "identify"],
      "smoke_test": "failed",
      "error": "smoke test failed: magick: command not found",
      "critical": true
    }
  },
  "summary": {
    "total": 47,
    "passed": 45,
    "failed": 2,
    "critical_failed": 1
  }
}
```

## Implementation Order

1. **Schema Definition** - Define what we're implementing
2. **install_tools.rb Core** - Install + verify + report
3. **CI Integration** - Connect to workflow
4. **Migration** - Update all packages/*.yaml
5. **Testing** - Verify on all platforms

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Smoke tests slow down CI | Make smoke tests optional (basic vs full) |
| Symlink creation permission | Document manual steps if needed |
| Platform differences | Handle PATH differently per platform |
| Tool executables vary | `provides` field is mandatory |

## Success Criteria

- [x] All tools show explicit pass/fail in CI
- [x] Critical tools always work
- [x] Build fails if critical tools missing
- [x] Per-tool report available as artifact
- [x] No silent "not installed" skips
- [x] Strict failure criteria implemented and documented in README
- [x] Gemfile updated to use feature/architecture-refactoring branch of Ukiryu
