# AWS DMS (Database Migration Service) Complete Guide

## What is AWS DMS?

**DMS = Database Migration Service**

A tool that moves your database from one place to another with minimal/zero downtime.

```
On-Premises Database          →          AWS Cloud
(Your data center)                       (Managed Service)

MySQL 500 GB           →           Amazon RDS MySQL
OR
Oracle 100 GB          →           Amazon Aurora PostgreSQL
```

---

## Two Types of Migrations

### 1. Homogeneous (Same Database Type)
```
MySQL On-Prem → RDS MySQL
PostgreSQL On-Prem → RDS PostgreSQL
SQL Server On-Prem → RDS SQL Server

Same database engine, simpler migration
```

### 2. Heterogeneous (Different Database Type)
```
Oracle On-Prem → PostgreSQL on Aurora
SQL Server On-Prem → MySQL on RDS
Teradata → Amazon Redshift

Different database engines, more complex
```

---

# Part 1: Homogeneous Migration (Same DB Type)

## Scenario: MySQL On-Premises → Amazon RDS MySQL

```
Before:
├─ Database: MySQL 5.7 on-prem
├─ Size: 500 GB
├─ Location: Your data center
└─ Cost: $500/month (hardware + maintenance)

After:
├─ Database: Amazon RDS MySQL 5.7
├─ Size: 500 GB in AWS
├─ Location: Cloud (AWS)
└─ Cost: $300/month (50% savings!)
```

---

## Step 1: Create Target RDS Instance

**In AWS Console:**

```
1. Go to: RDS → Create Database
2. Choose:
   ├─ Engine: MySQL
   ├─ Version: 5.7 (same as on-prem)
   ├─ DB Instance Class: db.t3.large
   ├─ Storage: 600 GB
   ├─ Multi-AZ: Yes
   ├─ VPC: Your migration VPC
   ├─ DB Name: myapp_db
   ├─ Master Username: admin
   ├─ Master Password: SecurePassword123
   └─ Click: "Create database"

Result: Empty RDS instance ready in AWS ✅
```

---

## Step 2: Create DMS Replication Instance

**In AWS Console:**

```
1. Go to: Database Migration Service → Replication Instances
2. Click: "Create replication instance"
3. Fill in:
   ├─ Name: "MySQL-Migration-Replication"
   ├─ Replication Instance Class: dms.t3.large
   ├─ Allocated Storage: 200 GB
   ├─ VPC: Your migration VPC
   ├─ Multi-AZ: Yes
   └─ Click: "Create"

Result: DMS replication instance ready ✅
```

---

## Step 3: Create Source Endpoint (On-Prem MySQL)

**In AWS Console:**

```
1. Go to: Database Migration Service → Endpoints
2. Click: "Create endpoint"
3. Choose: Endpoint Type: Source
4. Fill in:
   ├─ Endpoint Name: "On-Prem-MySQL-Source"
   ├─ Database Engine: MySQL
   ├─ Server Name: 192.168.1.50 (on-prem IP)
   ├─ Port: 3306
   ├─ User Name: root
   ├─ Password: your_password
   ├─ Database Name: myapp_db
   └─ Click: "Create endpoint"

5. Test Connection:
   ├─ Click: "Test connection"
   ├─ Choose replication instance
   └─ Status: SUCCESS ✅
```

---

## Step 4: Create Target Endpoint (RDS MySQL)

**In AWS Console:**

```
1. Go to: Database Migration Service → Endpoints
2. Click: "Create endpoint"
3. Choose: Endpoint Type: Target
4. Fill in:
   ├─ Endpoint Name: "RDS-MySQL-Target"
   ├─ Database Engine: MySQL
   ├─ Server Name: mydb.xxxxx.rds.amazonaws.com
   ├─ Port: 3306
   ├─ User Name: admin
   ├─ Password: SecurePassword123
   ├─ Database Name: myapp_db
   └─ Click: "Create endpoint"

5. Test Connection:
   ├─ Click: "Test connection"
   └─ Status: SUCCESS ✅
```

---

## Step 5: Create Migration Task

**In AWS Console:**

```
1. Go to: Database Migration Service → Database Migration Tasks
2. Click: "Create task"
3. Fill in Task Details:
   ├─ Task Identifier: "mysql-to-rds-migration"
   ├─ Replication Instance: "MySQL-Migration-Replication"
   ├─ Source Database Endpoint: "On-Prem-MySQL-Source"
   ├─ Target Database Endpoint: "RDS-MySQL-Target"
   ├─ Migration Type: "Migrate existing data and replicate ongoing changes"
   └─ Click: "Next"

4. Fill in Task Settings:
   ├─ Table Mappings:
   │  ├─ Selection rule: "include"
   │  ├─ Schema: "%"
   │  ├─ Table: "%"
   │  └─ Result: All tables will migrate ✅
   │
   ├─ LOB Settings:
   │  ├─ Limit: "limited"
   │  └─ Size: "32" KB
   │
   ├─ Validation:
   │  └─ Enable validation: YES ✅
   │
   ├─ CloudWatch Logs:
   │  └─ Enable CloudWatch logs: YES ✅
   │
   └─ Click: "Create task"

Result: Migration starts automatically ✅
```

---

## Step 6: Monitor Migration Progress

**In AWS Console:**

```
Full Load Progress:
├─ Status: ● Running
├─ Progress: 35%
├─ Tables Completed: 15 / 42
├─ Rows Read: 5,000,000
├─ Rows Loaded: 4,900,000
└─ Estimated Time: 2 hours (for 500 GB)

Full Load Completed:
├─ Status: ● Ongoing Replication
├─ Full Load: 100% ✅
├─ CDC (Change Data Capture): Started
├─ Replication Lag: < 1 second
└─ Both databases in sync ✅
```

---

## Step 7: Cutover (Switch to RDS)

**Cutover Window: 2-5 minutes**

```
T - 5 min: Prepare
           ├─ Verify replication lag = 0
           └─ All data synced ✅

T - 0 min: STOP APPLICATION
           ├─ No new transactions
           └─ Current connections close

T + 30 sec: Update Connection String
            ├─ Old: mysql://192.168.1.50:3306/myapp_db
            ├─ New: mysql://mydb.xxxxx.rds.amazonaws.com:3306/myapp_db
            └─ Application reconnects

T + 60 sec: START APPLICATION
            ├─ Connected to RDS MySQL
            ├─ Queries work ✅
            └─ Users back online

Result: Migration complete! 🎉
Downtime: ~2-5 minutes
```

---

## Homogeneous Migration Summary

```
Timeline: 3-4 weeks
├─ Week 1: Planning & setup
├─ Week 2: Replication & CDC
├─ Week 3: Testing
└─ Week 4: Cutover & validation

Effort: LOW
├─ DMS handles 99% automatically
├─ Manual work: Minimal
└─ Mostly monitoring

Cost: FREE (within free tier for testing)

Risk: LOW ✅
├─ Same database type
├─ Schema identical
├─ Cutover smooth
└─ Rollback easy

Downtime: 2-5 minutes ✅
```

---

# Part 2: Heterogeneous Migration (Different DB Type)

## Scenario: Oracle On-Premises → Amazon Aurora PostgreSQL

```
Before:
├─ Database: Oracle 12c on-prem
├─ Size: 100 GB
├─ Cost: $40,000/year (licensing)
├─ Complexity: HIGH (many stored procedures)
└─ Location: Your data center

After:
├─ Database: Amazon Aurora PostgreSQL
├─ Size: 100 GB in AWS
├─ Cost: $4,000/year (50x cheaper!)
├─ Complexity: Schema converted automatically
└─ Location: Cloud (AWS)
```

---

## Key Difference: Schema Conversion Required

### Homogeneous (No Conversion)
```
Oracle MySQL Table        →        RDS MySQL Table
CREATE TABLE customer (   →        CREATE TABLE customer (
  id INT,                            id INT,
  name VARCHAR(100)                  name VARCHAR(100)
);                                 );

Same structure, no changes! ✅
```

### Heterogeneous (Conversion Required)
```
Oracle Table              →        PostgreSQL Table
CREATE TABLE CUSTOMER (   →        CREATE TABLE customer (
  CUSTOMER_ID NUMBER(10), →          customer_id SERIAL,
  CUST_NAME VARCHAR2(100),→          cust_name VARCHAR(100),
  EMAIL VARCHAR2(100)     →          email VARCHAR(100)
);                                 );

DMS CONVERTS:
✓ Table names: UPPERCASE → lowercase
✓ Data types: NUMBER → SERIAL, VARCHAR2 → VARCHAR
✓ Constraints: Foreign keys, indexes
```

---

## Step 1: Create Target Aurora PostgreSQL

**In AWS Console:**

```
1. Go to: RDS → Create Database
2. Choose:
   ├─ Engine: Amazon Aurora
   ├─ Edition: PostgreSQL-compatible
   ├─ Version: Latest (e.g., 15.2)
   ├─ DB Cluster Class: db.t3.medium
   ├─ Storage: 100 GB
   ├─ Multi-AZ: Yes
   ├─ VPC: Your migration VPC
   ├─ DB Name: oracledb
   ├─ Master Username: postgres
   ├─ Master Password: SecurePassword123
   └─ Click: "Create database"

Result: Aurora PostgreSQL instance ready ✅
```

---

## Step 2: Create DMS Replication Instance

**Same as homogeneous migration**

```
1. Go to: Database Migration Service → Replication Instances
2. Create:
   ├─ Name: "Oracle-to-Aurora-Replication"
   ├─ Class: dms.t3.large
   ├─ Storage: 200 GB
   └─ Click: "Create"
```

---

## Step 3: Create Source Endpoint (Oracle)

**In AWS Console:**

```
1. Go to: Database Migration Service → Endpoints
2. Create Source Endpoint:
   ├─ Endpoint Type: Source
   ├─ Database Engine: Oracle
   ├─ Server Name: 192.168.1.30 (on-prem Oracle)
   ├─ Port: 1521 (Oracle default)
   ├─ User Name: system
   ├─ Password: oracle_password
   ├─ Database Name: ORCL
   └─ Click: "Create endpoint"

3. Test Connection:
   └─ Status: SUCCESS ✅
```

---

## Step 4: Create Target Endpoint (PostgreSQL)

**In AWS Console:**

```
1. Go to: Database Migration Service → Endpoints
2. Create Target Endpoint:
   ├─ Endpoint Type: Target
   ├─ Database Engine: PostgreSQL
   ├─ Server Name: oracledb.xxxxx.amazonaws.com
   ├─ Port: 5432
   ├─ User Name: postgres
   ├─ Password: SecurePassword123
   ├─ Database Name: postgres
   └─ Click: "Create endpoint"

3. Test Connection:
   └─ Status: SUCCESS ✅
```

---

## Step 5: Create Migration Task (With Schema Conversion)

**In AWS Console:**

```
1. Go to: Database Migration Service → Database Migration Tasks
2. Create Task:
   ├─ Task Identifier: "Oracle-to-Aurora-Migration"
   ├─ Replication Instance: "Oracle-to-Aurora-Replication"
   ├─ Source: "Oracle Source Endpoint"
   ├─ Target: "PostgreSQL Target Endpoint"
   ├─ Migration Type: "Migrate existing data and replicate ongoing changes"
   └─ Click: "Next"

3. Task Settings (IMPORTANT):
   ├─ Table Mappings: All tables selected
   ├─ Schema Conversion: ENABLED ✅
   │  └─ DMS converts Oracle → PostgreSQL
   ├─ Validation: ENABLED ✅
   │  └─ Verify source and target match
   ├─ LOB Settings: Limited
   └─ Click: "Create task"

Result: Migration starts with schema conversion ✅
```

---

## Step 6: Monitor Schema Conversion

**In AWS Console:**

```
Schema Conversion Status:
├─ Tables Scanned: 50
├─ Tables Converted: 48 ✅
├─ Warnings: 5 (needs review)
├─ Errors: 0 (critical issues)
│
└─ Conversion Details:
   ├─ Stored Procedures: 20 (NOT converted - manual work)
   ├─ Functions: 15 (check compatibility)
   ├─ Triggers: 10 (may need adjustment)
   ├─ Custom Types: 3 (review needed)
   └─ Data Types Converted:
      ├─ NUMBER → BIGINT ✅
      ├─ VARCHAR2 → VARCHAR ✅
      ├─ DATE → TIMESTAMP ✅
      └─ BLOB → BYTEA ✅

Full Load Progress:
├─ Status: Completed
├─ Tables Loaded: 50 / 50
├─ Rows Loaded: 50 million
├─ Time: 4 hours
└─ CDC Started: YES ✅

Data Validation:
├─ Validated Tables: 50 / 50
├─ Match: 50 ✅
├─ Mismatch: 0
└─ Validation: SUCCESS ✅
```

---

## Step 7: Manual Work - Fix Stored Procedures

**This is the critical part of heterogeneous migration!**

---

# Real-World Example: Banking Application

## The TransferMoney() Stored Procedure

### Business Logic:
```
When a customer transfers money:
1. Debit Account A (subtract money)
2. Credit Account B (add money)
3. Write Transaction Log (record transfer)
4. Commit Transaction (save all changes)

If ANY step fails:
├─ Rollback all changes
└─ Account balances unchanged (atomic transaction)
```

---

## ORACLE Version (PL/SQL)

```sql
CREATE OR REPLACE PROCEDURE TransferMoney(
  p_from_account_id IN NUMBER,
  p_to_account_id IN NUMBER,
  p_amount IN NUMBER,
  p_status OUT VARCHAR2)
IS
  v_from_balance NUMBER;
  v_to_balance NUMBER;
  v_transaction_id NUMBER;
BEGIN
  -- Get sequence for transaction ID
  v_transaction_id := seq_transaction.NEXTVAL;

  -- Start transaction (implicit in Oracle)
  
  -- Get sender's balance
  SELECT balance
  INTO v_from_balance
  FROM accounts
  WHERE account_id = p_from_account_id
  FOR UPDATE;  -- Lock the row
  
  -- Check sufficient balance
  IF v_from_balance < p_amount THEN
    RAISE_APPLICATION_ERROR(-20001, 'Insufficient funds');
  END IF;

  -- Debit Account A
  UPDATE accounts
  SET balance = balance - p_amount,
      last_updated = SYSDATE
  WHERE account_id = p_from_account_id;

  -- Get recipient's balance
  SELECT balance
  INTO v_to_balance
  FROM accounts
  WHERE account_id = p_to_account_id
  FOR UPDATE;  -- Lock the row

  -- Credit Account B
  UPDATE accounts
  SET balance = balance + p_amount,
      last_updated = SYSDATE
  WHERE account_id = p_to_account_id;

  -- Write Transaction Log
  INSERT INTO transaction_log(
    transaction_id,
    from_account_id,
    to_account_id,
    amount,
    transaction_date,
    status)
  VALUES(
    v_transaction_id,
    p_from_account_id,
    p_to_account_id,
    p_amount,
    SYSDATE,
    'SUCCESS');

  -- Commit transaction
  COMMIT;

  -- Set output status
  p_status := 'SUCCESS';

EXCEPTION
  WHEN OTHERS THEN
    -- Rollback on any error
    ROLLBACK;
    p_status := 'FAILED: ' || SQLERRM;
    RAISE;

END TransferMoney;
/
```

---

## Call Oracle Stored Procedure

```sql
DECLARE
  v_status VARCHAR2(100);
BEGIN
  -- Transfer $500 from Account 100 to Account 200
  TransferMoney(
    p_from_account_id => 100,
    p_to_account_id => 200,
    p_amount => 500,
    p_status => v_status);
  
  DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
END;
/

Output: Status: SUCCESS
```

---

## POSTGRESQL Version (PL/pgSQL)

```sql
CREATE OR REPLACE PROCEDURE TransferMoney(
  p_from_account_id INT,
  p_to_account_id INT,
  p_amount NUMERIC,
  OUT p_status VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
  v_from_balance NUMERIC;
  v_to_balance NUMERIC;
  v_transaction_id INT;
BEGIN
  -- Get next sequence for transaction ID
  v_transaction_id := nextval('seq_transaction');

  -- Start transaction (implicit)
  
  -- Get sender's balance with row lock
  SELECT balance
  INTO v_from_balance
  FROM accounts
  WHERE account_id = p_from_account_id
  FOR UPDATE;  -- Lock the row
  
  -- Check sufficient balance
  IF v_from_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient funds';
  END IF;

  -- Debit Account A
  UPDATE accounts
  SET balance = balance - p_amount,
      last_updated = NOW()
  WHERE account_id = p_from_account_id;

  -- Get recipient's balance with row lock
  SELECT balance
  INTO v_to_balance
  FROM accounts
  WHERE account_id = p_to_account_id
  FOR UPDATE;  -- Lock the row

  -- Credit Account B
  UPDATE accounts
  SET balance = balance + p_amount,
      last_updated = NOW()
  WHERE account_id = p_to_account_id;

  -- Write Transaction Log
  INSERT INTO transaction_log(
    transaction_id,
    from_account_id,
    to_account_id,
    amount,
    transaction_date,
    status)
  VALUES(
    v_transaction_id,
    p_from_account_id,
    p_to_account_id,
    p_amount,
    NOW(),
    'SUCCESS');

  -- Commit happens automatically if no exception
  -- Set output status
  p_status := 'SUCCESS';

EXCEPTION
  WHEN OTHERS THEN
    -- Rollback happens automatically
    p_status := 'FAILED: ' || SQLERRM;
    RAISE;

END;
$$;
```

---

## Call PostgreSQL Stored Procedure

```sql
-- Method 1: Using DO block
DO $$
DECLARE
  v_status VARCHAR;
BEGIN
  CALL TransferMoney(100, 200, 500, v_status);
  RAISE NOTICE 'Status: %', v_status;
END;
$$;

Output: Status: SUCCESS

-- Method 2: Direct call (PostgreSQL 11+)
CALL TransferMoney(100, 200, 500, NULL);
```

---

## Comparison: Oracle vs PostgreSQL

| Aspect | Oracle (PL/SQL) | PostgreSQL (PL/pgSQL) |
|--------|---|---|
| **Procedure Declaration** | `PROCEDURE ... IS` | `PROCEDURE ... LANGUAGE plpgsql AS $$` |
| **Variables** | `v_name IN/OUT NUMBER` | `p_name INT / OUT p_name INT` |
| **Sequence** | `seq_name.NEXTVAL` | `nextval('seq_name')` |
| **Current Date** | `SYSDATE` | `NOW()` |
| **Update Timestamp** | `UPDATE ... SYSDATE` | `UPDATE ... NOW()` |
| **Error Raise** | `RAISE_APPLICATION_ERROR(-20001, ...)` | `RAISE EXCEPTION '...'` |
| **Error Catch** | `EXCEPTION WHEN OTHERS` | `EXCEPTION WHEN OTHERS` |
| **Commit** | `COMMIT;` | Automatic |
| **Rollback** | `ROLLBACK;` | Automatic on exception |
| **Output Message** | `DBMS_OUTPUT.PUT_LINE(...)` | `RAISE NOTICE '...'` |
| **Error Message** | `SQLERRM` | `SQLERRM` |

---

## Key Differences in Banking Procedure

### 1. Sequence Access
```
Oracle:
v_transaction_id := seq_transaction.NEXTVAL;

PostgreSQL:
v_transaction_id := nextval('seq_transaction');
```

### 2. Date/Time
```
Oracle:
last_updated = SYSDATE

PostgreSQL:
last_updated = NOW()
```

### 3. Exception Handling
```
Oracle:
RAISE_APPLICATION_ERROR(-20001, 'Insufficient funds');

PostgreSQL:
RAISE EXCEPTION 'Insufficient funds';
```

### 4. Transaction Control
```
Oracle:
COMMIT;  -- Explicit
ROLLBACK; -- Explicit

PostgreSQL:
-- Automatic (implicit transactions)
-- No explicit COMMIT/ROLLBACK needed
-- Exception automatically rolls back
```

---

## What DMS Does (Automatic)

```
DMS Conversion:
✓ Basic structure converted
✓ Variable declarations updated
✓ UPDATE statements converted
✓ INSERT statements converted
✓ IF/ELSE logic converted
✓ Row-level locks (FOR UPDATE) work same way ✅
✓ Sequence access converted (mostly)
✓ Exception handling framework converted

Result: ~80% correct automatic conversion
```

---

## What You Must Fix (Manual Work)

```
Issues Found After DMS Conversion:

1. ❌ RAISE_APPLICATION_ERROR
   ├─ DMS converts to: RAISE EXCEPTION
   ├─ Result: Mostly works ✅
   └─ Action: Test and verify

2. ❌ Transaction Control
   ├─ Oracle: Explicit COMMIT/ROLLBACK
   ├─ PostgreSQL: Implicit (in procedures)
   ├─ DMS removes them
   └─ Action: Verify automatic behavior works

3. ❌ Sequence Generation
   ├─ Oracle: seq_name.NEXTVAL
   ├─ PostgreSQL: nextval('seq_name')
   ├─ DMS: Usually converts correctly ✓
   └─ Action: Test sequence generation

4. ✅ Date Functions
   ├─ Oracle: SYSDATE
   ├─ PostgreSQL: NOW()
   ├─ DMS: Converts automatically ✓
   └─ Action: Verify timestamps correct
```

---

## Testing: Oracle vs PostgreSQL

### Test Case: Transfer Money

```
Oracle Execution:
═══════════════════════════════════════
1. Before transfer:
   Account 100: $1000
   Account 200: $500

2. CALL TransferMoney(100, 200, 500, status);

3. After transfer:
   Account 100: $500 (deducted $500) ✓
   Account 200: $1000 (added $500) ✓
   Transaction Log: Record added ✓
   Status: SUCCESS ✓

PostgreSQL Execution (After Migration):
═══════════════════════════════════════
1. Before transfer:
   Account 100: $1000
   Account 200: $500

2. CALL TransferMoney(100, 200, 500, NULL);

3. After transfer:
   Account 100: $500 (deducted $500) ✓
   Account 200: $1000 (added $500) ✓
   Transaction Log: Record added ✓
   Status: SUCCESS ✓

MATCH! Procedure works correctly! ✅
```

### Test Edge Case: Insufficient Funds

```
Oracle:
════════
Account 100: $200 (has $200)
CALL TransferMoney(100, 200, 500, status);
  → Raises error: 'Insufficient funds'
  → Status: FAILED ✓
  → Accounts unchanged ✓

PostgreSQL:
═══════════
Account 100: $200 (has $200)
CALL TransferMoney(100, 200, 500, status);
  → Raises error: 'Insufficient funds'
  → Status: FAILED ✓
  → Accounts unchanged ✓

MATCH! Error handling works! ✅
```

---

## Real-World Banking Scenario

### Before Migration

```
Your Banking Application (Oracle):
├─ Runs on-prem Oracle 12c
├─ 100+ stored procedures
├─ Daily transactions: 1 million
├─ Critical: TransferMoney, Deposits, Withdrawals, etc.
├─ Licensing: $40,000/year
├─ Operational: $30,000/year
└─ Total: $70,000/year ❌
```

### Migration Process

```
Week 1-2: Planning
├─ Document 100+ stored procedures
├─ Identify critical procedures (TransferMoney, etc.)
└─ Plan testing strategy

Week 3: DMS Conversion
├─ DMS converts 80% automatically
├─ Schema converted: ✅
├─ 80 procedures work as-is: ✅
├─ 20 procedures need review: ⚠️
└─ TransferMoney: Minor fixes needed

Week 4-5: Manual Work & Testing
├─ Fix remaining 20 procedures
├─ Test each one thoroughly
├─ TransferMoney tested with edge cases
├─ All procedures validated
└─ Ready for production

Week 6: Cutover
├─ Execute cutover
├─ Switch to PostgreSQL Aurora
├─ Downtime: ~5 minutes
└─ Migration complete! 🎉
```

### After Migration

```
Your Banking Application (PostgreSQL Aurora):
├─ Runs in AWS
├─ Same 100+ stored procedures (converted)
├─ Daily transactions: 1 million (same)
├─ Critical procedures: All working ✅
├─ Licensing: Included (open source)
├─ Operational: $5,000/year (AWS managed)
└─ Total: $5,000/year ✅

Savings: $65,000/year (93% reduction!) 🎉
```

---

## Heterogeneous Migration Summary

```
Timeline: 8-12 weeks
├─ Week 1-2: Planning & assessment
├─ Week 3-4: DMS setup & conversion
├─ Week 5-6: Manual procedure fixes
├─ Week 7-8: Comprehensive testing
├─ Week 9: Additional testing & fixes
├─ Week 10: Final validation
├─ Week 11: Cutover preparation
└─ Week 12: Cutover & monitoring

Effort: HIGH ⚠️
├─ DMS handles 80% automatically
├─ Manual work: 20% (procedures, functions)
├─ Testing critical (financial transactions!)
└─ 4-6 weeks of hands-on work

Cost: FREE (within free tier for testing)

Risk: MEDIUM ⚠️
├─ More complexity than homogeneous
├─ Manual procedure verification needed
├─ Testing must be comprehensive
├─ Financial data integrity critical
└─ But manageable with planning

Downtime: 5-10 minutes ✅
```

---

# Comparison: Homogeneous vs Heterogeneous

| Aspect | Homogeneous | Heterogeneous |
|--------|---|---|
| **Example** | MySQL → RDS MySQL | Oracle → PostgreSQL |
| **Schema Conversion** | Identical ✅ | DMS converts ~80% ⚠️ |
| **Stored Procedures** | Work as-is ✅ | Need manual work ⚠️ |
| **Data Types** | Same ✅ | Mapped by DMS ✅ |
| **Functions** | Compatible ✅ | May need rewrite ⚠️ |
| **Testing** | Light ✅ | Heavy ⚠️ |
| **Timeline** | 3-4 weeks ✅ | 8-12 weeks ⚠️ |
| **Manual Work** | Minimal (1%) ✅ | Significant (20%) ⚠️ |
| **Cutover Risk** | LOW ✅ | MEDIUM ⚠️ |
| **Downtime** | 2-5 min ✅ | 5-10 min ⚠️ |
| **Cost Savings** | $200-500/month | $40,000-60,000/year |

---

## When to Use Which

### Use Homogeneous When:
```
✓ Same database type already in use
✓ Quick migration needed
✓ Minimal downtime required
✓ Simple schema, few procedures
✓ Non-critical application

Example:
├─ MySQL on-prem → RDS MySQL
├─ PostgreSQL on-prem → RDS PostgreSQL
└─ Timeline: 3-4 weeks
```

### Use Heterogeneous When:
```
✓ Want to modernize infrastructure
✓ Cost reduction critical (licensing)
✓ Open source preference
✓ More complex application
✓ Time to prepare available

Example:
├─ Oracle on-prem → Aurora PostgreSQL
├─ SQL Server on-prem → RDS MySQL
├─ Teradata → Amazon Redshift
└─ Timeline: 8-12 weeks
```

---

## Key Takeaways

### Homogeneous Migration
```
✅ Simple process
✅ High automation (99%)
✅ Fast timeline (3-4 weeks)
✅ Low risk
✅ Minimal manual work
```

### Heterogeneous Migration
```
✅ Bigger cost savings
✅ Schema conversion automated (80%)
⚠️ Manual work required (procedures, functions)
⚠️ Longer timeline (8-12 weeks)
⚠️ More testing needed
⚠️ Higher complexity
```

### Real Banking Example (TransferMoney)
```
✅ Oracle → PostgreSQL conversion ~85% automatic
⚠️ 15% manual fixes:
   ├─ Function names: seq.NEXTVAL → nextval()
   ├─ Date functions: SYSDATE → NOW()
   ├─ Error handling: RAISE_APPLICATION_ERROR → RAISE EXCEPTION
   └─ Testing: Critical for financial transactions!

Result: Works perfectly after conversion & testing ✅
```

---

## Cost Analysis

### Homogeneous (MySQL → RDS)
```
Current (On-Prem MySQL):
├─ Hardware: $500/month
├─ Maintenance: $200/month
└─ Total: $700/month

After Migration (RDS MySQL):
├─ RDS: $300/month
├─ Backup: $50/month
└─ Total: $350/month

Savings: $350/month (50% reduction)
Annual: $4,200 savings ✅
```

### Heterogeneous (Oracle → PostgreSQL)
```
Current (Oracle On-Prem):
├─ Licensing: $40,000/year
├─ Hardware: $20,000/year
├─ Operations: $30,000/year
└─ Total: $90,000/year

After Migration (Aurora PostgreSQL):
├─ RDS: $3,600/year
├─ Storage: $400/year
├─ Operations: $2,000/year
└─ Total: $6,000/year

Savings: $84,000/year (93% reduction) 🎉
Payback Period: < 6 months!
```

---

## Action Plan

### For Testing (Use AWS Free Tier)

```
Phase 1: Learn Homogeneous (Week 1-2)
├─ Create EC2 MySQL + RDS MySQL
├─ Use DMS to migrate 5 GB test data
├─ Practice cutover process
└─ Cost: $0 ✅

Phase 2: Learn Heterogeneous (Week 3-4)
├─ Use DocumentDB (30-day free trial)
├─ Create PostgreSQL target
├─ Test schema conversion
├─ Fix sample stored procedures
└─ Cost: $0 ✅

Phase 3: Advanced (Week 5+)
├─ Larger test databases
├─ More complex procedures
├─ Performance testing
└─ Cost: Still $0 (free tier) ✅
```

### For Production Migration (Later)

```
Month 1-2: Homogeneous (if applicable)
├─ Quick migration (3-4 weeks)
├─ Cost: $200-300
└─ Savings start immediately

Month 3-4: Heterogeneous (if applicable)
├─ Complex migration (8-12 weeks)
├─ Cost: $300-500
├─ But annual savings: $40k-60k+ 🎉
└─ ROI: < 1 month
```

---

## Final Summary

```
DMS is powerful for:
✅ Homogeneous migrations (easy, fast)
✅ Heterogeneous migrations (complex, worth it)

Key Success Factors:
✓ Plan thoroughly (especially heterogeneous)
✓ Test extensively (especially financial data)
✓ Document manual work needed
✓ Have rollback plan ready
✓ Validate after cutover

Remember:
The banking TransferMoney() example shows:
├─ 80% automatic conversion works perfectly
├─ 20% manual work is manageable
├─ Thorough testing catches issues
├─ Final result is reliable ✅

Your applications will work just as well,
just in the cloud, with massive cost savings! 💰
```
