"use strict";
const modes=Object.freeze({"jumpcs.prepareSession":"prepareSession","jumpcs.register":"register","jumpcs.verifyPhone":"verifyPhone","jumpcs.profile":"profile","jumpcs.checkout":"checkout","jumpcs.buy":"buy"});
module.exports={modes,resolve(mode){if(!modes[mode])throw new Error("JUMPCS_INVALID_TASK");return modes[mode];}};
