import { createReadStream, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';
import type { APIRoute } from 'astro';
import { DATA_DIR } from '../../lib/config';

export const GET: APIRoute = async ({ url }) => {
  try {
    const jobId = url.searchParams.get('id');

    if (!jobId) {
      return new Response(JSON.stringify({ error: 'Missing job ID parameter.' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Sanitize job ID to prevent path traversal
    const sanitizedJobId = jobId.replace(/[^a-zA-Z0-9-]/g, '');

    if (sanitizedJobId !== jobId) {
      return new Response(JSON.stringify({ error: 'Invalid job ID.' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const zipPath = join(DATA_DIR, `${sanitizedJobId}.zip`);

    if (!existsSync(zipPath)) {
      return new Response(
        JSON.stringify({
          error: 'Result not found. It may have expired or the job ID is invalid.',
        }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    const stat = statSync(zipPath);
    const filename = `beatportdl-${sanitizedJobId}.zip`;

    // Create a readable stream and convert to web ReadableStream
    const nodeStream = createReadStream(zipPath);

    const webStream = new ReadableStream({
      start(controller) {
        nodeStream.on('data', (chunk) => {
          controller.enqueue(chunk);
        });
        nodeStream.on('end', () => {
          controller.close();
        });
        nodeStream.on('error', (err) => {
          controller.error(err);
        });
      },
      cancel() {
        nodeStream.destroy();
      },
    });

    return new Response(webStream, {
      status: 200,
      headers: {
        'Content-Type': 'application/zip',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length': stat.size.toString(),
      },
    });
  } catch (err) {
    console.error('Result API error:', err);
    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : 'An unexpected error occurred',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }
};
