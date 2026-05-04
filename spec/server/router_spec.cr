require "../spec_helper"

describe Creestal::Server::Router do
  it "resolves home when configured home file exists" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "out")
      Creestal::Utils::FS.ensure_dir(root)

      home = File.join(root, "index.html")
      Creestal::Utils::FS.write_file(home, "<h1>Home</h1>")

      router = Creestal::Server::Router.new(root, "index")
      router.resolve_request("/").should eq(home)
    end
  end

  it "does not raise when configured home file is missing" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "out")
      Creestal::Utils::FS.ensure_dir(root)

      router = Creestal::Server::Router.new(root, "index")
      router.resolve_request("/").should eq("")
    end
  end

  it "falls back to index.html when configured home file is missing" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "out")
      Creestal::Utils::FS.ensure_dir(root)

      index_file = File.join(root, "index.html")
      Creestal::Utils::FS.write_file(index_file, "<h1>Fallback</h1>")

      router = Creestal::Server::Router.new(root, "home")
      router.resolve_request("/").should eq(index_file)
    end
  end

  it "resolves html and assets case-insensitively against lowercase output paths" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "out")
      Creestal::Utils::FS.ensure_dir(File.join(root, "blog"))
      Creestal::Utils::FS.ensure_dir(File.join(root, "assets", "images"))

      html_file = File.join(root, "blog", "first-post.html")
      asset_file = File.join(root, "assets", "images", "logo.css")
      Creestal::Utils::FS.write_file(html_file, "<h1>Post</h1>")
      Creestal::Utils::FS.write_file(asset_file, "body { color: red; }")

      router = Creestal::Server::Router.new(root, "index")
      router.resolve_request("/Blog/First-Post").should eq(html_file)
      router.resolve_request("/ASSETS/IMAGES/LOGO.CSS").should eq(asset_file)
    end
  end
end
