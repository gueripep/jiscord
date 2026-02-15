import { Router, Request, Response } from 'express';
import { generateToken, getLivekitUrl } from '../services/livekit';
import { authMiddleware } from '../middleware/auth';

const router = Router();

/**
 * POST /token
 * Body: { channelId: string, displayName?: string }
 * Headers: Authorization: Bearer <matrix_access_token>
 *
 * Returns a LiveKit JWT token for joining the specified voice channel.
 */
router.post('/', authMiddleware, (req: Request, res: Response) => {
      const { channelId, displayName } = req.body;
      const userId = (req as any).matrixUserId as string;

      if (!channelId || typeof channelId !== 'string') {
            res.status(400).json({ error: 'channelId is required' });
            return;
      }

      const name = displayName || userId;
      const token = generateToken(channelId, userId, name);

      res.json({
            token,
            livekitUrl: getLivekitUrl(),
      });
});

export default router;
