import { Router, Request, Response } from 'express';
import { getParticipants, handleWebhookEvent } from '../services/livekit';

const router = Router();

/**
 * GET /participants/:channelId
 * Returns the list of participants currently in a voice channel.
 * No auth required — participant lists are public within the app.
 */
router.get('/:channelId', (req: Request, res: Response) => {
      const { channelId } = req.params;
      const participants = getParticipants(channelId);

      res.json({
            channelId,
            count: participants.length,
            participants,
      });
});

/**
 * POST /participants/webhook
 * LiveKit webhook receiver. Configure LiveKit to POST events here.
 * Tracks participant_joined and participant_left events.
 */
router.post('/webhook', (req: Request, res: Response) => {
      const event = req.body;

      if (!event || !event.event) {
            res.status(400).json({ error: 'Invalid webhook payload' });
            return;
      }

      handleWebhookEvent(event);
      res.status(200).json({ ok: true });
});

export default router;
