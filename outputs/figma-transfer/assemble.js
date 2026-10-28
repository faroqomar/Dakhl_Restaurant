// Inject CONFIG and masterData before running this Figma Plugin API script.
const page=await figma.getNodeByIdAsync(CONFIG.pageId);await figma.setCurrentPageAsync(page);
await figma.loadFontAsync({family:'Noto Sans Arabic',style:'Regular'});await figma.loadFontAsync({family:'Noto Sans Arabic',style:'Bold'});
const ids=[],frames=[],masterNodes={};
for(const [i,m]of masterData.masters.entries())masterNodes[i]=await figma.getNodeByIdAsync(m.id);
for(const rootId of CONFIG.roots){const ref=await figma.getNodeByIdAsync(rootId);const sections=ref.children[0].children.filter(n=>n.type==='FRAME');
 for(const source of sections){const title=source.children[0].findAllWithCriteria({types:['TEXT']})[0]?.characters||'Screen';const key=title.split(' · ')[0];if(page.children.some(n=>n.name===title))continue;
 const clone=source.clone();page.appendChild(clone);clone.name=title;const allSource=[source,...source.findAll(()=>true)],allClone=[clone,...clone.findAll(()=>true)];const pairs=[];
 for(let i=0;i<allSource.length;i++){const mi=masterData.map[allSource[i].id];if(mi!==undefined)pairs.push([allClone[i],mi]);}
 for(const t of clone.findAllWithCriteria({types:['TEXT']})){const weight=t.fontName?.style||'';t.fontName={family:'Noto Sans Arabic',style:/bold|black|heavy|semibold/i.test(weight)?'Bold':'Regular'};}
 let linked=0;for(const [old,mi]of pairs){if(old.removed)continue;const m=masterData.masters[mi],component=masterNodes[mi],parent=old.parent,index=parent.children.indexOf(old),x=old.x,y=old.y,w=old.width,h=old.height;
 const values=old.findAllWithCriteria({types:['TEXT']}).map(t=>t.characters),instance=component.createInstance();parent.insertChild(index,instance);instance.name=old.name;instance.resize(w,h);if(parent.layoutMode==='NONE'){instance.x=x;instance.y=y}else{instance.layoutGrow=old.layoutGrow;instance.layoutAlign=old.layoutAlign}
 const overrides={};m.props.forEach((p,i)=>{if(values[i]!==undefined)overrides[p]=values[i]});if(Object.keys(overrides).length)instance.setProperties(overrides);old.remove();linked++;
 }
 clone.layoutSizingHorizontal='FIXED';clone.layoutSizingVertical='HUG';const existing=page.children.filter(n=>n.id!==clone.id&&n.type==='FRAME'&&n.name.includes(' · '));const i=CONFIG.offset+frames.length;clone.x=80+(i%CONFIG.columns)*CONFIG.cellWidth;clone.y=80+Math.floor(i/CONFIG.columns)*CONFIG.cellHeight;
 ids.push(clone.id,...clone.findAll(()=>true).map(n=>n.id));frames.push({id:clone.id,key,title,width:clone.width,height:clone.height,linked,texts:clone.findAllWithCriteria({types:['TEXT']}).length,instances:clone.findAllWithCriteria({types:['INSTANCE']}).length});
 }
}
return {createdNodeIds:ids,mutatedNodeIds:[],frames};
