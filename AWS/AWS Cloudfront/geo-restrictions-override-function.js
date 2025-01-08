//A function to bypass geo-restriction for specific files and enforce geo-restriction for other paths

function handler(event) {
    var request = event.request;
    var uri = request.uri;
    var headers = request.headers;

    // Bypass geo-restriction for specific files
    if (uri === '/ads.txt' || uri === '/app-ads.txt') {
        return request; // Allow access from anywhere
    }

    // Enforce geo-restriction for other paths
    var countryCode = headers['cloudfront-viewer-country']
        ? headers['cloudfront-viewer-country'].value
        : 'UNKNOWN';

    // Allowed countries
    var allowedCountries = ['US', 'CA'];

    if (!allowedCountries.includes(countryCode)) {
        return {
            statusCode: 403,
            statusDescription: 'Forbidden',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Access denied. Your country is restricted.'
        };
    }

    // Allow all other requests in allowed countries
    return request;
}