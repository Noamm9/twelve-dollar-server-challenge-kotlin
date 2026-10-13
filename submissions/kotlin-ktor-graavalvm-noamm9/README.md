# Kotlin + Ktor GraalVM

|                     |                                                                                                                                                           |
|---------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Language            | Kotlin 2.4.0                                                                                                                                              |
| Runtime             | GraalVM CE 25.4.4.1.1 native image                                                                                                                        |
| Framework           | Ktor 3.6.0                                                                                                                                                |
| Server              | Ktor CIO                                                                                                                                                  |
| SQLite driver       | xerial sqlite-jdbc 3.53.4.0                                                                                                                               |
| Connection pool     | HikariCP 7.1.0                                                                                                                                            |
| JSON                | kotlinx.serialization through Ktor content negotiation                                                                                                    |
| **Nginx or direct** | **Direct preferred**: serves `0.0.0.0:80` when configured that way;<br>But can be tested over Nginx too by changing `PORT` environment variable to `3000` |

Dependency versions are pinned in `gradle/libs.versions.toml`

## Running it

```bash
sudo bash install.sh 
bash build.sh
SQLITE_PATH=... JWT_SECRET=.. HOST=0.0.0.0 PORT=80 bash start.sh
```

For local development, use a non-privileged port:
```bash
bash SQLITE_PATH=... JWT_SECRET=... HOST=127.0.0.1 PORT=3000 bash start.sh
```

The server reads all runtime configuration from the challenge environment variables:

| Variable      | Purpose              | Default                   |
|---------------|----------------------|---------------------------|
| `SQLITE_PATH` | SQLite database path | `<project_dir>/sqlite.db` |
| `JWT_SECRET`  | HS256 JWT secret     | `twelve-dollar-challenge` |
| `HOST`        | HTTP bind host       | `127.0.0.1`               |
| `PORT`        | HTTP bind port       | `80`                      |

Defaults are provided only for local development.

## Build output

`install.sh` installs GraalVM CE into `/opt/graalvm`, and `build.sh` uses it for Gradle's `nativeCompile` task. `start.sh` then runs the native binary in the foreground:

```bash
build/native/nativeCompile/velox
```

Reflection used by Hikari, logback, java-jwt (Jackson) and kotlinx.serialization is registered in `src/main/resources/META-INF/native-image/dev.noamm9.velox/velox/reachability-metadata.json`, generated with the GraalVM tracing agent while running `test/test.sh`. A new `@Serializable` response class needs its `Companion` field and `Companion.serializer()` added there.

## Optimizations, and why

- **Direct mode preferred.** The app can bind to `0.0.0.0:80` when the benchmark environment provides the required capability. This avoids spending CPU on Nginx on a one-vCPU machine. For development, `PORT=3000` can be used to avoid privileged-port binding issues.
- **GraalVM native image.** No JIT warm-up and a much smaller memory footprint than the JVM, which leaves more of the 2 GB for SQLite's page cache and connections.
- **Ktor CIO.** CIO is a coroutine-based HTTP engine and keeps the stack simple without an external servlet container.
- **SQLite through JDBC with HikariCP.** Connections are reused instead of opening a new SQLite connection from scratch for every request.
- **SQLite pragmas set on connections.** The app enables WAL mode, `synchronous=NORMAL`, a busy timeout, mmap, a larger page cache, and in-memory temporary storage. WAL plus `synchronous=NORMAL` keeps writes durable enough for the challenge rules while improving read/write behavior.
- **Reference-style SQL.** Feed and post reads use the challenge's join plus per-post like-count query shape. Post creation uses `INSERT ... RETURNING`. Likes use one insert statement with `ON CONFLICT DO NOTHING`, followed by a post-existence check only when needed to distinguish an existing like from a missing post.
- **No cross-request response cache.** Requests read from SQLite while being served. Prepared statements and SQLite's own page cache are the only caching-like behavior used.
- **JWT auth uses Ktor's JWT support.** Tokens are verified on authenticated requests using the configured `JWT_SECRET`; token results are not cached across requests.
- **Compact JSON via kotlinx.serialization.** Response objects are serialized by Ktor content negotiation with stable field order from the Kotlin serializable models.

## License

MIT, under the repo's [license](../../LICENSE).