#!/bin/sh

##
# Use this script to tag a new release. 
# 
#       Make sure to increment the VERSION file first by running:
#             bin/bbn.sh
#
##

set -e
set -o pipefail

git tag `cat VERSION`
git push origin --tags
