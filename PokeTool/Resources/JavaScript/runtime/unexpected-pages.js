"use strict";
const PageGuard = require("./page-guard");
const definitions = [
  {code:"LOGIN_REQUIRED", descriptor:{name:"Login required", text:{includesAny:["sign in","login required"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}},
  {code:"SESSION_EXPIRED", descriptor:{name:"Session expired", text:{includesAny:["session expired","session has ended"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}},
  {code:"ACCESS_DENIED", descriptor:{name:"Access denied", text:{includesAny:["access denied","forbidden"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}},
  {code:"MAINTENANCE", descriptor:{name:"Maintenance", text:{includesAny:["maintenance","temporarily unavailable"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}},
  {code:"RATE_LIMITED", descriptor:{name:"Rate limited", text:{includesAny:["too many requests","rate limit"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}},
  {code:"CAPTCHA_REQUIRED", descriptor:{name:"CAPTCHA required", text:{includesAny:["captcha","verify you are human"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}},
  {code:"TERMS_REQUIRED", descriptor:{name:"Terms required", text:{includesAny:["accept the terms","terms of service"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}},
  {code:"ERROR_PAGE", descriptor:{name:"Error page", text:{includesAny:["an error occurred","something went wrong"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}},
  {code:"NETWORK_ERROR_PAGE", descriptor:{name:"Network error", text:{includesAny:["network error","offline"]}, confidencePolicy:{type:"minimumMatches",minimum:1}}}
];
async function detect(browser, registry) {
  const candidates = registry || definitions;
  for (const candidate of candidates) {
    if (await PageGuard.matches(browser, candidate.descriptor)) return candidate;
  }
  return null;
}
module.exports = {definitions, detect};
