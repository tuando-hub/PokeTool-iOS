"use strict";
const tasks = require("./pokemon-task");
const registry = require("./pokemon-mode-registry");
const Session = require("./pokemon-session");
const Result = require("./pokemon-result");
const errors = require("./pokemon-errors");
module.exports = async function execute(rawTask, context) {
  const task = tasks.validate(rawTask);
  const startedAt = Date.now();
  let session;
  try {
    session = await Session.create(task);
    const modeContext = Object.assign({}, context, {otp:task.options.otpProvider || null});
    const output = await registry.resolve(task.mode).execute(session, task, modeContext);
    const result = Result.make(task, output.status, output.code || null, output.message, startedAt, output.data, {history:session.history});
    await Result.persist(context.correlationId, result);
    await PokeToolRuntime.events.emit("pokemon.task.completed", {taskId:task.id,mode:task.mode,status:result.status});
    return result;
  } catch (rawError) {
    const error = errors.wrap(rawError, {step:rawError && rawError.step});
    const result = Result.make(task, "FAILED", error.code, error.message, startedAt, null, {
      step:error.step,causeCode:error.causeCode,history:session && session.history || []
    });
    try { await Result.persist(context.correlationId, result); } catch (_) {}
    await PokeToolRuntime.events.emit(error.code === "POKEMON_CANCELLED" ? "pokemon.task.cancelled" : "pokemon.task.failed", {
      taskId:task.id,mode:task.mode,code:error.code
    });
    throw Object.assign(error, {pokemonResult:result});
  } finally {
    await Session.destroy(session);
  }
};
