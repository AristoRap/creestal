require "../scaffold/pages"
require "../scaffold/layouts"
require "../scaffold/partials"
require "../scaffold/assets"
require "../scaffold/scripts"

module Creestal
  module Core
    struct GeneratorContext
      getter app_name : String
      getter source : String

      def initialize(@app_name : String, @source : String)
      end
    end

    class Generator
      getter app_name : String

      def initialize(@app_name : String, @force : Bool = false)
        @config = Config.new(@app_name)
        @cwd = Dir.current
        @app_dir = File.join(@cwd, app_name)
        @ctx = Core::GeneratorContext.new(@app_name, @config.source)
      end

      def run : String
        setup
        @app_dir
      end

      private def setup
        # Create app directory
        setup_base

        # Create source directory
        app_src_path = setup_src

        # Create pages  directory
        setup_pages(app_src_path)

        # Create partials directory
        setup_partials(app_src_path)

        # Create assets directory
        setup_assets(app_src_path)

        # Create layouts directory
        setup_layouts(app_src_path)

        # Create output directory
        app_output_path = File.join(@app_dir, @config.output)
        mkdir_and_log(app_output_path)
      end

      private def setup_base
        if Dir.exists?(@app_dir) && !@force
          app_text = Utils::Printer.info(@app_name)
          err_text = Utils::Printer.error("Error:")
          message = "#{err_text} `#{app_text}` #{Utils::Printer.error("already exists in:")} #{@cwd}"
          puts message
          puts Utils::Printer.warn("Use --force/-f to overwrite existing files")
          exit 1
        end
        puts "-"*80
        puts "Creating site '#{Utils::Printer.info(@app_name)}' #{Utils::Printer.accent(@force ? "[force]" : "")}"
        puts "-"*80

        # Create app directory
        Utils::FS.ensure_dir(@app_dir)

        # Create config file
        app_cfg_path = File.join(@app_dir, Creestal::DEFAULT_CONFIG_PATH)
        mkfile_and_log(app_cfg_path, @config.to_yaml)

        # # Create scripts
        # scripts_scaffold = Scaffold::Scripts.new(@ctx)
        # scripts_scaffold.resources.each do |r|
        #   resource_path = File.join(@app_dir, r[:file])
        #   mkfile_and_log(resource_path, r[:rendered])
        # end
      end

      private def setup_src : String
        app_src_path = File.join(@app_dir, @config.source)
        mkdir_and_log(app_src_path)

        app_src_path
      end

      private def setup_pages(app_src_path : String)
        app_pages_path = File.join(app_src_path, "pages")
        mkdir_and_log(app_pages_path)

        pages_scaffold = Scaffold::Pages.new(@ctx)
        pages_scaffold.resources.each do |r|
          resource_path = File.join(app_pages_path, r[:file])
          mkfile_and_log(resource_path, r[:rendered])
        end
      end

      private def setup_layouts(app_src_path : String)
        app_layouts_path = File.join(app_src_path, "layouts")
        mkdir_and_log(app_layouts_path)

        layouts_scaffold = Scaffold::Layouts.new(@ctx)
        layouts_scaffold.resources.each do |r|
          resource_path = File.join(app_layouts_path, r[:file])
          mkfile_and_log(resource_path, r[:rendered])
        end
      end

      private def setup_partials(app_src_path : String)
        # Create partials directory
        app_partials_path = File.join(app_src_path, "partials")
        mkdir_and_log(app_partials_path)

        partials_scaffold = Scaffold::Partials.new(@ctx)
        partials_scaffold.resources.each do |r|
          resource_path = File.join(app_partials_path, r[:file])
          mkfile_and_log(resource_path, r[:rendered])
        end
      end

      private def setup_assets(app_src_path : String)
        app_assets_path = File.join(app_src_path, "assets")
        Utils::FS.ensure_dir(app_assets_path)

        assets_scaffold = Scaffold::Assets.new(@ctx)
        assets_scaffold.resources.each do |r|
          asset_path = File.join(app_assets_path, r[:file])
          parent_dir = File.dirname(asset_path)
          mkdir_and_log(parent_dir)
          mkfile_and_log(asset_path, r[:rendered])
        end
      end

      private def mkdir_and_log(directory : String)
        return if Dir.exists?(directory)

        Utils::FS.ensure_dir(directory)
        rel_dir = directory == @app_dir ? @app_name : Path.new(directory).relative_to(@app_dir)
        result = String.build do |builder|
          builder << Utils::Printer.success("[create]")
          builder << " [dir]  "
          builder << Utils::Printer.info(rel_dir)
        end

        puts result
      end

      private def mkfile_and_log(file_path : String, file_content : String)
        Utils::FS.write_file(file_path, file_content)
        rel_file = Path.new(file_path).relative_to(@app_dir)
        result = String.build do |builder|
          builder << Utils::Printer.success("[create]")
          builder << " [file] "
          builder << Utils::Printer.info(rel_file)
        end

        puts result
      end
    end
  end
end
