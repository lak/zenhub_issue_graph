require 'ruby-graphviz'

class ZenhubRuby::Issue::Collection
  attr_reader :graph, :repo_name, :repo, :gh_client

  def <<(issue)
    @issues[issue.name] = issue
  end

  def [](name)
    @issues[name]
  end

  def add(issue)
    @issues[issue.name] = issue
    @graph.add_nodes(issue.to_s)
  end

  def add_edge(left, right)
    left.blocked_by(right)
    right.blocking(left)
    @graph.add_edges(left.to_s, right.to_s)
  end

  # Given a hash of data, create a new issue and add it to the collection,
  # or find an existing issue. Return the result.
  def add_or_find(hash)
    issue = ZenhubRuby::Issue.new(hash)

    if i = self[issue.name]
      return i
    else
      # XXX We should load issue data from github
      issue.load_from_gh(gh_client)
      self.add(issue)
      return issue
    end
  end

  def each
    @issues.each { |name, issue| yield(name, issue) }
  end

  def initialize(name, gh_client)
    @repo_name = name

    @gh_client = gh_client
    @issues = {}

    @graph = GraphViz.new(:G, :type => :digraph, rankdir: "LR")

    @indent = "  "
  end

  # Pre-load all of the issues from the github repo. We'll then layer this
  # with dependency and epic data from zenhub
  def load_issues
    load_repository_data()

    gh_client.list_issues(repo_name, { state: "all" }).each do |data|
      issue = ZenhubRuby::Issue.new
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
    #indent = "#{@indent * level}#{issue}"

    # We need the github API to get the repo name. And to get the issue title.
    #url = "https://github.com/"

    #string = "%-20s %2s %-30s %s" % [indent, epic_info, 
    issue.blockers.each do |blocker|
      print_dependencies(blocker, level + 1)
    end
  end

  def print_tree
    level = 0

    tree_tops.each do |issue|
      print_dependencies(issue, level)
    end
  end

  # Find all unblocked issues
  def tree_tops
    @issues.values.find_all { |issue| issue.non_blocking? }
  end
end
