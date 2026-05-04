require "../spec_helper"

def write_commands_config(root : String)
  root = File.realpath(root)
  config_path = File.join(root, "config.yml")
  Creestal::Utils::FS.write_file(config_path, <<-YAML)
source: src
output: out
default_layout: base
YAML
  config_path
end

def scaffold_commands_site(root : String)
  root = File.realpath(root)
  %w(src/pages src/layouts src/partials src/assets).each do |relative|
    Creestal::Utils::FS.ensure_dir(File.join(root, relative))
  end

  Creestal::Utils::FS.write_file(File.join(root, "src", "pages", "index.md"), <<-MD)
---
title: Home
layout: base
---

# Hello
MD

  Creestal::Utils::FS.write_file(File.join(root, "src", "layouts", "base.html"), <<-HTML)
<!doctype html>
<html>
  <head><title>{{ page.title }}</title></head>
  <body>
    <main>{{ page.content }}</main>
    {% include "header.html" %}
  </body>
</html>
HTML

  Creestal::Utils::FS.write_file(File.join(root, "src", "partials", "header.html"), "<header>header</header>")
  Creestal::Utils::FS.write_file(File.join(root, "src", "assets", "site.css"), "body{}")
end

describe Creestal::Commands do
  it "registers new, build, and serve on CLI root" do
    root = Creestal::CLI.root
    root.subcommands.keys.sort.should eq(["build", "new", "serve"])
  end

  it "new command creates a scaffolded project" do
    with_tmp_dir do |tmp|
      Dir.cd(tmp) do
        Creestal::Commands::New.command.execute(["demo-site"])

        app_root = File.join(tmp, "demo-site")
        File.exists?(File.join(app_root, "config.yml")).should be_true
        Dir.exists?(File.join(app_root, "src", "pages")).should be_true
        Dir.exists?(File.join(app_root, "src", "layouts")).should be_true
        Dir.exists?(File.join(app_root, "src", "partials")).should be_true
        Dir.exists?(File.join(app_root, "src", "assets")).should be_true

        header = Creestal::Utils::FS.read_file(File.join(app_root, "src", "partials", "header.html"))
        footer = Creestal::Utils::FS.read_file(File.join(app_root, "src", "partials", "footer.html"))
        header.includes?("{% include").should be_false
        footer.includes?("{% include").should be_false
      end
    end
  end

  it "build command raises when config does not exist" do
    with_tmp_dir do |tmp|
      Dir.cd(tmp) do
        expect_raises(Creestal::Errors::ConfigFileNotFoundError, /config file not found/) do
          Creestal::Commands::Build.command.execute(["--config", "missing.yml"])
        end
      end
    end
  end

  it "build command writes output for a valid site" do
    with_tmp_dir do |tmp|
      write_commands_config(tmp)
      scaffold_commands_site(tmp)

      Dir.cd(tmp) do
        Creestal::Commands::Build.command.execute(["--config", "config.yml"])
      end

      File.exists?(File.join(tmp, "out", "index.html")).should be_true
      File.exists?(File.join(tmp, "out", "assets", "site.css")).should be_true
    end
  end

  it "serve command raises when config does not exist" do
    with_tmp_dir do |tmp|
      Dir.cd(tmp) do
        expect_raises(Creestal::Errors::ConfigFileNotFoundError, /config file not found/) do
          Creestal::Commands::Serve.command.execute(["--config", "missing.yml"])
        end
      end
    end
  end

  it "serve --watch processes one change and rebuilds incrementally" do
    with_tmp_dir do |tmp|
      write_commands_config(tmp)
      scaffold_commands_site(tmp)

      changed_asset = File.join(tmp, "src", "assets", "app.js")
      rebuilt = Channel(Array(String)).new(1)

      begin
        Creestal::Commands::Serve.watcher_runner = ->(_root : String, _interval : Int32, on_change : Proc(Array(String), Nil)) do
          Creestal::Utils::FS.write_file(changed_asset, "console.log('watch');")
          on_change.call([changed_asset])
        end

        Creestal::Commands::Serve.server_start = ->(_server : Creestal::Server::Server) { nil }
        Creestal::Commands::Serve.on_rebuild = ->(paths : Array(String)) { rebuilt.send(paths) }

        Dir.cd(tmp) do
          Creestal::Commands::Serve.command.execute(["--config", "config.yml", "--watch"])
        end

        select
        when paths = rebuilt.receive
          paths.should eq([changed_asset])
        when timeout(2.seconds)
          raise "expected serve watch rebuild callback"
        end

        output_asset = File.join(tmp, "out", "assets", "app.js")
        File.exists?(output_asset).should be_true
        Creestal::Utils::FS.read_file(output_asset).should eq("console.log('watch');")
      ensure
        Creestal::Commands::Serve.reset_test_hooks!
      end
    end
  end

  it "serve --watch survives a deleted partial dependency and rebuilds later changes" do
    with_tmp_dir do |tmp|
      write_commands_config(tmp)
      scaffold_commands_site(tmp)

      site_root = File.realpath(tmp)
      deleted_partial = File.join(site_root, "src", "partials", "header.html")
      changed_asset = File.join(site_root, "src", "assets", "app.js")
      rebuilt = Channel(Array(String)).new(1)

      begin
        Creestal::Commands::Serve.watcher_runner = ->(_root : String, _interval : Int32, on_change : Proc(Array(String), Nil)) do
          File.delete(deleted_partial)
          on_change.call([deleted_partial])

          Creestal::Utils::FS.write_file(changed_asset, "console.log('watch');")
          on_change.call([changed_asset])
        end

        Creestal::Commands::Serve.server_start = ->(_server : Creestal::Server::Server) { nil }
        Creestal::Commands::Serve.on_rebuild = ->(paths : Array(String)) { rebuilt.send(paths) }

        Dir.cd(tmp) do
          Creestal::Commands::Serve.command.execute(["--config", "config.yml", "--watch"])
        end

        select
        when paths = rebuilt.receive
          paths.should eq([changed_asset])
        when timeout(2.seconds)
          raise "expected serve watch rebuild callback after partial deletion failure"
        end

        output_asset = File.join(tmp, "out", "assets", "app.js")
        File.exists?(output_asset).should be_true
        Creestal::Utils::FS.read_file(output_asset).should eq("console.log('watch');")
      ensure
        Creestal::Commands::Serve.reset_test_hooks!
      end
    end
  end

  it "serve --watch survives a deleted layout dependency and rebuilds later changes" do
    with_tmp_dir do |tmp|
      write_commands_config(tmp)
      scaffold_commands_site(tmp)

      site_root = File.realpath(tmp)
      deleted_layout = File.join(site_root, "src", "layouts", "base.html")
      changed_asset = File.join(site_root, "src", "assets", "app.js")
      rebuilt = Channel(Array(String)).new(1)

      begin
        Creestal::Commands::Serve.watcher_runner = ->(_root : String, _interval : Int32, on_change : Proc(Array(String), Nil)) do
          File.delete(deleted_layout)
          on_change.call([deleted_layout])

          Creestal::Utils::FS.write_file(changed_asset, "console.log('watch');")
          on_change.call([changed_asset])
        end

        Creestal::Commands::Serve.server_start = ->(_server : Creestal::Server::Server) { nil }
        Creestal::Commands::Serve.on_rebuild = ->(paths : Array(String)) { rebuilt.send(paths) }

        Dir.cd(tmp) do
          Creestal::Commands::Serve.command.execute(["--config", "config.yml", "--watch"])
        end

        select
        when paths = rebuilt.receive
          paths.should eq([changed_asset])
        when timeout(2.seconds)
          raise "expected serve watch rebuild callback after layout deletion failure"
        end

        output_asset = File.join(tmp, "out", "assets", "app.js")
        File.exists?(output_asset).should be_true
        Creestal::Utils::FS.read_file(output_asset).should eq("console.log('watch');")
      ensure
        Creestal::Commands::Serve.reset_test_hooks!
      end
    end
  end

  it "serve --build runs a full build before serving" do
    with_tmp_dir do |tmp|
      write_commands_config(tmp)
      scaffold_commands_site(tmp)

      page_path = File.join(tmp, "src", "pages", "index.md")
      output_html = File.join(tmp, "out", "index.html")

      # Seed existing output with old content.
      Dir.cd(tmp) do
        Creestal::Commands::Build.command.execute(["--config", "config.yml"])
      end
      Creestal::Utils::FS.read_file(output_html).includes?("Hello").should be_true

      # Change source page but do not build.
      Creestal::Utils::FS.write_file(page_path, <<-MD)
---
title: Home
layout: base
---

# Hello from -b
MD

      begin
        Creestal::Commands::Serve.server_start = ->(_server : Creestal::Server::Server) { nil }

        Dir.cd(tmp) do
          Creestal::Commands::Serve.command.execute(["--config", "config.yml", "-b"])
        end

        Creestal::Utils::FS.read_file(output_html).includes?("Hello from -b").should be_true
      ensure
        Creestal::Commands::Serve.reset_test_hooks!
      end
    end
  end
end
