###
Very, very simple DOM manipulation.
###

class dom
    constructor: (selector, parent) ->
        parent = document if not parent
        @elements = [].slice.call parent.querySelectorAll selector

    get: (index = 0) ->
        @elements[index]

    value: (value) ->
        if value
            @each (el) ->
                if el.value
                    el.value = value
                else
                    el.innerHTML = value
        else
            @elements[0].value or @elements[0].innerHTML

    each: (fn, endFn) ->
        end = @elements.length - 1
        endFn() if end == -1 and endFn

        @elements.forEach (e, i) ->
            fn(e)
            endFn() if i == end and endFn
            return
        @

    on: (event, fn) ->
        @elements.forEach (element) ->
            element.addEventListener event, fn
        @

module.exports = (selector, parent = null) ->
    if selector[0] is '#'
        document.getElementById selector[1..]
    else
        new dom(selector, parent)

module.exports.ready = (fn) ->
    if document.readyState is 'interactive' or document.readyState is 'complete'
        fn()
    else
        document.addEventListener 'DOMContentLoaded', fn
    return

##
# decode html entities
#
module.exports.htmlDecode = (value) ->
    e = document.createElement 'div'
    e.innerHTML = value
    e.childNodes[0].nodeValue unless e.childNodes.length == 0

##
# encode html entities
#
module.exports.htmlEncode = (value) ->
    e = document.createElement 'div'
    e.appendChild document.createTextNode value
    e.innerHTML
