import { config } from '../config';

interface MatrixWhoAmIResponse {
      user_id: string;
      device_id?: string;
}

/**
 * Verify a Matrix access token by calling the homeserver's /whoami endpoint.
 * Returns the authenticated user's Matrix ID (e.g. "@alice:example.com")
 * or null if the token is invalid.
 */
export async function verifyMatrixToken(accessToken: string): Promise<string | null> {
      try {
            const url = `${config.matrixHomeserverUrl}/_matrix/client/v3/account/whoami`;
            const response = await fetch(url, {
                  headers: {
                        'Authorization': `Bearer ${accessToken}`,
                  },
            });

            if (!response.ok) {
                  console.warn(`Matrix auth failed: ${response.status} ${response.statusText}`);
                  return null;
            }

            const data = (await response.json()) as MatrixWhoAmIResponse;
            return data.user_id || null;
      } catch (error) {
            console.error('Matrix auth verification error:', error);
            return null;
      }
}
