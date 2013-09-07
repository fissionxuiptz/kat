module Kat

  module Colour

    COLOURS = { :black   => 30, :red     => 31, :green   => 32, :yellow  => 33,
                :blue    => 34, :magenta => 35, :cyan    => 36, :white   => 37 }

    def respond_to? method, include_private = false
      return true if COLOURS.keys.include? method
      super
    end

  private

    def __colour code, args
      cstr = "\e[#{code}m%s\e[0m"
      STDOUT.tty? ? (Array === args ? args.map {|arg| cstr % arg.to_s } : cstr % args.to_s) : args
    end

    def method_missing method, *args, &block
      return __colour COLOURS[method], self if respond_to? method
      super
    end
  end

end

class String; include Kat::Colour; end
class Symbol; include Kat::Colour; end
class Array;  include Kat::Colour; end
