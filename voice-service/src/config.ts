import dotenv from 'dotenv';
dotenv.config();

export const config = {
      port: parseInt(process.env.PORT || '3500', 10),
      livekit: {
            apiKey: process.env.LIVEKIT_API_KEY || '',
            apiSecret: process.env.LIVEKIT_API_SECRET || '',
            url: process.env.LIVEKIT_URL || 'ws://localhost:7880',
      },
      matrixHomeserverUrl: process.env.MATRIX_HOMESERVER_URL || 'http://localhost:8008',
};

// Validate required config
if (!config.livekit.apiKey || !config.livekit.apiSecret) {
      console.error('ERROR: LIVEKIT_API_KEY and LIVEKIT_API_SECRET must be set');
      process.exit(1);
}
