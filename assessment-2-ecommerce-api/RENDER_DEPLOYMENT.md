# Deploying to Render

## Quick Start (5 minutes)

### Step 1: Push Code to GitHub
```bash
git init
git add .
git commit -m "Ready for Render deployment"
git remote add origin https://github.com/YOUR_USERNAME/assessment-2-ecommerce-api.git
git push -u origin main
```

### Step 2: Create Render Account
- Go to [render.com](https://render.com)
- Sign up with GitHub account (easiest)
- Authorize Render to access your repositories

### Step 3: Deploy
1. Click **New +** button in Render dashboard
2. Click **Web Service**
3. Select your `assessment-2-ecommerce-api` repository
4. Configure:
   - **Name**: `ecommerce-api` (auto-filled)
   - **Environment**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Plan**: Free (or Starter at $7/month for production)
5. Click **Create Web Service**

**That's it!** Render will build and deploy automatically.

---

## What You Get

| Feature | Free Tier | Starter ($7/mo) |
|---------|-----------|-----------------|
| **Auto-deploys** | ✅ | ✅ |
| **Preview deployments** | ✅ | ✅ |
| **Auto-shutdown** | After 15 min inactivity | None |
| **Performance** | Shared resources | 0.5 CPU, 512 MB RAM |
| **Suitable for** | Testing, demos | Production |

---

## Post-Deployment

### Your API URL
Once deployed, you'll get a URL like:
```
https://ecommerce-api.onrender.com
```

### Test the API
```bash
# Health check
curl https://ecommerce-api.onrender.com/health

# Get products
curl https://ecommerce-api.onrender.com/api/products

# Admin endpoints (with auth)
curl -H "Authorization: Bearer admin" \
  https://ecommerce-api.onrender.com/admin/metrics
```

---

## Environment Variables (Optional)

To add environment variables in Render:

1. Go to your service dashboard
2. Click **Environment** → **Add Environment Variable**
3. Add any needed variables:
   - `NODE_ENV=production` (auto-set)
   - `JWT_SECRET=your-secret-key` (if you update code to use this)
   - `PORT=3002` (auto-set)

---

## Monitoring & Logs

**View live logs:**
1. Service dashboard → **Logs** tab (bottom)
2. Shows real-time server output
3. Great for debugging issues

**View deployment history:**
1. Click **Deploys** tab
2. See all deployments and their status

---

## Upgrade to Paid (When Ready)

If you need:
- Always-on service (no shutdown)
- Better performance (production workloads)
- More resources

Click **Settings** → **Change Plan** → **Starter** or **Standard**

---

## Troubleshooting

### Service won't start?
1. Check **Logs** tab for error messages
2. Common issues:
   - Missing dependencies → run `npm install` locally
   - Wrong start command → check package.json `"start"` script
   - Port issues → server.js should use `process.env.PORT`

### Slow response?
- Free tier auto-shuts down after 15 min inactivity
- First request after shutdown takes 30 seconds
- Upgrade to **Starter** to stay always-on

### Need to redeploy?
- Push new code to GitHub → Render auto-deploys
- Or click **Manual Deploy** on service dashboard

---

## Cost Breakdown

| Service | Free | Starter | Standard |
|---------|------|---------|----------|
| **Web Service** | Free | $7/month | $12/month |
| **PostgreSQL** | 1 instance | 1 instance | ✅ |
| **Storage** | 100 MB | 1 GB | 10 GB |

**Current state**: Free tier fully sufficient for this project as-is

---

## Next Steps

1. ✅ Code ready for deployment
2. Push to GitHub
3. Connect GitHub to Render (5 minutes)
4. Watch deployment (2-3 minutes)
5. Share your live API URL!

Your API is now live and accessible worldwide! 🚀
