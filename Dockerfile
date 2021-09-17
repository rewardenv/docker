ARG DOCKER_VERSION
FROM docker:${DOCKER_VERSION}-dind

ENV DOCKER_OPTS=""

ENTRYPOINT [ "sh", "-c", "dockerd-entrypoint.sh $DOCKER_OPTS" ]