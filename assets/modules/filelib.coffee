# image utilities used in saltchan
# sign and encrypt raw image data

dom = require './dom'
nacl = require './naclHelper'
qwest = require '../bower_components/qwest'


# magic bytes for currently accepted file types
FILE_SIGNATURES =
    'image/jpg': [[0xff, 0xd8, 0xff, 0xe0]]
    'image/png': [[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]]
    'image/gif': [[0x47, 0x49, 0x46, 0x38, 0x37, 0x61], [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]]


guessMime = (data) ->
    for mime, signatures of FILE_SIGNATURES
        for signature in signatures
            compare = data.subarray(0, signature.length)
            for byte, i in signature
                if byte != compare[i]
                    break
                return mime
    null


module.exports.getData = ({file, error, success} = {}) ->
    reader = new FileReader
    reader.addEventListener 'load', (event) ->
        data = new Uint8Array event.target.result
        mime = guessMime data
        if mime is null
            error 'This does not look like an image.'
        else
            success mime, data
    reader.readAsArrayBuffer file
    return


MIME_EXTS =
    'image/png': 'png'
    'image/jpg': 'jpg'
    'image/jpeg': 'jpg'
    'image/gif': 'gif'


module.exports.filename = (mime, filename) ->
    name = filename.split '.'
    name.pop()
    name.push MIME_EXTS[mime] or 'png'
    name.join '.'


window.verify = (e) ->
    e.innerHTML = 'Working...'
    e.onclick = null
    reply = e.parentNode.parentNode.parentNode
    image = dom('img', e.parentNode.parentNode).get()
    pubSign = reply.getAttribute 'data-pubsign'
    qwest.get image.src, null, cache: yes, responseType: 'arraybuffer'
    .then (buffer) ->
        dataMime = image.getAttribute 'data-mime'
        data = new Uint8Array buffer
        if dataMime != guessMime data
            alert "File is not what it looks like!"
            throw new Error 'Advertised MIME does not match received.'
        valid = nacl.verifySignature nacl.hash(data), image.getAttribute('data-signature'), pubSign
        if valid
            e.removeAttribute 'href'
            e.innerHTML = "Valid signature from"
            e.appendChild nacl.getBadge pubSign
            e.parentNode.classList.add 'show-decrypt'
        else
            ga 'send', 'nacl-image', 'verify-failed'
            alert "File has been tampered with!"
            e.innerHTML = "NOPE"
            e.onclick = -> verify(this)
        return
    return


decryptCanvas = (img, nonce, secret) ->
    c = document.createElement 'canvas'
    c.width = img.naturalWidth
    c.height = img.naturalHeight
    ctx = c.getContext '2d'
    ctx.drawImage img, 0, 0

    imageData = ctx.getImageData 0, 0, c.width, c.height
    unclamped = new Uint8Array removeAlpha imageData.data

    # the first INT_BYTES represent the actual length of the encrypted data
    # so we can ignore the rest of unnecessary transparent pixels
    encryptedLength = bytes2int unclamped.subarray(0, INT_BYTES)
    unclampedData = unclamped.subarray(INT_BYTES, INT_BYTES + encryptedLength)
    newData = nacl.secretboxOpen unclampedData, nonce, secret

    # remove previously added buffer from image
    c.width -= 1
    c.height -= 1
    decryptedImageData = ctx.createImageData(c.width, c.height)
    decryptedImageData.data.set new Uint8ClampedArray addAlpha newData
    ctx.putImageData decryptedImageData, 0, 0

    c.toDataURL 'image/png'


window.decrypt = (e) ->
    e.innerHTML = 'Working...'
    e.onclick = null
    reply = e.parentNode.parentNode.parentNode
    image = dom('img', e.parentNode.parentNode).get()
    nonce = reply.getAttribute 'data-nonce'
    secret = reply.getAttribute 'data-secret'
    if not nonce or not secret
        alert "Can't decrypt this!"
        ga 'send', 'nacl-image', 'decrypt-attempt'
        return
    setTimeout ->
        try
            image.src = decryptCanvas image, nonce, secret
        catch
            ga 'send', 'nacl-image', 'decrypt-failed'
            alert "Failed decrypting image!"
        finally
            e.parentNode.removeChild(e)
