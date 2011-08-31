# -*- encoding: utf-8 -*-
#
$:.push File.expand_path("../recipes", __FILE__)
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
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["recipes"]
  s.extra_rdoc_files = [
    "README.mkd"
  ]

  s.add_runtime_dependency(%q<capistrano>, ["2.5.21"])
  s.add_runtime_dependency(%q<capistrano_colors>)
  s.add_runtime_dependency(%q<capistrano-log_with_awesome>)
  s.add_runtime_dependency(%q<foreman>)
  s.add_runtime_dependency(%q<grit>)
end
