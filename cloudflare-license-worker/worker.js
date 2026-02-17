/**
 * LoopMaker License Server
 *
 * Validates Gumroad license keys and enforces one license per device.
 *
 * Endpoints:
 * - GET /health - Health check
 * - POST /activate - Activate a license on a machine
 * - POST /verify - Verify an existing activation
 * - POST /deactivate - Deactivate a license from a machine
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const DEFAULT_PRODUCT_NAME = 'LoopMaker Pro';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    try {
      // Health check
      if (path === '/health') {
        return jsonResponse({
          success: true,
          message: 'LoopMaker License Server is running',
          timestamp: new Date().toISOString()
        });
      }

      // Activate license
      if (path === '/activate' && request.method === 'POST') {
        return await handleActivate(request, env);
      }

      // Verify license
      if (path === '/verify' && request.method === 'POST') {
        return await handleVerify(request, env);
      }

      // Deactivate license
      if (path === '/deactivate' && request.method === 'POST') {
        return await handleDeactivate(request, env);
      }

      return jsonResponse({ error: 'Not found' }, 404);

    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse({
        success: false,
        error: 'server_error',
        message: 'Internal server error'
      }, 500);
    }
  }
};

/**
 * Activate a license key
 */
async function handleActivate(request, env) {
  const body = await parseJsonBody(request);
  const licenseKey = normalizeString(body?.license_key);
  const machineId = normalizeString(body?.machine_id);

  if (!licenseKey || !machineId) {
    return jsonResponse({
      success: false,
      error: 'missing_params',
      message: 'License key and machine ID are required'
    }, 400);
  }

  // Verify with Gumroad
  const gumroadResult = await verifyWithGumroad(env, licenseKey);

  if (!gumroadResult.success) {
    const isServerConfigIssue = gumroadResult.error === 'config_error';

    return jsonResponse({
      success: false,
      error: isServerConfigIssue ? 'server_error' : 'invalid_license',
      message: gumroadResult.message || 'Invalid license key. Please check your key and try again.'
    }, isServerConfigIssue ? 500 : 400);
  }

  const existingActivation = await env.LICENSE_KV.get(licenseStorageKey(licenseKey), 'json');

  // Strict one-license-per-device policy:
  // once activated on machine A, activation on machine B is rejected.
  if (existingActivation && existingActivation.machine_id !== machineId) {
    return jsonResponse({
      success: false,
      error: 'already_activated',
      message: 'This license is already activated on another device. Deactivate it there before activating here.'
    }, 409);
  }

  const activation = existingActivation && existingActivation.machine_id === machineId
    ? {
      ...existingActivation,
      email: gumroadResult.email || existingActivation.email,
      product_name: gumroadResult.product_name || existingActivation.product_name,
      variants: gumroadResult.variants || existingActivation.variants
    }
    : {
      license_key: licenseKey,
      machine_id: machineId,
      activated_at: new Date().toISOString(),
      email: gumroadResult.email,
      product_name: gumroadResult.product_name,
      variants: gumroadResult.variants
    };

  await env.LICENSE_KV.put(licenseStorageKey(licenseKey), JSON.stringify(activation));
  await env.LICENSE_KV.put(machineStorageKey(machineId), JSON.stringify({ license_key: licenseKey }));

  return jsonResponse({
    success: true,
    message: existingActivation ? 'License already active on this device' : 'License activated successfully',
    activatedAt: activation.activated_at,
    licenseInfo: {
      email: gumroadResult.email,
      productName: gumroadResult.product_name || DEFAULT_PRODUCT_NAME,
      createdAt: gumroadResult.created_at,
      activatedAt: activation.activated_at,
      variants: gumroadResult.variants
    }
  });
}

/**
 * Verify an existing license
 */
async function handleVerify(request, env) {
  const body = await parseJsonBody(request);
  const licenseKey = normalizeString(body?.license_key);
  const machineId = normalizeString(body?.machine_id);

  if (!licenseKey || !machineId) {
    return jsonResponse({
      success: false,
      error: 'missing_params',
      message: 'License key and machine ID are required'
    }, 400);
  }

  // Check local activation first
  const activation = await env.LICENSE_KV.get(licenseStorageKey(licenseKey), 'json');

  if (!activation) {
    return jsonResponse({
      success: false,
      error: 'not_activated',
      message: 'License not found. Please activate first.'
    }, 400);
  }

  if (activation.machine_id !== machineId) {
    return jsonResponse({
      success: false,
      error: 'wrong_machine',
      message: 'License is activated on a different device.'
    }, 400);
  }

  // Verify with Gumroad (to check if license was refunded/revoked)
  const gumroadResult = await verifyWithGumroad(env, licenseKey);

  if (!gumroadResult.success) {
    // License was revoked - clear activation
    await env.LICENSE_KV.delete(licenseStorageKey(licenseKey));
    await env.LICENSE_KV.delete(machineStorageKey(machineId));

    return jsonResponse({
      success: false,
      error: 'license_revoked',
      message: 'License has been revoked or refunded.'
    }, 400);
  }

  return jsonResponse({
    success: true,
    message: 'License verified',
    activatedAt: activation.activated_at,
    licenseInfo: {
      email: activation.email || gumroadResult.email,
      productName: activation.product_name || DEFAULT_PRODUCT_NAME,
      createdAt: gumroadResult.created_at,
      activatedAt: activation.activated_at,
      variants: activation.variants || gumroadResult.variants
    }
  });
}

/**
 * Deactivate a license
 */
async function handleDeactivate(request, env) {
  const body = await parseJsonBody(request);
  const licenseKey = normalizeString(body?.license_key);
  const machineId = normalizeString(body?.machine_id);

  if (!licenseKey || !machineId) {
    return jsonResponse({
      success: false,
      error: 'missing_params',
      message: 'License key and machine ID are required'
    }, 400);
  }

  // Check activation exists
  const activation = await env.LICENSE_KV.get(licenseStorageKey(licenseKey), 'json');

  if (!activation) {
    return jsonResponse({
      success: false,
      error: 'not_activated',
      message: 'License not found.'
    }, 400);
  }

  if (activation.machine_id !== machineId) {
    return jsonResponse({
      success: false,
      error: 'wrong_machine',
      message: 'Cannot deactivate from a different device.'
    }, 400);
  }

  // Remove activation
  await env.LICENSE_KV.delete(licenseStorageKey(licenseKey));
  await env.LICENSE_KV.delete(machineStorageKey(machineId));

  return jsonResponse({
    success: true,
    message: 'License deactivated successfully. You can now activate on another device.'
  });
}

/**
 * Verify license with Gumroad API
 */
async function verifyWithGumroad(env, licenseKey) {
  const productId = normalizeString(env.GUMROAD_PRODUCT_ID);

  if (!productId) {
    return {
      success: false,
      error: 'config_error',
      message: 'License server is not configured. Missing GUMROAD_PRODUCT_ID.'
    };
  }

  try {
    const response = await fetch('https://api.gumroad.com/v2/licenses/verify', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        product_id: productId,
        license_key: licenseKey,
        increment_uses_count: 'false'
      })
    });

    const data = await response.json();

    if (data.success && !isRevokedPurchase(data.purchase)) {
      return {
        success: true,
        email: data.purchase?.email,
        product_name: data.purchase?.product_name,
        created_at: data.purchase?.created_at,
        variants: data.purchase?.variants,
        refunded: data.purchase?.refunded || false,
        chargebacked: data.purchase?.chargebacked || false,
        disputed: data.purchase?.disputed || false
      };
    } else {
      return {
        success: false,
        error: isRevokedPurchase(data.purchase) ? 'license_revoked' : 'invalid_license',
        message: isRevokedPurchase(data.purchase)
          ? 'License has been refunded or revoked.'
          : (data.message || 'Invalid license key')
      };
    }
  } catch (error) {
    console.error('Gumroad API error:', error);
    return {
      success: false,
      message: 'Unable to verify license. Please try again.'
    };
  }
}

/**
 * Parse JSON safely. Returns null on invalid JSON.
 */
async function parseJsonBody(request) {
  try {
    return await request.json();
  } catch (_) {
    return null;
  }
}

function normalizeString(value) {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim();
}

function isRevokedPurchase(purchase) {
  return Boolean(purchase?.refunded || purchase?.chargebacked || purchase?.disputed);
}

function licenseStorageKey(licenseKey) {
  return `license:${licenseKey}`;
}

function machineStorageKey(machineId) {
  return `machine:${machineId}`;
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
