# minio-nessie-dremio-local-data-lakehouse

### Config Nessie Source for Dremio (By 🤖)

```sh
# Chmod script file if needed
chmod 777 init-dremio.sh

./init-dremio.sh
```

Take a 🧋/🥤/☕️ and wait.


### Config Nessie Source for Dremio (By 🙌)

**Name:** nessie

**Endpoint URL:** http://nessie:19120/api/v2

**Tick None Authentication Type**

**Tick AWS Access Key**

**AWS Access Key:** minio

**AWS Access Serect:** minio123

**AWS Root Path:** warehouse *(Don't forget to create bucket in MinIO)*

**Connection Properties:**

| name | value |
|------|-------|
|fs.s3a.path.style.access | true |
|fs.s3a.endpoint | minio:9000 |
|dremio.s3.compat | true |

**Un-tick encryption Connection** *(if you don't you SSL/TLS connection)*

### A simple SQL query for testing

```sql
-- Create new table
CREATE TABLE IF NOT EXISTS nessie.numbers (
    col1 INTEGER,
    col2 FLOAT
);

-- Insert data
INSERT INTO nessie.numbers VALUES
    (23, 90.32),
    (345, 67.84),
    (2, 91.237),
    (498, 123.456),
    (34, 89.089);

-- Read table
SELECT * FROM nessie.numbers;

-- Delete table
DROP TABLE IF EXISTS nessie.numbers;
```
