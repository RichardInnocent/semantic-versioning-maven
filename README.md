# semantic-versioning-maven
A simple GitHub Action tool to increment the Maven version of a pom and all its children based on
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0).

## How does it work?
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0) can be used in conjunction
with this GitHub Action to automatically increment the version of your Maven project, push an
appropriate tag, and perform a deployment.

### Versioning
The next version is applied dependent on the commit message. As stipulated by the [Conventional
Commits](https://www.conventionalcommits.org/en/v1.0.0) specification, version numbers are
incremented as follows:

| Commit prefix    | Version increment type | Original version | New version |
|------------------|------------------------|------------------|-------------|
| `feat(scope)!:`  | Major                  | `1.0.0`          | `2.0.0`     |
| `fix(scope)!:`   | Major                  | `1.0.0`          | `2.0.0`     |
| `feat(scope):`   | Minor                  | `1.0.0`          | `1.1.0`     |
| `fix(scope):`    | Patch                  | `1.0.0`          | `1.0.1`     |
| Any other prefix | None                   | `1.0.0`          | `1.0.0`     |

This GitHub Action doesn't just apply the versioning change over the last commit. In fact, it will
actually iterate over all commits since the latest tag. The reason for this is that sometimes users
push multiple commits to a repository, for which GitHub actions only run for the most recent
commit. Only running it for the latest version might mean that we miss a significant version change.

_Note that this can cause some issues is multiple builds are running concurrently. We therefore
recommend using [concurrency limits]
(https://docs.github.com/en/actions/using-jobs/using-concurrency) to allow only one job at a time._

For example, a Maven project is currently at version `2.5.6` and is tagged. It then receives the
following commits:

`feat(#19)!: Added ISBN to books` -> Version is now `3.0.0`  
`fix(#20): Fixed issue where ...` -> Version is now `3.0.1`  
`feat(#15): Allow users to se...` -> Version is now `3.1.0`  
`Merge branch 'main' of https...` -> Version is now `3.1.0`  
`fix(#15): Prevent users from...` -> Version is now `3.1.1`

The GitHub Action would increment the version to version `3.1.1` and then make the changes to the
repository to reflect this. A tag (`v3.1.1`) is then pushed.

If a repository has no tags then all commits will be considered.

### Deployment Action
If the version changes (i.e. if the commits contain at least one version-affecting conventional
commit) then the deployment step will be executed. Out of the box, this command is:
```
mvn deploy
```
This can be customised by specifying a different deploy action.
