module Creestal
  module Commands
    module New
      def self.command : Argy::Command
        command = Argy::Command.new(use: "new [name]", short: "Create a new site")
        command.flags.bool("force", 'f', false, "Force overwrite existing files")

        command.on_run do |cmd, args|
          name = args[0]?
          raise Errors::ProjectNameRequiredError.new("project name is required") unless name

          force = cmd.bool_flag("force") || false

          output_dir = Core::Generator.new(name, force).run
          puts "-"*80
          puts "Done! Site created at: #{Utils::Printer.info(output_dir)}"
          puts "-"*80
          puts "Next steps:"
          puts "  cd #{output_dir.gsub(Dir.current, ".")}"
          puts "  creestal serve"
        end

        command
      end
    end
  end
end
