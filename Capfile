#!/usr/bin/ruby

require 'capistrano_colors'

set :application, "alpha_omega"
set :deploy_to, "/tmp/#{application}"
set :repository, "https://github.com/zendesk/alpha_omega"

role :app, "localhost", :once => true, :shell => "/bin/bash"

load 'zendesk/deploy'
