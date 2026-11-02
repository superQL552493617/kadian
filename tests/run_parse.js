// 开抢时间识别回归：node tests/run_parse.js
// 假定现在是北京时间 2026-11-01 00:00（和验收报告 2.1 一致），逐条调用页面里的 parseSaleTime。
const path=require('path'),fs=require('fs'),{chromium}=require('playwright');
(async()=>{const cases=JSON.parse(fs.readFileSync(path.join(__dirname,'parse_cases.json'),'utf8'));
const b=await chromium.launch(),p=await b.newPage(),errs=[];p.on('pageerror',e=>errs.push(e.message));
await p.goto('file://'+path.join(__dirname,'../iOS/App/Web/index.html'));
await p.waitForFunction(()=>typeof parseSaleTime==='function');
const now=Date.UTC(2026,9,31,16,0,0);
const got=await p.evaluate(([cs,now])=>cs.map(c=>{const a=parseSaleTime(c.text,now);if(a==null)return null;const d=new Date(a+8*36e5),z=n=>String(n).padStart(2,'0');return `${z(d.getUTCMonth()+1)}-${z(d.getUTCDate())} ${z(d.getUTCHours())}:${z(d.getUTCMinutes())}`}),[cases,now]);
let bad=0;cases.forEach((c,i)=>{const ok=got[i]===c.want;if(!ok)bad++;console.log(`${ok?'通过':'不通过'} | ${c.text} | 应得 ${c.want||'读不出'} | 实得 ${got[i]||'读不出'} | ${c.from}`)});
console.log(`\n共 ${cases.length} 条，不通过 ${bad} 条；JS 报错 ${errs.length} 个`,errs);await b.close();process.exit(bad||errs.length?1:0)})();
