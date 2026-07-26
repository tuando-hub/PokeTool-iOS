exports.name = "a";
const b = require("./circular-b");
exports.fromB = b.name;
