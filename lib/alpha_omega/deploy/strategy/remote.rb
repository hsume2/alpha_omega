require 'alpha_omega/deploy/strategy/base'

module Capistrano
  module Deploy
    module Strategy

      # An abstract superclass, which forms the base for all deployment
      # strategies which work by grabbing the code from the repository directly
      # from remote host.
      class Remote < Base
        # Executes the SCM command for this strategy and writes the REVISION
        # mark file to each host.
        def deploy!
          commands.each do |command|
            run command
          end
          run mark
        end

        def check!
          super.check do |d|
            d.remote.command(source.command)
          end
        end

        protected

          # An abstract method which must be overridden in subclasses, to
          # return the actual SCM command(s) which must be executed on each
          # target host in order to perform the deployment.
          def commands
            raise NotImplementedError, "`command' is not implemented by #{self.class.name}"
          end

          # Returns the command which will write the identifier of the
          # revision being deployed to the REVISION file on each host.
          def mark
            "echo #{revision} > #{configuration[:current_release]}/REVISION"
          end
      end

    end
  end
end
