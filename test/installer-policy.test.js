import assert from "node:assert/strict";
import fs from "node:fs";
const src=fs.readFileSync(new URL("../install.ps1",import.meta.url),"utf8");
const routine=["browser_open","browser_inspect","browser_set_field","browser_safe_action","browser_verify","browser_close","memory_remember","memory_recall","memory_outcome","memory_forget"];
for(const t of routine) assert.ok(src.includes(`mcp(jimmy-bridge/${t})`),`routine permission missing: ${t}`);
assert.ok(src.includes("$_ -ne 'mcp(jimmy-bridge/*)'"),"wildcard removal missing");
for(const t of ["request_publish","publish_status","execute_approved_publish"]) assert.ok(src.includes(`mcp(jimmy-bridge/${t})`),`protected ask missing: ${t}`);
assert.ok(!src.includes("dangerously-skip-permissions"),"unsafe Antigravity bypass present");
console.log("installer permission policy: PASS");
