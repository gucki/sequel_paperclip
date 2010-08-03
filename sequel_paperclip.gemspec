#!/usr/bin/env gem build
# -*- encoding: utf-8 -*-

require 'date'
require 'lib/sequel_paperclip/version'

Gem::Specification.new do |gem|
  gem.name     = 'sequel_paperclip'
  gem.version  = Sequel::Plugins::Paperclip::VERSION.dup
  gem.authors  = ['Corin Langosch']
  gem.date     = Date.today.to_s
  gem.email    = 'info@netskin.com'
  gem.homepage = 'http://github.com/gucki/sequel_paperclip'
  gem.summary  = 'Sequel plugin which provides Paperclip (attachments, thumbnail resizing, etc.) functionality for model.'
  gem.description = gem.summary

  gem.has_rdoc = true 
  gem.require_paths = ['lib']
  gem.extra_rdoc_files = ['README.rdoc', 'LICENSE', 'CHANGELOG']
  gem.files = Dir['Rakefile', '{lib,spec}/**/*', 'README*', 'LICENSE*', 'CHANGELOG*'] & `git ls-files -z`.split("\0")

  gem.add_dependency 'sequel', ">= 3.0.0"
  gem.add_development_dependency 'sqlite3-ruby'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'yard'
end

