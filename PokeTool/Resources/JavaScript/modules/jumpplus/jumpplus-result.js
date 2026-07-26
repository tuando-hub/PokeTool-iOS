"use strict";
const security=require("./jumpplus-security");
function make(task,status,code,message,startedAt,data,diagnostics){const finishedAt=Date.now();return {ok:!code||code==="JUMPPLUS_3DS_REQUIRED",mode:task.mode,taskId:task.id,accountIdentifier:security.maskEmail(task.account.email),status,code:code||null,message:message||status,startedAt,finishedAt,durationMs:finishedAt-startedAt,step:diagnostics&&diagnostics.step||null,data:security.redact(data||{}),diagnostics:security.redact(diagnostics||{})};}
async function persist(runId,result){const run=String(runId||"run").replace(/[^A-Za-z0-9_-]/g,"").slice(0,80)||"run";await PokeToolRuntime.storage.createDirectory("/results/jumpplus");await PokeToolRuntime.storage.writeJSON("/results/jumpplus/"+run+"-"+String(result.taskId).replace(/[^A-Za-z0-9_-]/g,"_")+".json",result,{overwrite:true});}
module.exports={make,persist};
