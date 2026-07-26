"use strict";
const Guard=require("/runtime/page-guard");
const TITLE={type:"includesAny",values:["\u5c11\u5e74\u30b8\u30e3\u30f3\u30d7\uff0b","\u5c11\u5e74\u30b8\u30e3\u30f3\u30d7+","Shonen Jump Plus","Fixture Jump Plus"]};
const e=(name,selector,state)=>({name,selector,state:state||"exists"});
const textButton=(label)=>async snapshot=>snapshot.browser.evaluate(`Array.from(document.querySelectorAll("button,a,[role=button]")).some(function(el){const r=el.getBoundingClientRect(),s=getComputedStyle(el),t=String(el.innerText||el.textContent||"").replace(/\\s+/g,"");return r.width>0&&r.height>0&&s.display!=="none"&&s.visibility!=="hidden"&&t.includes(${JSON.stringify(label)});})`);
const PRODUCT_ID="10834108156675977993";
const pages=Object.freeze({
HOME:{name:"JUMPPLUS_HOME",url:{type:"exact",value:"https://shonenjumpplus.com/"},title:TITLE,selectors:[e("header","header, .plus-header")],customPredicate:textButton("\u30ed\u30b0\u30a4\u30f3"),confidencePolicy:{type:"allRequired"}},
LOGIN_POPUP:{name:"JUMPPLUS_LOGIN_POPUP",url:{type:"startsWith",value:"https://shonenjumpplus.com/"},title:TITLE,selectors:[e("login-form",'form[action*="/user_account/login"]',"visible"),e("signup-switch","button.js-signup-button","visible")]},
SIGNUP_FORM:{name:"JUMPPLUS_SIGNUP_FORM",url:{type:"startsWith",value:"https://shonenjumpplus.com/"},title:TITLE,selectors:[e("email",'form:has(#input-agreement) input[name="email_address"]',"visible"),e("password",'form:has(#input-agreement) input[name="password"]',"visible"),e("agreement","#input-agreement","visible")]},
MAIL_SENT:{name:"JUMPPLUS_SIGNUP_MAIL_SENT",url:{type:"startsWith",value:"https://shonenjumpplus.com/"},title:TITLE,text:{includes:"\u767b\u9332\u30e1\u30fc\u30eb\u3092\u9001\u4fe1\u3057\u307e\u3057\u305f"},selectors:[e("signup-gone","#input-agreement","gone")]},
CONFIRMATION:{name:"JUMPPLUS_SIGNUP_CONFIRMATION",url:{type:"regex",value:"^https://shonenjumpplus\\.com/user_account/signup_registration/[A-Za-z0-9_-]+$"},title:TITLE,text:{includesAny:["\u30e1\u30fc\u30eb\u30a2\u30c9\u30ec\u30b9\u306e\u767b\u9332\u304c\u5b8c\u4e86","\u767b\u9332\u304c\u5b8c\u4e86"]}},
LOGGED_IN:{name:"JUMPPLUS_LOGGED_IN_HOME",url:{type:"startsWith",value:"https://shonenjumpplus.com/"},title:TITLE,selectors:[e("account-nav","li.plus-header-nav-premium, a[href*='/my/'], [data-user-account]","visible")]},
PREMIUM:{name:"JUMPPLUS_PREMIUM_CONFIRM",url:{type:"regex",value:"^https://shonenjumpplus\\.com/premium/confirm\\?product_id="+PRODUCT_ID+"$"},title:TITLE,customPredicate:textButton("\u6c7a\u6e08\u65b9\u6cd5\u3092\u9078\u629e\u3059\u308b")},
PAYMENT_METHOD:{name:"JUMPPLUS_PAYMENT_METHOD",url:{type:"startsWith",value:"https://shonenjumpplus.com/"},title:TITLE,selectors:[e("credit-3ds","a.payment_choose_credit_3d","visible")]},
CREDIT_FORM:{name:"JUMPPLUS_CREDIT_FORM",url:{type:"startsWith",value:"https://shonenjumpplus.com/"},title:TITLE,selectors:[e("credit-form",'form[name="creditFepChargePaymentInfoEntryActionForm"]',"visible"),e("card-number",'input[name="ccNumber"]',"visible"),e("expiry",'select[name="ccExpirationMonth"]',"visible"),e("security-code",'input[name="securityCode"]',"visible")]},
REVIEW:{name:"JUMPPLUS_PAYMENT_REVIEW",url:{type:"startsWith",value:"https://shonenjumpplus.com/"},title:TITLE,selectors:[e("review",'form[name="fepChargeIntensionConfirmActionForm"]',"visible")]},
COMPLETE:{name:"JUMPPLUS_SUBSCRIPTION_COMPLETE",url:{type:"startsWith",value:"https://shonenjumpplus.com/"},title:TITLE,text:{includesAny:["\u3054\u8cfc\u5165\u51e6\u7406\u306e\u5b8c\u4e86","\u8cfc\u5165\u304c\u5b8c\u4e86","\u6c7a\u6e08\u304c\u5b8c\u4e86"]}},
THREEDS:{name:"JUMPPLUS_3DS",url:{type:"regex",value:"(credit3d2|authenticate|stepup|challenge|emvtds|cardinal|/acs)"},title:()=>true,selectors:[e("3ds","form[name='credit3d2FepBuyAuthenticateActionForm'], form[action*='challenge'], iframe[src*='3ds'], iframe[src*='cardinal']","exists")],confidencePolicy:{type:"minimumMatches",minimum:1}}
});
const unexpected=Object.freeze({
CAPTCHA:{name:"JUMPPLUS_CAPTCHA",url:()=>true,title:()=>true,selectors:[e("captcha","iframe[src*='captcha'],.g-recaptcha,[data-captcha]")]},
MAINTENANCE:{name:"JUMPPLUS_MAINTENANCE",url:()=>true,title:TITLE,text:{includesAny:["\u30e1\u30f3\u30c6\u30ca\u30f3\u30b9","maintenance"]},confidencePolicy:{type:"minimumMatches",minimum:2}},
RATE_LIMITED:{name:"JUMPPLUS_RATE_LIMITED",url:()=>true,title:TITLE,text:{includesAny:["\u30a2\u30af\u30bb\u30b9\u304c\u96c6\u4e2d","too many requests"]},confidencePolicy:{type:"minimumMatches",minimum:2}}
});
async function identify(browser){for(const key of Object.keys(unexpected))if(await Guard.matches(browser,unexpected[key]))return {page:key,unexpected:true};for(const key of Object.keys(pages))if(await Guard.matches(browser,pages[key]))return {page:key,unexpected:false};return {page:"UNKNOWN",unexpected:true};}
module.exports={PRODUCT_ID,pages,unexpected,identify,inspect:(b,d)=>Guard.inspect(b,d),assert:(b,p,o)=>Guard.assert(b,typeof p==="string"?pages[p]:p,o),wait:(b,p,o)=>Guard.waitFor(b,typeof p==="string"?pages[p]:p,o)};
