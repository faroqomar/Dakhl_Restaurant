"""Rebuild the three frozen phase-00 reference views as layered SVG artwork.

Uses measured synthetic DOM geometry and host-rendered glyph outlines. Product
photos and the native select indicator are discrete assets, never whole UI rasters.
"""
import base64
import html
import json
import re
from pathlib import Path
import xml.etree.ElementTree as ET
ET.register_namespace('', 'http://www.w3.org/2000/svg')

BASE = Path(__file__).resolve().parents[1] / 'outputs/penpot/phase00/reference-data'
OUT = BASE.parent / 'screenshot-recreation'
OUT.mkdir(exist_ok=True)
SCREENS = ['desktop-sales', 'desktop-expenses', 'desktop-settings-data']

def num(value):
    return float(re.match(r'[-+.\d]+', str(value))[0])

def fmt(value):
    return f'{value:.6f}'.rstrip('0').rstrip('.') or '0'

def esc(value):
    return html.escape(str(value), quote=True)

def color(value, wire=False):
    if not wire:
        return value.replace('WindowText', '#000000')
    def convert(match):
        numbers = [float(x) for x in match.group(1).split(',')]
        gray = round(.2126 * numbers[0] + .7152 * numbers[1] + .0722 * numbers[2])
        if len(numbers) == 4:
            return f'rgba({gray},{gray},{gray},{numbers[3]})'
        return f'rgb({gray},{gray},{gray})'
    value = re.sub(r'rgba?\(([^)]+)\)', convert, value)
    def hexgray(match):
        s=match.group(1);s=''.join(c*2 for c in s) if len(s)==3 else s
        if len(s)!=6:return match[0]
        a=[int(s[i:i+2],16) for i in [0,2,4]]
        g=round(.2126*a[0]+.7152*a[1]+.0722*a[2]);return '#'+f'{g:02x}'*3
    return re.sub(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-fA-F])',hexgray,value).replace('WindowText','#000000')

def rgba(value):
    m=re.match(r'rgba?\(([^)]+)\)',value)
    if not m:return value,1
    a=m.group(1).split(',');return 'rgb('+','.join(a[:3])+')',float(a[3]) if len(a)>3 else 1

def rectpath(b, radii, inset=0):
    x,y,w,h=[b[k] for k in ['x','y','width','height']]
    x+=inset;y+=inset;w-=2*inset;h-=2*inset
    if min(w,h)<=0:return ''
    tl,tr,br,bl=[max(0,min(r-inset,w/2,h/2)) for r in radii]
    arc=lambda r,xx,yy: f'A{r} {r} 0 0 1 {xx} {yy}' if r else f'L{xx} {yy}'
    return f'M{x+tl} {y}H{x+w-tr}'+arc(tr,x+w,y+tr)+f'V{y+h-br}'+arc(br,x+w-br,y+h)+f'H{x+bl}'+arc(bl,x,y+h-bl)+f'V{y+tl}'+arc(tl,x+tl,y)+'Z'

def svg_inside(source,b,wire=False):
    s=ET.fromstring(source)
    vb=[float(v) for v in s.get('viewBox','0 0 24 24').replace(',',' ').split()]
    sx=b['width']/vb[2];sy=b['height']/vb[3]
    if s.get('preserveAspectRatio','xMidYMid meet')!='none':sx=sy=min(sx,sy)
    tx=b['x']+(b['width']-vb[2]*sx)/2;ty=b['y']+(b['height']-vb[3]*sy)/2
    # Penpot drops x/y on nested <svg>; explicit group transforms survive import.
    s.tag='g'
    for k in ['x','y','width','height','viewBox','overflow']:s.attrib.pop(k,None)
    s.set('transform',f'translate({tx} {ty}) scale({sx} {sy}) translate({-vb[0]} {-vb[1]})')
    return color(ET.tostring(s,encoding='unicode'),wire)

def outlines_map(screen):
    j=json.loads((BASE/(screen+'-text-outlines.json')).read_text())
    runs=j['runs'] if isinstance(j,dict) else j
    return {r['id']:r for r in runs}

def build(screen,wire=False):
    j=json.loads((BASE/(screen+'.json')).read_text())
    glyphs=outlines_map(screen)
    photos=json.loads((BASE/'photos-png.json').read_text()) if screen=='desktop-sales' else {}
    controlData=next(s for s in json.loads((BASE/'control-runs.json').read_text()) if s['id']==screen)
    controls=controlData['runs']
    defs=['<clipPath id="viewport"><rect width="1440" height="1000"/></clipPath>']
    shapes=[];stats={'elements':0,'textRuns':0,'images':0,'icons':0,'wholeUiRasters':0}
    def clip(node):
        c=node.get('clip',{'x':0,'y':0,'width':1440,'height':1000})
        key='clip-'+node['id']
        defs.append(f'<clipPath id="{key}"><rect x="{fmt(c["x"])}" y="{fmt(c["y"])}" width="{fmt(c["width"])}" height="{fmt(c["height"])}"/></clipPath>')
        return key
    def draw(node):
        b=node['bounds'];s=node['style'];kind=node.get('kind','element');parts=[]
        if b['width']<=0 or b['height']<=0:return
        key=clip(node)
        if kind=='text':
            g=glyphs.get(node['id'])
            if not g:raise ValueError('Missing glyph outline: '+node['id'])
            body=g.get('svg') or ''.join(line['svg'] for line in g['lines'])
            parts.append(f'<g fill="{color(s["color"],wire)}">{body}</g>');stats['textRuns']+=1
        elif kind=='svg':
            parts.append(svg_inside(node['svg'],b,wire));stats['icons']+=1
        else:
            radii=[num(s.get('border'+k+'Radius','0')) for k in ['TopLeft','TopRight','BottomRight','BottomLeft']]
            d=rectpath(b,radii)
            if s.get('boxShadow','none')!='none' and not wire:
                # Preserve shadows as vector/filter artwork, not a screen image.
                match=re.match(r'(rgba?\([^)]+\)) ([-.\d]+)px ([-.\d]+)px ([-.\d]+)px ([-.\d]+)px',s['boxShadow'])
                if match:
                    col,dx,dy,blur,spread=match.groups();basecol,alpha=rgba(col)
                    fid='shadow-'+node['id']
                    defs.append(f'<filter id="{fid}" x="-25%" y="-25%" width="150%" height="150%"><feDropShadow dx="{dx}" dy="{dy}" stdDeviation="{float(blur)/2}" flood-color="{basecol}" flood-opacity="{alpha}"/></filter>')
                    parts.append(f'<path d="{d}" fill="{s["backgroundColor"]}" filter="url(#{fid})"/>')
            fill=s.get('backgroundColor','rgba(0,0,0,0)')
            if rgba(fill)[1]>0:parts.append(f'<path d="{d}" fill="{color(fill,wire)}"/>')
            sides=['Top','Right','Bottom','Left'];widths=[num(s.get('border'+a+'Width','0')) for a in sides]
            colors=[s.get('border'+a+'Color','#000') for a in sides]
            if widths[0]>0 and len(set(widths))==1 and len(set(colors))==1:
                parts.append(f'<path d="{rectpath(b,radii,widths[0]/2)}" fill="none" stroke="{color(colors[0],wire)}" stroke-width="{widths[0]}"/>')
            else:
                x,y,w,h=[b[k] for k in ['x','y','width','height']]
                boxes=[(x,y,w,widths[0]),(x+w-widths[1],y,widths[1],h),(x,y+h-widths[2],w,widths[2]),(x,y,widths[3],h)]
                for z,edge in enumerate(boxes):
                    if widths[z]>0:
                        xx,yy,ww,hh=edge;parts.append(f'<rect x="{xx}" y="{yy}" width="{ww}" height="{hh}" fill="{color(colors[z],wire)}"/>')
            if kind=='image':
                imageClip='photo-'+node['id'];defs.append(f'<clipPath id="{imageClip}"><path d="{d}"/></clipPath>')
                if wire:
                    x,y,w,h=[b[k] for k in ['x','y','width','height']]
                    parts.append(f'<g clip-path="url(#{imageClip})"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#E7E7E7"/><path d="M{x} {y}l{w} {h}M{x+w} {y}l{-w} {h}" stroke="#B9B9B9" stroke-width="1"/></g>')
                else:
                    x,y,w,h=[b[k] for k in ['x','y','width','height']]
                    aspect='xMidYMid slice' if s['objectFit']=='cover' else 'xMidYMid meet'
                    parts.append(f'<image x="{x}" y="{y}" width="{w}" height="{h}" href="{photos.get(node["id"],node["dataUrl"])}" xlink:href="{photos.get(node["id"],node["dataUrl"])}" preserveAspectRatio="{aspect}" clip-path="url(#{imageClip})"/>');stats['images']+=1
        if parts:
            label=node.get('name') or node.get('characters') or node['id']
            shapes.append(f'<g id="{esc(node["id"]+" "+label)}" opacity="{node.get("opacity",1)}" clip-path="url(#{key})">'+''.join(parts)+'</g>');stats['elements']+=1
    for node in j['nodes']:draw(node)
    # Native controls contain user-agent shadow text rather than DOM text nodes.
    for c in controls:
        if c['kind']=='text':draw({**c,'clip':{'x':0,'y':0,'width':1440,'height':1000}})
        elif c.get('svg'):
            shapes.append(svg_inside(c['svg'],c.get('backgroundPaintBounds',c['bounds']),wire));stats['icons']+=1
        elif c.get('assetPath'):
            p=Path(c['assetPath']);data=base64.b64encode(p.read_bytes()).decode();b=c['bounds'];shapes.append(f'<image id="Native select indicator" x="{b["x"]}" y="{b["y"]}" width="{b["width"]}" height="{b["height"]}" href="data:image/png;base64,{data}" xlink:href="data:image/png;base64,{data}"/>');stats['icons']+=1
    if screen=='desktop-sales':
        status=next(n['bounds'] for n in j['nodes'] if n.get('name')=='span.pos-status')
        cx=status['x']+status['width']-3.5;cy=status['y']+status['height']/2
        shapes.append(f'<circle id="Ready status indicator" cx="{cx}" cy="{cy}" r="3.5" fill="{color("#159C68",wire)}"/>')
    for marker in controlData.get('markers',[]):
        p=Path(marker['assetPath'])
        if wire:p=p.with_name(p.stem+'-gray.png')
        data=base64.b64encode(p.read_bytes()).decode();b=marker['assetBounds']
        shapes.append(f'<image id="Native disclosure marker" x="{b["x"]}" y="{b["y"]}" width="{b["width"]}" height="{b["height"]}" href="data:image/png;base64,{data}" xlink:href="data:image/png;base64,{data}"/>');stats['icons']+=1
    if screen=='desktop-settings-data':
        shapes.append('<rect id="Native vertical scrollbar" x="1431" y="2" width="7" height="933.5" rx="3.5" fill="#7B7B79"/>')
    source=f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1440" height="1000" viewBox="0 0 1440 1000"><defs>{"".join(defs)}</defs><g clip-path="url(#viewport)">{"".join(shapes)}</g></svg>'
    name=screen+('-wireframe' if wire else '-design')
    (OUT/(name+'.svg')).write_text(source)
    return {'screen':screen,'kind':'wireframe' if wire else 'design','file':name+'.svg',**stats}

if __name__=='__main__':
    results=[build(s,w) for s in SCREENS for w in [False,True]]
    (OUT/'artwork-manifest.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2))
