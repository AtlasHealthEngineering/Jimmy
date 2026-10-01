import fs from "node:fs";import os from "node:os";import path from "node:path";
const dir=path.join(os.homedir(),".jimmy-bridge"), pendingPath=path.join(dir,"pending-publish.json"), approvalPath=path.join(dir,"publish-approval.json");
console.error("This helper is reserved for the trusted local UI and cannot approve without a pending record.");process.exit(2);
