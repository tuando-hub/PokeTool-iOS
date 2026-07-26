"use strict";
const Guard=require("/runtime/page-guard");
const HOST="jumpcs.shueisha.co.jp";
const TITLE={type:"includesAny",values:["ジャンプキャラクターズストア","Jump Characters Store","Fixture JumpCS"]};
const e=(name,selector,state)=>({name,selector,state:state||"exists"});
const pages=Object.freeze({
ENTRY_REDIRECT:{name:"JUMPCS_ENTRY_REDIRECT",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("entry","#frmOnetime, #mail, #pwd, #cpwd","visible")]},
REGISTRATION:{name:"JUMPCS_REGISTRATION",url:{type:"contains",value:"/shop/customer/entry.aspx"},title:TITLE,selectors:[e("mail","#mail","visible"),e("password","#pwd","visible"),e("confirmation","#cpwd","visible")]},
REGISTRATION_MAIL_SENT:{name:"JUMPCS_REGISTRATION_MAIL_SENT",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,text:{includesAny:["確認コード","メールを送信"]}},
EMAIL_CONFIRMATION:{name:"JUMPCS_EMAIL_CONFIRMATION",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("confirmation-code","#confirmation_code","visible")]},
PROFILE:{name:"JUMPCS_PROFILE",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("name","#name","visible"),e("phone","#tel","visible"),e("agreement","#agree_checkbox","exists")]},
PHONE_INPUT:{name:"JUMPCS_PHONE_INPUT",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("phone","#auth_tel","visible"),e("send","input.block-auth-tel-send--submit","visible")]},
SMS_CODE_INPUT:{name:"JUMPCS_SMS_CODE_INPUT",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("sms","input.block-auth-tel-certify--input, #auth_code, input[name='auth_code']","visible")]},
ACCOUNT_READY:{name:"JUMPCS_ACCOUNT_READY",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("menu","a[href*='customer/menu'], #customer-menu, .customer-menu","visible")]},
PRODUCT:{name:"JUMPCS_PRODUCT",url:{type:"contains",value:"/shop/g/g"},title:TITLE,selectors:[e("quantity","#qty","visible"),e("cart","#cart_button","visible")]},
CART:{name:"JUMPCS_CART",url:{type:"contains",value:"/shop/cart"},title:TITLE,selectors:[e("cart-line","[data-product-id], .cart-item, #cartForm","visible")]},
DELIVERY:{name:"JUMPCS_DELIVERY",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("terms","#agree_checkbox","exists")]},
PAYMENT_METHOD:{name:"JUMPCS_PAYMENT_METHOD",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("credit","input[name='selectcard'], #method_rB, input[name='paymentMethod']","visible")]},
CARD_FORM:{name:"JUMPCS_CARD_FORM",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("brand","select[name='card_brand']","visible"),e("number","input[name='card_num']","visible"),e("security","input[name='security_code']","visible")]},
REVIEW:{name:"JUMPCS_PAYMENT_REVIEW",url:{type:"startsWith",value:"https://jumpcs.shueisha.co.jp/"},title:TITLE,selectors:[e("final","input[name='submit.x'][value='注文を確定する']","visible")]},
THREEDS:{name:"JUMPCS_3DS_REDIRECT",url:{type:"regex",value:"(3ds|authenticate|stepup|challenge|cardinal|acs)"},title:()=>true,selectors:[e("challenge","iframe, form[action*='challenge'], form[id*='3ds']","exists")],confidencePolicy:{type:"minimumMatches",minimum:1}},
ORDER_COMPLETE:{name:"JUMPCS_ORDER_COMPLETE",url:{type:"regex",value:"^https://jumpcs\\.shueisha\\.co\\.jp/shop/order/order\\.aspx\\?order_id=[A-Za-z0-9_-]+$"},title:TITLE,selectors:[e("complete",".order-complete, .order-confirm, [data-order-id]","exists")]}
});
const unexpected=Object.freeze({CAPTCHA:{name:"JUMPCS_CAPTCHA_REQUIRED",url:()=>true,title:()=>true,selectors:[e("captcha",".g-recaptcha,iframe[src*='captcha'],[data-captcha]")]},MAINTENANCE:{name:"JUMPCS_MAINTENANCE",url:()=>true,title:TITLE,text:{includesAny:["メンテナンス","maintenance"]},confidencePolicy:{type:"minimumMatches",minimum:2}},SESSION_EXPIRED:{name:"JUMPCS_SESSION_EXPIRED",url:()=>true,title:TITLE,text:{includesAny:["ログインしてください","セッション"]},confidencePolicy:{type:"minimumMatches",minimum:2}}});
async function identify(browser){for(const k of Object.keys(unexpected))if(await Guard.matches(browser,unexpected[k]))return {page:k,unexpected:true};for(const k of Object.keys(pages))if(await Guard.matches(browser,pages[k]))return {page:k,unexpected:false};return {page:"UNKNOWN",unexpected:true};}
module.exports={HOST,pages,unexpected,identify,inspect:(b,d)=>Guard.inspect(b,d),assert:(b,p,o)=>Guard.assert(b,typeof p==="string"?pages[p]:p,o),wait:(b,p,o)=>Guard.waitFor(b,typeof p==="string"?pages[p]:p,o)};
