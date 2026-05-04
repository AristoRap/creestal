require "./resources/*"

module Creestal
  module Core
    class Site
      getter pages : Hash(String, Resources::Page)
      getter layouts : Hash(String, Resources::Layout)
      getter partials : Hash(String, FileEntry)
      getter assets : Hash(String, FileEntry)
      getter graph : SiteGraph

      def initialize(@ctx : Core::Context)
        @pages = {} of String => Resources::Page
        @layouts = {} of String => Resources::Layout
        @partials = {} of String => FileEntry
        @assets = {} of String => FileEntry
        @graph = SiteGraph.empty
        # Reverse dependency index: source path -> Set of paths that must
        # rebuild when it changes. Populated during parse, used during sync
        # to replace full-collection scans with O(1) lookups.
        @dependents = {} of String => Set(String)
      end

      def sync(changed_file : String) : SyncResult
        full_path = File.expand_path(changed_file)
        return sync_deleted(full_path) unless File.exists?(full_path)

        entry = @ctx.entry_for(full_path)
        result = SyncResult.new

        case entry.type
        when "page"
          existing = @pages[entry.full_path]?
          if existing.nil?
            page = parse_page(entry)
            @pages[entry.full_path] = page
            recompute_graph!
            result.pages_to_render << page.entry.full_path
          elsif existing.entry.changed?
            evict_dependencies(existing)
            page = parse_page(entry)
            @pages[entry.full_path] = page
            recompute_graph!
            result.pages_to_render << page.entry.full_path
          end
        when "layout"
          existing = @layouts[entry.full_path]?
          if existing.nil?
            layout = parse_layout(entry)
            @layouts[entry.full_path] = layout
            pages_depending_on(layout.entry.full_path).each do |page_path|
              result.pages_to_render << page_path
            end
          elsif existing.entry.changed?
            evict_dependencies(existing)
            layout = parse_layout(entry)
            @layouts[entry.full_path] = layout
            pages_depending_on(layout.entry.full_path).each do |page_path|
              result.pages_to_render << page_path
            end
          end
        when "asset"
          existing = @assets[entry.full_path]?
          if existing.nil?
            @assets[entry.full_path] = entry
            result.assets_to_copy << entry.full_path
          elsif existing.changed?
            result.assets_to_copy << existing.full_path
            existing.reload!
          end
        when "partial"
          existing = @partials[entry.full_path]?
          if existing.nil?
            @partials[entry.full_path] = entry
            # A new partial won't be included by any layout until that layout
            # is re-parsed, so there's nothing to cascade-build yet.
          elsif existing.changed?
            pages_depending_on_partial(existing.full_path).each do |page_path|
              result.pages_to_render << page_path
            end
            existing.reload!
          end
        when "out_of_bounds"
          result.ignored_paths << entry.full_path
        end

        result
      end

      private def source_type_for(full_path : String) : String
        return "page" if full_path.includes?(@ctx.pages_path)
        return "layout" if full_path.includes?(@ctx.layouts_path)
        return "partial" if full_path.includes?(@ctx.partials_path)
        return "asset" if full_path.includes?(@ctx.assets_src_path)

        "out_of_bounds"
      end

      def setup!
        parse_assets
        parse_partials
        parse_layouts
        parse_pages
        recompute_graph!
      end

      # Parses all source files then returns every output target required for
      # a full build. Builder owns the I/O execution of this plan.
      def full_sync_result : SyncResult
        setup!
        SyncResult.new(
          pages_to_render: @pages.keys.to_set,
          assets_to_copy: @assets.keys.to_set,
        )
      end

      def partials_by_basename
        @partials.transform_keys { |k| Path.new(k).stem }
      end

      def layouts_by_basename
        @layouts.transform_keys { |k| Path.new(k).stem }
      end

      # Registers a reverse dependency: when source changes, dependent must rebuild.
      private def register_dependency(source : String, dependent : String)
        @dependents[source] ||= Set(String).new
        @dependents[source] << dependent
      end

      # Removes all reverse-dependency registrations for a resource before
      # re-parsing it, so stale entries don't accumulate in the index.
      # Only applies to Resources::Base subclasses (pages, layouts) since those
      # are the only types that carry forward depends_on entries.
      private def evict_dependencies(resource : Resources::Base)
        resource.depends_on.each do |source_path|
          @dependents[source_path]?.try &.delete(resource.entry.full_path)
        end
      end

      private def parse_page(file : FileEntry) : Resources::Page
        page = Resources::Page.new(file)
        layout_name = page.front_matter.resolved_layout
        layout = layouts_by_basename[layout_name]? || raise Errors::LayoutNotFoundError.new("Layout not found: '#{layout_name}' (referenced by #{file.relative_path})")
        page.add_dependency(layout.entry.full_path)
        register_dependency(layout.entry.full_path, file.full_path)
        page
      end

      private def parse_pages(ext : String = "md") : Nil
        @ctx.get_page_entries(ext).each do |f|
          @pages[f.full_path] = parse_page(f)
        end
      end

      private def parse_assets : Nil
        @ctx.get_asset_entries.each do |f|
          @assets[f.full_path] = f
        end
      end

      private def parse_layout(file : FileEntry) : Resources::Layout
        layout = Resources::Layout.new(file, @ctx.site_source, @ctx.partials_path)
        layout.include_deps.each do |include_path|
          partial = partial_for_include(include_path) || raise Errors::PartialNotFoundError.new("Partial not found: '#{include_path}' (referenced by #{file.relative_path})")
          layout.add_dependency(partial.full_path)
          register_dependency(partial.full_path, file.full_path)
        end
        layout
      end

      private def partial_for_include(include_path : String) : FileEntry?
        normalized = include_path.strip
        normalized = normalized.sub(/^\.\//, "")
        normalized = normalized.sub(/^partials\//, "")

        candidates = [normalized]
        candidates << "#{normalized}.html" if File.extname(normalized).empty?

        candidates.each do |candidate|
          full_path = File.join(@ctx.partials_path, candidate)
          partial = @partials[full_path]?
          return partial if partial
        end

        nil
      end

      private def parse_layouts : Nil
        @ctx.get_layout_entries.each do |f|
          @layouts[f.full_path] = parse_layout(f)
        end
      end

      private def parse_partials : Nil
        @ctx.get_partial_entries.each do |f|
          @partials[f.full_path] = f
        end
      end

      private def recompute_graph! : Nil
        @graph = SiteGraph.new(@pages.values)
      end

      private def pages_depending_on(layout_path : String) : Set(String)
        pages = Set(String).new
        (@dependents[layout_path]? || Set(String).new).each do |page_path|
          pages << page_path if @pages.has_key?(page_path)
        end
        pages
      end

      private def pages_depending_on_partial(partial_path : String) : Set(String)
        pages = Set(String).new
        (@dependents[partial_path]? || Set(String).new).each do |layout_path|
          pages.concat(pages_depending_on(layout_path)) if @layouts.has_key?(layout_path)
        end
        pages
      end

      private def sync_deleted(full_path : String) : SyncResult
        result = SyncResult.new

        case source_type_for(full_path)
        when "page"
          deleted_page = @pages.delete(full_path)
          unless deleted_page.nil?
            evict_dependencies(deleted_page)
            @dependents.delete(full_path)
            output_path = File.join(@ctx.site_output, deleted_page.output_path)
            File.delete(output_path) if File.exists?(output_path)
            recompute_graph!
          end
        when "layout"
          affected_pages = pages_depending_on(full_path)
          deleted_layout = @layouts.delete(full_path)
          unless deleted_layout.nil?
            evict_dependencies(deleted_layout)
            @dependents.delete(full_path)
            unless affected_pages.empty?
              raise Errors::LayoutDeletedWithDependentsError.new("Layout deleted: #{deleted_layout.entry.relative_path}; rebuild blocked for dependent pages: #{affected_pages.to_a.join(", ")}")
            end
          end
        when "partial"
          affected_pages = pages_depending_on_partial(full_path)
          @partials.delete(full_path)
          @dependents.delete(full_path)
          unless affected_pages.empty?
            relative = Path.new(full_path).relative_to(@ctx.partials_path).to_s
            raise Errors::PartialDeletedWithDependentsError.new("Partial deleted: #{relative}; rebuild blocked for dependent pages: #{affected_pages.to_a.join(", ")}")
          end
        when "asset"
          deleted_asset = @assets.delete(full_path)
          unless deleted_asset.nil?
            output_path = File.join(@ctx.assets_out_path, Utils::FS.asset_output_path(deleted_asset.relative_path))
            File.delete(output_path) if File.exists?(output_path)
          end
        else
          result.ignored_paths << full_path
        end

        result
      end
    end
  end
end
