#!/bin/bash

#
# Inputs
#   TOKEN
#   GIT_EMAIL: The email address each commit should be associated with. Defaults to a github provided noreply address
#   GIT_USERNAME: The GitHub username each commit should be associated with. Defaults to github-actions[bot]
#   POM_PATH: The path within your directory the pom.xml you intended to change is located.
#

MAJOR=0
MINOR=1
PATCH=2

get_version_incrementType()
{
  if [[ "$1" =~ ^([Ff][Ee][Aa][Tt]|[Ff][Ii][Xx])(\(.*\))?!:.*$ ]]
  then
    version_increment_type="$MAJOR"
  elif [[ "$1" =~ ^[Ff][Ee][Aa][Tt](\(.*\))?:.*$ ]]
  then
    version_increment_type="$MINOR"
  else
    version_increment_type="$PATCH"
  fi
}

get_next_version()
{
  local mvn_version
  mvn_version=$(mvn -q \
      -Dexec.executable=echo \
      -Dexec.args='${project.version}' \
      --non-recursive \
      exec:exec)

  echo "Current version: ${mvn_version}"

  if [[ ! $mvn_version =~ ^[0-9]*\.[0-9]*\.[0-9]*$ ]]
  then
    echo "Existing version is not semantic. Version will not be incremented."
    next_version="$mvn_version"
    return 0
  fi

  IFS='.' read -ra version_components <<< "$mvn_version"

  get_version_incrementType "$1"

  if [[ "$version_increment_type" == "$MAJOR" ]]
  then
    echo "Detected major version increment"
    next_version="$((version_components[0]+1)).0.0"
  elif [[ "$version_increment_type" == "$MINOR" ]]
  then
    echo "Detected minor version increment"
    next_version="$((version_components[0])).$((version_components[1]+1)).0"
  else
    echo "Detected patch version increment"
    next_version="$((version_components[0])).$((version_components[1])).$((version_components[2]+1))"
  fi
}

if [[ -z "$GITHUB_TOKEN" ]]
then
  echo "No GITHUB_TOKEN environment variable provided. This is required."
  exit 1
fi
if [[ -z "$GIT_EMAIL" ]]
then
  echo "No GIT_EMAIL environment variable provided. This is required."
fi
if [[ -z "$GIT_USERNAME" ]]
then
  GIT_USERNAME="semantic-versioning-maven[bot]"
fi
if [[ -z "$POM_PATH" ]]
then
  POM_PATH="."
fi

get_next_version "$(git log -1)"
echo "Setting version to $next_version"

mvn versions:set -DnewVersion="$next_version" -DprocessAllModules -DgenerateBackupPoms=false

git add POM_PATH/pom.xml
REPO="https://$GITHUB_ACTOR:$TOKEN@github.com/$GITHUB_REPOSITORY.git"
git commit -m "Bump pom.xml from $OLD_VERSION to $NEW_VERSION"
git tag "$NEW_VERSION"
git push "$REPO" --follow-tags
git push "$REPO" --tags
