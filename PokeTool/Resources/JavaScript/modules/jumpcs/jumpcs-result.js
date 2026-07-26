"use strict";
const security=require("./jumpcs-security");
function make(task,status,code,message,startedAt,data,diagnostics){const finishedAt=Date.now();return {ok:!code||code==="JUMPCS_3DS_REQUIRED",mode:task.mode,taskId:task.id,accountIdentifier:security.maskEmail(task.account.email),status,code:code||null,message:message||status,startedAt,finishedAt,durationMs:finishedAt-startedAt,data:security.redact(data||{}),diagnostics:security.redact(diagnostics||{})};}
async function persist(runId,result){await PokeToolRuntime.storage.createDirectory("/results/jumpcs");const name=String(runId||"run").replace(/[^A-Za-z0-9_-]/g,"").slice(0,80)||"run";await PokeToolRuntime.storage.writeJSON("/results/jumpcs/"+name+"-"+String(result.taskId).replace(/[^A-Za-z0-9_-]/g,"_")+".json",result,{overwrite:true});return true;}
module.exports={make,persist};
