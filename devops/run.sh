#!/bin/bash

DEBUG=${DEBUG:-}

here=$(realpath "$(dirname "$0")")

DOCKER_REPO=$(basename "$here")
DOCKER_IMAGE=docker4gis/$DOCKER_REPO
CONTAINER=docker4gis-$DOCKER_REPO

export ENV_FILE=$HOME/.$CONTAINER.env
touch "$ENV_FILE"
chown "$USER" "$ENV_FILE"
chmod 600 "$ENV_FILE"

case "$1" in
set | s)
	shift
	exec "$here"/conf/set.sh "$@"
	;;
components | c)
	shift
	;;
esac

# Set default action.
set -- components "$@"

# Copy the docker4gis tool into the conf directory, so that it can be included
# in the image.
docker4gis_dir=$here/conf/docker4gis
rm -rf "$docker4gis_dir" 2>/dev/null
mkdir "$docker4gis_dir"
find "$here"/.. -maxdepth 1 \
	! -name ".*" \
	! -name node_modules \
	! -name devops \
	-exec cp -r {} "$docker4gis_dir" \;

# Build the image, preventing output if the DEBUG variable is not set (but
# capturing errors).
out=/dev/stdout
[ -z "$DEBUG" ] && out=/dev/null
err=/dev/stderr
[ -z "$DEBUG" ] && err=$(mktemp)
echo "Building Docker image $DOCKER_IMAGE..."
docker image build -t "$DOCKER_IMAGE" "$(dirname "$0")" >"$out" 2>"$err" || failed=true
[ -f "$err" ] && rm "$err"
[ -z "$failed" ] || exit 1

# Clean up.
rm -rf "$docker4gis_dir"

find_docker_user() {
	while read -r env_file; do
		grep "^DOCKER4GIS_VERSION=" "$env_file" &>/dev/null &&
			# The file is in a docker4gis component directory. We need the name
			# of the parent directory.
			DOCKER_USER=$(basename "$(dirname "$(dirname "$env_file")")") &&
			break
		# Find .env files in current directory direct subdirectories (using
		# -print | sort to start with the one in the current directory).
	done < <(find "$(realpath .)" -maxdepth 2 -name ".env" -type f -print | sort)
	[ -z "$DOCKER_USER" ] &&
		# Use the current directory name as a fallback.
		DOCKER_USER=$(basename "$(realpath .)")
}

# Set the DOCKER_USER variable (used as the default value for the DevOps Project
# Name).
[ -n "$DOCKER_USER" ] ||
	find_docker_user

# Find the local project directory to mount into the container for cloning repos.
# Walk up from the current directory looking for a .env file with
# DOCKER4GIS_VERSION, which means we're inside a component clone - the project
# directory is its parent. If not found walking up, look downward for component
# subdirectories (we're already in the project directory). Fall back to the
# current directory.
find_project_dir() {
	local dir
	dir=$(realpath .)
	while [ "$dir" != "/" ]; do
		if [ -f "$dir/.env" ] && grep -q "^DOCKER4GIS_VERSION=" "$dir/.env" 2>/dev/null; then
			PROJECT_DIR=$(dirname "$dir")
			return
		fi
		dir=$(dirname "$dir")
	done
	local env_file
	env_file=$(
		find "$(realpath .)" -maxdepth 2 -name ".env" -type f -print | sort |
			while IFS= read -r f; do
				grep -q "^DOCKER4GIS_VERSION=" "$f" 2>/dev/null && echo "$f" && break
			done
	)
	if [ -n "$env_file" ]; then
		PROJECT_DIR=$(dirname "$(dirname "$env_file")")
	else
		PROJECT_DIR=$(realpath .)
	fi
}

find_project_dir
PROJECT_DIR=$(realpath "$PROJECT_DIR")

docker_socket=/var/run/docker.sock
container_env_file=/devops/env_file

# Tee all stdout & stderr to a log file (from
# https://superuser.com/a/212436/462952).
[ -n "$DEBUG" ] && exec > >(tee devops.log) 2>&1

# We don't use the --env-file Docker option because it's tricky writing a value
# with spaces back to the file, and then getting it read back in correctly on
# the next container start.
docker container run --name "$CONTAINER" \
	--rm \
	--privileged \
	-ti \
	--env DEBUG="$DEBUG" \
	--env DOCKER_USER="$DOCKER_USER" \
	--env DEVOPS_ORGANISATION="$DEVOPS_ORGANISATION" \
	--env DEVOPS_DOCKER_REGISTRY="$DEVOPS_DOCKER_REGISTRY" \
	--env DEVOPS_DEFAULT_POOL="$DEVOPS_DEFAULT_POOL" \
	--env DEVOPS_VPN_POOL="$DEVOPS_VPN_POOL" \
	--env ENV_FILE="$container_env_file" \
	--mount type=bind,source="$ENV_FILE",target="$container_env_file" \
	--mount type=bind,source="$docker_socket",target="$docker_socket" \
	--mount type=bind,source="$PROJECT_DIR",target=/project \
	"$DOCKER_IMAGE" "$@" || exit

# Source the env_file to pick up DEVOPS_NEWLY_CLONED written by the container.
# shellcheck source=/dev/null
source "$ENV_FILE"

# The container runs as root, so cloned directories are root-owned on the host.
# Fix ownership back to the current user.
for repo in ${DEVOPS_NEWLY_CLONED:-}; do
	sudo chown -R "$USER" "$PROJECT_DIR/$repo"
done
