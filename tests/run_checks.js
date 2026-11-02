// 原型行为检查（KD-008）：node tests/run_checks.js [截图目录]
// Chromium + iPhone 尺寸。App 环境用模拟的原生接口；这里测不到 iPhone Safari 和真机效果。
const path=require('path'),fs=require('fs'),{chromium}=require('playwright');
const URL_='file://'+path.join(__dirname,'../iOS/App/Web/index.html'),SHOTS=process.argv[2]||'';
const results=[];const ck=(id,ok,info='')=>{results.push({id,ok,info});console.log(`${ok?'通过':'不通过'} | ${id}${info?' | '+info:''}`)};
const RES={zh:/习惯|打卡|日志|笔记|会员|订阅|读书|运动|单词|VIP|续费|每日提醒|通知角标|注销|配色板|卡片/,
 hant:/習慣|打卡|日誌|筆記|會員|訂閱|讀書|運動|單詞|VIP|續費|每日提醒|註銷|配色板|卡片/,
 en:/habit|check-?in|journal|premium|member|subscri|VIP|renew|daily reminder|palette|\bcard/i};
async function open(b,o={}){const c=await b.newContext({viewport:o.small?{width:375,height:667}:{width:390,height:844},deviceScaleFactor:2,hasTouch:!!o.touch,timezoneId:'Asia/Shanghai',colorScheme:o.dark?'dark':'light',locale:'zh-CN'});
const p=await c.newPage();p.errs=[];p.native=[];p.on('pageerror',e=>p.errs.push(e.message));
await p.exposeFunction('__rec',m=>{p.native.push(m)});
if(o.app)await p.addInitScript(()=>{window.__XM_NATIVE__=true;window.__XM_SPLASH_DONE=true;window.webkit={messageHandlers:{native:{postMessage:m=>{window.__rec(JSON.parse(JSON.stringify(m)));if(m.cmd==='live')return Promise.resolve(window.__liveRes);return Promise.resolve(null)}}}}});
if(o.lang)await p.addInitScript(l=>{try{localStorage.setItem('xm-lang',l)}catch(e){}},o.lang);
await p.goto(URL_);await p.waitForFunction(()=>typeof S!=='undefined'&&S&&document.querySelector('#view'));
if(!o.guide)await p.evaluate(()=>{S.prefs.guided=true;S.prefs.agreed=POLICY_VER;save();document.querySelectorAll('.gd,.pc').forEach(x=>x.remove())});
await p.waitForTimeout(150);return p}
const shot=async(p,n)=>{if(SHOTS){fs.mkdirSync(SHOTS,{recursive:true});await p.screenshot({path:path.join(SHOTS,n+'.png')})}};
const paste=(p,v)=>p.evaluate(v=>{const el=document.querySelector('#ieLink');el.value=v;el.dispatchEvent(new Event('paste'))},v).then(()=>p.waitForTimeout(60));
const ie=p=>p.evaluate(()=>{const s=document.querySelector('.sheet.ie');return {link:s.querySelector('#ieLink').value,name:s.querySelector('#ieName').value,date:s.querySelector('#ieDate').value,time:s.querySelector('#ieTime').value,plat:s.querySelector('#ieSrc').value,note:(s.querySelector('.kd-enote')||{}).textContent||''}});
const seed=(p,list)=>p.evaluate(list=>{const n=Date.now();S.items=list.map((x,i)=>({id:'t'+i,name:x.name,src:x.src||'ntp',at:n+x.in,link:x.link||'',remind:x.remind??5,live:x.live??true,auto:!!x.auto,createdAt:TODAY()}));save();renderToday()},list);
(async()=>{const b=await chromium.launch();let p;
/* ---- Q02 换链接 ---- */
p=await open(b);await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');
await paste(p,'【大麦】甲演唱会 11月20日10:00开抢 https://m.damai.cn/a');let r=await ie(p);const g1=r.name==='甲演唱会'&&r.time==='10:00:00'&&r.plat==='damai';
await paste(p,'【猫眼】乙演唱会 https://m.maoyan.com/b');r=await ie(p);const g2=r.name==='乙演唱会'&&r.time===''&&r.date===''&&r.plat==='maoyan';
await paste(p,'https://www.jd.com/c');await p.waitForTimeout(60);r=await ie(p);const g3=r.name===''&&r.time===''&&r.plat==='jd';
ck('Q02 换链接清掉自动带出的名称和时间',g1&&g2&&g3,JSON.stringify(r));await shot(p,'Q02_换链接后');
await paste(p,'https://example.com/x');r=await ie(p);ck('Q02 认不出的网址：平台回到默认',r.plat==='ntp',r.plat);
await p.fill('#ieName','我自己写的');await p.evaluate(()=>{const s=document.querySelector('#ieDate');s.value='2030-01-02';s.dispatchEvent(new Event('change'));});await p.waitForTimeout(30);await p.evaluate(()=>{const s=document.querySelector('#ieTime');s.value='12:00:00';s.dispatchEvent(new Event('change'));});await p.waitForTimeout(30);
await paste(p,'【大麦】丙 11月21日10:00开抢 https://m.damai.cn/c');r=await ie(p);ck('Q02 手动填过的不动，并提示确认',r.name==='我自己写的'&&r.date==='2030-01-02'&&r.time==='12:00:00'&&/之前填的/.test(r.note),JSON.stringify(r));await p.context().close();
/* ---- Q14 保存第一下有效 ---- */
p=await open(b,{touch:false});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await p.fill('#ieName','手动场');
await p.evaluate(()=>{const s=document.querySelector('#ieDate');s.value='2030-01-02';s.dispatchEvent(new Event('change'))});await p.waitForTimeout(30);await p.evaluate(()=>{const s=document.querySelector('#ieTime');s.value='12:00:00';s.dispatchEvent(new Event('change'))});await p.waitForTimeout(30);
await p.click('#ieLink');await p.keyboard.type('https://m.damai.cn/z');await p.click('#ieOk');await p.waitForTimeout(450);
let st=await p.evaluate(()=>({n:S.items.length,open:!!document.querySelector('.sheet.ie.show'),link:S.items[0]&&S.items[0].link,name:S.items[0]&&S.items[0].name}));ck('Q14 输完链接直接点保存，第一下就保存，且只存一场',st.n===1&&!st.open&&st.link==='https://m.damai.cn/z'&&st.name==='手动场',JSON.stringify(st));await p.context().close();
/* ---- Q17 不是链接 ---- */
p=await open(b);await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await p.click('#ieLink');await p.keyboard.type('我随便写的不是链接');await p.click('#ieName');await p.waitForTimeout(60);r=await ie(p);
ck('Q17 不是链接：不写进名称和链接，有提示',r.link===''&&r.name===''&&/不是链接/.test(r.note),JSON.stringify(r));
await p.evaluate(()=>{const s=document.querySelector('#ieLink');s.value='m.jd.com/abc';s.dispatchEvent(new Event('change'))});await p.waitForTimeout(60);r=await ie(p);ck('Q17 不带 http 的网址自动补全',r.link==='https://m.jd.com/abc'&&r.plat==='jd',r.link);await p.context().close();
/* ---- Q09 自动打开 ---- */
p=await open(b);await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await p.click('#ieMore');await p.click('#ieAuto');await p.waitForTimeout(40);
st=await p.evaluate(()=>({on:document.querySelector('#ieAuto').classList.contains('on'),txt:document.querySelector('.sheet.ie').innerText,toast:document.body.innerText.includes('先填抢购链接')}));ck('Q09 没链接打不开，写明到点不会打开',!st.on&&/到点不会打开/.test(st.txt)&&st.toast);await shot(p,'Q09_没链接不能自动打开');
await paste(p,'https://m.damai.cn/a');await p.click('#ieAuto');await p.waitForTimeout(40);st=await p.evaluate(()=>document.querySelector('#ieAuto').classList.contains('on'));
await p.evaluate(()=>{const s=document.querySelector('#ieLink');s.value='';s.dispatchEvent(new Event('change'))});await p.waitForTimeout(40);
const st2=await p.evaluate(()=>document.querySelector('#ieAuto').classList.contains('on'));ck('Q09 有链接能开；清空链接后自动关掉',st&&!st2);await p.context().close();
/* ---- Q03 下一场 ---- */
p=await open(b);await seed(p,[{name:'已开抢十分钟',in:-600e3},{name:'一小时后',in:3600e3},{name:'两小时后',in:7200e3}]);await p.waitForTimeout(150);
st=await p.evaluate(()=>({card:document.querySelector('.kd-next .kd-nn').textContent,live:nextLive().name,list:[...document.querySelectorAll('.kd-list .kd-it b')].map(x=>x.textContent)}));
ck('Q03 超过 60 秒不占下一场，卡片和悬浮窗同一场',st.card==='一小时后'&&st.live==='一小时后'&&st.list.join()==='两小时后,已开抢十分钟',JSON.stringify(st));await shot(p,'Q03_下一场');
await seed(p,[{name:'刚开抢',in:-58500},{name:'后一场',in:3600e3}]);await p.waitForTimeout(100);const before=await p.evaluate(()=>({c:document.querySelector('.kd-next .kd-nn').textContent,t:document.querySelector('.kd-ncd').textContent}));await p.waitForTimeout(2200);const after=await p.evaluate(()=>document.querySelector('.kd-next .kd-nn').textContent);
ck('Q03 60 秒内仍显示正计时，过 60 秒自动换到下一场',before.c==='刚开抢'&&/已开抢 \+/.test(before.t)&&after==='后一场',before.t+' → '+after);
await seed(p,[{name:'旧的',in:-600e3}]);await p.waitForTimeout(100);st=await p.evaluate(()=>({next:!!document.querySelector('.kd-next'),list:document.querySelectorAll('.kd-list .kd-it').length}));ck('Q03 只有已开抢的：没有下一场卡片，留在列表',!st.next&&st.list===1,JSON.stringify(st));await p.context().close();
/* ---- Q04 同意弹窗 ---- */
p=await open(b,{app:true,guide:true});await p.waitForSelector('.pc',{timeout:6000});let t=await p.evaluate(()=>document.querySelector('.pc').innerText);ck('Q04 同意弹窗是卡点的内容',!RES.zh.test(t)&&/抢购日程/.test(t),t.replace(/\n/g,' ').slice(0,90));await shot(p,'Q04_同意弹窗');await p.context().close();
/* ---- Q05 Q08 Q10 Q15 设置 ---- */
for(const app of [false,true]){p=await open(b,{app});await p.evaluate(()=>{goPage('me')});await p.waitForTimeout(100);await p.evaluate(()=>openSettingsSheet());await p.waitForTimeout(350);t=await p.evaluate(()=>document.querySelector('.st-sheet').innerText);
ck(`Q05 设置没有每日提醒、提醒时间、周起始、通知角标（${app?'App':'预览'}）`,!/每日提醒|提醒时间|每周从哪天|通知角标/.test(t));ck(`Q15 设置没有注销账户、清缓存（${app?'App':'预览'}）`,!/注销|缓存/.test(t));if(!app)await shot(p,'Q05_设置页');
await p.context().close()}
p=await open(b);await seed(p,[{name:'要清掉的',in:3600e3}]);await p.evaluate(()=>{S.drills=[{t:1,ms:200,early:0}];save();openSettingsSheet()});await p.waitForTimeout(300);await p.click('#stReset');await p.waitForTimeout(250);await shot(p,'Q08_清空确认');t=await p.evaluate(()=>document.body.innerText);const q8a=/所有抢购日程/.test(t);
await p.getByRole('button',{name:'清空',exact:true}).last().click();await p.waitForTimeout(250);await p.getByRole('button',{name:'确认清空'}).click();await p.waitForTimeout(350);st=await p.evaluate(()=>({i:S.items.length,d:S.drills.length}));ck('Q08 文案说清楚，真的清空抢购和演练',q8a&&st.i===0&&st.d===0,JSON.stringify(st));await p.context().close();
p=await open(b);await p.evaluate(()=>openSettingsSheet());await p.waitForTimeout(300);await p.click('[data-go="lock"]');await p.waitForTimeout(350);t=await p.evaluate(()=>document.querySelector('.st-sheet').innerText);ck('Q10 密码锁写明可能耽误抢购',/可能耽误抢购/.test(t));await shot(p,'Q10_密码锁');await p.context().close();
p=await open(b);await p.evaluate(()=>goPage('me'));await p.waitForTimeout(100);t=await p.evaluate(()=>document.querySelector('#view').innerText);ck('Q15 预览的我的页没有假的检查更新',!/检查更新/.test(t)&&/网页预览/.test(t));await p.context().close();
/* ---- Q07 个性化 ---- */
p=await open(b);await p.evaluate(()=>goPage('me'));await p.waitForTimeout(80);await p.evaluate(()=>openPageSheet('personal'));await p.waitForTimeout(350);t=await p.evaluate(()=>document.body.innerText);ck('Q07 个性化没有配色板入口、完成音效',!/配色板|完成音效/.test(t)&&/主题/.test(t));await shot(p,'Q07_个性化');await p.context().close();
/* ---- Q11 灵动岛 ---- */
p=await open(b);await seed(p,[{name:'甲',in:3600e3,live:false}]);await p.evaluate(()=>{LIVE_OFF=true;renderDay()});await p.waitForTimeout(80);await p.click('[data-live]');await p.waitForTimeout(100);st=await p.evaluate(()=>({live:S.items[0].live,txt:document.body.innerText}));
ck('Q11 权限被关：提示去系统设置，不提示已开启，开关不变',st.live===false&&/系统设置打开/.test(st.txt)&&!/已开启灵动岛/.test(st.txt));await shot(p,'Q11_权限被关');
await p.evaluate(()=>{LIVE_OFF=false;renderDay()});await p.waitForTimeout(40);await p.click('[data-live]');await p.waitForTimeout(60);st=await p.evaluate(()=>({live:S.items[0].live,txt:document.body.innerText}));ck('Q11 权限正常时开关照常',st.live===true&&/已开启灵动岛/.test(st.txt));await p.context().close();
/* ---- Q16 演练悬浮时钟 ---- */
p=await open(b);await p.evaluate(()=>openDrill());await p.waitForTimeout(400);st=await p.evaluate(()=>{const f=document.querySelector('.kd-dr .kd-fx .kd-fs'),c=getComputedStyle(f);return {w:c.writingMode,h:f.getBoundingClientRect().height,wd:f.getBoundingClientRect().width}});ck('Q16 悬浮时钟四个字横排',st.w==='horizontal-tb'&&st.wd>st.h,JSON.stringify(st));await shot(p,'Q16_演练');await p.evaluate(()=>document.querySelector('#drX').click());await p.context().close();
/* ---- Q18 Q19 ---- */
p=await open(b,{lang:'en'});await seed(p,[{name:'A',src:'damai',in:3600e3},{name:'B',src:'jd',in:7200e3},{name:'C',src:'taobao',in:9000e3,remind:30}]);await p.waitForTimeout(150);st=await p.evaluate(()=>[...document.querySelectorAll('.kd-ib')].map(x=>x.textContent));ck('Q18 英文角标不是中文',st.every(x=>!/[㐀-鿿]/.test(x)),st.join());await shot(p,'Q18_英文列表');await p.context().close();
p=await open(b,{small:true});await seed(p,[{name:'甲',in:3600e3},{name:'乙',src:'taobao',in:7200e3,remind:30}]);await p.waitForTimeout(150);st=await p.evaluate(()=>{const s=document.querySelector('.kd-im small');return {sw:s.scrollWidth,cw:s.clientWidth,txt:s.textContent}});ck('Q19 副标题不截断',st.sw<=st.cw&&/提前 30 分钟提醒/.test(st.txt),JSON.stringify(st));await shot(p,'Q19_列表小屏');await p.context().close();
/* ---- Q20 Q21 ---- */
p=await open(b);st=await p.evaluate(()=>{S.drills=[250,250,250].map(ms=>({t:1,ms,early:0}));const a=leadAdvice().v;S.drills=[150,150,150].map(ms=>({t:1,ms,early:0}));const c=leadAdvice().v;S.drills=[240,240,240].map(ms=>({t:1,ms,early:0}));const d=leadAdvice().v;return {a,c,d}});ck('Q20 四舍五入：0.25→0.3，0.15→0.2，0.24→0.2',st.a===300&&st.c===200&&st.d===200,JSON.stringify(st));
await p.evaluate(()=>{S.prefs.lead=300;save();PV.mode='offline';Object.keys(SYNC).forEach(k=>delete SYNC[k]);renderDay()});await p.waitForTimeout(700);t=await p.evaluate(()=>document.querySelector('#kdLead').innerText);ck('Q21 对时失败不显示提前 0.3 秒',!/提前 0\.3/.test(t)&&/对时后生效/.test(t),t.replace(/\n/g,' '));await shot(p,'Q21_对时失败');
await p.evaluate(()=>{PV.mode='ok';syncTime(curSrc(),true)});await p.waitForTimeout(700);t=await p.evaluate(()=>document.querySelector('#kdLead').innerText);ck('Q21 对上时间后恢复显示提前 0.3 秒',/提前 0\.3/.test(t),t.replace(/\n/g,' '));await p.context().close();
/* ---- 未退步：时间线、补偿、对时失败、备份、演练 ---- */
p=await open(b);await p.evaluate(()=>{S.prefs.lead=300;S.prefs.src='damai';save();renderDay()});await p.waitForTimeout(700);st=await p.evaluate(()=>({d:displayNow('damai')-platformNow('damai'),o:platformNow('damai')-Date.now()-offOf('damai')}));ck('未退步：显示时间=平台时间+补偿',st.d===300&&Math.abs(st.o)<=2,JSON.stringify(st));
await p.evaluate(()=>{const n=Date.now();S.items=[{id:'a',name:'甲',src:'damai',at:n+20e3,link:'https://m.damai.cn/a',remind:5,live:true,auto:true,autoLead:30,createdAt:TODAY()}];window.__op=[];window.open=u=>{window.__op.push(u);return {}};save();renderDay()});await p.waitForTimeout(300);st=await p.evaluate(()=>({op:window.__op.length,tip:!document.querySelector('#kdTip').hidden}));ck('未退步：到自动打开时间会打开，对时成功才显示看这个时间就行',st.op===1&&st.tip,JSON.stringify(st));
await p.evaluate(()=>{PV.mode='offline';Object.keys(SYNC).forEach(k=>delete SYNC[k]);syncTime(curSrc(),true)});await p.waitForTimeout(700);st=await p.evaluate(()=>document.querySelector('#kdTip').hidden);ck('未退步：对时失败不显示看这个时间就行',st);await p.context().close();
p=await open(b);await seed(p,[{name:'备份场',in:3600e3}]);st=await p.evaluate(async()=>{const d=backupData();return {slug:Object.keys(d).length>0,items:(d.items||[]).length}});ck('未退步：备份带上抢购',st.items===1,JSON.stringify(st));await p.context().close();
/* ---- 模板残留：把用户够得着的页面走一遍 ---- */
const PAGES={'首页':()=>{},'我的':()=>goPage('me'),'设置':()=>openSettingsSheet(),'账号':()=>openAccount(),'使用指南':()=>openGuide(),'关于':()=>openAbout(),'反馈':()=>openFeedback(),'备份':()=>openPageSheet('backup'),'导入':()=>openImport(),'个性化':()=>openPageSheet('personal'),'主题':()=>{pTab='theme';openPageSheet('personal')},'字体':()=>{pTab='font';openPageSheet('personal')},'添加抢购':()=>openItemEditor(null),'时间源':()=>openSrcSheet(),'悬浮窗设置':()=>openPipSheet(),'反应补偿':()=>openLead(),'演练':()=>openDrill(),'预览开关':()=>openPreviewPanel()};
for(const [lang,key] of [['zh-Hans','zh'],['zh-Hant','hant'],['en','en']])for(const [n,fn] of Object.entries(PAGES)){const pg=await open(b,{lang});try{await pg.evaluate(`(${fn.toString()})()`);await pg.waitForTimeout(450);const tx=await pg.evaluate(()=>document.body.innerText);const hit=tx.match(RES[key]);if(hit||pg.errs.length)ck(`残留 ${lang} ${n}`,false,(hit?hit[0]+' … '+tx.slice(Math.max(0,hit.index-20),hit.index+30).replace(/\n/g,' '):'')+pg.errs.join(';'))}catch(e){ck(`残留 ${lang} ${n}`,false,e.message.slice(0,120))}await pg.context().close()}
ck('模板残留：18 个页面、3 种语言走完',true);
/* ---- 引导 ---- */
p=await open(b,{guide:true});await p.waitForTimeout(1500);t=await p.evaluate(()=>document.body.innerText);ck('新手引导没有模板字样',!RES.zh.test(t),t.replace(/\n/g,' ').slice(0,70));await shot(p,'新手引导');await p.context().close();
const bad=results.filter(x=>!x.ok);console.log(`\n共 ${results.length} 项，不通过 ${bad.length} 项`);await b.close();process.exit(bad.length?1:0)})().catch(e=>{console.error(e);process.exit(2)});
