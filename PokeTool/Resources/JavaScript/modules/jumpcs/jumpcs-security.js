"use strict";
function maskEmail(v){const p=String(v||"").split("@");return p.length===2?(p[0].slice(0,2)||"*")+"***@"+p[1]:"<private>";}
function maskPhone(v){const d=String(v||"").replace(/\D/g,"");return d.length>4?"***"+d.slice(-4):"<private>";}
function safeURL(v){const m=/^(https?):\/\/([^/?#]+)(\/[^?#]*)?/i.exec(String(v||""));return m?m[1].toLowerCase()+"://"+m[2].toLowerCase()+(m[3]||"/"):"";}
function redact(v){if(Array.isArray(v))return v.map(redact);if(!v||typeof v!=="object")return v;const o={};Object.keys(v).forEach(k=>{if(/password|pass|token|bearer|cookie|authorization|secret|otp|card|cvv|cvc|security|device|subscr|apiKey|imap/i.test(k))o[k]="<redacted>";else if(/email/i.test(k))o[k]=maskEmail(v[k]);else if(/phone|tel|sdt/i.test(k))o[k]=maskPhone(v[k]);else o[k]=redact(v[k]);});return o;}
function clear(v){if(!v||typeof v!=="object")return;Object.keys(v).forEach(k=>{v[k]=null;delete v[k];});}
module.exports={maskEmail,maskPhone,safeURL,redact,clear};
