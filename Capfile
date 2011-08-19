#!/usr/bin/ruby

require 'etc'
require 'capistrano_colors'

set :application, "alpha_omega"
set :repository, "https://github.com/zendesk/alpha_omega"

set :user, Etc.getlogin
set :group, Etc.getgrgid(Etc.getpwnam(Etc.getlogin).gid).name
set :deploy_to, "/tmp/#{application}"
set :releases, %w(alpha omega lamda hash)

role :app, "localhost", :once => true, :shell => "/bin/bash"

load 'zendesk/deploy'
