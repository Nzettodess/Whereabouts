// Vercel serverless function to send OneSignal push notifications
export default async function handler(req, res) {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    const { playerIds, title, message, data, external_id } = req.body;

    // VERBOSE LOGGING: Start request tracking
    console.log('--- PUSH NOTIFICATION REQUEST START ---');
    console.log('Target PlayerIds (UIDs):', playerIds);
    console.log('Title:', title);
    console.log('Message:', message);
    console.log('Data:', data);
    console.log('External ID:', external_id);

    if (!playerIds || !Array.isArray(playerIds) || !message) {
        console.error('ERROR: Missing required fields');
        return res.status(400).json({ error: 'Missing required fields' });
    }

    const apiKey = process.env.ONESIGNAL_API_KEY;
    const appId = process.env.ONESIGNAL_APP_ID;

    if (!apiKey || !appId) {
        console.error('SERVER ERROR: Missing ONESIGNAL_API_KEY or ONESIGNAL_APP_ID in environment variables');
        return res.status(500).json({ error: 'Server configuration error' });
    }

    try {
        const payload = {
            app_id: appId,
            // Target by External ID (Firebase UID)
            include_aliases: {
                external_id: playerIds
            },
            headings: { en: title || 'Orbit' },
            contents: { en: message },
            data: data || {},
            external_id: external_id,
        };

        console.log('OneSignal Payload:', JSON.stringify(payload, null, 2));

        const response = await fetch('https://onesignal.com/api/v1/notifications', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Basic ${apiKey}`,
            },
            body: JSON.stringify(payload),
        });

        const result = await response.json();
        console.log('OneSignal API Response Status:', response.status);
        console.log('OneSignal API Response Body:', JSON.stringify(result, null, 2));

        // Return a condensed version of the result for the Dart debug UI
        let statusText = '';
        if (result.errors) {
            statusText = `Errors: ${JSON.stringify(result.errors)}`;
        } else {
            statusText = `Recips: ${result.recipients || 0}, ID: ${result.id || 'N/A'}`;
        }

        console.log('Final Status Text:', statusText);
        console.log('--- PUSH NOTIFICATION REQUEST END ---');

        if (response.status !== 200) {
            return res.status(response.status).json({
                error: statusText,
                sentTo: playerIds,
                fullResponse: result
            });
        }

        return res.status(200).send(statusText);
    } catch (error) {
        console.error('FETCH EXCEPTION:', error);
        console.log('--- PUSH NOTIFICATION REQUEST END (FAILED) ---');
        return res.status(500).json({ error: 'Failed to send notification: ' + error.message });
    }
}
