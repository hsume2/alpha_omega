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
  s.homepage    = "https://github.com/destructuring/alpha_omega"
  s.summary     = %q{alpha_omega capistrano recipes}
  s.description = %q{Common reciples for persistent capistrano releases}
  s.date        = %q{2011-08-31}
  s.executables   = ["ao" ]
  s.require_paths = ["lib"]
  s.files = %w(LICENSE VERSION README.mkd) + Dir.glob("libexec/**/*") + Dir.glob("lib/**/*") + Dir.glob("sbin/**/*")

  s.add_runtime_dependency(%q<json>)
  s.add_runtime_dependency(%q<deep_merge>)
  s.add_runtime_dependency("capistrano", "2.5.21")
  s.add_runtime_dependency(%q<capistrano_colors>)
  s.add_runtime_dependency(%q<capistrano-log_with_awesome>)
end
