require 'nokogiri'
require 'open-uri'
require 'kat/version'

class Kat
  KAT_URL = 'http://kickass.to'
  EMPTY_URL = 'new'
  SEARCH_URL = 'usearch'
  ADVANCED_URL = "#{KAT_URL}/torrents/search/advanced/"

  STRING_FIELDS = [ :seeds, :user, :files, :imdb, :season, :episode ]

  # If these are set to anything but nil or false, they're turned on in the query
  SWITCH_FIELDS = [ :safe, :verified ]

  # The names of these fields are transposed for ease of use
  SELECT_FIELDS = [ { :name => :categories, :label => :category, :id => :category },
                    { :name => :times,      :label => :added,    :id => :age },
                    { :name => :languages,  :label => :language, :id => :lang_id },
                    { :name => :platforms,  :label => :platform, :id => :platform_id } ]

  SORT_FIELDS   = %w(size files_count time_add seeders leechers)

  # The number of pages of results
  attr_reader :pages

  # Any error in searching is stored here
  attr_reader :error

  @@doc = nil

  #
  # Create a new +Kat+ object to search Kickass Torrents.
  # The search_term can be nil, a string/symbol, or an array of strings/symbols.
  # Valid options are in STRING_FIELDS, SELECT_FIELDS or SWITCH_FIELDS.
  #
  def initialize search_term = nil, opts = {}
    @search_term = []
    @options = {}

    self.query = search_term
    self.options = opts
  end

  #
  # Kat.search will do a quick search and return the results
  #
  def self.search search_term
    self.new(search_term).search
  end

  #
  # Generate a query string from the stored options, supplying an optional page number
  #
  def query_str page = 0
    str = [ SEARCH_URL, @query.join(' ').gsub(/[^a-z0-9: _-]/i, '') ]
    str = [ EMPTY_URL ] if str[1].empty?
    str << page + 1 if page > 0
    str << if SORT_FIELDS.include? @options[:sort].to_s
      "?field=#{options[:sort].to_s}&sorder=#{options[:asc] ? 'asc' : 'desc'}"
    else
      ''    # ensure a trailing slash after the search terms or page number
    end
    str.join '/'
  end

  #
  # Change the search term, triggering a query rebuild and clearing past results.
  #
  # Raises ArgumentError if search_term is not a String, Symbol or Array
  #
  def query= search_term
    @search_term = case search_term
      when nil then []
      when String, Symbol then [ search_term ]
      when Array then search_term.flatten.select {|el| [ String, Symbol ].include? el.class }
      else raise ArgumentError, "search_term must be a String, Symbol or Array. #{search_term.inspect} given."
    end
    build_query
  end

  #
  # Get a copy of the search options hash
  #
  def options
    @options.dup
  end

  #
  # Change search options with a hash, triggering a query string rebuild and
  # clearing past results.
  #
  # Raises ArgumentError if opts is not a Hash
  #
  def options= opts
    raise ArgumentError, "opts must be a Hash. #{opts.inspect} given." unless opts.is_a? Hash
    @options.merge! opts
    build_query
  end

  #
  # Perform the search, supplying an optional page number to search on. Returns
  # a result set limited to the 25 results Kickass Torrents returns itself. Will
  # cache results for subsequent calls of search with the same query string.
  #
  def search page = 0
    unless @results[page] or (@pages > -1 and page >= @pages)
      begin
        doc = Nokogiri::HTML(open("#{KAT_URL}/#{URI::encode(query_str page)}"))
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

        # If we haven't previously performed a search with this query string, get the
        # number of pages from the pagination bar at the bottom of the results page.
        @pages = doc.css('div.pages > a').last.text.to_i if @pages < 0

        # If there was no pagination bar and the previous statement didn't trigger
        # a NoMethodError, there are results but only 1 page worth.
        @pages = 1 if @pages <= 0
      rescue NoMethodError
        # The results page had no pagination bar, but did return some results.
        @pages = 1
      rescue => e
        # No result throws a 404 error.
        @pages = 0 if e.class == OpenURI::HTTPError and e.message['404 Not Found']
        @error = { :error => e, :query => query_str(page) }
      end
    end

    results[page]
  end

  #
  # For message chaining
  #
  def do_search page = 0
    search page
    self
  end

  #
  # Get a copy of the results
  #
  def results
    @results.dup
  end

  #
  # If method_sym is a field name in SELECT_FIELDS, we can fetch the list of values.
  #
  def self.respond_to? method_sym, include_private = false
    SELECT_FIELDS.find {|field| field[:name] == method_sym } ? true : super
  end

  #
  # If method_sym or its plural is a field name in the results list, this will tell us
  # if we can fetch the list of values. It'll only happen after a successful search.
  #
  def respond_to? method_sym, include_private = false
    if not (@results.empty? or @results.last.empty?) and
           (@results.last.first[method_sym] or @results.last.first[method_sym.to_s.chop.to_sym])
      return true
    end
    super
  end

private

  #
  # Clear out the query and rebuild it from the various stored options. Also clears out the
  # results set and sets pages back to -1
  #
  def build_query
    @query = @search_term.dup
    @pages = -1
    @results = []

    @query << "\"#{@options[:exact]}\"" if @options[:exact]
    @query << @options[:or].join(' OR ') unless @options[:or].nil? or @options[:or].empty?
    @query += @options[:without].map {|s| "-#{s}" } if @options[:without]

    STRING_FIELDS.each {|f| @query << "#{f}:#{@options[f]}" if @options[f] }
    SWITCH_FIELDS.each {|f| @query << "#{f}:1" if @options[f] }
    SELECT_FIELDS.each do |f|
      if (@options[f[:label]].to_s.to_i > 0 and f[:id].to_s['_id']) or
         (@options[f[:label]] and not f[:id].to_s['_id'])
        @query << "#{f[:id]}:#{@options[f[:label]]}"
      end
    end
  end

  #
  # Get a list of options for a particular selection field from the advanced search form
  #
  # Raises an error unless the label is in SELECT_FIELDS
  #
  def self.field_options label
    begin
      raise 'Unknown search field' unless SELECT_FIELDS.find {|f| f[:label] == label.to_sym }

      opts = (@@doc ||= Nokogiri::HTML(open(ADVANCED_URL))).css('table.formtable td').find do |e|
        e.text[/#{label.to_s}/i]
      end.next_element.first_element_child.children

      unless (group = opts.css('optgroup')).empty?
        # Categories
        group.inject({}) {|c, og| c[og.attributes['label'].value] = og.children.map {|o| o.attributes['value'].value }; c }
      else
        # Times, languages, platforms
        opts.reject {|o| o.attributes.empty? }.inject({}) {|p, o| p[o.text] = o.attributes['value'].value; p }
      end
    rescue => e
      { :error => e }
    end
  end

  #
  # If method_sym is a field name in SELECT_FIELDS, fetch the list of values.
  #
  def self.method_missing method_sym, *args, &block
    if respond_to? method_sym
      return self.field_options SELECT_FIELDS.find {|field| field[:name] == method_sym }[:label]
    end
    super
  end

  #
  # If method_sym or its plural form is a field name in the results list, fetch the list of values.
  # Can only happen after a successful search.
  #
  def method_missing method_sym, *args, &block
    if respond_to? method_sym
      # Don't need no fancy schmancy singularizing method. Just try chopping off the 's'.
      return @results.compact.map {|rs| rs.map {|r| r[method_sym] || r[method_sym.to_s.chop.to_sym] } }.flatten
    end
    super
  end

end
