"use strict";

const Imap = require("imap");
const {simpleParser} = require("mailparser");
const parser = require("./getotp-parser");

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

function bridgeError(code, message, retryable) {
  return Object.assign(new Error(message), {code, retryable:Boolean(retryable)});
}

function connect(config, signal) {
  return new Promise((resolve, reject) => {
    const imap = new Imap({
      user:config.imapEmail, password:config.imapPassword,
      host:config.host, port:993, tls:true,
      tlsOptions:{rejectUnauthorized:true},
      connTimeout:15000, authTimeout:15000
    });
    const abort = () => {
      try { imap.end(); } catch (_) {}
      reject(bridgeError("OTP_CANCELLED", "OTP request was cancelled."));
    };
    signal && signal.addEventListener("abort", abort, {once:true});
    imap.once("ready", () => {
      signal && signal.removeEventListener("abort", abort);
      resolve(imap);
    });
    imap.once("error", error => {
      signal && signal.removeEventListener("abort", abort);
      const auth = /auth|login|credential/i.test(String(error && error.message));
      reject(bridgeError(
        auth ? "OTP_AUTH_FAILED" : "OTP_CONNECTION_FAILED",
        auth ? "Mailbox authentication failed." : "Mailbox connection failed.",
        !auth
      ));
    });
    imap.connect();
  });
}

function openInbox(imap) {
  return new Promise((resolve, reject) => imap.openBox("INBOX", true, error =>
    error ? reject(bridgeError("OTP_MAILBOX_UNAVAILABLE", "INBOX is unavailable.", true)) : resolve()
  ));
}

function search(imap, criteria) {
  return new Promise((resolve, reject) => imap.search(criteria, (error, ids) =>
    error ? reject(bridgeError("OTP_PROVIDER_ERROR", "Mailbox search failed.", true)) : resolve(ids || [])
  ));
}

function fetchOne(imap, uid) {
  return new Promise((resolve, reject) => {
    let settled = false;
    const finish = (error, value) => {
      if (settled) return;
      settled = true;
      error ? reject(error) : resolve(value);
    };
    const request = imap.fetch(uid, {bodies:"", markSeen:false});
    request.on("message", message => message.on("body", stream =>
      simpleParser(stream).then(value => finish(null, value))
        .catch(() => finish(bridgeError("OTP_PARSE_FAILED", "Mail MIME parsing failed.")))
    ));
    request.once("error", () => finish(bridgeError("OTP_PROVIDER_ERROR", "Mail fetch failed.", true)));
    setTimeout(() => finish(bridgeError("OTP_TIMEOUT", "Mail fetch timed out.", true)), 15000);
  });
}

function receivedAt(mail) {
  const value = mail && (mail.date || mail.receivedDate);
  const timestamp = value ? new Date(value).getTime() : 0;
  return Number.isFinite(timestamp) ? timestamp : 0;
}

async function waitForValue(request, signal) {
  const host = parser.providerHost(request.imapEmail, request.providerHosts);
  if (!host) throw bridgeError("OTP_INVALID_CONFIGURATION", "Mailbox provider is not configured.");
  const timeoutMs = Math.min(Math.max(Number(request.timeoutMs || 300000), 1000), 300000);
  const pollMs = Math.min(Math.max(Number(request.pollIntervalMs || 2000), 1000), 10000);
  const startedAt = Number(request.receivedAfter || Date.now());
  const checked = new Set();
  const resultStates = new Map();
  const imap = await connect({...request, host}, signal);
  try {
    await openInbox(imap);
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      if (signal && signal.aborted) throw bridgeError("OTP_CANCELLED", "OTP request was cancelled.");
      const ids = await search(imap, [["TO", request.targetEmail], ["SINCE", new Date(startedAt)]]);
      for (const uid of ids.map(Number).filter(Number.isFinite).sort((a,b) => b-a).slice(0,20)) {
        if (checked.has(uid)) continue;
        checked.add(uid);
        const mail = await fetchOne(imap, uid);
        if (!parser.matchesEnvelope(mail, request)) continue;
        if (request.mode === "CheckMail") {
          for (const productId of Array.isArray(request.productIds) ? request.productIds : []) {
            const state = parser.classifyLotteryMail(mail, productId);
            if (state) resultStates.set(String(productId), state);
          }
          continue;
        }
        const result = parser.parseMail(mail, request.mode);
        if (result) return {
          ok:true, type:result.type, value:result.value,
          receivedAt:new Date(receivedAt(mail) || Date.now()).toISOString(),
          messageIdHash:mail.messageId ? require("crypto").createHash("sha256")
            .update(String(mail.messageId)).digest("hex").slice(0,16) : null,
          source:"imap", elapsedMs:Date.now()-startedAt
        };
      }
      if (request.mode === "CheckMail" && resultStates.size > 0) {
        const results = Array.from(resultStates, ([productId,status]) => ({productId,status}));
        return {
          ok:true,type:"resultMail",result:{
            status:results.some(item=>item.status==="WON") ? "WON" :
              (results.some(item=>item.status==="LOST") ? "LOST" : "PENDING"),
            items:results
          },receivedAt:new Date().toISOString(),source:"imap",
          elapsedMs:Date.now()-startedAt
        };
      }
      await delay(Math.min(pollMs, Math.max(0, deadline-Date.now())));
    }
    throw bridgeError("OTP_TIMEOUT", "No matching message arrived before timeout.", true);
  } finally {
    try { imap.end(); } catch (_) {}
  }
}

module.exports = {bridgeError, waitForValue};
