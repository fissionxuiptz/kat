require 'kat/search'
require 'kat/version'
require 'kat/field_map'

module Kat
  NAME = 'Kickass Torrents Search'
  MALEVOLENT_DICTATOR_FOR_LIFE = 'Fission Xuiptz'
  AUTHOR = MALEVOLENT_DICTATOR_FOR_LIFE
  VERSION_STR = "#{NAME} #{VERSION} (c) 2013 #{MALEVOLENT_DICTATOR_FOR_LIFE}"

  BASE_URL     = 'http://kickass.to'
  RECENT_PATH  = 'new'
  SEARCH_PATH  = 'usearch'
  ADVANCED_URL = "#{BASE_URL}/torrents/search/advanced/"
end
