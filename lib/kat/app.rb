require_relative '../kat'
require_relative 'options'
require_relative 'colour'

require 'highline'
require 'yaml'
require 'io/console'

module Kat
  #
  # Convenience method for the App class
  #
  def self.app(args = ARGV)
    App.new(args).main
  end

  class App
    MIN_WIDTH = 80
    CONFIG = File.join ENV['HOME'], '.katrc'

    # The current page number (0-based)
    attr_accessor :page

    # The +Kat::Search+ search object
    attr_reader :kat

    # The app options hash
    attr_reader :options

    #
    # Create a new +Kat::App+ object, using command-line switches as options by default
    #
    def initialize(args = ARGV)
      @kat = nil
      @page = 0
      @window_width = 0
      @show_info = !hide_info?
      @h = HighLine.new

      init_options args
      init_search
    end

    #
    # Initialise the app's options
    #
    def init_options(args = nil)
      @args = case args
              when nil    then []
              when String then args.split
              else             args
              end

      @options = load_config || {}

      Kat.options(@args).tap do |o|
        @options.merge!(o) { |k, ov, nv| o["#{ k }_given".intern] ? nv : ov }
      end

      Kat::Colour.colour = @options[:colour]
    rescue NoMethodError => e
      @options = {}
      warn "Wrong config file format: #{ e }"
    end

    #
    # Initialise the +Kat::Search+ object with the query and it's options
    #
    def init_search
      @kat ||= Kat.search
      @kat.query = @args.join(' ')
      @kat.options = @options
    end

    #
    # The main method. Prints a list of options for categories, platforms,
    # languages or times if the user has asked for them, otherwise will loop
    # over the running method until the user quits (or there's no results).
    #
    def main
      puts VERSION_STR

      Kat::Search.selects.select { |k, v| @options[v[:select]] }.tap do |lists|
        if lists.empty?
          while running; end
        else
          puts format_lists lists
        end
      end
    end

    private

    #
    # Get the width of the terminal window
    #
    def set_window_width
      # Highline 1.7's terminal_size cannot be trusted to return the values in
      # the correct order so just use IO.console.winsize directly
      @window_width = IO.console.winsize[1]
    end

    #
    # Hide extra info if window width is 80 chars or less
    #
    def hide_info?
      @window_width < 81
    end

    #
    # Is there a next page?
    #
    def next?
      @page < @kat.pages - 1
    end

    #
    # Is there a previous page?
    #
    def prev?
      @page > 0
    end

    #
    # Do the search, output the results and prompt the user for what to do next.
    # Returns false on error or the user enters 'q', otherwise returns true to
    # signify to the main loop it should run again.
    #
    def running
      puts
      set_window_width

      searching = true
      [
        -> {
          @kat.search @page
          searching = false
        },

        -> {
          i = 0
          while searching
            print "\rSearching...".yellow + '\\|/-'[i % 4]
            i += 1
            sleep 0.1
          end
        }
      ].map { |w| Thread.new { w.call } }.each(&:join)

      puts((res = format_results))

      if res.size > 1
        case (answer = prompt)
        when 'i' then @show_info = !@show_info
        when 'n' then @page += 1 if next?
        when 'p' then @page -= 1 if prev?
        when 'q' then return false
        else
          if (1..@kat.results[@page].size).include?((answer = answer.to_i))
            print "\nDownloading".yellow <<
                  ": #{ @kat.results[@page][answer - 1][:title] }... "
            puts download @kat.results[@page][answer - 1]
          end
        end

        true
      else
        false
      end
    end

    #
    # Format a list of options
    #
    def format_lists(lists)
      lists.inject([nil]) do |buf, (_, val)|
        opts = Kat::Search.send(val[:select])
        buf << val[:select].to_s.capitalize
        buf << nil unless opts.values.first.is_a? Array
        width = opts.keys.sort { |a, b| b.size <=> a.size }.first.size
        opts.each do |k, v|
          buf += if v.is_a? Array
                   [nil, "%#{ width }s => #{ v.shift }" % k] +
                     v.map { |e| ' ' * (width + 4) + e }
                 else
                   ["%-#{ width }s => #{ v }" % k]
                 end
        end
        buf << nil
      end
    end

    #
    # Format the list of results with header information
    #
    def format_results
      main_width = @window_width - (!hide_info? || @show_info ? 42 : 4)
      buf = []

      if @kat.error
        return ["\rConnection failed".red]
      elsif !@kat.results[@page]
        return ["\rNo results    ".red]
      end

      buf << "\r#{ @kat.message[:message] }\n".red if @kat.message

      buf << ("\r%-#{ main_width + 5 }s#{ '      Size     Age      Seeds Leeches' if !hide_info? || @show_info }" %
        ["Page #{ page + 1 } of #{ @kat.pages }", nil]).yellow

      @kat.results[@page].each_with_index do |t, i|
        age = t[:age].split "\xC2\xA0"
        age = '%3d %-6s' % age
        # Filter out the crap that invariably infests torrent names
        title = t[:title].codepoints.map { |c| c > 31 && c < 127 ? c.chr : '?' }.join[0...main_width]
        buf << ("%2d. %-#{ main_width }s#{ ' %10s %10s %7d %7d' if !hide_info? or @show_info }" %
          [i + 1, title, t[:size], age, t[:seeds], t[:leeches]]).tap { |s| s.red! if t[:seeds] == 0 }
      end

      buf << nil
    end

    #
    # Create a regex to validate the user's input
    #
    def validation_regex
      n = @kat.results[@page].size
      commands = "[#{ 'i' if hide_info? }#{ 'n' if next? }#{ 'p' if prev? }q]|"
      _01to09  = "[1-#{ [n, 9].min }]"
      _10to19  = "#{ "|1[0-#{ [n - 10, 9].min }]" if n >  9 }"
      _20to25  = "#{ "|2[0-#{ n - 20 }]" if n > 19 }"

      /^(#{ commands }#{ _01to09 }#{ _10to19 }#{ _20to25 })$/
    end

    #
    # Set the prompt after the results list has been printed
    #
    def prompt
      n = @kat.results[@page].size
      @h.ask("1#{ "-#{n}" if n > 1}".cyan(true) << ' to download' <<
             "#{ ', ' << '(n)'.cyan(true) << 'ext' if next? }" <<
             "#{ ', ' << '(p)'.cyan(true) << 'rev' if prev? }" <<
             "#{ ", #{ @show_info ? 'hide' : 'show' } " << '(i)'.cyan(true) << 'nfo' if hide_info? }" <<
             ', ' << '(q)'.cyan(true) << 'uit: ') do |q|
        q.responses[:not_valid] = 'Invalid option.'
        q.validate = validation_regex
      end
    rescue RegexpError
      puts((@kat.pages > 0 ? "Error reading the page\n" : "Could not connect to the site\n").red)

      return 'q'
    end

    #
    # Download the torrent to either the output directory or the working directory
    #
    def download(torrent)
      return [:failed, 'no download link available'].red unless torrent[:download]

      # Lazy hack. Future Me won't be happy ¯\_(ツ)_/¯
      unless (uri = URI(URI.encode torrent[:download])).scheme
        uri = URI(URI.encode "https:#{torrent[:download]}")
      end
      uri.query = nil

      file = "#{ @options[:output] || '.' }/" \
             "#{ torrent[:title].tr(' ', ?.).gsub(/[^a-z0-9()_.-]/i, '') }.torrent"

      fail '404 File Not Found' if (res = Net::HTTP.start(uri.host) do |http|
        http.get uri
      end).code == '404'

      File.open(File.expand_path(file), 'w') { |f| f.write res.body }

      :done.green
    rescue => e
      [:failed, e.message].red
    end

    #
    # Load options from CONFIG if it exists
    #
    def load_config
      (symbolise = lambda do |h|
        h.is_a?(Hash) ? Hash[h.map { |k, v| [k.intern, symbolise[v]] }] : h
      end)[YAML.load_file CONFIG] if File.readable? CONFIG
    rescue => e
      warn "Failed to load #{ CONFIG }: #{ e }"
    end
  end
end
