const { useState, useEffect, useRef, useMemo } = React;

// ---------- DATA ----------
const PROJECTS = [
  {
    id: "virl",
    name: "virl",
    glyph: "v",
    path: "/Users/william/Documents/my_virl_app",
    branch: "main",
    entry: ["main.dart", "main_dev.dart"],
    flavor: ["dev", "prod"],
    device: ["Pixel 8 Pro", "SM S721B"],
    lastBuild: "2h ago",
    scripts: [
      { name: "release.sh",        path: "scripts/release.sh",        desc: "prod build + sign" },
    ],
  },
  {
    id: "logigram",
    name: "logigram",
    glyph: "l",
    path: "/Users/william/Documents/scs/code/logigram_flutter",
    branch: "feat/scanner",
    entry: ["main_nightly.dart", "main.dart", "main_staging.dart", "main_production.dart"],
    flavor: ["nightly", "staging", "production", "dev"],
    device: ["SM S721B", "Pixel 8 Pro", "iPhone 15 Pro", "macOS", "Chrome (web)"],
    lastBuild: "just now",
    scripts: [
      { name: "build_nightly.sh",   path: "scripts/build_nightly.sh",   desc: "APK + AAB · nightly" },
      { name: "deploy_firebase.sh", path: "scripts/deploy_firebase.sh", desc: "upload to App Distribution" },
      { name: "release_store.sh",   path: "scripts/release_store.sh",   desc: "AAB → Play Console" },
      { name: "notarize_macos.sh",  path: "scripts/notarize_macos.sh",  desc: "sign + notarize" },
    ],
  },
  {
    id: "shopify_app",
    name: "shopify_app",
    glyph: "s",
    path: "/Users/william/Documents/shopify/flutter_app",
    branch: "main",
    entry: ["main.dart", "main_staging.dart"],
    flavor: ["production", "staging"],
    device: ["iPhone 15 Pro", "Pixel 8 Pro"],
    lastBuild: "yesterday",
    scripts: [
      { name: "release_ios.sh",     path: "scripts/release_ios.sh",     desc: "IPA + TestFlight" },
      { name: "release_android.sh", path: "scripts/release_android.sh", desc: "AAB + Play Console" },
    ],
  },
];

// Sample initial log lines for the active project
const INITIAL_LOG = [
  { kind: "section", text: "flutter pub outdated" },
  { kind: "pkg", pkg: "google_mlkit_barcode_scanning", ver: "0.14.1", avail: "0.14.2" },
  { kind: "pkg", pkg: "google_mlkit_commons", ver: "0.11.0", avail: "0.11.1" },
  { kind: "pkg", pkg: "google_mlkit_text_recognition", ver: "0.15.0", avail: "0.15.1" },
  { kind: "pkg", pkg: "heif_converter", ver: "1.0.1", avail: "1.0.2" },
  { kind: "section", text: "build_runner" },
  { kind: "info", text: "Running build_runner build --delete-conflicting-outputs" },
  { kind: "ok",   text: "Generated 24 file(s) in 2.1s" },
  { kind: "section", text: "gradle" },
  { kind: "info", text: "Gradle task assembleNightlyRelease" },
  { kind: "ok",   text: 'Built <span class="path">build/app/outputs/flutter-apk/app-nightly-release.apk</span> <span class="dim">(18.4 MB)</span>' },
];

const ACTION_LOGS = {
  run: [
    { kind: "info", text: 'Running <span class="path">flutter run --flavor {flavor} -t {entry}</span>' },
    { kind: "info", text: "Syncing files to device {device}" },
    { kind: "ok",   text: "App started in debug mode" },
  ],
  cleanPub: [
    { kind: "info", text: "Running flutter clean" },
    { kind: "ok",   text: "Deleted build/" },
    { kind: "info", text: "Running flutter pub get" },
    { kind: "ok",   text: 'Got dependencies <span class="dim">(82 packages)</span>' },
  ],
  apk: [
    { kind: "info", text: 'Running <span class="path">flutter build apk --flavor {flavor}</span>' },
    { kind: "info", text: "Gradle task assembleNightlyRelease" },
    { kind: "ok",   text: 'Built <span class="path">app-{flavor}-release.apk</span> <span class="dim">(18.4 MB)</span>' },
  ],
  runner: [
    { kind: "info", text: "Running build_runner build --delete-conflicting-outputs" },
    { kind: "info", text: "Generating files" },
    { kind: "ok",   text: "Generated 24 file(s) in 2.1s" },
  ],
  ipa: [
    { kind: "info", text: 'Running <span class="path">flutter build ipa --flavor {flavor}</span>' },
    { kind: "info", text: "Building for iOS" },
    { kind: "ok",   text: "IPA built successfully" },
  ],
  aab: [
    { kind: "info", text: 'Running <span class="path">flutter build appbundle --flavor {flavor}</span>' },
    { kind: "info", text: "Gradle task bundleNightlyRelease" },
    { kind: "ok",   text: 'Built <span class="path">app-{flavor}-release.aab</span> <span class="dim">(24.1 MB)</span>' },
  ],
};

const ACTION_NAMES = {
  run: "Run",
  cleanPub: "Clean + Pub",
  apk: "Build APK",
  runner: "build_runner",
  ipa: "Build IPA",
  aab: "Build AAB",
};

// ---------- TWEAK DEFAULTS (persisted) ----------
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#C15F3C",
  "density": "comfortable",
  "headingStyle": "serif",
  "showHeadStats": true,
  "showLineNumbers": true,
  "logBg": "warm"
}/*EDITMODE-END*/;

// ---------- HELPERS ----------
function fmtPath(p) {
  // colorize the slashes in a path
  return p.split("/").map((s, i, a) => (
    <React.Fragment key={i}>
      {i > 0 && <span className="slash">/</span>}
      {s}
    </React.Fragment>
  ));
}

function clip(s, n) { return s.length > n ? s.slice(0, n - 1) + "…" : s; }

function App() {
  const t = window.useTweaks ? window.useTweaks(TWEAK_DEFAULTS) : [TWEAK_DEFAULTS, () => {}];
  const [tweaks, setTweak] = t;

  // Apply density to body
  useEffect(() => {
    document.body.dataset.density = tweaks.density || "comfortable";
  }, [tweaks.density]);

  // Apply accent
  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty("--accent", tweaks.accent);
    // derive soft tints
    root.style.setProperty("--accent-tint", hexA(tweaks.accent, 0.08));
    root.style.setProperty("--accent-soft", hexA(tweaks.accent, 0.18));
  }, [tweaks.accent]);

  // Apply log bg
  useEffect(() => {
    const root = document.documentElement;
    if (tweaks.logBg === "white") {
      root.style.setProperty("--surface-2", "#FFFFFF");
    } else if (tweaks.logBg === "ink") {
      root.style.setProperty("--surface-2", "#2A2823");
    } else {
      root.style.setProperty("--surface-2", "#F7F4EC");
    }
  }, [tweaks.logBg]);

  // ---- App state ----
  const [activeId, setActiveId] = useState("logigram");
  const proj = PROJECTS.find(p => p.id === activeId) || PROJECTS[1];

  const [entry,  setEntry]  = useState(proj.entry[0]);
  const [flavor, setFlavor] = useState(proj.flavor[0]);
  const [device, setDevice] = useState(proj.device[0]);
  const [clean,  setClean]  = useState(true);

  // re-sync selects when switching project
  useEffect(() => {
    setEntry(proj.entry[0]);
    setFlavor(proj.flavor[0]);
    setDevice(proj.device[0]);
  }, [activeId]);

  const [logLines, setLogLines] = useState(INITIAL_LOG);
  const [running, setRunning]   = useState(null);   // current action key
  const [lastResult, setLastResult] = useState({ name: "Build APK", flavor: "nightly", time: 3.2, ok: true });
  const [activeTab, setActiveTab] = useState("output");
  const [customs, setCustoms] = useState([
    { cmd: "flutter test",    icon: "ti-flask" },
    { cmd: "flutter analyze", icon: "ti-zoom-check" },
    { cmd: "flutter pub upgrade", icon: "ti-arrow-up" },
  ]);

  const logRef = useRef(null);
  useEffect(() => {
    if (logRef.current) logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [logLines]);

  // ---- Runners ----
  function appendLog(line) { setLogLines(ls => [...ls, line]); }
  function clearLog() { setLogLines([{ kind:"dim", text:"Log cleared." }]); }

  function runAction(key) {
    if (running) return;
    setRunning(key);
    setLogLines([
      { kind: "section", text: `${ACTION_NAMES[key]} · ${flavor}` },
      { kind: "info", text: `<span class="dim">$</span> entry=<span class="ok">${entry}</span> flavor=<span class="ok">${flavor}</span> device=<span class="ok">${device}</span>` },
    ]);
    const lines = (ACTION_LOGS[key] || []).map(l => ({
      ...l,
      text: l.text.replaceAll("{flavor}", flavor).replaceAll("{entry}", entry).replaceAll("{device}", device),
    }));
    let i = 0;
    const start = performance.now();
    const tick = setInterval(() => {
      if (i < lines.length) {
        appendLog(lines[i]);
        i++;
      } else {
        clearInterval(tick);
        setRunning(null);
        const t = ((performance.now() - start) / 1000).toFixed(1);
        setLastResult({ name: ACTION_NAMES[key], flavor, time: t, ok: true });
      }
    }, 520);
  }

  function runCustom(cmd) {
    if (running) return;
    setRunning("custom");
    setLogLines([
      { kind: "section", text: cmd },
      { kind: "info", text: `<span class="dim">$</span> ${cmd}` },
    ]);
    const start = performance.now();
    setTimeout(() => {
      appendLog({ kind: "ok", text: "Done" });
      setRunning(null);
      const t = ((performance.now() - start) / 1000).toFixed(1);
      setLastResult({ name: cmd, flavor: "", time: t, ok: true });
    }, 900);
  }

  function runScript(script) {
    if (running) return;
    setRunning("script:" + script.name);
    setLogLines([
      { kind: "section", text: script.name + " · " + script.desc },
      { kind: "info", text: `<span class="dim">$</span> bash <span class="path">${script.path}</span>` },
    ]);
    // Mock realistic shell output
    const lines = [
      { kind: "dim",  text: `<span class="dim">[1/5]</span> Resolving environment…` },
      { kind: "info", text: `Loading <span class="path">.env.${flavor}</span>` },
      { kind: "dim",  text: `<span class="dim">[2/5]</span> flutter clean &amp;&amp; flutter pub get` },
      { kind: "ok",   text: "Got dependencies" },
      { kind: "dim",  text: `<span class="dim">[3/5]</span> build_runner build --delete-conflicting-outputs` },
      { kind: "ok",   text: "Generated 24 file(s)" },
      { kind: "dim",  text: `<span class="dim">[4/5]</span> flutter build --flavor ${flavor} --release` },
      { kind: "ok",   text: 'Built <span class="path">build/app/outputs/bundle/' + flavor + 'Release/app-' + flavor + '-release.aab</span> <span class="dim">(24.1 MB)</span>' },
      { kind: "dim",  text: `<span class="dim">[5/5]</span> Uploading artifact…` },
      { kind: "ok",   text: 'Done. <span class="dim">artifact://' + script.name.replace(".sh","") + '-' + Date.now().toString(36) + '</span>' },
    ];
    let i = 0;
    const start = performance.now();
    const tick = setInterval(() => {
      if (i < lines.length) { appendLog(lines[i]); i++; }
      else {
        clearInterval(tick);
        setRunning(null);
        const t = ((performance.now() - start) / 1000).toFixed(1);
        setLastResult({ name: script.name, flavor, time: t, ok: true });
      }
    }, 380);
  }

  function addCustom() {
    const c = prompt("Enter custom command:");
    if (!c) return;
    setCustoms(cs => [...cs, { cmd: c, icon: "ti-terminal-2" }]);
  }

  // ---- Render ----
  const headingFam = tweaks.headingStyle === "sans"
    ? "var(--sans)"
    : "var(--serif)";
  const headingStyleEm = tweaks.headingStyle === "sans"
    ? { fontStyle: "normal", textDecoration: "underline", textDecorationThickness: "2px", textDecorationColor: "var(--accent)", textUnderlineOffset: "5px" }
    : { fontStyle: "italic", color: "var(--accent)" };

  // Heading: split project name with last char accented for italic flavor
  const nameMain = proj.name.slice(0, -1);
  const nameTail = proj.name.slice(-1);

  return (
    <div className="app">
      {/* TITLEBAR */}
      <div className="titlebar">
        <div className="traffic">
          <span className="dot r"></span>
          <span className="dot y"></span>
          <span className="dot g"></span>
        </div>
        <div className="tb-title">build_tool · v2.4</div>
        <div className="tb-meta">
          <span className="pill"><span className="swatch"></span> {proj.branch}</span>
          <span>flutter 3.24.5</span>
        </div>
      </div>

      {/* SIDEBAR */}
      <aside className="sidebar">
        <div className="sidebar-head">
          <div className="eyebrow">workspace</div>
          <h2 style={{ fontFamily: headingFam }}>
            Projects<span style={{ color: "var(--accent)" }}>.</span>
          </h2>
        </div>
        <div className="sidebar-search">
          <i className="ti ti-search" style={{ fontSize: 13 }}></i>
          <input placeholder="Search projects" />
          <span className="kbd">⌘P</span>
        </div>
        <div className="project-list">
          {PROJECTS.map(p => (
            <div
              key={p.id}
              className={"project-item" + (p.id === activeId ? " active" : "")}
              onClick={() => setActiveId(p.id)}
            >
              <div className="proj-row">
                <span className="proj-name">
                  <span className="glyph">{p.glyph}</span>
                  {p.name}
                </span>
                <button className="proj-menu" onClick={e => e.stopPropagation()}>
                  <i className="ti ti-dots"></i>
                </button>
              </div>
              <div className="proj-path">{clip(p.path, 30)}</div>
              {p.id === activeId && (
                <div className="proj-status">
                  <span className="branch">{p.branch}</span>
                  <span>·</span>
                  <span>{p.lastBuild}</span>
                </div>
              )}
            </div>
          ))}
        </div>
        <div className="sidebar-foot">
          <button className="btn-add">
            <i className="ti ti-plus"></i> Add project
          </button>
        </div>
      </aside>

      {/* MAIN */}
      <main className="main">
        {/* HEADER */}
        <div className="proj-head">
          <div className="title-block">
            <div className="eyebrow">
              <span className="dot-mini"></span> active project
            </div>
            <h1 style={{ fontFamily: headingFam }}>
              {nameMain}<em style={headingStyleEm}>{nameTail}</em>
            </h1>
            <div className="path">{fmtPath(proj.path)}</div>
          </div>
          {tweaks.showHeadStats && (
            <div className="head-stats">
              <div className="stat">
                <span className="label">last build</span>
                <span className={"val " + (lastResult.ok ? "ok" : "")}>
                  {lastResult.time}s {lastResult.ok ? "✓" : "✗"}
                </span>
              </div>
              <div className="stat">
                <span className="label">size</span>
                <span className="val">18.4 MB</span>
              </div>
              <div className="stat">
                <span className="label">flutter</span>
                <span className="val">3.24.5</span>
              </div>
            </div>
          )}
        </div>

        {/* CONFIG */}
        <div className="config">
          <Field label="Entry">
            <Select value={entry} onChange={setEntry} options={proj.entry} />
          </Field>
          <Field label="Flavor">
            <Select value={flavor} onChange={setFlavor} options={proj.flavor} />
          </Field>
          <Field label="Device">
            <Select value={device} onChange={setDevice} options={proj.device} />
          </Field>
          <div className="toggle-row">
            <div
              className={"switch" + (clean ? " on" : "")}
              onClick={() => setClean(c => !c)}
              role="switch"
              aria-checked={clean}
            ></div>
            <span className="toggle-label">Clean before build</span>
          </div>
        </div>

        {/* ACTIONS */}
        <div className="actions">
          <div className="actions-grid">
            <button
              className={"btn primary" + (running === "run" ? " running" : "")}
              onClick={() => runAction("run")}
            >
              <span className="play"></span> Run
              <span className="kbd">⌘R</span>
            </button>
            <button
              className={"btn" + (running === "cleanPub" ? " running" : "")}
              onClick={() => runAction("cleanPub")}
            >
              <i className="ti ti-sparkles"></i> Clean + Pub
            </button>
            <button
              className={"btn" + (running === "runner" ? " running" : "")}
              onClick={() => runAction("runner")}
            >
              <i className="ti ti-settings-cog"></i> build_runner
            </button>
            <span className="btn-sep"></span>
            <button
              className={"btn" + (running === "apk" ? " running" : "")}
              onClick={() => runAction("apk")}
            >
              <i className="ti ti-package"></i> APK
            </button>
            <button
              className={"btn" + (running === "aab" ? " running" : "")}
              onClick={() => runAction("aab")}
            >
              <i className="ti ti-brand-android"></i> AAB
            </button>
            <button
              className={"btn" + (running === "ipa" ? " running" : "")}
              onClick={() => runAction("ipa")}
            >
              <i className="ti ti-brand-apple"></i> IPA
            </button>
          </div>

          <div className="custom-block">
            <div className="lbl" style={{ display:"flex", alignItems:"center", gap:8 }}>
              <span>release scripts</span>
              <span className="dim" style={{ fontFamily:"var(--mono)", fontSize:10, color:"var(--dim)", textTransform:"none", letterSpacing:0 }}>
                {proj.scripts.length} detected in <span style={{color:"var(--muted)"}}>./scripts</span>
              </span>
            </div>
            <div className="scripts">
              {proj.scripts.map((s, i) => (
                <button
                  key={i}
                  className={"script-card" + (running === "script:" + s.name ? " running" : "")}
                  onClick={() => runScript(s)}
                >
                  <span className="script-icon"><i className="ti ti-terminal-2"></i></span>
                  <span className="script-meta">
                    <span className="script-name">{s.name}</span>
                    <span className="script-desc">{s.desc}</span>
                  </span>
                  <span className="script-run"><i className="ti ti-player-play-filled"></i></span>
                </button>
              ))}
              <button className="script-card add" onClick={() => alert('Pick a .sh file from the project')}>
                <span className="script-icon dashed"><i className="ti ti-plus"></i></span>
                <span className="script-meta">
                  <span className="script-name dim">Add script</span>
                  <span className="script-desc">browse .sh files…</span>
                </span>
              </button>
            </div>
          </div>

          <div className="custom-block">
            <div className="lbl">custom commands</div>
            <div className="chips">
              {customs.map((c, i) => (
                <button key={i} className="chip" onClick={() => runCustom(c.cmd)}>
                  <i className={"ti " + c.icon}></i> {c.cmd}
                </button>
              ))}
              <button className="chip add" onClick={addCustom}>
                <i className="ti ti-plus"></i> Add
              </button>
            </div>
          </div>
        </div>

        {/* LOG */}
        <div className="log-area">
          <div className="log-bar">
            <div className="log-tabs">
              <button
                className={"log-tab" + (activeTab === "output" ? " active" : "")}
                onClick={() => setActiveTab("output")}
              >Output <span className="ct">{logLines.length}</span></button>
              <button
                className={"log-tab" + (activeTab === "problems" ? " active" : "")}
                onClick={() => setActiveTab("problems")}
              >Problems <span className="ct">0</span></button>
              <button
                className={"log-tab" + (activeTab === "history" ? " active" : "")}
                onClick={() => setActiveTab("history")}
              >History <span className="ct">12</span></button>
            </div>

            <div className="log-status">
              {running ? (
                <>
                  <span style={{ width:14, height:14, borderRadius:"50%", border:"1.5px solid var(--accent)", borderTopColor:"transparent", animation:"spin .9s linear infinite", display:"inline-block" }}></span>
                  Running <span className="dim">·</span> {ACTION_NAMES[running] || "custom"}
                </>
              ) : (
                <>
                  <span className="tick">✓</span>
                  {lastResult.name}{lastResult.flavor && ` (${lastResult.flavor})`}
                  <span className="dim">· {lastResult.time}s</span>
                </>
              )}
            </div>

            <div className="log-tools">
              <button className="icon-btn" title="Filter"><i className="ti ti-filter"></i></button>
              <button className="icon-btn" title="Search"><i className="ti ti-search"></i></button>
              <button className="icon-btn" title="Save log"><i className="ti ti-device-floppy"></i></button>
              <button className="icon-btn" title="Clear" onClick={clearLog}><i className="ti ti-eraser"></i></button>
            </div>
          </div>

          <div className={"progress" + (running ? "" : " idle")}>
            <div className="bar"></div>
          </div>

          <div className="log-body" ref={logRef}>
            {activeTab === "output" && logLines.map((l, i) => (
              <LogLine key={i} line={l} idx={i + 1} showLine={tweaks.showLineNumbers} />
            ))}
            {activeTab === "output" && running && (
              <div className="log-line">
                <span className="gutter">{tweaks.showLineNumbers ? logLines.length + 1 : ""}</span>
                <span className="glyph dim">·</span>
                <span className="body"><span className="cursor-blink"></span></span>
              </div>
            )}
            {activeTab === "problems" && (
              <div className="log-line">
                <span className="gutter"></span>
                <span className="body"><span className="dim">No problems found. Last analyze: 2 minutes ago.</span></span>
              </div>
            )}
            {activeTab === "history" && (
              <HistoryView />
            )}
          </div>
        </div>
      </main>

      {/* TWEAKS */}
      <TweaksUI tweaks={tweaks} setTweak={setTweak} />

      <style>{`
        @keyframes spin{to{transform:rotate(360deg);}}
      `}</style>
    </div>
  );
}

// ---------- SUBCOMPONENTS ----------
function Field({ label, children }) {
  return (
    <div className="field">
      <span className="lbl">{label}</span>
      {children}
    </div>
  );
}

function Select({ value, onChange, options }) {
  return (
    <div className="select-wrap">
      <select value={value} onChange={e => onChange(e.target.value)}>
        {options.map(o => <option key={o} value={o}>{o}</option>)}
      </select>
    </div>
  );
}

function LogLine({ line, idx, showLine }) {
  if (line.kind === "section") {
    return (
      <div className="log-line section">
        <span className="gutter"></span>
        <span className="glyph"></span>
        <span className="body">— {line.text} —</span>
      </div>
    );
  }
  if (line.kind === "pkg") {
    return (
      <div className="log-line">
        <span className="gutter">{showLine ? idx : ""}</span>
        <span className="glyph dim">↑</span>
        <span className="body">
          <span className="pkg">{line.pkg}</span>{" "}
          <span className="ver">{line.ver}</span>{" "}
          <span className="avail">→ {line.avail}</span>
        </span>
      </div>
    );
  }
  const glyph = {
    ok: "✓",
    info: "→",
    warn: "!",
    err: "✗",
    dim: "·",
  }[line.kind] || " ";
  return (
    <div className="log-line">
      <span className="gutter">{showLine ? idx : ""}</span>
      <span className={"glyph " + line.kind}>{glyph}</span>
      <span className="body" dangerouslySetInnerHTML={{ __html: line.text }} />
    </div>
  );
}

function HistoryView() {
  const items = [
    { name: "Build APK",   flavor: "nightly",    time: "just now",  duration: "3.2s", ok: true },
    { name: "Run",         flavor: "nightly",    time: "12m ago",   duration: "5.1s", ok: true },
    { name: "build_runner",flavor: "—",          time: "1h ago",    duration: "2.1s", ok: true },
    { name: "Build IPA",   flavor: "production", time: "3h ago",    duration: "47s",  ok: false },
    { name: "Clean + Pub", flavor: "—",          time: "yesterday", duration: "11s",  ok: true },
  ];
  return (
    <div style={{ display:"flex", flexDirection:"column", gap:0 }}>
      {items.map((it, i) => (
        <div key={i} className="log-line" style={{ padding:"6px 0", borderBottom: i < items.length-1 ? "1px dashed var(--hairline)" : "none" }}>
          <span className="gutter"></span>
          <span className={"glyph " + (it.ok ? "ok" : "err")}>{it.ok ? "✓" : "✗"}</span>
          <span className="body" style={{ display:"flex", gap:14, alignItems:"baseline" }}>
            <span style={{ fontWeight:600, minWidth:110 }}>{it.name}</span>
            <span className="dim" style={{ minWidth:90 }}>{it.flavor}</span>
            <span className="dim" style={{ minWidth:80 }}>{it.duration}</span>
            <span className="dim">{it.time}</span>
          </span>
        </div>
      ))}
    </div>
  );
}

// ---------- TWEAKS PANEL ----------
function TweaksUI({ tweaks, setTweak }) {
  if (!window.TweaksPanel) return null;
  const { TweaksPanel, TweakSection, TweakColor, TweakRadio, TweakSelect, TweakToggle } = window;
  return (
    <TweaksPanel title="Tweaks">
      <TweakSection title="Aesthetic">
        <TweakColor
          label="Accent"
          value={tweaks.accent}
          onChange={v => setTweak("accent", v)}
          options={["#C15F3C", "#7C4A2A", "#5C7A3F", "#3F5C7A", "#7A3F5C", "#1F1E1D"]}
        />
        <TweakRadio
          label="Heading"
          value={tweaks.headingStyle}
          onChange={v => setTweak("headingStyle", v)}
          options={[
            { value: "serif", label: "Serif" },
            { value: "sans",  label: "Sans" },
          ]}
        />
        <TweakSelect
          label="Log surface"
          value={tweaks.logBg}
          onChange={v => setTweak("logBg", v)}
          options={[
            { value: "warm",  label: "Warm paper" },
            { value: "white", label: "Pure white" },
            { value: "ink",   label: "Ink (dark)" },
          ]}
        />
      </TweakSection>

      <TweakSection title="Layout">
        <TweakRadio
          label="Density"
          value={tweaks.density}
          onChange={v => setTweak("density", v)}
          options={[
            { value: "compact",     label: "Compact" },
            { value: "comfortable", label: "Comfort" },
            { value: "spacious",    label: "Spacious" },
          ]}
        />
        <TweakToggle
          label="Show stats in header"
          value={tweaks.showHeadStats}
          onChange={v => setTweak("showHeadStats", v)}
        />
        <TweakToggle
          label="Log line numbers"
          value={tweaks.showLineNumbers}
          onChange={v => setTweak("showLineNumbers", v)}
        />
      </TweakSection>
    </TweaksPanel>
  );
}

// ---------- UTILS ----------
function hexA(hex, a) {
  const m = hex.replace("#","");
  const r = parseInt(m.slice(0,2),16), g = parseInt(m.slice(2,4),16), b = parseInt(m.slice(4,6),16);
  return `rgba(${r},${g},${b},${a})`;
}

// ---------- MOUNT ----------
ReactDOM.createRoot(document.getElementById("root")).render(<App />);
