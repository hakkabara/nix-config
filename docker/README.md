# WorkVM Docker Tooling

Container stacks and images used by WorkVM DFIR/security tooling.

## BloodHound CE

Start:

    cd docker/bloodhound-ce
    docker compose --env-file /run/secrets/docker/bloodhound-ce.env up -d

Stop:

    docker compose --env-file /run/secrets/docker/bloodhound-ce.env down

UI:

    http://127.0.0.1:8080/ui/login

Neo4j:

    http://127.0.0.1:7474

## BloodHound Legacy

Preferred setup:

- BloodHound Legacy 4.3.1 native Nix package
- Neo4j 4.4.19 inside Docker

Start Neo4j:

    cd docker/bloodhound-legacy
    docker compose --env-file /run/secrets/docker/bloodhound-legacy.env up -d neo4j

Connect native BloodHound to:

    bolt://127.0.0.1:7688

Neo4j Browser:

    http://127.0.0.1:7475

### Fully containerized Legacy GUI

An archived third-party image is available but is not enabled by default:

    docker compose \
      --env-file /run/secrets/docker/bloodhound-legacy.env \
      --profile container-gui \
      up -d

Prefer the native Legacy client whenever possible.

## Arkime

Local offline-PCAP analysis stack.

Components:

- Arkime 6.6.0
- OpenSearch 2.19.5
- Arkime Viewer
- UI PCAP upload

Runtime secret:

    /run/secrets/docker/arkime.env

The UI is published only on:

    http://127.0.0.1:8005

First-time initialization:

    cd docker/arkime

    docker compose \
      --env-file /run/secrets/docker/arkime.env \
      up -d opensearch

    docker compose \
      --env-file /run/secrets/docker/arkime.env \
      run --rm arkime-init

    docker compose \
      --env-file /run/secrets/docker/arkime.env \
      run --rm arkime-user

    docker compose \
      --env-file /run/secrets/docker/arkime.env \
      up -d viewer

The admin username is:

    admin

The admin password is stored only in the SOPS runtime environment.

## Zeek PCAP helper

Analyze an offline PCAP with the preloaded Zeek container:

    zeek-pcap evidence.pcap

Optional output directory:

    zeek-pcap evidence.pcap ./zeek-output

The input is mounted read-only and generated Zeek logs are written as
the current WorkVM user.
