import express from 'express';
import cors from 'cors';
import { config } from './config';
import tokenRouter from './routes/token';
import participantsRouter from './routes/participants';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/token', tokenRouter);
app.use('/participants', participantsRouter);

// Health check
app.get('/health', (_req, res) => {
      res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
app.listen(config.port, () => {
      console.log(`[Voice Service] Running on port ${config.port}`);
      console.log(`[Voice Service] LiveKit URL: ${config.livekit.url}`);
      console.log(`[Voice Service] Matrix HS: ${config.matrixHomeserverUrl}`);
});
