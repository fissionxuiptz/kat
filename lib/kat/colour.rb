module Kat

  module Colour

    COLOURS = %w(black red green yellow blue magenta cyan white)

    class << self
      def colour=(f); @@colour = f && capable? end
      def colour?; @@colour end
      # From AwesomePrint.colorize? by Michael Dvorkin
      # https://github.com/michaeldv/awesome_print/blob/master/lib/awesome_print/inspector.rb
      def capable?; (STDOUT.tty? && ((ENV['TERM'] && ENV['TERM'] != 'dumb') || ENV['ANSICON'])) end
    end

    @@colour = capable?

    def colour?; @@colour end

    def uncolour
      case self
      when String then gsub /\e\[[0-9;]+?m(.*?)\e\[0m/, '\\1'
      when Array  then map {|e| e.uncolour }
      else self
      end
    end

    def uncolour!
      case self
      when String then replace uncolour
      when Array  then each {|e| e.uncolour! }
      end
      self
    end

    def respond_to? method, include_private = false
      return true if COLOURS.include? method.to_s or (not Symbol === self and COLOURS.include? method[/^.*(?=!$)/])
      super
    end

  private

    def colour name, intense = false
      return case self
      when String, Symbol then "\e[#{intense ? 1 : 0};#{30 + COLOURS.index(name)}m#{self}\e[0m"
      when Array          then map {|e| e.send name, intense }
      end if colour?
      self
    end

    def colour! name, intense = false
      case self
      when String then replace send(name, intense)
      when Array  then each {|e| e.send "#{name}!", intense }
      end if colour?
      self
    end

    def method_missing method, *args, &block
      return send "colour#{method[/!$/]}", method[/[^!]+/], args[0] if respond_to? method
      super
    end
  end

end

class String; include Kat::Colour end
class Symbol; include Kat::Colour end
class Array;  include Kat::Colour end
