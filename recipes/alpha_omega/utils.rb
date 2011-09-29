require 'capistrano'

module AlphaOmega

  def self.what_branch
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
        elsif !branch_feature && allow_branches.member?(branch_type)
          branch_type
        else
          puts "current branch must be #{allow_branches.join(', ')}, feature/xyz, or hotfix/xyz"
          abort
        end
      else
        puts "could not find a suitable branch"
        abort
      end
    end
  end

  def self.what_hosts (nodes_spec)
    # load all the nodes and define cap tasks
    nodes = {}

    Dir[nodes_spec].each do |fname|
      nm_node = File.basename(fname, ".json")

      node = JSON.parse(IO.read(fname))
      node[:node_name] = nm_node

      nodes[nm_node] = node

      yield node if node[:node_name] && node["public_ip"] # TODO is the :node_name test necessary?
    end

    nodes

  end

  def self.what_groups (nodes)
    # generalize groups
    cap_groups = {}

    nodes.each do |nm_node, node|
      %w(chef_group cap_group).each do |nm_group| # TODO get rid of chef_group
        if node.member?(nm_group) && !node["ignore"]
          node[nm_group].each do |g|
            cap_groups[g] ||= {}
            cap_groups[g][nm_node] = node
          end
        end
      end
    end

    cap_groups.each do |nm_group, group|
      yield nm_group, group
    end

    cap_groups
  end

end

