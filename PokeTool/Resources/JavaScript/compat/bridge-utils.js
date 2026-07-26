"use strict";

function structuredError(value, namespace, operation) {
  if (value instanceof Error && value.code) return value;
  const source = value && typeof value === "object" ? value : {};
  const error = new Error(source.message || namespace + " operation failed.");
  error.name = source.name || namespace + "Error";
  error.code = source.code || namespace.toUpperCase() + "_INTERNAL_ERROR";
  error.namespace = source.namespace || namespace;
  error.operation = source.operation || operation;
  error.operationId = source.operationId || null;
  error.runtimeId = source.runtimeId || null;
  error.retryable = Boolean(source.retryable);
  error.details = source.details || {};
  return error;
}

function invoke(namespace, method, args) {
  let payload;
  try {
    payload = JSON.stringify({args:Array.prototype.slice.call(args)}, function (_key, value) {
      if (typeof value === "function" || typeof value === "symbol" || typeof value === "bigint") {
        throw new TypeError("Unsupported bridge value");
      }
      if (typeof value === "number" && !Number.isFinite(value)) {
        throw new TypeError("Non-finite number");
      }
      return value === undefined ? null : value;
    });
  } catch (_) {
    return Promise.reject(structuredError({
      code:"INVALID_ARGUMENT", message:"Arguments must be finite, acyclic JSON values."
    }, namespace, method));
  }
  try {
    return Promise.resolve(Native[namespace].invoke(method, payload)).catch(function (error) {
      throw structuredError(error, namespace, method);
    });
  } catch (error) {
    return Promise.reject(structuredError(error, namespace, method));
  }
}

function bind(namespace, methods) {
  methods.forEach(function (method) {
    Native[namespace][method] = function () {
      return invoke(namespace, method, arguments);
    };
  });
  Native[namespace].getVersion = function () { return Native[namespace].version; };
}

module.exports = {invoke:invoke, bind:bind, structuredError:structuredError};
