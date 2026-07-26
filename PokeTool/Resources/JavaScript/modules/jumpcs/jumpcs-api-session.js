"use strict";
const API=require("./jumpcs-api-client");
async function create(task){const auth=await API.authenticate(task);return {state:"STORE_SESSION_READY",bearer:auth.bearer,deviceId:auth.deviceId,store:auth.store,account:auth.account};}
module.exports={create};
