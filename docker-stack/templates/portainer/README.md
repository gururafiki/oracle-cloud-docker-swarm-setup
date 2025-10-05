# Portainer Docker Stack teamplte for Docker Swarm

This is the minimal Docker Stack template for deploying [Portainer](https://www.portainer.io/) - self-hosted container management solution.

In order to deploy to Docker Swarm - run `docker stack deploy -c docker-compose.yaml portainer-app`

Below you can see the list of endpoints you can access:
1. http://<public_ip>:9080 - HTTP access to Portainer
2. https://<public_ip>:9443 - HTTPS access to Portainer
