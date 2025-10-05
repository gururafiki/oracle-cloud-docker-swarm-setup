# Docker Stack templates for Docker Swarm

Here you can find several templates that you can use to build your own stack and deploy to Docker Swarm Cluster.

In every *template/* you will find:
- *docker-compose.yaml* - YAML file defining services and volumes, env variables, secrets needed for these services
- *secrets.example.yaml* - list of secrets that has to be set in environment. Keep in mind that for some templates (e.g. in *dokploy/*) - secrets has to be set not only to `docker secrets`, but also replaced templated within *docker-compose.yaml* (look for `{{ postgres_password }}`). You can either replace it in template manually, or take a look on ansible playbook that does it during **Copy docker-compose file**, check [dokploy_stack.yml](../ansible/dokploy_stack.yml)
- *README.md* - overview of Docket Stack.

## Cheatsheet
1. Set Docker secret with `docker secret create <secret_name>`. You will be prompted to input secret after running this command. Alternatively you can run following command instead to set secret without being prompted for input: `echo -n "<my_secret_value>" | docker secret create <secret_name> -`
2. Run `docker stack deploy -c docker-compose.yaml <my_stack_name>`