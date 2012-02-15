require 'capistrano'
require 'yaml'
require 'deep_merge'

module AlphaOmega

  def self.magic_prefix
    "eea914aaa8dde6fdae29242b1084a2b0415eefaf"
  end

  def self.node_defaults(node, pods_config, opsdb, env_pod, this_pod, node_name)
    env_pod = this_pod if env_pod == "default" # TODO get rid of default
    node_name = node_name.split(".").first

    node["node_name"] = node_name

    # defaults
    node["run_list"] ||= []
    node["cap_group"] ||= []
    node["nagios_group"] ||= []
    node["private_aliases"] ||= []
    node["node"] = nil

    # enrich with pods config
    node["env_pod"] = env_pod
    node.deep_merge!(pods_config[env_pod])

    # enrich with opsdb
    node.deep_merge!(opsdb[env_pod][node_name]) if opsdb[env_pod].key? node_name

    node["run_list"] = node["run_list"].clone # TODO without a clone, node.run_list also updates pods_config.env_pod.run_list

    # derive
    node["fq_domain"] = %w(env_pod env_dc dc_domain).collect {|s| node[s] }.uniq.join(".")
    node["fq_name"] = %w(node_name env_pod env_dc dc_domain).collect {|s| node[s] }.uniq.join(".")
    node["p_name"] = "#{node["node_name"]}.#{node["env_pod"]}"

    # check if managed
    if this_pod != env_pod # TODO get rid of default, use this_pod
      node["q_name"] = "#{node["node_name"]}.#{node["env_pod"]}"
      node["managed"] = true
    else
      node["q_name"] = node["node_name"]
      node["managed"] = false
    end

    # check if infra pod
    if node["env_pod"] == node["env_dc"]
      node["infra"] = true
    else
      node["infra"] = false
      node["infra_domain"] = "#{node["env_dc"]}.#{node["dc_domain"]}"
    end

    node["run_list"].concat pods_config[env_pod]["run_list"] if pods_config[env_pod].key? "run_list"

    node["cap_group"] << "all"
    node["cap_group"] << node_name.sub(/\d+/, "")

    node["cap_group"].concat pods_config[env_pod]["cap_group"] if pods_config[env_pod].key? "cap_group"

    node
  end

  def self.default_pods_tasks
    Proc.new do |config, pod_name, pod, mix_pods, pods_config, opsdb, this_pod, &node_filter|
      [ "", ".echo", ".yaml" ].each do |tsuffix|
         # world task accumulates all.* after tasks
        config.task "world#{tsuffix}" do
        end

        # each pod task sets the pod context for host/group tasks
        config.task "#{pod_name}#{tsuffix}" do
          set :current_pod, pod_name
        end
      end

      hosts =
        AlphaOmega.what_hosts pod do |task_name, remote_name, node|
          n = AlphaOmega.node_defaults(node, pods_config, opsdb, pod_name, this_pod, remote_name)

          if node_filter.nil? || node_filter.call(n)
            config.task "#{task_name}.#{pod_name}" do
              role :app, remote_name
            end
          
            config.task "#{task_name}.#{pod_name}.echo" do
              puts "#{AlphaOmega.magic_prefix} #{remote_name}"
            end
          
            config.task "#{task_name}.#{pod_name}.yaml" do
              StringIO.new({ remote_name => n }.to_yaml).lines.each {|l| puts "#{AlphaOmega.magic_prefix} #{l}" }
            end
          
            [ "", ".echo", ".yaml" ].each do |tsuffix|
              config.task "#{task_name}#{tsuffix}" do
                after "#{task_name}#{tsuffix}", "#{task_name}.#{current_pod}#{tsuffix}"
              end
            end

            puts "found #{n["node_name"]}"
            n
          else
            nil
          end
        end

      AlphaOmega.what_groups hosts do |task_name, nodes|
        if task_name == "all"
          # simulate all podXX all
          [ "", ".echo", ".yaml" ].each do |tsuffix|
            unless pod_name == "default"
              config.after "world#{tsuffix}", "#{pod_name}#{tsuffix}"
            end
            config.after "world#{tsuffix}", "#{task_name}#{tsuffix}"
          end
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

        config.task "#{task_name}.#{pod_name}.echo" do
          unless mix_pods
            if last_pod && last_pod != pod_name
              puts "ERROR: cannot call tasks that mix different dc_env (last pod = #{last_pod}, current pod = #{pod_name})"
              exit 1
            end
          end

          set :last_pod, pod_name
          nodes.keys.sort.each do |remote_name|
            puts "#{AlphaOmega.magic_prefix} #{remote_name}"
          end
        end

        config.task "#{task_name}.#{pod_name}.yaml" do
          unless mix_pods
            if last_pod && last_pod != pod_name
              puts "ERROR: cannot call tasks that mix different dc_env (last pod = #{last_pod}, current pod = #{pod_name})"
              exit 1
            end
          end

          set :last_pod, pod_name
          nodes.sort.each do |remote_name, node|
            StringIO.new({ remote_name => node }.to_yaml).lines.each {|l| puts "#{AlphaOmega.magic_prefix} #{l}" }
          end
        end

        [ "", ".echo", ".yaml" ].each do |tsuffix|
          config.task "#{task_name}#{tsuffix}" do
            after "#{task_name}#{tsuffix}", "#{task_name}.#{current_pod}#{tsuffix}"
          end
        end
      end
    end
  end

  def self.setup_pods (config, node_home, mix_pods = true, &node_filter)
    self.what_pods(config, node_home) do |config, pod_name, pod, pods_config, opsdb, this_pod| 
      self.default_pods_tasks.call(config, pod_name, pod, mix_pods, pods_config, opsdb, this_pod, &node_filter) 
    end
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
    # pods config
    pods_config = YAML.load(File.read("#{node_home}/config/pods.yml"))

    # opsdb config
    opsdb = Dir["#{node_home}/config/pod/*.yaml"].inject({}) do |acc, fname|
      env_pod = File.basename(File.basename(fname, ".yaml"), ".json")
      acc[env_pod] = YAML.load(File.read(fname))
      acc
    end

    pods = { }

    this_pod = File.read("/etc/podname").strip
    pods["default"] = {
      "nodes_specs" => [ "#{node_home}/pods/#{this_pod}/*.yaml", "#{node_home}/pods/#{this_pod}/*.json" ],
      "node_suffix" => ""
    }
    yield config, "default", pods["default"], pods_config, opsdb, this_pod # TODO get rid of default and use this_pod

    this_host = Socket.gethostname.chomp.split(".")[0]
    n = File.exists?("#{node_home}/pods/#{this_pod}/#{this_host}.yaml") ? YAML.load(File.read("#{node_home}/pods/#{this_pod}/#{this_host}.yaml")) : JSON.load(File.read("#{node_home}/pods/#{this_pod}/#{this_host}.json"))
    this_node = AlphaOmega.node_defaults(n, pods_config, opsdb, this_pod, this_pod, this_host)

    (this_node["pods"] || []).each do |pod_name|
      pods[pod_name] = { 
        "nodes_specs" => [ "#{node_home}/pods/#{pod_name}/*.yaml", "#{node_home}/pods/#{pod_name}/*.json" ],
        "node_suffix" => ".#{pod_name}"
      }
      yield config, pod_name, pods[pod_name], pods_config, opsdb, this_pod
    end

    pods
  end

  def self.what_hosts (pod)
    # load all the nodes and define cap tasks
    pod["nodes_specs"].inject({}) do |hosts, spec|
      Dir[spec].inject(hosts) do |acc, fname|
        node_name = File.basename(File.basename(fname, ".yaml"), ".json")

        node = YAML.load(IO.read(fname))
        node["node_name"] = node_name

        n = yield node_name, "#{node_name}#{pod["node_suffix"]}", node unless node["virtual"]
        acc[node_name] = n if n
        acc
      end
    end
  end

  def self.what_groups (nodes)
    # generalize groups
    cap_groups = {}

    nodes.each do |node_name, node|
      node["cap_group"].each do |g|
        cap_groups[g] ||= {}
        cap_groups[g][node["q_name"]] = node
      end
    end

    cap_groups.each do |group_name, nodes|
      yield group_name, nodes
    end

    cap_groups
  end
end
