require "yaml"
require "markd"
require "./base"

module Creestal
  module Core
    module Resources
      struct FrontMatter
        include YAML::Serializable

        getter title : String
        getter date : Time?
        getter tags : Array(String)? = [] of String
        getter draft : Bool? = false
        # Stored as nilable so YAML::Serializable can deserialize an absent or
        # explicit-null field without raising. Callers should use #resolved_layout,
        # which always returns a non-nil String.
        getter layout : String? = nil

        # Returns the declared layout name, falling back to DEFAULT_LAYOUT when
        # the field was absent or explicitly null in the front matter.
        def resolved_layout : String
          layout.presence || Creestal::DEFAULT_LAYOUT
        end
      end

      class Page < Base
        getter front_matter : FrontMatter
        getter markdown : String

        def initialize(@entry : Core::FileEntry)
          super(@entry)

          parsed = parse_entry
          @front_matter = parsed[:front_matter]
          @markdown = parsed[:markdown]
        end

        def output_path(extension : String = "html") : String
          super(extension)
        end

        def output_content : String
          Markd.to_html(@markdown)
        end

        def title : String
          @front_matter.title
        end

        def date : Time?
          @front_matter.date
        end

        def tags : Array(String)
          @front_matter.tags || [] of String
        end

        def draft : Bool
          @front_matter.draft || false
        end

        def layout_name : String
          @front_matter.resolved_layout
        end

        def content : String
          output_content
        end

        def parse_entry : NamedTuple(front_matter: FrontMatter, markdown: String)
          md_content = @entry.content.lstrip
          raise Creestal::Errors::MissingFrontmatterError.new("Missing frontmatter") unless md_content.starts_with?("---")
          # Find the closing ---
          rest = md_content[3..] # skip opening ---
          close = rest.index("\n---")
          raise Creestal::Errors::UnclosedFrontmatterError.new("Unclosed frontmatter") unless close
          yaml_src = rest[0...close]
          markdown = rest[close + 4..].lstrip # skip closing ---\n

          {
            front_matter: FrontMatter.from_yaml(yaml_src),
            markdown:     markdown,
          }
        end
      end
    end
  end
end
