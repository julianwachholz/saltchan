# chan utils
# posts verification, encryption and decryption

dom = require './dom'
nacl = require './naclHelper'


##
# sign & encrypt a submission if needed
#
formSubmit = (event) ->
    event.preventDefault()
    text = dom('#form-text').value.cleanWhitespace()
    data = dom '#form-data'

    json = nacl.signPost text
    if dom('#form-encrypt')?.checked
        try recipientKeys = getQuotedPublicKeys json.pubkey, text
        json.text = nacl.encryptPost recipientKeys, json.text, json.signature
        json.signature = 'ENCRYPTED'
    data.value = JSON.stringify json
    @submit()
    return


##
# check all mentioned posts and add their public key to recipients
#
getQuotedPublicKeys = (myPublicKey, text) ->
    recipients = [myPublicKey]
    matches = text.match /(^| )>>(\d+)/gm

    for match in matches
        publicKey = dom('#id' + match.replace '>>', '')
            .getAttribute 'data-pubkey'
        if publicKey not in recipients
            recipients.push publicKey

    if recipients.length < 2 and not confirm "No recipients found, only you will be able to read this.\nContinue?"
        throw new Error()

    recipients

##
# Post formatting
#
String::cleanWhitespace = ->
    @replace /\n{2,}/g, '\n\n'
        .replace /\n+$/, ''

String::quoteLinks = ->
    @replace /(?:^|\b)&gt;&gt;&gt;(\d+)/gm, '<a href="$1">$&</a>'
        .replace /(?:^|\b)&gt;&gt;(\d+)/gm, '<a href="#id$1">$&</a>'


##
# quote a post in your reply
#
quoteReply = (event) ->
    event.preventDefault()
    text = dom '#form-text'
    replyId = @getAttribute 'data-id'
    text.value += ">>#{replyId}\n"
    text.focus()
    return


##
# format a post, decrypting it if needed
#
formatPost = (post) ->
    try decryptPost post
    signature = nacl.getSignature post
    publicKey = nacl.getSignPublicKey post
    text = dom('.js-text', post)
    info = dom('.info', post).get()
    badge = nacl.getBadge(publicKey)
    if nacl.verifySignature dom.htmlDecode(text.value()), signature, publicKey
        info.replaceChild badge, dom('.badge', post).get()
    text.value text.value().cleanWhitespace().quoteLinks()
    return


decryptPost = (post) ->
    json = nacl.decryptPost post
    post.classList.remove 'encrypted'
    post.setAttribute 'data-signature', json.signature
    dom('.reply-text', post).value dom.htmlEncode json.text


module.exports.ready = ->
    if threadId = dom '#meta-thread'
        nacl.initThread threadId.getAttribute 'value'

    dom '.js-reply'
        .on 'click', quoteReply

    dom '.js-post'
        .each formatPost

    dom '.js-form'
        .on 'submit', formSubmit

    return
