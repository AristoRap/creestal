require "../spec_helper"

def build_resource_page(tmp : String, filename : String, content : String)
  path = File.join(tmp, filename)
  Creestal::Utils::FS.write_file(path, content)
  entry = Creestal::Core::FileEntry.new("page", path, filename)
  Creestal::Core::Resources::Page.new(entry)
end

describe Creestal::Core::Resources::Page do
  it "parses frontmatter and markdown" do
    with_tmp_dir do |tmp|
      yaml = <<-YAML
title: My Title
tags:
- one
- two
draft: true
layout: custom
YAML

      content = <<-MD
---
#{yaml}
---
# Hello

This is a paragraph.
MD

      page = build_resource_page(tmp, "about.md", content)
      page.front_matter.title.should eq("My Title")
      page.front_matter.tags.should eq(["one", "two"])
      page.front_matter.draft.should be_true
      page.front_matter.layout.should eq("custom")
      page.output_content.includes?("Hello").should be_true
    end
  end

  it "accepts leading whitespace before frontmatter" do
    with_tmp_dir do |tmp|
      content = "\n  \n---\ntitle: T\n---\n# Hi\n"
      page = build_resource_page(tmp, "a.md", content)
      page.front_matter.title.should eq("T")
    end
  end

  it "raises MissingFrontmatterError when frontmatter missing" do
    with_tmp_dir do |tmp|
      begin
        build_resource_page(tmp, "a.md", "no frontmatter")
        raise "expected MissingFrontmatterError"
      rescue e
        e.should be_a(Creestal::Errors::MissingFrontmatterError)
      end
    end
  end

  it "raises UnclosedFrontmatterError when frontmatter not closed" do
    with_tmp_dir do |tmp|
      content = "---\ntitle: X\nno close"
      begin
        build_resource_page(tmp, "a.md", content)
        raise "expected UnclosedFrontmatterError"
      rescue e
        e.should be_a(Creestal::Errors::UnclosedFrontmatterError)
      end
    end
  end

  it "frontmatter defaults and types" do
    with_tmp_dir do |tmp|
      content = "---\ntitle: D\n---\n# H\n"
      page = build_resource_page(tmp, "d.md", content)
      (page.front_matter.tags || [] of String).size.should eq(0)
      page.front_matter.draft.should be_false
      page.front_matter.resolved_layout.should eq(Creestal::DEFAULT_LAYOUT)
    end
  end

  it "output_path uses html extension by default" do
    with_tmp_dir do |tmp|
      content = "---\ntitle: D\n---\n# H\n"
      page = build_resource_page(tmp, "about.md", content)
      page.output_path.should eq("about.html")
    end
  end
end
