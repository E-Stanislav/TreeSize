# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

TreeSize — a macOS disk-space analyzer (treemap/sunburst visualization, top files, delete-to-trash), built per the spec in `macos-disk-manager-tz.md` (Russian, at repo root). Spec stage 1 (MVP) is implemented; stages 2–5 (cleanup categories, uninstaller, duplicates, RAM monitor, snapshots, localization) are not started — the spec file is the source of truth for planned features.

## Commands

```bash
# Build (run from TreeSize/ — the .xcodeproj is there, not at repo root)
cd TreeSize && xcodebuild -project TreeSize.xcodeproj -scheme TreeSize -configuration Debug build

# Unit tests
cd TreeSize && xcodebuild -project TreeSize.xcodeproj -scheme TreeSize -only-testing:TreeSizeTests test

# Single test
cd TreeSize && xcodebuild -project TreeSize.xcodeproj -scheme TreeSize -only-testing:TreeSizeTests/TreeSizeTests/treemapCoversFullRect test
```

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. UI test target exists but is not maintained.

## Critical build/toolchain gotchas

- The project builds with **`-default-isolation=MainActor`**. All non-UI types (FileNode, FileCategory, DiskScanner, TreemapLayout, VolumeService, TreeMapSlice, VolumeInfo, free functions like `formatBytes`) are marked `nonisolated` — this is required, otherwise the concurrent scanner serializes onto the main thread and freezes the UI. New model/service code needs the same treatment.
- In this SDK (macOS 26), `Text.lineLimit(Int)` / `.truncationMode` in a modifier chain resolve to View modifiers returning `some View`, which breaks `GraphicsContext.draw(Text, in:)`. Don't use them before Canvas `draw`; Canvas clips to the rect anyway.
- `Color.quaternary` doesn't exist (only `.quaternary` as ShapeStyle). In ternaries mixing it with Color, wrap both branches in `AnyShapeStyle`.
- `ByteCountFormatter.string(fromByteCount:countStyle:)` (not the `stringFromByteCount` spelling).
- Picker style is `.pickerStyle(.segmented)`.
- Xcode project is objectVersion 77 with file-system-synchronized groups: **new .swift files under TreeSize/TreeSize/ are picked up automatically** — no pbxproj editing needed.
- App Sandbox is enabled. Scanning relies on user-selected folders via NSOpenPanel (security-scoped access handled in `AppModel.scan`).

## Architecture

MVVM with @Observable, layered per the spec (§3.5):

- `Models/FileNode.swift` — `nonisolated final class` tree node (size, children, parent, file/directory counts). Mutation during scan only; UI reads afterwards. Free `formatBytes`/`formatCount` helpers live here.
- `Models/FileCategory.swift` — file-type classification → HSB color coding (`color(variant:)` varies brightness so same-category neighbors differ).
- `Services/DiskScanner.swift` — async recursive scan via unstructured `TaskGroup` per directory. Packages (`.app` etc.) are treated as single leaves with recursive size from resource values. `ScanCounter` actor throttles progress reports (every 1000 files).
- `Services/TreemapLayout.swift` — pure squarified treemap (Bruls); `flatten()` renders 2 levels deep, skipping blocks below a min area.
- `Services/VolumeService.swift` — mounted volume list (browsable only).
- `ViewModels/AppModel.swift` — single `@Observable @MainActor` model: scan lifecycle (cancellation, security scope), drill-down navigation (`navigationPath` stack), selection, top-files computation (background Task.detached), trash + tree rebalancing (`removeFromTree` subtracts sizes up the ancestor chain).
- `Views/` — `ContentView` switches on `AppModel.Section` (sidebar: Обзор/Диск/Топ файлов); `SidebarView`, `DashboardView` (volume cards + UsageRing), `TreemapView`/`SunburstView` (Canvas + `SpatialTapGesture` + `onContinuousHover`, hit-test deepest rect/segment), `TopFilesView` (card grid), `DetailsPanelView`, `Theme.swift` (`cardStyle`, `UsageRing`, `Chip` — CleanMyMac-style design system).

Key data flow: scan → FileNode tree → treemap/sunburst render children of `currentDirectory`; tap on a directory pushes it onto `navigationPath` (drill-down), tap on a file selects it for the details panel.
