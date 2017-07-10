#!/usr/bin/env ruby

require_relative 'image_builder'
require_relative 'dependencies'
require_relative 'dockerhub'

def running_on_travis?
  ENV['TRAVIS'] == 'true'
end

def push?
  ARGV.include?('--push=true') || running_on_travis?
end

Dockerhub.login if push?
src_dir = ENV['SRC_DIR']
args = dir_get_args(src_dir)
builder = ImageBuilder.new(src_dir, args)
builder.build_and_test_image
Dockerhub.push(builder.image_name) if push?

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# TODO:
# Running Travis
# Send POST to trigger immediate dependents.
#
# Running locally
# graph-chain-build all dependents

=begin
puts '-' * 42
puts 'gathering_dependencies'
dependencies = get_dependencies
puts
puts JSON.pretty_generate(dependencies)
puts
puts "#{dependencies.size} repos gathered"
puts
graph = dependency_graph(dependencies)
puts
puts JSON.pretty_generate(graph)
=end


