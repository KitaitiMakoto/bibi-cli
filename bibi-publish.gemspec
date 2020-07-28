# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bibi/publish/version'

Gem::Specification.new do |gem|
  gem.name          = "bibi-publish"
  gem.version       = Bibi::Publish::VERSION
  gem.summary       = %q{Publishes EPUB files using Bibi}
  gem.description   = %q{bibi-publish uploads EPUB files to S3 and make them readable via web using Bibi a EPUB reader application.}
  gem.license       = "MIT"
  gem.authors       = ["Kitaiti Makoto"]
  gem.email         = "KitaitiMakoto@gmail.com"
  gem.homepage      = "https://rubygems.org/gems/bibi-publish"

  gem.files         = `git ls-files`.split($/)

  `git submodule --quiet foreach --recursive pwd`.split($/).each do |submodule|
    submodule.sub!("#{Dir.pwd}/",'')

    Dir.chdir(submodule) do
      `git ls-files`.split($/).map do |subpath|
        gem.files << File.join(submodule,subpath)
      end
    end
  end
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_runtime_dependency "archive-zip"
  gem.add_runtime_dependency "dry-cli"
  gem.add_runtime_dependency "dry-configurable"
  gem.add_runtime_dependency "epub-parser"
  gem.add_runtime_dependency "xdg"

  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rubygems-tasks'
  gem.add_development_dependency "test-unit"
  gem.add_development_dependency 'yard'
end
