require 'kat'
require 'kat/options'
require 'highline'

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
    attr_accessor :page
    attr_reader   :kat, :options

    def initialize args = ARGV
      @kat = nil
      @page = 0
      @h = HighLine.new

      init_options args
      init_search
    end

    def init_options args = nil
      @args = args || @args
      @options = (Kat.options args || @args).freeze
    end

    def init_search
      @kat ||= Kat.search
      @kat.query = @args.join(' ')
      @kat.options = @options
    end

    def main
      puts VERSION_STR

      Kat::Search.selects.select {|k, v| @options[v[:select]] }.tap do |lists|
        unless lists.empty?
          list_args.each do |k, v|
            list_args = Kat.send v[:select]
            puts "\n  #{v[:select].to_s.capitalize}"
            puts unless Array === list_args.values.first
            list_args.each {|k, v| puts Array === v ? "\n  %12s => #{v.join "\n\t\t  "}" % k : "  %-23s => #{v}" % k }
            puts
          end
        else
          while running; end
        end
      end
    end

  private

    def running
      r = @kat.search page
      if r.nil?
        puts "\nNo results"
        return nil
      end

      n = @page < @kat.pages - 1
      p = @page > 0

      puts "\n%-72s S     L\n\n" % "Page #{page + 1} of #{@kat.pages}"
      r.each_with_index do |t, i|
        puts "%2d. %-64s %5d %5d" % [ i + 1, t[:title][0..63], t[:seeds], t[:leeches] ]
      end

      commands = "[#{'n' if n}#{'p' if p}q]|"
      _01to09  = "[1#{r.size >  9 ? '-9' : '-' + r.size.to_s}]"
      _10to19  = "#{r.size   >  9 ? '|1[0-' + (r.size > 19 ? '9' : (r.size - 10).to_s) + ']' : ''}"
      _20to25  = "#{r.size   > 19 ? '|2[0-' + (r.size - 20).to_s + ']' : ''}"
      prompt   = "\n1#{r.size > 1 ? '-' + r.size.to_s : ''} to download" +
                 "#{', (n)ext' if n}" +
                 "#{', (p)rev' if p}" +
                 ', (q)uit: '

      case (answer = @h.ask(prompt) {|q| q.validate = /^(#{commands}#{_01to09}#{_10to19}#{_20to25})$/ })
      when 'q' then return nil
      when 'n' then @page += 1 if n
      when 'p' then @page -= 1 if p
      else
        if (1..r.size).include? answer.to_i
          torrent = @kat.results[page][answer.to_i - 1]
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

  end

end
