"use strict";
const security = require("./pokemon-security");
function make(task, status, code, message, startedAt, data, diagnostics) {
  const finishedAt = Date.now();
  return {
    ok:!code,mode:task.mode,taskId:task.id,
    accountIdentifier:security.maskEmail(task.account && task.account.email),
    status,code:code || null,message:message || status,
    startedAt,finishedAt,durationMs:finishedAt-startedAt,
    step:diagnostics && diagnostics.step || null,
    data:security.redact(data || {}),diagnostics:security.redact(diagnostics || {})
  };
}
async function persist(runId, result) {
  const safeRun = String(runId || "run").replace(/[^A-Za-z0-9_-]/g,"").slice(0,80) || "run";
  await PokeToolRuntime.storage.createDirectory("/results/pokemon");
  await PokeToolRuntime.storage.writeJSON(
    "/results/pokemon/" + safeRun + "-" + result.taskId.replace(/[^A-Za-z0-9_-]/g,"_") + ".json",
    result,{overwrite:true}
  );
  return true;
}
module.exports = {make,persist};
