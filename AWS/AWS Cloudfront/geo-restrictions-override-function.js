//A function to bypass geo-restriction for specific files and enforce geo-restriction for other paths

function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Paths that should return a fixed 301 response
    var fixedResponsePaths = [
        '/wp-login.php',
        '/xmlrpc.php',
        '/robots.txt',
        '/favicon.ico',
        '/wp-content',
        '/NewFile.php',
        '/heh.php',
        '/sellers.json',
        '/help',
        '/yukki',
        '/apple-touch-icon-precomposed.png',
        '/apple-touch-icon.png',
        '/security.txt',
        '/wp-ver.php',
        '/apple-touch-icon-152x152.png',
        '/apple-touch-icon-152x152-precomposed.png',
        '/login'
    ];

    // Handle fixed 301 response for specific paths
    if (fixedResponsePaths.includes(uri)) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
    
    // Handle wildcard match for /wp-content/*
    if (uri.startsWith('/wp-content/')) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
    
    // Handle wildcard match for //*
    if (uri.startsWith('//')) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
    
    // Handle wildcard match for /wp-admin/*
    if (uri.startsWith('/wp-admin/')) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
    
    // Handle wildcard match for /.well-known/*
    if (uri.startsWith('/.well-known/')) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
    
    // Handle wildcard match for /api/*
    if (uri.startsWith('/api/')) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
  
        // Handle wildcard match for /admin/*
    if (uri.startsWith('/admin/')) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'content-type': { value: 'text/plain' }
            },
            body: 'Nothing to see here'
        };
    }
    
    // Handle wildcard match for /vendor/*
    if (uri.startsWith('/vendor/')) {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
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