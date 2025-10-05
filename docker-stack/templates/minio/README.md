# MinIO Docker Stack teamplte for Docker Swarm

This is the minimal Docker Compose template for deploying [MinIO](https://www.min.io/) - self-hosted blob-storage (S3 alternative)

In order to deploy to Docker Swarm:
1. Set Docker secret with `docker secret create minio_root_password`. You will be prompted to input secret after running this command. Alternatively you can run following command instead to set secret without being prompted for input: `echo -n "<my_minio_password>" | docker secret create minio_root_password -`
2. Run `docker stack deploy -c docker-compose.yaml minio-app`

Below you can see the list of endpoints you can access:
1. http://<public_ip>:9001 - HTTP Access to MinIO Admin UI
2. http://<public_ip>:9000 - S3 Endpoint

Credentials:
- Enviornment variable `MINIO_ROOT_USER` is used as login for Admin UI and as `AWS_ACCESS_KEY_ID`.
- Value of secret `minio_root_password` - used as password for Admin UI and as `AWS_SECRET_ACCESS_KEY`
