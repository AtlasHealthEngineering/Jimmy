import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const read = p => fs.readFileSync(new URL(p, import.meta.url), "utf8");
const installer=read("../install.ps1");
const uninstaller=read("../uninstall.ps1");
const chat=read("../src/jimmy-chat.ps1");
const spec=read("../installer/JimmyBridge.iss");
const server=read("../src/server.js");
const routine=["browser_open","browser_inspect","browser_set_field","browser_safe_action","browser_verify","browser_close","memory_remember","memory_recall","memory_outcome","memory_forget"];
const publish=["request_publish","publish_status","execute_approved_publish"];
for(const tool of [...routine,...publish]){
  assert.ok(installer.includes("'mcp(jimmy-bridge/"+tool+")'"),"missing governed tool "+tool);
}
assert.ok(installer.includes("$granted=@($routine + $publishWorkflow)"),"publish transport permissions missing");
assert.ok(installer.includes("$_ -notin $granted"),"CLI prompt elimination is incomplete");
assert.ok(installer.includes("$_ -ne 'mcp(jimmy-bridge/*)'"),"wildcard grants must be stripped");
assert.ok(installer.includes("explicitly denied in Antigravity settings"),"explicit local deny must fail closed");
assert.ok(!installer.includes("dangerously-skip-permissions"),"global permission bypass prohibited");
assert.ok(installer.includes("browser-consent-v1.json") && installer.includes("jimmy-browser-routine-v1"),"versioned consent receipt missing");
assert.ok(installer.includes("GetCurrent().User.Value"),"consent must be tied to the Windows user");
assert.ok(installer.includes("MessageBoxButtons]::YesNo"),"consent requires explicit yes/no");
assert.ok(installer.includes("MessageBoxDefaultButton]::Button2"),"No must be the default choice");
assert.ok(installer.includes("if($NoConsentUI -or ![Environment]::UserInteractive)"),"noninteractive setup must not grant consent");
assert.ok(spec.includes("WizardSilent") && spec.includes("-NoConsentUI"),"silent installer must disable consent UI");
assert.ok(spec.includes("function InitializeSetup()") && spec.includes("MB_DEFBUTTON2") && spec.includes("Result := False"),"installer must deny declined consent before extraction");
assert.ok(spec.includes("-ConsentGranted") && installer.includes("[switch]$ConsentGranted"),"installer must pass one-time native consent to setup");
assert.ok(installer.includes("Get-Content $settingsPath -Raw -Encoding UTF8"),"installer must read existing Unicode settings");
assert.ok(uninstaller.includes("Get-Content $settingsPath -Raw -Encoding UTF8"),"uninstaller must preserve Unicode settings");
assert.ok(uninstaller.includes("Remove-Item $consentPath") && uninstaller.includes("$_ -notmatch '^mcp\\(jimmy-bridge/'"),"uninstall must revoke consent and tool grants");
assert.ok(chat.includes("--model gemini-3.8-flash-low -p $policy"),"chat must choose the verified browser-capable model");
assert.ok(!chat.includes("dangerously-skip-permissions"),"chat may not bypass policy");
for(const guard of ["independent_human_approval_required","browser_session_mismatch","no_pending_publish","approval_expired"]){
  assert.ok(server.includes(guard),"publish boundary missing: "+guard);
}

const start=installer.indexOf("  $routine=@(");
const writerStart=installer.indexOf("[IO.File]::WriteAllText($settingsPath,",start);
const writerEnd=installer.indexOf("\n",writerStart);
assert.ok(start>=0 && writerStart>start && writerEnd>writerStart,"cannot locate actual settings writer");
const permissionsCode=installer.slice(start,writerEnd);
assert.ok(permissionsCode.includes("[Text.UTF8Encoding]::new($false)"),"Windows PowerShell writer must exclude UTF-8 BOM");
assert.ok(!installer.includes("Set-Content -Path $settingsPath -Encoding UTF8"),"legacy BOM writer remains");

// Exercise exactly the installer permission generator on Windows. Test the actual
// output bytes, routine allow rules, preserved external rules, and explicit denials.
if(process.platform==="win32"){
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),"jimmy-permission-policy-"));
  const settingsPath=path.join(temp,"settings.json");
  const run=()=> {
    const escaped=settingsPath.replaceAll("'","''");
    const ps="$ErrorActionPreference='Stop'; $settingsPath='"+escaped+"'; $settings=Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json; "+permissionsCode;
    return execFileSync("powershell.exe",["-NoProfile","-NonInteractive","-Command",ps],{timeout:180000,stdio:"pipe"});
  };
  try {
    const before={profile:{displayName:"José 🌸",preferences:{region:"München",key:"中文"}},permissions:{
      allow:["mcp(other-plugin/inspect)"],
      ask:["mcp(jimmy-bridge/browser_open)","mcp(jimmy-bridge/execute_approved_publish)","mcp(other-plugin/publish)"],
      deny:["read_file(*)","command(*)"]
    }};
    fs.writeFileSync(settingsPath,JSON.stringify(before));
    run();
    const bytes=fs.readFileSync(settingsPath);
    assert.equal(bytes[0],0x7b,"settings must begin with JSON, not BOM");
    assert.notDeepEqual([...bytes.subarray(0,3)],[0xef,0xbb,0xbf],"UTF-8 BOM rejected by Antigravity");
    const complete=JSON.parse(bytes.toString("utf8"));
    assert.deepEqual(complete.profile,before.profile,"Unicode and unrelated deep settings must survive rewrite");
    const actual=complete.permissions;
    for(const tool of [...routine,...publish]){
      const rule="mcp(jimmy-bridge/"+tool+")";
      assert.ok(actual.allow.includes(rule),"not preauthorized: "+rule);
      assert.ok(!actual.ask.includes(rule),"redundant CLI prompt for: "+rule);
    }
    assert.ok(actual.allow.includes("mcp(other-plugin/inspect)"),"unrelated allow lost");
    assert.ok(actual.ask.includes("mcp(other-plugin/publish)"),"unrelated ask lost");
    assert.deepEqual(actual.deny,before.permissions.deny,"unrelated denials changed");
    assert.ok(!actual.allow.includes("mcp(jimmy-bridge/*)"),"wildcard grant found");
    const denied={permissions:{allow:[],ask:[],deny:["mcp(jimmy-bridge/browser_open)"]}};
    fs.writeFileSync(settingsPath,JSON.stringify(denied));
    assert.throws(()=>run(),/Command failed|status|Error/i,"an explicit denial must block enrollment");
    assert.deepEqual(JSON.parse(fs.readFileSync(settingsPath,"utf8")),denied,"deny case must not rewrite permissions");
  } finally {
    fs.rmSync(temp,{recursive:true,force:true});
  }
}
console.log("Jimmy one-time consent, no-prompt routine permissions, and protected publishing policy: PASS");
