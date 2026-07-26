"use strict";
const Pages = require("./pokemon-pages");
const security = require("./pokemon-security");
async function create(task) {
  const browser = await PokeToolRuntime.browser.create({
    persistence:"isolatedNonPersistent",
    metadata:{product:"pokemon",taskId:task.id,account:security.maskEmail(task.account.email)}
  });
  const session = {
    browser, browserId:browser.browserId, startedAt:Date.now(),
    accountIdentifier:security.maskEmail(task.account.email), history:[]
  };
  session.record = snapshot => {
    session.history.push({
      url:security.safeURL(snapshot.url),title:snapshot.title,timestamp:Date.now()
    });
    if (session.history.length > 32) session.history.shift();
    return snapshot;
  };
  return session;
}
async function record(session) {
  const snapshot = await Pages.inspect(session.browser, {
    name:"CURRENT",url:()=>true,title:()=>true,readyState:["interactive","complete"],
    confidencePolicy:{type:"allRequired"}
  });
  session.history.push({
    url:security.safeURL(snapshot.url),title:snapshot.title,timestamp:Date.now()
  });
  if (session.history.length > 32) session.history.shift();
  return snapshot;
}
async function destroy(session) {
  return PokeToolRuntime.web.safeDestroy(session && session.browser);
}
module.exports = {create,record,destroy};
