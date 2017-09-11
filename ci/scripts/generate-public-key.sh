#!/bin/bash

set -e
[ -n "$DEBUG" ] && set -x

# This script will generate a new /public.key and updates vault with the private key info

: ${REPO_ROOT:?required}
export KEY_AUTHOR=${KEY_AUTHOR:-"Stark & Wayne Bot"}
export KEY_EMAIL=${KEY_EMAIL:-"drnic+bot@starkandwayne.com"}
export GPG_SAFE_PATH=${GPG_SAFE_PATH:-secret/pipelines/homebrew/gpg}

# change to the root of the repo
pushd ${REPO_ROOT}
mkdir -p tmp

export GNUPGHOME="$(mktemp -d)"
cat >tmp/bot <<EOF
    %no-protection
    %echo Generating a basic OpenPGP key
    Key-Type: RSA
    Key-Length: 4096
    Subkey-Type: ELG-E
    Subkey-Length: 4096
    Name-Real: ${KEY_AUTHOR}
    Name-Comment: Created by CI
    Name-Email: ${KEY_EMAIL}
    Expire-Date: 0
    # Do a commit here, so that we can later print "done" :-)
    %commit
    %echo done
EOF
gpg --batch --generate-key tmp/bot

gpg --list-keys

key_id=$(gpg --list-keys "${KEY_AUTHOR}" | grep "^      " | tail -n1 | awk '{print $1}')
echo "New key ID: $key_id"
echo 5B1ADEF310E816BB30E7E729825FA0CE67EE52E3 > tmp/bot.id
gpg --export -a ${key_id} > public.key
gpg --export-secret-keys -a ${key_id} > tmp/bot.private.key
safe set ${GPG_SAFE_PATH} public@public.key private@tmp/bot.private.key id@tmp/bot.id
ci/repipe

gpg --list-keys
gpg --fingerprint