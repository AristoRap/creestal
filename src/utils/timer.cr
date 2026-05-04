module Creestal
  module Utils
    module Timer
      # Measures elapsed monotonic time for a block and returns block result plus duration.
      def self.measure(&block : -> T) : {T, Time::Span} forall T
        started_at = Time.instant
        result = yield
        elapsed = Time.instant - started_at
        {result, elapsed}
      end

      def self.format(duration : Time::Span) : String
        ms = duration.total_milliseconds
        return "#{ms.round(1)}ms" if ms < 1000.0

        "#{(ms / 1000.0).round(2)}s"
      end
    end
  end
end
