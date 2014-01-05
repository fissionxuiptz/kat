# coding: utf-8
lib = File.expand_path '../lib', __FILE__
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib
require 'kat/version'

Gem::Specification.new do |s|
  s.name          = 'kat'
  s.version       = Kat::VERSION
  s.date          = Time.new.strftime '%Y-%m-%d'
  s.author        = 'Fission Xuiptz'
  s.email         = 'fissionxuiptz@softwaremojo.com'
  s.homepage      = 'http://github.com/fissionxuiptz/kat'
  s.license       = 'MIT'

  s.summary       = 'Kickass Torrents Interface'
  s.description   = 'A Ruby interface to Kickass Torrents'

  s.files         = `git ls-files`.split $/
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename f }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_runtime_dependency 'nokogiri', '~> 1.6'
  s.add_runtime_dependency 'highline', '~> 1.6'
  s.add_runtime_dependency 'trollop', '~> 2.0'
  s.add_runtime_dependency 'andand', '~> 1.3'
end
