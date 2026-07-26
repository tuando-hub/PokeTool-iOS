"use strict";
const Login=require("./pokemon-login");
const actions=require("./pokemon-actions");
const errors=require("./pokemon-errors");
const ENTRY="https://www.pokemoncenter-online.com/lottery/apply.html?t=";

async function pageAsync(browser, source, context, timeoutMs) {
  const id="__pokemon_async_"+String(await PokeToolRuntime.system.uuid()).replace(/-/g,"");
  await browser.evaluate(`window[${JSON.stringify(id)}]={state:"running"};(async function(){try{const value=await (${source});window[${JSON.stringify(id)}]={state:"done",value:value};}catch(error){window[${JSON.stringify(id)}]={state:"failed",message:String(error&&error.message||error)};}})();null`);
  const deadline=performance.now()+Math.min(timeoutMs||30000,60000);
  try {
    while(performance.now()<deadline){
      context.cancellationToken&&context.cancellationToken.throwIfCancelled();
      const result=await browser.evaluate(`window[${JSON.stringify(id)}]||null`);
      if(result&&result.state==="done")return result.value;
      if(result&&result.state==="failed")throw errors.create("POKEMON_ENTRY_UNAVAILABLE","Pokemon lottery page operation failed.",{step:"LOTTERY_API"});
      await PokeToolRuntime.web.delay(250);
    }
    throw errors.create("POKEMON_ENTRY_UNAVAILABLE","Pokemon lottery page operation timed out.",{step:"LOTTERY_API",retryable:true});
  } finally { try{await browser.evaluate(`delete window[${JSON.stringify(id)}];null`);}catch(_){} }
}
async function execute(session,task,context){
  await Login.login(session,task,context);
  await actions.open(session,"LOTTERY",ENTRY+Date.now(),context);
  const browser=session.browser;
  const tokenInfo=await pageAsync(browser,`new Promise(function(resolve,reject){if(!window.gigya||!gigya.accounts||!gigya.accounts.getJWT)return reject(new Error("NO_GIGYA"));gigya.accounts.getJWT({fields:"UID,email,data.memberID,data.isPhoneNumberVerified",callback:function(value){value&&value.id_token?resolve({token:value.id_token,userId:value.UID||""}):reject(new Error("NO_JWT"));}});})`,context,20000);
  const list=await pageAsync(browser,`fetch("/a/ltr/api/lottery/v1/get-lottery-list",{method:"GET",credentials:"include",headers:{"x-requested-with":"XMLHttpRequest","content-type":"application/json","authorization":"Bearer "+${JSON.stringify(tokenInfo.token)}}}).then(async function(response){const body=await response.text();if(!response.ok)throw new Error("HTTP_"+response.status);const parsed=JSON.parse(body||"{}");return parsed.data||[];})`,context,20000);
  if(!Array.isArray(list)||!list.length)throw errors.create("POKEMON_ENTRY_UNAVAILABLE","No active lottery list was returned.",{step:"LOTTERY_LIST"});
  const results=[];
  for(const productCode of task.input.productIds){
    context.cancellationToken&&context.cancellationToken.throwIfCancelled();
    let found=null;
    for(const lottery of list)for(const item of lottery.applicationItems||[])if(item.itemCd===productCode){found={lotteryGroupId:lottery.lotteryGroupId,itemPrizeId:item.itemPrizeId,itemName:item.itemPrizeName};break;}
    if(!found){results.push({productCode,status:"NOT_FOUND"});continue;}
    const response=await pageAsync(browser,`fetch("/a/ltr/api/lottery/v1/apply-lottery",{method:"POST",credentials:"include",headers:{"accept":"*/*","x-requested-with":"XMLHttpRequest","content-type":"application/json","authorization":"Bearer "+${JSON.stringify(tokenInfo.token)}},body:JSON.stringify(${JSON.stringify({lotteryGroupId:"__GROUP__",itemPrizeId:"__PRIZE__"})}.replace('"__GROUP__"',JSON.stringify(found.lotteryGroupId)).replace('"__PRIZE__"',JSON.stringify(found.itemPrizeId))})}).then(async function(response){const body=await response.text();return {ok:response.ok,status:response.status,body:body};})`,context,30000);
    if(response.ok){results.push({productCode,status:"ENTERED",name:found.itemName});continue;}
    const message=String(response.body||"");
    if(/already|applied/i.test(message)){results.push({productCode,status:"ALREADY_ENTERED"});continue;}
    if(/closed|period/i.test(message)){results.push({productCode,status:"CLOSED"});continue;}
    results.push({productCode,status:"FAILED",httpStatus:response.status});
  }
  const failed=results.some(item=>item.status==="FAILED"||item.status==="NOT_FOUND");
  return {status:failed?"FAILED":(results.every(item=>item.status==="ALREADY_ENTERED")?"ALREADY_ENTERED":"ENTERED"),code:failed?"POKEMON_ENTRY_UNAVAILABLE":null,data:{results}};
}
module.exports={execute};
