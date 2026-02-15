import { Request, Response, NextFunction } from 'express';
import { verifyMatrixToken } from '../services/matrix-auth';

/**
 * Express middleware that verifies the Matrix access token from
 * the Authorization header and attaches the user ID to the request.
 */
export async function authMiddleware(
      req: Request,
      res: Response,
      next: NextFunction
): Promise<void> {
      const authHeader = req.headers.authorization;

      if (!authHeader || !authHeader.startsWith('Bearer ')) {
            res.status(401).json({ error: 'Missing or invalid Authorization header' });
            return;
      }

      const accessToken = authHeader.slice(7); // Strip "Bearer "
      const userId = await verifyMatrixToken(accessToken);

      if (!userId) {
            res.status(401).json({ error: 'Invalid Matrix access token' });
            return;
      }

      // Attach verified user info to request
      (req as any).matrixUserId = userId;
      next();
}
