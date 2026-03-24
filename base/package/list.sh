#!/bin/bash

# Uncomment for debugging the commands that are issued:
# echo
# echo " -- $0 $* --"
# echo
# set -x

# Compiles a list of commands to run all components' containers.

# Either empty (we're creating the package image's run.sh script from the
# build.sh), or 'dirty' (we're running without a package image, in the dev env).
directive=$1

BASE=$BASE
DOCKER_BASE=$DOCKER_BASE
DOCKER_REGISTRY=$DOCKER_REGISTRY
DOCKER_USER=$DOCKER_USER

# Use a temp dir to collect component name→version mappings.
temp_components=$(mktemp -d)

finish() {
    rm -rf "$temp_components"
    exit "${1:-0}"
}

error() {
    echo "> ERROR: $1" >&2
    finish 1
}

# In the monorepo, components live in ./components/ subdirectories.
for comp_dir in ./components/*/; do
    [ -d "$comp_dir" ] || continue
    # Start a subshell to prevent overwriting environment variables.
    (
        DOCKER4GIS_VERSION=
        DOCKER_REGISTRY=
        DOCKER_USER=
        DOCKER_REPO=

        comp_env="${comp_dir}.env"
        [ -f "$comp_env" ] || exit
        # shellcheck source=/dev/null
        . "$comp_env"

        [ "$DOCKER_REPO" ] || DOCKER_REPO=$(basename "$(realpath "$comp_dir")")

        # Skip standalone components.
        [ -n "$DOCKER4GIS_STANDALONE" ] && exit
        # Must be a valid docker4gis component directory.
        [ "$DOCKER4GIS_VERSION" ] && [ "$DOCKER_REGISTRY" ] && [ "$DOCKER_USER" ] && [ "$DOCKER_REPO" ] || exit

        packagejson="${comp_dir}package.json"
        [ -f "$packagejson" ] || exit
        version=$(node --print "require('$packagejson').version")
        if [ "$version" = 0.0.0 ]; then
            version=latest
        else
            version=v$version
        fi

        # Add this component's version to the collection.
        echo "$version" >"$temp_components"/"$DOCKER_REPO"
    )
done

components=$temp_components

if ! ls "$components"/* >/dev/null 2>&1; then
    echo "Zero components." >&2
    finish 127
fi

local_image_exists() {
    docker image tag "$1" "$1" >/dev/null 2>&1
}

repo=
version=

add_repo() {

    echo "Fetching $repo..." >&2

    local image=$DOCKER_REGISTRY/$DOCKER_USER/$repo
    local tag

    if [ "$directive" = dirty ] && local_image_exists "$image:latest"; then
        # use latest image _if_ it exists locally
        tag=latest
    else
        if ! [ "$version" = latest ]; then
            tag=$version
        else
            if [ "$directive" = dirty ]; then
                error "no image for '$repo'; was it built already?"
            else
                error "version unknown for '$repo'; was it pushed already?"
            fi
        fi
        # Use local image _if_ it exists.
        local_image_exists "$image:$tag" ||
            # Otherwise, try to find it in the registry. Note that this is why
            # the build validation pipeline of the package repo has to log into
            # the docker registry.
            docker image pull "$image:$tag" >/dev/null ||
            error "image '$image:$tag' not found"
    fi

    if [ "$tag" ]; then
        echo "$image:$tag" >&2
        echo >&2
        echo "$("$DOCKER_BASE/.docker4gis/run" "$tag" "$repo") || exit"
        echo "echo"
    else
        error "no tag for '$image'"
    fi
}

# Test if current repo is one of the given repos.
pick_repo() {
    repo=$(basename "$repo_file")
    version=$(cat "$repo_file")
    local item
    for item in "$@"; do
        [ "$item" = "$repo" ] && return 0
    done
    return 1
}

first_repo() {
    pick_repo postgis mysql
}

last_repo() {
    pick_repo proxy cron
}

add_postgis_ddl() {
    [ "$repo" = postgis ] || return 0

    ddl_repo=postgis-ddl
    ddl_repo_file=$components/$ddl_repo
    [ -f "$ddl_repo_file" ] ||
        error "component '$ddl_repo' is required when 'postgis' is present; add a components/$ddl_repo component directory"

    repo=$ddl_repo
    version=$(cat "$ddl_repo_file")
    add_repo
    postgis_ddl_added=true
}

# Loop through all components and add those that should go first.
for repo_file in "$components"/*; do
    if first_repo; then
        add_repo
        add_postgis_ddl
    fi
done

# Loop through all components again and add those that should not go first or
# last.
for repo_file in "$components"/*; do
    first_repo || last_repo ||
        ([ "$repo" = postgis-ddl ] && [ -n "$postgis_ddl_added" ]) ||
        add_repo
done

# Loop through all components again and add those that should go last.
for repo_file in "$components"/*; do
    last_repo && add_repo
done

# Tidy up.
finish
