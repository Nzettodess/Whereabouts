// Vercel serverless function to send OneSignal push notifications
export default async function handler(req, res) {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    const { playerIds, title, message, data } = req.body;
    console.log('Push request received for playerIds:', playerIds?.length);

    if (!playerIds || !Array.isArray(playerIds) || !message) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    const apiKey = process.env.ONESIGNAL_API_KEY;
    const appId = process.env.ONESIGNAL_APP_ID;

    if (!apiKey || !appId) {
        console.error('SERVER ERROR: Missing ONESIGNAL_API_KEY or ONESIGNAL_APP_ID');
        return res.status(500).json({ error: 'Server configuration error' });
    }

    try {
        const payload = {
            app_id: appId,
            // Use include_subscription_ids for modern OneSignal V16 Subscription IDs (UUIDs)
            include_subscription_ids: playerIds,
            headings: { en: title || 'Orbit' },
            contents: { en: message },
            data: data || {},
        };

        console.log('Sending OneSignal payload to:', JSON.stringify(playerIds));

        const response = await fetch('https://onesignal.com/api/v1/notifications', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Basic ${apiKey}`,
            },
            body: JSON.stringify(payload),
        });

        const result = await response.json();
        console.log('OneSignal API Result:', JSON.stringify(result));

        // Return a condensed version of the result for the Dart debug UI
        const statusText = result.errors ? `Errors: ${JSON.stringify(result.errors)}` : `Recips: ${result.recipients || 0}`;

        if (response.status !== 200) {
            console.error('OneSignal API Error Status:', response.status);
            // Include IDs and result in response for precise debugging in Dart UI
            return res.status(response.status).json({
                error: statusText,
                sentTo: playerIds,
                fullResponse: result
            });
        }

        return res.status(200).send(statusText);
    } catch (error) {
        console.error('Fetch error:', error);
        return res.status(500).json({ error: 'Failed to send notification' });
    }
}
