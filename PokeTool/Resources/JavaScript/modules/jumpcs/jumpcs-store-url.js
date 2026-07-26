"use strict";
const errors=require("./jumpcs-errors");
function validate(value){const input=String(value||"");if(!/^https:\/\/jumpcs\.shueisha\.co\.jp\/[^?#]+\?[^#]*subscr_token=[A-Za-z0-9._~%+-]+(?:&[^#]*)?$/.test(input))throw errors.create("JUMPCS_STORE_URL_INVALID","Store URL failed exact host and token validation.",{step:"STORE_URL"});const match=input.match(/[?&]subscr_token=([^&#]+)/);if(!match)throw errors.create("JUMPCS_SUBSCR_TOKEN_MISSING","Store URL has no subscription token.",{step:"STORE_URL"});const token=decodeURIComponent(match[1]);if(!/^[A-Za-z0-9._~%+-]+$/.test(token))throw errors.create("JUMPCS_SUBSCR_TOKEN_INVALID","Subscription token format is invalid.",{step:"STORE_URL"});return {url:input,tokenPresent:true,token};}
function safe(value){const v=validate(value);return {safeUrl:String(value).replace(/([?&]subscr_token=)[^&#]+/i,"$1<redacted>"),tokenPresent:v.tokenPresent};}
module.exports={validate,safe};
