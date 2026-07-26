(function (global) {
  "use strict";

  const runtime = {
    version: "0.0.1",
    phase: 0,
    healthCheck: function () {
      return {
        ok: true,
        runtime: "JavaScriptCore",
        phase: this.phase,
        version: this.version
      };
    }
  };

  global.PokeToolRuntime = runtime;
})(this);

