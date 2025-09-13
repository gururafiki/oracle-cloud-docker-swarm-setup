db = db.getSiblingDB('swarm');

db.createCollection('swarm');

db.createUser({
  user: "swarm_app",
  pwd: "<my_secret_passoword>", 
  roles: [
    { role: "readWrite", db: "swarm" }
  ]
})