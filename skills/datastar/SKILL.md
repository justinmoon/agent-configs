---
name: datastar
description: Hypermedia framework for backend-driven reactive web UIs. Use when building Datastar apps, SSE endpoints, signal management, DOM morphing, and Rust SDK (Axum) integration. Covers data-* attributes, patterns, and the Datastar philosophy.
---

# Datastar

Lightweight (~11KB) hypermedia framework. Backend drives frontend via SSE. HTML is the UI.

## Spirit of Datastar

Build an MPA. Each page is a resource. Keep a stream open to the current state of that resource. Ship, touch grass, repeat. **Backend is source of truth.**

## Local Checkouts

- `~/code/datastar` - Core JS framework
- `~/code/datastar-rust` - Rust SDK (Axum/Rocket)

## Core Mental Model

1. HTML is the UI. Backend renders HTML and pushes partial HTML + signal patches over SSE.
2. Frontend only keeps small, local UI state (signals) and forwards intent to backend.
3. Morphing merges new HTML into existing DOM; you can send fat chunks.

## Basic Flow

1. Render HTML from backend (templates)
2. Add `data-*` attributes for reactivity
3. Use `@get/@post/...` to open SSE requests; server streams events:
   - `datastar-patch-elements` (HTML fragment + mode)
   - `datastar-patch-signals` (JSON patch)
4. Morph applies patches, signals update, UI reacts

## Syntax Rules (Critical)

- Attributes: `data-<plugin>` with optional `:<key>` and modifiers `__mod.tag`
- Example: `data-on:click__debounce.300ms.prevent="@post('/save')"`
- **`data-on:click` is correct. `data-on-click` is NOT** (plugin would be `on-click`, which does not exist)
- Modifiers after `__` (double underscore). Tags after `.` (dot)
- Signals referenced as `$name` in expressions
- Use `$` sparingly; backend is the source of truth

## Signal Naming

- Regular signals: sent with every request
- `_`-prefixed signals: local only, NOT sent to backend

```html
<div data-signals="{username: '', _isMenuOpen: false}">
  <!-- username goes to backend, _isMenuOpen stays local -->
</div>
```

## Key Attributes

| Attribute | Purpose |
|-----------|---------|
| `data-signals` | Define reactive signals |
| `data-bind:value` | Two-way bind input |
| `data-text` | Set textContent |
| `data-show` | Conditional visibility |
| `data-class` | Toggle classes |
| `data-on:click` | Handle click events |
| `data-init` | Run on element load |
| `data-indicator` | Show during SSE fetch |
| `data-ignore-morph` | Preserve during morph |

## Actions (Expressions)

```html
<button data-on:click="@post('/save')">Save</button>
<button data-on:click="@get('/data')">Load</button>
<button data-on:click="@delete('/item/42')">Delete</button>
```

Options: `selector`, `headers`, `contentType` (json|form), `filterSignals` {include, exclude}

## SSE Events

### datastar-patch-elements
```
event: datastar-patch-elements
data: selector #result
data: mode inner
data: elements <div>Updated!</div>
```

Modes: `outer` (default), `inner`, `replace`, `prepend`, `append`, `before`, `after`, `remove`

### datastar-patch-signals
```
event: datastar-patch-signals
data: signals {count: 42, status: "done"}
```

## Rust SDK (Axum) - Quick Reference

```rust
use datastar::{axum::ReadSignals, prelude::{PatchElements, PatchSignals, ElementPatchMode}};

#[derive(Deserialize)]
struct Signals {
    count: i32,
}

async fn handler(ReadSignals(signals): ReadSignals<Signals>) -> impl IntoResponse {
    Sse::new(stream_fn(|mut yielder| async move {
        // Patch elements
        let patch = PatchElements::new("<div id='result'>Done!</div>");
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;

        // Patch with selector and mode
        let patch = PatchElements::new("<li>New item</li>")
            .selector("#list")
            .mode(ElementPatchMode::Append);
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;

        // Patch signals
        let patch = PatchSignals::new(format!(r#"{{"count": {}}}"#, signals.count + 1));
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
    }))
}
```

### ElementPatchMode Options
- `Outer` (default) - Replace entire element
- `Inner` - Replace children only
- `Replace` - Hard replace (no morph)
- `Prepend`, `Append`, `Before`, `After`
- `Remove` - Delete element

## Common Patterns

### Loading Indicator
```html
<button data-on:click="@post('/save')" data-indicator:_loading>Save</button>
<span data-show="$_loading">Saving...</span>
```

### Form Binding
```html
<form data-signals="{email: '', password: ''}">
  <input type="email" data-bind:value="email">
  <input type="password" data-bind:value="password">
  <button data-on:click="@post('/login')">Login</button>
</form>
```

### Debounced Search
```html
<input data-bind:value="query"
       data-on:input__debounce.300ms="@get('/search')">
```

### Infinite Scroll
```html
<div data-on-intersect__once="@get('/items?page=2')">Loading...</div>
```

### Live Updates (Long-lived SSE)
```html
<div data-init="@get('/stream')">
  <!-- Server pushes updates -->
</div>
```

## UX Requirements (Mandatory)

**Every button that triggers an action MUST:**

1. **Show Loading State** - Use `data-indicator` to show the action is in progress
2. **Prevent Double-Click** - Loading state inherently disables re-triggering; use `data-attr:disabled="$_loading"` for explicit disable
3. **Show Feedback** - User must always know what happened (success, error, or loading)
4. **Handle Errors Visibly** - No silent failures. Backend MUST send error patches on failure

```html
<!-- CORRECT: Full UX pattern -->
<button data-on:click="@post('/save')"
        data-indicator:_saving
        data-attr:disabled="$_saving">
  <span data-show="!$_saving">Save</span>
  <span data-show="$_saving">Saving...</span>
</button>
<div id="save-result"></div> <!-- Backend patches success/error here -->

<!-- WRONG: No loading state, no feedback -->
<button data-on:click="@post('/save')">Save</button>
```

**Backend MUST always respond with feedback:**
```rust
// Success: patch result element
let patch = PatchElements::new(r#"<div id="save-result" class="success">Saved!</div>"#);

// Error: patch error message (NEVER fail silently)
let patch = PatchElements::new(r#"<div id="save-result" class="error">Failed to save: reason</div>"#);
```

## Anti-Patterns to AVOID

1. **Optimistic Updates** - Don't show success before backend confirms
2. **Too Much Frontend State** - Backend is source of truth
3. **Custom History Management** - Use standard navigation
4. **Trusting Cached State** - Always fetch current state from backend
5. **Silent Failures** - Never swallow errors; always show user what happened
6. **Buttons Without Loading States** - Every action button needs `data-indicator`

## Additional Resources

- [rust-sdk.md](rust-sdk.md) - Complete Rust SDK reference with Axum examples
- [attributes.md](attributes.md) - Full attribute reference
- [patterns.md](patterns.md) - Common implementation patterns

## Links

- [Official Docs](https://data-star.dev)
- [GitHub](https://github.com/starfederation/datastar)
- [Rust SDK](https://github.com/starfederation/datastar-rust)
