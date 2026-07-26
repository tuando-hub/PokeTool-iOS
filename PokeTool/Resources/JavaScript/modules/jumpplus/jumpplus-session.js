"use strict";
const security=require("./jumpplus-security");
async function create(task){const browser=await PokeToolRuntime.browser.create({persistence:"isolatedNonPersistent",metadata:{product:"jumpplus",taskId:task.id,account:security.maskEmail(task.account.email)}});return {browser,browserId:browser.browserId,startedAt:Date.now(),accountIdentifier:security.maskEmail(task.account.email),history:[],record(snapshot){this.history.push({url:security.safeURL(snapshot.url),title:snapshot.title,timestamp:Date.now()});if(this.history.length>32)this.history.shift();return snapshot;}};}
async function destroy(session){return PokeToolRuntime.web.safeDestroy(session&&session.browser);}
module.exports={create,destroy};
