import { chromium } from "playwright";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { spawn } from "node:child_process";
const root=path.join(os.homedir(),".jimmy-bridge");
const profile=path.join(root,"chrome-profile");
const port=9323, endpoint="http://127.0.0.1:"+port;
const candidates=[
 "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
 "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
 path.join(process.env.LOCALAPPDATA||"","Google","Chrome","Application","chrome.exe"),
 "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
 "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe"
];
const browserExe=candidates.find(p=>p&&fs.existsSync(p));
const sessionFile=path.join(root,"browser-session.json");
async function liveSessionId(){try{const v=await fetch(endpoint+"/json/version").then(r=>r.json());const raw=String(v.webSocketDebuggerUrl||"");const id=raw.split("/").pop();if(id)return id}catch{}throw new Error("jimmy_browser_identity_unavailable");}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
export async function connectBrowser(){
 if(!browserExe)throw new Error("jimmy_browser_missing");
 fs.mkdirSync(profile,{recursive:true});
 let browser; try{browser=await chromium.connectOverCDP(endpoint)}catch{
  spawn(browserExe,["--remote-debugging-port="+port,"--remote-debugging-address=127.0.0.1","--user-data-dir="+profile,"--no-first-run","--no-default-browser-check"],{detached:true,stdio:"ignore"}).unref();
  for(let i=0;i<30&&!browser;i++){await sleep(500);try{browser=await chromium.connectOverCDP(endpoint)}catch{}}
 }
 if(!browser)throw new Error("jimmy_browser_unavailable");
 const context=browser.contexts()[0]||await browser.newContext(); const page=context.pages()[0]||await context.newPage();
 const sid=await liveSessionId(); fs.writeFileSync(sessionFile,JSON.stringify({id:sid,observed:Date.now()}));
 return {browser,context,page,sessionId:sid};
}
export function rotateSession(){const id=crypto.randomUUID();fs.writeFileSync(sessionFile,JSON.stringify({id,created:Date.now()}));return id;}
