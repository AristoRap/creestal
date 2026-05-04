module Creestal
  module Core
    class SiteGraph
      struct PageNode
        getter title : String
        getter source_path : String
        getter output_path : String
        getter url : String
        getter date : Time?
        getter tags : Array(String)
        getter draft : Bool

        def initialize(
          @title : String,
          @source_path : String,
          @output_path : String,
          @url : String,
          @date : Time?,
          @tags : Array(String),
          @draft : Bool,
        )
        end
      end

      getter nav : Array(PageNode)
      getter posts : Array(PageNode)
      getter all_pages : Array(PageNode)

      def to_context(page : Resources::Page)
        {
          "nav"         => serialize(@nav),
          "posts"       => serialize(@posts),
          "all_pages"   => serialize(@all_pages),
          "breadcrumbs" => serialize(breadcrumbs_for(page)),
        }
      end

      def self.empty : SiteGraph
        new([] of Resources::Page)
      end

      def initialize(pages : Enumerable(Resources::Page))
        @all_pages = pages.map { |p| to_page_node(p) }.to_a.sort_by { |node| {node.output_path, node.title} }
        @posts = @all_pages
          .select { |node| !node.draft && node.source_path.starts_with?("blog/") }
          .sort_by { |node| {sort_date(node.date), node.output_path} }
        @nav = @all_pages
          .select { |node| !node.draft && !node.source_path.starts_with?("blog/") }
          .sort_by { |node| {node.title.downcase, node.output_path} }
      end

      def breadcrumbs_for(page : Resources::Page) : Array(PageNode)
        path = page.path_without_ext
        by_source = @all_pages.each_with_object({} of String => PageNode) do |node, memo|
          memo[node.source_path] = node
        end

        crumbs = [] of PageNode
        if (home = by_source["index"]?)
          crumbs << home
        end

        current = ""
        segments = path.split('/')
        segments.each do |segment|
          current = current.empty? ? segment : "#{current}/#{segment}"
          node = by_source[current]?
          crumbs << node if node && !crumbs.includes?(node)
        end

        crumbs
      end

      private def to_page_node(page : Resources::Page) : PageNode
        output = page.output_path
        url = output == "index.html" ? "/" : "/#{output.gsub(/\.html$/, "")}"

        PageNode.new(
          title: page.title,
          source_path: page.path_without_ext,
          output_path: output,
          url: url,
          date: page.front_matter.date,
          tags: page.front_matter.tags || [] of String,
          draft: page.front_matter.draft || false,
        )
      end

      private def sort_date(date : Time?)
        date ? -date.to_unix : Int64::MAX
      end

      private def serialize(nodes : Array(PageNode))
        nodes.map do |node|
          {
            "title"       => node.title,
            "source_path" => node.source_path,
            "output_path" => node.output_path,
            "url"         => node.url,
            "date"        => node.date,
            "tags"        => node.tags,
            "draft"       => node.draft,
          }
        end
      end
    end
  end
end
