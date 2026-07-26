"use strict";
const Login = require("./pokemon-login");
const actions = require("./pokemon-actions");
const Pages = require("./pokemon-pages");
const OTP = require("./pokemon-otp-provider");
const errors = require("./pokemon-errors");

const INPUT = "https://www.pokemoncenter-online.com/mail-change-input/";
async function execute(session, task, context) {
  actions.requireInput(task, ["newEmail"]);
  await Login.login(session, task, context);
  await actions.open(session, "EMAIL_CHANGE", INPUT, context);
  const browser = session.browser;
  await actions.setAndVerify(browser, "#email", task.input.newEmail, false);
  await actions.setAndVerify(browser, "#emailRe", task.input.newEmail, false);
  await PokeToolRuntime.web.tapButton(browser, ".sendmail");
  await Pages.wait(browser, "EMAIL_MAIL_SENT", {timeoutMs:20000,cancellationToken:context.cancellationToken});
  const otp = await OTP.wait({
    imapEmail:task.account.imapEmail || task.options.imapEmail,
    imapPassword:task.account.imapPassword || task.options.imapPassword,
    targetEmail:task.input.newEmail, mode:"ChangeEmail", expectedType:"confirmationURL",
    receivedAfter:Date.now(), timeoutMs:task.options.otpTimeoutMs
  }, context);
  if (otp.type !== "confirmationURL" || !/^https:\/\/www\.pokemoncenter-online\.com\/mail-change-complete\/\?token=/.test(otp.value)) {
    throw errors.create("POKEMON_OTP_FAILED", "Email confirmation URL was invalid.", {step:"EMAIL_OTP"});
  }
  await actions.open(session, "EMAIL_CHANGE_COMPLETE", otp.value, context);
  return {status:"CHANGED",data:{newEmailMasked:require("./pokemon-security").maskEmail(task.input.newEmail)}};
}
module.exports = {execute};
