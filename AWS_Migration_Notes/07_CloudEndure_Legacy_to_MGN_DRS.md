# CloudEndure (Migration & Disaster Recovery): Legacy Tool → MGN and DRS

> **Why this note is short:** CloudEndure was an independent company's product that **AWS acquired in 2019**. AWS then rebuilt it as its own services. As I understand it:
> - **CloudEndure Migration → AWS Application Migration Service (MGN)**
> - **CloudEndure Disaster Recovery → AWS Elastic Disaster Recovery (DRS)**
>
> AWS has since retired the standalone CloudEndure products (around the end of 2022, as I recall). **Confirm the dates and status in AWS's announcements before quoting them.** If your curriculum still lists CloudEndure assignments, you do them in **MGN and DRS** today, and the concepts are the same.

---

## Table of Contents
1. Timeline and Mapping
2. How CloudEndure Worked (Same Idea You Already Know)
3. Terminology Map: CloudEndure → MGN/DRS
4. What Improved in MGN/DRS
5. Doing the CloudEndure Assignments Today
6. If You See CloudEndure in an Old Project
7. Interview-Ready Summary
8. Key Takeaways

---

## 1. Timeline and Mapping

```
CloudEndure (independent company)
   │  acquired by AWS (2019)
   ▼
CloudEndure Migration  ───────────────▶  AWS Application Migration Service (MGN)
CloudEndure Disaster Recovery ────────▶  AWS Elastic Disaster Recovery (DRS)
```

| Old product | Replacement | Note |
|---|---|---|
| CloudEndure Migration | **MGN** | The recommended AWS rehost tool |
| CloudEndure Disaster Recovery | **DRS** | The recommended AWS DR tool |
| CloudEndure console (a separate SaaS site) | **AWS console** | Native IAM, CloudTrail, tags, no separate login |

---

## 2. How CloudEndure Worked (Same Idea You Already Know)

```
Source server + CloudEndure agent
        │  continuous block-level replication (TLS, TCP 1500)
        ▼
Staging area in your AWS account (replication servers + low-cost EBS)
        │  Test / Cutover  (or DR: Drill / Recovery)
        ▼
Launched EC2 instances (machine converter fixes drivers/boot)
```

This is the **exact architecture** described in `04_AWS_MGN_Deep_Dive.md` and `05_AWS_Elastic_Disaster_Recovery.md`, because MGN and DRS are built on the same technology.

---

## 3. Terminology Map: CloudEndure → MGN/DRS

| CloudEndure term | MGN / DRS term |
|---|---|
| **Project** (one per target region/account) | **Region/account + service initialization** (the settings live in the AWS service in that region) |
| **Machine** | **Source server** |
| **Blueprint** (target machine settings) | **Launch settings** (EC2 launch template) |
| **Replication settings** (in the project) | **Replication Settings template** |
| **Replication server** | **Replication server** (same) |
| **Machine converter** | **Conversion server** |
| **Test mode** | **Test instances** (MGN) / **Drill** (DRS) |
| **Cutover** | **Cutover** (MGN) / **Recovery** (DRS) |
| **CloudEndure agent** | **AWS Replication Agent** |
| **CloudEndure user/API token** in the agent installer | **IAM user access key** (install time) |
| **Failback client** (CloudEndure DR) | **DRS Failback Client** |
| **Point-in-time recovery** | **Point-in-time recovery** (DRS) |

---

## 4. What Improved in MGN/DRS

| Area | CloudEndure | MGN / DRS |
|---|---|---|
| **Access control** | Separate user store and API tokens | **AWS IAM**, SSO, and CloudTrail auditing |
| **Console** | External SaaS site | Native AWS console |
| **Tagging/cost allocation** | Limited | AWS tags, Cost Explorer |
| **Orchestration** | Basic | Applications, **waves**, **post-launch actions (SSM)**, Migration Hub integration |
| **Agentless** | None | **Agentless vCenter replication** option (MGN) |
| **Regional resources** | Account/project-based | Regional AWS services with IAM-controlled roles |
| **Private connectivity** | Possible | VPC endpoints, private IP data replication |
| **Compliance** | Separate vendor | AWS service coverage |

---

## 5. Doing the CloudEndure Assignments Today

Your curriculum's Day 11–12 says:

> *Create a source machine in one region and migrate it to another region with CloudEndure migration. Create a source machine in one region and DR it to another region with CloudEndure DR.*

Do them with:

| Curriculum assignment | Do this instead | Note |
|---|---|---|
| CloudEndure **Migration**, region A → region B | **MGN**, Assignment 2 | `04_AWS_MGN_Deep_Dive.md`, section 14 |
| CloudEndure **DR**, region A → region B | **DRS**, Assignment 3 | `05_AWS_Elastic_Disaster_Recovery.md`, section 17 |

If you finish those two labs, you've covered Days 5–8 **and** Days 11–12 in practice.

---

## 6. If You See CloudEndure in an Old Project

| Situation | What to do |
|---|---|
| An old runbook says "log in to console.cloudendure.com" | The product may no longer exist. Use MGN/DRS |
| Servers still replicating via the old CloudEndure agent | Plan to **reinstall the AWS Replication Agent**. Check AWS's migration guidance for moving from CloudEndure to MGN/DRS (don't assume it's in place) |
| Documentation links are dead | Search the AWS docs for the MGN/DRS equivalent of that concept (use section 3's table) |
| A vendor says "CloudEndure" | They mean MGN (migration) or DRS (disaster recovery) |

---

## 7. Interview-Ready Summary

> "CloudEndure was a block-level replication product that AWS acquired. It became **AWS Application Migration Service** for rehost migrations and **AWS Elastic Disaster Recovery** for DR. Both use an agent on the source server, replicate over TCP 1500 to a lightweight replication server and low-cost staging volumes in AWS, then launch converted EC2 instances for tests and cutover (MGN) or drills and recovery (DRS)."

---

## 8. Key Takeaways

```
1. CloudEndure → AWS acquired it (2019) → rebuilt as MGN (migration) and DRS (disaster recovery).
2. Same architecture: agent, TCP 1500, replication server, staging EBS, conversion, launch.
3. Terms map: Blueprint → Launch settings, Machine → Source server, Project → regional service settings.
4. MGN/DRS add IAM, CloudTrail, waves, post-launch actions, and agentless (MGN).
5. Do the CloudEndure assignments with MGN (migration) and DRS (DR), because the product is retired.
6. Verify retirement dates and any migration path from the old product in AWS's official announcements.
```

**Next note:** `08_Refactoring_and_App2Container.md`
