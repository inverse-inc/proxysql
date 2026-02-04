#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

usage() {
    echo "Usage: $0 [-f|--force] <PROXYSQL_VERSION> <PROXYSQL_BRANCH>"
    echo ""
    echo "Arguments:"
    echo "  -f, --force       Force rebuild (no cache)"
    echo "  PROXYSQL_VERSION  Version number (e.g., 3.0.5). Must have a matching Dockerfile_<version>"
    echo "  PROXYSQL_BRANCH   Git branch name to build from (must exist in the repo)"
    echo ""
    echo "Example:"
    echo "  $0 3.0.5 v3.0.5-systemd"
    echo "  $0 -f 3.0.5 v3.0.5-systemd"
    exit 1
}

# Parse options
FORCE_BUILD=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_BUILD="--no-cache"
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Check arguments
if [[ $# -ne 2 ]]; then
    usage
fi

PROXYSQL_VERSION="$1"
PROXYSQL_BRANCH="$2"

# Check if Dockerfile for this version exists
DOCKERFILE="${SCRIPT_DIR}/Dockerfile_${PROXYSQL_VERSION}"
if [[ ! -f "${DOCKERFILE}" ]]; then
    echo "Error: Dockerfile not found: ${DOCKERFILE}"
    echo "The Dockerfile for version ${PROXYSQL_VERSION} does not exist."
    exit 1
fi

# Check if branch exists in the remote repo
echo "Checking if branch '${PROXYSQL_BRANCH}' exists..."
if ! git ls-remote --exit-code --heads https://github.com/inverse-inc/proxysql.git "${PROXYSQL_BRANCH}" > /dev/null 2>&1; then
    echo "Error: Branch '${PROXYSQL_BRANCH}' does not exist in https://github.com/inverse-inc/proxysql.git"
    exit 1
fi
echo "Branch '${PROXYSQL_BRANCH}' found."

# Build the image
echo "Building Docker image with PROXYSQL_VERSION=${PROXYSQL_VERSION} PROXYSQL_BRANCH=${PROXYSQL_BRANCH}..."
docker build ${FORCE_BUILD} \
    --build-arg PROXYSQL_VERSION="${PROXYSQL_VERSION}" \
    --build-arg PROXYSQL_BRANCH="${PROXYSQL_BRANCH}" \
    -t local/proxysql \
    -f "${DOCKERFILE}" \
    "${SCRIPT_DIR}"

# Extract the deb file
echo "Extracting .deb file..."
docker run --rm --entrypoint="" --user "$(id -u):$(id -g)" -v "${SCRIPT_DIR}:/output" local/proxysql sh -c 'cp /tmp/*.deb /output/'

echo "Done! Deb file extracted to: ${SCRIPT_DIR}/"
ls -la "${SCRIPT_DIR}"/*.deb
