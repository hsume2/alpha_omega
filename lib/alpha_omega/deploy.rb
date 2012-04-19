$:.unshift File.expand_path(File.join(File.dirname(__FILE__),'..','..','lib'))

require 'benchmark'
require 'yaml'
require 'alpha_omega/deploy/scm'
require 'alpha_omega/deploy/strategy'
require 'alpha_omega/utils'
require 'capistrano_colors'
require 'capistrano/log_with_awesome'

ENV["AO_USER"] || ENV["AO_USER"] = ENV["USER"]

Capistrano::Configuration.instance(:must_exist).load do |config|

  def _cset(name, *args, &block)
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  # =========================================================================
  # These variables MUST be set in the client capfiles. If they are not set,
  # the deploy will fail with an error.
  # =========================================================================

  _cset(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
  _cset(:repository)  { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }

  # =========================================================================
  # These variables may be set in the client capfile if their default values
  # are not sufficient.
  # =========================================================================

  _cset :scm, :git
  _cset :deploy_via, :checkout
  _cset(:branch) { AlphaOmega.what_branch }
  _cset(:revision) { source.head }

  _cset :default_shell, "/bin/bash"
  _cset(:deploy_to) { "/u/apps/#{application}" }

  _cset :root_user, "root"
  _cset :root_group, "root"

  _cset :dir_perms, "0775"

  _cset :bundler_options, "--deployment --without development:test"
  _cset :ruby_loader, ""

  _cset(:run_method)        { fetch(:use_sudo, true) ? :sudo : :run }

  _cset :current_pod, "default"
  _cset :last_pod, nil
  _cset :local_only, ENV['LOCAL_ONLY'] ? true : false

  _cset (:figlet) { [%x(which figlet).strip].reject {|f| !(File.executable? f)}.first || echo }

  # =========================================================================
  # These variables should NOT be changed unless you are very confident in
  # what you are doing. Make sure you understand all the implications of your
  # changes if you do decide to muck with these!
  # =========================================================================

  _cset(:source)            { Capistrano::Deploy::SCM.new(scm, self) }
  _cset(:strategy)          { Capistrano::Deploy::Strategy.new(deploy_via, self) }
  _cset(:real_revision)     { source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { run_locally(cmd) } } }

  _cset :releases,          [ "alpha", "beta", "omega" ]
  _cset(:releases_dir)      { releases.length > 0 ? "releases" : "" }
  _cset(:current_workarea)  { capture("readlink #{current_path} || true").strip.split("/")[-1] || releases[0] }

  _cset :previous_dir,        "previous"
  _cset :current_dir,         "current"
  _cset :next_dir,            "next"
  _cset :compare_dir,         "compare"
  _cset :migrate_dir,         "migrate"

  _cset :service_dir,         "service"
  _cset :log_dir,             "log"

  _cset(:service_path)      { File.join(deploy_to, service_dir) }
  _cset(:service_drop)      { File.join(deploy_to, ".#{service_dir}.d") }
  _cset(:log_path)          { File.join(deploy_to, log_dir) }

  _cset(:rollback_release_name) { 
    if releases.length > 0
      w = current_workarea
      releases.index(w) && releases[(releases.index(w))%releases.length]
    else
      ""
    end
  }
  _cset(:previous_release_name) { 
    if releases.length > 0
      w = current_workarea
      releases.index(w) && releases[(releases.index(w)-1)%releases.length]
    else
      ""
    end
  }
  _cset(:current_release_name) { 
    if releases.length > 0
      w = current_workarea
      stage = releases[((releases.index(w)?releases.index(w):-1)+1)%releases.length]
      system "#{figlet} -w 200 on #{stage}"
      stage
    else
      ""
    end
  }
  _cset(:next_release_name) { 
    if releases.length > 0
      w = current_workarea
      releases.index(w) && releases[(releases.index(w)+1)%releases.length]
    else
      ""
    end
  }
  _cset :compare_release_name, compare_dir
  _cset :migrate_release_name, migrate_dir

  _cset(:releases_path)     { File.join(deploy_to, releases_dir) }
  _cset(:previous_path)     { File.join(deploy_to, previous_dir) }
  _cset(:current_path)      { File.join(deploy_to, current_dir) }
  _cset(:external_path)     { current_path }
  _cset(:next_path)         { File.join(deploy_to, next_dir) }
  _cset(:compare_path)      { File.join(deploy_to, compare_dir) }
  _cset(:migrate_path)      { File.join(deploy_to, migrate_dir) }

  _cset(:rollback_revision) { capture("cat #{rollback_release}/REVISION", :except => { :no_release => true }).strip }
  _cset(:previous_revision) { capture("cat #{previous_release}/REVISION", :except => { :no_release => true }).strip }
  _cset(:current_revision)  { capture("cat #{current_release}/REVISION",  :except => { :no_release => true }).strip }
  _cset(:next_revision)     { capture("cat #{next_release}/REVISION",     :except => { :no_release => true }).strip }
  _cset(:compare_revision)  { capture("cat #{compare_release}/REVISION",  :except => { :no_release => true }).strip }
  _cset(:migrate_revision)  { capture("cat #{migrate_release}/REVISION",  :except => { :no_release => true }).strip }

  # formerly:
  #
  # some tasks, like symlink, need to always point at the latest release, but
  # they can also (occassionally) be called standalone. In the standalone case,
  # the timestamped release_path will be inaccurate, since the directory won't
  # actually exist. This variable lets tasks like symlink work either in the
  # standalone case, or during deployment.
  #
  # with persistent releases, the latest release is always the current release

  _cset(:rollback_release)  { File.join(releases_path, rollback_release_name) }
  _cset(:previous_release)  { File.join(releases_path, previous_release_name) }
  _cset(:current_release)   { File.join(releases_path, current_release_name) }
  _cset(:next_release)      { File.join(releases_path, next_release_name) }
  _cset(:compare_release)   { File.join(releases_path, compare_release_name) }
  _cset(:migrate_release)   { File.join(releases_path, migrate_release_name) }

  # =========================================================================
  # deploy:lock defaults
  # =========================================================================
  _cset(:want_unlock) { true }
  _cset(:lock_timeout) { 86400 }

  # =========================================================================
  # These are helper methods that will be available to your recipes.
  # =========================================================================

  # Auxiliary helper method for the `deploy:check' task. Lets you set up your
  # own dependencies.
  def depend(location, type, *args)
    deps = fetch(:dependencies, {})
    deps[location] ||= {}
    deps[location][type] ||= []
    deps[location][type] << args
    set :dependencies, deps
  end

  # Temporarily sets an environment variable, yields to a block, and restores
  # the value when it is done.
  def with_env(name, value)
    saved, ENV[name] = ENV[name], value
    yield
  ensure
    ENV[name] = saved
  end

  # logs the command then executes it locally.
  # returns the command output as a string
  def run_locally(cmd)
    logger.trace "executing locally: #{cmd.inspect}" if logger
    output_on_stdout = nil
    elapsed = Benchmark.realtime do
      output_on_stdout = `#{cmd}`
    end
    if $?.to_i > 0 # $? is command exit code (posix style)
      raise Capistrano::LocalArgumentError, "Command #{cmd} returned status code #{$?}"
    end
    logger.trace "command finished in #{(elapsed * 1000).round}ms" if logger
    output_on_stdout
  end


  # If a command is given, this will try to execute the given command, as
  # described below. Otherwise, it will return a string for use in embedding in
  # another command, for executing that command as described below.
  #
  # If :run_method is :sudo (or :use_sudo is true), this executes the given command
  # via +sudo+. Otherwise is uses +run+. If :as is given as a key, it will be
  # passed as the user to sudo as, if using sudo. If the :as key is not given,
  # it will default to whatever the value of the :admin_runner variable is,
  # which (by default) is unset.
  #
  # THUS, if you want to try to run something via sudo, and what to use the
  # root user, you'd just to try_sudo('something'). If you wanted to try_sudo as
  # someone else, you'd just do try_sudo('something', :as => "bob"). If you
  # always wanted sudo to run as a particular user, you could do
  # set(:admin_runner, "bob").
  def try_sudo(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    command = args.shift
    raise ArgumentError, "too many arguments" if args.any?

    as = options.fetch(:as, fetch(:admin_runner, nil))
    via = fetch(:run_method, :sudo)
    if command
      invoke_command(command, :via => via, :as => as)
    elsif via == :sudo
      sudo(:as => as)
    else
      ""
    end
  end

  # Same as sudo, but tries sudo with :as set to the value of the :runner
  # variable (which defaults to "app").
  def try_runner(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    args << options.merge(:as => fetch(:runner, "app"))
    try_sudo(*args)
  end

  # =========================================================================
  # These are the tasks that are available to help with deploying web apps.
  # You can have cap give you a summary of them with `cap -T'.
  # =========================================================================

  namespace :deploy do
    desc <<-DESC
      Deploys your project. This calls both `update' and `restart'. Note that \
      this will generally only work for applications that have already been deployed \
      once.
    DESC
    task :default do
      update
      restart
    end

    desc <<-DESC
      Copies your project and updates the symlink. It does this in a \
      transaction, so that if either `update_code' or `symlink' fail, all \
      changes made to the remote servers will be rolled back, leaving your \
      system in the same state it was in before `update' was invoked. Usually, \
      you will want to call `deploy' instead of `update', but `update' can be \
      handy if you want to deploy, but not immediately restart your application.
    DESC
    task :update do
      transaction do
        update_code
        symlink
      end
    end

    task :bootstrap_code, :except => { :no_release => true } do
      if releases.length < 2 # without services and run as root
        run "[[ -d #{deploy_to} ]] || #{try_sudo} install -v -d -m #{dir_perms} #{try_sudo.empty? ? '' : "-o #{root_user} -g #{root_group}"} #{deploy_to}"
        run "#{try_sudo} install -v -d -m #{dir_perms} #{try_sudo.empty? ? '' : "-o #{user} -g #{group}"} #{releases_path} #{deploy_to}/log"
      else
        dirs = [ releases_path, service_path, service_drop, log_path ]
        dir_args = dirs.map {|d| d.sub("#{deploy_to}/", "") }.join(' ')
        run "#{try_sudo} install -v -d -m #{dir_perms} #{try_sudo.empty? ? '' : "-o #{user} -g #{group}"} #{deploy_to}"
        run "cd #{deploy_to} && install -v -d -m #{dir_perms} #{dir_args}"
      end
    end

    desc <<-DESC
      Copies your project to the remote servers. This is the first stage \
      of any deployment; moving your updated code and assets to the deployment \
      servers. You will rarely call this task directly, however; instead, you \
      should call the `deploy' task (to do a complete deploy) or the `update' \
      task (if you want to perform the `restart' task separately).
    DESC
    task :update_code, :except => { :no_release => true } do
      bootstrap_code
      strategy.deploy!
      bundle
      cook
    end

    task :symlink_next, :except => { :no_release => true } do
      if releases.length >= 2
          run "ln -vnfs #{current_release} #{next_path}"
      end
    end

    desc <<-DESC
      Updates the symlink to the most recently deployed version. Capistrano works \
      by putting each new release of your application in its own directory. When \
      you deploy a new version, this task's job is to update the `current' symlink \
      to point at the new version. You will rarely need to call this task \
      directly; instead, use the `deploy' task (which performs a complete \
      deploy, including `restart') or the 'update' task (which does everything \
      except `restart').
    DESC
    task :symlink, :except => { :no_release => true } do
      if releases.length > 0
        on_rollback do
          if rollback_release
            run "rm -fv #{previous_path} #{next_path}; true"
            run "ln -vnfs #{rollback_release} #{current_path}; true"
          else
            logger.important "no previous release to rollback to, rollback of symlink skipped"
          end
        end

        if releases.length == 1
          run "ln -vnfs #{current_release} #{current_path}"
        else
          run "rm -fv #{previous_path} #{next_path}"
          run "ln -vnfs #{current_release} #{current_path}"
          if current_path != external_path
            run "#{File.dirname(external_path).index(deploy_to) == 0 ? "" : try_sudo} ln -vnfs #{current_path} #{external_path}"
          end
          run "ln -vnfs #{rollback_release} #{previous_path}"
        end

        system "#{figlet} -w 200 #{current_release_name} activated"
      end
    end

    desc <<-DESC
      Copy files to the currently deployed version. This is useful for updating \
      files piecemeal, such as when you need to quickly deploy only a single \
      file. Some files, such as updated templates, images, or stylesheets, \
      might not require a full deploy, and especially in emergency situations \
      it can be handy to just push the updates to production, quickly.

      To use this task, specify the files and directories you want to copy as a \
      comma-delimited list in the FILES environment variable. All directories \
      will be processed recursively, with all files being pushed to the \
      deployment servers.

        $ cap deploy:upload FILES=templates,controller.rb

      Dir globs are also supported:

        $ cap deploy:upload FILES='config/apache/*.conf'
    DESC
    task :upload, :except => { :no_release => true } do
      files = (ENV["FILES"] || "").split(",").map { |f| Dir[f.strip] }.flatten
      abort "Please specify at least one file or directory to update (via the FILES environment variable)" if files.empty?

      files.each { |file| top.upload(file, File.join(current_path, file)) }
    end

    desc <<-DESC
      Restarts your application.
    DESC
    task :restart, :roles => :app, :except => { :no_release => true } do
    end

    desc <<-DESC
      Builds binaries (like assets, jars, format conversions for distribution
      by deploy:dist.
    DESC
    task :build, :roles => :build, :except => { :no_release => true } do
    end

    desc <<-DESC
      Distribute binaries built in deploy:build.
    DESC
    task :dist, :roles => :app, :except => { :no_release => true } do
    end

    desc <<-DESC
      Checkpoint for various language bundlers
    DESC
    task :bundle, :roles => :app, :except => { :no_release => true } do
    end

    desc <<-DESC
      Apply microwave tvdinners to a release directory.
    DESC
    task :cook, :roles => :app, :except => { :no_release => true } do
    end

    desc <<-DESC
      Compares your application.
    DESC
    task :compare, :roles => :app, :except => { :no_release => true } do
      set :current_release_name, "compare"
      update_code
      run "ln -vnfs #{compare_release} #{compare_path}"
    end

    namespace :rollback do
      desc <<-DESC
        [internal] Points the current symlink at the previous revision.
        This is called by the rollback sequence, and should rarely (if
        ever) need to be called directly.
      DESC
      task :revision, :except => { :no_release => true } do
        if previous_release
          system "#{figlet} -w 200 on #{previous_release_name}"
          run "rm -fv #{previous_path} #{next_path}"

          run "ln -vnfs #{previous_release} #{current_path}"
        else
          abort "could not rollback the code because there is no prior release"
        end
      end

      desc <<-DESC
        [internal] Removes the most recently deployed release.
        This is called by the rollback sequence, and should rarely
        (if ever) need to be called directly.
      DESC
      task :cleanup, :except => { :no_release => true } do
      end

      desc <<-DESC
        Rolls back to the previously deployed version. The `current' symlink will \
        be updated to point at the previously deployed version, and then the \
        current release will be removed from the servers. You'll generally want \
        to call `rollback' instead, as it performs a `restart' as well.
      DESC
      task :code, :except => { :no_release => true } do
        revision
        cleanup
      end

      desc <<-DESC
        Rolls back to a previous version and restarts. This is handy if you ever \
        discover that you've deployed a lemon; `cap rollback' and you're right \
        back where you were, on the previously deployed version.
      DESC
      task :default do
        revision
        restart
        cleanup
      end
    end

    desc <<-DESC
      Override in deploy recipes.  Formerly a railsy rake db:migrate.
    DESC
    task :migrate, :roles => :db, :only => { :primary => true } do
      set :current_release_name, "migrate"
      update_code
      run "ln -vnfs #{migrate_release} #{migrate_path}"
    end

    desc <<-DESC
      Test deployment dependencies. Checks things like directory permissions, \
      necessary utilities, and so forth, reporting on the things that appear to \
      be incorrect or missing. This is good for making sure a deploy has a \
      chance of working before you actually run `cap deploy'.

      You can define your own dependencies, as well, using the `depend' method:

        depend :remote, :gem, "tzinfo", ">=0.3.3"
        depend :local, :command, "svn"
        depend :remote, :directory, "/u/depot/files"
    DESC
    task :check, :except => { :no_release => true } do
      dependencies = strategy.check!

      other = fetch(:dependencies, {})
      other.each do |location, types|
        types.each do |type, calls|
          if type == :gem
            dependencies.send(location).command(fetch(:gem_command, "gem")).or("`gem' command could not be found. Try setting :gem_command")
          end

          calls.each do |args|
            dependencies.send(location).send(type, *args)
          end
        end
      end

      if dependencies.pass?
        puts "You appear to have all necessary dependencies installed"
      else
        puts "The following dependencies failed. Please check them and try again:"
        dependencies.reject { |d| d.pass? }.each do |d|
          puts "--> #{d.message}"
        end
        abort
      end
    end

    desc <<-DESC
      Start the application servers.
    DESC
    task :start, :roles => :app do
    end

    desc <<-DESC
      Stop the application servers.
    DESC
    task :stop, :roles => :app do
    end

    namespace :pending do
      desc <<-DESC
        Displays the `diff' since your last deploy. This is useful if you want \
        to examine what changes are about to be deployed. Note that this might \
        not be supported on all SCM's.
      DESC
      task :diff, :except => { :no_release => true } do
        system(source.local.diff(current_revision))
      end

      desc <<-DESC
        Displays the commits since your last deploy. This is good for a summary \
        of the changes that have occurred since the last deploy. Note that this \
        might not be supported on all SCM's.
      DESC
      task :default, :except => { :no_release => true } do
        from = source.next_revision(current_revision)
        system(source.local.log(from))
      end
    end

    task :lock do
      epoch = Time.now.to_i
      locker = ''

      run "cat #{log_path}/.#{application}_deploy_lock 2>&- || true" do |ch, stream, data|
        locker << data
      end

      if !locker.empty?
        lock_epoch = locker.split[0].to_i
        lock_user = locker.split[1]

        lock_elasped = epoch-lock_epoch

        if lock_elasped < lock_timeout
          true # don't do anything if locks timeout, jus advise unlock
        end

        puts "deploy locked by #{lock_user} #{epoch-lock_epoch} seconds ago"
        puts "use bin/unlock to remove this lock"
        abort
      end

      run_script = <<-SCRIPT
        echo #{epoch} #{ENV['AO_USER']} > #{log_path}/.#{application}_deploy_lock;
      SCRIPT

      if want_unlock
        at_exit { self.unlock; }
      end

      run run_script.gsub(/[\n\r]+[ \t]+/, " ")
    end

    task :dont_unlock  do
      set :want_unlock, false
    end

    task :unlock do
      if want_unlock
        run "rm -f #{log_path}/.#{application}_deploy_lock"
      end
    end

  end # :deploy

  namespace :ruby do
    task :bundle do
      run_script = <<-SCRIPT
        set -e; cd #{current_release};
      SCRIPT

      run_script += <<-SCRIPT
        #{ruby_loader} bundle check 2>&1 > /dev/null || { #{ruby_loader} bundle install --quiet --local #{bundler_options} && #{ruby_loader} bundle check > /dev/null; };
      SCRIPT

      run run_script.gsub(/[\n\r]+[ \t]+/, " ")
    end
  end

  after "deploy:bundle", "ruby:bundle"

  namespace :node do
    task :bundle do
      run_script = <<-SCRIPT
        set -e; cd #{current_release};
      SCRIPT

      run_script += <<-SCRIPT
        npm install;
      SCRIPT

      run run_script.gsub(/[\n\r]+[ \t]+/, " ")
    end
  end

  on :exit do
    unless local_only
      put full_log, "#{log_path}/#{application}-#{ENV["AO_USER"]}.log-#{Time.now.strftime('%Y%m%d-%H%M')}"
    end
  end

end # Capistrano::Configuration
