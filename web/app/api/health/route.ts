// Liveness for the container's health check and Coolify. No external calls:
// it answers as long as the Node server is up.
export const dynamic = 'force-dynamic';

export function GET() {
  return Response.json({ ok: true }, { headers: { 'Cache-Control': 'no-store' } });
}
