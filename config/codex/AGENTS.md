# Browser automation: use agent-browser

When a task requires interacting with a browser — navigating pages, clicking elements, filling
forms, taking screenshots, extracting page content, or testing a web UI — use `agent-browser`
(the CLI installed via `brew install agent-browser && agent-browser install`).

**The workflow:**
```sh
agent-browser open <url>
agent-browser snapshot -i       # see interactive elements as @eN refs
agent-browser click @e3         # act on a ref
agent-browser snapshot -i       # re-snapshot after any page change
```

Use `agent-browser` instead of Chrome DevTools, Playwright, Puppeteer, or headless Chrome
unless one of these applies (and state the reason when choosing the alternative):

1. The task specifically requires Chrome DevTools Protocol features that agent-browser does not
   expose (e.g. performance tracing, heap snapshots, network interception, CDP event streams).
2. The task requires Playwright/Puppeteer test scripts that will be committed to the repo and
   run in CI (agent-browser is a session tool, not a test framework).
3. A specific browser automation library is already integrated in the project and the user
   asked to use it.

When none of those apply, prefer agent-browser — it is faster, lower-token, and already
installed on this machine.
