# CloudFront + WAF on ALB: Complete Configuration Guide

## Architecture Overview

```
Users Worldwide
    ↓
www.freshdesk.com, hey.freshdesk.com, tee.freshdesk.com
    ↓
CloudFront Distribution (Global CDN)
├─ Caches content globally
├─ Adds custom header: X-Origin-Verify
└─ Forwards requests to ALB
    ↓
ALB (from EKS Ingress)
    ↓
WAF Web ACL (Security Layer)
├─ Checks: X-Origin-Verify header
├─ Blocks if missing or wrong value
└─ Protects pods from unauthorized access
    ↓
EKS Pods (Your Application)
├─ Pod 1
├─ Pod 2
└─ Pod 3
```

---

## Prerequisite: SSL Certificate

### Request Wildcard Certificate in AWS ACM

**Covers all subdomains with ONE certificate:**

```
AWS Console → Certificate Manager → Request certificate

Fill in:

Domain names to protect:
├─ *.freshdesk.com (wildcard - covers all subdomains)
├─ freshdesk.com (apex domain)
│  └─ Optional but recommended
├─ www.freshdesk.com (explicit - not needed with wildcard)
├─ hey.freshdesk.com (explicit - not needed with wildcard)
└─ tee.freshdesk.com (explicit - not needed with wildcard)

Validation method:
└─ Choose: "DNS validation"

Click: "Request certificate"
```

### Validate Certificate (DNS)

```
1. AWS shows CNAME records to add

2. Go to your domain registrar:
   ├─ GoDaddy
   ├─ Route53
   ├─ Namecheap
   └─ Or wherever you manage DNS

3. Add CNAME records for validation:
   ├─ Name: _xxxxx.freshdesk.com (AWS provides exact value)
   ├─ Value: _xxxxx.acm-validations.aws. (AWS provides exact value)
   └─ TTL: 300

4. Wait: 5-10 minutes

5. Status: "Issued" ✅
   └─ Certificate ready to use!
```

---

# PART 1: CloudFront Configuration

## Step 1: Create CloudFront Distribution

### 1.1 Open CloudFront Console

```
AWS Console → CloudFront → Distributions
Click: "Create distribution"
Choose: "Web"
Click: "Create"
```

### 1.2 Configure Origin (ALB)

```
ORIGIN DETAILS:

1. Origin domain:
   ├─ Click dropdown
   ├─ Select your ALB from list
   └─ Example: alb-123456.us-east-1.elb.amazonaws.com

2. Origin name:
   ├─ Auto-filled (or enter: "EKS-ALB")
   └─ Just a label for reference

3. Protocol policy:
   ├─ Choose: "HTTPS only"
   └─ (Recommended for security)

4. HTTP port: 80 (default OK)

5. HTTPS port: 443 (default OK)

6. Minimum origin SSL protocol:
   ├─ Choose: "TLSv1.2"
   └─ (Security best practice)

7. Custom headers - ADD CUSTOM HEADER:
   ├─ Click: "Add header"
   ├─ Header name: "X-Origin-Verify"
   │  (Exact name - case sensitive!)
   ├─ Header value: "K9mL2pQ5xR8vZ1bC4dF7gH0j"
   │  (Use strong random string)
   │  └─ Generate: https://www.random.org/strings/
   │  └─ Or: openssl rand -base64 20
   └─ CloudFront adds this header to EVERY request to ALB

WHAT THIS HEADER DOES:
├─ Every request from CloudFront → ALB includes this header
├─ WAF checks: "Does request have this header?"
├─ If YES: Allow ✓
├─ If NO: Block ❌
```

### 1.3 Configure Default Cache Behavior

```
DEFAULT CACHE BEHAVIOR SETTINGS:

1. Viewer protocol policy:
   ├─ Choose: "Redirect HTTP to HTTPS"
   └─ (Force all users to HTTPS)

2. Allowed HTTP methods:
   ├─ Check: GET, HEAD
   ├─ Uncheck: POST, PUT, DELETE, PATCH
   └─ (Cache only GET/HEAD requests)

3. Compress objects automatically:
   ├─ Choose: Yes
   └─ (Gzip compression - reduces bandwidth)

4. Cache key and origin requests:
   ├─ Choose: "Cache policy and origin request policy"

5. Cache policy:
   ├─ Choose: "CachingOptimized"
   │  ├─ TTL: 24 hours
   │  ├─ Good for: Static content, images, CSS, JS
   │  └─ Best for most websites
   │
   ├─ Or: "CachingDisabled" (if you want no caching)
   │
   └─ Or: Custom policy (for advanced)

6. Origin request policy:
   ├─ Choose: "AllViewerAndCloudFrontHeaders"
   └─ (Forwards all headers to origin)

7. Response headers policy:
   ├─ Choose: "SecurityHeadersPolicy"
   └─ Adds security headers:
      ├─ Strict-Transport-Security
      ├─ X-Content-Type-Options: nosniff
      ├─ X-Frame-Options: DENY
      └─ X-XSS-Protection
```

### 1.4 Configure Distribution Settings

```
DISTRIBUTION SETTINGS:

1. Price class:
   ├─ Choose: "Use all edge locations"
   │  ├─ Global coverage
   │  ├─ All CloudFront edge locations
   │  └─ Recommended for worldwide users
   │
   ├─ Or: "Use only North America and Europe"
   │  └─ 50% cheaper, regional coverage
   │
   └─ Or: "Use North America, Europe, Asia, etc."
       └─ Balance of price and coverage

2. Alternate domain names (CNAME):
   ├─ Add: "www.freshdesk.com"
   ├─ Add: "hey.freshdesk.com"
   ├─ Add: "tee.freshdesk.com"
   ├─ Add: "freshdesk.com" (apex domain)
   └─ Add any other subdomain you want
   
   THESE ARE YOUR CUSTOM DOMAINS:
   ├─ Users access these domains
   ├─ They resolve to CloudFront
   └─ Can have multiple domains on one distribution

3. SSL certificate:
   ├─ Choose: "Use certificate from ACM"
   ├─ Select: "*.freshdesk.com" (the wildcard certificate)
   │  └─ This covers ALL subdomains
   └─ Certificate must cover domains listed above

4. Description:
   ├─ Enter: "CloudFront for EKS website - freshdesk.com"
   └─ For reference only

5. Enable Web ACL:
   ├─ Choose: Yes
   ├─ WAF Web ACL: (Will fill this after creating WAF)
   │  └─ Can update later
   └─ This is where WAF connects to CloudFront

6. Click: "Create distribution"

STATUS: "Deploying"
├─ Time: 5-15 minutes to deploy globally
└─ Can proceed to create WAF while deploying
```

---

## Step 2: Get CloudFront Domain & Configure DNS

### 2.1 CloudFront Domain Created

```
After distribution created:

AWS Console → CloudFront → Distributions

Your distribution shows:
├─ Domain Name: d123xyz.cloudfront.net
├─ Status: Enabled
└─ Copy this domain name
```

### 2.2 Add CNAME Records in DNS

```
Go to your domain registrar:
├─ Route53 (AWS)
├─ GoDaddy
├─ Namecheap
└─ Other registrar

Add CNAME records for each subdomain:

Record 1 - www subdomain:
├─ Name: www
├─ Type: CNAME
├─ Value: d123xyz.cloudfront.net
└─ TTL: 300

Record 2 - hey subdomain:
├─ Name: hey
├─ Type: CNAME
├─ Value: d123xyz.cloudfront.net (SAME CloudFront domain!)
└─ TTL: 300

Record 3 - tee subdomain:
├─ Name: tee
├─ Type: CNAME
├─ Value: d123xyz.cloudfront.net (SAME!)
└─ TTL: 300

Apex domain (optional but recommended):
├─ Name: (leave blank or @ symbol)
├─ Type: ALIAS (if supported) or A record
├─ Value: d123xyz.cloudfront.net
└─ Some registrars require ALIAS for apex

Result:
├─ www.freshdesk.com → CloudFront ✓
├─ hey.freshdesk.com → CloudFront ✓
├─ tee.freshdesk.com → CloudFront ✓
└─ All traffic routed to same CloudFront distribution!
```

### 2.3 Verify DNS Resolution

```bash
# Check DNS resolution
nslookup www.freshdesk.com

Expected output:
Name: www.freshdesk.com
Address: (CloudFront IP)
Alias: d123xyz.cloudfront.net

Or use dig:
dig www.freshdesk.com +short
└─ Should resolve to CloudFront IP
```

---

# PART 2: WAF Configuration

## Step 1: Create WAF Web ACL for ALB

### 1.1 Open WAF Console

```
AWS Console → WAF & Shield → Web ACLs

IMPORTANT:
├─ Region: Must be SAME as your ALB
├─ If ALB in us-east-1 → WAF in us-east-1
└─ CloudFront WAF is in us-east-1 (special)

Click: "Create web ACL"
```

### 1.2 Create Web ACL

```
Fill in details:

1. Name:
   └─ "alb-waf"

2. Description:
   └─ "WAF for ALB - checks CloudFront custom header"

3. Cloud Watch metrics:
   ├─ Choose: Enable
   └─ Logs WAF activity for monitoring

4. Resource type:
   ├─ Choose: "Application Load Balancer"
   │  (IMPORTANT: NOT CloudFront!)
   │  (This WAF protects ALB specifically)
   └─ CloudFront gets its own WAF if needed

5. Associated AWS resources:
   ├─ Leave blank for now
   └─ Associate AFTER WAF is created

Click: "Next"
```

### 1.3 Add Custom Rule - Check Header

```
1. Click: "Add rules" → "Add my own rules and rule groups"
2. Choose: "Rule builder"

CUSTOM RULE CONFIGURATION:

Rule name:
└─ "check-cloudfront-header"

If statement:
├─ Click: "Add statement"
├─ Statement type: "HTTP request header"
│  (We're checking for a specific header)
├─ Header name: "X-Origin-Verify"
│  (MUST match exactly what CloudFront sends!)
├─ Match type: "Exactly"
│  (Must match exactly, no partial matches)
├─ Search string: "K9mL2pQ5xR8vZ1bC4dF7gH0j"
│  (MUST be same value CloudFront adds!)
│  (Case sensitive!)
└─ Text transformation: "None"
   (Don't transform the header)

Action:
├─ Choose: "Allow"
└─ (If header matches rule → allow traffic through)

Click: "Add rule"
```

### 1.4 Set Default Action

```
After adding rule:

Default action:
├─ Choose: "Block"
└─ (Block by default, only allow if rule matches)

WHAT THIS MEANS:

Request with correct header?
├─ X-Origin-Verify: K9mL2pQ5xR8vZ1bC4dF7gH0j
├─ Rule matches → ALLOW ✓
└─ Traffic passes to pods

Request with NO header?
├─ (Direct ALB access, no CloudFront)
├─ Rule doesn't match → DEFAULT ACTION
├─ Default action: BLOCK ❌
└─ Returns 403 Forbidden

Request with WRONG value?
├─ X-Origin-Verify: wrong-value
├─ Rule doesn't match → DEFAULT ACTION
├─ Default action: BLOCK ❌
└─ Returns 403 Forbidden

Result:
├─ Only CloudFront traffic allowed
├─ Direct ALB access blocked
└─ Your EKS pods protected!

Click: "Next"
```

### 1.5 Review & Create WAF

```
Review all settings:

Rule name: check-cloudfront-header
Rule type: HTTP request header
Header name: X-Origin-Verify
Match type: Exactly
Value: K9mL2pQ5xR8vZ1bC4dF7gH0j
Action if matches: Allow
Default action: Block

Click: "Create web ACL"

Result:
└─ WAF Web ACL created! ✅
```

---

## Step 2: Associate WAF with ALB

### 2.1 Find Your ALB

```
AWS Console → EC2 → Load Balancers

Find your ALB:
├─ Created from EKS Ingress
├─ Name: alb-xxxxx (auto-generated)
├─ Region: (verify same region as WAF)
└─ Click on it
```

### 2.2 Add WAF to ALB

```
In ALB Details page:

Look for section:
├─ "Associated resources" OR
├─ "Integrated services" OR
├─ "Web ACL"

Click: "Edit" or "Add WAF"

Choose:
├─ Web ACL: "alb-waf" (the one you created)
└─ Click: "Save" or "Apply"

Status: "Updating" (~2 minutes)

Result:
└─ WAF now protecting ALB! ✅
```

---

## Step 3: (Optional) Update CloudFront with WAF

```
For extra protection, you can add WAF to CloudFront too:

AWS Console → CloudFront → Distributions

Select your distribution → Edit

Look for: "Web ACL"

Choose: Your WAF Web ACL

Click: "Save"

Note: This is OPTIONAL
├─ WAF on ALB already protects pods
├─ WAF on CloudFront adds edge protection
└─ Both together = maximum security

Most setups: WAF on ALB is enough
Advanced setups: WAF on both layers
```

---

# COMPLETE DATA FLOW

## User Accesses www.freshdesk.com

```
STEP-BY-STEP FLOW:

Step 1: User makes request
├─ Browser: GET https://www.freshdesk.com/
└─ User's location: Tokyo

Step 2: DNS Resolution
├─ www.freshdesk.com resolves to CloudFront
├─ Request goes to nearest CloudFront edge
└─ Edge location: Tokyo

Step 3: CloudFront Receives Request
├─ Checks cache: "Do I have this content?"
├─ First time: NO cache hit
├─ Adds custom header: X-Origin-Verify: K9mL2pQ5xR8vZ1bC4dF7gH0j
└─ Forwards request to ALB

Step 4: Request Reaches ALB
├─ ALB has WAF attached
├─ Request includes header from CloudFront
└─ WAF intercepts BEFORE routing to pods

Step 5: WAF Checks Request
├─ Question 1: "Has X-Origin-Verify header?"
├─ Answer: YES ✓
├─ Question 2: "Value = K9mL2pQ5xR8vZ1bC4dF7gH0j?"
├─ Answer: YES ✓
├─ Decision: ALLOW
└─ Forwards to pods

Step 6: ALB Routes to Pods
├─ Ingress routing based on hostname
├─ Routes to appropriate pod
└─ Pod processes request

Step 7: Pod Executes & Returns Response
├─ Pod runs your application
├─ Returns HTML, JSON, or other content
├─ Response includes headers (e.g., Cache-Control)
└─ Response travels back

Step 8: Response Returns to CloudFront
├─ Response comes back to ALB
├─ ALB sends to CloudFront
└─ CloudFront reads cache headers

Step 9: CloudFront Caches Content
├─ If Cache-Control: max-age=3600
├─ CloudFront stores in Tokyo edge
├─ TTL: 1 hour
├─ Next request from Tokyo: Instant hit! ⚡
└─ Pod never contacted again until cache expires

Step 10: Response Sent to User
├─ CloudFront returns to browser
├─ Browser displays website
└─ User sees content in ~10ms from Tokyo edge! ✓

RESULT:
✅ Website loads fast
✅ Content cached globally
✅ Pods protected by WAF
✅ Direct access impossible
```

---

## Attacker Tries Direct ALB Access

```
ATTACK SCENARIO:

Step 1: Attacker tries direct access
├─ curl http://alb-xxxxx.us-east-1.elb.amazonaws.com/
└─ Direct to ALB (bypasses CloudFront)

Step 2: Request Reaches ALB
├─ ALB has WAF attached
├─ Request has NO custom header
│  (CloudFront wasn't involved)
└─ WAF intercepts

Step 3: WAF Checks Request
├─ Question: "Has X-Origin-Verify header?"
├─ Answer: NO ❌
├─ Rule doesn't match
├─ Default action: BLOCK
└─ Returns 403 Forbidden

Step 4: Request BLOCKED
├─ Never reaches pods ✓
├─ Pod resources protected ✓
├─ Attack prevented ✓
└─ Pod CPU not wasted

RESULT:
❌ Attacker blocked
✅ Your infrastructure protected
```

---

# TESTING & VERIFICATION

## Test 1: Via CloudFront (Should Work)

```bash
curl -I https://www.freshdesk.com/

Expected response:
HTTP/2 200
Content-Type: text/html
X-Cache: Miss from cloudfront (first time)
X-Cache-Key: (CloudFront cache key)
Via: cloudfront

Status: ✅ SUCCESS
```

## Test 2: Direct ALB (Should Fail)

```bash
# Get ALB address
kubectl get ingress myapp-ingress
# Note: alb-xxxxx.us-east-1.elb.amazonaws.com

# Try direct access
curl -I http://alb-xxxxx.us-east-1.elb.amazonaws.com/

Expected response:
HTTP/1.1 403 Forbidden
Content-Type: text/html

Status: ✅ BLOCKED (correct!)
```

## Test 3: Monitor WAF Activity

```
AWS Console → WAF & Shield → Web ACLs

Click: "alb-waf" → "Requests" tab

You'll see:
├─ Allowed requests
│  ├─ Source: CloudFront edges (52.84.x.x, 52.85.x.x, etc.)
│  ├─ Header: X-Origin-Verify present
│  └─ Action: ALLOWED
│
└─ Blocked requests
   ├─ Source: Various IPs (attackers)
   ├─ Header: X-Origin-Verify missing
   └─ Action: BLOCKED
```

## Test 4: Check Cache Headers

```
In browser:
1. Open website: https://www.freshdesk.com/
2. Open Developer Tools (F12)
3. Go to Network tab
4. Refresh page
5. Click any resource
6. Look at Response Headers:
   ├─ Via: cloudfront ✓
   ├─ X-Cache: (Hit/Miss)
   ├─ Cache-Control: max-age=3600
   └─ Other CloudFront headers
```

---

# MONITORING & LOGS

## CloudFront Logs

```
AWS Console → CloudFront → Distributions

Select distribution → Details

Under "Logs":
├─ Standard logging: Logs to S3
├─ Real-time logs: Stream to Kinesis
└─ Enable for troubleshooting
```

## WAF Logs

```
AWS Console → WAF & Shield → Web ACLs

Click "alb-waf" → "Requests"

See:
├─ Timestamp
├─ Source IP
├─ Request path
├─ Headers received
├─ Rule matched
└─ Action taken

Or in CloudWatch:
├─ CloudWatch → Logs
├─ Log group: /aws/waf/alb-waf
└─ Detailed logs of every request
```

---

# COMPLETE CONFIGURATION CHECKLIST

```
✅ SSL Certificate
   ├─ Requested: *.freshdesk.com
   ├─ Added: freshdesk.com
   ├─ Validated: DNS
   └─ Status: Issued

✅ CloudFront Distribution
   ├─ Created: Yes
   ├─ Origin: ALB
   ├─ Custom header: X-Origin-Verify: K9mL2pQ5xR8vZ1bC4dF7gH0j
   ├─ Alternate domains: www, hey, tee, freshdesk.com
   ├─ Certificate: *.freshdesk.com
   └─ Status: Enabled

✅ DNS Records
   ├─ www.freshdesk.com: CNAME to CloudFront
   ├─ hey.freshdesk.com: CNAME to CloudFront
   ├─ tee.freshdesk.com: CNAME to CloudFront
   ├─ freshdesk.com: ALIAS/A to CloudFront
   └─ Propagated: ~5-30 minutes

✅ WAF Web ACL
   ├─ Created: Yes
   ├─ Rule: check-cloudfront-header
   ├─ Checks: X-Origin-Verify header
   ├─ Value: K9mL2pQ5xR8vZ1bC4dF7gH0j
   ├─ Default action: Block
   └─ Status: Active

✅ WAF Associated with ALB
   ├─ ALB: alb-xxxxx...
   ├─ WAF: alb-waf
   ├─ Status: Active
   └─ Protection: Enabled

✅ Testing
   ├─ CloudFront access: ✓ Works
   ├─ Direct ALB access: ✓ Blocked
   ├─ WAF logging: ✓ Active
   └─ Cache working: ✓ Verified

✅ Security
   ├─ HTTPS: Enabled
   ├─ Only CloudFront to ALB: Enforced
   ├─ Direct access: Blocked
   └─ EKS pods: Protected
```

---

# ARCHITECTURE SUMMARY

```
www.freshdesk.com / hey.freshdesk.com / tee.freshdesk.com
    │
    ├─ DNS: CNAME to CloudFront
    │
    ↓
CloudFront Distribution (d123xyz.cloudfront.net)
    ├─ Caches content globally
    ├─ Adds header: X-Origin-Verify
    ├─ 600+ edge locations
    ├─ Certificate: *.freshdesk.com
    └─ Covers all subdomains
    │
    ↓ (with custom header)
ALB (from EKS Ingress)
    │
    ├─ WAF Web ACL
    │  ├─ Checks: X-Origin-Verify header
    │  ├─ Allows: If header present & correct
    │  └─ Blocks: If missing or wrong
    │
    ↓ (only if WAF allows)
EKS Pods
    ├─ Pod 1 (app container)
    ├─ Pod 2 (app container)
    └─ Pod 3 (app container)
```

---

## Cost Analysis

```
Monthly costs:

CloudFront:
├─ Data transfer: $0.085/GB (varies by region)
├─ HTTP requests: $0.0075 per 10,000
├─ HTTPS requests: $0.01 per 10,000
└─ Typical: $50-200/month (depends on traffic)

WAF on ALB:
├─ Base: $5/month
├─ Rules: $1 per rule per month
├─ Requests: $0.60 per million
└─ Typical: $10-50/month

ALB:
├─ Base: $16/month
├─ LCU (processed bytes): $0.006 per LCU
└─ Typical: $20-100/month

Certificate (ACM):
├─ Free for AWS resources ✓
└─ Cost: $0

Total: ~$100-350/month (depending on traffic)
```

---

## Troubleshooting

### Issue: Certificate Not Valid

```
Problem: Browser shows certificate error

Check:
1. Certificate covers domain
   └─ *.freshdesk.com should cover www.freshdesk.com ✓

2. Certificate in CloudFront config
   └─ Verify correct certificate selected

3. DNS propagated correctly
   └─ nslookup www.freshdesk.com
   └─ Should resolve to CloudFront

Solution:
└─ Wait for DNS propagation (up to 48 hours)
```

### Issue: Direct ALB Access Not Blocked

```
Problem: curl to ALB returns 200 instead of 403

Check:
1. WAF associated with ALB
   └─ ALB → Edit → Verify WAF attached

2. WAF rule exists and is active
   └─ WAF → Rules → Verify rule enabled

3. Default action is Block
   └─ WAF → Settings → Verify default = Block

4. Rule is checking correct header
   └─ WAF → Rules → Verify header name & value

Solution:
└─ Check and fix settings above
```

### Issue: CloudFront Slow

```
Problem: Content takes long to load

Check:
1. Cache policy configured
   └─ Should have default TTL

2. Content is cacheable
   └─ Check Cache-Control headers

3. Edge location is nearby
   └─ CloudFront should serve from nearest edge

4. Origin responding fast
   └─ Check ALB/pod performance

Solution:
└─ Increase TTL if appropriate
└─ Optimize origin response time
```

---

## Next Steps

```
After setup complete:

1. Monitor CloudFront metrics
   └─ Requests, bandwidth, hit ratio

2. Monitor WAF logs
   └─ Blocked vs allowed requests

3. Optimize cache
   └─ Adjust TTL based on content

4. Scale as needed
   └─ Add more pods if needed

5. Set up alerts
   └─ High 403 rates indicate attacks
```

---

## Summary

```
What you have:

✅ One wildcard certificate (*.freshdesk.com)
   └─ Covers unlimited subdomains

✅ One CloudFront distribution
   └─ Serves all subdomains globally

✅ Multiple DNS records
   ├─ www.freshdesk.com → CloudFront
   ├─ hey.freshdesk.com → CloudFront
   └─ tee.freshdesk.com → CloudFront

✅ One ALB (from EKS Ingress)
   └─ Origin for CloudFront

✅ One WAF on ALB
   ├─ Checks custom header
   ├─ Blocks unauthorized access
   └─ Protects pods

Result:
├─ All subdomains served from global CDN ✓
├─ All subdomains on HTTPS ✓
├─ Only CloudFront traffic reaches pods ✓
├─ Infrastructure protected ✓
└─ Scalable and secure ✓
```
