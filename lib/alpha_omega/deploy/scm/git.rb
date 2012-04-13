require 'alpha_omega/deploy/scm/base'

module Capistrano
  module Deploy
    module SCM

      # An SCM module for using Git as your source control tool with Capistrano
      # 2.0.
      #
      # Assumes you are using a shared Git repository.
      #
      # Parts of this plugin borrowed from Scott Chacon's version, which I
      # found on the Capistrano mailing list but failed to be able to get
      # working.
      #
      # FEATURES:
      #
      #   * Very simple, only requiring 2 lines in your deploy.rb.
      #   * Can deploy different branches, tags, or any SHA1 easily.
      #   * Supports :scm_command Capistrano directive.
      #
      # CONFIGURATION
      # -------------
      #
      # Use this plugin by adding the following line in your config/deploy.rb:
      #
      #   set :scm, :git
      #
      # Set <tt>:repository</tt> to the path of your Git repo:
      #
      #   set :repository, "someuser@somehost:/home/myproject"
      #
      # The above two options are required to be set, the ones below are
      # optional.
      #
      # You may set <tt>:branch</tt>, which is the reference to the branch, tag,
      # or any SHA1 you are deploying, for example:
      #
      #   set :branch, "master"
      #
      # Otherwise, HEAD is assumed.  I strongly suggest you set this.  HEAD is
      # not always the best assumption.
      #
      # The <tt>:scm_command</tt> configuration variable, if specified, will
      # be used as the full path to the git executable on the *remote* machine:
      #
      #   set :scm_command, "/opt/local/bin/git"
      #
      # AUTHORS
      # -------
      #
      # Garry Dolley http://scie.nti.st
      # Contributions by Geoffrey Grosenbach http://topfunky.com
      #              Scott Chacon http://jointheconversation.org
      #                          Alex Arnell http://twologic.com
      #                                   and Phillip Goldenburg

      class Git < Base
        # Sets the default command name for this SCM on your *local* machine.
        # Users may override this by setting the :scm_command variable.
        default_command "git"

        # When referencing "head", use the branch we want to deploy or, by
        # default, Git's reference of HEAD (the latest changeset in the default
        # branch, usually called "master").
        def head
          variable(:branch) || 'HEAD'
        end

        # Performs a clone on the remote machine, then checkout on the branch
        # you want to deploy.
        def checkout(revision, destination)
          git = command

          execute = []

          execute << "[[ -d #{destination}/.git ]] || #{git} clone #{verbose} #{variable(:repository)} #{destination}"
          execute << "cd #{destination} && #{git} fetch -q && #{git} checkout -q --force #{revision}"
          execute << "cd #{destination} && #{git} reset --hard #{revision} && #{git} submodule update --init --recursive"

          execute
        end

        # Returns a string of diffs between two revisions
        def diff(from, to=nil)
          from << "..#{to}" if to
          scm :diff, from
        end

        # Returns a log of changes between the two revisions (inclusive).
        def log(from, to=nil)
          scm :log, "#{from}..#{to}"
        end

        # Getting the actual commit id, in case we were passed a tag
        # or partial sha or something - it will return the sha if you pass a sha, too
        def query_revision(revision)
          raise ArgumentError, "Deploying remote branches is no longer supported.  Specify the remote branch as a local branch for the git repository you're deploying from (ie: '#{revision.gsub('origin/', '')}' rather than '#{revision}')." if revision =~ /^origin\//
          return revision if revision =~ /^[0-9a-f]{40}$/
          command = scm('ls-remote', repository, revision)
          result = yield(command)
          revdata = result.split(/[\t\n]/)
          newrev = nil
          revdata.each_slice(2) do |refs|
            rev, ref = *refs
            if ref.sub(/refs\/.*?\//, '').strip == revision.to_s
              newrev = rev
              break
            end
          end
          raise "Unable to resolve revision for '#{revision}' on repository '#{repository}'." unless newrev =~ /^[0-9a-f]{40}$/
          return newrev
        end

        private

          # If verbose output is requested, return nil, otherwise return the
          # command-line switch for "quiet" ("-q").
          def verbose
            variable(:scm_verbose) ? nil : "-q"
          end
      end
    end
  end
end
