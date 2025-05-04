# Docker Workshop: From Zero to Container Hero

## 1. Why Docker? The Problem We're Solving

As software engineers, we've all experienced these challenges:

- "It works on my machine but not on the server"
- Setting up a new developer's environment takes hours or days
- Running multiple software versions on the same computer is complicated
- Testing compatibility across versions is difficult
- Keeping development, testing, and production environments consistent is nearly impossible

Docker solves these problems by **containerizing** your applications.

## 2. What is Docker? A Simple Explanation

**Docker** is a containerization platform that packages your application and its dependencies together in the form of a container.

> 🖼️ **Analogy**: Think of Docker containers like shipping containers in global trade - standardized boxes that can hold different goods but have a consistent interface for transport and handling.

### How Containers Differ from Virtual Machines

![Docker vs VM Architecture](https://www.docker.com/wp-content/uploads/2021/11/docker-containerized-and-vm-transparent-bg.png)

- **Containers** share the host operating system's kernel
- **Virtual machines** run a complete guest operating system

This fundamental difference is why containers are:
- Faster to start (seconds vs minutes)
- More lightweight (MBs vs GBs)
- More efficient with system resources

## 3. Installing Docker

Before we start our hands-on journey, let's make sure you have Docker installed:

### For macOS
1. Download Docker Desktop from [Docker's official website](https://www.docker.com/products/docker-desktop)
2. Install the application
3. Start Docker Desktop

### For Ubuntu/Debian
```bash
# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc
# Set up the repository
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

### Verify Installation
Open a terminal and run:
```bash
docker --version
docker compose version
```

## 4. Your First Container: Hello Docker World

Let's get hands-on immediately with some basic commands:

```bash
# Pull the hello-world image
docker pull hello-world

# Run your first container
docker run hello-world
```

You should see a success message explaining that your installation works!

Now let's try something more interactive:

```bash
# Run an Ubuntu container with an interactive terminal
docker run -it --rm ubuntu bash
```

This drops you into a bash shell in an Ubuntu container. Try some commands:
```bash
ls
cat /etc/os-release
exit
```

The `--rm` flag automatically removes the container when you exit.

## 5. Understanding Docker Core Concepts

Now that you've run your first containers, let's understand some core concepts:

### Images vs. Containers

- An **image** is a read-only template with instructions for creating a container
- A **container** is a running instance of an image

> 🖼️ **Analogy**: An image is like a class in programming, while a container is like an object instance of that class

```
                DOCKER IMAGE                 CONTAINERS (RUNTIME INSTANCES)
              +--------------+             +------------------------+
              |              |  creates    |        Container 1     |
              |   nginx:1.19 |------------>|                        |
              |              |             +------------------------+
              +--------------+
                     |                     +------------------------+
                     |       creates       |        Container 2     |
                     +-------------------->|                        |
                                          +------------------------+
                                          
                                          +------------------------+
                     +-------------------->|        Container 3     |
                                          |                        |
                                          +------------------------+
```

### Docker Registry

- **Docker Hub** is a cloud-based registry where Docker images are stored and shared
- You can also run your own private registry
- Images are referred to as `username/repository:tag`

### Key Docker Commands: The Basics

```bash
# List all running containers
docker ps

# List all containers (including stopped ones)
docker ps -a

# Stop a container
docker stop <container_id_or_name>

# Start a stopped container
docker start <container_id_or_name>

# Remove a container
docker rm <container_id_or_name>

# View logs of a container
docker logs <container_id_or_name>

# List all images
docker images
```

## 6. Creating Your Own Docker Image

Now let's create our own Docker image with a Dockerfile:

1. Create a file named `Dockerfile` (no extension)
2. Add these contents:

```Dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
```

3. Create a simple `index.html` file:
```html
<!DOCTYPE html>
<html>
<head>
    <title>My Docker Website</title>
</head>
<body>
    <h1>Hello from Docker!</h1>
    <p>If you see this, your custom Docker image works!</p>
</body>
</html>
```

4. Build your image:
```bash
docker build -t my-website .
```

5. Run your image:
```bash
docker run -d -p 8080:80 --name my-website-container my-website
```

6. Visit http://localhost:8080 in your browser to see your website!

## 7. Docker Architecture: How It Works

Now that you've used Docker, let's understand how it works under the hood:

### Docker Components

- **Docker Engine**: The core of Docker (daemon, REST API, CLI)
- **Docker Client**: The command line tool that lets you interact with Docker
- **Docker Host**: The machine running the Docker daemon
- **Docker Registry**: Stores Docker images

```
  +-------------+     +-------------+     +-----------------+
  |             |     |             |     |                 |
  | Docker CLI  |---->| Docker API  |---->|  Docker Daemon  |
  |  (Client)   |     |   (REST)    |     |                 |
  |             |     |             |     |                 |
  +-------------+     +-------------+     +-----------------+
                                               |      ^
                                               |      |
                                               v      |
  +-----------------------------------------------------------------+
  |                                                                 |
  |                     Host Operating System                       |
  |                                                                 |
  +-----------------------------------------------------------------+
        |            |              |                |
        v            v              v                v
  +----------+  +----------+  +----------+    +------------+
  |          |  |          |  |          |    |            |
  |Container1|  |Container2|  |Container3|    |  Registry  |
  |          |  |          |  |          |    |            |
  +----------+  +----------+  +----------+    +------------+
```

### Image Layers

Docker images are built in layers, where each instruction in a Dockerfile creates a layer:

- Each layer is a difference from the previous layer
- Layers are cached to speed up builds
- Layers are read-only
- When a container runs, Docker adds a writable layer on top

```
                 Container Layer (R/W)
              +-----------------------+
              |                       |
              +-----------------------+
                 Image Layer 3 (R/O)     FROM nginx:alpine
              +-----------------------+   COPY index.html /usr/share/nginx/html/
              |                       |
              +-----------------------+
                 Image Layer 2 (R/O)     FROM alpine
              +-----------------------+   RUN apk add --no-cache nginx
              |                       |
              +-----------------------+
                 Image Layer 1 (R/O)     FROM scratch
              +-----------------------+   ADD alpine-base.tar.gz /
              |                       |
              +-----------------------+
```

```bash
# View the layers in an image
docker history nginx:alpine
```

## 8. Docker Networking

Containers need to communicate with each other and the outside world. Docker provides several network types:

### Network Types

- **bridge**: The default network. Containers can talk to each other (if on same bridge)
- **host**: Container uses the host's networking directly
- **none**: No networking
- **overlay**: Connect multiple Docker daemons together (used with Docker Swarm)
- **macvlan**: Assign a MAC address to a container (appears as physical device)

```bash
# List networks
docker network ls

# Create a network
docker network create my-network

# Run a container on a specific network
docker run -d --name db --network my-network postgres

# Connect an existing container to a network
docker network connect my-network my-container
```

## 9. Data Persistence with Volumes

Containers are ephemeral - when they're deleted, their data is lost. Volumes solve this:

### Types of Data Storage

- **Volumes**: Managed by Docker, stored in a part of the host filesystem
- **Bind Mounts**: Map a host path directly into a container
- **tmpfs mounts**: Stored in host memory only

```
   Host Filesystem                       Container Filesystem
+---------------------+                +----------------------+
|                     |                |                      |
|                     |                |                      |
|                     |                |                      |
|  +---------------+  |                |  +---------------+   |
|  |   /var/lib/   |  |                |  |  /data inside |   |
|  |   docker/     |  |   mounted as   |  |   container   |   |
|  |   volumes/    |<-+--------------->+->|               |   |
|  |   volume1     |  |                |  |               |   |
|  +---------------+  |                |  +---------------+   |
|                     |                |                      |
+---------------------+                +----------------------+
```

```bash
# Create a named volume
docker volume create my-data

# Run a container with a volume
docker run -d --name postgres -v my-data:/var/lib/postgresql/data postgres

# Using bind mounts for development
docker run -d -p 8080:80 -v $(pwd):/usr/share/nginx/html nginx
```

## 10. Docker Compose: Managing Multi-Container Applications

Real applications often involve multiple containers. Docker Compose simplifies this:

### Creating a docker-compose.yml

```
 +-------------------+       +-------------------+
 |                   |       |                   |
 |    Web Service    |------>|  Database Service |
 |    (Frontend)     |       |   (PostgreSQL)    |
 |                   |       |                   |
 +-------------------+       +-------------------+
        ^   |                        ^
        |   |                        |
        |   v                        |
 +------------------------------------------+
 |                                          |
 |          Docker Compose File             |
 |     (defines and connects services)      |
 |                                          |
 +------------------------------------------+
```

```yaml
# Using the Compose Specification, versioning is optional at the root
# For older versions, you might see `version: '3.8'` for example.
services:
  web:
    build: ./web
    ports:
      - "8080:80"
    depends_on:
      - db
  db:
    image: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: example

volumes:
  postgres-data:
```

### Using Docker Compose

```bash
# Start all services
docker compose up -d

# View running services
docker compose ps

# View logs
docker compose logs <service_name_optional>

# Stop all services
docker compose down
```

## 11. Docker Best Practices

To get the most out of Docker:

### Image Best Practices

- Use official base images when possible
- Create minimal images (use Alpine or distroless)
- Multi-stage builds for smaller production images
- Don't run as root in containers
- Tag images specifically, avoid using `latest`

### Dockerfile Best Practices

```Dockerfile
# Example of a good Dockerfile
FROM node:14-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
USER nginx
```

- Group similar commands to reduce layers
- Place infrequently changing commands earlier in the Dockerfile
- Use .dockerignore to exclude unnecessary files

## 12. Troubleshooting Docker

Common issues and how to solve them:

### Container Problems

```bash
# View container logs
docker logs container_name

# Get a shell in a running container
docker exec -it container_name sh

# Check container resource usage
docker stats
```

### Image Problems

```bash
# Clean up unused images
docker image prune

# Remove all stopped containers and unused images
docker system prune -a
```

## 13. Next Steps on Your Docker Journey

Congratulations! You're now well on your way to becoming a Docker expert. Here's what to explore next:

- **Docker Swarm** or **Kubernetes** for container orchestration
- **Docker security** practices and scanning tools
- **CI/CD pipelines** with Docker
- **Docker monitoring** with Prometheus and Grafana

### Useful Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/) for official images
- [Play with Docker](https://labs.play-with-docker.com/) for online practice

Remember, the power of Docker comes from the ecosystem and patterns built around it. Keep exploring and experimenting!
