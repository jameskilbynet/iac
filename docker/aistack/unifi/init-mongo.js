db.getSiblingDB("unifi").createUser({
  user: process.env.MONGO_USER || "unifi",
  pwd: process.env.MONGO_PASS || "unifipass",
  roles: [{ role: "dbOwner", db: "unifi" }]
});
db.getSiblingDB("unifi_stat").createUser({
  user: process.env.MONGO_USER || "unifi",
  pwd: process.env.MONGO_PASS || "unifipass",
  roles: [{ role: "dbOwner", db: "unifi_stat" }]
});