# -*- encoding: utf-8 -*-

class Razor::Command::CreatePolicy < Razor::Command
  summary "Create a new policy"
  description <<-EOT
Policies tie together the rules, as tags, with the task and repo containing
the OS to install, and the broker for post-install configuration.

The overall list of policies is ordered, and polcies are considered in that
order. When a new policy is created, the entry `before` or `after` can be
used to put the new policy into the table before or after another
policy. If neither `before` or `after` are specified, the policy is
appended to the policy table.
  EOT

  example <<-EOT
A sample policy installing CentOS 6.4:

    {
      "name":          "centos-for-small",
      "repo":          {"name": "centos-6.4"},
      "task":          {"name": "centos"},
      "broker":        {"name": "noop"},
      "enabled":       true,
      "hostname":      "host${id}.example.com",
      "root_password": "secret",
      "max_count":     20,
      "before":        {"name": "other policy"},
      "tags": [
        {"name": "small", "rule": ["<=", ["num", ["fact", "processorcount"]], 2]}
      ]
    }
  EOT

  authz  '%{name}'
  attr   'name',          type: String, required: true, size: 1..Float::INFINITY
  attr   'hostname',      type: String, required: true, size: 1..Float::INFINITY
  attr   'root_password', type: String, size: 1..Float::INFINITY

  object 'before', exclude: 'after' do
    attr 'name', type: String, required: true, references: Razor::Data::Policy
  end

  object 'after', exclude: 'before' do
    attr 'name', type: String, required: true, references: Razor::Data::Policy
  end

  array 'tags' do
    object do
      attr 'name', type: String, required: true, references: Razor::Data::Tag
    end
  end

  object 'repo' do
    attr 'name', type: String, required: true, references: Razor::Data::Repo
  end

  object 'broker' do
    attr 'name', type: String, required: true, references: Razor::Data::Broker
  end

  object 'task' do
    attr 'name', type: String, required: true
  end

  def run(request, data)
    tags = (data.delete("tags") || []).map do |t|
      Razor::Data::Tag.find_or_create_with_rule(t)
    end

    data["repo"]   &&= Razor::Data::Repo[:name => data["repo"]["name"]]
    data["broker"] &&= Razor::Data::Broker[:name => data["broker"]["name"]]

    if data["task"]
      data["task_name"] = data.delete("task")["name"]
    end

    data["hostname_pattern"] = data.delete("hostname")

    # Handle positioning in the policy table
    if data["before"] or data["after"]
      position = data["before"] ? "before" : "after"
      neighbor = Razor::Data::Policy[:name => data.delete(position)["name"]]
    end

    # Create the policy
    policy = Razor::Data::Policy.new(data).save
    tags.each { |t| policy.add_tag(t) }
    position and policy.move(position, neighbor)
    policy.save

    return policy
  end
end
