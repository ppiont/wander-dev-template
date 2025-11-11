import express from 'express'
import cors from 'cors'
import { Pool } from 'pg'
import { createClient } from 'redis'

const app = express()
const PORT = process.env.PORT || 8080

// Middleware
app.use(cors())
app.use(express.json())

// Database connection
const db = new Pool({
  connectionString: process.env.DATABASE_URL,
})

// Redis connection
const redis = createClient({
  url: process.env.REDIS_URL,
})

redis.on('error', (err) => console.error('Redis Client Error', err))

// Connect to Redis
;(async () => {
  try {
    await redis.connect()
    console.log('✅ Connected to Redis')
  } catch (err) {
    console.error('❌ Failed to connect to Redis:', err)
  }
})()

// Health check function (shared)
const checkHealth = async () => {
  const dbResult = await db.query('SELECT 1')
  const dbHealthy = dbResult.rowCount === 1
  const redisHealthy = redis.isOpen
  const healthy = dbHealthy && redisHealthy

  return {
    healthy,
    data: {
      status: healthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      services: {
        database: dbHealthy ? 'healthy' : 'unhealthy',
        redis: redisHealthy ? 'healthy' : 'unhealthy',
      },
    },
  }
}

// Root-level health endpoint for Kubernetes probes
app.get('/health', async (req, res) => {
  try {
    const { healthy, data } = await checkHealth()
    res.status(healthy ? 200 : 503).json(data)
  } catch (error) {
    console.error('Health check failed:', error)
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

// Create API router (all business logic serves at /api)
const apiRouter = express.Router()

// API health endpoints
apiRouter.get('/health', async (req, res) => {
  try {
    const { healthy, data } = await checkHealth()
    res.status(healthy ? 200 : 503).json(data)
  } catch (error) {
    console.error('Health check failed:', error)
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

apiRouter.get('/health/db', async (req, res) => {
  try {
    const result = await db.query('SELECT 1')
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

apiRouter.get('/health/redis', async (req, res) => {
  try {
    const isHealthy = redis.isOpen
    res.status(isHealthy ? 200 : 503).json({
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

// API root endpoint
apiRouter.get('/', (req, res) => {
  res.json({
    message: 'Wander API',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      healthDb: '/api/health/db',
      healthRedis: '/api/health/redis',
    },
  })
})

// Mount API router at /api
app.use('/api', apiRouter)

// Start server
app.listen(PORT, () => {
  console.log(`🚀 API server running on http://localhost:${PORT}`)
  console.log(`📍 API endpoints available at /api/*`)
  console.log(`❤️  Health check available at /health (for k8s probes)`)
})

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received: closing HTTP server')
  await redis.quit()
  await db.end()
  process.exit(0)
})
