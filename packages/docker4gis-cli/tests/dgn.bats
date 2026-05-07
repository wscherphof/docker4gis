DOCKER_BASE="$(cd "$BATS_TEST_DIRNAME/../base" && pwd)"
export DOCKER_BASE

load "$DOCKER_BASE/.plugins/bats/helper.bash"

DGN="$(realpath "$BATS_TEST_DIRNAME/../dgn")"
DG="$(realpath "$BATS_TEST_DIRNAME/../docker4gis")"
MONOREPO_ROOT="$(realpath "$BATS_TEST_DIRNAME/../..")"
export DGN DG MONOREPO_ROOT

# ===========================================================================
# Monorepo fallback — dgn finds docker4gis via the monorepo structure
# ===========================================================================

@test "dgn: finds docker4gis via monorepo fallback and runs it" {
    run bash -c "cd '$MONOREPO_ROOT' && '$DGN' docker4gis"
    assert_success
    assert_output "docker4gis"
}

@test "dgn: passes arguments through to docker4gis (version)" {
    run bash -c "cd '$MONOREPO_ROOT' && '$DGN' version"
    assert_success
    assert_output "development"
}

# ===========================================================================
# Walk-up — dgn finds a docker4gis file by walking up the directory tree
# ===========================================================================

@test "dgn: finds docker4gis by walking up from a subdirectory" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    cp "$DG" "$tmpdir/docker4gis"
    chmod +x "$tmpdir/docker4gis"
    mkdir -p "$tmpdir/sub/dir"
    run bash -c "cd '$tmpdir/sub/dir' && '$DGN' docker4gis"
    assert_success
    assert_output "docker4gis"
    rm -rf "$tmpdir"
}

@test "dgn: uses the nearest docker4gis (closest ancestor wins)" {
    local outer inner
    outer="$(mktemp -d)"
    inner="$outer/inner"
    mkdir -p "$inner"
    # Outer docker4gis: outputs "outer"
    printf '#!/usr/bin/env bash\necho outer\n' >"$outer/docker4gis"
    chmod +x "$outer/docker4gis"
    # Inner docker4gis: outputs "inner"
    printf '#!/usr/bin/env bash\necho inner\n' >"$inner/docker4gis"
    chmod +x "$inner/docker4gis"
    run bash -c "cd '$inner' && '$DGN'"
    assert_success
    assert_output "inner"
    rm -rf "$outer"
}

# ===========================================================================
# Not found — dgn fails when no docker4gis can be located
# ===========================================================================

@test "dgn: reports an error when no docker4gis script can be found" {
    # Use an isolated temp dir far from any monorepo.
    local tmpdir
    tmpdir="$(mktemp -d /tmp/dgn_notfound_XXXXXX)"
    run bash -c "cd '$tmpdir' && '$DGN' version 2>&1"
    assert_failure
    assert_output --partial "could not find"
    rm -rf "$tmpdir"
}

@test "dgn: error message mentions the starting directory" {
    local tmpdir
    tmpdir="$(mktemp -d /tmp/dgn_notfound_XXXXXX)"
    run bash -c "cd '$tmpdir' && '$DGN' version 2>&1"
    assert_failure
    assert_output --partial "dgn:"
    rm -rf "$tmpdir"
}
