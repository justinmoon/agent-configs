# Datastar Patterns

Common implementation patterns for Datastar applications.

## The Tao of Datastar

### Core Principles

1. **Backend is Source of Truth** - Most state on server. Frontend can't be trusted.
2. **Fat Morph** - Send large DOM chunks. Morphing is efficient.
3. **Restrained Signals** - Only for UI interactions and form binding.
4. **No Optimistic Updates** - Show loading, confirm after backend response.
5. **Always Show Feedback** - User must ALWAYS know what's happening. No silent actions.
6. **No Silent Failures** - Every error MUST be shown to the user. Never swallow errors.

### Anti-Patterns

```html
<!-- BAD: Optimistic update -->
<div data-on:click="status = 'Saved!'; @post('/save')">

<!-- GOOD: Loading indicator, backend confirms -->
<div data-on:click="@post('/save')" data-indicator:_saving>
<span data-show="$_saving">Saving...</span>
```

```html
<!-- BAD: Too much frontend state -->
<div data-signals="{users: [], selectedUser: null, filters: {...}}">

<!-- GOOD: Minimal local state, backend drives UI -->
<div data-signals="{_menuOpen: false, searchQuery: ''}">
```

```html
<!-- BAD: Button with no loading state or feedback -->
<button data-on:click="@post('/delete')">Delete</button>

<!-- GOOD: Loading state + disabled during action + feedback target -->
<button data-on:click="@delete('/items/42')"
        data-indicator:_deleting
        data-attr:disabled="$_deleting">
  <span data-show="!$_deleting">Delete</span>
  <span data-show="$_deleting">Deleting...</span>
</button>
<div id="delete-result"></div>
```

## Button UX Requirements (Mandatory)

**Every button that performs an action MUST have:**

1. **Loading indicator** - `data-indicator:_loading` to track request state
2. **Disabled during action** - `data-attr:disabled="$_loading"` to prevent double-clicks
3. **Visual feedback** - Show "Loading...", spinner, or change button text
4. **Result target** - Element where backend can patch success/error messages

### Standard Button Pattern

```html
<button data-on:click="@post('/action')"
        data-indicator:_actionLoading
        data-attr:disabled="$_actionLoading">
  <span data-show="!$_actionLoading">Do Action</span>
  <span data-show="$_actionLoading">Processing...</span>
</button>
<div id="action-result"></div>
```

### Backend MUST Respond With Feedback

```rust
// On success - ALWAYS confirm to user
let patch = PatchElements::new(r#"<div id="action-result" class="success">Done!</div>"#);
yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;

// On error - NEVER fail silently
let patch = PatchElements::new(r#"<div id="action-result" class="error">Failed: {reason}</div>"#);
yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
```

### Delete Button With Confirmation

```html
<button data-on:click="if(confirm('Are you sure?')) @delete('/items/42')"
        data-indicator:_deleting
        data-attr:disabled="$_deleting">
  <span data-show="!$_deleting">🗑 Delete</span>
  <span data-show="$_deleting">Deleting...</span>
</button>
```

### Icon Button With Spinner

```html
<button data-on:click="@post('/refresh')"
        data-indicator:_refreshing
        data-attr:disabled="$_refreshing"
        class="icon-btn">
  <svg data-show="!$_refreshing"><!-- refresh icon --></svg>
  <svg data-show="$_refreshing" class="spin"><!-- spinner icon --></svg>
</button>
```

## Form Handling

### Basic Form

```html
<form data-signals="{email: '', password: ''}"
      data-on:submit__prevent="@post('/login')">
  <input type="email" data-bind:value="email" required>
  <input type="password" data-bind:value="password" required>
  <button type="submit" data-indicator:_submitting>
    <span data-show="!$_submitting">Login</span>
    <span data-show="$_submitting">Logging in...</span>
  </button>
</form>
<div id="login-result"></div>
```

### Inline Validation

```html
<form data-signals="{username: ''}">
  <input type="text"
         data-bind:value="username"
         data-on:blur="@post('/validate/username')">
  <span id="username-error"></span>
</form>
```

### File Upload

```html
<form data-signals="{_file: null}">
  <input type="file" data-on:change="_file = evt.target.files[0]">
  <button data-on:click="@post('/upload', {body: $_file})"
          data-indicator:_uploading>
    Upload
  </button>
</form>
```

## Lists and Tables

### Click to Edit Row

```html
<tr id="user-1">
  <td>Alice</td>
  <td>
    <button data-on:click="@get('/users/1/edit')"
            data-indicator:_editLoading
            data-attr:disabled="$_editLoading">
      <span data-show="!$_editLoading">Edit</span>
      <span data-show="$_editLoading">Loading...</span>
    </button>
  </td>
</tr>
```

Backend replaces with edit form, save returns to view mode.

### Delete with Confirmation

```html
<tr id="item-42">
  <td>Item Name</td>
  <td>
    <button data-on:click="if(confirm('Delete?')) @delete('/items/42')"
            data-indicator:_deleting
            data-attr:disabled="$_deleting">
      <span data-show="!$_deleting">Delete</span>
      <span data-show="$_deleting">Deleting...</span>
    </button>
  </td>
</tr>
<div id="delete-result"></div> <!-- Backend patches success/error here -->

### Infinite Scroll

```html
<div id="items">
  <!-- Existing items -->
</div>
<div data-on-intersect__once="@get('/items?page=2')" id="load-trigger">
  Loading more...
</div>
```

Backend appends items and updates trigger for next page.

## Real-Time Updates

### Polling

```html
<div data-on-interval__duration.2000ms="@get('/jobs/123/status')">
  <span id="job-status">Checking...</span>
</div>
```

### Live Stream (Long-lived SSE)

```html
<div data-init="@get('/notifications/stream')">
  <ul id="notifications"></ul>
</div>
```

Backend sends events as they occur:
```
event: datastar-patch-elements
data: mode prepend
data: selector #notifications
data: elements <li class="new">New message!</li>
```

### CQRS Pattern

- Long-lived read connection for real-time updates
- Short-lived write requests for mutations

```html
<!-- Read stream for live updates -->
<div data-init="@get('/resource/stream')">
  <div id="content"></div>

  <!-- Write action with loading state -->
  <button data-on:click="@post('/resource/update')"
          data-indicator:_updating
          data-attr:disabled="$_updating">
    <span data-show="!$_updating">Update</span>
    <span data-show="$_updating">Updating...</span>
  </button>
  <div id="update-result"></div>
</div>
```

## Search and Filtering

### Debounced Search

```html
<div data-signals="{query: ''}">
  <input type="search"
         data-bind:value="query"
         data-on:input__debounce.300ms="@get('/search')"
         placeholder="Search...">
  <div id="results"></div>
</div>
```

### Filter Controls

```html
<div data-signals="{category: 'all', sort: 'newest'}">
  <select data-bind:value="category"
          data-on:change="@get('/products')">
    <option value="all">All</option>
    <option value="electronics">Electronics</option>
  </select>

  <select data-bind:value="sort"
          data-on:change="@get('/products')">
    <option value="newest">Newest</option>
    <option value="price">Price</option>
  </select>

  <div id="product-list"></div>
</div>
```

## UI Interactions

### Toggle Menu (Local State)

```html
<div data-signals="{_menuOpen: false}">
  <button data-on:click="$_menuOpen = !$_menuOpen">Menu</button>
  <nav data-show="$_menuOpen">
    <a href="/home">Home</a>
    <a href="/about">About</a>
  </nav>
</div>
```

### Modal Dialog

```html
<div data-signals="{_modalOpen: false}">
  <button data-on:click="$_modalOpen = true; @get('/modal/content')"
          data-indicator:_modalLoading
          data-attr:disabled="$_modalLoading">
    <span data-show="!$_modalLoading">Open Modal</span>
    <span data-show="$_modalLoading">Loading...</span>
  </button>

  <div data-show="$_modalOpen" class="modal-backdrop"
       data-on:click__self="$_modalOpen = false">
    <div class="modal" id="modal-content">
      <!-- Content loaded here -->
    </div>
  </div>
</div>
```

### Tabs

```html
<div data-signals="{_activeTab: 'overview'}">
  <div class="tabs">
    <button data-on:click="$_activeTab = 'overview'"
            data-class="{'active': $_activeTab === 'overview'}">
      Overview
    </button>
    <button data-on:click="$_activeTab = 'details'; @get('/tabs/details')"
            data-class="{'active': $_activeTab === 'details'}"
            data-indicator:_detailsLoading
            data-attr:disabled="$_detailsLoading">
      <span data-show="!$_detailsLoading">Details</span>
      <span data-show="$_detailsLoading">Loading...</span>
    </button>
  </div>

  <div data-show="$_activeTab === 'overview'" id="tab-overview">
    <!-- Static content -->
  </div>
  <div data-show="$_activeTab === 'details'" id="tab-details">
    <!-- Loaded on demand -->
  </div>
</div>
```

## Keyboard Shortcuts

### Global Keys

```html
<div data-on:keydown__window="
  if (evt.key === 'Escape') $_modalOpen = false;
  if (evt.key === '/' && evt.ctrlKey) $searchInput.focus();
">
  <input data-ref:searchInput type="search">
</div>
```

### Form Shortcuts

```html
<form data-on:keydown="
  if (evt.key === 'Enter' && evt.ctrlKey) @post('/submit');
">
  <textarea data-bind:value="content"></textarea>
  <small>Ctrl+Enter to submit</small>
</form>
```

## Progress Indicators

### Progress Bar

```html
<div data-signals="{progress: 0}">
  <button data-on:click="@post('/start-job')"
          data-indicator:_processing
          data-attr:disabled="$_processing">
    <span data-show="!$_processing">Start</span>
    <span data-show="$_processing">Processing...</span>
  </button>
  <div data-show="$_processing || $progress > 0">
    <div class="progress-bar">
      <div class="fill" data-style:width="`${$progress}%`"></div>
    </div>
    <span data-text="`${$progress}%`"></span>
  </div>
  <div id="job-result"></div> <!-- Backend patches success/error here -->
</div>
```

Backend streams progress:
```
event: datastar-patch-signals
data: signals {progress: 25}

event: datastar-patch-signals
data: signals {progress: 50}

event: datastar-patch-signals
data: signals {progress: 100}
```

## Backend Patterns

### Redirect After Action

```html
<div data-signals="{_redirect: ''}"
     data-effect="if ($_redirect) window.location.href = $_redirect">
</div>
```

Backend sends:
```
event: datastar-patch-signals
data: signals {_redirect: "/dashboard"}
```

### Keep-Alive for Long Connections

Backend sends periodic comments to prevent timeout:
```
: keepalive

: keepalive
```

### Error Handling (No Silent Failures!)

**CRITICAL: Every backend error MUST be shown to the user. Never swallow errors.**

Send errors as patches:
```
event: datastar-patch-elements
data: selector #error
data: elements <div class="error">Something went wrong!</div>

event: datastar-patch-signals
data: signals {error: "Failed to save", _loading: false}
```

**Rust pattern for guaranteed error feedback:**
```rust
async fn action_handler() -> impl IntoResponse {
    Sse::new(stream_fn(|mut yielder| async move {
        match do_action().await {
            Ok(result) => {
                // Success feedback
                let patch = PatchElements::new(
                    r#"<div id="result" class="success">Action completed!</div>"#
                );
                yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
            }
            Err(e) => {
                // Error feedback - NEVER skip this!
                let patch = PatchElements::new(
                    &format!(r#"<div id="result" class="error">Error: {}</div>"#, e)
                );
                yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
            }
        }
        // Always clear loading state
        let patch = PatchSignals::new(r#"{"_loading": false}"#);
        yielder.yield_item(Ok(patch.write_as_axum_sse_event())).await;
    }))
}
```
