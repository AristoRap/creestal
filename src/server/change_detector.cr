module Creestal
  module Server
    class ChangeDetector
      @baseline : Hash(String, Time)

      def initialize(@watch_root : String)
        @baseline = snapshot
      end

      # Returns every path that was created, modified, or deleted since last poll.
      def poll : Array(String)
        fresh = snapshot
        changed = diff(@baseline, fresh)
        @baseline = fresh unless changed.empty?
        changed
      end

      private def watched_files : Array(String)
        Dir.glob(File.join(@watch_root, "**", "*")).select { |path| File.file?(path) }
      end

      private def snapshot : Hash(String, Time)
        watched_files.each_with_object({} of String => Time) do |path, h|
          h[path] = File.info(path).modification_time
        end
      end

      private def diff(baseline : Hash(String, Time), fresh : Hash(String, Time)) : Array(String)
        changed = [] of String

        fresh.each do |path, mtime|
          previous = baseline[path]?
          changed << path if previous.nil? || previous != mtime
        end

        baseline.each_key do |path|
          changed << path unless fresh.has_key?(path)
        end

        changed
      end
    end
  end
end
