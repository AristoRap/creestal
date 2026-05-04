require "../spec_helper"

describe Creestal::Core::FileEntry do
  it "is unchanged right after initialization" do
    with_tmp_dir do |tmp|
      path = File.join(tmp, "page.md")
      Creestal::Utils::FS.write_file(path, "hello")

      entry = Creestal::Core::FileEntry.new("page", path, "page.md")
      entry.changed?.should be_false
    end
  end

  it "detects changes after file content mutates" do
    with_tmp_dir do |tmp|
      path = File.join(tmp, "page.md")
      Creestal::Utils::FS.write_file(path, "hello")

      entry = Creestal::Core::FileEntry.new("page", path, "page.md")
      Creestal::Utils::FS.write_file(path, "hello world")

      entry.changed?.should be_true
    end
  end

  it "reload! re-baselines the hash" do
    with_tmp_dir do |tmp|
      path = File.join(tmp, "page.md")
      Creestal::Utils::FS.write_file(path, "a")

      entry = Creestal::Core::FileEntry.new("page", path, "page.md")
      Creestal::Utils::FS.write_file(path, "b")
      entry.changed?.should be_true

      entry.reload!
      entry.changed?.should be_false
    end
  end

  it "reads latest content without mutating baseline" do
    with_tmp_dir do |tmp|
      path = File.join(tmp, "page.md")
      Creestal::Utils::FS.write_file(path, "first")

      entry = Creestal::Core::FileEntry.new("page", path, "page.md")
      Creestal::Utils::FS.write_file(path, "second")

      entry.content.should eq("second")
      entry.changed?.should be_true
    end
  end
end
