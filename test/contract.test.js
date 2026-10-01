import fs from "node:fs";
const src=fs.readFileSync(new URL("../src/server.js",import.meta.url),"utf8");
const must=["memory_remember","memory_recall","memory_outcome","memory_forget","browser_open","browser_inspect","browser_set_field","browser_safe_action","browser_verify","request_publish","publish_status","execute_approved_publish","browser_close"];
for(const name of must)if(!src.includes('server.tool("'+name+'"'))throw new Error("missing tool "+name);
if(/CONFIRM_PUBLISH|challenge:z/.test(src))throw new Error("model-visible publish secret remains");
if(!src.includes("independent_human_approval_required"))throw new Error("human approval guard missing");
if(!src.includes("browser_session_mismatch"))throw new Error("session binding missing");
console.log("CONTRACT_V03_PASS",must.join(","));
