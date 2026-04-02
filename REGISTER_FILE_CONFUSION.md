# Register File Structure Confusion: Which File to Edit?

## Problem

When attempting to fix the `batch_process` default value for Inkscape, the fix was applied to the wrong file. This document explains the confusion and recommends a solution.

## Current State

The inkscape tool has two similar-looking YAML files:

```
tools/inkscape/
├── 1.0.yaml                    # "Legacy" single-file definition
├── index.yaml                  # Implementation index (v2 architecture)
├── default/
│   ├── 0.92.yaml              # Implementation version file
│   └── 1.0.yaml               # Implementation version file (THIS IS LOADED!)
└── ...
```

## What Actually Gets Loaded

The `Ukiryu::Tool::Loader.load_with_implementation_index` method uses this flow:

1. Load `tools/inkscape/index.yaml` to get the ImplementationIndex
2. Detect implementation (e.g., "default") and version (e.g., "1.0")
3. Load `tools/inkscape/default/1.0.yaml` as the ImplementationVersion
4. Convert to ToolDefinition for compatibility

**The file at `tools/inkscape/1.0.yaml` is NOT used by this code path.**

## The Confusion

| File Path | Purpose | Used By |
|-----------|---------|---------|
| `tools/inkscape/1.0.yaml` | Legacy single-file tool definition | Legacy loader (if v2 index not found) |
| `tools/inkscape/default/1.0.yaml` | Implementation version file | v2 loader (`load_with_implementation_index`) |

Both files have similar structures with `execution_profiles` containing commands and flags. A developer editing `tools/inkscape/1.0.yaml` expects changes to take effect, but they don't because the v2 loader ignores that file.

## Debug Output Shows the Issue

Before fix (editing wrong file):
```
[VECTORY DEBUG] YAML modern_unix batch_process default: false (FalseClass)
[VECTORY DEBUG] Loaded batch_process default: true (TrueClass)
[VECTORY DEBUG] Loaded batch_process description: "Close GUI after processing (required for headless)"
```

The YAML file on disk showed `default: false`, but the loaded tool had `default: true` because a different file was being loaded.

## Root Cause

The v2 architecture was introduced to support multiple implementations of a tool (e.g., GNU grep vs BSD grep). However:

1. The legacy single-file format (`tools/{tool}/{version}.yaml`) still exists
2. Both files can exist simultaneously for the same tool
3. There is no documentation indicating which file takes precedence
4. There is no validation to ensure files are in sync

## Recommended Solutions

### Option 1: Deprecate Legacy Files

1. Add a warning when legacy files (`tools/{tool}/{version}.yaml`) are present alongside v2 structure
2. Eventually remove support for legacy single-file format
3. Update all tools to use only the v2 structure

### Option 2: Add Validation/Sync

1. When both files exist, validate they are in sync
2. Add a CI check to detect discrepancies
3. Document clearly which file is the source of truth

### Option 3: Single Source of Truth

1. Remove implementation version files (`tools/{tool}/{implementation}/{version}.yaml`)
2. Keep only the interface definition and have implementations reference it
3. Avoid duplication of command/flag definitions

## Files Affected

This issue likely affects all tools in the register that have both:
- `tools/{tool}/{version}.yaml` (legacy)
- `tools/{tool}/index.yaml` (v2)

## Immediate Fix

For the Inkscape `batch_process` issue, the fix was applied to:
- `tools/inkscape/default/1.0.yaml` - **Correct file (now fixed)**

The other file was also updated but is not used:
- `tools/inkscape/1.0.yaml` - **Not loaded by v2 architecture**
