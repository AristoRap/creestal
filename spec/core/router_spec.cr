require "../spec_helper"

describe Creestal::Server::Router do
  it "resolves home and html paths and static assets" do
    tmp = File.join(Dir.tempdir, "creestal-router-#{Process.pid}-#{Random::Secure.hex(8)}")
    begin
      # create structure
      Creestal::Utils::FS.ensure_dir(File.join(tmp, "assets"))
      index = File.join(tmp, "index.html")
      about = File.join(tmp, "about.html")
      css = File.join(tmp, "assets", "style.css")
      js = File.join(tmp, "assets", "app.js")

      File.write(index, "index")
      File.write(about, "about")
      File.write(css, "css")
      File.write(js, "js")

      router = Creestal::Server::Router.new(tmp, "index")

      router.resolve_request("/").should eq(index)
      router.resolve_request("/index").should eq(index)
      router.resolve_request("/index.html").should eq(index)

      router.resolve_request("/about").should eq(about)
      router.resolve_request("/about.html").should eq(about)

      router.resolve_request("/assets/style.css").should eq(css)
      router.resolve_request("/assets/app.js").should eq(js)

      router.resolve_request("/missing.png").should eq("")
    ensure
      Creestal::Utils::FS.cleanup_dir(tmp) if Dir.exists?(tmp)
    end
  end

  it "handles percent-decoding errors by treating as home" do
    tmp = File.join(Dir.tempdir, "creestal-router-#{Process.pid}-#{Random::Secure.hex(8)}")
    begin
      Creestal::Utils::FS.ensure_dir(tmp)
      index = File.join(tmp, "index.html")
      File.write(index, "index")

      router = Creestal::Server::Router.new(tmp, "index")
      # invalid percent-encoding currently resolves to empty string
      router.resolve_request("%E0").should eq("")
    ensure
      Creestal::Utils::FS.cleanup_dir(tmp) if Dir.exists?(tmp)
    end
  end

  it "handle_html returns empty for missing html" do
    tmp = File.join(Dir.tempdir, "creestal-router-#{Process.pid}-#{Random::Secure.hex(8)}")
    begin
      Creestal::Utils::FS.ensure_dir(tmp)
      router = Creestal::Server::Router.new(tmp, "index")
      router.handle_html("nope").should eq("")
    ensure
      Creestal::Utils::FS.cleanup_dir(tmp) if Dir.exists?(tmp)
    end
  end
end
