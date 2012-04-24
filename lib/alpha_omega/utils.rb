require 'capistrano'
require 'yaml'
require 'deep_merge'

$this_pod = nil
$opsdb = nil
$pods_config = nil

module AlphaOmega

  def self.magic_prefix
    "eea914aaa8dde6fdae29242b1084a2b0415eefaf"
  end

  def self.node_defaults(node, env_pod, node_name)
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
    node.deep_merge!($pods_config[env_pod])

    # enrich with opsdb
    node.deep_merge!($opsdb[env_pod][node_name]) if $opsdb[env_pod].key? node_name

    node["run_list"] = node["run_list"].clone # TODO without a clone, node.run_list also updates pods_config.env_pod.run_list

    # derive
    node["fq_domain"] = %w(env_pod env_dc dc_domain).collect {|s| node[s] }.uniq.join(".")
    node["fq_name"] = %w(node_name env_pod env_dc dc_domain).collect {|s| node[s] }.uniq.join(".")
    node["p_name"] = "#{node["node_name"]}.#{node["env_pod"]}"

    # check if managed
    if $this_pod != env_pod
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

    node["run_list"].concat $pods_config[env_pod]["run_list"] if $pods_config[env_pod].key? "run_list"

    node["cap_group"] << "all"

    node["cap_group"].concat $pods_config[env_pod]["cap_group"] if $pods_config[env_pod].key? "cap_group"

    node
  end

  def self.default_pods_tasks
    Proc.new do |config, pod_name, pod, this_node, &node_filter|
      %w(app echo yaml).each do |tsuffix|
         # world task accumulates all.* after tasks
        config.task "world.#{tsuffix}" do # task world
        end

        # each pod task sets the pod context for host/group tasks
        config.task "#{pod_name}.#{tsuffix}" do # task default, pod1
          set :current_pod, pod_name
        end
      end

      node_dna = { }
      hosts =
        AlphaOmega.what_hosts pod do |task_name, remote_name, node|
          n = AlphaOmega.node_defaults(node, pod_name, remote_name)
          node_dna[remote_name] = {}
          node_dna[remote_name].deep_merge!(n)

          if node_filter.nil? || node_filter.call(this_node, n)
            config.task "#{task_name}.#{pod_name}.app" do # task host.default.app, host.pod1.app
              role :app, remote_name
              set :dna, node_dna[remote_name]
            end
          
            config.task "#{task_name}.#{pod_name}.echo" do # task host.default.echo, host.pod1.echo
              puts "#{AlphaOmega.magic_prefix} #{remote_name}"
            end
          
            config.task "#{task_name}.#{pod_name}.yaml" do # task host.default.yaml, host.pod1..yaml
              StringIO.new({ remote_name => n }.to_yaml).lines.to_a[1..-1].each {|l| puts "#{AlphaOmega.magic_prefix} #{l}" }
            end
          
            %w(app echo yaml).each do |tsuffix|
              config.task "#{task_name}.#{tsuffix}" do # task host -> host.current_pod
                config.after "#{task_name}.#{tsuffix}", "#{task_name}.#{current_pod}.#{tsuffix}"
              end
            end

            n
          else
            nil
          end
        end

      AlphaOmega.what_groups hosts do |task_name, nodes|
        if task_name == "all"
          # simulate all podXX all
          %w(app echo yaml).each do |tsuffix|
            config.after "world.#{tsuffix}", "#{pod_name}.#{tsuffix}" # podXX
            config.after "world.#{tsuffix}", "#{task_name}.#{tsuffix}" # all
          end
        end

        %w(app echo yaml).each do |tsuffix|
          config.task "#{task_name}.#{pod_name}.#{tsuffix}" do
          end

          nodes.keys.sort.each do |remote_name|
            config.after "#{task_name}.#{pod_name}.#{tsuffix}", "#{remote_name}.#{tsuffix}"
          end

          config.task "#{task_name}.#{tsuffix}" do
            config.after "#{task_name}.#{tsuffix}", "#{task_name}.#{current_pod}.#{tsuffix}"
          end
        end
      end
    end
  end

  def self.setup_pods (config, node_home, &node_filter)
    self.what_pods(config, node_home) do |config, pod_name, pod, this_node| 
      self.default_pods_tasks.call(config, pod_name, pod, this_node, &node_filter) 
    end
  end

  def self.what_branch (allowed = %w(production staging master develop) + [%r(/)])
    current = `cat .git/HEAD`.strip.split(" ")
    if current[0] == "ref:"
      branch_name = current[1].split("/")[2..-1].join("/")
      if allowed.any? {|rx| rx.match(branch_name) }
        branch_name
      else
        puts "current branch must be one of #{allowed.join(', ')}"
        abort
      end
    else
      current[0]
    end
  end

  def self.what_pods (config, node_home)
    # pods config
    $pods_config = YAML.load(File.read("#{node_home}/config/pods.yml"))

    # opsdb config
    $opsdb = Dir["#{node_home}/config/pod/*.yaml"].inject({}) do |acc, fname|
      env_pod = File.basename(File.basename(fname, ".yaml"), ".json")
      acc[env_pod] = YAML.load(File.read(fname))
      acc
    end

    $this_pod = File.read("/etc/podname").strip
    config.set :current_pod, $this_pod
    
    this_host = Socket.gethostname.chomp.split(".")[0]
    dna_base = "#{node_home}/pods/#{$this_pod}/#{this_host}"
    dna = File.exists?("#{dna_base}.yaml") ? YAML.load(File.read("#{dna_base}.yaml")) : JSON.load(File.read("#{dna_base}.json"))
    this_node = AlphaOmega.node_defaults(dna, $this_pod, this_host)

    ((this_node["pods"] || []) + [$this_pod]).ineject{}) do |pods, pod_name|
      pods[pod_name] = { 
        "nodes_specs" => [ "#{node_home}/pods/#{pod_name}/*.yaml", "#{node_home}/pods/#{pod_name}/*.json" ],
        "node_suffix" => (pod_name == $this_pod ? "" : ".#{pod_name}")
      }
      yield config, pod_name, pods[pod_name], this_node
      pods
    end
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
      unless nodes.member? group_name
        yield group_name, nodes
      end
    end

    cap_groups
  end
end
