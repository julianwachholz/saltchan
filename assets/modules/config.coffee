# simple config holder

dom = require './dom'

USE_LOCALTIME = 'true' == localStorage.getItem 'config_localtime'
QUOTE_NOFOCUS = 'true' == localStorage.getItem 'config_quote_nofocus'
AUTO_UPDATE = 'true' == localStorage.getItem 'config_auto_update'


createSettings = ->
    div = document.createElement 'div'

    div.id = 'settings'
    div.innerHTML = """
    <h3>Settings</h3>
    <label><input type="checkbox" onchange="localStorage.setItem('config_localtime', this.checked)"
    #{if USE_LOCALTIME then 'checked' else ''}> Show times in my timezone</label><br>
    <label><input type="checkbox" onchange="localStorage.setItem('config_quote_nofocus', this.checked)"
    #{if QUOTE_NOFOCUS then 'checked' else ''}> Don't scroll down when quoting</label><br>
    <label><input type="checkbox" onchange="localStorage.setItem('config_auto_update', this.checked)"
    #{if AUTO_UPDATE then 'checked' else ''}> Auto-update threads</label><br>
    <p>Changes take effect after page reload.</p>
    <button onclick="settings()">Close</button>
    <button onclick="window.location.reload()">Reload</button>
    """
    document.body.appendChild(div)
    div


window.settings = ->
    settings = dom('#settings')
    if not settings
        settings = createSettings()
    settings.classList.toggle('visible')
    ga 'send', 'click', 'settings'
    return


##
# exported config variables
module.exports =
    USE_LOCALTIME: USE_LOCALTIME
    QUOTE_NOFOCUS: QUOTE_NOFOCUS
    AUTO_UPDATE: AUTO_UPDATE
