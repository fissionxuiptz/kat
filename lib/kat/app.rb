require 'kat'
require 'kat/options'
require 'highline'
require 'yaml'

module Kat

  class << self
    #
    # Convenience method for the App
    #
    def app args = ARGV
      App.new(args).main
    end
  end

  class App
    CONFIG_FILE = File.expand_path '~/.katrc'
    MIN_WIDTH = 80

    attr_accessor :page
    attr_reader   :kat, :options

    def initialize args = ARGV
      @kat = nil
      @page = 0
      @window_width = 0
      @show_info = !hide_info?
      @h = HighLine.new

      init_options args
      init_search
    end

    def init_options args = nil
      @args = args || []

      @options = if File.exist? CONFIG_FILE
        (symbolize = lambda do |h|
          Hash === h ? Hash[h.map {|k, v| [ k.to_sym, symbolize[v] ] }] : h
        end)[YAML.load_file CONFIG_FILE]
      else
        {}
      end

      @options.merge!(Kat.options @args) {|k, old_val, new_val| new_val ? new_val : old_val }
      @options.freeze
    end

    def init_search
      @kat ||= Kat.search
      @kat.query = @args.join(' ')
      @kat.options = @options
    end

    def main
      puts VERSION_STR

      Kat::Search.selects.select {|k, v| @options[v[:select]] }.tap do |lists|
        if lists.empty?
          while running; end
        else
          puts format_lists lists
        end
      end
    end

  private

    def set_window_width
      @window_width = @h.terminal_size[0]
    end

    def hide_info?
      @window_width < 81
    end

    def next?
      @page < @kat.pages - 1
    end

    def prev?
      @page > 0
    end

    def running
      puts
      set_window_width

      searching = true
      [
        lambda do
          @kat.search @page
          searching = false
        end,

        lambda do
          i = 0
          while searching do
            print "\rSearching... #{'\\|/-'[i % 4]}"
            i += 1
            sleep 0.1
          end
        end
      ].map {|w| Thread.new { w.call } }.each(&:join)

      return puts "\rNo results    " unless @kat.results[@page]

      puts format_results

      case (answer = prompt)
      when 'i' then @show_info = !@show_info
      when 'n' then @page += 1 if next?
      when 'p' then @page -= 1 if prev?
      when 'q' then return false
      else
        if (1..@kat.results[@page].size).include? (answer = answer.to_i)
          print "\nDownloading: #{@kat.results[@page][answer - 1][:title]}... "
          puts download @kat.results[@page][answer - 1]
        end
      end

      return true
    end

    def format_lists lists
      lists.inject([ nil ]) do |buf, (k, v)|
        opts = Kat::Search.send v[:select]
        buf << v[:select].to_s.capitalize
        buf << nil unless Array === opts.values.first
        width = opts.keys.sort {|a, b| b.size <=> a.size }[0].size
        opts.each do |k, v|
          buf += (Array === v ?
            [ nil, "%#{width}s => #{v.shift}" % k ] + v.map {|e| ' ' * (width + 4) + e } :
            [ "%-#{width}s => #{v}" % k ])
        end
        buf << nil
      end
    end

    def format_results
      main_width = @window_width - ((!hide_info? or @show_info) ? 42 : 4)
      buf = [ "\r%-#{main_width + 5}s#{'      Size    Age       Seeds Leeches' if !hide_info? or @show_info}" %
        "Page #{page + 1} of #{@kat.pages}" ]
      buf << nil
      @kat.results[@page].each_with_index do |t, i|
        age = t[:age].split "\xC2\xA0"
        age = "%3d %-6s" % age
        # Filter out the crap that invariably infests torrent names
        title = t[:title].codepoints.map {|c| c > 31 && c < 127 ? c.chr : '?' }.join[0...main_width]
        buf << "%2d. %-#{main_width}s#{' %10s %10s %7d %7d' if !hide_info? or @show_info}" %
          [ i + 1, title, t[:size], age, t[:seeds], t[:leeches] ]
      end
      buf << nil
    end

    def validation_regex
      n = @kat.results[@page].size
      commands = "[#{'i' if hide_info?}#{'n' if next?}#{'p' if prev?}q]|"
      _01to09  = "[1#{n >  9 ? '-9' : '-' + n.to_s}]"
      _10to19  = "#{n   >  9 ? '|1[0-' + (n > 19 ? '9' : (n - 10).to_s) + ']' : ''}"
      _20to25  = "#{n   > 19 ? '|2[0-' + (n - 20).to_s + ']' : ''}"
      /^(#{commands}#{_01to09}#{_10to19}#{_20to25})$/
    end

    def prompt
      n = @kat.results[@page].size
      @h.ask("1#{n > 1 ? '-' + n.to_s : ''} to download" +
             "#{', (n)ext' if next?}" +
             "#{', (p)rev' if prev?}" +
             "#{", #{@show_info ? 'hide' : 'show'} (i)nfo" if hide_info?}" +
             ', (q)uit: ') do |q|
        q.responses[:not_valid] = 'Invalid option.'
        q.validate = validation_regex
      end
    end

    def download torrent
      begin
        uri = URI torrent[:download]
        uri.query = nil
        response = uri.read
        file = "#{File.expand_path(@options[:output] || '.')}/#{torrent[:title].gsub(/ /, '.').gsub(/[^a-z0-9()_.-]/i, '')}.torrent"
        File.open(file, 'w') {|f| f.write response }
      rescue => e
        return [ red("failed"), e.message ]
      end
      green "done"
    end

    def red str; colour str, 31; end
    def green str; colour str, 32; end
    def colour str, code; STDOUT.tty? ? "\e[#{code}m#{str}\e[0m" : str; end
  end

end
