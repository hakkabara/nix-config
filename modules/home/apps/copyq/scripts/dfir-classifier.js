var text = str(input()).trim()

var tags = []

if (text.length <= 1000000) {

    // MD5
    if (/^[a-fA-F0-9]{32}$/.test(text)) {
        tags.push('hash')
        tags.push('md5')
    }

    // SHA1
    if (/^[a-fA-F0-9]{40}$/.test(text)) {
        tags.push('hash')
        tags.push('sha1')
    }

    // SHA256
    if (/^[a-fA-F0-9]{64}$/.test(text)) {
        tags.push('hash')
        tags.push('sha256')
    }

    // SHA512
    if (/^[a-fA-F0-9]{128}$/.test(text)) {
        tags.push('hash')
        tags.push('sha512')
    }


    // IPv4
    var ipv4Parts = text.split('.')

    if (ipv4Parts.length === 4) {

        var validIPv4 = true

        for (var i = 0; i < 4; i++) {
            var value = Number(ipv4Parts[i])

            if (isNaN(value) || value < 0 || value > 255) {
                validIPv4 = false
            }
        }

        if (validIPv4) {
            tags.push('network')
            tags.push('ipv4')
        }
    }


    // IPv6
    if (
        text.indexOf(':') !== -1 &&
        text.indexOf(' ') === -1
    ) {

        var ipv6Parts = text.split(':')

        if (ipv6Parts.length >= 3) {

            var validIPv6 = true

            for (var i = 0; i < ipv6Parts.length; i++) {

                if (ipv6Parts[i].length > 4) {
                    validIPv6 = false
                }

                if (!/^[a-fA-F0-9]*$/.test(ipv6Parts[i])) {
                    validIPv6 = false
                }
            }

            if (validIPv6) {
                tags.push('network')
                tags.push('ipv6')
            }
        }
    }


    // URL
    if (
        text.indexOf('http://') === 0 ||
        text.indexOf('https://') === 0
    ) {
        tags.push('network')
        tags.push('url')

        if (text.indexOf('https://') === 0) {
            tags.push('https')
        }

        if (text.indexOf('http://') === 0) {
            tags.push('http')
        }
    }


    // Email
    if (
        text.indexOf(' ') === -1 &&
        text.indexOf('@') > 0
    ) {

        var emailParts = text.split('@')

        if (emailParts.length === 2) {

            var user = emailParts[0]
            var domain = emailParts[1]

            if (
                user.length > 0 &&
                domain.indexOf('.') > 0
            ) {

                tags.push('identity')
                tags.push('email')
                tags.push('network')
                tags.push('domain')
            }
        }
    }


    // Domain
    if (
        text.indexOf(' ') === -1 &&
        text.indexOf('/') === -1 &&
        text.indexOf(':') === -1 &&
        text.indexOf('@') === -1
    ) {

        var domainParts = text.split('.')
        var validDomain = true

        if (domainParts.length < 2) {
            validDomain = false
        }

        for (var i = 0; i < domainParts.length; i++) {

            var part = domainParts[i]

            if (part.length === 0) {
                validDomain = false
            }

            if (/^[0-9]+$/.test(part)) {
                validDomain = false
            }

            if (!/^[a-zA-Z0-9-]+$/.test(part)) {
                validDomain = false
            }
        }

        if (validDomain) {
            tags.push('network')
            tags.push('domain')
        }
    }


    // Linux paths
    if (
        text.indexOf('/') === 0 &&
        text.indexOf(' ') === -1
    ) {
        tags.push('file')
        tags.push('path')
        tags.push('linux')
    }


    // Windows paths
    if (
        text.length >= 3 &&
        text[1] === ':' &&
        text.indexOf('\\\\') !== -1
    ) {
        tags.push('file')
        tags.push('path')
        tags.push('windows')
    }
}

// Remove duplicate tags
var uniqueTags = []

for (var i = 0; i < tags.length; i++) {
    if (uniqueTags.indexOf(tags[i]) === -1) {
        uniqueTags.push(tags[i])
    }
}

// Sort tags
uniqueTags.sort()

if (uniqueTags.length > 0) {
    setData('application/x-copyq-tags', uniqueTags.join(','))
}

