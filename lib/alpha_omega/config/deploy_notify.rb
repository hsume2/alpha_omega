require 'tempfile'

Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :deploy do
    namespace :notify do
      task :default do
        if $deploy["notify"]
          unless skip_notifications
            airbrake if $deploy["notify"].member? "airbrake"
            newrelic if $deploy["notify"].member? "newrelic"
            campfire if $deploy["notify"].member? "campfire"
            flowdock if $deploy["notify"].member? "flowdock"
          end

          email if $deploy["notify"].member? "email"
        end
      end

      task :campfire do
        require 'capistrano/campfire'

        set :campfire_options, 
              :ssl => true,
              :account => $deploy["notify"]["campfire"]["account"],
              :room => $deploy["notify"]["campfire"]["room"],
              :email => $deploy["notify"]["campfire"]["email"],
              :token => $deploy["notify"]["campfire"]["token"]

        begin 
          campfire_room.speak notify_message
        rescue
          $stderr.puts "Campfire announcement failed"
        end
      end

      task :airbrake do
        require 'airbrake'
        require 'airbrake_tasks'

        Airbrake.configure do |config|
          config.api_key = $deploy["notify"]["airbrake"]["api_key"]
        end
        
        begin
          AirbrakeTasks.deploy({
            :rails_env      => dna['app_env'],
            :scm_revision   => "#{real_revision} #{revision}",
            :scm_repository => repository,
            :local_username => ENV['_AO_DEPLOYER']
          })
        rescue EOFError
          $stderr.puts "An error occurred during the Airtoad deploy notification."
        end
      end

      task :flowdock do
        require 'flowdock'

        flow = Flowdock::Flow.new(:api_token => $deploy["notify"]["flowdock"]["api_token"])
                    
        flow.push_to_team_inbox(
          :subject => "Application #{$deploy["application"]} deployed #deploy",
          :content => "Application deployed successfully!", 
          :tags => $deploy["notify"]["flowdock"]["tags"],
          :source => "alpha_omega deployment",
          :from => {
            :address => $deploy["notify"]["flowdock"]["from"]["address"],
            :name => $deploy["notify"]["flowdock"]["from"]["name"]
          },
          :project => $deploy["notify"]["flowdock"]["project"])
      end 

      task :newrelic do
        require 'new_relic/recipes'
      end

      task :email do
        tmp_notify = Tempfile.new('email')
        tmp_notify.write notify_message
        tmp_notify.close
        run_locally "cat '#{tmp_notify.path}' | mail -s '#{notify_message_abbr}' #{$deploy["notify"]["email"]["recipients"].join(" ")}"
        tmp_notify.unlink
      end

      def map_sha_tag rev
        %x(git show-ref | grep '^#{rev} refs/tags/' | cut -d/ -f3).chomp
      end

      def public_git_url url
        url.sub("git@github.com:","https://github.com/").sub(/\.git$/,'')
      end

      def notify_message
        if dna["app_env"] == "production"
          summary = "#{public_git_url repository}/compare/#{map_sha_tag cmp_previous_revision}...#{map_sha_tag cmp_current_revision}"
        else
          summary = "#{public_git_url repository)}/commit/#{cmp_current_revision}"
        end

        "#{ENV['_AO_DEPLOYER']} deployed #{application} to #{ENV['_AO_ARGS']} (#{dna['app_env']}): #{ENV['FLAGS_tag']}" +
        "\n\nSummary:\n\n" + summary + 
        "\n\nLog:\n\n" + full_log
      end 

      def notify_message_abbr
        "#{ENV['_AO_DEPLOYER']} deployed #{application} to #{ENV['_AO_ARGS']} (#{dna['app_env']}): #{ENV['FLAGS_tag']}"
      end 
    end
  end

  after "deploy:restart", "deploy:notify"
end
