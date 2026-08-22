#!/bin/bash

set -e

echo "Инициализируем config server replica set"
docker compose exec -T configsvr mongosh --port 27019 --quiet <<'EOF'
try {
  const status = rs.status();
  print(`Replica set ${status.set} already initialized`);
} catch (error) {
  const result = rs.initiate({
    _id: "config-rs",
    configsvr: true,
    members: [
      { _id: 0, host: "configsvr:27019" }
    ]
  });
  printjson(result);
}
EOF

echo "Инициализируем shard1 replica set"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
try {
  const status = rs.status();
  print(`Replica set ${status.set} already initialized`);
} catch (error) {
  const result = rs.initiate({
    _id: "shard1-rs",
    members: [
      { _id: 0, host: "shard1-1:27018" },
      { _id: 1, host: "shard1-2:27018" },
      { _id: 2, host: "shard1-3:27018" }
    ]
  });
  printjson(result);
}
EOF

echo "Инициализируем shard2 replica set"
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<'EOF'
try {
  const status = rs.status();
  print(`Replica set ${status.set} already initialized`);
} catch (error) {
  const result = rs.initiate({
    _id: "shard2-rs",
    members: [
      { _id: 0, host: "shard2-1:27018" },
      { _id: 1, host: "shard2-2:27018" },
      { _id: 2, host: "shard2-3:27018" }
    ]
  });
  printjson(result);
}
EOF

echo "Ждем применения replica set конфигурации"
sleep 15

echo "Добавляем шарды и включаем шардирование коллекции"
docker compose exec -T mongos mongosh --port 27017 --quiet <<'EOF'
const adminDb = db.getSiblingDB("admin");
const configDb = db.getSiblingDB("config");
const appDb = db.getSiblingDB("somedb");

const shards = adminDb.runCommand({ listShards: 1 }).shards.map((shard) => shard._id);
if (!shards.includes("shard1-rs")) {
  const result = sh.addShard("shard1-rs/shard1-1:27018,shard1-2:27018,shard1-3:27018");
  printjson(result);
}
if (!shards.includes("shard2-rs")) {
  const result = sh.addShard("shard2-rs/shard2-1:27018,shard2-2:27018,shard2-3:27018");
  printjson(result);
}

const enableResult = sh.enableSharding("somedb");

const collectionMetadata = configDb.collections.findOne({ _id: "somedb.helloDoc" });
if (!collectionMetadata) {
  const result = sh.shardCollection("somedb.helloDoc", { name: "hashed" }, false, { numInitialChunks: 4 });
  printjson(result);
}

const deleteResult = appDb.helloDoc.deleteMany({});
const documents = [];
for (let i = 0; i < 1000; i += 1) {
  documents.push({ age: i, name: `ly${i}` });
}
const insertResult = appDb.helloDoc.insertMany(documents);

print(`Deleted documents: ${deleteResult.deletedCount}`);
print(`Inserted documents: ${Object.keys(insertResult.insertedIds).length}`);
print(`Total documents: ${appDb.helloDoc.countDocuments()}`);
printjson(adminDb.runCommand({ listShards: 1 }));
printjson({
  "shard1-rs members": adminDb.runCommand({ listShards: 1 }).shards.find((shard) => shard._id === "shard1-rs").host,
  "shard2-rs members": adminDb.runCommand({ listShards: 1 }).shards.find((shard) => shard._id === "shard2-rs").host
});
EOF

echo "Очищаем Redis cache"
docker compose exec -T redis redis-cli FLUSHALL
