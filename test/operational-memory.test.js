import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { OperationalMemory } from "../src/operational-memory.js";

const dir=fs.mkdtempSync(path.join(os.tmpdir(),"jimmy-memory-"));
const m=new OperationalMemory(path.join(dir,"memory.json"));
const route={id:"vitis-website-editor",intent:"open my website editor",aliases:["my website","Brivity editor","Vitis Realty editor"],provenance:"user-taught",steps:[
 {action:"open",target:"https://vitisrealty.com"},
 {action:"find-and-open",target:"Admin Login"},
 {action:"human-authentication",target:"stop and wait for user"},
 {action:"resume",target:"website editor"}
]};
assert.equal(m.teach(route).state,"LEARNED");
assert.equal(m.recall("take me to my Brivity editor").id,"vitis-website-editor");
assert.equal(m.outcome("vitis-website-editor",true).state,"VERIFIED");
assert.ok(m.read().procedures[0].verifiedAt);
assert.equal(m.outcome("vitis-website-editor",false).state,"STALE");
assert.throws(()=>m.teach({...route,id:"bad",steps:[{password:"secret"}]}),/memory_secret_rejected/);
assert.equal(m.forget("vitis-website-editor"),true);
assert.equal(m.recall("my website editor"),null);
console.log("operational memory contract: PASS");
