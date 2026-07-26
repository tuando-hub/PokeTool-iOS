"use strict";

const http = require("http");
const {waitForValue} = require("./getotp-imap");
const {validate} = require("./getotp-validation");

const MAX_BODY = 128 * 1024;
const controllers = new Map();
const json = (response, status, body) => {
  response.writeHead(status, {"Content-Type":"application/json","Cache-Control":"no-store"});
  response.end(JSON.stringify(body));
};

const server = http.createServer((request, response) => {
  const expectedKey = process.env.GETOTP_API_KEY;
  if (!expectedKey || request.headers.authorization !== `Bearer ${expectedKey}`) {
    return json(response, 401, {ok:false,error:{code:"OTP_AUTH_FAILED",message:"Service authorization failed."}});
  }
  if (request.method === "DELETE" && request.url.startsWith("/v1/operations/")) {
    const id = decodeURIComponent(request.url.slice("/v1/operations/".length));
    const controller = controllers.get(id);
    if (controller) controller.abort();
    controllers.delete(id);
    return json(response, 200, {ok:true,cancelled:Boolean(controller)});
  }
  if (request.method !== "POST" || request.url !== "/v1/otp/wait") {
    return json(response, 404, {ok:false,error:{code:"OTP_PROVIDER_ERROR",message:"Route not found."}});
  }
  let raw = "";
  request.on("data", chunk => {
    raw += chunk;
    if (Buffer.byteLength(raw) > MAX_BODY) request.destroy();
  });
  request.on("end", async () => {
    let body;
    try { body = JSON.parse(raw); }
    catch (_) { return json(response, 400, {ok:false,error:{code:"OTP_INVALID_CONFIGURATION",message:"Invalid JSON."}}); }
    const invalid = validate(body);
    if (invalid) return json(response, 400, {ok:false,error:{code:"OTP_INVALID_CONFIGURATION",message:invalid}});
    const controller = new AbortController();
    controllers.set(body.operationId, controller);
    response.on("close", () => controller.abort());
    try {
      const value = await waitForValue(body, controller.signal);
      json(response, 200, value);
    } catch (error) {
      json(response, error.code === "OTP_AUTH_FAILED" ? 401 : 502, {
        ok:false, error:{
          code:error.code || "OTP_PROVIDER_ERROR",
          message:error.message || "OTP provider failed.",
          retryable:Boolean(error.retryable)
        }
      });
    } finally {
      controllers.delete(body.operationId);
    }
  });
});

if (require.main === module) {
  server.listen(Number(process.env.GETOTP_PORT || 8787), "127.0.0.1");
}
module.exports = {server};
