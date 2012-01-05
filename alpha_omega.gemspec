# -*- encoding: utf-8 -*-
#
$:.push File.expand_path("../lib", __FILE__)
require "alpha_omega/version"

Gem::Specification.new do |s|
  s.name        = "alpha_omega"
  s.version     = AlphaOmega::Version.to_s
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["David Nghiem", "Tom Bombadil"]
  s.email       = ["nghidav@gmail.com", "amanibhavam@destructuring.org"]
  s.homepage    = "https://github.com/HeSYINUvSBZfxqA/alpha_omega"
  s.summary     = %q{alpha_omega capistrano recipes}
  s.description = %q{Common reciples for persistent capistrano releases}
  s.date        = %q{2011-08-31}
  s.executables   = ["alpha_omega"]
  s.require_paths = ["lib"]
  s.files = %w(LICENSE README.mkd Procfile.rb) + Dir.glob("libexec/**/*") +Dir.glob("lib/**/*")

  s.add_runtime_dependency(%q<grit>)
  s.add_runtime_dependency(%q<surface>)
  s.add_runtime_dependency(%q<marathon>)
  s.add_runtime_dependency(%q<HeSYINUvSBZfxqA-capistrano>)
  s.add_runtime_dependency(%q<HeSYINUvSBZfxqA-capistrano_colors>)
  s.add_runtime_dependency(%q<HeSYINUvSBZfxqA-capistrano_log>)
end

