module Kat
  FIELD_MAP = {
    exact:    { type: :string, desc: 'Exact phrase' },
    or:       { type: :string, desc: 'Optional words',    multi: true },
    without:  { type: :string, desc: 'Without this word', multi: true },

    sort:     { type: :string, desc: 'Sort field (size, files, added, seeds, leeches)' },
    asc:      {                desc: 'Ascending sort order (descending is default)' },

    category: { type: :string, desc: 'Category',           select: :categories, short: :c },
    added:    { type: :string, desc: 'Age of the torrent', select: :times,      short: :a, sort: :time_add, id: :age },
    size:     { sort: :size },

    user:     { type: :string, desc: 'Uploader',           input: true },
    files:    { type: :int,    desc: 'Number of files',    input: true, sort: :files_count },
    imdb:     { type: :int,    desc: 'IMDB ID',            input: true },
    seeds:    { type: :int,    desc: 'Min no of seeders',  input: true, sort: :seeders, short: :s },
    leeches:  { sort: :leechers },
    season:   { type: :int,    desc: 'Television season',  input: true },
    episode:  { type: :int,    desc: 'Television episode', input: true, short: :e },

    language: { type: :int,    desc: 'Language',      select: :languages, id: :lang_id },
    platform: { type: :int,    desc: 'Game platform', select: :platforms, id: :platform_id },

    safe:     {                desc: 'Family safe filter', check: true, short: :none},
    verified: {                desc: 'Verified torrent',   check: true, short: :none },

    output:   { type: :string, desc: 'Directory to save torrents in', short: :o },
    colour:   {                desc: 'Output with colour',            short: :none }
  }.freeze
end
