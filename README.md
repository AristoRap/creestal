# Creestal

Creestal is a static site generator written in Crystal.

It builds Markdown pages into HTML using Crinja layouts and partials, can serve the generated site locally, and supports incremental rebuilds while watching for changes.

## Installation

Prerequisite:

- Crystal 1.20.0 or newer

Build from source:

```sh
shards install
shards build
```

The binary is written to:

```text
bin/creestal
```

Optional local install:

```sh
cp bin/creestal /usr/local/bin/creestal
```

## Quick Start

Create a site:

```sh
creestal new my-site
cd my-site
```

Build it:

```sh
creestal build
```

Serve it locally:

```sh
creestal serve --watch
```

Default URL:

```text
http://localhost:3000
```

## Commands

### `creestal new [name]`

Create a new scaffolded site.

Flags:

- `-f`, `--force`: overwrite existing files

### `creestal build/b`

Run a full build from the configured source directory to the configured output directory.

Flags:

- `-c`, `--config`: path to config file (default: `config.yml`)

Behavior:

- validates the config file path
- validates the configured source directory
- clears and rebuilds the output directory

### `creestal serve/s/srv`

Serve the configured output directory.

Flags:

- `-c`, `--config`: path to config file (default: `config.yml`)
- `-b`, `--build`: force a full build before serving
- `-w`, `--watch`: watch source files and rebuild incrementally on change
- `-p`, `--port`: port to listen on (default: `3000`)
- `--host`: host to bind (default: `localhost`)

Behavior:

- if output is missing or empty, runs a full build before serving
- if `--build` is passed, always runs a full build before serving
- if output already exists, loads source state so watch mode can rebuild incrementally
- in watch mode, rebuilds changed pages/assets and triggers browser reload

## Project Structure

Scaffolded projects use this structure:

```text
my-site/
	config.yml
	src/
		pages/
		layouts/
		partials/
		assets/
	out/
```

Directories:

- `src/pages/`: Markdown pages
- `src/layouts/`: Crinja HTML layouts
- `src/partials/`: Crinja HTML partials included by layouts
- `src/assets/`: static assets copied to output
- `out/`: generated site output

## Configuration

Creestal reads YAML from `config.yml`.

Example:

```yaml
site: "My Site"
home: "index"
source: "src"
output: "out"
default_layout: "base"
watcher_interval_ms: 500
```

Fields:

- `site`: site name
- `home`: home page path without extension
- `source`: source directory relative to the config file
- `output`: output directory relative to the config file
- `default_layout`: fallback layout name when a page does not set one
- `watcher_interval_ms`: file watcher polling interval in milliseconds

Defaults:

- `site`: `New Creestal Site`
- `home`: `index`
- `source`: `src`
- `output`: `out`
- `default_layout`: `base`
- `watcher_interval_ms`: `500`

## Pages

Pages are Markdown files in `src/pages/` with YAML front matter.

Example:

```markdown
---
title: Hello
layout: base
date: 2026-05-04
tags: [intro, docs]
draft: false
---

# Hello
```

Supported front matter fields:

- `title` (required)
- `date` (optional)
- `tags` (optional, defaults to `[]`)
- `draft` (optional, defaults to `false`)
- `layout` (optional, defaults to configured `default_layout`)

Routing/output examples:

- `src/pages/index.md` -> `out/index.html` -> `/`
- `src/pages/about.md` -> `out/about.html` -> `/about`
- `src/pages/blog/first-post.md` -> `out/blog/first-post.html` -> `/blog/first-post`

Path normalization:

- generated page output paths are always lowercased
- generated asset output paths are always lowercased
- route matching normalizes incoming request paths to lowercase before lookup
- files that only differ by case in the same directory collide after normalization and fail the build

Draft behavior:

- draft pages are parsed
- draft pages are not rendered to output
- if a page becomes a draft after being built, its output file is removed

## Layouts and Partials

Layouts are regular HTML files rendered with Crinja.

Partials are included with standard Crinja include syntax:

```jinja
{% include "header.html" %}
```

Creestal loads includes from `src/partials/` first, then from the source root.

Included partials receive the same render context as the parent layout.

### Render Context

Each render receives three top-level values:

- `page`
- `site`
- `active_page`

#### `page`

Available fields:

- `page.title`
- `page.date`
- `page.tags`
- `page.draft`
- `page.layout`
- `page.content`
- `page.output_path`
- `page.source_path`

Most commonly used:

```jinja
<title>{{ page.title }}</title>
<main>{{ page.content }}</main>
```

#### `site`

Available collections:

- `site.nav`: non-draft, non-blog pages
- `site.posts`: non-draft pages under `blog/`
- `site.all_pages`: all pages, including drafts
- `site.breadcrumbs`: breadcrumb chain for the current page

Each page node in these collections contains:

- `title`
- `source_path`
- `output_path`
- `url`
- `date`
- `tags`
- `draft`

Notes:

- `site.nav` is sorted by title
- `site.posts` is sorted by date descending, then path
- `site.all_pages` is sorted by output path, then title

Example:

```jinja
{% for post in site.posts %}
	<a href="{{ post.url }}">{{ post.title }}</a>
{% endfor %}
```

#### `active_page`

`active_page` is the current page path without extension.

It is exposed as a top-level render value, not as `page.active_page`.

Examples:

- `index`
- `about`
- `blog/first-post`

Creestal also exposes a helper:

```jinja
{{ is_active("about", "active") }}
```

`is_active(current, value)` returns `value` when `current == active_page`, otherwise it returns an empty string.

Example in markup:

```jinja
<a class='{{ is_active("about", "active") }}' href="/about">About</a>
```

## Dependency Tracking

Creestal tracks layout and partial dependencies so incremental rebuilds only touch affected pages.

Currently:

- page changes rebuild that page
- layout changes rebuild dependent pages
- partial changes rebuild pages whose layouts include those partials
- asset changes copy only affected assets
- output path collisions fail fast before files are written

## Development

Run the full test suite:

```sh
crystal spec
```

Run targeted suites:

```sh
crystal spec spec/core
crystal spec spec/commands
crystal spec spec/integration
crystal spec spec/server
```

Build the binary:

```sh
shards build
```

## Status

Creestal is under active development.

## License

MIT
