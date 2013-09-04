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
      @show_info = !hide_info?
      @h = HighLine.new

      init_options args
      init_search
    end

    def init_options args = nil
      @args = args || @args
      @options = {}
      @options = (symbolize = lambda do |h|
        Hash === h ? Hash[h.map {|k, v| [ k.to_sym, symbolize[v] ] }] : h
      end)[YAML.load_file CONFIG_FILE] if File.exist? CONFIG_FILE
      @options.merge!(Kat.options args || @args) {|k, old_val, new_val| new_val ? new_val : old_val }
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
          puts formatted_list_options lists
        end
      end
    end

  private

    def width
      HighLine::SystemExtensions.terminal_size[0]
    end

    def hide_info?
      width < 81
    end

    def running
      r = @kat.search @page
      if r.nil?
        puts "\nNo results"
        return nil
      end

      n = @page < @kat.pages - 1
      p = @page > 0

      main_width = width - ((!hide_info? or @show_info) ? 42 : 4)
      puts "\n%-#{main_width + 5}s#{'      Size    Age       Seeds Leeches' if !hide_info? or @show_info}\n\n" % "Page #{page + 1} of #{@kat.pages}"
      r.each_with_index do |t, i|
        age = t[:age].split "\xC2\xA0"
        age = "%3d %-6s" % age
        puts "%2d. %-#{main_width}s#{' %10s %10s %7d %7d' if !hide_info? or @show_info}" % [ i + 1, t[:title][0...main_width], t[:size], age, t[:seeds], t[:leeches] ]
      end

      commands = "[#{'i' if hide_info?}#{'n' if n}#{'p' if p}q]|"
      _01to09  = "[1#{r.size >  9 ? '-9' : '-' + r.size.to_s}]"
      _10to19  = "#{r.size   >  9 ? '|1[0-' + (r.size > 19 ? '9' : (r.size - 10).to_s) + ']' : ''}"
      _20to25  = "#{r.size   > 19 ? '|2[0-' + (r.size - 20).to_s + ']' : ''}"
      prompt   = "\n1#{r.size > 1 ? '-' + r.size.to_s : ''} to download" +
                 "#{', (n)ext' if n}" +
                 "#{', (p)rev' if p}" +
                 "#{", #{@show_info ? 'hide' : 'show'} (i)nfo" if hide_info?}" +
                 ', (q)uit: '

      case (answer = @h.ask(prompt) {|q| q.validate = /^(#{commands}#{_01to09}#{_10to19}#{_20to25})$/ })
      when 'q' then return nil
      when 'i' then @show_info = !@show_info
      when 'n' then @page += 1 if n
      when 'p' then @page -= 1 if p
      else
        if (1..r.size).include? answer.to_i
          torrent = r[answer.to_i - 1]
          puts "\nDownloading: #{torrent[:title]}"

          begin
            uri = URI torrent[:download]
            uri.query = nil
            response = uri.read
            file = "#{File.expand_path(options[:output] || '.')}/#{torrent[:title].gsub(/ /, '.').gsub(/[^a-z0-9()_.-]/i, '')}.torrent"
            File.open(file, 'w') {|f| f.write response }
          rescue => e
            puts e.message
          end
        end
      end

      return 1
    end

    def formatted_list_options lists
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

  end

end
