All succesful Packer builds should end up here in a folder named after their build configuration (eg `windows-server2019-standard-core`).
The output folder is set via the Packer build configuration object `"output_directory":` using relative paths.

This directory is gitignored so output here shouldn't affect your ability to `git pull` this repo.