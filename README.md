TODO REPLACE WITH REPO NAME
===========================
TODO replace with repo description

TODO COMPLETE AND DELETE
------------------------
CONFIGURE GENERAL REPO SETTINGS
1. [ ] Check "always suggest updating pull request branches"
1. [ ] Check "allow auto-merge"
1. [ ] Check "automatically delete head branches"
1. [ ] Give the "Engineers" team Admin access to the repo

SET UP KURTOSIS BRANCH PROTECTION
1. [ ] Under "Branches", create a new branch protection rule
1. [ ] Set the rule name to `master`
1. [ ] Check "Require pull request reviews before merging"
1. [ ] Check "Require approvals" (leaving it at 1)
1. [ ] Check "Allow specified actors to bypass required pull requests" and give the `kurtosisbot` user the permission
1. [ ] Check "Require status checks to pass before merging"
1. [ ] Check "Require branches to be up-to-date before merging" (NOTE: this prevents subtle bugs where two people change code in two separate branches, both their branches pass CI, but when merged they fail)
1. [ ] Add the status checks you want to pass (NOTE: if you have no CI/status checks for now, this is fine - just leave it empty)
1. [ ] Check "Require conversation resolution before merging" (NOTE: this is important as people sometimes forget comments)
1. [ ] Check "Include admins" at the bottom (admins can make mistakes too)
1. [ ] Select "Create" at the bottom

SET UP CIRCLECI
1. [ ] Commit a `.circleci/config.yml` file (easiest to copy from another project)
1. [ ] Visit [the CircleCI projects page](https://app.circleci.com/projects/project-dashboard/github/kurtosis-tech/) and select "Set Up Project"
1. [ ] **VERY IMPORTANT:** Open the CircleCI project settings, go to Advanced, and set the following values:
    * [ ] `Pass secrets to builds from forked pull requests` = `false`
        * **HUGE WARNING:** This is VERY VERY IMPORTANT to be set to `false`!!! If it's `true`, somebody could fork our repo, add an `echo "${GITHUB_TOKEN}"` in their fork, our CI would happily run it and print the value, and they'd get to impersonate us and do all sorts of nasty things like delete repos!!!!!
    * [ ] `Only build pull requests` = `true`
        * If this is set to `false` (the default), CircleCI will build _every_ commit, which will quickly exhaust our CircleCI credits and mean we can't build CI
    * [ ] `Auto-cancel redundant builds` = `true`
        * If this is set to `false` (the default), CircleCI will waste credits unnecessarily (which is probably why it defaults to `false` - because they want you using more credits :P)
1. [ ] If you need any additional secrets (Docker, Kurtosis user, etc.), find the ones you need [from the list](https://app.circleci.com/settings/organization/github/kurtosis-tech/contexts?return-to=https%3A%2F%2Fapp.circleci.com%2Fpipelines%2Fgithub%2Fkurtosis-tech) add them to the `context` section of the project's CircleCI `config.yml` using Circle

SET UP VERSIONING/RELEASING
1. [ ] Ask Kevin to make the Kurtosisbot RELEASER_TOKEN available to this repo so that the repo-releasing Github Action can use it (Kevin eeds to go into `kurtosis-tech` org settings and give the secret access to your new repo)
