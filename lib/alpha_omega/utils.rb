require 'capistrano'

module AlphaOmega

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

  def self.what_hosts (nodes_spec)
    # load all the nodes and define cap tasks
    nodes = {}

    Dir[nodes_spec].each do |fname|
      node_name = File.basename(fname, ".json")

      node = JSON.parse(IO.read(fname))
      node["node_name"] = node_name

      nodes[node_name] = node

      yield node_name, node unless node["virtual"]
    end

    nodes

  end

  def self.what_groups (nodes)
    # generalize groups
    cap_groups = {}

    nodes.each do |node_name, node|
      %w(chef_group cap_group).each do |nm_group| # TODO get rid of chef_group
        if node.member?(nm_group) && !node["ignore"]
          node[nm_group].each do |g|
            cap_groups[g] ||= {}
            cap_groups[g][node_name] = node
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

