//! StormSnow — a plugin that makes it snow on the desktop.
//!
//! The shell does the drawing (`modules/background/Snow.qml`); this executable only decides what
//! the snow looks like:
//!
//!   `info`         -> manifest (capabilities: effects, window, actions, widget)
//!   `effects`      -> `{"effects": [{"type": "snow", "density": ..., "wind": ...}]}`
//!   `window`       -> settings page with presets and sliders
//!   `event <id>`   -> a control changed, persist it
//!   `actions`      -> "Toggle snow"
//!   `run <action>` -> toggle / report

use storm_plugin_api as api;

use api::{Action, Bind, Capability, Effect, Event, EventValue, Page, Plugin, Row, State, choice};
use std::env;
use std::process::ExitCode;

const ID: &str = "storm-snow";
/// The plugin's own version; `api::VERSION` is the version of the helper crate.
const VERSION: &str = env!("CARGO_PKG_VERSION");

fn plugin() -> Plugin {
    Plugin::new("StormSnow", VERSION)
        .id(ID)
        .description("Snowfall on the desktop, with presets, wind and density")
        .capabilities([
            Capability::Effects,
            Capability::Window,
            Capability::Actions,
            Capability::Binds,
        ])
}

#[derive(Clone, Copy)]
struct Preset {
    id: &'static str,
    label: &'static str,
    density: f64,
    wind: f64,
    speed: f64,
    size: f64,
}

const PRESETS: [Preset; 3] = [
    Preset { id: "light", label: "Light", density: 0.18, wind: 0.15, speed: 0.75, size: 0.85 },
    Preset { id: "even", label: "Even", density: 0.35, wind: 0.30, speed: 1.00, size: 1.00 },
    Preset { id: "blizzard", label: "Blizzard", density: 0.75, wind: 0.85, speed: 1.60, size: 1.15 },
];

fn preset(id: &str) -> Option<Preset> {
    PRESETS.iter().copied().find(|preset| preset.id == id)
}

struct Settings {
    enabled: bool,
    overlay: bool,
    preset: String,
    density: f64,
    wind: f64,
    speed: f64,
    size: f64,
}

impl Settings {
    fn load() -> Self {
        let state = State::load(ID);
        let preset_id = state.text("preset", "even");
        let fallback = preset(&preset_id).unwrap_or(PRESETS[1]);

        Self {
            enabled: state.bool("enabled", true),
            overlay: state.bool("overlay", false),
            preset: preset_id,
            density: state.number("density", fallback.density),
            wind: state.number("wind", fallback.wind),
            speed: state.number("speed", fallback.speed),
            size: state.number("size", fallback.size),
        }
    }

    fn save(&self) {
        let mut state = State::load(ID);
        state.set("enabled", self.enabled);
        state.set("overlay", self.overlay);
        state.set("preset", &self.preset);
        state.set("density", self.density);
        state.set("wind", self.wind);
        state.set("speed", self.speed);
        state.set("size", self.size);
        let _ = state.save();
    }

    fn apply_preset(&mut self, id: &str) {
        if let Some(preset) = preset(id) {
            self.density = preset.density;
            self.wind = preset.wind;
            self.speed = preset.speed;
            self.size = preset.size;
        }

        self.preset = id.to_string();
    }
}

fn effects() -> String {
    let settings = Settings::load();

    if !settings.enabled {
        return api::effects(&[]);
    }

    api::effects(&[Effect::shader("snow", "shaders/snow.frag.qsb")
        .text("layer", if settings.overlay { "overlay" } else { "background" })
        .time_scale(settings.speed)
        .uniform("density", settings.density)
        .uniform("wind", settings.wind)
        .uniform("flakeSize", settings.size)
        .uniform("strength", 1.0)])
}

fn options() -> Vec<api::Choice<'static>> {
    let mut list: Vec<api::Choice<'static>> =
        PRESETS.iter().map(|preset| choice(preset.id, preset.label)).collect();

    list.push(choice("custom", "Custom"));
    list
}

fn window() -> String {
    let settings = Settings::load();
    let flakes = (settings.density * 2400.0).round() as i64;

    api::Window::new("StormSnow")
        .icon("ac_unit")
        .size(520.0, 560.0)
        .pages(vec![Page::new("snow", "Snowfall").rows(vec![
            Row::Section("Snowfall"),
            Row::Toggle {
                id: "enabled",
                label: "Snow on the desktop",
                subtext: "Falls behind the windows",
                value: settings.enabled,
            },
            Row::Toggle {
                id: "overlay",
                label: "Above the windows",
                subtext: "Draws over everything, including fullscreen",
                value: settings.overlay,
            },
            Row::Choice {
                id: "preset",
                label: "Preset",
                value: &settings.preset,
                options: &options(),
            },
            api::slider("density", "Density", 0.0, 1.0, settings.density, Some(2)),
            api::slider("wind", "Wind", -1.0, 1.0, settings.wind, Some(2)),
            api::slider("speed", "Fall speed", 0.3, 2.5, settings.speed, Some(1)),
            api::slider("size", "Flake size", 0.4, 2.0, settings.size, Some(2)),
            Row::Section("Now"),
            Row::Info {
                label: "Flakes in the air",
                subtext: "approximate",
                value: &flakes.to_string(),
            },
            Row::Text("Presets overwrite the sliders; moving a slider switches the preset to Custom."),
        ])])
        .json()
}

fn run(action: &str, target: Option<&str>) -> i32 {
    let mut settings = Settings::load();

    match action {
        "toggle" => {
            settings.enabled = !settings.enabled;
            settings.save();
            println!("Snow {}", if settings.enabled { "on" } else { "off" });
        }
        "bind" => match target {
            Some("toggle") | None => {
                settings.enabled = !settings.enabled;
                settings.save();
                println!("Snow {}", if settings.enabled { "on" } else { "off" });
            }
            Some(other) => {
                eprintln!("unknown bind: {other}");
                return 1;
            }
        },
        "status" => println!(
            "Snow {} · {} · density {:.2} · wind {:.2}",
            if settings.enabled { "on" } else { "off" },
            if settings.overlay { "overlay" } else { "background" },
            settings.density,
            settings.wind
        ),
        "reset" => {
            let mut state = State::load(ID);
            state.set("enabled", true);
            state.set("overlay", false);
            state.set("preset", "even");
            state.set("density", PRESETS[1].density);
            state.set("wind", PRESETS[1].wind);
            state.set("speed", PRESETS[1].speed);
            state.set("size", PRESETS[1].size);
            let _ = state.save();
            println!("Snow reset to Even");
        }
        _ => {
            eprintln!("unknown action: {action}");
            return 1;
        }
    }

    0
}

fn apply_event(control: &str, value: &EventValue) -> bool {
    let mut settings = Settings::load();

    match control {
        "enabled" => settings.enabled = value.as_bool(),
        "overlay" => settings.overlay = value.as_bool(),
        "preset" => settings.apply_preset(&value.as_text()),
        "density" => {
            settings.density = value.as_f64().clamp(0.0, 1.0);
            settings.preset = "custom".to_string();
        }
        "wind" => {
            settings.wind = value.as_f64().clamp(-1.0, 1.0);
            settings.preset = "custom".to_string();
        }
        "speed" => {
            settings.speed = value.as_f64().clamp(0.3, 2.5);
            settings.preset = "custom".to_string();
        }
        "size" => {
            settings.size = value.as_f64().clamp(0.4, 2.0);
            settings.preset = "custom".to_string();
        }
        "reset" => {
            settings.apply_preset("even");
            settings.enabled = true;
        }
        _ => return false,
    }

    settings.save();
    true
}

fn binds() -> String {
    api::binds(&[Bind::new("toggle", "CTRL + SUPER + SHIFT + S").description("Toggle snow")])
}

fn actions() -> String {
    api::actions(&[Action::new("toggle", "Toggle snow"), Action::new("reset", "Reset settings")])
}

fn main() -> ExitCode {
    let mut args = env::args().skip(1);
    let command = args.next().unwrap_or_default();

    let output = match command.as_str() {
        "info" => plugin().info(),
        "schemes" => api::schemes(&[]),
        "actions" => actions(),
        "binds" => binds(),
        "effects" => effects(),
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
            eprintln!("usage: {ID} info|effects|window|actions|binds|event|run");
            return ExitCode::FAILURE;
        }
    };

    println!("{output}");
    ExitCode::SUCCESS
}
