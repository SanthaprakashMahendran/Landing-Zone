# AWS SCT (Schema Conversion Tool) & Database Import/Export

SCT · DMS Schema Conversion · Native Dump/Restore · SQL Server Backup/Restore to RDS · Choosing the Method · Assignment 4

> Works together with `AWS_DMS_Migration_Guide.md` (DMS itself). This note covers what that guide leaves out: **who converts the schema**, and **native import/export** methods.

---

## Table of Contents
1. The Big Picture: Who Does What?
2. Homogeneous vs Heterogeneous (Quick Recap)
3. AWS Schema Conversion Tool (SCT)
4. SCT Workflow (Step by Step)
5. Reading the Assessment Report
6. Manual Fixes After Conversion
7. DMS Schema Conversion (Console-Based Alternative)
8. Babelfish for Aurora PostgreSQL (SQL Server Apps)
9. Native Import/Export Methods
10. MySQL / MariaDB
11. PostgreSQL
12. SQL Server (Backup/Restore to RDS)
13. Oracle (Data Pump)
14. Choosing: DMS vs Native Tools
15. Validation After Migration
16. Assignment 4: Sample DB → RDS with DMS (Step by Step)
17. Troubleshooting
18. Key Takeaways

---

## 1. The Big Picture: Who Does What?

```
HETEROGENEOUS MIGRATION (for example Oracle → Aurora PostgreSQL)

Step 1: SCHEMA          →  AWS SCT (or DMS Schema Conversion)
        tables, indexes, views, stored procedures, functions, sequences
Step 2: DATA            →  AWS DMS
        full load + ongoing replication (CDC)
Step 3: APPLICATION     →  you change SQL, drivers, connection strings
Step 4: VALIDATE + CUTOVER
```

| Tool | Moves | Converts schema? |
|---|---|---|
| **AWS DMS** | **Data** (and basic table structure for like-to-like) | ❌ Not complex objects such as stored procedures |
| **AWS SCT** | **Schema and code** | ✅ Converts, and flags what can't be converted automatically |
| **Native tools** | Data and schema together (same engine) | ❌ Same engine only |

> **Clarification for your DMS notes:** the heterogeneous example titled "Create Migration Task (With Schema Conversion)" can read as if DMS converts stored procedures. In practice **SCT (or DMS Schema Conversion) converts the schema, and the DMS task moves the data**. Verify against the DMS docs and update that heading/explanation.

---

## 2. Homogeneous vs Heterogeneous (Quick Recap)

| | Homogeneous | Heterogeneous |
|---|---|---|
| Example | MySQL → RDS MySQL | Oracle → Aurora PostgreSQL |
| Schema conversion | **Not needed** | **Required** (SCT) |
| Tools | Native dump/restore or DMS | **SCT + DMS** |
| Effort | Low | Medium to very high (stored procedures!) |
| Application changes | Minimal | SQL dialect, data types, drivers |

---

## 3. AWS Schema Conversion Tool (SCT)

### What it is
A **free desktop application** (Windows, macOS, Linux) that connects to your **source** and **target** databases and:

1. **Assesses** how convertible your schema is (report with a percentage and effort)
2. **Converts** schema objects automatically where possible
3. **Flags** the objects that need manual work, with hints
4. **Applies** the converted schema to the target

### Typical source → target pairs

| Source | Common targets |
|---|---|
| Oracle | Aurora PostgreSQL, RDS PostgreSQL, Aurora MySQL, RDS MySQL |
| SQL Server | Aurora PostgreSQL, RDS PostgreSQL, MySQL (or keep it on RDS SQL Server) |
| MySQL | PostgreSQL |
| Teradata, Netezza, Greenplum, Vertica | **Amazon Redshift** (data warehouse migrations) |
| IBM Db2, Sybase, SAP ASE | Various |

(Check the SCT user guide for the **current support matrix**.)

### What gets converted

| Object | Typical result |
|---|---|
| Tables, columns, data types | Mostly automatic |
| Primary/foreign keys, indexes | Mostly automatic |
| Views | Mostly automatic |
| Sequences and identity columns | Automatic with adjustments |
| **Stored procedures, functions, triggers, packages** | **Partly automatic**, often needs manual fixes |
| Vendor-specific features (Oracle packages, `CONNECT BY`, `ROWNUM`, `DECODE`) | Converted or flagged |

SCT can **insert extension packs** (helper functions in the target) to emulate source functions.

---

## 4. SCT Workflow (Step by Step)

```
1. Install SCT on a machine that can reach BOTH databases
2. Download the JDBC drivers for source and target, and configure them in SCT settings
3. Create a new project (choose source and target engines)
4. Connect to the source database (a read-only account with metadata access is enough)
5. Connect to the target database
6. Select the schema → right-click → "Create report" (assessment)
7. Review the report (section 5)
8. Right-click the schema → "Convert schema"
9. Review the converted code in the right pane; fix flagged items (section 6)
10. Right-click the converted schema on the TARGET side → "Apply to database"
11. Run DMS (full load + CDC) to move the data
12. Re-create/verify indexes and constraints per your DMS plan, then validate and cut over
```

### Order matters
```
SCT: create target schema (without data)
   ▼
DMS: full load + CDC  (often with foreign keys/triggers disabled during load)
   ▼
Create secondary indexes and constraints, then validate and cut over
```

### Network
SCT runs on a machine inside your network (or an EC2 bastion) with access to both databases, over the **VPN** if the source is on-prem.

---

## 5. Reading the Assessment Report

SCT produces a report such as:

```
Database Migration Assessment (illustrative)

Source: Oracle 19c          Target: Aurora PostgreSQL 15
Schemas: HR, SALES

Object type        Total   Auto-converted   Needs manual action
Tables               120       120               0
Views                 30        28               2
Indexes              210       210               0
Sequences             18        18               0
Procedures            45        20              25
Functions             60        35              25
Packages              12         0              12
Triggers              20        15               5

Overall: 78% fully automatic
Estimated effort for remaining items: ~45 person-days
```

### Reading it

| Item | What it means |
|---|---|
| **Auto-converted %** | The share SCT converted with no action needed |
| **Action items (by complexity)** | Simple / medium / **significant** / complex, which is your **effort estimate** |
| **Per-object details** | Why an object wasn't converted (unsupported feature) and what to do |
| **Drives the strategy** | Low % (for example below 50%) may mean *keep the engine* (RDS Oracle, or RDS SQL Server) or consider **Babelfish** |

> Run the assessment during the **Assess phase** (note 02). It decides whether a heterogeneous migration is worth it.

---

## 6. Manual Fixes After Conversion

Typical conversion issues (from Oracle PL/SQL to PostgreSQL PL/pgSQL; compare with the banking `TransferMoney()` example in your DMS guide):

| Oracle | PostgreSQL |
|---|---|
| `NUMBER` | `NUMERIC` / `INTEGER` / `BIGINT` (choose carefully) |
| `VARCHAR2` | `VARCHAR` / `TEXT` |
| `SYSDATE` | `NOW()` / `CURRENT_TIMESTAMP` |
| `seq.NEXTVAL` | `nextval('seq')` |
| `DECODE(a,b,c,d)` | `CASE WHEN ... END` |
| `ROWNUM` | `LIMIT` / `ROW_NUMBER()` |
| `NVL(a,b)` | `COALESCE(a,b)` |
| Packages | Schemas + functions |
| Exceptions (`WHEN OTHERS`) | `EXCEPTION WHEN OTHERS THEN` blocks with differences |
| `COMMIT` inside a procedure | Different transaction rules (use `PROCEDURE` with care) |
| Empty string = NULL in Oracle | Empty string ≠ NULL in PostgreSQL (logic bugs!) |

**Process for each flagged object:** read SCT's action item → rewrite in the target dialect → unit test → compare outputs between source and target on the same inputs.

---

## 7. DMS Schema Conversion (Console-Based Alternative)

AWS also provides **DMS Schema Conversion** inside the **DMS console** (no desktop app):

| | **SCT (desktop)** | **DMS Schema Conversion (console)** |
|---|---|---|
| Install | Yes (desktop + JDBC drivers) | No, it runs in AWS |
| Network | Your machine reaches both DBs | DMS **instance profile** reaches your DBs |
| Source/target support | Broadest (including DW sources) | A growing list (check docs) |
| Workflow | Local project | Migration project in the console |
| Best for | Complex/rare engines, offline work | Common engines, with a team that prefers the console |

You can try the console tool first, and use SCT when the engine isn't supported.

---

## 8. Babelfish for Aurora PostgreSQL (SQL Server Apps)

**Babelfish** lets **Aurora PostgreSQL** understand **T-SQL and the SQL Server wire protocol**, so many SQL Server apps run with **few code changes**.

```
SQL Server app ──(TDS protocol, T-SQL)──▶ Babelfish on Aurora PostgreSQL
```

| Point | Detail |
|---|---|
| Benefit | Escape SQL Server licensing without rewriting every query |
| Tool | **Babelfish Compass** analyzes your SQL for compatibility |
| Limits | Not 100% compatible. Test thoroughly |

Consider it for SQL Server → PostgreSQL migrations when **rewriting is too costly**.

---

## 9. Native Import/Export Methods

When migrating **to the same engine**, native tools are often simplest, and cheaper than DMS.

```
Native: stop (or quiesce) the source → dump → copy file → restore into RDS → switch
DMS:    full load + CDC (ongoing) → cutover with minimal downtime
```

| Pros of native | Cons of native |
|---|---|
| Simple, familiar, no extra service | **Downtime** equals dump + copy + restore time |
| Exact copy (same engine) | No ongoing replication (unless using engine-native replication) |
| Free (just storage and transfer) | Large DBs take long |

---

## 10. MySQL / MariaDB

### Small to medium databases: `mysqldump`

```bash
# 1. dump from the source
mysqldump -h source-host -u root -p \
  --single-transaction --routines --triggers --events \
  --set-gtid-purged=OFF  mydb > mydb.sql

# 2. restore into RDS MySQL
mysql -h mydb.xxxx.us-east-1.rds.amazonaws.com -u admin -p mydb < mydb.sql
```

- `--single-transaction` gives a consistent snapshot of InnoDB tables without locking.
- For big files, `gzip` the dump and copy it with `scp`/`aws s3 cp` to an EC2 instance in the same region as the RDS, then restore from there.

### Large databases: restore from an **S3 backup (Percona XtraBackup)** into a new RDS/Aurora MySQL instance

```
xtrabackup (source) → upload backup to S3 → RDS "Restore from S3" → new instance
```

Much faster than `mysqldump` for hundreds of GB.

### Minimal downtime: **binlog replication** (source → RDS), or **DMS** (full load + CDC).

---

## 11. PostgreSQL

```bash
# Dump (custom format, compressed, parallel)
pg_dump -h source-host -U postgres -Fc -j 4 -f mydb.dump mydb

# Restore into RDS PostgreSQL (create the DB first)
pg_restore -h mydb.xxxx.us-east-1.rds.amazonaws.com -U admin -d mydb -j 4 --no-owner --no-privileges mydb.dump

# Plain SQL alternative
pg_dump -h source-host -U postgres mydb > mydb.sql
psql   -h <rds-endpoint> -U admin mydb < mydb.sql
```

| Tip | Why |
|---|---|
| `-Fc` (custom format) + `pg_restore -j` | Faster, with parallel restore |
| `--no-owner --no-privileges` | RDS has no true superuser, so avoid ownership errors |
| Dump **roles** separately (`pg_dumpall --globals-only`) | Roles aren't in the database dump |
| **Logical replication** (`CREATE PUBLICATION/SUBSCRIPTION`) | Near-zero-downtime same-engine migration |
| Run `ANALYZE` after restore | Update planner statistics |

---

## 12. SQL Server (Backup/Restore to RDS)

RDS for SQL Server lets you restore **native `.bak` backups** through **S3**.

```
Source SQL Server ─ BACKUP DATABASE ─▶ .bak ─▶ upload to S3 ─▶ RDS restores it
```

### Setup (one time)

```
1. S3 bucket (same region as RDS) for backups
2. IAM role allowing RDS to read/write that bucket
3. RDS option group with option  SQLSERVER_BACKUP_RESTORE  (link the IAM role)
4. Attach the option group to the RDS SQL Server instance
```

### Backup on the source and upload

```sql
BACKUP DATABASE SalesDB TO DISK = 'D:\Backup\SalesDB.bak' WITH COMPRESSION, CHECKSUM;
```
```bash
aws s3 cp D:\Backup\SalesDB.bak s3://my-sql-backups/SalesDB.bak
```

### Restore in RDS (run on the RDS instance)

```sql
exec msdb.dbo.rds_restore_database
     @restore_db_name='SalesDB',
     @s3_arn_to_restore_from='arn:aws:s3:::my-sql-backups/SalesDB.bak';

-- check progress
exec msdb.dbo.rds_task_status @db_name='SalesDB';
```

### Reverse direction (RDS → file)

```sql
exec msdb.dbo.rds_backup_database
     @source_db_name='SalesDB',
     @s3_arn_to_backup_to='arn:aws:s3:::my-sql-backups/SalesDB-out.bak',
     @overwrite_s3_backup_file=1;
```

| Note | Detail |
|---|---|
| Must be the same or lower **SQL Server version/edition** compatibility | Check the RDS docs for the supported versions |
| **Logins** and **SQL Agent jobs** aren't in the backup | Script them separately |
| For minimal downtime | Use **DMS** or **log shipping/differential restores** (check RDS docs for the supported approach) |

(See the link in your curriculum for **Importing and exporting SQL Server databases**.)

---

## 13. Oracle (Data Pump)

```
Source: expdp → dump files → copy to RDS (via S3 integration or DB link) → RDS: impdp (DBMS_DATAPUMP)
```

```bash
# Source
expdp system/*** schemas=HR directory=DATA_PUMP_DIR dumpfile=hr.dmp logfile=hr_exp.log
```

RDS Oracle steps (outline):
1. Enable **S3 integration** (option group `S3_INTEGRATION`, IAM role)
2. Download the dump into `DATA_PUMP_DIR` from S3:
   ```sql
   SELECT rdsadmin.rdsadmin_s3_tasks.download_from_s3(
          p_bucket_name => 'my-oracle-dumps', p_directory_name => 'DATA_PUMP_DIR') AS task_id FROM dual;
   ```
3. Import with `DBMS_DATAPUMP` (since you don't have OS access).

For a minimal-downtime option, use **DMS (CDC)** or **GoldenGate**.

---

## 14. Choosing: DMS vs Native Tools

```
Same engine?
├─ Yes
│   ├─ Small DB / downtime OK ─────────────▶ Native dump/restore (simplest)
│   ├─ Large DB, short downtime needed ────▶ Native physical backup (XtraBackup / .bak) + catch-up
│   └─ Near-zero downtime needed ─────────▶ DMS (CDC) or engine-native replication
└─ No (heterogeneous)
    └─ SCT (schema) + DMS (data + CDC)       [+ manual code fixes]
```

| Factor | Native | DMS (+SCT) |
|---|---|---|
| Downtime | Hours (dump/copy/restore) | Minutes (cutover) |
| Engine change | ❌ | ✅ |
| Cost | Low | DMS replication instance + SCT effort |
| Complexity | Low | Medium |
| Large tables / LOBs | Fine | Needs tuning (LOB settings) |
| Ongoing sync | ❌ | ✅ CDC |
| Validation | Manual | Built-in data validation |

---

## 15. Validation After Migration

| Check | How |
|---|---|
| **Row counts** per table | `SELECT COUNT(*)` on source vs target |
| **Checksums** of key columns | Hash/aggregate comparisons |
| **DMS data validation** | Enable validation in the task, then check the `Validation state` |
| **Schema objects** | Compare counts of tables, indexes, constraints, procedures |
| **Sequences/identity** | Set the next value above the max (typical PostgreSQL post-load task) |
| **Stored procedure output** | Run the same inputs on both and diff |
| **Performance** | Compare slow queries, update statistics (`ANALYZE`) |
| **Application tests** | Full functional test against the new DB |
| **Permissions and users** | Recreate logins/roles |
| **Backups/monitoring** | Enable automated backups, Performance Insights, alarms |

---

## 16. Assignment 4: Sample DB → RDS with DMS (Step by Step)

**Goal:** Create a **source DB**, load a **sample database**, migrate it to **RDS with DMS**, and validate it. (Full DMS steps are in `AWS_DMS_Migration_Guide.md`; this adds the sample data and checks.)

### Option A: MySQL (Sakila sample)

**1. Source (EC2 playing "on-prem")**

```bash
# Amazon Linux 2023
sudo dnf install -y mariadb105-server   # or mysql-community-server
sudo systemctl enable --now mariadb
sudo mysql_secure_installation
wget https://downloads.mysql.com/docs/sakila-db.tar.gz && tar xzf sakila-db.tar.gz
sudo mysql < sakila-db/sakila-schema.sql
sudo mysql < sakila-db/sakila-data.sql
sudo mysql -e "CREATE USER 'dms'@'%' IDENTIFIED BY 'Str0ngPass!'; GRANT ALL ON sakila.* TO 'dms'@'%'; GRANT REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'dms'@'%';"
```

Enable binary logging for CDC (`log_bin=ON`, `binlog_format=ROW`, `server_id=1`) in the MySQL config, and restart.

**2. Target RDS**

```
RDS MySQL (db.t3.micro, single-AZ, 20 GB), same VPC or reachable, create an empty DB "sakila"
```

**3. DMS**

```
Replication instance (dms.t3.micro) → source endpoint (EC2) → target endpoint (RDS)
Task: Full load + CDC, enable validation, table mapping: schema "sakila" → all tables
```

**4. Validate**

```sql
-- on both
SELECT COUNT(*) FROM sakila.film;       -- 1000
SELECT COUNT(*) FROM sakila.rental;     -- 16044
SELECT COUNT(*) FROM sakila.customer;   -- 599
```

**5. Prove CDC**

```sql
-- on source while the task runs
INSERT INTO sakila.actor(first_name,last_name) VALUES ('Test','CDC');
-- on target
SELECT * FROM sakila.actor WHERE last_name='CDC';    -- appears within seconds
```

### Option B: Same migration using native tools (compare time and effort)

```bash
mysqldump -u root -p --single-transaction --routines --triggers sakila > sakila.sql
mysql -h <rds-endpoint> -u admin -p -e "CREATE DATABASE sakila_native"
mysql -h <rds-endpoint> -u admin -p sakila_native < sakila.sql
```

Compare: setup time, downtime, and whether changes after the dump were captured. (Not with `mysqldump`.)

### Option C: Heterogeneous (stretch goal)

Source **PostgreSQL** (Pagila sample) → **Aurora PostgreSQL** is homogeneous. For a heterogeneous practice use **MySQL (Sakila) → PostgreSQL** with **SCT**:

```
1. Install SCT + JDBC drivers on your laptop
2. Connect to Sakila (MySQL) and to an empty RDS PostgreSQL
3. Create the assessment report → convert schema → apply to PostgreSQL
4. Run a DMS full-load task for the data
5. Compare counts and a few queries
```

### Clean up

```
Delete: DMS task, endpoints, replication instance, RDS instances/snapshots, source EC2, security groups
```

---

## 17. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| SCT can't connect | Wrong JDBC driver/version, or network | Install the right driver, and test connectivity from that machine |
| Low conversion % | Many vendor-specific procedures | Review action items, consider Babelfish, or keep the source engine |
| DMS full load fails with FK errors | Foreign keys enforced during load | Disable FKs/triggers during load (target settings), then enable them |
| `mysqldump` restore fails (definer/GTID) | `DEFINER` users missing, GTID | `--set-gtid-purged=OFF`, and recreate definers or strip them |
| `pg_restore` ownership errors | RDS has no superuser | `--no-owner --no-privileges` |
| SQL Server restore fails | Option group missing, role problem, wrong version | Verify `SQLSERVER_BACKUP_RESTORE` and the IAM role, and check the version |
| CDC not capturing | Binlog/supplemental logging not enabled | Enable ROW binlog (MySQL), logical replication/`wal_level` (PostgreSQL), supplemental logging (Oracle) |
| Data mismatch after migration | LOB truncation, data type mapping, time zones | Check the DMS LOB mode, and the data type mapping rules |
| PostgreSQL sequences produce duplicates | Sequences not advanced after load | `SELECT setval(...)` to max(id)+1 |

---

## 18. Key Takeaways

```
1. DMS moves DATA. SCT (or DMS Schema Conversion) converts the SCHEMA and code. They work together.
2. Heterogeneous = SCT assessment → convert schema → manual fixes → DMS full load + CDC → validate.
3. The SCT assessment report (% auto-converted, action items) decides if a heterogeneous migration is worth it.
4. Babelfish can make SQL Server → Aurora PostgreSQL much cheaper to port.
5. Same-engine migrations can use native tools: mysqldump/XtraBackup, pg_dump/pg_restore, SQL Server .bak via S3, Oracle Data Pump.
6. Native = simple but has downtime. DMS CDC = minimal downtime.
7. Always validate: counts, checksums, DMS validation, sequences, stored procedure output, performance.
8. Practice with a sample DB (Sakila/Pagila), prove CDC with a live insert, and clean up.
```

**Next note:** `07_CloudEndure_Legacy_to_MGN_DRS.md`
