# PHASE 1: BusyBox Interface Implementation Plan

## Overview

Split 6 monolithic tool profiles into GNU/BusyBox interfaces to fix Alpine CI compatibility.

## Tools to Convert

| # | Tool | Current Profile | Target | Priority |
|---|------|----------------|--------|----------|
| 1 | tar | tools/tar/1.35.yaml | tar_gnu/1.35.yaml + tar_busybox/1.36.1.yaml | HIGH |
| 2 | grep | tools/grep/3.12.yaml | grep_gnu/3.12.yaml + grep_busybox/1.36.1.yaml | HIGH |
| 3 | sed | tools/sed/4.9.yaml | sed_gnu/4.9.yaml + sed_busybox/1.36.1.yaml | HIGH |
| 4 | find | tools/find/1.0.yaml | find_gnu/4.9.yaml + find_busybox/1.36.1.yaml | HIGH |
| 5 | wget | tools/wget/1.24.yaml | wget_gnu/1.24.yaml + wget_busybox/1.36.1.yaml | MEDIUM |
| 6 | awk | tools/awk/5.3.yaml | awk_gnu/5.3.yaml + awk_busybox/1.36.1.yaml | MEDIUM |

## Implementation Steps for Each Tool

### Step 1: Create Interface Definition
Create `interfaces/{tool}/1.0.yaml` defining the contract

### Step 2: Create GNU Implementation
Create `tools/{tool}_gnu/{version}.yaml` with:
- `implements: {tool}`
- GNU version detection
- GNU search paths
- Full feature set

### Step 3: Create BusyBox Implementation
Create `tools/{tool}_busybox/1.36.1.yaml` with:
- `implements: {tool}`
- BusyBox version detection
- BusyBox search paths (include /bin/)
- Minimal feature set

### Step 4: Remove Monolithic Profile
Delete `tools/{tool}/` directory

### Step 5: Commit and Test
- Commit changes
- Push to register v1
- Monitor ukiryu CI for Alpine compatibility

## Version Numbers

Based on actual releases:
- GNU tar: 1.35 (current)
- GNU grep: 3.12 (current)
- GNU sed: 4.9 (current)
- GNU find: 4.9 (current)
- GNU wget: 1.24 (current)
- GNU awk (gawk): 5.3 (current)
- BusyBox: 1.36.1 (Alpine 3.19)

## Search Paths

### Linux (Alpine compatibility)
GNU tools:
- `/usr/bin/{tool}`
- `/usr/local/bin/{tool}`
- `/bin/{tool}` (for some GNU tools on Alpine)

BusyBox tools:
- `/bin/{tool}` (BusyBox primary location)
- `/usr/bin/{tool}` (fallback)

## Order of Implementation

1. **tar** - Most critical for CI/CD
2. **grep** - Core search, currently failing
3. **sed** - Core processing, missing -i in BusyBox
4. **find** - File discovery
5. **wget** - Download automation
6. **awk** - Text processing

## Success Criteria

- All 6 interfaces created (18 files total)
- All monolithic profiles removed
- Alpine CI passes
- Documentation updated
- Zero breaking changes to existing API (users still reference `Ukiryu::Tool.get(:tar)` etc.)

## Files to Create

### Interface Definitions (6 files)
- interfaces/tar/1.0.yaml
- interfaces/grep/1.0.yaml
- interfaces/sed/1.0.yaml
- interfaces/find/1.0.yaml
- interfaces/wget/1.0.yaml
- interfaces/awk/1.0.yaml

### GNU Implementations (6 files)
- tools/tar_gnu/1.35.yaml
- tools/grep_gnu/3.12.yaml
- tools/sed_gnu/4.9.yaml
- tools/find_gnu/4.9.yaml
- tools/wget_gnu/1.24.yaml
- tools/awk_gnu/5.3.yaml

### BusyBox Implementations (6 files)
- tools/tar_busybox/1.36.1.yaml
- tools/grep_busybox/1.36.1.yaml
- tools/sed_busybox/1.36.1.yaml
- tools/find_busybox/1.36.1.yaml
- tools/wget_busybox/1.36.1.yaml
- tools/awk_busybox/1.36.1.yaml

## Progress Tracking

- [ ] tar interface
- [ ] grep interface
- [ ] sed interface
- [ ] find interface
- [ ] wget interface
- [ ] awk interface

## References

- BUSYBOX_SUPPORT.md - Full documentation
- interfaces/gzip/1.0.yaml - Interface example
- tools/gzip_gnu/1.12.yaml - GNU implementation example
- tools/gzip_busybox/1.36.1.yaml - BusyBox implementation example
