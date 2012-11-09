Capistrano::Configuration.instance(:must_exist).load do |config|
  set :reviewed, nil

  namespace :deploy do
    task :challenge do
      if dna["app_env"] == "production"
        who = Capistrano::CLI.ui.ask(" -- Who has reviewed this deploy to #{dna["app_env"]}? ")
        if who.empty?
          abort
        else
          set :reviewed, who
          sleep 3
        end

        unless ENV['FLAGS_tag'] && !ENV['FLAGS_tag'].empty?
          puts "Did not specify a tag for production"
          abort
        end
      end
    end
  end

  before "deploy:began", "deploy:challenge"
end
