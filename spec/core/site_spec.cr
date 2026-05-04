require "../spec_helper"

def write_site_config(root : String)
  root = File.realpath(root)
  config_path = File.join(root, "config.yml")
  Creestal::Utils::FS.write_file(config_path, <<-YAML)
source: src
output: out
default_layout: base
YAML
  config_path
end

def scaffold_min_site(root : String) : NamedTuple(page: String, layout: String, partial: String, asset: String)
  root = File.realpath(root)
  %w(src/pages src/layouts src/partials src/assets).each do |relative|
    Creestal::Utils::FS.ensure_dir(File.join(root, relative))
  end

  page_path = File.join(root, "src", "pages", "index.md")
  layout_path = File.join(root, "src", "layouts", "base.html")
  partial_path = File.join(root, "src", "partials", "banner.html")
  asset_path = File.join(root, "src", "assets", "site.css")

  Creestal::Utils::FS.write_file(page_path, <<-MD)
---
title: Home
layout: base
---

# Hello
MD

  Creestal::Utils::FS.write_file(layout_path, <<-HTML)
<!doctype html>
<html>
  <head><title>{{ page.title }}</title></head>
  <body class="shell-a">
    <main>{{ page.content }}</main>
    {% include "banner.html" %}
  </body>
</html>
HTML

  Creestal::Utils::FS.write_file(partial_path, "<section>banner-a</section>")
  Creestal::Utils::FS.write_file(asset_path, "body { color: black; }")

  {
    page:    page_path,
    layout:  layout_path,
    partial: partial_path,
    asset:   asset_path,
  }
end

describe Creestal::Core::Site do
  it "returns all pages and assets in full_sync_result" do
    with_tmp_dir do |tmp|
      config_path = write_site_config(tmp)
      paths = scaffold_min_site(tmp)

      site = Creestal::Core::Site.new(Creestal::Core::Context.new(config_path))
      result = site.full_sync_result

      result.pages_to_render.should eq(Set{paths[:page]})
      result.assets_to_copy.should eq(Set{paths[:asset]})
      result.ignored_paths.should be_empty
    end
  end

  it "returns changed page path when an existing page mutates" do
    with_tmp_dir do |tmp|
      config_path = write_site_config(tmp)
      paths = scaffold_min_site(tmp)
      site = Creestal::Core::Site.new(Creestal::Core::Context.new(config_path))
      site.setup!

      Creestal::Utils::FS.write_file(paths[:page], <<-MD)
---
title: Home Updated
layout: base
---

# Updated
MD

      result = site.sync(paths[:page])
      result.pages_to_render.should eq(Set{paths[:page]})
      result.assets_to_copy.should be_empty
      result.ignored_paths.should be_empty
    end
  end

  it "cascades a changed layout to dependent pages" do
    with_tmp_dir do |tmp|
      config_path = write_site_config(tmp)
      paths = scaffold_min_site(tmp)
      site = Creestal::Core::Site.new(Creestal::Core::Context.new(config_path))
      site.setup!

      Creestal::Utils::FS.write_file(paths[:layout], <<-HTML)
<!doctype html>
<html>
  <head><title>{{ page.title }}</title></head>
  <body class="shell-b">
    <main>{{ page.content }}</main>
    {% include "banner.html" %}
  </body>
</html>
HTML

      result = site.sync(paths[:layout])
      result.pages_to_render.should eq(Set{paths[:page]})
    end
  end

  it "cascades a changed partial to dependent pages" do
    with_tmp_dir do |tmp|
      config_path = write_site_config(tmp)
      paths = scaffold_min_site(tmp)
      site = Creestal::Core::Site.new(Creestal::Core::Context.new(config_path))
      site.setup!

      Creestal::Utils::FS.write_file(paths[:partial], "<section>banner-b</section>")

      result = site.sync(paths[:partial])
      result.pages_to_render.should eq(Set{paths[:page]})
      result.assets_to_copy.should be_empty
      result.ignored_paths.should be_empty
    end
  end

  it "returns new assets in assets_to_copy" do
    with_tmp_dir do |tmp|
      config_path = write_site_config(tmp)
      _paths = scaffold_min_site(tmp)
      site = Creestal::Core::Site.new(Creestal::Core::Context.new(config_path))
      site.setup!

      new_asset = File.join(tmp, "src", "assets", "app.js")
      Creestal::Utils::FS.write_file(new_asset, "console.log('x');")

      result = site.sync(new_asset)
      result.assets_to_copy.should eq(Set{File.realpath(new_asset)})
      result.pages_to_render.should be_empty
      result.ignored_paths.should be_empty
    end
  end

  it "returns out_of_bounds paths as ignored" do
    with_tmp_dir do |tmp|
      config_path = write_site_config(tmp)
      _paths = scaffold_min_site(tmp)
      site = Creestal::Core::Site.new(Creestal::Core::Context.new(config_path))

      outside = File.join(tmp, "notes.txt")
      Creestal::Utils::FS.write_file(outside, "ignore me")

      result = site.sync(outside)
      result.ignored_paths.should eq([File.realpath(outside)])
      result.pages_to_render.should be_empty
      result.assets_to_copy.should be_empty
    end
  end

  it "tracks include dependencies in conditionals and subdirectories" do
    with_tmp_dir do |tmp|
      config_path = write_site_config(tmp)
      root = File.realpath(tmp)
      %w(src/pages src/layouts src/partials src/partials/nested).each do |relative|
        Creestal::Utils::FS.ensure_dir(File.join(root, relative))
      end

      page_path = File.join(root, "src", "pages", "index.md")
      layout_path = File.join(root, "src", "layouts", "base.html")
      partial_path = File.join(root, "src", "partials", "nested", "banner.html")

      Creestal::Utils::FS.write_file(page_path, <<-MD)
---
title: Home
layout: base
---

# Hello
MD

      Creestal::Utils::FS.write_file(layout_path, <<-HTML)
<!doctype html>
<html>
  <body>
    <main>{{ page.content }}</main>
    {# {% include "missing.html" %} #}
    {% if true %}
      {% include "nested/banner.html" %}
    {% endif %}
  </body>
</html>
HTML

      Creestal::Utils::FS.write_file(partial_path, "<section>nested-a</section>")

      site = Creestal::Core::Site.new(Creestal::Core::Context.new(config_path))
      site.setup!

      Creestal::Utils::FS.write_file(partial_path, "<section>nested-b</section>")
      result = site.sync(partial_path)

      result.pages_to_render.should eq(Set{page_path})
    end
  end

  it "raises when an included partial does not exist" do
    with_tmp_dir do |tmp|
      config_path = write_site_config(tmp)
      root = File.realpath(tmp)
      %w(src/pages src/layouts src/partials).each do |relative|
        Creestal::Utils::FS.ensure_dir(File.join(root, relative))
      end

      page_path = File.join(root, "src", "pages", "index.md")
      layout_path = File.join(root, "src", "layouts", "base.html")

      Creestal::Utils::FS.write_file(page_path, <<-MD)
---
title: Home
layout: base
---

# Hello
MD

      Creestal::Utils::FS.write_file(layout_path, <<-HTML)
<!doctype html>
<html>
  <body>
    <main>{{ page.content }}</main>
    {% include "does-not-exist.html" %}
  </body>
</html>
HTML

      site = Creestal::Core::Site.new(Creestal::Core::Context.new(config_path))

      expect_raises(Creestal::Errors::PartialNotFoundError, /Partial not found: 'does-not-exist.html'/) do
        site.full_sync_result
      end
    end
  end
end
