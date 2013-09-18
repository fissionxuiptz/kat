module Kat

  module Colour

    COLOURS = %w(black red green yellow blue magenta cyan white)

    class << self
      # From AwesomePrint.colorize? by Michael Dvorkin
      # https://github.com/michaeldv/awesome_print/blob/master/lib/awesome_print/inspector.rb
      def capable?
        STDOUT.tty? && (ENV['TERM'] && ENV['TERM'] != 'dumb' || ENV['ANSICON'])
      end

      def colour=(f)
        @@colour = f && capable?
      end

      def colour?
        @@colour
      end
    end

    @@colour = capable?

    def colour?
      @@colour
    end

    COLOURS.each { |c|
      define_method(c) { |*args| colour c, args[0] }
      define_method("#{ c }!") { |*args| colour! c, args[0] }
    }

    def uncolour
      case self
      when String then gsub /\e\[[0-9;]+?m(.*?)\e\[0m/, '\\1'
      when Array  then map { |e| e.uncolour if e }
      else self
      end
    end

    def uncolour!
      case self
      when String then replace uncolour
      when Array  then each { |e| e.uncolour! if e }
      end

      self
    end

  private

    def colour(name, intense = false)
      return case self
             when String, Symbol then "\e[#{ intense ? 1 : 0 };#{ 30 + COLOURS.index(name) }m#{ self }\e[0m"
             when Array          then map { |e| e.send name.to_s, intense if e }
             end if colour?

      self
    end

    def colour!(name, intense = false)
      case self
      when String then replace send(name.to_s, intense)
      when Array  then each { |e| e.send "#{ name.to_s }!", intense if e }
      end if colour?

      self
    end

  end

end

class String; include Kat::Colour end
class Symbol; include Kat::Colour end
class Array;  include Kat::Colour end
