# tweetnacl helpers

dom = require './dom'
nacl = require '../bower_components/tweetnacl/nacl-fast.min'


THREAD_NEW = 'THREAD_NEW'
KEYS_SIGN = 'sign-'
KEYS_BOX = 'box-'

##
# keys used in the current thread
#
threadKeys = null


##
# decode a base64 encoded string of an expected length
#
verifyAndDecodeBase64 = (expected, base64) ->
    try
        s = nacl.util.decodeBase64 base64
        return s unless s.length != expected
    catch
        false


##
# generate new keypairs for the given id
generateNewKeys = (threadId) ->
    threadKeys =
        sign: nacl.sign.keyPair()
        box: nacl.box.keyPair()
    localStorage.setItem KEYS_SIGN + threadId, nacl.util.encodeBase64 threadKeys.sign.secretKey
    localStorage.setItem KEYS_BOX + threadId, nacl.util.encodeBase64 threadKeys.box.secretKey
    return


##
# decrypt the private keys for the current thread or generate new ones
#
module.exports.initThread = (threadId) ->
    if newSignKey = localStorage.getItem KEYS_SIGN + THREAD_NEW
        localStorage.setItem KEYS_SIGN + threadId, newSignKey
        localStorage.setItem KEYS_BOX + threadId, localStorage.getItem KEYS_BOX + THREAD_NEW
        localStorage.removeItem KEYS_SIGN + THREAD_NEW
        localStorage.removeItem KEYS_BOX + THREAD_NEW
    if signKey = localStorage.getItem KEYS_SIGN + threadId
        boxKey = localStorage.getItem KEYS_BOX + threadId
        threadKeys =
            sign: nacl.sign.keyPair.fromSecretKey verifyAndDecodeBase64 nacl.sign.secretKeyLength, signKey
            box: nacl.box.keyPair.fromSecretKey verifyAndDecodeBase64 nacl.box.secretKeyLength, boxKey
    return


##
# return the signature for a reply
#
module.exports.getSignature = (reply) ->
    signature = reply.getAttribute 'data-signature'
    return false if signature == 'ENCRYPTED'
    verifyAndDecodeBase64 nacl.sign.signatureLength, signature


##
# get the signing publicKey for this reply
#
module.exports.getSignPublicKey = (reply) ->
    verifyAndDecodeBase64 nacl.sign.publicKeyLength, reply.getAttribute 'data-pubsign'


##
# verify a signed reply
#
module.exports.verifySignature = (text, signature, publicKey) ->
    return false if signature is false
    decodedText = nacl.util.decodeUTF8 text
    if typeof signature == 'string'
        signature = verifyAndDecodeBase64 nacl.sign.signatureLength, signature
    if typeof publicKey == 'string'
        publicKey = verifyAndDecodeBase64 nacl.sign.publicKeyLength, publicKey
    try
        nacl.sign.detached.verify decodedText, signature, publicKey
    catch e
        ga 'send', 'nacl-errors', 'verify-failed', {nonInteraction: 1}
        false


##
# get a colored badge for a publicKey
#
module.exports.getBadge = (publicKey) ->
    if typeof publicKey == 'string'
        publicKey = verifyAndDecodeBase64 nacl.sign.publicKeyLength, publicKey

    keyLength = publicKey.length
    colorOffset = Math.floor publicKey[0] / 255 * keyLength
    color = [
        publicKey[(colorOffset) % keyLength]
        publicKey[(colorOffset + 1) % keyLength]
        publicKey[(colorOffset + 2) % keyLength]
    ]
    textIsWhite = 125 >= Math.round ((parseInt(color[0]) * 299) + (parseInt(color[1]) * 587) + (parseInt(color[2]) * 114)) / 1000

    badge = document.createElement 'span'
    badge.innerHTML = nacl.util.encodeBase64(publicKey)[..9]
    badge.style.backgroundColor = "rgb(#{color.join(',')})"
    badge.classList.add 'badge'
    badge.classList.add 'text-white' if textIsWhite

    badge


##
# returns the signature of text data
#
module.exports.sign = signDetached = (text) ->
    if not threadKeys
        generateNewKeys THREAD_NEW
    nacl.util.encodeBase64 nacl.sign.detached nacl.util.decodeUTF8(text), threadKeys.sign.secretKey


##
# returns an object with text, signature and publickeys
#
module.exports.signReply = (text) ->
    if not threadKeys
        generateNewKeys THREAD_NEW

    text: text
    pubkey: nacl.util.encodeBase64 threadKeys.box.publicKey
    pubsign: nacl.util.encodeBase64 threadKeys.sign.publicKey
    signature: signDetached text


##
# generate a random secret
#
module.exports.randomKey = -> nacl.randomBytes nacl.secretbox.keyLength


##
# symmetric encryption
#
module.exports.secretbox = (data, nonce, secret) ->
    if typeof data == 'string'
        data = nacl.util.decodeUTF8 data
    if typeof nonce == 'string'
        nonce = verifyAndDecodeBase64 nacl.secretbox.nonceLength, nonce
    if typeof secret == 'string'
        secret = verifyAndDecodeBase64 nacl.secretbox.keyLength, secret
    nacl.secretbox data, nonce, secret

##
# symmetric decryption
#
module.exports.secretboxOpen = (data, nonce, secret) ->
    if typeof nonce == 'string'
        nonce = verifyAndDecodeBase64 nacl.secretbox.nonceLength, nonce
    if typeof secret == 'string'
        secret = verifyAndDecodeBase64 nacl.secretbox.keyLength, secret
    nacl.secretbox.open data, nonce, secret


##
# encrypt a reply for all recipients
#
module.exports.encryptReply = (recipientKeys, secret, payload) ->
    nonce = nacl.randomBytes nacl.secretbox.nonceLength
    data =
        recipients: []
        nonce: nacl.util.encodeBase64 nonce
        payload: nacl.util.encodeBase64 nacl.secretbox nacl.util.decodeUTF8(payload), nonce, secret

    for recipientKey in recipientKeys
        decodedKey = verifyAndDecodeBase64 nacl.box.publicKeyLength, recipientKey
        continue if not decodedKey

        recipientNonce = nacl.randomBytes nacl.secretbox.nonceLength
        data.recipients.push
            key: recipientKey
            nonce: nacl.util.encodeBase64 recipientNonce
            secret: nacl.util.encodeBase64 nacl.box secret, recipientNonce, decodedKey, threadKeys.box.secretKey

    return data


##
# decrypt a reply
#
module.exports.decryptReply = (reply) ->
    theirPublicKey = verifyAndDecodeBase64 nacl.box.publicKeyLength, reply.getAttribute 'data-pubkey'
    myPublicKeyBase64 = nacl.util.encodeBase64 threadKeys.box.publicKey

    data = JSON.parse dom.htmlDecode dom('.reply-text', reply).value()
    for recipient in data.recipients
        continue unless recipient.key == myPublicKeyBase64
        secret = nacl.box.open(
            nacl.util.decodeBase64 recipient.secret
            verifyAndDecodeBase64(nacl.secretbox.nonceLength, recipient.nonce)
            theirPublicKey
            threadKeys.box.secretKey
        )
        if not secret
            ga 'send', 'nacl-errors', 'decrypt-attempt', {nonInteraction: 1}
            throw new Error "Failed decrypting reply!"
        try
            reply.setAttribute 'data-nonce', data.nonce
            reply.setAttribute 'data-secret', nacl.util.encodeBase64 secret
            return JSON.parse nacl.util.encodeUTF8 nacl.secretbox.open(
                nacl.util.decodeBase64 data.payload
                verifyAndDecodeBase64(nacl.secretbox.nonceLength, data.nonce)
                secret
            )
        catch
            ga 'send', 'nacl-errors', 'decrypt-failed', {nonInteraction: 1}
            throw new Error "Failed opening secret box!"
    throw new Error "Not encrypted for you!"
