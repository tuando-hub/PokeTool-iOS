exports.name = "b";
const a = require("./circular-a");
exports.fromA = a.name;
