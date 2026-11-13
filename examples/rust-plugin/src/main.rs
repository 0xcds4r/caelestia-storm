//! Example caelestia plugin.
//!
//! A plugin is a plain executable. The shell calls it with:
//!   `info`    -> JSON manifest
//!   `schemes` -> JSON array of colour schemes (seed colours are expanded to a full palette)
//!   `actions` -> JSON array of buttons shown on the plugin card
//!   `run <id>`-> run one of those actions (stdout is shown as a notification)
//!   `widget`  -> one-line bar widget, `{"icon": "...", "text": "..."}`
//!   `run click` is sent when the bar widget is clicked.
//!
//! Build with `cargo build --release` and drop the binary into
//! `~/.config/caelestia/plugins/` (or a directory with it named `plugin`).

use std::env;
use std::process::ExitCode;

const INFO: &str = r#"{
    "name": "Storm Palette Pack",
    "description": "Example plugin with seed-based colour schemes, an action and a bar widget",
    "version": "0.2.0",
    "capabilities": ["schemes", "actions", "widget"]
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
