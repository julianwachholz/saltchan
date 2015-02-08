###
saltchan reply form
###
dom = require './dom'
qwest = require '../bower_components/qwest'
nacl = require '../bower_components/tweetnacl/nacl-fast.min'


TEXT =
    DEFAULT: 'Post'
    PROGRESS: 'Working...'


class Form

    constructor: (@form, @keyManager) ->
        if @form
            @collectInputs()
            @bindEvents()

    collectInputs: ->
        @mode = @form.getAttribute 'data-mode'
        @errorMessage = dom '#error'
        @submitButton = dom '#submit'
        @inputs =
            subject: dom '#subject'
            comment: dom '#comment'
            file: dom '#file'
            encrypt: dom '#encrypt'
        return

    bindEvents: ->
        @form.addEventListener 'submit', @submit.bind @
        return

    error: (error) ->
        @submitButton.innerHTML = TEXT.DEFAULT
        if error
            @form.classList.add 'error'
            @errorMessage.innerHTML = error
        else
            @form.classList.remove 'error'
        return

    submit: (event) ->
        event.preventDefault()
        @submitButton.innerHTML = TEXT.PROGRESS
        @error false

        try
            reply = new ReplyForm
                comment: @inputs.comment.value
                subject: @inputs.subject.value
            reply.validate @mode
            reply.setKeys @keyManager.getKeys()
            reply.signComment()
        catch e
            @error e

        @ajaxReply reply

        @submitButton.innerHTML = TEXT.DEFAULT
        return

    ajaxReply: (reply) ->
        xhrData = new FormData
        xhrData.append 'data', JSON.stringify reply.getData()

        qwest.post window.location.pathname, xhrData
        .then (json) =>
            if json?.location and '#' not in json.location
                threadMatch = json.location.match /\/(\w+)\/thread\/(\d+)/
                @keyManager.saveKeys threadMatch[1] + '-' + threadMatch[2]
                window.location = json.location
            if json?.error
                @error json.error
            else
                @error false
                input.value = '' for input in currentForm
                if isThread
                    window.update(-> window.location = json.location; return)
                    if autoUpdateEnabled
                        toggleUpdate true, 10
            return
        .catch (error) =>
            @error error
        return


module.exports.Form = Form


class ReplyForm

    constructor: ({@comment, @subject} = {subject: null}) ->
        @sanitize()

    sanitize: ->
        @comment = @comment.cleanWhitespace()
        @subject = @subject.cleanWhitespace() if @subject
        return

    validate: (mode) ->
        if mode == 'thread'
            if not @comment and not @subject
                throw new Error "Either comment or subject is required."

    setKeys: (@keys) ->
        return

    signComment: (signKey) ->
        commentDecoded = nacl.util.decodeUTF8 @comment
        @commentSignature = nacl.sign.detached commentDecoded, @keys.sign.secretKey
        return

    getData: ->
        subject: @subject
        comment: @comment
        signature: nacl.util.encodeBase64 @commentSignature
        pubkey: nacl.util.encodeBase64 @keys.box.publicKey
        pubsign: nacl.util.encodeBase64 @keys.sign.publicKey
