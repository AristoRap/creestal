module Creestal
  module Server
    class Watcher
      def initialize(@detector : ChangeDetector, @interval_ms : Int32 = 500)
        @running = false
      end

      def start(&on_change : Array(String) -> Nil) : Nil
        @running = true
        while @running
          sleep @interval_ms.milliseconds
          changed = @detector.poll
          on_change.call(changed) unless changed.empty?
        end
      end

      def stop : Nil
        @running = false
      end
    end
  end
end
