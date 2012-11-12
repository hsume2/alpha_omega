# taken from https://github.com/PagerDuty/pd-cap-recipes/blob/master/lib/pd-cap-recipes/tasks/performance.rb
Capistrano::Configuration.instance(:must_exist).load do |config|
  start_times = {}
  end_times = {}
  order = []

  on :before do 
    unless skip_performance
      order << [:start, current_task]
      start_times[current_task] = Time.now    
    end
  end

  on :after do 
    unless skip_performance
      unless skip_performance_task == current_task
        order << [:end, current_task]
        end_times[current_task] = Time.now    
      end
    end
  end

  config.on :exit do
    unless ENV['LOCAL_ONLY'] && !ENV['LOCAL_ONLY'].empty?
      print_report(start_times, end_times, order)
    end
  end

  def print_report(start_times, end_times, order)
    def l(s)
      logger.info s
    end

    l " Performance Report"
    l "=========================================================="
    
    indent = 0 
    (order + [nil]).each_cons(2) do |payload1, payload2|
      action, task = payload1
      if action == :start
        l "#{".." * indent}#{task.fully_qualified_name}" unless task == payload2.last
        indent += 1
      else
        indent -= 1
        if end_times[task] && start_times[task]
          l "#{".." * indent}#{task.fully_qualified_name} #{(end_times[task] - start_times[task]).to_i}s"
        end
      end
    end
    l "=========================================================="
  end

  namespace :deploy do
    namespace :enable do
      task :performance do
        set :skip_performance, false
        set :skip_performance_task, current_task
      end
    end
  end

  before "deploy:began", "deploy:enable:performance"
end
