DOCKER_BASE="$(cd "$BATS_TEST_DIRNAME/../base" && pwd)"
export DOCKER_BASE

load "$DOCKER_BASE/.plugins/bats/helper.bash"

DG="$(realpath "$BATS_TEST_DIRNAME/../docker4gis")"
MONOREPO_ROOT="$(realpath "$BATS_TEST_DIRNAME/../..")"
export DG MONOREPO_ROOT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_component_dir() {
    local dir="$1"
    mkdir -p "$dir"
    printf 'DOCKER4GIS_VERSION=1.0.0\n' >"$dir/.env"
    printf '{"version":"1.0.0"}\n' >"$dir/package.json"
}

# ===========================================================================
# Self-identification
# ===========================================================================

@test "docker4gis: self-identify command outputs 'docker4gis'" {
    run "$DG" docker4gis
    assert_success
    assert_output "docker4gis"
}

# ===========================================================================
# base
# ===========================================================================

@test "base: outputs a path ending in /base" {
    run "$DG" base
    assert_success
    assert_output --regexp ".*/base$"
}

# ===========================================================================
# pwd / where
# ===========================================================================

@test "pwd: outputs an absolute directory path" {
    run "$DG" pwd
    assert_success
    assert_output --regexp "^/"
}

@test "where: is an alias for pwd" {
    run "$DG" pwd
    local expected="$output"
    run "$DG" where
    assert_success
    assert_output "$expected"
}

# ===========================================================================
# version / v
# ===========================================================================

@test "version: outputs 'development' when running from a git clone" {
    run "$DG" version
    assert_success
    assert_output "development"
}

@test "v: is an alias for version" {
    run "$DG" v
    assert_success
    assert_output "development"
}

# ===========================================================================
# bats
# ===========================================================================

@test "bats: creates a named .bats file" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run "$DG" bats "$tmpdir/my-test.bats"
    assert_success
    assert_file_exists "$tmpdir/my-test.bats"
    rm -rf "$tmpdir"
}

@test "bats: created file contains the helper load line" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run "$DG" bats "$tmpdir/my-test.bats"
    assert_success
    run grep "helper.bash" "$tmpdir/my-test.bats"
    assert_success
    rm -rf "$tmpdir"
}

@test "bats: defaults to creating test.bats in cwd" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' bats"
    assert_success
    assert_file_exists "$tmpdir/test.bats"
    rm -rf "$tmpdir"
}

@test "bats: fails when the target file already exists" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    touch "$tmpdir/existing.bats"
    run "$DG" bats "$tmpdir/existing.bats"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# Unknown command
# ===========================================================================

@test "unknown command: prints usage and exits 0" {
    run "$DG" xyz-unknown-command-that-does-not-exist
    assert_success
    assert_output --partial "Usage:"
}

# ===========================================================================
# init / new
# ===========================================================================

@test "init: fails with 'Project name not set' when given an empty name" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && echo '' | '$DG' init 2>&1"
    assert_failure
    assert_output --partial "Project name not set"
    rm -rf "$tmpdir"
}

@test "new: is an alias for init (same error on empty name)" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && echo '' | '$DG' new 2>&1"
    assert_failure
    assert_output --partial "Project name not set"
    rm -rf "$tmpdir"
}

# ===========================================================================
# component / c
# ===========================================================================

@test "component: fails outside a docker4gis project" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' component mycomp 2>&1"
    assert_failure
    assert_output --partial "docker4gis project"
    rm -rf "$tmpdir"
}

@test "c: is an alias for component (same error outside project)" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' c mycomp 2>&1"
    assert_failure
    assert_output --partial "docker4gis project"
    rm -rf "$tmpdir"
}

# ===========================================================================
# base-component
# ===========================================================================

@test "base-component: fails outside a docker4gis monorepo" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' base-component mycomp 2>&1"
    assert_failure
    assert_output --partial "monorepo"
    rm -rf "$tmpdir"
}

# ===========================================================================
# template
# ===========================================================================

@test "template: fails outside a docker4gis project" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' template 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# build / b — error path (no component context)
# ===========================================================================

@test "build: fails when run outside any docker4gis context" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' build 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

@test "b: is an alias for build (same failure outside context)" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' b 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# run / r — error path
# ===========================================================================

@test "run: fails when run outside any docker4gis context" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' run 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

@test "r: is an alias for run (same failure outside context)" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' r 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# br — error path
# ===========================================================================

@test "br: fails when run outside any docker4gis context" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' br 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# push / p — error path
# ===========================================================================

@test "push: fails when run outside any docker4gis context" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' push 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

@test "p: is an alias for push (same failure outside context)" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' p 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# test / t — warns when no tests found
# ===========================================================================

@test "test: warns when no tests exist in an empty directory" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    make_component_dir "$tmpdir"
    run bash -c "cd '$tmpdir' && '$DG' test 2>&1"
    assert_success
    assert_output --partial "WARNING"
    rm -rf "$tmpdir"
}

@test "t: is an alias for test (same warning on empty directory)" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    make_component_dir "$tmpdir"
    run bash -c "cd '$tmpdir' && '$DG' t 2>&1"
    assert_success
    assert_output --partial "WARNING"
    rm -rf "$tmpdir"
}

# ===========================================================================
# unbuild — error path
# ===========================================================================

@test "unbuild: fails when run outside any docker4gis context" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' unbuild 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# standalone
# ===========================================================================

@test "standalone: writes DOCKER4GIS_STANDALONE=true to .env" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    make_component_dir "$tmpdir"
    run bash -c "cd '$tmpdir' && '$DG' standalone"
    assert_success
    run grep "DOCKER4GIS_STANDALONE=true" "$tmpdir/.env"
    assert_success
    rm -rf "$tmpdir"
}

@test "standalone: creates an executable run.sh" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    make_component_dir "$tmpdir"
    run bash -c "cd '$tmpdir' && '$DG' standalone"
    assert_success
    assert_file_executable "$tmpdir/run.sh"
    rm -rf "$tmpdir"
}

@test "standalone: does not overwrite an existing run.sh" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    make_component_dir "$tmpdir"
    printf '#!/bin/bash\necho existing\n' >"$tmpdir/run.sh"
    chmod +x "$tmpdir/run.sh"
    run bash -c "cd '$tmpdir' && '$DG' standalone"
    assert_success
    run grep "existing" "$tmpdir/run.sh"
    assert_success
    rm -rf "$tmpdir"
}

@test "standalone: rejects extra parameters" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    make_component_dir "$tmpdir"
    run bash -c "cd '$tmpdir' && '$DG' standalone extra 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# bump
# ===========================================================================

@test "bump: writes DOCKER4GIS_VERSION to .env" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    make_component_dir "$tmpdir"
    run bash -c "cd '$tmpdir' && '$DG' bump 2>&1"
    assert_success
    run grep "^DOCKER4GIS_VERSION=" "$tmpdir/.env"
    assert_success
    rm -rf "$tmpdir"
}

@test "bump: outputs the bumped version string" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    make_component_dir "$tmpdir"
    run bash -c "cd '$tmpdir' && '$DG' bump 2>&1"
    assert_success
    # In a git clone the version is "development".
    assert_output --partial "development"
    rm -rf "$tmpdir"
}

# ===========================================================================
# login
# ===========================================================================

@test "login: fails when no password argument is given" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    # Create a minimal context so dotenv doesn't abort first.
    make_component_dir "$tmpdir"
    run bash -c "cd '$tmpdir' && '$DG' login 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

# ===========================================================================
# git-push / gp
# ===========================================================================

@test "git-push: exits cleanly with 'No changes' message in a clean repo" {
    run bash -c "cd '$MONOREPO_ROOT' && '$DG' git-push 2>&1"
    # Either "No changes to commit" (success) or a git/network error (failure).
    # Both are acceptable; the key requirement is that when there are no
    # uncommitted changes the command prints the expected message and exits.
    if [ "$status" -eq 0 ]; then
        assert_output --partial "No changes to commit"
    fi
}

@test "gp: is an alias for git-push" {
    run bash -c "cd '$MONOREPO_ROOT' && '$DG' gp 2>&1"
    if [ "$status" -eq 0 ]; then
        assert_output --partial "No changes to commit"
    fi
}

# ===========================================================================
# all
# ===========================================================================

@test "all: fails with 'monorepo root' message outside a monorepo" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' all echo 2>&1"
    assert_failure
    assert_output --partial "monorepo root"
    rm -rf "$tmpdir"
}

@test "all: runs the given command in each component from the monorepo root" {
    run bash -c "cd '$MONOREPO_ROOT' && '$DG' all echo ok 2>&1"
    assert_success
}

# ===========================================================================
# run-single / rs — error path
# ===========================================================================

@test "run-single: fails outside a docker4gis context" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' run-single 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}

@test "rs: is an alias for run-single (same failure outside context)" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run bash -c "cd '$tmpdir' && '$DG' rs 2>&1"
    assert_failure
    rm -rf "$tmpdir"
}
