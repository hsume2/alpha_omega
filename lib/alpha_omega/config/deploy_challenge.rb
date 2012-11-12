Capistrano::Configuration.instance(:must_exist).load do |config|
  set :reviewed, nil

  namespace :deploy do
    task :challenge do
      if dna["app_env"] == "production"
        unless ENV['FLAGS_tag'] && !(ENV['FLAGS_tag'].empty? || ENV['FLAGS_tag'] == "HEAD")
          puts "Did not specify a tag for production via -t vX.Y.Z"
          abort
        end

        a, b = rand(10), rand(10)
        if Capistrano::CLI.ui.ask(" -- WARNING: Accessing production, please think: #{a} + #{b} = ").downcase.strip.to_i != (a + b)
          abort
        else
          sleep(3)
        end
      end
    end
  end

  before "deploy:began", "deploy:challenge"
end
