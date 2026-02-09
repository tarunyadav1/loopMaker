/**
 * LoopMaker License Server
 *
 * Validates license keys with Gumroad API and manages activations.
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

// Gumroad product ID (use the API product ID, not the permalink)
const GUMROAD_PRODUCT_ID = 'REPLACE_WITH_LOOPMAKER_PRODUCT_ID';

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
  const body = await request.json();
  const { license_key, machine_id } = body;

  if (!license_key || !machine_id) {
    return jsonResponse({
      success: false,
      error: 'missing_params',
      message: 'License key and machine ID are required'
    }, 400);
  }

  // Verify with Gumroad
  const gumroadResult = await verifyWithGumroad(license_key);

  if (!gumroadResult.success) {
    return jsonResponse({
      success: false,
      error: 'invalid_license',
      message: gumroadResult.message || 'Invalid license key. Please check your key and try again.'
    }, 400);
  }

  // Check if already activated on different machine
  const existingActivation = await env.LICENSE_KV.get(`license:${license_key}`, 'json');

  if (existingActivation && existingActivation.machine_id !== machine_id) {
    // Check if we allow multiple activations (based on Gumroad variant)
    const maxActivations = gumroadResult.quantity || 1;
    const activations = await getActivationsForLicense(env, license_key);

    if (activations.length >= maxActivations) {
      return jsonResponse({
        success: false,
        error: 'already_activated',
        message: `This license is already activated on another device. You can deactivate it from the original device or contact support.`
      }, 400);
    }
  }

  // Store activation
  const activation = {
    license_key,
    machine_id,
    activated_at: new Date().toISOString(),
    email: gumroadResult.email,
    product_name: gumroadResult.product_name,
    variants: gumroadResult.variants
  };

  await env.LICENSE_KV.put(`license:${license_key}`, JSON.stringify(activation));
  await env.LICENSE_KV.put(`machine:${machine_id}`, JSON.stringify({ license_key }));

  return jsonResponse({
    success: true,
    message: 'License activated successfully',
    activatedAt: activation.activated_at,
    licenseInfo: {
      email: gumroadResult.email,
      productName: gumroadResult.product_name || 'LoopMaker Pro',
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
  const body = await request.json();
  const { license_key, machine_id } = body;

  if (!license_key || !machine_id) {
    return jsonResponse({
      success: false,
      error: 'missing_params',
      message: 'License key and machine ID are required'
    }, 400);
  }

  // Check local activation first
  const activation = await env.LICENSE_KV.get(`license:${license_key}`, 'json');

  if (!activation) {
    return jsonResponse({
      success: false,
      error: 'not_activated',
      message: 'License not found. Please activate first.'
    }, 400);
  }

  if (activation.machine_id !== machine_id) {
    return jsonResponse({
      success: false,
      error: 'wrong_machine',
      message: 'License is activated on a different device.'
    }, 400);
  }

  // Verify with Gumroad (to check if license was refunded/revoked)
  const gumroadResult = await verifyWithGumroad(license_key);

  if (!gumroadResult.success) {
    // License was revoked - clear activation
    await env.LICENSE_KV.delete(`license:${license_key}`);
    await env.LICENSE_KV.delete(`machine:${machine_id}`);

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
      productName: activation.product_name || 'LoopMaker Pro',
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
  const body = await request.json();
  const { license_key, machine_id } = body;

  if (!license_key || !machine_id) {
    return jsonResponse({
      success: false,
      error: 'missing_params',
      message: 'License key and machine ID are required'
    }, 400);
  }

  // Check activation exists
  const activation = await env.LICENSE_KV.get(`license:${license_key}`, 'json');

  if (!activation) {
    return jsonResponse({
      success: false,
      error: 'not_activated',
      message: 'License not found.'
    }, 400);
  }

  if (activation.machine_id !== machine_id) {
    return jsonResponse({
      success: false,
      error: 'wrong_machine',
      message: 'Cannot deactivate from a different device.'
    }, 400);
  }

  // Remove activation
  await env.LICENSE_KV.delete(`license:${license_key}`);
  await env.LICENSE_KV.delete(`machine:${machine_id}`);

  return jsonResponse({
    success: true,
    message: 'License deactivated successfully. You can now activate on another device.'
  });
}

/**
 * Verify license with Gumroad API
 */
async function verifyWithGumroad(licenseKey) {
  try {
    const response = await fetch('https://api.gumroad.com/v2/licenses/verify', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        product_id: GUMROAD_PRODUCT_ID,
        license_key: licenseKey,
        increment_uses_count: 'false'
      })
    });

    const data = await response.json();

    if (data.success) {
      return {
        success: true,
        email: data.purchase?.email,
        product_name: data.purchase?.product_name,
        created_at: data.purchase?.created_at,
        variants: data.purchase?.variants,
        quantity: data.purchase?.quantity || 1,
        refunded: data.purchase?.refunded || false,
        chargebacked: data.purchase?.chargebacked || false
      };
    } else {
      return {
        success: false,
        message: data.message || 'Invalid license key'
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
 * Get all activations for a license (for multi-device support)
 */
async function getActivationsForLicense(env, licenseKey) {
  const activation = await env.LICENSE_KV.get(`license:${licenseKey}`, 'json');
  return activation ? [activation] : [];
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
