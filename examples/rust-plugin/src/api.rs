#![allow(dead_code)]

//! Small helper library for writing caelestia plugins in Rust.
//!
//! No dependencies: everything the shell expects (JSON on stdout, `key=value` state files) is built
//! here, so a plugin is usually just `match` on the command plus a few builders from this module.
//!
//! ```no_run
//! use crate::api::{Action, Capability, Event, Fields, Plugin, State, Widget};
//!
//! fn main() {
//!     let plugin = Plugin::new("demo", "0.1.0")
//!         .description("Demo plugin")
//!         .capabilities([Capability::Widget, Capability::Window]);
//!
//!     match std::env::args().nth(1).as_deref() {
//!         Some("info") => println!("{}", plugin.info()),
//!         Some("widgets") => println!("{}", api::widgets(&[Widget::new("load").icon("speed").text("0.4")])),
//!         _ => {}
//!     }
//! }
//! ```

use std::collections::BTreeMap;
use std::path::PathBuf;

/// Version of the plugin crate (set by cargo).
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

// --- JSON output ------------------------------------------------------------------------------

/// Escapes a string for embedding in JSON.
pub fn escape(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

/// A JSON string literal.
pub fn string(value: &str) -> String {
    format!("\"{}\"", escape(value))
}

/// A JSON number (integers are printed without a fractional part).
pub fn number(value: f64) -> String {
    if value.fract() == 0.0 {
        format!("{}", value as i64)
    } else {
        format!("{value}")
    }
}

/// Builds a JSON object, skipping empty strings and unset options.
#[derive(Default)]
pub struct Fields(Vec<String>);

impl Fields {
    pub fn new() -> Self {
        Self::default()
    }

    /// Adds a string field; empty values are omitted.
    pub fn text(mut self, key: &str, value: &str) -> Self {
        if !value.is_empty() {
            self.0.push(format!("{}: {}", string(key), string(value)));
        }
        self
    }

    /// Adds a string field; `None` is omitted.
    pub fn opt_text(self, key: &str, value: Option<&str>) -> Self {
        match value {
            Some(value) => self.text(key, value),
            None => self,
        }
    }

    /// Adds a number field.
    pub fn num(mut self, key: &str, value: f64) -> Self {
        self.0.push(format!("{}: {}", string(key), number(value)));
        self
    }

    /// Adds an optional number field.
    pub fn opt_num(self, key: &str, value: Option<f64>) -> Self {
        match value {
            Some(value) => self.num(key, value),
            None => self,
        }
    }

    /// Adds a boolean field.
    pub fn bool(mut self, key: &str, value: bool) -> Self {
        self.0.push(format!("{}: {}", string(key), value));
        self
    }

    /// Adds a pre-rendered JSON value.
    pub fn raw(mut self, key: &str, value: String) -> Self {
        self.0.push(format!("{}: {}", string(key), value));
        self
    }

    pub fn build(self) -> String {
        format!("{{ {} }}", self.0.join(", "))
    }
}

/// Renders a JSON array from pre-rendered values.
pub fn array(items: &[String]) -> String {
    format!("[{}]", items.join(", "))
}

// --- Manifest ---------------------------------------------------------------------------------

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Capability {
    Schemes,
    Actions,
    Widget,
    Window,
    Desktop,
}

impl Capability {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Schemes => "schemes",
            Self::Actions => "actions",
            Self::Widget => "widget",
            Self::Window => "window",
            Self::Desktop => "desktop",
        }
    }
}

/// `info` output.
pub struct Plugin {
    id: String,
    name: String,
    description: String,
    version: String,
    capabilities: Vec<Capability>,
}

impl Plugin {
    pub fn new(name: &str, version: &str) -> Self {
        Self {
            id: name.to_string(),
            name: name.to_string(),
            description: String::new(),
            version: version.to_string(),
            capabilities: Vec::new(),
        }
    }

    pub fn id(mut self, id: &str) -> Self {
        self.id = id.to_string();
        self
    }

    pub fn description(mut self, description: &str) -> Self {
        self.description = description.to_string();
        self
    }

    pub fn capabilities(mut self, capabilities: impl IntoIterator<Item = Capability>) -> Self {
        self.capabilities = capabilities.into_iter().collect();
        self
    }

    pub fn info(&self) -> String {
        let capabilities: Vec<String> = self.capabilities.iter().map(|c| string(c.as_str())).collect();
        Fields::new()
            .text("name", &self.name)
            .text("description", &self.description)
            .text("version", &self.version)
            .raw("capabilities", array(&capabilities))
            .build()
    }

    /// True if the plugin declared this capability.
    pub fn has(&self, capability: Capability) -> bool {
        self.capabilities.contains(&capability)
    }
}

// --- Schemes / actions ------------------------------------------------------------------------

pub struct Scheme<'a> {
    pub id: &'a str,
    pub name: &'a str,
    pub seed: &'a str,
    pub mode: Option<&'a str>,
    pub variant: Option<&'a str>,
}

impl<'a> Scheme<'a> {
    pub fn new(id: &'a str, name: &'a str, seed: &'a str) -> Self {
        Self {
            id,
            name,
            seed,
            mode: None,
            variant: None,
        }
    }

    pub fn mode(mut self, mode: &'a str) -> Self {
        self.mode = Some(mode);
        self
    }

    pub fn variant(mut self, variant: &'a str) -> Self {
        self.variant = Some(variant);
        self
    }

    pub fn json(&self) -> String {
        Fields::new()
            .text("id", self.id)
            .text("name", self.name)
            .text("seed", self.seed)
            .opt_text("mode", self.mode)
            .opt_text("variant", self.variant)
            .build()
    }
}

pub fn schemes(schemes: &[Scheme<'_>]) -> String {
    array(&schemes.iter().map(|scheme| scheme.json()).collect::<Vec<_>>())
}

pub struct Action<'a> {
    pub id: &'a str,
    pub name: &'a str,
}

impl<'a> Action<'a> {
    pub fn new(id: &'a str, name: &'a str) -> Self {
        Self { id, name }
    }

    pub fn json(&self) -> String {
        Fields::new().text("id", self.id).text("name", self.name).build()
    }
}

pub fn actions(actions: &[Action<'_>]) -> String {
    array(&actions.iter().map(|action| action.json()).collect::<Vec<_>>())
}

// --- Bar widgets ------------------------------------------------------------------------------

#[derive(Default)]
pub struct Widget<'a> {
    pub id: &'a str,
    pub icon: &'a str,
    pub text: &'a str,
    pub tooltip: &'a str,
}

impl<'a> Widget<'a> {
    pub fn new(id: &'a str) -> Self {
        Self {
            id,
            ..Self::default()
        }
    }

    pub fn icon(mut self, icon: &'a str) -> Self {
        self.icon = icon;
        self
    }

    pub fn text(mut self, text: &'a str) -> Self {
        self.text = text;
        self
    }

    pub fn tooltip(mut self, tooltip: &'a str) -> Self {
        self.tooltip = tooltip;
        self
    }

    pub fn json(&self) -> String {
        Fields::new()
            .text("id", self.id)
            .text("icon", self.icon)
            .text("text", self.text)
            .text("tooltip", self.tooltip)
            .build()
    }
}

pub fn widgets(widgets: &[Widget<'_>]) -> String {
    array(&widgets.iter().map(|widget| widget.json()).collect::<Vec<_>>())
}

// --- Desktop widgets --------------------------------------------------------------------------

pub struct Desktop<'a> {
    pub id: &'a str,
    pub anchor: &'a str,
    pub margin: Option<f64>,
    pub width: Option<f64>,
    pub icon: &'a str,
    pub title: &'a str,
    pub text: &'a str,
    pub subtext: &'a str,
}

impl<'a> Desktop<'a> {
    pub fn new(id: &'a str, title: &'a str, text: &'a str) -> Self {
        Self {
            id,
            anchor: "top-left",
            margin: None,
            width: None,
            icon: "",
            title,
            text,
            subtext: "",
        }
    }

    pub fn anchor(mut self, anchor: &'a str) -> Self {
        self.anchor = anchor;
        self
    }

    pub fn margin(mut self, margin: f64) -> Self {
        self.margin = Some(margin);
        self
    }

    pub fn width(mut self, width: f64) -> Self {
        self.width = Some(width);
        self
    }

    pub fn icon(mut self, icon: &'a str) -> Self {
        self.icon = icon;
        self
    }

    pub fn subtext(mut self, subtext: &'a str) -> Self {
        self.subtext = subtext;
        self
    }

    pub fn json(&self) -> String {
        Fields::new()
            .text("id", self.id)
            .text("anchor", self.anchor)
            .opt_num("margin", self.margin)
            .opt_num("width", self.width)
            .text("icon", self.icon)
            .text("title", self.title)
            .text("text", self.text)
            .text("subtext", self.subtext)
            .build()
    }
}

pub fn desktop(widgets: &[Desktop<'_>]) -> String {
    Fields::new()
        .raw("widgets", array(&widgets.iter().map(|widget| widget.json()).collect::<Vec<_>>()))
        .build()
}

// --- Windows ----------------------------------------------------------------------------------

pub struct Choice<'a> {
    pub value: &'a str,
    pub text: &'a str,
}

pub fn choice<'a>(value: &'a str, text: &'a str) -> Choice<'a> {
    Choice { value, text }
}

/// One control row in a plugin window.
pub enum Row<'a> {
    Section(&'a str),
    Text(&'a str),
    Info {
        label: &'a str,
        subtext: &'a str,
        value: &'a str,
    },
    Toggle {
        id: &'a str,
        label: &'a str,
        subtext: &'a str,
        value: bool,
    },
    Button {
        id: &'a str,
        label: &'a str,
        subtext: &'a str,
        icon: &'a str,
    },
    TextField {
        id: &'a str,
        label: &'a str,
        value: &'a str,
        placeholder: &'a str,
    },
    Slider {
        id: &'a str,
        label: &'a str,
        min: Option<f64>,
        max: Option<f64>,
        value: f64,
    },
    Choice {
        id: &'a str,
        label: &'a str,
        value: &'a str,
        options: &'a [Choice<'a>],
    },
}

impl Row<'_> {
    pub fn json(&self) -> String {
        match self {
            Row::Section(text) => Fields::new().text("type", "section").text("text", text).build(),
            Row::Text(text) => Fields::new().text("type", "text").text("text", text).build(),
            Row::Info { label, subtext, value } => Fields::new()
                .text("type", "info")
                .text("label", label)
                .text("subtext", subtext)
                .text("value", value)
                .build(),
            Row::Toggle { id, label, subtext, value } => Fields::new()
                .text("type", "toggle")
                .text("id", id)
                .text("label", label)
                .text("subtext", subtext)
                .bool("value", *value)
                .build(),
            Row::Button { id, label, subtext, icon } => Fields::new()
                .text("type", "button")
                .text("id", id)
                .text("label", label)
                .text("subtext", subtext)
                .text("icon", icon)
                .build(),
            Row::TextField { id, label, value, placeholder } => Fields::new()
                .text("type", "textfield")
                .text("id", id)
                .text("label", label)
                .text("value", value)
                .text("placeholder", placeholder)
                .build(),
            Row::Slider { id, label, min, max, value } => Fields::new()
                .text("type", "slider")
                .text("id", id)
                .text("label", label)
                .opt_num("min", *min)
                .opt_num("max", *max)
                .num("value", *value)
                .build(),
            Row::Choice { id, label, value, options } => Fields::new()
                .text("type", "choice")
                .text("id", id)
                .text("label", label)
                .text("value", value)
                .raw(
                    "options",
                    array(
                        &options
                            .iter()
                            .map(|option| Fields::new().text("value", option.value).text("text", option.text).build())
                            .collect::<Vec<_>>(),
                    ),
                )
                .build(),
        }
    }
}

pub struct Page<'a> {
    pub id: &'a str,
    pub label: &'a str,
    pub rows: Vec<Row<'a>>,
}

impl<'a> Page<'a> {
    pub fn new(id: &'a str, label: &'a str) -> Self {
        Self {
            id,
            label,
            rows: Vec::new(),
        }
    }

    pub fn rows(mut self, rows: Vec<Row<'a>>) -> Self {
        self.rows = rows;
        self
    }

    pub fn json(&self) -> String {
        Fields::new()
            .text("id", self.id)
            .text("label", self.label)
            .raw("sections", array(&self.rows.iter().map(|row| row.json()).collect::<Vec<_>>()))
            .build()
    }
}

pub struct Window<'a> {
    pub title: &'a str,
    pub icon: &'a str,
    pub width: Option<f64>,
    pub height: Option<f64>,
    pub pages: Vec<Page<'a>>,
}

impl<'a> Window<'a> {
    pub fn new(title: &'a str) -> Self {
        Self {
            title,
            icon: "",
            width: None,
            height: None,
            pages: Vec::new(),
        }
    }

    pub fn icon(mut self, icon: &'a str) -> Self {
        self.icon = icon;
        self
    }

    pub fn size(mut self, width: f64, height: f64) -> Self {
        self.width = Some(width);
        self.height = Some(height);
        self
    }

    pub fn pages(mut self, pages: Vec<Page<'a>>) -> Self {
        self.pages = pages;
        self
    }

    pub fn json(&self) -> String {
        Fields::new()
            .text("title", self.title)
            .text("icon", self.icon)
            .opt_num("width", self.width)
            .opt_num("height", self.height)
            .raw("pages", array(&self.pages.iter().map(|page| page.json()).collect::<Vec<_>>()))
            .build()
    }
}

// --- Events -----------------------------------------------------------------------------------

/// A control value sent by the shell as `plugin event <id> <json>`.
pub enum EventValue {
    Bool(bool),
    Number(f64),
    Text(String),
}

impl EventValue {
    pub fn as_bool(&self) -> bool {
        match self {
            Self::Bool(value) => *value,
            Self::Number(value) => *value != 0.0,
            Self::Text(value) => value == "true",
        }
    }

    pub fn as_f64(&self) -> f64 {
        match self {
            Self::Bool(value) => i32::from(*value) as f64,
            Self::Number(value) => *value,
            Self::Text(value) => value.parse().unwrap_or(0.0),
        }
    }

    pub fn as_text(&self) -> String {
        match self {
            Self::Bool(value) => value.to_string(),
            Self::Number(value) => number(*value),
            Self::Text(value) => value.clone(),
        }
    }
}

pub struct Event {
    pub control: String,
    pub value: EventValue,
}

impl Event {
    /// Parses `[control, json-value]` (the arguments after `event`). A missing value means `true`,
    /// so buttons can be handled like `event reset`.
    pub fn parse(args: &[String]) -> Option<Self> {
        let control = args.first()?.clone();
        let raw = args.get(1).map(|value| value.trim()).unwrap_or("true");

        let value = if raw == "true" || raw == "false" {
            EventValue::Bool(raw == "true")
        } else if let Ok(number) = raw.parse::<f64>() {
            EventValue::Number(number)
        } else {
            EventValue::Text(raw.trim_matches('"').to_string())
        };

        Some(Self { control, value })
    }
}

// --- State ------------------------------------------------------------------------------------

pub fn state_dir() -> PathBuf {
    std::env::var("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| ".".into())).join(".local/state")
        })
}

/// A tiny `key=value` store, one file per plugin.
pub struct State {
    path: PathBuf,
    values: BTreeMap<String, String>,
}

impl State {
    pub fn load(plugin_id: &str) -> Self {
        let path = state_dir().join(format!("{plugin_id}.conf"));
        let mut values = BTreeMap::new();

        if let Ok(text) = std::fs::read_to_string(&path) {
            for line in text.lines() {
                if let Some((key, value)) = line.split_once('=') {
                    values.insert(key.trim().to_string(), value.trim().to_string());
                }
            }
        }

        Self { path, values }
    }

    pub fn text(&self, key: &str, default: &str) -> String {
        self.values.get(key).cloned().unwrap_or_else(|| default.to_string())
    }

    pub fn bool(&self, key: &str, default: bool) -> bool {
        self.values.get(key).map(|value| value == "true").unwrap_or(default)
    }

    pub fn number(&self, key: &str, default: f64) -> f64 {
        self.values
            .get(key)
            .and_then(|value| value.parse().ok())
            .unwrap_or(default)
    }

    pub fn set(&mut self, key: &str, value: impl ToString) {
        self.values.insert(key.to_string(), value.to_string());
    }

    pub fn save(&self) -> std::io::Result<()> {
        if let Some(parent) = self.path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        let body: String = self
            .values
            .iter()
            .map(|(key, value)| format!("{key}={value}\n"))
            .collect();

        std::fs::write(&self.path, body)
    }
}
