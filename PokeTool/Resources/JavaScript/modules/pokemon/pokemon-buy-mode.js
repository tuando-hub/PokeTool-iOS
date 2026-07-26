"use strict";
const Login = require("./pokemon-login");
const actions = require("./pokemon-actions");
const Pages = require("./pokemon-pages");
const errors = require("./pokemon-errors");

async function execute(session, task, context) {
  await Login.login(session, task, context);
  await actions.open(session, "PRODUCT", task.input.productURL, context);
  const browser = session.browser;
  const text = await browser.text();
  if (/out of stock|sold out/i.test(text)) return {status:"OUT_OF_STOCK",data:{}};
  if (/purchase limit|already purchased/i.test(text)) return {status:"LIMIT_REACHED",data:{}};
  if (task.input.quantity && await browser.exists("#quantity")) {
    await browser.selectValue("#quantity", String(task.input.quantity));
  }
  if (!await browser.exists(".add-to-cart-button")) {
    throw errors.create("POKEMON_PRODUCT_NOT_FOUND", "Product purchase controls were not found.", {step:"PRODUCT"});
  }
  await PokeToolRuntime.web.tapButton(browser, ".add-to-cart-button");
  await Pages.wait(browser, "CART", {timeoutMs:30000,cancellationToken:context.cancellationToken});
  await PokeToolRuntime.web.tapButton(browser, ".checkout-btn, .checkout");
  await Pages.wait(browser, "CHECKOUT", {timeoutMs:30000,cancellationToken:context.cancellationToken});
  await PokeToolRuntime.web.tapButton(browser, ".next-step-button");
  await Pages.wait(browser, "REVIEW", {timeoutMs:30000,cancellationToken:context.cancellationToken});
  if (!task.options.allowFinalSubmit) return {status:"READY_FOR_FINAL_SUBMIT",data:{finalSubmit:false}};
  context.cancellationToken && context.cancellationToken.throwIfCancelled();
  if (!await browser.exists("#submitOrder")) throw errors.create("POKEMON_CHECKOUT_FAILED", "Final order control is unavailable.", {step:"REVIEW"});
  await PokeToolRuntime.web.tapButton(browser, "#submitOrder");
  try {
    await Pages.wait(browser, "ORDER_COMPLETE", {timeoutMs:30000,cancellationToken:context.cancellationToken});
  } catch (cause) {
    throw errors.create("POKEMON_PURCHASE_STATE_UNKNOWN", "Final submission outcome could not be verified; it will not be retried.", {step:"FINAL_SUBMIT",cause});
  }
  const orderId = await browser.evaluate(`(document.querySelector("[data-order-id],.order-number")||{}).textContent||null`);
  return {status:"PURCHASED",data:{orderReference:orderId ? String(orderId).slice(-8) : null}};
}
module.exports = {execute};
