//! Example caelestia plugin.
//!
//! A plugin is a plain executable. The shell calls it with:
//!   `info`    -> JSON manifest
//!   `schemes` -> JSON array of colour schemes (seed colours are expanded to a full palette)
//!
//! Build with `cargo build --release` and drop the binary into
//! `~/.config/caelestia/plugins/` (or a directory with it named `plugin`).

use std::env;
use std::process::ExitCode;

const INFO: &str = r#"{
    "name": "Storm Palette Pack",
    "description": "Example plugin with a few seed-based colour schemes",
    "version": "0.1.0",
    "capabilities": ["schemes"]
}"#;

const SCHEMES: &str = r##"[
    { "id": "sunset", "name": "Sunset", "seed": "#ff7a18", "mode": "dark", "variant": "tonalspot" },
    { "id": "mint", "name": "Mint", "seed": "#3ddc97", "mode": "dark", "variant": "vibrant" },
    { "id": "paper", "name": "Paper", "seed": "#c8a98b", "mode": "light", "variant": "neutral" }
]"##;

fn main() -> ExitCode {
    match env::args().nth(1).as_deref() {
        Some("info") => {
            println!("{INFO}");
            ExitCode::SUCCESS
        }
        Some("schemes") => {
            println!("{SCHEMES}");
            ExitCode::SUCCESS
        }
        Some(other) => {
            eprintln!("unknown command: {other}");
            eprintln!("usage: storm-palette-pack info|schemes");
            ExitCode::FAILURE
        }
        None => {
            eprintln!("usage: storm-palette-pack info|schemes");
            ExitCode::FAILURE
        }
    }
}
