require_relative 'field_map'
require_relative 'version'
require 'trollop'

module Kat
  #
  # Convenience method for the Options class
  #
  def self.options(args)
    Options.parse args
  end

  class Options
    #
    # Pick out the invocation options from the field map
    #
    def self.options_map
      fields = %i(desc type multi select short)

      FIELD_MAP.reduce({}) do |hash, (k, v)|
        hash.tap { |h| h[k] = v.select { |f| fields.include? f } if v[:desc] }
      end
    end

    def self.parse(args)
      Trollop.options(args) do
        version VERSION_STR
        banner <<-USAGE.gsub(/^\s+\|/, '')
          |#{ VERSION_STR }
          |
          |Usage: #{ File.basename __FILE__ } [options] <query>+
          |
          |  Options:
        USAGE

        Options.options_map.each do |k, v|
          opt k,
              v[:desc],
              type:  v[:type] || :boolean,
              multi: v[:multi],
              short: v[:short]
        end

        Options.options_map.each do |k, v|
          opt v[:select],
              "List the #{ v[:select] } that may be used with --#{ k }",
              short: :none if v[:select]
        end
      end
    end
  end
end
