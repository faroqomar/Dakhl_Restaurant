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

BASE = Path(__file__).resolve().parent
OUT = BASE.parent / 'source-artwork'
OUT.mkdir(exist_ok=True)
SCREENS = ['desktop-sales','desktop-navigation','desktop-invoice-new','phone-invoice-new','phone-sales','design-system','medium-sales','wide-sales']

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
    j=json.loads((BASE/(screen+'.json')).read_text());width=j['viewport']['width'];height=j['viewport']['height']
    glyphs=outlines_map(screen)
    photos=json.loads((BASE/(screen+'-photos-png.json')).read_text())
    controlData=next(s for s in json.loads((BASE/'control-runs.json').read_text()) if s['id']==screen)
    controls=controlData['runs']
    defs=[f'<clipPath id="viewport"><rect width="{width}" height="{height}"/></clipPath>']
    shapes=[];stats={'elements':0,'textRuns':0,'images':0,'icons':0,'wholeUiRasters':0}
    def clip(node):
        c=node.get('clip',{'x':0,'y':0,'width':width,'height':height})
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
            outline=s.get('outline','none')
            om=re.match(r'(rgba?\([^)]+\)|#[0-9a-fA-F]+) solid ([.0-9]+)px',outline)
            if om and float(om[2])>0:
                oc,ow=om[1],float(om[2]);offset=num(s.get('outlineOffset','0'))
                parts.append(f'<path d="{rectpath(b,radii,-offset-ow/2)}" fill="none" stroke="{color(oc,wire)}" stroke-width="{ow}"/>')
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
    # Preserve paint order: control shadow text/icons must sit beside their
    # owning control, rather than above a later modal/scrim.
    strict_controls=screen in ['desktop-invoice-new','phone-invoice-new']
    clip_audit={'screen':screen,'controls':[],'markers':[],'nativeClipPathSupportNotAssumed':True}
    by_id={n['id']:n for n in j['nodes']}
    def intersect_bounds(a,b):
        x=max(a['x'],b['x']);y=max(a['y'],b['y']);r=min(a['x']+a['width'],b['x']+b['width']);bottom=min(a['y']+a['height'],b['y']+b['height'])
        return {'x':x,'y':y,'width':max(0,r-x),'height':max(0,bottom-y)}
    def actual_owner_clip(owner):
        return intersect_bounds(owner['clip'],owner['bounds'])
    attached={};unattached=[]
    for original in controls:
        c=dict(original);b=c['bounds'];cx=b['x']+b['width']/2;cy=b['y']+b['height']/2
        attributes=c.get('control',{}).get('attributes',[])
        dom_id=c.get('owner',{}).get('domId') or (attributes[attributes.index('id')+1] if 'id' in attributes else None)
        source_id=c.get('sourceControlId')
        if not source_id:
            source_match=re.search(r'-(n[0-9]+)-select-indicator$',c.get('id',''));source_id=source_match[1] if source_match else None
        exact=[n for n in j['nodes'] if n.get('kind')=='control' and ((source_id and n['id']==source_id) or (dom_id and (n.get('name')=='#'+dom_id or n.get('name','').startswith('#'+dom_id+'.'))))]
        if strict_controls:
            proof={'runId':c['id'],'kind':c['kind'],'text':c.get('text'),'ownerDomId':dom_id,'sourceOwnerId':exact[0]['id'] if exact else None,'runBounds':b}
            if len(exact)!=1:
                proof.update({'omitted':True,'reason':'Actual owning control absent or ambiguous in paint-visible source nodes; no geometric fallback.'});clip_audit['controls'].append(proof);continue
            owner=exact[0];visible=owner.get('visibleBounds',{'width':0,'height':0});paint_clip=actual_owner_clip(owner)
            proof.update({'ownerBounds':owner['bounds'],'ownerInheritedClip':owner['clip'],'ownerVisibleBounds':visible,'appliedPaintClip':paint_clip,'sourcePaintVisible':owner.get('paintVisible',True)})
            if owner.get('paintVisible') is False or visible['width']<=0 or visible['height']<=0 or paint_clip['width']<=0 or paint_clip['height']<=0:
                proof.update({'omitted':True,'reason':'Actual owner is not paint-visible after inherited clipping.'});clip_audit['controls'].append(proof);continue
            painted_run=intersect_bounds(b,paint_clip);proof['runVisibleBounds']=painted_run
            if painted_run['width']<=0 or painted_run['height']<=0:
                proof.update({'omitted':True,'reason':'Shadow run lies completely outside actual owner paint clip.'});clip_audit['controls'].append(proof);continue
            if c['kind']=='indicator' and not c.get('svg') and not c.get('assetPath'):
                proof.update({'omitted':True,'reason':'UA indicator has no drawable source asset; existing no-paint behavior retained, no invented geometry.'});clip_audit['controls'].append(proof);continue
            c['clip']=paint_clip;proof.update({'omitted':False,'partialClip':painted_run['width']<b['width']-.01 or painted_run['height']<b['height']-.01});clip_audit['controls'].append(proof)
            attached.setdefault(owner['id'],[]).append(c);continue
        matches=exact or [n for n in j['nodes'] if n.get('kind')=='control' and n['bounds']['x']-1<=cx<=n['bounds']['x']+n['bounds']['width']+1 and n['bounds']['y']-1<=cy<=n['bounds']['y']+n['bounds']['height']+1]
        if matches:
            owner=exact[0] if exact else min(matches,key=lambda n:n['bounds']['width']*n['bounds']['height']);attached.setdefault(owner['id'],[]).append(c)
        else:unattached.append(c)
    def draw_control(c):
        if c['kind']=='text':draw({**c,'clip':c.get('clip',{'x':0,'y':0,'width':width,'height':height})})
        elif c.get('svg') or c.get('assetPath'):
            if c.get('svg'):body=svg_inside(c['svg'],c.get('backgroundPaintBounds',c['bounds']),wire)
            else:
                p=Path(c['assetPath']);p=p.with_name(p.stem+'-gray.png') if wire else p
                data=base64.b64encode(p.read_bytes()).decode();b=c['bounds'];body=f'<image id="Native select indicator" x="{b["x"]}" y="{b["y"]}" width="{b["width"]}" height="{b["height"]}" href="data:image/png;base64,{data}" xlink:href="data:image/png;base64,{data}"/>'
            if strict_controls:
                key=clip(c);body=f'<g id="{esc(c["id"]+" Native control indicator")}" clip-path="url(#{key})">{body}</g>'
            shapes.append(body);stats['icons']+=1
    for node in j['nodes']:
        draw(node)
        for c in attached.get(node['id'],[]):draw_control(c)
    for c in unattached:draw_control(c)
    if screen in ['desktop-sales','desktop-navigation','phone-sales','medium-sales','wide-sales'] and any(n.get('name')=='span.pos-status' for n in j['nodes']):
        status=next(n['bounds'] for n in j['nodes'] if n.get('name')=='span.pos-status')
        cx=status['x']+status['width']-3.5;cy=status['y']+status['height']/2
        shapes.append(f'<circle id="Ready status indicator" cx="{cx}" cy="{cy}" r="3.5" fill="{color("#159C68",wire)}"/>')
    for marker in controlData.get('markers',[]):
        marker_clip=None
        if strict_controls:
            def text_under(node_id):
                def is_under(n):
                    while n:
                        if n==node_id:return True
                        n=by_id.get(n,{}).get('parentId')
                    return False
                return ''.join(n.get('characters','') for n in j['texts'] if is_under(n['id'])).strip()
            owners=[n for n in j['nodes'] if n.get('tag')=='summary' and text_under(n['id'])==marker.get('summary','').strip()]
            proof={'kind':'disclosure','summary':marker.get('summary'),'open':marker.get('open'),'assetBounds':marker['assetBounds'],'sourceOwnerId':owners[0]['id'] if len(owners)==1 else None}
            if len(owners)!=1:
                proof.update({'omitted':True,'reason':'Actual painted summary owner absent or ambiguous; no geometric fallback.'});clip_audit['markers'].append(proof);continue
            owner=owners[0];marker_clip=actual_owner_clip(owner);painted=intersect_bounds(marker['assetBounds'],marker_clip)
            proof.update({'ownerBounds':owner['bounds'],'ownerInheritedClip':owner['clip'],'ownerVisibleBounds':owner.get('visibleBounds'),'appliedPaintClip':marker_clip,'runVisibleBounds':painted})
            if owner.get('paintVisible') is False or painted['width']<=0 or painted['height']<=0:
                proof.update({'omitted':True,'reason':'Actual summary/marker clipped from view.'});clip_audit['markers'].append(proof);continue
            proof.update({'omitted':False,'partialClip':painted['width']<marker['assetBounds']['width']-.01 or painted['height']<marker['assetBounds']['height']-.01});clip_audit['markers'].append(proof)
        p=Path(marker['assetPath'])
        if wire:p=p.with_name(p.stem+'-gray.png')
        data=base64.b64encode(p.read_bytes()).decode();b=marker['assetBounds'];body=f'<image id="Native disclosure marker" x="{b["x"]}" y="{b["y"]}" width="{b["width"]}" height="{b["height"]}" href="data:image/png;base64,{data}" xlink:href="data:image/png;base64,{data}"/>'
        if strict_controls:
            node={'id':'marker-'+owner['id'],'clip':marker_clip};key=clip(node);body=f'<g id="{node["id"]} Native disclosure marker" clip-path="url(#{key})">{body}</g>'
        shapes.append(body);stats['icons']+=1
    if strict_controls:
        (OUT/(screen+'-control-clips.json')).write_text(json.dumps(clip_audit,ensure_ascii=False,indent=2)+'\n')
    if screen=='desktop-settings-data':
        shapes.append('<rect id="Native vertical scrollbar" x="1431" y="2" width="7" height="933.5" rx="3.5" fill="#7B7B79"/>')
    if screen=='desktop-navigation':
        # DOM traversal order is not CSS stacking order. The frozen scrim/sidebar
        # are shell siblings before main but paint at z-index20/21 above it.
        parent={n['id']:n.get('parentId') for n in j['nodes']}
        roots={n.get('name'):n['id'] for n in j['nodes'] if n.get('name') in ['#nav-scrim.scrim','#main-sidebar.sidebar']}
        def subtree(root):
            found={root}
            for n in j['nodes']:
                if n.get('parentId') in found:found.add(n['id'])
            return found
        scrim=subtree(roots['#nav-scrim.scrim']);sidebar=subtree(roots['#main-sidebar.sidebar'])
        def source_id(shape):
            m=re.match(r'<g id="([^ "]+)',shape)
            return m[1] if m else None
        background=[shape for shape in shapes if source_id(shape) not in scrim|sidebar]
        scrim_shapes=[shape for shape in shapes if source_id(shape) in scrim]
        sidebar_shapes=[shape for shape in shapes if source_id(shape) in sidebar]
        assert len(background)+len(scrim_shapes)+len(sidebar_shapes)==len(shapes)
        shapes=background+scrim_shapes+sidebar_shapes
    source=f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><defs>{"".join(defs)}</defs><g clip-path="url(#viewport)">{"".join(shapes)}</g></svg>'
    name=screen+('-wireframe' if wire else '-design')
    (OUT/(name+'.svg')).write_text(source)
    return {'screen':screen,'kind':'wireframe' if wire else 'design','file':name+'.svg',**stats}

if __name__=='__main__':
    results=[build(s,w) for s in SCREENS for w in [False,True]]
    (OUT/'artwork-manifest.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2))
