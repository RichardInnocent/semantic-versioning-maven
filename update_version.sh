#!/bin/bash

# Inputs:
#   TOKEN
#     required: true
#     description: The token used to perform the commit actions such as committing the version
#         changes to the repository.
#     example: ghp_123456789abcdefgfijklmnopqrstuvwxyz
#   GITHUB_ACTOR
#     required: true
#     description: The owner of the GitHub repository.
#     example: owner-name
#   GITHUB_REPOSITORY
#     required: true
#     description: The name of the GitHub repository.
#     example: repository-name
#   GIT_EMAIL
#     required: false
#     description: The email address each commit should be associated with.
#     default: A GitHub-provided no-reply address.
#     example: my-git-bot@example.com
#   GIT_USERNAME
#     required: false
#     description: The GitHub username each commit should be associated with.
#     default: github-actions[bot]
#     example: my-git-bot
#   POM_PATH
#     required: false
#     description: The path within your directory the pom.xml you intended to change is located.
#     default: .
#     example: ./project
#   DEPLOY_ACTION
#     required: false
#     description: The action that will run upon the successful incrementation of the version. Note
#         that this will not run if the version does not change.
#     default: mvn deploy
#     example: mvn deploy
#
# Outputs:
#   [none]

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
    version_increment_type="$PATCH"
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
  local repo="https://$GITHUB_ACTOR:$TOKEN@github.com/$GITHUB_REPOSITORY.git"
  git add ./\*pom.xml
  git -c "user.email=$GIT_EMAIL" -c "user.name=$GIT_USERNAME" commit -m "Increment version to $1 [skip ci]"
  git tag "v$1"
  git push "$repo" --follow-tags
  git push "$repo" --tags
}

if [[ -z "$TOKEN" ]]
then
  echo "No GITHUB_TOKEN environment variable provided. This is required."
  exit 1
fi
if [[ -z "$GIT_EMAIL" ]]
then
  GIT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
fi
if [[ -z "$GIT_USERNAME" ]]
then
  GIT_USERNAME="semantic-versioning-maven[bot]"
fi
if [[ -z "$POM_PATH" ]]
then
  POM_PATH="."
fi

cd "$POM_PATH"

get_relevant_commits

if [[ -z "$commit_messages" ]]
then
  echo "No commits found since last tag. Skipping all actions and terminating"
  exit 0
fi

number_of_commits="$(echo "$commit_messages" | wc -l | xargs)"
if [[ "$number_of_commits" == "1" ]]
then
  echo "Attempting to up-version across the $number_of_commits commit since the last tag"
else
  echo "Attempting to up-version across the $number_of_commits commits since the last tag"
fi

get_current_version
echo "Current version: $current_version"
echo "::set-output name=vpreviousVersion::$current_version"
version="$current_version"

while IFS= read -r commit
do
  echo "Processing commit: $commit"
  get_next_version "$version" "$commit"
  echo "  Version before: $version" 
  version="$next_version"
  echo "  Version after:  $version"
done <<< "$commit_messages"

echo "Setting version to $version"
echo "::set-output name=newVersion::$version"

if [[ "$version" == "$current_version" ]]
then
  echo "Version not incremented. Skipping deployment actions"
  exit 0
fi

make_version_changes "$version"
