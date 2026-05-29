import express, { Request, Response } from 'express';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
import axios from 'axios';
import * as trafficService from './mockTrafficService';

const app = express();
const httpServer = createServer(app);
const io = new SocketIOServer(httpServer, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT ?? 3001;

// ── Health ─────────────────────────────────────────────────────────────────
app.get('/api/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

// ── Session ─────────────────────────────────────────────────────────────────
app.post('/api/session', (req: Request, res: Response) => {
  const { userId, homeLocation, currentLocation, threshold, frequency } = req.body;

  if (!userId || !homeLocation || !currentLocation) {
    res.status(400).json({ error: 'userId, homeLocation, and currentLocation are required' });
    return;
  }

  const session = trafficService.createSession(
    userId,
    homeLocation,
    currentLocation,
    threshold ?? 20,
    frequency ?? 10,
    (update) => {
      io.emit('traffic_update', update);
    }
  );

  res.status(201).json(session);
});

app.get('/api/session/:userId', (req: Request, res: Response) => {
  const session = trafficService.getSession(req.params.userId);
  if (!session) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }
  res.json(session);
});

app.put('/api/session/:userId/location', (req: Request, res: Response) => {
  const { lat, long } = req.body;
  if (lat === undefined || long === undefined) {
    res.status(400).json({ error: 'lat and long are required' });
    return;
  }
  const ok = trafficService.updateLocation(req.params.userId, { lat, long });
  if (!ok) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }
  res.json({ success: true });
});

app.delete('/api/session/:userId', (req: Request, res: Response) => {
  const ok = trafficService.stopSession(req.params.userId);
  if (!ok) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }
  res.json({ success: true });
});

app.put('/api/session/:userId/settings', (req: Request, res: Response) => {
  const { homeLocation, notificationThreshold, notificationFrequencyMinutes } = req.body;
  const ok = trafficService.updateSettings(req.params.userId, {
    homeLocation,
    notificationThreshold,
    notificationFrequencyMinutes,
  });
  if (!ok) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }
  res.json({ success: true });
});

// ── Traffic ──────────────────────────────────────────────────────────────────
app.get('/api/traffic/:userId', (req: Request, res: Response) => {
  const condition = trafficService.getTraffic(req.params.userId);
  if (!condition) {
    res.status(404).json({ error: 'No traffic data yet' });
    return;
  }
  res.json(condition);
});

// ── Places search (Nominatim proxy) ─────────────────────────────────────────
app.get('/api/places/search', async (req: Request, res: Response) => {
  const q = req.query.q as string;
  if (!q) {
    res.status(400).json({ error: 'q parameter is required' });
    return;
  }
  try {
    const response = await axios.get('https://nominatim.openstreetmap.org/search', {
      params: { format: 'json', q, limit: 5 },
      headers: { 'User-Agent': 'TrafficBuilder/1.0' },
    });
    res.json(response.data);
  } catch (err) {
    res.status(502).json({ error: 'Geocoding request failed' });
  }
});

// ── Socket.io ────────────────────────────────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);

  socket.on('check_traffic', ({ userId }: { userId: string }) => {
    trafficService.forceCheck(userId);
  });

  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

httpServer.listen(PORT, () => {
  console.log(`Traffic Builder server running on http://localhost:${PORT}`);
});
