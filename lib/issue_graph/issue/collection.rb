require 'ruby-graphviz'
require 'issue_graph/issue'

class IssueGraph::Issue::Collection
  attr_reader :graph, :repo_name, :repo_id, :repo, :gh_client, :zh_client

  def <<(issue)
    @issues[issue.name] = issue
  end

  def [](name)
    @issues[name]
  end

  # Add our issue to our internal graph. Don't add them to the graphviz object yet.
  # It makes more sense to wait until our object is fully constructred.
  def add(issue)
    @issues[issue.name] = issue
  end

  # Add an edge to the graph.
  # Note we don't add it to the graphviz object. We do that once our issue objects
  # are fully constructed.
  def add_edge(left, right)
    left.blocked_by(right)
    right.blocking(left)
    
    @edges << [left, right]
  end

  # Given a hash of data, create a new issue and add it to the collection,
  # or find an existing issue. Return the result.
  def add_or_find(hash)
    issue = IssueGraph::Issue.new(hash)

    if i = self[issue.name]
      return i
    else
      # load issue data from github so we have enough info for the graph string
      issue[:repo_name] = repository_name_from_id(issue[:repo_id])
      issue.load_from_gh(gh_client)
      self.add(issue)
      return issue
    end
  end

  # This is the core function of this class. It adds all of the issues from
  # the main repo into the graph, loads epics, and then adds all of the edges.
  def build_issue_graph
    load_issues()

    # Then get the epic data
    load_epics()

    # Then the dependencies
    load_dependencies()

    # Pick a color for the issue, based on repository.
    color_issues_by_repo()
  end

  # Pick a color for each repository, then tell each issue what color to use.
  # This is only used when outputting the graph.
  def color_issues_by_repo
    # This will need to be done differently.
    # Ideally I'd color each repo a different color.
    color_list = %w{cornsilk azure aquamarine cyan2 darksalmon cadetblue1 greenyellow palegreen olivedrab1 plum1 pink1 sandybrown grey}

    colormap = {}
    # Our main repo is always gold.
    colormap[repo_id] = "gold"

    # For coloring the node in the graph
    self.each do |name, issue|
      unless color = colormap[issue[:repo_id]]
        # Pick a new color, if there isn't one already set for this repo.
        unless color = color_list.shift
          raise "Ran out of colors!"
        end

        colormap[issue[:repo_id]] = color
      end

      issue[:fillcolor] = color
    end
  end

  def each
    @issues.each { |name, issue| yield(name, issue) }
  end

  def init_zenhub_client(auth)
    @zh_client = IssueGraph::ZenhubClient.new(auth['zenhub'], auth['github'])
  end

  def init_github_client(auth)
    @gh_client = Octokit::Client.new :access_token => auth['github'], :auto_paginate => true
  end

  def initialize(name, auth)
    @repo_name = name

    # Init the clients
    init_github_client(auth)
    init_zenhub_client(auth)

    # Try to hold down the number of lookups from id to name
    @repository_cache = {}

    # This is for temporary storage of edges.
    # GraphViz can only handle strings. And we don't want to add our
    # strings until we have all the data we want.
    @edges = []

    @issues = {}

    @graph = GraphViz.new(:G, :type => :digraph, rankdir: "LR")

    @indent = "  "
  end

  # Add dependency edges for everything we find.
  def load_dependencies
    result = zh_client.dependencies(repo_name)

    result["dependencies"].each do |hash|
      blocking = add_or_find(hash["blocking"])
      blocked = add_or_find(hash["blocked"])

      add_edge(blocked, blocking)
    end
  end

  # Load all of the epics into the graph
  def load_epics
    result = zh_client.epics(repo_name)

    epics = []

    result["epic_issues"].each do |hash|

      issue = add_or_find(hash)
      issue[:is_epic] = true

      unless issue.is_epic?
        raise "Epic not epic"
      end

      epics << issue
    end

    # Then add an edge for each of the issues contained in the epic
    epics.each do |epic|
      result = zh_client.epic_data(repo_name, epic[:issue_number])

      result["issues"].each do |hash|
        issue = add_or_find(hash)

        add_edge(epic, issue)
      end
    end
  end

  # Pre-load all of the issues from the github repo. We'll then layer this
  # with dependency and epic data from zenhub
  def load_issues
    load_repository_data()

    gh_client.list_issues(repo_name, { state: "all" }).each do |data|
      issue = IssueGraph::Issue.new
      issue.load_from_gh_data(data)
      issue[:repo_id] = repo[:id]
      issue[:repo_name] = repo_name
      self.add(issue)
    end
  end

  def load_repository_data
    @repo = gh_client.repo(repo_name)
    @repo_id = repo[:id]
  end

  def print_dependencies(issue, level)
    if level > 20
      raise "You screwed up"
    end

    epic_info = ""
    if issue.is_epic?
      epic_info = " *"
    end

    # We should probably print the issue name and URL next
    puts "#{@indent * level}#{issue}#{epic_info}"

    issue.blockers.each do |blocker|
      print_dependencies(blocker, level + 1)
    end
  end

  def print_graph(name)
    # First add all of the nodes to the graph
    @issues.values.each do |issue|
      issue.node = graph.add_nodes(issue.to_s)

      issue.decorate_graph_node
    end

    # Then all of the edges
    @edges.each do |left, right|
      graph.add_edges(left.node, right.node)
    end

    # Then print
    graph.output(png: name + ".png")
  end

  def print_tree
    level = 0

    tree_tops.each do |issue|
      print_dependencies(issue, level)
    end
  end

  # We were doing a ton of these calls, and they throw errors, so it seemed
  # worth cutting the call count.
  def repository_name_from_id(id)
    unless name = @repository_cache[id]
      data = gh_client.repository(id)
      
      @repository_cache[id] = data["full_name"]
      name = data["full_name"]
    end
    name
  end

  # Find all unblocked issues
  def tree_tops
    @issues.values.find_all { |issue| issue.non_blocking? }
  end
end
