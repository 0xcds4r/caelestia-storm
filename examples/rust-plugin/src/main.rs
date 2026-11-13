//! Example caelestia plugin.
//!
//! A plugin is a plain executable. The shell calls it with:
//!   `info`    -> JSON manifest
//!   `schemes` -> JSON array of colour schemes (seed colours are expanded to a full palette)
//!   `actions` -> JSON array of buttons shown on the plugin card
//!   `run <id>`-> run one of those actions (stdout is shown as a notification)
//!   `widgets` -> bar widgets, `[{"id": "load", "icon": "...", "text": "..."}]`
//!   `run click <widget id>` is sent when one of them is clicked.
//!   `window`  -> JSON descriptor of a window the shell renders with its own settings widgets
//!   `event <id> <json>` -> a control in that window changed
//!   `desktop` -> JSON descriptor of widgets drawn on the desktop (wallpaper)
//!
//! Build with `cargo build --release` and drop the binary into
//! `~/.config/caelestia/plugins/` (or a directory with it named `plugin`).

use std::env;
use std::process::ExitCode;

const INFO: &str = r#"{
    "name": "Storm Palette Pack",
    "description": "Example plugin with seed-based colour schemes, an action and a bar widget",
    "version": "0.5.0",
    "capabilities": ["schemes", "actions", "widget", "window", "desktop"]
}"#;

const ACTIONS: &str = r#"[
    { "id": "about", "name": "About" },
    { "id": "reload", "name": "Reload schemes" }
]"#;

const SCHEMES: &str = r##"[
    { "id": "sunset", "name": "Sunset", "seed": "#ff7a18", "mode": "dark", "variant": "tonalspot" },
    { "id": "mint", "name": "Mint", "seed": "#3ddc97", "mode": "dark", "variant": "vibrant" },
    { "id": "paper", "name": "Paper", "seed": "#c8a98b", "mode": "light", "variant": "neutral" }
]"##;

#[derive(Clone)]
struct State {
    announce: bool,
    mode: String,
    strength: u32,
}

impl Default for State {
    fn default() -> Self {
        Self {
            announce: true,
            mode: "auto".to_string(),
            strength: 60,
        }
    }
}

fn state_path() -> std::path::PathBuf {
    let base = env::var("XDG_STATE_HOME")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| {
            std::path::PathBuf::from(env::var("HOME").unwrap_or_else(|_| ".".into()))
                .join(".local/state")
        });
    base.join("storm-palette-pack.conf")
}

impl State {
    fn load() -> Self {
        let mut state = State::default();
        if let Ok(text) = std::fs::read_to_string(state_path()) {
            for line in text.lines() {
                let Some((key, value)) = line.split_once('=') else {
                    continue;
                };
                match key.trim() {
                    "announce" => state.announce = value.trim() == "true",
                    "mode" => state.mode = value.trim().to_string(),
                    "strength" => state.strength = value.trim().parse().unwrap_or(60),
                    _ => {}
                }
            }
        }
        state
    }

    fn save(&self) {
        let path = state_path();
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let _ = std::fs::write(
            path,
            format!(
                "announce={}\nmode={}\nstrength={}\n",
                self.announce, self.mode, self.strength
            ),
        );
    }
}

fn memory_percent() -> u32 {
    let read = |key: &str| -> Option<u32> {
        std::fs::read_to_string("/proc/meminfo")
            .ok()?
            .lines()
            .find(|line| line.starts_with(key))?
            .split_whitespace()
            .nth(1)?
            .parse()
            .ok()
    };

    let total = read("MemTotal:").unwrap_or(0);
    let available = read("MemAvailable:").unwrap_or(0);
    if total == 0 {
        return 0;
    }

    (((total - available) as f32 / total as f32) * 100.0).round() as u32
}

fn widgets() -> String {
    format!(
        r#"[{{ "id": "load", "icon": "speed", "text": "{}", "tooltip": "1 minute load average" }}, {{ "id": "mem", "icon": "memory", "text": "{}%", "tooltip": "Memory in use" }}]"#,
        load_average(),
        memory_percent()
    )
}

fn desktop_descriptor() -> String {
    format!(
        r#"{{ "widgets": [
    {{ "id": "load", "anchor": "top-left", "margin": 64, "width": 240, "icon": "speed", "title": "Load average", "text": "{}", "subtext": "1 minute" }},
    {{ "id": "mem", "anchor": "bottom-right", "margin": 64, "width": 240, "icon": "memory", "title": "Memory", "text": "{}%", "subtext": "in use" }}
] }}"#,
        load_average(),
        memory_percent()
    )
}

fn window_descriptor() -> String {
    let state = State::load();
    let state_file = state_path().display().to_string();
    format!(
        r##"{{
  "title": "Storm Palette Pack",
  "icon": "palette",
  "width": 560,
  "height": 500,
  "pages": [
    {{
      "id": "general",
      "label": "General",
      "sections": [
        {{ "type": "section", "text": "Behaviour" }},
        {{ "type": "toggle", "id": "announce", "label": "Announce scheme changes", "subtext": "Show a desktop notification", "value": {} }},
        {{ "type": "choice", "id": "mode", "label": "Accent source", "value": "{}", "options": [
            {{ "value": "auto", "text": "Auto" }},
            {{ "value": "wallpaper", "text": "Wallpaper" }},
            {{ "value": "fixed", "text": "Fixed" }}
        ] }},
        {{ "type": "slider", "id": "strength", "label": "Accent strength", "min": 0, "max": 100, "value": {} }},
        {{ "type": "section", "text": "Notes" }},
        {{ "type": "text", "text": "These settings live in the plugin's own state file - the shell only renders this window and forwards events." }}
      ]
    }},
    {{
      "id": "about",
      "label": "About",
      "sections": [
        {{ "type": "info", "label": "Version", "subtext": "Example plugin", "value": "0.3.0" }},
        {{ "type": "info", "label": "State file", "value": "{}" }},
        {{ "type": "button", "id": "reset", "label": "Reset settings", "subtext": "Back to defaults", "icon": "restart_alt" }}
      ]
    }}
  ]
}}"##,
        state.announce, state.mode, state.strength, state_file
    )
}

fn apply_event(control: &str, raw: &str) -> bool {
    let mut state = State::load();
    let value = raw.trim().trim_matches('"');

    match control {
        "announce" => state.announce = value == "true",
        "mode" => state.mode = value.to_string(),
        "strength" => state.strength = value.parse().unwrap_or(state.strength),
        "reset" => state = State::default(),
        _ => return false,
    }

    state.save();
    true
}

fn load_average() -> String {
    std::fs::read_to_string("/proc/loadavg")
        .ok()
        .and_then(|text| text.split_whitespace().next().map(str::to_string))
        .unwrap_or_else(|| "?".to_string())
}

fn main() -> ExitCode {
    let mut args = env::args().skip(1);

    match args.next().as_deref() {
        Some("info") => {
            println!("{INFO}");
            ExitCode::SUCCESS
        }
        Some("schemes") => {
            println!("{SCHEMES}");
            ExitCode::SUCCESS
        }
        Some("actions") => {
            println!("{ACTIONS}");
            ExitCode::SUCCESS
        }
        Some("window") => {
            println!("{}", window_descriptor());
            ExitCode::SUCCESS
        }
        Some("event") => {
            let control = args.next().unwrap_or_default();
            let value = args.next().unwrap_or_default();
            if apply_event(&control, &value) {
                ExitCode::SUCCESS
            } else {
                eprintln!("unknown control: {control}");
                ExitCode::FAILURE
            }
        }
        Some("desktop") => {
            println!("{}", desktop_descriptor());
            ExitCode::SUCCESS
        }
        Some("widgets") => {
            println!("{}", widgets());
            ExitCode::SUCCESS
        }
        Some("run") => {
            let action = args.next();
            let target = args.next();

            match action.as_deref() {
                Some("about") => {
                    println!("Storm Palette Pack 0.4.0 - example caelestia plugin");
                    ExitCode::SUCCESS
                }
                Some("reload") => {
                    println!("Palette pack reloaded");
                    ExitCode::SUCCESS
                }
                Some("click") => {
                    if target.as_deref() == Some("mem") {
                        println!("Memory in use: {}%", memory_percent());
                    } else {
                        println!("Load average: {}", load_average());
                    }
                    ExitCode::SUCCESS
                }
                other => {
                    eprintln!("unknown action: {other:?}");
                    ExitCode::FAILURE
                }
            }
        }
        Some(other) => {
            eprintln!("unknown command: {other}");
            ExitCode::FAILURE
        }
        None => {
            eprintln!("usage: storm-palette-pack info|schemes|actions|widget|run <action>");
            ExitCode::FAILURE
        }
    }
}
