#!/usr/bin/env bash
[ "$DEBUG" == "true" ] && set -x
set -e
trap '>&2 printf "\n\e[01;31mError: Command \`%s\` on line $LINENO failed with exit code $?\033[0m\n" "$BASH_COMMAND"' ERR

## find directory where this script is located following symlinks if necessary
readonly BASE_DIR="$(
  cd "$(
    dirname "$(
      (readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}") |
        sed -e "s#^../#$(dirname "$(dirname "${BASH_SOURCE[0]}")")/#"
    )"
  )" >/dev/null &&
    pwd
)/.."
pushd "${BASE_DIR}" >/dev/null

DOCKER_REGISTRY="docker.io"
IMAGE_BASE="${DOCKER_REGISTRY}/rewardenv"
DOCKER_BASE_IMAGE=${DOCKER_BASE_IMAGE:-'docker'}

function print_usage() {
  echo "build.sh [--push] [--dry-run] <IMAGE_TYPE>"
  echo
  echo "example:"
  echo "build.sh --push"
}

# Parse long args and translate them to short ones.
for arg in "$@"; do
  shift
  case "$arg" in
  "--push") set -- "$@" "-p" ;;
  "--dry-run") set -- "$@" "-n" ;;
  "--help") set -- "$@" "-h" ;;
  *) set -- "$@" "$arg" ;;
  esac
done

PUSH=${PUSH:-''}
DRY_RUN=${DRY_RUN:-''}

# Parse short args.
OPTIND=1
while getopts "pnh" opt; do
  case "$opt" in
  "p") PUSH=true ;;
  "n") DRY_RUN=true ;;
  "?" | "h")
    print_usage >&2
    exit 1
    ;;
  esac
done
shift "$((OPTIND - 1))"

FROM_IMAGE="$(echo "${DOCKER_BASE_IMAGE}" | cut -d: -f1)"

if [[ ${DRY_RUN} ]]; then
  DOCKER="echo docker"
else
  DOCKER="docker"
fi

if [[ -z ${DOCKER_VERSION} ]]; then
  printf >&2 "\n\e[01;31mError: Missing DOCKER_VERSION. Please set it using DOCKER_VERSION env var!\033[0m\n"
  print_usage
  exit 1
fi

function docker_login() {
  if [[ ${PUSH} ]]; then
    if [[ ${DOCKER_USERNAME:-} ]]; then
      echo "Attempting non-interactive docker login (via provided credentials)"
      echo "${DOCKER_PASSWORD:-}" | ${DOCKER} login -u "${DOCKER_USERNAME:-}" --password-stdin "${DOCKER_REGISTRY}"
    elif [[ -t 1 ]]; then
      echo "Attempting interactive docker login (tty)"
      ${DOCKER} login "${DOCKER_REGISTRY}"
    fi
  fi
}

function build_image() {
  BUILD_DIR="$(dirname "${file}")"
  IMAGE_NAME="docker"
  IMAGE_TAG="${IMAGE_BASE}/${IMAGE_NAME}"
  TAG_SUFFIX="${DOCKER_VERSION}-dind"

  IMAGE_TAG+=":${TAG_SUFFIX}"

  BUILD_CONTEXT="."
  BUILD_ARGS+=("--build-arg")
  BUILD_ARGS+=("DOCKER_VERSION=${DOCKER_VERSION}")

  printf "\e[01;31m==> building %s from %s/Dockerfile with context %s\033[0m\n" "${IMAGE_TAG}" "${BUILD_DIR}" "${BUILD_CONTEXT}"
  ${DOCKER} build \
    -t "${IMAGE_TAG}" \
    -f "${BUILD_DIR}/Dockerfile" \
    "${BUILD_ARGS[@]}" \
    "${BUILD_CONTEXT}"

  if [[ -n "${LATEST_TAG:+x}" && ${LATEST_TAG} = "true" ]]; then
    LATEST_TAG=$(echo "${IMAGE_TAG}" | sed -r "s/([^:]*:).*/\1latest/")
    ${DOCKER} tag "${IMAGE_TAG}" "${LATEST_TAG}"
    printf "\e[01;31m==> Successfully tagged %s\033[0m\n" "${LATEST_TAG}"
    [[ $PUSH ]] && PUSH_LATEST=true
  fi

  [[ $PUSH ]] && ${DOCKER} push "${IMAGE_TAG}"
  [[ $PUSH_LATEST ]] && ${DOCKER} push "${LATEST_TAG}"

  unset PUSH_SHORT PUSH_LATEST

  return 0
}

## Login to docker hub as needed
docker_login

for file in $(find . -type f -name Dockerfile | sort -t_ -k1,1 -d); do
  build_image
done

exit 0
