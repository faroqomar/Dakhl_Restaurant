from pathlib import Path
p=Path('outputs/penpot/phase01/reference-data/build-artwork-phase01.py');s=p.read_text();a=s.index('    attached={};unattached=[]');b=s.index('    for node in j[\'nodes\']:\n        draw(node)',a)
s=s[:a]+'''    strict_controls=screen in ['desktop-invoice-new','phone-invoice-new']
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
''' +s[b:]
a=s.index("    for marker in controlData.get('markers',[]):");b=s.index("    if screen=='desktop-settings-data':",a)
s=s[:a]+'''    for marker in controlData.get('markers',[]):
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
        (OUT/(screen+'-control-clips.json')).write_text(json.dumps(clip_audit,ensure_ascii=False,indent=2)+'\\n')
''' +s[b:]
p.write_text(s)
# Future derived extraction marks discrete indicators with exact source-owner identity.
p=Path('outputs/penpot/phase01/reference-data/capture-phase01.cjs');s=p.read_text().replace("kind:'indicator',assetPath:arrowPath,bounds:assetBounds","kind:'indicator',sourceControlId:n.id,assetPath:arrowPath,bounds:assetBounds");p.write_text(s)
