const express = require('express');
const cors = require('cors');
const path = require('path');

// Import routes
const productsRoutes = require('./routes/products');
const cartRoutes = require('./routes/cart');
const secretProductRoutes = require('./routes/product_secret_endpoint');

const app = express();
const PORT = process.env.PORT || 3002;

// ADDED: Metrics Collection System
const metrics = {
  startTime: Date.now(),
  requests: {
    total: 0,
    byMethod: { GET: 0, POST: 0, PUT: 0, DELETE: 0, OPTIONS: 0 },
    byStatus: { '2xx': 0, '3xx': 0, '4xx': 0, '5xx': 0 }
  },
  performance: {
    avgResponseTime: 0,
    slowestEndpoint: { path: '', time: 0 },
    fastestEndpoint: { path: '', time: Infinity },
    responses: []
  },
  endpoints: new Map()
};

function collectMetrics(req, res, next) {
  const start = Date.now();
  const originalSend = res.send;
  
  res.send = function(data) {
    const duration = Date.now() - start;
    const statusCode = res.statusCode;
    const statusCategory = `${Math.floor(statusCode / 100)}xx`;
    
    // Update overall metrics
    metrics.requests.total++;
    metrics.requests.byMethod[req.method] = (metrics.requests.byMethod[req.method] || 0) + 1;
    metrics.requests.byStatus[statusCategory] = (metrics.requests.byStatus[statusCategory] || 0) + 1;
    
    // Track endpoint performance
    const endpoint = `${req.method} ${req.path}`;
    if (!metrics.endpoints.has(endpoint)) {
      metrics.endpoints.set(endpoint, { count: 0, totalTime: 0, avgTime: 0, minTime: Infinity, maxTime: 0 });
    }
    const endpointMetrics = metrics.endpoints.get(endpoint);
    endpointMetrics.count++;
    endpointMetrics.totalTime += duration;
    endpointMetrics.avgTime = endpointMetrics.totalTime / endpointMetrics.count;
    endpointMetrics.minTime = Math.min(endpointMetrics.minTime, duration);
    endpointMetrics.maxTime = Math.max(endpointMetrics.maxTime, duration);
    
    // Track slowest/fastest
    if (duration > metrics.performance.slowestEndpoint.time) {
      metrics.performance.slowestEndpoint = { path: endpoint, time: duration };
    }
    if (duration < metrics.performance.fastestEndpoint.time) {
      metrics.performance.fastestEndpoint = { path: endpoint, time: duration };
    }
    
    // Calculate average response time
    metrics.performance.responses.push(duration);
    if (metrics.performance.responses.length > 1000) metrics.performance.responses.shift();
    metrics.performance.avgResponseTime = metrics.performance.responses.reduce((a, b) => a + b, 0) / metrics.performance.responses.length;
    
    return originalSend.call(this, data);
  };
  
  next();
}

// ADDED: Audit Logging System
const auditLogs = []; // Stores up to 1000 logs
const MAX_AUDIT_LOGS = 1000;

function logAudit(req, res, next) {
  // Log request details
  const logEntry = {
    timestamp: new Date().toISOString(),
    method: req.method,
    path: req.path,
    ip: req.ip || req.connection.remoteAddress,
    userAgent: req.get('user-agent') || 'Unknown',
    requestSize: req.headers['content-length'] || 0
  };
  
  // Intercept response to log status
  const originalSend = res.send;
  res.send = function(data) {
    logEntry.statusCode = res.statusCode;
    logEntry.responseSize = Buffer.byteLength(JSON.stringify(data));
    
    // Try to extract userId from auth header
    const authHeader = req.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const crypto = require('crypto');
      const token = authHeader.substring(7);
      logEntry.userId = crypto.createHash('md5').update(token).digest('hex').substring(0, 8);
    }
    
    // Add to audit logs (FIFO rotation)
    auditLogs.push(logEntry);
    if (auditLogs.length > MAX_AUDIT_LOGS) {
      auditLogs.shift();
    }
    
    return originalSend.call(this, data);
  };
  
  next();
}

// ADDED: Rate Limiting System
const rateLimitStore = new Map(); // IP address -> { count, resetTime }
const RATE_LIMIT = {
  windowMs: 60 * 1000, // 1 minute
  maxRequests: 100 // 100 requests per minute
};

function rateLimit(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress;
  const now = Date.now();
  
  if (!rateLimitStore.has(ip)) {
    rateLimitStore.set(ip, { count: 1, resetTime: now + RATE_LIMIT.windowMs });
    return next();
  }
  
  const record = rateLimitStore.get(ip);
  
  if (now > record.resetTime) {
    // Reset the window
    record.count = 1;
    record.resetTime = now + RATE_LIMIT.windowMs;
    return next();
  }
  
  record.count++;
  
  if (record.count > RATE_LIMIT.maxRequests) {
    return res.status(429).json({
      error: 'Too many requests',
      retryAfter: Math.ceil((record.resetTime - now) / 1000),
      message: `Rate limit exceeded. Max ${RATE_LIMIT.maxRequests} requests per minute.`
    });
  }
  
  // Add rate limit info to response headers
  res.set({
    'X-RateLimit-Limit': RATE_LIMIT.maxRequests,
    'X-RateLimit-Remaining': RATE_LIMIT.maxRequests - record.count,
    'X-RateLimit-Reset': record.resetTime
  });
  
  next();
}

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ADDED: Apply Rate Limiting, Metrics Collection, and Audit Logging
app.use(rateLimit);
app.use(collectMetrics);
app.use(logAudit);

// Custom headers for puzzle hints
app.use((req, res, next) => {
  res.set({
    'X-API-Version': 'v2.0',
    'X-Puzzle-Hint': 'base64_decode_this_cHJvZHVjdF9zZWNyZXRfZW5kcG9pbnQ=',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
  });
  next();
});

// Routes
app.use('/api/products', productsRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/product_secret_endpoint', secretProductRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// ADDED: Audit Logs endpoint (admin only - needs auth)
app.get('/admin/audit-logs', (req, res) => {
  const authHeader = req.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  res.json({
    totalLogs: auditLogs.length,
    logs: auditLogs.slice(-50), // Return last 50 logs
    message: 'Showing last 50 audit logs'
  });
});

// ADDED: Rate Limit Status endpoint
app.get('/admin/rate-limit-status', (req, res) => {
  const authHeader = req.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  const now = Date.now();
  const stats = {
    totalTracked: rateLimitStore.size,
    config: {
      windowMs: RATE_LIMIT.windowMs,
      maxRequests: RATE_LIMIT.maxRequests
    },
    activeIPs: []
  };
  
  rateLimitStore.forEach((record, ip) => {
    if (now < record.resetTime) {
      stats.activeIPs.push({
        ip,
        requests: record.count,
        remaining: Math.max(0, RATE_LIMIT.maxRequests - record.count),
        resetIn: Math.ceil((record.resetTime - now) / 1000) + 's'
      });
    }
  });
  
  res.json(stats);
});

// ADDED: Metrics endpoint (admin - performance monitoring)
app.get('/admin/metrics', (req, res) => {
  const authHeader = req.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  const uptime = Date.now() - metrics.startTime;
  const endpointStats = [];
  
  metrics.endpoints.forEach((stats, endpoint) => {
    endpointStats.push({
      endpoint,
      count: stats.count,
      avgTime: Math.round(stats.avgTime),
      minTime: stats.minTime,
      maxTime: stats.maxTime
    });
  });
  
  res.json({
    uptime: Math.round(uptime / 1000) + 's',
    requests: metrics.requests,
    performance: {
      avgResponseTime: Math.round(metrics.performance.avgResponseTime),
      slowestEndpoint: metrics.performance.slowestEndpoint,
      fastestEndpoint: metrics.performance.fastestEndpoint,
      totalRequests: metrics.requests.total
    },
    endpoints: endpointStats.sort((a, b) => b.count - a.count),
    message: 'API performance metrics'
  });
});
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Error handler
app.use((error, req, res, next) => {
  console.error('Error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`🛒 Assessment 2: E-commerce Product API running on http://localhost:${PORT}`);
  console.log(`📋 View instructions: http://localhost:${PORT}`);
  console.log(`⚡ Performance challenges await!`);
});
