# saltchan main script
dom = require './modules/dom'
#config = require './modules/config'
nacl = require './bower_components/tweetnacl/nacl-fast.min'

form = require './modules/form'
#reply = require './modules/reply'


String::cleanWhitespace = ->
    @replace /\n{2,}/g, '\n\n'  # truncate multiple linebreaks
        .replace /\n+$/, ''     # remove trailing whitespace
        .trim()

# String::formatReply = ->
#     @replace /(?:^|\b)&gt;&gt;&gt;(\d+)/gm, '<a href="$1">$&</a>'
#         .replace /(?:^|\b)&gt;&gt;(\d+)/gm, '<a href="#id$1">$&</a>'
#         .replace /^&gt;.*$/gm, '<q>$&</q>'


class Chan

    constructor: (@threadId) ->
        @keyManager = new KeyManager @threadId
        @setupForm()

    setupForm: ->
        @form = new form.Form dom('#form'), @keyManager
        return


class KeyManager

    SIGN_PREFIX = 'sign-'
    BOX_PREFIX = 'box-'

    constructor: (@threadId) ->
        if @threadId
            @keys = @checkLocalStorage()

    getKeys: ->
        if not @keys
            @keys = @generateKeys()
            @saveKeys() if @threadId
        @keys

    generateKeys: ->
        sign: nacl.sign.keyPair()
        box: nacl.box.keyPair()

    signStorageKey: -> SIGN_PREFIX + @threadId
    boxStorageKey: -> BOX_PREFIX + @threadId

    checkLocalStorage: ->
        debugger
        signBase64 = localStorage.getItem @signStorageKey()
        boxBase64 = localStorage.getItem @boxStorageKey()

        if signBase64 and boxBase64
            sign: nacl.sign.keyPair.fromSecretKey nacl.util.decodeBase64 signBase64
            box: nacl.box.keyPair.fromSecretKey nacl.util.decodeBase64 boxBase64

    saveKeys: (threadId = null) ->
        if threadId
            @threadId = threadId
        debugger
        signBase64 = nacl.util.encodeBase64 @keys.sign.secretKey
        boxBase64 = nacl.util.encodeBase64 @keys.box.secretKey
        localStorage.setItem @signStorageKey(), signBase64
        localStorage.setItem @boxStorageKey(), boxBase64
        return


dom.ready ->
    DEBUG = !!dom('#meta-debug')?.getAttribute('value')
    threadId = dom('#meta-thread')?.getAttribute('value')
    new Chan threadId
    return
