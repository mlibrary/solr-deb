# Build solr .deb packages
## Requirements
- `dpkg-deb`, gnu `date`
## Features
- Reproducible builds: For a given git commit the resulting `.deb` package should be identical every time it's built.
## Usage
- Run locally: `./build.sh`
- GitHub action: `git push`, then to download the build artifact to do the (Action page)[https://github.com/mlibrary/solr-deb/actions/workflows/build_deb.yml], click the latest commit, and look for "Artifacts" at the bottom of the page.
## New release
- Increment patch number in `build.sh`. This is appended to the version string for the upstream release (example: `x.y.z-123`, where x.y.z is an official release and 123 is the local patch).
- If the upstream version is changing set correct version in `build.sh`, and add the upstream checksum file to this repo.
- Test any diff files and make sure they are applied in `build.sh`.
- Push this repo. GitHub actions will run `build.sh` and upload the resulting `.deb` file as a build artifact.
