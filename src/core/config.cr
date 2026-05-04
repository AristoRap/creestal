require "yaml"

module Creestal
  DEFAULT_CONFIG_PATH         = "config.yml"
  DEFAULT_SOURCE_DIR          = "src"
  DEFAULT_OUTPUT_DIR          = "out"
  DEFAULT_SITE_NAME           = "New Creestal Site"
  DEFAULT_LAYOUT              = "base"
  DEFAULT_HOST                = "localhost"
  DEFAULT_PORT                = 3000
  DEFAULT_WATCHER_INTERVAL_MS =  500

  module Core
    class Config
      include YAML::Serializable

      getter site : String
      getter home : String
      getter source : String
      getter output : String
      getter default_layout : String
      getter watcher_interval_ms : Int32

      def self.load(config_path : String) : Config
        return new unless File.exists?(config_path)

        cfg_content = Utils::FS.read_file(config_path)
        parsed = YAML.parse(cfg_content).as_h?
        return new unless parsed

        site = string_value(parsed, "site") || Creestal::DEFAULT_SITE_NAME
        home = string_value(parsed, "home") || "index"
        source = string_value(parsed, "source") || Creestal::DEFAULT_SOURCE_DIR
        output = string_value(parsed, "output") || Creestal::DEFAULT_OUTPUT_DIR
        default_layout = string_value(parsed, "default_layout") || Creestal::DEFAULT_LAYOUT
        watcher_interval_ms = int_value(parsed, "watcher_interval_ms") || DEFAULT_WATCHER_INTERVAL_MS

        new(
          site: site,
          home: home,
          source: source,
          output: output,
          default_layout: default_layout,
          watcher_interval_ms: watcher_interval_ms
        )
      end

      def initialize(
        @site : String = Creestal::DEFAULT_SITE_NAME,
        @home : String = "index",
        @source : String = Creestal::DEFAULT_SOURCE_DIR,
        @output : String = Creestal::DEFAULT_OUTPUT_DIR,
        @default_layout : String = Creestal::DEFAULT_LAYOUT,
        @watcher_interval_ms : Int32 = DEFAULT_WATCHER_INTERVAL_MS,
      )
      end

      private def self.string_value(parsed : Hash(YAML::Any, YAML::Any), key : String) : String?
        parsed[key]?.try(&.as_s?)
      end

      private def self.bool_value(parsed : Hash(YAML::Any, YAML::Any), key : String) : Bool?
        parsed[key]?.try(&.as_bool?)
      end

      private def self.int_value(parsed : Hash(YAML::Any, YAML::Any), key : String) : Int32?
        parsed[key]?.try(&.as_i?)
      end
    end
  end
end
