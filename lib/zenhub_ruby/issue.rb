class ZenhubRuby::Issue
  require 'zenhub_ruby/issue/collection'

  attr_reader :issue_number, :repo_id, :url

  def self.name_from_hash(hash)
    "#{hash['issue_number']}-#{hash['repo_id']}"
  end

  def [](name)
    @attrs[name.intern]
  end

  def []=(name, value)
    @attrs[name.intern] = value
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

  def initialize(attrs = {})
    @attrs = {}

    attrs.each do |name, value|
      self[name] = value
    end

    self[:repo_id] = self[:repo_id].to_i
    self[:issue_number] = self[:issue_number].to_i

    @blocked_by = []
    @blocking = []
  end

  def load_from_gh_data(data)
    self[:url] = data["html_url"]
    self[:title] = data["title"]
    self[:state] = data["state"]
    self[:issue_number] = data["number"]

    text = [ data["body"] ]
    self[:text] = text
    #if data["comments"] > 0
    #  text += client.issue_comments(repo_name, issue["number"]).map do |comment|
    #    comment["body"]
    #  end
    #end
#
#      issue["comments"] = text.join("\n").gsub(/\r\n/, "\n")
  end

  def name
    "#{self[:issue_number]}-#{self[:repo_id]}"
  end

  def non_blocking?
    @blocking.empty?
  end

  def to_s
    name
  end
end
