#!/bin/sh

##
# Use this script to increment the patch value in VERSION and create a commit for it.
##

set -e
set -o pipefail

# parse version
MAJOR=$(cat ./VERSION | xargs | cut -d'.' -f1)
MINOR=$(cat ./VERSION | xargs | cut -d'.' -f2)
PATCH=$(cat ./VERSION | xargs | cut -d'.' -f3)

# bump patch value
PATCH=`expr $PATCH + 1`
VERSION="${MAJOR}.${MINOR}.${PATCH}"
printf "${VERSION}" > ./VERSION

# add commit
git add VERSION
git commit -m "Bump version to $VERSION"
