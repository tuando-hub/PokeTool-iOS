"use strict";
const Login = require("./pokemon-login");
const actions = require("./pokemon-actions");
const Pages = require("./pokemon-pages");
const OTP = require("./pokemon-otp-provider");
const errors = require("./pokemon-errors");

const HISTORY = "https://www.pokemoncenter-online.com/order-history/";
function statusFromText(text) {
  if (/lost|not selected/i.test(text)) return "LOST";
  if (/won|selected/i.test(text)) return "WON";
  if (/pending|application in progress/i.test(text)) return "PENDING";
  return "UNAVAILABLE";
}
async function execute(session, task, context) {
  await Login.login(session, task, context);
  await actions.open(session, "RESULT", task.input.resultURL || HISTORY, context);
  const browser = session.browser;
  const nodes = await browser.evaluate(`Array.from(document.querySelectorAll(".comOrderList li,[data-result]")).map(function(el){return {text:String(el.innerText||""),status:String(el.getAttribute("data-status")||"")};})`);
  let status = "UNAVAILABLE";
  const list = Array.isArray(nodes) ? nodes : [];
  for (const item of list) {
    const next = statusFromText(String(item.status || "") + " " + String(item.text || ""));
    if (next !== "UNAVAILABLE") { status = next; break; }
  }
  if (status === "UNAVAILABLE" && task.options.checkResultMail === true) {
    const mail = await OTP.wait({
      imapEmail:task.account.imapEmail || task.options.imapEmail,
      imapPassword:task.account.imapPassword || task.options.imapPassword,
      targetEmail:task.account.email, mode:"CheckMail", expectedType:"resultMail",
      productIds:task.input.productIds || [], receivedAfter:task.input.receivedAfter || Date.now(),
      timeoutMs:task.options.otpTimeoutMs
    }, context);
    status = mail.result && mail.result.status || "UNAVAILABLE";
  }
  if (status === "PENDING") return {status,code:"POKEMON_RESULT_PENDING",data:{}};
  if (status === "UNAVAILABLE") return {status,code:"POKEMON_RESULT_UNAVAILABLE",data:{}};
  return {status,data:{}};
}
module.exports = {execute,statusFromText};
