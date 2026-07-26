"use strict";
const PageGuard = require("/runtime/page-guard");
const BRAND = {type:"includesAny",values:[
  "\u30dd\u30b1\u30e2\u30f3\u30bb\u30f3\u30bf\u30fc\u30aa\u30f3\u30e9\u30a4\u30f3",
  "Pokemon Center Online","Fixture Pokemon"
]};
const visible = (name, selector) => ({name:name,selector:selector,state:"visible"});
const exists = (name, selector) => ({name:name,selector:selector,state:"exists"});
const pages = Object.freeze({
  LOGIN:{name:"POKEMON_LOGIN",url:{type:"contains",value:"/login/"},title:BRAND,
    selectors:[visible("email","#login-form-email"),visible("password","#current-password"),visible("submit","#form1Button")]},
  OTP:{name:"POKEMON_OTP",url:{type:"regex",value:"/(login|factor|auth)/"},title:BRAND,selectors:[visible("otp","#authCode")]},
  TERMS:{name:"POKEMON_TERMS",url:{type:"regex",value:"/(terms|agreement|mypage)/"},title:BRAND,selectors:[visible("terms-submit","#terms_button")]},
  MYPAGE:{name:"POKEMON_MYPAGE",url:{type:"contains",value:"/mypage/"},title:BRAND,selectors:[exists("mypage","main .mypage, .mypage, .comMyPage, [data-page='mypage']")]},
  REGISTRATION_START:{name:"POKEMON_REGISTRATION_START",url:{type:"regex",value:"/(login|new-customer)/"},title:BRAND,selectors:[visible("register-email","#login-form-regist-email")]},
  REGISTRATION_MAIL:{name:"POKEMON_REGISTRATION_MAIL",url:{type:"regex",value:"/(confirmation|registration|login)/"},title:BRAND,selectors:[visible("send-confirmation","#send-confirmation-email")]},
  REGISTRATION_FORM:{name:"POKEMON_REGISTRATION_FORM",url:{type:"contains",value:"/new-customer/"},title:BRAND,selectors:[visible("name","#registration-form-fname"),visible("registration","#registration_button")]},
  REGISTRATION_CONFIRM:{name:"POKEMON_REGISTRATION_CONFIRM",url:{type:"contains",value:"/new-customer/"},title:BRAND,selectors:[visible("confirmation",".submitButton, [data-page='registration-confirm']")]},
  REGISTRATION_COMPLETE:{name:"POKEMON_REGISTRATION_COMPLETE",url:{type:"regex",value:"/(registration|mypage|complete)/"},title:BRAND,selectors:[exists("complete","[data-page='registration-complete'], .registration-complete, .complete")]},
  LOTTERY:{name:"POKEMON_LOTTERY",url:{type:"contains",value:"/lottery/apply.html"},title:BRAND,selectors:[exists("lottery-root","#lottery-app, .lottery, [data-page='lottery']")]},
  LOTTERY_COMPLETE:{name:"POKEMON_LOTTERY_COMPLETE",url:{type:"contains",value:"/lottery/"},title:BRAND,selectors:[exists("entry-status","[data-entry-status], .lottery-result, .application-status")]},
  RESULT:{name:"POKEMON_RESULT",url:{type:"regex",value:"/(lottery-history|order-history)/"},title:BRAND,selectors:[exists("result",".comOrderList, [data-result], [data-page='result']")]},
  ORDER_HISTORY:{name:"POKEMON_ORDER_HISTORY",url:{type:"contains",value:"/order-history/"},title:BRAND,selectors:[exists("orders",".comOrderList, [data-page='order-history']")]},
  ORDER_ADDRESS:{name:"POKEMON_ORDER_ADDRESS",url:{type:"contains",value:"/order-delivery-address-show/"},title:BRAND,selectors:[visible("address","#name, [name='dwfrm_changeAddress_phone']")]},
  ORDER_ADDRESS_COMPLETE:{name:"POKEMON_ORDER_ADDRESS_COMPLETE",url:{type:"regex",value:"/(order-history|order-delivery-address)/"},title:BRAND,selectors:[exists("complete",".complete, .comOrderList, [data-page='address-complete']")]},
  EMAIL_CHANGE:{name:"POKEMON_EMAIL_CHANGE",url:{type:"contains",value:"/mail-change-input/"},title:BRAND,selectors:[visible("email","#email"),visible("email-confirm","#emailRe"),visible("send",".sendmail")]},
  EMAIL_MAIL_SENT:{name:"POKEMON_EMAIL_MAIL_SENT",url:{type:"regex",value:"/(mail-change|mail-change-send)/"},title:BRAND,selectors:[exists("sent",".mail-sent, [data-page='mail-sent'], .complete")]},
  EMAIL_CHANGE_COMPLETE:{name:"POKEMON_EMAIL_COMPLETE",url:{type:"contains",value:"/mail-change-complete/"},title:BRAND,selectors:[exists("complete","[data-page='email-complete'], .mail-change-complete, .complete")]},
  PRODUCT:{name:"POKEMON_PRODUCT",url:{type:"regex",value:"/(products?|product)/"},title:BRAND,selectors:[exists("product","[data-product-id], .product-detail, .productDetail")]},
  CART:{name:"POKEMON_CART",url:{type:"contains",value:"/cart/"},title:BRAND,selectors:[exists("cart",".cart, .comCart, [data-page='cart']")]},
  CHECKOUT:{name:"POKEMON_CHECKOUT",url:{type:"regex",value:"/(checkout|order)/"},title:BRAND,selectors:[exists("checkout","[data-page='checkout'], .checkout, .order-form")]},
  REVIEW:{name:"POKEMON_REVIEW",url:{type:"regex",value:"/(confirm|review|order)/"},title:BRAND,selectors:[exists("review","[data-page='review'], .order-confirm, .review")]},
  ORDER_COMPLETE:{name:"POKEMON_ORDER_COMPLETE",url:{type:"regex",value:"/(complete|thank)/"},title:BRAND,selectors:[exists("order-complete","[data-order-id], .order-complete, .complete")]}
});
const unexpected = Object.freeze({
  CAPTCHA:{name:"POKEMON_CAPTCHA",url:{type:"regex",value:"/(captcha|challenge)/"},title:BRAND,selectors:[exists("captcha","iframe[src*='captcha'], .g-recaptcha, [data-captcha]")]},
  MAINTENANCE:{name:"POKEMON_MAINTENANCE",url:{type:"regex",value:"/(maintenance|error)/"},title:BRAND,text:{includesAny:["maintenance","temporarily unavailable"]},confidencePolicy:{type:"minimumMatches",minimum:2}},
  SESSION_EXPIRED:{name:"POKEMON_SESSION_EXPIRED",url:{type:"contains",value:"/login/"},title:BRAND,text:{includesAny:["session expired"]},confidencePolicy:{type:"minimumMatches",minimum:2}}
});
async function identify(browser) {
  for (const key of Object.keys(unexpected)) if (await PageGuard.matches(browser, unexpected[key])) return {page:key,unexpected:true};
  for (const key of Object.keys(pages)) if (await PageGuard.matches(browser, pages[key])) return {page:key,unexpected:false};
  return {page:"UNKNOWN",unexpected:true};
}
module.exports = {
  pages,unexpected,identify,inspect:(browser,descriptor)=>PageGuard.inspect(browser,descriptor),
  assert:(browser,page,options)=>PageGuard.assert(browser,typeof page==="string"?pages[page]:page,options),
  wait:(browser,page,options)=>PageGuard.waitFor(browser,typeof page==="string"?pages[page]:page,options)
};
