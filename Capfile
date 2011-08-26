#!/usr/bin/env ruby

require 'etc'

load 'alpha_omega/deploy'

ssh_options[:forward_agent] = true

set :application, File.basename(Dir.pwd)
set :repository, %x{git config remote.origin.url}.strip

set :user, Etc.getlogin
set :group, Etc.getgrgid(Etc.getpwnam(Etc.getlogin).gid).name
set :deploy_to, Dir.pwd
set :releases, %w(alpha omega lamda hash)

role :app, "localhost", :once => true, :shell => "/bin/bash"

