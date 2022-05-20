#!/bin/bash

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

get_next_version "fix(hello)!: commit message"
echo "Setting version to $next_version"

mvn versions:set -DnewVersion="$next_version" -DprocessAllModules -DgenerateBackupPoms=false
