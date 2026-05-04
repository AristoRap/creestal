module Creestal
  module Core
    module Resources
      class Base
        getter entry : Core::FileEntry
        getter path_without_ext : String
        getter depends_on : Array(String)

        def initialize(@entry : Core::FileEntry)
          @path_without_ext = Utils::FS.normalize_web_path(Utils::FS.strip_extension(@entry.relative_path))
          @depends_on = [] of String
        end

        def output_path(extension : String) : String
          Utils::FS.page_output_path(@entry.relative_path, extension)
        end

        def output_content : String
          @entry.content
        end

        def add_dependency(path : String)
          @depends_on << path
        end
      end
    end
  end
end
