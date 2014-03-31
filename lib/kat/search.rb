require File.dirname(__FILE__) + '/version'
require File.dirname(__FILE__) + '/field_map'
require 'nokogiri'
require 'net/http'
require 'andand'

module Kat

  BASE_URL     = 'http://kickass.to'
  RECENT_PATH  = 'new'
  SEARCH_PATH  = 'usearch'
  ADVANCED_URL = "#{ BASE_URL }/torrents/search/advanced/"

  class << self
    #
    # Convenience methods for the Search class
    #
    def search(search_term = nil, opts = {})
      Search.new search_term, opts
    end

    def quick_search(search_term = nil)
      Search.quick_search search_term
    end
  end

  class Search
    # The number of pages of results
    attr_reader :pages

    # Any error in searching is stored here
    attr_reader :error

    attr_reader :message

    @@doc = nil

    class << self

      #
      # Kat.quick_search will do a quick search and return the results
      #
      def quick_search(search_term = nil)
        new(search_term).search
      end

      def field_map(type = nil)
        return FIELD_MAP.dup unless type

        FIELD_MAP.inject({}) { |hash, (k, v)|
          hash.tap { |h|
            case type
            when :select then h[k] = { select: v[:select], id: v[:id] || k }
            when :sort   then h[k] = v[:sort] and h[v[:sort]] = v[:sort]
                              h[v[:id]] = v[:sort] if v[:id]
            else              h[k] = v[type]
            end if v[type]
          }
        }
      end

      def checks;  field_map :check  end
      def inputs;  field_map :input  end
      def selects; field_map :select end
      def sorts;   field_map :sort   end

    private

      #
      # Get a list of options for a particular selection field from the advanced search form
      #
      def field_options(label)
        fail 'Unknown search field' unless selects.find { |k, v| k == label.intern }

        url = URI(ADVANCED_URL)

        @@doc ||= Nokogiri::HTML(Net::HTTP.start(url.host) { |http| http.get url }.body)

        opts = @@doc.css('table.formtable td').find { |e|
          e.text[/#{ label }/i]
        }.next_element.first_element_child.children

        unless (group = opts.css('optgroup')).empty?
          # Categories
          group.inject({}) { |cat, og|
            cat.tap { |c|
              c[og.attributes['label'].value] = og.children.map { |o|
                o.attributes['value'].value
              }
            }
          }
        else
          # Times, languages, platforms
          opts.reject { |o| o.attributes.empty? }.inject({}) { |p, o|
            p.tap { |p| p[o.text] = o.attributes['value'].value }
          }
        end
      rescue => e
        { error: e }
      end

      #
      # If method is a field name in SELECT_FIELDS, fetch the list of values.
      #
      def method_missing(method, *args, &block)
        return super unless respond_to? method
        field_options selects.find { |k, v| v[:select] == method }.first
      end

      #
      # If method is a field name in SELECT_FIELDS, we can fetch the list of values
      #
      def respond_to_missing?(method, include_private = false)
        !!selects.find { |k, v| v[:select] == method } || super
      end

    end # class methods

    #
    # Create a new +Kat::Search+ object to search Kickass Torrents.
    # The search_term can be nil, a string/symbol, or an array of strings/symbols.
    # Valid options are in STRING_FIELDS, SELECT_FIELDS or SWITCH_FIELDS.
    #
    def initialize(search_term = nil, opts = {})
      @search_term = []
      @options = {}
      @error = nil
      @message = nil

      self.query = search_term
      self.options = opts
    end

    #
    # Generate a query string from the stored options, supplying an optional page number
    #
    def query_str(page = 0)
      str = [SEARCH_PATH, @query.join(' ').gsub(/[^a-z0-9: _-]/i, '')]
      str = [RECENT_PATH] if str[1].empty?
      str << page + 1 if page > 0

      sorts.find { |k, v| @options[:sort] && k == @options[:sort].intern }.tap { |k, v|
        str << (k ? "?field=#{ v }&sorder=#{ options[:asc] ? 'asc' : 'desc' }" : '')
      }

      str.join '/'
    end

    #
    # Change the search term, triggering a query rebuild and clearing past results.
    #
    # Raises ArgumentError if search_term is not a String, Symbol or Array
    #
    def query=(search_term)
      @search_term = case search_term
        when nil, ''        then []
        when String, Symbol then [search_term]
        when Array          then search_term.flatten.select { |e| [String, Symbol].include? e.class }
        else fail ArgumentError, "search_term must be a String, Symbol or Array. " <<
                                 "#{ search_term.inspect } given."
      end

      build_query
    end

    #
    # Get a copy of the search options hash
    #
    def options
      Marshal.load(Marshal.dump(@options))
    end

    #
    # Change search options with a hash, triggering a query string rebuild and
    # clearing past results.
    #
    # Raises ArgumentError if options is not a Hash
    #
    def options=(options)
      fail ArgumentError, "options must be a Hash. " <<
                          "#{ options.inspect } given." unless Hash === options

      @options.merge! options

      build_query
    end

    def sort?
      sorts.any? { |k, v| @options[:sort] && k == @options[:sort].intern }
    end

    #
    # Perform the search, supplying an optional page number to search on. Returns
    # a result set limited to the 25 results Kickass Torrents returns itself. Will
    # cache results for subsequent calls of search with the same query string.
    #
    def search(page = 0)
      @error = nil
      @message = nil

      search_proc = -> page {
        begin
          uri = URI(URI::encode(to_s page))
          res = Net::HTTP.get_response(uri)
          if res.code == '301'
            path = Net::HTTP::Get.new(res.header['location'])
            res = Net::HTTP.start(uri.host) { |http| http.request path }
            @message = { message: 'Sort is not functioning' } if sort?
          end

          @pages = 0 and return if res.code == '404'

          doc = Nokogiri::HTML(res.body)

          @results[page] = doc.xpath('//table[@class="data"]/tr[position()>1]/td[1]').map { |node|
            { path:     node.css('a.torType').first.andand.attr('href'),
              title:    node.css('a.cellMainLink').text,
              magnet:   node.css('a.imagnet').first.andand.attr('href'),
              download: node.css('a.idownload').last.andand.attr('href'),
              size:     (node = node.next_element).text,
              files:    (node = node.next_element).text.to_i,
              age:      (node = node.next_element).text,
              seeds:    (node = node.next_element).text.to_i,
              leeches:  (node = node.next_element).text.to_i }
          }

          # If we haven't previously performed a search with this query string, get the
          # number of pages from the pagination bar at the bottom of the results page.
          # If there's no pagination bar there's only 1 page of results.
          if @pages == -1
            p = doc.css('div.pages > a').last
            @pages = p ? [1, p.text.to_i].max : 1
          end
        rescue => e
          @error = { error: e }
        end unless @results[page] || (@pages > -1 && page >= @pages)
      }

      # Make sure we do a query for the first page of results before getting
      # subsequent pages in order to correctly figure out the total number of
      # pages of results.
      pages = (Range === page ? page.to_a : [page])
      pages.unshift(0) if @pages == -1 && !pages.include?(0)
      pages.each { |i| search_proc.call i }

      results[Range === page ? page.max : page]
    end

    #
    # For message chaining
    #
    def go(page = 0)
      search page
      self
    end

    # Was called do_search in v1, keeping it for compatibility
    alias_method :do_search, :go

    #
    # Get a copy of the results
    #
    def results
      Marshal.load(Marshal.dump(@results))
    end

    def checks;  Search.checks  end
    def inputs;  Search.inputs  end
    def selects; Search.selects end
    def sorts;   Search.sorts   end

    #
    # Use the search url as the string representation of the object
    #
    def to_s(page = 0)
      "#{ BASE_URL }/#{ query_str page }"
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

      @query << "\"#{ @options[:exact] }\"" if @options[:exact]
      @query << @options[:or].join(' OR ') unless @options[:or].nil? or @options[:or].empty?
      @query += @options[:without].map { |s| "-#{ s }" } if @options[:without]

      @query += inputs.select  { |k, v| @options[k] }.map { |k, v| "#{ k }:#{ @options[k] }" }
      @query += checks.select  { |k, v| @options[k] }.map { |k, v| "#{ k }:1" }
      @query += selects.select { |k, v|
        (v[:id].to_s[/^.*_id$/] && @options[k].to_s.to_i > 0) ||
        (v[:id].to_s[/^[^_]+$/] && @options[k])
      }.map { |k, v| "#{ v[:id] }:#{ @options[k] }" }
    end

    #
    # Fetch a list of values from the results set given by name
    #
    def results_column(name)
      @results.compact.map { |rs| rs.map { |r| r[name] || r[name[0...-1].intern] } }.flatten
    end

    #
    # If method or its plural form is a field name in the results list, fetch the list of values.
    # Can only happen after a successful search.
    #
    def method_missing(method, *args, &block)
      respond_to?(method) ? results_column(method) : super
    end

    def respond_to_missing?(method, include_private)
      !(@results.empty? || @results.first.empty?) &&
        (@results.first.first[method] || @results.first.first[method[0..-2].intern]) || super
    end

  end

end
