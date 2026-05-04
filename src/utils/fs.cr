require "file_utils"

module Creestal
  module Utils
    module FS
      def self.ensure_dir(path : String) : Nil
        FileUtils.mkdir_p(path)
      end

      def self.copy_dir(source_path : String, destination_path : String) : Nil
        begin
          FileUtils.cp_r(source_path, destination_path)
        rescue e : Exception
          raise Creestal::Errors::FileCopyError.new(e.message)
        end
      end

      def self.copy_file(source_path : String, destination_path : String) : Nil
        parent = File.dirname(destination_path)
        ensure_dir(parent)
        begin
          FileUtils.cp(source_path, destination_path)
        rescue e : Exception
          raise Creestal::Errors::FileCopyError.new(e.message)
        end
      end

      def self.write_file(path : String, content : String) : Nil
        parent = File.dirname(path)
        ensure_dir(parent)
        begin
          File.write(path, content)
        rescue e : Exception
          raise Creestal::Errors::FileWriteError.new(e.message)
        end
      end

      def self.read_file(path : String) : String
        unless File.exists?(path)
          raise Creestal::Errors::FileNotFoundError.new("File not found: #{path}")
        end

        begin
          File.read(path)
        rescue e : Exception
          raise Creestal::Errors::FileReadError.new(e.message)
        end
      end

      def self.cleanup_dir(path : String) : Nil
        begin
          FileUtils.rm_r(path)
        rescue e : Exception
          raise Creestal::Errors::DirCleanupError.new(e.message)
        end
      end

      def self.find_files_in_dir_by_extension(directory : String, extension : String) : Array(String)
        extension = extension.starts_with?(".") ? extension : ".#{extension}"

        Dir.glob(File.join(directory, "**", "*#{extension}")).sort
      end

      def self.strip_extension(path : String) : String
        as_path = Path.new(path)
        as_path.to_s.sub(as_path.extension, "")
      end

      def self.normalize_web_path(path : String) : String
        path.gsub('\\', '/').downcase
      end

      def self.page_output_path(relative_path : String, extension : String = "html") : String
        ext = extension.starts_with?(".") ? extension : ".#{extension}"
        "#{normalize_web_path(strip_extension(relative_path))}#{ext}"
      end

      def self.asset_output_path(relative_path : String) : String
        normalize_web_path(relative_path)
      end
    end
  end
end
