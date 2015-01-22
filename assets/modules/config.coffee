# simple config holder

dom = require './dom'

USE_LOCALTIME = 'true' == localStorage.getItem 'config_localtime'
QUOTE_NOFOCUS = 'true' == localStorage.getItem 'config_quote_nofocus'


createSettings = ->
    div = document.createElement 'div'

    div.id = 'settings'
    div.innerHTML = """
    <h3>Settings</h3>
    <label><input type="checkbox" onchange="localStorage.setItem('config_localtime', this.checked)"
    #{if USE_LOCALTIME then 'checked' else ''}> Show times in my timezone</label><br>
    <label><input type="checkbox" onchange="localStorage.setItem('config_quote_nofocus', this.checked)"
    #{if QUOTE_NOFOCUS then 'checked' else ''}> Don't scroll down when quoting</label><br>
    <p>Changes take effect after page reload.</p>
    <a href="javascript:settings()">Close</a>
    <a href="javascript:location=location">Reload</a>
    """
    document.body.appendChild(div)
    div


window.settings = ->
    settings = dom('#settings')
    if not settings
        settings = createSettings()
    settings.classList.toggle('visible')
    return


##
# exported config variables
module.exports =
    USE_LOCALTIME: USE_LOCALTIME
    QUOTE_NOFOCUS: QUOTE_NOFOCUS
