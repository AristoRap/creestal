require "spec"

ENV["CREESTAL_ENV"] = "test"
require "../src/creestal"

def with_tmp_dir(prefix : String = "creestal-spec", &)
  path = File.join(Dir.tempdir, "#{prefix}-#{Process.pid}-#{Random::Secure.hex(8)}")
  Creestal::Utils::FS.ensure_dir(path)

  begin
    yield path
  ensure
    Creestal::Utils::FS.cleanup_dir(path) if Dir.exists?(path)
  end
end
