require 'minitest/autorun'
require File.dirname(__FILE__) + '/../../lib/kat/colour'

describe Kat::Colour do
  let(:colours) { %i(black red green yellow blue magenta cyan white) }

  describe 'colour' do
    it 'has working flag methods' do
      Kat::Colour.capable?.must_equal true
      Kat::Colour.colour = false
      Kat::Colour.colour?.must_equal false
      Kat::Colour.colour = true
      Kat::Colour.colour?.must_equal true
    end

    it 'has colour methods' do
      colours.each { |c|
        ''.respond_to?(c).must_equal true
        :s.respond_to?(c).must_equal true
        [].respond_to?(c).must_equal true
        {}.respond_to?(c).wont_equal true
      }
    end

    it 'colours strings' do
      colours.each_with_index { |c, i|
        str = 'foobar'
        result = "\e[0;#{ 30 + i }mfoobar\e[0m"
        intense_result = "\e[1;#{ 30 + i }mfoobar\e[0m"

        str.send(c).must_equal result
        str.must_equal 'foobar'

        str.send(c, true).must_equal intense_result
        str.must_equal 'foobar'

        str.send("#{ c }!").must_equal result
        str.must_equal result

        str = 'foobar'
        str.send("#{ c }!", true).must_equal intense_result
        str.must_equal intense_result
      }
    end

    it 'uncolour strings' do
      str = "\e[0;30mfoobar\e[0m"
      result = str.dup

      str.uncolour.must_equal 'foobar'
      str.must_equal result

      str.uncolour!.must_equal 'foobar'
      str.must_equal 'foobar'
    end

    it 'colours symbols' do
      colours.each_with_index { |c, i|
        sym = :foobar
        result = "\e[0;#{ 30 + i }mfoobar\e[0m"
        intense_result = "\e[1;#{ 30 + i }mfoobar\e[0m"

        sym.send(c).must_equal result
        sym.must_equal :foobar

        sym.send(c, true).must_equal intense_result
        sym.must_equal :foobar

        sym.send("#{ c }!").must_equal :foobar
        sym.must_equal :foobar

        sym.send("#{ c }!", true).must_equal :foobar
        sym.must_equal :foobar
      }
    end

    it 'does not uncolour symbols' do
      sym = :foobar

      sym.uncolour.must_equal :foobar
      sym.must_equal :foobar

      sym.uncolour!.must_equal :foobar
      sym.must_equal :foobar
    end

    it 'colours arrays of strings and symbols' do
      colours.each_with_index { |c, i|
        s = ['foobar', :foobar, nil, ['foobar', :foobar, nil]]
        t = ['foobar', :foobar, nil, ['foobar', :foobar, nil]]
        result = [
          "\e[0;#{ 30 + i }mfoobar\e[0m",
          "\e[0;#{ 30 + i }mfoobar\e[0m",
          nil,
          ["\e[0;#{ 30 + i }mfoobar\e[0m",
           "\e[0;#{ 30 + i }mfoobar\e[0m",
           nil]
        ]

        s.send(c).must_equal result
        s.must_equal t

        result[1] = :foobar
        result[3][1] = :foobar
        s.send("#{ c }!").must_equal result
        s.must_equal result
      }
    end

    it 'uncolours arrays of strings' do
      s = [
        "\e[0;30mfoobar\e[0m",
        :foobar,
        nil,
        ["\e[0;30mfoobar\e[0m",
         :foobar,
         nil]
      ]
      t = [
        "\e[0;30mfoobar\e[0m",
        :foobar,
        nil,
        ["\e[0;30mfoobar\e[0m",
         :foobar,
         nil]
      ]
      result = ['foobar', :foobar, nil, ['foobar', :foobar, nil]]

      s.uncolour.must_equal result
      s.must_equal t

      s.uncolour!.must_equal result
      s.must_equal result
    end
  end
end
