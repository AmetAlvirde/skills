# Deepening

How to turn a cluster of shallow modules into a deep one safely. Assumes the
glossary in [SKILL.md](SKILL.md) — module, interface, seam, adapter.

## Dependency taxonomy

Classify the candidate's dependencies first; the category decides how the
deepened module is tested across its seam.

1. **In-process** — pure computation, in-memory state, no I/O. Always
   deepenable: merge the modules and test through the new interface directly.
   No adapter needed.
2. **Local-substitutable** — a real local stand-in exists (PGLite for
   Postgres, in-memory filesystem). Deepenable when the stand-in exists; tests
   run against it, and the seam stays internal — no port at the external
   interface.
3. **Remote but owned** — your own services across a network (internal APIs,
   microservices). Define a port at the seam; the deep module owns the logic
   and the transport is injected as an adapter — HTTP/queue in production,
   in-memory in tests. The logic sits in one deep module even though it is
   deployed across a network.
4. **True external** — third-party services you don't control (Stripe,
   Twilio). Inject the dependency as a port; tests provide a mock adapter.
   Mock only at this category — mocking your own modules couples tests to the
   implementation.

## Seam discipline

- Price every proposed seam by its adapters: one adapter is a hypothetical
  seam — plain indirection — so hold the port until the second adapter
  (usually the test one) is justified.
- A deep module may keep **internal seams** private to its implementation and
  its own tests. Keep them out of the external interface; exposing an internal
  seam because tests use it shallows the module back down.

## Testing: replace, don't layer

- New tests go at the deepened module's interface — the interface is the test
  surface — asserting observable outcomes, not internal state.
- Old unit tests on the absorbed shallow modules become waste the moment
  interface tests cover the behavior: delete them, don't stack the new suite
  on top.
- Tests describe behavior, so they survive internal refactors. A test that has
  to change when the implementation changes was testing past the interface.
