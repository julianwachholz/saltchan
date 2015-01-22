# chan utils
# reply verification, encryption and decryption

dom = require './dom'
nacl = require './naclHelper'
config = require './config'
ajax = require '../bower_components/reqwest'


##
# sign & encrypt a submission if needed
#
formSubmit = (event) ->
    event.preventDefault()
    text = dom('#form-text').value.cleanWhitespace()
    data = dom '#form-data'

    json = nacl.signReply text
    if dom('#form-encrypt')?.checked
        try
            recipientKeys = getQuotedPublicKeys json.pubkey, text
        catch
            return
        json.text = nacl.encryptReply recipientKeys, json.text, json.signature
        json.signature = 'ENCRYPTED'
    data.value = JSON.stringify json
    @submit()
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

    if recipients.length < 2 and not confirm "No recipients found, only you will be able to read this.\nContinue?"
        throw new Error()

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
quoteReply = (event) ->
    event.preventDefault()
    text = dom '#form-text'
    replyId = @getAttribute 'data-id'
    text.value += ">>#{replyId}\n"
    text.focus() if not config.QUOTE_NOFOCUS
    return


##
# update thread
#
makeUpdateFunction = () ->
    replyCount = parseInt dom('#meta-start').getAttribute 'value'
    replyList = dom '#js-reply-list'
    threadReplies = dom '.js-thread-replies'

    ->
        get = location + "?start=#{replyCount}"
        ajax url: get, success: (data) ->
            replyCount = parseInt data.thread_replies
            threadReplies.value data.thread_replies
            data.replies.forEach (reply) ->
                replyList.appendChild makeReplyNode reply
        return


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
        <a href="#id#{reply.id}">No.</a><a class="js-quote" data-id="#{reply.id}" href="#">#{reply.id}</a>
      </span>
    </div>
    <p class="reply-text js-text">#{reply.data.text}</p>
    """
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
        localTime = new Date(Date.parse(timeNode.innerHTML) - (new Date().getTimezoneOffset() * 1e3 * 60))
        timeNode.innerHTML = formatDateTime localTime
    text.value text.value().cleanWhitespace().formatReply()
    return


formatDateTime = (date) ->
    "#{date.getFullYear()}-#{if date.getMonth() < 9 then '0' else ''}#{date.getMonth()+1}-#{date.getDate()} " +
    "#{if date.getHours() < 10 then '0' else ''}#{date.getHours()}" +
    ":#{if date.getMinutes() < 10 then '0' else ''}#{date.getMinutes()}" +
    ":#{if date.getSeconds() < 10 then '0' else ''}#{date.getSeconds()}"


decryptReply = (reply) ->
    json = nacl.decryptReply reply
    reply.classList.remove 'encrypted'
    reply.setAttribute 'data-signature', json.signature
    dom('.reply-text', reply).value dom.htmlEncode json.text


module.exports.ready = ->
    if threadId = dom '#meta-thread'
        nacl.initThread threadId.getAttribute 'value'
        window.update = makeUpdateFunction()

    dom '.js-quote'
        .on 'click', quoteReply

    dom '.js-reply'
        .each formatReply, () ->
            document.documentElement.className = ''
            return

    dom '.js-form'
        .on 'submit', formSubmit

    return
