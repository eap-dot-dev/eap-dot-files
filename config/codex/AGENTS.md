# Standing guidance

## Never leave a process running that nothing will stop

A background process must carry its own bound. Do not rely on a cleanup line later in the
script — if the shell wrapper is orphaned, killed, or the session ends first, that line never
runs and the process survives indefinitely.

**The rule:** bound the process, not the script.

```sh
timeout 60 sh -c 'while :; do :; done' &     # dies on its own
trap 'kill 0' EXIT INT TERM                  # fires on every exit path, including SIGTERM
ulimit -t 30                                 # hard CPU-seconds ceiling
```

**Before reaching for synthetic load at all:** it is usually the wrong tool. To test behavior
under CPU contention, prefer raising the timeout under test, asserting on the timeout value
directly, or injecting a delay — none of which can outlive the session.

The same rule covers anything that outlives its parent: dev servers, file watchers, tunnels,
`tail -f`, polling loops. If you start one, either bound it or tell the operator it is running
and how to stop it — in the same message, not a later one.

## Clean up what you started, in the turn you started it

Temp files, scratch scripts under `/tmp`, background jobs, spawned servers. If a command
created it and the work is done, remove it before ending the turn. If it must outlive the turn,
say so explicitly and give the exact command to stop or delete it.

## Browser automation: use agent-browser

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
