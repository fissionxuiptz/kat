require 'minitest/autorun'

begin
  require 'minitest/reporters'
  MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new
rescue LoadError
end

require 'kat'

blue_peter = Kat.new
blue_peter.do_search.do_search 1

describe Kat do

  let(:kat) { Kat.new 'test' }
  let(:kat_opts) { Kat.new 'test', { :category => 'books' } }

  describe 'basic search' do
    it 'returns a full result set' do
      Kat.search('test').size.must_equal 25
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
      kat_opts.query = [ 0, {}, [ :test, 0..1, [ 'user:foo' ] ] ]
      kat_opts.query_str(1).must_equal 'usearch/test user:foo category:books/2/'
    end

    it 'returns a valid query string based on many options' do
      kat_opts.options = { :files => 2, :safe => true, :language => 2, :sort => :files_count, :asc => true, :seeds => 2 }
      kat_opts.query_str(1).must_equal 'usearch/test category:books seeds:2 files:2 lang_id:2 safe:1/2/?field=files_count&sorder=asc'
    end

    it 'wont respond to result fields before a search' do
      [ :titles, :files ].each do |s|
        kat.respond_to?(s).must_equal false
      end
    end

    it 'responds to result fields after a search' do
      [ :titles, :files ].each do |s|
        blue_peter.respond_to?(s).must_equal true
      end
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
      bp.options = { :user => :foobar }
      bp.options.must_equal({ :user => :foobar })
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
      kat.options = { :category => :wallpapers }
      kat.search.wont_be_nil
      kat.search.size.wont_equal 0
      kat.pages.must_equal 1
    end

    it 'can return 0 results, set an error and set pages to 0' do
      kat.query = 'owijefbvoweivf'
      kat.search.must_be_nil
      kat.error[:error].must_be_instance_of OpenURI::HTTPError
      kat.error[:error].message.must_equal '404 Not Found'
      kat.pages.must_equal 0
    end

  end

end
