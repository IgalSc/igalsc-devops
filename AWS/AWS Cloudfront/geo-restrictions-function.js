function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Paths that should return a fixed 200 response
    var fixedResponsePaths = [
        '/wp-login.php',
        '/xmlrpc.php',
        '/robots.txt',
        '/favicon.ico',
        '/wp-content',
    ];

    // Handle fixed 200 response for specific paths
    if (fixedResponsePaths.includes(uri)) {
        return {
            statusCode: 200,
            statusDescription: 'OK',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
    
    // Handle wildcard match for /wp-content/*
    if (uri.startsWith('/wp-content/')) {
        return {
            statusCode: 200,
            statusDescription: 'OK',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
    
    // Enforce geo-restriction for other paths
    var headers = request.headers;
    var countryCode = headers['cloudfront-viewer-country']
        ? headers['cloudfront-viewer-country'].value
        : 'UNKNOWN';

    // Allowed countries
    var allowedCountries = ['US', 'CA'];

    if (!allowedCountries.includes(countryCode)) {
        return {
            statusCode: 200,
            statusDescription: 'OK',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Due to video content digital rights, your country is restricted from accessing this app.'
        };
    }

    // Allow all other requests in allowed countries
    return request;
}