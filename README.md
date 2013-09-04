[![Build Status](https://secure.travis-ci.org/fissionxuiptz/kat.png)](http://travis-ci.org/fissionxuiptz/kat)

# Kat

A Ruby interface to Kickass Torrents

## Installation

Add this line to your application's Gemfile:

    gem 'kat'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kat

## Usage

### Quick search

    Kat.search('game of thrones')

### Search for torrents

    kat = Kat.new('game of thrones', { :category => 'tv' })
    kat.search

### Specifying pages

Page searching is 0-based. The number of pages is set after a search is performed and returned
with the `pages` method.

    kat.search(2)             # Third page of results
    kat.results[0]            # First page of results
    kat.pages                 # Total number of pages

### Results

The `results` method returns a list of torrent information per page. Each result has
title, magnet, download, size, files, age, seeds and leeches information. Complete lists
of each can be returned with:

    kat.titles                # List all titles...
    kat.downloads             #       ...downloads...
    kat.seeds                 #       ...seeds etc

### Requerying

The Kat instance can be reused with the `query=` and `options=` methods.

    kat.query = 'hell on wheels'
    kat.options = { :seeds => 100 }

Either method resets the number of pages and the results cache.

### Executable

In addition to the Kat class, there is also a binary which makes use of the class to do
some rudimentary searching and downloading of torrents. Invoke `kat --help` to get a
complete list of options.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
