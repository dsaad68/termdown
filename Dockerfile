# Linux image for building termdown and running its integration checks.
#
#   just linux-image        # build it
#   just linux-integration  # build it, then run Tests/Integration/cli.sh inside
#
# The unit tests have their own recipe (`just linux-build`), which mounts the
# working tree instead of copying it. This image is the end-to-end one: it builds
# from a clean context and then runs the binary the way a user would.
FROM swift:6.2

# Only what the build and the checks need beyond the toolchain: the script uses
# awk/sed/grep, all present in the Swift image already.
WORKDIR /src
COPY . .

# Debug rather than release: the integration checks exercise behavior, not speed,
# and a release build of the mermaid port costs minutes for nothing here.
RUN swift build

# A config-less HOME, so the first-run path is exercised rather than inheriting
# whatever the build host had. The script points XDG_CONFIG_HOME at a temp dir of
# its own regardless.
ENV HOME=/root
CMD ["Tests/Integration/cli.sh", ".build/debug/termdown"]
