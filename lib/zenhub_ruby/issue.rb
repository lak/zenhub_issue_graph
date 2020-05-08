class ZenhubRuby::Issue
  class Collection
    def <<(issue)
      @issues[issue.name] = issue
    end

    def [](name)
      @issues[name]
    end

    def add(issue)
      @issues[issue.name] = issue
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

      epic_info = ""
      if issue.is_epic?
        epic_info = " *"
      end
      puts "#{@indent * level}#{issue}#{epic_info}"
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

  attr_reader :issue_number, :repo_id, :url

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
  
  def is_epic?
    @is_epic
  end

  def initialize(attrs)
    modified_attrs = {}
    attrs.each do |name, value|
      modified_attrs[name.intern] = value
    end

    @issue_number = modified_attrs[:issue_number].to_i
    @repo_id = modified_attrs[:repo_id].to_i
    @is_epic = modified_attrs[:is_epic] || false
    @url = modified_attrs[:url]

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
