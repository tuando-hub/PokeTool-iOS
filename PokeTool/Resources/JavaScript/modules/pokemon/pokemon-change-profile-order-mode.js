"use strict";
const Login = require("./pokemon-login");
const actions = require("./pokemon-actions");
const Pages = require("./pokemon-pages");
const Form = require("./pokemon-form");
const errors = require("./pokemon-errors");

const HISTORY = "https://www.pokemoncenter-online.com/order-history/";
async function execute(session, task, context) {
  actions.requireInput(task, ["profile","productIds"]);
  await Login.login(session, task, context);
  await actions.open(session, "ORDER_HISTORY", HISTORY, context);
  const browser = session.browser;
  const result = await browser.evaluate(`(function(ids){const rows=Array.from(document.querySelectorAll(".comOrderList > li"));for(const row of rows){const src=(row.querySelector(".phoBox img")||{}).src||"";if(ids.some(id=>src.indexOf(id)>=0)){const text=(row.querySelector(".number span")||{}).innerText||"";const match=text.match(/[A-Za-z0-9-]{5,}/);return match&&match[0];}}return null;})(` + JSON.stringify(task.input.productIds) + `)`);
  if (!result) throw errors.create("POKEMON_PROFILE_UPDATE_FAILED", "Matching order was not found.", {step:"ORDER_HISTORY"});
  const url = "https://www.pokemoncenter-online.com/order-delivery-address-show/?orderNo=" + encodeURIComponent(result);
  await actions.open(session, "ORDER_ADDRESS", url, context);
  await Form.fillOrderAddress(browser, task.input.profile);
  await PokeToolRuntime.web.tapButton(browser, "#changeAddressButton");
  await Pages.wait(browser, "ORDER_ADDRESS_COMPLETE", {timeoutMs:30000,cancellationToken:context.cancellationToken});
  return {status:"CHANGED",data:{orderReference:String(result).slice(-6),changedFields:Object.keys(task.input.profile)}};
}
module.exports = {execute};
