#!/usr/bin/env ruby

require 'alpha_omega/deploy'

# application deploy
namespace :alpha_omega do
  namespace :bundle do
    task :ruby do
      run "{ cd #{deploy_release} && #{ruby_loader} bundle check 2>&1 >/dev/null; } || #{ruby_loader} bundle --local --path vendor/bundle >/dev/null"
    end
  end
end

# overrides
namespace :deploy do
  task :bundle do
    alpha_omega.bundle.ruby
  end
end

# interesting hosts
Deploy self, __FILE__ do |admin, node| 
  { :deploy => { } }
end
