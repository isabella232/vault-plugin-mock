#!/usr/bin/env bash
set -euo pipefail

branch=$1
semvar_bump=$2

echo "Remote is - $(git remote -v)"
git_remote=$(git config --get remote.origin.url | cut -f2 -d":")
git_remote=${git_remote%".git"}
echo "$git_remote"

git config user.name github-actions
git config user.email github-actions@github.com
git config --global url."https://$GITHUB_TOKEN:x-oauth-basic@github.com/".insteadOf "https://github.com/"
git checkout -b update-"$GITHUB_REPOSITORY"-"$VERSION"-"$(date +%s)"

go get github.com/"$GITHUB_REPOSITORY$semvar_bump"
go mod tidy
rm -rf vendor
go mod vendor

if [ -n "$(git status --untracked-files=no --porcelain)" ]; then
  git add .
  git commit -m "Updating $GITHUB_REPOSITORY deps"
  command=$(hub pull-request -m "Update version of $GITHUB_REPOSITORY." -b "$git_remote:$branch" \
  -h "$git_remote:update-$GITHUB_REPOSITORY-$VERSION-$(date +%s)" \
  -l "plugin-update" -a "$ACTOR" -p | tail -1) || return 1
  echo "$command"
  text="<$command|PR on Vault $branch> successfully created! ($GITHUB_REPOSITORY version: $VERSION) and assigned to $ACTOR"
else
  text="No PR created on Vault $branch ($GITHUB_REPOSITORY version: $VERSION) as this module version bump does not result in an update to go.mod. Please check."
fi

json='
{
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "'$text'"
      }
    }
  ]
}'

echo "$json" | curl -X POST -H "Content-type: application/json; charset=utf-8" \
--data @- \
"$SLACK_WEBHOOK_URL";
