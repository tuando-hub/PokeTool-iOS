"use strict";
const Pages = require("./pokemon-pages");
const errors = require("./pokemon-errors");

function cancelled(context) {
  context.cancellationToken && context.cancellationToken.throwIfCancelled();
}
async function emit(name, task, attributes) {
  return PokeToolRuntime.events.emit(name, Object.assign({
    taskId:task.id, mode:task.mode
  }, attributes || {}));
}
async function open(session, page, url, context, timeoutMs) {
  cancelled(context);
  await session.browser.load(url);
  const result = await Pages.wait(session.browser, page, {
    timeoutMs:timeoutMs || 30000, cancellationToken:context.cancellationToken
  });
  session.record(result);
  return result;
}
async function setAndVerify(browser, selector, value, sensitive) {
  await PokeToolRuntime.web.setValue(browser, selector, value);
  const actual = await browser.query(selector, "value");
  if (sensitive ? !String(actual || "").length : String(actual) !== String(value)) {
    throw errors.create("POKEMON_PAGE_MISMATCH", "A form field did not retain its expected value.", {
      step:"FORM_VERIFICATION"
    });
  }
}
async function classify(browser) {
  const page = await Pages.identify(browser);
  if (page.page === "CAPTCHA") throw errors.create("POKEMON_CAPTCHA_REQUIRED", "CAPTCHA requires manual intervention.");
  if (page.page === "MAINTENANCE") throw errors.create("POKEMON_MAINTENANCE", "Pokemon Center is under maintenance.", {retryable:true});
  if (page.page === "SESSION_EXPIRED") throw errors.create("POKEMON_SESSION_EXPIRED", "The Pokemon Center session expired.");
  return page;
}
function requireInput(task, names) {
  names.forEach(name => {
    if (task.input[name] === undefined || task.input[name] === null || task.input[name] === "") {
      throw errors.create("POKEMON_INVALID_TASK", "Required mode input is missing.", {details:{field:name}});
    }
  });
}
module.exports = {cancelled,emit,open,setAndVerify,classify,requireInput};
