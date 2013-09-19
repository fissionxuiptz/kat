require 'minitest/autorun'
require File.dirname(__FILE__) + '/../../lib/kat/app'

app = Kat::App.new %w(aliens -c movies -o .)
app.kat.go(1).go(app.kat.pages - 1)

describe Kat::App do
  describe 'app' do
    it 'initialises options' do
      app.kat.must_be_instance_of Kat::Search
      app.options.must_be_instance_of Hash
      app.options[:category].must_equal 'movies'
      app.options[:category_given].must_equal true
    end

    it 're-initialises options' do
      k = Kat::App.new %w(aliens)
      k.init_options %w(bible -c books)
      k.options.must_be_instance_of Hash
      k.options[:category].must_equal 'books'
      k.options[:category_given].must_equal true
    end

    it 'creates a validation regex' do
      app.page.must_equal 0
      app.instance_exec {
        @window_width = 80

        prev?.wont_equal true
        next?.must_equal true
        validation_regex.must_equal(/^([inq]|[1-9]|1[0-9]|2[0-5])$/)

        @window_width = 81
        @page = 1

        prev?.must_equal true
        next?.must_equal true
        validation_regex.must_equal(/^([npq]|[1-9]|1[0-9]|2[0-5])$/)

        @page = kat.pages - 1
        n = kat.results[@page].size

        prev?.must_equal true
        next?.wont_equal true
        validation_regex.must_equal(
          /^([pq]|[1-#{ [9, n].min }]#{
          "|1[0-#{ [9, n - 10].min }]" if n > 9
          }#{ "|2[0-#{ n - 20 }]" if n > 19 })$/
        )

        @page = 0
      }
    end

    it 'deals with terminal width' do
      app.instance_exec {
        set_window_width
        hide_info?.must_equal (@window_width < 81)
      }
    end

    it 'formats a list of options' do
      app.instance_exec {
        %i(category added platform language).each { |s|
          list = format_lists(s => Kat::Search.selects[s])

          list.must_be_instance_of Array
          list.wont_be_empty

          [0, 2, list.size - 1].each { |i| list[i].must_be_nil }

          list[1].must_equal case s
          when :added    then 'Times'
          when :category then 'Categories'
          else                s.to_s.capitalize << 's'
          end

          3.upto(list.size - 2) { |i| list[i].must_be_instance_of String } unless s == :category
          3.upto(list.size - 2) { |i| list[i].must_match(/^\s*([A-Z]+ => )?[a-z0-9-]+/) if list[i] } if s == :category
        }
      }
    end

    it 'formats a list of torrents' do
      Kat::Colour.colour = false
      app.instance_exec {
        set_window_width
        list = format_results

        list.must_be_instance_of Array
        list.wont_be_empty

        list.size.must_equal kat.results[0].size + 3
        2.upto(list.size - 2) { |i|
          list[i].must_match /^(\s[1-9]|[12][0-9])\. .*/
        }
      }
    end

    it 'downloads data from a URL' do
      Kat::Colour.colour = false
      app.instance_exec {
        s = 'foobar'
        result = download({ download: 'http://google.com', title: s })
        result.must_equal :done
        File.exists?(File.expand_path "./#{ s }.torrent").must_equal true
        File.delete(File.expand_path "./#{ s }.torrent")
      }
    end

    it 'returns an error message when a download fails' do
      Kat::Colour.colour = false
      app.instance_exec {
        result = download({ download: 'http://foo.bar', title: 'foobar' })
        result.must_be_instance_of Array
        result.first.must_equal :failed
        result.last.must_match /^getaddrinfo/
      }
    end
  end
end
