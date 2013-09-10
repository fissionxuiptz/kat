require File.dirname(__FILE__) + '/field_map'
require File.dirname(__FILE__) + '/version'
require 'trollop'

module Kat

  class << self
    #
    # Convenience method for the Options class
    #
    def options args = []
      Options.new(args).parse
    end
  end

  class Options

    class << self
      def options_map
        FIELD_MAP.inject({}) do |hash, (k, v)|
          hash.tap {|h| h[k] = v.select {|f| %i(desc type multi select short).include? f } if v[:desc] }
        end
      end
    end

    def initialize args = nil
      @args = args || []
    end

    def parse args = nil
      Trollop::options(args || @args) do
        version VERSION_STR
        banner <<-USAGE
#{VERSION_STR}

Usage: #{File.basename __FILE__} [options] <query>+

  Options:
USAGE
        Options.options_map.each {|k, v| opt k, v[:desc], { :type => v[:type] || :boolean, :multi => v[:multi], :short => v[:short] } }
        Options.options_map.each {|k, v| opt v[:select], "List the #{v[:select]} that may be used with --#{k}", :short => :none if v[:select] }
      end
    end

  end
end
