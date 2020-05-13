class IssueGraph::Issue
  attr_reader :issue_number, :repo_id, :url

  attr_accessor :node

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

  # Add information to the graph node based on the issue itself.
  def decorate_graph_node
    # Epic vs normal determines shape and edge color
    # Main repo vs other repo determines color

    # Everyone
    style = %w{filled}
    node[:shape] = "box"

    # This will need to be done differently.
    # Ideally I'd color each repo a different color.
    color_list = %w{cornsilk azure aquamarine cyan2 darksalmon cadetblue1 gray greenyellow palegreen olivedrab1 plum1 pink1 sandybrown}

    if is_epic?
      style << "rounded"
      node[:color] = "crimson"
    end

    if in_target_repo?
      node[:fillcolor] = "gold"
    else
      node[:fillcolor] = "cornsilk"
    end

    node[:style] = style.join(",")
  end
  
  def in_target_repo?
    self[:in_target_repo]
  end

  def is_epic?
    self[:is_epic]
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

  # We have an issue number and repo number from zenhub. We need to load
  # the rest of the data.
  def load_from_gh(client)
    issue_data = client.issue(self[:repo_id], self[:issue_number])
    load_from_gh_data(issue_data)
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

    # issue["comments"] = text.join("\n").gsub(/\r\n/, "\n")
  end

  def name
    "#{self[:issue_number]}-#{self[:repo_id]}"
  end

  def non_blocking?
    @blocking.empty?
  end

  def to_s
    "#{self[:repo_name]}##{self[:issue_number]}\n#{self[:title]}"
  end
end
