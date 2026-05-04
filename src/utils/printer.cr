require "colorize"

module Creestal
  module Utils
    module Printer
      def self.info(message)
        message.colorize(:cyan)
      end

      def self.error(message)
        message.colorize(:red)
      end

      def self.warn(message)
        message.colorize(:yellow)
      end

      def self.success(message)
        message.colorize(:green)
      end

      def self.debug(message)
        message.colorize(:blue)
      end

      def self.accent(message)
        message.colorize(:magenta)
      end
    end
  end
end
