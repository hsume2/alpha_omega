#!/usr/bin/env ruby

require 'etc'
require 'recipes/alpha_omega/deploy'

ssh_options[:forward_agent] = true

set :application, File.basename(Dir.pwd)
set :repository, "git://localhost/.git"

set :user, Etc.getlogin
set :group, Etc.getgrgid(Etc.getpwnam(Etc.getlogin).gid).name
set :deploy_to, Dir.pwd
set :releases, %w(alpha beta gamma omega)

role :app, "localhost", :once => true, :shell => "/bin/bash"
