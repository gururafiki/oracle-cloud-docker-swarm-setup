# MongoDB Docker Stack teamplte for Docker Swarm

This is the minimal Docker Stack template for deploying [MongoDB](https://www.mongodb.com/) - no-SQL database

In order to deploy to Docker Swarm:
1. Set Docker secret with `docker secret create mongo_root_password`. You will be prompted to input secret after running this command. Alternatively you can run following command instead to set secret without being prompted for input: `echo -n "<my_mongo_password>" | docker secret create mongo_root_password -`
2. Run `docker stack deploy -c docker-compose.yaml mongodb-app`

After deployment resulting connection string will look following way: `mongodb://$MONGO_INITDB_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@<public_ip>:27017/`.
