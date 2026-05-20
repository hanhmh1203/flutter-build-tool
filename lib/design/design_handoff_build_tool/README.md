# Handoff: Flutter Build Tool — Light "Paper" Redesign

## Overview

A desktop GUI tool for running Flutter build/run commands across multiple local
projects. Replaces a CLI workflow with a centralized panel: pick a project →
configure entry / flavor / device → run common actions (Run, Build APK/AAB/IPA,
build_runner, etc.) or trigger pre-existing `.sh` release scripts → stream the
output into a live log.

This redesign reskins the original dark UI into a refined, light, "paper-like"
desktop aesthetic inspired by the Claude desktop app, with serif display type
for headings and a calmer information architecture (tabs for the log,
release-script cards, per-project header stats).

## About the Design Files

The files in this bundle are **design references created in HTML** — interactive
prototypes showing the intended look and behavior, **not production code to copy
directly**. The task is to **recreate these designs in the target codebase's
existing environment** (the real Flutter Build Tool, whatever stack it uses —
Tauri + React, Electron, Flutter desktop, native macOS, etc.) using that
codebase's established patterns, components and libraries.

If the project does not yet have a chosen framework, pick whichever is most
appropriate (e.g. Tauri + React for a lightweight, cross-platform shell). The
HTML / React / Babel setup here is a prototyping convenience, not a target.

## Fidelity

**High-fidelity.** The mock has final colors, typography, spacing, hover/active
states, and motion. Recreate it pixel-perfectly using the codebase's existing
component primitives. All color, type, and spacing tokens listed below are
authoritative — copy them into the codebase's theme.

## Window Specs

- Designed for a fixed-size desktop window
- **Target size:** ~1100 × 760 px (default), resizable; minimum sensible
  width is ~960 px before the 3-column config grid wraps
- **Chrome:** native window chrome OR custom titlebar with macOS-style traffic
  lights on the left and a centered monospace title

---

## Screens / Views

The tool is a single window with one main layout. Below is the layout broken
down by region.

### Window grid

```
┌──────────────────────────────────────────────────────────────────┐
│                          TITLEBAR  42px                          │
├──────────────┬───────────────────────────────────────────────────┤
│              │              PROJECT HEADER                       │
│              ├───────────────────────────────────────────────────┤
│   SIDEBAR    │              CONFIG (entry / flavor / device)     │
│   260px      ├───────────────────────────────────────────────────┤
│              │              ACTIONS  (run / build / scripts)     │
│              ├───────────────────────────────────────────────────┤
│              │              LOG AREA  (tabs + body, fills rest)  │
└──────────────┴───────────────────────────────────────────────────┘
```

CSS: `grid-template-columns: 260px 1fr; grid-template-rows: 42px 1fr;`

---

### 1. Titlebar (top, full-width, 42 px tall)

- Background: `--paper` (#F4F1E8)
- Bottom border: 1 px solid `--hairline` (#EDE9DD)
- Padding: `0 14px`, items in flex row with `gap: 8px`

**Contents (left → right):**
1. Three traffic-light dots, 11 × 11 px, gap 6 px:
   - Red `#EC6A5E`, yellow `#F4BE4F`, green `#61C454`
   - Hairline border `0.5px rgba(0,0,0,.1)`
2. **Centered title** — `build_tool · v2.4`
   - Font: `JetBrains Mono` 11 px, color `--muted`
3. **Right-side meta** (flex, gap 14 px, mono 11 px, color `--muted`):
   - **Branch pill**: small `--ok` (green) dot + branch name (e.g. `feat/scanner`).
     Background `--surface`, 1 px `--hairline` border, pill-shape.
   - **Flutter version** label: `flutter 3.24.5` (plain text)

---

### 2. Sidebar (left, 260 px wide)

Background `--paper`. Right border 1 px `--hairline`. Vertical flex container.

#### 2a. Sidebar header (padding 22/22/14)
- **Eyebrow**: mono 10 px, uppercase, letter-spacing .14em, color `--muted`,
  text: `workspace`
- **Heading**: `Projects.` — Source Serif 4 weight 500, 28 px, letter-spacing
  -0.02em, color `--text`. The trailing period is `--accent` color.

#### 2b. Search bar (margin 0 14 8)
- Pill (border-radius 999, padding 7/12), background `--surface`, 1 px
  `--hairline` border
- Search icon (tabler `ti-search`, 13 px, color `--muted`)
- Borderless input, DM Sans 12.5 px, placeholder `Search projects`
- Right-side keyboard hint `⌘P`: mono 10 px, 1 px 5 px padding, 1 px
  `--hairline` border, 4 px radius, background `--surface-2`

#### 2c. Project list (flex 1, overflow-y auto, padding 4/8/8)
Each list item:
- Padding `10px 12px`, border-radius `10px`, margin-bottom 1 px
- Hover: background `--surface`
- Active: background `--surface`, inset 1 px `--border` ring, plus a 2 px
  vertical bar (`--accent`) at `left: -2px; top: 14px; bottom: 14px;`
  border-radius 2 px
- Cursor: pointer
- Transition 140 ms on background

Item internal layout (column):
1. **Top row** (flex, space-between, gap 6):
   - **Name group** (flex, gap 8):
     - Glyph: 18 × 18 box, 5 px radius, background `--accent-tint`, italic
       Source Serif 4 500 14 px, color `--accent`, contains the first letter
       of the project (`v`, `l`, `s`).
     - Project name: DM Sans 600 13.5 px, color `--text`, letter-spacing
       -0.005em.
   - **Three-dot menu button** (`ti-dots`): color `--dim`, only visible on
     hover (`opacity: 0` → 1 on item hover, 120 ms transition), 14 px, 2/4 px
     padding, 4 px radius. Hover: color `--text`, background `--surface-2`.
2. **Path row**: mono 11 px, color `--muted`, padding-left 26 px (to align
   with name after glyph), truncated with ellipsis to ~30 chars.
3. **Status row** (active item only): padding-left 26 px, gap 8, mono 10 px,
   color `--muted`. Contains:
   - Branch with a small `--ok` dot before it (5 × 5 circle)
   - Bullet separator
   - Last-build relative time (e.g. `just now`, `2h ago`)

#### 2d. Sidebar footer (padding 10/12/14, top border 1 px `--hairline`)
- Full-width **Add project** button:
  - Background transparent, 1 px **dashed** `--border-2`, 10 px radius
  - Padding 9 px 12 px, DM Sans 500 12.5 px, color `--muted`
  - Flex row, center-aligned, gap 6 px, with `ti-plus` icon
  - Hover: border-color `--accent`, color `--accent`, background `--accent-tint`

---

### 3. Project header (main top region)

- Padding `var(--pad-y) var(--pad)` (default 18/24)
- Bottom border 1 px `--hairline`
- Flex row, `align-items: flex-end`, `justify-content: space-between`,
  gap 24 px

**Title block (left):**
- **Eyebrow**: mono 10.5 px uppercase letter-spacing .14em color `--muted`,
  flex row with a 5 × 5 `--accent` dot before, text: `active project`
- **H1**: Source Serif 4 weight 500, **34 px**, letter-spacing -0.025em,
  line-height 1. The last character of the project name is italicized and
  colored `--accent` (e.g. "logigra" + italic accent "m"). Inline span style:
  `font-style: italic; color: var(--accent); font-weight: 500;`
- **Path**: mono 11.5 px, color `--muted`, margin-top 8 px. Slashes are
  rendered separately with color `--dim` for subtle hierarchy.

**Head stats (right, optional via tweak):**
- Flex row, gap 18 px, mono 11 px, color `--muted`, align-items flex-end
- Three stat cells (label / value column, right-aligned, gap 3):
  1. `LAST BUILD` (label) / `3.2s ✓` (value, color `--ok`)
  2. `SIZE`       / `18.4 MB`
  3. `FLUTTER`    / `3.24.5`
- Label: 9.5 px letter-spacing .12em uppercase color `--dim`
- Value: 13 px color `--text` weight 500

---

### 4. Config row

- Padding `var(--pad-y) var(--pad)`, bottom border 1 px `--hairline`
- CSS grid: `grid-template-columns: 1.4fr 1fr 1fr auto;` gap 24 px, items
  align flex-end

**Three "Field" cells (Entry, Flavor, Device):**
- Each is a column (gap 6 px):
  - **Label**: mono 10 px uppercase letter-spacing .12em color `--muted`,
    e.g. `ENTRY`, `FLAVOR`, `DEVICE`
  - **Select** (custom): underline-only style
    - `appearance: none`, transparent background, no border except
      `border-bottom: 1px solid var(--border)`
    - Mono 13.5 px weight 500, color `--text`, padding `5px 22px 6px 0`
    - Hover/focus: border-bottom color `--accent`
    - Custom chevron drawn via `::after` (two angled 1.5 px borders forming
      a down-caret), color `--muted`, positioned right 4 / vertically
      centered

**Fourth cell — toggle row:**
- Flex, align-items center, gap 10, padding-bottom 6
- **Switch**: 32 × 18 pill, background `--border` (off) / `--accent` (on),
  140 ms transition. Knob: 14 × 14 white circle with `0 1px 2px rgba(0,0,0,.15)`
  shadow, translated 14 px when on.
- Label: `Clean before build`, DM Sans 500 13 px, color `--text-2`

---

### 5. Actions

Padding `var(--pad-y) var(--pad)`, bottom border 1 px `--hairline`, column
flex with gap 14 px.

#### 5a. Actions grid (top row, flex wrap, gap 8)

- **Primary button — Run**
  - Background `--text` (#1F1E1D), color `--bg` (#FAF9F5), no separate border
  - Pill, padding `9px 20px`
  - Content: 8 × 8 play triangle (CSS clip-path), text `Run`, kbd `⌘R`
  - Hover: background → `--accent`, color → white
  - Inner kbd: mono 10 px, color `#FAF1EB`, background `rgba(255,255,255,.12)`,
    transparent border, 4 px radius, 1/5 padding

- **Secondary buttons** (Clean + Pub, build_runner, APK, AAB, IPA)
  - Background `--surface`, 1 px `--border`, color `--text`
  - Pill, padding `9px 16px`, DM Sans 600 13 px, letter-spacing -0.005em
  - Tabler icons 15 px before label (sparkles, settings-cog, package,
    brand-android, brand-apple)
  - Hover: border `--border-2`, background `--surface-2`, translateY(-0.5px)
  - Running state: border + text `--accent`, background `--accent-tint`,
    `pulse` 1.6s box-shadow animation
  - 140 ms transition

- **Separator** between scripty buttons (Clean+Pub, build_runner) and binary
  builds (APK, AAB, IPA): 1 × 18 px `--border` rule, margin 0 4 px

#### 5b. Release scripts block

- Label row: mono 10 px uppercase letter-spacing .12em color `--muted`,
  followed by a secondary badge (`N detected in ./scripts`, mono 10 px,
  color `--dim`, the path part in `--muted`)
- Below: CSS grid `repeat(auto-fill, minmax(220px, 1fr))`, gap 8

**Script card:**
- Background `--surface`, 1 px `--border`, 10 px radius
- Padding `10px 12px`
- Flex row, gap 10, align-items center
- 140 ms transitions on all properties
- Hover: border `--accent`, background `--accent-tint`,
  translateY(-0.5px); icon box turns white-on-accent; play chevron shifts +1 px
- Running state: same accent treatment + pulse animation

Card internals:
1. **Icon box** — 28 × 28, 6 px radius, background `--surface-2`,
   1 px `--hairline` border, contains tabler `ti-terminal-2` 15 px color `--text-2`
2. **Meta column** (flex 1, min-width 0):
   - Filename: mono 12 px weight 600 color `--text` letter-spacing -0.01em,
     truncated. Examples: `build_nightly.sh`, `deploy_firebase.sh`,
     `release_store.sh`, `notarize_macos.sh`
   - Description: DM Sans 10.5 px color `--muted`, truncated. Examples:
     `APK + AAB · nightly`, `upload to App Distribution`, `AAB → Play Console`
3. **Play chevron** — `ti-player-play-filled`, 13 px, color `--dim`,
   shifts +1 px on hover

**"Add script" card** (last cell, dashed):
- Same dimensions but `border-style: dashed`, background transparent
- Icon box: dashed `--border-2`, color `--muted`, background transparent
- Filename text color `--muted`, description `browse .sh files…`
- Hover: background `--accent-tint`

#### 5c. Custom commands block

- Label `CUSTOM COMMANDS` (mono 10 px uppercase letter-spacing .12em color `--muted`)
- Chips: flex wrap, gap 6
- Each chip: inline-flex gap 6, padding `5px 12px`, pill, 1 px `--border`
  border, transparent background, mono 11.5 px color `--text-2`. Icon
  13 px before label.
- Hover: border + color `--accent`, background `--accent-tint`
- Add chip: dashed border, color `--muted`, with `ti-plus`

---

### 6. Log area (fills remaining height)

Flex column. Background `--surface-2`, top border 1 px `--hairline`.

#### 6a. Log bar (top)
- Padding 9 px 24 px, flex row gap 6, background `--paper`, bottom border
  1 px `--hairline`
- **Tabs** (left): Output / Problems / History
  - Each tab: padding `5px 12px` (with extra padding-bottom 14 and
    margin-bottom -10 to overlap the bottom border), mono 11 px weight 500
    color `--muted`. 1.5 px bottom border transparent.
  - Active tab: color `--text`, bottom border `--accent`. Its count pill
    background `--accent-tint`, color `--accent`.
  - Each tab has a small **count pill** to its right: 9.5 px, padding 1 px
    5 px, pill radius, background `--surface-2`, color `--muted`.
- **Status (center-right, margin-left auto)**: mono 11.5 px color `--text-2`
  - Idle state: green tick circle (14 × 14, `--ok` background, white "✓"
    9 px weight 700) + `<lastResult.name> (<flavor>) · <time>s` (the
    "(flavor)" only when present; the trailing time in `--muted`)
  - Running state: 14 × 14 spinning ring (1.5 px `--accent` border with
    transparent top, 900 ms linear rotation) + `Running · <action name>`
- **Tool icons (right)**: filter, search, save (`ti-device-floppy`),
  clear (`ti-eraser`). Each is a 26 × 26 icon button, transparent
  background, 6 px radius, color `--muted`, icon 15 px. Hover: background
  `--surface`, color `--text`.

#### 6b. Progress strip
- 2 px tall, full width, background `--hairline`, flex-shrink 0
- Active (`running`): 30 %-wide `--accent` bar with `slide` keyframe
  (translateX -100% → 380% over 1.2 s ease-in-out infinite)
- Idle: full-width `--ok` bar at 0.4 opacity, no animation

#### 6c. Log body
- Flex 1, overflow-y auto
- Padding 14 px 24 px 24 px
- Font: JetBrains Mono 12 px line-height 1.85
- Background `--surface-2` (warm by default), color `--text-2`

**Log line layout** (flex row, gap 10, align-items baseline):
1. **Gutter** (18 px, right-aligned, mono 10.5 px color `--dim`,
   user-select none): line number (when "log line numbers" tweak on),
   otherwise empty.
2. **Glyph** (14 px column, center-aligned, weight 700): one of
   - `✓` colored `--ok` (success)
   - `→` colored `--accent` (info)
   - `!` colored `--warn`
   - `✗` colored `--danger`
   - `·` colored `--dim`
   - `↑` colored `--dim` (used for "package update available" lines)
3. **Body** (flex 1, color `--text`): the message. Inline spans for
   semantic colors:
   - `.pkg` weight 600 color `--text` (package name)
   - `.ver` color `--muted` (version)
   - `.avail` color `--ok` (e.g. `→ 0.14.2`)
   - `.path` color `--accent` (file paths, commands)
   - `.dim` color `--dim` (parenthetical notes, file sizes)
   - `.ok` color `--ok` weight 500
   - `.err` color `--danger` weight 500

**Section divider** lines:
- Margin 14 px 0 6 px, padding-top 10 px, top border 1 px **dashed** `--border`
- Body text color `--muted`, font-size 10.5 px letter-spacing .1em uppercase
- Rendered as `— <section name> —`

**Trailing cursor** (while running): inline-block 7 × 13 `--accent`
rectangle, vertical-align -2 px, `blink` 1 s step animation (50 % opacity 0).

**History tab content**: list of build entries with columns
`name (110 px) · flavor (90 px) · duration (80 px) · time`. 1 px dashed
`--hairline` bottom border between rows. Same glyph column as log lines
(ok/err).

**Problems tab content**: single dim line `No problems found. Last
analyze: 2 minutes ago.`

---

## Tweaks panel (in-app design controls)

Available via the host toolbar's "Tweaks" toggle. Floating bottom-right
panel with these controls. **In production, do NOT ship the Tweaks panel
as user UI** — translate selected tweak values into the app's settings /
preferences UI.

| Key | Type | Options | Effect |
|---|---|---|---|
| `accent` | color | `#C15F3C`, `#7C4A2A`, `#5C7A3F`, `#3F5C7A`, `#7A3F5C`, `#1F1E1D` | Sets `--accent` and derived `--accent-tint`/`--accent-soft` |
| `headingStyle` | radio | `serif` / `sans` | Toggles H1 / H2 font family (and the italic-accent treatment vs underline-accent) |
| `logBg` | select | `warm` / `white` / `ink` | Overrides `--surface-2` for the log body. `ink` = dark `#2A2823`, useful for high-contrast log mode |
| `density` | radio | `compact` / `comfortable` / `spacious` | Sets `--pad` (18/24/32) and `--pad-y` (12/18/24) |
| `showHeadStats` | toggle | bool | Show/hide the right-side header stats block |
| `showLineNumbers` | toggle | bool | Show/hide log gutter line numbers |

---

## Interactions & Behavior

### Project switching
- Clicking a sidebar item makes it active (apply active styles described
  above) and replaces the main panel's project context.
- The Entry / Flavor / Device selects reset to the new project's first
  option in each list. This is a deliberate UX choice — different
  projects rarely share flavor/entry names.
- The header H1 and path update.
- The release-scripts grid replaces with the new project's `.sh` list.
- (Not in mock but expected) The log can show a small "→ Switched to
  project: <name>" line as a `info` glyph.

### Run actions (Run, Clean+Pub, APK, AAB, IPA, build_runner)
- On click:
  1. If another action is `running`, ignore the click (one-at-a-time).
  2. Set the clicked button into `running` visual state (border+text
     `--accent`, pulse animation).
  3. Clear the log and write a section header `<Action> · <flavor>`
     plus an info line echoing the current entry/flavor/device.
  4. Stream the action's log lines at ~520 ms intervals (use a fake
     interval in the mock; in production, stream stdout from the child
     process).
  5. While running: log status shows spinner + `Running · <name>`,
     progress strip animates.
  6. On completion: clear `running`, log status shows green tick +
     `<name> (<flavor>) · <T>s`, progress strip becomes idle.

### Release script cards
- Click runs the script: same `running` lifecycle as the action buttons.
- Mock log streams a five-step `[1/5]…[5/5]` shell trace at 380 ms
  intervals. In production, stream actual `bash <script.path>` output.
- The card's name is the file's basename; the description is read from
  a JSON manifest or the first `# ` comment line of the script.

### Custom commands
- Click runs a quick command — log shows the section + `$ <cmd>`,
  followed by `✓ Done` after ~900 ms.
- "Add" prompts for a command string and appends a new chip with a
  default `ti-terminal-2` icon.
- In production, custom commands should persist per-project to disk.

### Log tabs
- Switching tabs swaps the body content. State is local to the window;
  Output is the default after each action.
- Tab counts update in real time (Output = log line count; Problems =
  parsed analyzer issue count; History = build records count).

### Hover / focus
- Sidebar items: background `--surface` on hover, no border ring.
- Buttons: see specs above. All transitions 140 ms ease.
- Selects: bottom border turns `--accent` on hover or focus.

### Keyboard
- `⌘P` opens project search (sidebar input gains focus).
- `⌘R` triggers Run.
- (Recommended) `⌘K` opens a command palette covering actions and scripts.
- (Recommended) Escape closes the Tweaks panel.

### Window
- The mock locks `max-height: 760px`. In a real desktop window, allow
  resizing; the log body absorbs extra vertical space, everything above
  it is fixed-height.

---

## State Management

Minimal local state. Suggested shape (TypeScript):

```ts
type ProjectId = string;

interface Project {
  id: ProjectId;
  name: string;
  glyph: string;          // single character, derived from name
  path: string;           // absolute filesystem path
  branch: string;         // current git branch (live, polled)
  entry: string[];        // candidate Dart entrypoints
  flavor: string[];       // candidate flutter flavors
  device: string[];       // available devices (from `flutter devices`)
  lastBuild: string;      // relative time string
  scripts: ScriptRef[];   // .sh files discovered under scripts/
}

interface ScriptRef {
  name: string;           // basename, e.g. "build_nightly.sh"
  path: string;           // path relative to project root
  desc: string;           // short description (see source)
}

interface BuildResult {
  name: string;
  flavor: string;
  time: number;           // seconds
  ok: boolean;
  artifactPath?: string;
  sizeBytes?: number;
}

interface AppState {
  projects: Project[];
  activeProjectId: ProjectId;
  config: { entry: string; flavor: string; device: string; clean: boolean };
  running: string | null;        // action key, e.g. "apk" or "script:build_nightly.sh"
  log: LogLine[];
  history: BuildResult[];
  lastResult: BuildResult;
  activeTab: "output" | "problems" | "history";
  customs: { cmd: string; icon: string }[];
}
```

**Data sources (production):**
- `projects[]` from a user-editable preferences file (~/.config/build_tool/projects.json or similar)
- `branch` live-polled via `git symbolic-ref --short HEAD` per project
- `entry`, `flavor` parsed from `lib/` filenames matching `main*.dart` and
  from `flutter.flavors` in pubspec or detected from build flavor configs
- `device` from `flutter devices --machine`
- `scripts[]` from globbing `scripts/*.sh` under the project root
- Action runs spawn child processes; stdout/stderr line-buffered into `log[]`
- `history` persisted to disk per-project

---

## Design Tokens

### Colors (CSS variables, all defined on `:root`)

```css
/* Backgrounds */
--bg:         #FAF9F5;   /* app background (warm cream) */
--paper:      #F4F1E8;   /* titlebar, sidebar, log toolbar */
--surface:    #FFFFFF;   /* cards, buttons, search */
--surface-2:  #F7F4EC;   /* hover surface, log body (warm) */

/* Lines */
--border:     #E8E4D9;   /* default 1 px border */
--border-2:   #D6D1C4;   /* stronger border, dashed handles */
--hairline:   #EDE9DD;   /* near-invisible dividers */

/* Text */
--text:       #1F1E1D;   /* primary */
--text-2:     #3D3B36;   /* secondary */
--muted:      #807E76;   /* meta, labels */
--dim:        #B5B2A8;   /* gutter, slashes, faint metadata */

/* Accent (Claude clay) */
--accent:      #C15F3C;
--accent-hov:  #A94C2D;
--accent-soft: #F2E6DE;
--accent-tint: #FAF1EB;

/* Semantic */
--ok:     #5C7A3F;       /* success */
--warn:   #B8722E;       /* warning */
--danger: #B5453C;       /* error */
```

**Alternate accents (Tweaks)**: `#7C4A2A`, `#5C7A3F`, `#3F5C7A`, `#7A3F5C`, `#1F1E1D`.

**Ink log mode** (logBg=`ink`): `--surface-2` overrides to `#2A2823`.

### Typography

```css
--serif: 'Source Serif 4', Georgia, serif;            /* display H1, sidebar H2 */
--sans:  'DM Sans', ui-sans-serif, sans-serif;        /* UI: labels, buttons, body */
--mono:  'JetBrains Mono', ui-monospace, monospace;   /* code, paths, log, eyebrows */
```

Google Fonts URL:
```
https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,400;8..60,500;8..60,600&family=DM+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap
```

**Type scale used:**
| Role | Family | Size | Weight | Tracking |
|---|---|---|---|---|
| H1 (project name) | Source Serif 4 | 34 | 500 | -0.025em |
| H2 (sidebar "Projects.") | Source Serif 4 | 28 | 500 | -0.02em |
| Eyebrow (uppercase mono) | JetBrains Mono | 10–10.5 | 400 | .12–.14em |
| Field label | JetBrains Mono | 10 | 400 | .12em |
| Body / button | DM Sans | 13 | 600 | -0.005em |
| Select value | JetBrains Mono | 13.5 | 500 | — |
| Toggle label | DM Sans | 13 | 500 | — |
| Project name (sidebar) | DM Sans | 13.5 | 600 | -0.005em |
| Project path | JetBrains Mono | 11 | 400 | — |
| Status row | JetBrains Mono | 10 | 400 | — |
| Log line (body) | JetBrains Mono | 12 | 400 | line-height 1.85 |
| Log gutter | JetBrains Mono | 10.5 | 400 | — |
| Log status | JetBrains Mono | 11.5 | 400 | — |
| Stat value | JetBrains Mono | 13 | 500 | — |
| Stat label | JetBrains Mono | 9.5 | 400 | .12em uppercase |

### Spacing & radius

```css
--r-sm:   6px;
--r-md:   10px;
--r-lg:   14px;
--r-pill: 999px;

--pad:    24px;  /* horizontal default; 18 compact, 32 spacious */
--pad-y:  18px;  /* vertical default;   12 compact, 24 spacious */
```

Common gaps used in layout: `4, 6, 8, 10, 14, 18, 24`. Stick to these.

### Shadows

Used sparingly — this is a flat, line-based design.
- Switch knob: `0 1px 2px rgba(0,0,0,.15)`
- Running pulse: `0 0 0 4px rgba(193,95,60,.12)` at 50 % keyframe
- Traffic-light dots: `0.5px solid rgba(0,0,0,.1)` (border, not shadow)
- Tweaks panel (from starter): `0 1px 0 rgba(255,255,255,.5) inset, 0 12px 40px rgba(0,0,0,.18)`

### Motion

- All hover transitions: **140 ms ease** on color / background / border / transform
- Pulse keyframe (running buttons / cards): 1.6 s ease-in-out infinite
- Progress bar slide: 1.2 s ease-in-out infinite
- Cursor blink: 1 s steps(1) infinite
- Spinner: 900 ms linear infinite
- Subtle button hover lift: `translateY(-0.5px)`

---

## Assets

- **Icons**: [Tabler Icons](https://tabler.io/icons) via the
  `@tabler/icons-webfont` CDN package. Specific icons used:
  - `ti-search`, `ti-plus`, `ti-dots`
  - `ti-sparkles`, `ti-settings-cog`, `ti-package`
  - `ti-brand-android`, `ti-brand-apple`
  - `ti-terminal-2`, `ti-flask`, `ti-zoom-check`, `ti-arrow-up`
  - `ti-player-play-filled`
  - `ti-filter`, `ti-device-floppy`, `ti-eraser`
  - In production, use the codebase's existing icon library if there is
    one; otherwise install `@tabler/icons-react` (or platform equivalent).
- **Fonts**: Google Fonts URL above. Self-host for production / offline use.
- No bitmap or vector assets ship with the design.

---

## Files

In this bundle:
- `Build Tool.html` — the HTML shell, root styles, and font/script imports.
  Read for the full CSS token system and component class rules.
- `build-tool.jsx` — React (JSX, transpiled in-browser by Babel) that
  contains all components, state logic, mock data, and the log streamer.
  Read for the layout React tree and per-action log scripts.
- `tweaks-panel.jsx` — utility component from the design tool that
  implements the floating Tweaks panel. **Not** part of the shipping
  app; remove in production.

Open `Build Tool.html` in any modern browser to interact with the design.
