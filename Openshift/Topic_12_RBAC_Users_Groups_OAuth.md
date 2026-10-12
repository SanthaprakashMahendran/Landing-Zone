# **Topic 12: RBAC, Users, Groups & OAuth Identity Providers ⭐ — Complete Notes**

> **Sandbox practicability:** ⚠️ Partly.
> ✅ RBAC **inside your own project** (you're project admin): roles, role bindings, service accounts, `oc auth can-i`.
> ❌ OAuth/identity-provider config, creating users and groups, cluster roles. These are admin-only.
> Your sandbox login goes through **Red Hat SSO** (an OpenID Connect provider), which makes it a good real example.

---

## **Table of Contents**
1. Introduction
2. Authentication vs Authorization
3. The OAuth Server
4. Identity Providers (IdPs)
5. Users, Identities & Groups
6. RBAC Concepts
7. Default Roles
8. Role Bindings (Giving Access)
9. Service Accounts
10. Checking Permissions
11. Project Creation & `self-provisioner`
12. The `kubeadmin` User
13. Red Hat SSO in Your Sandbox
14. ROSA: Managing Identity with the `rosa` CLI
15. Troubleshooting
16. Real-World Examples
17. Best Practices
18. Hands-on Lab (Sandbox)
19. Key Takeaways

---

## **1. Introduction**

### **Quick Definition**

```
Authentication (AuthN):  "Who are you?"        →  OAuth server + identity provider
Authorization  (AuthZ):  "What may you do?"    →  RBAC (roles + bindings)
```

Kubernetes has RBAC but **no built-in user management**, since you bring certificates or OIDC. OpenShift ships a **built-in OAuth server** and a **User/Group API**, so login works out of the box.

---

## **2. Authentication vs Authorization**

```
 ┌────────┐  1. login   ┌──────────────┐  2. who?   ┌──────────────────┐
 │  User  │────────────▶│ OAuth Server │───────────▶│ Identity Provider│
 └────────┘             └──────┬───────┘◀───────────└──────────────────┘
      ▲   3. access token      │
      └────────────────────────┘
      │
      │ 4. API call + token
      ▼
 ┌───────────┐  5. authenticated as "santha"  ┌──────┐
 │ API Server│───────────────────────────────▶│ RBAC │  6. allowed? yes/no
 └───────────┘                                └──────┘
```

| Step | Component |
|---|---|
| Login | OAuth server (`openshift-authentication`) |
| Identity check | Identity Provider (Red Hat SSO, LDAP, GitHub...) |
| Token | `sha256~...` OAuth access token (default lifetime 24h) |
| Permission check | RBAC on every API call |

---

## **3. The OAuth Server**

- Runs as the **authentication operator** in `openshift-authentication` (managed by the cluster).
- Issues **OAuth access tokens**, which are what `oc login` and the console use.
- Configured through one cluster-scoped object: **`oauth/cluster`**.

```bash
oc get oauth cluster -o yaml          # admin
oc get oauthaccesstokens              # admin (all tokens)
oc whoami -t                          # your own token
```

### **Token settings**

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  tokenConfig:
    accessTokenMaxAgeSeconds: 86400    # 24h
```

---

## **4. Identity Providers (IdPs)**

An IdP is the system that **verifies who you are**. A cluster can have several at once.

| IdP | Source of users | Typical use |
|---|---|---|
| **HTPasswd** | A password file stored in a Secret | Labs, break-glass admins |
| **OpenID Connect (OIDC)** | Keycloak, **Red Hat SSO**, Okta, Azure AD, Google | Enterprise SSO (**what your sandbox uses**) |
| **LDAP / Active Directory** | Corporate directory | Large on-prem companies |
| **GitHub / GitLab / Google** | Public identity | Developer clusters |
| **Keystone** | OpenStack | OpenStack clusters |
| **Request header** | Front-end proxy (SSO gateways) | Special integrations |

### **HTPasswd example**

```bash
htpasswd -c -B -b users.htpasswd alice 'Passw0rd!'
htpasswd -B -b users.htpasswd bob 'Passw0rd!'
oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config
```

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
    - name: local-users
      mappingMethod: claim
      type: HTPasswd
      htpasswd:
        fileData:
          name: htpass-secret
```

### **OIDC (Red Hat SSO / Keycloak) example**

```yaml
identityProviders:
  - name: redhat-sso
    mappingMethod: claim
    type: OpenID
    openID:
      clientID: openshift
      clientSecret:
        name: sso-client-secret         # Secret in openshift-config
      issuer: https://sso.redhat.com/auth/realms/redhat-external
      claims:
        preferredUsername: [preferred_username]
        name: [name]
        email: [email]
```

### **Mapping methods**

| `mappingMethod` | Behaviour |
|---|---|
| `claim` (default) | Fails if a user with the same name exists from a different IdP |
| `lookup` | Users and identities must be pre-created manually |
| `add` | Adds the new identity to an existing user |

> ❌ **Sandbox:** you can't edit `oauth/cluster`. Know the shape of this object.

---

## **5. Users, Identities & Groups**

OpenShift has its own API objects (`user.openshift.io/v1`):

| Object | Meaning | Example |
|---|---|---|
| **Identity** | One login record from an IdP | `redhat-sso:santha` |
| **User** | The OpenShift account (created on first login) | `santha` |
| **Group** | A set of users, used for RBAC | `platform-team` |

```
Identity (redhat-sso:santha) ──maps to──▶ User (santha) ──member of──▶ Group (developers)
```

### **Commands**

```bash
oc whoami
oc get user                           # admin
oc get identity                       # admin
oc get groups                         # admin (or your groups)

# admin
oc adm groups new developers alice bob
oc adm groups add-users developers carol
oc adm groups remove-users developers bob
```

### **Group sync**
For LDAP, `oc adm groups sync` imports groups from the directory. For OIDC, groups are usually managed in the OpenShift group API or via the **group sync operator**.

### **Built-in virtual groups**

| Group | Members |
|---|---|
| `system:authenticated` | Everyone logged in |
| `system:unauthenticated` | Anonymous |
| `system:serviceaccounts` | All service accounts |
| `system:serviceaccounts:<project>` | All SAs in that project |

---

## **6. RBAC Concepts**

RBAC answers: **Which subject may perform which verb on which resource, and where?**

```
Subject  (User / Group / ServiceAccount)
   │  is bound by
   ▼
RoleBinding / ClusterRoleBinding
   │  to
   ▼
Role / ClusterRole   (rules: verbs × resources)
```

| Object | Scope | Meaning |
|---|---|---|
| **Role** | One namespace | A set of permissions |
| **ClusterRole** | Cluster | A set of permissions, reusable anywhere |
| **RoleBinding** | One namespace | Grants a Role **or ClusterRole** in that namespace |
| **ClusterRoleBinding** | Cluster | Grants a ClusterRole everywhere |

### **A rule**

```yaml
rules:
  - apiGroups: [""]                 # core API
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "update", "patch"]
```

### **Key trick**

A **ClusterRole bound with a RoleBinding** gives those permissions **only in one project**. That's how the built-in `admin`, `edit` and `view` roles work. (Same Kubernetes RBAC you already know. OpenShift adds the roles and `oc` helpers.)

---

## **7. Default Roles**

### **Roles you give to people in a project**

| Role | Can do |
|---|---|
| **admin** | Everything in the project, including RBAC. Cannot change quotas. |
| **edit** | Create and change most objects (deployments, routes, builds). **Cannot manage RBAC.** |
| **view** | Read-only |
| **basic-user** | See basic project info |
| **system:image-puller / -pusher** | Image access (Topic 11) |

### **Cluster-level roles**

| Role | Can do |
|---|---|
| **cluster-admin** | Everything |
| **cluster-reader** | Read everything, change nothing |
| **self-provisioner** | Create new projects |
| **basic-user** | Cluster default for authenticated users |

```bash
oc get clusterrole | grep -E "^(admin|edit|view|cluster-admin|cluster-reader|self-provisioner)\b"
oc describe clusterrole edit
```

### **Quick mapping**

```
Developer in own project   →  edit  (or admin if they manage access)
Team lead                  →  admin
Auditor / QA               →  view
Platform engineer          →  cluster-reader or cluster-admin
CI service account         →  edit (or a custom narrow role)
```

---

## **8. Role Bindings (Giving Access)**

### **Project-level**

```bash
# a user
oc policy add-role-to-user edit alice -n santha-dev
# a group
oc policy add-role-to-group view qa-team -n santha-dev
# a service account (-z)
oc policy add-role-to-user edit -z ci-bot -n santha-dev
# remove
oc policy remove-role-from-user edit alice -n santha-dev
```

### **Cluster-level** (admin ❌)

```bash
oc adm policy add-cluster-role-to-user cluster-reader alice
oc adm policy add-cluster-role-to-group cluster-admin platform-admins
```

### **As YAML (preferred, versioned in Git)**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: alice-edit
  namespace: santha-dev
subjects:
  - kind: User
    name: alice
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

### **A custom role**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: santha-dev
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
```

```bash
oc create rolebinding bob-pod-reader --role=pod-reader --user=bob -n santha-dev
```

### **Inspect**

```bash
oc get rolebindings -n santha-dev
oc describe rolebinding admin -n santha-dev
oc get rolebinding -n santha-dev -o wide
```

---

## **9. Service Accounts**

A **ServiceAccount (SA)** is an identity for **pods and automation**, not for humans.

```
system:serviceaccount:<project>:<name>
```

Every project gets three by default: `default`, `builder`, `deployer`.

```bash
oc create sa ci-bot
oc policy add-role-to-user edit -z ci-bot
oc create token ci-bot --duration=1h        # short-lived token
oc get sa
```

| SA | Used by |
|---|---|
| `default` | Pods that don't specify one |
| `builder` | Build pods (pushes images) |
| `deployer` | Legacy DeploymentConfig |
| Custom (`ci-bot`) | Pipelines, GitOps and scripts |

### **Pod → SA**

```yaml
spec:
  serviceAccountName: ci-bot
```

### **SA and SCC**
Pod security (Topic 6) is also tied to the SA. Giving an SA the `anyuid` SCC lets its pods run as root. This is a **security-sensitive** action.

```bash
oc adm policy add-scc-to-user anyuid -z ci-bot       # admin ❌ in sandbox
```

---

## **10. Checking Permissions**

```bash
# Can I do this?
oc auth can-i create deployments -n santha-dev
oc auth can-i get nodes
oc auth can-i '*' '*' -n santha-dev           # am I project admin?

# What can I do?
oc auth can-i --list -n santha-dev

# Can SOMEONE ELSE do this? (needs impersonation permission)
oc auth can-i delete pods --as=alice -n santha-dev
oc auth can-i get secrets --as=system:serviceaccount:santha-dev:ci-bot -n santha-dev

# Who can do this?
oc policy who-can get secrets -n santha-dev
oc policy who-can create deployments -n santha-dev
```

`oc policy who-can` is the audit command. Use it before you give a role away.

---

## **11. Project Creation & `self-provisioner`**

By default **any authenticated user can create projects** because of this binding:

```bash
oc get clusterrolebinding self-provisioners -o yaml
# subjects: Group system:authenticated:oauth
```

### **Lock it down (admin ❌)**

```bash
oc patch clusterrolebinding.rbac self-provisioners \
  -p '{"subjects": null}'
oc adm policy add-cluster-role-to-group self-provisioner platform-team
```

### **Project request template**
Admins can define a **project template** that automatically adds quotas, LimitRanges, NetworkPolicies and RoleBindings to every new project (Topic 13).

---

## **12. The `kubeadmin` User**

On a self-managed install the installer creates a temporary **`kubeadmin`** user (password in `auth/kubeadmin-password`).

- It's a **break-glass** account, not for daily use.
- **Best practice:** configure a real IdP, give a real user `cluster-admin`, then **delete `kubeadmin`**:

```bash
oc delete secret kubeadmin -n kube-system
```

On **ROSA**, there's no `kubeadmin`. You create an IdP, or a temporary `cluster-admin` with `rosa create admin`.

---

## **13. Red Hat SSO in Your Sandbox**

When you open the console you're redirected to **Red Hat SSO**, log in, and land back as `santha`.

```
Browser ─▶ OpenShift OAuth ─▶ (redirect) ─▶ Red Hat SSO (OIDC)
                                                  │ login
Browser ◀─ OpenShift OAuth ◀─ code/token ────────┘
```

### **What you can observe from inside**

```bash
oc whoami                      # santha
oc whoami --show-token         # OAuth token issued after the SSO login
oc get user ~                  # your User object (the "~" = current user)
oc auth can-i --list -n santha-dev
oc get rolebinding -n santha-dev -o wide     # you should be 'admin' here
```

### **Why this matters**
- Your **identity is external**. Passwords never touch OpenShift.
- Authorization stays **inside OpenShift** (RBAC). SSO proves who you are, and RBAC decides what you can do.
- If SSO tokens expire, `oc login --web` again.

---

## **14. ROSA: Managing Identity with the `rosa` CLI**

On ROSA you don't edit `oauth/cluster` directly. You use:

```bash
rosa create idp --cluster=demo --type=github --client-id=... --client-secret=...
rosa create idp --cluster=demo --type=openid ...
rosa create user --cluster=demo --cluster-admins=alice     # grant cluster-admin
rosa list idps --cluster=demo
rosa list users --cluster=demo
```

Red Hat SRE also needs access to ROSA for operations, using separate, audited roles (Topic 24).

> ❌ Reading only in the sandbox.

---

## **15. Troubleshooting**

| Symptom | Check | Cause / fix |
|---|---|---|
| `Forbidden: User "x" cannot list resource ...` | `oc auth can-i <verb> <resource> -n <ns>` | No RoleBinding for the user in that namespace |
| Login loop or `invalid_request` | OAuth server logs (admin) | IdP misconfigured (wrong redirect URI or secret) |
| `Unauthorized` | `oc whoami` | Token expired, so log in again |
| User logs in but sees nothing | `oc get projects` | Authenticated, but no roles yet |
| `error: You may not request a new project via this API` | `self-provisioner` | Project creation was restricted |
| Pod gets 403 calling the API | SA bindings | Pod's SA has no role. Bind a role to that SA |
| `serviceaccount ... cannot be used with SCC` | `oc describe pod` | SA lacks the SCC (Topic 6) |
| `edit` user can't create RoleBindings | Role is too weak | `edit` can't manage RBAC. Needs `admin` |

### **Debug order**

```bash
oc whoami
oc auth can-i --list -n <ns>
oc policy who-can <verb> <resource> -n <ns>
oc get rolebinding,clusterrolebinding -A -o wide | grep <user>
```

---

## **16. Real-World Examples**

### **Example 1: Onboard a team**

```bash
oc new-project team-a
oc policy add-role-to-group edit team-a-devs -n team-a
oc policy add-role-to-group view team-a-qa -n team-a
oc policy add-role-to-user admin lead-alice -n team-a
```

### **Example 2: CI bot that can only deploy**

```bash
oc create sa deployer-bot -n santha-dev
oc create role deploy-only -n santha-dev \
   --verb=get,list,patch,update --resource=deployments.apps
oc create rolebinding deployer-bot-deploy -n santha-dev \
   --role=deploy-only --serviceaccount=santha-dev:deployer-bot
oc create token deployer-bot -n santha-dev --duration=1h
```

Test it:
```bash
oc auth can-i patch deployments -n santha-dev --as=system:serviceaccount:santha-dev:deployer-bot   # yes
oc auth can-i delete pods         -n santha-dev --as=system:serviceaccount:santha-dev:deployer-bot   # no
```

### **Example 3: Audit who can read Secrets**

```bash
oc policy who-can get secrets -n santha-dev
```

### **Example 4: Read-only access across the cluster for an auditor** (admin ❌)

```bash
oc adm policy add-cluster-role-to-user cluster-reader auditor1
```

---

## **17. Best Practices**

- ✅ Use an **external IdP (SSO)**, never shared accounts
- ✅ Bind roles to **groups**, not individual users
- ✅ **Least privilege**: `view` → `edit` → `admin`, and avoid `cluster-admin`
- ✅ Use **one service account per app or pipeline**, with short-lived tokens
- ✅ Keep RoleBindings in **Git** (GitOps)
- ✅ Remove **`kubeadmin`** once real admins exist
- ✅ Restrict **`self-provisioner`** and use a **project template** with quotas
- ✅ Audit with `oc policy who-can`
- ❌ Don't give `anyuid` or `privileged` SCC to broad groups
- ❌ Don't give `system:authenticated` powerful roles

---

## **18. Hands-on Lab (Sandbox)**

Legend: ✅ run it · ⚠️ may be restricted · ❌ admin only

| # | Task | Status |
|---|---|---|
| 1 | `oc whoami`, `oc get user ~`, `oc get project` | ✅ |
| 2 | `oc get rolebinding -n santha-dev -o wide` and find your own `admin` binding | ✅ |
| 3 | `oc describe clusterrole admin` and `oc describe clusterrole edit`, then compare them | ✅ |
| 4 | `oc auth can-i --list -n santha-dev` | ✅ |
| 5 | Create SA `ci-bot`, create a Role `pod-reader`, and bind it to the SA | ✅ |
| 6 | Test with `oc auth can-i get pods --as=system:serviceaccount:santha-dev:ci-bot` (yes) and `... delete pods ...` (no) | ✅ (impersonation may be limited ⚠️) |
| 7 | Create a token with `oc create token ci-bot`, log in as the SA in another terminal, and try to create something | ✅ |
| 8 | `oc policy who-can get secrets -n santha-dev` | ✅ |
| 9 | Run a pod with `serviceAccountName: ci-bot` and call the API from inside with its token | ✅ |
| 10 | `oc get oauth cluster -o yaml` | ❌ admin |
| 11 | Add an HTPasswd IdP and create groups | ❌ admin |

### **Expected learning outcomes**
- You can explain the OAuth login flow and what "SSO + RBAC" means.
- You can grant least-privilege access to people and service accounts.
- You can audit who can do what.

---

## **19. Key Takeaways**

1. **AuthN** = OAuth server + identity provider, and **AuthZ** = RBAC.
2. **Identity providers** (OIDC/Red Hat SSO, LDAP, GitHub, HTPasswd) are plugged into `oauth/cluster`.
3. OpenShift **User, Identity and Group** are API objects created on first login.
4. Default roles: **admin > edit > view**, plus cluster-level `cluster-admin`, `cluster-reader` and `self-provisioner`.
5. **ClusterRole + RoleBinding = permissions in one project only.**
6. **Service accounts** are for pods and automation, and each one needs its own least-privilege role.
7. **`oc auth can-i`** and **`oc policy who-can`** are your debugging and audit commands.
8. Delete **`kubeadmin`** on self-managed clusters and use real IdP users.

### **Common Commands**

```bash
oc whoami [-t] [--show-server]
oc policy add-role-to-user|add-role-to-group <role> <name> -n <ns>
oc policy remove-role-from-user <role> <name> -n <ns>
oc create sa <name> && oc create token <name>
oc auth can-i <verb> <resource> [--as=<user>] -n <ns>
oc auth can-i --list -n <ns>
oc policy who-can <verb> <resource> -n <ns>
oc adm groups new <group> <users...>
```

---

**✅ Topic 12 Complete**

When ready, reply:
- ✅ **"Ready for Topic 13"** → Move to: ResourceQuota, LimitRange & ClusterResourceQuota
- ❓ **"Need clarification on [section]"**
