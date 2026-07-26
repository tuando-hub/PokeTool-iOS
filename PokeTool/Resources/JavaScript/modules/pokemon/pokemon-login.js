"use strict";
const Pages = require("./pokemon-pages");
const OTP = require("./pokemon-otp-provider");
const errors = require("./pokemon-errors");

const LOGIN_URL = "https://www.pokemoncenter-online.com/login/";

async function fillVerified(browser, selector, value, sensitive) {
  await PokeToolRuntime.web.setValue(browser, selector, value);
  const state = await browser.query(selector, "value");
  if (sensitive ? !state : String(state) !== String(value)) {
    throw errors.create("POKEMON_PAGE_MISMATCH", "Form field state could not be verified.", {
      step:sensitive ? "PASSWORD" : "LOGIN_FORM"
    });
  }
}

async function acceptTerms(session, context) {
  const identified = await Pages.identify(session.browser);
  if (identified.page === "MYPAGE") return {accepted:false,page:"MYPAGE"};
  if (identified.page !== "TERMS") {
    throw errors.create("POKEMON_UNEXPECTED_PAGE", "Expected MyPage or Terms after authentication.", {
      step:"TERMS",diagnostics:{identified:identified.page}
    });
  }
  await Pages.assert(session.browser, "TERMS", {timeoutMs:10000,cancellationToken:context.cancellationToken});
  await PokeToolRuntime.web.setChecked(session.browser, "#terms", true);
  if (await session.browser.exists("#privacyPolicy")) {
    await PokeToolRuntime.web.setChecked(session.browser, "#privacyPolicy", true);
  }
  await PokeToolRuntime.web.tapButton(session.browser, "#terms_button");
  await Pages.wait(session.browser, "MYPAGE", {timeoutMs:30000,cancellationToken:context.cancellationToken});
  return {accepted:true,page:"MYPAGE"};
}

async function login(session, task, context) {
  const browser = session.browser;
  context.cancellationToken && context.cancellationToken.throwIfCancelled();
  await browser.load(LOGIN_URL);
  await Pages.wait(browser, "LOGIN", {timeoutMs:30000,cancellationToken:context.cancellationToken});
  await fillVerified(browser, "#login-form-email", task.account.email, false);
  await fillVerified(browser, "#current-password", task.account.password, true);
  await PokeToolRuntime.web.tapButton(browser, "#form1Button");

  const deadline = performance.now() + 30000;
  let identified;
  while (performance.now() < deadline) {
    context.cancellationToken && context.cancellationToken.throwIfCancelled();
    identified = await Pages.identify(browser);
    if (["OTP","TERMS","MYPAGE","CAPTCHA","MAINTENANCE"].includes(identified.page)) break;
    const text = await browser.text();
    if (/パスワード.*(正しく|違)|invalid.*credential/i.test(text)) {
      throw errors.create("POKEMON_INVALID_CREDENTIAL", "Pokémon credentials were rejected.", {step:"LOGIN"});
    }
    if (/ロック|locked/i.test(text)) {
      throw errors.create("POKEMON_ACCOUNT_LOCKED", "Pokémon account is locked.", {step:"LOGIN"});
    }
    await PokeToolRuntime.web.delay(250);
  }
  if (identified && identified.page === "CAPTCHA") {
    throw errors.create("POKEMON_CAPTCHA_REQUIRED", "CAPTCHA requires manual intervention.", {step:"LOGIN"});
  }
  if (identified && identified.page === "MAINTENANCE") {
    throw errors.create("POKEMON_MAINTENANCE", "Pokémon Center is under maintenance.", {step:"LOGIN",retryable:true});
  }
  if (identified && identified.page === "OTP") {
    const started = Date.now();
    const otp = await OTP.wait({
      imapEmail:task.account.imapEmail || task.options.imapEmail,
      imapPassword:task.account.imapPassword || task.options.imapPassword,
      targetEmail:task.account.email, mode:task.mode,
      receivedAfter:started, timeoutMs:task.options.otpTimeoutMs
    }, context);
    if (otp.type !== "numericOTP") {
      throw errors.create("POKEMON_OTP_FAILED", "Expected a numeric OTP.", {step:"OTP"});
    }
    await fillVerified(browser, "#authCode", otp.value, true);
    const button = await browser.exists("#authBtn") ? "#authBtn" :
      (await browser.exists("#certify") ? "#certify" : "button[type='submit']");
    await PokeToolRuntime.web.tapButton(browser, button);
    identified = null;
    const afterOTP = performance.now() + 30000;
    while (performance.now() < afterOTP) {
      identified = await Pages.identify(browser);
      if (["TERMS","MYPAGE","CAPTCHA","MAINTENANCE"].includes(identified.page)) break;
      await PokeToolRuntime.web.delay(250);
    }
  }
  if (!identified || !["TERMS","MYPAGE"].includes(identified.page)) {
    throw errors.create("POKEMON_MYPAGE_NOT_REACHED", "Authentication did not reach MyPage or Terms.", {
      step:"LOGIN",diagnostics:{identified:identified && identified.page || "UNKNOWN"}
    });
  }
  const terms = await acceptTerms(session, context);
  await Pages.assert(browser, "MYPAGE", {timeoutMs:15000,cancellationToken:context.cancellationToken});
  return {ok:true,termsAccepted:terms.accepted};
}
module.exports = {LOGIN_URL, login, acceptTerms, fillVerified};
