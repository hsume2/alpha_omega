require 'capistrano'
require 'yaml'

module AlphaOmega

  def self.echo_magic
    "eea914aaa8dde6fdae29242b1084a2b0415eefaf"
  end

  def self.default_pods_tasks
    Proc.new do |config, pod_name, pod, mix_pods|
      # world task accumulates all.* after tasks
      config.task "world" do
      end

      config.task "world.echo" do
      end

      # each pod task sets the pod context for host/group tasks
      config.task pod_name do
        set :current_pod, pod_name
      end

      config.task "#{pod_name}.echo" do
        set :current_pod, pod_name
      end

      hosts =
        AlphaOmega.what_hosts pod do |task_name, remote_name, node|
          config.task "#{task_name}.#{pod_name}" do
            role :app, remote_name
          end
        
          config.task task_name do
            after task_name, "#{task_name}.#{current_pod}"
          end

          config.task "#{task_name}.#{pod_name}.echo" do
            puts "#{AlphaOmega.echo_magic} #{remote_name}"
          end
        
          config.task "#{task_name}.echo" do
            after "#{task_name}.echo", "#{task_name}.#{current_pod}.echo"
          end

        end

      AlphaOmega.what_groups hosts do |task_name, nodes|
        if task_name == "all"
          # simulate all podXX all
          unless pod_name == "default"
            config.after "world", pod_name
            config.after "world.echo", "#{pod_name}.echo"
          end
          
          config.after "world", task_name
          config.after "world.echo", "#{task_name}.echo"
        end

        config.task "#{task_name}.#{pod_name}" do
          unless mix_pods
            if last_pod && last_pod != pod_name
              puts "ERROR: cannot call tasks that mix different dc_env (last pod = #{last_pod}, current pod = #{pod_name})"
              exit 1
            end
          end

          set :last_pod, pod_name
          nodes.keys.sort.each do |remote_name|
            role :app, remote_name
          end
        end

        config.task task_name do
          after task_name, "#{task_name}.#{current_pod}"
        end

        config.task "#{task_name}.#{pod_name}.echo" do
          unless mix_pods
            if last_pod && last_pod != pod_name
              puts "ERROR: cannot call tasks that mix different dc_env (last pod = #{last_pod}, current pod = #{pod_name})"
              exit 1
            end
          end

          set :last_pod, pod_name
          nodes.keys.sort.each do |remote_name|
            puts "#{AlphaOmega.echo_magic} #{remote_name}"
          end
        end

        config.task "#{task_name}.echo" do
          after "#{task_name}.echo", "#{task_name}.#{current_pod}.echo"
        end
      end
    end
  end

  def self.setup_pods (config, node_home, mix_pods = true)
    self.what_pods(config, node_home) { |config, pod_name, pod| self.default_pods_tasks.call(config, pod_name, pod, mix_pods) }
  end

  def self.what_branch (allowed = %w(production master develop))
    if ENV["BRANCH"]
      ENV["BRANCH"]
    elsif ENV["TAG"]
      ENV["TAG"]
    else
      current = `git branch`.split("\n").find {|b| b.split(" ")[0] == '*' } # use Grit
      if current
        star, branch_name = current.split(" ")
        branch_type, branch_feature = branch_name.split("/")
        if %w(feature hotfix).member?(branch_type)
          branch_name
        elsif !branch_feature && allowed.member?(branch_type)
          branch_type
        else
          puts "current branch must be #{allowed.join(', ')}, feature/xyz, or hotfix/xyz"
          abort
        end
      else
        puts "could not find a suitable branch"
        abort
      end
    end
  end

  def self.what_pods (config, node_home)
    pods = { }

    this_pod = File.read("/etc/podname").strip
    pods["default"] = {
      "nodes_spec" => "#{node_home}/pods/#{this_pod}/*.yaml",
      "node_suffix" => ""
    }
    yield config, "default", pods[this_pod] # TODO get rid of default and use this_pod

    this_host = Socket.gethostname.chomp.split(".")[0]
    this_node = YAML.load(File.read("#{node_home}/pods/#{this_pod}/#{this_host}.yaml"))

    (this_node["pods"] || []).each do |pod_name|
      pods[pod_name] = { 
        "nodes_spec" => "#{node_home}/pods/#{pod_name}/*.yaml",
        "node_suffix" => ".#{pod_name}"
      }
      yield config, pod_name, pods[pod_name]
    end

    pods
  end

  def self.what_hosts (pod)
    # load all the nodes and define cap tasks
    nodes = {}

    Dir[pod["nodes_spec"]].each do |fname|
      node_name = File.basename(fname, ".yaml")

      node = YAML.load(IO.read(fname))
      node["node_name"] = node_name
      node["pod_context"] = pod

      nodes[node_name] = node

      yield node_name, "#{node_name}#{pod["node_suffix"]}", node unless node["virtual"]
    end

    nodes

  end

  def self.what_groups (nodes)
    # generalize groups
    cap_groups = {}

    nodes.each do |node_name, node|
      remote_name = "#{node_name}#{node["pod_context"]["node_suffix"]}"
      (node["cap_group"] || []).each do |g|
        cap_groups[g] ||= {}
        cap_groups[g][remote_name] = node
      end
    end

    cap_groups.each do |group_name, nodes|
      yield group_name, nodes
    end

    cap_groups
  end

end

