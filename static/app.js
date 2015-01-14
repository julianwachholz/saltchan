/**
 * pgpchan
 */
(function (d) {
'use strict';

var threadKeys = {
    sign: null,
    box: null
};

function $(id) {
    return d.getElementById(id);
}

function submitThread(form) {
    // we need two keypairs, one for encryption and
    // another one for signing the message
    var boxKeyPair = nacl.box.keyPair(),
        signKeyPair = nacl.sign.keyPair(),

        // nonce = nacl.randomBytes(nacl.secretbox.nonceLength),
        text = $('form-text').value,
        data = $('form-data');

    data.value = JSON.stringify({
        message: text,
        signature: nacl.util.encodeBase64(nacl.sign.detached(nacl.util.decodeUTF8(text), signKeyPair.secretKey)),
        pubkey: nacl.util.encodeBase64(boxKeyPair.publicKey),
        pubsign: nacl.util.encodeBase64(signKeyPair.publicKey)
    });

    localStorage.setItem('new-thread', 'true');
    localStorage.setItem('box-new', nacl.util.encodeBase64(boxKeyPair.secretKey));
    localStorage.setItem('sign-new', nacl.util.encodeBase64(signKeyPair.secretKey));
    form.submit();
}

function submitReply(form) {
    if (!threadKeys.sign || !threadKeys.box) {
        throw new Error('No signing keys present or not ready!');
    }
    var text = $('form-text').value,
        data = $('form-data');

    data.value = JSON.stringify({
        message: text,
        signature: nacl.util.encodeBase64(nacl.sign.detached(nacl.util.decodeUTF8(text), threadKeys.sign.secretKey)),
        pubkey: nacl.util.encodeBase64(threadKeys.box.publicKey),
        pubsign: nacl.util.encodeBase64(threadKeys.sign.publicKey)
    });

    form.submit();
}

function decodeVerify(length, base64) {
    try {
        var s = nacl.util.decodeBase64(base64);
        if (s.length != length) {
            throw new Error('Invalid signature length.');
        }
        return s;
    } catch (e) {
        return false;
    }
}

function array2rgb(uint8) {
    var len = uint8.length,
        offset = Math.floor(uint8[0] / 255 * len);
    return [uint8[offset % len], uint8[(offset+1) % len], uint8[(offset+2) % len]];
}
function textColorWhite(rgb) {
    // see http://www.w3.org/TR/AERT#color-contrast
    var o = Math.round(((parseInt(rgb[0]) * 299) + (parseInt(rgb[1]) * 587) + (parseInt(rgb[2]) * 114)) /1000);
    return o <= 125;
}

function htmlDecode(value) {
    var e = d.createElement('div');
    e.innerHTML = value;
    return e.childNodes.length === 0 ? '' : e.childNodes[0].nodeValue;
}

function verifyPost(post) {
    var signature, pubkey, message, badge, badgecolor, infoEl, contentEl;

    signature = decodeVerify(nacl.sign.signatureLength, post.getAttribute('data-signature'));
    pubkey = decodeVerify(nacl.sign.publicKeyLength, post.getAttribute('data-pubsign'));
    contentEl = post.getElementsByClassName('reply-text')[0];
    message = nacl.util.decodeUTF8(htmlDecode(contentEl.innerHTML));

    badge = d.createElement('span');
    if (nacl.sign.detached.verify(message, signature, pubkey)) {
        badgecolor = array2rgb(pubkey);
        badge.className = 'badge verified';
        if (textColorWhite(badgecolor)) {
            badge.classList.add('dark');
        }
        badge.style.background = 'rgb(' + badgecolor.join(',') + ')';
        badge.innerHTML = post.getAttribute('data-pubsign').substring(0, 10);
    } else {
        badge.className = 'badge invalid';
        badge.innerHTML = 'INVALID';
    }
    infoEl = post.getElementsByClassName('info')[0];
    infoEl.replaceChild(badge, infoEl.getElementsByClassName('badge')[0]);

    formatPost(contentEl);
}

function formatPost(el) {
    var raw = el.innerHTML;
    el.innerHTML = raw
        // thread links
        .replace(/(?:^|\b)&gt;&gt;&gt;([0-9]+)/gm, '<a href="$1">$&</a>')
        // post links
        .replace(/(?:^|\b)&gt;&gt;([0-9]+)/gm, '<a href="#id$1">$&</a>');
}

function tryVerify(numTry) {
    if (!window.naclReady) {
        if (numTry > 10) {
            window.location = '/error/nacl/';
        } else {
            console.debug('nacl not ready, retrying #' + numTry);
            return setTimeout(function () {
                tryVerify(numTry + 1);
            }, 100);
        }
    }
    var posts = [].slice.call(d.querySelectorAll('.js-verify'));
    posts.forEach(function (post) {
        verifyPost(post);
    });
}

function initThread() {
    var thread = $('meta-thread').getAttribute('value');

    if (localStorage.getItem('new-thread')) {
        localStorage.setItem('box-' + thread, localStorage.getItem('box-new'));
        localStorage.setItem('sign-' + thread, localStorage.getItem('sign-new'));
        localStorage.removeItem('new-thread');
        localStorage.removeItem('box-new');
        localStorage.removeItem('sign-new');
    }
    if (!localStorage.getItem('sign-' + thread) || !localStorage.getItem('box-' + thread)) {
        threadKeys.box = nacl.box.keyPair();
        localStorage.setItem('box-' + thread, nacl.util.encodeBase64(threadKeys.box.secretKey));
        threadKeys.sign = nacl.sign.keyPair();
        localStorage.setItem('sign-' + thread, nacl.util.encodeBase64(threadKeys.sign.secretKey));
    } else {
        threadKeys.box = nacl.box.keyPair.fromSecretKey(decodeVerify(nacl.box.secretKeyLength, localStorage.getItem('box-' + thread)));
        threadKeys.sign = nacl.sign.keyPair.fromSecretKey(decodeVerify(nacl.sign.secretKeyLength, localStorage.getItem('sign-' + thread)));
    }
}

function initReply() {
    var replyLinks = [].slice.call(d.querySelectorAll('.js-reply')),
        quotePost;

    quotePost = function(event) {
        var text = $('form-text'), id = this.getAttribute('data-id');
        event.preventDefault();
        text.value += '>>' + id + '\n';
        text.focus();
    };
    replyLinks.forEach(function (link) {
        link.addEventListener('click', quotePost);
    });
}

function init() {
    var forms = [].slice.call(d.querySelectorAll('form[data-mode]'));
    forms.forEach(function (form) {
        form.addEventListener('submit', function submit(event) {
            var mode = this.getAttribute('data-mode');
            event.preventDefault();

            if (!naclReady) {
                console.error('tweetnacl not ready');
            }
            if (mode === 'thread') {
                submitThread(this);
            }
            if (mode === 'reply') {
                submitReply(this);
            }
        });
    });

    if ($('meta-thread')) {
        initThread();
        initReply();
    }

    tryVerify(1);
}

if(d.readyState === 'interactive' || d.readyState === 'complete') {
    init();
}
d.addEventListener('DOMContentLoaded', function () {
    init();
});

}(document));
