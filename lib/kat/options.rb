require File.dirname(__FILE__) + '/field_map'
require File.dirname(__FILE__) + '/version'
require 'trollop'

module Kat

  class << self
    #
    # Convenience method for the Options class
    #
    def options(args)
      Options.parse args
    end
  end

  class Options

    class << self
      #
      # Pick out the invocation options from the field map
      #
      def options_map
        fields = %i(desc type multi select short)

        FIELD_MAP.inject({}) { |hash, (k, v)|
          hash.tap { |h| h[k] = v.select { |f| fields.include? f } if v[:desc] }
        }
      end

      def parse(args)
        Trollop::options(args) {
          version VERSION_STR
          banner <<-USAGE.gsub /^\s+\|/, ''
            |#{ VERSION_STR }
            |
            |Usage: #{ File.basename __FILE__ } [options] <query>+
            |
            |  Options:
          USAGE

          Options.options_map.each { |k, v|
            opt k,
                v[:desc],
                { type:  v[:type] || :boolean,
                  multi: v[:multi],
                  short: v[:short] }
          }

          Options.options_map.each { |k, v|
            opt v[:select],
                "List the #{ v[:select] } that may be used with --#{ k }",
                short: :none if v[:select]
          }
        }
      end
    end

  end
end
