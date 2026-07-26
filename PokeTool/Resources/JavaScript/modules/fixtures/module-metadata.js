exports.loadedDuringExecution = module.loaded;
exports.parent = module.parent;
exports.id = module.id;
exports.filename = module.filename;
exports.dirname = module.dirname;
exports.child = require("./relative-child");
exports.children = module.children;
