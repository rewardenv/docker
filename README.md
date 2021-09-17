# Docker

Docker in Docker image with customizable arguments

## Usage examples
Run locally:

```
docker run --rm -it -e DOCKER_OPTS="--mtu=1300" rewardenv/docker:20.10.7-dind
```

To use it inside Bitbucket Pipelines:

```
- name: docker-in-docker
  type: docker
  image: rewardenv/docker:20.10.7-dind
  variables:
     DOCKER_OPTS: "--mtu=1300"
```

## Currently Supported Docker Versions*
- "20.10.7"
- "20.10.8"

---

*If you'd like to add more versions, feel free to modify the [workflow](https://github.com/rewardenv/docker/blob/main/.github/workflows/build.yml) and send a PR.