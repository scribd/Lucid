#!/bin/sh

current_version=`cat VERSION`

next_version=$1
if [ -z $next_version ]; then
	next_version=${current_version%.*}.$((${current_version##*.}+1))
fi

echo $next_version
echo $next_version > VERSION

release_tar="https://github.com/scribd/Lucid/archive/$current_version.tar.gz"
sha=$(curl -L -s $release_tar | shasum -a 256 | sed 's/ .*//')
sed -i '' "s|^  \(sha256 \"\)\(.*\)\(\"\)|  \1$sha\3|" $(brew --repo homebrew/core)/Formula/lucid.rb

previous_version=${current_version%.*}.$((${current_version##*.}-1))
sed -i '' "s/${previous_version//./\\.}/$current_version/g" \
$(brew --repo homebrew/core)/Formula/lucid.rb

git commit -am "Bump version to $next_version"