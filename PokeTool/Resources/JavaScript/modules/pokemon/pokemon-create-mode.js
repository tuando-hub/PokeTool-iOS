"use strict";
const actions = require("./pokemon-actions");
const Pages = require("./pokemon-pages");
const OTP = require("./pokemon-otp-provider");
const Form = require("./pokemon-form");
const errors = require("./pokemon-errors");

const START = "https://www.pokemoncenter-online.com/login/";
async function execute(session, task, context) {
  actions.requireInput(task, ["profile"]);
  const browser = session.browser;
  await actions.emit("pokemon.task.started", task, {step:"REGISTRATION_START"});
  await actions.open(session, "REGISTRATION_START", START, context);
  await actions.setAndVerify(browser, "#login-form-regist-email", task.account.email, false);
  await PokeToolRuntime.web.tapButton(browser, "#form2Button");
  await Pages.wait(browser, "REGISTRATION_MAIL", {timeoutMs:20000,cancellationToken:context.cancellationToken});
  if (await browser.exists("#send-confirmation-email")) {
    await PokeToolRuntime.web.tapButton(browser, "#send-confirmation-email");
  }
  const otp = await OTP.wait({
    imapEmail:task.account.imapEmail || task.options.imapEmail,
    imapPassword:task.account.imapPassword || task.options.imapPassword,
    targetEmail:task.account.email, mode:"Create", expectedType:"confirmationURL",
    receivedAfter:Date.now(), timeoutMs:task.options.otpTimeoutMs
  }, context);
  if (otp.type === "alreadyRegistered") {
    return {status:"ALREADY_EXISTS",code:null,data:{}};
  }
  if (otp.type !== "confirmationURL" || !/^https:\/\/www\.pokemoncenter-online\.com\/new-customer\/\?token=/.test(otp.value)) {
    throw errors.create("POKEMON_OTP_FAILED", "Registration confirmation URL was invalid.", {step:"REGISTRATION_MAIL"});
  }
  await actions.open(session, "REGISTRATION_FORM", otp.value, context);
  await Form.fillProfile(browser, Object.assign({}, task.input.profile, {password:task.account.password}));
  if (await browser.exists("#registration_button")) {
    await PokeToolRuntime.web.tapButton(browser, "#registration_button");
    await Pages.wait(browser, "REGISTRATION_CONFIRM", {timeoutMs:20000,cancellationToken:context.cancellationToken});
  }
  await PokeToolRuntime.web.tapButton(browser, ".submitButton");
  await Pages.wait(browser, "REGISTRATION_COMPLETE", {timeoutMs:30000,cancellationToken:context.cancellationToken});
  return {status:"CREATED",data:{emailChanged:false}};
}
module.exports = {execute};
