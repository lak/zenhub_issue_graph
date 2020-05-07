class ZenhubRuby::Issue
  class Collection
    def <<(issue)
      @issues[issue.name] = issue
    end

    def [](name)
      unless issue = @issues[name]
        issue_number, repo = name.split("-")

        issue = ZenhubRuby::Issue.new(issue_number, repo)

        @issues[issue.name] = issue
      end
      return issue
    end

    def each
      @issues.each { |name, issue| yield(name, issue) }
    end

    def initialize
      @issues = {}

      @indent = "  "
    end

    def print_dependencies(issue, level)
      if level > 20
        raise "You screwed up"
      end

      puts "#{@indent * level}#{issue}"
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

  attr_reader :issue_number, :repo_id

  def self.name_from_hash(hash)
    "#{hash['issue_number']}-#{hash['repo_id']}"
  end

  # We're only going to specify the edge from one direction
  def blocking(issue)
    @blocking << issue
  end

  def blocked_by(issue)
    @blocked_by << issue
  end

  def blockers
    @blocked_by
  end

  def initialize(issue_number, repo_id)
    @issue_number = issue_number.to_i
    @repo_id = repo_id.to_i

    @blocked_by = []
    @blocking = []
  end

  def name
    "#{issue_number}-#{repo_id}"
  end

  def non_blocking?
    @blocking.empty?
  end

  def to_s
    name
  end
end
