# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sequel_paperclip/version"

Gem::Specification.new do |s|
  s.name        = "sequel_paperclip"
  s.version     = SequelPaperclip::VERSION
  s.authors     = ["Corin Langosch"]
  s.email       = ["info@corinlangosch.com"]
  s.homepage    = %q{http://github.com/gucki/sequel_paperclip}
  s.summary     = %q{Easy file attachment management for Sequel}
  s.description = %q{Sequel plugin which provides Paperclip (attachments, thumbnail resizing, etc.) functionality for model.}

  s.rubyforge_project = "sequel_paperclip"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
end

