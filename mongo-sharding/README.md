# mongo-sharding

Проект для задания 2: MongoDB sharding.

В этой версии приложение `pymongo_api` подключается не к одиночной MongoDB, а к `mongos`. `mongos` маршрутизирует запросы к двум шардам: `shard1` и `shard2`. Метаданные шардированного кластера хранит `configsvr`.

## Состав сервисов

- `pymongo_api` - приложение.
- `mongos` - MongoDB query router.
- `configsvr` - config server для метаданных шардированного кластера.
- `shard1` - первый шард.
- `shard2` - второй шард.

## Как запустить

Запустите контейнеры:

```shell
docker compose up -d
```

Проверьте, что сервисы стартовали:

```shell
docker compose ps
```

## Как инициализировать шардирование

Запустите скрипт инициализации:

```shell
./scripts/mongo-init.sh
```

Скрипт выполняет следующие действия:

1. Инициализирует replica set `config-rs` для `configsvr`.
2. Инициализирует одноузловый replica set `shard1-rs` для `shard1`.
3. Инициализирует одноузловый replica set `shard2-rs` для `shard2`.
4. Добавляет `shard1-rs` и `shard2-rs` в `mongos`.
5. Включает шардирование для базы `somedb`.
6. Шардирует коллекцию `somedb.helloDoc` по hashed shard key `name`.
7. Заполняет коллекцию `helloDoc` 1000 документами.

Шарды в этом задании сделаны как одноузловые replica set, потому что `mongos` работает с шардами в формате replica set. Полноценную отказоустойчивость с тремя репликами на каждый шард добавляем в задании 3.

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
- количество документов по шардам внутри секции `collections.helloDoc.shards`.

Проверить эндпоинт коллекции:

```shell
curl http://localhost:8080/helloDoc/count
```
