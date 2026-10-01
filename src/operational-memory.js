import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SECRET=/(password|passwd|oauth|access[_ -]?token|refresh[_ -]?token|session[_ -]?token|api[_ -]?key|authorization|bearer)/i;
const norm=s=>String(s??"").trim().toLowerCase().replace(/[^a-z0-9]+/g," ").trim();

export class OperationalMemory {
  constructor(file=path.join(os.homedir(),".jimmy-bridge","operational-memory.json")){
    this.file=file;fs.mkdirSync(path.dirname(file),{recursive:true});
  }
  read(){try{const x=JSON.parse(fs.readFileSync(this.file,"utf8"));return Array.isArray(x.procedures)?x:{version:1,procedures:[]};}catch{return{version:1,procedures:[]}}}
  write(db){fs.writeFileSync(this.file,JSON.stringify(db,null,2),{encoding:"utf8",mode:0o600});}
  teach(p){
    const raw=JSON.stringify(p);if(SECRET.test(raw))throw new Error("memory_secret_rejected");
    if(!p?.id||!p?.intent||!Array.isArray(p.aliases)||!Array.isArray(p.steps))throw new Error("memory_invalid_procedure");
    const now=new Date().toISOString(),db=this.read(),old=db.procedures.find(x=>x.id===p.id);
    const item={id:p.id,intent:p.intent,aliases:[...new Set([p.intent,...p.aliases])],steps:p.steps,provenance:p.provenance??"user-taught",state:"LEARNED",successes:old?.successes??0,failures:old?.failures??0,updatedAt:now,verifiedAt:old?.verifiedAt??null};
    db.procedures=db.procedures.filter(x=>x.id!==p.id);db.procedures.push(item);this.write(db);return item;
  }
  recall(query){
    const q=norm(query),terms=new Set(q.split(" ").filter(Boolean));let best=null,score=0;
    for(const p of this.read().procedures){for(const a of p.aliases){const n=norm(a);let s=n===q?100:[...new Set(n.split(" "))].filter(x=>terms.has(x)).length;if(s>score){score=s;best=p}}}
    return score>0?best:null;
  }
  outcome(id,ok){
    const db=this.read(),p=db.procedures.find(x=>x.id===id);if(!p)throw new Error("memory_procedure_not_found");
    if(ok){p.successes++;p.state="VERIFIED";p.verifiedAt=new Date().toISOString();}else{p.failures++;p.state="STALE";}p.updatedAt=new Date().toISOString();this.write(db);return p;
  }
  forget(id){const db=this.read(),n=db.procedures.length;db.procedures=db.procedures.filter(x=>x.id!==id);this.write(db);return n!==db.procedures.length;}
}
