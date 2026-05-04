require "../spec_helper"

describe Creestal::Core::SyncResult do
  it "merges page and asset sets" do
    left = Creestal::Core::SyncResult.new(
      pages_to_render: Set{"/tmp/page-a.md"},
      assets_to_copy: Set{"/tmp/a.css"},
    )

    right = Creestal::Core::SyncResult.new(
      pages_to_render: Set{"/tmp/page-b.md"},
      assets_to_copy: Set{"/tmp/b.js"},
    )

    left.merge!(right)

    left.pages_to_render.should eq(Set{"/tmp/page-a.md", "/tmp/page-b.md"})
    left.assets_to_copy.should eq(Set{"/tmp/a.css", "/tmp/b.js"})
  end

  it "preserves set uniqueness across multiple merges" do
    result = Creestal::Core::SyncResult.new(
      pages_to_render: Set{"/tmp/page-a.md"},
      assets_to_copy: Set{"/tmp/a.css"},
    )

    duplicate = Creestal::Core::SyncResult.new(
      pages_to_render: Set{"/tmp/page-a.md"},
      assets_to_copy: Set{"/tmp/a.css"},
    )

    result.merge!(duplicate)

    result.pages_to_render.size.should eq(1)
    result.assets_to_copy.size.should eq(1)
  end

  it "appends ignored paths in merge order" do
    left = Creestal::Core::SyncResult.new(ignored_paths: ["one"])
    right = Creestal::Core::SyncResult.new(ignored_paths: ["two", "three"])

    left.merge!(right)

    left.ignored_paths.should eq(["one", "two", "three"])
  end
end
