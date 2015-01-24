# image utilities used in saltchan
# sign and encrypt raw image data

dom = require './dom'
nacl = require './naclHelper'

INT_BYTES = 8  # but note that javascript only does 2^53


##
# load an image into a canvas and get its data base base64 encoded PNG
#
getImageBase64 = (img, encrypt, nonce, secret) ->
    c = document.createElement 'canvas'
    c.width = img.naturalWidth
    c.height = img.naturalHeight
    ctx = c.getContext '2d'
    ctx.drawImage img, 0, 0
    encryptImage c, ctx, nonce, secret if encrypt
    c.toDataURL 'image/png'


int2bytes = (x) ->
    if x > Number.MAX_SAFE_INTEGER
        window.formError "Image is too large to encrypt!"
        throw new Error "Integer is too large to be safe (>2^53)!"
    bytes = []
    i = INT_BYTES
    loop
        bytes[--i] = x & 0xff
        x = (x - bytes[i]) / 0x100
        break if not i
    bytes

bytes2int = (bytes) ->
    x = 0
    for byte, i in bytes
        x += byte
        if i < bytes.length - 1
            x = x * 0x100
    x

window.b2i = bytes2int
window.i2b = int2bytes


##
# remove alpha channel bits from an Uint8ClampedArray
# as returned by context.getImageData
#
removeAlpha = (arr, askAlpha) ->
    alphaConfirm = false

    if arr.length % 4 != 0
        throw new Error 'Cannot remove alpha channel from non-imagedata like array.'
    newArr = []
    for byte, i in arr
        if (i + 1) % 4 == 0
            if askAlpha and byte < 255 and not alphaConfirm
                alphaConfirm = confirm "We detected transparent pixels in this image. They will appear as black due to browser limitations. Continue?"
                if not alphaConfirm
                    throw new Error "User canceled encryption."
            continue
        newArr.push byte
    newArr


##
# re-add fully opaque alpha channel to Uint8ClampedArray
#
addAlpha = (arr) ->
    if arr.length % 3 != 0
        throw new Error 'Array length is not multiple of 3.'
    newArr = []
    for byte, i in arr
        newArr.push byte
        if (i + 1) % 3 == 0
            newArr.push 255
    newArr


encryptImage = (c, ctx, nonce, secret) ->
    imageData = ctx.getImageData 0, 0, c.width, c.height

    unclampedNoAlpha = new Uint8Array removeAlpha imageData.data, yes

    # we save the actual length of the encrypted data in the first few bytes
    encryptedData = nacl.secretbox unclampedNoAlpha, nonce, secret
    newData = new Uint8Array encryptedData.length + INT_BYTES
    newData.set int2bytes(encryptedData.length)
    newData.set encryptedData, INT_BYTES

    newWithAlpha = new Uint8ClampedArray addAlpha newData

    # encrypted data is slightly larger, so add some spacing here
    c.width += 1
    c.height += 1
    encryptedImageData = ctx.createImageData(c.width, c.height)
    encryptedImageData.data.set newWithAlpha
    ctx.putImageData encryptedImageData, 0, 0
    return


loadImage = (src, fn) ->
    img = new Image
    img.addEventListener 'load', -> fn img
    img.src = src
    return


module.exports.getImageData = ({file, encrypt, nonce, secret, callback} = {}) ->
    reader = new FileReader
    reader.addEventListener 'load', (event) ->
        if not /^image\//.test file.type
            window.formError 'This is not an image!'
            throw new Error
        loadImage event.target.result, (img) ->
            callback getImageBase64 img, encrypt, nonce, secret
    reader.readAsDataURL file
    return


module.exports.base64ToBlob = (base64) ->
    base64split = base64.split(',')
    mime = base64split[0].match(/^data:(.*?);base64$/)[1]
    data = atob base64split[1]
    bytes = []
    for byte in data
        bytes.push byte.charCodeAt 0
    new Blob [new Uint8Array bytes], type: mime


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


window.verifyImage = (e) ->
    e.innerHTML = 'Working...'
    e.onclick = null
    reply = e.parentNode.parentNode.parentNode
    image = dom('img', e.parentNode.parentNode).get()
    pubSign = reply.getAttribute 'data-pubsign'

    setTimeout ->
        base64 = getImageBase64 image
        valid = nacl.verifySignature base64, image.getAttribute('data-signature'), pubSign
        if valid
            e.removeAttribute 'href'
            e.innerHTML = "Valid signature from"
            e.appendChild nacl.getBadge pubSign
            e.parentNode.classList.add 'show-decrypt'
        else
            alert "Image has been tampered with!"
            e.onclick = -> verifyImage(this)
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


window.decryptImage = (e) ->
    e.innerHTML = 'Working...'
    e.onclick = null
    reply = e.parentNode.parentNode.parentNode
    image = dom('img', e.parentNode.parentNode).get()
    nonce = reply.getAttribute 'data-nonce'
    secret = reply.getAttribute 'data-secret'
    if not nonce or not secret
        alert "Can't decrypt this!"
        return
    setTimeout ->
        try
            image.src = decryptCanvas image, nonce, secret
        catch
            alert "Failed decrypting image!"
        finally
            e.parentNode.removeChild(e)
