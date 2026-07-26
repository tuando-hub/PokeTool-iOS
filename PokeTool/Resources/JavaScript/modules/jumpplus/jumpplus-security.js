"use strict";
function maskEmail(value){const p=String(value||"").split("@");return p.length===2?(p[0].slice(0,2)||"*")+"***@"+p[1]:"<private>";}
function safeURL(value){const match=/^(https?):\/\/([^/?#]+)(\/[^?#]*)?/i.exec(String(value||""));return match?match[1].toLowerCase()+"://"+match[2].toLowerCase()+(match[3]||"/"):"";}
function redact(value){if(Array.isArray(value))return value.map(redact);if(!value||typeof value!=="object")return value;const out={};Object.keys(value).forEach(key=>{if(/password|pass|otp|token|cookie|authorization|card|cvv|cvc|security|expiration|acs|creq|pareq|jwt/i.test(key))out[key]="<redacted>";else if(/email/i.test(key))out[key]=maskEmail(value[key]);else out[key]=redact(value[key]);});return out;}
function clearPayment(payment){if(!payment||typeof payment!=="object")return;Object.keys(payment).forEach(key=>{payment[key]=null;delete payment[key];});}
module.exports={maskEmail,safeURL,redact,clearPayment};
