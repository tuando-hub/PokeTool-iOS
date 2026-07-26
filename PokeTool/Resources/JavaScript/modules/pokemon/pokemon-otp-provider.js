"use strict";
const errors = require("./pokemon-errors");
const security = require("./pokemon-security");

function configured(options) {
  return Boolean(options && options.serviceURL && options.apiKey);
}
async function wait(request, context) {
  const options = context && context.otp || {};
  if (options.mockResult) {
    if (context.cancellationToken) context.cancellationToken.throwIfCancelled();
    return Object.assign({ok:true,source:"mock",elapsedMs:0,receivedAt:new Date().toISOString()}, options.mockResult);
  }
  if (!configured(options)) {
    throw errors.create("POKEMON_OTP_FAILED", "Production OTP provider requires configuration.", {
      step:"OTP",diagnostics:{provider:"requiresConfiguration"}
    });
  }
  const totalTimeout = Math.min(Math.max(Number(request.timeoutMs || 120000),1000),120000);
  const deadline = Date.now() + totalTimeout;
  const body = {
    operationId:null,
    imapEmail:request.imapEmail,
    imapPassword:request.imapPassword,
    targetEmail:request.targetEmail,
    mode:request.mode,
    productIds:Array.isArray(request.productIds) ? request.productIds : [],
    sender:request.sender || null,
    receivedAfter:request.receivedAfter || Date.now(),
    timeoutMs:Math.min(totalTimeout,5000),
    pollIntervalMs:Math.max(Number(request.pollIntervalMs || 2000),1000)
  };
  while (Date.now() < deadline) {
    context.cancellationToken && context.cancellationToken.throwIfCancelled();
    body.operationId = await PokeToolRuntime.system.uuid();
    body.timeoutMs = Math.min(5000, Math.max(1000, deadline-Date.now()));
    try {
      const response = await PokeToolRuntime.network.postJSON(
        String(options.serviceURL).replace(/\/$/,"") + "/v1/otp/wait", body,
        {headers:{Authorization:"Bearer " + options.apiKey},timeoutMs:body.timeoutMs+2000,responseType:"json"}
      );
      const value = response.body || response;
      if (value && value.ok === true &&
          (value.value || (value.type === "resultMail" && value.result))) return value;
      if (value && value.error && value.error.code === "OTP_TIMEOUT") continue;
      throw errors.create("POKEMON_OTP_FAILED", "OTP provider did not return a valid result.", {
        step:"OTP",diagnostics:security.redact(value && value.error || {})
      });
    } catch (error) {
      if (context.cancellationToken && context.cancellationToken.cancelled) {
        throw errors.create("POKEMON_CANCELLED", "OTP wait was cancelled.", {step:"OTP"}, error);
      }
      if (error && ["NETWORK_TIMEOUT","OTP_TIMEOUT"].includes(error.code) && Date.now()<deadline) continue;
      throw errors.create("POKEMON_OTP_FAILED", "OTP provider request failed.", {
        step:"OTP",retryable:Boolean(error && error.retryable)
      }, error);
    }
  }
  throw errors.create("POKEMON_OTP_FAILED", "OTP wait timed out.", {step:"OTP",retryable:true});
}
module.exports = {
  version:"1.0.0",
  capabilities:options => ({mock:true,production:configured(options) ? true : "requiresConfiguration"}),
  wait
};
