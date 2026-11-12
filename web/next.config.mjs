/** @type {import('next').NextConfig} */
const nextConfig = {
  poweredByHeader: false,
  // `next dev` otherwise writes an AGENTS.md into web/; the repo's own
  // CLAUDE.md and .claude/skills/marketing-site cover this site.
  agentRules: false,
  // The Docker image (Dockerfile) runs Next's standalone server. Vercel and
  // local builds keep the default output.
  ...(process.env.NEXT_OUTPUT_STANDALONE === '1' ? { output: 'standalone' } : {}),
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};

export default nextConfig;
