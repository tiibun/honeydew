# GitHub Actions Tag Release Workflow Design

## Goal

When a tag matching `v*` is pushed to this repository, GitHub Actions should build the `honeydew/cmd/main` executable for Linux, macOS, and Windows, then create a GitHub Release and attach one archive per OS.

## Scope

This design covers:

- A new tag-triggered GitHub Actions workflow at the repository root
- Cross-platform builds for `honeydew/cmd/main`
- Packaging built binaries into release archives
- Creating a GitHub Release only after all target builds succeed

This design does not cover:

- Publishing MoonBit packages
- Replacing or restructuring existing CI in `moon_mysql`
- Building `honeytui/cmd/main`

## Constraints and Decisions

- Trigger only on pushed tags matching `v*`
- Release target is `honeydew/cmd/main` only
- Output format is OS-specific archives:
  - Linux: `.tar.gz`
  - macOS: `.tar.gz`
  - Windows: `.zip`
- Release creation should fail closed: if any OS build fails, no Release is published
- The workflow should remain separate from regular CI to keep responsibilities clear

## Recommended Approach

Use a single workflow with:

1. A matrix `build` job for Linux, macOS, and Windows
2. A final `release` job that downloads the artifacts from all build jobs and creates the GitHub Release

This keeps the workflow easy to understand while isolating OS-specific packaging differences to a small part of the build steps.

## Workflow Structure

### Trigger

The workflow listens to:

```yaml
on:
  push:
    tags:
      - 'v*'
```

### Permissions

The workflow grants:

```yaml
permissions:
  contents: write
```

This allows the release job to create a GitHub Release and upload assets.

### Build Job

The `build` job runs with a matrix like:

- `ubuntu-latest`
- `macos-latest`
- `windows-latest`

Each matrix entry is responsible for:

1. Checking out the repository
2. Installing MoonBit
3. Running `moon update`
4. Building `honeydew/cmd/main`
5. Collecting the built executable into a staging directory
6. Packaging the staging directory into an OS-specific archive
7. Uploading that archive as a workflow artifact

## Build and Packaging Details

### Build Target

The executable to build is the main package at:

- `honeydew/cmd/main`

The workflow should produce a native binary on each runner so the output matches the target OS.

### Artifact Contents

Each archive should contain:

- The built `honeydew` executable (`honeydew.exe` on Windows)
- `README.md`
- `LICENSE`

This makes the release asset immediately usable and self-describing.

### Archive Naming

Release asset names should follow this pattern:

- `honeydew-${tag}-${os}-${arch}.tar.gz` for Linux and macOS
- `honeydew-${tag}-${os}-${arch}.zip` for Windows

Examples:

- `honeydew-v0.1.0-linux-x64.tar.gz`
- `honeydew-v0.1.0-macos-x64.tar.gz`
- `honeydew-v0.1.0-windows-x64.zip`

The exact architecture label should come from the runner context or be set explicitly in the matrix to avoid ambiguous names.

### Windows Differences

Windows packaging needs two explicit differences:

- The executable name should end with `.exe`
- Archive creation should use `Compress-Archive` or an equivalent PowerShell-native step

Linux and macOS can share a tar-based packaging step.

## Release Job

The `release` job should:

1. Depend on the `build` job
2. Download all uploaded artifacts
3. Create a GitHub Release using the pushed tag as both the release tag and display name
4. Upload all packaged archives as release assets

The release body can be minimal. A fixed short template is sufficient unless richer release notes are added later.

## Failure Handling

- If any matrix build fails, the `release` job must not run
- No partial release should be published
- Packaging failures are treated the same as build failures

This preserves trust in tagged releases by ensuring every published tag has all supported platform assets.

## Validation Plan

Before considering the workflow ready:

1. Confirm existing repository layout and main package path still match this design
2. Validate MoonBit commands used by the workflow against the current project structure
3. Run the project checks that already exist, including `moon check` and `moon test`
4. Review the workflow YAML for OS-specific command correctness and artifact naming consistency

## Implementation Notes

- Add the workflow under `.github/workflows/` at the repository root
- Prefer one self-contained workflow over splitting release logic across multiple workflows
- Keep CI for normal branch pushes separate from release automation
- If the repository later needs multi-architecture assets, extend the matrix rather than duplicating the workflow
