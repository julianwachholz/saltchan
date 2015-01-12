/**
 * pgpchan
 */
(function (d) {
'use strict';

function fieldFocus() {
    console.log('focused textarea');
}

function init() {
    var fields = [].slice.call(d.querySelectorAll('textarea[data-mode]'));
    fields.forEach(function (field) {
        field.addEventListener('focus', fieldFocus);
    });
}

if(d.readyState === 'interactive' || d.readyState === 'complete') {
    init();
}
d.addEventListener('DOMContentLoaded', function () {
    init();
});

}(document));
