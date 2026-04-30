#!/usr/bin/env bash

set -Eeuo pipefail

owner="bptoworld"
repo="b-p.config"
branch="master"
config_dir="/b-p.config"

tmp_dir="/root/.b-p-deploy/tmp"
tmp_credentials="${tmp_dir}/git-credentials"

github_secret_dir="${config_dir}/github/secrets"
github_credentials="${github_secret_dir}/git-credentials"

deploy_script="${config_dir}/bootstrap/ubuntu-24/deploy-from-template.sh"

fail() {
    echo "FAILED: $*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || fail "root required"

if ! command -v git >/dev/null 2>&1; then
    apt-get update
    apt-get install -y ca-certificates git
fi

if ! command -v git-lfs >/dev/null 2>&1; then
    apt-get update
    apt-get install -y git-lfs
fi

git lfs install --system >/dev/null 2>&1 || true

printf "GitHub username: " >/dev/tty
IFS= read -r github_user </dev/tty

printf "GitHub token: " >/dev/tty
old_stty="$(stty -g < /dev/tty)"
stty -echo < /dev/tty
IFS= read -r github_token </dev/tty
stty "$old_stty" < /dev/tty
printf "\n" >/dev/tty

[ -n "$github_user" ] || fail "empty GitHub username"
[ -n "$github_token" ] || fail "empty GitHub token"

mkdir -p "$tmp_dir"
chmod 700 "$tmp_dir"

rm -f "$tmp_credentials"
git config --global credential.helper "store --file=${tmp_credentials}"

printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n" \
    "$github_user" "$github_token" | git credential approve

chmod 600 "$tmp_credentials"

if [ -d "${config_dir}/.git" ]; then
    git -C "$config_dir" fetch origin "$branch"
    git -C "$config_dir" checkout "$branch"
    git -C "$config_dir" pull --ff-only origin "$branch"
else
    rm -rf "$config_dir"
    git clone --branch "$branch" "https://github.com/${owner}/${repo}.git" "$config_dir"
fi

mkdir -p "$github_secret_dir"
chmod 700 "$github_secret_dir"

rm -f "$github_credentials"
git config --global credential.helper "store --file=${github_credentials}"

printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n" \
    "$github_user" "$github_token" | git credential approve

chmod 600 "$github_credentials"
rm -f "$tmp_credentials"

[ -f "$deploy_script" ] || fail "deploy script not found"

chmod +x "$deploy_script"
exec "$deploy_script"