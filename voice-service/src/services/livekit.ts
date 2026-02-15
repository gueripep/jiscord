import { AccessToken } from 'livekit-server-sdk';
import { config } from '../config';

/**
 * In-memory participant tracking.
 * Maps channelId -> Set of { userId, displayName, joinedAt }.
 */
export interface Participant {
      userId: string;
      displayName: string;
      joinedAt: string;
}

const channelParticipants = new Map<string, Map<string, Participant>>();

/**
 * Generate a LiveKit access token for a user to join a specific voice channel.
 */
export function generateToken(channelId: string, userId: string, displayName: string): string {
      const token = new AccessToken(config.livekit.apiKey, config.livekit.apiSecret, {
            identity: userId,
            name: displayName,
            ttl: '24h',
      });

      token.addGrant({
            room: channelId,
            roomJoin: true,
            canPublish: true,
            canSubscribe: true,
            canPublishData: true,
      });

      return token.toJwt();
}

/**
 * Get the LiveKit WebSocket URL for client connections.
 */
export function getLivekitUrl(): string {
      return config.livekit.url;
}

/**
 * Get participants currently in a channel.
 */
export function getParticipants(channelId: string): Participant[] {
      const participants = channelParticipants.get(channelId);
      if (!participants) return [];
      return Array.from(participants.values());
}

/**
 * Handle a LiveKit webhook event to track participant join/leave.
 */
export function handleWebhookEvent(event: {
      event: string;
      room?: { name: string };
      participant?: { identity: string; name?: string };
}): void {
      const roomName = event.room?.name;
      const participantId = event.participant?.identity;

      if (!roomName || !participantId) return;

      switch (event.event) {
            case 'participant_joined': {
                  if (!channelParticipants.has(roomName)) {
                        channelParticipants.set(roomName, new Map());
                  }
                  channelParticipants.get(roomName)!.set(participantId, {
                        userId: participantId,
                        displayName: event.participant?.name || participantId,
                        joinedAt: new Date().toISOString(),
                  });
                  console.log(`[Voice] ${participantId} joined ${roomName}`);
                  break;
            }
            case 'participant_left': {
                  channelParticipants.get(roomName)?.delete(participantId);
                  // Clean up empty channels
                  if (channelParticipants.get(roomName)?.size === 0) {
                        channelParticipants.delete(roomName);
                  }
                  console.log(`[Voice] ${participantId} left ${roomName}`);
                  break;
            }
      }
}
