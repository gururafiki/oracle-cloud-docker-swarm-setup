# Dokploy Docker Stack template for Docker Swarm

**WARNING**: This template is experimental, recommendation is to use install script provided by Dokploy.

This is the minimal docker compose template for Dokploy (Open-source self-hosted Vercel alternative).

In order to deploy to Docker Swarm:
1. Set Docker secret with `docker secret create postgres_password`. You will be prompted to input secret after running this command. Alternatively you can run following command instead to set secret without being prompted for input: `echo -n "<my_postgres_password>" | docker secret create postgres_password -`
2. Replace `{{ postgres_password }}` in [docker-compose.yaml](docker-compose.yaml)
3. Run `docker stack deploy -c docker-compose.yaml dokploy-stack`

It exposes following endpoints:
- Port *3000* - Dokploy Admin UI.

Secrets:
- `POSTGRES_PASSWORD` - password for PostgreSQL Database.
