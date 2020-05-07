require 'zenhub_ruby/connection'
require 'zenhub_ruby/github'
require 'zenhub_ruby/version'

module ZenhubRuby
  class Client
    include Connection

    attr_reader :zenhub_access_token, :github

    def issue_data(repo_name, issue_number)
      get "/p1/repositories/#{github.repo_id(repo_name)}/issues/#{issue_number}"
    end

    def issue_events(repo_name, issue_number)
      get "/p1/repositories/#{github.repo_id(repo_name)}/issues/#{issue_number}/events"
    end

    def board_data(repo_name)
      get "/p1/repositories/#{github.repo_id(repo_name)}/board"
    end

    def dependencies(repo_name)
      get "/p1/repositories/#{github.repo_id(repo_name)}/dependencies"
    end

    def initialize(zenhub_access_token, github_access_token)
      @zenhub_access_token = zenhub_access_token
      @github = ZenhubRuby::Github.new(github_access_token)
    end
  end
end
