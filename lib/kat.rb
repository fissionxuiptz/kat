# TODO: Implement field sort and sort order
#       Lookup advanced search for language and platform values
#       Comments
#       Tests

require 'nokogiri'
require 'open-uri'

class Kat
  KAT_URL = 'http://kickass.to'
  SEARCH_URL = "#{KAT_URL}/usearch/"
  ADVANCED_URL = "#{KAT_URL}/torrents/search/advanced/"

  STRING_FIELDS = [ :category, :seeds, :user, :age, :files, :imdb, :season, :episode ]
  SELECT_FIELDS = [ { :name => :language, :id => :lang_id }, { :name => :platform, :id => :platform_id } ]
  SWITCH_FIELDS = [ :safe, :verified ]

  attr_reader :results, :pages, :error

  def initialize search_term = nil, opts = {}
    @search_term = []
    @options = opts.is_a?(Hash) ? opts : {}
    self.query = search_term.dup
  end

  def self.search search_term
    self.new(search_term).search
  end

  def query page = 0
    @query.join(' ').gsub(/[^a-z0-9: _-]/i, '') + (page > 0 ? "/#{page + 1}" : '') + (@query.empty? ? '' : '/')
  end

  def query= search_term
    @search_term = case search_term
      when nil    then []
      when String then [ search_term ]
      when Array  then search_term.flatten.select {|el| el.is_a? String }
      else raise ArgumentError, "search_term must be a String or Array object. #{search_term.inspect} given."
    end
    build_query
  end

  def options
    @options.dup
  end

  def options= opts
    raise ArgumentError, "opts must be a Hash object. #{opts.inspect} given." unless opts.is_a? Hash
    @options.merge! opts
    build_query
  end

  def search page = 0
    unless query.empty? or @results[page] or (@pages > 0 and page >= @pages)
      begin
        doc = Nokogiri::HTML(open("#{SEARCH_URL}#{URI::encode(query page)}"))
        @results[page] = doc.css('td.torrentnameCell').map do |node|
          { :title    => node.css('a.normalgrey').text,
            :magnet   => node.css('a.imagnet').first.attributes['href'].value,
            :download => node.css('a.idownload').last.attributes['href'].value,
            :size     => (node = node.next_element).text,
            :files    => (node = node.next_element).text.to_i,
            :age      => (node = node.next_element).text,
            :seeds    => (node = node.next_element).text.to_i,
            :leeches  => (node = node.next_element).text.to_i }
        end
        @pages = doc.css('div.pages > a').last.text.to_i if @pages == 0
        @pages = 1 if @pages == 0
      rescue => e
        if e.name == :text
          @pages = 1
        else
          @error = { :error => e, :query => query(page) }
        end
      end
    end

    @results[page]
  end

  def respond_to? method_sym, include_private = false
    return true if not @results.empty? and (@results.last.first[method_sym] or @results.last.first[method_sym.to_s.chop.to_sym])
    super
  end

private

  def build_query
    @query = @search_term.dup
    @pages = 0
    @results = []

    @query << "\"#{@options[:exact]}\"" if @options[:exact]
    @query << @options[:or].join(' OR ') unless @options[:or].nil? or @options[:or].empty?
    @query += @options[:without].map {|s| "-#{s}" } if @options[:without]

    STRING_FIELDS.each {|f| @query << "#{f}:#{@options[f]}" if @options[f] }
    SELECT_FIELDS.each {|f| @query << "#{f[:id]}:#{@options[f[:name]]}" if @options[f[:name]].to_i > 0 }
    SWITCH_FIELDS.each {|f| @query << "#{f}:1" if @options[f] }
  end

  def method_missing method_sym, *arguments, &block
    m = method_sym.to_s.chop.to_sym
    if not @results.empty? and (@results.last.first[method_sym] or @results.last.first[m])
      @results.compact.map {|rs| rs.map {|r| r[method_sym] || r[m] } }.flatten
    else
      super
    end
  end

end
