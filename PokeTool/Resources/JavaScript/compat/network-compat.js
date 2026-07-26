"use strict";
const bridge = require("./bridge-utils");
bridge.bind("Network", ["request"]);
const request = options => bridge.invoke("Network", "request", [options]);
PokeToolRuntime.network = Object.freeze({
  version: Native.Network.version,
  capabilities: () => Native.Network.capabilities(),
  request: request,
  get: (url, options) => request(Object.assign({}, options || {}, {url:url, method:"GET"})),
  post: (url, body, options) => request(Object.assign({}, options || {}, {url:url, method:"POST", body:body})),
  getJSON: async (url, options) => {
    const response = await request(Object.assign({}, options || {}, {
      url:url, method:"GET", responseType:"json"
    }));
    return response;
  },
  postJSON: (url, value, options) => request(Object.assign({}, options || {}, {
    url:url, method:"POST", body:JSON.stringify(value), bodyEncoding:"json",
    responseType:"json", headers:Object.assign({"Content-Type":"application/json"}, (options || {}).headers || {})
  }))
});
module.exports = PokeToolRuntime.network;
