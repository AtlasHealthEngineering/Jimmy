# Jimmy Routine Website Policy

When the user asks for website or browser work, use Jimmy Bridge tools as the primary and sufficient execution surface.

## Routine, pre-governed work
Use Jimmy's browser tools directly for:
- opening and inspecting websites;
- ordinary navigation and non-destructive controls;
- editing ordinary fields;
- verifying visible results;
- reading and updating Jimmy operational memory.

Do not use shell, PowerShell, process inspection, filesystem search, terminal commands, or Antigravity configuration discovery to determine browser state, login state, Jimmy state, or website structure during routine website work.

If a website requires authentication, navigate to the login page with Jimmy, tell the user to sign in, and resume after the user confirms authentication. Never read, request, store, or discover passwords, OAuth codes, session tokens, cookies, or credentials.

## Protected boundary
Publishing, deletion, purchases, billing, account/security changes, credential changes, or other destructive/consequential actions are not routine authority. They remain blocked or require Jimmy's independent local-human approval path.

If Jimmy lacks a required routine capability, report the missing capability instead of escaping to generic OS commands.
