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
    end
  end

  attr_reader :issue_number, :repo_id

  def self.name_from_hash(hash)
    "#{hash['repo_id']}-#{hash['issue_number']}"
  end

  # We're only going to specify the edge from one direction
  def blocking(issue_number)
    raise "No blocking allowed"
    @blocking << issue_number
  end

  def blocked_by(issue)
    @blocked_by << issue
  end

  def initialize(issue_number, repo_id)
    @issue_number = issue_number
    @repo_id = repo_id

    @blocked_by = []
    @blocking = []
  end

  def name
    "#{repo_id}-#{issue_number}"
  end
end
