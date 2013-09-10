require 'yaml'

module Kat

  FIELD_MAP = (symbolize = lambda do |h|
    case h
    when Hash   then Hash[h.map {|k, v| [ k.to_sym, k == 'desc' ? v : symbolize[v] ] }]
    when String then h.to_sym
    else h
    end
  end)[YAML.load(<<-FIELD_MAP
---
exact:
  type:   string
  desc:   Exact phrase

or:
  type:   string
  desc:   Optional words
  multi:  true

without:
  type:   string
  desc:   Without this word
  multi:  true

sort:
  type:   string
  desc:   Sort field (size, files, added, seeds, leeches)

asc:
  desc:   Ascending sort order (descending is default)

category:
  select: categories
  type:   string
  desc:   Category
  short:  c

added:
  select: times
  sort:   time_add
  type:   string
  desc:   Age of the torrent
  id:     age
  short:  a

size:
  sort:   size

user:
  input:  true
  type:   string
  desc:   Uploader

files:
  input:  true
  sort:   files_count
  type:   int
  desc:   Number of files

imdb:
  input:  true
  type:   int
  desc:   IMDB ID

seeds:
  input:  true
  sort:   seeders
  type:   int
  desc:   Min no of seeders
  short:  s

leeches:
  sort:   leechers

season:
  input:  true
  type:   int
  desc:   Television season

episode:
  input:  true
  type:   int
  desc:   Television episode
  short:  e

language:
  select: languages
  type:   int
  desc:   Language
  id:     lang_id

platform:
  select: platforms
  type:   int
  desc:   Game platform
  id:     platform_id

safe:
  check:  true
  desc:   Family safe filter
  short:  none

verified:
  check:  true
  desc:   Verified torrent
  short:  none

output:
  type:   string
  desc:   Directory to save torrents in
  short:  o

colour:
  type:   boolean
  desc:   Output with colour
  short:  none
FIELD_MAP
  )].freeze

end
