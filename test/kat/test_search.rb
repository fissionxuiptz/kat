require 'minitest/autorun'
require File.dirname(__FILE__) + '/../../lib/kat/search'

blue_peter = Kat.search
blue_peter.go.go 1

describe Kat::Search do

  let(:kat) { Kat.search 'test' }
  let(:kat_opts) { Kat.search 'test', { category: 'books' } }

  describe 'basic search' do
    it 'returns a full result set' do
      Kat.quick_search('test').size.must_equal 25
    end
  end

  describe 'advanced search' do
    it 'returns a valid query string' do
      blue_peter.query_str.must_equal 'new/'
      blue_peter.query_str(1).must_equal 'new/2/'
      kat.query_str.must_equal 'usearch/test/'
      kat_opts.query_str(1).must_equal 'usearch/test category:books/2/'
      kat_opts.query = :foobar
      kat_opts.query_str(1).must_equal 'usearch/foobar category:books/2/'
      kat_opts.query = [0, {}, [:test, 0..1, ['user:foo']]]
      kat_opts.query_str(1).must_equal 'usearch/test user:foo category:books/2/'
    end

    it 'returns a valid query string based on many options' do
      kat_opts.options = { files: 2, safe: true, language: 2, sort: :files_count, asc: true, seeds: 2 }
      kat_opts.query_str(1).must_equal 'usearch/test files:2 seeds:2 safe:1 category:books lang_id:2/2/?field=files_count&sorder=asc'
    end

    it 'wont respond to result fields before a search' do
      %i(titles files).each { |s|
        kat.respond_to?(s).must_equal false
      }
    end

    it 'responds to result fields after a search' do
      %i(titles files).each { |s|
        blue_peter.respond_to?(s).must_equal true
      }
    end

    it 'returns identical result sets' do
      blue_peter.results[0].must_equal blue_peter.search
    end

    it 'returns a full result set' do
      blue_peter.search(1).size.must_equal 25
      blue_peter.titles.size.must_equal 50
    end

    it 'returns a valid query string with options' do
      bp = blue_peter.dup
      bp.options = { user: :foobar }
      bp.options.must_equal({ user: :foobar })
      bp.query_str(1).must_equal 'usearch/user:foobar/2/'
      bp.results.must_be_empty
      bp.pages.must_equal(-1)
    end

    it 'can raise an ArgumentError for query=' do
      proc { kat.query = 0 }.must_raise ArgumentError
    end

    it 'can raise an ArgumentError for options=' do
      proc { kat.options = 'foobar' }.must_raise ArgumentError
    end

    it 'works when there are fewer than 25 results' do
      kat.options = { category: :wallpapers }
      kat.search.wont_be_nil
      kat.search.size.wont_equal 0
      kat.pages.must_equal 1
    end

    it 'can return 0 results, set an error and set pages to 0' do
      kat.query = 'owijefbvoweivf'
      kat.search.must_be_nil
      kat.pages.must_equal 0
    end
  end

  describe 'field options' do
    it 'returns a list of time added options' do
      times = Kat::Search.times
      times.must_be_instance_of Hash
      times.wont_be_empty
      times[:error].must_be_nil
    end

    it 'returns a list of categories' do
      categories = Kat::Search.categories
      categories.must_be_instance_of Hash
      categories.wont_be_empty
      categories[:error].must_be_nil
    end

    it 'returns a list of languages' do
      languages = Kat::Search.languages
      languages.must_be_instance_of Hash
      languages.wont_be_empty
      languages[:error].must_be_nil
    end

    it 'returns a list of platforms' do
      platforms = Kat::Search.platforms
      platforms.must_be_instance_of Hash
      platforms.wont_be_empty
      platforms[:error].must_be_nil
    end

    it 'returns an error' do
      Kat::Search.class_exec { field_options :foobar }[:error].must_be_instance_of RuntimeError
    end
  end
end
