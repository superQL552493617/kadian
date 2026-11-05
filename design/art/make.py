import sys
def scene(dark, text, en=False):
    P = dict(
      sky1='#FFF6DC' if not dark else '#1F2330', sky2='#FCE6AE' if not dark else '#2B2A2E',
      sun='#F5BE3E' if not dark else '#E3C77E', sunIn='#F9D36B' if not dark else '#EBD49A',
      ink='#3B3530' if not dark else '#EDE6D8', ink2='#6B5F52' if not dark else '#B9AF9F',
      hillB='#A9CF9B' if not dark else '#3F5A49', hillF='#79AE72' if not dark else '#2F4838', hillN='#5E9459' if not dark else '#263C2E',
      petal='#FFFFFF' if not dark else '#D9D4C8', core='#F2A33A' if not dark else '#C9933E', hand='#5A4632' if not dark else '#5A4A33',
      card='#000' )
    stars = '' if not dark else ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#F3E7C4" opacity="{o}"/>' for x,y,r,o in [(58,190,1.6,.9),(92,226,1.1,.7),(262,182,1.4,.85),(286,236,1.0,.6),(232,212,.9,.6),(40,250,1.0,.55),(150,176,1.2,.7)])
    birds = '' if dark else f'<g fill="none" stroke="{P["ink2"]}" stroke-width="2" stroke-linecap="round"><path d="M64 214q7-7 14 0q7-7 14 0"/><path d="M96 236q5-5 10 0q5-5 10 0"/></g>'
    spark = lambda x,y,s,c: f'<path d="M{x} {y-s}Q{x+s*.18} {y-s*.18} {x+s} {y}Q{x+s*.18} {y+s*.18} {x} {y+s}Q{x-s*.18} {y+s*.18} {x-s} {y}Q{x-s*.18} {y-s*.18} {x} {y-s}Z" fill="{c}"/>'
    sp = spark(268,206,9,P['sun'])+spark(286,234,5,P['sun'])+spark(246,186,4,P['sun'])
    ticks=''.join(f'<line x1="165" y1="{262}" x2="165" y2="{270 if i%3 else 274}" stroke="{P["hand"]}" stroke-opacity=".55" stroke-width="{2.6 if i%3==0 else 1.8}" stroke-linecap="round" transform="rotate({i*30} 165 340)"/>' for i in range(12))
    flower=lambda x,y,s: f'<g transform="translate({x} {y}) scale({s})">'+''.join(f'<ellipse cx="0" cy="-5.2" rx="3.3" ry="4.6" fill="{P["petal"]}" transform="rotate({a})"/>' for a in range(0,360,72))+f'<circle r="2.6" fill="{P["core"]}"/></g>'
    grass=lambda x,y: f'<path d="M{x} {y}q-2-7-6-10M{x} {y}q1-8 4-12M{x} {y}q3-5 8-7" fill="none" stroke="{P["hillN"]}" stroke-width="1.8" stroke-linecap="round"/>'
    fs = 23 if not en else 19
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 330 560" width="330" height="560">
<defs>
 <style>@font-face{{font-family:K;src:url(xm_kai.ttf)}}</style>
 <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{P['sky1']}"/><stop offset="1" stop-color="{P['sky2']}"/></linearGradient>
 <radialGradient id="sun" cx=".42" cy=".38" r=".7"><stop offset="0" stop-color="{P['sunIn']}"/><stop offset="1" stop-color="{P['sun']}"/></radialGradient>
 <clipPath id="card"><rect x="14" y="150" width="302" height="350" rx="30"/></clipPath>
 <filter id="grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="7"/><feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .09 0"/><feComposite in2="SourceGraphic" operator="in"/></filter>
 <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
</defs>
<text x="165" y="118" text-anchor="middle" font-family="K" font-size="{fs}" fill="{P['ink']}" letter-spacing="{1 if not en else 0}">{text}</text>
<g clip-path="url(#card)">
 <rect x="14" y="150" width="302" height="350" fill="url(#sky)"/>
 {stars}
 <circle cx="165" cy="340" r="104" fill="{P['sun']}" opacity="{.35 if not dark else .22}" filter="url(#glow)"/>
 <circle cx="165" cy="340" r="88" fill="url(#sun)"/>
 {ticks}
 <line x1="165" y1="340" x2="165" y2="282" stroke="{P['hand']}" stroke-width="4" stroke-linecap="round" transform="rotate(60 165 340)"/>
 <line x1="165" y1="340" x2="165" y2="300" stroke="{P['hand']}" stroke-width="5" stroke-linecap="round" transform="rotate(-60 165 340)"/>
 <circle cx="165" cy="340" r="5" fill="{P['hand']}"/>
 {birds}{sp if not dark else ''}
 <path d="M14 392C70 352 118 360 160 386C204 412 250 356 316 372V500H14Z" fill="{P['hillB']}"/>
 <path d="M14 430C66 402 114 404 168 424C222 444 266 418 316 410V500H14Z" fill="{P['hillF']}"/>
 {flower(70,446,1)}{flower(236,452,.85)}{flower(126,472,.75)}{flower(286,470,.9)}{flower(196,480,.7)}
 {grass(100,458)}{grass(262,440)}{grass(44,476)}{grass(170,494)}

</g>
</svg>'''
for name,dark,text,en in [('light',0,'准点，就是最好的运气。',0),('dark',1,'准点，就是最好的运气。',0),('light_en',0,'Right on time is the best luck.',1),('dark_en',1,'Right on time is the best luck.',1)]:
    open(f'{name}.svg','w',encoding='utf-8').write(scene(dark,text,en))
print('ok')
