require "../spec_helper"

def write_e2e_config(root : String)
  root = File.realpath(root)
  path = File.join(root, "config.yml")
  Creestal::Utils::FS.write_file(path, <<-YAML)
source: src
output: out
default_layout: base
YAML
  path
end

def scaffold_e2e_site(root : String) : NamedTuple(page: String, layout: String, partial: String, asset: String, output_html: String, output_asset: String)
  root = File.realpath(root)
  %w(src/pages src/layouts src/partials src/assets).each do |relative|
    Creestal::Utils::FS.ensure_dir(File.join(root, relative))
  end

  page = File.join(root, "src", "pages", "index.md")
  layout = File.join(root, "src", "layouts", "base.html")
  partial = File.join(root, "src", "partials", "hero.html")
  asset = File.join(root, "src", "assets", "site.css")

  Creestal::Utils::FS.write_file(page, <<-MD)
---
title: Home
layout: base
---

# Version A
MD

  Creestal::Utils::FS.write_file(layout, <<-HTML)
<!doctype html>
<html>
  <head><title>{{ page.title }}</title></head>
  <body class="layout-a">
    <main>{{ page.content }}</main>
    {% include "hero.html" %}
  </body>
</html>
HTML

  Creestal::Utils::FS.write_file(partial, "<section>hero-a</section>")
  Creestal::Utils::FS.write_file(asset, "body { margin: 0; }")

  {
    page:         page,
    layout:       layout,
    partial:      partial,
    asset:        asset,
    output_html:  File.join(root, "out", "index.html"),
    output_asset: File.join(root, "out", "assets", "site.css"),
  }
end

describe "incremental rebuild e2e" do
  it "rebuilds dependent output when partial, layout, and page change" do
    with_tmp_dir do |tmp|
      config_path = write_e2e_config(tmp)
      paths = scaffold_e2e_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run
      initial = Creestal::Utils::FS.read_file(paths[:output_html])
      initial.includes?("hero-a").should be_true
      initial.includes?("layout-a").should be_true
      initial.includes?("Version A").should be_true

      Creestal::Utils::FS.write_file(paths[:partial], "<section>hero-b</section>")
      site = Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:partial]])
      after_partial = Creestal::Utils::FS.read_file(paths[:output_html])
      after_partial.includes?("hero-b").should be_true

      Creestal::Utils::FS.write_file(paths[:layout], <<-HTML)
<!doctype html>
<html>
  <head><title>{{ page.title }}</title></head>
  <body class="layout-b">
    <main>{{ page.content }}</main>
    {% include "hero.html" %}
  </body>
</html>
HTML
      site = Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:layout]])
      after_layout = Creestal::Utils::FS.read_file(paths[:output_html])
      after_layout.includes?("layout-b").should be_true

      Creestal::Utils::FS.write_file(paths[:page], <<-MD)
---
title: Home
layout: base
---

# Version B
MD
      Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:page]])
      after_page = Creestal::Utils::FS.read_file(paths[:output_html])
      after_page.includes?("Version B").should be_true
      after_page.includes?("hero-b").should be_true
      after_page.includes?("layout-b").should be_true
    end
  end

  it "handles deleted assets during incremental rebuild and removes output asset" do
    with_tmp_dir do |tmp|
      config_path = write_e2e_config(tmp)
      paths = scaffold_e2e_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run
      File.exists?(paths[:output_asset]).should be_true

      File.delete(paths[:asset])

      Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:asset]])
      File.exists?(paths[:output_asset]).should be_false
    end
  end
end
