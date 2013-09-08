module Kat

  module Colour

    COLOURS = { :black           => 30,
                :red             => 31,
                :green           => 32,
                :yellow          => 33,
                :blue            => 34,
                :magenta         => 35,
                :cyan            => 36,
                :white           => 37,

                :on_black        => 40,
                :on_red          => 41,
                :on_green        => 42,
                :on_yellow       => 43,
                :on_blue         => 44,
                :on_magenta      => 45,
                :on_cyan         => 46,
                :on_white        => 47,

                :bold_black      => 90,
                :bold_red        => 91,
                :bold_green      => 92,
                :bold_yellow     => 93,
                :bold_blue       => 94,
                :bold_magenta    => 95,
                :bold_cyan       => 96,
                :bold_white      => 97,

                :on_bold_black   => 100,
                :on_bold_red     => 101,
                :on_bold_green   => 102,
                :on_bold_yellow  => 103,
                :on_bold_blue    => 104,
                :on_bold_magenta => 105,
                :on_bold_cyan    => 106,
                :on_bold_white   => 107 }

    def respond_to? method, include_private = false
      return true if COLOURS.keys.include? method
      super
    end

  private

    def __colour code, args
      cstr = "\e[#{code}m%s\e[0m"
      if Kat::App.colour && STDOUT.tty?
        Array === args ?
          args.map {|arg| cstr % arg.to_s } :
          cstr % args.to_s
      else
        args
      end
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
