# storm-plugin-api

Helpers for writing [Caelestia Storm](https://github.com/0xcds4r/caelestia-storm) plugins in Rust.
No dependencies: the JSON the shell expects, the window descriptors and the `key=value` state store
are all built here.

```toml
# Cargo.toml of your plugin
[dependencies]
storm-plugin-api = { path = "../api" }   # or vendor this crate next to your plugin
```

```rust
use storm_plugin_api as api;
use api::{Action, Capability, Effect, Event, Page, Plugin, Row, State, Widget};

fn main() {
    let plugin = Plugin::new("demo", env!("CARGO_PKG_VERSION"))
        .description("Demo plugin")
        .capabilities([Capability::Widget, Capability::Window, Capability::Effects]);

    match std::env::args().nth(1).as_deref() {
        Some("info") => println!("{}", plugin.info()),
        Some("widgets") => println!("{}", api::widgets(&[
            Widget::new("load").icon("speed").text("0.42"),
        ])),
        Some("effects") => println!("{}", api::effects(&[
            Effect::new("snow").num("density", 0.35).num("wind", 0.3),
        ])),
        Some("window") => println!("{}", api::Window::new("Demo")
            .size(520.0, 420.0)
            .pages(vec![Page::new("main", "Main").rows(vec![
                Row::Toggle { id: "enabled", label: "Enabled", subtext: "", value: true },
                api::slider("density", "Density", 0.0, 1.0, 0.35, Some(2)),
            ])])
            .json()),
        Some("event") => {
            let args: Vec<String> = std::env::args().skip(2).collect();
            if let Some(event) = Event::parse(&args) {
                let mut state = State::load("demo");
                state.set("enabled", event.value.as_bool());
                let _ = state.save();
            }
        }
        _ => {}
    }
}
```

## What is in here

| Item | Purpose |
|------|---------|
| `Plugin`, `Capability` | the `info` manifest (`schemes`, `actions`, `widget`, `window`, `desktop`, `effects`) |
| `Scheme`, `schemes()` | seed-based colour schemes |
| `Action`, `actions()` | buttons on the plugin card |
| `Widget`, `widgets()` | taskbar entries, polled every minute |
| `Desktop`, `desktop()` | cards on the wallpaper (text or a render-only web view) |
| `Effect`, `effects()` | animated background effects (`snow`) |
| `Window`, `Page`, `Row`, `slider()`, `choice()` | the window descriptor Nexus renders |
| `Event`, `EventValue` | parsing `event <control> <json>` |
| `State` | `key=value` store in `$XDG_STATE_HOME/<id>.conf` |
| `Fields`, `escape`, `string`, `number`, `array` | building arbitrary JSON by hand |

The protocol itself is documented in `plugins/pallete/README.md`; the shell side lives in
`services/Plugins.qml` and `modules/nexus/PluginWindow.qml`.
