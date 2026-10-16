# mongo-sharding-repl

Проект для задания 3: MongoDB sharding с репликацией.

В этой версии приложение `pymongo_api` подключается к `mongos`, а каждый MongoDB-шард является replica set из трех инстансов.

## Состав сервисов

- `pymongo_api` - приложение.
- `mongos` - MongoDB query router.
- `configsvr` - config server для метаданных шардированного кластера.
- `shard1-1`, `shard1-2`, `shard1-3` - replica set `shard1-rs`.
- `shard2-1`, `shard2-2`, `shard2-3` - replica set `shard2-rs`.

## Как запустить

Запустите контейнеры:

```shell
docker compose up -d
```

Проверьте, что сервисы стартовали:

```shell
docker compose ps
```

## Как инициализировать репликацию и шардирование

Запустите скрипт инициализации:

```shell
./scripts/mongo-init.sh
```

Скрипт выполняет следующие действия:

1. Инициализирует replica set `config-rs` для `configsvr`.
2. Инициализирует replica set `shard1-rs` из трех инстансов:
   - `shard1-1:27018`;
   - `shard1-2:27018`;
   - `shard1-3:27018`.
3. Инициализирует replica set `shard2-rs` из трех инстансов:
   - `shard2-1:27018`;
   - `shard2-2:27018`;
   - `shard2-3:27018`.
4. Добавляет оба replica set как шарды в `mongos`.
5. Включает шардирование для базы `somedb`.
6. Шардирует коллекцию `somedb.helloDoc` по hashed shard key `name`.
7. Заполняет коллекцию `helloDoc` 1000 документами.

## Как проверить MongoDB

Проверить список шардов:

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'sh.status()'
```

Проверить количество документов:

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.countDocuments()'
```

Проверить распределение коллекции по шардам:

```shell
docker compose exec -T mongos mongosh --port 27017 --quiet --eval 'db.getSiblingDB("somedb").helloDoc.getShardDistribution()'
```

Проверить replica set `shard1-rs`:

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'rs.status().members.map((member) => ({ name: member.name, state: member.stateStr }))'
```

Проверить replica set `shard2-rs`:

```shell
docker compose exec -T shard2-1 mongosh --port 27018 --quiet --eval 'rs.status().members.map((member) => ({ name: member.name, state: member.stateStr }))'
```

## Как проверить приложение

Если проект запущен локально, откройте:

[http://localhost:8080](http://localhost:8080)

Или выполните:

```shell
curl http://localhost:8080
```

В ответе приложения должны быть:

- `mongo_topology_type: "Sharded"`;
- `mongo_is_mongos: true`;
- коллекция `helloDoc`;
- общее количество документов `1000`;
- список шардов;
- количество документов по шардам внутри секции `collections.helloDoc.shards`;
- секция `replica_sets`, где у `shard1-rs` и `shard2-rs` указано по 3 реплики.

Проверить эндпоинт коллекции:

```shell
curl http://localhost:8080/helloDoc/count
```
