import fs from "node:fs";
const src=fs.readFileSync(new URL("../src/server.js",import.meta.url),"utf8");
const browserRuntime=fs.readFileSync(new URL("../src/browser-runtime.js",import.meta.url),"utf8");
if(!browserRuntime.includes("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))throw new Error("macOS Chrome discovery missing");
const must=["memory_remember","memory_recall","memory_outcome","memory_forget","browser_open","browser_inspect","browser_set_field","browser_safe_action","browser_verify","request_publish","publish_status","execute_approved_publish","browser_close"];
for(const name of must)if(!src.includes('server.tool("'+name+'"'))throw new Error("missing tool "+name);
if(/CONFIRM_PUBLISH|challenge:z/.test(src))throw new Error("model-visible publish secret remains");
if(!src.includes("independent_human_approval_required"))throw new Error("human approval guard missing");
if(!src.includes("browser_session_mismatch"))throw new Error("session binding missing");
const boundary=[
  'reason:"no_pending_publish"',
  'reason:"approval_expired"',
  'reason:"browser_session_mismatch"',
  'reason:"independent_human_approval_required"',
  'a.id!==pending.id','a.session!==pending.session','a.decision!=="approve"','a.expires<=Date.now()'
];
for(const guard of boundary)if(!src.includes(guard))throw new Error("protected boundary guard missing: "+guard);
const protectedMatch=src.match(/const PROTECTED=\/([^/]+)\/i;/);
if(!protectedMatch)throw new Error("protected action policy missing");
const protectedWords=protectedMatch[1].split("|");
for(const word of ["publish","delete","destroy","billing","password","security","credential","account"])if(!protectedWords.includes(word))throw new Error("protected action weakened: "+word);
if(protectedWords.includes("remove"))throw new Error("reversible draft removal incorrectly protected");
console.log("CONTRACT_V046_PASS",must.join(","));
