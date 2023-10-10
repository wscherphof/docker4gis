#!/bin/bash

POSTGRESQL_VERSION=${1:-$POSTGRESQL_VERSION}
POSTGRESQL_VERSION=${POSTGRESQL_VERSION:-16}

POSTGIS_VERSION=${2:-$POSTGIS_VERSION}
POSTGIS_VERSION=${POSTGIS_VERSION:-3.4}

PYTHON=${PYTHON:-python3}
MYSQL_VERSION=${MYSQL_VERSION:-0.8.26-1}
ODBC_FDW_VERSION=${ODBC_FDW_VERSION:-0.5.1}
MONGO_FDW_VERSION=${MONGO_FDW_VERSION:-5_5_1}
PGJWT_VERSION=${PGJWT_VERSION:-f3d82fd}
PGXN_VERSION=${PGXN_VERSION:-1.3.2}
PGSAFEUPDATE_VERSION=${PGSAFEUPDATE_VERSION:-1.4}

IMAGE=${IMAGE:-docker4gis/$(basename "$(realpath .)")}
DOCKER_BASE=$DOCKER_BASE

mkdir -p conf
cp -r "$DOCKER_BASE"/.plugins "$DOCKER_BASE"/.docker4gis conf
docker image build \
    --build-arg POSTGRESQL_VERSION="$POSTGRESQL_VERSION" \
    --build-arg POSTGIS_VERSION="$POSTGIS_VERSION" \
    --build-arg PYTHON="$PYTHON" \
    --build-arg MYSQL_VERSION="$MYSQL_VERSION" \
    --build-arg ODBC_FDW_VERSION="$ODBC_FDW_VERSION" \
    --build-arg MONGO_FDW_VERSION="$MONGO_FDW_VERSION" \
    --build-arg PGJWT_VERSION="$PGJWT_VERSION" \
    --build-arg PGXN_VERSION="$PGXN_VERSION" \
    --build-arg PGSAFEUPDATE_VERSION="$PGSAFEUPDATE_VERSION" \
    -t "$IMAGE" .
rm -rf conf/.plugins conf/.docker4gis
