# Datastar Attributes Reference

All Datastar functionality is accessed through `data-*` attributes on HTML elements.

## Syntax Rules

- Format: `data-<plugin>` with optional `:<key>` and modifiers `__mod.tag`
- **`data-on:click` is correct. `data-on-click` is NOT**
- Modifiers use `__` (double underscore)
- Tags use `.` (dot)
- Signals referenced as `$name` in expressions
- `el` is the current element, `evt` is available in event handlers

Example: `data-on:click__debounce.300ms.prevent="@post('/save')"`

## Event Handling

### data-on:[event]

Handle DOM events with optional modifiers.

```html
<!-- Basic click -->
<button data-on:click="@post('/action')">Click</button>

<!-- With modifiers -->
<button data-on:click__prevent="@post('/submit')">Submit</button>

<!-- Debounced input -->
<input data-on:input__debounce.300ms="@get('/search')">

<!-- Window-level events -->
<div data-on:keydown__window="handleKey(evt)">

<!-- Multiple events -->
<input data-on:focus="highlight()" data-on:blur="unhighlight()">
```

**Event Modifiers:**
- `__prevent` - preventDefault()
- `__stop` - stopPropagation()
- `__once` - Fire only once
- `__capture` - Use capture phase
- `__passive` - Passive listener
- `__window` - Listen on window
- `__outside` - Fire when clicking outside element

**Timing Modifiers:**
- `__delay.<ms|s>` - Delay execution
- `__debounce.<ms|s>[.leading][.notrailing]` - Debounce
- `__throttle.<ms|s>[.noleading][.trailing]` - Throttle

**View Transition:**
- `__viewtransition` - Use View Transition API

### data-on-interval

Trigger at regular intervals.

```html
<!-- Poll every second -->
<div data-on-interval__duration.1000ms="@get('/status')">
```

Modifiers: `__duration.<ms|s>[.leading]`

### data-on-intersect

Trigger when element enters/exits viewport.

```html
<div data-on-intersect="@get('/load-content')">Loading...</div>

<!-- Fire only once -->
<div data-on-intersect__once="@get('/analytics/view')">

<!-- Fire at 50% visibility -->
<div data-on-intersect__half="@get('/load')">

<!-- Fire when exiting viewport -->
<div data-on-intersect__exit="cleanup()">
```

Modifiers: `__once`, `__full`, `__half`, `__threshold.<0-100>`, `__exit`

### data-on-signal-patch

Trigger when signals change.

```html
<div data-on-signal-patch="console.log('Signal changed')">

<!-- Filter specific signals -->
<div data-on-signal-patch-filter="{include:/count/}"
     data-on-signal-patch="handleCountChange()">
```

## State Management

### data-signals

Define reactive signals (state).

```html
<!-- Object syntax -->
<div data-signals="{count: 0, name: '', items: []}">

<!-- Underscore prefix = local only (not sent to backend) -->
<div data-signals="{_menuOpen: false, searchQuery: ''}">

<!-- Single key -->
<div data-signals:count="0">
```

Modifier: `__ifmissing` - Only set if signal doesn't exist

### data-bind:[attr]

Two-way binding between element attribute and signal.

```html
<!-- Input value -->
<input type="text" data-bind:value="username">

<!-- Checkbox -->
<input type="checkbox" data-bind:checked="agreed">

<!-- Select -->
<select data-bind:value="country">
  <option value="us">USA</option>
  <option value="uk">UK</option>
</select>

<!-- File input (yields base64) -->
<input type="file" data-bind:value="fileData">
```

### data-computed

Derived/computed values from signals.

```html
<div data-signals="{price: 100, quantity: 2}">
  <span data-computed:total="price * quantity"></span>
  Total: <span data-text="$total"></span>
</div>
```

### data-init

Run expression when element is inserted.

```html
<div data-init="@get('/initial-data')">
<div data-init="console.log('mounted')">
```

### data-effect

Run side effects when referenced signals change.

```html
<div data-effect="console.log('Count is now:', $count)">
<div data-effect="localStorage.setItem('theme', $theme)">
```

## DOM Updates

### data-text

Set element's text content.

```html
<span data-text="$username">placeholder</span>
<span data-text="`Hello, ${$name}!`">placeholder</span>
<span data-text="$count * 2">0</span>
```

### data-show

Conditionally show/hide element (sets `display: none`).

```html
<div data-show="$isLoggedIn">Welcome back!</div>
<div data-show="$items.length > 0">You have items</div>
<div data-show="!$_loading">Content</div>
```

### data-class

Dynamically add/remove classes.

```html
<!-- Object syntax -->
<div data-class="{'active': $isActive, 'disabled': $isDisabled}">

<!-- String syntax -->
<div data-class="$isActive ? 'active' : 'inactive'">

<!-- Single class -->
<div data-class:active="$isActive">
```

### data-attr:[attribute]

Set any attribute dynamically.

```html
<button data-attr:disabled="$isSubmitting">Submit</button>
<img data-attr:src="$imageUrl">
<a data-attr:href="$linkUrl">Link</a>
```

### data-style:[property]

Set inline styles.

```html
<div data-style:color="$textColor">
<div data-style:display="$isVisible ? 'block' : 'none'">
<div data-style:width="`${$progress}%`">
```

### data-ref

Create a signal pointing to the element.

```html
<input data-ref:searchInput>
<button data-on:click="$searchInput.focus()">Focus</button>
```

## Morphing Control

### data-ignore

Skip element during all Datastar processing.

```html
<div data-ignore>
  <!-- Datastar won't process this subtree -->
</div>

<!-- Ignore only this element, process children -->
<div data-ignore__self>
```

### data-ignore-morph

Preserve element content across morphs (but allow attribute updates).

```html
<video data-ignore-morph>
  <!-- Video keeps playing during morphs -->
</video>
```

### data-preserve-attr

Keep specific attribute values during morph.

```html
<input data-preserve-attr="value class">
```

## Backend Actions

Actions are prefixed with `@` and execute HTTP requests.

### HTTP Methods

```html
<button data-on:click="@get('/data')">Load</button>
<button data-on:click="@post('/submit')">Submit</button>
<button data-on:click="@put('/update')">Update</button>
<button data-on:click="@patch('/partial')">Patch</button>
<button data-on:click="@delete('/remove')">Delete</button>
```

### Action Options

```html
<!-- With headers -->
<button data-on:click="@post('/api', {headers: {'X-Custom': 'value'}})">

<!-- Signal filtering -->
<button data-on:click="@post('/api', {filterSignals: {include: 'user.*'}})">
<button data-on:click="@post('/api', {filterSignals: {exclude: '_*'}})">

<!-- Form content type -->
<button data-on:click="@post('/save', {contentType: 'form'})">

<!-- Custom selector for response -->
<button data-on:click="@get('/partial', {selector: '#target'})">
```

### Utility Actions

```html
<!-- Access signal without subscribing to changes -->
<div data-text="@peek($count)">

<!-- Set all matching signals -->
<button data-on:click="@setAll('', 'form.*')">Clear Form</button>

<!-- Toggle all matching boolean signals -->
<button data-on:click="@toggleAll('selected.*')">Toggle All</button>
```

## Loading States

### data-indicator

Signal that's true while SSE fetch is in flight.

```html
<button data-on:click="@post('/save')" data-indicator:_saving>
  Save
</button>
<span data-show="$_saving">Saving...</span>

<!-- Or point to an element -->
<button data-on:click="@post('/save')" data-indicator="#saving-indicator">
  Save
</button>
<span id="saving-indicator" style="display:none">Saving...</span>
```

## Debug

### data-json-signals

Render current signals as JSON (for debugging).

```html
<pre data-json-signals></pre>
<pre data-json-signals__terse></pre>
```

## Pro Attributes (Datastar Pro)

| Attribute | Purpose |
|-----------|---------|
| `data-animate` | Animation helpers with easing |
| `data-custom-validity` | Form validation messages |
| `data-on-raf` | requestAnimationFrame triggers |
| `data-on-resize` | Resize observer triggers |
| `data-persist` | Persist signals to localStorage/sessionStorage |
| `data-query-string` | Sync with URL query params |
| `data-replace-url` | Update URL without navigation |
| `data-scroll-into-view` | Scroll element into view |
| `data-view-transition` | Set view-transition-name |
| `data-rocket` | Rocket component definition |

## Expression Syntax

Expressions support JavaScript with access to:
- All signals as `$name` variables
- `el` - Current element
- `evt` - Event object (in event handlers)

```html
<div data-signals="{count: 0}">
  <button data-on:click="$count++">+1</button>
  <button data-on:click="$count = $count * 2">Double</button>
  <span data-text="`Count: ${$count}`"></span>
</div>
```
