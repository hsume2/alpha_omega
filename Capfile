#!/usr/bin/ruby

require 'etc'
require 'capistrano_colors'

set :application, "alpha_omega"
set :deploy_to, "/tmp/#{application}"
set :repository, "https://github.com/zendesk/alpha_omega"
set :user, Etc.getlogin
set :group, Etc.getgrgid(Etc.getpwnam(Etc.getlogin).gid).name

role :app, "localhost", :once => true, :shell => "/bin/bash"

load 'zendesk/deploy'
