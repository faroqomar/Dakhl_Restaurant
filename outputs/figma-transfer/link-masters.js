const page=await figma.getNodeByIdAsync('0:1');await figma.setCurrentPageAsync(page);
for(const style of ['Regular','Bold'])await figma.loadFontAsync({family:'Noto Sans Arabic',style});
const roots=['3:2','6:2','10:2','8:2','9:2','11:2','13:2','12:2','14:2','17:2'];
const created=[],map={},cache={},groups={},stats={};const vars=await figma.variables.getLocalVariablesAsync();const styles=await figma.getLocalTextStylesAsync();
function category(n){if(n.type!=='FRAME')return null;if(n.name.startsWith('Button'))return n.height>100?'Product Card':n.children.some(c=>c.name==='Icon')&&n.children.length===1?'Icon Button':'Button';if(/Input|Text Area|Combobox|Checkbox|Select/.test(n.name))return 'Field';return null;}
function signature(n){const parts=n.findAll(x=>x.type==='VECTOR'||x.type==='TEXT'||('fills'in x&&Array.isArray(x.fills)&&x.fills.some(f=>f.type==='IMAGE')));return JSON.stringify([category(n),Math.round(n.width),Math.round(n.height),n.fills,n.opacity,n.children.length,parts.map(x=>x.type==='TEXT'?[x.fontSize,x.fontName.style]:x.type==='VECTOR'?x.vectorPaths:x.fills)]);}
for(const rootId of roots){const root=await figma.getNodeByIdAsync(rootId);const candidates=root.findAllWithCriteria({types:['FRAME']}).filter(n=>category(n));const candidateIds=new Set(candidates.map(n=>n.id));
for(const source of candidates){let parent=source.parent,skip=false;while(parent&&parent!==root){if(candidateIds.has(parent.id)){skip=true;break}parent=parent.parent}if(skip)continue;const key=signature(source),family=category(source);let item=cache[key];
if(!item){const copy=source.clone();page.appendChild(copy);const texts=copy.findAllWithCriteria({types:['TEXT']});for(const t of texts){const weight=t.fontName?.style||'';t.fontName={family:'Noto Sans Arabic',style:/bold|black|heavy|semibold/i.test(weight)?'Bold':'Regular'};t.textAutoResize='WIDTH_AND_HEIGHT';}
const c=figma.createComponentFromNode(copy);created.push(c.id,...c.findAll(()=>true).map(n=>n.id));c.name='Source/'+family+'/'+String(Object.keys(cache).length+1).padStart(3,'0');c.description='Reusable source layout from app/ui. Exact original control structure, editable Arabic font fallback. Width and labels can be overridden; colors link to Daftar variables.';
const props=[];for(const [i,t]of c.findAllWithCriteria({types:['TEXT']}).entries()){const p=c.addComponentProperty('Text '+(i+1),'TEXT',t.characters);t.componentPropertyReferences={characters:p};props.push(p)}
if(!groups[family]){const g=figma.createAutoLayout('HORIZONTAL',{name:'Source library / '+family,itemSpacing:24});page.appendChild(g);g.resize(3800,100);g.layoutWrap='WRAP';g.counterAxisSizingMode='FIXED';g.primaryAxisSizingMode='FIXED';g.layoutSizingVertical='HUG';g.paddingTop=g.paddingBottom=g.paddingLeft=g.paddingRight=24;g.fills=[];g.x=1600;g.y=80;groups[family]=g;created.push(g.id)}groups[family].appendChild(c);c.layoutSizingHorizontal='FIXED';c.layoutSizingVertical='FIXED';
item=cache[key]={id:c.id,props,family};stats[family]=(stats[family]||0)+1;}
map[source.id]=Object.keys(cache).indexOf(key);
}}
let y=80;for(const g of Object.values(groups)){g.x=1600;g.y=y;y+=g.height+120}
return {createdNodeIds:created,mutatedNodeIds:[],map,masters:Object.values(cache),stats,groups:Object.fromEntries(Object.entries(groups).map(([k,v])=>[k,v.id])),unique:Object.keys(cache).length};
