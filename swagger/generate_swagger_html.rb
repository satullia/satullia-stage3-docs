#!/usr/bin/env ruby
# ============================================================================
# Generates swagger/satullia-api.html — a self-contained, Swagger-UI-style
# interactive page with a "Try it out" test section for every API operation.
#
# The page embeds the OpenAPI spec (converted to JSON) and renders:
#   * top bar with server selector + bearer token (with quick login)
#   * tag sidebar + operation cards (method badge, path, summary, description)
#   * editable path/query parameters, request-body editor (example-prefilled)
#   * Execute button -> live fetch, status code, elapsed time, pretty body
#   * curl copy button per operation
#
# Regenerate after editing satullia-api.yaml:
#   ruby generate_swagger_html.rb
# ============================================================================
require "yaml"
require "json"

SRC = File.expand_path("satullia-api.yaml", __dir__)
OUT = File.expand_path("satullia-api.html", __dir__)

spec = YAML.safe_load_file(SRC, aliases: true)
json = JSON.pretty_generate(spec).gsub("</", "<\\/")
built = Time.now.strftime("%Y-%m-%d %H:%M")

PATH_COUNT = spec.fetch("paths", {}).size
OPCOUNT = spec.fetch("paths", {}).values.sum { |item| item.keys.grep(/\A(get|post|put|delete|patch|head|options)\z/).size }

html = <<~'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Satullia API — Swagger UI</title>
<style>
  :root{
    --bg:#f3f4f7; --card:#ffffff; --border:#d9dee6; --text:#1c2733; --muted:#5b6b7c;
    --top:#1b1b1f; --top-text:#f5f6fa; --accent:#66b8ff;
    --get:#61affe; --post:#49cc90; --put:#fca130; --delete:#f93e3e; --head:#9012fe; --patch:#50e3c2;
    --mono:ui-monospace,SFMono-Regular,Menlo,Consolas,"Liberation Mono",monospace;
  }
  *{box-sizing:border-box}
  body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
    background:var(--bg);color:var(--text);font-size:15px}
  a{color:#1f6feb;text-decoration:none}
  /* ---------- top bar ---------- */
  header{position:fixed;top:0;left:0;right:0;z-index:50;background:var(--top);color:var(--top-text);
    padding:10px 18px;display:flex;flex-wrap:wrap;gap:14px;align-items:center;
    border-bottom:1px solid #000}
  header .brand{display:flex;align-items:center;gap:10px;font-weight:700;font-size:17px;letter-spacing:.2px}
  header .brand .logo{width:26px;height:26px;border-radius:6px;background:linear-gradient(135deg,#66b8ff,#49cc90);
    display:inline-flex;align-items:center;justify-content:center;font-size:13px;color:#05203a}
  header label{font-size:11px;text-transform:uppercase;letter-spacing:.6px;color:#9aa4b2}
  header select,input{background:#26262c;color:var(--top-text);border:1px solid #3d3d45;border-radius:6px;
    padding:6px 8px;font-size:13px;font-family:var(--mono);min-width:120px}
  header .btn{background:#2f2f36;border:1px solid #4a4a54;color:var(--top-text);border-radius:6px;
    padding:6px 12px;font-size:12.5px;cursor:pointer}
  header .btn:hover{background:#3b3b44}
  header .btn.primary{background:#49cc90;border-color:#49cc90;color:#062b1a;font-weight:700}
  .spacer{flex:1}
  #toast{position:fixed;top:60px;right:16px;z-index:99;background:#152238;color:#e8f1ff;padding:10px 16px;
    border-radius:8px;font-size:13px;box-shadow:0 6px 24px rgba(0,0,0,.25);opacity:0;transition:opacity .25s;
    pointer-events:none;max-width:420px}
  #toast.show{opacity:1}
  /* ---------- layout ---------- */
  .wrap{display:flex;margin-top:60px;min-height:calc(100vh - 60px)}
  aside{width:270px;flex:0 0 270px;background:#ffffff;border-right:1px solid var(--border);
    padding:14px 10px 30px;position:sticky;top:60px;height:calc(100vh - 60px);overflow:auto}
  aside .tag{font-size:11px;text-transform:uppercase;letter-spacing:.8px;color:var(--muted);
    padding:12px 10px 4px;font-weight:700}
  aside a{display:flex;justify-content:space-between;gap:8px;padding:5px 10px;border-radius:6px;
    color:var(--text);font-family:var(--mono);font-size:12px;align-items:center}
  aside a:hover{background:#eef1f6}
  aside a .m{font-size:10.5px;font-weight:800;padding:1px 6px;border-radius:4px;color:#fff}
  aside a.is-active{background:#e3ecf9}
  main{flex:1;padding:22px 28px 80px;max-width:1180px;min-width:0}
  /* ---------- hero / notes ---------- */
  .hero{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:20px 24px;margin-bottom:22px}
  .hero h1{margin:0 0 6px;font-size:22px}
  .hero p{margin:4px 0;color:var(--muted);line-height:1.5}
  .notes{background:#fff8e8;border:1px solid #f2dfb3;border-radius:10px;padding:14px 18px;margin-bottom:26px}
  .notes h4{margin:0 0 8px;font-size:13px;text-transform:uppercase;letter-spacing:.6px;color:#8a6d1a}
  .notes li{margin:3px 0;font-size:13.5px;color:#5f5400}
  .notes code{font-family:var(--mono);background:#fff;border:1px solid #e8d9a8;border-radius:4px;
    padding:0 4px;font-size:12px}
  /* ---------- tag sections ---------- */
  .tagsec{margin-bottom:14px}
  .taghead{display:flex;align-items:baseline;gap:10px;margin:26px 0 12px}
  .taghead h2{margin:0;font-size:19px;border-bottom:2px solid #cfd6df;padding-bottom:6px}
  .taghead .cnt{font-size:12px;color:var(--muted);font-family:var(--mono)}
  /* ---------- operation cards ---------- */
  .op{background:var(--card);border:1px solid var(--border);border-radius:10px;margin-bottom:14px;
    box-shadow:0 1px 2px rgba(20,30,50,.04);transition:box-shadow .15s}
  .op.open{box-shadow:0 6px 22px rgba(20,30,50,.10)}
  .op-head{display:flex;align-items:center;gap:12px;padding:12px 16px;cursor:pointer;flex-wrap:wrap}
  .op-head:hover{background:#fafbfd}
  .op-head .badge{font-family:var(--mono);font-weight:800;font-size:12px;color:#fff;border-radius:5px;
    padding:4px 9px;min-width:64px;text-align:center}
  .op-head .path{font-family:var(--mono);font-size:14px;font-weight:600;word-break:break-all}
  .op-head .sum{color:var(--muted);font-size:13px;margin-left:auto;padding-right:6px}
  .op-head .chev{color:#9aa4b2;transition:transform .15s}
  .op.open .op-head .chev{transform:rotate(90deg)}
  .op-body{display:none;border-top:1px solid var(--border);padding:16px 18px;background:#fbfcfe}
  .op.open .op-body{display:block}
  .op-desc{white-space:pre-wrap;color:#36434f;font-size:13.5px;line-height:1.55;margin:0 0 12px}
  .op-desc code{font-family:var(--mono);background:#eef1f5;border-radius:4px;padding:0 4px;font-size:12px}
  table.pars{width:100%;border-collapse:collapse;margin:6px 0 14px;font-size:13px}
  table.pars th{text-align:left;color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.5px;
    border-bottom:1px solid var(--border);padding:6px 8px}
  table.pars td{border-bottom:1px solid #eef1f5;padding:7px 8px;vertical-align:middle}
  table.pars td input{width:100%;min-width:140px;font-family:var(--mono);font-size:12.5px;padding:5px 8px;
    border:1px solid #c9d1da;border-radius:6px;background:#fff}
  table.pars td input:focus{outline:2px solid #a0c6f5;border-color:#66b8ff}
  .req-dot{color:#f93e3e;font-weight:800}
  .par-in,.par-type{font-family:var(--mono);font-size:11.5px;text-transform:uppercase;letter-spacing:.4px;color:var(--muted)}
  .lbl{font-size:12px;font-weight:700;color:#36434f;text-transform:uppercase;letter-spacing:.4px;margin:10px 0 6px}
  textarea{width:100%;min-height:110px;font-family:var(--mono);font-size:12.5px;line-height:1.5;padding:9px 11px;
    border:1px solid #c9d1da;border-radius:8px;background:#fff;resize:vertical;color:#152238}
  textarea:focus{outline:2px solid #a0c6f5;border-color:#66b8ff}
  input[type=file]{font-size:12.5px;font-family:var(--mono)}
  .op-actions{display:flex;gap:10px;margin-top:14px;align-items:center}
  .op-actions .btn{background:#ffffff;border:1px solid #b9c2cc;color:#1c2733;border-radius:6px;padding:7px 16px;
    font-size:13px;cursor:pointer;font-weight:600}
  .op-actions .btn:hover{border-color:#8b99a8}
  .op-actions .btn.exec{background:#49cc90;border-color:#49cc90;color:#062b1a;font-weight:700}
  .op-actions .btn.exec:disabled{opacity:.55;cursor:wait}
  .op-actions .hint{font-size:12px;color:var(--muted);margin-left:auto;font-family:var(--mono)}
  /* ---------- test results ---------- */
  .result{display:none;margin-top:14px;border:1px solid var(--border);border-radius:10px;overflow:hidden}
  .result.show{display:block}
  .r-head{display:flex;align-items:center;gap:12px;padding:9px 14px;background:#f2f4f8;border-bottom:1px solid var(--border);
    flex-wrap:wrap;font-size:12.5px}
  .r-status{font-family:var(--mono);font-weight:800;padding:3px 10px;border-radius:5px;color:#fff;font-size:12px}
  .r-status.good{background:#49cc90}.r-status.bad{background:#f93e3e}.r-status.warn{background:#fca130}
  .r-meta{color:var(--muted);font-family:var(--mono);font-size:11.5px}
  .r-desc{color:#36434f}
  .r-url{font-family:var(--mono);font-size:11.5px;color:#5b6b7c;background:#fff;border:1px solid var(--border);
    border-radius:6px;padding:2px 8px;margin-left:auto}
  pre.res-body{margin:0;padding:14px 16px;background:#152238;color:#e8ecf3;font-family:var(--mono);
    font-size:12.5px;line-height:1.55;overflow:auto;max-height:460px;white-space:pre-wrap;word-break:break-word}
  pre.res-body .tok-s{color:#8fd492}.tok-n{color:#f6b73c}.tok-k{color:#71a9f0}.tok-b{color:#e58ac2}
  .err-note{color:#ff9d9d}
  .curl-wrap{display:flex;gap:8px;margin-top:10px;align-items:center}
  .curl-wrap pre{flex:1;margin:0;background:#f1f3f7;border:1px solid var(--border);border-radius:8px;
    padding:8px 12px;font-size:11.5px;overflow:auto;font-family:var(--mono);color:#33414f}
  .curl-wrap button{background:#fff;border:1px solid #b9c2cc;border-radius:6px;padding:5px 12px;font-size:12px;
    cursor:pointer}
  .error{color:#c0392b;font-size:13px;padding:6px 0}
  footer{color:#8a94a1;font-size:12px;text-align:center;padding:30px 0 10px;font-family:var(--mono)}
  @media(max-width:900px){aside{display:none}.wrap{margin-top:60px}.hero h1{font-size:18px}}
</style>
</head>
<body>

<header>
  <div class="brand"><span class="logo">S</span> Satullia API</div>
  <div>
    <label for="server">Server</label>
    <select id="server"></select>
  </div>
  <div>
    <label for="token">Bearer token</label>
    <input id="token" type="text" placeholder="JWT access token" style="min-width:280px" autocomplete="off">
  </div>
  <div>
    <label>Quick login</label>
    <input id="loginEmail" type="email" placeholder="email" value="test@gmail.com" style="min-width:170px">
    <input id="loginPass" type="password" placeholder="password" value="passWORD@@22" style="min-width:120px">
    <button class="btn primary" id="loginBtn">Get token</button>
  </div>
  <div class="spacer"></div>
  <button class="btn" id="expAll">Expand all</button>
  <button class="btn" id="colAll">Collapse all</button>
</header>
<div id="toast"></div>

<div class="wrap">
  <aside id="sidebar"></aside>
  <main>
    <div class="hero">
      <h1><span id="specTitle"></span> <span id="specVer" style="font-size:13px;color:#5b6b7c"></span></h1>
      <p id="specDesc"></p>
    </div>
    <div class="notes">
      <h4>Known deployment states (see API-REFERENCE.md)</h4>
      <ul>
        <li><code>/api/v1/deck/saved</code> and <code>/api/v1/deck/recent</code> are <b>planned</b> — they currently return <code>404</code>.</li>
        <li>The gateway does not route <code>folders</code>, <code>profile</code>, <code>post</code> prefixes yet — pick the <i>local</i> server for those, or expect <code>404 Service not found</code>.</li>
        <li>Post routes are registered <b>without</b> the <code>/api/v1</code> prefix (<code>/posts</code>) — use the local post-service URL (<code>http://localhost:3003</code>).</li>
        <li>File download of a missing file returns <code>200</code> with an HTML page (never 404); uploads are not proxied on the file domain (<code>405</code>).</li>
        <li>Unicode query params must be percent-encoded in URLs.</li>
      </ul>
    </div>
    <div id="content"></div>
    <footer>Generated from <code>satullia-api.yaml</code> · __BUILT__ · prepared for the Satullia front-end team</footer>
  </main>
</div>

<script>
"use strict";
/* ============================= spec ============================= */
const SPEC = __SPEC_JSON__;

/* ============================= helpers ============================= */
const $ = s => document.querySelector(s);
const $$ = s => Array.from(document.querySelectorAll(s));
const esc = s => String(s).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const METHODS = {get:"#61affe",post:"#49cc90",put:"#fca130",delete:"#f93e3e",head:"#9012fe",patch:"#50e3c2",options:"#0b5cab"};
const fmtTime = t => t < 1000 ? Math.round(t) + " ms" : (t/1000).toFixed(2) + " s";

function toast(msg, ms){
  const t = $("#toast"); t.textContent = msg; t.classList.add("show");
  clearTimeout(toast._h); toast._h = setTimeout(() => t.classList.remove("show"), ms || 3500);
}

function resolve(ref, depth){
  if (depth > 6 || !ref || typeof ref !== "string") return {type:"object"};
  if (!ref.startsWith("#/components/")) return {type:"object"};
  const parts = ref.replace("#/components/", "").split("/");
  let node = SPEC.components;
  for (const p of parts){ node = node && node[p]; if (!node) return {type:"object"}; }
  return node;
}
function ownProp(schema){ return schema && schema.properties && Object.entries(schema.properties); }
function sampleFor(schema, depth){
  if (depth > 5) return null;
  schema = schema || {type:"object"};
  if (schema.$ref) schema = resolve(schema.$ref, depth + 1);
  if (schema.allOf && schema.allOf.length){ let out = {}; for (const s of schema.allOf){ const o = sampleFor(s, depth + 1); if (o && typeof o === "object") out = Object.assign(out, o); } return out; }
  switch (schema.type){
    case "object": {
      const out = {};
      const props = Object.entries(schema.properties || {});
      const req = new Set(schema.required || []);
      const ordered = [...props.filter(([k]) => req.has(k)), ...props.filter(([k]) => !req.has(k))];
      for (const [k, ps] of ordered) out[k] = ps.example !== undefined ? ps.example : sampleFor(ps, depth + 1);
      return out;
    }
    case "array": return [sampleFor(schema.items, depth + 1)];
    case "integer": case "number": return 0;
    case "boolean": return false;
    case "string": default:
      if (schema.enum && schema.enum.length) return schema.enum[0];
      if (schema.format === "uuid") return "00000000-0000-0000-0000-000000000000";
      if (schema.example !== undefined) return schema.example;
      return "";
  }
}
function bodyExample(op){
  const c = op.requestBody && op.requestBody.content, key = c && Object.keys(c)[0];
  if (!c) return {text:"", type:null, media:null};
  const media = c[key];
  if (media.example !== undefined) return {text: JSON.stringify(media.example, null, 2), type:"json", media:key};
  if (media.schema) return {text: JSON.stringify(sampleFor(media.schema, 0), null, 2) || "{}", type: media.schema.type === "string" && media.schema.format === "binary" ? "binary" : "json", media:key};
  return {text:"", type:null, media:key};
}
function paramDefault(p){
  if (p.example !== undefined) return p.example;
  const s = p.schema || {};
  if (s.default !== undefined) return s.default;
  switch (s.type){ case "integer": case "number": return 1; case "boolean": return "false"; default: return ""; }
}

/* ============================= state ============================= */
const state = { token: localStorage.getItem("satullia.token") || "", server: localStorage.getItem("satullia.server") || 0 };
const tagDesc = {}; (SPEC.tags || []).forEach(t => tagDesc[t.name] = t.description);
const opsByTag = new Map();
const allOps = [];
for (const [path, item] of Object.entries(SPEC.paths || {})){
  for (const [method, op] of Object.entries(item)){
    if (!METHODS[method]) continue;
    const tags = (op.tags && op.tags.length) ? op.tags : ["Other"];
    const id = "op-" + tags[0].toLowerCase().replace(/\s+/g, "-") + "-" + method + "-" + path.replace(/[^a-z0-9]+/gi, "-");
    allOps.push({path, method, op, tags, id});
    for (const t of tags){ if (!opsByTag.has(t)) opsByTag.set(t, []); opsByTag.get(t).push({path, method, op, id}); }
  }
}

/* ============================= top bar ============================= */
function setupTopBar(){
  $("#specTitle").textContent = SPEC.info.title;
  $("#specVer").textContent = "v" + SPEC.info.version;
  $("#specDesc").textContent = SPEC.info.description.split("\n").map(l => l.trim()).filter(Boolean)[0] || "";
  const sel = $("#server");
  (SPEC.servers || []).forEach((s, i) => {
    const o = document.createElement("option"); o.value = i; o.textContent = s.url + "  —  " + (s.description || "");
    sel.appendChild(o);
  });
  sel.value = Math.min(state.server, (SPEC.servers.length - 1));
  $("#token").value = state.token;
  sel.addEventListener("change", () => { state.server = sel.value; localStorage.setItem("satullia.server", sel.value); });
  $("#token").addEventListener("change", () => { state.token = $("#token").value.trim(); localStorage.setItem("satullia.token", state.token); });
  $("#loginBtn").addEventListener("click", async () => {
    const base = SPEC.servers[+sel.value].url;
    const email = $("#loginEmail").value.trim(), pass = $("#loginPass").value;
    $("#loginBtn").disabled = true; $("#loginBtn").textContent = "…";
    try {
      const r = await fetch(base + "/api/v1/auth/login", { method: "POST", headers: {"Content-Type":"application/json"}, body: JSON.stringify({email, password}) });
      const j = await r.json().catch(() => ({}));
      const t = (j.data && (j.data.access_token || j.data.token)) || j.access_token || j.token || "";
      if (!t) throw new Error("no token in response: " + (j.error && (j.error.message || j.error.code) || JSON.stringify(j).slice(0, 120)));
      state.token = t; $("#token").value = t; localStorage.setItem("satullia.token", t);
      toast("Token obtained (" + (j.data && j.data.refresh_token ? "access+refresh" : "access") + ")" + (r.ok ? "" : " — note: HTTP " + r.status));
    } catch (e) { toast("Login failed: " + e.message, 6000); }
    finally { $("#loginBtn").disabled = false; $("#loginBtn").textContent = "Get token"; }
  });
  $("#expAll").addEventListener("click", () => $$(".op").forEach(o => o.classList.add("open")));
  $("#colAll").addEventListener("click", () => $$(".op").forEach(o => o.classList.remove("open")));
}

/* ============================= sidebar ============================= */
function setupSidebar(){
  const sb = $("#sidebar");
  for (const [tag, ops] of opsByTag){
    const h = document.createElement("div"); h.className = "tag"; h.textContent = tag + " (" + ops.length + ")";
    sb.appendChild(h);
    ops.forEach(({id, path, method}) => {
      const a = document.createElement("a"); a.href = "#" + id;
      a.innerHTML = '<span class="m" style="background:' + METHODS[method] + '">' + method.toUpperCase() + '</span><span>' + esc(path) + '</span>';
      a.addEventListener("click", () => { $$("aside a").forEach(x => x.classList.remove("is-active")); a.classList.add("is-active"); });
      sb.appendChild(a);
    });
  }
}

/* ============================= operation cards ============================= */
function renderOps(){
  const content = $("#content");
  for (const [tag, ops] of opsByTag){
    const sec = document.createElement("section"); sec.className = "tagsec";
    const head = document.createElement("div"); head.className = "taghead";
    head.innerHTML = '<h2>' + esc(tag) + '</h2><span class="cnt">' + ops.length + ' op' + (ops.length > 1 ? "s" : "") + '</span>' +
      (tagDesc[tag] ? '<span class="cnt" style="font-family:inherit;font-size:12.5px;color:#5b6b7c">— ' + esc(tagDesc[tag]) + '</span>' : "");
    sec.appendChild(head);
    ops.forEach(o => sec.appendChild(renderOp(o)));
    content.appendChild(sec);
  }
}

function renderOp({path, method, op, id}){
  const card = document.createElement("div"); card.className = "op"; card.id = id;
  const bodyEx = bodyExample(op);
  const params = op.parameters || [];

  /* header */
  const head = document.createElement("div"); head.className = "op-head";
  head.innerHTML = '<span class="badge" style="background:' + METHODS[method] + '">' + method.toUpperCase() + '</span>' +
    '<span class="path">' + esc(path) + '</span>' +
    '<span class="sum">' + esc(op.summary || "") + '</span><span class="chev">▶</span>';
  head.addEventListener("click", () => card.classList.toggle("open"));
  card.appendChild(head);

  /* try-it-out body */
  const body = document.createElement("div"); body.className = "op-body";
  if (op.description) { const d = document.createElement("div"); d.className = "op-desc"; d.textContent = op.description; body.appendChild(d); }
  if ((op.security || []).some(s => s.bearerAuth)) {
    const s = document.createElement("div"); s.className = "op-desc"; s.style.color = "#8a6d1a";
    s.textContent = "Requires Authorization: Bearer <token> (set in the top bar).";
    body.appendChild(s);
  }

  /* parameters */
  const pathPar = params.filter(p => p.in === "path"), queryPar = params.filter(p => p.in === "query");
  if (pathPar.length || queryPar.length){
    const tbl = document.createElement("table"); tbl.className = "pars";
    tbl.innerHTML = "<tr><th style='width:140px'>Name</th><th style='width:70px'>Where</th><th style='width:60px'>Req</th><th style='width:120px'>Type</th><th>Value</th></tr>";
    for (const p of [...pathPar, ...queryPar]){
      const tr = document.createElement("tr");
      const def = paramDefault(p);
      tr.innerHTML =
        '<td><code>' + esc(p.name) + '</code>' + (p.description ? '<div class="par-in">' + esc(p.description) + '</div>' : "") + '</td>' +
        '<td class="par-in">' + p.in + '</td>' +
        '<td>' + (p.required ? '<span class="req-dot">*</span>' : "") + '</td>' +
        '<td class="par-type">' + esc((p.schema && p.schema.type) || (p.schema && p.schema.$ref && "ref") || "string") +
          (p.schema && p.schema.format ? " / " + esc(p.schema.format) : "") + '</td>' +
        '<td><input data-param="' + esc(p.name) + '" data-in="' + p.in + '" value="' + esc(def) + '"' +
          (p.required ? ' required' : "") + '></td>';
      tbl.appendChild(tr);
    }
    body.appendChild(tbl);
  }

  /* request body editor */
  if (bodyEx.media && bodyEx.media.includes("multipart")){
    const l = document.createElement("div"); l.className = "lbl"; l.textContent = "Request body — multipart/form-data";
    const f = document.createElement("input"); f.type = "file"; f.className = "file-input";
    body.appendChild(l); body.appendChild(f);
  } else if (bodyEx.type === "json"){
    const l = document.createElement("div"); l.className = "lbl"; l.textContent = "Request body — application/json";
    const ta = document.createElement("textarea"); ta.className = "body-json"; ta.spellcheck = false;
    ta.value = bodyEx.text;
    const edHint = document.createElement("div"); edHint.style.cssText = "font-size:11.5px;color:#8a94a1;margin-top:4px";
    edHint.textContent = "Edit freely — Execute sends it as-is.";
    body.appendChild(l); body.appendChild(ta); body.appendChild(edHint);
  }

  /* actions */
  const actions = document.createElement("div"); actions.className = "op-actions";
  const tryBtn = document.createElement("button"); tryBtn.className = "btn"; tryBtn.textContent = "Try it out";
  const execBtn = document.createElement("button"); execBtn.className = "btn exec"; execBtn.textContent = "Execute";
  execBtn.style.display = "none";
  actions.appendChild(tryBtn); actions.appendChild(execBtn);
  const hint = document.createElement("span"); hint.className = "hint"; hint.textContent = "runs live against the selected server";
  actions.appendChild(hint);
  body.appendChild(actions);

  /* result panel */
  const res = document.createElement("div"); res.className = "result";
  res.innerHTML = '<div class="r-head"></div><pre class="res-body"></pre>';
  const curlWrap = document.createElement("div"); curlWrap.className = "curl-wrap"; curlWrap.style.display = "none";
  curlWrap.innerHTML = '<pre class="curl"></pre><button class="copy-curl">Copy curl</button>';
  res.appendChild(curlWrap);
  body.appendChild(res);
  card.appendChild(body);

  tryBtn.addEventListener("click", () => {
    card.classList.add("open");
    const editing = execBtn.style.display !== "none";
    if (editing){
      execBtn.style.display = "none"; tryBtn.textContent = "Try it out";
      hint.textContent = "runs live against the selected server";
      res.classList.remove("show");
      $$(".result.show").forEach(r => r.classList.remove("show"));
    } else {
      execBtn.style.display = "inline-block"; tryBtn.textContent = "Cancel";
      hint.textContent = "edit parameters, then Execute";
      res.classList.remove("show");
      $$(".result.show").forEach(r => r.classList.remove("show"));
    }
  });
  execBtn.addEventListener("click", () => execOp(card, path, method, op, res, bodyEx, execBtn, tryBtn, hint));

  card.querySelector(".copy-curl").addEventListener("click", () => {
    navigator.clipboard.writeText(card.querySelector(".curl").textContent).then(() => toast("curl copied"));
  });

  return card;
}

async function execOp(card, path, method, op, res, bodyEx, execBtn, tryBtn, hint){
  const base = SPEC.servers[+$("#server").value].url;
  const inputs = card.querySelectorAll("input[data-param]");
  let url = base + path;
  const queries = [];
  inputs.forEach(inp => {
    const name = inp.dataset.param, where = inp.dataset.in, v = inp.value.trim();
    if (where === "path") url = url.replace("{" + name + "}", encodeURIComponent(v || ""));
    if (where === "query" && v !== "") queries.push(encodeURIComponent(name) + "=" + encodeURIComponent(v));
  });
  if (queries.length) url += "?" + queries.join("&");

  const headers = {};
  if (state.token) headers["Authorization"] = "Bearer " + state.token;
  let bodyData;
  if (bodyEx.media && bodyEx.media.includes("multipart")){
    const fd = new FormData();
    const f = card.querySelector(".file-input").files[0];
    if (f) fd.append("file", f); else { showRes(res, 400, "Select a file first", 0, "", "", url); return; }
    bodyData = fd;
  } else if (bodyEx.type === "json"){
    const ta = card.querySelector(".body-json"), raw = ta.value.trim();
    if (raw){ try { bodyData = JSON.stringify(JSON.parse(raw)); headers["Content-Type"] = "application/json"; }
      catch (e){ showRes(res, 400, "Invalid JSON: " + e.message, 0, "", "", url); return; } }
  }

  /* curl preview */
  let curl = "curl -s -X " + method.toUpperCase() + " '" + url + "'";
  if (state.token) curl += " \\\n  -H 'Authorization: Bearer <token>'";
  if (bodyData && typeof bodyData === "string") curl += " \\\n  -H 'Content-Type: application/json' \\\n  -d '" + bodyData.replace(/'/g, "'\\''") + "'";
  const curEl = card.querySelector(".curl"); curEl.textContent = curl;
  card.querySelector(".curl-wrap").style.display = "flex";

  const rHead = res.querySelector(".r-head");
  rHead.innerHTML = '<span class="r-meta">' + esco(method.toUpperCase()) + ' ' + esc(path) + '</span><span class="r-url">' + esc(url) + '</span>';
  rHead.querySelector(".r-url").style.marginLeft = "auto";
  tryBtn.textContent = "Cancel"; tryBtn.disabled = true; execBtn.disabled = true; execBtn.textContent = "Executing…";
  const t0 = performance.now();
  try {
    const r = await fetch(url, { method: method.toUpperCase(), headers, body: bodyData, redirect: "follow" });
    const ms = performance.now() - t0;
    const ct = r.headers.get("content-type") || "";
    const text = await r.text();
    const head = res.querySelector(".r-head");
    const status = r.status, ok = status < 300, warn = status < 500;
    const respDesc = op.responses && op.responses[String(status)] && op.responses[String(status)].description;
    const bodyEl = res.querySelector(".res-body");
    bodyEl.innerHTML = "";
    if (ct.includes("json")){
      try {
        const j = JSON.parse(text);
        bodyEl.appendChild(renderJson(j));
      } catch (e){ bodyEl.textContent = text || "(empty body)"; }
    } else if (ct.includes("text") || ct.includes("html")){
      bodyEl.textContent = text.length > 20000 ? text.slice(0, 20000) + "\n… (truncated, " + text.length + " bytes)" : text;
    } else {
      bodyEl.innerHTML = '<span class="err-note">Binary response (' + (ct || "unknown type") + ") — " + text.length + " bytes. Not rendered as JSON.</span>";
    }
    head.innerHTML =
      '<span class="r-status ' + (ok ? "good" : warn ? "warn" : "bad") + '">' + status + ' ' + esc(r.statusText) + '</span>' +
      '<span class="r-meta">' + fmtTime(ms) + '</span>' +
      '<span class="r-meta">' + esc(ct.split(";")[0] || "") + '</span>' +
      (respDesc ? '<span class="r-desc">' + esc(respDesc) + '</span>' : "") +
      '<span class="r-url" style="margin-left:auto;max-width:60%;overflow:hidden;text-overflow:ellipsis">' + esc(url) + '</span>';
    res.classList.add("show");
  } catch (e){
    showRes(res, 0, "Network error: " + e.message, performance.now() - t0, "", "", url);
  } finally {
    tryBtn.disabled = false; execBtn.disabled = false; execBtn.textContent = "Execute";
  }
}

function showRes(res, status, text, ms, ct, respDesc, url){
  const head = res.querySelector(".r-head");
  head.innerHTML =
    '<span class="r-status ' + (status >= 200 && status < 300 ? "good" : status > 0 && status < 500 ? "warn" : "bad") + '">' + (status || "ERR") + '</span>' +
    '<span class="r-meta">' + fmtTime(ms) + '</span>' +
    (respDesc ? '<span class="r-desc">' + esc(respDesc) + '</span>' : "") +
    '<span class="r-url">' + esc(url) + '</span>';
  const bodyEl = res.querySelector(".res-body"); bodyEl.textContent = text;
  res.classList.add("show");
}

/* pretty JSON renderer */
function renderJson(j, depth){
  const box = document.createElement("span");
  if (j === null) { box.innerHTML = '<span class="tok-k">null</span>'; return box; }
  if (Array.isArray(j)){
    if (j.length === 0){ box.innerHTML = '<span class="tok-k">[ ]</span>'; return box; }
    box.innerHTML = '[';
    j.forEach((v, i) => { box.appendChild(renderJson(v, depth + 1)); if (i < j.length - 1) box.appendChild(document.createTextNode(",")); });
    box.innerHTML += ']';
    return box;
  }
  if (typeof j === "object"){
    const keys = Object.keys(j);
    if (!keys.length){ box.innerHTML = '<span class="tok-k">{ }</span>'; return box; }
    box.innerHTML = '{';
    keys.forEach((k, i) => {
      const s = document.createElement("span");
      s.innerHTML = '<span class="tok-s">&quot;' + esc(k) + '&quot;</span>: ';
      s.appendChild(renderJson(j[k], depth + 1));
      if (i < keys.length - 1) s.appendChild(document.createTextNode(","));
      box.appendChild(s);
    });
    box.innerHTML += '}';
    return box;
  }
  if (typeof j === "string"){ box.innerHTML = '<span class="tok-s">&quot;' + esc(j) + '&quot;</span>'; return box; }
  if (typeof j === "boolean"){ box.innerHTML = '<span class="tok-b">' + j + '</span>'; return box; }
  box.innerHTML = '<span class="tok-n">' + j + '</span>';
  return box;
}
function esco(s){ return esc(s); }

/* ============================= init ============================= */
setupTopBar();
setupSidebar();
renderOps();
</script>
</body>
</html>
HTML

html = html.gsub("__SPEC_JSON__", json).gsub("__BUILT__", built)

Dir.mkdir(File.dirname(OUT)) unless Dir.exist?(File.dirname(OUT))
File.write(OUT, html)

puts "wrote #{OUT} (#{File.size(OUT).to_i / 1024} KB, #{PATH_COUNT} paths / #{OPCOUNT} operations)"