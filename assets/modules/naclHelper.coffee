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
    decodedText = nacl.util.decodeUTF8 text
    try
        nacl.sign.detached.verify decodedText, signature, publicKey
    catch
        false


##
# get a colored badge for a publicKey
#
module.exports.getBadge = (publicKey) ->
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
# returns an object with text, signature and publickeys
#
module.exports.signReply = (text) ->
    if not threadKeys
        generateNewKeys THREAD_NEW

    text: text
    pubkey: nacl.util.encodeBase64 threadKeys.box.publicKey
    pubsign: nacl.util.encodeBase64 threadKeys.sign.publicKey
    signature: nacl.util.encodeBase64 nacl.sign.detached nacl.util.decodeUTF8(text), threadKeys.sign.secretKey


##
# encrypt a reply for all recipients
#
module.exports.encryptReply = (recipientKeys, text, signature) ->
    data = []
    payload = nacl.util.decodeUTF8 JSON.stringify text: text, signature: signature

    for recipientKey in recipientKeys
        decodedKey = verifyAndDecodeBase64 nacl.box.publicKeyLength, recipientKey
        continue if not decodedKey

        nonce = nacl.randomBytes nacl.secretbox.nonceLength
        data.push
            key: recipientKey
            nonce: nacl.util.encodeBase64 nonce
            data: nacl.util.encodeBase64 nacl.box payload, nonce, decodedKey, threadKeys.box.secretKey

    return JSON.stringify data


##
# decrypt a reply
#
module.exports.decryptReply = (reply) ->
    theirPublicKey = verifyAndDecodeBase64 nacl.box.publicKeyLength, reply.getAttribute 'data-pubkey'
    myPublicKeyBase64 = nacl.util.encodeBase64 threadKeys.box.publicKey

    for data in JSON.parse dom.htmlDecode dom('.reply-text', reply).value()
        continue unless data.key == myPublicKeyBase64
        payload = nacl.box.open(
            nacl.util.decodeBase64 data.data
            verifyAndDecodeBase64(nacl.secretbox.nonceLength, data.nonce)
            theirPublicKey
            threadKeys.box.secretKey
        )
        if not payload
            throw new Error "Failed decrypting reply!"
        try
            return JSON.parse nacl.util.encodeUTF8 payload
        catch e
            throw new Error "Failed encoding decrypted reply!"
    throw new Error "Not encrypted for you!"
