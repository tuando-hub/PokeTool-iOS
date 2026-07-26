"use strict";
const Pages=require("./jumpcs-pages");const errors=require("./jumpcs-errors");
function cancel(c){if(c&&c.cancellationToken)c.cancellationToken.throwIfCancelled();}
async function set(browser,selector,value,sensitive){await browser.setValue(selector,value);const actual=await browser.query(selector,"value");if(sensitive?!String(actual||"").length:String(actual)!==String(value))throw errors.create("JUMPCS_PAGE_MISMATCH","Field verification failed.",{step:"FORM"});}
async function click(browser,selector){const result=await browser.evaluate(`(function(){const el=document.querySelector(${JSON.stringify(selector)});if(!el)return false;const r=el.getBoundingClientRect(),s=getComputedStyle(el);if(!r.width||!r.height||s.display==='none'||s.visibility==='hidden'||el.disabled)return false;el.scrollIntoView({block:'center'});el.click();return true;})()`);if(!result)throw errors.create("JUMPCS_PAGE_MISMATCH","Required action was not visible or enabled.",{step:"ACTION"});return true;}
async function open(session,page,url,c){cancel(c);await session.browser.load(url);const result=await Pages.wait(session.browser,page,{timeoutMs:30000,cancellationToken:c&&c.cancellationToken});session.record(result);return result;}
module.exports={cancel,set,click,open};
