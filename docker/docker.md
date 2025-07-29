# Docker Documentation

## Table of Contents
- [Introduction](#introduction)
- [Dockerfile Basics](#dockerfile-basics)
- [Image Management](#image-management)
- [Container Lifecycle](#container-lifecycle)
- [Networking](#networking)
- [Volumes & Storage](#volumes--storage)
- [Docker Compose](#docker-compose)
- [Best Practices](#best-practices)
- [Common Commands](#common-commands)
- [Troubleshooting](#troubleshooting)

## Introduction
- Quick overview of Docker concepts (images, containers, registries)
- Use cases and common workflows

## Dockerfile Basics
- `FROM`
- `WORKDIR`: Creates the path of the working dir if it doesn't exist.
- `COPY`
- `RUN`: Execute a command during build time, creating a NEW image layer.
- `CMD`: Default command to run when container starts, can override by CLI.
`ENTRYPOINT`: Sets executable that will always run. Useful for containers behaving like binaries
- `EXPOSE`: Container will listen on this port. Does not publish the port by itself.
- Layer caching & build optimization: 
    - Each instruction is a new layer.
    - Order instructions from least to most frequently changing.
    - Combine multiple RUNs using && to reduce layers.
- Multistage builds overview:
    - Use multiple FROM statements to build intermediate images `FROM nginx:1.1 AS base`.
    - Copy only necessary artifacts from builder stages.
    - i.e. Build with a full SDK, then copy binaries to a minimal runtime image
- Environment variables and ARGs:
    - `ENV KEY=VALUE` sets the environment variables in the container, accessible at runtime.
    - `ARG name[=default]` defines the build-time variables to be passed with `--build-arg`

## Image Management
- Building images (`docker build`)
- Tagging and pushing images (`docker tag`, `docker push`)
- Inspecting images (`docker images`, `docker history`, `docker inspect`)

## Container Lifecycle
- Creating and running containers (`docker run`)
- Inspecting (`docker ps`, `docker inspect`)
- Starting, stopping, restarting, and removing containers
- Attaching and logging (`docker logs`, `docker attach`, `docker exec`)

## Networking
- Default bridge network vs user-defined bridge
    - Default Bridge Network: automatically created, all containers connect by default.
    - User-defined Bridge Network: for isolation and security, custom IP ranges/subnets.
- Host, none, and overlay networks
    - Host Network: Containr shares host's network stack, best performance.
    - None: useful for batch jobs or secure apps.
    - Overlay Network: Enables communication between containers across hosts. Used in swarm mode, encrypts traffic between nodes. `docker network create -d overlay ..`
- Port mapping (`-p` flag) host:container
    - `docker run-p 8080:80 nginx`
- Network inspection and troubleshooting

```bash
# View the default bridge network
docker network ls
docker network inspect bridge

# Create a custom bridge and run containers
docker network create my-network
docker run -d --name web --network my-network nginx
```

## Volumes & Storage
- Bind mounts vs volumes
    - Bind Mounts: mount a host directory or file to container
    - Volumes: Managed by docker and stored in `docker` location.
- Creating and managing volumes (`docker volume create`, `docker volume prune`)
- Volume backup and restore strategies

```bash
docker volume create my-vol
docker run -v my-vol:/app/data nginx

# Volume driver options
docker volume create --driver local \
    --opt type=tmpfs \
    --opt device=tmpfs \
    --opt o=size=100m \
    temp-volume

# Backup using a helper container
docker run --rm --volumes-from data-container -v $(pwd):/backup alpine \
  tar czf /backup/backup.tar.gz /data
```



## Docker Compose
- Compose file structure (version, services, networks, volumes)
- Common commands (`docker-compose up`, `docker-compose down`, `docker-compose logs`)
- Environment variables and `.env` files in Compose
- Extending and overriding Compose files

```bash
# .env file in same dir as docker-compose.yml
API_VERSION=v1.2.4
NODE_ENV=PROD

```

## Best Practices
- Image size optimization
- Security tips (least privilege, user namespaces)
- Logging and monitoring containers
- Clean up unused resources (`docker system prune`)

```dockerfile
# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

# Good: Clean up in same layer
RUN apt-get update && \
    apt-get install -y python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
    # rm line is the cleanup layer
```

## Common Commands
- Quick command reference for daily use
- Examples with flags and options

## Troubleshooting
- Debugging container startup issues
- Inspecting logs and events
- Network and volume debugging tips

```bash
# JSON file driver with log rotation
docker run --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  nginx
```

- Docker-compose

```yaml
version: '3.8'
services:
  web:
    image: nginx
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```


