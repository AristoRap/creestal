require "./errors"
require "./utils/*"
require "./core/*"
require "./server/*"
require "./cli"

# TODO: Write documentation for `Creestal`
module Creestal
  VERSION = "0.1.1"

  def self.run(argv : Array(String) = ARGV)
    CLI.run(argv)
  end
end

Creestal.run unless ENV["CREESTAL_ENV"]? == "test"
