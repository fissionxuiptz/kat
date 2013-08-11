require 'minitest/autorun'
require 'minitest/pride'
require 'kat'

describe Kat do
  before do
    @kat = { :vanilla  => Kat.new,
             :basic    => Kat.new('test'),
             :advanced => Kat.new('test', { :category => 'books' }) }
  end

# Quick search tests

  describe 'when quick searching' do
    it 'returns a result set' do
      Kat.search('test').must_be_instance_of Array
      Kat.search('test').size.must_equal 25
    end
  end

# Vanilla query tests

  describe 'when checking if a vanilla query responds to result field before searching' do
    it 'returns false' do
      [ :titles, :magnets, :downloads, :sizes, :files, :ages, :seeds, :leeches ].each do |s|
        @kat[:vanilla].respond_to?(s).must_equal false
      end
    end
  end

  describe 'when checking if a vanilla query responds to result fields after searching' do
    it 'returns true' do
      @kat[:vanilla].search
      [ :titles, :magnets, :downloads, :sizes, :files, :ages, :seeds, :leeches ].each do |s|
        @kat[:vanilla].respond_to?(s).must_equal true
      end
    end
  end

  describe 'when building a vanilla query' do
    it 'returns a query to new torrents' do
      @kat[:vanilla].query.must_equal 'new/'
    end
  end

  describe 'when searching with a vanilla query' do
    it 'returns a full result set' do
      @kat[:vanilla].search.must_be_instance_of Array
      [ :search, :titles, :magnets, :downloads, :sizes, :files, :ages, :seeds, :leeches ].each do |s|
        @kat[:vanilla].send(s).size.must_equal 25
      end
    end
  end

  describe 'when searching the 2nd page of a vanilla query' do
    it 'returns a full result set' do
      @kat[:vanilla].search(1).must_be_instance_of Array
      @kat[:vanilla].search(1).size.must_equal 25
    end
  end

  describe 'when searching 2 pages of a vanilla query' do
    it 'returns 50 results for each result field' do
      @kat[:vanilla].search
      @kat[:vanilla].search(1)
      [ :titles, :magnets, :downloads, :sizes, :files, :ages, :seeds, :leeches ].each do |s|
        @kat[:vanilla].send(s).size.must_equal 50
      end
    end
  end

  describe 'when rebuilding a vanilla query' do
    it 'returns a query to new torrents' do
      @kat[:vanilla].query = nil
      @kat[:vanilla].query.must_equal 'new/'
    end
  end

  describe 'when changing the search term on a vanilla query' do
    it 'returns a query to usearch' do
      @kat[:vanilla].query = 'test'
      @kat[:vanilla].query.must_equal 'usearch/test/'
    end
  end

  describe 'when adding an array of search terms to a vanilla query' do
    it 'returns a query to usearch' do
      @kat[:vanilla].query = [ 'test', 'category:books' ]
      @kat[:vanilla].query.must_equal 'usearch/test category:books/'
    end
  end

  describe 'when adding an array of crap to a vanilla query' do
    it 'returns a valid query' do
      @kat[:vanilla].query = [ 0, {}, [ 'test', 0..1 ] ]
      @kat[:vanilla].query.must_equal 'usearch/test/'
    end
  end

# Basic query tests

  describe 'when checking if a basic query responds to result fields after searching' do
    it 'returns true' do
      @kat[:basic].search
      [ :titles, :magnets, :downloads, :sizes, :files, :ages, :seeds, :leeches ].each do |s|
        @kat[:basic].respond_to?(s).must_equal true
      end
    end
  end

  describe 'when building a basic query' do
    it 'returns a query to usearch' do
      @kat[:basic].query.must_equal 'usearch/test/'
    end
  end

  describe 'when building a basic query with pages' do
    it 'returns a query to usearch with page numbers' do
      @kat[:basic].query(1).must_equal 'usearch/test/2/'
    end
  end

  describe 'when changing the search term of a basic query to nil' do
    it 'returns a query to new' do
      @kat[:basic].query = nil
      @kat[:basic].query.must_equal 'new/'
    end
  end

  describe 'when adding options to a basic query' do
    it 'returns a query to usearch with options' do
      @kat[:basic].options = { :category => 'movies' }
      @kat[:basic].options.must_equal({ :category => 'movies' })
      @kat[:basic].query.must_equal 'usearch/test category:movies/'
      @kat[:basic].results.must_be_empty
      @kat[:basic].pages.must_be :==, -1
    end
  end

  describe 'when adding options to a basic query with pages' do
    it 'returns a query to usearch with options and page numbers' do
      @kat[:basic].options = { :category => 'movies' }
      @kat[:basic].options.must_equal({ :category => 'movies' })
      @kat[:basic].query(1).must_equal 'usearch/test category:movies/2/'
      @kat[:basic].results.must_be_empty
      @kat[:basic].pages.must_be :==, -1
    end
  end

  describe 'when searching with a basic query' do
    it 'returns a result set' do
      @kat[:basic].search.must_be_instance_of Array
      @kat[:basic].search.size.must_equal 25
      @kat[:basic].pages.must_be :>, 0
    end
  end

  describe 'when searching the 2nd page of a basic query' do
    it 'returns a result set' do
      @kat[:basic].search(1).must_be_instance_of Array
      @kat[:basic].search(1).size.must_equal 25
      @kat[:basic].pages.must_be :>, 0
    end
  end

  describe 'when searching with the same basic query twice' do
    it 'returns the same result set' do
      @kat[:basic].search.must_equal @kat[:basic].search
    end
  end

  describe 'when searching for something that does not exist in a basic query' do
    it 'returns an empty set, sets an error and sets pages to 0' do
      @kat[:basic].query = 'owijefbvoweivf'
      @kat[:basic].search.must_be_nil
      @kat[:basic].error.must_be_instance_of Hash
      @kat[:basic].error[:error].must_be_instance_of OpenURI::HTTPError
      @kat[:basic].error[:error].message.must_equal '404 Not Found'
      @kat[:basic].pages.must_equal 0
    end
  end

  describe 'when searching for something with 1 page of results in a basic query' do
    it 'returns a result set and sets the pages to 1' do
      @kat[:basic].options = { :category => 'wallpapers' }
      @kat[:basic].options.must_equal({ :category => 'wallpapers' })
      @kat[:basic].search.wont_be_nil
      @kat[:basic].search.size.wont_equal 0
    end
  end

  describe 'when passing query= a Symbol' do
    it 'works just like a String' do
      @kat[:basic].query = :test
      @kat[:basic].query.must_equal 'usearch/test/'
    end
  end

  describe 'when passing a non-String-or-Array object to query=' do
    it 'raises an ArgumentError' do
      proc { @kat[:basic].query = { :foo => 'bar' } }.must_raise ArgumentError
    end
  end

  describe 'when passing a non-Hash object to options=' do
    it 'raises an ArgumentError' do
      proc { @kat[:basic].options = 'foobar' }.must_raise ArgumentError
    end
  end

# Advanced query tests

  describe 'when building an advanced query' do
    it 'returns a query with options to usearch' do
      @kat[:advanced].query.must_equal 'usearch/test category:books/'
    end
  end

  describe 'when building an advanced query with pages' do
    it 'returns a query with options and page numbers' do
      @kat[:advanced].query(1).must_equal 'usearch/test category:books/2/'
    end
  end

  describe 'when building an advanced query with select fields' do
    it 'returns a query with options to usearch' do
      @kat[:advanced].options = { :language => 2 }
      @kat[:advanced].query.must_equal 'usearch/test category:books lang_id:2/'
    end
  end

  describe 'when using symbols instead of strings in an advanced query' do
    it 'returns the same query string' do
      @kat[:advanced].options = { :category => :books }
      @kat[:advanced].query.must_equal 'usearch/test category:books/'
    end
  end

  describe 'when sorting fields' do
    it 'adds a sort part to the query string' do
      @kat[:advanced].options = { :sort => :size }
      @kat[:advanced].query.must_equal 'usearch/test category:books/?field=size&sorder=desc'
    end
  end

end
