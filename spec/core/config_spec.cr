require "../spec_helper"

describe Creestal::Core::Config do
  it "returns defaults when config file is missing" do
    tmp = File.join(Dir.tempdir, "creestal-config-#{Process.pid}-#{Random::Secure.hex(8)}")
    path = File.join(tmp, "missing.yml")
    begin
      cfg = Creestal::Core::Config.load(path)
      cfg.site.should eq(Creestal::DEFAULT_SITE_NAME)
      cfg.home.should eq("index")
      cfg.source.should eq(Creestal::DEFAULT_SOURCE_DIR)
      cfg.output.should eq(Creestal::DEFAULT_OUTPUT_DIR)
      cfg.default_layout.should eq(Creestal::DEFAULT_LAYOUT)
    ensure
      Creestal::Utils::FS.cleanup_dir(tmp) if Dir.exists?(tmp)
    end
  end

  it "returns defaults when YAML parses to non-hash" do
    tmp = File.join(Dir.tempdir, "creestal-config-#{Process.pid}-#{Random::Secure.hex(8)}")
    begin
      Creestal::Utils::FS.ensure_dir(tmp)
      path = File.join(tmp, "config.yml")
      File.write(path, "- a\n- b\n")

      cfg = Creestal::Core::Config.load(path)
      cfg.site.should eq(Creestal::DEFAULT_SITE_NAME)
    ensure
      Creestal::Utils::FS.cleanup_dir(tmp) if Dir.exists?(tmp)
    end
  end

  it "loads provided string values from YAML" do
    tmp = File.join(Dir.tempdir, "creestal-config-#{Process.pid}-#{Random::Secure.hex(8)}")
    begin
      Creestal::Utils::FS.ensure_dir(tmp)
      path = File.join(tmp, "config.yml")
      contents = <<-YAML
site: My Site
home: home_page
source: content
output: public
default_layout: custom
YAML
      File.write(path, contents)

      cfg = Creestal::Core::Config.load(path)
      cfg.site.should eq("My Site")
      cfg.home.should eq("home_page")
      cfg.source.should eq("content")
      cfg.output.should eq("public")
      cfg.default_layout.should eq("custom")
    ensure
      Creestal::Utils::FS.cleanup_dir(tmp) if Dir.exists?(tmp)
    end
  end

  it "partials fall back to defaults" do
    tmp = File.join(Dir.tempdir, "creestal-config-#{Process.pid}-#{Random::Secure.hex(8)}")
    begin
      Creestal::Utils::FS.ensure_dir(tmp)
      path = File.join(tmp, "config.yml")
      File.write(path, "site: Partial Site\n")

      cfg = Creestal::Core::Config.load(path)
      cfg.site.should eq("Partial Site")
      cfg.source.should eq(Creestal::DEFAULT_SOURCE_DIR)
    ensure
      Creestal::Utils::FS.cleanup_dir(tmp) if Dir.exists?(tmp)
    end
  end

  it "non-string values for string keys fall back to defaults" do
    tmp = File.join(Dir.tempdir, "creestal-config-#{Process.pid}-#{Random::Secure.hex(8)}")
    begin
      Creestal::Utils::FS.ensure_dir(tmp)
      path = File.join(tmp, "config.yml")
      File.write(path, "site: 123\n")

      cfg = Creestal::Core::Config.load(path)
      cfg.site.should eq(Creestal::DEFAULT_SITE_NAME)
    ensure
      Creestal::Utils::FS.cleanup_dir(tmp) if Dir.exists?(tmp)
    end
  end
end
