# image_builder

[run_build_image.sh](https://github.com/cyber-dojo-languages/image_builder/blob/master/run_build_image.sh)
is the script (containing docker commands) which all the
[cyber-dojo-languages github organization](https://github.com/cyber-dojo-languages)
repos curl and then run as the only command in their .travis.yml file.

There are two kinds of repos in the cyber-dojo-languages github organization:
- language repos
- testFramework repos

- - - -

# language repos
Contain a docker/Dockerfile which installs a base language.
The image_builder attempts to build the docker image
and, if successful, pushes the image to the
[cyberdojofoundation](https://hub.docker.com/u/cyberdojofoundation/)
dockerhub.
See [example](https://github.com/cyber-dojo-languages/python-3.5.3).

- - - -

# testFramework repos
Contain a docker/Dockerfile which installs a test-framework.
Also contains start_point/files for the test-framework.
The image_builder attempts to build and test the docker image
and, if successful, pushes the image to the
[cyberdojofoundation](https://hub.docker.com/u/cyberdojofoundation/)
dockerhub, and triggers all dependent github repos.
See [example](https://github.com/cyber-dojo-languages/python-pytest).

The tests
- Verify the start_point files using the command [ [cyber-dojo](https://github.com/cyber-dojo/commander/blob/master/cyber-dojo) start-point create name --dir=REPO_DIR ]
- Verify the start_point files run outcome is red
- Verify the start_point files tweaked to green is green
- Verify the start_point files tweaked to amber is amber

- - - -

NB: There is a circular dependency which can occasionally bite you.
When image_builder is running start-point files (to test them against a docker image)
it uses the three runners. The runners themselves have tests which rely on start-point
test-data in various language+testFramework combinations (eg gcc-assert).
These images (eg cyberdojofoundation/gcc_assert) are built by image_builder.


