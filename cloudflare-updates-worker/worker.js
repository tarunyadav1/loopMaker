/**
 * LoopMaker Updates Worker
 *
 * Serves Sparkle appcast.xml and update files from R2 storage.
 *
 * Endpoints:
 * - GET /download - Redirects to latest release (use for Gumroad)
 * - GET /appcast.xml - Returns the Sparkle appcast feed
 * - GET /releases/:filename - Downloads update files from R2
 * - GET /health - Health check
 * - POST /admin/release - Create/update a release (requires auth)
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    try {
      // Health check
      if (path === '/health') {
        return jsonResponse({ status: 'ok', service: 'loopmaker-updates' });
      }

      // Serve appcast.xml
      if (path === '/appcast.xml') {
        return await handleAppcast(env);
      }

      // Redirect to latest release (permanent URL for Gumroad)
      if (path === '/download' || path === '/download/latest') {
        return await handleLatestDownload(env);
      }

      // Serve release files from R2
      if (path.startsWith('/releases/')) {
        const filename = path.replace('/releases/', '');
        return await handleFileDownload(env, filename, request, ctx);
      }

      // Admin: Create/update release
      if (path === '/admin/release' && request.method === 'POST') {
        return await handleCreateRelease(request, env);
      }

      // Admin: List releases
      if (path === '/admin/releases' && request.method === 'GET') {
        return await handleListReleases(request, env);
      }

      // Admin: Purge cache for a file
      if (path === '/admin/purge-cache' && request.method === 'POST') {
        return await handlePurgeCache(request, env);
      }

      return jsonResponse({ error: 'Not found' }, 404);

    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse({ error: 'Internal server error' }, 500);
    }
  }
};

/**
 * Generate and serve the appcast.xml
 */
async function handleAppcast(env) {
  // Get latest release info from KV
  const latestRelease = await env.APPCAST_KV.get('latest_release', 'json');

  if (!latestRelease) {
    // Return empty appcast if no releases yet
    const emptyAppcast = `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>LoopMaker Updates</title>
    <link>https://loopmaker.app</link>
    <description>Most recent updates to LoopMaker</description>
    <language>en</language>
  </channel>
</rss>`;
    return new Response(emptyAppcast, {
      headers: {
        'Content-Type': 'application/xml',
        ...CORS_HEADERS,
      },
    });
  }

  // Get all releases for full appcast
  const allReleases = await env.APPCAST_KV.get('all_releases', 'json') || [latestRelease];

  const appcast = generateAppcast(allReleases);

  return new Response(appcast, {
    headers: {
      'Content-Type': 'application/xml',
      'Cache-Control': 'public, max-age=300', // Cache for 5 minutes
      ...CORS_HEADERS,
    },
  });
}

/**
 * Generate Sparkle-compatible appcast XML
 */
function generateAppcast(releases) {
  const items = releases.map(release => `
    <item>
      <title>Version ${release.version}</title>
      <sparkle:version>${release.buildNumber}</sparkle:version>
      <sparkle:shortVersionString>${release.version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${release.minimumSystemVersion || '14.0'}</sparkle:minimumSystemVersion>
      <description><![CDATA[${release.releaseNotes || 'Bug fixes and improvements.'}]]></description>
      <pubDate>${release.pubDate}</pubDate>
      <enclosure
        url="${release.downloadUrl}"
        sparkle:edSignature="${release.edSignature}"
        length="${release.fileSize}"
        type="application/octet-stream"/>
    </item>`).join('\n');

  return `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>LoopMaker Updates</title>
    <link>https://loopmaker.app</link>
    <description>Most recent updates to LoopMaker</description>
    <language>en</language>
    ${items}
  </channel>
</rss>`;
}

/**
 * Handle redirect to latest release
 * This provides a permanent URL that always points to the latest version
 * Use this for Gumroad download links: https://loopmaker-updates.tarunyadav9761.workers.dev/download
 */
async function handleLatestDownload(env) {
  const latestRelease = await env.APPCAST_KV.get('latest_release', 'json');

  if (!latestRelease || !latestRelease.filename) {
    return jsonResponse({ error: 'No release available' }, 404);
  }

  // Redirect to the actual file
  return new Response(null, {
    status: 302,
    headers: {
      'Location': latestRelease.downloadUrl,
      ...CORS_HEADERS,
    },
  });
}

/**
 * Handle file downloads from R2
 * Serves directly from R2 without edge caching to ensure fresh files
 * (Caching was causing issues with file updates)
 */
async function handleFileDownload(env, filename, request, ctx) {
  const object = await env.UPDATES_BUCKET.get(filename);

  if (!object) {
    return jsonResponse({ error: 'File not found' }, 404);
  }

  const headers = new Headers();
  headers.set('Content-Type', 'application/octet-stream');
  headers.set('Content-Disposition', `attachment; filename="${filename}"`);
  headers.set('Content-Length', object.size);
  // Use ETag for cache validation - allows browser caching but server controls freshness
  headers.set('ETag', object.etag);
  headers.set('Cache-Control', 'public, max-age=3600, must-revalidate'); // 1 hour, must revalidate

  Object.entries(CORS_HEADERS).forEach(([key, value]) => {
    headers.set(key, value);
  });

  return new Response(object.body, { headers });
}

/**
 * Admin: Create or update a release
 * Requires Authorization header with admin secret
 */
async function handleCreateRelease(request, env) {
  // Verify admin authorization
  const authHeader = request.headers.get('Authorization');
  const adminSecret = env.ADMIN_SECRET;

  if (!adminSecret || authHeader !== `Bearer ${adminSecret}`) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const body = await request.json();

  // Validate required fields
  const required = ['version', 'buildNumber', 'edSignature', 'fileSize', 'filename'];
  for (const field of required) {
    if (!body[field]) {
      return jsonResponse({ error: `Missing required field: ${field}` }, 400);
    }
  }

  const release = {
    version: body.version,
    buildNumber: body.buildNumber,
    edSignature: body.edSignature,
    fileSize: body.fileSize,
    filename: body.filename,
    downloadUrl: `https://loopmaker-updates.tarunyadav9761.workers.dev/releases/${body.filename}`,
    releaseNotes: body.releaseNotes || 'Bug fixes and improvements.',
    minimumSystemVersion: body.minimumSystemVersion || '14.0',
    pubDate: new Date().toUTCString(),
  };

  // Store as latest release
  await env.APPCAST_KV.put('latest_release', JSON.stringify(release));

  // Add to all releases list
  let allReleases = await env.APPCAST_KV.get('all_releases', 'json') || [];

  // Remove existing release with same version
  allReleases = allReleases.filter(r => r.version !== release.version);

  // Add new release at the beginning
  allReleases.unshift(release);

  // Keep only last 10 releases
  allReleases = allReleases.slice(0, 10);

  await env.APPCAST_KV.put('all_releases', JSON.stringify(allReleases));

  return jsonResponse({
    success: true,
    message: 'Release created',
    release: release,
    appcastUrl: 'https://loopmaker-updates.tarunyadav9761.workers.dev/appcast.xml'
  });
}

/**
 * Admin: List all releases
 */
async function handleListReleases(request, env) {
  const authHeader = request.headers.get('Authorization');
  const adminSecret = env.ADMIN_SECRET;

  if (!adminSecret || authHeader !== `Bearer ${adminSecret}`) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const allReleases = await env.APPCAST_KV.get('all_releases', 'json') || [];

  return jsonResponse({ releases: allReleases });
}

/**
 * Admin: Purge cache for a specific file
 */
async function handlePurgeCache(request, env) {
  const authHeader = request.headers.get('Authorization');
  const adminSecret = env.ADMIN_SECRET;

  if (!adminSecret || authHeader !== `Bearer ${adminSecret}`) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const body = await request.json();
  const filename = body.filename;

  if (!filename) {
    return jsonResponse({ error: 'Missing filename' }, 400);
  }

  // Purge from Cloudflare cache
  const cacheUrl = `https://loopmaker-updates.tarunyadav9761.workers.dev/releases/${filename}`;
  const cache = caches.default;

  try {
    const deleted = await cache.delete(cacheUrl);
    return jsonResponse({
      success: true,
      message: deleted ? 'Cache purged' : 'File was not in cache',
      filename: filename
    });
  } catch (error) {
    return jsonResponse({ error: 'Failed to purge cache', details: error.message }, 500);
  }
}

/**
 * Helper: Create JSON response
 */
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...CORS_HEADERS,
    },
  });
}
