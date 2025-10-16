# Synchronet BBS Docker

A Docker-based deployment of [Synchronet BBS](http://www.synchro.net/), a multiuser bulletin board system

This is kind of a mess at the moment, since it's full of specific hacks for my personal installation.
But, maybe someday soon I'll tidy it up to be more generic?

## Features

- **Multi-stage Docker build** based on Debian bullseye-slim
- **DOSEMU** integration for running classic DOS door games
- **MQTT support** via Mosquitto
- **Persistent data** via volume mounts

## Prerequisites

- Docker
- Docker Compose

## Setup

### 1. Download Dependencies

First, download the required Synchronet and DOSEMU packages:

```bash
./update-deps.sh
```

This downloads:
- Synchronet source and runtime tarballs from vert.synchro.net
- DOSEMU package from Debian archives
- Kermit source for file transfers

### 2. Build the Container

With docker-compose:
```bash
docker-compose build
```

Or build directly:
```bash
docker build -t lmorchard/synchronet .
```

### 3. Run

You should read up on [Synchronet configuration](https://wiki.synchro.net/config:index).
This project gets sbbs running, but everything beyond that is out of scope for this README.

With docker run:
```bash
docker run -d \
  --name sbbs \
  -v $(pwd)/data:/data \
  -p 6580:6580 \
  -p 6522:6522 \
  -p 6523:6523 \
  lmorchard/synchronet
```

With docker-compose:
```bash
docker-compose up -d
```

## Data Persistence

Synchronet intermingles directories for runtime data, configuration, and customization alongside executables and other ideally read-only files.

So, I'm trying a slightly convoluted scheme of directory juggling and symlinking to support persistence in an external volume.

On startup, the container automatically runs `link-sbbs-data.sh` which:

1. **Initializes `/data` as needed** - Copies any missing Synchronet directories (ctrl, data, mods, etc.) from `/sbbs` in the container to the mounted `/data` volume - these are the out-of-box default files.
2. **Backs up conflicts** - If a directory exists in both locations, the original in `/sbbs/` is moved to `/data/backup/` before symlinking - unless a backup already exists, in which case the directory in the container is deleted.
3. **Creates symlinks from `/sbbs/` to `/data/`** - Links `/sbbs/<dir>` → `/data/<dir>` so all BBS state data and customizable files live in the persistent volume but are accessible from expected locations within the container.

This ensures all configuration, user data, and customizations persist across container rebuilds. The script ignores build-only directories like `exec`, `install`, and `src`.

Seems to be working for me, but it's a bit of a blunt instrument and it only operates on the first level of directories in `/sbbs/`

## Automated Builds

This repository uses GitHub Actions to automatically build and push Docker images to Docker Hub.

### Build Triggers

**"Nightly" builds (main branch):**
- Triggered on push to `main` branch or manual trigger
- Downloads latest `sbbs_src.tgz` and `sbbs_run.tgz` (development versions)
- Tagged as: `latest`, `main`, `sbbs-<hash>`

Note: This isn't *really* nightly, since I haven't bothered to hook this up to a schedule.
I might? But mostly I just want this as a way to do a quick archived build of the latest.

**Stable releases (version tags):**
- Triggered by git tags matching `v*` (e.g., `v320d`)
- Downloads versioned tarballs (e.g., `ssrc320d.tgz`, `srun320d.tgz`)
- Tagged as: `v320d`, `sbbs-<hash>`

### Smart Rebuild Detection

The workflow computes a SHA256 hash of the Synchronet source tarballs. If an image with that hash already exists on Docker Hub, it skips the rebuild and just updates tags. This saves ~5-10 minutes when Synchronet hasn't changed.

### Available Tags

- `lmorchard/synchronet:latest` - Most recent build from main branch
- `lmorchard/synchronet:v320d` - Specific stable release (e.g., v3.20d)
- `lmorchard/synchronet:sbbs-<hash>` - Exact Synchronet version by content hash
- `lmorchard/synchronet:main` - Current main branch

### Setting Up for Your Fork

To use automated builds in your fork:

1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Add two repository secrets:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Docker Hub access token (create at hub.docker.com → Account Settings → Security)
3. Update image name in `.github/workflows/docker-build-push.yml` (change `lmorchard/synchronet` to your image name)
