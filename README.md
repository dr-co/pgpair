Pair master-slave for Postgresql for CI.

Fromm time to time You need to start Pg as master and replica in CI-system,
for example gitlab-ci system.

So You can use the docker.

Source code: https://github.com/dr-co/pgpair

Here is unera/pgpair:9.5, unera/pgpair:10, unera/pgpair:11, etc


**Environment**:

- `PG_USER`, `PG_PASSWORD` - user and password (default is test@test)
- `PG_DB` - database. (default is test) 
- `PG_MASTER_PORT` (default is 5432)
- `PG_SLAVE_PORT` (default is 5433)


**Note**: You can create several databases using space symbol in database name:

`PG_DB="test1 test2"` creates 2 databases `test1`, `test2`

Example `gitlab-ci.yml`:

```yaml
variables:
    PG_USER: myuser
    PG_PASSWORD: mypass
    PG_MASTER_PORT: 1234
    PG_SLAVE_PORT: 4321
    PG_DB: test1 test2
services:
    - name: unera/pgpair:11
      alias: shard0
    - name: unera/pgpair:11
      alias: shard1

test:
    script:
	test_connect shard0:1234,shard0:4321
	test_connect shard1:1234,shard1:4321
```
