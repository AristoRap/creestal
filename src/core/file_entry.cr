require "digest/sha256"

module Creestal
  module Core
    class FileEntry
      getter full_path : String
      getter relative_path : String
      getter type : String
      getter sha256 : String

      def initialize(@type : String, @full_path : String, @relative_path : String)
        @sha256 = calc_sha256(read_content)
      end

      # Re-baselines the stored hash to the current file contents.
      # Call this after a change has been detected and acted on so that
      # subsequent changed? calls measure from the new baseline.
      def reload! : FileEntry
        @sha256 = calc_sha256(read_content)
        self
      end

      # Pure read — never touches @sha256.
      def content : String
        read_content
      end

      # True if the file on disk differs from the baseline set at
      # construction or the last reload!.
      def changed? : Bool
        @sha256 != calc_sha256(read_content)
      end

      private def read_content : String
        Utils::FS.read_file(@full_path)
      end

      private def calc_sha256(file_content : String) : String
        Digest::SHA256.hexdigest(file_content)
      end
    end
  end
end
