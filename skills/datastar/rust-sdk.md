# Datastar Rust SDK Reference

Rust SDK for Datastar with Axum and Rocket integration.

Repo: `~/code/datastar-rust`

## Cargo.toml

```toml
[dependencies]
datastar = { version = "0.1", features = ["axum"] }
# or features = ["rocket"] for Rocket
```

## Core Types

### PatchElements

Patches HTML elements into the DOM.

```rust
use datastar::prelude::{PatchElements, ElementPatchMode};

// Basic usage - element ID is inferred
let patch = PatchElements::new("<div id='result'>Hello!</div>");

// With explicit selector
let patch = PatchElements::new("<p>Content</p>")
    .selector("#container");

// With mode
let patch = PatchElements::new("<li>Item</li>")
    .selector("#list")
    .mode(ElementPatchMode::Append);

// Remove element
let patch = PatchElements::new_remove("#old-element");

// With view transitions
let patch = PatchElements::new("<div id='page'>...</div>")
    .use_view_transition(true);
```

### ElementPatchMode

| Mode | Description |
|------|-------------|
| `Outer` | Replace entire element (morph outer HTML) - **default** |
| `Inner` | Replace children only (morph inner HTML) |
| `Replace` | Hard replace outer HTML (no morph) |
| `Prepend` | Add as first child |
| `Append` | Add as last child |
| `Before` | Insert before element |
| `After` | Insert after element |
| `Remove` | Remove the element |

### PatchSignals

Updates reactive signals on the page.

```rust
use datastar::prelude::PatchSignals;

// Basic usage - JSON string
let patch = PatchSignals::new(r#"{"count": 42, "status": "done"}"#);

// Using serde_json
let patch = PatchSignals::new(serde_json::json!({
    "count": 42,
    "items": ["a", "b", "c"]
}).to_string());

// Only set if signal doesn't exist
let patch = PatchSignals::new(r#"{"defaultValue": 0}"#)
    .only_if_missing(true);
```

### ExecuteScript

Execute JavaScript on the client.

```rust
use datastar::prelude::ExecuteScript;

let script = ExecuteScript::new("console.log('Hello from server')");

// Auto-remove script element after execution (default: true)
let script = ExecuteScript::new("alert('Done!')")
    .auto_remove(true);
```

## Axum Integration

### ReadSignals Extractor

```rust
use datastar::axum::ReadSignals;
use serde::Deserialize;

#[derive(Deserialize)]
struct MySignals {
    count: i32,
    query: Option<String>,
    items: Vec<String>,
}

async fn handler(ReadSignals(signals): ReadSignals<MySignals>) -> impl IntoResponse {
    // signals.count, signals.query, etc.
}
```

ReadSignals works with both GET (query param) and POST/PUT/etc (JSON body).

### SSE Response

```rust
use axum::response::Sse;
use axum::response::sse::Event;
use asynk_strim::{Yielder, stream_fn};
use std::convert::Infallible;

async fn sse_handler(ReadSignals(signals): ReadSignals<MySignals>) -> impl IntoResponse {
    Sse::new(stream_fn(|mut yielder: Yielder<Result<Event, Infallible>>| async move {
        // Patch elements
        let patch = PatchElements::new("<div id='status'>Processing...</div>");
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;

        // Do some work...
        tokio::time::sleep(Duration::from_secs(1)).await;

        // Patch signals
        let patch = PatchSignals::new(r#"{"progress": 50}"#);
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;

        // More work...
        tokio::time::sleep(Duration::from_secs(1)).await;

        // Final update
        let patch = PatchElements::new("<div id='status'>Complete!</div>");
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;

        let patch = PatchSignals::new(r#"{"progress": 100, "done": true}"#);
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
    }))
}
```

### Converting to SSE Event

All Datastar types implement conversion to Axum's `Event`:

```rust
// Method 1: write_as_axum_sse_event()
let event = patch.write_as_axum_sse_event();

// Method 2: Into<Event>
let event: Event = patch.into();

// Method 3: From reference
let event = Event::from(&patch);
```

## Complete Axum Example

```rust
use {
    asynk_strim::{Yielder, stream_fn},
    axum::{
        Router,
        response::{Html, IntoResponse, Sse, sse::Event},
        routing::{get, post},
    },
    core::convert::Infallible,
    datastar::{axum::ReadSignals, prelude::{PatchElements, PatchSignals, ElementPatchMode}},
    serde::Deserialize,
    std::time::Duration,
};

#[derive(Deserialize)]
struct CounterSignals {
    count: i32,
}

async fn index() -> Html<&'static str> {
    Html(r#"
<!DOCTYPE html>
<html>
<head>
    <script type="module" src="https://cdn.jsdelivr.net/npm/@starfederation/datastar"></script>
</head>
<body>
    <div data-signals='{"count": 0}'>
        <button data-on:click="@post('/increment')">+</button>
        <span id="count" data-text="$count"></span>
        <button data-on:click="@post('/decrement')">-</button>
    </div>
</body>
</html>
    "#)
}

async fn increment(ReadSignals(signals): ReadSignals<CounterSignals>) -> impl IntoResponse {
    Sse::new(stream_fn(|mut yielder: Yielder<Result<Event, Infallible>>| async move {
        let new_count = signals.count + 1;
        let patch = PatchSignals::new(format!(r#"{{"count": {}}}"#, new_count));
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
    }))
}

async fn decrement(ReadSignals(signals): ReadSignals<CounterSignals>) -> impl IntoResponse {
    Sse::new(stream_fn(|mut yielder: Yielder<Result<Event, Infallible>>| async move {
        let new_count = signals.count - 1;
        let patch = PatchSignals::new(format!(r#"{{"count": {}}}"#, new_count));
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
    }))
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(index))
        .route("/increment", post(increment))
        .route("/decrement", post(decrement));

    let listener = tokio::net::TcpListener::bind("127.0.0.1:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

## Streaming Multiple Events

```rust
async fn long_operation(ReadSignals(signals): ReadSignals<Signals>) -> impl IntoResponse {
    Sse::new(stream_fn(|mut yielder: Yielder<Result<Event, Infallible>>| async move {
        for i in 0..=100 {
            // Update progress
            let patch = PatchSignals::new(format!(r#"{{"progress": {}}}"#, i));
            yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;

            // Update UI
            let patch = PatchElements::new(format!(
                r#"<div id="progress-bar" style="width: {}%"></div>"#, i
            ));
            yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;

            tokio::time::sleep(Duration::from_millis(50)).await;
        }

        // Final result
        let patch = PatchElements::new(r#"<div id="result">Complete!</div>"#);
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
    }))
}
```

## Tips

1. **Use `serde_json::json!`** for complex signal updates to avoid JSON escaping issues
2. **Stream multiple events** for long operations to show progress
3. **Element IDs** - If no selector specified, the element's id attribute is used
4. **Morphing** - Default `Outer` mode preserves form state and focus
5. **View Transitions** - Enable for smooth page-like transitions
