require "../spec_helper"

describe Creestal::Utils::FS do
  it "creates nested directories with ensure_dir" do
    with_tmp_dir do |tmp|
      path = File.join(tmp, "a", "b", "c")
      Creestal::Utils::FS.ensure_dir(path)
      Dir.exists?(path).should be_true
    end
  end

  it "writes and reads files" do
    with_tmp_dir do |tmp|
      path = File.join(tmp, "hello.txt")
      Creestal::Utils::FS.write_file(path, "hello world")
      Creestal::Utils::FS.read_file(path).should eq("hello world")
    end
  end

  it "raises FileNotFoundError when reading missing file" do
    with_tmp_dir do |tmp|
      path = File.join(tmp, "nope.txt")
      begin
        Creestal::Utils::FS.read_file(path)
        raise "expected Creestal::Errors::FileNotFoundError"
      rescue e
        e.should be_a(Creestal::Errors::FileNotFoundError)
      end
    end
  end

  it "copies a single file to a nested destination" do
    with_tmp_dir do |tmp|
      src = File.join(tmp, "src.txt")
      File.write(src, "copy me")

      dest = File.join(tmp, "nested", "dest.txt")
      Creestal::Utils::FS.copy_file(src, dest)

      File.exists?(dest).should be_true
      Creestal::Utils::FS.read_file(dest).should eq("copy me")
    end
  end

  it "copies a directory recursively" do
    with_tmp_dir do |tmp|
      src_dir = File.join(tmp, "from")
      nested = File.join(src_dir, "sub")
      Creestal::Utils::FS.ensure_dir(nested)
      File.write(File.join(src_dir, "a.txt"), "a")
      File.write(File.join(nested, "b.txt"), "b")

      dest_dir = File.join(tmp, "to")
      Creestal::Utils::FS.copy_dir(src_dir, dest_dir)

      File.exists?(File.join(dest_dir, "a.txt")).should be_true
      File.exists?(File.join(dest_dir, "sub", "b.txt")).should be_true
      Creestal::Utils::FS.read_file(File.join(dest_dir, "sub", "b.txt")).should eq("b")
    end
  end

  it "finds files by extension and returns sorted paths" do
    with_tmp_dir do |tmp|
      File.write(File.join(tmp, "b.md"), "b")
      File.write(File.join(tmp, "a.md"), "a")
      File.write(File.join(tmp, "other.txt"), "x")

      results = Creestal::Utils::FS.find_files_in_dir_by_extension(tmp, "md")
      results.map { |p| File.basename(p) }.should eq(["a.md", "b.md"])
    end
  end

  it "cleanup_dir removes a directory" do
    with_tmp_dir do |tmp|
      dir = File.join(tmp, "to_remove")
      Creestal::Utils::FS.ensure_dir(dir)
      Creestal::Utils::FS.cleanup_dir(dir)
      Dir.exists?(dir).should be_false
    end
  end
end
