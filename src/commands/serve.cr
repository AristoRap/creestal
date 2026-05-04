require "uri"
require "http"

module Creestal
  module Commands
    module Serve
      @@watcher_runner : Proc(String, Int32, Proc(Array(String), Nil), Nil) = ->(watch_root : String, interval_ms : Int32, on_change : Proc(Array(String), Nil)) do
        detector = Server::ChangeDetector.new(watch_root)
        watcher = Server::Watcher.new(detector, interval_ms)
        watcher.start do |paths|
          on_change.call(paths)
        end
      end

      @@server_start : Proc(Server::Server, Nil) = ->(server : Server::Server) do
        server.start
      end

      @@on_rebuild : Proc(Array(String), Nil)? = nil

      def self.watcher_runner=(runner : Proc(String, Int32, Proc(Array(String), Nil), Nil))
        @@watcher_runner = runner
      end

      def self.server_start=(runner : Proc(Server::Server, Nil))
        @@server_start = runner
      end

      def self.on_rebuild=(runner : Proc(Array(String), Nil)?)
        @@on_rebuild = runner
      end

      def self.reset_test_hooks! : Nil
        @@watcher_runner = ->(watch_root : String, interval_ms : Int32, on_change : Proc(Array(String), Nil)) do
          detector = Server::ChangeDetector.new(watch_root)
          watcher = Server::Watcher.new(detector, interval_ms)
          watcher.start do |paths|
            on_change.call(paths)
          end
        end

        @@server_start = ->(server : Server::Server) do
          server.start
        end

        @@on_rebuild = nil
      end

      def self.command : Argy::Command
        command = Argy::Command.new(use: "serve", short: "Serve static files from configured output directory", aliases: ["s", "srv"])
        command.flags.string("config", 'c', Creestal::DEFAULT_CONFIG_PATH, "Path to config file")
        command.flags.string("host", nil, Creestal::DEFAULT_HOST, "Host to bind")
        command.flags.bool("watch", 'w', false, "Watch for changes and reload")
        command.flags.bool("build", 'b', false, "Run a full build before serving")
        command.flags.int("port", 'p', Creestal::DEFAULT_PORT, "Port to listen on")

        command.on_run do |cmd, _args|
          cfg_flag = cmd.string_flag("config")
          host = cmd.string_flag("host")
          port = cmd.int_flag("port")
          watch = cmd.bool_flag("watch")
          force_build = cmd.bool_flag("build")
          config_path = File.expand_path(cfg_flag, Dir.current)
          raise Errors::ConfigFileNotFoundError.new("config file not found: #{config_path}") unless File.exists?(config_path)

          ctx = Core::Context.new(config_path)

          # Always do a full build first so the output directory is complete and
          # the returned Site carries all parsed state for incremental updates.
          builder = Core::Builder.new(ctx)
          site = if force_build || !Dir.exists?(ctx.site_output) || Dir.empty?(ctx.site_output)
                   builder.run
                 else
                   # Output already exists — still need a populated Site for the watcher.
                   site_obj = Core::Site.new(ctx)
                   site_obj.setup!
                   site_obj
                 end

          server = Server::Server.new(ctx.site_output, ctx.config.home, host, port, watch)

          if watch
            reload_ch = Channel(Array(String)).new

            # Watcher fiber — detects changes, signals
            spawn do
              on_change = Proc(Array(String), Nil).new { |paths| reload_ch.send(paths) }
              @@watcher_runner.call(ctx.site_source, ctx.config.watcher_interval_ms, on_change)
            end

            # Rebuild + broadcast fiber — waits for signal
            spawn do
              loop do
                paths = reload_ch.receive
                begin
                  site, elapsed = Utils::Timer.measure { Core::Builder.new(ctx, site).run_incremental(paths) }
                  puts "File change: #{paths.join(", ")} | rebuilt | took #{Utils::Printer.info(Utils::Timer.format(elapsed))}"
                  server.broadcast_reload
                  @@on_rebuild.try &.call(paths)
                rescue e : Errors::BuildError
                  puts Utils::Printer.error("File change: #{paths.join(", ")} | rebuild failed | #{e.message}")
                end
              end
            end
          end

          puts "Serving #{ctx.site_output} at http://#{host}:#{port}#{" (watching)" if watch}"
          @@server_start.call(server)
        end

        command
      end
    end
  end
end
