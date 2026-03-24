dotenv() {
    local flag=$1
    local file=${2:-.env}

    DOCKER4GIS_VERSION=
    DOCKER_REPO=
    DOCKER4GIS_ROOT=

    if [ -e "$file" ]; then
        [ "$flag" = 'export' ] && set -a
        # shellcheck source=/dev/null
        source "$file"
        if [ "$PIPELINE" ]; then
            # Running in a pipeline.
            DOCKER_REPO=${DOCKER_REPO:-$PIPELINE_DOCKER_REPO}
            DOCKER_USER=${DOCKER_USER:-$PIPELINE_DOCKER_USER}
        else
            # Running in a local clone, that should be in a proper directory
            # structure.
            local dir
            dir=$(realpath "$(dirname "$file")")
            DOCKER_REPO=${DOCKER_REPO:-$(basename "$dir")}
            local parent_dir
            parent_dir=$(dirname "$dir")
            if [ "$(basename "$parent_dir")" = "components" ]; then
                # Monorepo: component is inside a components/ subdir; derive
                # DOCKER_USER from the grandparent (the monorepo root).
                DOCKER_USER=${DOCKER_USER:-$(basename "$(dirname "$parent_dir")")}
            else
                DOCKER_USER=${DOCKER_USER:-$(basename "$parent_dir")}
            fi
        fi
        [ "$flag" = 'export' ] && {
            set +a
            export DOCKER_REPO
            export DOCKER_USER
        }
    fi

    if [ "$DOCKER4GIS_VERSION" ] &&
        [ -e "$file" ] &&
        [ -e "$(dirname "$file")"/package.json ]; then
        true
    elif [ "$flag" = 'forgiving' ]; then
        false
    else
        echo "Current directory not recognised as a $docker4gis component or application package." >&2
        exit 1
    fi
}

# Just to prevent schellcheck from complaining about the missing variable.
docker4gis=${docker4gis:-docker4gis}
