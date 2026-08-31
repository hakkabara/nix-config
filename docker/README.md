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
