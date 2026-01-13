# Datastar Patterns

Common implementation patterns for Datastar applications.

## The Tao of Datastar

### Core Principles

1. **Backend is Source of Truth** - Most state on server. Frontend can't be trusted.
2. **Fat Morph** - Send large DOM chunks. Morphing is efficient.
3. **Restrained Signals** - Only for UI interactions and form binding.
4. **No Optimistic Updates** - Show loading, confirm after backend response.

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
  <td><button data-on:click="@get('/users/1/edit')">Edit</button></td>
</tr>
```

Backend replaces with edit form, save returns to view mode.

### Delete with Confirmation

```html
<tr id="item-42">
  <td>Item Name</td>
  <td>
    <button data-on:click="if(confirm('Delete?')) @delete('/items/42')">
      Delete
    </button>
  </td>
</tr>
```

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

  <!-- Write action -->
  <button data-on:click="@post('/resource/update')">Update</button>
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
  <button data-on:click="$_modalOpen = true; @get('/modal/content')">
    Open Modal
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
            data-class="{'active': $_activeTab === 'details'}">
      Details
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
  <button data-on:click="@post('/start-job')" data-indicator:_processing>
    Start
  </button>
  <div data-show="$_processing || $progress > 0">
    <div class="progress-bar">
      <div class="fill" data-style:width="`${$progress}%`"></div>
    </div>
    <span data-text="`${$progress}%`"></span>
  </div>
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

### Error Handling

Send errors as patches:
```
event: datastar-patch-elements
data: selector #error
data: elements <div class="error">Something went wrong!</div>

event: datastar-patch-signals
data: signals {error: "Failed to save", _loading: false}
```
