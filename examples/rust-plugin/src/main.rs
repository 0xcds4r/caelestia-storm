//! Example caelestia plugin built on `api.rs`.
//!
//! The shell calls the executable with:
//!   `info`               -> JSON manifest
//!   `schemes`            -> seed-based colour schemes
//!   `actions`            -> buttons shown on the plugin card
//!   `run <action>`       -> run an action (stdout becomes a notification)
//!   `widgets`            -> taskbar widgets, polled every minute
//!   `run click <id>`     -> a taskbar widget was clicked
//!   `window`             -> window descriptor rendered by the shell
//!   `event <id> <json>`  -> a control in that window changed
//!   `desktop`            -> cards drawn on the desktop

mod api;

use api::{Action, Capability, Desktop, Event, EventValue, Page, Plugin, Row, Scheme, State, Widget, choice};
use std::env;
use std::process::ExitCode;

const ID: &str = "storm-palette-pack";

fn plugin() -> Plugin {
    Plugin::new("Storm Palette Pack", api::VERSION)
        .id(ID)
        .description("Example plugin: colour schemes, actions, widgets and a window")
        .capabilities([
            Capability::Schemes,
            Capability::Actions,
            Capability::Widget,
            Capability::Window,
            Capability::Desktop,
        ])
}

fn load_average() -> String {
    std::fs::read_to_string("/proc/loadavg")
        .ok()
        .and_then(|text| text.split_whitespace().next().map(str::to_string))
        .unwrap_or_else(|| "?".to_string())
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

fn schemes() -> String {
    api::schemes(&[
        Scheme::new("sunset", "Sunset", "#ff7a18"),
        Scheme::new("mint", "Mint", "#3ddc97").variant("vibrant"),
        Scheme::new("paper", "Paper", "#c8a98b").mode("light").variant("neutral"),
    ])
}

fn actions() -> String {
    api::actions(&[Action::new("about", "About"), Action::new("reload", "Reload schemes")])
}

fn widgets() -> String {
    let load = load_average();
    let memory = format!("{}%", memory_percent());

    api::widgets(&[
        Widget::new("load").icon("speed").text(&load).tooltip("1 minute load average"),
        Widget::new("mem").icon("memory").text(&memory).tooltip("Memory in use"),
    ])
}

fn desktop() -> String {
    let load = load_average();
    let memory = format!("{}%", memory_percent());

    api::desktop(&[
        Desktop::new("load", "Load average", &load)
            .anchor("top-left")
            .margin(64.0)
            .width(240.0)
            .icon("speed")
            .subtext("1 minute"),
        Desktop::new("mem", "Memory", &memory)
            .anchor("bottom-right")
            .margin(64.0)
            .width(240.0)
            .icon("memory")
            .subtext("in use"),
    ])
}

fn window() -> String {
    let state = State::load(ID);
    let announce = state.bool("announce", true);
    let mode = state.text("mode", "auto");
    let strength = state.number("strength", 60.0);
    let state_file = api::state_dir().join(format!("{ID}.conf")).display().to_string();

    api::Window::new("Storm Palette Pack")
        .icon("palette")
        .size(560.0, 500.0)
        .pages(vec![
            Page::new("general", "General").rows(vec![
                Row::Section("Behaviour"),
                Row::Toggle {
                    id: "announce",
                    label: "Announce scheme changes",
                    subtext: "Show a desktop notification",
                    value: announce,
                },
                Row::Choice {
                    id: "mode",
                    label: "Accent source",
                    value: &mode,
                    options: &[choice("auto", "Auto"), choice("wallpaper", "Wallpaper"), choice("fixed", "Fixed")],
                },
                Row::Slider {
                    id: "strength",
                    label: "Accent strength",
                    min: Some(0.0),
                    max: Some(100.0),
                    value: strength,
                },
                Row::Section("Notes"),
                Row::Text("These settings live in the plugin's own state file — the shell only renders this window and forwards events."),
            ]),
            Page::new("web", "Web").rows(vec![
                Row::Section("Embedded page"),
                Row::Webview {
                    url: "https://example.com",
                    height: Some(300.0),
                },
            ]),
            Page::new("about", "About").rows(vec![
                Row::Info {
                    label: "Version",
                    subtext: "Example plugin",
                    value: api::VERSION,
                },
                Row::Info {
                    label: "State file",
                    subtext: "",
                    value: &state_file,
                },
                Row::Button {
                    id: "reset",
                    label: "Reset settings",
                    subtext: "Back to defaults",
                    icon: "restart_alt",
                },
            ]),
        ])
        .json()
}

fn apply_event(control: &str, value: &EventValue) -> bool {
    let mut state = State::load(ID);

    match control {
        "announce" => state.set("announce", value.as_bool()),
        "mode" => state.set("mode", value.as_text()),
        "strength" => state.set("strength", value.as_f64().round() as i64),
        "reset" => {
            state.set("announce", true);
            state.set("mode", "auto");
            state.set("strength", 60);
        }
        _ => return false,
    }

    let _ = state.save();
    true
}

fn run(action: &str, target: Option<&str>) -> i32 {
    match action {
        "about" => println!("{} {} - example caelestia plugin", "Storm Palette Pack", api::VERSION),
        "reload" => println!("Palette pack reloaded"),
        "click" => match target {
            Some("mem") => println!("Memory in use: {}%", memory_percent()),
            Some("load") | None => println!("Load average: {}", load_average()),
            Some(other) => println!("Unknown widget: {other}"),
        },
        _ => {
            eprintln!("unknown action: {action}");
            return 1;
        }
    }

    0
}

fn main() -> ExitCode {
    let mut args = env::args().skip(1);
    let command = args.next().unwrap_or_default();

    let output = match command.as_str() {
        "info" => plugin().info(),
        "schemes" => schemes(),
        "actions" => actions(),
        "widgets" => widgets(),
        "desktop" => desktop(),
        "window" => window(),
        "run" => {
            let action = args.next().unwrap_or_default();
            let target = args.next();
            let status = run(&action, target.as_deref());
            return if status == 0 { ExitCode::SUCCESS } else { ExitCode::FAILURE };
        }
        "event" => {
            let rest: Vec<String> = args.collect();
            let Some(event) = Event::parse(&rest) else {
                eprintln!("usage: event <control> <json>");
                return ExitCode::FAILURE;
            };

            if !apply_event(&event.control, &event.value) {
                eprintln!("unknown control: {}", event.control);
                return ExitCode::FAILURE;
            }

            return ExitCode::SUCCESS;
        }
        _ => {
            eprintln!("usage: {ID} info|schemes|actions|widgets|desktop|window|event|run");
            return ExitCode::FAILURE;
        }
    };

    println!("{output}");
    ExitCode::SUCCESS
}
