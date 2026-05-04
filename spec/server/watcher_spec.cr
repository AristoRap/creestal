require "../spec_helper"

describe Creestal::Server::Watcher do
  it "invokes callback when detector reports changes" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "src")
      Creestal::Utils::FS.ensure_dir(root)

      changed = Channel(Array(String)).new(1)
      watcher = uninitialized Creestal::Server::Watcher
      detector = Creestal::Server::ChangeDetector.new(root)

      watcher = Creestal::Server::Watcher.new(detector, 5)

      spawn do
        watcher.start do |paths|
          changed.send(paths)
          watcher.stop
        end
      end

      touched = File.join(root, "new.css")
      Creestal::Utils::FS.write_file(touched, "body{}")

      select
      when paths = changed.receive
        paths.should contain(touched)
      when timeout(1.second)
        watcher.stop
        raise "expected watcher callback"
      end
    end
  end

  it "does not invoke callback when no changes are detected" do
    with_tmp_dir do |tmp|
      root = File.join(tmp, "src")
      Creestal::Utils::FS.ensure_dir(root)
      Creestal::Utils::FS.write_file(File.join(root, "stable.txt"), "same")
      detector = Creestal::Server::ChangeDetector.new(root)

      callback_count = Atomic(Int32).new(0)
      watcher = Creestal::Server::Watcher.new(detector, 5)

      spawn do
        watcher.start do |_paths|
          callback_count.add(1)
        end
      end
      sleep 40.milliseconds
      watcher.stop
      sleep 15.milliseconds

      callback_count.get.should eq(0)
    end
  end
end
