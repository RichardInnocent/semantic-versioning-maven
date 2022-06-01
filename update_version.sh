#!/bin/bash

MAJOR=0
MINOR=1
PATCH=2
NONE=3

# Gets the increment type for the commit.
# Inputs:
#   $1: The commit message
# Outputs:
#   version_increment_type: Will be 0, 1, 2, or 3, corresponding with the MAJOR, MINOR, PATCH, or
#   NONE variables.
get_version_increment_type()
{
  if [[ "$1" =~ ^([Ff][Ee][Aa][Tt]|[Ff][Ii][Xx])(\(.*\))?!:.*$ ]]
  then
    version_increment_type="$MAJOR"
  elif [[ "$1" =~ ^[Ff][Ee][Aa][Tt](\(.*\))?:.*$ ]]
  then
    version_increment_type="$MINOR"
  elif [[ "$1" =~ ^[Ff][Ii][Xx](\(.*\))?:.*$ ]]
  then
    version_increment_type="$MINOR"
  else
    version_increment_type="$NONE"
  fi
}

# Gets the current version of the Maven package.
# Inputs:
#   [none]
# Outputs:
#   current_version: The current version of the Maven project, e.g. 1.0.0
get_current_version()
{
  current_version=$(mvn -q \
      -Dexec.executable=echo \
      -Dexec.args='${project.version}' \
      --non-recursive \
      exec:exec)
}

# Gets the next version based on the current version and the commit message.
# Inputs:
#   $1: The current version, e.g. 1.0.0
#   $2: The commit message, e.g. fix(hello)!: commit message
# Outputs:
#   next_version: The next version based on the commit, e.g. 1.0.1
get_next_version()
{
  if [[ ! "$1" =~ ^[0-9]*\.[0-9]*\.[0-9]*$ ]]
  then
    echo "Existing version is not semantic. Version will not be incremented."
    next_version="$mvn_version"
    exit 0
  fi

  IFS='.' read -ra version_components <<< "$1"

  get_version_increment_type "$2"

  if [[ "$version_increment_type" == "$MAJOR" ]]
  then
    echo "  Detected major version increment"
    next_version="$((version_components[0]+1)).0.0"
  elif [[ "$version_increment_type" == "$MINOR" ]]
  then
    echo "  Detected minor version increment"
    next_version="$((version_components[0])).$((version_components[1]+1)).0"
  elif [[ "$version_increment_type" == "$PATCH" ]]
  then
    echo "  Detected patch version increment"
    next_version="$((version_components[0])).$((version_components[1])).$((version_components[2]+1))"
  else
    echo "  Detected no version increment"
    next_version="$1"
  fi
}

# Gets the subjects of the relevant commits since the last tag. If no tags exist, this will include
# all commits in the history.
# Inputs:
#   [none]
# Outputs:
#   commit_messages: A single string containing each commit subject. Each different commit subject
#       will be on a different line.
get_relevant_commits()
{
  number_of_tags=$(git tag | wc -l | xargs)
  if [[ $number_of_tags == "0" ]]
  then
    echo "No tags exist. Processing all commits"
    commit_messages=$(git log --format=%s)
  else
    if [[ $number_of_tags == "1" ]]
    then
      echo "$number_of_tags previous tag found. Only commits since the latest tag will be processed"
    else
      echo "$number_of_tags previous tags found. Only commits since the latest tag will be processed"
    fi
    latest_tag=$(git describe --tags --abbrev=0)
    echo "Latest tag: $latest_tag"
    commit_messages=$(git log $latest_tag..HEAD --format=%s)
  fi 
}

# Makes the version changes. This includes setting the Maven version and creating and pushing a new
# tag.
# Inputs:
#   $1: The version to apply, e.g. 1.0.1
# Outputs:
#   [none]
make_version_changes()
{
  mvn versions:set -DnewVersion="$1" -DprocessAllModules -DgenerateBackupPoms=false
  # TODO - commit changes
  git tag "v$1"
  git push origin --tags
}

get_relevant_commits
echo "Attempting to up-version across the $(echo "$commit_messages" | wc -l | xargs) commits since the last tag"

get_current_version
version=$current_version

while IFS= read -r commit
do
  echo "Processing commit: $commit"
  get_next_version "$version" "$commit"
  echo "  Version before: $version" 
  version=$next_version
  echo "  Version after:  $version"
done <<< "$commit_messages"

echo "Setting version to $version"

#make_version_changes "$version"
