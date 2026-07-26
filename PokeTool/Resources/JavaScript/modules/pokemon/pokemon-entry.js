"use strict";
const registry = require("./pokemon-mode-registry");
const task = require("./pokemon-task");
const executor = require("./pokemon-executor");
const pages = require("./pokemon-pages");
const otp = require("./pokemon-otp-provider");
module.exports = Object.freeze({
  version:"1.0.0",
  capabilities:Object.freeze({
    createAccount:true,lottery:true,checkResult:true,
    changeProfileOrder:true,changeEmail:true,buy:true,
    otp:otp.capabilities(),productionOTP:otp.capabilities().production,
    finalPurchaseDefault:false,pageVerification:"url+title+dom"
  }),
  modes:registry.modes.slice(),validateTask:task.validate,executeTask:executor,
  stop:reason=>require("../product/product-entry").runner.stop(reason),
  diagnostics:Object.freeze({pageNames:Object.keys(pages.pages)})
});
