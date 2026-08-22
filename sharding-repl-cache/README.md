# sharding-repl-cache

Проект для задания 4: MongoDB sharding, репликация и Redis-кеширование.

В этой версии приложение `pymongo_api` подключается к `mongos`, каждый шард является replica set из трех инстансов, а ответы эндпоинта `/helloDoc/users` кешируются в Redis.

## Состав сервисов

- `pymongo_api` - приложение.
- `mongos` - MongoDB query router.
- `configsvr` - config server для метаданных шардированного кластера.
- `shard1-1`, `shard1-2`, `shard1-3` - replica set `shard1-rs`.
- `shard2-1`, `shard2-2`, `shard2-3` - replica set `shard2-rs`.
- `redis` - кеш для ответов приложения.

## Как запустить

Запустите контейнеры:

```shell
docker compose up -d
```

Проверьте, что сервисы стартовали:

```shell
docker compose ps
```

## Как инициализировать MongoDB

Запустите скрипт инициализации:

```shell
./scripts/mongo-init.sh
```

Скрипт выполняет следующие действия:

1. Инициализирует replica set `config-rs` для `configsvr`.
2. Инициализирует replica set `shard1-rs` из трех инстансов.
3. Инициализирует replica set `shard2-rs` из трех инстансов.
4. Добавляет оба replica set как шарды в `mongos`.
5. Включает шардирование для базы `somedb`.
6. Шардирует коллекцию `somedb.helloDoc` по hashed shard key `name`.
7. Заполняет коллекцию `helloDoc` 1000 документами.
8. Очищает Redis cache, чтобы после повторной инициализации не остались старые ответы.

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
- `cache_enabled: true`;
- коллекция `helloDoc`;
- общее количество документов `1000`;
- список шардов;
- количество документов по шардам внутри секции `collections.helloDoc.shards`;
- секция `replica_sets`, где у `shard1-rs` и `shard2-rs` указано по 3 реплики.

## Как проверить кеширование

Кеширование включено для эндпоинта:

```text
/helloDoc/users
```

Первый запрос должен выполняться дольше, потому что приложение читает данные из MongoDB. Второй и последующие запросы должны выполняться быстрее 100 мс, потому что ответ берется из Redis.

Перед проверкой можно очистить Redis:

```shell
docker compose exec -T redis redis-cli FLUSHALL
```

Замерить первый запрос:

```shell
curl -o /dev/null -s -w 'first request: %{time_total}s\n' http://localhost:8080/helloDoc/users
```

Замерить повторный запрос:

```shell
curl -o /dev/null -s -w 'cached request: %{time_total}s\n' http://localhost:8080/helloDoc/users
```
