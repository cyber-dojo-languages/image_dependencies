require_relative 'all_avatars_names'
require_relative 'assert_system'
require_relative 'banner'
require 'securerandom'
require 'tmpdir'

class ImageBuilder

  def initialize(dir_name)
    @dir_name = dir_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def build_image(image_name)
    banner {
      uuid = SecureRandom.hex[0..10].downcase
      temp_image_name = "imagebuilder/tmp_#{uuid}"
      assert_system "cd #{dir_name} && docker build --no-cache --tag #{temp_image_name} ."

      Dir.mktmpdir('image_builder') do |tmp_dir|
        docker_filename = "#{tmp_dir}/Dockerfile"
        File.open(docker_filename, 'w') { |fd|
          fd.write(make_users_dockerfile(temp_image_name))
        }
        assert_system [
          'docker build',
            "--file #{docker_filename}",
            "--tag #{image_name}",
            tmp_dir
        ].join(' ')
      end

      assert_system "docker rmi #{temp_image_name}"
    }
    print_image_OS(image_name)
  end

  private

  attr_reader :dir_name

  include AssertSystem
  include Banner

  # - - - - - - - - - - - - - - - - -

  def print_image_OS(image_name)
    banner {
      index = image_name.index(':')
      if index.nil?
        name = image_name
        tag = 'latest'
      else
        name = image_name[0..index-1]
        version = image_name[index+1..-1]
      end
      spaces = '\\s+'
      assert_backtick "docker images | grep -E '#{name}#{spaces}#{tag}'"
      cat_etc_issue = [
        'docker run --rm -it',
        image_name,
        "sh -c 'cat /etc/issue'",
        '| head -1'
      ].join(space)
      assert_system cat_etc_issue
    }
  end

  # - - - - - - - - - - - - - - - - -

  def make_users_dockerfile(temp_image_name)
    cmd = "docker run --rm -it #{temp_image_name} sh -c 'cat /etc/issue'"
    etc_issue = assert_backtick cmd
    if etc_issue.include? 'Alpine'
      return alpine_make_users_dockerfile(temp_image_name)
    end
    if etc_issue.include? 'Ubuntu'
      return ubuntu_make_users_dockerfile(temp_image_name)
    end
  end

  # - - - - - - - - - - - - - - - - -

  def alpine_make_users_dockerfile(temp_image_name)
    lined "FROM #{temp_image_name}",
          '',
          idempotent_alpine_add_cyberdojo_group_command,
          idempotent_alpine_add_avatar_users_command
  end

  def idempotent_alpine_add_cyberdojo_group_command
    sh_splice 'RUN if [ ! $(getent group cyber-dojo) ]; then',
              "      addgroup -g #{cyber_dojo_gid} cyber-dojo;",
              '    fi'
  end

  def idempotent_alpine_add_avatar_users_command
    add_avatar_users_command =
      all_avatars_names.collect { |name|
        alpine_add_avatar_user_command(name)
      }.join(' && ')
    # Fail fast if avatar users have already been added
    sh_splice 'RUN (cat /etc/passwd | grep -q zebra:x:40063) ||',
              "    (#{add_avatar_users_command})"
  end

  def alpine_add_avatar_user_command(name)
    spaced '(',
      'adduser',
      '-D',               # no password
      '-G cyber-dojo',    # group
      "-h /home/#{name}", # home-dir
      "-s '/bin/sh'",     # shell
      "-u #{user_id(name)}",
      name,
    ')'
  end

  # - - - - - - - - - - - - - - - - -

  def ubuntu_make_users_dockerfile(temp_image_name)
    lined "FROM #{temp_image_name}",
          '',
          idempotent_ubuntu_add_cyberdojo_group_command,
          idempotent_ubuntu_add_avatar_users_command
  end

  def idempotent_ubuntu_add_cyberdojo_group_command
    sh_splice 'RUN if [ ! $(getent group cyber-dojo) ]; then',
              "      addgroup --gid #{cyber_dojo_gid} cyber-dojo;",
              '    fi'
  end

  def idempotent_ubuntu_add_avatar_users_command
    add_avatar_users_command =
      all_avatars_names.collect { |name|
        ubuntu_add_avatar_user_command(name)
      }.join(' && ')
    # Fail fast if avatar users have already been added
    sh_splice 'RUN (cat /etc/passwd | grep -q zebra:x:40063) ||',
              "    (#{add_avatar_users_command})"
  end

  def ubuntu_add_avatar_user_command(name)
    spaced '(',
      'adduser',
      '--disabled-password',
      '--gecos ""', # don't ask for details
      '--ingroup cyber-dojo',
      "--home /home/#{name}",
      "--uid #{user_id(name)}",
      name,
    ')'
  end

  # - - - - - - - - - - - - - - - - -

  def cyber_dojo_gid
    5000
  end

  # - - - - - - - - - - - - - - - - -

  def user_id(avatar_name)
    40000 + all_avatars_names.index(avatar_name)
  end

  include AllAvatarsNames

  # - - - - - - - - - - - - - - - - -

  def sh_splice(*lines)
    lines.join(space + '\\' + "\n")
  end

  def lined(*lines)
    lines.join("\n")
  end

  def spaced(*words)
    words.join(space)
  end

  def space
    ' '
  end

end