"use strict";
function validate(body){if(!body||typeof body!=="object")return "Request body is required.";for(const key of ["operationId","imapEmail","imapPassword","targetEmail","mode"]){if(typeof body[key]!=="string"||!body[key])return `${key} is required.`;}if(String(body.imapPassword).length>4096)return "imapPassword exceeds the service limit.";if(body.timeoutMs!==undefined&&(!Number.isFinite(body.timeoutMs)||body.timeoutMs<1000||body.timeoutMs>300000))return "timeoutMs is outside the allowed range.";return null;}
module.exports={validate};
