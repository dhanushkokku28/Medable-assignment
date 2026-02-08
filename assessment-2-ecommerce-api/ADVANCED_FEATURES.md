# Advanced Features - Rate Limiting & Audit Logging

## 🎉 New Features Added

### 1. Rate Limiting ⏱️
Protects the API from abuse by limiting the number of requests per IP address.

**Configuration:**
- Window: 60 seconds (1 minute)
- Max Requests: 100 per window
- Per IP Address Tracking

**How It Works:**
- Each IP address can make up to 100 requests per minute
- Counter resets after each 60-second window
- Exceeding the limit returns HTTP 429 (Too Many Requests)
- Response includes retry information

**Example Response (Rate Limit Exceeded):**
```json
{
  "error": "Too many requests",
  "retryAfter": 45,
  "message": "Rate limit exceeded. Max 100 requests per minute."
}
```

**Response Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 23
X-RateLimit-Reset: 1644207840000
```

---

### 2. Audit Logging 📋
Records all API requests and responses for security monitoring and compliance.

**What's Logged:**
- Timestamp (ISO 8601)
- HTTP Method (GET, POST, PUT, DELETE)
- Request Path
- Response Status Code
- Client IP Address
- User ID (if authenticated)
- Request Size (bytes)
- Response Size (bytes)

**Log Entry Example:**
```
[2026-02-07T05:22:40.829Z] GET /api/products → 200 (User: a1b2c3d4)
```

**Storage:**
- In-memory storage (last 1000 logs)
- Logs are rotated (oldest removed when limit exceeded)
- Can be extended to database for persistence

---

## 🔧 Admin Endpoints

### 1. View Audit Logs
```bash
curl -H "Authorization: Bearer admin-token" \
     "http://localhost:3002/admin/audit-logs"
```

**Response:**
```json
{
  "totalLogs": 102,
  "logs": [
    {
      "timestamp": "2026-02-07T05:22:40.829Z",
      "method": "GET",
      "path": "/api/products",
      "statusCode": 200,
      "userAgent": "curl/7.64.1",
      "ip": "::1",
      "userId": "a1b2c3d4",
      "requestSize": 0,
      "responseSize": 2048
    }
  ],
  "message": "Showing last 50 audit logs"
}
```

---

### 2. View Rate Limit Status
```bash
curl -H "Authorization: Bearer admin-token" \
     "http://localhost:3002/admin/rate-limit-status"
```

**Response:**
```json
{
  "totalTracked": 1,
  "config": {
    "windowMs": 60000,
    "maxRequests": 100
  },
  "activeIPs": [
    {
      "ip": "192.168.1.100",
      "requests": 45,
      "remaining": 55,
      "resetIn": "23s"
    }
  ]
}
```

---

## 🔐 Security Features

### Authentication Required for Admin Endpoints
Both admin endpoints require Bearer token authentication:

```bash
# Without token - REJECTED (401)
curl "http://localhost:3002/admin/audit-logs"
# {"error": "Authentication required"}

# With token - ACCEPTED (200)
curl -H "Authorization: Bearer admin-token" \
     "http://localhost:3002/admin/audit-logs"
```

---

## 📊 Use Cases

### Rate Limiting Benefits
- ✅ Prevent DDoS attacks
- ✅ Fair resource usage
- ✅ Protect database from overload
- ✅ Prevent brute force attempts
- ✅ Cost control (API calls)

### Audit Logging Benefits
- ✅ Security compliance (GDPR, SOC 2)
- ✅ Fraud detection
- ✅ Performance monitoring
- ✅ User behavior analysis
- ✅ Incident investigation
- ✅ Change tracking

---

## 🧪 Testing Rate Limiting

### Test 1: Normal Requests (Within Limit)
```bash
# This will succeed
for i in {1..50}; do
  curl "http://localhost:3002/health"
done
# All 50 requests succeed (well within 100 limit)
```

### Test 2: Exceed Rate Limit
```bash
# This will trigger rate limiting
for i in {1..105}; do
  curl "http://localhost:3002/health"
done
# First 100 requests succeed
# Requests 101-105 return 429
```

### Test 3: Multiple IPs Tracked Separately
```bash
# IP 1 makes 100 requests (allowed)
# IP 2 makes 100 requests (allowed)
# They have separate counters

# From Machine A
for i in {1..100}; do curl "http://localhost:3002/health"; done

# From Machine B (different IP)
for i in {1..100}; do curl "http://localhost:3002/health"; done
# Both succeed because they're different IPs
```

---

## 📈 Monitoring Pattern

### Recommended Admin Dashboard Flow
```
1. Check Rate Limit Status
   - See which IPs are active
   - Identify potential attackers
   - Monitor usage patterns

2. Review Audit Logs
   - Check for suspicious activities
   - Track failed authentication attempts
   - Monitor admin operations

3. Identify Anomalies
   - IPs exceeding limits
   - Unusual request patterns
   - Failed operations
```

---

## 🛠️ Configuration (Optional)

To modify rate limiting, edit `server.js`:

```javascript
const RATE_LIMIT = {
  windowMs: 60 * 1000,    // Window size (milliseconds)
  maxRequests: 100        // Max requests per window
};
```

Examples:
```javascript
// Strict: 30 requests per 30 seconds
const RATE_LIMIT = {
  windowMs: 30 * 1000,
  maxRequests: 30
};

// Lenient: 1000 requests per 1 hour
const RATE_LIMIT = {
  windowMs: 60 * 60 * 1000,
  maxRequests: 1000
};
```

---

## 📝 Log Retention Policy

**Current Configuration:**
- Max Logs Stored: 1000 entries
- Storage: In-memory (resets on server restart)

**When exceeded:**
- Oldest log is automatically removed
- Latest logs are always preserved
- No manual cleanup needed

**For Production:**
- Store logs in database (MongoDB, PostgreSQL)
- Implement log rotation (daily/hourly)
- Archive old logs to cold storage
- Set retention period (e.g., 90 days)

---

## 🔍 Example Workflows

### Detecting Abuse
```bash
# Step 1: Check rate limit status to find suspicious IPs
curl -H "Authorization: Bearer admin-token" \
     "http://localhost:3002/admin/rate-limit-status"

# Result: See IPs hitting the limit repeatedly
# Action: Block IP in firewall/proxy

# Step 2: Review audit logs to understand what they did
curl -H "Authorization: Bearer admin-token" \
     "http://localhost:3002/admin/audit-logs"
```

### Security Incident Investigation
```bash
# Check audit logs for suspicious activity
# Look for:
# - Multiple 401 errors (auth failures)
# - 429 responses (rate limit blocks)
# - Unusual paths accessed
# - Large response sizes

# Example: Find all failed login attempts
curl -H "Authorization: Bearer admin-token" \
     "http://localhost:3002/admin/audit-logs" \
     | jq '.logs[] | select(.statusCode == 401)'
```

### Performance Monitoring
```bash
# Track request sizes to identify large payloads
curl -H "Authorization: Bearer admin-token" \
     "http://localhost:3002/admin/audit-logs" \
     | jq '.logs | sort_by(.responseSize) | reverse | .[0:10]'
# Shows 10 largest responses
```

---

## ✅ Status

- ✅ Rate Limiting: Functional
- ✅ Audit Logging: Functional
- ✅ Admin Endpoints: Protected
- ✅ Per-IP Tracking: Working
- ✅ Log Rotation: Implemented

---

## 📞 Troubleshooting

### Getting 429 Too Many Requests?
- Wait 60 seconds for rate limit window to reset
- Or use a different IP/proxy
- Check your request frequency

### Can't Access Admin Endpoints?
- Ensure Authorization header is included
- Use valid Bearer token
- Check if endpoint exists: `/admin/audit-logs` or `/admin/rate-limit-status`

### Logs Not Appearing?
- Make sure requests completed successfully
- Admin logs only after response sent
- Wait a few seconds for async logging
- Check server console for errors

---

**Last Updated**: February 7, 2026
**Status**: ✅ COMPLETE & TESTED
