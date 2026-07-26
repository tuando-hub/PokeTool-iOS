exports.after = function (delay, callback) { return setTimeout(callback, delay); };
exports.cancel = function (id) { clearTimeout(id); };
