require "argy"

require "./commands/*"

module Creestal
  class CLI
    def self.root : Argy::Command
      root = Argy::Command.new(use: "creestal", short: "Minimal static site generator")

      root.add_command(Commands::New.command)
      root.add_command(Commands::Build.command)
      root.add_command(Commands::Serve.command)
      root
    end

    def self.run(argv : Array(String) = ARGV)
      root.execute(argv)
    end
  end
end
