"use strict";
const errors=require("./jumpplus-errors");
const modes=Object.freeze({
"jumpplus.register":"register","jumpplus.login":"login","jumpplus.premium":"premium","jumpplus.subscribe":"subscribe"});
function resolve(mode){if(!modes[mode])throw errors.create("JUMPPLUS_INVALID_TASK","Jump Plus mode is not registered.");return modes[mode];}
module.exports={modes:Object.keys(modes),resolve};
