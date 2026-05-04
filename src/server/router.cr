module Creestal
  module Server
    class Router
      def initialize(@root : String, @home : String)
        @css = {} of String => String
        @js = {} of String => String
        @html = {} of String => String
        setup
      end

      def resolve_request(path : String) : String
        path = normalize_request_path(decode_path(path))
        if is_home?(path)
          home_path = "#{@home}.html"
          return @html[home_path]? || @html["index.html"]? || ""
        end

        path = path.lchop('/')
        if path.ends_with?(".html") || path.split(".").size == 1
          return handle_html(path)
        end

        if @css.has_key?(path)
          @css[path]
        elsif @js.has_key?(path)
          @js[path]
        else
          ""
        end
      end

      private def is_home?(path : String) : Bool
        path == "/" || path == @home || path == "#{@home}.html" || path.empty?
      end

      private def decode_path(path : String) : String
        URI.decode(path)
      rescue ArgumentError
        ""
      end

      private def normalize_request_path(path : String) : String
        Utils::FS.normalize_web_path(path)
      end

      def handle_html(path : String) : String
        return @html[path] if path.ends_with?(".html") && @html.has_key?(path)

        path = "#{path}.html"
        @html.has_key?(path) ? @html[path] : ""
      end

      private def setup
        css_files = Utils::FS.find_files_in_dir_by_extension(@root, ".css")
        css_files.each do |f|
          rel_path = Utils::FS.normalize_web_path(Path.new(f).relative_to(@root).to_s)
          @css[rel_path] = f
        end

        js_files = Utils::FS.find_files_in_dir_by_extension(@root, ".js")
        js_files.each do |f|
          rel_path = Utils::FS.normalize_web_path(Path.new(f).relative_to(@root).to_s)
          @js[rel_path] = f
        end

        html_files = Utils::FS.find_files_in_dir_by_extension(@root, ".html")
        html_files.each do |f|
          rel_path = Utils::FS.normalize_web_path(Path.new(f).relative_to(@root).to_s)
          @html[rel_path] = f
        end
      end
    end
  end
end
