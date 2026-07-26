"use strict";
const Pages=require("./jumpcs-pages");const security=require("./jumpcs-security");
async function create(task,store){const browser=await PokeToolRuntime.browser.create({persistence:"isolatedNonPersistent",metadata:{product:"jumpcs",taskId:task.id,account:security.maskEmail(task.account.email)}});return {browser,browserId:browser.browserId,history:[],store,record(s){this.history.push({url:security.safeURL(s.url),title:s.title,timestamp:Date.now()});if(this.history.length>32)this.history.shift();return s;}};}
async function open(session){await session.browser.load(session.store.url);const state=await Pages.identify(session.browser);if(state.unexpected)throw new Error("JUMPCS_BROWSER_BOOTSTRAP_FAILED");session.record({url:await session.browser.url(),title:await session.browser.title()});return state;}
async function destroy(session){return PokeToolRuntime.web.safeDestroy(session&&session.browser);}
module.exports={create,open,destroy};
