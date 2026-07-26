# Plugin boundary

This directory defines plugin-facing interfaces only. Phase 0.5 contains no plugin loader, registry, discovery mechanism, or plugin implementation.

Core types never import or reference a concrete plugin. A future plugin may depend on the documented Core service interfaces and receive a restricted bridge through `PluginContext`.

