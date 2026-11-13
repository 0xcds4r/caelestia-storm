//! Example caelestia plugin.
//!
//! A plugin is a plain executable. The shell calls it with:
//!   `info`    -> JSON manifest
//!   `schemes` -> JSON array of colour schemes (seed colours are expanded to a full palette)
//!   `actions` -> JSON array of buttons shown on the plugin card
//!   `run <id>`-> run one of those actions (stdout is shown as a notification)
//!   `widget`  -> one-line bar widget, `{"icon": "...", "text": "..."}`
//!   `run click` is sent when the bar widget is clicked.
//!   `window`  -> JSON descriptor of a window the shell renders with its own settings widgets
//!   `event <id> <json>` -> a control in that window changed
//!
//! Build with `cargo build --release` and drop the binary into
//! `~/.config/caelestia/plugins/` (or a directory with it named `plugin`).

use std::env;
use std::process::ExitCode;

const INFO: &str = r#"{
    "name": "Storm Palette Pack",
    "description": "Example plugin with seed-based colour schemes, an action and a bar widget",
    "version": "0.3.0",
    "capabilities": ["schemes", "actions", "widget", "window"]
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
        Some("widget") => {
            println!(
                r#"{{ "icon": "speed", "text": "{}", "tooltip": "1 minute load average" }}"#,
                load_average()
            );
            ExitCode::SUCCESS
        }
        Some("run") => match args.next().as_deref() {
            Some("about") => {
                println!("Storm Palette Pack 0.2.0 - example caelestia plugin");
                ExitCode::SUCCESS
            }
            Some("reload") => {
                println!("Palette pack reloaded");
                ExitCode::SUCCESS
            }
            Some("click") => {
                println!("Load average: {}", load_average());
                ExitCode::SUCCESS
            }
            other => {
                eprintln!("unknown action: {other:?}");
                ExitCode::FAILURE
            }
        },
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
