module Creestal
  module Errors
    class CreestalError < Exception
    end

    class CommandError < CreestalError
    end

    class ProjectNameRequiredError < CommandError
    end

    class ConfigFileNotFoundError < CommandError
    end

    class SourceDirectoryNotFoundError < CommandError
    end

    class BuildError < CreestalError
    end

    class MissingLayoutDependencyError < BuildError
    end

    class LayoutNotFoundError < BuildError
    end

    class PartialNotFoundError < BuildError
    end

    class LayoutDeletedWithDependentsError < BuildError
    end

    class PartialDeletedWithDependentsError < BuildError
    end

    class OutputPathCollisionError < BuildError
    end

    class PageOutputPathCollisionError < OutputPathCollisionError
    end

    class AssetOutputPathCollisionError < OutputPathCollisionError
    end

    class FileSystemError < CreestalError
    end

    class FileNotFoundError < FileSystemError
    end

    class FileReadError < FileSystemError
    end

    class FileWriteError < FileSystemError
    end

    class FileCopyError < FileSystemError
    end

    class DirCleanupError < FileSystemError
    end

    class ParsingError < CreestalError
    end

    class MissingFrontmatterError < ParsingError
    end

    class UnclosedFrontmatterError < ParsingError
    end

    class RouteError < CreestalError
    end
  end
end
