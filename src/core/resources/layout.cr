require "./base"
require "crinja"

module Creestal
  module Core
    module Resources
      class Layout < Base
        getter include_deps : Array(String)

        def initialize(@entry : Core::FileEntry, @site_source : String, @partials_path : String)
          super(@entry)
          @include_deps = extract_include_deps(@entry.content)
        end

        def output_path(extension : String = "html") : String
          super(extension)
        end

        def output_content(page : Resources::Page, site_graph : Core::SiteGraph) : String
          env = Crinja.new
          env.loader = Crinja::Loader::FileSystemLoader.new([@partials_path, @site_source])
          template = env.from_string(@entry.content)
          active_page = page.path_without_ext
          env.functions["is_active"] = Crinja.function({current: "", value: ""}, :is_active) do
            arguments["current"].as_s == active_page ? arguments["value"].as_s : ""
          end

          page_context = {
            "title"       => page.title,
            "date"        => page.date,
            "tags"        => page.tags,
            "draft"       => page.draft,
            "layout"      => page.layout_name,
            "content"     => page.content,
            "output_path" => page.output_path,
            "source_path" => page.path_without_ext,
          }

          template.render({
            "active_page" => active_page,
            "page"        => page_context,
            "site"        => site_graph.to_context(page),
          })
        end

        private def extract_include_deps(template_source : String) : Array(String)
          source = template_source.gsub(/\{#.*?#\}/m, "")
          source
            .scan(/\{%\s*include\s+["']([^"']+)["'][^%]*%\}/)
            .map(&.[1])
            .uniq
        end
      end
    end
  end
end
