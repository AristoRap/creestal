module Creestal
  module Core
    struct SyncResult
      getter pages_to_render : Set(String)
      getter assets_to_copy : Set(String)
      getter ignored_paths : Array(String)

      def initialize(
        @pages_to_render = Set(String).new,
        @assets_to_copy = Set(String).new,
        @ignored_paths = [] of String,
      )
      end

      def merge!(other : SyncResult) : self
        @pages_to_render.concat(other.pages_to_render)
        @assets_to_copy.concat(other.assets_to_copy)
        @ignored_paths.concat(other.ignored_paths)
        self
      end
    end
  end
end
