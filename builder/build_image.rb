#!/usr/bin/env ruby

require_relative 'builder'
require_relative 'dependencies'
require_relative 'dockerhub'

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def running_on_travis?
  ENV['TRAVIS'] == 'true'
end

if running_on_travis?
  repo_triples = get_repo_triples
  puts "<repo_triples>"
  puts repo_triples.inspect
  puts "</repo_triples>"
end

#puts dependencies.inspect

src_dir = ENV['SRC_DIR']
args = dependencies[src_dir]

Dockerhub.login if running_on_travis?
builder = Builder.new(src_dir, args)
builder.build_and_test_image
Dockerhub.push(builder.image_name) if running_on_travis?
