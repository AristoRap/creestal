require "../spec_helper"

def write_context_config(root : String)
  config_path = File.join(root, "config.yml")
  Creestal::Utils::FS.write_file(config_path, "source: src\noutput: out\n")
  config_path
end

def ensure_context_source_dirs(root : String)
  %w(src/pages src/layouts src/partials src/assets).each do |relative|
    Creestal::Utils::FS.ensure_dir(File.join(root, relative))
  end
end

describe Creestal::Core::Context do
  it "classifies entries by source subdirectory" do
    with_tmp_dir do |tmp|
      config_path = write_context_config(tmp)
      ensure_context_source_dirs(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      page_path = File.join(tmp, "src", "pages", "a.md")
      layout_path = File.join(tmp, "src", "layouts", "base.html")
      partial_path = File.join(tmp, "src", "partials", "header.html")
      asset_path = File.join(tmp, "src", "assets", "site.css")

      Creestal::Utils::FS.write_file(page_path, "---\ntitle: A\n---\n# A")
      Creestal::Utils::FS.write_file(layout_path, "<html><body></body></html>")
      Creestal::Utils::FS.write_file(partial_path, "<header>H</header>")
      Creestal::Utils::FS.write_file(asset_path, "body{}")

      ctx.entry_for(page_path).type.should eq("page")
      ctx.entry_for(layout_path).type.should eq("layout")
      ctx.entry_for(partial_path).type.should eq("partial")
      ctx.entry_for(asset_path).type.should eq("asset")
    end
  end

  it "marks files outside source bounds as out_of_bounds" do
    with_tmp_dir do |tmp|
      config_path = write_context_config(tmp)
      ensure_context_source_dirs(tmp)
      ctx = Creestal::Core::Context.new(config_path)

      outside_path = File.join(tmp, "notes.txt")
      Creestal::Utils::FS.write_file(outside_path, "not in source tree")

      entry = ctx.entry_for(outside_path)
      entry.type.should eq("out_of_bounds")
      entry.relative_path.should eq(Path.new(outside_path).relative_to(outside_path).to_s)
    end
  end
end
