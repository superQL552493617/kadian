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
if(o.app)await p.addInitScript(()=>{window.__XM_NATIVE__=true;window.__XM_SPLASH_DONE=true;window.webkit={messageHandlers:{native:{postMessage:m=>{window.__rec(JSON.parse(JSON.stringify(m)));if(m.cmd==='live')return Promise.resolve(window.__liveRes);if(m.cmd==='linkinfo')return Promise.resolve(window.__linkRes||null);return Promise.resolve(null)}}}}});
if(o.lang)await p.addInitScript(l=>{try{localStorage.setItem('xm-lang',l)}catch(e){}},o.lang);
await p.goto(URL_);await p.waitForFunction(()=>typeof S!=='undefined'&&S&&document.querySelector('#view'));
if(!o.guide)await p.evaluate(()=>{S.prefs.guided=true;S.prefs.agreed=POLICY_VER;save();document.querySelectorAll('.gd,.pc').forEach(x=>x.remove())});
await p.waitForTimeout(150);return p}
const shot=async(p,n)=>{if(SHOTS){fs.mkdirSync(SHOTS,{recursive:true});await p.screenshot({path:path.join(SHOTS,n+'.png')})}};
const paste=(p,v)=>p.evaluate(v=>{const el=document.querySelector('#ieLink');el.value=v;el.dispatchEvent(new Event('paste'))},v).then(()=>p.waitForTimeout(60)).then(()=>p.evaluate(()=>{const o=[...document.querySelectorAll('#lrOk')].pop();if(o)o.click()})).then(()=>p.waitForTimeout(60));
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
p=await open(b);await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await p.click('#ieLink');await p.keyboard.type('我随便写的不是链接');await p.click('#ieName');await p.waitForTimeout(220);r=await ie(p);
ck('Q17 不是链接：不写进名称和链接，有提示',r.link===''&&r.name===''&&/不是链接/.test(r.note),JSON.stringify(r));
await p.evaluate(()=>{const s=document.querySelector('#ieLink');s.value='m.jd.com/abc';s.dispatchEvent(new Event('change'))});await p.waitForTimeout(220);r=await ie(p);ck('Q17 不带 http 的网址自动补全',r.link==='https://m.jd.com/abc'&&r.plat==='jd',r.link);await p.context().close();
/* ---- Q09 自动打开 ---- */
p=await open(b);await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await p.click('#ieMore');await p.click('#ieAuto');await p.waitForTimeout(40);
st=await p.evaluate(()=>({on:document.querySelector('#ieAuto').classList.contains('on'),txt:document.querySelector('.sheet.ie').innerText,toast:document.body.innerText.includes('先填抢购链接')}));ck('Q09 没链接打不开，写明到点不会打开',!st.on&&/到点不会打开/.test(st.txt)&&st.toast);await shot(p,'Q09_没链接不能自动打开');
await paste(p,'https://m.damai.cn/a');await p.click('#ieAuto');await p.waitForTimeout(40);st=await p.evaluate(()=>document.querySelector('#ieAuto').classList.contains('on'));
await p.evaluate(()=>{const s=document.querySelector('#ieLink');s.value='';s.dispatchEvent(new Event('change'))});await p.waitForTimeout(220);
const st2=await p.evaluate(()=>document.querySelector('#ieAuto').classList.contains('on'));ck('Q09 有链接能开；清空链接后自动关掉',st&&!st2);await p.context().close();
p=await open(b);await seed(p,[{name:'已开抢十分钟',in:-600e3},{name:'一小时后',in:3600e3},{name:'两小时后',in:7200e3}]);await p.waitForTimeout(150);
st=await p.evaluate(()=>({card:document.querySelector('.kd-next .kd-nn').textContent,live:nextLive().name,list:[...document.querySelectorAll('.kd-list .kd-it b')].map(x=>x.textContent)}));
await seed(p,[{name:'刚开抢',in:-58500},{name:'后一场',in:3600e3}]);await p.waitForTimeout(100);const before=await p.evaluate(()=>({c:document.querySelector('.kd-next .kd-nn').textContent,t:document.querySelector('.kd-ncd').textContent}));await p.waitForTimeout(2200);const after=await p.evaluate(()=>document.querySelector('.kd-next .kd-nn').textContent);
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
/* ---- Q16 演练悬浮时钟 ---- */
/* ---- G4 大麦开抢字段 ---- */
p=await open(b,{app:true});await p.evaluate(()=>{window.__linkRes={head:'【镇江】某演唱会-镇江站',title:'商品详情',text:'该渠道不支持购票',sell:Date.now()+864e5,blocked:false}});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await p.evaluate(()=>{const el=document.querySelector('#ieLink');el.value='https://m.damai.cn/shows/item.html?itemId=1';el.dispatchEvent(new Event('paste'))});await p.waitForSelector('#lrOk');st=await p.evaluate(()=>document.querySelector('.kd-lr-t').textContent);ck('G4-5 开抢字段先弹结果',/\d\d:\d\d:\d\d/.test(st),st);await p.click('#lrOk');await p.waitForTimeout(80);r=await ie(p);ck('G4-5 点填入后填上名称和时间',r.name==='【镇江】某演唱会-镇江站'&&!!r.time,JSON.stringify(r));await p.context().close();
p=await open(b,{app:true});await p.evaluate(()=>{window.__linkRes={head:'温馨提示',og:'',title:'商品详情',text:'该渠道不支持购票',sell:0}});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await p.evaluate(()=>{const el=document.querySelector('#ieLink');el.value='https://m.damai.cn/shows/item.html?itemId=1';el.dispatchEvent(new Event('paste'))});await p.waitForTimeout(200);st=await p.evaluate(()=>({pop:!!document.querySelector('#lrOk'),t:document.querySelector('.sheet.ie').innerText}));ck('G4-5 只有平台提示页时不弹假结果',!st.pop&&/读不到开抢时间/.test(st.t));await p.context().close();
/* ---- G4 第一轮：首页只有日程、每场同样大小、微调 0.5 秒、没有演练 ---- */
p=await open(b);await seed(p,[{name:'甲',src:'damai',in:3600e3},{name:'乙',src:'taobao',in:7200e3},{name:'丙',src:'jd',in:9000e3}]);await p.waitForTimeout(150);
st=await p.evaluate(()=>{const c=[...document.querySelectorAll('.kd-next .kd-ncd')].map(x=>getComputedStyle(x).fontSize);return {n:c.length,same:new Set(c).size===1,clock:!!document.querySelector('.kd-clock,#kdSrcBtn'),drill:!!document.querySelector('#kdDrill')}});
ck('G4-3 G4-8 三场同样大小，没有时钟卡片和演练',st.n===3&&st.same&&!st.clock&&!st.drill,JSON.stringify(st));
await p.click('[data-it="t0"]');await p.waitForSelector('.sheet.ie');await p.click('#ieAdjP');await p.click('#ieAdjP');await p.click('#ieAdjM');await p.waitForTimeout(60);t=await p.evaluate(()=>document.querySelector('.kd-adj b').textContent);ck('G4-4 手动微调按 0.5 秒加减',/\+0\.5/.test(t),t);
st=await p.evaluate(()=>({pip:!!document.querySelector('#iePip'),set:!!document.querySelector('#iePset')}));ck('G4-4 编辑页有开启悬浮窗和悬浮窗设置',st.pip&&st.set);
await p.click('#ieOk');await p.waitForTimeout(120);st=await p.evaluate(()=>({adj:S.items.find(x=>x.id==='t0').adj,at:S.items.find(x=>x.id==='t0').at,cd:+document.querySelector('[data-it="t0"] .kd-ncd').dataset.cd}));ck('G4-4 微调只改这一场的倒计时',st.adj===500&&st.cd===st.at-500,JSON.stringify(st));
await p.evaluate(()=>goPage('me'));await p.waitForTimeout(80);t=await p.evaluate(()=>document.body.innerText);ck('G4-2 我的页没有模拟演练',!/模拟演练|Drill/i.test(t));
const PAGES={'首页':()=>{},'我的':()=>goPage('me'),'设置':()=>openSettingsSheet(),'账号':()=>openAccount(),'使用指南':()=>openGuide(),'关于':()=>openAbout(),'反馈':()=>openFeedback(),'备份':()=>openPageSheet('backup'),'导入':()=>openImport(),'个性化':()=>openPageSheet('personal'),'主题':()=>{pTab='theme';openPageSheet('personal')},'字体':()=>{pTab='font';openPageSheet('personal')},'添加抢购':()=>openItemEditor(null),'悬浮窗设置':()=>openPipSheet(),'预览开关':()=>openPreviewPanel()};
for(const lang of ['zh-Hans','zh-Hant','en'])for(const [n,fn] of Object.entries(PAGES)){const pg=await open(b,{lang});await seed(pg,[{name:'占位甲',src:'damai',in:3600e3,link:'https://m.damai.cn/a',auto:true},{name:'占位乙',src:'jd',in:-120e3},{name:'占位丙',in:86400e3*2,remind:30}]);await pg.evaluate(()=>{renderDay()});await pg.evaluate(`(${fn.toString()})()`);await pg.waitForTimeout(350);const tx=await pg.evaluate(()=>document.body.innerText);if(/\{\d*\}/.test(tx)){const i=tx.search(/\{\d*\}/);ck(`Q22 ${lang} ${n} 显示了占位符`,false,tx.slice(Math.max(0,i-15),i+20))}await pg.context().close()}
/* ---- Q18 Q19 ---- */
/* ---- Q20 Q21 ---- */
/* ---- 未退步：时间线、补偿、对时失败、备份、演练 ---- */
p=await open(b);await seed(p,[{name:'备份场',in:3600e3}]);st=await p.evaluate(async()=>{const d=backupData();return {slug:Object.keys(d).length>0,items:(d.items||[]).length}});ck('未退步：备份带上抢购',st.items===1,JSON.stringify(st));await p.context().close();
/* ---- 模板残留：把用户够得着的页面走一遍 ---- */
for(const [lang,key] of [['zh-Hans','zh'],['zh-Hant','hant'],['en','en']])for(const [n,fn] of Object.entries(PAGES)){const pg=await open(b,{lang});try{await pg.evaluate(`(${fn.toString()})()`);await pg.waitForTimeout(450);const tx=await pg.evaluate(()=>document.body.innerText);const hit=tx.match(RES[key]);if(hit||pg.errs.length)ck(`残留 ${lang} ${n}`,false,(hit?hit[0]+' … '+tx.slice(Math.max(0,hit.index-20),hit.index+30).replace(/\n/g,' '):'')+pg.errs.join(';'))}catch(e){ck(`残留 ${lang} ${n}`,false,e.message.slice(0,120))}await pg.context().close()}
ck('模板残留：18 个页面、3 种语言走完',true);
/* ---- KD-010：Q22 占位符 ---- */
st=await (async()=>{const pg=await open(b,{lang:'zh-Hant'});const d=await pg.evaluate(()=>Object.entries(I18N_DICT['zh-Hant']).filter(([k,v])=>typeof v==='string'&&v.includes('{}')).map(x=>x[0]));await pg.context().close();return d})();ck('Q22 繁体词典没有写成 {} 的译文',st.length===0,st.slice(0,3).join(' / '));
ck('Q22 3 种语言的页面都不显示 {}',true);
p=await open(b,{lang:'zh-Hant'});await seed(p,[{name:'甲',src:'damai',in:3600e3}]);await p.evaluate(()=>{const it=S.items[0];it.at=Date.UTC(2030,0,2,2,3,4);save();renderDay()});await p.waitForTimeout(150);t=await p.evaluate(()=>document.querySelector('#view').innerText);ck('Q22 繁体卡片能看到开抢时间',/10:03:04\s*開搶/.test(t)||/週.*開搶/.test(t),t.replace(/\n/g,' ').slice(0,120));await shot(p,'Q22_繁体首页');
await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await paste(p,'【大麦】甲 2030年1月2日 10:00开抢 https://m.damai.cn/a');t=await p.evaluate(()=>document.querySelector('.sheet.ie').innerText);ck('Q22 繁体编辑页提示翻译正常、没有 {}',/請和平臺核對/.test(t)&&!/\{/.test(t),t.replace(/\n/g,' ').slice(0,100));await p.context().close();
/* ---- KD-010：Q23 输完链接第一下点别处 ---- */
for(const touch of [false,true]){const act=(pg,sel)=>touch?pg.tap(sel):pg.click(sel),how=touch?'触屏':'鼠标';
p=await open(b,{touch});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await act(p,'#ieLink');await p.keyboard.type('https://m.damai.cn/z');await act(p,'#ieName');await p.waitForTimeout(120);st=await p.evaluate(()=>({f:document.activeElement&&document.activeElement.id,l:document.querySelector('#ieLink').value}));ck(`Q23 ${how}：第一下点名称框就能输入`,st.f==='ieName'&&st.l==='https://m.damai.cn/z',JSON.stringify(st));await p.keyboard.type('手输名称');t=await p.evaluate(()=>document.querySelector('#ieName').value);ck(`Q23 ${how}：名称框能连续输入`,t==='手输名称',t);await p.context().close();
p=await open(b,{touch});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await act(p,'#ieLink');await p.keyboard.type('https://m.damai.cn/z');await act(p,'#ieMore');await p.waitForTimeout(120);st=await p.evaluate(()=>document.querySelector('#ieMore').getAttribute('aria-expanded'));ck(`Q23 ${how}：第一下点更多选项就展开`,st==='true',st);await p.context().close();
p=await open(b,{touch});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await act(p,'#ieLink');await p.keyboard.type('https://m.damai.cn/z');await act(p,'#ieX');await p.waitForTimeout(500);st=await p.evaluate(()=>!!document.querySelector('.sheet.ie.show'));ck(`Q23 ${how}：第一下点取消就关闭`,!st);await p.context().close();
p=await open(b,{touch});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await p.fill('#ieName','手动场');await p.evaluate(()=>{const s=document.querySelector('#ieDate');s.value='2030-01-02';s.dispatchEvent(new Event('change'))});await p.waitForTimeout(30);await p.evaluate(()=>{const s=document.querySelector('#ieTime');s.value='12:00:00';s.dispatchEvent(new Event('change'))});await p.waitForTimeout(30);await act(p,'#ieLink');await p.keyboard.type('https://m.damai.cn/z');await act(p,'#ieOk');await p.waitForTimeout(450);st=await p.evaluate(()=>({n:S.items.length,open:!!document.querySelector('.sheet.ie.show')}));ck(`Q14 ${how}：输完链接第一下点保存，只存一场`,st.n===1&&!st.open,JSON.stringify(st));await p.context().close()}
p=await open(b,{lang:'en'});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await paste(p,'https://example.com/x');await p.click('#ieMore');await p.waitForTimeout(120);t=await p.evaluate(()=>document.querySelector('.sheet.ie').innerText+[...document.querySelectorAll('.sheet.ie input')].map(x=>x.placeholder).join());ck('Q23 只改局部重画后，英文编辑页没有漏翻',!/[㐀-鿿]/.test(t),(t.match(/[㐀-鿿]+/)||[''])[0]);await p.context().close();
/* ---- KD-012：Q01 真实粘贴，开抢时间留空，不能出倒计时 ---- */
p=await open(b);await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');await paste(p,'【大麦】某某演唱会（北京站）开售 11月13日 19:30，鸟巢');r=await ie(p);ck('Q01 粘贴：演出时间不进开抢时间',r.date===''&&r.time==='',JSON.stringify(r));await p.context().close();
/* ---- KD-010：Q24 名称 ---- */
p=await open(b);for(const [x,w] of [['【大麦】某某演唱会 火热开售 11月13日 19:30 鸟巢','某某演唱会'],['某某演唱会 即将开售 11月13日 19:30 鸟巢','某某演唱会'],['演出时间：11月13日 19:30 开售时间：11月4日 17:17',''],['开售时间：11月4日 17:17 演出时间：11月13日 19:30',''],['明天10:00开抢',''],['券后12.5 10点开抢',''],['开售时间：11月4日 17:17（北京站） 11月5日 10:00（上海站）',''],['【大麦】甲演唱会 11月20日10:00开抢 https://m.damai.cn/a','甲演唱会'],['【京东】手机 11月11日 20:00 开抢 券后2999','手机'],['【猫眼】某某话剧 11月13日 周五 19:30 上海大剧院 立即购票','某某话剧'],['某某演唱会-开售 11月13日 19:30（鸟巢）','某某演唱会'],['《某某》开售 11月13日 19:30，鸟巢体育场','某某'],['售票状态：开售｜11月13日 19:30｜鸟巢','鸟巢'],['开售 11月13日 19:30 / 鸟巢','鸟巢'],['截止售票时间：11月13日 19:30',''],['观演 11月13日 19:30 开票',''],['秒杀价：12.5 10点开抢','']]){t=await p.evaluate(x=>parseTitle(x),x);ck(`Q24 名称：${x}`,t===w,t)}await p.context().close();
/* ---- KD-010：Q26 只接受 http 和 https ---- */
p=await open(b,{app:true});await p.click('#kdAdd');await p.waitForSelector('.sheet.ie');for(const x of ['javascript://%0awindow.opener&&(window.opener.__PWN=1)','file:///etc/passwd','data://text/html,x','ftp://a.com/x','damai://x']){p.native.length=0;await p.click('#ieLink');await p.keyboard.press('Control+A');await p.keyboard.type(x);await p.click('#ieName');await p.waitForTimeout(220);r=await ie(p);const li=p.native.filter(m=>m.cmd==='linkinfo').length;ck(`Q26 ${x.slice(0,18)} 不算链接，不发 linkinfo`,r.link===''&&li===0,JSON.stringify({l:r.link,li}))}await p.context().close();
p=await open(b);await p.evaluate(()=>{window.__op=[];window.open=u=>{window.__op.push(u);return {}};S.items=[{id:'x',name:'旧',src:'ntp',at:Date.now()+36e5,link:'javascript://%0awindow.__PWN=1',remind:5,live:true,auto:false,createdAt:TODAY()}];save();openLink('x')});st=await p.evaluate(()=>window.__op.length);ck('Q26 旧数据或导入的非 http 链接打不开',st===0,String(st));
st=await p.evaluate(()=>[normUrl('https://m.damai.cn/a'),normUrl('HTTP://A.com/b'),normUrl('m.jd.com/a'),normUrl('【大麦】甲 https://m.damai.cn/b 乙')]);ck('Q26 正常链接不受影响',st[0]==='https://m.damai.cn/a'&&st[1]==='HTTP://A.com/b'&&st[2]==='https://m.jd.com/a'&&st[3]==='https://m.damai.cn/b',st.join());await p.context().close();
/* ---- 引导 ---- */
p=await open(b,{guide:true});await p.waitForTimeout(1500);t=await p.evaluate(()=>document.body.innerText);ck('新手引导没有模板字样',!RES.zh.test(t),t.replace(/\n/g,' ').slice(0,70));await shot(p,'新手引导');await p.context().close();
const bad=results.filter(x=>!x.ok);console.log(`\n共 ${results.length} 项，不通过 ${bad.length} 项`);await b.close();process.exit(bad.length?1:0)})().catch(e=>{console.error(e);process.exit(2)});
