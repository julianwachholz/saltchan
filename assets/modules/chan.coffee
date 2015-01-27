# chan utils
# reply verification, encryption and decryption

dom = require './dom'
nacl = require './naclHelper'
imagelib = require './imagelib'
config = require './config'
qwest = require '../bower_components/qwest'

MAX_UPLOAD = 5 * 1024 * 1024

isThread = no
autoUpdateEnabled = no
toggleUpdate = null

currentForm = null
submitText = null


##
# sign & encrypt a submission if needed
#
formSubmit = (event) ->
    event.preventDefault()
    submitButton = dom('#form-submit')
    submitText = submitButton.innerHTML
    submitButton.innerHTML = 'Working...'
    text = dom('#form-text').value.cleanWhitespace()
    data = dom '#form-data'
    json = nacl.signReply text
    randomKey = null
    encrypt = no

    currentForm = @

    if dom('#form-encrypt')?.checked
        try
            recipientKeys = getQuotedPublicKeys json.pubkey, text
        catch
            formError 'No recipients for encrypted reply.'
            return
        encrypt = yes
        randomKey = nacl.randomKey()
        payload = JSON.stringify text: json.text, signature: json.signature
        encryptObj = nacl.encryptReply recipientKeys, randomKey, payload
        json.text = JSON.stringify encryptObj
        json.signature = 'ENCRYPTED'

    fileInput = dom('#form-file')
    if fileInput?.files.length > 0
        imagelib.getImageData
            file: fileInput.files[0]
            encrypt: encrypt
            nonce: encryptObj?.nonce
            secret: randomKey
            callback: (base64) ->
                json.file_signature = nacl.sign base64
                if encrypt
                    file = imagelib.base64ToBlob base64
                else file = fileInput.files[0]
                data.value = JSON.stringify json
                ga 'send', (if isThread then 'thread' else 'reply'), 'image'
                ga 'send', 'reply', 'image-encrypted' if encrypted
                ajaxReply file, imagelib.filename(file.type, fileInput.files[0].name)
                return
    else
        data.value = JSON.stringify json
        ga 'send', (if isThread then 'thread' else 'reply'), 'text'
        ga 'send', 'reply', 'text-encrypted' if encrypted
        ajaxReply()
    return


formError = (error) ->
    dom('#form-submit').innerHTML = submitText
    if error
        currentForm.classList.add 'error'
        dom('.error-message', currentForm).value error
    else
       currentForm.classList.remove 'error'

window.formError = formError


ajaxReply = (file, filename) ->
    data = new FormData
    for input in currentForm
        if input.name
            data.append input.name, input.value

    if file
        if file.size > MAX_UPLOAD
            formError "File is too large!"
            return
        data.append 'file', file, filename

    qwest.post window.location.pathname, data
    .then (json) ->
        if json?.location and not isThread
            window.location = json.location
        if json?.error
            formError json.error
        else
            formError no
            input.value = '' for input in currentForm
            if isThread
                window.update(-> window.location = json.location; return)
                if autoUpdateEnabled
                    toggleUpdate yes, 10
        return
    .catch (error) ->
        formError error
    return


##
# check all mentioned replies and add their public key to recipients
#
getQuotedPublicKeys = (myPublicKey, text) ->
    recipients = [myPublicKey]
    matches = text.match /(^| )>>(\d+)/gm

    if matches
        for match in matches
            publicKey = dom('#id' + match.replace '>>', '')
                .getAttribute 'data-pubkey'
            if publicKey not in recipients
                recipients.push publicKey

    if recipients.length < 2
        throw new Error unless dom('#meta-debug')
    ga 'send', 'reply', 'recipients', recipients.length
    recipients


##
# Reply formatting
#
String::cleanWhitespace = ->
    @replace /\n{2,}/g, '\n\n'
        .replace /\n+$/, ''

String::formatReply = ->
    @replace /(?:^|\b)&gt;&gt;&gt;(\d+)/gm, '<a href="$1">$&</a>'
        .replace /(?:^|\b)&gt;&gt;(\d+)/gm, '<a href="#id$1">$&</a>'
        .replace /^&gt;.*$/gm, '<q>$&</q>'


##
# quote a reply
#
window.quote = (id) ->
    text = dom '#form-text'
    text.value += ">>#{id}\n"
    text.focus() if not config.QUOTE_NOFOCUS
    ga 'send', 'click', 'quote', id
    return


##
# update thread
#
makeUpdateFunction = ->
    updateLinks = dom '.js-update'
    threadId = parseInt dom('#meta-thread').getAttribute 'value'
    replyCount = parseInt dom('#meta-start').getAttribute 'value'
    replyList = dom '#js-reply-list'
    threadReplies = dom '.js-thread-replies'
    replyText = (->
        singular = threadReplies.get().getAttribute 'data-singular'
        plural = threadReplies.get().getAttribute 'data-plural'
        (n) -> n + ' ' + if n == 1 then singular else plural
    )()

    (fn) ->
        updateLinks.each (link) ->
            link.innerHTML = 'Loading...'
            link.href = 'javascript:false'
        ga 'send', 'click', 'update', threadId if not fn

        qwest.get  window.location.pathname + "?start=#{replyCount}"
        .then (data) ->
            replyCount = parseInt data.thread_replies
            threadReplies.value replyText data.thread_replies
            data.replies.forEach (reply) ->
                replyList.appendChild makeReplyNode reply
            updateLinks.each (link) ->
                link.innerHTML = 'Update'
                link.href = 'javascript:update()'
            if fn
                fn(data.replies.length)
                toggleUpdate autoUpdateEnabled
            else
                toggleUpdate autoUpdateEnabled, if data.replies.length > 0 then 10 else 0
        return


##
# toggle thread auto updating
#
makeToggleUpdateFunction = ->
    autoNodes = dom '.js-autoupdate'
    toggles = dom '.js-autoupdate-checkbox'
    currentTimeout = 10
    timer = null

    toggles.on 'click', () ->
        ga 'send', 'click', 'autoupdate'
        currentTimeout = 10
        toggleUpdate @checked

    updateCountdown = (n) ->
        if n > 0
            autoNodes.value "Auto (#{n})"
            timer = setTimeout (-> updateCountdown n - 1), 1e3
        else
            autoNodes.value "Auto (...)"
            window.update (newReplies) ->
                if newReplies == 0
                    currentTimeout += Math.round currentTimeout / 2
                else
                    currentTimeout = Math.min 20, Math.round currentTimeout / newReplies
                currentTimeout = Math.min 180, currentTimeout
                currentTimeout = Math.max 5, currentTimeout
        return

    toggleUpdate = (checked, newTimeout) ->
        if newTimeout
            currentTimeout = newTimeout
        if timer
            clearTimeout timer
        toggles.each (e) -> e.checked = checked
        if checked
            autoUpdateEnabled = yes
            updateCountdown currentTimeout
        else
            autoUpdateEnabled = no
            autoNodes.value "Auto"
        return

    toggleUpdate


##
# Create a reply DOM element
#
makeReplyNode = (reply) ->
    el = document.createElement 'article'
    el.id = "id#{reply.id}"
    el.className = 'js-reply'
    el.setAttribute 'data-signature', reply.data.signature
    el.setAttribute 'data-pubsign', reply.data.pubsign
    el.setAttribute 'data-pubkey', reply.data.pubkey
    el.innerHTML = """
    <div class="info">
      <time>#{reply.date}</time>
      <span class="badge">#{reply.data.pubsign[..9]}</span>
      <span class="replyid">
        <a href="#id#{reply.id}">No.</a><a href="javascript:quote(#{reply.id})">#{reply.id}</a>
      </span>
    </div>
    """
    if reply.data?.file
        el.innerHTML += """
        <figure class="reply-file">
          <figcaption>
            <a href="/files/#{reply.data.file_url}" target="_blank">#{reply.data.file}</a>
          </figcaption>
          <img src="/files/#{reply.data.file_url}" onclick="this.parentNode.classList.toggle('expand')"
               data-signature="#{reply.data.file_signature}">
          <figcaption class="file-tools">
            <a href="javascript:" onclick="verifyImage(this)">Verify</a>
            #{if reply.data.signature == 'ENCRYPTED' then '<a href="javascript:" onclick="decryptImage(this)" class="js-file-decrypt">Decrypt</a>' else ''}
          </figcaption>
        </figure>
        """
    el.innerHTML += """<p class="reply-text js-text">#{reply.data.text}</p>"""
    if reply.data.signature == 'ENCRYPTED'
        el.classList.add 'encrypted'
        el.innerHTML += '<p class="encrypted-info"><em class="meta">Encrypted message.</em></p>'
    formatReply(el)
    el


##
# format a reply, decrypting it if needed
#
formatReply = (reply) ->
    try decryptReply reply
    signature = nacl.getSignature reply
    publicKey = nacl.getSignPublicKey reply
    text = dom('.js-text', reply)
    info = dom('.info', reply).get()
    badge = nacl.getBadge publicKey
    if nacl.verifySignature dom.htmlDecode(text.value()), signature, publicKey
        info.replaceChild badge, dom('.badge', reply).get()
    if config.USE_LOCALTIME
        timeNode = dom('time', reply).get()
        timeNode.innerHTML = formatDateTime new Date timeNode.innerHTML
    text.value text.value().cleanWhitespace().formatReply()
    return


formatDateTime = (date) ->
    "#{date.getFullYear()}-#{if date.getMonth() < 9 then '0' else ''}#{date.getMonth()+1}-#{date.getDate()}" +
    "T#{if date.getHours() < 10 then '0' else ''}#{date.getHours()}" +
    ":#{if date.getMinutes() < 10 then '0' else ''}#{date.getMinutes()}" +
    ":#{if date.getSeconds() < 10 then '0' else ''}#{date.getSeconds()}"


decryptReply = (reply) ->
    json = nacl.decryptReply reply
    reply.classList.remove 'encrypted'
    reply.setAttribute 'data-signature', json.signature
    dom('.reply-text', reply).value dom.htmlEncode json.text


module.exports.ready = ->
    if threadId = dom '#meta-thread'
        isThread = yes
        nacl.initThread threadId.getAttribute 'value'
        window.update = makeUpdateFunction()
        toggleUpdate = makeToggleUpdateFunction()
        toggleUpdate yes if config.AUTO_UPDATE

    dom '.js-reply'
        .each formatReply, () ->
            document.documentElement.className = ''
            return

    dom '.js-form'
        .on 'submit', formSubmit

    return
