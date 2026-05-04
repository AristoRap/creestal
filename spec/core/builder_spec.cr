require "../spec_helper"

def write_builder_config(root : String)
  root = File.realpath(root)
  config_path = File.join(root, "config.yml")
  Creestal::Utils::FS.write_file(config_path, <<-YAML)
source: src
output: out
default_layout: base
YAML
  config_path
end

def scaffold_builder_site(root : String) : NamedTuple(page: String, layout: String, partial: String, asset: String, output: String)
  root = File.realpath(root)
  %w(src/pages src/layouts src/partials src/assets).each do |relative|
    Creestal::Utils::FS.ensure_dir(File.join(root, relative))
  end

  page_path = File.join(root, "src", "pages", "index.md")
  layout_path = File.join(root, "src", "layouts", "base.html")
  partial_path = File.join(root, "src", "partials", "banner.html")
  asset_path = File.join(root, "src", "assets", "site.css")
  output_path = File.join(root, "out")

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
    output:  output_path,
  }
end

def build_page_resource(root : String, source_relative_path : String, entry_relative_path : String, title : String = "Page") : Creestal::Core::Resources::Page
  path = File.join(root, source_relative_path)
  Creestal::Utils::FS.write_file(path, <<-MD)
---
title: #{title}
layout: base
---

# #{title}
MD

  entry = Creestal::Core::FileEntry.new("page", path, entry_relative_path)
  page = Creestal::Core::Resources::Page.new(entry)
  page.add_dependency(File.join(root, "src", "layouts", "base.html"))
  page
end

def build_asset_entry(root : String, source_relative_path : String, entry_relative_path : String, content : String = "body { color: red; }") : Creestal::Core::FileEntry
  path = File.join(root, source_relative_path)
  Creestal::Utils::FS.write_file(path, content)
  Creestal::Core::FileEntry.new("asset", path, entry_relative_path)
end

describe Creestal::Core::Builder do
  it "run cleans stale output and writes page + asset outputs" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)

      Creestal::Utils::FS.ensure_dir(paths[:output])
      stale = File.join(paths[:output], "stale.txt")
      Creestal::Utils::FS.write_file(stale, "remove me")

      ctx = Creestal::Core::Context.new(config_path)
      site = Creestal::Core::Builder.new(ctx).run

      site.pages.size.should eq(1)
      site.assets.size.should eq(1)
      File.exists?(stale).should be_false

      output_html = File.join(paths[:output], "index.html")
      output_css = File.join(paths[:output], "assets", "site.css")
      File.exists?(output_html).should be_true
      File.exists?(output_css).should be_true
      Creestal::Utils::FS.read_file(output_html).includes?("banner-a").should be_true
      Creestal::Utils::FS.read_file(output_html).includes?("Hello").should be_true
    end
  end

  it "writes page and asset outputs to lowercase paths" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      root = File.realpath(tmp)
      %w(src/pages/Blog src/layouts src/partials src/assets/Images).each do |relative|
        Creestal::Utils::FS.ensure_dir(File.join(root, relative))
      end

      page_path = File.join(root, "src", "pages", "Blog", "First-Post.md")
      layout_path = File.join(root, "src", "layouts", "base.html")
      asset_path = File.join(root, "src", "assets", "Images", "Logo.css")

      Creestal::Utils::FS.write_file(page_path, <<-MD)
---
title: Mixed Case
layout: base
---

# Hello
MD

      Creestal::Utils::FS.write_file(layout_path, <<-HTML)
<!doctype html>
<html>
  <body>{{ active_page }} {{ page.content }}</body>
</html>
HTML

      Creestal::Utils::FS.write_file(asset_path, "body { color: red; }")

      ctx = Creestal::Core::Context.new(config_path)
      site = Creestal::Core::Builder.new(ctx).run

      site.pages.values.first.output_path.should eq("blog/first-post.html")
      built_files = Dir.glob(File.join(root, "out", "**", "*")).map do |path|
        Path.new(path).relative_to(File.join(root, "out")).to_s
      end

      built_files.should contain("blog/first-post.html")
      built_files.should contain("assets/images/logo.css")
    end
  end

  it "fails full build when two pages normalize to the same output path" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      root = File.realpath(tmp)
      %w(src/pages src/layouts).each do |relative|
        Creestal::Utils::FS.ensure_dir(File.join(root, relative))
      end

      Creestal::Utils::FS.write_file(File.join(root, "src", "layouts", "base.html"), <<-HTML)
<!doctype html>
<html><body>{{ page.content }}</body></html>
HTML

      ctx = Creestal::Core::Context.new(config_path)
      site = Creestal::Core::Site.new(ctx)
      upper = build_page_resource(root, File.join("src", "pages", "Docs", "Index.md"), File.join("Docs", "Index.md"), "Upper")
      lower = build_page_resource(root, File.join("src", "pages", "docs", "index.md"), File.join("docs", "index.md"), "Lower")
      site.pages[upper.entry.full_path] = upper
      site.pages[lower.entry.full_path] = lower

      expect_raises(Creestal::Errors::PageOutputPathCollisionError, /Page output path collision: 'docs\/index.html'/) do
        Creestal::Core::Builder.new(ctx, site).run_incremental([] of String)
      end
    end
  end

  it "fails full build when two assets normalize to the same output path" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      root = File.realpath(tmp)
      %w(src/pages src/layouts src/assets).each do |relative|
        Creestal::Utils::FS.ensure_dir(File.join(root, relative))
      end

      ctx = Creestal::Core::Context.new(config_path)
      site = Creestal::Core::Site.new(ctx)
      upper = build_asset_entry(root, File.join("src", "assets", "Images", "Logo.css"), File.join("Images", "Logo.css"), "body { color: red; }")
      lower = build_asset_entry(root, File.join("src", "assets", "images", "logo.css"), File.join("images", "logo.css"), "body { color: blue; }")
      site.assets[upper.full_path] = upper
      site.assets[lower.full_path] = lower

      expect_raises(Creestal::Errors::AssetOutputPathCollisionError, /Asset output path collision: 'assets\/images\/logo.css'/) do
        Creestal::Core::Builder.new(ctx, site).run_incremental([] of String)
      end
    end
  end

  it "fails incremental build when a renamed page collides after normalization" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      root = File.realpath(tmp)
      %w(src/pages src/layouts).each do |relative|
        Creestal::Utils::FS.ensure_dir(File.join(root, relative))
      end

      ctx = Creestal::Core::Context.new(config_path)
      site = Creestal::Core::Site.new(ctx)
      first = build_page_resource(root, File.join("src", "pages", "Docs", "Guide.md"), File.join("Docs", "Guide.md"), "Guide")
      second = build_page_resource(root, File.join("src", "pages", "docs", "guide.md"), File.join("docs", "guide.md"), "Colliding Guide")
      site.pages[first.entry.full_path] = first
      site.pages[second.entry.full_path] = second

      expect_raises(Creestal::Errors::PageOutputPathCollisionError, /Page output path collision: 'docs\/guide.html'/) do
        Creestal::Core::Builder.new(ctx, site).run_incremental([] of String)
      end
    end
  end

  it "run_incremental rebuilds a changed page" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run

      Creestal::Utils::FS.write_file(paths[:page], <<-MD)
---
title: Home Updated
layout: base
---

# Updated Content
MD

      Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:page]])
      html = Creestal::Utils::FS.read_file(File.join(paths[:output], "index.html"))
      html.includes?("Updated Content").should be_true
    end
  end

  it "run_incremental cascades a changed layout to dependent page output" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run

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

      Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:layout]])
      html = Creestal::Utils::FS.read_file(File.join(paths[:output], "index.html"))
      html.includes?("shell-b").should be_true
    end
  end

  it "run_incremental copies a newly added asset" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run

      new_asset = File.join(tmp, "src", "assets", "app.js")
      Creestal::Utils::FS.write_file(new_asset, "console.log('new');")

      Creestal::Core::Builder.new(ctx, site).run_incremental([new_asset])

      output_asset = File.join(paths[:output], "assets", "app.js")
      File.exists?(output_asset).should be_true
      Creestal::Utils::FS.read_file(output_asset).should eq("console.log('new');")
    end
  end

  it "run_incremental removes output when a source page is deleted" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run
      output_html = File.join(paths[:output], "index.html")
      File.exists?(output_html).should be_true

      File.delete(paths[:page])

      Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:page]])
      File.exists?(output_html).should be_false
    end
  end

  it "run_incremental fails in strict mode when a layout is deleted" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run
      File.delete(paths[:layout])

      expect_raises(Creestal::Errors::LayoutDeletedWithDependentsError, /Layout deleted: base.html; rebuild blocked for dependent pages/) do
        Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:layout]])
      end
    end
  end

  it "run_incremental fails in strict mode when a partial is deleted" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run
      File.delete(paths[:partial])

      expect_raises(Creestal::Errors::PartialDeletedWithDependentsError, /Partial deleted: banner.html; rebuild blocked for dependent pages/) do
        Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:partial]])
      end
    end
  end

  it "does not write output for pages with draft: true" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      draft_page = File.join(tmp, "src", "pages", "hidden.md")
      Creestal::Utils::FS.write_file(draft_page, <<-MD)
---
title: Hidden
layout: base
draft: true
---

# Secret
MD

      site = Creestal::Core::Builder.new(ctx).run

      # Non-draft page is present, draft page is absent
      File.exists?(File.join(paths[:output], "index.html")).should be_true
      File.exists?(File.join(paths[:output], "hidden.html")).should be_false
    end
  end

  it "removes output when draft: true is added to an already-built page" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      site = Creestal::Core::Builder.new(ctx).run
      output_html = File.join(paths[:output], "index.html")
      File.exists?(output_html).should be_true

      # Add draft: true to the already-built page
      Creestal::Utils::FS.write_file(paths[:page], <<-MD)
---
title: Home
layout: base
draft: true
---

# Hello
MD

      Creestal::Core::Builder.new(ctx, site).run_incremental([paths[:page]])
      File.exists?(output_html).should be_false
    end
  end

  it "exposes active_page in layout and partial contexts" do
    with_tmp_dir do |tmp|
      config_path = write_builder_config(tmp)
      paths = scaffold_builder_site(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      Creestal::Utils::FS.write_file(paths[:layout], <<-HTML)
<!doctype html>
<html>
  <head><title>{{ page.title }}</title></head>
  <body>
    <nav data-layout-active="{{ active_page }}"></nav>
    {% include "banner.html" %}
    <main>{{ page.content }}</main>
  </body>
</html>
HTML

      Creestal::Utils::FS.write_file(paths[:partial], <<-HTML)
<aside data-partial-active="{{ active_page }}"></aside>
HTML

      Creestal::Core::Builder.new(ctx).run

      output_html = File.join(paths[:output], "index.html")
      rendered = Creestal::Utils::FS.read_file(output_html)
      rendered.includes?("data-layout-active=\"index\"").should be_true
      rendered.includes?("data-partial-active=\"index\"").should be_true
    end
  end
end
