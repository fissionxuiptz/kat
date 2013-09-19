require File.dirname(__FILE__) + '/../kat'
require File.dirname(__FILE__) + '/options'
require File.dirname(__FILE__) + '/colour'

require 'highline'
require 'yaml'

module Kat

  class << self
    #
    # Convenience method for the App class
    #
    def app(args = ARGV)
      App.new(args).main
    end
  end

  class App
    MIN_WIDTH = 80

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
      @options = {}
      @args = case args
      when nil    then []
      when String then args.split
      else             args
      end

      load_config

      Kat.options(@args).tap { |o|
        @options.merge!(o) { |k, ov, nv| o["#{ k }_given".intern] ? nv : ov }
      }

      Kat::Colour.colour = @options[:colour]
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

      Kat::Search.selects.select { |k, v| @options[v[:select]] }.tap { |lists|
        if lists.empty?
          while running; end
        else
          puts format_lists lists
        end
      }
    end

  private

    #
    # Get the width of the terminal window
    #
    def set_window_width
      @window_width = @h.terminal_size[0]
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
          while searching do
            print "\rSearching...".yellow + '\\|/-'[i % 4]
            i += 1
            sleep 0.1
          end
        }
      ].map { |w| Thread.new { w.call } }.each(&:join)

      puts (res = format_results)

      if res.size > 1
        case (answer = prompt)
        when 'i' then @show_info = !@show_info
        when 'n' then @page += 1 if next?
        when 'p' then @page -= 1 if prev?
        when 'q' then return false
        else
          if (1..@kat.results[@page].size).include? (answer = answer.to_i)
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
      lists.inject([nil]) { |buf, (k, v)|
        opts = Kat::Search.send(v[:select])
        buf << v[:select].to_s.capitalize
        buf << nil unless Array === opts.values.first
        width = opts.keys.sort { |a, b| b.size <=> a.size }.first.size
        opts.each { |k, v|
          buf += if Array === v
            [nil, "%#{ width }s => #{ v.shift }" % k] +
            v.map { |e| ' ' * (width + 4) + e }
          else
            ["%-#{ width }s => #{ v }" % k]
          end
        }
        buf << nil
      }
    end

    #
    # Format the list of results with header information
    #
    def format_results
      main_width = @window_width - (!hide_info? || @show_info ? 42 : 4)

      if @kat.error
        return ["\rConnection failed".red]
      elsif !@kat.results[@page]
        return ["\rNo results    ".red]
      end

      buf = ["\r%-#{ main_width + 5 }s#{ '      Size     Age      Seeds Leeches' if !hide_info? || @show_info }" %
        "Page #{ page + 1 } of #{ @kat.pages }", nil].yellow!

      @kat.results[@page].each_with_index { |t, i|
        age = t[:age].split "\xC2\xA0"
        age = "%3d %-6s" % age
        # Filter out the crap that invariably infests torrent names
        title = t[:title].codepoints.map { |c| c > 31 && c < 127 ? c.chr : '?' }.join[0...main_width]
        buf << ("%2d. %-#{ main_width }s#{ ' %10s %10s %7d %7d' if !hide_info? or @show_info }" %
          [i + 1, title, t[:size], age, t[:seeds], t[:leeches]]).tap { |s| s.red! if t[:seeds] == 0 }
      }

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
             ', ' << '(q)'.cyan(true) << 'uit: ') { |q|
        q.responses[:not_valid] = 'Invalid option.'
        q.validate = validation_regex
      }
    end

    #
    # Download the torrent to either the output directory or the working directory
    #
    def download(torrent)
      uri = URI(URI::encode torrent[:download])
      uri.query = nil
      file = "#{ @options[:output] || '.' }/" <<
             "#{ torrent[:title].tr(' ', ?.).gsub(/[^a-z0-9()_.-]/i, '') }.torrent"

      fail '404 File Not Found' if (res = Net::HTTP.start(uri.host) { |http|
        http.get uri
      }).code == '404'

      File.open(File.expand_path(file), 'w') { |f| f.write res.body }

      :done.green
    rescue => e
      [:failed, e.message].red
    end

    #
    # Load options from ~/.katrc if it exists
    #
    def load_config
      config = File.join(ENV['HOME'], '.katrc')

      @options = (symbolise = -> h {
        Hash === h ? Hash[h.map { |k, v| [k.intern, symbolise[v]] }] : h
      })[YAML.load_file config] if File.readable? config
    rescue => e
      warn "Failed to load #{config}: #{e}"
    end

  end

end
