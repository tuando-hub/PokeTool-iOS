"use strict";
const Task=require("./jumpplus-task-schema");
const Registry=require("./jumpplus-mode-registry");
const Pages=require("./jumpplus-pages");
const Payment=require("./jumpplus-payment");
module.exports=Object.freeze({version:"1.0.0",capabilities:Object.freeze({register:true,login:true,premiumNavigation:true,paymentForm:true,finalSubmit:"explicitOnly",emailConfirmation:"requiresConfiguration",threeDS:"detectOnly",jumpCharactersStore:false}),modes:Registry.modes.slice(),validateTask:Task.validate,executeTask:require("./jumpplus-executor"),stop:reason=>require("../product/product-entry").runner.stop(reason),diagnostics:Object.freeze({productId:Pages.PRODUCT_ID,pageNames:Object.keys(Pages.pages),paymentFields:["ccNumber","ccExpirationMonth","ccExpirationYear","securityCode"],premiumURL:Payment.PREMIUM})});
