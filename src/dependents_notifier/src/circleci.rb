require_relative 'assert_system'
require_relative 'failed'
require_relative 'print_to'
require 'json'

class CircleCI

  def initialize(triple)
    @triple = triple
  end

  def validate_triple
    if validated?
      print_to STDOUT, triple.inspect
    else
      print_to STDERR, *triple_diagnostic
      exit false
    end
  end

  def trigger_dependents
    trigger(dependent_repos)
  end

  private

  attr_reader :triple

  include AssertSystem
  include Failed
  include PrintTo

  # - - - - - - - - - - - - - - - - - - - - -

  def image_name
    triple['image_name']
  end

  def from
    triple['from']
  end

  def test_framework?
    triple['test_framework']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def validated?
    found = triples.find { |_,tri| tri['image_name'] == image_name }
    if found.nil?
      return false
    end
    # TODO: check if > 1 found
    found[1]['from'] == from &&
      found[1]['test_framework'] == test_framework?
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def triples
    @triples ||= curled_triples
  end

  def curled_triples
    assert_system "curl -O --silent --fail #{triples_url}"
    json_parse('./' + triples_filename)
  end

  def triples_url
    github_org = 'https://raw.githubusercontent.com/cyber-dojo-languages'
    repo = 'images_info'
    branch = 'master'
    "#{github_org}/#{repo}/#{branch}/#{triples_filename}"
  end

  def triples_filename
    'images_info.json'
  end

  def triple_diagnostic
    [ '',
      triples_url,
      'does not contain an entry for:',
      '',
      "#{quoted('REPO')}: {",
      "  #{quoted('from')}: #{quoted(from)},",
      "  #{quoted('image_name')}: #{quoted(image_name)},",
      "  #{quoted('test_framework')}: #{test_framework?}",
      '},',
      ''
    ]
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def trigger(repos)
    print_to STDOUT, "number of dependent repos: #{repos.size}"
    repos.shuffle.each do |repo_name|
      puts "  #{cdl}/#{repo_name}"
      output = assert_backtick "#{__dir__}/post_trigger-circleci.sh #{repo_name}"
      print_to STDOUT, output
      print_to STDOUT, "\n", '- - - - - - - - -'
    end
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def dependent_repos
    triples.keys.select { |key| triples[key]['from'] == image_name }
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def quoted(s)
    '"' + s.to_s + '"'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def cdl
    'cyber-dojo-languages'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def json_parse(filename)
    begin
      content = IO.read(filename)
      JSON.parse(content)
    rescue JSON::ParserError
      failed "error parsing JSON file:#{filename}"
    end
  end

end