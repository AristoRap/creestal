module Creestal
  module Core
    class Context
      getter config : Core::Config
      getter site_root : String
      getter site_source : String
      getter site_output : String
      getter assets_src_path : String
      getter assets_out_path : String
      getter layouts_path : String
      getter partials_path : String
      getter pages_path : String

      def initialize(config_path : String)
        @config = Core::Config.load(config_path)
        # Root
        @site_root = File.dirname(config_path)
        # Source
        @site_source = File.join(@site_root, @config.source)
        @assets_src_path = File.join(@site_source, "assets")
        @layouts_path = File.join(@site_source, "layouts")
        @partials_path = File.join(@site_source, "partials")
        @pages_path = File.join(@site_source, "pages")
        # Output
        @site_output = File.join(@site_root, @config.output)
        @assets_out_path = File.join(@site_output, "assets")
      end

      def entry_for(filepath : String) : FileEntry
        real_path = File.realpath(filepath)
        if real_path.includes?(@pages_path)
          build_file_entry("page", real_path, @pages_path)
        elsif real_path.includes?(@layouts_path)
          build_file_entry("layout", real_path, @layouts_path)
        elsif real_path.includes?(@partials_path)
          build_file_entry("partial", real_path, @partials_path)
        elsif real_path.includes?(@assets_src_path)
          build_file_entry("asset", real_path, @assets_src_path)
        else
          build_file_entry("out_of_bounds", real_path, real_path)
        end
      end

      def get_page_entries(extension : String = "md") : Array(FileEntry)
        Utils::FS.find_files_in_dir_by_extension(@pages_path, extension).map do |f|
          build_file_entry("page", f, @pages_path)
        end
      end

      def get_layout_entries(extension : String = "html") : Array(FileEntry)
        Utils::FS.find_files_in_dir_by_extension(@layouts_path, extension).map do |f|
          build_file_entry("layout", f, @layouts_path)
        end
      end

      def get_partial_entries(extension : String = "html") : Array(FileEntry)
        Utils::FS.find_files_in_dir_by_extension(@partials_path, extension).map do |f|
          build_file_entry("partial", f, @partials_path)
        end
      end

      def get_asset_entries : Array(FileEntry)
        allowed_extensions = ["css", "js"]
        allowed_extensions.flat_map do |ext|
          Utils::FS.find_files_in_dir_by_extension(@assets_src_path, ext).map do |f|
            build_file_entry("asset", f, @assets_src_path)
          end
        end
      end

      private def path_relative_to(path : String, parent : String) : String
        Path.new(path).relative_to(parent).to_s
      end

      private def build_file_entry(type : String, file_path : String, prefix_path : String) : FileEntry
        FileEntry.new(
          type: type,
          full_path: file_path,
          relative_path: path_relative_to(file_path, prefix_path),
        )
      end
    end
  end
end
