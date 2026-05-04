module Creestal
  module Commands
    module Build
      def self.command : Argy::Command
        command = Argy::Command.new(use: "build", short: "Build static files from configured source directory", aliases: ["b"])
        command.flags.string("config", 'c', Creestal::DEFAULT_CONFIG_PATH, "Path to config file")

        command.on_run do |cmd, _args|
          cfg_flag = cmd.string_flag("config")
          config_path = File.expand_path(cfg_flag, Dir.current)
          raise Errors::ConfigFileNotFoundError.new("config file not found: #{config_path}") unless File.exists?(config_path)
          ctx = Core::Context.new(config_path)

          unless Dir.exists?(ctx.site_source)
            raise Errors::SourceDirectoryNotFoundError.new("source directory not found: #{ctx.site_source}")
          end

          Utils::FS.ensure_dir(ctx.site_output) if !Dir.exists?(ctx.site_output)

          _, elapsed = Utils::Timer.measure { Core::Builder.new(ctx).run }
          puts "-"*80
          puts "Done! Site built at: #{Utils::Printer.info(ctx.site_output)}"
          puts "Took: #{Utils::Printer.info(Utils::Timer.format(elapsed))}"
          puts "Serve with: creestal serve"
        end

        command
      end
    end
  end
end
