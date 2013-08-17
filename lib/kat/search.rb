require 'nokogiri'
require 'open-uri'

module Kat

  class << self
    def search search_term = nil, opts = {}
      Search.new search_term, opts
    end

    def quick_search search_term = nil
      Search.quick_search search_term
    end
  end

  class Search
    # The number of pages of results
    attr_reader :pages

    # Any error in searching is stored here
    attr_reader :error

    @@doc = nil

    class << self

      #
      # Kat.quick_search will do a quick search and return the results
      #
      def quick_search search_term = nil
        new(search_term).search
      end

      def field_map type = nil
        return FIELD_MAP.dup unless type
        FIELD_MAP.inject({}) do |hash, (k, v)|
          hash.tap do |h|
            case type
            when :select then h[k] = { :select => v[:select], :id => v[:id] || k }
            when :sort   then h[k] = v[:sort] and h[v[:sort]] = v[:sort]
            else              h[k] = v[type]
            end if v[type]
          end
        end
      end

      def checks;  field_map :check;  end
      def inputs;  field_map :input;  end
      def selects; field_map :select; end
      def sorts;   field_map :sort;   end

      #
      # If method is a field name in SELECT_FIELDS, we can fetch the list of values.
      #
      def respond_to? method, include_private = false
        selects.find {|k, v| v[:select] == method } ? true : super
      end

    private

      #
      # Get a list of options for a particular selection field from the advanced search form
      #
      # Raises an error unless the label is a select field
      #
      def field_options label
        begin
          raise 'Unknown search field' unless selects.find {|k, v| k == label.to_sym }

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
      # If method is a field name in SELECT_FIELDS, fetch the list of values.
      #
      def method_missing method, *args, &block
        if respond_to? method
          return field_options selects.find {|k, v| v[:select] == method }[0]
        end
        super
      end

    end
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
    # Generate a query string from the stored options, supplying an optional page number
    #
    def query_str page = 0
      str = [ SEARCH_PATH, @query.join(' ').gsub(/[^a-z0-9: _-]/i, '') ]
      str = [ RECENT_PATH ] if str[1].empty?
      str << page + 1 if page > 0
      sorts.find {|k, v| k == @options[:sort] }.tap do |k, v|
        str << (k ? "?field=#{v}&sorder=#{options[:asc] ? 'asc' : 'desc'}" : '')
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
      raise ArgumentError, "opts must be a Hash. #{opts.inspect} given." unless Hash === opts
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
          doc = Nokogiri::HTML(open("#{BASE_URL}/#{URI::encode(query_str page)}"))
          @results[page] = doc.css('td.torrentnameCell').map do |node|
            { :path     => node.css('a.normalgrey').first.attributes['href'].value,
              :title    => node.css('a.normalgrey').text,
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
        rescue NoMethodError => e
          # The results page had no pagination bar, but did return some results.
          @pages = 1
          #@error = { :error => e, :query => query_str(page) }
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
    def go page = 0
      search page
      self
    end

    # Was called do_search in v1, keeping it for compatibility
    alias_method :do_search, :go

    #
    # Get a copy of the results
    #
    def results
      @results.dup
    end

    def checks;  Search.checks;  end
    def inputs;  Search.inputs;  end
    def selects; Search.selects; end
    def sorts;   Search.sorts;   end

    #
    # If method or its plural is a field name in the results list, this will tell us
    # if we can fetch the list of values. It'll only happen after a successful search.
    #
    def respond_to? method, include_private = false
      if not (@results.empty? or @results.last.empty?) and
             (@results.last.first[method] or @results.last.first[method.to_s.chop.to_sym])
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
      @query   = @search_term.dup
      @pages   = -1
      @results = []

      @query << "\"#{@options[:exact]}\"" if @options[:exact]
      @query << @options[:or].join(' OR ') unless @options[:or].nil? or @options[:or].empty?
      @query += @options[:without].map {|s| "-#{s}" } if @options[:without]

      @query += inputs.select {|k, v| @options[k] }.map {|k, v| "#{k}:#{@options[k]}" }
      @query += checks.select {|k, v| @options[k] }.map {|k, v| "#{k}:1" }
      @query += selects.select do |k, v|
        (v[:id].to_s[/^.*_id$/] and @options[k].to_s.to_i > 0) or
        (v[:id].to_s[/^[^_]+$/] and @options[k])
      end.map {|k, v| "#{v[:id]}:#{@options[k]}" }
    end

    #
    # If method or its plural form is a field name in the results list, fetch the list of values.
    # Can only happen after a successful search.
    #
    def method_missing method, *args, &block
      if respond_to? method
        # Don't need no fancy schmancy singularizing method. Just try chopping off the 's'.
        return @results.compact.map {|rs| rs.map {|r| r[method] || r[method.to_s.chop.to_sym] } }.flatten
      end
      super
    end

  end

end
