/**
 * Evidentia Chain-of-Custody System
 * Integration Gateway - Main Application Entry Point
 * 
 * This server acts as the Integration Gateway described in the paper,
 * providing REST APIs for frontend applications and forensic tool integrations.
 */

import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import path from 'path';

import { logger } from './config/logger';
import { initializeFabricGateway, disconnectFabricGateway } from './fabric/gateway';
import { initializeIPFS } from './services/ipfs.service';

// Routes
import authRoutes from './routes/auth.routes';
import evidenceRoutes from './routes/evidence.routes';
import forensicRoutes from './routes/forensic.routes';
import auditRoutes from './routes/audit.routes';

// Load environment variables
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const app: Express = express();
const PORT = process.env.PORT || 3001;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true
}));

// Request parsing
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Logging middleware
app.use(morgan('combined', {
  stream: { write: (message: string) => logger.info(message.trim()) }
}));

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'evidentia-gateway'
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/evidence', evidenceRoutes);
app.use('/api/forensic', forensicRoutes);
app.use('/api/audit', auditRoutes);

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.path}`
  });
});

// Error handler
app.use((err: Error, req: Request, res: Response, _next: NextFunction) => {
  logger.error('Unhandled error:', err);
  
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'An unexpected error occurred'
  });
});

// Graceful shutdown
async function shutdown() {
  logger.info('Shutting down gracefully...');
  await disconnectFabricGateway();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// Start server
async function startServer() {
  try {
    // Initialize Fabric Gateway
    logger.info('Initializing Fabric Gateway...');
    await initializeFabricGateway();
    logger.info('Fabric Gateway initialized successfully');

    // Initialize IPFS
    logger.info('Initializing IPFS client...');
    await initializeIPFS();
    logger.info('IPFS client initialized successfully');

    // Start Express server
    app.listen(PORT, () => {
      logger.info(`====================================`);
      logger.info(`Evidentia Integration Gateway`);
      logger.info(`====================================`);
      logger.info(`Server running on port ${PORT}`);
      logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
      logger.info(`Organization: ${process.env.FABRIC_ORG}`);
      logger.info(`Channel: ${process.env.FABRIC_CHANNEL_NAME}`);
      logger.info(`====================================`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

export default app;

