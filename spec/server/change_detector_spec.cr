require "../spec_helper"

describe Creestal::Server::ChangeDetector do
  it "detects new files" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "src")
      Creestal::Utils::FS.ensure_dir(root)

      detector = Creestal::Server::ChangeDetector.new(root)
      detector.poll.should eq([] of String)

      created = File.join(root, "new.txt")
      Creestal::Utils::FS.write_file(created, "hello")

      detector.poll.should contain(created)
    end
  end

  it "detects modified files" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "src")
      Creestal::Utils::FS.ensure_dir(root)
      path = File.join(root, "page.md")
      Creestal::Utils::FS.write_file(path, "one")

      detector = Creestal::Server::ChangeDetector.new(root)
      detector.poll.should eq([] of String)

      initial_mtime = File.info(path).modification_time
      tries = 0
      while File.info(path).modification_time == initial_mtime && tries < 20
        tries += 1
        Creestal::Utils::FS.write_file(path, "two-#{tries}")
        sleep 2.milliseconds
      end

      detector.poll.should contain(path)
    end
  end

  it "detects deleted files" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "src")
      Creestal::Utils::FS.ensure_dir(root)
      path = File.join(root, "gone.txt")
      Creestal::Utils::FS.write_file(path, "bye")

      detector = Creestal::Server::ChangeDetector.new(root)
      detector.poll.should eq([] of String)

      File.delete(path)

      detector.poll.should contain(path)
    end
  end

  it "does not report the same deletion repeatedly" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "src")
      Creestal::Utils::FS.ensure_dir(root)
      path = File.join(root, "once.txt")
      Creestal::Utils::FS.write_file(path, "bye")

      detector = Creestal::Server::ChangeDetector.new(root)
      detector.poll.should eq([] of String)

      File.delete(path)

      detector.poll.should contain(path)
      detector.poll.should eq([] of String)
    end
  end
end
