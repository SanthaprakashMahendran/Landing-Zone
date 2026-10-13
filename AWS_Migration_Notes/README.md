# AWS Migration Notes (MAP Curriculum Companion)

These notes fill the gaps between the migration curriculum (Assess → Mobilize → Migrate) and the existing guides in the repo root.

## Existing notes (repo root)

| File | Covers |
|---|---|
| [OnPrem_to_AWS_Migration_Guide.md](../OnPrem_to_AWS_Migration_Guide.md) | Server migration walk-through, strategies, 7-phase runbook, costs |
| [VPN_Setup_and_MGN_Migration.md](../VPN_Setup_and_MGN_Migration.md) | Site-to-Site VPN, MGN steps *(see corrections in note 04, section 16)* |
| [AWS_DMS_Migration_Guide.md](../AWS_DMS_Migration_Guide.md) | DMS: homogeneous and heterogeneous migrations *(see the schema-conversion clarification in note 06)* |
| [README.md](../README.md), [DEPLOYMENT-CHECKLIST.md](../DEPLOYMENT-CHECKLIST.md) | Control Tower / AFT deployment |

## New notes (this folder)

| # | Note | Curriculum days | Assignment |
|---|---|---|---|
| 01 | [MAP Framework & the 6 Rs](01_MAP_Framework_and_6Rs.md) | Day 1 | |
| 02 | [Assess Phase Tools](02_Assess_Phase_Tools.md) (Migration Evaluator, Cloudamize/OLA, MRA, MPA/CMDB, questionnaire, ADS) | Day 2 | |
| 03 | [Mobilize: Migration Hub & Landing Zone](03_Mobilize_Migration_Hub_Landing_Zone.md) | Day 2–4 | **Assignment 1**: Control Tower, 2 accounts, guardrails |
| 04 | [AWS MGN Deep Dive](04_AWS_MGN_Deep_Dive.md) | Day 5–6 | **Assignment 2**: cross-region migration |
| 05 | [AWS Elastic Disaster Recovery](05_AWS_Elastic_Disaster_Recovery.md) | Day 7–8 | **Assignment 3**: region-to-region DR |
| 06 | [AWS SCT & DB Import/Export](06_AWS_SCT_and_DB_Import_Export.md) | Day 9–10 | **Assignment 4**: sample DB → RDS with DMS |
| 07 | [CloudEndure → MGN/DRS](07_CloudEndure_Legacy_to_MGN_DRS.md) | Day 11–12 | **Assignment 5** (done with MGN/DRS) |
| 08 | [Refactoring & App2Container](08_Refactoring_and_App2Container.md) | Day 13–14 | **Assignment 6** (optional) |
| 09 | [Data Transfer Services](09_Data_Transfer_Services.md) (S3, DataSync, Storage Gateway, Direct Connect, Snow) | Day 14 | |

## Suggested study order

```
01 → 02 → 03 (do Assignment 1) → 04 (Assignment 2) → 05 (Assignment 3)
   → 06 (Assignment 4) → 09 → 08 → 07
```

## Before you rely on the details

- AWS changes service names, features, prices and availability. These notes mark places to **verify against the current AWS documentation** (installer names/URLs, IAM policy names, device capacities, service status).
- Some services mentioned (Migration Hub features, Refactor Spaces, App2Container, Snowmobile, CloudEndure) may be retired, limited or replaced. Check each one's current status before planning around it.
- **Every lab can cost money.** Each assignment ends with a clean-up section. Delete replication servers, EBS volumes/snapshots, instances, DMS resources, IAM users/keys and VPC components when you finish.
